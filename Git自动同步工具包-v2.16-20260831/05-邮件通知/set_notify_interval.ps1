# ============================================================
# Git 自动同步工具包 - 设置邮件发送频率 (set_notify_interval.ps1)
# ------------------------------------------------------------
# 用法:
#   powershell -NoProfile -ExecutionPolicy Bypass -File set_notify_interval.ps1 -Minutes 10
#
# 参数 -Minutes 取值:
#   0          = 即时 (每次有变化都发)
#   任意正整数 = 自定义分钟数 (如 15 / 30 / 90 / 120 ...)
#   默认推荐 10 分钟 (有变化才发)
# ============================================================

param([string]$Minutes = '')

$confPath = Join-Path $env:ProgramData 'GitAutoSync\mail_config.txt'

if (-not (Test-Path -LiteralPath $confPath)) {
    Write-Host '尚未配置邮件, 请先运行 [1] 开启并绑定 SMTP'
    Read-Host '按回车返回'
    exit 0
}

if ($Minutes -notmatch '^\d+$') {
    Write-Host "无效数值: $Minutes  (请填写 0 或任意正整数分钟, 如 15 / 30 / 90)"
    Read-Host '按回车返回'
    exit 0
}
[int]$m = [int]$Minutes

$lines = Get-Content -LiteralPath $confPath -Encoding Default
$idx = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^notify_interval=') { $idx = $i; break }
}
$newLine = "notify_interval=$m"
if ($idx -ge 0) { $lines[$idx] = $newLine } else { $lines = $lines + $newLine }
try {
    Set-Content -LiteralPath $confPath -Encoding Default -Value $lines -ErrorAction Stop
} catch {
    Write-Host "写入配置文件失败: $_"
    Write-Host "请通过 [以管理员身份运行] 的 邮件通知配置.bat 来设置频率"
    Read-Host '按回车返回'
    exit 1
}

$desc = if ($m -eq 0) { '即时 (每次变化都发)' } else { "$m 分钟" }
Write-Host "[OK] 已设置发送频率: $desc"
Start-Sleep -Milliseconds 1000
