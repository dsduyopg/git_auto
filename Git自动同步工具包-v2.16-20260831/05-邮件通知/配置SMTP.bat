@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title Git 自动同步工具包 - 邮件通知配置

set "PROGDATA=%ProgramData%"
if not defined PROGDATA set "PROGDATA=%USERPROFILE%"
set "CONFDIR=%PROGDATA%\GitAutoSync"
set "CONF=%CONFDIR%\mail_config.txt"

:TOP
cls
echo ==============================================
echo   Git 自动同步工具包 - 邮件通知配置
echo ==============================================
echo.
echo   配置文件: %CONF%
echo.
echo   当前状态:
if exist "%CONF%" (
  for /f "usebackq tokens=1,2 delims==" %%a in ("%CONF%") do (
    if "%%a"=="enabled" echo     开关    : %%b   (1=开启  0=关闭)
    if "%%a"=="smtp_server" echo     服务器  : %%b
    if "%%a"=="smtp_port" echo     端口    : %%b
    if "%%a"=="from" echo     发件人  : %%b
    if "%%a"=="to" echo     收件人  : %%b
    if "%%a"=="notify_interval" echo     发送频率: %%b 分钟 (0=即时)
  )
) else (
  echo     尚未配置 (邮件通知默认关闭)
)
echo.
echo ----------------------------------------------
echo   [1] 开启并绑定 SMTP
echo   [2] 关闭邮件通知
echo   [3] 发送一封测试邮件
echo   [4] 收件人管理 (增/删/清空)
echo   [5] 设置发送频率 (即时或任意分钟)
echo   [0] 退出
echo ----------------------------------------------
set /p CHOICE=   请选择: 

if "%CHOICE%"=="1" goto SETUP
if "%CHOICE%"=="2" goto DISABLE
if "%CHOICE%"=="3" goto TESTMAIL
if "%CHOICE%"=="4" goto MANAGE
if "%CHOICE%"=="5" goto SETINTERVAL
goto END

:SETUP
echo.
echo --- 选择邮箱类型 (自动填写服务器和端口) ---
echo   [1] QQ邮箱       smtp.qq.com     587  STARTTLS
echo   [2] 163邮箱      smtp.163.com    587  STARTTLS
echo   [3] Gmail        smtp.gmail.com  587  STARTTLS
echo   [4] 企业邮箱 / 自定义 (手动填写)
echo.
set /p MTYPE=   请输入 1-4: 

if "%MTYPE%"=="1" (
  set "SMTP_SERVER=smtp.qq.com"
  set "SMTP_PORT=587"
  set "USE_SSL=1"
  goto ASKMAIL
)
if "%MTYPE%"=="2" (
  set "SMTP_SERVER=smtp.163.com"
  set "SMTP_PORT=587"
  set "USE_SSL=1"
  goto ASKMAIL
)
if "%MTYPE%"=="3" (
  set "SMTP_SERVER=smtp.gmail.com"
  set "SMTP_PORT=587"
  set "USE_SSL=1"
  goto ASKMAIL
)
if "%MTYPE%"=="4" (
  set /p SMTP_SERVER=   SMTP 服务器 (如 smtp.exmail.qq.com): 
  set /p SMTP_PORT=    端口 (回车默认 587; 465 隐式SSL 本工具不支持): 
  set /p USE_SSL=      是否 SSL (1=是 0=否, 回车默认 1): 
  if not defined SMTP_PORT set "SMTP_PORT=587"
  if not defined USE_SSL set "USE_SSL=1"
  goto ASKMAIL
)
echo   输入无效
pause
goto TOP

:ASKMAIL
echo.
echo --- 填写发信身份 ---
set /p FROM_ADDR=   发件邮箱 (如 123456@qq.com): 
if not defined FROM_ADDR (
  echo   发件邮箱不能为空
  pause
  goto TOP
)
echo.
echo   授权码说明: 不是邮箱登录密码!
echo   QQ邮箱 : 设置 - 账户 - POP3/SMTP服务 - 生成授权码
echo   163邮箱: 设置 - POP3/SMTP/IMAP - 开启 - 生成授权码
echo.
set /p SMTP_PASS=   SMTP 授权码: 
if not defined SMTP_PASS (
  echo   授权码不能为空
  pause
  goto TOP
)
set /p TO_ADDR=   收件邮箱 (多个用逗号分隔): 
if not defined TO_ADDR set "TO_ADDR=%FROM_ADDR%"

if not exist "%CONFDIR%" mkdir "%CONFDIR%" 2>nul
> "%CONF%" echo # Git 自动同步工具包 - 邮件通知配置
>> "%CONF%" echo # enabled=1 开启, 0 关闭
>> "%CONF%" echo enabled=1
>> "%CONF%" echo smtp_server=%SMTP_SERVER%
>> "%CONF%" echo smtp_port=%SMTP_PORT%
>> "%CONF%" echo use_ssl=%USE_SSL%
>> "%CONF%" echo from=%FROM_ADDR%
>> "%CONF%" echo password=%SMTP_PASS%
>> "%CONF%" echo to=%TO_ADDR%
>> "%CONF%" echo notify_interval=10

echo.
echo   [OK] 邮件通知已开启并保存
echo   配置: %CONF%
echo.
echo   提示: 授权码以明文保存在上述文件, 请勿外传该文件
echo.
set /p NOWTEST=   是否立即发一封测试邮件? (y/n): 
if /i "%NOWTEST%"=="y" goto TESTMAIL
pause
goto TOP

:DISABLE
echo.
if not exist "%CONF%" (
  echo   当前本就没有配置, 无需关闭
  pause
  goto TOP
)
if not exist "%CONFDIR%" mkdir "%CONFDIR%" 2>nul
set "TMPCONF=%CONF%.tmp"
> "%TMPCONF%" echo # Git 自动同步工具包 - 邮件通知配置
>> "%TMPCONF%" echo enabled=0
>> "%TMPCONF%" findstr /b /v /c:"#" /c:"enabled=" "%CONF%"
move /y "%TMPCONF%" "%CONF%" >nul
echo   [OK] 邮件通知已关闭 (SMTP 账号等配置已保留, 可随时重新开启)
echo.
pause
goto TOP

:MANAGE
cls
echo --- 收件人管理 ---
if not exist "%CONF%" (
  echo   尚未配置, 请先选 [1] 开启并绑定 SMTP
  pause
  goto TOP
)
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "manage_recipients.ps1"
goto TOP

:TESTMAIL
echo.
if not exist "%CONF%" (
  echo   [提示] 尚未配置, 请先选 [1] 开启并绑定 SMTP
  pause
  goto TOP
)
set "TOLINE="
for /f "usebackq tokens=1,2 delims==" %%a in ("%CONF%") do (
  if "%%a"=="to" set "TOLINE=%%b"
)
if not defined TOLINE (
  echo   收件人为空, 请先选 [4] 添加收件人
  pause
  goto TOP
)
cls
echo --- 选择测试的收件人 ---
echo   [0] 全部: %TOLINE%
set "IDX=0"
for %%e in (%TOLINE%) do (
  set /a IDX+=1
  echo   [!IDX!] %%e
)
echo.
set "SELTO="
set /p SEL=请选择编号(0=全部): 
if "%SEL%"=="0" (
  set "SELTO="
  goto SENDTEST
)
set "IDX=0"
for %%e in (%TOLINE%) do (
  set /a IDX+=1
  if !IDX!==%SEL% set "SELTO=%%e"
)
:SENDTEST
cd /d "%~dp0"
echo   正在发送测试邮件...
if defined SELTO (
  powershell -NoProfile -ExecutionPolicy Bypass -File "send_mail.ps1" -Subject "Git同步工具包 - 测试邮件" -Body "收到这封邮件说明 SMTP 配置正确, 邮件通知已可用。" -To "%SELTO%" -Force
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "send_mail.ps1" -Subject "Git同步工具包 - 测试邮件" -Body "收到这封邮件说明 SMTP 配置正确, 邮件通知已可用。" -Force
)
echo.
echo   说明: [OK]=发送成功  [跳过]=未开启或配置不全  [失败]=配置有误(见错误原因)
echo   日志: %CONFDIR%\git_mail_notify.log
echo.
pause
goto TOP

:SETINTERVAL
cls
echo --- 设置邮件发送频率 ---
if not exist "%CONF%" (
  echo   尚未配置, 请先选 [1] 开启并绑定 SMTP
  pause
  goto TOP
)
cd /d "%~dp0"
echo   同一频率窗口内多次推送只会发一封 (聚合通知, 避免刷屏):
echo     [0]    即时 (每次有变化都发)
echo     [10]   10 分钟 (有变化才发, 推荐)
echo     [任意正整数]  自定义分钟数, 例如 15 / 30 / 90 / 120 ...
echo.
set /p IV=请输入分钟数 (0=即时, 或任意正整数分钟, 如 15/30/90): 
if "%IV%"=="" goto SETINTERVAL
powershell -NoProfile -ExecutionPolicy Bypass -File "set_notify_interval.ps1" -Minutes %IV%
pause
goto TOP

:END
endlocal
