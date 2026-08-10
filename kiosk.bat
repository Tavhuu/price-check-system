@echo off
REM ============================================================
REM  Price Check - KIOSK / POS mode (Windows)
REM  Runs the app like a point-of-sale terminal:
REM    * starts the local server and RESTARTS it if it ever stops
REM    * opens the browser FULLSCREEN (Chrome/Edge --kiosk)
REM    * REOPENS the browser automatically if it gets closed
REM
REM  Double-click to start. To auto-start at login, run
REM  install-startup.bat once.
REM
REM  To STOP the kiosk:
REM    * press Alt+F4 to close the fullscreen browser, then
REM    * close the small minimized "Price Check Server" window.
REM ============================================================

setlocal EnableExtensions
cd /d "%~dp0"

set "PORT=8000"
set "HOSTNAME=pricecheck.local"
set "KPROFILE=%LOCALAPPDATA%\PriceCheckKiosk"

REM Second entry point: run the self-restarting server loop.
if /i "%~1"=="server" goto serverloop

REM --- Decide which URL to open (friendly hostname if configured) ---
set "OPENHOST=localhost"
ping -n 1 %HOSTNAME% >nul 2>nul && set "OPENHOST=%HOSTNAME%"
set "URL=http://%OPENHOST%:%PORT%/"
title Price Check - KIOSK

REM --- Make sure a server engine exists before we start ---
call :find_server
if not defined SRV (
  echo.
  echo   Could not find Python, PHP, or Node to run the local server.
  echo   Install Python 3 from https://www.python.org/downloads/
  echo   ^(tick "Add Python to PATH"^), then run this again.
  echo.
  pause
  goto :eof
)

REM --- Start the self-restarting server in its own minimized window ---
start "Price Check Server" /min cmd /c ""%~f0" server"

REM --- Give the server a moment to come up ---
timeout /t 3 /nobreak >nul

REM --- Find a browser that supports kiosk (fullscreen) mode ---
call :find_browser
if not defined BROWSER (
  echo   No Chrome or Edge found; opening your default browser instead.
  echo   The server keeps running in the minimized window.
  start "" "%URL%"
  goto :eof
)

REM --- Browser watchdog: keep the fullscreen kiosk open ---
:browserloop
start "" /wait "%BROWSER%" --kiosk --no-first-run --disable-pinch --overscroll-history-navigation=0 --user-data-dir="%KPROFILE%" "%URL%"
echo Browser closed - reopening in 2s...  (close this window to stop the watchdog)
timeout /t 2 /nobreak >nul
goto browserloop

REM ------------------------------------------------------------
:serverloop
call :find_server
title Price Check Server (auto-restart)
:runserver
%SRV%
echo [%date% %time%] server stopped - restarting in 3s...
timeout /t 3 /nobreak >nul
goto runserver

REM ------------------------------------------------------------
:find_server
set "SRV="
where py >nul 2>nul && set "SRV=py -3 -m http.server %PORT%"
if defined SRV exit /b
where python >nul 2>nul && set "SRV=python -m http.server %PORT%"
if defined SRV exit /b
where python3 >nul 2>nul && set "SRV=python3 -m http.server %PORT%"
if defined SRV exit /b
where php >nul 2>nul && set "SRV=php -S localhost:%PORT%"
if defined SRV exit /b
where npx >nul 2>nul && set "SRV=npx --yes http-server -p %PORT% -c-1 ."
exit /b

REM ------------------------------------------------------------
:find_browser
set "BROWSER="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "BROWSER=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined BROWSER if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "BROWSER=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined BROWSER if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "BROWSER=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if not defined BROWSER if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set "BROWSER=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not defined BROWSER if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set "BROWSER=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
exit /b
