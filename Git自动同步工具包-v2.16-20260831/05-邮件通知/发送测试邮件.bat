@echo off
chcp 65001 >nul
title Git 自动同步工具包 - 发送测试邮件
cd /d "%~dp0"

set "PROGDATA=%ProgramData%"
if not defined PROGDATA set "PROGDATA=%USERPROFILE%"
set "CONFDIR=%PROGDATA%\GitAutoSync"
set "CONF=%CONFDIR%\mail_config.txt"

echo ==============================================
echo   发送测试邮件
echo ==============================================
echo.

if not exist "%CONF%" (
  echo   [提示] 尚未配置邮件, 请先运行 [配置SMTP.bat]
  echo.
  pause
  exit /b
)

echo   配置文件: %CONF%
echo   正在发送...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "send_mail.ps1" -Subject "Git同步工具包 - 测试邮件" -Body "收到这封邮件说明 SMTP 配置正确, 邮件通知已可用。"
echo.
echo   结果说明:
echo     [OK]   = 发送成功, 去收件箱看看
echo     [跳过] = 未开启(enabled=0) 或 配置不全
echo     [失败] = 配置有误, 上方会显示错误原因
echo.
echo   日志: %CONFDIR%\git_mail_notify.log
echo.
pause
