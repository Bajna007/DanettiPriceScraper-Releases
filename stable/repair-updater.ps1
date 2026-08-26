[CmdletBinding()]
param(
  [string]$InstallDirectory = "",
  [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$manifestUrl = "https://api.github.com/repos/Bajna007/DanettiPriceScraper-Releases/contents/stable/manifest.json?ref=main"
$releaseRepository = "Bajna007/DanettiPriceScraper-Releases"
$publicKey = "b1lkLdDw9CaJ+62oHEcGAmQgw9so6E+nxiyuCWkJUp4="
$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path -LiteralPath $powerShell -PathType Leaf)) { $powerShell = "powershell.exe" }
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("danetti-updater-repair-" + [guid]::NewGuid().ToString("N"))

function Test-DanettiInstallRoot {
  param([string]$Path)

  if (-not $Path) { return $false }
  $packagePath = Join-Path $Path "package.json"
  if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { return $false }
  try {
    $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
    return [string]$package.name -eq "danetti-price-scraper"
  } catch {
    return $false
  }
}

function Find-DanettiInstallRoot {
  if ($InstallDirectory) {
    $resolved = [System.IO.Path]::GetFullPath($InstallDirectory)
    if (-not (Test-DanettiInstallRoot $resolved)) {
      throw "A megadott mappa nem Danetti-telepites: $resolved"
    }
    return $resolved
  }

  $desktop = [Environment]::GetFolderPath("Desktop")
  $candidates = @(
    (Get-Location).Path,
    (Join-Path $desktop "DanettiPriceScraper-main"),
    (Join-Path $desktop "DanettiPriceScraper")
  )
  $shell = New-Object -ComObject WScript.Shell
  foreach ($shortcut in @(Get-ChildItem -LiteralPath $desktop -Filter "*Danetti*.lnk" -File -ErrorAction SilentlyContinue)) {
    try {
      $workingDirectory = $shell.CreateShortcut($shortcut.FullName).WorkingDirectory
      if ($workingDirectory) { $candidates += $workingDirectory }
    } catch {
    }
  }
  foreach ($candidate in @($candidates | Select-Object -Unique)) {
    if (Test-DanettiInstallRoot $candidate) { return [System.IO.Path]::GetFullPath($candidate) }
  }
  throw "Nem talalom a Danetti telepitesi mappat. Add meg az -InstallDirectory parameterrel."
}

try {
  $root = Find-DanettiInstallRoot
  $verifier = Join-Path $root "scripts\updates\verify-release.mjs"
  if (-not (Test-Path -LiteralPath $verifier -PathType Leaf)) {
    throw "A helyi alairas-ellenorzo hianyzik: $verifier"
  }
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "Node.js nem talalhato." }

  New-Item -ItemType Directory -Path $stage -Force | Out-Null
  $manifestPath = Join-Path $stage "manifest.json"
  Invoke-WebRequest -UseBasicParsing -Uri $manifestUrl -Headers @{
    Accept = "application/vnd.github.raw+json"
    "Cache-Control" = "no-cache"
    "User-Agent" = "Danetti-Updater-Repair"
    "X-GitHub-Api-Version" = "2022-11-28"
  } -OutFile $manifestPath
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  $version = [string]$manifest.version
  if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
    throw "A publikus frissitesi jegyzek verzioja ervenytelen."
  }
  $packagePath = Join-Path $stage "danetti-price-scraper-$version.zip"
  Invoke-WebRequest -UseBasicParsing -Uri ([string]$manifest.package_url) -OutFile $packagePath

  & node $verifier `
    --manifest $manifestPath `
    --zip $packagePath `
    --version $version `
    --release-repository $releaseRepository `
    --public-key $publicKey
  if ($LASTEXITCODE -ne 0) { throw "A mentofrissites alairas-ellenorzese hibakoddal leallt: $LASTEXITCODE" }
  if ($VerifyOnly) {
    Write-Output "OK: a Danetti v$version mentofrissitesi csomagja hiteles. Git nem szukseges."
    return
  }

  $extractDirectory = Join-Path $stage "extract"
  Expand-Archive -LiteralPath $packagePath -DestinationPath $extractDirectory -Force
  $authenticatedUpdater = Join-Path $extractDirectory "danetti-price-scraper\scripts\updates\apply-signed-update.ps1"
  if (-not (Test-Path -LiteralPath $authenticatedUpdater -PathType Leaf)) {
    throw "A hitelesitett csomagbol hianyzik az updater."
  }

  & $powerShell `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $authenticatedUpdater `
    -ManifestUrl $manifestUrl `
    -ExpectedVersion $version `
    -PublicKey $publicKey `
    -InstallDirectory $root
  if ($LASTEXITCODE -ne 0) { throw "A Danetti mentofrissitese hibakoddal leallt: $LASTEXITCODE" }
  Write-Output "A Danetti v$version hitelesitett mentofrissitese elkeszult."
} finally {
  if (Test-Path -LiteralPath $stage -PathType Container) {
    $resolvedStage = [System.IO.Path]::GetFullPath($stage)
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if ($resolvedStage.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolvedStage).StartsWith("danetti-updater-repair-")) {
      Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
  }
}
