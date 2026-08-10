@echo off
REM ============================================================
REM  Price Check - install auto-start (Windows)
REM  Run this ONCE on the HOST PC (approve the admin prompt).
REM
REM  Creates a scheduled task so the price-check host starts
REM  automatically when the PC BOOTS - before anyone logs in.
REM  That means after a restart or a power outage the tablets
REM  work again by themselves, with nobody touching the PC.
REM
REM  It also restarts the host automatically if it ever crashes.
REM
REM  To undo, run uninstall-autostart.bat.
REM ============================================================

setlocal EnableExtensions
cd /d "%~dp0"

set "TASKNAME=PriceCheckHost"
set "XML=%TEMP%\pricecheck_task.xml"

REM --- Make sure we are running as administrator ---
net session >nul 2>nul
if %errorlevel% neq 0 (
  echo Requesting administrator rights...
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)

REM --- Locate Python and bake the full path into the task.
REM     The task runs as SYSTEM, which may not share your PATH. ---
set "PYEXE="
for /f "delims=" %%I in ('where py 2^>nul') do if not defined PYEXE set "PYEXE=%%I"
if not defined PYEXE for /f "delims=" %%I in ('where python 2^>nul') do if not defined PYEXE set "PYEXE=%%I"
if not defined PYEXE for /f "delims=" %%I in ('where python3 2^>nul') do if not defined PYEXE set "PYEXE=%%I"

if not defined PYEXE (
  echo.
  echo   Python was not found. Install Python 3 first:
  echo       https://www.python.org/downloads/
  echo   Tick "Add Python to PATH" during setup, then run this again.
  echo.
  pause
  exit /b
)

set "ARGS=&quot;%~dp0server.py&quot;"
if /i "%PYEXE:~-6%"=="py.exe" set "ARGS=-3 &quot;%~dp0server.py&quot;"

echo   Using Python: %PYEXE%
echo   Creating scheduled task "%TASKNAME%"...

REM --- Build the task definition ---
> "%XML%" echo ^<?xml version="1.0" encoding="UTF-16"?^>
>>"%XML%" echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
>>"%XML%" echo   ^<RegistrationInfo^>^<Description^>Price Check host (shared product database for tablets)^</Description^>^</RegistrationInfo^>
>>"%XML%" echo   ^<Triggers^>^<BootTrigger^>^<Enabled^>true^</Enabled^>^<Delay^>PT30S^</Delay^>^</BootTrigger^>^</Triggers^>
>>"%XML%" echo   ^<Principals^>^<Principal id="Author"^>^<UserId^>S-1-5-18^</UserId^>^<RunLevel^>HighestAvailable^</RunLevel^>^</Principal^>^</Principals^>
>>"%XML%" echo   ^<Settings^>
>>"%XML%" echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
>>"%XML%" echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
>>"%XML%" echo     ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
>>"%XML%" echo     ^<AllowHardTerminate^>true^</AllowHardTerminate^>
>>"%XML%" echo     ^<StartWhenAvailable^>true^</StartWhenAvailable^>
>>"%XML%" echo     ^<RunOnlyIfNetworkAvailable^>false^</RunOnlyIfNetworkAvailable^>
>>"%XML%" echo     ^<Enabled^>true^</Enabled^>
>>"%XML%" echo     ^<Hidden^>false^</Hidden^>
>>"%XML%" echo     ^<RunOnlyIfIdle^>false^</RunOnlyIfIdle^>
>>"%XML%" echo     ^<WakeToRun^>false^</WakeToRun^>
>>"%XML%" echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
>>"%XML%" echo     ^<Priority^>7^</Priority^>
>>"%XML%" echo     ^<RestartOnFailure^>^<Interval^>PT1M^</Interval^>^<Count^>999^</Count^>^</RestartOnFailure^>
>>"%XML%" echo   ^</Settings^>
>>"%XML%" echo   ^<Actions Context="Author"^>
>>"%XML%" echo     ^<Exec^>
>>"%XML%" echo       ^<Command^>%PYEXE%^</Command^>
>>"%XML%" echo       ^<Arguments^>%ARGS%^</Arguments^>
>>"%XML%" echo       ^<WorkingDirectory^>%~dp0^</WorkingDirectory^>
>>"%XML%" echo     ^</Exec^>
>>"%XML%" echo   ^</Actions^>
>>"%XML%" echo ^</Task^>

schtasks /create /tn "%TASKNAME%" /xml "%XML%" /f >nul 2>&1
if %errorlevel% neq 0 (
  echo.
  echo   Could not create the scheduled task. Showing the error:
  echo.
  schtasks /create /tn "%TASKNAME%" /xml "%XML%" /f
  del "%XML%" >nul 2>nul
  echo.
  pause
  exit /b
)
del "%XML%" >nul 2>nul

REM --- Start it now so you do not have to reboot to test ---
schtasks /run /tn "%TASKNAME%" >nul 2>nul

echo.
echo   Done. The price-check host now starts automatically at boot,
echo   and restarts itself if it stops.
echo.
echo   It is running now too - open the tablet address to check.
echo   ^(Run host.bat if you want to SEE the server window and the
echo    tablet address; it will say the port is in use, which just
echo    means the background one is already running.^)
echo.
echo   IMPORTANT - so the PC itself comes back on after a power cut,
echo   you must also turn on the BIOS/UEFI setting usually called
echo   "Restore on AC Power Loss" or "AC Power Recovery" and set it
echo   to "Power On". No software can do that part.
echo.
pause
