# ============================================================
# 云端变化镜像拉取器 - 通用版 (change_fetcher_generic.ps1)
# 定时读取配置文件,把云端最新变化拉到对应目标目录
# 配置格式(每行):  目标目录|远端URL|分支|SSH密钥路径
# 密钥路径可省略,省略时使用默认密钥 (# 开头为注释)
# ============================================================

$ErrorActionPreference = 'Continue'

# ---- 邮件通知(可选功能, 未配置则整段跳过, 频率由 send_mail.ps1 统一节流) ----
$MailHelper = ''
try {
    $toolRoot = Split-Path $PSScriptRoot -Parent
    $mailDir = Get-ChildItem -Path $toolRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '05*' } | Select-Object -First 1
    if ($mailDir) {
        $cand = Join-Path $mailDir.FullName 'send_mail.ps1'
        if (Test-Path -LiteralPath $cand) { $MailHelper = $cand }
    }
} catch { }
function Send-MailNotify {
    param([string]$Title, [string]$Content)
    if (-not $MailHelper) { return }
    if (-not (Test-Path -LiteralPath $MailHelper)) { return }
    $conf = Join-Path $env:ProgramData 'GitAutoSync\mail_config.txt'
    if (-not (Test-Path -LiteralPath $conf)) { return }
    try { & powershell -NoProfile -ExecutionPolicy Bypass -File $MailHelper -Subject $Title -Body $Content } catch { }
}

# ---- 配置 ----
$SettingsFile = Join-Path $env:USERPROFILE 'git_mirror_settings.txt'
$IntervalMinutes = 60
if (Test-Path -LiteralPath $SettingsFile) {
    Get-Content -LiteralPath $SettingsFile -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -match '^interval\s*=\s*(\d+)$') {
            $v = [int]$Matches[1]
            if ($v -ge 1 -and $v -le 1440) { $IntervalMinutes = $v }
        }
    }
}
$CleanUntracked = if ($env:GIT_MIRROR_CLEAN -eq '0') { $false } else { $true }
$ConfigFile = Join-Path $env:USERPROFILE 'git_mirror_config.txt'
$LogFile = Join-Path $env:USERPROFILE 'git_mirror_fetcher.log'

# 默认 SSH 私钥(第一条记录未指定密钥时使用)
$sshDir = Join-Path $env:USERPROFILE '.ssh'
$DefaultKey = $null
if (Test-Path $sshDir) {
    $keys = Get-ChildItem $sshDir -File | Where-Object {
        $_.Name -notlike '*.pub' -and $_.Name -notmatch 'known_hosts|config|authorized_keys'
    }
    if ($keys.Count -gt 0) { $DefaultKey = $keys[0].FullName }
}
if (-not $DefaultKey) {
    Write-Host "[错误] 未找到 SSH 私钥"
    exit 1
}
$env:GIT_SSH_COMMAND = "ssh -i `"$($DefaultKey -replace '\\','/')`" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

function Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    $line | Out-File -FilePath $LogFile -Append -Encoding utf8
    Write-Host $line
}

function Get-Mirrors {
    $result = @()
    if (-not (Test-Path $ConfigFile)) {
        Log "错误：找不到配置文件 $ConfigFile"
        return $result
    }
    Get-Content $ConfigFile -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        $parts = $line -split '\|'
        if ($parts.Count -ge 3) {
            $item = @{ Dir = $parts[0].Trim(); Url = $parts[1].Trim(); Branch = $parts[2].Trim(); Key = $null }
            if ($parts.Count -ge 4 -and $parts[3].Trim()) { $item.Key = $parts[3].Trim() }
            $result += $item
        }
    }
    return $result
}

function Update-Mirror {
    param($m)
    $key = if ($m.Key) { $m.Key } else { $DefaultKey }
    $env:GIT_SSH_COMMAND = "ssh -i `"$($key -replace '\\','/')`" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    $gitDir = Join-Path $m.Dir '.git'
    if (-not (Test-Path $gitDir)) {
        $parent = Split-Path $m.Dir
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $out = git clone $m.Url $m.Dir 2>&1
        if ($LASTEXITCODE -eq 0) {
            git -C $m.Dir checkout $m.Branch 2>&1 | Out-Null
            Log "已克隆 $($m.Dir)"
            Send-MailNotify -Title "拉取成功: $($m.Dir)" -Content "目标: $($m.Dir)`n分支: $($m.Branch)`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n结果: 已克隆/更新成功"
        } else {
            Log "克隆失败 $($m.Dir): $out"
            Send-MailNotify -Title "拉取失败: $($m.Dir)" -Content "目标: $($m.Dir)`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n结果: 克隆失败`n错误: $out"
        }
    } else {
        $fOut = git -C $m.Dir fetch origin $m.Branch 2>&1
        if ($LASTEXITCODE -ne 0) {
            Log "fetch 失败 $($m.Dir): $fOut"
            Send-MailNotify -Title "拉取失败: $($m.Dir)" -Content "目标: $($m.Dir)`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n结果: fetch 失败`n错误: $fOut"
            return
        }
        git -C $m.Dir reset --hard "origin/$($m.Branch)" 2>&1 | Out-Null
        if ($CleanUntracked) { git -C $m.Dir clean -fd 2>&1 | Out-Null }
        Log "已更新 $($m.Dir) -> origin/$($m.Branch)"
        Send-MailNotify -Title "拉取成功: $($m.Dir)" -Content "目标: $($m.Dir)`n分支: origin/$($m.Branch)`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n结果: 已克隆/更新成功"
    }
}

Log '============================================'
Log 'change fetcher 启动 (通用版)'
Log "间隔: ${IntervalMinutes} 分钟  配置: $ConfigFile"
Log "清理未跟踪文件: $CleanUntracked (设置 GIT_MIRROR_CLEAN=0 可关闭)"
Log "默认密钥: $DefaultKey (每条记录可用第4列单独指定)"

$mirrors = Get-Mirrors
Log "读取到 $($mirrors.Count) 个镜像"
foreach ($m in $mirrors) { Update-Mirror $m }
Log '首轮完成,进入定时循环'

while ($true) {
    Start-Sleep -Seconds ($IntervalMinutes * 60)
    Log "----- 新一轮检测 -----"
    $mirrors = Get-Mirrors
    foreach ($m in $mirrors) { Update-Mirror $m }
    Log "本轮完成"
}
