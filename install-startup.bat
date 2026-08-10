@echo off
REM ============================================================
REM  Price Check - install auto-start (Windows)
REM  Run this ONCE. It makes the kiosk (kiosk.bat) launch
REM  automatically every time you log in to Windows, so the
REM  price checker behaves like an always-on POS terminal.
REM
REM  No admin rights needed (installs for the current user).
REM  To undo, run uninstall-startup.bat.
REM ============================================================

setlocal EnableExtensions
cd /d "%~dp0"

set "TARGET=%~dp0kiosk.bat"
set "WORKDIR=%~dp0"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "LINK=%STARTUP%\Price Check Kiosk.lnk"

powershell -NoProfile -Command ^
  "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%LINK%');" ^
  "$s.TargetPath='%TARGET%';" ^
  "$s.WorkingDirectory='%WORKDIR%';" ^
  "$s.WindowStyle=7;" ^
  "$s.Description='Price Check kiosk (POS mode)';" ^
  "$s.Save()"

if exist "%LINK%" (
  echo.
  echo   Installed. The kiosk will start automatically when you log in.
  echo   Shortcut: %LINK%
  echo.
  echo   Start it now without rebooting? Close this and double-click kiosk.bat.
) else (
  echo.
  echo   Something went wrong creating the startup shortcut.
)
echo.
pause
