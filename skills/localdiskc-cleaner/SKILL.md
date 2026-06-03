---
name: localdiskc-cleaner
description: 分析并清理 Windows C 盘空间。当用户要求释放磁盘空间、清理 C 盘、将文件夹移动到其他盘符、或解决 Windows 磁盘空间不足警告时使用。
license: MIT
compatibility: 仅适用于 Windows 10/11，需要管理员权限（部分操作），目标盘需有足够可用空间
---

# C 盘空间清理工具

引导 Windows 用户通过安全的分步操作回收 C 盘空间。

## 触发条件

- 用户报告 C 盘空间不足
- 用户要求将文件从 C 盘移动到其他盘
- 用户想要清理 Windows 临时文件和缓存
- 用户提到"C盘满了"、"C盘空间不足"、"清理C盘"

## 前置检查

开始前确认：1. 当前系统是 Windows  2. 用户具有管理员权限（部分操作需要）

```powershell
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -ne 'C' } | Select-Object Name, @{N='可用空间GB';E={[math]::Round($_.Free/1GB,2)}}
```

分流：**有其他盘且空间充足** → 完整流程（清理 + 迁移）；**只有 C 盘** → 仅清理流程

确认：Windows 用户名（`$env:USERNAME`）+ 如需迁移：目标盘符和路径

## 安全分级

所有展示给用户的表格**必须**包含安全分级列。

| 级别 | 含义 | Agent 行为 |
|------|------|-----------|
| 🟢 安全 | 临时文件/缓存，可自动重建 | 说明后可直接执行 |
| 🟡 谨慎 | 数据可能有价值 | 逐项说明影响，获得明确确认 |
| 🔴 危险 | 系统关键/不可逆 | 永不删除，仅建议系统工具处理 |

## 执行阶段

### 第一阶段：全面扫描

1. **脚本基准扫描**（优先）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/scan.ps1 | Tee-Object -Variable scanResult; $scanResult | Out-File "$env:TEMP\c-drive-scan-before.json" -Encoding UTF8
```

> 脚本路径相对于技能安装目录，找不到时用绝对路径。额外路径用 `-ExtraPaths "path1,path2"` 传入。

2. **Agent 动态扩展**：根据用户描述探索脚本未覆盖的可疑目录。

> **脚本失败时**：参阅 `references/fallback-commands.md` 获取手动扫描命令模板。

将结果以表格展示（类别/项目/路径/大小/分级/说明），询问用户要执行哪些操作。

### 第二阶段：清理临时文件

> 两种流程都执行。

向用户展示确认表（项目/路径/大小/分级/操作），确认后逐项清理。

> **清理前安全检查**（文件锁、自动保存文件排除、下载文件排除）：参阅 `references/safety-rules.md`

### 第三阶段：使用 junction 移动大文件夹

> **仅完整流程执行**。

**迁移前必须通过 6 项前置检查**（云同步检测、重定向检测、已有 junction 检测、BitLocker 检查、NTFS 文件系统检查、空间检查）：

> 详细前置检查和 10 步迁移操作命令：参阅 `references/migration-guide.md`
> 安全规则细则（云同步/UWP/加密/游戏/开发者）：参阅 `references/safety-rules.md`

核心原则：**复制 → 验证完整性（数量+大小必须一致） → rename 备份 → 创建 junction → 测试 → 删备份**

### 第四阶段：清理应用缓存

将应用缓存展示给用户确认（应用/路径/大小/分级/影响），不能确认则不清理。

### 第五阶段：验证并报告

1. 验证 junction：`powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`
2. 生成结果报告：
```powershell
powershell -ExecutionPolicy Bypass -File scripts/scan.ps1 | Out-File "$env:TEMP\c-drive-scan-after.json" -Encoding UTF8
powershell -ExecutionPolicy Bypass -File scripts/build_report.ps1 -Mode result -BeforeFile "$env:TEMP\c-drive-scan-before.json" -InputFile "$env:TEMP\c-drive-scan-after.json"
```

> **脚本失败时**：参阅 `references/fallback-commands.md` 获取手动验证命令。

在对话中展示操作汇总表（操作/项目/释放空间/分级/状态）。

## 仅清理流程（只有 C 盘时）

1. 扫描可清理项（脚本或 `references/fallback-commands.md` 手动扫描）
2. 表格展示，用户逐项确认
3. 逐项执行清理
4. 汇报释放空间
5. 空间仍紧张时给补充建议（🟢 `cleanmgr` / 🟡 卸载重装 / 🟡 `powercfg /h off` / 🔴 页面文件通过系统设置）

## 核心安全规则

- **只重命名，不删除** — junction 验证通过前绝不删原文件夹
- **用 junction（`mklink /J`）** 而非符号链接 — 无需管理员权限
- **移动前关闭程序 + 检查文件锁**
- **绝不移动系统文件夹**（Windows、Program Files 等）
- **云同步文件夹不建议 junction 迁移**
- 建议用户**操作前创建系统还原点**

> 详细安全规则和各场景处理方式：参阅 `references/safety-rules.md`

## 脚本参考

| 脚本 | 用途 | 关键参数 |
|------|------|---------|
| `scan.ps1` | 基准扫描，输出 JSON（含 OneDrive/加密检测） | `-MinSizeMB 50` `-ExtraPaths "p1,p2"` |
| `verify.ps1` | 验证 junction 完整性 | 无 |
| `build_report.ps1` | 生成 HTML 报告 | `-Mode report` 或 `-Mode result -BeforeFile <before.json>` |

scan.ps1 输出分组：`temp` / `browser_cache` / `app_cache` / `dev_cache` / `user_folders` / `game_library` / `system_logs` / `other` / `extra`

> 典型使用流程（完整命令序列）：参阅 `references/migration-guide.md`
