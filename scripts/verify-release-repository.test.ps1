Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$verifier = Join-Path $PSScriptRoot "verify-release-repository.ps1"
& $verifier

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("danetti-release-verifier-test-" + [guid]::NewGuid().ToString("N") + ".json")
try {
  $manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\stable\manifest.json") -Raw | ConvertFrom-Json
  $manifest.asset.sha256 = "not-a-sha256"
  $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temp -Encoding utf8
  $rejected = $false
  try {
    & $verifier -ManifestPath $temp
  } catch {
    $rejected = $true
  }
  if (-not $rejected) { throw "Invalid manifest SHA-256 was accepted." }
  Write-Output "Danetti release repository verifier tests passed."
} finally {
  if (Test-Path -LiteralPath $temp -PathType Leaf) { Remove-Item -LiteralPath $temp -Force }
}
