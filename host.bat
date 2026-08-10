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

:loop
%PY% server.py %PORT%
echo.
echo   [%date% %time%] Host stopped - restarting in 3 seconds...
echo   ^(Press Ctrl+C now to quit for good.^)
timeout /t 3 /nobreak >nul
goto loop
