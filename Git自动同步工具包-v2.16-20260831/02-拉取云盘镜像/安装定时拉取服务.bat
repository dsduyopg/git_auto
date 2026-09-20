@echo off
chcp 65001 >nul
setlocal
REM ============================================================
REM  Install scheduled mirror-fetch service (GitMirrorFetcher)
REM  Auto-elevates to admin. Uses nssm bundled in the kit.
REM ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~dp0安装定时拉取服务.bat' -Verb RunAs"
    exit /b
)

set "NSSM=%~dp0..\04-一键部署\nssm_bin\nssm.exe"
if not exist "%NSSM%" set "NSSM=C:\nssm\nssm.exe"
if not exist "%NSSM%" set "NSSM=nssm"

where nssm >nul 2>&1
if %errorlevel% neq 0 if "%NSSM%"=="nssm" (
    echo [ERROR] nssm.exe not found. Please run 04-一键部署\开始使用.bat first.
    pause
    exit /b 1
)

set "SVC=GitMirrorFetcher"
set "FETCHER=%~dp0change_fetcher_generic.ps1"
set "WORKDIR=%~dp0"

"%NSSM%" stop %SVC% >nul 2>&1
"%NSSM%" remove %SVC% confirm >nul 2>&1
"%NSSM%" install %SVC% "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" "-NoProfile -ExecutionPolicy Bypass -File ""%FETCHER%"""
"%NSSM%" set %SVC% ObjectName LocalSystem
"%NSSM%" set %SVC% AppDirectory "%WORKDIR:~0,-1%"
"%NSSM%" set %SVC% Start SERVICE_AUTO_START
"%NSSM%" set %SVC% AppExit Default Restart
"%NSSM%" set %SVC% AppRestartDelay 5000
"%NSSM%" set %SVC% AppStdout "%USERPROFILE%\git_mirror_fetcher_console.log"
"%NSSM%" set %SVC% AppStderr "%USERPROFILE%\git_mirror_fetcher_console_err.log"
"%NSSM%" set %SVC% AppRotateFiles 1
"%NSSM%" set %SVC% AppRotateBytes 1048576
"%NSSM%" set %SVC% AppEnvironmentExtra USERPROFILE="%USERPROFILE%"
"%NSSM%" start %SVC%

echo.
echo ------------------------------------------------------------
echo  Service installed: %SVC%
echo  Config file: %USERPROFILE%\git_mirror_config.txt
echo  Log file: %USERPROFILE%\git_mirror_fetcher.log
echo ------------------------------------------------------------
sc query %SVC%
pause
