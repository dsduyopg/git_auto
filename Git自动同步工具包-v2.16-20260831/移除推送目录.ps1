# ============================================================
# 移除/排除推送目录或文件
# 功能: 让已存在的 Git 仓库不再把某个目录/文件推送到云端
# 运行方式: 双击 移除推送目录.bat
# ============================================================

$ErrorActionPreference = 'Continue'

function Ask-Input($prompt) {
    Write-Host $prompt -NoNewline
    return (Read-Host).Trim()
}

$repoPath = Ask-Input "1) Git 仓库本地路径 (如 D:\我的项目): "
if (-not $repoPath) { Write-Host "[错误] 路径不能为空"; exit 1 }

$candidate = [IO.Path]::GetFullPath($repoPath)
$foundRepo = $null
$probe = $candidate
while ($probe) {
    if (Test-Path -LiteralPath (Join-Path $probe '.git')) { $foundRepo = $probe; break }
    $parent = Split-Path $probe -Parent
    if (-not $parent -or $parent -eq $probe) { break }
    $probe = $parent
}
if (-not $foundRepo) {
    Write-Host "[错误] 未找到 Git 仓库，请确认路径: $repoPath"
    exit 1
}

$isSubPath = [string]::Compare($candidate, $foundRepo, $true) -ne 0
if ($isSubPath) {
    $targetPath = $candidate.Substring($foundRepo.Length).TrimStart('\','/')
    Write-Host "[提示] 已自动定位到 Git 仓库: $foundRepo"
    Write-Host "       将停止推送仓库内路径: $targetPath"
} else {
    $targetPath = Ask-Input "2) 要停止推送的目录/文件 (仓库内路径，如 my_data\secret): "
    if (-not $targetPath) { Write-Host "[错误] 目录/文件不能为空"; exit 1 }
}

$repoPath = $foundRepo
$repoFull = [IO.Path]::GetFullPath($repoPath).TrimEnd('\')

$full = [IO.Path]::GetFullPath((Join-Path $repoFull $targetPath))
if ($full -ne $repoFull -and -not $full.StartsWith($repoFull + '\')) {
    Write-Host "[错误] 该路径不在仓库内: $targetPath"
    exit 1
}
$rel = $full.Substring($repoFull.Length).TrimStart('\','/') -replace '\\','/'
if (-not $rel) { Write-Host "[错误] 不能排除整个仓库根目录"; exit 1 }
$isDir = Test-Path -LiteralPath $full -PathType Container
$giLine = if ($isDir) { $rel.TrimEnd('/') + '/' } else { $rel }

# 写入 .gitignore
$giPath = Join-Path $repoFull '.gitignore'
$lines = @()
if (Test-Path -LiteralPath $giPath) {
    $lines = @([System.IO.File]::ReadAllLines($giPath))
}
if ($lines -notcontains $giLine) {
    if ($lines.Count -gt 0 -and $lines[-1] -ne '') { $lines += '' }
    if ($lines.Count -eq 0 -or $lines[-1] -ne '# 自定义排除：不推送到云端') {
        $lines += '# 自定义排除：不推送到云端'
    }
    $lines += $giLine
    [System.IO.File]::WriteAllLines($giPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "[OK] 已写入 .gitignore: $giLine"
} else {
    Write-Host "[提示] .gitignore 已包含: $giLine"
}

# 从 Git 索引移除（本地文件保留）
$gitPath = $rel.TrimEnd('/')
$tracked = git -C $repoFull ls-files -- $gitPath
if ($tracked) {
    git -C $repoFull rm -r --cached --quiet --ignore-unmatch -- $gitPath
    Write-Host "[OK] 已从 Git 索引移除，本地文件保留: $rel"
} else {
    Write-Host "[提示] 该路径尚未被 Git 跟踪，无需移除: $rel"
}

# 更新本仓库已有的实时同步脚本
$syncScripts = @(Get-ChildItem -LiteralPath $repoFull -Filter 'git_sync_realtime_*.ps1' -File -ErrorAction SilentlyContinue)
foreach ($script in $syncScripts) {
    $text = [System.IO.File]::ReadAllText($script.FullName)
    $pWin = $giLine.TrimEnd('/') -replace '/','\'
    if ($text -notlike "*$rel*" -and $text -notlike "*$pWin*") {
        $marker = 'if ($FullPath -like "$RepoPath\git_sync*") { return $true }'
        $insert = "`r`n    if (`$FullPath -eq `"`$RepoPath\$pWin`" -or `$FullPath -like `"`$RepoPath\$pWin\*`") { return `$true }"
        if ($text.Contains($marker)) {
            $text = $text.Replace($marker, $marker + $insert)
            [System.IO.File]::WriteAllText($script.FullName, $text, (New-Object System.Text.UTF8Encoding($true)))
            Write-Host "[OK] 已更新同步脚本: $($script.Name)"
        } else {
            Write-Host "[提示] 未识别同步脚本格式，请手动检查: $($script.Name)"
        }
    }
}

Write-Host ""
$doCommit = Ask-Input "是否现在提交并推送？(Y/N，回车默认 N): "
if ($doCommit -match '^[Yy]') {
    git -C $repoFull add -A
    git -C $repoFull commit -m "chore: stop tracking $rel"
    $branch = git -C $repoFull branch --show-current
    if ($branch) { git -C $repoFull push origin $branch }
}
Write-Host ""
Read-Host "完成。若同步服务正在运行，重启对应服务后新的排除规则才生效。按回车退出"
