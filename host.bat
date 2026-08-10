@echo off
REM ============================================================
REM  Price Check - HOST (Windows)
REM  Run this on the shop PC. It hosts the shared product
REM  database and serves the app to tablets/phones on the same
REM  Wi-Fi, like a POS system.
REM
REM  The window shows two addresses:
REM     On this PC:     http://localhost:8000/
REM     On the tablet:  http://192.168.x.x:8000/   <-- type this on the tablet
REM
REM  The server RESTARTS automatically if it ever stops.
REM  Keep this window open. Press Ctrl+C twice to stop.
REM
REM  First time only: run allow-firewall.bat so tablets can connect.
REM ============================================================

setlocal EnableExtensions
cd /d "%~dp0"

set "PORT=8000"
title Price Check - HOST (shared database)

REM --- server.py needs Python; it is what provides the shared database ---
set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY where python3 >nul 2>nul && set "PY=python3"

if not defined PY (
  echo.
  echo   Python is required to host the shared database.
  echo.
  echo   Install Python 3 from  https://www.python.org/downloads/
  echo   During setup, tick "Add Python to PATH", then run this file again.
  echo.
  echo   ^(Without Python the app still runs, but each device would keep its
  echo    own separate product list instead of sharing one.^)
  echo.
  pause
  exit /b
)

REM --- Is a host already running (e.g. started automatically at login)? ---
call :port_busy
if "%BUSY%"=="1" (
  echo.
  echo   Price Check is ALREADY RUNNING on this PC.
  echo   ^(It probably started automatically when you logged in.^)
  echo.
  echo   On this PC:     http://localhost:%PORT%/
  echo.
  echo   To see the tablet address, open that link and it is shown in the
  echo   Manage panel, or turn off auto-start with uninstall-autostart.bat
  echo   and run this file again.
  echo.
  pause
  exit /b
)

:loop
%PY% server.py %PORT%

REM If the port is now served by something else, another copy took over -
REM stop instead of restarting forever.
call :port_busy
if "%BUSY%"=="1" (
  echo.
  echo   Another copy of the host is now running on port %PORT%,
  echo   so this window is not needed. Closing.
  echo.
  pause
  exit /b
)

echo.
echo   [%date% %time%] Host stopped - restarting in 3 seconds...
echo   ^(Press Ctrl+C now to quit for good.^)
timeout /t 3 /nobreak >nul
goto loop

REM ------------------------------------------------------------
REM Sets BUSY=1 when something is already answering on %PORT%.
:port_busy
set "BUSY=0"
for /f %%R in ('powershell -NoProfile -Command ^
  "try{(Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri 'http://localhost:%PORT%/api/rev')^|Out-Null;'1'}catch{'0'}" 2^>nul') do set "BUSY=%%R"
exit /b
