param(
  [string]$ProjectRoot = ".",
  [string]$StreamlitPath = ".\app_streamlit.py",
  [switch]$InstallDeps
)

$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$StreamlitPath = (Resolve-Path (Join-Path $ProjectRoot $StreamlitPath)).Path

# Ensure files exist
if (-not (Test-Path (Join-Path $ProjectRoot "router_rag.py"))) {
  Write-Error "router_rag.py not found. Run the generator step that created rag.py and router_rag.py first."
  exit 1
}

# Swap import to use router_rag instead of router (non-destructive: write app_streamlit_rag_router.py)
$src = Get-Content -Raw -Path $StreamlitPath -Encoding UTF8
$patched = $src -replace 'from\\s+router\\s+import\\s+Router', 'from router_rag import Router'
$outPath = Join-Path $ProjectRoot "app_streamlit_rag_router.py"
[System.IO.File]::WriteAllText($outPath, $patched, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "✔ Created: $outPath (now using router_rag.Router)"

if ($InstallDeps) {
  Push-Location $ProjectRoot
  try {
    if (-not (Test-Path ".venv")) {
      Write-Host "Creating venv in .venv ..."
      py -m venv .venv 2>$null; if ($LASTEXITCODE -ne 0) { python -m venv .venv }
    }
    & .\.venv\Scripts\Activate.ps1
    python -m pip install --upgrade pip
    if (Test-Path "requirements.txt") { pip install -r requirements.txt }
    pip install chromadb sentence-transformers pypdf python-docx langchain-community
    Write-Host "Dependencies installed."
  } finally {
    Pop-Location
  }
}

Write-Host "`nRun:"
Write-Host "  streamlit run `"$outPath`""
