# ============================================================
# Git 自动同步工具包 - 邮件通知模块 (send_mail.ps1)
# ------------------------------------------------------------
# 用法:
#   powershell -NoProfile -ExecutionPolicy Bypass -File send_mail.ps1 -Subject "标题" -Body "正文"
# 可选:
#   -ConfigPath "自定义配置文件路径"
#
# 设计原则:
#   1. 未配置 或 enabled=0  -> 静默退出(exit 0)，绝不影响同步主流程
#   2. 发送失败             -> 仅记录日志，同样 exit 0，不中断同步
#   3. 配置保存在 %ProgramData%\GitAutoSync\mail_config.txt
#      原因: 同步服务以 LocalSystem 账号运行，配置若放用户目录服务读不到
# ============================================================

param(
    [string]$Subject = 'Git 自动同步通知',
    [string]$Body = '',
    [string]$ConfigPath = '',
    [string]$To = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ---- 配置文件路径: 优先公共目录，保证服务(SYSTEM)与当前用户都能读取 ----
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $programData = $env:ProgramData
    if ([string]::IsNullOrWhiteSpace($programData)) { $programData = $env:USERPROFILE }
    $ConfigPath = Join-Path $programData 'GitAutoSync\mail_config.txt'
}

$LogFile = Join-Path (Split-Path $ConfigPath -Parent) 'git_mail_notify.log'

function Write-MailLog($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    try { [System.IO.File]::AppendAllText($LogFile, $line + "`r`n", [System.Text.Encoding]::UTF8) } catch { }
    Write-Host $line
}

# ---- 未配置则静默跳过(不算错误) ----
if (-not (Test-Path -LiteralPath $ConfigPath)) { exit 0 }

# ---- 解析 key=value 配置 ----
$conf = @{}
try {
    $raw = [System.IO.File]::ReadAllText($ConfigPath, [System.Text.Encoding]::UTF8)
} catch { exit 0 }
foreach ($line in ($raw -split "`r?`n")) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    $idx = $t.IndexOf('=')
    if ($idx -le 0) { continue }
    $conf[$t.Substring(0, $idx).Trim()] = $t.Substring($idx + 1).Trim()
}

# ---- 总开关 ----
if ($conf['enabled'] -ne '1') { exit 0 }

$server = $conf['smtp_server']
$from   = $conf['from']
$pass   = $conf['password']
$to     = $conf['to']
if ($To -and $To.Trim()) { $to = $To.Trim() }

if (-not $server -or -not $from -or -not $pass -or -not $to) {
    Write-MailLog '[跳过] 邮件配置不完整 (smtp_server / from / password / to 为必填)'
    exit 0
}

$port = 465
if ($conf['smtp_port'] -match '^\d+$') { $port = [int]$conf['smtp_port'] }
$ssl = $true
if ($conf['use_ssl'] -eq '0') { $ssl = $false }

# ---- 发送频率节流 (notify_interval, 单位: 分钟) ----
# 0 或不配置 = 即时发送; >0 = 该分钟数内最多发送一封 (聚合通知, 避免刷屏)
# 说明: 推送成功本就在"有文件变化"时才触发, 所以成功邮件天然只在有变化时发
#       失败通知由同步脚本自身另带 30 分钟节流, 这里再做一层统一窗口控制
# 测试/手动发送请加 -Force 跳过节流, 否则也会被频率限制
$intervalMin = 0
if ($conf['notify_interval'] -match '^\d+$') { $intervalMin = [int]$conf['notify_interval'] }
if ($intervalMin -lt 0) { $intervalMin = 0 }
if (-not $Force -and $intervalMin -gt 0) {
    $lastNotifyFile = Join-Path (Split-Path $ConfigPath -Parent) 'last_notify.tmp'
    if (Test-Path -LiteralPath $lastNotifyFile) {
        $lastT = (Get-Item -LiteralPath $lastNotifyFile).LastWriteTime
        if (((Get-Date) - $lastT).TotalMinutes -lt $intervalMin) {
            exit 0
        }
    }
    try { New-Item -ItemType File -Path $lastNotifyFile -Force | Out-Null } catch { }
}

try {
    $msg = New-Object System.Net.Mail.MailMessage
    $msg.From = New-Object System.Net.Mail.MailAddress($from)
    foreach ($addr in ($to -split '[,;]')) {
        $a = $addr.Trim()
        if ($a) { [void]$msg.To.Add($a) }
    }
    $msg.Subject         = $Subject
    $msg.Body            = $Body
    $msg.SubjectEncoding = [System.Text.Encoding]::UTF8
    $msg.BodyEncoding    = [System.Text.Encoding]::UTF8
    $msg.BodyTransferEncoding = [System.Net.Mime.TransferEncoding]::Base64
    if ($msg | Get-Member HeadersEncoding) {
        $msg.HeadersEncoding = [System.Text.Encoding]::UTF8
    }

    $client = New-Object System.Net.Mail.SmtpClient($server, $port)
    $client.EnableSsl = $ssl
    $client.UseDefaultCredentials = $false
    $client.Credentials = New-Object System.Net.NetworkCredential($from, $pass)
    $client.Timeout = 20000
    try {
        $client.Send($msg)
        Write-MailLog "[OK] 邮件已发送 -> $to (主题: $Subject)"
    } finally {
        $client.Dispose()
        $msg.Dispose()
    }
    exit 0
} catch {
    # 取最内层异常, 让错误原因更具体
    # 例如: "无法连接到远程服务器" / "不允许使用邮箱名称..." / 认证失败
    $ex = $_.Exception
    $detail = $ex.Message
    while ($ex.InnerException) {
        $ex = $ex.InnerException
        $detail = $ex.Message
    }
    Write-MailLog ('[失败] 发送邮件出错: ' + $detail)
    exit 0
}
