@echo off
rem © Mayanktaker Computers & Web Development | https://mayanktaker.com
title Windows Gaming Setup - Run as Administrator
cd /d "%~dp0"

rem Ask for administrator rights once, at the very start.
net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo   Administrator rights are required.
  echo   Please click YES on the UAC prompt...
  echo.
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo.
echo   ======================================================================
echo     Windows Gaming Setup
echo     Created by Mayanktaker Computers ^& Web Development
echo     https://mayanktaker.com
echo   ======================================================================
echo.
echo   Windows Gaming Setup is starting...
echo   A coloured log will be printed below.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Win11-Gaming-Setup.ps1" -ElevatedChild -NoPause

echo.
echo   Finished. Check the logs in:
echo   C:\ProgramData\Win11GamingSetup\logs
echo   logs.txt (in this folder and in C:\ProgramData\Win11GamingSetup)
echo.
echo   Website: https://mayanktaker.com
echo   ☕ Fuel Mayank with coffee: https://buymeacoffee.com/mayanktaker
echo.
pause
