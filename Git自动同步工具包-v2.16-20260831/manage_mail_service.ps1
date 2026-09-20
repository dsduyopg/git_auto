# ============================================================
# Git 自动同步工具包 - 邮件服务管理菜单
# ------------------------------------------------------------
# 功能:
#   1. 列出本机所有"已安装 GitAutoSync 同步服务"的仓库 (动态扫描注册表, 通用)。
#   2. 输入序号即可为某个仓库开启/关闭邮件通知。
#   3. 一键安装 / 启动 / 停止 "邮件监控服务" (GitAutoSyncMail)。
#   4. 完全不修改各仓库的同步脚本, 跨电脑通用。
#
# 使用:
#   - 通过 服务管理.bat -> [H] 进入 (已管理员提权)。
#   - 或右键本脚本"以管理员身份运行"。
# ============================================================

$ErrorActionPreference = 'Continue'

# ---------- 管理员自检 ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '需要管理员权限才能修改邮件配置 / 安装服务。' -ForegroundColor Yellow
    Write-Host '请通过 服务管理.bat -> [H] 进入, 或右键本脚本"以管理员身份运行"。'
    Read-Host '按回车退出'
    exit 1
}

$GA            = Join-Path $env:ProgramData 'GitAutoSync'
$SendMail      = Join-Path $GA 'send_mail.ps1'
$EnabledFile   = Join-Path $GA 'mail_enabled_repos.txt'
$MonitorScript = Join-Path $GA 'mail_monitor.ps1'
$nssm          = Join-Path $PSScriptRoot '04-一键部署\nssm_bin\nssm.exe'
if (-not (Test-Path -LiteralPath $nssm)) { $nssm = 'C:\nssm\nssm.exe' }

# ---------- 读取所有同步服务对应的仓库 ----------
function Get-RepoList {
    $result = @()
    $svcs = Get-Service -Name 'GitAutoSync*' -ErrorAction SilentlyContinue | Sort-Object Name
    foreach ($svc in $svcs) {
        $params = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)\Parameters"
        $scriptPath = $null
        if (Test-Path -LiteralPath $params) {
            $p = Get-ItemProperty -LiteralPath $params -ErrorAction SilentlyContinue
            if ($p.AppParameters -match '-File\s+"?([^"]+?\.ps1)"?') {
                $scriptPath = $Matches[1]
            } elseif ($p.Application -match '\.ps1') {
                $scriptPath = $p.Application
            }
        }
        if (-not $scriptPath -or -not (Test-Path -LiteralPath $scriptPath)) { continue }
        $dir = Split-Path -Parent $scriptPath
        $repo = $null
        try { $repo = (git -C $dir rev-parse --show-toplevel 2>$null) } catch { }
        if (-not $repo) { $repo = $dir }
        $result += [PSCustomObject]@{
            Service = $svc.Name
            Repo    = $repo
            Script  = $scriptPath
        }
    }
    return $result
}

# ---------- 读取已启用邮件的仓库列表 ----------
function Get-Enabled {
    if (-not (Test-Path -LiteralPath $EnabledFile)) { return @() }
    try {
        return @([System.IO.File]::ReadAllLines($EnabledFile, [System.Text.Encoding]::UTF8) | Where-Object { $_.Trim() })
    } catch { return @() }
}

# ---------- 写入启用 / 关闭 ----------
function Set-Enabled($repo, $on) {
    $list = Get-Enabled
    if ($on) {
        if ($list -notcontains $repo) { $list = $list + $repo }
    } else {
        $list = @($list | Where-Object { $_ -ne $repo })
    }
    try {
        [System.IO.File]::WriteAllLines($EnabledFile, $list, (New-Object System.Text.UTF8Encoding($false)))
    } catch {
        Write-Host ("写配置失败: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
}

# ---------- 关闭某仓库脚本里旧的内联邮件逻辑 (避免与监控服务重复发信) ----------
function Disable-LegacyMail($scriptPath) {
    try {
        $content = [System.IO.File]::ReadAllText($scriptPath, [System.Text.Encoding]::UTF8)
        if ($content -match '\$MailNotifyEnabled\s*=\s*\$true') {
            $newContent = $content -replace '\$MailNotifyEnabled\s*=\s*\$true', '$MailNotifyEnabled = $false'
            [System.IO.File]::WriteAllText($scriptPath, $newContent, [System.Text.Encoding]::UTF8)
        }
    } catch { }
}

# ---------- 安装 / 启动邮件监控服务 ----------
function Install-MailService {
    # 把 monitor 脚本复制到公共目录 (首次或更新)
    $src = Join-Path $PSScriptRoot 'mail_monitor.ps1'
    if (Test-Path -LiteralPath $src) {
        try { Copy-Item -LiteralPath $src -Destination $MonitorScript -Force } catch { Write-Host '复制 monitor 脚本失败(可能正在运行, 已生效)' -ForegroundColor Yellow }
    }
    if (-not (Test-Path -LiteralPath $MonitorScript)) {
        Write-Host "未找到邮件监控脚本: $MonitorScript" -ForegroundColor Red
        return
    }

    $svc = Get-Service -Name 'GitAutoSyncMail' -ErrorAction SilentlyContinue
    if (-not $svc) {
        $pwsh = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
        & $nssm install GitAutoSyncMail | Out-Null
        & $nssm set GitAutoSyncMail Application $pwsh | Out-Null
        & $nssm set GitAutoSyncMail AppParameters "-NoProfile -ExecutionPolicy Bypass -File `"$MonitorScript`"" | Out-Null
        & $nssm set GitAutoSyncMail AppDirectory $GA | Out-Null
        & $nssm set GitAutoSyncMail DisplayName "GitAutoSync 邮件通知监控" | Out-Null
        & $nssm set GitAutoSyncMail Description "监控启用邮件的仓库, 有新推送时发送通知" | Out-Null
        & $nssm set GitAutoSyncMail Start SERVICE_AUTO_START | Out-Null
        Write-Host '已安装 GitAutoSyncMail 服务' -ForegroundColor Green
    }

    Stop-Service GitAutoSyncMail -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
    Start-Service GitAutoSyncMail -ErrorAction SilentlyContinue
    Write-Host '已启动 GitAutoSyncMail 服务' -ForegroundColor Green

    # 发一封测试邮件确认配置可用
    if (Test-Path -LiteralPath $SendMail) {
        Write-Host '正在发送一封测试邮件...'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SendMail -Subject '[GitAutoSync] 邮件服务已启用' -Body "邮件监控服务 GitAutoSyncMail 已成功启动。`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Force
    }
}

function Stop-MailService {
    Stop-Service GitAutoSyncMail -Force -ErrorAction SilentlyContinue
    Write-Host '已停止 GitAutoSyncMail 服务' -ForegroundColor Green
}

# ---------- 显示 SMTP 与监控服务状态 ----------
function Show-MailConfig {
    if (-not (Test-Path -LiteralPath (Join-Path $GA 'mail_config.txt'))) {
        Write-Host '  [!] 未找到 mail_config.txt, 请先配置 SMTP (工具包 05-邮件通知)' -ForegroundColor Yellow
    } else {
        $enabled = $false
        Get-Content (Join-Path $GA 'mail_config.txt') -Encoding UTF8 | ForEach-Object { if ($_ -match '^enabled\s*=\s*1') { $enabled = $true } }
        Write-Host ("  SMTP 总开关: " + $(if ($enabled) { '已开启 (enabled=1)' } else { '已关闭 (enabled≠1)' }))
    }
    $m = Get-Service -Name GitAutoSyncMail -ErrorAction SilentlyContinue
    Write-Host ("  邮件监控服务: " + $(if ($m) { $m.Status } else { '未安装' }))
}

# ---------- 主菜单 ----------
while ($true) {
    Clear-Host
    $repos   = Get-RepoList
    $enabled = Get-Enabled
    Write-Host '============================================'
    Write-Host '   Git 自动同步 · 邮件服务管理'
    Write-Host '============================================'
    Show-MailConfig
    Write-Host ''
    Write-Host '   已安装同步服务的仓库 (输入序号切换邮件开/关):'
    if ($repos.Count -eq 0) {
        Write-Host '   (未找到任何 GitAutoSync 同步服务)'
    } else {
        for ($i = 0; $i -lt $repos.Count; $i++) {
            $on = $enabled -contains $repos[$i].Repo
            Write-Host ("  [{0}] [{1}] {2}" -f ($i + 1), $(if ($on) { '邮件✓' } else { '邮件 ' }), $repos[$i].Repo)
            Write-Host ("       服务: {0}" -f $repos[$i].Service)
        }
    }
    Write-Host ''
    Write-Host '   [S] 安装/启动 邮件监控服务'
    Write-Host '   [X] 停止 邮件监控服务'
    Write-Host '   [A] 全部启用邮件'
    Write-Host '   [N] 全部关闭邮件'
    Write-Host '   [0] 返回上级菜单'
    Write-Host ''

    $opt = Read-Host '请选择 (序号 / S / X / A / N / 0)'
    if ($opt -eq '0') { break }
    elseif ($opt -eq 'S') { Install-MailService; Read-Host '按回车继续' }
    elseif ($opt -eq 'X') { Stop-MailService; Read-Host '按回车继续' }
    elseif ($opt -eq 'A') {
        $repos | ForEach-Object { Set-Enabled $_.Repo $true; Disable-LegacyMail $_.Script }
        Write-Host '已全部启用邮件' -ForegroundColor Green; Read-Host '按回车继续'
    }
    elseif ($opt -eq 'N') {
        $repos | ForEach-Object { Set-Enabled $_.Repo $false }
        Write-Host '已全部关闭邮件' -ForegroundColor Green; Read-Host '按回车继续'
    }
    elseif ($opt -match '^\d+$') {
        $idx = [int]$opt
        if ($idx -ge 1 -and $idx -le $repos.Count) {
            $r  = $repos[$idx - 1]
            $on = $enabled -contains $r.Repo
            Set-Enabled $r.Repo (-not $on)
            if (-not $on) { Disable-LegacyMail $r.Script }
            Write-Host ("已{0}邮件: {1}" -f $(if (-not $on) { '启用' } else { '关闭' }), $r.Repo) -ForegroundColor Green
        } else {
            Write-Host '序号无效' -ForegroundColor Red
        }
        Read-Host '按回车继续'
    }
    else {
        Write-Host '输入无效' -ForegroundColor Red
        Start-Sleep -Milliseconds 600
    }
}
