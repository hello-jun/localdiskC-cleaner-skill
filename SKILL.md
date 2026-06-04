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

### 分流决策

| 条件 | 流程 | 参阅 |
|------|------|------|
| 有其他盘且空间充足 | 完整流程（清理 + 迁移） | `references/flow-full.md` |
| 只有 C 盘 | 仅清理流程 | `references/flow-common.md` |

两种流程共享的操作步骤在 `references/flow-common.md` 中，完整流程额外包含迁移阶段。

确认：Windows 用户名（`$env:USERNAME`）+ 如需迁移：目标盘符和路径

## 脚本路径定位

在进入执行阶段之前，先定位脚本目录的绝对路径。运行以下命令：

```powershell
$found = $null
$d = $PWD.Path
while ($d -and -not $found) {
    $t = Join-Path $d "scripts\scan.ps1"
    if (Test-Path $t) { $found = Join-Path $d "scripts" }
    $d = Split-Path $d -Parent
}
if (-not $found) {
    foreach ($r in @("$env:USERPROFILE\.agents\skills","$env:USERPROFILE\.claude","$env:USERPROFILE\.opencode","$env:USERPROFILE")) {
        if ($found) { break }
        if (-not (Test-Path $r)) { continue }
        $f = Get-ChildItem $r -Recurse -Depth 5 -Filter scan.ps1 -File -EA SilentlyContinue |
             Where-Object { $_.FullName -match 'localdiskc-cleaner' } | Select-Object -First 1
        if ($f) { $found = Split-Path $f.FullName }
    }
}
if ($found) { Write-Host "CLEANER_SCRIPT_DIR=$found" } else { Write-Host "CLEANER_SCRIPT_DIR=NOT_FOUND" }
```

将输出中 `CLEANER_SCRIPT_DIR=` 后的路径记为 **脚本目录**，后续所有命令中用该绝对路径替代 `scripts/`。

> 若输出 `NOT_FOUND`，进入手动扫描模式（仍可生成 HTML 报告，参阅 `references/fallback-commands.md`）。

## 安全分级

所有展示给用户的表格**必须**包含安全分级列。

| 级别 | 含义 | Agent 行为 |
|------|------|-----------|
| 🟢 安全 | 临时文件/缓存，可自动重建 | 说明后可直接执行 |
| 🟡 谨慎 | 数据可能有价值 | 逐项说明影响，获得明确确认 |
| 🔴 危险 | 系统关键/不可逆 | 永不删除，仅建议系统工具处理 |

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
| `scan.ps1` | 基准扫描，输出 JSON（含 OneDrive/加密检测） | **`-OutputFile <path>`（必填）** `-MinSizeMB 50` `-ExtraPaths "p1,p2"` |
| `verify.ps1` | 验证 junction 完整性 | 无 |
| `build_report.ps1` | 生成 HTML 报告 | `-Mode report`（默认，自动查找扫描数据）或 `-Mode result`（清理前后对比） |

scan.ps1 输出分组：`temp` / `browser_cache` / `app_cache` / `dev_cache` / `user_folders` / `game_library` / `system_logs` / `other` / `extra`

## 参考文档索引

| 文档 | 用途 |
|------|------|
| `references/flow-common.md` | 公共操作步骤（扫描、清理、验证、补充建议） |
| `references/flow-full.md` | 完整流程编排（公共步骤 + 迁移阶段） |
| `references/migration-guide.md` | 迁移详细步骤和 PowerShell 命令 |
| `references/safety-rules.md` | 安全规则细则 |
| `references/fallback-commands.md` | 脚本失败时的手动命令模板 |
| `references/windows-data-layout.md` | Windows 数据布局参考 |
