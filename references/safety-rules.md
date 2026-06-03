# 安全规则细则

本文件包含各场景的详细安全规则。SKILL.md 中为核心安全要点，此处为展开说明。

## 清理临时文件安全检查（Phase 2 详细）

清理前必须执行以下检查：

### 1. 关闭相关程序

浏览器缓存清理前关闭浏览器；WPS 缓存清理前关闭 WPS；Windows 更新缓存清理前停止 Windows Update 服务。

### 2. 检查文件锁

```powershell
$locked = @()
Get-Process | ForEach-Object {
    try { $_.Modules.FileName } catch {}
} | Where-Object { $_ -like "$env:TEMP*" } | ForEach-Object { $locked += $_ }
if ($locked.Count -gt 0) { Write-Warning "以下文件被锁定，跳过: $($locked -join ', ')" }
```

### 3. 排除应用自动保存文件

`%TEMP%` 中可能有 Office 自动恢复文件和 Photoshop 临时文件，**不得删除**：

```powershell
# 安全清理：排除自动保存文件和 Office 锁文件
Get-ChildItem $env:TEMP -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '^~\$' -and $_.Name -notmatch '^~[aw][ar]\d{4}\.tmp$' -and $_.Name -notmatch '^~.*\.tmp$' } |
    Remove-Item -Force -ErrorAction SilentlyContinue
```

排除规则：
- `~$*` — Office 锁定文件（`~$report.docx`、`~$sheet.xlsx` 等），匹配所有 `~$` 开头的文件
- `~ar*.tmp`、`~wr*.tmp` — Office 自动恢复文件
- `~*.tmp` — 其他应用临时文件
- `*.crdownload` — Chrome 正在下载
- `*.partial` — Edge 正在下载

## OneDrive / 云同步规则

OneDrive、Dropbox、Google Drive、坚果云管理的文件夹**不建议通过 junction 迁移**，可能导致同步冲突或重复上传。

scan.ps1 会自动检测云同步状态并标记受影响的文件夹为 🟡 `movable: false`。

### 手动检测命令

```powershell
# OneDrive
Test-Path $env:OneDrive
# Dropbox
Test-Path "$env:USERPROFILE\Dropbox"
# Google Drive
Test-Path "$env:USERPROFILE\Google Drive"
# 坚果云
Test-Path "$env:LOCALAPPDATA\Nutstore"
```

### 正确做法

引导用户在对应云同步工具的设置中更改同步目录位置，或暂停同步后再迁移。

## UWP 应用数据规则

`%LOCALAPPDATA%\Packages` 下的 UWP 应用数据**绝对禁止通过 junction 迁移**。

- UWP 应用运行在沙箱中，不识别 junction，迁移后应用会崩溃
- 如果发现此目录较大，仅可清理特定应用的缓存子目录（如 `Packages\*\LocalCache`）
- scan.ps1 已将此目录标记为 🔴

## 磁盘加密（BitLocker）规则

如果 C 盘启用了 BitLocker，**迁移到未加密的目标盘会降低数据安全性**。

### 检测命令

```powershell
Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus
```

scan.ps1 输出的 `drives[].bitlocker` 字段也会报告每块盘的加密状态。

### 风险矩阵

| C 盘 | 目标盘 | 建议 |
|------|--------|------|
| 加密 | 加密 | 安全，可正常迁移 |
| 加密 | 未加密 | 需提醒用户，建议启用目标盘 BitLocker |
| 未加密 | 未加密 | 无额外风险 |

## 游戏平台规则

| 平台 | 迁移方式 | 说明 |
|------|---------|------|
| Steam | 客户端「设置 → 存储 → 添加驱动器」 | 不要用 junction，会破坏游戏验证 |
| Epic Games | Launcher「卸载 → 重装到其他盘」 | 同上 |
| Xbox Game Pass | **不支持迁移** | UWP 应用，由系统管理 |
| Microsoft Store | **不支持迁移** | 同上 |

scan.ps1 会扫描 `game_library` 分组并给出对应建议。

## 开发者环境规则

| 项目 | 规则 | 原因 |
|------|------|------|
| `node_modules` | 可删除后 `npm install` 重建，但**不要 junction 迁移** | 可能导致模块解析问题 |
| Docker 镜像 | 通过 `docker system prune -a` 清理 | 不要手动删除 Docker 数据目录 |
| WSL2 `ext4.vhdx` | 通过 `wsl --export/import` 管理 | 不可 junction 迁移，不可直接删除 |
| NuGet / pip / Maven 缓存 | 🟢 安全清理 | 清除后按需重新下载 |
| VS Code / Cursor 扩展 | 可迁移但需修改配置 | 修改 `--extensions-dir` 参数 |

## 常见可移动文件夹

| 文件夹 | 典型大小 | 分级 | junction 兼容性 |
|--------|---------|------|----------------|
| Documents（文档） | 10-100 GB | 🟢 安全 | 完全兼容 |
| Desktop（桌面） | 1-10 GB | 🟢 安全 | 完全兼容 |
| Downloads（下载） | 1-20 GB | 🟢 安全 | 完全兼容 |
| Pictures（图片） | 1-50 GB | 🟢 安全 | 完全兼容 |
| Videos（视频） | 1-50 GB | 🟢 安全 | 完全兼容 |
| xwechat_files（微信） | 10-50 GB | 🟡 谨慎 | 兼容，需重新索引 |
| AppData\Local\Temp | 1-5 GB | 🟢 安全 | 不适用（直接清理） |
| AppData\Local\kingsoft（WPS） | 5-15 GB | 🟡 谨慎 | 部分兼容 |
