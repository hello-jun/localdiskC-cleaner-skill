# localdiskc-cleaner

> Running out of C drive space? One command to fix it.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-Standard-green)](https://agentskills.io)
[![Windows](https://img.shields.io/badge/Platform-Windows%2010%20%2F%2011-blue)](#)

A skill for cleaning and reclaiming Windows C drive space, based on the [Agent Skills protocol](https://agentskills.io). Works across 40+ compatible runtimes including Claude Code, Codex, Cursor, Gemini CLI, VS Code, GitHub Copilot, Roo Code, OpenCode, and more.

[See it in action](#demo) · [Environment Setup](#environment-setup-for-beginners) · [Install](#install) · [Pain Points Solved](#pain-points-solved) · [What Gets Cleaned](#what-gets-cleaned) · [Safety Mechanisms](#safety-mechanisms) · [Safety Warning](#safety-warning)

**Other Languages:** [中文](README.md)

---

## Demo

```
User   ❯  My C drive is almost full, only 15 GB left. Help me clean it up.

Claude ❯  Scanning C drive...

      ┌──────────┬─────────────────────────┬────────┬──────┬──────────────────────────────┐
      │ Category │ Item                    │ Size   │ Risk │ Note                         │
      ├──────────┼─────────────────────────┼────────┼──────┼──────────────────────────────┤
      │ Cleanable│ Windows Update cache    │ 4.2 GB │ 🟢   │ Installed update packages    │
      │ Cleanable│ User temp files         │ 2.1 GB │ 🟢   │ App cache, auto-rebuilt      │
      │ Cleanable│ Browser cache (Chrome)  │ 1.8 GB │ 🟢   │ Web cache, auto-rebuilt      │
      │ Cleanable│ WPS cache               │ 5.2 GB │ 🟡   │ May contain unsynced docs    │
      │ Movable  │ Documents               │ 68.6GB │ 🟢   │ Can migrate via junction     │
      │ Movable  │ xwechat_files (WeChat)  │ 31.0GB │ 🟡   │ May need re-indexing after   │
      └──────────┴─────────────────────────┴────────┴──────┴──────────────────────────────┘

      After selecting items, cleanup and migration run automatically.
      Pre-cleanup safety checks passed. Copy integrity verification passed.

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

## Pain Points Solved

| Pain Point | How This Skill Helps |
|------------|---------------------|
| **WeChat/DingTalk/Lark chat files filling up C drive** | Auto-discovers `xwechat_files` and other large directories, migrates via junction to another drive — apps are unaffected |
| **Desktop/Documents cluttered with files** | Migrates Documents, Desktop, etc. to another drive; junction redirect keeps the original path working |
| **C drive turns red but don't know what's taking space** | One-click scan, grouped by category, generates visual HTML report |
| **No idea how much space was freed after cleanup** | Before/after comparison report showing exactly how much each operation freed |
| **Browser/update caches accumulate several GB** | Auto-scans and cleans Chrome, Edge, Firefox multi-profile caches |
| **Developer toolchains using too much space** | Discovers npm/pip/NuGet/Docker/WSL2/VS Code extension caches |
| **Games filling up C drive** | Detects Steam/Epic/Xbox game libraries with platform-specific migration advice |
| **Have other drives but don't know how to use them** | Detects available drive letters and free space, auto-recommends migration plans |
| **Worried about breaking apps after cleanup** | Three-tier safety classification + 10 pre-checks + copy integrity verification + rename backup strategy |
| **OneDrive/cloud sync folders** | Auto-detects OneDrive, Dropbox, Google Drive, Nutstore — avoids sync conflicts from migration |
| **Corporate PC with folder redirection** | Auto-detects Group Policy redirection and marks as no-migration |
| **Script failure leaves you stuck** | Every phase has fallback manual commands — you're never dependent on scripts |

---

## What Gets Cleaned

### Temp Files & Caches (Direct Cleanup)

| Item | Typical Size | Safety Tier |
|------|-------------|-------------|
| Windows Update cache | 1-10 GB | 🟢 Safe |
| User temp files | 1-5 GB | 🟢 Safe |
| Windows temp files | 0.5-2 GB | 🟢 Safe |
| Browser cache (Chrome/Edge/Firefox multi-Profile) | 0.5-3 GB | 🟢 Safe |
| Recycle Bin | Varies | 🟢 Safe |
| Thumbnail cache | 0.1-1 GB | 🟢 Safe |
| Windows logs | 0.1-1 GB | 🟢 Safe |
| Delivery Optimization files | 0.1-2 GB | 🟢 Safe |
| Prefetch cache | 0.1-0.5 GB | 🟢 Safe |
| App crash dumps | 0-2 GB | 🟢 Safe |
| WPS cache | 5-15 GB | 🟡 Caution |
| Tencent/QQ data | 1-10 GB | 🟡 Caution |
| DingTalk/Lark cache | 1-10 GB | 🟡 Caution |
| Windows.old | 10-30 GB | 🟡 Caution |
| Event logs | 0.1-1 GB | 🔴 Suggest Only |

### Developer Tool Caches

| Item | Typical Size | Safety Tier |
|------|-------------|-------------|
| npm / Yarn / pnpm cache | 1-10 GB | 🟢 Safe |
| pip cache | 0.5-5 GB | 🟢 Safe |
| NuGet package cache | 1-10 GB | 🟢 Safe |
| Gradle / Maven cache | 1-10 GB | 🟢 Safe |
| Docker Desktop data | 1-30 GB | 🟡 Caution |
| WSL2 virtual disks | 1-30 GB | 🔴 Suggest Only |
| VS Code / Cursor extensions | 1-5 GB | 🟡 Caution |

### Game Platforms (Platform-Specific Migration Advice)

| Platform | Typical Size | Handling |
|----------|-------------|----------|
| Steam library | 10-100 GB | Guide to use Steam client migration |
| Epic Games | 5-50 GB | Guide to reinstall via Launcher |
| Xbox Game Pass | 5-50 GB | Not supported for migration |

### Folder Migration (via junction Redirect)

| Folder | Typical Size | Safety Tier | junction Compatibility |
|--------|-------------|-------------|----------------------|
| Documents | 10-100 GB | 🟢 Safe | Fully compatible |
| Desktop | 1-10 GB | 🟢 Safe | Fully compatible |
| Downloads | 1-20 GB | 🟢 Safe | Fully compatible |
| Pictures | 1-50 GB | 🟢 Safe | Fully compatible |
| Videos | 1-50 GB | 🟢 Safe | Fully compatible |
| xwechat_files (WeChat) | 10-50 GB | 🟡 Caution | Compatible, may need re-indexing |

---

## Safety Mechanisms

### Three-Tier Safety Classification

| Tier | Meaning | Handling |
|------|---------|----------|
| 🟢 Safe | Temp files/caches, auto-rebuilt | Explain to user, then proceed |
| 🟡 Caution | Data may have value | Explain impact per item, get explicit confirmation |
| 🔴 Danger | System-critical/irreversible | Never operate, only suggest system tools |

### Migration Protection (6 Layers)

1. **Cloud sync detection** — Auto-detects OneDrive/Dropbox/Google Drive/Nutstore, avoids sync conflicts
2. **Enterprise redirect detection** — Detects Group Policy redirects, marks as no-migration
3. **Existing junction detection** — Avoids duplicate migration
4. **Disk encryption check** — BitLocker status comparison, alerts on encryption mismatch
5. **File system check** — Target drive must be NTFS (FAT32 doesn't support junction)
6. **Space check** — Target drive needs 110% free space

### Migration Operation Safety

- After copying, **verify file count and size** must match exactly
- Original folder is **only renamed** to `_backup`, never deleted
- After junction creation, test that apps can access files normally
- **Office lock file detection** (`~$*.docx`), terminates migration if open documents found

---

## Safety Warning

> ⚠️ **Cleaning your C drive carries risk.** Always carefully review each item before confirming cleanup or migration.
>
> **Before starting:**
> - Save and close all files being edited (especially Word, Excel, PowerPoint)
> - Close WeChat, WPS, browsers, and other programs that may lock files
> - Consider creating a System Restore Point as an extra safeguard
>
> **During the process:**
> - Review each confirmation table carefully — do not blindly approve everything
> - Pay extra attention to 🟡 Caution-level items and their impact descriptions
> - Be patient during large folder copy and verification — do not interrupt
>
> **After completion:**
> - Open your commonly used programs to confirm they work normally
> - Check that files on Desktop and Documents can be opened properly
> - Only delete backup folders after confirming everything is fine

---

## How It Works

**With another drive available** — Full workflow:

1. **Scan** — Run PowerShell script for comprehensive C drive analysis (includes OneDrive/encryption/cloud sync detection)
2. **Clean** — Safely delete temp files, caches, logs (after user confirmation)
3. **Migrate** — robocopy copy + junction redirect, verify integrity before switching
4. **Verify** — Check junction validity, test that applications work normally, generate comparison report

**Only C drive available** — Cleanup-only workflow:

1. **Scan** — Find all safely cleanable items
2. **Display** — Show results in a table with safety tiers, confirm each item
3. **Clean** — Only clean items the user approves
4. **Suggest** — Provide further recommendations to free up space

---

## Contact

Feel free to reach out and connect:

- **QQ:** 1792937214
- **WeChat:** luckyzjun

---

## License

[MIT License](LICENSE)
