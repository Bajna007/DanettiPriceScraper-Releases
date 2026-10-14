[CmdletBinding()]
param(
  [string]$InstallDirectory = "",
  [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repository = "Bajna007/DanettiPriceScraper-Releases"
$manifestUrl = "https://raw.githubusercontent.com/$repository/main/stable/manifest-git.json"
$publicKey = "b1lkLdDw9CaJ+62oHEcGAmQgw9so6E+nxiyuCWkJUp4="
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("danetti-git-update-" + [guid]::NewGuid().ToString("N"))

function Test-DanettiRoot {
  param([string]$Path)
  if (-not $Path) { return $false }
  $packagePath = Join-Path $Path "package.json"
  if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { return $false }
  try { return [string](Get-Content $packagePath -Raw | ConvertFrom-Json).name -eq "danetti-price-scraper" }
  catch { return $false }
}

function Find-DanettiRoot {
  if ($InstallDirectory) {
    $resolved = [System.IO.Path]::GetFullPath($InstallDirectory)
    if (-not (Test-DanettiRoot $resolved)) { throw "A megadott mappa nem Danetti-telepites: $resolved" }
    return $resolved
  }
  if (Test-DanettiRoot (Get-Location).Path) { return (Get-Location).Path }
  $desktop = [Environment]::GetFolderPath("Desktop")
  $candidates = @()
  if ($desktop) {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($shortcut in @(Get-ChildItem $desktop -Filter "*Danetti*.lnk" -File -ErrorAction SilentlyContinue)) {
      try { $candidates += $shell.CreateShortcut($shortcut.FullName).WorkingDirectory } catch {}
    }
    $shortcutRoots = @($candidates | Where-Object { Test-DanettiRoot $_ } | Select-Object -Unique)
    if ($shortcutRoots.Count -eq 1) { return [System.IO.Path]::GetFullPath($shortcutRoots[0]) }
    $candidates += @( (Join-Path $desktop "DanettiPriceScraper-main"), (Join-Path $desktop "DanettiPriceScraper") )
  }
  $roots = @($candidates | Where-Object { Test-DanettiRoot $_ } | Select-Object -Unique)
  if ($roots.Count -eq 1) { return [System.IO.Path]::GetFullPath($roots[0]) }
  Add-Type -AssemblyName System.Windows.Forms
  $picker = New-Object System.Windows.Forms.FolderBrowserDialog
  try {
    $picker.Description = "Valaszd ki a meglevo DanettiPriceScraper telepitesi mappat."
    if ($picker.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK -and (Test-DanettiRoot $picker.SelectedPath)) {
      return $picker.SelectedPath
    }
  } finally { $picker.Dispose() }
  throw "Nem talalom a Danetti telepitesi mappat. Add meg az -InstallDirectory parameterrel."
}

function Invoke-NodeChecked {
  param([string[]]$Arguments)
  & node @Arguments
  if ($LASTEXITCODE -ne 0) { throw "A Danetti csomagellenorzese hibakoddal leallt: $LASTEXITCODE" }
}

try {
  $root = Find-DanettiRoot
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "Node.js nem talalhato." }
  New-Item -ItemType Directory -Path $stage -Force | Out-Null
  $manifestPath = Join-Path $stage "manifest.json"
  Invoke-WebRequest -UseBasicParsing -Uri $manifestUrl -Headers @{
    Accept = "application/vnd.github.raw+json"
    "Cache-Control" = "no-cache"
    "User-Agent" = "Danetti-Git-Update"
    "X-GitHub-Api-Version" = "2022-11-28"
  } -OutFile $manifestPath
  $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
  $version = [string]$manifest.version
  $commit = [string]$manifest.artifact_commit
  if ([string]$manifest.schema_version -ne "2.0.0" -or [string]$manifest.distribution -ne "github_git" -or
      $version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$' -or $commit -notmatch '^[a-f0-9]{40}$') {
    throw "A GitHub frissitesi jegyzek ervenytelen."
  }
  $expectedUrl = "https://raw.githubusercontent.com/$repository/$commit/packages/v$version/danetti-price-scraper-$version.zip"
  if ([string]$manifest.package_url -ne $expectedUrl) { throw "Nem engedelyezett Danetti csomagforras." }
  # Bootstrap verification tools are fetched from the same immutable GitHub commit
  # as the package. No key, Git executable or GitHub login is needed on the client.
  foreach ($filename in @("release-manifest.mjs", "verify-release.mjs")) {
    Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/$repository/$commit/bootstrap/$filename" -OutFile (Join-Path $stage $filename)
  }
  $verifier = Join-Path $stage "verify-release.mjs"
  $verification = @($verifier, "--manifest", $manifestPath, "--version", $version,
    "--release-repository", $repository, "--allow-git-distribution", "--runtime-root", $root)
  Invoke-NodeChecked -Arguments @($verification + "--manifest-only")
  $packagePath = Join-Path $stage "danetti-price-scraper-$version.zip"
  Write-Output "Danetti v$version letoltese es ellenorzese..."
  Invoke-WebRequest -UseBasicParsing -Uri $expectedUrl -OutFile $packagePath
  Invoke-NodeChecked -Arguments @($verification + @("--zip", $packagePath))
  if ($VerifyOnly) { Write-Output "OK: a Danetti v$version GitHub-csomagja es fajllistaja ervenyes."; return }
  $extract = Join-Path $stage "extract"
  Expand-Archive -LiteralPath $packagePath -DestinationPath $extract -Force
  $installer = Join-Path $extract "danetti-price-scraper/scripts/updates/apply-signed-update.ps1"
  if (-not (Test-Path $installer -PathType Leaf)) { throw "A csomagbol hianyzik a Danetti frissito." }
  $powerShell = if ($env:SystemRoot) { Join-Path $env:SystemRoot "System32/WindowsPowerShell/v1.0/powershell.exe" } else { (Get-Process -Id $PID).Path }
  & $powerShell -NoProfile -ExecutionPolicy Bypass -File $installer -ManifestUrl $manifestUrl -ExpectedVersion $version -PublicKey $publicKey -InstallDirectory $root
  if ($LASTEXITCODE -ne 0) { throw "A Danetti frissitese hibakoddal leallt: $LASTEXITCODE" }
  Write-Output "A Danetti v$version frissitese elkeszult. A kovetkezo frissites mar az alkalmazasbol indithato."
} finally {
  if (Test-Path $stage -PathType Container) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
