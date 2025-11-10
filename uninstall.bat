@echo off
REM ============================================================================
REM Corporate Wallpaper Uninstallation
REM Executes PowerShell uninstallation script
REM ============================================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-CorporateWallpaper.ps1"
exit /b %errorlevel%
