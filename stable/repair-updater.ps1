[CmdletBinding()]
param(
  [string]$InstallDirectory = "",
  [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$manifestUrl = "https://api.github.com/repos/Bajna007/DanettiPriceScraper-Releases/contents/stable/manifest.json?ref=main"
$publicKey = "b1lkLdDw9CaJ+62oHEcGAmQgw9so6E+nxiyuCWkJUp4="
$powerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path -LiteralPath $powerShell -PathType Leaf)) { $powerShell = "powershell.exe" }

function Test-DanettiInstallRoot {
  param([string]$Path)

  if (-not $Path) { return $false }
  return (
    (Test-Path -LiteralPath (Join-Path $Path "package.json") -PathType Leaf) -and
    (Test-Path -LiteralPath (Join-Path $Path "scripts\updates\apply-signed-update.ps1") -PathType Leaf)
  )
}

function Find-DanettiInstallRoot {
  if ($InstallDirectory) {
    $resolved = [System.IO.Path]::GetFullPath($InstallDirectory)
    if (-not (Test-DanettiInstallRoot $resolved)) {
      throw "A megadott mappa nem Danetti-telepítés: $resolved"
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

  foreach ($script in @(Get-ChildItem -LiteralPath $desktop -Filter "apply-signed-update.ps1" -File -Recurse -ErrorAction SilentlyContinue)) {
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $script.DirectoryName "..\.."))
    if (Test-DanettiInstallRoot $candidate) { return $candidate }
  }
  throw "Nem találom a Danetti telepítési mappáját az Asztalon. Futtasd újra az InstallDirectory megadásával."
}

$root = Find-DanettiInstallRoot
Write-Output "Danetti telepítés: $root"
$manifest = Invoke-RestMethod -Uri $manifestUrl -Headers @{
  Accept = "application/vnd.github.raw+json"
  "Cache-Control" = "no-cache"
  "User-Agent" = "Danetti-Updater-Repair"
  "X-GitHub-Api-Version" = "2022-11-28"
}
$version = [string]$manifest.version
if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
  throw "A publikus frissítési jegyzék verziója érvénytelen."
}

Write-Output "A Danetti $version aláírt frissítése indul."
$arguments = @(
  "-NoProfile",
  "-ExecutionPolicy",
  "Bypass",
  "-File",
  (Join-Path $root "scripts\updates\apply-signed-update.ps1"),
  "-ManifestUrl",
  $manifestUrl,
  "-ExpectedVersion",
  $version,
  "-PublicKey",
  $publicKey
)
if ($VerifyOnly) { $arguments += "-VerifyOnly" }
& $powerShell @arguments
if ($LASTEXITCODE -ne 0) { throw "A Danetti mentőfrissítése hibakóddal leállt: $LASTEXITCODE" }
Write-Output $(if ($VerifyOnly) { "A Danetti $version mentőfrissítője ellenőrizve." } else { "A Danetti $version mentőfrissítése elkészült." })
