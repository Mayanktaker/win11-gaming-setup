@echo off
rem © Mayanktaker Computers & Web Development | https://mayanktaker.com
setlocal EnableDelayedExpansion

title Windows Gaming Setup - View Logs

echo.
echo   ======================================================================
echo     Windows Gaming Setup - View Logs
echo     Created by Mayanktaker Computers ^& Web Development
echo     https://mayanktaker.com
echo   ======================================================================
echo.

set "LOGFILE="

if exist "%~dp0logs.txt" (
  set "LOGFILE=%~dp0logs.txt"
) else if exist "%ProgramData%\Win11GamingSetup\logs.txt" (
  set "LOGFILE=%ProgramData%\Win11GamingSetup\logs.txt"
) else (
  for /f "delims=" %%F in ('dir /b /o-d "%ProgramData%\Win11GamingSetup\logs\setup-*.log" 2^>nul') do (
    if not defined LOGFILE set "LOGFILE=%ProgramData%\Win11GamingSetup\logs\%%F"
  )
)

if defined LOGFILE (
  echo   Found log file:
  echo   !LOGFILE!
  echo.
  echo   Opening in Notepad...
  start notepad.exe "!LOGFILE!"
) else (
  echo   No log files found yet.
  echo   Run RUN-AS-ADMIN.cmd first to perform setup and generate logs.
  echo.
)

echo.
echo   Website: https://mayanktaker.com
echo   ☕ Fuel Mayank with coffee: https://buymeacoffee.com/mayanktaker
echo.
pause
