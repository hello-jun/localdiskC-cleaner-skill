# Fallback 命令模板

当 PowerShell 脚本（scan.ps1 / verify.ps1 / build_report.ps1）执行失败时，agent 应使用本文件的命令模板手动完成操作。

## Phase 1 Fallback：手动扫描

如果 `scan.ps1` 执行失败（权限不足、PowerShell 版本过低、路径找不到等），使用以下命令手动扫描。

### 通用大小计算函数

```powershell
function Get-Size($p) { if(Test-Path $p){[math]::Round((Get-ChildItem $p -Recurse -File -Force -EA SilentlyContinue|Measure-Object Length -Sum).Sum/1MB,2)}else{0} }
```

### 逐项扫描可清理目录

```powershell
Get-Size "$env:TEMP"
Get-Size "C:\Windows\Temp"
Get-Size "C:\Windows\SoftwareDistribution\Download"
Get-Size "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
Get-Size "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
Get-Size "$env:LOCALAPPDATA\Kingsoft"
Get-Size "$env:APPDATA\Tencent"
```

### 逐项扫描可迁移目录

```powershell
Get-Size "$env:USERPROFILE\Documents"
Get-Size "$env:USERPROFILE\Desktop"
Get-Size "$env:USERPROFILE\Downloads"
Get-Size "$env:USERPROFILE\Pictures"
Get-Size "$env:USERPROFILE\Videos"
# 搜索微信目录
Get-ChildItem $env:USERPROFILE -Directory -Filter "*wechat*" | ForEach-Object { Get-Size $_.FullName }
```

### 动态扩展扫描

无论脚本是否成功，agent 都应动态探索额外目录：

- 用户提到的特定应用路径
- `Get-ChildItem $env:USERPROFILE -Directory` 列出用户目录下所有文件夹
- `Get-ChildItem $env:LOCALAPPDATA -Directory` 扫描本地应用数据
- 按安全分级整理结果展示给用户

## 一键手动扫描 + JSON 构建

当 `scan.ps1` 不可用时，执行以下脚本完成扫描并输出 JSON（格式与 `scan.ps1` 完全兼容，可直接用于 `build_report.ps1`）。

将输出保存到 `$env:TEMP\c-drive-scan-before.json`（或 `-after`），后续即可正常调用 `build_report.ps1` 生成 HTML 报告。

```powershell
function Get-SizeMB($p) {
    if (Test-Path $p) {
        $s = (Get-ChildItem $p -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum
        [math]::Round($s / 1MB, 2)
    } else { 0 }
}

$groups = [ordered]@{}

$scanDefs = @(
    @{ G = 'temp'; P = "$env:TEMP"; T = 'green'; N = '用户临时文件，删除后自动重建' }
    @{ G = 'temp'; P = 'C:\Windows\Temp'; T = 'green'; N = 'Windows 临时文件' }
    @{ G = 'temp'; P = 'C:\Windows\SoftwareDistribution\Download'; T = 'green'; N = 'Windows 更新下载缓存' }
    @{ G = 'temp'; P = 'C:\Windows\Prefetch'; T = 'green'; N = '预读取缓存' }
    @{ G = 'browser_cache'; P = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"; T = 'green'; N = 'Chrome 缓存' }
    @{ G = 'browser_cache'; P = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"; T = 'green'; N = 'Chrome 代码缓存' }
    @{ G = 'browser_cache'; P = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"; T = 'green'; N = 'Edge 缓存' }
    @{ G = 'browser_cache'; P = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"; T = 'green'; N = 'Edge 代码缓存' }
    @{ G = 'browser_cache'; P = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"; T = 'green'; N = 'Firefox 配置文件和缓存' }
    @{ G = 'app_cache'; P = "$env:LOCALAPPDATA\Kingsoft\WPS Cloud Files"; T = 'yellow'; N = 'WPS 云文件缓存' }
    @{ G = 'app_cache'; P = "$env:APPDATA\Tencent"; T = 'yellow'; N = '腾讯应用数据（QQ等）' }
    @{ G = 'app_cache'; P = "$env:LOCALAPPDATA\DingTalk"; T = 'yellow'; N = '钉钉缓存数据' }
    @{ G = 'app_cache'; P = "$env:LOCALAPPDATA\feishu"; T = 'yellow'; N = '飞书缓存' }
    @{ G = 'app_cache'; P = "$env:LOCALAPPDATA\Bytedance\Lark"; T = 'yellow'; N = '飞书（Lark）缓存' }
    @{ G = 'system_logs'; P = 'C:\Windows\Logs'; T = 'green'; N = 'Windows 日志文件' }
    @{ G = 'system_logs'; P = "$env:LOCALAPPDATA\CrashDumps"; T = 'green'; N = '应用崩溃转储文件' }
    @{ G = 'other'; P = "C:\`$Recycle.Bin"; T = 'green'; N = '回收站' }
    @{ G = 'other'; P = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"; T = 'green'; N = '缩略图缓存' }
    @{ G = 'other'; P = 'C:\Windows\SoftwareDistribution\DeliveryOptimization'; T = 'green'; N = '传递优化缓存' }
    @{ G = 'other'; P = 'C:\Windows.old'; T = 'yellow'; N = '旧 Windows 安装' }
)

foreach ($def in $scanDefs) {
    $mb = Get-SizeMB $def.P
    if ($mb -ge 50) {
        if (-not $groups[$def.G]) { $groups[$def.G] = @() }
        $groups[$def.G] += @{ path = $def.P; size_mb = $mb; tier = $def.T; movable = $false; note = $def.N }
    }
}

# 用户文件夹（可迁移）
foreach ($name in @('Documents','Desktop','Downloads','Pictures','Videos','Music')) {
    $dp = Join-Path $env:USERPROFILE $name
    $mb = Get-SizeMB $dp
    if ($mb -ge 50) {
        if (-not $groups['user_folders']) { $groups['user_folders'] = @() }
        $groups['user_folders'] += @{ path = $dp; size_mb = $mb; tier = 'green'; movable = $true; note = "$name，junction 迁移安全" }
    }
}

# 开发者工具缓存
$devDefs = @(
    @{ P = "$env:USERPROFILE\AppData\Local\npm-cache"; N = 'npm 缓存' }
    @{ P = "$env:LOCALAPPDATA\pnpm-store"; N = 'pnpm store' }
    @{ P = "$env:USERPROFILE\.nuget\packages"; N = 'NuGet 包缓存' }
    @{ P = "$env:USERPROFILE\.gradle\caches"; N = 'Gradle 缓存' }
    @{ P = "$env:USERPROFILE\.m2\repository"; N = 'Maven 缓存' }
    @{ P = "$env:LOCALAPPDATA\Docker"; N = 'Docker Desktop 数据' }
)
foreach ($dd in $devDefs) {
    $mb = Get-SizeMB $dd.P
    if ($mb -ge 50) {
        if (-not $groups['dev_cache']) { $groups['dev_cache'] = @() }
        $groups['dev_cache'] += @{
            path = $dd.P; size_mb = $mb
            tier = if ($dd.P -match 'Docker') { 'yellow' } else { 'green' }
            movable = $false; note = $dd.N
        }
    }
}

# 构建输出（与 scan.ps1 格式完全兼容）
$result = [ordered]@{
    system = [ordered]@{
        os       = (Get-CimInstance Win32_OperatingSystem).Caption
        hostname = $env:COMPUTERNAME
        username = $env:USERNAME
        onedrive = if ($env:OneDrive -or $env:OneDriveCommercial) { 'active' } else { 'not_detected' }
        drives   = @(Get-PSDrive -PSProvider FileSystem -EA SilentlyContinue | ForEach-Object {
            @{ letter = "$($_.Name):"; total_gb = [math]::Round(($_.Used + $_.Free) / 1GB, 2); free_gb = [math]::Round($_.Free / 1GB, 2) }
        })
    }
    groups    = $groups
    scan_time = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
}

$result | ConvertTo-Json -Depth 5
```

### 执行方式

> 上方脚本是多行 PowerShell，**不要用 `-Command` 传递**（特殊字符和 `$` 变量会导致解析失败）。
> 正确做法：将脚本内容保存为临时文件，再用 `-File` 执行。

**步骤 1**：将上方 ```powershell ... ``` 中的完整脚本保存到 `$env:TEMP\manual_scan.ps1`。

**步骤 2**：执行并保存 JSON：

```powershell
# 扫描前
powershell -ExecutionPolicy Bypass -File "$env:TEMP\manual_scan.ps1" | Out-File "$env:TEMP\c-drive-scan-before.json" -Encoding UTF8

# 清理后再次扫描（保存为不同文件名）
powershell -ExecutionPolicy Bypass -File "$env:TEMP\manual_scan.ps1" | Out-File "$env:TEMP\c-drive-scan-after.json" -Encoding UTF8
```

### JSON 就绪后生成 HTML 报告

根据脚本目录是否已定位，选择对应路径：

**情况 A — 脚本目录已定位**（路径定位返回了路径，但 `scan.ps1` 因其他原因失败）：直接用 `build_report.ps1` 生成 HTML。

```powershell
# 分析报告
powershell -ExecutionPolicy Bypass -File "<脚本目录>\build_report.ps1" -InputFile "$env:TEMP\c-drive-scan-before.json"

# 结果报告（清理后）
powershell -ExecutionPolicy Bypass -File "<脚本目录>\build_report.ps1" -Mode result -BeforeFile "$env:TEMP\c-drive-scan-before.json" -InputFile "$env:TEMP\c-drive-scan-after.json"
```

**情况 B — 脚本目录未定位**（路径定位返回 `NOT_FOUND`）：使用下方的「内联 HTML 报告生成」脚本，同样需保存为临时文件后用 `-File` 执行。

## 内联 HTML 报告生成

当 `build_report.ps1` 也不可用时，使用以下脚本直接生成 HTML 报告。支持 `report`（分析）和 `result`（对比）两种模式。

> **执行方式**：将脚本保存为临时文件（如 `$env:TEMP\build_html_report.ps1`），再用 `powershell -ExecutionPolicy Bypass -File "$env:TEMP\build_html_report.ps1"` 执行。不要用 `-Command` 传递多行脚本。

### 分析报告（单次扫描）

```powershell
$jsonPath = "$env:TEMP\c-drive-scan-before.json"
$scan = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cDrive = $scan.system.drives | Where-Object { $_.letter -eq 'C:' }
$totalCleanable = 0; $totalMovable = 0
foreach ($gn in $scan.groups.PSObject.Properties.Name) {
    foreach ($item in $scan.groups.$gn) {
        if ($item.movable) { $totalMovable += $item.size_mb } else { $totalCleanable += $item.size_mb }
    }
}
$gNames = @{ temp='临时文件';browser_cache='浏览器缓存';app_cache='应用缓存';dev_cache='开发者工具缓存';user_folders='用户文件夹';game_library='游戏库';system_logs='系统日志';other='其他';extra='额外发现' }
$rows = ""
foreach ($gn in $scan.groups.PSObject.Properties.Name) {
    $g = $scan.groups.$gn; if ($g.Count -eq 0) { continue }
    $rows += "<h3>$($gNames[$gn])</h3><table><tr><th>路径</th><th>大小</th><th>分级</th><th>类型</th><th>说明</th></tr>"
    foreach ($item in $g) {
        $tier = @{green='🟢安全';yellow='🟡谨慎';red='🔴危险'}[$item.tier]
        $type = if ($item.movable) { '可迁移' } else { '可清理' }
        $rows += "<tr><td style='font-family:monospace;font-size:12px'>$($item.path)</td><td><b>$([math]::Round($item.size_mb/1024,2)) GB</b></td><td>$tier</td><td>$type</td><td>$($item.note)</td></tr>"
    }
    $rows += "</table>"
}
$cFree = if ($cDrive) { $cDrive.free_gb } else { 0 }
$html = @"
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>C盘扫描报告</title>
<style>
body{font-family:system-ui,"Microsoft YaHei",sans-serif;background:#0f172a;color:#e2e8f0;padding:24px;max-width:960px;margin:auto}
h1{margin-bottom:4px}.time{color:#94a3b8;font-size:14px;margin-bottom:20px}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:24px}
.card{background:#1e293b;border-radius:10px;padding:18px}.card .label{color:#94a3b8;font-size:13px}.card .value{font-size:26px;font-weight:700}
.green{color:#22c55e}.yellow{color:#eab308}.blue{color:#3b82f6}
table{width:100%;border-collapse:collapse;margin-bottom:16px;font-size:14px}
th{text-align:left;padding:8px 10px;border-bottom:1px solid #334155;color:#94a3b8}
td{padding:8px 10px;border-bottom:1px solid #1e293b}tr:hover{background:#334155}
h3{margin:20px 0 8px;font-size:16px;color:#e2e8f0}
</style></head><body>
<h1>C 盘空间扫描报告</h1>
<p class="time">扫描时间: $($scan.scan_time) | 主机: $($scan.system.hostname) | 用户: $($scan.system.username)</p>
<div class="cards">
<div class="card"><div class="label">可清理空间</div><div class="value green">$([math]::Round($totalCleanable/1024,2)) GB</div></div>
<div class="card"><div class="label">可迁移空间</div><div class="value yellow">$([math]::Round($totalMovable/1024,2)) GB</div></div>
<div class="card"><div class="label">C 盘可用</div><div class="value blue">$cFree GB</div></div>
</div>
$rows
<p style="text-align:center;color:#475569;font-size:12px;margin-top:32px">由 localdiskc-cleaner-skill 生成 · 数据仅供参考</p>
</body></html>
"@
$outPath = Join-Path $env:USERPROFILE "Desktop\C盘扫描报告.html"
$html | Out-File $outPath -Encoding UTF8 -Force
Write-Host "报告已生成: $outPath" -ForegroundColor Green
Start-Process $outPath
```

### 结果报告（清理前后对比）

```powershell
$before = Get-Content "$env:TEMP\c-drive-scan-before.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$after  = Get-Content "$env:TEMP\c-drive-scan-after.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$bC = $before.system.drives | Where-Object { $_.letter -eq 'C:' }
$aC = $after.system.drives  | Where-Object { $_.letter -eq 'C:' }
$actualFreed = [math]::Round($aC.free_gb - $bC.free_gb, 2)
# 构建路径对比
$map = @{}
foreach ($gn in $before.groups.PSObject.Properties.Name) { foreach ($i in $before.groups.$gn) { $map[$i.path] = $i } }
$changes = @()
foreach ($gn in $after.groups.PSObject.Properties.Name) {
    foreach ($i in $after.groups.$gn) {
        $b = $map[$i.path]; $bSize = if ($b) { $b.size_mb } else { 0 }
        $diff = [math]::Round($bSize - $i.size_mb, 2)
        if ($diff -gt 0) {
            $tier = @{green='🟢安全';yellow='🟡谨慎';red='🔴危险'}[if($b){$b.tier}else{$i.tier}]
            $status = if ($i.size_mb -eq 0) { '✅ 完成' } else { '⚡ 部分清理' }
            $type = if ($b -and $b.movable) { '迁移' } else { '清理' }
            $changes += [ordered]@{ path=$b.path; before=$bSize; after=$i.size_mb; freed=$diff; tier=$tier; type=$type; status=$status; note=if($b){$b.note}else{''} }
        }
    }
}
$changes = $changes | Sort-Object freed -Descending
$rows = ""
foreach ($c in $changes) {
    $rows += "<tr><td style='font-family:monospace;font-size:12px'>$($c.path)</td><td>$([math]::Round($c.before/1024,2)) GB</td><td>$([math]::Round($c.after/1024,2)) GB</td><td style='color:#22c55e'><b>$([math]::Round($c.freed/1024,2)) GB</b></td><td>$($c.tier)</td><td>$($c.type)</td><td>$($c.status)</td></tr>"
}
$html = @"
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>C盘清理结果报告</title>
<style>
body{font-family:system-ui,"Microsoft YaHei",sans-serif;background:#0f172a;color:#e2e8f0;padding:24px;max-width:960px;margin:auto}
h1{margin-bottom:4px}.time{color:#94a3b8;font-size:14px;margin-bottom:20px}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:24px}
.card{background:#1e293b;border-radius:10px;padding:18px}.card .label{color:#94a3b8;font-size:13px}.card .value{font-size:26px;font-weight:700}
.green{color:#22c55e}.red{color:#ef4444}.cyan{color:#06b6d4}
table{width:100%;border-collapse:collapse;margin-bottom:16px;font-size:14px}
th{text-align:left;padding:8px 10px;border-bottom:1px solid #334155;color:#94a3b8}
td{padding:8px 10px;border-bottom:1px solid #1e293b}tr:hover{background:#334155}
</style></head><body>
<h1>C 盘清理结果报告</h1>
<p class="time">清理前: $($before.scan_time) | 清理后: $($after.scan_time) | 用户: $($after.system.username)</p>
<div class="cards">
<div class="card"><div class="label">实际释放空间</div><div class="value green">$actualFreed GB</div></div>
<div class="card"><div class="label">清理前可用</div><div class="value red">$([math]::Round($bC.free_gb,2)) GB</div></div>
<div class="card"><div class="label">清理后可用</div><div class="value cyan">$([math]::Round($aC.free_gb,2)) GB</div></div>
</div>
<h3>操作明细</h3>
<table><tr><th>路径</th><th>清理前</th><th>清理后</th><th>释放</th><th>分级</th><th>操作</th><th>状态</th></tr>
$rows</table>
<p style="text-align:center;color:#475569;font-size:12px;margin-top:32px">由 localdiskc-cleaner-skill 生成 · 对比清理前后扫描数据</p>
</body></html>
"@
$outPath = Join-Path $env:USERPROFILE "Desktop\C盘清理结果报告.html"
$html | Out-File $outPath -Encoding UTF8 -Force
Write-Host "报告已生成: $outPath" -ForegroundColor Green
Start-Process $outPath
```

## Phase 5 Fallback：手动验证 Junction

如果 `verify.ps1` 执行失败，使用以下命令手动检查 junction。

### 列出所有 junction

```powershell
cmd /c "dir /AL `"$env:USERPROFILE`"" | findstr /I "JUNCTION"
```

### 逐项检查

```powershell
fsutil reparsepoint query "C:\Users\用户名\Documents"
Test-Path "C:\Users\用户名\Documents"  # 应返回 True
```

### 检查 junction 目标是否有内容

```powershell
(Get-ChildItem "C:\Users\用户名\Documents" -Recurse -File -Force -EA SilentlyContinue | Measure-Object).Count
```

### 对比清理前后磁盘空间

```powershell
Get-PSDrive C | Select-Object @{N='可用空间GB';E={[math]::Round($_.Free/1GB,2)}}
# 逐项检查已清理/已迁移的目录
Get-Item "C:\Users\用户名\Documents" | Select-Object FullName, Attributes, Target
```

## 仅清理流程详细说明

当用户没有其他盘可用时，执行仅清理流程：

1. 执行第一阶段扫描，筛选出「类别=可清理」的项目
   - 脚本成功：使用 scan.ps1 输出
   - 脚本失败：使用上方手动扫描命令或「一键手动扫描 + JSON 构建」
2. 将所有可清理项汇总成表格展示给用户（含安全分级列），由用户逐项确认
3. 逐项执行清理命令
4. 汇报释放空间：`Get-PSDrive C` 对比前后可用空间
5. 如果空间仍然紧张，给出补充建议：
   - 🟢 使用「磁盘清理」工具（`cleanmgr`）
   - 🟡 检查大型软件是否可卸载重装
   - 🟡 关闭休眠（`powercfg /h off`），失去快速启动
   - 🔴 页面文件不建议手动删除
6. 生成 HTML 报告（使用 `build_report.ps1` 或上方「内联 HTML 报告生成」）
