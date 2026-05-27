# localdiskc-cleaner

> Running out of C drive space? One command to fix it.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-Standard-green)](https://agentskills.io)
[![Windows](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-blue)](#)

A skill for cleaning and reclaiming Windows C drive space, based on the [Agent Skills protocol](https://agentskills.io). Works across 40+ compatible runtimes including Claude Code, Codex, Cursor, Gemini CLI, VS Code, GitHub Copilot, Roo Code, OpenCode, and more.

[See it in action](#demo) · [Environment Setup](#environment-setup-for-beginners) · [Install](#install) · [How it works](#how-it-works) · [What gets cleaned](#cleanable-items) · [Safety rules](#safety-rules)

---

## Demo

```
User   ❯  My C drive is almost full, only 15 GB left. Help me clean it up.

Claude ❯  Scanning C drive...

      ┌──────────┬─────────────────────────┬────────┬──────┬──────────────────────────────┐
      │ Category │ Item                    │ Size   │ Risk │ Note                         │
      ├──────────┼─────────────────────────┼────────┼──────┼──────────────────────────────┤
      │ Cleanable│ Windows Update cache    │ 4.2 GB │ Low  │ Installed update packages    │
      │ Cleanable│ User temp files         │ 2.1 GB │ Low  │ App cache, auto-rebuilt      │
      │ Cleanable│ Browser cache (Chrome)  │ 1.8 GB │ Low  │ Web cache, auto-rebuilt      │
      │ Movable  │ Documents               │ 68.6GB │ Low  │ Can migrate via junction     │
      │ Movable  │ xwechat_files (WeChat)  │ 31.0GB │ Med  │ May need re-indexing after   │
      └──────────┴─────────────────────────┴────────┴──────┴──────────────────────────────┘

      After selecting items, cleanup and migration run automatically.

      C drive free space: 15.31 GB → 102.33 GB
```

---

## Environment Setup (For Beginners)

If you're not a programmer or haven't used AI coding tools before, please complete these setup steps first.

### 1. Install Node.js

Node.js is a JavaScript runtime that enables the `npx` command.

**Steps:**

1. Visit the [Node.js website](https://nodejs.org/)
2. Download the **LTS (Long Term Support)** version (recommended)
3. Run the installer and click "Next" through the prompts
4. After installation, open Terminal (search for `Terminal` on Windows) and verify:

```bash
node --version
npm --version
```

If version numbers appear (e.g., `v18.17.0`), installation was successful.

### 2. Install an AI Assistant (OpenCode Example)

OpenCode is an AI coding assistant that can execute commands and write code for you.

**Steps:**

1. Open Terminal (search for `Terminal` on Windows)
2. Run the following command to install OpenCode globally:

```bash
npm install -g opencode-ai
```

3. After installation, type `opencode` in the terminal to start

**Alternative AI assistants:**
- [Claude Code](https://claude.ai/) (requires Anthropic API)
- [Cursor](https://cursor.sh/) (built-in AI features)
- [GitHub Copilot](https://github.com/features/copilot) (requires GitHub account)

### 3. Configure AI Model API KEY

AI assistants need to connect to a large language model to work. You'll need to obtain an API KEY.

**How to get an API KEY:**

| Provider | How to Get | Notes |
|----------|------------|-------|
| DeepSeek | [platform.deepseek.com](https://platform.deepseek.com/) | Affordable pricing, recommended |
| Zhipu AI | [open.bigmodel.cn](https://www.bigmodel.cn/glm-coding?ic=AGPB6AWSVL) | Free tier available for new users |
| Xiaomi MiMo | [platform.xiaomimimo.com](https://platform.xiaomimimo.com?ref=SXX5PS) | Use invite code SXX5PS for bonus credits |
| OpenAI | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) | Requires VPN, pay-per-use |
| Anthropic | [console.anthropic.com](https://console.anthropic.com/) | Requires VPN, pay-per-use |

**Configure API KEY in OpenCode:**

Please refer to the official tutorial: [OpenCode DeepSeek API Key Configuration](https://learnopencode.com/1-start/04b-deepseek.html)

---

## Install

### One-liner (recommended, cross-runtime)

```bash
npx skills add hello-jun/localdiskC-cleaner-skill --yes
```

Auto-detects your current runtime (Claude Code, Codex, Cursor, Gemini CLI, etc.) and installs to the correct path. Or just tell your AI assistant:

> "Install this skill for me: https://github.com/hello-jun/localdiskC-cleaner-skill"

### Manual install

<details>
<summary>Click to expand per-runtime install paths</summary>

**Claude Code**

Paste the contents of `SKILL.md` directly into a conversation, or clone locally:

```bash
git clone https://github.com/hello-jun/localdiskC-cleaner-skill
```

**Other runtimes (Codex, Cursor, Gemini CLI, etc.)**

| Runtime | Install Path |
|---------|-------------|
| Codex CLI | `~/.codex/skills/localdiskc-cleaner/` |
| Cursor | `~/.cursor/skills/localdiskc-cleaner/` |
| Gemini CLI | `~/.gemini/skills/localdiskc-cleaner/` |
| Other | Clone into the runtime's `skills/` directory |

```bash
git clone https://github.com/hello-jun/localdiskC-cleaner-skill <path-above>
```

You can also paste the contents of `SKILL.md` directly into any agent conversation.

</details>

---

## Usage

After installing, tell your agent:

```
My C drive is full, help me clean it up
```

```
Move my Documents folder to the E drive
```

```
帮我清理一下C盘空间
```

---

## How it works

**With another drive available** — Full workflow:

1. **Scan** — Analyze C drive, find all cleanable items and movable folders
2. **Clean** — Safely delete temp files, caches, and logs (after user confirmation)
3. **Migrate** — Copy via robocopy + redirect with junction, transparent to apps
4. **Verify** — Check junction validity, test that applications work normally

**Only C drive available** — Cleanup-only workflow:

1. **Scan** — Find all safely cleanable items
2. **Display** — Show results in a table with risk levels, confirm each item
3. **Clean** — Only clean items the user approves
4. **Suggest** — Provide further recommendations (Disk Cleanup tool, disable hibernation, etc.)

---

## Cleanable Items

| Item | Typical Size | Risk |
|------|-------------|------|
| Windows Update cache | 1-10 GB | Low |
| User temp files | 1-5 GB | Low |
| Windows temp files | 0.5-2 GB | Low |
| Browser cache (Chrome/Edge) | 0.5-3 GB | Low |
| Recycle Bin | Varies | Low |
| Thumbnail cache | 0.1-1 GB | Low |
| Windows logs | 0.1-1 GB | Low |
| Delivery Optimization files | 0.1-2 GB | Low |
| WPS cache | 5-15 GB | Medium |
| Tencent/DingTalk/Lark cache | 1-10 GB | Medium |
| Windows.old | 10-30 GB | Low |

## Movable Folders

| Folder | Typical Size | Risk |
|--------|-------------|------|
| Documents | 10-100 GB | Low |
| Desktop | 1-10 GB | Low |
| Downloads | 1-20 GB | Low |
| Pictures / Videos / Music | 1-50 GB | Low |
| xwechat_files (WeChat) | 10-50 GB | Medium |

---

## Safety Rules

- **Rename, never delete** — Original folders are kept as backups until junctions are verified
- **Prefer junctions over symlinks** — Better compatibility, no admin privileges required
- **Close apps before moving** — Avoids file locking issues
- **Never touch system folders** — Windows, Program Files, etc. are out of scope

---

## License

[MIT License](LICENSE)
