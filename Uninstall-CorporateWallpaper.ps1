# ============================================================================
# Script: Uninstall-CorporateWallpaper.ps1
# Description: Removes corporate wallpaper deployment
# Author: Andre Costa
# Repository: https://github.com/cascodigital/intune-wallpaper-deploy
# Version: 1.0.0
# License: MIT
# ============================================================================

<#
.SYNOPSIS
    Removes corporate wallpaper and scheduled task.

.DESCRIPTION
    Uninstalls the corporate wallpaper by removing the scheduled task
    and deleting the wallpaper folder.

.EXAMPLE
    .\Uninstall-CorporateWallpaper.ps1

.NOTES
    - Runs as SYSTEM
    - Removes scheduled task
    - Deletes wallpaper folder
#>

$destinationFolder = "C:\ProgramData\CorporateWallpapers"
$logPath = "C:\Windows\Logs\WallpaperDeploy.log"
$taskName = "Apply-Corporate-Wallpaper"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    try {
        Add-Content -Path $logPath -Value "[$timestamp] [$Level] $Message" -Force
    } catch {}
}

Write-Log "========================================" "INFO"
Write-Log "Corporate Wallpaper Uninstallation" "INFO"
Write-Log "========================================" "INFO"

# Remove scheduled task
try {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Log "Scheduled task removed: $taskName" "SUCCESS"
    } else {
        Write-Log "Task not found (already removed)" "INFO"
    }
} catch {
    Write-Log "Error removing task: $_" "WARN"
}

# Remove wallpaper folder
try {
    if (Test-Path $destinationFolder) {
        Remove-Item -Path $destinationFolder -Recurse -Force -ErrorAction Stop
        Write-Log "Wallpaper folder removed: $destinationFolder" "SUCCESS"
    } else {
        Write-Log "Folder not found (already removed)" "INFO"
    }
} catch {
    Write-Log "Error removing folder: $_" "WARN"
}

Write-Log "========================================" "INFO"
Write-Log "Uninstallation completed" "SUCCESS"
Write-Log "========================================" "INFO"

exit 0
