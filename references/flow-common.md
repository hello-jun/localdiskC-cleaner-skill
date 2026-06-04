# 公共操作步骤

两种流程（完整流程 / 仅清理流程）共享的操作步骤。

## 参数：迁移可用

由 SKILL.md 前置检查的分流结果决定：

| 分流结果 | 迁移可用 | 影响范围 |
|---------|---------|---------|
| 有其他盘且空间充足 | **是** | 表格含"可迁移"类型，询问菜单含迁移选项 |
| 只有 C 盘 | **否** | 表格全部显示"可清理"，询问菜单无迁移选项 |

---

## 第一步：全面扫描

1. **脚本基准扫描**（优先）：

```powershell
powershell -ExecutionPolicy Bypass -File "<脚本目录>\scan.ps1" | Tee-Object -Variable scanResult; $scanResult | Out-File "$env:TEMP\c-drive-scan-before.json" -Encoding UTF8
```

> `<脚本目录>` 替换为 SKILL.md 路径定位步骤获取的绝对路径。额外路径用 `-ExtraPaths "path1,path2"` 传入。

2. **Agent 动态扩展**：根据用户描述探索脚本未覆盖的可疑目录。

> **脚本失败时**：参阅 `fallback-commands.md` 中的「一键手动扫描 + JSON 构建」，将 JSON 保存到 `$env:TEMP\c-drive-scan-before.json`，后续仍可生成 HTML 报告。

## 第二步：生成报告并展示

扫描完成后，必须立即执行以下操作。

### 步骤 2a：生成 HTML 分析报告并自动打开

```powershell
powershell -ExecutionPolicy Bypass -File "<脚本目录>\build_report.ps1" -InputFile "$env:TEMP\c-drive-scan-before.json"
```

> 报告会自动生成到桌面并在浏览器中打开。若脚本不可用，使用 `fallback-commands.md` 中的「内联 HTML 报告生成」。

### 步骤 2b：在终端中展示可清理和可迁移列表

解析扫描结果，在终端中以表格形式展示所有可清理和可迁移项目：

```powershell
$scanData = Get-Content "$env:TEMP\c-drive-scan-before.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$allItems = @()
foreach ($groupName in $scanData.groups.PSObject.Properties.Name) {
    $group = $scanData.groups.$groupName
    foreach ($item in $group) {
        $allItems += [ordered]@{
            类别 = $groupName
            项目 = Split-Path $item.path -Leaf
            路径 = $item.path
            大小GB = [math]::Round($item.size_mb / 1024, 2)
            分级 = switch ($item.tier) {
                "green" { "🟢 安全" }
                "yellow" { "🟡 谨慎" }
                "red" { "🔴 危险" }
            }
            类型 = if ($item.movable -and $迁移可用) { "可迁移" } else { "可清理" }
            说明 = $item.note
        }
    }
}
$allItems | Sort-Object 大小GB -Descending | Format-Table -AutoSize
```

> **`$迁移可用`**：仅 C 盘时为 `$false`，所有项目类型列均显示"可清理"。

**表格格式要求**：
- 必须包含列：类别、项目、路径、大小(GB)、分级、类型、说明
- 按大小从大到小排序
- 使用安全分级符号：🟢安全、🟡谨慎、🔴危险

### 步骤 2c：询问用户操作

展示列表后，询问用户要执行哪些操作。

**迁移可用 = 是** 时：

> 以上是扫描发现的可清理和可迁移项目（HTML报告已自动打开）。请告诉我您想要执行哪些操作：
> 1. 清理所有🟢安全项目
> 2. 清理特定类别（如临时文件、浏览器缓存等）
> 3. 迁移特定文件夹到其他盘
> 4. 查看详细说明后再决定
> 请输入您的选择（如：1、2+临时文件、3+文档文件夹）

**迁移可用 = 否** 时：

> 以上是扫描发现的可清理项目（HTML报告已自动打开）。请告诉我您想要执行哪些操作：
> 1. 清理所有🟢安全项目
> 2. 清理特定类别（如临时文件、浏览器缓存等）
> 3. 查看详细说明后再决定
> 请输入您的选择（如：1、2+临时文件）

## 第三步：清理临时文件

向用户展示确认表（项目/路径/大小/分级/操作），确认后逐项清理。

> **清理前安全检查**（文件锁、自动保存文件排除、下载文件排除）：参阅 `safety-rules.md`

## 第四步：清理应用缓存

将应用缓存展示给用户确认（应用/路径/大小/分级/影响），不能确认则不清理。

## 第五步：验证并报告

1. 验证 junction（仅完整流程执行了迁移时需要）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File "<脚本目录>\verify.ps1"
   ```

2. 重新扫描并生成结果报告：
   ```powershell
   powershell -ExecutionPolicy Bypass -File "<脚本目录>\scan.ps1" | Out-File "$env:TEMP\c-drive-scan-after.json" -Encoding UTF8
   powershell -ExecutionPolicy Bypass -File "<脚本目录>\build_report.ps1" -Mode result -BeforeFile "$env:TEMP\c-drive-scan-before.json" -InputFile "$env:TEMP\c-drive-scan-after.json"
   ```

> **脚本失败时**：参阅 `fallback-commands.md` 获取手动验证命令和内联报告生成。

3. 在对话中展示操作汇总表（操作/项目/释放空间/分级/状态）。

## 第六步：补充建议

空间仍紧张时，向用户提供以下建议：

| 建议 | 分级 | 命令/操作 |
|------|------|----------|
| 磁盘清理工具 | 🟢 安全 | `cleanmgr` |
| 卸载重装到其他盘 | 🟡 谨慎 | 通过"设置 → 应用"卸载后重装到目标盘 |
| 关闭休眠文件 | 🟡 谨慎 | `powercfg /h off`（释放约等于内存大小的空间） |
| 调整页面文件 | 🔴 危险 | 通过"系统属性 → 高级 → 性能设置 → 高级 → 虚拟内存"调整 |
