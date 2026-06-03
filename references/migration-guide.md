# 文件夹迁移详细步骤

本文件包含 Phase 3（junction 迁移）的完整操作步骤和 PowerShell 命令。

## 前置检查（迁移前逐项确认）

### 1. 云同步检测

scan.ps1 输出中用户文件夹的 note 如果包含 "OneDrive" / "Dropbox" / "Google Drive" / "坚果云"，**不建议迁移**。

```powershell
Test-Path $env:OneDrive
Test-Path "$env:USERPROFILE\Dropbox"
Test-Path "$env:USERPROFILE\Google Drive"
Test-Path "$env:LOCALAPPDATA\Nutstore"
```

### 2. 文件夹重定向检测

scan.ps1 输出中标记为 🔴（企业重定向）的文件夹，**禁止迁移**。

### 3. 已有 junction 检测

scan.ps1 输出中 note 包含 "已经是 junction" 的文件夹，**跳过**（已迁移过）。

### 4. 磁盘加密检查

```powershell
Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus
```

C 盘加密但目标盘未加密时，需提醒用户。

### 5. 目标盘文件系统检查

```powershell
(Get-Volume -DriveLetter <目标盘>).FileSystemType
# 必须返回 NTFS，FAT32/exFAT 不支持 junction
```

### 6. 目标盘空间检查

```powershell
$sourceSize = (Get-ChildItem "<源路径>" -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum
$targetFree = (Get-PSDrive "<目标盘>").Free
if ($targetFree -lt $sourceSize * 1.1) { Write-Warning "目标盘空间不足" }
```

## 迁移操作步骤

确认前置检查通过后，对每个需要移动的文件夹执行以下步骤：

### 步骤 1：关闭相关程序

关闭微信、WPS、浏览器等可能访问源文件夹的程序。

### 步骤 2：检查文件锁（双重检查）

```powershell
# 检查 1：检测 Office 锁文件（~$*.docx / ~$*.xlsx / ~$*.pptx）
$officeLocks = Get-ChildItem "<源路径>" -Recurse -File -Filter "~$*" -Force -ErrorAction SilentlyContinue
if ($officeLocks.Count -gt 0) {
    Write-Warning "发现 Office 锁定文件，请先关闭 Word/Excel/PowerPoint："
    $officeLocks | ForEach-Object { Write-Warning "  $($_.FullName)" }
    return  # 终止迁移
}

# 检查 2：测试目录写权限
$testPath = Join-Path "<源路径>" "_locktest_$(Get-Random)"
New-Item $testPath -ItemType File -Force | Remove-Item -Force
if ($?) { Write-Host "文件夹未被锁定" } else { Write-Warning "文件夹被锁定，请关闭相关程序"; return }
```

> **重要**：如果发现 `~$*.docx` / `~$*.xlsx` / `~$*.pptx` 文件，说明 Office 应用正在使用此目录中的文件。即使 `Rename-Item` 在 Windows 上可以重命名含锁定文件的目录，**也会导致用户后续保存的内容写入 _backup 目录，在删除备份时丢失**。必须等待用户关闭所有 Office 应用后再继续。

### 步骤 3：检查目标盘文件系统

```powershell
(Get-Volume -DriveLetter <目标盘>).FileSystemType
# 必须返回 NTFS，否则终止迁移
```

### 步骤 4：检查目标盘剩余空间

```powershell
$src = (Get-ChildItem "<源路径>" -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum
$free = (Get-PSDrive "<目标盘>").Free
if ($free -lt $src * 1.1) { Write-Error "目标盘空间不足，需要 $([math]::Round($src*1.1/1GB,1)) GB，可用 $([math]::Round($free/1GB,1)) GB"; return }
```

### 步骤 5：复制文件

```powershell
robocopy "<源路径>" "<目标路径>" /E /COPY:DAT /R:5 /W:10 /MT:8 /NFL /NDL /NP /DCOPY:T
```

> 使用 `/COPY:DAT` 而非 `/COPYALL`。`/COPYALL` 需要管理员权限，`/COPY:DAT` 只复制数据、属性、时间戳，普通用户即可执行。

robocopy 退出码说明：
- 0 = 无变化
- 1 = 文件已复制
- 2 = 额外文件
- 3 = 1+2
- **8+ = 错误，需要关注**

### 步骤 6：验证复制完整性（关键步骤，不可跳过）

```powershell
$src = Get-ChildItem "<源路径>" -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum
$dst = Get-ChildItem "<目标路径>" -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum
Write-Host "源: $($src.Count) 个文件, $([math]::Round($src.Sum/1GB,2)) GB"
Write-Host "目标: $($dst.Count) 个文件, $([math]::Round($dst.Sum/1GB,2)) GB"
if ($src.Count -ne $dst.Count) { Write-Error "文件数量不一致！源 $($src.Count) vs 目标 $($dst.Count)。禁止继续操作。"; return }
if ([math]::Abs($src.Sum - $dst.Sum) -gt 1MB) { Write-Error "文件大小不一致！禁止继续操作。"; return }
```

> **如果验证不通过，绝不继续后续步骤。** 分析 robocopy 日志找出跳过的文件，关闭锁定进程后重新复制。

### 步骤 7：重命名原文件夹作为备份

```powershell
Rename-Item -Path "<源路径>" -NewName "<文件夹名>_backup"
```

例如：`Rename-Item -Path "C:\Users\X\Documents" -NewName "Documents_backup"`

### 步骤 8：创建 junction

```powershell
cmd /c mklink /J "<源路径>" "<目标盘>:<目标路径>"
```

### 步骤 9：测试

打开相关程序，验证文件可以正常访问。

### 步骤 10：确认无误后删除备份

## 典型使用流程

```powershell
# 脚本路径说明：以下使用相对路径，实际运行时请替换为绝对路径
# 例如: $scriptPath = "$env:USERPROFILE\.skills\localdiskc-cleaner\scripts"

# 1. 扫描并保存结果
powershell -ExecutionPolicy Bypass -File scripts/scan.ps1 | Out-File "$env:TEMP\c-drive-scan-before.json" -Encoding UTF8

# 2. 生成分析报告（可选）
powershell -ExecutionPolicy Bypass -File scripts/build_report.ps1 -InputFile "$env:TEMP\c-drive-scan-before.json"

# 3. ... 执行清理和迁移操作 ...

# 4. 清理后再次扫描
powershell -ExecutionPolicy Bypass -File scripts/scan.ps1 | Out-File "$env:TEMP\c-drive-scan-after.json" -Encoding UTF8

# 5. 验证 junction
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1

# 6. 生成结果报告（对比前后差异）
powershell -ExecutionPolicy Bypass -File scripts/build_report.ps1 -Mode result -BeforeFile "$env:TEMP\c-drive-scan-before.json" -InputFile "$env:TEMP\c-drive-scan-after.json"
```
