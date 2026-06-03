# Windows 数据布局参考

为 AI agent 提供 Windows 磁盘数据分布的权威参考，辅助扫描分类和清理决策。

## 标准用户目录

所有用户数据位于 `C:\Users\<用户名>\`（即 `$env:USERPROFILE`）。

| 目录 | 环境变量 | 典型大小 | junction 兼容性 | 分级 |
|------|---------|---------|----------------|------|
| Desktop | - | 1-10 GB | 完全兼容 | 🟢 |
| Documents | - | 10-100 GB | 完全兼容 | 🟢 |
| Downloads | - | 1-20 GB | 完全兼容 | 🟢 |
| Pictures | - | 1-50 GB | 完全兼容 | 🟢 |
| Videos | - | 1-50 GB | 完全兼容 | 🟢 |
| Music | - | 1-10 GB | 完全兼容 | 🟢 |
| Favorites | - | <100 MB | 完全兼容 | 🟢 |
| AppData | `$env:APPDATA` / `$env:LOCALAPPDATA` | 见下文 | 部分兼容 | 按子目录分 |

**注意**：使用 `$env:USERPROFILE` 而非 `C:\Users\$env:USERNAME`，因为用户名可能包含中文字符，且配置文件路径可能被重定向。

## AppData 三层结构

### AppData\Local（`$env:LOCALAPPDATA`）

机器特定的缓存和临时数据，通常可以清理。

| 子目录 | 说明 | 典型大小 | 分级 |
|--------|------|---------|------|
| `\Temp` | 用户临时文件 | 1-5 GB | 🟢 |
| `\Microsoft\Windows\Explorer` | 缩略图缓存 + 其他 | 0.1-1 GB | 🟢 |
| `\Microsoft\Windows\INetCache` | IE/Edge 临时文件 | 0.1-1 GB | 🟢 |
| `\CrashDumps` | 应用崩溃转储 | 0-2 GB | 🟢 |
| `\Google\Chrome\User Data` | Chrome 全部数据 | 1-10 GB | 缓存🟢/其他🟡 |
| `\Microsoft\Edge\User Data` | Edge 全部数据 | 1-5 GB | 缓存🟢/其他🟡 |
| `\Kingsoft` | WPS Office 数据 | 5-15 GB | 🟡 |
| `\DingTalk` | 钉钉缓存 | 0.5-5 GB | 🟡 |
| `\Bytedance\Lark` / `\feishu` | 飞书缓存 | 0.5-5 GB | 🟡 |

### AppData\Roaming（`$env:APPDATA`）

跨机器同步的配置和应用数据，通常不应随意删除。

| 子目录 | 说明 | 典型大小 | 分级 |
|--------|------|---------|------|
| `\Tencent` | QQ/微信/TIM 配置和数据 | 1-10 GB | 🟡 |
| `\Microsoft\Windows\Start Menu` | 开始菜单快捷方式 | <10 MB | 🔴 |
| `\Microsoft\Windows\Themes` | 主题配置 | <50 MB | 🔴 |

### AppData\LocalLow

低完整性级别应用的数据，通常较小，一般不需要清理。

## 应用专属目录

### 微信（WeChat）

```
%USERPROFILE%\xwechat_files\          # 微信文件存储（通常最大）
%USERPROFILE%\Documents\WeChat Files\  # 部分版本的文件存储
%APPDATA%\Tencent\WeChat\              # 配置和日志
```

- **迁移注意**：junction 兼容，但迁移后首次打开微信会重新索引聊天记录，耗时较长
- **不要删除**：`Msg` 目录下的数据库文件

### WPS Office

```
%LOCALAPPDATA%\Kingsoft\WPS Cloud Files\  # WPS 云文档缓存
%LOCALAPPDATA%\Kingsoft\WPS Office\       # 程序缓存
%APPDATA%\kingsoft\                        # 配置和模板
```

- **清理注意**：`WPS Cloud Files` 可能包含未同步到云端的本地文档

### 钉钉（DingTalk）

```
%LOCALAPPDATA%\DingTalk\  # 缓存和接收文件
```

### 飞书（Lark/飞书）

```
%LOCALAPPDATA%\Bytedance\Lark\  # 国际版
%LOCALAPPDATA%\feishu\          # 国内版
%APPDATA%\Bytedance\Lark\       # 应用数据
```

### Chrome

```
%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache\              # 🟢 缓存
%LOCALAPPDATA%\Google\Chrome\User Data\Default\Code Cache\         # 🟢 代码缓存
%LOCALAPPDATA%\Google\Chrome\User Data\Default\Service Worker\     # 🟢 SW 缓存
%LOCALAPPDATA%\Google\Chrome\User Data\Default\                    # 🟡 整个 Default 包含书签/密码
```

**不要删除整个 `User Data` 目录**，仅清理 `Cache` 和 `Code Cache` 子目录。

### Edge

结构与 Chrome 相同（同为 Chromium），路径在 `%LOCALAPPDATA%\Microsoft\Edge\User Data\`。

## OneDrive 与云同步

### OneDrive 检测

OneDrive 在 Windows 10/11 中深度集成，常见的用户文件夹可能被 OneDrive 接管：

```
%USERPROFILE%\OneDrive\                          # 个人 OneDrive
%USERPROFILE%\OneDrive - 公司名\                  # 企业 OneDrive
%USERPROFILE%\OneDrive - 个人昵称\                # 混合场景
```

**检测方法**：
- 环境变量：`$env:OneDrive`、`$env:OneDriveCommercial`
- 进程：`Get-Process OneDrive -ErrorAction SilentlyContinue`
- scan.ps1 的 `system.onedrive` 字段

### OneDrive 占位符（文件按需）

OneDrive "文件按需"功能会在本地创建占位符，实际文件在云端。特征：
- 文件属性包含 `RecallOnDataAccess` 或 `Offline` 标记
- `Get-Item` 显示大小为 0 但实际云端有数据

**注意**：对 OneDrive 管理的文件夹创建 junction 会导致：
- OneDrive 检测到文件夹结构变化
- 可能触发全量重新同步
- 可能产生重复文件或同步冲突

### 正确处理方式

- 引导用户通过 OneDrive 设置 → 同步文件夹 → 更改位置
- 或暂时暂停 OneDrive 同步 → 迁移 → 恢复同步

## 文件夹重定向（企业组策略）

企业 AD 环境可能通过组策略将用户文件夹重定向到文件服务器：

```
\\fileserver\users\用户名\Documents
\\fileserver\users\用户名\Desktop
```

**检测方法**：
- `(Get-Item "$env:USERPROFILE\Documents").Target` 返回 `\\server\...` 网络路径
- scan.ps1 自动标记为 🔴 `movable: false`

**处理**：禁止迁移。重定向文件夹由 IT 管理员管理。

## 磁盘加密（BitLocker）

### 检测方法

```powershell
Get-BitLockerVolume | Select-Object MountPoint, ProtectionStatus, EncryptionMethod
```

scan.ps1 输出中每块盘的 `bitlocker` 字段也包含此信息。

### 风险

| C 盘 | 目标盘 | 风险 |
|------|--------|------|
| 加密 | 加密 | 安全，可正常迁移 |
| 加密 | 未加密 | 数据安全性降低，需提醒用户 |
| 未加密 | 未加密 | 无额外风险 |
| 未加密 | 加密 | 安全性提升，但 junction 可能需额外权限 |

## 开发者工具数据

### Node.js / 前端

| 路径 | 说明 | 典型大小 | 分级 |
|------|------|---------|------|
| `%LOCALAPPDATA%\npm-cache` | npm 缓存 | 1-10 GB | 🟢 |
| `%LOCALAPPDATA%\Yarn\Cache` | Yarn 缓存 | 0.5-5 GB | 🟢 |
| `%LOCALAPPDATA%\pnpm-cache` | pnpm 缓存 | 1-10 GB | 🟢 |
| 项目目录下 `node_modules` | 依赖包 | 单个 0.1-2 GB | 🟢 可删后 npm install |

### Python

| 路径 | 说明 | 分级 |
|------|------|------|
| `%LOCALAPPDATA%\pip\Cache` | pip 缓存 | 🟢 |
| `%USERPROFILE%\.conda` | Conda 环境 | 🟡 可能含自定义包 |

### .NET / Java

| 路径 | 说明 | 分级 |
|------|------|------|
| `%USERPROFILE%\.nuget\packages` | NuGet 包缓存 | 🟢 |
| `%USERPROFILE%\.gradle\caches` | Gradle 缓存 | 🟢 |
| `%USERPROFILE%\.m2\repository` | Maven 本地仓库 | 🟢 |

### Docker / WSL2

| 路径 | 说明 | 分级 | 处理方式 |
|------|------|------|---------|
| `%LOCALAPPDATA%\Docker` | Docker Desktop 数据 | 🟡 | `docker system prune -a` |
| `%LOCALAPPDATA%\Packages\CanonicalGroupLimited*\LocalState\ext4.vhdx` | WSL2 虚拟磁盘 | 🔴 | `wsl --export/import` |

**WSL2 迁移方法**（不可用 junction）：
```powershell
wsl --export Ubuntu D:\wsl-backup.tar
wsl --unregister Ubuntu
wsl --import Ubuntu D:\WSL D:\wsl-backup.tar
```

### 编辑器扩展

| 路径 | 说明 | 分级 |
|------|------|------|
| `%USERPROFILE%\.vscode\extensions` | VS Code 扩展 | 🟡 可迁移但需修改配置 |
| `%USERPROFILE%\.cursor\extensions` | Cursor 扩展 | 🟡 同上 |

## 游戏平台

### Steam

```
<Steam安装路径>\steamapps\common\           # 游戏安装目录
<Steam安装路径>\steamapps\libraryfolders.vdf  # 库配置文件（包含额外库路径）
```

注册表位置：`HKCU:\Software\Valve\Steam\SteamPath`

**迁移方式**：Steam 客户端 → 设置 → 存储 → 添加驱动器 → 右键游戏 → 移动

### Epic Games

清单目录：`%LOCALAPPDATA%\Epic Games\EpicGamesLauncher\Data\Manifests\*.item`

每个 `.item` 文件是 JSON，包含 `InstallLocation` 字段。

**迁移方式**：Epic Games Launcher → 库 → 卸载 → 重新安装到其他盘

### Xbox Game Pass / Microsoft Store

```
C:\Program Files\ModifiableWindowsApps\      # Game Pass 游戏
C:\WindowsApps\                              # Microsoft Store 应用
```

**不可手动迁移**，UWP 应用由系统管理。

以下目录/文件应通过系统工具管理，不应由 agent 直接删除：

| 路径 | 说明 | 推荐管理方式 |
|------|------|-------------|
| `C:\Windows\WinSxS` | 组件存储，看起来很大但大部分是硬链接 | `DISM /Online /Cleanup-Image /StartComponentCleanup` |
| `C:\hiberfil.sys` | 休眠文件（与内存等大） | `powercfg /h off` 关闭休眠 |
| `C:\pagefile.sys` | 页面文件 | 系统设置 → 高级 → 性能 → 虚拟内存 |
| `C:\swapfile.sys` | UWP 应用交换文件 | 不可手动管理 |
| `C:\Windows\System32` | 系统核心 | 绝对禁止操作 |
| `C:\Program Files` / `Program Files (x86)` | 已安装程序 | 通过"设置 → 应用"卸载 |
| `C:\ProgramData` | 全局应用数据 | 不建议手动清理 |

## Tier 分配规则

根据路径模式快速判断安全级别：

### 🟢 安全（可直接清理）
- 匹配 `*\Temp\*` 或 `*\Temp`
- 匹配 `*\Cache\*` 或 `*\Code Cache\*`
- 匹配 `*\SoftwareDistribution\Download\*`
- 匹配 `*\Prefetch\*`
- 匹配 `*\CrashDumps\*`
- 匹配 `*\INetCache\*`
- 回收站
- 缩略图缓存

### 🟡 谨慎（需用户确认）
- 匹配 `*\Kingsoft\*`（WPS 数据）
- 匹配 `*\Tencent\*`（腾讯应用数据）
- 匹配 `*\DingTalk\*`（钉钉）
- 匹配 `*\Bytedance\*` 或 `*\feishu\*`（飞书）
- 匹配 `*\wechat\*` 或 `*\WeChat*`（微信）
- `C:\Windows.old`（旧系统）

### 🔴 危险（仅建议，不操作）
- 匹配 `C:\Windows\*`（非 Temp/Log 子目录）
- 匹配 `C:\Program Files\*`
- 匹配 `*\WinSxS\*`
- 匹配 `*\hiberfil.sys`、`*\pagefile.sys`、`*\swapfile.sys`
- 匹配 `C:\ProgramData\*`

## Junction 兼容性说明

| 应用 | Junction 迁移 | 说明 |
|------|--------------|------|
| Desktop/Documents/Downloads/Pictures/Videos/Music | ✅ 完全兼容 | Windows 原生支持，通过 junction 透明访问 |
| 微信（xwechat_files） | ✅ 兼容 | 迁移后首次启动会重新索引，耗时取决于数据量 |
| WPS Office | ⚠️ 部分兼容 | 缓存目录可迁移，但配置文件中可能存储了绝对路径 |
| 钉钉 | ⚠️ 未验证 | 理论可行但未经广泛测试 |
| 飞书 | ⚠️ 未验证 | 同上 |
| Chrome/Edge 缓存 | ✅ 兼容 | 浏览器会自动在 junction 指向的目录中读写 |

**最佳实践**：用户文件夹（Desktop/Documents 等）优先迁移，应用数据谨慎迁移。
