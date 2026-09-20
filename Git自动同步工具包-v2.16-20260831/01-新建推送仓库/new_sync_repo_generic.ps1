# ============================================================
# 一键新建同步仓库工具 - 通用版 (PowerShell)
# 运行方式: 双击 新建同步仓库-通用版.bat
# 通用版: 每个人的 SSH密钥/身份/nssm路径 都自行输入或自动检测
# 功能: 输入新仓库路径+平台+远端地址，自动完成：
#   1. 创建目录 + git init + 关联远端
#   2. 配置 SSH 密钥 / safe.directory / 身份
#   3. 生成该仓库的同步脚本 和 安装脚本
#   4. 打印下一步(运行安装脚本装服务)
# ============================================================

$ErrorActionPreference = 'Continue'

function Ask-Input($prompt) {
    Write-Host $prompt -NoNewline
    return (Read-Host).Trim()
}

Write-Host "=============================================="
Write-Host "  一键新建同步仓库工具 (通用版)"
Write-Host "=============================================="

# ========== 第 A 步: 检测/选择 SSH 私钥 ==========
Write-Host "--- 第 1 项: SSH 私钥 ---"
$homeDir = $env:USERPROFILE
$sshDir = Join-Path $homeDir '.ssh'
$foundKeys = @()
if (Test-Path $sshDir) {
    $foundKeys = Get-ChildItem $sshDir -File | Where-Object {
        $_.Name -notlike '*.pub' -and $_.Name -notmatch 'known_hosts|config|authorized_keys'
    }
}
if ($foundKeys.Count -gt 0) {
    Write-Host "检测到以下 SSH 私钥(请输入编号选择):"
    for ($i = 0; $i -lt $foundKeys.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $foundKeys[$i].FullName)
    }
    $pick = Ask-Input "  请输入编号(或直接粘贴密钥完整路径): "
    if ($pick -match '^\d+$' -and [int]$pick -ge 1 -and [int]$pick -le $foundKeys.Count) {
        $SSHKeyPath = $foundKeys[[int]$pick - 1].FullName
    } else {
        $SSHKeyPath = $pick
    }
} else {
    $SSHKeyPath = Ask-Input "未检测到密钥，请粘贴 SSH 私钥完整路径: "
}
# 转成带/的路径供 ssh -i 使用
$SSHKeyPath = $SSHKeyPath -replace '\\', '/'
if (-not (Test-Path ($SSHKeyPath -replace '/', '\'))) {
    Write-Host "[警告] 找不到私钥文件: $SSHKeyPath"
    Write-Host "       程序会继续，但同步可能因认证失败。请确认密钥已添加到 Gitee/GitHub。"
}

# ========== 第 B 步: git 身份 ==========
Write-Host "--- 第 2 项: git 提交身份 ---"
$GitName  = Ask-Input "  请输入 user.name (如 your-name): "
$GitEmail = Ask-Input "  请输入 user.email (如 xxx@qq.com): "
if (-not $GitName)  { $GitName  = 'your-name' }
if (-not $GitEmail) { $GitEmail = 'your@email.com' }

# ========== 第 C 步: 定位 nssm.exe ==========
Write-Host "--- 第 3 项: nssm.exe 路径 ---"
$candidates = @(
    # 优先找工具包内自带的 nssm
    (Join-Path (Split-Path $PSScriptRoot -Parent) '04-一键部署\nssm_bin\nssm.exe'),
    'C:\nssm\nssm.exe',
    'C:\Program Files\nssm\nssm.exe'
)
$NssmExe = $null
foreach ($c in $candidates) {
    if (Test-Path $c) { $NssmExe = $c; break }
}
if (-not $NssmExe -and (Get-Command nssm -ErrorAction SilentlyContinue)) {
    $NssmExe = (Get-Command nssm).Source
}
if (-not $NssmExe) {
    $NssmExe = Ask-Input "未找到 nssm，请粘贴 nssm.exe 完整路径: "
}
Write-Host "  使用 nssm: $NssmExe"

# ========== 第 1 步: 仓库路径 ==========
$repoPath = Ask-Input "1) 新仓库本地路径 (如 D:\新项目): "
if (-not $repoPath) { Write-Host "[错误] 路径不能为空"; exit 1 }

# ========== 第 1.5 步: 排除目录/文件(可选) ==========
$ignoreRaw = Ask-Input "1.5) 不推送的目录/文件，多个用逗号分隔 (如 my_data\secret, logs，回车跳过): "

# ========== 第 2 步: 平台 ==========
Write-Host "2) 选择平台:"
Write-Host "     [1] Gitee   [2] GitHub"
$plat = Ask-Input "    请输入 1 或 2: "
$defaultBranch = if ($plat -eq '2') { 'main' } else { 'master' }
$platName = if ($plat -eq '2') { 'GitHub' } else { 'Gitee' }
$branch = Ask-Input "    分支 (回车默认 $defaultBranch): "
if (-not $branch) { $branch = $defaultBranch }

# ========== 第 3 步: 远端地址 ==========
$remoteUrl = Ask-Input "3) 远端 SSH 地址 (如 git@gitee.com:用户/仓库.git): "
if (-not $remoteUrl) { Write-Host "[错误] 远端地址不能为空"; exit 1 }
Write-Host "   平台: $platName  分支: $branch"
Write-Host ""

# 创建目录
if (-not (Test-Path $repoPath)) {
    New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
    Write-Host "[OK] 已创建目录: $repoPath"
} else {
    Write-Host "[提示] 目录已存在: $repoPath"
}

# 解析排除项为仓库内相对路径
$repoFull = [IO.Path]::GetFullPath($repoPath).TrimEnd('\')
$IgnorePaths = @()
if ($ignoreRaw) {
    foreach ($item in ($ignoreRaw -split '[,，]')) {
        $item = $item.Trim().Trim('\','/')
        if (-not $item) { continue }
        $full = if ([IO.Path]::IsPathRooted($item)) { [IO.Path]::GetFullPath($item) } else { [IO.Path]::GetFullPath((Join-Path $repoPath $item)) }
        if ($full -ne $repoFull -and -not $full.StartsWith($repoFull + '\')) {
            Write-Host "[警告] 排除项不在仓库内，已跳过: $item"
            continue
        }
        $rel = $full.Substring($repoFull.Length).TrimStart('\','/')
        if (Test-Path -LiteralPath $full -PathType Container) { $rel = $rel.TrimEnd('/','\') + '/' }
        $IgnorePaths += $rel
    }
}

# git init
if (-not (Test-Path (Join-Path $repoPath '.git'))) {
    git -C $repoPath init 2>&1 | Out-Null
    Write-Host "[OK] 已 git init"
}
# 分支重命名
git -C $repoPath branch -m $branch 2>&1 | Out-Null

# 关联远端(GitHub 自动转 443)
if ($remoteUrl -match '^git@github\.com:(.+)$') {
    $remoteUrl = "ssh://git@ssh.github.com:443/$($Matches[1])"
    Write-Host "[提示] GitHub 已自动改用 443 端口: $remoteUrl"
}
if ((git -C $repoPath remote) -contains 'origin') {
    git -C $repoPath remote remove origin 2>&1 | Out-Null
}
git -C $repoPath remote add origin $remoteUrl
$safeDir = $repoPath -replace '\\', '/'
Write-Host "[OK] 已关联远端: $remoteUrl"

# 配置
$sshCmd = "ssh -i `"$SSHKeyPath`" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
git -C $repoPath config core.sshCommand $sshCmd
git -C $repoPath config --local --add safe.directory $repoPath
git -C $repoPath config --local user.name $GitName
git -C $repoPath config --local user.email $GitEmail
Write-Host "[OK] 已配置 SSH 密钥 / safe.directory / 身份"

# 拉取远端已有内容
Write-Host "[*] 尝试拉取远端内容(若远端为空会自动跳过)..."
$pullOut = git -C $repoPath pull origin $branch 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[提示] 首次拉取未成功(空仓库或分支不一致属正常):"
    $pullOut | ForEach-Object { Write-Host "       $_" }
}

# 生成文件名 / 服务名
$repoName = Split-Path $repoPath -Leaf
$svcBase = ($repoName -replace '[^A-Za-z0-9_]', '')
if (-not $svcBase) { $svcBase = 'Repo' }
$svcName = "GitAutoSync_$svcBase"
if ($svcBase -ne $repoName) {
    # 中文/特殊字符目录名会被剔除，追加路径哈希保证服务名唯一
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($repoPath.ToLowerInvariant()))
    $shortHash = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').Substring(0, 6)
    $svcName = "GitAutoSync_${svcBase}_$shortHash"
}
$syncFile = Join-Path $repoPath "git_sync_realtime_$svcName.ps1"
$installPs1 = Join-Path $repoPath 'install_service.ps1'
$installBat = Join-Path $repoPath '安装服务.bat'

# 写 .gitignore
$giLines = @(
    '# 忽略日志和同步文件',
    'sync.log',
    'git_sync*.log',
    'git_sync_service*.log',
    'status.tmp',
    '# 系统文件',
    '.DS_Store',
    'Thumbs.db'
)
if ($IgnorePaths.Count -gt 0) {
    $giLines += ''
    $giLines += '# 自定义排除：不推送到云端'
    foreach ($p in $IgnorePaths) { $giLines += $p }
}
$gi = $giLines -join "`r`n"
Set-Content -Path (Join-Path $repoPath '.gitignore') -Value $gi -Encoding utf8
Write-Host "[OK] 已生成 .gitignore"
foreach ($p in $IgnorePaths) {
    $gitPath = $p.TrimEnd('/')
    $tracked = git -C $repoPath ls-files -- $gitPath
    if ($tracked) {
        git -C $repoPath rm -r --cached --quiet --ignore-unmatch -- $gitPath
        Write-Host "[OK] 已从 Git 索引移除（本地文件保留）: $p"
    }
}

# 生成同步脚本
$syncTmpl = @'
# ============================================================
# Git 实时自动同步脚本 - 自动生成
# 路径: __REPOPATH__  ->  __REMOTE__ (origin/__BRANCH__)
# ============================================================

$ErrorActionPreference = 'Continue'

$RepoPath      = '__REPOPATH__'
$Branch        = '__BRANCH__'
$Remote        = 'origin'
$LogFile       = Join-Path $RepoPath 'git_sync.log'
$DebounceMs    = 3000
$RetryTimes    = 3
$RetryWaitSec  = 5
$IgnoredPaths  = __IGNORED_PATHS__

if (-not (Test-Path $RepoPath)) {
    Write-Host "错误：目录不存在 $RepoPath"
    exit 1
}
Set-Location $RepoPath

function Write-Log {
    param([string]$Msg)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg
    $line | Out-File -FilePath $LogFile -Append -Encoding utf8
    Write-Host $line
}

Write-Log '============================================'
Write-Log 'Git 实时同步脚本启动'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Log '错误：未找到 git 命令，请先安装 Git'
    exit 1
}
if (-not (Test-Path (Join-Path $RepoPath '.git'))) {
    Write-Log '错误：该目录不是 git 仓库'
    exit 1
}
$hasRemote = (git -C $RepoPath remote) -match "^$Remote$"
if (-not $hasRemote) {
    Write-Log "错误：未配置远程仓库 $Remote`n请先执行: git remote add $Remote <仓库地址>"
    exit 1
}

function Should-Ignore {
    param([string]$FullPath)
    if ($FullPath -like "$RepoPath\.git*") { return $true }
    if ($FullPath -like "$RepoPath\git_sync*") { return $true }
    foreach ($p in $IgnoredPaths) {
        $pWin = $p -replace '/', '\'
        $target = Join-Path $RepoPath $pWin
        if ($FullPath -eq $target -or $FullPath -like "$target\*") { return $true }
    }
    return $false
}

function Test-GitBusy {
    # 是否有其他 git 进程正在使用本仓库
    $procs = Get-CimInstance Win32_Process -Filter "Name='git.exe'" -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        if ($p.CommandLine -and ($p.CommandLine -match [regex]::Escape($RepoPath))) { return $true }
    }
    return $false
}

function Clear-StaleLock {
    # 清理残留的 index.lock（无活跃 git 进程时才清理）
    $lock = Join-Path $RepoPath '.git\index.lock'
    if (Test-Path $lock) {
        if (Test-GitBusy) {
            Write-Log "index.lock 存在但 git 进程忙碌，等待其释放..."
            return $false
        }
        Write-Log "检测到残留 index.lock，正在清理..."
        Remove-Item $lock -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $lock)) { Write-Log "残留锁已清理" }
    }
    return $true
}

# ---- 邮件通知(可选功能) ----
# 未配置 SMTP 时整段自动跳过, 不启动任何额外进程, 行为与未集成时完全一致
# 失败通知默认 30 分钟节流, 避免持续失败时反复发信
$MailHelper   = '__MAIL_HELPER__'
$MailConfPath = Join-Path $env:ProgramData 'GitAutoSync\mail_config.txt'
$MailThrottle = Join-Path $RepoPath 'git_sync_mail_throttle.tmp'

function Send-MailNotify {
    param([string]$Title, [string]$Content, [switch]$Throttle)
    if (-not $MailHelper) { return }
    if (-not (Test-Path -LiteralPath $MailHelper)) { return }
    if (-not (Test-Path -LiteralPath $MailConfPath)) { return }
    if ($Throttle) {
        if (Test-Path -LiteralPath $MailThrottle) {
            $last = (Get-Item -LiteralPath $MailThrottle).LastWriteTime
            if (((Get-Date) - $last).TotalMinutes -lt 30) { return }
        }
        try { New-Item -ItemType File -Path $MailThrottle -Force | Out-Null } catch { }
    }
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $MailHelper -Subject $Title -Body $Content
    } catch { }
}

# 获取本次提交变更文件列表（处理 UTF-8 中文文件名）
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

function Sync-Now {
    try {
        Clear-StaleLock
        $addOut = git -C $RepoPath add -A 2>&1
        if ($LASTEXITCODE -ne 0) { Write-Log "git add 失败：$addOut"; return }
        $status = git -C $RepoPath status --porcelain
        if ([string]::IsNullOrWhiteSpace($status)) { Write-Log '无实际文件变动，跳过提交'; return }
        $msg = "auto-sync: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        $commitOut = git -C $RepoPath commit -m $msg 2>&1
        if ($LASTEXITCODE -ne 0) { Write-Log "git commit 失败：$commitOut"; return }
        Write-Log "已提交：$msg"
        for ($i = 1; $i -le $RetryTimes; $i++) {
            $pushOut = git -C $RepoPath push $Remote $Branch 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "推送成功 -> $Remote/$Branch"
                $syncFiles = Get-ChangedFiles -Path $RepoPath
                Send-MailNotify -Title "同步成功: $RepoPath" -Content "仓库: $RepoPath`n分支: $Remote/$Branch`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n结果: 推送成功`n`n变更文件:`n$syncFiles"
                return
            }
            Write-Log "推送失败(第 $i/$RetryTimes 次)：$pushOut"
            Start-Sleep -Seconds $RetryWaitSec
        }
        Write-Log '推送失败，超过重试次数，将在下次变化时重试'
        $failedFiles = (git -C $RepoPath -c core.quotePath=false diff-tree --no-commit-id --name-only -r HEAD) -join "`n"
        Send-MailNotify -Title "同步失败: $RepoPath" -Content "仓库: $RepoPath`n分支: $Remote/$Branch`n时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n结果: 推送失败(已重试 $RetryTimes 次)`n错误: $pushOut`n`n变更文件:`n$failedFiles" -Throttle
        Clear-StaleLock
    } catch {
        Write-Log "同步出错：$_"
        Clear-StaleLock
    }
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path                  = $RepoPath
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter          = [System.IO.NotifyFilters]::LastWrite -bor `
                                 [System.IO.NotifyFilters]::FileName -bor `
                                 [System.IO.NotifyFilters]::DirectoryName -bor `
                                 [System.IO.NotifyFilters]::Size
$watcher.EnableRaisingEvents   = $true

$null = Register-ObjectEvent $watcher Created -SourceIdentifier Sync.Created
$null = Register-ObjectEvent $watcher Changed -SourceIdentifier Sync.Changed
$null = Register-ObjectEvent $watcher Renamed -SourceIdentifier Sync.Renamed
$null = Register-ObjectEvent $watcher Deleted -SourceIdentifier Sync.Deleted

Write-Log '启动时执行一次完整同步...'
Sync-Now
Write-Log "开始实时监听目录：$RepoPath（按 Ctrl+C 停止）"

while ($true) {
    $e = Wait-Event -Timeout 1
    if ($null -eq $e) { continue }
    $evArgs = $e.SourceEventArgs
    if ($null -ne $evArgs -and (Should-Ignore $evArgs.FullPath)) {
        Remove-Event -EventIdentifier $e.EventIdentifier
        continue
    }
    Remove-Event -EventIdentifier $e.EventIdentifier
    Start-Sleep -Milliseconds $DebounceMs
    while ($null -ne ($tmp = Wait-Event -Timeout 0)) {
        Remove-Event -EventIdentifier $tmp.EventIdentifier
    }
    Write-Log '检测到文件变化，开始同步...'
    Sync-Now
}
'@
if ($IgnorePaths.Count -gt 0) {
    $ignoreArray = "(@(`r`n"
    foreach ($p in $IgnorePaths) { $ignoreArray += "    '$($p -replace '\\','/')'`r`n" }
    $ignoreArray += ")"
} else {
    $ignoreArray = '@()'
}
# 定位邮件通知模块(05- 开头目录下的 send_mail.ps1), 找不到则留空 = 不启用
$mailHelper = ''
$toolRoot = Split-Path $PSScriptRoot -Parent
$mailDir = Get-ChildItem -Path $toolRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '05*' } | Select-Object -First 1
if ($mailDir) {
    $mailCand = Join-Path $mailDir.FullName 'send_mail.ps1'
    if (Test-Path -LiteralPath $mailCand) { $mailHelper = $mailCand }
}
$syncScript = $syncTmpl -replace '__REPOPATH__', $repoPath `
                       -replace '__BRANCH__', $branch `
                       -replace '__REMOTE__', $remoteUrl `
                       -replace '__MAIL_HELPER__', $mailHelper `
                       -replace '__IGNORED_PATHS__', $ignoreArray
[System.IO.File]::WriteAllText($syncFile, $syncScript, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "[OK] 已生成同步脚本: $syncFile"

# 生成安装 bat(完全写死服务名,无变量,避免环境干扰)
$SVC   = $svcName
$REPO  = $repoPath
$SYNC  = $syncFile
$LOG   = Join-Path $repoPath 'git_sync_service.log'
$LOGERR = Join-Path $repoPath 'git_sync_service_err.log'
$SAFE  = $repoPath -replace '\\', '/'
$batContent = "@echo off`r`n" +
              "chcp 65001 >nul`r`n" +
              "set `"NSSM=$NssmExe`"`r`n" +
              "`"%NSSM%`" stop $SVC >nul 2>&1`r`n" +
              "`"%NSSM%`" remove $SVC confirm >nul 2>&1`r`n" +
              "`"%NSSM%`" install $SVC `"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`" `"-NoProfile -ExecutionPolicy Bypass -File `"`"$SYNC`"`"`"`r`n" +
              "`"%NSSM%`" set $SVC ObjectName LocalSystem`r`n" +
              "`"%NSSM%`" set $SVC AppDirectory `"$REPO`"`r`n" +
              "`"%NSSM%`" set $SVC Start SERVICE_AUTO_START`r`n" +
              "`"%NSSM%`" set $SVC AppExit Default Restart`r`n" +
              "`"%NSSM%`" set $SVC AppRestartDelay 5000`r`n" +
              "`"%NSSM%`" set $SVC AppStdout `"$LOG`"`r`n" +
              "`"%NSSM%`" set $SVC AppStderr `"$LOGERR`"`r`n" +
              "`"%NSSM%`" set $SVC AppRotateFiles 1`r`n" +
              "`"%NSSM%`" set $SVC AppRotateBytes 1048576`r`n" +
              "`"%NSSM%`" set $SVC AppEnvironmentExtra GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0=`"$SAFE`"`r`n" +
              "`"%NSSM%`" start $SVC`r`n" +
              "echo.`r`npause`r`n"
[System.IO.File]::WriteAllText($installBat, $batContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[OK] 已生成安装脚本: $installBat"

Write-Host ""
Write-Host "=============================================="
Write-Host "  配置完成！"
Write-Host "  目录   : $repoPath"
Write-Host "  服务名 : $svcName"
Write-Host "  平台   : $platName ($branch)"
Write-Host "  排除项 : $($IgnorePaths -join ', ')"
Write-Host ""
Write-Host "  下一步：右键 [ $installBat ] -> 以管理员身份运行"
Write-Host "          即可安装并启动自动同步服务"
Write-Host "=============================================="
