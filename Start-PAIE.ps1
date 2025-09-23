$ErrorActionPreference = 'Stop'

# --- Resolve project folder ---
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $scriptDir

# --- Paths (.run, pid/port files) ---
$runDir   = Join-Path $scriptDir ".run"
$pidFile  = Join-Path $runDir   "streamlit.pid"
$portFile = Join-Path $runDir   "port.txt"
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
Remove-Item $pidFile,$portFile -Force -ErrorAction SilentlyContinue

# --- Pick a free port ---
$ports = 8501,8510,8511
function Test-Free([int]$p){
  try { $c = New-Object Net.Sockets.TcpClient('127.0.0.1', $p); $c.Close(); $false } catch { $true }
}
$port = ($ports | Where-Object { Test-Free $_ } | Select-Object -First 1)
if (-not $port) { $port = 8501 }
Set-Content -Path $portFile -Value $port -Encoding ascii

# --- Python path (venv first, else system) ---
$py = Join-Path $scriptDir ".venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }

# --- Launch Streamlit (minimized) and record the PID ---
$arg  = "-m streamlit run `"paie_app\ui\app_streamlit.py`" --server.port $port --server.address localhost --server.headless true"
$proc = Start-Process -FilePath $py -ArgumentList $arg -WindowStyle Minimized -PassThru
Set-Content -Path $pidFile -Value $proc.Id -Encoding ascii

# --- Open one browser tab ---
Start-Process "http://localhost:$port"
Write-Host "PAIE started on http://localhost:$port (PID $($proc.Id))"
