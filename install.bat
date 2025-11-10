@echo off
REM ============================================================================
REM Corporate Wallpaper Deployment
REM Executes PowerShell installation script
REM ============================================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-CorporateWallpaper.ps1"
exit /b %errorlevel%
