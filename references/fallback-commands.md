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
   - 脚本失败：使用上方手动扫描命令
2. 将所有可清理项汇总成表格展示给用户（含安全分级列），由用户逐项确认
3. 逐项执行清理命令
4. 汇报释放空间：`Get-PSDrive C` 对比前后可用空间
5. 如果空间仍然紧张，给出补充建议：
   - 🟢 使用「磁盘清理」工具（`cleanmgr`）
   - 🟡 检查大型软件是否可卸载重装
   - 🟡 关闭休眠（`powercfg /h off`），失去快速启动
   - 🔴 页面文件不建议手动删除
