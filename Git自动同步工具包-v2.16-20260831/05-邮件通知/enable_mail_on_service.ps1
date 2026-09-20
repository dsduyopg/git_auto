# ============================================================
# Git 自动同步工具包 · 为指定仓库同步脚本注入/升级邮件通知
# ------------------------------------------------------------
# 用法:
#   powershell -File enable_mail_on_service.ps1 -All
#   powershell -File enable_mail_on_service.ps1 -Service GitAutoSync_Datahub
#   直接运行 (无参数) 进入交互选择模式
#
# 设计原则:
#   1. 幂等: 已含邮件逻辑的脚本自动跳过, 不会重复注入
#   2. 安全: 注入前自动备份原脚本为 *.mailbak
#   3. 只增不改: 仅在推送成功/失败分支追加邮件调用, 不改动原有同步逻辑
#   4. 全局模块: 统一把 send_mail.ps1 部署到 %ProgramData%\GitAutoSync\, 所有仓库共用一份
# ============================================================

param(
    [string]$Service = '',
    [string]$ScriptPath = '',
    [switch]$All
)

$ErrorActionPreference = 'Continue'

function Get-AllSyncScripts {
    $result = @()
    Get-Service -Name 'GitAutoSync*' -ErrorAction SilentlyContinue | ForEach-Object {
        $n = $_.Name
        $p = "HKLM:\SYSTEM\CurrentControlSet\Services\$n\Parameters"
        $app = (Get-ItemProperty -Path $p -ErrorAction SilentlyContinue).AppParameters
        $script = $null
        if ($app -match '-File\s+"?([^"]+?\.ps1)"?') { $script = $Matches[1] }
        if ($script -and (Test-Path -LiteralPath $script)) {
            $result += [pscustomobject]@{ Service = $n; Status = $_.Status; Script = $script }
        }
    }
    return $result
}

function Ensure-GlobalSendMail {
    $globalMail = Join-Path $env:ProgramData 'GitAutoSync\send_mail.ps1'
    if (-not (Test-Path -LiteralPath $globalMail)) {
        $src = Join-Path $PSScriptRoot 'send_mail.ps1'
        if (Test-Path -LiteralPath $src) {
            New-Item -ItemType Directory -Path (Split-Path $globalMail) -Force | Out-Null
            Copy-Item -LiteralPath $src -Destination $globalMail -Force
            Write-Host "[OK] 已将 send_mail.ps1 部署到全局位置: $globalMail"
        } else {
            Write-Host "[警告] 未找到 send_mail.ps1 源文件: $src"
        }
    }
    return $globalMail
}

function Inject-Mail {
    param([string]$Script)

    $content = [System.IO.File]::ReadAllText($Script, [System.Text.Encoding]::UTF8)
    if ($content.Contains('send_mail.ps1')) {
        Write-Host "  [跳过] 已包含邮件逻辑: $Script"
        return $false
    }

    # ---- 顶部块: 邮件配置 + 辅助函数, 注入到 function Sync-Now 之前 ----
    $header = @'
# ================== 邮件通知（自动注入，重启服务后生效） ==================
$MailScript = $null
$globalMail = Join-Path $env:ProgramData 'GitAutoSync\send_mail.ps1'
if (Test-Path -LiteralPath $globalMail) { $MailScript = $globalMail }
else {
    try {
        $md = Get-ChildItem -Path $RepoPath -Recurse -Directory -Filter '05-邮件通知' -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'send_mail.ps1') } | Select-Object -First 1
        if ($md) { $MailScript = Join-Path $md.FullName 'send_mail.ps1' }
    } catch { }
}
$MailConfPath = Join-Path $env:ProgramData 'GitAutoSync\mail_config.txt'
$MailThrottle = Join-Path $RepoPath 'git_sync_mail_throttle.tmp'

function Get-ChangedFiles {
    param([string]$Path)
    $prevEnc = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        # 取最近 10 分钟内所有提交涉及的文件（去重），避免只显示 HEAD 单条提交
        $files = git -C $Path -c core.quotePath=false -c i18n.logOutputEncoding=UTF-8 log --since="10 minutes ago" --name-only --pretty=format: -- .
        if (-not $files) {
            $files = git -C $Path -c core.quotePath=false -c i18n.logOutputEncoding=UTF-8 diff-tree --no-commit-id --name-only -r HEAD
        }
        return ($files | Where-Object { $_.Trim() } | Sort-Object -Unique) -join "`n"
    } finally {
        [Console]::OutputEncoding = $prevEnc
    }
}

function Send-MailNotify {
    param([string]$Title, [string]$Content, [switch]$Throttle)
    if (-not $MailScript) { return }
    if (-not (Test-Path -LiteralPath $MailScript)) { return }
    if (-not (Test-Path -LiteralPath $MailConfPath)) { return }
    if ($Throttle) {
        if (Test-Path -LiteralPath $MailThrottle) {
            $t = (Get-Item -LiteralPath $MailThrottle).LastWriteTime
            if (((Get-Date) - $t).TotalMinutes -lt 30) { return }
        }
        try { New-Item -ItemType File -Path $MailThrottle -Force | Out-Null } catch { }
    }
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MailScript -Subject $Title -Body $Content *> $null
    } catch { }
}
# ===========================================================================================

'@

    $successCall = @'
                $syncFiles = Get-ChangedFiles -Path $RepoPath
                Send-MailNotify -Title "同步成功: $RepoPath" -Content "仓库: $RepoPath`n分支: $Remote/$Branch`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n结果: 推送成功`n`n变更文件:`n$syncFiles"
'@

    $failCall = @'
        Send-MailNotify -Title "同步失败: $RepoPath" -Content "仓库: $RepoPath`n分支: $Remote/$Branch`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n结果: 推送失败(已重试 $RetryTimes 次)`n错误: $pushOut" -Throttle
'@

    # ---- 注入顶部块 (必须在 function Sync-Now 之前, 因为引用了 $RepoPath) ----
    if ($content.Contains('function Sync-Now {')) {
        $content = $content.Replace('function Sync-Now {', $header + 'function Sync-Now {')
    } else {
        Write-Host "  [警告] 未找到 function Sync-Now, 跳过(该服务可能不是实时推送型): $Script"
        return $false
    }

    # ---- 注入推送成功分支 ----
    $anchorOk = $false
    if ($content.Contains('Write-Log "推送成功 -> $Remote/$Branch"')) {
        $replSuccess = 'Write-Log "推送成功 -> $Remote/$Branch"' + "`n" + $successCall
        $content = $content.Replace('Write-Log "推送成功 -> $Remote/$Branch"', $replSuccess)
        $anchorOk = $true
    } else {
        Write-Host "  [警告] 未找到成功分支锚点, 跳过成功邮件: $Script"
    }

    # ---- 注入推送失败分支 ----
    if ($content.Contains("Write-Log '推送失败，超过重试次数，将在下次变化时重试'")) {
        $replFail = "Write-Log '推送失败，超过重试次数，将在下次变化时重试'" + "`n" + $failCall
        $content = $content.Replace("Write-Log '推送失败，超过重试次数，将在下次变化时重试'", $replFail)
        $anchorOk = $true
    } else {
        Write-Host "  [警告] 未找到失败分支锚点, 跳过失败邮件: $Script"
    }

    if (-not $anchorOk) {
        Write-Host "  [警告] 两个分支锚点都没找到, 未写入任何改动: $Script"
        return $false
    }

    # ---- 备份原脚本后再写回 ----
    $bak = $Script + '.mailbak'
    if (-not (Test-Path -LiteralPath $bak)) {
        Copy-Item -LiteralPath $Script -Destination $bak -Force
    }
    try {
        [System.IO.File]::WriteAllText($Script, $content, [System.Text.UTF8Encoding]::new($true))
        Write-Host "  [OK] 已注入邮件逻辑(原脚本备份为 $(Split-Path $bak -Leaf)): $Script"
        return $true
    } catch {
        Write-Host "  [警告] 写入失败: $_  请确认以管理员身份运行本工具(右键 bat 选「以管理员身份运行」)"
        return $false
    }
}

# ===================== 主流程 =====================
Ensure-GlobalSendMail | Out-Null

# 直接对指定脚本文件注入 (调试/手动指定)
if ($ScriptPath) {
    if (-not (Test-Path -LiteralPath $ScriptPath)) { Write-Host "文件不存在: $ScriptPath"; exit 1 }
    Write-Host "处理指定文件: $ScriptPath"
    Inject-Mail -Script $ScriptPath
    Write-Host '完成。'
    return
}

$svcList = Get-AllSyncScripts

if (-not $svcList -or $svcList.Count -eq 0) {
    Write-Host '未找到任何 GitAutoSync 同步服务'
    exit 0
}

if ($All) {
    $targets = $svcList
} elseif ($Service) {
    $targets = @($svcList | Where-Object { $_.Service -eq $Service })
    if ($targets.Count -eq 0) { Write-Host "未找到服务: $Service"; exit 1 }
} else {
    # 交互选择
    Write-Host ''
    Write-Host '可注入邮件的同步服务（状态基于是否已含邮件逻辑）:'
    for ($i = 0; $i -lt $svcList.Count; $i++) {
        $txt = [System.IO.File]::ReadAllText($svcList[$i].Script, [System.Text.Encoding]::UTF8)
        $m = if ($txt.Contains('send_mail.ps1')) { '[已开启]' } else { '[未开启]' }
        Write-Host ("  [{0}] {1}  {2}  {3}" -f ($i + 1), $svcList[$i].Service, $svcList[$i].Status, $m)
    }
    $pick = Read-Host '请输入编号 (或输入 all 处理全部)'
    if ($pick -eq 'all') {
        $targets = $svcList
    } else {
        $idx = 0
        if ([int]::TryParse($pick, [ref]$idx) -and $idx -ge 1 -and $idx -le $svcList.Count) {
            $targets = @($svcList[$idx - 1])
        } else {
            Write-Host '输入无效'
            exit 1
        }
    }
}

Write-Host ''
foreach ($t in $targets) {
    Write-Host "处理: $($t.Service) -> $($t.Script)"
    Inject-Mail -Script $t.Script
}

Write-Host ''
Write-Host '完成。请重启对应服务使改动生效（服务管理菜单按 [R]，或双击「重启本仓库同步服务.bat」）。'
