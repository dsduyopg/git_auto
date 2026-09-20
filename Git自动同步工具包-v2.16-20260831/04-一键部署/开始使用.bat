@echo off
chcp 65001 >nul
setlocal
REM ============================================================
REM  Git Auto-Sync Kit - One-click setup & environment check
REM  Zero-experience friendly.
REM ============================================================

echo ============================================
echo   Git Auto-Sync Kit - Setup Helper
echo ============================================

echo.
echo [1] Checking Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo   [FAIL] Git not found. Install Git first:
    echo          https://git-scm.com/download/win
    echo   Then run this again.
    pause
    exit /b 1
)
for /f "tokens=1-3" %%v in ('git --version') do echo   [OK] %%v %%w %%x

echo.
echo [2] Checking SSH key...
if exist "%USERPROFILE%\.ssh\id_ed25519" (
    echo   [OK] Key found: %USERPROFILE%\.ssh\id_ed25519
) else (
    echo   [NOTICE] No SSH key found.
    choice /c YN /m "Generate a new SSH key now?"
    if errorlevel 2 goto :nokey
    if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
    ssh-keygen -t ed25519 -f "%USERPROFILE%\.ssh\id_ed25519" -N ""
    echo   [OK] Key generated.
    echo   Public key - add this line to Gitee/GitHub:
    type "%USERPROFILE%\.ssh\id_ed25519.pub"
    echo.
    echo   Gitee: Settings - SSH Public Keys
    echo   GitHub: Settings - SSH and GPG keys
    echo.
    pause
)
:nokey

echo.
echo [3] Checking nssm...
if exist "%~dp0nssm_bin\nssm.exe" (
    echo   [OK] nssm found.
) else (
    echo   [WARN] nssm not found in the nssm_bin folder
)

echo.
echo ============================================
echo   Done! What do you want to do?
echo ============================================
echo   [A] Auto-sync a LOCAL folder to Gitee/GitHub
echo       (folder 01 - new push repo)
echo.
echo   [B] Pull a REMOTE repo to a local folder
echo       (folder 02 - pull mirror)
echo.
echo   [C] Fix or rebuild services if broken
echo       (folder 03 - fix and rebuild)
echo.
echo   [D] Read the beginner guide (Chinese)
echo       (open the docs folder)
echo.
choice /c YN /m "Open the docs folder now?"
if errorlevel 2 goto :done
start "" "%~dp0..\docs\"

:done
echo.
echo Tip: read the beginner guide in the docs folder.
pause