@echo off
REM ============================================================
REM  Price Check - friendly hostname setup (Windows)
REM  Run this ONCE (right-click > Run as administrator, or just
REM  double-click and approve the prompt). It adds a line to the
REM  Windows hosts file so http://pricecheck.local:8000/ opens
REM  the kiosk on this PC. After this, just use server.bat.
REM
REM  To change the name, edit HOSTNAME below before running.
REM  To undo, remove the "pricecheck.local" line from:
REM    C:\Windows\System32\drivers\etc\hosts
REM ============================================================

setlocal EnableExtensions
set "HOSTNAME=pricecheck.local"

REM --- Make sure we are running as administrator ---
net session >nul 2>nul
if %errorlevel% neq 0 (
  echo Requesting administrator rights...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

set "HOSTS=%SystemRoot%\System32\drivers\etc\hosts"

REM --- Already present? ---
findstr /i /c:"%HOSTNAME%" "%HOSTS%" >nul 2>nul
if %errorlevel%==0 (
  echo.
  echo   "%HOSTNAME%" is already in the hosts file. Nothing to do.
  echo   Open the kiosk with server.bat, then visit:
  echo       http://%HOSTNAME%:8000/
  echo.
  pause
  exit /b
)

REM --- Add the entry (blank line first, in case the file has no trailing newline) ---
>>"%HOSTS%" echo.
>>"%HOSTS%" echo 127.0.0.1    %HOSTNAME%
if %errorlevel% neq 0 (
  echo.
  echo   Could not write to the hosts file. Make sure this ran as administrator.
  echo.
  pause
  exit /b
)

ipconfig /flushdns >nul 2>nul

echo.
echo   Done. Added:  127.0.0.1    %HOSTNAME%
echo.
echo   Now run server.bat and open:
echo       http://%HOSTNAME%:8000/
echo.
pause
