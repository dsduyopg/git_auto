@echo off
chcp 65001 >nul
setlocal
REM ============================================================
REM  Rebuild ALL GitAutoSync services (fix "marked for deletion")
REM  Usage: double-click (auto-elevates to admin)
REM ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoExit','-NoProfile','-ExecutionPolicy','Bypass','-File','\"%~dp0rebuild_all.ps1\"' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0rebuild_all.ps1"
pause
