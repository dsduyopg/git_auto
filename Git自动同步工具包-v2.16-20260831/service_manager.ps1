# Git 自动同步工具包 · 服务管理菜单

$ErrorActionPreference = 'Continue'
$nssm = Join-Path $PSScriptRoot '04-一键部署\nssm_bin\nssm.exe'
if (-not (Test-Path -LiteralPath $nssm)) { $nssm = 'C:\nssm\nssm.exe' }

function Get-SyncServices {
    Get-Service -Name 'GitAutoSync*','GitMirrorFetcher' -ErrorAction SilentlyContinue | Sort-Object Name
}

function Get-RepoPathFromService {
    param([System.ServiceProcess.ServiceController]$svc)
    $params = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)\Parameters"
    $repo = $null
    if (Test-Path -LiteralPath $params) {
        $p = Get-ItemProperty -LiteralPath $params -ErrorAction SilentlyContinue
        if ($p.AppDirectory) {
            $repo = [string]$p.AppDirectory
        } elseif ($p.AppParameters -match '-File\s+"?([^"]+?\.ps1)"?') {
            $repo = Split-Path $Matches[1]
        }
    }
    return $repo
}

function Show-Status {
    Write-Host ''
    Write-Host '--- 同步服务状态 ---'
    $s = Get-SyncServices
    if (-not $s) {
        Write-Host '未找到同步服务，请先使用 新建自动推送仓库 或 安装定时拉取服务'
    } else {
        $s | Format-Table Status,Name -AutoSize
    }
    Write-Host ''
    Read-Host '按回车返回菜单'
}

function Start-All {
    Write-Host ''
    $s = Get-SyncServices
    if (-not $s) {
        Write-Host '未找到同步服务，请先使用 新建自动推送仓库 或 安装定时拉取服务'
    }
    foreach ($x in $s) {
        if ($x.Status -ne 'Running') {
            Start-Service $x.Name -ErrorAction Continue
            Write-Host "已启动: $($x.Name)"
        } else {
            Write-Host "已在运行: $($x.Name)"
        }
    }
    Write-Host ''
    Read-Host '按回车返回菜单'
}

function Stop-All {
    Write-Host ''
    $s = Get-SyncServices
    if (-not $s) {
        Write-Host '未找到同步服务'
    }
    foreach ($x in $s) {
        Stop-Service $x.Name -Force -ErrorAction SilentlyContinue
        Write-Host "已停止: $($x.Name)"
    }
    Write-Host ''
    Read-Host '按回车返回菜单'
}

function Select-Service {
    $s = Get-SyncServices
    if (-not $s) {
        Write-Host '未找到同步服务'
        Read-Host '按回车返回菜单'
        return $null
    }
    Write-Host '可操作的同步服务：'
    for ($i = 0; $i -lt $s.Count; $i++) {
        Write-Host ("  [{0}] {1}  {2}" -f ($i + 1), $s[$i].Name, $s[$i].Status)
        $repo = Get-RepoPathFromService -svc $s[$i]
        if ($repo) { Write-Host "      仓库路径: $repo" }
    }
    $pick = Read-Host '请输入服务编号'
    $idx = 0
    if (-not [int]::TryParse($pick, [ref]$idx) -or $idx -lt 1 -or $idx -gt $s.Count) {
        Write-Host '编号无效'
        Read-Host '按回车返回菜单'
        return $null
    }
    return $s[$idx - 1]
}

function Start-One {
    Write-Host ''
    $svc = Select-Service
    if ($null -eq $svc) { return }
    if ($svc.Status -ne 'Running') {
        Start-Service $svc.Name -ErrorAction Continue
        Write-Host "已启动: $($svc.Name)"
    } else {
        Write-Host "已在运行: $($svc.Name)"
    }
    Read-Host '按回车返回菜单'
}

function Stop-One {
    Write-Host ''
    $svc = Select-Service
    if ($null -eq $svc) { return }
    Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
    Write-Host "已停止: $($svc.Name)"
    Read-Host '按回车返回菜单'
}

function Restart-One {
    Write-Host ''
    $svc = Select-Service
    if ($null -eq $svc) { return }
    $repo = Get-RepoPathFromService -svc $svc
    if ($repo) { Write-Host "仓库路径: $repo" }
    Write-Host "正在重启: $($svc.Name) ..."
    Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    Start-Service $svc.Name -ErrorAction Continue
    Start-Sleep -Milliseconds 500
    $after = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($after -and $after.Status -eq 'Running') {
        Write-Host "已重启并运行: $($svc.Name)"
    } elseif ($after -and $after.Status -eq 'Stopped') {
        Write-Host "服务已停止，启动失败或已被禁用，请查看日志"
    } else {
        Write-Host "重启完成，请按 [1] 查看状态确认"
    }
    Read-Host '按回车返回菜单'
}

function Remove-One {
    Write-Host ''
    $s = Get-SyncServices
    if (-not $s) {
        Write-Host '未找到同步服务'
        Read-Host '按回车返回菜单'
        return
    }
    Write-Host '可卸载的同步服务：'
    for ($i = 0; $i -lt $s.Count; $i++) {
        Write-Host ("  [{0}] {1}  {2}" -f ($i + 1), $s[$i].Name, $s[$i].Status)
    }
    $pick = Read-Host '请输入要卸载的服务编号'
    $idx = 0
    if (-not [int]::TryParse($pick, [ref]$idx) -or $idx -lt 1 -or $idx -gt $s.Count) {
        Write-Host '编号无效'
        Read-Host '按回车返回菜单'
        return
    }
    $svc = $s[$idx - 1]
    if ($svc.Name -eq 'GitMirrorFetcher') {
        Write-Host 'GitMirrorFetcher 管理多个镜像目录，请先编辑 %USERPROFILE%\git_mirror_config.txt 删除对应行，再使用 [6] 卸载该服务。'
        Read-Host '按回车返回菜单'
        return
    }
    $params = "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)\Parameters"
    $repo = $null
    if (Test-Path -LiteralPath $params) {
        $p = Get-ItemProperty -LiteralPath $params -ErrorAction SilentlyContinue
        if ($p.AppDirectory) {
            $repo = [string]$p.AppDirectory
        } elseif ($p.AppParameters -match '-File\s+"?([^"]+?\.ps1)"?') {
            $repo = Split-Path $Matches[1]
        }
    }
    if (-not $repo -or -not (Test-Path -LiteralPath $repo)) {
        Write-Host '无法解析仓库路径，请手动删除文件夹'
        Read-Host '按回车返回菜单'
        return
    }
    $isRepo = Test-Path -LiteralPath (Join-Path $repo '.git')
    Write-Host ''
    Write-Host "服务    : $($svc.Name)"
    Write-Host "仓库路径: $repo"
    Write-Host '将执行：停止服务 -> 卸载服务 -> 删除本地文件夹（云端仓库不受影响）'
    $confirm = Read-Host '确认执行？此操作不可恢复 (Y/N)'
    if ($confirm -notmatch '^[Yy]') {
        Write-Host '已取消'
        Read-Host '按回车返回菜单'
        return
    }
    if (-not $isRepo) {
        $confirm2 = Read-Host '该目录不是 Git 仓库，仍要删除整个文件夹吗？(Y/N)'
        if ($confirm2 -notmatch '^[Yy]') {
            Write-Host '已取消'
            Read-Host '按回车返回菜单'
            return
        }
    }
    Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
    & $nssm remove $svc.Name confirm | Out-Null
    Start-Sleep -Milliseconds 800
    if (Test-Path -LiteralPath $repo) {
        Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction Continue
    }
    $cfg = Join-Path $env:USERPROFILE 'git_mirror_config.txt'
    if (Test-Path -LiteralPath $cfg) {
        $lines = [System.IO.File]::ReadAllLines($cfg)
        $keep = @($lines | Where-Object { ($_ -split '\|')[0].Trim() -ne $repo })
        if ($keep.Count -ne $lines.Count) {
            [System.IO.File]::WriteAllLines($cfg, $keep, (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "已清理镜像配置: $repo"
        }
    }
    Write-Host ''
    if (Test-Path -LiteralPath $repo) {
        Write-Host '[警告] 文件夹删除未完全成功（可能被占用），请稍后手动删除'
    } else {
        Write-Host "[OK] 服务已卸载，本地仓库已删除: $repo"
    }
    Read-Host '按回车返回菜单'
}

function Repair-All {
    Write-Host ''
    Write-Host '正在修复所有同步服务...'
    & (Join-Path $PSScriptRoot '03-修复与重建\修复服务.bat')
}

function Rebuild-All {
    Write-Host ''
    Write-Host '正在彻底重建所有同步服务...'
    & (Join-Path $PSScriptRoot '03-修复与重建\彻底重建服务.bat')
}

function Uninstall-All {
    Write-Host ''
    $s = Get-SyncServices
    if (-not $s) {
        Write-Host '未找到同步服务'
        Read-Host '按回车返回菜单'
        return
    }
    Write-Host '以下服务将被停止并卸载:'
    $s | Select-Object Name | Format-Table -AutoSize
    $confirm = Read-Host '确认卸载全部同步服务？(Y/N)'
    if ($confirm -notmatch '^[Yy]') {
        Write-Host '已取消'
        Read-Host '按回车返回菜单'
        return
    }
    foreach ($x in $s) {
        Stop-Service $x.Name -Force -ErrorAction SilentlyContinue
        & $nssm remove $x.Name confirm | Out-Null
        Write-Host "已卸载: $($x.Name)"
    }
    Write-Host ''
    Read-Host '按回车返回菜单'
}

function Set-Interval {
    Write-Host ''
    $settings = Join-Path $env:USERPROFILE 'git_mirror_settings.txt'
    $current = 60
    if (Test-Path -LiteralPath $settings) {
        Get-Content -LiteralPath $settings -Encoding UTF8 | ForEach-Object {
            if ($_ -match '^interval\s*=\s*(\d+)$') { $current = [int]$Matches[1] }
        }
    }
    Write-Host "当前定时拉取间隔: $current 分钟"
    $mins = (Read-Host '新的间隔分钟数 (1-1440, 回车默认 60): ').Trim()
    if (-not $mins) { $mins = '60' }
    $n = 0
    if (-not [int]::TryParse($mins, [ref]$n) -or $n -lt 1 -or $n -gt 1440) {
        Write-Host '输入无效，请输入 1-1440 之间的分钟数'
        Read-Host '按回车返回菜单'
        return
    }
    $content = "interval=$n`r`n"
    [System.IO.File]::WriteAllText($settings, $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "已保存: interval=$n 分钟"
    $svc = Get-Service -Name 'GitMirrorFetcher' -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        Start-Service $svc.Name -ErrorAction SilentlyContinue
        Write-Host 'GitMirrorFetcher 已重启，新间隔立即生效'
    } else {
        Write-Host '提示: GitMirrorFetcher 服务未安装，请先按 A 安装'
    }
    Read-Host '按回车返回菜单'
}

function Open-Docs {
    Start-Process (Join-Path $PSScriptRoot 'docs\0基础入门.md')
}

function Exclude-PushPath {
    Write-Host ''
    & (Join-Path $PSScriptRoot '移除推送目录.bat')
    Read-Host '按回车返回菜单'
}

function Show-About {
    Write-Host ''
    Write-Host 'Git 自动同步工具包 v2.16（通用发布版）'
    Write-Host '作者: wowsony'
    Write-Host '仓库: https://github.com/dsduyopg/linux_heima'
    Write-Host '反馈: 请在 GitHub Issues 提交问题'
    Write-Host '本工具采用 MIT 许可证，欢迎学习使用；请保留作者与来源信息。'
    Read-Host '按回车返回菜单'
}

while ($true) {
    Clear-Host
    Write-Host '============================================'
    Write-Host '   Git 自动同步 · 服务管理'
    Write-Host '============================================'
    Write-Host '   [1] 查看服务状态'
    Write-Host '   [2] 启动所有同步服务'
    Write-Host '   [3] 停止所有同步服务'
    Write-Host '   [4] 修复所有同步服务'
    Write-Host '   [5] 彻底重建所有同步服务'
    Write-Host '   [6] 卸载所有同步服务'
    Write-Host '   [7] 打开使用文档'
    Write-Host '   [8] 新建自动推送仓库'
    Write-Host '   [9] 新建云端镜像拉取'
    Write-Host '   [A] 安装定时拉取服务'
    Write-Host '   [B] 生成 SSH 密钥'
    Write-Host '   [C] 启动指定服务'
    Write-Host '   [D] 停止指定服务'
    Write-Host '   [R] 重启指定服务（重载脚本）'
    Write-Host '   [E] 卸载指定服务并删除仓库'
    Write-Host '   [F] 设置定时拉取间隔'
    Write-Host '   [H] 删除/排除仓库里的子目录'
    Write-Host '   [G] 关于本工具'
    Write-Host '   [M] 邮件通知配置（SMTP 总开关）'
    Write-Host '   [I] 邮件服务管理（按仓库开关·推荐）'
    Write-Host '   [N] 为指定仓库开启/升级邮件通知（旧版方式）'
    Write-Host '   [0] 退出'
    Write-Host ''
    $opt = Read-Host '请选择操作'
    switch ($opt) {
        '1' { Show-Status }
        '2' { Start-All }
        '3' { Stop-All }
        '4' { Repair-All }
        '5' { Rebuild-All }
        '6' { Uninstall-All }
        '7' { Open-Docs }
        '8' { & (Join-Path $PSScriptRoot '新建自动推送仓库.bat') }
        '9' { & (Join-Path $PSScriptRoot '新建云端镜像拉取.bat') }
        'A' { & (Join-Path $PSScriptRoot '安装定时拉取服务.bat') }
        'B' { & (Join-Path $PSScriptRoot '生成SSH密钥.bat') }
        'C' { Start-One }
        'D' { Stop-One }
        'R' { Restart-One }
        'E' { Remove-One }
        'F' { Set-Interval }
        'H' { Exclude-PushPath }
        'G' { Show-About }
        'M' { & (Join-Path $PSScriptRoot '邮件通知配置.bat') }
        'I' { & (Join-Path $PSScriptRoot 'manage_mail_service.ps1') }
        'N' { & (Join-Path $PSScriptRoot '05-邮件通知\enable_mail_on_service.ps1'); Read-Host '按回车返回菜单' }
        '0' { break }
        default { Write-Host '输入无效，请重新选择'; Start-Sleep -Milliseconds 800 }
    }
}
