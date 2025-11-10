# ============================================================================
# Script: Detect-CorporateWallpaper.ps1
# Description: Detection script for Intune
# Author: Andre Costa
# Repository: https://github.com/[your-username]/intune-wallpaper-deploy
# Version: 1.0.0
# License: MIT
# ============================================================================

<#
.SYNOPSIS
    Detects if corporate wallpaper is installed.

.DESCRIPTION
    Checks for the presence of the wallpaper file and scheduled task.
    Returns exit code 0 if detected (installed), exit code 1 if not.

.EXAMPLE
    .\Detect-CorporateWallpaper.ps1

.NOTES
    Used by Intune as detection rule for Win32 app
#>

$wallpaperPath = "C:\ProgramData\CorporateWallpapers\wallpaper.jpg"
$taskName = "Apply-Corporate-Wallpaper"

# Check if wallpaper file exists
$fileExists = Test-Path $wallpaperPath

# Check if scheduled task exists
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($fileExists -and $taskExists) {
    # Verify file is not corrupted (minimum size check)
    $fileSize = (Get-Item $wallpaperPath).Length

    if ($fileSize -gt 10000) {
        Write-Host "Corporate wallpaper is installed"
        exit 0
    }
}

Write-Host "Corporate wallpaper is not installed"
exit 1
