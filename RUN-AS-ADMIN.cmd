@echo off
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
echo   Windows Gaming Setup is starting...
echo   A coloured log will be printed below.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Win11-Gaming-Setup.ps1" -ElevatedChild -NoPause

echo.
echo   Finished. Check the log in:
echo   C:\ProgramData\Win11GamingSetup\logs
echo.
pause
