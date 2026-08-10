@echo off
REM ============================================================
REM  Price Check - remove auto-start (Windows)
REM  Stops the background host and removes the scheduled task
REM  created by install-autostart.bat. Your database is NOT
REM  touched - pricecheck.db stays exactly as it is.
REM ============================================================

setlocal EnableExtensions
set "TASKNAME=PriceCheckHost"

net session >nul 2>nul
if %errorlevel% neq 0 (
  echo Requesting administrator rights...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

schtasks /query /tn "%TASKNAME%" >nul 2>nul
if %errorlevel% neq 0 (
  echo.
  echo   No auto-start task found - nothing to remove.
  echo.
  pause
  exit /b
)

schtasks /end    /tn "%TASKNAME%" >nul 2>nul
schtasks /delete /tn "%TASKNAME%" /f >nul 2>nul

echo.
echo   Removed. The host no longer starts automatically.
echo   Start it manually any time with host.bat.
echo   Your database (pricecheck.db) was not touched.
echo.
pause
