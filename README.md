# Cursor + Windows harness (RTK, Caveman, cursor-mem)

Lightweight analogue of [Bennie](https://github.com/kyronyx-ai/Bennie-claude) for **Cursor on Windows**. Full Bennie (jobs, gates, dashboard) remains **macOS + Claude Code**.

---

## For coding agents (runbook)

**Goal:** Install RTK + Caveman + cursor-mem on a Windows machine with Cursor IDE.

**Prerequisites (stop and tell the user if missing):**

| Requirement | Minimum | Check |
|-------------|---------|--------|
| OS | Windows 10/11 | `$env:OS` |
| PowerShell | 5.1+ | `$PSVersionTable.PSVersion` |
| Node.js | **22.13+** | `node -p process.versions.node` |
| Python | **3.10+** (for cursor-mem) | `python --version` |
| Network | GitHub + npm + PyPI | download RTK zip, `npm`, `pip` |
| Cursor | Installed | user confirms |

**Do not** install claude-mem if cursor-mem is used (one memory provider).

**Steps:**

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
# Standalone clone (github.com/Zer0Fit3/cursor-harness):
.\setup.ps1
.\verify.ps1

# Or from the pricing_library monorepo:
# .\scripts\cursor-harness\setup.ps1
# .\scripts\cursor-harness\verify.ps1
```

- Default: installs **cursor-mem**. To skip memory: `.\scripts\cursor-harness\setup.ps1 -SkipMemory`
- To skip re-downloading Caveman skills: `-SkipCavemanSkills`

**After success:** tell the user to **restart Cursor**. Optional: open http://127.0.0.1:37800 (cursor-mem viewer).

**Writes under `%USERPROFILE%` only** (not the git repo):

- `.local\bin\rtk.exe`
- `.caveman\bin\` (Go binaries)
- `.cursor\hooks.json`, `.cursor\mcp.json`
- `.agents\skills\` (Caveman)
- `.cursor-mem\` (DB, config, worker)
- User PATH: `.local\bin`, `.caveman\bin`, Python `Scripts`

**Idempotent:** safe to re-run `setup.ps1` to repair.

---

## What Bennie uses vs this stack

| Bennie recipe | Role | This stack |
|---------------|------|------------|
| `efficiency.rtk` | Shell output compression | `preToolUse` → `rtk hook cursor` |
| `efficiency.caveman` | Small rock skill; big rock proxy on Claude/Codex | Skills + `caveman-mcp`; **no** `caveman wrap cursor` |
| `memory.claude-mem` | Session memory | **cursor-mem** instead (Cursor-native) |

Rules: RTK owns shell output; Caveman skill per session (not global always-on); one memory tool.

---

## Human quick start

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\path\to\cursor-harness   # or pricing_library\scripts\cursor-harness
.\setup.ps1
.\verify.ps1
```

Restart Cursor. In Agent: run `git status` — output should look RTK-compressed. Invoke **caveman** skill when you want terse replies.

---

## Verify RTK manually

1. New Agent chat → ask for `git status` via Shell tool.
2. Compare to the same command in an external terminal (no hook).

If RTK fails: `hooks.json` must use a **full path** to `rtk.exe` (the script sets this). Cursor Settings → Hooks should list entries.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `node` not found | Install Node 22.13+, new terminal, rerun setup |
| `cursor-mem` not found after pip | Rerun setup (adds Python Scripts to user PATH) or `python -m cursor_mem.cli start` |
| Worker stopped | `python -m cursor_mem.cli start` or `cursor-mem restart` |
| Hooks wiped | Rerun `setup.ps1` (merges RTK + preserves cursor-mem hooks) |
| winget blocked | Setup does **not** use winget; uses Invoke-WebRequest for RTK |

---

## Not included

Bennie MCP, job gates, unlazy, macOS global install, live dashboard (demo only: `~\.bennie-harness\scripts\demo.js` if cloned).

---

## Pin updates

RTK version is `$RtkVersion` in `setup.ps1` (default `0.51.0`). Bump when upgrading; re-run setup.
