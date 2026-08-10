@echo off
title Price Check - Enable Auto-Start
cd /d "%~dp0"

REM ============================================================
REM  Price Check - enable auto-start (Windows)
REM
REM  Makes the host start automatically every time you log in.
REM  Registers the launcher under the per-user "Run" key, so NO
REM  administrator rights are needed and it runs as you - which
REM  matters when the folder lives on your Desktop and Python is
REM  installed for your account only.
REM
REM  Double-click this file once.
REM  To turn it off later: uninstall-autostart.bat
REM ============================================================

setlocal EnableExtensions

set "NAME=PriceCheckHost"

REM --- Find the launcher. host.bat is the normal name; run_server.bat is
REM     accepted too in case the file was renamed. ---
set "TARGET="
if exist "%~dp0host.bat"       set "TARGET=%~dp0host.bat"
if not defined TARGET if exist "%~dp0run_server.bat" set "TARGET=%~dp0run_server.bat"

if not defined TARGET (
  echo.
  echo   Could not find host.bat in this folder:
  echo       %~dp0
  echo.
  echo   Keep this file in the SAME folder as host.bat and server.py,
  echo   then run it again.
  echo.
  pause
  exit /b
)

if not exist "%~dp0server.py" (
  echo.
  echo   WARNING: server.py is not in this folder. Auto-start will be
  echo   registered, but the host will not run until all the files are
  echo   together in one folder.
  echo.
)

echo.
echo   Registering Price Check to start automatically at login...
echo.
echo   Will launch: %TARGET%
echo.

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "%NAME%" /t REG_SZ /d "\"%TARGET%\"" /f >nul 2>&1

REM --- Clean up anything left by earlier versions of this installer.
REM     Two auto-start methods at once would fight over the port. ---
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Price Check Host.lnk" >nul 2>&1
schtasks /query /tn "%NAME%" >nul 2>&1
if not errorlevel 1 (
  echo   Removing the older "before login" scheduled task...
  schtasks /end    /tn "%NAME%" >nul 2>&1
  schtasks /delete /tn "%NAME%" /f  >nul 2>&1
  schtasks /query  /tn "%NAME%" >nul 2>&1
  if not errorlevel 1 (
    echo.
    echo   NOTE: that task could not be removed without administrator rights.
    echo   Please run uninstall-autostart.bat as administrator first, then
    echo   run this file again - otherwise two copies of the host would try
    echo   to use the same port.
    echo.
  )
)

echo   Verifying the registration...
echo.
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "%NAME%"
if errorlevel 1 goto failed

echo.
echo   ====================================================
echo    DONE. Price Check will start by itself the next
echo    time you log in to Windows.
echo.
echo    TEST IT NOW: sign out and back in (or restart).
echo    The server window should open on its own, showing
echo    the address to type on the tablet.
echo.
echo    To turn it off later: uninstall-autostart.bat
echo   ====================================================
echo.
echo   NOTE: this starts after you LOG IN. So the shop recovers
echo   from a power cut on its own, also turn on:
echo     1. BIOS/UEFI "Restore on AC Power Loss" = Power On
echo     2. Windows automatic sign-in
echo   Or run install-autostart-boot.bat, which starts the host
echo   before anyone logs in (needs administrator).
echo.
goto end

:failed
echo.
echo   ====================================================
echo    FAILED - auto-start was NOT registered.
echo    Try right-clicking this file and choosing
echo    "Run as administrator", then run it again.
echo   ====================================================

:end
echo.
pause
