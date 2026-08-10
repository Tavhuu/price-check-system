@echo off
REM ============================================================
REM  Price Check - optional nightly PC restart (Windows)
REM  Run ONCE to make the PC reboot itself every night, which
REM  keeps a shop machine healthy on long uptimes. The host
REM  starts again by itself on boot (install-autostart.bat).
REM
REM  Default time is 04:00. Change REBOOTTIME below if needed.
REM  To undo, run this file and choose R, or:
REM      schtasks /delete /tn "PriceCheckNightlyReboot" /f
REM
REM  NOTE: this does NOT make the PC power itself back on after
REM  a power cut - that is a BIOS/UEFI setting. See the README.
REM ============================================================

setlocal EnableExtensions

set "TASKNAME=PriceCheckNightlyReboot"
set "REBOOTTIME=04:00"

net session >nul 2>nul
if %errorlevel% neq 0 (
  echo Requesting administrator rights...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

echo.
echo   Nightly restart at %REBOOTTIME%
echo.
echo     [I] Install / update it
echo     [R] Remove it
echo     [Q] Quit
echo.
choice /c IRQ /n /m "Choose I, R or Q: "
if errorlevel 3 exit /b
if errorlevel 2 goto remove

REM --- Install ---
schtasks /create /tn "%TASKNAME%" /tr "shutdown.exe /r /f /t 60 /c \"Nightly restart\"" ^
  /sc daily /st %REBOOTTIME% /ru SYSTEM /rl HIGHEST /f >nul 2>&1
if %errorlevel% neq 0 (
  echo.
  echo   Could not create the task:
  schtasks /create /tn "%TASKNAME%" /tr "shutdown.exe /r /f /t 60 /c \"Nightly restart\"" ^
    /sc daily /st %REBOOTTIME% /ru SYSTEM /rl HIGHEST /f
  echo.
  pause
  exit /b
)
echo.
echo   Done. The PC will restart daily at %REBOOTTIME%
echo   ^(a 60-second warning is shown first, so anyone still using
echo    it can cancel with:  shutdown /a^).
echo.
pause
exit /b

:remove
schtasks /delete /tn "%TASKNAME%" /f >nul 2>nul
if %errorlevel% neq 0 (
  echo.
  echo   No nightly restart task was scheduled.
) else (
  echo.
  echo   Removed. The PC will no longer restart on a schedule.
)
echo.
pause
