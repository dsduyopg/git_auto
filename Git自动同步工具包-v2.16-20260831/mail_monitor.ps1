# ============================================================
# Git 自动同步工具包 - 邮件通知监控服务 (GitAutoSyncMail)
# ------------------------------------------------------------
# 工作方式:
#   常驻后台, 每 30 秒检查一次 mail_enabled_repos.txt 中"已启用邮件"的仓库,
#   若该仓库出现了新的提交 (HEAD 变化), 就调用 send_mail.ps1 发送一封通知,
#   正文列出本次新增/改动的文件。
#
# 设计要点:
#   1. 完全独立于各仓库的同步脚本, 不修改、不注入任何同步脚本, 通用且安全。
#   2. 是否发信由两层开关决定:
#        - 全局: ProgramData\GitAutoSync\mail_config.txt 的 enabled=1 (SMTP 总开关)
#        - 按仓库: mail_enabled_repos.txt 中是否包含该仓库路径
#   3. 首次见到某仓库只记录其当前 HEAD, 不发送 (避免历史积压群发)。
#   4. 服务以 SYSTEM 运行, 配置统一放在 %ProgramData%\GitAutoSync, 保证可读。
# ============================================================

$ErrorActionPreference = 'Continue'

$GA           = Join-Path $env:ProgramData 'GitAutoSync'
$SendMail     = Join-Path $GA 'send_mail.ps1'
$EnabledFile  = Join-Path $GA 'mail_enabled_repos.txt'
$StateFile    = Join-Path $GA 'mail_monitor_state.txt'
$LogFile      = Join-Path $GA 'mail_monitor.log'

# ---------- 日志 ----------
function Write-MMLog($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    try { [System.IO.File]::AppendAllText($LogFile, $line + "`r`n", [System.Text.Encoding]::UTF8) } catch { }
}

# ---------- 保存 HEAD 状态 ----------
function SaveState {
    $sb = New-Object System.Text.StringBuilder
    foreach ($k in $state.Keys) {
        [void]$sb.AppendLine("$k=$($state[$k])")
    }
    try { [System.IO.File]::WriteAllText($StateFile, $sb.ToString(), [System.Text.Encoding]::UTF8) } catch { }
}

# ---------- 读取上次已知 HEAD ----------
$state = @{}
if (Test-Path -LiteralPath $StateFile) {
    try {
        $raw = [System.IO.File]::ReadAllText($StateFile, [System.Text.Encoding]::UTF8)
        foreach ($l in ($raw -split "`r?`n")) {
            $t = $l.Trim()
            if ($t -and $t.Contains('=')) {
                $eq = $t.IndexOf('=')
                $state[$t.Substring(0, $eq).Trim()] = $t.Substring($eq + 1).Trim()
            }
        }
    } catch { }
}

Write-MMLog '邮件监控服务启动'

# ---------- 主循环 ----------
while ($true) {
    Start-Sleep -Seconds 30

    if (-not (Test-Path -LiteralPath $EnabledFile)) { continue }
    $repos = @()
    try {
        $repos = [System.IO.File]::ReadAllLines($EnabledFile, [System.Text.Encoding]::UTF8) | Where-Object { $_.Trim() }
    } catch { continue }

    foreach ($repo in $repos) {
        $repo = $repo.Trim()
        if (-not (Test-Path -LiteralPath (Join-Path $repo '.git'))) { continue }

        $head = $null
        try { $head = (git -C $repo rev-parse HEAD 2>$null) } catch { continue }
        if (-not $head) { continue }

        $prev = $state[$repo]
        if ($prev -eq $head) { continue }

        if ($null -eq $prev) {
            # 首次见到该仓库, 仅记录状态, 不发送
            $state[$repo] = $head
            SaveState
            continue
        }

        # 有新提交 -> 收集变更文件
        $files = $null
        try {
            $files = git -C $repo -c core.quotePath=false -c i18n.logOutputEncoding=UTF-8 diff --name-only $prev $head 2>$null
        } catch { }
        if (($null -eq $files) -or ($files.Count -eq 0)) {
            try {
                $files = git -C $repo -c core.quotePath=false -c i18n.logOutputEncoding=UTF-8 diff-tree --no-commit-id --name-only -r $head 2>$null
            } catch { }
        }

        $body = "仓库: $repo`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
        if ($files -and (($files | Where-Object { $_.Trim() }) -join '').Trim()) {
            $body += "`n变更文件:`n" + (($files | Where-Object { $_.Trim() }) -join "`n")
        } else {
            $body += "`n(本次仅有元数据/提交信息变化, 无具体文件差异)"
        }

        $subject = "[Git同步通知] $(Split-Path $repo -Leaf)"
        if (Test-Path -LiteralPath $SendMail) {
            try {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SendMail -Subject $subject -Body $body *> $null
            } catch {
                Write-MMLog ("[失败] 调用 send_mail 出错: " + $_.Exception.Message)
            }
        } else {
            Write-MMLog "[警告] 未找到 send_mail.ps1, 跳过: $repo"
        }

        $state[$repo] = $head
        SaveState
    }
}
