# Deployment Guide

Complete step-by-step guide for deploying corporate wallpaper via Microsoft Intune.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Prepare Wallpaper](#step-1-prepare-wallpaper)
- [Step 2: Create Package](#step-2-create-package)
- [Step 3: Upload to Intune](#step-3-upload-to-intune)
- [Step 4: Configure App](#step-4-configure-app)
- [Step 5: Assign](#step-5-assign)
- [Step 6: Monitor](#step-6-monitor)
- [Step 7: Verify](#step-7-verify)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- **Microsoft Intune subscription**
- **Admin access** to Microsoft Endpoint Manager
- **IntuneWinAppUtil.exe** - [Download here](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool)
- **PowerShell 5.1+** on your admin workstation
- **Windows 10/11 target devices** enrolled in Intune

## Step 1: Prepare Wallpaper

### 1.1 Choose or Create Wallpaper

**Recommendations**:
- Resolution: **1920x1080** (minimum), **2560x1440** (recommended), **3840x2160** (4K)
- Format: **JPG**
- Size: Maximum **5 MB**
- Aspect ratio: **16:9** for modern displays

### 1.2 Rename File

Rename your image to **exactly**: `wallpaper.jpg`

### 1.3 Place in Repository

Copy `wallpaper.jpg` to the repository folder.

## Step 2: Create Package

### 2.1 Download IntuneWinAppUtil

```powershell
# Download from GitHub
Invoke-WebRequest -Uri "https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe" -OutFile "IntuneWinAppUtil.exe"
```

### 2.2 Verify Files

Ensure these files are in the repository folder:

```
intune-wallpaper-deploy/
├── Install-CorporateWallpaper.ps1
├── Uninstall-CorporateWallpaper.ps1
├── Detect-CorporateWallpaper.ps1
├── install.bat
├── uninstall.bat
└── wallpaper.jpg  ← Your image
```

### 2.3 Create .intunewin Package

```powershell
.\IntuneWinAppUtil.exe -c ".\intune-wallpaper-deploy" -s "install.bat" -o ".\intune-wallpaper-deploy"
```

**Output**: `install.intunewin` in the same folder

## Step 3: Upload to Intune

### 3.1 Open Endpoint Manager

Navigate to: [https://endpoint.microsoft.com](https://endpoint.microsoft.com)

### 3.2 Create New App

1. Go to **Apps** → **Windows** → **Add**
2. Select: **Windows app (Win32)**
3. Click **Select app package file**
4. Browse and select `install.intunewin`
5. Click **OK**

## Step 4: Configure App

### 4.1 App Information

| Field | Value |
|-------|-------|
| **Name** | Corporate Wallpaper |
| **Description** | Deploys corporate wallpaper to Windows devices via scheduled task |
| **Publisher** | Your Company Name |
| **App version** | 1.0.0 |
| **Category** | Productivity |
| **Show as featured** | No |
| **Information URL** | (optional) |
| **Privacy URL** | (optional) |

Click **Next**

### 4.2 Program

| Setting | Value |
|---------|-------|
| **Install command** | `install.bat` |
| **Uninstall command** | `uninstall.bat` |
| **Install behavior** | **System** (important!) |
| **Device restart behavior** | No specific action |
| **Return codes** | Use defaults |

Click **Next**

### 4.3 Requirements

| Requirement | Value |
|-------------|-------|
| **Operating system architecture** | 64-bit |
| **Minimum operating system** | Windows 10 1607 |

Click **Next**

### 4.4 Detection Rules

1. **Rules format**: Use a custom detection script
2. **Script file**: Click **Select** and upload `Detect-CorporateWallpaper.ps1`
3. **Run script as 32-bit process**: **No**
4. **Enforce script signature check**: **No**

Click **Next**

### 4.5 Dependencies

None needed. Click **Next**

### 4.6 Supersedence

None needed. Click **Next**

### 4.7 Assignments

#### Required (Recommended)

1. Click **Add group**
2. Select **All devices** or specific device groups
3. Click **Select**

#### Available for enrolled devices (Optional)

Leave empty unless you want users to install on-demand.

#### Uninstall (Optional)

Leave empty.

Click **Next**

### 4.8 Review and Create

Review all settings and click **Create**

Upload may take 1-2 minutes.

## Step 5: Assign

App is now assigned to selected groups. Devices will receive it during next sync.

### Sync Timing

- **Automatic sync**: Every 8 hours
- **Manual sync (user)**: Settings → Accounts → Work/School → Sync
- **Manual sync (portal)**: Device page → Sync button
- **Expected deployment time**: 30-60 minutes for first deployment

## Step 6: Monitor

### 6.1 Device Install Status

1. Go to **Apps** → **Windows apps** → **Corporate Wallpaper**
2. Click **Device install status**
3. View status for each device:
   - **In progress**: Installing
   - **Installed**: Success
   - **Failed**: Check logs

### 6.2 User Install Status

View per-user installation status (useful for shared devices).

### 6.3 Refresh Data

Click **Refresh** button to update status. May take a few minutes to reflect changes.

## Step 7: Verify

### On a Target Device

#### Check Installation

```powershell
# Wallpaper file
Test-Path C:\ProgramData\CorporateWallpapers\wallpaper.jpg
# Should return: True

# Scheduled task
Get-ScheduledTask -TaskName "Apply-Corporate-Wallpaper"
# Should return task details

# View log
Get-Content C:\Windows\Logs\WallpaperDeploy.log -Tail 20
```

#### Test Wallpaper Application

```powershell
# Execute task manually
Start-ScheduledTask -TaskName "Apply-Corporate-Wallpaper"

# Wallpaper should change immediately
```

#### Verify at Login

1. Log off
2. Log back in
3. Wallpaper should appear automatically

## Troubleshooting

### Installation Shows "Failed"

**Check Intune logs** on device:

```powershell
Get-Content "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log" | Select-String "Corporate Wallpaper" -Context 5
```

**Common causes**:
- wallpaper.jpg missing from package
- Incorrect file permissions
- PowerShell execution policy blocked

**Solution**: Recreate .intunewin ensuring wallpaper.jpg is included

### "Installed" but Wallpaper Doesn't Appear

**Check scheduled task**:

```powershell
$task = Get-ScheduledTask -TaskName "Apply-Corporate-Wallpaper"
if ($null -eq $task) {
    Write-Host "Task not created - check installation logs"
} else {
    Write-Host "Task exists - State: $($task.State)"
}
```

**If task exists**: Log off and log back in

**If task missing**: Script didn't run completely, check logs

### Wallpaper Reverts to Default

This is expected behavior. The scheduled task **only applies at logon**. If user manually changes wallpaper, it stays changed until next logon.

**To prevent**: Use Group Policy (not covered in this script).

### Intune Sync Takes Forever

**This is normal**, especially for first deployment:
- First deployment: 30-60 minutes
- Updates: 15-45 minutes
- Multiple edits: Longer due to throttling

**Workaround**: Test locally first to confirm it works:

```powershell
# As Administrator on target device
cd C:\path\to\files
.\install.bat
```

### Deployment Stuck "In Progress"

**Force sync** on device:
- Settings → Accounts → Work/School → Sync
- Or restart device
- Or wait 8 hours for automatic sync

**If still stuck after 2 hours**: Check if device can reach Intune service

## Best Practices

1. **Test on pilot group** before full deployment
2. **Optimize image size** to reduce deployment time
3. **Monitor first 24 hours** for failures
4. **Document deployment date** and wallpaper version
5. **Communicate to users** about the change

## Updating Wallpaper

To deploy a new wallpaper:

### Option A: Update Existing App

1. Replace `wallpaper.jpg` with new image
2. Recreate `.intunewin` package
3. In Intune, edit the app
4. Upload new `.intunewin`
5. Save

Devices will automatically receive update.

### Option B: Create New Version

1. Create new app: "Corporate Wallpaper v2"
2. Assign to same groups
3. Old app will be superseded

## Rollback

To remove wallpaper:

1. Go to app **Assignments**
2. Move groups from **Required** to **Uninstall**
3. Save

Devices will uninstall on next sync.

---

**Questions?** contact your IT admin.
