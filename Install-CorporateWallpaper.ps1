# ============================================================================
# Script: Install-CorporateWallpaper.ps1
# Description: Deploys corporate wallpaper via Intune with Scheduled Task
# Author: Andre Costa
# Repository: https://github.com/cascodigital/intune-wallpaper-deploy
# Version: 1.0.0
# License: MIT
# ============================================================================

<#
.SYNOPSIS
    Deploys corporate wallpaper to Windows devices via Intune.

.DESCRIPTION
    This script copies a wallpaper image to a corporate folder and creates
    a Scheduled Task that applies the wallpaper when users log in.

    The script runs in SYSTEM context (via Intune), but the wallpaper is
    applied in USER context through the scheduled task.

.PARAMETER WallpaperName
    Name of the wallpaper file (default: wallpaper.jpg)

.PARAMETER LogPath
    Path to the log file (default: C:\Windows\Logs\WallpaperDeploy.log)

.EXAMPLE
    .\Install-CorporateWallpaper.ps1

.EXAMPLE
    .\Install-CorporateWallpaper.ps1 -WallpaperName "company-bg.jpg"

.NOTES
    - Runs as SYSTEM
    - Creates scheduled task for user context execution
    - Wallpaper style: Fill (covers entire screen without distortion)
    - Multi-language support: Uses SIDs instead of group names
#>

param(
    [string]$WallpaperName = "wallpaper.jpg",
    [string]$LogPath = "C:\Windows\Logs\WallpaperDeploy.log"
)

# ============================================================================
# LOGGING FUNCTION
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","SUCCESS","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage

    try {
        Add-Content -Path $LogPath -Value $logMessage -Force
    } catch {
        # Silently continue if log write fails
    }
}

# ============================================================================
# INITIALIZE
# ============================================================================

$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

Write-Log "========================================" "INFO"
Write-Log "Corporate Wallpaper Deployment Started" "INFO"
Write-Log "========================================" "INFO"

# ============================================================================
# CONFIGURATION
# ============================================================================

$destinationFolder = "C:\ProgramData\CorporateWallpapers"
$destinationPath = "$destinationFolder\$WallpaperName"
$sourcePath = "$PSScriptRoot\$WallpaperName"
$userScriptPath = "$destinationFolder\Apply-Wallpaper-User.ps1"
$taskName = "Apply-Corporate-Wallpaper"

Write-Log "Source: $sourcePath" "INFO"
Write-Log "Destination: $destinationPath" "INFO"

# ============================================================================
# STEP 1: COPY WALLPAPER FILE
# ============================================================================

Write-Log "Step 1: Copying wallpaper file..." "INFO"

try {
    # Create destination folder
    if (-not (Test-Path $destinationFolder)) {
        New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
        Write-Log "Created folder: $destinationFolder" "INFO"
    }

    # Verify source exists
    if (-not (Test-Path $sourcePath)) {
        Write-Log "ERROR: Source file not found: $sourcePath" "ERROR"
        Write-Log "Ensure wallpaper.jpg is in the same folder as this script" "ERROR"
        exit 1
    }

    # Copy wallpaper
    Copy-Item -Path $sourcePath -Destination $destinationPath -Force -ErrorAction Stop

    $fileSize = (Get-Item $destinationPath).Length
    Write-Log "Wallpaper copied successfully ($([math]::Round($fileSize/1MB, 2)) MB)" "SUCCESS"

    # Set permissions using SID (works in any Windows language)
    try {
        $acl = Get-Acl $destinationPath
        # S-1-5-32-545 = BUILTIN\Users (universal SID)
        $usersSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
        $usersAccount = $usersSID.Translate([System.Security.Principal.NTAccount])
        $permission = $usersAccount, "Read", "Allow"
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
        $acl.SetAccessRule($accessRule)
        Set-Acl $destinationPath $acl
        Write-Log "Permissions configured" "INFO"
    } catch {
        Write-Log "WARNING: Could not set ACL (non-critical): $_" "WARN"
    }

} catch {
    Write-Log "ERROR copying wallpaper: $_" "ERROR"
    exit 1
}

# ============================================================================
# STEP 2: CREATE USER-CONTEXT SCRIPT
# ============================================================================

Write-Log "Step 2: Creating user-context script..." "INFO"

# User script template (executed when user logs in)
$userScriptContent = @'
$wallpaperPath = "WALLPAPER_PATH_PLACEHOLDER"
$logPath = "LOG_PATH_PLACEHOLDER"

function Write-UserLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    try {
        Add-Content -Path $logPath -Value "[$timestamp] [USER:$env:USERNAME] $Message" -Force
    } catch {}
}

Write-UserLog "Applying corporate wallpaper..."

try {
    # Verify wallpaper file exists
    if (-not (Test-Path $wallpaperPath)) {
        Write-UserLog "ERROR: Wallpaper file not found at $wallpaperPath"
        exit 1
    }

    # Configure user registry
    $regPath = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $regPath -Name "Wallpaper" -Value $wallpaperPath -Force
    Set-ItemProperty -Path $regPath -Name "WallpaperStyle" -Value "10" -Force  # Fill
    Set-ItemProperty -Path $regPath -Name "TileWallpaper" -Value "0" -Force

    Write-UserLog "Registry configured"

    # Apply wallpaper immediately using Windows API
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

    [Wallpaper]::SystemParametersInfo(20, 0, $wallpaperPath, 0x01 -bor 0x02)
    Write-UserLog "Wallpaper applied successfully"

} catch {
    Write-UserLog "ERROR: $_"
}
'@

# Replace placeholders with actual paths
$userScriptContent = $userScriptContent.Replace("WALLPAPER_PATH_PLACEHOLDER", $destinationPath)
$userScriptContent = $userScriptContent.Replace("LOG_PATH_PLACEHOLDER", $LogPath)

try {
    Set-Content -Path $userScriptPath -Value $userScriptContent -Force -ErrorAction Stop
    Write-Log "User script created: $userScriptPath" "SUCCESS"
} catch {
    Write-Log "ERROR creating user script: $_" "ERROR"
    exit 1
}

# ============================================================================
# STEP 3: CREATE SCHEDULED TASK
# ============================================================================

Write-Log "Step 3: Creating scheduled task..." "INFO"

# Remove existing task if present
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

try {
    # Task action: Execute PowerShell with user script
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$userScriptPath`""

    # Task trigger: At logon of any user
    $trigger = New-ScheduledTaskTrigger -AtLogOn

    # Task principal: Run as logged-in user (not SYSTEM)
    # Use SID S-1-5-32-545 for Users group (works in any language)
    $usersSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545")
    $usersGroup = $usersSID.Translate([System.Security.Principal.NTAccount]).Value
    $principal = New-ScheduledTaskPrincipal -GroupId $usersGroup -RunLevel Limited

    # Task settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    # Register task
    Register-ScheduledTask `
        -TaskName $taskName `
        -Description "Applies corporate wallpaper at user logon" `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Force | Out-Null

    Write-Log "Scheduled task created: $taskName" "SUCCESS"

    # Verify task was created
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Log "Task verified - State: $($task.State)" "SUCCESS"
    } else {
        Write-Log "WARNING: Task created but verification failed" "WARN"
    }

} catch {
    Write-Log "ERROR creating scheduled task: $_" "ERROR"
    exit 1
}

# ============================================================================
# STEP 4: APPLY FOR CURRENTLY LOGGED-IN USERS
# ============================================================================

Write-Log "Step 4: Applying for currently logged-in users..." "INFO"

try {
    # Find logged-in users by looking for explorer.exe processes
    $loggedUsers = Get-WmiObject -Class Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue |
        ForEach-Object { 
            $owner = $_.GetOwner()
            if ($owner.User -and $owner.Domain) {
                [PSCustomObject]@{
                    User = $owner.User
                    Domain = $owner.Domain
                }
            }
        } | Select-Object -Unique User, Domain

    if ($loggedUsers) {
        Write-Log "Found $($loggedUsers.Count) logged-in user(s)" "INFO"

        # Execute task immediately for current users
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
        Write-Log "Task executed for current users" "SUCCESS"

        # Wait for task to complete
        Start-Sleep -Seconds 3

    } else {
        Write-Log "No users currently logged in" "INFO"
        Write-Log "Wallpaper will apply at next login" "INFO"
    }
} catch {
    Write-Log "Could not execute task immediately: $_" "WARN"
    Write-Log "Wallpaper will apply at next login" "INFO"
}

# ============================================================================
# COMPLETION
# ============================================================================

Write-Log "========================================" "INFO"
Write-Log "Deployment completed successfully!" "SUCCESS"
Write-Log "========================================" "INFO"

exit 0
