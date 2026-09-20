@echo off
chcp 65001 >nul
setlocal
REM ============================================================
REM  One-click: create a new auto-sync repo (GENERIC version)
REM  Works on any machine: asks for SSH key, git identity, nssm
REM ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0new_sync_repo_generic.ps1"
echo.
pause