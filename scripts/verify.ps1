#Requires -Version 5.1
<#
.SYNOPSIS
    Junction 完整性验证脚本 - 检查所有 junction 链接是否有效
.DESCRIPTION
    枚举用户配置文件目录下的所有 junction，验证目标路径存在、可访问且有内容。
    输出结构化 JSON 验证报告。
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File verify.ps1
#>

$ErrorActionPreference = 'SilentlyContinue'

$userProfile = $env:USERPROFILE

function Test-Junction {
    param([string]$Path)

    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item) { return $null }

    # 检查是否为 junction
    $attrs = $item.Attributes
    if ($attrs -band [System.IO.FileAttributes]::ReparsePoint) {
        return $item
    }
    return $null
}

function Get-JunctionTarget {
    param([string]$Path)
    try {
        # 方法 1: PowerShell .Target 属性（PS 3.0+）
        $item = Get-Item -LiteralPath $Path -Force
        if ($item.Target) { return $item.Target }

        # 方法 2: 通过 WMI 查询 ReparsePoint
        $parent = Split-Path $Path -Parent
        $name = Split-Path $Path -Leaf
        $dirOutput = cmd /c "dir /AL `"$parent`"" 2>$null
        # 查找包含该目录名的行
        $line = $dirOutput | Where-Object { $_ -match [regex]::Escape($name) } | Select-Object -Last 1
        if ($line) {
            $match = $line | Select-String -Pattern "\[([^\]]+)\]" -ErrorAction SilentlyContinue
            if ($match) { return $match.Matches[0].Groups[1].Value }
        }
        return $null
    }
    catch { return $null }
}

Write-Host "验证 Junction 完整性..." -ForegroundColor Cyan
Write-Host "  扫描目录: $userProfile" -ForegroundColor Gray

# 枚举用户目录下所有 junction（包括子目录，深度 2 层）
$junctions = @()
$dirs = Get-ChildItem -LiteralPath $userProfile -Directory -Force -Depth 2 -ErrorAction SilentlyContinue

foreach ($dir in $dirs) {
    $junction = Test-Junction -Path $dir.FullName
    if ($junction) {
        $target = Get-JunctionTarget -Path $dir.FullName
        $targetExists = $false
        $targetAccessible = $false
        $targetFileCount = 0

        if ($target -and (Test-Path -LiteralPath $target)) {
            $targetExists = $true
            try {
                $targetFileCount = (Get-ChildItem -LiteralPath $target -Recurse -File -Force -ErrorAction SilentlyContinue |
                                   Measure-Object).Count
                $targetAccessible = $true
            }
            catch { $targetAccessible = $false }
        }

        # 检查是否存在备份文件夹
        $backupPath = "$($dir.FullName)_backup"
        $backupExists = Test-Path -LiteralPath $backupPath
        $backupFileCount = 0
        if ($backupExists) {
            $backupFileCount = (Get-ChildItem -LiteralPath $backupPath -Recurse -File -Force -ErrorAction SilentlyContinue |
                              Measure-Object).Count
        }

        $status = if (-not $targetExists) { "broken" }
                  elseif (-not $targetAccessible) { "inaccessible" }
                  elseif ($targetFileCount -eq 0) { "empty_target" }
                  else { "ok" }

        $junctions += [ordered]@{
            source          = $dir.FullName
            target          = $target
            status          = $status
            target_exists   = $targetExists
            target_accessible = $targetAccessible
            target_files    = $targetFileCount
            backup_exists   = $backupExists
            backup_path     = if ($backupExists) { $backupPath } else { $null }
            backup_files    = $backupFileCount
        }
    }
}

# 汇总
$ok = ($junctions | Where-Object { $_.status -eq "ok" }).Count
$broken = ($junctions | Where-Object { $_.status -eq "broken" }).Count
$other = $junctions.Count - $ok - $broken

$output = [ordered]@{
    total     = $junctions.Count
    ok        = $ok
    broken    = $broken
    other     = $other
    junctions = $junctions
    verify_time = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
}

if ($broken -gt 0) {
    Write-Host "`n⚠ 发现 $broken 个失效的 Junction!" -ForegroundColor Red
}
elseif ($junctions.Count -eq 0) {
    Write-Host "`n未发现 Junction 链接。" -ForegroundColor Yellow
}
else {
    Write-Host "`n所有 Junction 验证通过。" -ForegroundColor Green
}

$json = $output | ConvertTo-Json -Depth 4
$json
