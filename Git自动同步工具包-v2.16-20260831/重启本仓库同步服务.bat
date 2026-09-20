@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
chcp 65001 >nul
echo Restarting GitAutoSyncGH service (reload sync script)...
net stop GitAutoSyncGH
net start GitAutoSyncGH
echo.
echo Done.
pause
