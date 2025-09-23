param([switch]$VerboseKill)

$ErrorActionPreference = 'SilentlyContinue'

# --- Resolve project folder & files ---
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $scriptDir
$runDir   = Join-Path $scriptDir ".run"
$pidFile  = Join-Path $runDir   "streamlit.pid"
$portFile = Join-Path $runDir   "port.txt"

function Kill-ByPid([int]$targetPid) {
  if (-not $targetPid) { return $false }
  if ($VerboseKill) { Write-Host "Killing PID $targetPid ..." }

  # try PowerShell first
  try {
    if ($targetPid -ne $PID) { Stop-Process -Id $targetPid -Force -ErrorAction Stop; }
  } catch { }

  # ensure from a separate process (handles self/trees)
  Start-Process "$env:WINDIR\System32\taskkill.exe" -ArgumentList "/PID $targetPid /T /F" -NoNewWindow -Wait | Out-Null
  return -not (Get-Process -Id $targetPid -ErrorAction SilentlyContinue)
}

$killed = $false

# 1) PID file
if (Test-Path $pidFile) {
  $pidText = (Get-Content $pidFile | Select-Object -First 1).Trim()
  if ($pidText -match '^\d+$') {
    $serverPid = [int]$pidText
    $killed = Kill-ByPid $serverPid
  }
}

# 2) by port (if we have it and not killed yet)
if (-not $killed -and (Test-Path $portFile)) {
  $port = ((Get-Content $portFile).Trim() -as [int])
  if ($port) {
    try {
      $own = (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop).OwningProcess
      if ($own) { $killed = Kill-ByPid $own }
    } catch { }
  }
}

# 3) by command line (final fallback)
if (-not $killed) {
  Get-CimInstance Win32_Process |
    Where-Object {
      $_.Name -match '^(python(w)?|streamlit)\.exe$' -and
      $_.CommandLine -match 'paie_app\\ui\\app_streamlit\.py'
    } |
    ForEach-Object {
      if (Kill-ByPid $_.ProcessId) { $killed = $true }
    }
}

if ($killed) {
  Remove-Item $runDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
  Write-Host "Stopped PAIE."
} else {
  Write-Host "Nothing to stop."
}
