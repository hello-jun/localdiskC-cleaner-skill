#Requires -Version 5.1
<#
.SYNOPSIS
    C 盘扫描报告生成器 - 支持分析报告和结果报告两种模式
.DESCRIPTION
    模式 1（分析报告）：读取 scan.ps1 输出，展示扫描发现和空间预估
    模式 2（结果报告）：对比清理前后两次扫描 JSON，展示实际释放量和变化
.PARAMETER InputFile
    当前扫描的 JSON 文件路径（分析模式下即唯一输入；结果模式下为清理后的扫描）
.PARAMETER BeforeFile
    清理前的扫描 JSON 文件路径（仅结果模式需要）
.PARAMETER Mode
    report = 分析报告（默认），result = 结果报告（需提供 BeforeFile）
.PARAMETER OutputFile
    输出 HTML 文件路径。默认为桌面上的 C盘扫描报告.html 或 C盘清理结果报告.html
.PARAMETER OpenBrowser
    生成后是否自动在浏览器中打开。默认 $true
.EXAMPLE
    # 分析报告
    powershell -ExecutionPolicy Bypass -File build_report.ps1 -InputFile scan-before.json
    # 结果报告（清理前后对比）
    powershell -ExecutionPolicy Bypass -File build_report.ps1 -Mode result -BeforeFile scan-before.json -InputFile scan-after.json
#>

[CmdletBinding()]
param(
    [string]$InputFile = "",
    [string]$BeforeFile = "",
    [ValidateSet("report", "result")]
    [string]$Mode = "report",
    [string]$OutputFile = "",
    [bool]$OpenBrowser = $true
)

# --- 读取 JSON ---
function Read-ScanJson {
    param([string]$Path)
    if ($Path -ne "" -and (Test-Path $Path)) {
        return Get-Content -Path $Path -Raw -Encoding UTF8
    }
    Write-Error "找不到文件: $Path"
    exit 1
}

# HTML 编码：防止路径中的特殊字符破坏 HTML 结构
function Html-Encode {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace("'", '&#39;')
}

if ($InputFile -ne "" -and (Test-Path $InputFile)) {
    $scanJson = Read-ScanJson -Path $InputFile
}
elseif ([Console]::IsInputRedirected) {
    $scanJson = @([System.Console]::In.ReadToEnd())
}
else {
    $defaultPath = Join-Path $env:TEMP "c-drive-scan.json"
    if (Test-Path $defaultPath) {
        $scanJson = Get-Content -Path $defaultPath -Raw -Encoding UTF8
    } else {
        Write-Error "未找到扫描数据。请通过 -InputFile 指定 JSON 文件或通过管道传入。"
        exit 1
    }
}

$scan = $scanJson | ConvertFrom-Json
if (-not $scan -or -not $scan.system) {
    Write-Error "无效的扫描数据: $InputFile"
    exit 1
}

$beforeJson = ""
$before = $null
if ($Mode -eq "result") {
    $beforeJson = Read-ScanJson -Path $BeforeFile
    $before = $beforeJson | ConvertFrom-Json
    if (-not $before -or -not $before.system) {
        Write-Error "无效的清理前数据: $BeforeFile"
        exit 1
    }
}

# --- 计算汇总 ---
function Get-Summary {
    param($ScanData)
    $cleanable = 0; $movable = 0; $items = @()
    foreach ($groupName in $ScanData.groups.PSObject.Properties.Name) {
        $group = $ScanData.groups.$groupName
        foreach ($item in $group) {
            $items += $item
            if ($item.movable -eq $true) { $movable += $item.size_mb }
            else { $cleanable += $item.size_mb }
        }
    }
    return @{ cleanable = $cleanable; movable = $movable; items = $items }
}

$summary = Get-Summary -ScanData $scan
$totalCleanable = $summary.cleanable
$totalMovable = $summary.movable

$cDrive = $scan.system.drives | Where-Object { $_.letter -eq "C:" }
$cFree = if ($cDrive) { $cDrive.free_gb } else { 0 }
$cTotal = if ($cDrive) { $cDrive.total_gb } else { 0 }
$cUsed = $cTotal - $cFree
$estimatedFree = [math]::Round($cFree + $totalCleanable / 1024 + $totalMovable / 1024, 2)

# --- 输出路径 ---
if ($OutputFile -eq "") {
    if ($Mode -eq "result") {
        $OutputFile = Join-Path $env:USERPROFILE "Desktop\C盘清理结果报告.html"
    } else {
        $OutputFile = Join-Path $env:USERPROFILE "Desktop\C盘扫描报告.html"
    }
}

# --- Tier 映射 ---
$tierMap = @{
    "green"  = @{ label = "🟢 安全"; color = "#22c55e" }
    "yellow" = @{ label = "🟡 谨慎"; color = "#eab308" }
    "red"    = @{ label = "🔴 危险"; color = "#ef4444" }
}

$groupNames = @{
    "temp" = "临时文件"; "browser_cache" = "浏览器缓存"; "app_cache" = "应用缓存"
    "user_folders" = "用户文件夹"; "system_logs" = "系统日志"; "other" = "其他"; "extra" = "额外发现"
}

# =====================================================
# 通用样式
# =====================================================
$commonStyle = @"
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, "Microsoft YaHei", sans-serif; background: #0f172a; color: #e2e8f0; padding: 24px; line-height: 1.6; }
    .container { max-width: 1000px; margin: 0 auto; }
    h1 { font-size: 24px; margin-bottom: 8px; }
    .scan-time { color: #94a3b8; font-size: 14px; margin-bottom: 24px; }
    .summary-cards { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 24px; }
    .card { background: #1e293b; border-radius: 12px; padding: 20px; }
    .card-label { color: #94a3b8; font-size: 13px; margin-bottom: 4px; }
    .card-value { font-size: 28px; font-weight: 700; }
    .card-value.green { color: #22c55e; } .card-value.yellow { color: #eab308; }
    .card-value.blue { color: #3b82f6; } .card-value.red { color: #ef4444; }
    .card-value.cyan { color: #06b6d4; }
    .disk-bar-container { background: #1e293b; border-radius: 12px; padding: 20px; margin-bottom: 24px; }
    .disk-bar-title { font-size: 14px; color: #94a3b8; margin-bottom: 12px; }
    .disk-bar { height: 32px; border-radius: 8px; background: #334155; overflow: hidden; display: flex; }
    .disk-bar-used { background: #ef4444; height: 100%; }
    .disk-bar-free { background: #22c55e; height: 100%; }
    .disk-bar-label { font-size: 13px; color: #94a3b8; margin-top: 8px; display: flex; justify-content: space-between; }
    .group-section { background: #1e293b; border-radius: 12px; padding: 20px; margin-bottom: 16px; }
    .group-section h2 { font-size: 18px; margin-bottom: 12px; }
    .group-size { color: #94a3b8; font-size: 14px; font-weight: normal; margin-left: 8px; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th { text-align: left; padding: 8px 12px; border-bottom: 1px solid #334155; color: #94a3b8; font-weight: 500; }
    td { padding: 8px 12px; border-bottom: 1px solid #1e293b; }
    tr:hover { background: #334155; }
    .path { font-family: monospace; font-size: 12px; color: #cbd5e1; max-width: 350px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .size { font-weight: 600; white-space: nowrap; }
    .tier-badge { display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 12px; color: #fff; font-weight: 500; }
    .status-badge { display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 12px; font-weight: 500; }
    .status-ok { background: #22c55e; color: #fff; }
    .status-partial { background: #eab308; color: #fff; }
    .status-skip { background: #94a3b8; color: #fff; }
    .compare-bar { display: flex; gap: 16px; align-items: center; margin-bottom: 8px; }
    .compare-bar-item { flex: 1; }
    .compare-label { font-size: 13px; color: #94a3b8; margin-bottom: 4px; }
    .compare-value { font-size: 20px; font-weight: 700; }
    .arrow { font-size: 24px; color: #94a3b8; }
    .freed { color: #22c55e; }
    .footer { text-align: center; color: #475569; font-size: 12px; margin-top: 32px; }
    .section-title { font-size: 18px; font-weight: 600; margin: 24px 0 12px; color: #e2e8f0; }
"@

# =====================================================
# 模式 1：分析报告
# =====================================================
if ($Mode -eq "report") {

    function Build-TableRows {
        param($Items)
        $rows = ""
        foreach ($item in $Items) {
            $tier = $tierMap[$item.tier]
            $tierLabel = if ($tier) { $tier.label } else { "⚪ 未知" }
            $tierColor = if ($tier) { $tier.color } else { "#94a3b8" }
            $sizeGB = [math]::Round($item.size_mb / 1024, 2)
            $movableLabel = if ($item.movable) { "可迁移" } else { "可清理" }
            $rows += @"
            <tr>
                <td><span class="tier-badge" style="background:$tierColor">$tierLabel</span></td>
                <td>$movableLabel</td>
                <td class="path">$(Html-Encode $item.path)</td>
                <td class="size">$sizeGB GB</td>
                <td>$(Html-Encode $item.note)</td>
            </tr>
"@
        }
        return $rows
    }

    $groupSections = ""
    foreach ($groupName in $scan.groups.PSObject.Properties.Name) {
        $group = $scan.groups.$groupName
        if ($group.Count -eq 0) { continue }
        $groupTitle = if ($groupNames[$groupName]) { $groupNames[$groupName] } else { $groupName }
        $groupTotal = [math]::Round(($group | Measure-Object -Property size_mb -Sum).Sum / 1024, 2)
        $rows = Build-TableRows -Items $group

        $groupSections += @"
        <div class="group-section">
            <h2>$groupTitle <span class="group-size">共 $groupTotal GB</span></h2>
            <table>
                <thead><tr><th>分级</th><th>类型</th><th>路径</th><th>大小</th><th>说明</th></tr></thead>
                <tbody>$rows</tbody>
            </table>
        </div>
"@
    }

    $usedPct = if ($cTotal -gt 0) { [math]::Round(($cUsed / $cTotal) * 100, 1) } else { 0 }
    $freePct = if ($cTotal -gt 0) { [math]::Round(($cFree / $cTotal) * 100, 1) } else { 0 }
    $reportData = ($scanJson | ConvertFrom-Json | ConvertTo-Json -Depth 5 -Compress) -replace '</script>', '<\/script>'

    $html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>C 盘空间扫描报告</title>
<style>$commonStyle</style>
</head>
<body>
<div class="container">
    <h1>C 盘空间扫描报告</h1>
    <p class="scan-time">扫描时间: $($scan.scan_time) | 主机: $($scan.system.hostname) | 用户: $($scan.system.username)</p>

    <div class="summary-cards">
        <div class="card">
            <div class="card-label">可清理空间</div>
            <div class="card-value green">$([math]::Round($totalCleanable / 1024, 2)) GB</div>
        </div>
        <div class="card">
            <div class="card-label">可迁移空间</div>
            <div class="card-value yellow">$([math]::Round($totalMovable / 1024, 2)) GB</div>
        </div>
        <div class="card">
            <div class="card-label">清理后预估可用</div>
            <div class="card-value blue">$estimatedFree GB</div>
        </div>
    </div>

    <div class="disk-bar-container">
        <div class="disk-bar-title">C 盘使用情况 — 已用 $([math]::Round($cUsed, 2)) GB / 总共 $([math]::Round($cTotal, 2)) GB</div>
        <div class="disk-bar">
            <div class="disk-bar-used" style="width:$usedPct%"></div>
            <div class="disk-bar-free" style="width:$freePct%"></div>
        </div>
        <div class="disk-bar-label">
            <span style="color:#ef4444">■ 已用 $usedPct%</span>
            <span style="color:#22c55e">■ 可用 $freePct% ($([math]::Round($cFree, 2)) GB)</span>
        </div>
    </div>

    $groupSections

    <div class="footer">由 localdiskc-cleaner-skill 扫描脚本生成 · 数据仅供参考，操作前请确认</div>
</div>
<script>const SCAN_DATA = $reportData;</script>
</body>
</html>
"@

}

# =====================================================
# 模式 2：结果报告（清理前后对比）
# =====================================================
if ($Mode -eq "result") {

    # 清理前数据
    $beforeC = $before.system.drives | Where-Object { $_.letter -eq "C:" }
    $beforeFree = if ($beforeC) { $beforeC.free_gb } else { 0 }
    $beforeTotal = if ($beforeC) { $beforeC.total_gb } else { 0 }
    $beforeUsed = $beforeTotal - $beforeFree

    $beforeSummary = Get-Summary -ScanData $before

    # 实际释放量
    $actualFreed = [math]::Round($cFree - $beforeFree, 2)

    # 构建路径 → 大小的映射用于对比
    function Get-PathSizeMap {
        param($ScanData)
        $map = @{}
        foreach ($groupName in $ScanData.groups.PSObject.Properties.Name) {
            foreach ($item in $ScanData.groups.$groupName) {
                $map[$item.path] = $item
            }
        }
        return $map
    }

    $beforeMap = Get-PathSizeMap -ScanData $before
    $afterMap = Get-PathSizeMap -ScanData $scan

    # 对比每个路径的变化
    $changes = @()
    $allPaths = @() + $beforeMap.Keys + $afterMap.Keys | Select-Object -Unique

    foreach ($path in $allPaths) {
        $bItem = $beforeMap[$path]
        $aItem = $afterMap[$path]
        $bSize = if ($bItem) { $bItem.size_mb } else { 0 }
        $aSize = if ($aItem) { $aItem.size_mb } else { 0 }
        $diff = [math]::Round($bSize - $aSize, 2)

        if ($diff -gt 0) {
            # 路径变小了 = 释放了空间
            $tier = if ($bItem) { $bItem.tier } else { if ($aItem) { $aItem.tier } else { "green" } }
            $tierInfo = $tierMap[$tier]
            $tierLabel = if ($tierInfo) { $tierInfo.label } else { "⚪ 未知" }
            $tierColor = if ($tierInfo) { $tierInfo.color } else { "#94a3b8" }
            $note = if ($bItem) { $bItem.note } else { "" }
            $movableLabel = if ($bItem -and $bItem.movable) { "迁移" } else { "清理" }
            $status = if ($aSize -eq 0) { "done" } else { "partial" }

            $changes += [ordered]@{
                path        = $path
                before_mb   = [math]::Round($bSize, 2)
                after_mb    = [math]::Round($aSize, 2)
                freed_mb    = $diff
                tier        = $tier
                tier_label  = $tierLabel
                tier_color  = $tierColor
                type        = $movableLabel
                status      = $status
                note        = $note
            }
        }
    }

    # 按释放量降序排列
    $changes = $changes | Sort-Object -Property freed_mb -Descending

    # 清理前后的进度条
    $beforeUsedPct = if ($beforeTotal -gt 0) { [math]::Round(($beforeUsed / $beforeTotal) * 100, 1) } else { 0 }
    $beforeFreePct = if ($beforeTotal -gt 0) { [math]::Round(($beforeFree / $beforeTotal) * 100, 1) } else { 0 }
    $afterUsedPct = if ($cTotal -gt 0) { [math]::Round(($cUsed / $cTotal) * 100, 1) } else { 0 }
    $afterFreePct = if ($cTotal -gt 0) { [math]::Round(($cFree / $cTotal) * 100, 1) } else { 0 }

    # 操作明细行
    $changeRows = ""
    foreach ($c in $changes) {
        $beforeGB = [math]::Round($c.before_mb / 1024, 2)
        $afterGB = [math]::Round($c.after_mb / 1024, 2)
        $freedGB = [math]::Round($c.freed_mb / 1024, 2)
        $statusHtml = if ($c.status -eq "done") {
            '<span class="status-badge status-ok">✅ 完成</span>'
        } else {
            '<span class="status-badge status-partial">⚡ 部分清理</span>'
        }

        $changeRows += @"
        <tr>
            <td><span class="tier-badge" style="background:$($c.tier_color)">$($c.tier_label)</span></td>
            <td>$($c.type)</td>
            <td class="path">$(Html-Encode $c.path)</td>
            <td class="size">$beforeGB GB</td>
            <td class="size">$afterGB GB</td>
            <td class="size freed">$freedGB GB</td>
            <td>$statusHtml</td>
        </tr>
"@
    }

    # 仍可操作的空间
    $remainCleanable = $totalCleanable
    $remainMovable = $totalMovable
    $remainTotalGB = [math]::Round(($remainCleanable + $remainMovable) / 1024, 2)

    # 原始数据（转义 </script> 防止注入）
    $beforeData = ($beforeJson | ConvertFrom-Json | ConvertTo-Json -Depth 5 -Compress) -replace '</script>', '<\/script>'
    $afterData = ($scanJson | ConvertFrom-Json | ConvertTo-Json -Depth 5 -Compress) -replace '</script>', '<\/script>'

    $html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>C 盘清理结果报告</title>
<style>$commonStyle</style>
</head>
<body>
<div class="container">
    <h1>C 盘清理结果报告</h1>
    <p class="scan-time">清理前: $($before.scan_time) | 清理后: $($scan.scan_time) | 用户: $($scan.system.username)</p>

    <!-- 核心成果 -->
    <div class="summary-cards">
        <div class="card">
            <div class="card-label">实际释放空间</div>
            <div class="card-value green">$actualFreed GB</div>
        </div>
        <div class="card">
            <div class="card-label">清理前可用</div>
            <div class="card-value red">$([math]::Round($beforeFree, 2)) GB</div>
        </div>
        <div class="card">
            <div class="card-label">清理后可用</div>
            <div class="card-value cyan">$([math]::Round($cFree, 2)) GB</div>
        </div>
    </div>

    <!-- 清理前后对比进度条 -->
    <div class="disk-bar-container">
        <div class="disk-bar-title">清理前 — 已用 $([math]::Round($beforeUsed, 2)) GB / 总共 $([math]::Round($beforeTotal, 2)) GB（可用 $([math]::Round($beforeFree, 2)) GB）</div>
        <div class="disk-bar" style="margin-bottom:16px">
            <div class="disk-bar-used" style="width:$beforeUsedPct%"></div>
            <div class="disk-bar-free" style="width:$beforeFreePct%"></div>
        </div>
        <div class="disk-bar-title">清理后 — 已用 $([math]::Round($cUsed, 2)) GB / 总共 $([math]::Round($cTotal, 2)) GB（可用 $([math]::Round($cFree, 2)) GB）</div>
        <div class="disk-bar">
            <div class="disk-bar-used" style="width:$afterUsedPct%"></div>
            <div class="disk-bar-free" style="width:$afterFreePct%"></div>
        </div>
    </div>

    <!-- 操作明细 -->
    <div class="group-section">
        <h2>操作明细</h2>
        <table>
            <thead><tr><th>分级</th><th>操作</th><th>路径</th><th>清理前</th><th>清理后</th><th>释放</th><th>状态</th></tr></thead>
            <tbody>$changeRows</tbody>
        </table>
    </div>

    <!-- 仍可操作的空间 -->
    <div class="summary-cards">
        <div class="card">
            <div class="card-label">仍可清理</div>
            <div class="card-value green">$([math]::Round($remainCleanable / 1024, 2)) GB</div>
        </div>
        <div class="card">
            <div class="card-label">仍可迁移</div>
            <div class="card-value yellow">$([math]::Round($remainMovable / 1024, 2)) GB</div>
        </div>
        <div class="card">
            <div class="card-label">潜在可回收总计</div>
            <div class="card-value blue">$remainTotalGB GB</div>
        </div>
    </div>

    <div class="footer">由 localdiskc-cleaner-skill 生成 · 对比清理前后扫描数据</div>
</div>
<script>
const BEFORE_DATA = $beforeData;
const AFTER_DATA = $afterData;
</script>
</body>
</html>
"@
}

# --- 输出 ---
$html | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
Write-Host "报告已生成: $OutputFile" -ForegroundColor Green

if ($OpenBrowser) {
    Start-Process $OutputFile
}
