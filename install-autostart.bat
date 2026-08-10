@echo off
REM ============================================================
REM  Price Check - install auto-start (Windows)
REM  Run this ONCE on the HOST PC and approve the admin prompt.
REM
REM  The host will then start automatically when the PC BOOTS -
REM  before anyone logs in - so after a restart or a power cut
REM  the tablets work again without anyone touching the PC.
REM  It also restarts itself if it ever stops.
REM
REM  This checks that it really works and tells you if not.
REM  To undo, run uninstall-autostart.bat.
REM ============================================================

setlocal EnableExtensions
cd /d "%~dp0"

REM --- Re-launch as administrator if we are not already ---
net session >nul 2>nul
if %errorlevel% neq 0 (
  echo Requesting administrator rights...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0autostart.ps1" -Action install

echo.
echo   IMPORTANT - so the PC itself powers back on after a power cut,
echo   you must also enable the BIOS/UEFI setting usually called
echo   "Restore on AC Power Loss" or "AC Power Recovery" and set it
echo   to "Power On". No software can do that part.
echo.
pause
