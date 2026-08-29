[CmdletBinding()]
param(
  [string]$ManifestPath = "",
  [string]$SourceRepository = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $ManifestPath) { $ManifestPath = Join-Path $PSScriptRoot "..\stable\manifest.json" }

function Assert-Condition {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

$manifestFile = [System.IO.Path]::GetFullPath($ManifestPath)
Assert-Condition (Test-Path -LiteralPath $manifestFile -PathType Leaf) "Manifest not found: $manifestFile"
$manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json

$required = @("schema_version", "product", "version", "channel", "asset", "package_url", "release_commit", "published_at", "signature")
foreach ($field in $required) {
  Assert-Condition ($null -ne $manifest.PSObject.Properties[$field]) "Manifest field missing: $field"
}

$version = [string]$manifest.version
Assert-Condition ([string]$manifest.schema_version -eq "1.0.0") "Unsupported manifest schema_version."
Assert-Condition ([string]$manifest.product -eq "danetti-price-scraper") "Unexpected manifest product."
Assert-Condition ([string]$manifest.channel -eq "stable") "Unexpected manifest channel."
Assert-Condition ($version -match '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') "Invalid semantic version."
Assert-Condition ([string]$manifest.release_commit -match '^[0-9a-f]{40}$') "Invalid release_commit."
Assert-Condition ([string]$manifest.asset.name -eq "danetti-price-scraper-$version.zip") "Asset name/version mismatch."
Assert-Condition ([long]$manifest.asset.size -gt 0) "Asset size must be positive."
Assert-Condition ([string]$manifest.asset.sha256 -match '^[0-9a-f]{64}$') "Invalid asset SHA-256."

$expectedUrl = "https://github.com/Bajna007/DanettiPriceScraper-Releases/releases/download/v$version/danetti-price-scraper-$version.zip"
Assert-Condition ([string]$manifest.package_url -eq $expectedUrl) "Package URL does not match repository, tag, version, and asset name."

$published = [DateTimeOffset]::MinValue
Assert-Condition ([DateTimeOffset]::TryParse([string]$manifest.published_at, [ref]$published)) "Invalid published_at timestamp."
try {
  $signatureBytes = [Convert]::FromBase64String([string]$manifest.signature)
} catch {
  throw "Manifest signature is not valid base64."
}
Assert-Condition ($signatureBytes.Length -eq 64) "Ed25519 signature must decode to 64 bytes."

if ($SourceRepository) {
  $sourceRoot = [System.IO.Path]::GetFullPath($SourceRepository)
  Assert-Condition (Test-Path -LiteralPath (Join-Path $sourceRoot ".git")) "SourceRepository is not a Git checkout."
  $commit = [string]$manifest.release_commit

  & git -C $sourceRoot cat-file -e "$commit`^{commit}"
  Assert-Condition ($LASTEXITCODE -eq 0) "Signed source commit is unavailable in SourceRepository."

  $tagCommit = (& git -C $sourceRoot rev-parse "refs/tags/v$version`^{commit}" 2>$null | Select-Object -First 1)
  Assert-Condition ($LASTEXITCODE -eq 0 -and [string]$tagCommit -eq $commit) "Version tag does not resolve to signed source commit."

  $packageJsonText = (& git -C $sourceRoot show "$commit`:package.json") -join "`n"
  Assert-Condition ($LASTEXITCODE -eq 0) "package.json is unavailable at signed source commit."
  $sourcePackage = $packageJsonText | ConvertFrom-Json
  Assert-Condition ([string]$sourcePackage.version -eq $version) "Source package version does not match manifest."

  $sourceRepair = ((& git -C $sourceRoot show "$commit`:scripts/updates/repair-updater.ps1") -join "`n").TrimEnd()
  Assert-Condition ($LASTEXITCODE -eq 0) "Repair script is unavailable at signed source commit."
  $publicRepairPath = Join-Path (Split-Path -Parent $manifestFile) "repair-updater.ps1"
  Assert-Condition (Test-Path -LiteralPath $publicRepairPath -PathType Leaf) "Public repair script is missing."
  $publicRepair = (Get-Content -LiteralPath $publicRepairPath -Raw).Replace("`r`n", "`n").TrimEnd()
  Assert-Condition ($sourceRepair -eq $publicRepair) "Public repair script differs from signed source commit."
}

Write-Output "Danetti release repository verification passed for v$version."
