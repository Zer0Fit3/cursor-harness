# Cursor + Windows: RTK, Caveman (small rock + binaries), cursor-mem (optional, default on).
# Idempotent. Run from the cloned cursor-harness folder:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\setup.ps1
#   .\verify.ps1
param(
  [switch]$SkipMemory,
  [switch]$SkipCavemanSkills,
  [string]$RtkVersion = '0.51.0'
)

$ErrorActionPreference = 'Stop'

$LocalBin = Join-Path $env:USERPROFILE '.local\bin'
$CaveBin = Join-Path $env:USERPROFILE '.caveman\bin'
$CursorDir = Join-Path $env:USERPROFILE '.cursor'
$HooksFile = Join-Path $CursorDir 'hooks.json'
$McpFile = Join-Path $CursorDir 'mcp.json'

function Ensure-Dir($p) { if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

function Prepend-UserPath([string[]]$dirs) {
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $userPath) { $userPath = '' }
  foreach ($d in $dirs) {
    if ($d -and ($userPath -notlike "*$d*")) { $userPath = "$d;$userPath" }
  }
  [Environment]::SetEnvironmentVariable('Path', $userPath.TrimEnd(';'), 'User')
  $env:Path = (($dirs | Where-Object { $_ }) -join ';') + ';' + $env:Path
}

function Read-JsonFile($path) {
  if (-not (Test-Path $path)) { return $null }
  return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-JsonFile($path, $obj) {
  ($obj | ConvertTo-Json -Depth 12) | Set-Content -Path $path -Encoding utf8
}

function Merge-Hooks($existing, $rtkHookCmd) {
  $hooks = if ($existing -and $existing.hooks) { $existing.hooks } else { @{} }
  $pre = @($hooks.preToolUse | Where-Object { $_.command -notmatch 'rtk' })
  $hooks.preToolUse = @(@{ command = $rtkHookCmd; matcher = 'Shell' }) + $pre
  return @{ version = 1; hooks = $hooks }
}

function Merge-McpServer($existing, $name, $entry) {
  $root = if ($existing) { $existing } else { @{ mcpServers = @{} } }
  if (-not $root.mcpServers) { $root | Add-Member -NotePropertyName mcpServers -NotePropertyValue @{} -Force }
  $servers = @{}
  foreach ($p in $root.mcpServers.PSObject.Properties) { $servers[$p.Name] = $p.Value }
  $servers[$name] = $entry
  return @{ mcpServers = $servers }
}

function Test-NodeMin([string]$min = '22.13.0') {
  $v = (node -p 'process.versions.node')
  $a = $min.Split('.').ForEach({ [int]$_ })
  $b = $v.Split('.').ForEach({ [int]($_ -replace '\D.*','') })
  for ($i = 0; $i -lt 3; $i++) {
    $ai = if ($i -lt $a.Count) { $a[$i] } else { 0 }
    $bi = if ($i -lt $b.Count) { $b[$i] } else { 0 }
    if ($bi -gt $ai) { return $true }
    if ($bi -lt $ai) { return $false }
  }
  return $true
}

function Find-Python {
  foreach ($cmd in @('python', 'py')) {
    $c = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
  }
  return $null
}

function Ensure-PythonScriptsOnPath {
  $py = Find-Python
  if (-not $py) { return $null }
  $scripts = & $py -c "import sysconfig; print(sysconfig.get_path('scripts'))"
  if ($scripts -and (Test-Path $scripts)) {
    Prepend-UserPath @($scripts)
    return $scripts
  }
  return $null
}

# --- Prerequisites ---
if ($PSVersionTable.PSVersion.Major -lt 5) { Write-Error 'PowerShell 5.1+ required.' }
Ensure-Dir $LocalBin
Ensure-Dir $CursorDir

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Error 'Node.js not on PATH. Install Node 22.13+ from https://nodejs.org, reopen terminal, rerun setup.ps1.'
}
if (-not (Test-NodeMin)) {
  Write-Error "Node $(node -p 'process.versions.node') is below 22.13.0 (required for @caveman-ai/cli)."
}
Write-Host "Node $(node -p 'process.versions.node')"

Prepend-UserPath @($LocalBin, $CaveBin)

# --- RTK ---
$rtkExe = Join-Path $LocalBin 'rtk.exe'
if (-not (Test-Path $rtkExe)) {
  Write-Host "Downloading RTK $RtkVersion..."
  $zip = Join-Path $env:TEMP "rtk-$RtkVersion-win.zip"
  Invoke-WebRequest -Uri "https://github.com/rtk-ai/rtk/releases/download/v$RtkVersion/rtk-x86_64-pc-windows-msvc.zip" -OutFile $zip
  $extract = Join-Path $env:TEMP "rtk-extract-$RtkVersion"
  if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
  Expand-Archive -Path $zip -DestinationPath $extract -Force
  Copy-Item (Get-ChildItem $extract -Filter rtk.exe -Recurse | Select-Object -First 1).FullName $rtkExe -Force
}
& $rtkExe --version | Out-Host

$hooksBefore = Read-JsonFile $HooksFile
& $rtkExe init -g --agent cursor 2>&1 | Out-Host
$hooksAfter = Read-JsonFile $HooksFile
$base = if ($hooksAfter) { $hooksAfter } elseif ($hooksBefore) { $hooksBefore } else { $null }
$rtkHookCmd = "`"$rtkExe`" hook cursor"
Write-JsonFile $HooksFile (Merge-Hooks $base $rtkHookCmd)
Write-Host "RTK hook (full path): $HooksFile"

# --- Caveman ---
if (-not (Get-Command caveman -ErrorAction SilentlyContinue)) {
  npm install -g @caveman-ai/cli 2>&1 | Out-Host
}
caveman setup --install 2>&1 | Out-Host

if (-not $SkipCavemanSkills) {
  Write-Host 'Installing Caveman skills for Cursor (npx skills)...'
  npx skills add JuliusBrussee/caveman -a cursor -g --yes 2>&1 | Out-Host
}

$mcpExe = Join-Path $CaveBin 'caveman-mcp.exe'
if (Test-Path $mcpExe) {
  $mcp = Read-JsonFile $McpFile
  $merged = Merge-McpServer $mcp 'caveman' @{ command = $mcpExe; args = @() }
  Write-JsonFile $McpFile $merged
  Write-Host "Caveman MCP: $McpFile"
}

# --- cursor-mem (default on) ---
if (-not $SkipMemory) {
  $py = Find-Python
  if (-not $py) {
    Write-Error 'Python 3.10+ required for cursor-mem. Install from https://python.org (check "Add to PATH"), rerun setup.ps1.'
  }
  Write-Host "Python: $py"
  & $py -m pip install --upgrade cursor-mem 2>&1 | Out-Host
  Ensure-PythonScriptsOnPath | Out-Null
  & $py -m cursor_mem.cli install --global 2>&1 | Out-Host
  & $py -m cursor_mem.cli start 2>&1 | Out-Host
  # Re-assert RTK hook after cursor-mem may have rewritten hooks.json
  $hooksMem = Read-JsonFile $HooksFile
  Write-JsonFile $HooksFile (Merge-Hooks $hooksMem $rtkHookCmd)
}

Write-Host ''
Write-Host 'Setup finished. Run: .\verify.ps1'
Write-Host 'Restart Cursor. Use Caveman via skill /caveman per chat. Memory viewer: http://127.0.0.1:37800'
