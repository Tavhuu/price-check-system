@echo off
title Price Check - Auto-Start Before Login
cd /d "%~dp0"

REM ============================================================
REM  Price Check - start the host BEFORE anyone logs in.
REM
REM  Use this only if you want the shop to recover from a power
REM  cut with nobody signing in to Windows. It needs
REM  administrator rights and runs the host as the SYSTEM
REM  account, which does NOT work if Python was installed "for
REM  me only" - install Python for all users first.
REM
REM  For most setups install-autostart.bat is the easier choice.
REM  To turn either off: uninstall-autostart.bat
REM ============================================================

setlocal EnableExtensions

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
