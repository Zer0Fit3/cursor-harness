# Cursor + Windows harness (RTK, Caveman, cursor-mem)

> **Public version.** This is a public, standalone version of an internal agent harness. It needs no private repos, accounts or tools — everything installs from public GitHub, npm and PyPI.

One script that sets up three token- and context-saving tools for **Cursor on Windows**:

| Tool | What it does | How it's wired |
|------|--------------|----------------|
| [RTK](https://github.com/rtk-ai/rtk) | Compresses shell command output before the agent sees it | Cursor `preToolUse` hook → `rtk hook cursor` |
| [Caveman](https://github.com/JuliusBrussee/caveman) | Terse-reply skill you turn on per chat, plus a `caveman-mcp` server | Skill in `~\.agents\skills\`, MCP in `~\.cursor\mcp.json` |
| [cursor-mem](https://pypi.org/project/cursor-mem/) | Persistent memory across Cursor sessions (optional, on by default) | Cursor hooks + MCP + local worker |

---

## Requirements

| Requirement | Minimum | Check |
|-------------|---------|-------|
| OS | Windows 10/11 | `$env:OS` |
| PowerShell | 5.1+ | `$PSVersionTable.PSVersion` |
| Node.js | **22.13+** | `node -p process.versions.node` |
| Python | **3.10+** (only for cursor-mem) | `python --version` |
| Network | Access to GitHub, npm and PyPI | — |
| Cursor | Installed | — |

## Install

```powershell
git clone https://github.com/Zer0Fit3/cursor-harness.git
cd cursor-harness
Set-ExecutionPolicy -Scope Process Bypass -Force
.\setup.ps1
.\verify.ps1
```

Then **restart Cursor**. The cursor-mem viewer is at http://127.0.0.1:37800.

Options:

| Flag | Effect |
|------|--------|
| `.\setup.ps1 -SkipMemory` | Skip cursor-mem (no Python needed). Verify with `.\verify.ps1 -SkipMemory`. |
| `.\setup.ps1 -SkipCavemanSkills` | Don't re-download the Caveman skills. |
| `.\setup.ps1 -RtkVersion 0.51.0` | Pin a different RTK release (default `0.51.0`). |

`setup.ps1` is idempotent, so you can re-run it to repair an install.

### What it changes

Everything goes under `%USERPROFILE%`. Nothing is written to the repo.

- `.local\bin\rtk.exe`
- `.caveman\bin\` (Caveman Go binaries)
- `.cursor\hooks.json`, `.cursor\mcp.json` (merged — existing entries are kept)
- `.agents\skills\` (Caveman skills)
- `.cursor-mem\` (database, config, worker)
- Global npm package `@caveman-ai/cli`, pip package `cursor-mem`
- User PATH: `.local\bin`, `.caveman\bin`, Python `Scripts`

---

## Using it

- **RTK:** automatic. In a Cursor Agent chat, ask it to run `git status`. The output should be shorter than the same command in a normal terminal.
- **Caveman:** invoke the **caveman** skill in a chat when you want terse replies. It is deliberately not always-on.
- **cursor-mem:** automatic once the worker is running.

Use one memory provider only. Don't install claude-mem alongside cursor-mem.

---

## For coding agents (runbook)

**Goal:** install RTK, Caveman and cursor-mem on a Windows machine with Cursor.

1. Check the [requirements](#requirements). If one is missing, stop and tell the user what to install.
2. From the cloned repo root, run:
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\setup.ps1
   .\verify.ps1
   ```
   Add `-SkipMemory` to **both** commands if the user doesn't want memory or has no Python.
3. `verify.ps1` exits 0 on success and 1 on failure, listing each check. On failure, re-run `setup.ps1` once, then report the failing checks.
4. Tell the user to **restart Cursor**.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `node` not found | Install Node 22.13+, open a new terminal, re-run setup |
| `cursor-mem` not found after pip | Re-run setup (adds Python `Scripts` to user PATH) or use `python -m cursor_mem.cli start` |
| cursor-mem worker stopped | `python -m cursor_mem.cli start` or `cursor-mem restart` |
| RTK not compressing output | `hooks.json` must use the **full path** to `rtk.exe` (setup does this). Check that Cursor Settings → Hooks lists the entry, then restart Cursor. |
| Hooks wiped by another tool | Re-run `setup.ps1` (re-merges the RTK hook and keeps cursor-mem hooks) |
| winget blocked | Not needed. Setup downloads RTK with `Invoke-WebRequest`. |

## Updating

The RTK version is pinned by `$RtkVersion` in `setup.ps1`. To upgrade RTK, delete `%USERPROFILE%\.local\bin\rtk.exe`, then re-run setup with the new `-RtkVersion`. Each run upgrades cursor-mem (`pip install --upgrade`) and re-fetches the Caveman skills. To upgrade the Caveman CLI itself, run `npm install -g @caveman-ai/cli@latest`.

---

## Background: relation to Bennie

This harness is a lightweight Windows/Cursor counterpart to **Bennie**, an internal Claude Code harness for macOS (jobs, gates, dashboard). Bennie is not public and **is not needed** to use this repo. This section only explains where the design choices came from.

| Bennie recipe | Role | This stack |
|---------------|------|------------|
| `efficiency.rtk` | Shell output compression | `preToolUse` → `rtk hook cursor` |
| `efficiency.caveman` | Small rock skill; big rock proxy on Claude/Codex | Skills + `caveman-mcp`; **no** `caveman wrap cursor` |
| `memory.claude-mem` | Session memory | **cursor-mem** instead (Cursor-native) |

Rules carried over: RTK owns shell output, Caveman is turned on per session (not always-on), and only one memory tool is used.

Not included from Bennie: its MCP server, job gates, unlazy, macOS global install, and the live dashboard.
