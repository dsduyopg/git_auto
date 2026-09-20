# ============================================================
# 修复服务-通用版 (fix_services_generic.ps1)
# 自动扫描所有 GitAutoSync* 服务,读取各自配置,全部重装为正确配置
# 任何仓库都能修,数量不限。以管理员身份运行。
# ============================================================

$ErrorActionPreference = 'Continue'

# ---- 自动检测 nssm.exe ----
$nssm = $null
$candidates = @(
    "$PSScriptRoot\..\04-一键部署\nssm_bin\nssm.exe",
    'C:\nssm\nssm.exe',
    'C:\Program Files\nssm\nssm.exe'
)
foreach ($c in $candidates) { if (Test-Path $c) { $nssm = $c; break } }
if (-not $nssm -and (Get-Command nssm -ErrorAction SilentlyContinue)) { $nssm = (Get-Command nssm).Source }
if (-not $nssm) {
    Write-Host "[错误] 未找到 nssm.exe,请把 nssm 放到 C:\nssm\nssm.exe 或包内 04-一键部署\nssm_bin\"
    exit 1
}
Write-Host "使用 nssm: $nssm"

Write-Host "=============================================="
Write-Host "  通用服务修复工具"
Write-Host "=============================================="
Write-Host "[*] 扫描 GitAutoSync 服务..."

$svcRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Services'
$found = @()
Get-ChildItem $svcRegPath | ForEach-Object {
    $name = $_.PSChildName
    if ($name -like 'GitAutoSync*') {
        $params = Join-Path $_.PSPath 'Parameters'
        if (Test-Path $params) {
            $appParams = (Get-ItemProperty $params -ErrorAction SilentlyContinue).AppParameters
            if ($appParams) { $found += @{ Name = $name; AppParams = $appParams } }
        }
    }
}
if ($found.Count -eq 0) { Write-Host "[提示] 未找到任何 GitAutoSync 服务"; exit 0 }
Write-Host "发现 $($found.Count) 个服务"

foreach ($svc in $found) {
    $name = $svc.Name
    if ($svc.AppParams -match '-File\s+"?([^"]+?\.ps1)"?') { $script = $Matches[1].Trim('"') }
    else { Write-Host "[跳过] $name : 无法解析脚本"; continue }
    $repo = Split-Path $script
    $logOut = Join-Path $repo 'git_sync_service.log'
    $logErr = Join-Path $repo 'git_sync_service_err.log'

    Write-Host ""
    Write-Host "=== 修复: $name (repo=$repo) ==="
    & $nssm stop $name 2>&1 | Out-Null
    & $nssm remove $name confirm 2>&1 | Out-Null
    & $nssm install $name "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" 2>&1 | Out-Null
    & $nssm set $name ObjectName LocalSystem 2>&1 | Out-Null
    & $nssm set $name AppDirectory "$repo" 2>&1 | Out-Null
    & $nssm set $name Start SERVICE_AUTO_START 2>&1 | Out-Null
    & $nssm set $name AppExit Default Restart 2>&1 | Out-Null
    & $nssm set $name AppRestartDelay 5000 2>&1 | Out-Null
    & $nssm set $name AppStdout "$logOut" 2>&1 | Out-Null
    & $nssm set $name AppStderr "$logErr" 2>&1 | Out-Null
    & $nssm set $name AppRotateFiles 1 2>&1 | Out-Null
    & $nssm set $name AppRotateBytes 1048576 2>&1 | Out-Null
    & $nssm set $name AppEnvironmentExtra GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0=* 2>&1 | Out-Null
    & $nssm start $name 2>&1 | Out-Null
    $st = (sc.exe query $name 2>&1 | Select-String 'RUNNING')
    if ($st) { Write-Host "[OK] $name 已修复并运行" }
    else { Write-Host "[警告] $name 未运行,请查看 $logOut" }
}

Write-Host ""
Write-Host "验证:  sc query | findstr GitAutoSync"
Write-Host "       sc qc GitAutoSync   (应显示 AUTO_START)"
