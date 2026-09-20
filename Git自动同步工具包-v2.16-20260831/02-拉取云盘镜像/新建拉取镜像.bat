@echo off
chcp 65001 >nul
setlocal
REM ============================================================
REM  Add a cloud-pull mirror (any Gitee/GitHub repo -> any path)
REM  Usage: run this, follow the prompts
REM ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0new_pull_mirror_generic.ps1"
echo.
pause