@echo off
title Price Check - Disable Auto-Start
cd /d "%~dp0"

REM ============================================================
REM  Price Check - turn off auto-start (Windows)
REM  Removes every auto-start method this project may have set:
REM    * the per-user "Run" registry entry
REM    * a Startup-folder shortcut
REM    * the "before login" scheduled task
REM  Your database (pricecheck.db) is NOT touched.
REM ============================================================

setlocal EnableExtensions

set "NAME=PriceCheckHost"
set "FOUND="

echo.
echo   Removing auto-start entries...
echo.

REM --- 1. Per-user Run key (no admin needed) ---
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "%NAME%" >nul 2>&1
if not errorlevel 1 (
  reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "%NAME%" /f >nul 2>&1
  echo     - removed the login auto-start.
  set "FOUND=1"
)

REM --- 2. Startup-folder shortcut from an older version ---
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Price Check Host.lnk" (
  del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Price Check Host.lnk" >nul 2>&1
  echo     - removed the Startup-folder shortcut.
  set "FOUND=1"
)

REM --- 3. Scheduled task (needs admin; ask for it only if the task exists) ---
schtasks /query /tn "%NAME%" >nul 2>&1
if not errorlevel 1 (
  net session >nul 2>nul
  if errorlevel 1 (
    echo     - a "before login" task exists; asking for administrator rights...
    powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    exit /b
  )
  schtasks /end    /tn "%NAME%" >nul 2>&1
  schtasks /delete /tn "%NAME%" /f >nul 2>&1
  echo     - removed the "before login" scheduled task.
  set "FOUND=1"
)

echo.
if defined FOUND (
  echo   Done. Price Check no longer starts by itself.
  echo   Start it manually any time with host.bat.
) else (
  echo   Nothing to remove - auto-start was not set up.
)
echo.
echo   Your database (pricecheck.db) was not touched.
echo.
pause
