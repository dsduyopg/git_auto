@echo off
chcp 65001 >nul
setlocal
REM ============================================================
REM  Generic service repair - fixes ALL GitAutoSync services
REM  Usage: double-click (auto-elevates to admin)
REM ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoExit','-NoProfile','-ExecutionPolicy','Bypass','-File','\"%~dp0fix_services_generic.ps1\"' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fix_services_generic.ps1"
pause
