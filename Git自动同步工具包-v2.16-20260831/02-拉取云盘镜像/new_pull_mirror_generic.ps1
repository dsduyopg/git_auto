# ============================================================
# 新建云端拉取镜像工具 - 通用版 (new_pull_mirror_generic.ps1)
# 任意远端仓库 -> 克隆/更新到任意指定路径
# 可选择 ~/.ssh 下的 SSH 密钥,并把密钥记入配置文件
# ============================================================

$ErrorActionPreference = 'Continue'
$ConfigFile = Join-Path $env:USERPROFILE 'git_mirror_config.txt'

# ---- 列出 SSH 私钥,让用户选择 ----
function Find-SshKeys {
    $sshDir = Join-Path $env:USERPROFILE '.ssh'
    if (Test-Path $sshDir) {
        return @(Get-ChildItem $sshDir -File | Where-Object {
            $_.Name -notlike '*.pub' -and $_.Name -notmatch 'known_hosts|config|authorized_keys'
        } | Select-Object -ExpandProperty FullName)
    }
    return @()
}
$keyList = @(Find-SshKeys)
if ($keyList.Count -eq 0) {
    Write-Host "[错误] 未找到 SSH 私钥。请先运行 生成SSH密钥.bat,或手动执行 ssh-keygen"
    Write-Host "      并把公钥(.pub)内容添加到你的 Gitee/GitHub 账号"
    exit 1
}
$sshKey = $null
if ($keyList.Count -eq 1) {
    $sshKey = $keyList[0]
} else {
    Write-Host "检测到以下 SSH 私钥,请选择本次拉取使用的密钥:"
    for ($i = 0; $i -lt $keyList.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $keyList[$i])
    }
    $pick = (Read-Host '  请输入编号: ').Trim()
    $idx = 0
    if (-not [int]::TryParse($pick, [ref]$idx) -or $idx -lt 1 -or $idx -gt $keyList.Count) {
        Write-Host "[错误] 编号无效"
        exit 1
    }
    $sshKey = $keyList[$idx - 1]
}
$env:GIT_SSH_COMMAND = "ssh -i `"$($sshKey -replace '\\','/')`" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
Write-Host "[提示] 使用 SSH 密钥: $sshKey"

function Ask-Input($prompt) {
    Write-Host $prompt -NoNewline
    return (Read-Host).Trim()
}

Write-Host "=============================================="
Write-Host "  新建云端拉取镜像工具 (通用版)"
Write-Host "=============================================="

# 1. 远端地址
$remoteUrl = Ask-Input "1) 远端 SSH 地址 (如 git@gitee.com:user/repo.git): "
if (-not $remoteUrl) { Write-Host "[错误] 地址不能为空"; exit 1 }

# 2. GitHub 自动转 443
$isGitHub = $remoteUrl -match 'github'
if ($remoteUrl -match '^git@github\.com:(.+)$') {
    $remoteUrl = "ssh://git@ssh.github.com:443/$($Matches[1])"
    Write-Host "[提示] GitHub 已自动改用 443 端口"
}

# 3. 目标目录(默认取仓库名;输入含路径分隔符则视为完整路径)
$defaultName = ''
if ($remoteUrl -match '/([^/]+)\.git$') { $defaultName = $Matches[1] }
$repoName = Ask-Input "2) 目标目录 (回车默认: $defaultName): "
if (-not $repoName) { $repoName = $defaultName }
if (-not $repoName) { $repoName = 'mirror' }
if ($repoName -match '[\\/]') {
    $targetDir = $repoName.TrimEnd('\', '/')
    Write-Host "[提示] 检测到完整路径,目标目录: $targetDir"
} else {
    $targetDir = Join-Path (Get-Location) $repoName
}

# 4. 分支
$defaultBranch = if ($isGitHub) { 'main' } else { 'master' }
$branch = Ask-Input "3) 分支 (回车默认: $defaultBranch): "
if (-not $branch) { $branch = $defaultBranch }

# 5. 追加到配置文件
if (-not (Test-Path $ConfigFile)) {
    New-Item -ItemType File -Path $ConfigFile -Force | Out-Null
}
$content = if (Test-Path $ConfigFile) { [System.IO.File]::ReadAllText($ConfigFile) } else { '' }
$entry = "$targetDir|$remoteUrl|$branch|$sshKey"
$key3 = "$targetDir|$remoteUrl|$branch"
$isDup = $content -split "`r?`n" | Where-Object { $t = $_.Trim(); $t -and (($t -split '\|')[0..2] -join '|') -eq $key3 }
if ($isDup) {
    Write-Host "[提示] 该镜像配置已存在，跳过重复登记"
} else {
    if ($content -and -not $content.EndsWith("`n")) { $content += "`n" }
    $content += "$entry`n"
    [System.IO.File]::WriteAllText($ConfigFile, $content, (New-Object System.Text.UTF8Encoding($false)))
}
Write-Host ""
Write-Host "[OK] 已登记: $targetDir  <-  $remoteUrl  ($branch)"
Write-Host ""

# 6. 立即拉取
Write-Host "--- 立即拉取到 $targetDir ---"
$gitDir = Join-Path $targetDir '.git'
if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
if (-not (Test-Path $gitDir)) {
    $out = git clone $remoteUrl $targetDir 2>&1
    if ($LASTEXITCODE -eq 0) {
        git -C $targetDir checkout $branch 2>&1 | Out-Null
        Write-Host "[OK] 已克隆到 $targetDir"
    } else {
        Write-Host "[失败] 克隆失败: $out"
    }
} else {
    git -C $targetDir remote set-url origin $remoteUrl 2>&1 | Out-Null
    $fOut = git -C $targetDir fetch origin $branch 2>&1
    if ($LASTEXITCODE -eq 0) {
        git -C $targetDir reset --hard "origin/$branch" 2>&1 | Out-Null
        Write-Host "[OK] 已更新到云端最新"
    } else {
        Write-Host "[失败] 更新失败: $fOut"
    }
}

Write-Host ""
Write-Host "=============================================="
Write-Host "  完成! 配置保存在: $ConfigFile"
Write-Host "  (如需定时自动更新,可配合 change_fetcher 使用)"
Write-Host "=============================================="
