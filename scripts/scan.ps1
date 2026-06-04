#Requires -Version 5.1
<#
.SYNOPSIS
    C 盘空间扫描脚本 - 输出结构化 JSON，作为 AI agent 清理决策的基准数据
.DESCRIPTION
    快速扫描 C 盘常见可清理/可迁移目录，按类别分组输出 JSON。
    自动检测 OneDrive、文件夹重定向、磁盘加密等风险因素。
    本脚本是"基准扫描"而非完整扫描，agent 可在此基础上动态扩展。
.PARAMETER MinSizeMB
    最小报告阈值（MB），低于此大小的目录不纳入结果。默认 50
.PARAMETER ScanMovable
    是否扫描可迁移到其他盘的用户文件夹。默认 $true
.PARAMETER ExtraPaths
    agent 传入的额外路径（逗号分隔），会统一计算大小并纳入结果
.PARAMETER OutputFile
    必填。JSON 输出文件的绝对路径。推荐清理前用 c-drive-scan-before.json，清理后用 c-drive-scan-after.json
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scan.ps1 -OutputFile "$env:TEMP\c-drive-scan-before.json"
    powershell -ExecutionPolicy Bypass -File scan.ps1 -MinSizeMB 100 -ExtraPaths "C:\SomeApp\Data,C:\Another\Path" -OutputFile "$env:TEMP\c-drive-scan-before.json"
#>

[CmdletBinding()]
param(
    [double]$MinSizeMB = 50,
    [bool]$ScanMovable = $true,
    [string[]]$ExtraPaths = @(),
    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

$ErrorActionPreference = 'SilentlyContinue'

# --- Helper: 计算目录大小（MB）---
function Get-FolderSizeMB {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) { return 0 }
        $size = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        return [math]::Round($size / 1MB, 2)
    }
    catch { return 0 }
}

# --- Helper: 扫描一组路径 ---
function Get-ScanGroup {
    param(
        [string]$Group,
        [hashtable[]]$Items,
        [double]$Threshold
    )
    $results = @()
    foreach ($item in $Items) {
        $sizeMB = Get-FolderSizeMB -Path $item.Path
        if ($sizeMB -ge $Threshold) {
            $results += [ordered]@{
                path     = $item.Path
                size_mb  = $sizeMB
                tier     = $item.Tier
                movable  = $item.Movable
                note     = $item.Note
            }
        }
    }
    return $results
}

# --- Helper: 检测路径是否被 OneDrive 管理 ---
function Test-OneDriveManaged {
    param([string]$Path)
    $onedriveExe = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    if (-not $onedriveExe) { return $false }

    $onedrivePaths = @()
    # OneDrive 同步根目录
    if ($env:OneDrive) { $onedrivePaths += $env:OneDrive }
    if ($env:OneDriveCommercial) { $onedrivePaths += $env:OneDriveCommercial }
    # 扫描用户目录下所有 OneDrive 文件夹
    $onedrivePaths += (Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Filter "OneDrive*" -ErrorAction SilentlyContinue).FullName

    foreach ($odPath in $onedrivePaths) {
        if ($odPath -and $Path.StartsWith($odPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    # 检查路径是否是 OneDrive 占位符链接（文件按需）
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        if ($item -and $item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $target = $item.Target
            if ($target -and $target -match "OneDrive") { return $true }
        }
    }
    catch {}

    return $false
}

# --- Helper: 检测路径是否已经是 junction ---
function Test-IsJunction {
    param([string]$Path)
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            return @{ is_junction = $true; target = $item.Target }
        }
    }
    catch {}
    return @{ is_junction = $false; target = $null }
}

# --- Helper: 检测云同步工具（OneDrive + Dropbox + Google Drive + 坚果云）---
function Test-CloudSyncManaged {
    param([string]$Path)

    # OneDrive（已通过 Test-OneDriveManaged 覆盖，此处作为补充）
    $cloudRoots = @()
    if ($env:OneDrive) { $cloudRoots += $env:OneDrive }
    if ($env:OneDriveCommercial) { $cloudRoots += $env:OneDriveCommercial }
    # 用户目录下匹配 OneDrive* 的所有文件夹
    $cloudRoots += (Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Filter "OneDrive*" -ErrorAction SilentlyContinue).FullName

    # Dropbox
    $dropbox = Get-ItemProperty -Path "HKCU:\Software\Dropbox" -Name "InstallPath" -ErrorAction SilentlyContinue
    if ($dropbox) {
        $dropboxDir = Join-Path $env:USERPROFILE "Dropbox"
        if (Test-Path $dropboxDir) { $cloudRoots += $dropboxDir }
    }

    # Google Drive
    $gdriveDirs = Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Filter "Google Drive*" -ErrorAction SilentlyContinue
    foreach ($gd in $gdriveDirs) { $cloudRoots += $gd.FullName }
    $gdriveDirs2 = Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Filter "My Drive*" -ErrorAction SilentlyContinue
    foreach ($gd in $gdriveDirs2) { $cloudRoots += $gd.FullName }

    # 坚果云（中文用户常见）
    $jianguoDirs = Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Filter "坚果云*" -ErrorAction SilentlyContinue
    foreach ($jg in $jianguoDirs) { $cloudRoots += $jg.FullName }
    # 检查坚果云配置文件
    $jianguoConf = "$localAppData\Nutstore"
    if (Test-Path $jianguoConf) {
        $nutstoreDirs = Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Filter "Nutstore*" -ErrorAction SilentlyContinue
        foreach ($ns in $nutstoreDirs) { $cloudRoots += $ns.FullName }
    }

    foreach ($root in $cloudRoots) {
        if ($root -and $Path.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            return @{ managed = $true; service = if ($root -match "OneDrive") { "OneDrive" } elseif ($root -match "Dropbox") { "Dropbox" } elseif ($root -match "Google Drive|My Drive") { "Google Drive" } elseif ($root -match "坚果云|Nutstore") { "坚果云" } else { "云同步" } }
        }
    }
    return @{ managed = $false; service = $null }
}

# --- Helper: 检测文件夹重定向（企业组策略）---
function Test-FolderRedirection {
    param([string]$Path)
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        if ($item -and $item.Target) {
            $target = $item.Target
            # 目标指向网络路径 (\\server\share) 即为重定向
            if ($target -match "^\\\\") { return $true }
            # 目标不在 C 盘也可能是重定向
            if ($target -notmatch "^C:") { return $true }
        }
    }
    catch {}
    return $false
}

# --- Helper: 检测磁盘是否启用 BitLocker ---
function Get-DriveEncryption {
    param([string]$DriveLetter)
    try {
        $vol = Get-BitLockerVolume -MountPoint $DriveLetter -ErrorAction SilentlyContinue
        if ($vol) {
            return @{
                encrypted    = ($vol.ProtectionStatus -ne "Off")
                encryption_method = $vol.EncryptionMethod
                protection   = $vol.ProtectionStatus.ToString()
            }
        }
    }
    catch {}
    # fallback: 通过 manage-bde 命令
    try {
        $output = cmd /c "manage-bde -status $DriveLetter 2>nul"
        $encrypted = $output | Select-String -Pattern "已加密|Encryption Method" -ErrorAction SilentlyContinue
        return @{
            encrypted    = ($null -ne $encrypted)
            encryption_method = "unknown"
            protection   = "unknown"
        }
    }
    catch {}
    return @{ encrypted = $false; encryption_method = "N/A"; protection = "N/A" }
}

# --- Helper: 动态搜索游戏平台库目录 ---
function Find-GameLibraries {
    $gamePaths = @()

    # Steam
    $steamPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue
    if ($steamPath) {
        $steamLib = Join-Path $steamPath.SteamPath "steamapps\common"
        if (Test-Path $steamLib) {
            $sizeMB = Get-FolderSizeMB -Path $steamLib
            if ($sizeMB -ge 1) {
                $gamePaths += @{
                    Path = $steamLib; Tier = "yellow"; Movable = $false
                    Note = "Steam 游戏库，建议通过 Steam 设置迁移库文件夹"
                }
            }
        }
        # 检查 Steam 库文件中定义的其他位置
        $vdf = Join-Path $steamPath.SteamPath "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            $content = Get-Content $vdf -Raw -ErrorAction SilentlyContinue
            $matches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
            foreach ($m in $matches) {
                $libPath = $m.Groups[1].Value -replace "\\\\", "\"
                $commonPath = Join-Path $libPath "steamapps\common"
                if ((Test-Path $commonPath) -and ($commonPath -ne $steamLib)) {
                    $sizeMB = Get-FolderSizeMB -Path $commonPath
                    if ($sizeMB -ge 1) {
                        $gamePaths += @{
                            Path = $commonPath; Tier = "yellow"; Movable = $false
                            Note = "Steam 额外游戏库，建议通过 Steam 设置管理"
                        }
                    }
                }
            }
        }
    }

    # Epic Games
    $epicManifests = "$localAppData\Epic Games\EpicGamesLauncher\Data\Manifests"
    if (Test-Path $epicManifests) {
        $epicDirs = @()
        Get-ChildItem $epicManifests -Filter "*.item" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $json = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($json.InstallLocation) { $epicDirs += $json.InstallLocation }
            }
            catch {}
        }
        $epicDirs | Select-Object -Unique | ForEach-Object {
            if (Test-Path $_) {
                $sizeMB = Get-FolderSizeMB -Path $_
                if ($sizeMB -ge 100) {
                    $gamePaths += @{
                        Path = $_; Tier = "yellow"; Movable = $false
                        Note = "Epic Games 安装的游戏，建议通过 Epic Games Launcher 管理"
                    }
                }
            }
        }
    }

    # Xbox Game Pass / Microsoft Store 游戏
    $xboxPath = "C:\Program Files\ModifiableWindowsApps"
    if (Test-Path $xboxPath) {
        $sizeMB = Get-FolderSizeMB -Path $xboxPath
        if ($sizeMB -ge $MinSizeMB) {
            $gamePaths += @{
                Path = $xboxPath; Tier = "red"; Movable = $false
                Note = "Xbox Game Pass 游戏，不可手动移动"
            }
        }
    }

    return $gamePaths
}

# --- 环境变量 ---
$userProfile = $env:USERPROFILE
$localAppData = $env:LOCALAPPDATA
$roamingAppData = $env:APPDATA
$temp = $env:TEMP

# =====================================================
# 定义扫描路径（基准覆盖，agent 可在此基础上扩展）
# =====================================================

$tempPaths = @(
    @{ Path = "$temp";                              Tier = "green";  Movable = $false; Note = "用户临时文件，删除后自动重建" }
    @{ Path = "C:\Windows\Temp";                    Tier = "green";  Movable = $false; Note = "Windows 临时文件" }
    @{ Path = "C:\Windows\SoftwareDistribution\Download"; Tier = "green"; Movable = $false; Note = "Windows 更新下载缓存" }
    @{ Path = "C:\Windows\Prefetch";                Tier = "green";  Movable = $false; Note = "预读取缓存，系统自动重建" }
)

$browserCachePaths = @(
    @{ Path = "$localAppData\Google\Chrome\User Data\Default\Cache";                        Tier = "green"; Movable = $false; Note = "Chrome 缓存" }
    @{ Path = "$localAppData\Google\Chrome\User Data\Default\Code Cache";                   Tier = "green"; Movable = $false; Note = "Chrome 代码缓存" }
    @{ Path = "$localAppData\Google\Chrome\User Data\Default\Service Worker\CacheStorage";  Tier = "green"; Movable = $false; Note = "Chrome Service Worker 缓存" }
    @{ Path = "$localAppData\Microsoft\Edge\User Data\Default\Cache";                       Tier = "green"; Movable = $false; Note = "Edge 缓存" }
    @{ Path = "$localAppData\Microsoft\Edge\User Data\Default\Code Cache";                  Tier = "green"; Movable = $false; Note = "Edge 代码缓存" }
    @{ Path = "$localAppData\Mozilla\Firefox\Profiles";                                    Tier = "green"; Movable = $false; Note = "Firefox 配置文件和缓存" }
)

# 动态扫描 Chrome/Edge 多 Profile
foreach ($browserBase in @("$localAppData\Google\Chrome\User Data", "$localAppData\Microsoft\Edge\User Data")) {
    if (Test-Path $browserBase) {
        $profiles = Get-ChildItem -LiteralPath $browserBase -Directory -Filter "Profile *" -ErrorAction SilentlyContinue
        foreach ($p in $profiles) {
            foreach ($sub in @("Cache", "Code Cache", "Service Worker\CacheStorage")) {
                $cachePath = Join-Path $p.FullName $sub
                if (Test-Path $cachePath) {
                    $browserCachePaths += @{
                        Path = $cachePath; Tier = "green"; Movable = $false; Note = "$($p.Name) 缓存"
                    }
                }
            }
        }
    }
}

$appCachePaths = @(
    @{ Path = "$localAppData\Kingsoft\WPS Cloud Files";    Tier = "yellow"; Movable = $false; Note = "WPS 云文件缓存，可能包含未同步文档" }
    @{ Path = "$roamingAppData\Tencent";                   Tier = "yellow"; Movable = $false; Note = "腾讯应用数据（QQ等），可能含聊天记录" }
    @{ Path = "$localAppData\DingTalk";                    Tier = "yellow"; Movable = $false; Note = "钉钉缓存数据" }
    @{ Path = "$localAppData\Bytedance\Lark";              Tier = "yellow"; Movable = $false; Note = "飞书缓存数据" }
    @{ Path = "$localAppData\feishu";                      Tier = "yellow"; Movable = $false; Note = "飞书（国内版）缓存" }
    @{ Path = "$roamingAppData\Bytedance\Lark";            Tier = "yellow"; Movable = $false; Note = "飞书应用数据" }
)

# UWP 应用数据保护（不可通过 junction 迁移）
$uwpPackagesPath = "$localAppData\Packages"
if (Test-Path $uwpPackagesPath) {
    $uwpSize = Get-FolderSizeMB -Path $uwpPackagesPath
    if ($uwpSize -ge $MinSizeMB) {
        $appCachePaths += @{
            Path = $uwpPackagesPath; Tier = "red"; Movable = $false
            Note = "UWP 应用数据，junction 迁移会导致应用崩溃。仅可清理缓存子目录"
        }
    }
}

# =====================================================
# 开发者工具链路径
# =====================================================
$devCachePaths = @()

# npm/yarn/pnpm 缓存
$devCachePaths += @{ Path = "$userProfile\AppData\Local\npm-cache";        Tier = "green"; Movable = $false; Note = "npm 缓存，可安全清理" }
$devCachePaths += @{ Path = "$userProfile\AppData\Local\Yarn\Cache";      Tier = "green"; Movable = $false; Note = "Yarn 缓存" }
$devCachePaths += @{ Path = "$localAppData\pnpm-cache";                   Tier = "green"; Movable = $false; Note = "pnpm 缓存" }
$devCachePaths += @{ Path = "$localAppData\pnpm-store";                   Tier = "green"; Movable = $false; Note = "pnpm store" }

# pip 缓存
$pipCache = "$userProfile\AppData\Local\pip\Cache"
if (Test-Path $pipCache) {
    $devCachePaths += @{ Path = $pipCache; Tier = "green"; Movable = $false; Note = "pip 缓存，可安全清理" }
}

# NuGet 缓存
$nugetCache = "$userProfile\.nuget\packages"
if (Test-Path $nugetCache) {
    $devCachePaths += @{ Path = $nugetCache; Tier = "green"; Movable = $false; Note = "NuGet 包缓存，清理后会按需重新下载" }
}

# Docker
$dockerDesktop = "$localAppData\Docker"
if (Test-Path $dockerDesktop) {
    $devCachePaths += @{ Path = $dockerDesktop; Tier = "yellow"; Movable = $false; Note = "Docker Desktop 数据，建议通过 docker system prune 清理" }
}
$wslVhdx = "$localAppData\Packages\CanonicalGroupLimited*\LocalState\ext4.vhdx"
$wslFiles = Get-Item $wslVhdx -ErrorAction SilentlyContinue
foreach ($wf in $wslFiles) {
    $devCachePaths += @{
        Path = $wf.FullName; Tier = "red"; Movable = $false
        Note = "WSL2 虚拟磁盘，不可直接删除/迁移，使用 wsl --manage 或 wsl --export 管理"
    }
}

# VS Code / Cursor 扩展
foreach ($extDir in @("$userProfile\.vscode\extensions", "$userProfile\.cursor\extensions")) {
    if (Test-Path $extDir) {
        $devCachePaths += @{
            Path = $extDir; Tier = "yellow"; Movable = $false
            Note = "编辑器扩展目录，可通过修改扩展目录路径迁移"
        }
    }
}

# Gradle / Maven 缓存
foreach ($cacheDir in @("$userProfile\.gradle\caches", "$userProfile\.m2\repository")) {
    if (Test-Path $cacheDir) {
        $devCachePaths += @{
            Path = $cacheDir; Tier = "green"; Movable = $false
            Note = "Java 构建工具缓存，可安全清理后按需重新下载"
        }
    }
}

# =====================================================
# 用户文件夹（带 OneDrive/重定向检测）
# =====================================================
$userFolderPaths = @()
if ($ScanMovable) {
    $userFolderDefs = @(
        @{ Name = "Documents"; Path = "$userProfile\Documents" }
        @{ Name = "Desktop";   Path = "$userProfile\Desktop" }
        @{ Name = "Downloads"; Path = "$userProfile\Downloads" }
        @{ Name = "Pictures";  Path = "$userProfile\Pictures" }
        @{ Name = "Videos";    Path = "$userProfile\Videos" }
        @{ Name = "Music";     Path = "$userProfile\Music" }
    )

    foreach ($def in $userFolderDefs) {
        if (-not (Test-Path $def.Path)) { continue }

        # 检查是否已经是 junction
        $junctionInfo = Test-IsJunction -Path $def.Path
        if ($junctionInfo.is_junction) {
            $userFolderPaths += @{
                Path = $def.Path; Tier = "red"; Movable = $false
                Note = "此文件夹已经是 junction（指向 $($junctionInfo.target)），不需要重复迁移"
            }
            continue
        }

        # 检查文件夹重定向
        $isRedirected = Test-FolderRedirection -Path $def.Path
        if ($isRedirected) {
            $userFolderPaths += @{
                Path = $def.Path; Tier = "red"; Movable = $false
                Note = "此文件夹已被企业组策略重定向到网络路径，禁止迁移"
            }
            continue
        }

        # 检查云同步管理
        $cloudInfo = Test-CloudSyncManaged -Path $def.Path
        if ($cloudInfo.managed) {
            $userFolderPaths += @{
                Path = $def.Path; Tier = "yellow"; Movable = $false
                Note = "此文件夹由 $($cloudInfo.service) 同步管理，junction 迁移可能导致同步冲突。建议先暂停同步或通过 $($cloudInfo.service) 设置移动"
            }
            continue
        }

        # 检查 OneDrive（补充检测：环境变量和进程）
        $isOneDrive = Test-OneDriveManaged -Path $def.Path
        if ($isOneDrive) {
            $userFolderPaths += @{
                Path = $def.Path; Tier = "yellow"; Movable = $false
                Note = "此文件夹由 OneDrive 同步管理，junction 迁移可能导致同步冲突。建议先暂停同步或使用 OneDrive 设置移动"
            }
            continue
        }

        # 正常文件夹
        $userFolderPaths += @{
            Path = $def.Path; Tier = "green"; Movable = $true
            Note = "$($def.Name)，junction 迁移安全"
        }
    }

    # 动态搜索微信数据目录
    $wechatDirs = Get-ChildItem -LiteralPath $userProfile -Directory -Filter "*wechat*" -ErrorAction SilentlyContinue
    foreach ($wd in $wechatDirs) {
        $userFolderPaths += @{
            Path = $wd.FullName; Tier = "yellow"; Movable = $true
            Note = "微信数据，迁移后可能需要重新索引聊天记录"
        }
    }
}

$systemLogPaths = @(
    @{ Path = "C:\Windows\Logs";                       Tier = "green";  Movable = $false; Note = "Windows 日志文件" }
    @{ Path = "C:\Windows\System32\winevt\Logs";       Tier = "red";    Movable = $false; Note = "事件日志，建议通过事件查看器管理" }
    @{ Path = "$localAppData\CrashDumps";              Tier = "green";  Movable = $false; Note = "应用崩溃转储文件" }
)

$otherPaths = @(
    @{ Path = "C:\`$Recycle.Bin";                      Tier = "green";  Movable = $false; Note = "回收站" }
    @{ Path = "$localAppData\Microsoft\Windows\Explorer"; Tier = "green"; Movable = $false; Note = "缩略图缓存（含其他数据）" }
    @{ Path = "C:\Windows\SoftwareDistribution\DeliveryOptimization"; Tier = "green"; Movable = $false; Note = "传递优化缓存" }
    @{ Path = "C:\Windows.old";                        Tier = "yellow"; Movable = $false; Note = "旧 Windows 安装，确认不再需要后可删除" }
)

# =====================================================
# 游戏平台库（动态检测）
# =====================================================
$gamePaths = @(Find-GameLibraries)

# =====================================================
# 系统信息 + 安全检测
# =====================================================
Write-Host "扫描 C 盘空间..." -ForegroundColor Cyan

$drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | ForEach-Object {
    $letter = "$($_.Name):"
    $enc = Get-DriveEncryption -DriveLetter $letter
    [ordered]@{
        letter        = $letter
        total_gb      = [math]::Round($_.Used / 1GB + $_.Free / 1GB, 2)
        free_gb       = [math]::Round($_.Free / 1GB, 2)
        bitlocker     = $enc
    }
}

# OneDrive 状态
$onedriveStatus = "not_detected"
if ($env:OneDrive -or $env:OneDriveCommercial) { $onedriveStatus = "active" }
elseif (Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue) { $onedriveStatus = "running" }

$systemInfo = [ordered]@{
    os             = (Get-CimInstance Win32_OperatingSystem).Caption
    hostname       = $env:COMPUTERNAME
    username       = $env:USERNAME
    onedrive       = $onedriveStatus
    drives         = $drives
}

# =====================================================
# 执行扫描
# =====================================================
$groups = [ordered]@{}

Write-Host "  扫描临时文件..." -ForegroundColor Gray
$groups["temp"] = @(Get-ScanGroup -Group "temp" -Items $tempPaths -Threshold $MinSizeMB)

Write-Host "  扫描浏览器缓存..." -ForegroundColor Gray
$groups["browser_cache"] = @(Get-ScanGroup -Group "browser_cache" -Items $browserCachePaths -Threshold $MinSizeMB)

Write-Host "  扫描应用缓存..." -ForegroundColor Gray
$groups["app_cache"] = @(Get-ScanGroup -Group "app_cache" -Items $appCachePaths -Threshold $MinSizeMB)

Write-Host "  扫描开发者工具缓存..." -ForegroundColor Gray
$groups["dev_cache"] = @(Get-ScanGroup -Group "dev_cache" -Items $devCachePaths -Threshold $MinSizeMB)

if ($ScanMovable) {
    Write-Host "  扫描用户文件夹..." -ForegroundColor Gray
    $groups["user_folders"] = @(Get-ScanGroup -Group "user_folders" -Items $userFolderPaths -Threshold $MinSizeMB)
}

Write-Host "  扫描游戏库..." -ForegroundColor Gray
$groups["game_library"] = @(Get-ScanGroup -Group "game_library" -Items $gamePaths -Threshold $MinSizeMB)

Write-Host "  扫描系统日志..." -ForegroundColor Gray
$groups["system_logs"] = @(Get-ScanGroup -Group "system_logs" -Items $systemLogPaths -Threshold $MinSizeMB)

Write-Host "  扫描其他可清理项..." -ForegroundColor Gray
$groups["other"] = @(Get-ScanGroup -Group "other" -Items $otherPaths -Threshold $MinSizeMB)

# --- 处理 agent 传入的额外路径 ---
if ($ExtraPaths.Count -gt 0) {
    Write-Host "  扫描额外路径..." -ForegroundColor Gray
    $extraResults = @()
    foreach ($ep in $ExtraPaths) {
        $sizeMB = Get-FolderSizeMB -Path $ep
        if ($sizeMB -ge $MinSizeMB) {
            $extraResults += [ordered]@{
                path    = $ep
                size_mb = $sizeMB
                tier    = "yellow"
                movable = $false
                note    = "agent 探索发现的额外路径"
            }
        }
    }
    $groups["extra"] = @($extraResults)
}

# --- 输出 JSON ---
$output = [ordered]@{
    system    = $systemInfo
    groups    = $groups
    scan_time = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
}

Write-Host "`n扫描完成。" -ForegroundColor Green

# 输出 OneDrive/加密风险提示
$odNote = if ($onedriveStatus -ne "not_detected") { " [检测到 OneDrive: $onedriveStatus]" } else { "" }
$cEnc = ($drives | Where-Object { $_.letter -eq "C:" }).bitlocker
$encNote = if ($cEnc -and $cEnc.encrypted) { " [C: BitLocker 已启用 - 注意目标盘加密状态]" } else { "" }
if ($odNote -or $encNote) {
    Write-Host "⚠ 安全提示:$odNote$encNote" -ForegroundColor Yellow
}

$json = $output | ConvertTo-Json -Depth 5

$json | Out-File -FilePath $OutputFile -Encoding UTF8 -Force
Write-Host "扫描数据已保存: $OutputFile" -ForegroundColor Green

$json
