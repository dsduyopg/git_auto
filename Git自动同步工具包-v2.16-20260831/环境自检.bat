@echo off
chcp 65001 >nul
setlocal
if not exist "%~dp004-一键部署\开始使用.bat" (
    echo [ERROR] Missing setup script. Please re-extract the package.
    pause
    exit /b 1
)
call "%~dp004-一键部署\开始使用.bat"
pause
