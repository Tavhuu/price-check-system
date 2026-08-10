<#
  Price Check - auto-start installer.

  Registers a scheduled task so the host starts automatically when the PC
  boots (before anyone logs in), and restarts itself if it stops. Run it
  through install-autostart.bat / uninstall-autostart.bat, which handle the
  administrator prompt for you.

  Usage:
      powershell -ExecutionPolicy Bypass -File autostart.ps1 -Action install
      powershell -ExecutionPolicy Bypass -File autostart.ps1 -Action remove
#>

param(
    [ValidateSet('install', 'remove', 'startup')]
    [string]$Action = 'install',
    [int]$Port = 8000
)

$ErrorActionPreference = 'Stop'
$TaskName = 'PriceCheckHost'
$here     = Split-Path -Parent $MyInvocation.MyCommand.Path
$script   = Join-Path $here 'server.py'

function Say($msg)  { Write-Host "  $msg" }
function Fail($msg) { Write-Host ""; Write-Host "  ERROR: $msg" -ForegroundColor Red; Write-Host "" }
function Ok($msg)   { Write-Host "  $msg" -ForegroundColor Green }

function Test-Host-Responding {
    try {
        Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 `
            -Uri "http://localhost:$Port/api/rev" | Out-Null
        return $true
    } catch { return $false }
}

# Simpler fallback: a shortcut in the Startup folder. Needs no administrator
# and works on any Windows, but only runs once somebody logs in.
function Install-StartupShortcut {
    $startup = [Environment]::GetFolderPath('Startup')
    if ([string]::IsNullOrEmpty($startup)) {
        Fail "Could not locate your Startup folder."
        Say "Press Win+R, type shell:startup, and drop a shortcut to host.bat there."
        return $false
    }
    $link    = Join-Path $startup 'Price Check Host.lnk'
    $target  = Join-Path $here 'host.bat'
    if (-not (Test-Path $target)) { Fail "host.bat not found next to this script."; return $false }
    try {
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($link)
        $sc.TargetPath       = $target
        $sc.WorkingDirectory = $here
        $sc.WindowStyle      = 7          # start minimised
        $sc.Description      = 'Price Check host'
        $sc.Save()
    } catch {
        Fail "Could not create the Startup shortcut: $($_.Exception.Message)"
        return $false
    }
    Ok "Startup shortcut created:"
    Say "  $link"
    Say ""
    Say "The host will start when you log in to Windows."
    Say "For it to come back on its own after a power cut, Windows must also"
    Say "log in automatically (search Settings for 'automatic sign-in'), or use"
    Say "the scheduled-task method which does not need a login."
    return $true
}

if ($Action -eq 'startup') {
    Say "Installing the simple Startup-folder method..."
    Say ""
    Install-StartupShortcut | Out-Null
    Say ""
    return
}

# The ScheduledTasks module ships with Windows 8 / Server 2012 and later.
if (-not (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)) {
    Fail "This version of Windows does not provide the scheduled-task commands."
    if ($Action -eq 'install') {
        Say "Falling back to the simpler Startup-folder method..."
        Say ""
        Install-StartupShortcut | Out-Null
    } else {
        Say "Nothing to remove."
    }
    Say ""
    return
}

# ---------------------------------------------------------------- remove ---
if ($Action -eq 'remove') {
    try {
        $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $existing) {
            Say "No auto-start task found - nothing to remove."
        } else {
            try { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue } catch {}
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Ok "Removed. The host no longer starts automatically."
            Say "Start it manually any time with host.bat."
        }
    } catch {
        Fail "Could not remove the task: $($_.Exception.Message)"
        Say "Make sure you ran uninstall-autostart.bat (it asks for administrator)."
        return
    }
    # Also clear the Startup shortcut, if the fallback method was used.
    $startupDir = [Environment]::GetFolderPath('Startup')
    $link = if ([string]::IsNullOrEmpty($startupDir)) { $null }
            else { Join-Path $startupDir 'Price Check Host.lnk' }
    if ($link -and (Test-Path $link)) {
        Remove-Item $link -Force -ErrorAction SilentlyContinue
        Ok "Startup shortcut removed too."
    }
    Say "Your database (pricecheck.db) was not touched."
    return
}

# --------------------------------------------------------------- install ---
Say "Installing auto-start for the Price Check host..."
Say ""

if (-not (Test-Path $script)) {
    Fail "server.py was not found next to this script ($here). Keep all the files together."
    return
}

# 1. Find Python. The task runs as SYSTEM, which does not share your PATH,
#    so we record the full path to the executable.
$pyCmd = Get-Command python.exe -ErrorAction SilentlyContinue
if (-not $pyCmd) { $pyCmd = Get-Command py.exe -ErrorAction SilentlyContinue }
if (-not $pyCmd) {
    Fail "Python was not found."
    Say "Install Python 3 from https://www.python.org/downloads/"
    Say "and tick 'Add Python to PATH' during setup, then run this again."
    return
}
$pyExe = $pyCmd.Source
Say "Python:   $pyExe"
Say "Server:   $script"

# 2. A per-user Python install lives under C:\Users\... and the SYSTEM account
#    usually cannot run it. Catch that now rather than after a failed reboot.
$perUser = ($env:LOCALAPPDATA -and $pyExe -like "$env:LOCALAPPDATA*") -or $pyExe -like 'C:\Users\*'
if ($perUser) {
    Say ""
    Say "NOTE: this Python is installed for your user account only."
    Say "      If the check below fails, reinstall Python with"
    Say "      'Install for all users' ticked, then run this again."
}

# 3. If something is already serving the port, the task would fail to bind.
if (Test-Host-Responding) {
    Say ""
    Say "A host is already running on port $Port."
    Say "Close that window (host.bat) first, then run this again,"
    Say "so the check below tests the scheduled task itself."
    return
}

# 4. Register the task: at boot, as SYSTEM, no time limit, restart on failure.
try {
    $action  = New-ScheduledTaskAction -Execute $pyExe `
                                       -Argument "`"$script`" $Port" `
                                       -WorkingDirectory $here
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' `
                                            -LogonType ServiceAccount `
                                            -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet `
                    -AllowStartIfOnBatteries `
                    -DontStopIfGoingOnBatteries `
                    -StartWhenAvailable `
                    -MultipleInstances IgnoreNew `
                    -ExecutionTimeLimit ([TimeSpan]::Zero) `
                    -RestartInterval (New-TimeSpan -Minutes 1) `
                    -RestartCount 999

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
                           -Principal $principal -Settings $settings `
                           -Description 'Price Check host (shared product database for tablets)' `
                           -Force | Out-Null
} catch {
    Fail "Could not create the scheduled task: $($_.Exception.Message)"
    Say "Make sure you ran install-autostart.bat (it asks for administrator)."
    return
}
Ok "Scheduled task '$TaskName' created."

# 5. Prove it actually works, instead of trusting it until the next reboot.
Say ""
Say "Starting it now to check it really works..."
try { Start-ScheduledTask -TaskName $TaskName } catch {
    Fail "The task was created but could not be started: $($_.Exception.Message)"
    return
}

$up = $false
foreach ($i in 1..15) {
    Start-Sleep -Seconds 1
    if (Test-Host-Responding) { $up = $true; break }
}

Say ""
if ($up) {
    Ok "WORKING - the host is running as a background service."
    Say ""
    Say "It will now start by itself whenever the PC boots, so the tablets"
    Say "come back on their own after a restart or a power cut."
    Say ""
    Say "Run host.bat any time you want to see the tablet address."
} else {
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    $code = if ($info) { $info.LastTaskResult } else { 'unknown' }
    Fail "The task was created but the host did not come up (last result: $code)."
    Say "Most likely causes:"
    Say "  * Python is installed for your user only - reinstall it with"
    Say "    'Install for all users' ticked."
    Say "  * Another program is using port $Port."
    Say "  * Antivirus blocked the task."
    Say ""
    Say "Check Task Scheduler (taskschd.msc) -> Task Scheduler Library ->"
    Say "'$TaskName' -> History for the exact error, and run host.bat to see"
    Say "whether the server starts normally in a window."
    Say ""
    $answer = Read-Host "  Try the simpler Startup-folder method instead? (Y/N)"
    if ($answer -match '^[Yy]') {
        Say ""
        if (Install-StartupShortcut) {
            try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false } catch {}
            Say ""
            Say "The scheduled task was removed, so only the Startup shortcut is used."
        }
    }
}
Say ""
