# ============================================================
# Git 自动同步工具包 - 收件人管理 (manage_recipients.ps1)
# ------------------------------------------------------------
# 用法:
#   powershell -NoProfile -ExecutionPolicy Bypass -File manage_recipients.ps1
#
# 功能:
#   列出 / 添加 / 删除 / 清空 邮件通知的收件人
#   配置保存在 %ProgramData%\GitAutoSync\mail_config.txt 的 to= 字段
# ============================================================

$ErrorActionPreference = 'Stop'

$programData = $env:ProgramData
if ([string]::IsNullOrWhiteSpace($programData)) { $programData = $env:USERPROFILE }
$confPath = Join-Path $programData 'GitAutoSync\mail_config.txt'

if (-not (Test-Path -LiteralPath $confPath)) {
    Write-Host '尚未配置邮件, 请先运行 [邮件通知配置] -> [1] 开启并绑定 SMTP'
    Read-Host '按回车返回'
    exit 0
}

# ---- 读取全部配置行, 定位 to= 行 ----
$lines = [System.IO.File]::ReadAllLines($confPath)
$toLineIdx = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^to=') { $toLineIdx = $i; break }
}

$list = @()
if ($toLineIdx -ge 0) {
    $raw = $lines[$toLineIdx].Substring(3).Trim()
    if ($raw) {
        $list = @($raw.Split([char[]]@(',', ';')) | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
}

function Save-List($l) {
    $newTo = $l -join ','
    if ($script:toLineIdx -ge 0) {
        $script:lines[$script:toLineIdx] = "to=$newTo"
    } else {
        $script:lines = $script:lines + "to=$newTo"
    }
    [System.IO.File]::WriteAllLines($confPath, $script:lines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "[OK] 已保存"
    Start-Sleep -Milliseconds 800
}

while ($true) {
    Clear-Host
    Write-Host '============================================'
    Write-Host '   收件人管理'
    Write-Host '============================================'
    Write-Host ''
    if ($list.Count -eq 0) {
        Write-Host '   当前收件人: (空)'
    } else {
        for ($i = 0; $i -lt $list.Count; $i++) {
            Write-Host ("   [{0}] {1}" -f ($i + 1), $list[$i])
        }
    }
    Write-Host ''
    Write-Host '   [1] 添加收件人'
    Write-Host '   [2] 删除收件人 (输入编号)'
    Write-Host '   [3] 清空所有收件人'
    Write-Host '   [0] 返回'
    Write-Host ''
    $op = Read-Host '请选择'
    switch ($op) {
        '1' {
            $add = (Read-Host '输入新收件邮箱').Trim()
            if (-not $add) { Write-Host '不能为空'; Start-Sleep -Milliseconds 800; break }
            if ($list -contains $add) { Write-Host '该邮箱已在列表中'; Start-Sleep -Milliseconds 800; break }
            $script:list = $script:list + $add
            Save-List $script:list
        }
        '2' {
            $id = 0
            $inp = (Read-Host '输入要删除的编号').Trim()
            if (-not [int]::TryParse($inp, [ref]$id) -or $id -lt 1 -or $id -gt $script:list.Count) {
                Write-Host '编号无效'; Start-Sleep -Milliseconds 800; break
            }
            $removed = $script:list[$id - 1]
            $script:list = @($script:list | Where-Object { $_ -ne $removed })
            Save-List $script:list
        }
        '3' {
            $script:list = @()
            Save-List $script:list
        }
        '0' { break }
        default { Write-Host '输入无效'; Start-Sleep -Milliseconds 800 }
    }
    if ($op -eq '0') { break }
}
