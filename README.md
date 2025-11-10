# Corporate Wallpaper Deployment for Microsoft Intune

Deploy corporate wallpapers to Windows 10/11 devices via Microsoft Intune Win32 App using Scheduled Tasks.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-lightgrey.svg)](https://www.microsoft.com/windows)

## Features

- ✅ **Automatic deployment** via Microsoft Intune
- ✅ **Scheduled Task** applies wallpaper at user logon
- ✅ **Fill mode** - covers entire screen without distortion
- ✅ **Multi-language support** - works in any Windows language (uses SIDs)
- ✅ **User-friendly** - doesn't override user's personal wallpapers permanently
- ✅ **Comprehensive logging** - detailed logs for troubleshooting
- ✅ **Easy to customize** - just replace the image file

## How It Works

1. **Intune executes script as SYSTEM**: Copies wallpaper to `C:\ProgramData\CorporateWallpapers`
2. **Creates Scheduled Task**: Configured to run at logon of any user
3. **User logs in**: Task automatically applies wallpaper in user context
4. **Wallpaper appears**: Fill style, maintains aspect ratio, no black bars

## Quick Start

### Prerequisites

- Microsoft Intune subscription
- Windows 10 version 1607 or higher / Windows 11
- Admin access to Microsoft Endpoint Manager
- [Microsoft Win32 Content Prep Tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool)

### 1. Clone Repository

```bash
git clone https://github.com/[your-username]/intune-wallpaper-deploy.git
cd intune-wallpaper-deploy
```

### 2. Add Your Wallpaper

Place your wallpaper image in the repository folder and rename it to `wallpaper.jpg`:

- **Recommended resolution**: 1920x1080 or higher
- **Supported formats**: JPG, PNG (rename to .jpg)
- **Maximum size**: 5 MB

### 3. Create Intune Package

```powershell
# Using Microsoft Win32 Content Prep Tool
.\IntuneWinAppUtil.exe -c "." -s "install.bat" -o "."
```

This creates `install.intunewin`

### 4. Upload to Intune

1. Go to [Microsoft Endpoint Manager admin center](https://endpoint.microsoft.com)
2. Navigate to **Apps** → **Windows** → **Add**
3. Select **Windows app (Win32)**
4. Upload `install.intunewin`

### 5. Configure App

| Setting | Value |
|---------|-------|
| **Install command** | `install.bat` |
| **Uninstall command** | `uninstall.bat` |
| **Install behavior** | System |
| **Detection rule** | Custom script (use `Detect-CorporateWallpaper.ps1`) |

### 6. Assign

Assign the app to device groups as **Required**.

## Files

| File | Description |
|------|-------------|
| `Install-CorporateWallpaper.ps1` | Main installation script |
| `Uninstall-CorporateWallpaper.ps1` | Uninstallation script |
| `Detect-CorporateWallpaper.ps1` | Detection script for Intune |
| `install.bat` | Batch wrapper for installation |
| `uninstall.bat` | Batch wrapper for uninstallation |
| `wallpaper.jpg` | Your corporate wallpaper (you provide this) |

## Wallpaper Style

The script configures wallpaper with **Fill** style (`WallpaperStyle = 10`):

- ✅ Covers entire screen
- ✅ Maintains aspect ratio
- ✅ No black bars
- ✅ No distortion

Other styles available (edit script if needed):
- `0` = Center
- `2` = Stretch (may distort)
- `6` = Fit (may show black bars)
- `22` = Span (multi-monitor)

## How to Verify

On a target device:

```powershell
# Check wallpaper file
Test-Path C:\ProgramData\CorporateWallpapers\wallpaper.jpg

# Check scheduled task
Get-ScheduledTask -TaskName "Apply-Corporate-Wallpaper"

# View logs
Get-Content C:\Windows\Logs\WallpaperDeploy.log -Tail 20

# Test manually
Start-ScheduledTask -TaskName "Apply-Corporate-Wallpaper"
```

## Troubleshooting

### Wallpaper doesn't appear after login

**Solution**: Log off and log back in. The scheduled task runs at user logon.

### Intune shows "Installed" but wallpaper not applied

**Check**:
1. Scheduled task exists: `Get-ScheduledTask -TaskName "Apply-Corporate-Wallpaper"`
2. File exists: `Test-Path C:\ProgramData\CorporateWallpapers\wallpaper.jpg`
3. Run task manually: `Start-ScheduledTask -TaskName "Apply-Corporate-Wallpaper"`

### Installation failed

**Review logs**:
- Intune logs: `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AgentExecutor.log`
- Script logs: `C:\Windows\Logs\WallpaperDeploy.log`

### Intune takes too long to deploy

**This is normal**:
- First deployment: 30-60 minutes
- Subsequent updates: 15-45 minutes
- Multiple edits: Longer due to throttling

**Workaround**: Test installation locally first:
```powershell
# As Administrator
cd C:\path\to\files
.\install.bat
```

## Customization

### Change Wallpaper Folder

Edit `Install-CorporateWallpaper.ps1`, line 34:

```powershell
$destinationFolder = "C:\YourCompany\Wallpapers"
```

### Change Task Name

Edit `Install-CorporateWallpaper.ps1`, line 37:

```powershell
$taskName = "Your-Custom-Task-Name"
```

### Change Wallpaper Style

Edit `Install-CorporateWallpaper.ps1`, find the user script section and modify:

```powershell
Set-ItemProperty -Path $regPath -Name "WallpaperStyle" -Value "10" -Force
```

## Architecture

```
┌─────────────────┐
│  Intune Portal  │
└────────┬────────┘
         │ Deploys Win32 App
         ▼
┌─────────────────────────┐
│  Device (SYSTEM context)│
│  - Copies wallpaper.jpg │
│  - Creates user script  │
│  - Creates sched. task  │
└────────┬────────────────┘
         │ At user logon
         ▼
┌──────────────────────────┐
│  User Context            │
│  - Configures registry   │
│  - Applies via Win32 API │
│  - Wallpaper appears     │
└──────────────────────────┘
```

## Logs

All operations are logged to `C:\Windows\Logs\WallpaperDeploy.log`

**Example successful log**:

```
[2025-11-08 20:49:42] [INFO] ========================================
[2025-11-08 20:49:42] [INFO] Corporate Wallpaper Deployment Started
[2025-11-08 20:49:42] [SUCCESS] Wallpaper copied successfully (3.01 MB)
[2025-11-08 20:49:42] [INFO] Permissions configured
[2025-11-08 20:49:42] [SUCCESS] User script created
[2025-11-08 20:49:42] [SUCCESS] Scheduled task created
[2025-11-08 20:49:42] [SUCCESS] Task verified - State: Ready
[2025-11-08 20:49:42] [SUCCESS] Task executed for current users
[2025-11-08 20:49:42] [SUCCESS] Deployment completed successfully!
[2025-11-08 20:49:45] [USER:Andre] Applying corporate wallpaper...
[2025-11-08 20:49:45] [USER:Andre] Registry configured
[2025-11-08 20:49:45] [USER:Andre] Wallpaper applied successfully
```

## Requirements

- **Operating System**: Windows 10 1607+ or Windows 11
- **Intune License**: Microsoft Intune subscription
- **PowerShell**: Version 5.1 or higher
- **Windows Edition**: Windows 10/11 Pro, Enterprise, or Education (Home not supported)

## License

MIT License - see [LICENSE](LICENSE) file for details

## Author

**Andre Costa**

## Acknowledgments

- Inspired by enterprise deployment best practices
- Built for Microsoft Intune ecosystem
- Tested on Windows 10/11 environments

## Changelog

### Version 1.0.0 (2025-11-08)

- ✅ Initial release
- ✅ Scheduled task-based deployment
- ✅ Multi-language support using SIDs
- ✅ Fill wallpaper style
- ✅ Comprehensive logging
- ✅ Support for current and future users

