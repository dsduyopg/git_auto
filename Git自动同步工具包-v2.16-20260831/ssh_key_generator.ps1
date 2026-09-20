# Git 自动同步工具包 · SSH 密钥生成器

$ErrorActionPreference = 'Continue'

function Ask-Input($prompt) {
    Write-Host $prompt -NoNewline
    return (Read-Host).Trim()
}

Write-Host '=============================================='
Write-Host '  SSH 密钥生成器（Gitee / GitHub 通用）'
Write-Host '=============================================='

$keyName = Ask-Input '1) 密钥名称 (回车默认 id_ed25519，可输 gitee_sync 等): '
if (-not $keyName) { $keyName = 'id_ed25519' }
if ($keyName -match '[\\/:*?"<>|]') {
    Write-Host '[错误] 名称包含非法字符，请重新运行'
    Read-Host '按回车退出'
    exit 1
}

$sshDir = Join-Path $env:USERPROFILE '.ssh'
if (-not (Test-Path -LiteralPath $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}
$keyPath = Join-Path $sshDir $keyName
$pubPath = "$keyPath.pub"

if (Test-Path -LiteralPath $keyPath) {
    Write-Host "[提示] 已存在密钥: $keyPath"
    $over = Ask-Input '       是否覆盖重新生成？(Y/N): '
    if ($over -notmatch '^[Yy]') {
        Write-Host '已取消，保留原密钥'
        Read-Host '按回车退出'
        exit 0
    }
    Remove-Item -LiteralPath $keyPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $pubPath -Force -ErrorAction SilentlyContinue
}

Write-Host '正在生成密钥...'
# 无口令 (-N "") 是必须的：NSSM 服务在后台非交互运行，带口令的密钥无法自动使用
# 用 cmd 执行，避免 PowerShell 吞掉空参数导致 ssh-keygen 报 "option requires an argument -- N"
$cmdLine = 'ssh-keygen -q -t ed25519 -f "' + $keyPath + '" -N ""'
$genOut = cmd /d /s /c $cmdLine 2>&1
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pubPath)) {
    Write-Host '[错误] 生成失败，详细信息如下：'
    $genOut | ForEach-Object { Write-Host "       $_" }
    Write-Host '       请检查 OpenSSH 客户端是否已安装：Windows 设置 -> 可选功能 -> OpenSSH 客户端'
    Read-Host '按回车退出'
    exit 1
}

$pub = Get-Content -LiteralPath $pubPath -Raw
Write-Host ''
Write-Host '=============================================='
Write-Host '  生成成功！公钥内容如下（已复制到剪贴板）：'
Write-Host '=============================================='
Write-Host $pub.Trim()
Write-Host ''
try { Set-Clipboard -Value $pub.Trim() } catch { }
Write-Host '下一步：'
Write-Host '  Gitee  : 登录 -> 设置 -> SSH公钥 -> 粘贴保存'
Write-Host '  GitHub : Settings -> SSH and GPG keys -> New SSH key'
Write-Host '  把上面的公钥内容粘贴进去保存即可。'
Write-Host ''
Read-Host '按回车退出'
