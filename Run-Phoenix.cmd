@echo off
cd /d "%~dp0"
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-PhoenixApps.ps1"
echo.
pause
