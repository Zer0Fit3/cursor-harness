# Exit 0 if the Cursor harness stack looks installed. For agents / CI-style checks.
# Pass -SkipMemory if setup.ps1 was run with -SkipMemory.
param([switch]$SkipMemory)
$ErrorActionPreference = 'Continue'
$fail = 0

function Check($name, $cond) {
  if ($cond) { Write-Host "  OK   $name" } else { Write-Host "  FAIL $name"; $script:fail++ }
}

$LocalBin = Join-Path $env:USERPROFILE '.local\bin'
$CaveBin = Join-Path $env:USERPROFILE '.caveman\bin'
$HooksFile = Join-Path $env:USERPROFILE '.cursor\hooks.json'
$McpFile = Join-Path $env:USERPROFILE '.cursor\mcp.json'
$CaveSkill = Join-Path $env:USERPROFILE '.agents\skills\caveman\SKILL.md'

Write-Host "Cursor harness verify ($env:USERNAME on $env:COMPUTERNAME)"
Check 'rtk.exe' (Test-Path (Join-Path $LocalBin 'rtk.exe'))
Check 'caveman-mcp.exe' (Test-Path (Join-Path $CaveBin 'caveman-mcp.exe'))
Check 'caveman skill' (Test-Path $CaveSkill)
Check 'hooks.json' (Test-Path $HooksFile)
Check 'mcp.json' (Test-Path $McpFile)

if (Test-Path $HooksFile) {
  $h = Get-Content $HooksFile -Raw
  Check 'RTK preToolUse hook' ($h -match 'rtk' -and $h -match 'preToolUse')
  if (-not $SkipMemory) { Check 'cursor-mem hooks' ($h -match 'cursor_mem\.hook_handler') }
}

if (Test-Path $McpFile) {
  $m = Get-Content $McpFile -Raw
  Check 'MCP caveman' ($m -match '"caveman"')
  if (-not $SkipMemory) { Check 'MCP cursor-mem' ($m -match '"cursor-mem"') }
}

if (-not $SkipMemory) {
  $cm = Get-Command cursor-mem -ErrorAction SilentlyContinue
  if (-not $cm) {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) { $cm = @{ Source = 'python -m cursor_mem.cli' } }
  }
  Check 'cursor-mem CLI' ($null -ne $cm)

  if ($cm -and $cm.Source -ne 'python -m cursor_mem.cli') {
    & $cm.Source status 2>&1 | Out-Host
  } elseif (Get-Command python -ErrorAction SilentlyContinue) {
    python -m cursor_mem.cli status 2>&1 | Out-Host
  }
}

if ($fail -gt 0) {
  Write-Host "`n$fail check(s) failed. Run: .\setup.ps1"
  exit 1
}
Write-Host "`nAll checks passed. Restart Cursor if hooks/MCP changed recently."
exit 0
