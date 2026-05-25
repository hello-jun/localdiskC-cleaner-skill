# localdiskc-cleaner

> C 盘满了？一行命令搞定。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-Standard-green)](https://agentskills.io)
[![Windows](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-blue)](#)

基于 [Agent Skills 协议](https://agentskills.io)，在 Claude Code、Codex、Cursor、Gemini CLI、VS Code、GitHub Copilot、Roo Code、OpenCode 等 40+ 兼容 runtime 中通用。

[看效果](#效果示例) · [安装](#安装) · [工作原理](#工作原理) · [它清理了什么](#可清理项) · [安全规则](#安全规则)

---

## 效果示例

```
用户  ❯  C 盘快满了，只剩 15 GB，帮我清理一下

Claude ❯  正在扫描 C 盘...

      ┌─────────┬──────────────────────┬────────┬──────┬────────────────────────┐
      │ 类别    │ 项目                 │ 大小   │ 风险 │ 说明                   │
      ├─────────┼──────────────────────┼────────┼──────┼────────────────────────┤
      │ 可清理  │ Windows 更新缓存     │ 4.2 GB │ 低   │ 已安装更新的下载包     │
      │ 可清理  │ 用户临时文件         │ 2.1 GB │ 低   │ 应用缓存，自动重建     │
      │ 可清理  │ 浏览器缓存(Chrome)   │ 1.8 GB │ 低   │ 网页缓存，自动重建     │
      │ 可迁移  │ Documents            │ 68.6GB │ 低   │ 可用 junction 迁移     │
      │ 可迁移  │ xwechat_files(微信)  │ 31.0GB │ 中   │ 迁移后可能需重新索引   │
      └─────────┴──────────────────────┴────────┴──────┴────────────────────────┘

      选择要操作的项目后，自动完成清理和迁移。

      C 盘可用空间：15.31 GB → 102.33 GB
```

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

## 工作原理

**有其他盘时** — 完整流程：

1. **扫描** — 全面分析 C 盘，找出所有可清理项和可迁移文件夹
2. **清理** — 安全删除临时文件、缓存、日志（用户确认后执行）
3. **迁移** — 用 robocopy 复制 + junction 重定向，应用程序无感知
4. **验证** — 检查 junction 有效性，测试程序正常运行

**只有 C 盘时** — 仅清理流程：

1. **扫描** — 找出所有可安全清理的项目
2. **展示** — 汇总成表格，标注风险等级，逐项确认
3. **清理** — 只清理用户同意的项目
4. **建议** — 给出进一步释放空间的方案（磁盘清理工具、关闭休眠等）

---

## 可清理项

| 项目 | 典型大小 | 风险 |
|------|---------|------|
| Windows 更新缓存 | 1-10 GB | 低 |
| 用户临时文件 | 1-5 GB | 低 |
| Windows 临时文件 | 0.5-2 GB | 低 |
| 浏览器缓存（Chrome/Edge） | 0.5-3 GB | 低 |
| 回收站 | 不定 | 低 |
| 缩略图缓存 | 0.1-1 GB | 低 |
| Windows 日志 | 0.1-1 GB | 低 |
| 传递优化文件 | 0.1-2 GB | 低 |
| WPS 缓存 | 5-15 GB | 中 |
| 腾讯/钉钉/飞书缓存 | 1-10 GB | 中 |
| Windows.old 旧系统 | 10-30 GB | 低 |

## 可迁移文件夹

| 文件夹 | 典型大小 | 风险 |
|--------|---------|------|
| Documents（文档） | 10-100 GB | 低 |
| Desktop（桌面） | 1-10 GB | 低 |
| Downloads（下载） | 1-20 GB | 低 |
| Pictures / Videos / Music | 1-50 GB | 低 |
| xwechat_files（微信） | 10-50 GB | 中 |

---

## 安全规则

- **只重命名，不删除** — junction 验证通过前，原文件夹保留为备份
- **优先使用 junction** — 比符号链接兼容性更好，无需管理员权限
- **移动前关闭相关程序** — 避免文件锁定
- **绝不移动系统文件夹** — Windows、Program Files 等不在操作范围内

---

## 许可证

[MIT License](LICENSE)
