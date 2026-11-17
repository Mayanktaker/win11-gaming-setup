@echo off
rem © Mayanktaker Computers & Web Development | https://mayanktaker.com
title Windows Gaming Setup - Revert as Administrator
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
echo   Reverting Windows Gaming Setup changes...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Revert.ps1"

echo.
echo   Revert finished. Reboot recommended.
echo.
pause
