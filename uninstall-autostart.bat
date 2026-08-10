@echo off
REM ============================================================
REM  Price Check - remove auto-start (Windows)
REM  Stops the background host and removes the scheduled task
REM  created by install-autostart.bat. Your database is NOT
REM  touched - pricecheck.db stays exactly as it is.
REM ============================================================

setlocal EnableExtensions
cd /d "%~dp0"

net session >nul 2>nul
if %errorlevel% neq 0 (
  echo Requesting administrator rights...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0autostart.ps1" -Action remove

echo.
pause
