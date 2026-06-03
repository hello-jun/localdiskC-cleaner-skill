# localdiskc-cleaner

> C 盘满了？一行命令搞定。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-Standard-green)](https://agentskills.io)
[![Windows](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-blue)](#)

一个清理本地磁盘 C 盘空间的工具技能，基于 [Agent Skills 协议](https://agentskills.io)，在 Claude Code、Codex、Cursor、Gemini CLI、VS Code、GitHub Copilot、Roo Code、OpenCode 等 40+ 兼容 runtime 中通用。

[看效果](#效果示例) · [环境准备](#环境准备小白用户必读) · [安装](#安装) · [解决哪些痛点](#解决哪些痛点) · [能清理什么](#能清理什么) · [安全机制](#安全机制) · [安全提示](#安全提示)

**Other Languages:** [English](README_EN.md)

---

## 效果示例

```
用户  ❯  C 盘快满了，只剩 15 GB，帮我清理一下

Claude ❯  正在扫描 C 盘...

      ┌─────────┬──────────────────────┬────────┬──────┬────────────────────────┐
      │ 类别    │ 项目                 │ 大小   │ 风险 │ 说明                   │
      ├─────────┼──────────────────────┼────────┼──────┼────────────────────────┤
      │ 可清理  │ Windows 更新缓存     │ 4.2 GB │ 🟢   │ 已安装更新的下载包     │
      │ 可清理  │ 用户临时文件         │ 2.1 GB │ 🟢   │ 应用缓存，自动重建     │
      │ 可清理  │ 浏览器缓存(Chrome)   │ 1.8 GB │ 🟢   │ 网页缓存，自动重建     │
      │ 可清理  │ WPS 缓存             │ 5.2 GB │ 🟡   │ 可能含未同步文档       │
      │ 可迁移  │ Documents            │ 68.6GB │ 🟢   │ 可用 junction 迁移     │
      │ 可迁移  │ xwechat_files(微信)  │ 31.0GB │ 🟡   │ 迁移后可能需重新索引   │
      └─────────┴──────────────────────┴────────┴──────┴────────────────────────┘

      选择要操作的项目后，自动完成清理和迁移。
      清理前安全检查通过，复制完整性验证通过。

      C 盘可用空间：15.31 GB → 102.33 GB
```

---

## 环境准备（小白用户必读）

如果你不是程序员，或者没有使用过 AI 编程工具，请先完成以下准备工作。

### 1. 安装 Node.js

Node.js 是运行 JavaScript 的环境，安装后可以使用 `npx` 命令。

**步骤：**

1. 访问 [Node.js 官网](https://nodejs.org/zh-cn/)
2. 下载 **LTS（长期支持版）**（小白用户推荐使用 Windows 安装程序.msi, [下载链接](https://nodejs.org/dist/v24.16.0/node-v24.16.0-x64.msi)）
3. 双击安装包，一路点击“下一步”即可
4. 安装完成后，打开终端（同时按下 Windows 键+Q 键 搜索 `终端`），输入以下命令验证：

```bash
node --version
npm --version
```

如果显示版本号（如 `v24.16.0`），说明安装成功。

### 2. 安装 AI 助手（以 OpenCode 为例）

OpenCode 是一个 AI 编程助手，可以帮你执行命令、编写代码。

**步骤：**

1. 打开终端（Windows 搜索 `终端`）
2. 运行以下命令全局安装 OpenCode：

```bash
npm install -g opencode-ai
```

3. 安装完成后，在终端中输入 `opencode` 即可启动

**其他可选的 AI 助手：**
- [Claude Code](https://claude.ai/)（需要 Anthropic API）
- [Cursor](https://cursor.sh/)（内置 AI 功能）
- [GitHub Copilot](https://github.com/features/copilot)（需要 GitHub 账号）

### 3. 配置大模型 API KEY

AI 助手需要连接大语言模型才能工作。你需要获取一个 API KEY。

**获取 API KEY 的方式：**

| 服务商 | 获取方式 | 说明 |
|--------|----------|------|
| 深度求索（DeepSeek） | [platform.deepseek.com](https://platform.deepseek.com/) | 国内服务，价格便宜（强烈推荐） |
| 智谱 AI | [open.bigmodel.cn](https://www.bigmodel.cn/glm-coding?ic=AGPB6AWSVL) | 国内服务，注册有免费额度，够用了 |
| xiao mi MiMo | [https://platform.xiaomimimo.com/](https://platform.xiaomimimo.com?ref=SXX5PS) | 注册填写邀请码 SXX5PS，送10块钱体验金，够用了|
| OpenAI | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) | 需要科学上网，按使用量付费 |
| Anthropic | [console.anthropic.com](https://console.anthropic.com/) | 需要科学上网，按使用量付费 |

**在 OpenCode 中配置 API KEY：**

请参照教程：[OpenCode 配置 DeepSeek API Key](https://learnopencode.com/1-start/04b-deepseek.html)

---

## 安装

### 方式一：一行命令（推荐，跨 runtime）

```bash
npx skills add hello-jun/localdiskC-cleaner-skill --yes
```

自动检测当前 runtime（Claude Code、Codex、Cursor、Gemini CLI 等 40+ 兼容工具），安装到正确路径。也可以直接告诉你的 AI 助手：

> "帮我安装这个 skill：https://github.com/hello-jun/localdiskC-cleaner-skill"

### 方式二：手动安装

<details>
<summary>展开查看各 runtime 的手动安装方式</summary>

**Claude Code**

把 `SKILL.md` 的内容直接粘贴进对话即可，或 clone 到本地后引用：

```bash
git clone https://github.com/hello-jun/localdiskC-cleaner-skill
```

**其他 runtime（Codex、Cursor、Gemini CLI 等）**

| Runtime | 安装路径 |
|---------|----------|
| Codex CLI | `~/.codex/skills/localdiskc-cleaner/` |
| Cursor | `~/.cursor/skills/localdiskc-cleaner/` |
| Gemini CLI | `~/.gemini/skills/localdiskc-cleaner/` |
| 其他 runtime | clone 到对应 runtime 的 `skills/` 目录 |

```bash
git clone https://github.com/hello-jun/localdiskC-cleaner-skill <上面对应的路径>
```

也可以把 `SKILL.md` 的内容直接粘贴进对话，所有 runtime 都支持。

</details>

---

## 使用

装好后，对 agent 说：

```
C 盘满了，帮我清理一下
```

```
帮我把 Documents 文件夹移动到 E 盘
```

```
Help me free up space on my C drive
```

---

## 解决哪些痛点

| 痛点场景 | 本 Skill 如何解决 |
|---------|-----------------|
| **微信/钉钉/飞书聊天文件占满 C 盘** | 自动发现 `xwechat_files` 等大目录，通过 junction 迁移到其他盘，应用无感知 |
| **桌面/文档堆积大量文件** | 将 Documents、Desktop 等整个迁移到其他盘，junction 重定向后路径不变 |
| **C 盘变红但不知道什么占空间** | 一键扫描，按类别分组展示，生成可视化 HTML 报告 |
| **清理后不知道释放了多少** | 清理前后对比报告，精确显示每项操作的释放量 |
| **浏览器缓存/更新缓存累积数 GB** | 自动扫描并清理 Chrome、Edge、Firefox 多 Profile 缓存 |
| **开发者工具链占空间** | 发现 npm/pip/NuGet/Docker/WSL2/VS Code 扩展等开发者缓存 |
| **游戏占满 C 盘** | 检测 Steam/Epic/Xbox 游戏库，给出平台专用迁移建议 |
| **有其他盘但不知道怎么利用** | 检测可用盘符和空间，自动推荐迁移方案 |
| **担心清理后程序出问题** | 三级安全分级 + 10 项前置检查 + 复制完整性验证 + rename 备份策略 |
| **OneDrive/云同步文件夹** | 自动检测 OneDrive、Dropbox、Google Drive、坚果云，避免迁移导致同步冲突 |
| **企业电脑有文件夹重定向** | 自动检测组策略重定向，标记为禁止迁移 |
| **脚本失败时无法操作** | 每个阶段都有 Fallback 手动命令，不依赖脚本也能完成 |

---

## 能清理什么

### 临时文件与缓存（直接清理）

| 项目 | 典型大小 | 安全分级 |
|------|---------|---------|
| Windows 更新缓存 | 1-10 GB | 🟢 安全 |
| 用户临时文件 | 1-5 GB | 🟢 安全 |
| Windows 临时文件 | 0.5-2 GB | 🟢 安全 |
| 浏览器缓存（Chrome/Edge/Firefox 多 Profile） | 0.5-3 GB | 🟢 安全 |
| 回收站 | 不定 | 🟢 安全 |
| 缩略图缓存 | 0.1-1 GB | 🟢 安全 |
| Windows 日志 | 0.1-1 GB | 🟢 安全 |
| 传递优化文件 | 0.1-2 GB | 🟢 安全 |
| 预读取缓存 | 0.1-0.5 GB | 🟢 安全 |
| 应用崩溃转储 | 0-2 GB | 🟢 安全 |
| WPS 缓存 | 5-15 GB | 🟡 谨慎 |
| 腾讯/QQ 数据 | 1-10 GB | 🟡 谨慎 |
| 钉钉/飞书缓存 | 1-10 GB | 🟡 谨慎 |
| Windows.old 旧系统 | 10-30 GB | 🟡 谨慎 |
| 事件日志 | 0.1-1 GB | 🔴 仅建议 |

### 开发者工具缓存

| 项目 | 典型大小 | 安全分级 |
|------|---------|---------|
| npm / Yarn / pnpm 缓存 | 1-10 GB | 🟢 安全 |
| pip 缓存 | 0.5-5 GB | 🟢 安全 |
| NuGet 包缓存 | 1-10 GB | 🟢 安全 |
| Gradle / Maven 缓存 | 1-10 GB | 🟢 安全 |
| Docker Desktop 数据 | 1-30 GB | 🟡 谨慎 |
| WSL2 虚拟磁盘 | 1-30 GB | 🔴 仅建议 |
| VS Code / Cursor 扩展 | 1-5 GB | 🟡 谨慎 |

### 游戏平台（给出专用迁移建议）

| 平台 | 典型大小 | 处理方式 |
|------|---------|---------|
| Steam 游戏库 | 10-100 GB | 引导使用 Steam 客户端迁移 |
| Epic Games | 5-50 GB | 引导使用 Launcher 重装 |
| Xbox Game Pass | 5-50 GB | 不支持迁移，提示用户 |

### 文件夹迁移（通过 junction 重定向）

| 文件夹 | 典型大小 | 安全分级 | junction 兼容性 |
|--------|---------|---------|---------------|
| Documents（文档） | 10-100 GB | 🟢 安全 | 完全兼容 |
| Desktop（桌面） | 1-10 GB | 🟢 安全 | 完全兼容 |
| Downloads（下载） | 1-20 GB | 🟢 安全 | 完全兼容 |
| Pictures（图片） | 1-50 GB | 🟢 安全 | 完全兼容 |
| Videos（视频） | 1-50 GB | 🟢 安全 | 完全兼容 |
| xwechat_files（微信） | 10-50 GB | 🟡 谨慎 | 兼容，需重新索引 |

---

## 安全机制

### 三级安全分级

| 级别 | 含义 | 处理方式 |
|------|------|---------|
| 🟢 安全 | 临时文件/缓存，可自动重建 | 向用户说明后执行 |
| 🟡 谨慎 | 数据可能有价值 | 逐项说明影响，获得明确确认 |
| 🔴 危险 | 系统关键/不可逆 | 永不操作，仅建议系统工具 |

### 迁移保护（6 道防线）

1. **云同步检测** — 自动检测 OneDrive/Dropbox/Google Drive/坚果云，避免同步冲突
2. **企业重定向检测** — 检测组策略重定向，标记为禁止迁移
3. **已有 junction 检测** — 避免重复迁移
4. **磁盘加密检查** — BitLocker 状态对比，提醒加密差异
5. **文件系统检查** — 目标盘必须为 NTFS（FAT32 不支持 junction）
6. **空间检查** — 目标盘需有 110% 余量

### 迁移操作安全

- 复制后**验证文件数量和大小**必须完全一致
- 原文件夹**仅重命名**为 `_backup`，不删除
- Junction 创建后测试应用可正常访问
- **Office 锁文件检测**（`~$*.docx`），有打开的文档时终止迁移

---

## 安全提示

> ⚠️ **清理 C 盘是有风险的操作。** 在操作过程中请务必仔细核对每一项要清理/迁移的内容，确认后再让 agent 执行。
>
> **建议操作前：**
> - 保存并关闭所有正在编辑的文件（尤其是 Word、Excel、PPT）
> - 关闭微信、WPS、浏览器等可能占用文件的程序
> - 建议创建系统还原点作为额外保障
>
> **操作过程中：**
> - 仔细查看每张确认表，不要一键全部确认
> - 🟡 谨慎级别的项目要特别留意影响说明
> - 迁移大文件夹时耐心等待复制和验证完成，不要中断
>
> **操作完成后：**
> - 打开常用软件确认运行正常
> - 检查桌面、文档中的文件是否可以正常打开
> - 确认无误后再删除备份文件夹

---

## 工作原理

**有其他盘时** — 完整流程：

1. **扫描** — 运行 PowerShell 脚本，全面分析 C 盘（含 OneDrive/加密/云同步检测）
2. **清理** — 安全删除临时文件、缓存、日志（用户确认后执行）
3. **迁移** — robocopy 复制 + junction 重定向，验证完整性后切换
4. **验证** — 检查 junction 有效性，测试程序正常运行，生成对比报告

**只有 C 盘时** — 仅清理流程：

1. **扫描** — 找出所有可安全清理的项目
2. **展示** — 汇总成表格，标注安全分级，逐项确认
3. **清理** — 只清理用户同意的项目
4. **建议** — 给出进一步释放空间的方案

---

## 交流

欢迎加我交流，一起探讨技术问题：

- **QQ：** 1792937214
- **微信：** luckyzjun

---

## 许可证

[MIT License](LICENSE)
