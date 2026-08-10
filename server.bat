@echo off
REM ============================================================
REM  Price Check - local server launcher (Windows)
REM  Double-click this file to run the price checker on this PC.
REM  It serves this folder over http://localhost:8000/ and opens
REM  your browser. Keep this window open while using the app;
REM  close it (or press Ctrl+C) to stop the server.
REM ============================================================

setlocal EnableExtensions
cd /d "%~dp0"

set "PORT=8000"
REM Friendly hostname (set up once with set-hostname.bat). If it isn't
REM configured in the Windows hosts file yet, we fall back to localhost.
set "HOSTNAME=pricecheck.local"
set "OPENHOST=localhost"
ping -n 1 %HOSTNAME% >nul 2>nul && set "OPENHOST=%HOSTNAME%"
set "URL=http://%OPENHOST%:%PORT%/"
title Price Check - local server

REM --- Prefer server.py: it adds the shared database used by tablets ---
where py >nul 2>nul        && (set "CMD=py -3 server.py %PORT%"                & goto run)
where python >nul 2>nul    && (set "CMD=python server.py %PORT%"               & goto run)
where python3 >nul 2>nul   && (set "CMD=python3 server.py %PORT%"              & goto run)

REM --- No Python: still works, but each device keeps its own separate list ---
echo.
echo   NOTE: Python was not found, so the shared database is unavailable.
echo   The app will run, but every device keeps its OWN product list.
echo   Install Python 3 and re-run this to share one database.
echo.
where php >nul 2>nul        && (set "CMD=php -S localhost:%PORT%"               & goto run)
where npx >nul 2>nul        && (set "CMD=npx --yes http-server -p %PORT% -c-1 ." & goto run)

echo.
echo   Could not find Python, PHP, or Node to run a local web server.
echo.
echo   Easiest fix: install Python 3 from
echo       https://www.python.org/downloads/
echo   During setup, tick "Add Python to PATH", then run this file again.
echo.
pause
goto :eof

:run
echo.
echo   Starting Price Check at %URL%
echo   Leave this window open while you use the app.
echo   Close this window (or press Ctrl+C) to stop the server.
echo.

REM Open the browser a moment after the server starts (parallel, no extra window).
start "" /b cmd /c "ping -n 2 127.0.0.1 >nul & start %URL%"

%CMD%

REM If the server exits (e.g. port already in use), pause so the message is readable.
echo.
echo   Server stopped. If it failed to start, port %PORT% may already be in use.
pause
