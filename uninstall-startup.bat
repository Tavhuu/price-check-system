@echo off
REM ============================================================
REM  Price Check - remove auto-start (Windows)
REM  Undoes install-startup.bat so the kiosk no longer launches
REM  automatically at login. Does not delete any app files.
REM ============================================================

setlocal EnableExtensions
set "LINK=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Price Check Kiosk.lnk"

if exist "%LINK%" (
  del "%LINK%"
  echo.
  echo   Removed the auto-start shortcut. The kiosk will no longer
  echo   launch automatically at login.
) else (
  echo.
  echo   No auto-start shortcut found - nothing to remove.
)
echo.
pause
