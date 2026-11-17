@echo off
rem © Mayanktaker Computers & Web Development | https://mayanktaker.com
setlocal EnableDelayedExpansion

title Windows Gaming Setup - System Audit

:: Check for Administrator privileges
net session >nul 2>&1
if errorlevel 1 (
  echo.
  echo   ======================================================================
  echo     Elevating to Administrator...
  echo     Please click "Yes" on the UAC prompt to audit system settings.
  echo   ======================================================================
  echo.
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
  exit /b
)

echo.
echo   ======================================================================
echo     Windows Gaming Setup - System Audit
echo     Created by Mayanktaker Computers ^& Web Development
echo     https://mayanktaker.com
echo   ======================================================================
echo.
echo   Running non-destructive gaming optimization audit...
echo   Detecting Windows Update drift and verifying settings...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Win11-Gaming-Setup.ps1" -Audit -ElevatedChild -NoPause

echo.
echo   Audit finished. Check results above or in logs.txt.
echo   Website: https://mayanktaker.com
echo   ☕ Fuel Mayank with coffee: https://buymeacoffee.com/mayanktaker
echo.
pause
