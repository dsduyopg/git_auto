@echo off
chcp 65001 >nul
title Git 自动同步工具包 - 邮件通知配置
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"

set "SUBDIR=%~dp005-邮件通知"
if not exist "%SUBDIR%\配置SMTP.bat" (
  echo.
  echo   [错误] 找不到邮件模块: %SUBDIR%\配置SMTP.bat
  echo.
  pause
  exit /b
)

call "%SUBDIR%\配置SMTP.bat"
