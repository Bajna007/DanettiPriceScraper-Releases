@echo off
setlocal DisableDelayedExpansion
title Danetti frissites
echo Danetti frissito inditasa...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; $stage=Join-Path ([IO.Path]::GetTempPath()) ('danetti-bootstrap-'+[guid]::NewGuid().ToString('N')); try { New-Item -ItemType Directory -Path $stage | Out-Null; $script=Join-Path $stage 'update.ps1'; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/Bajna007/DanettiPriceScraper-Releases/0d3447b96fa483765db19a942191529ccaf97f70/bootstrap/repair-keyless-updater.ps1' -OutFile $script; & $script } catch { Write-Host $_.Exception.Message; exit 1 } finally { if(Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force } }"
if errorlevel 1 (
  echo A frissites nem fejezodott be. A hiba fent lathato.
  pause
  exit /b 1
)
echo A Danetti frissitese elkeszult.
pause
