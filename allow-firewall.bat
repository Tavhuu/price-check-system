@echo off
REM ============================================================
REM  Price Check - allow tablets to connect (Windows Firewall)
REM  Run this ONCE on the HOST PC (approve the admin prompt).
REM  It opens the port so tablets and phones on the same Wi-Fi
REM  can reach the price checker running on this PC.
REM
REM  To undo:  netsh advfirewall firewall delete rule name="Price Check"
REM ============================================================

setlocal EnableExtensions
set "PORT=8000"
set "RULE=Price Check"

REM --- Make sure we are running as administrator ---
net session >nul 2>nul
if %errorlevel% neq 0 (
  echo Requesting administrator rights...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

REM --- Remove any previous copy so re-running stays clean ---
netsh advfirewall firewall delete rule name="%RULE%" >nul 2>nul

netsh advfirewall firewall add rule name="%RULE%" dir=in action=allow protocol=TCP localport=%PORT% profile=private,domain
if %errorlevel% neq 0 (
  echo.
  echo   Could not add the firewall rule. Make sure this ran as administrator.
  echo.
  pause
  exit /b
)

echo.
echo   Done. Tablets on the same Wi-Fi can now reach this PC on port %PORT%.
echo.
echo   Note: this allows PRIVATE (home/work) networks only, not public Wi-Fi.
echo   Make sure Windows treats your shop Wi-Fi as a Private network.
echo.
echo   Next: run host.bat, then type the "On the tablet" address it shows
echo   into the tablet's browser.
echo.
pause
