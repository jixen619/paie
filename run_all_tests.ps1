# ===== PAIE full test runner: 5 prompts per structure (20 total) =====
$ErrorActionPreference = "Stop"
$root = "C:\Users\Jixen Biju\Desktop\PAIE and DABI"
$cli  = Join-Path $root "paie_app\ui\cli.py"
$user = "default"

# --- prompts (5 each) ---
$userStory = @(
  "Provide me the user story for Two-Factor Authentication Integration module",
  "Create a user story for a Model Selector so users can switch between local LLMs",
  "Write a user story for exporting BI datasets (interactions, models, latency) to CSV",
  "Generate a user story for Chat History grouped by date with per-item downloads",
  "Provide a user story for a Freeform mode that bypasses templates but logs analytics"
)
$useCase = @(
  "Provide the use case for Generate Structured Output (preconditions, main flow, alt flows)",
  "Provide the use case for Manage History (view, search, download, clear) with exceptions",
  "Provide the use case for Export BI CSVs including error handling for disk/permission",
  "Provide the use case for Switch Model via dropdown with validation and fallback",
  "Provide the use case for View Analytics when DB has data and when it's empty"
)
$testCase = @(
  "Create test cases for 2FA login (valid, expired, wrong code, rate limit)",
  "Create test cases for Model Selector (default loads, switch, missing model, fallback)",
  "Create test cases for BI export (files exist, schema correct, permission error, large data)",
  "Create test cases for History (search works, MD/JSON/DOCX downloads, clear history)",
  "Create test cases for SQLite logging (row written, timestamp valid, charts render)"
)
$summary = @(
  "Summarize PAIE goals and deliverables for a project brief with risks and assumptions",
  "Summarize last week’s analytics trends (usage and average latency) with 3 insights, 2 actions",
  "Summarize stakeholder interview notes into needs, pain points, success metrics",
  "Summarize a sprint review into accomplishments, carry-overs, blockers, next actions",
  "Summarize a competitive scan of local/offline AI tools into differentiators and gaps"
)

$plan = [ordered]@{
  user_story = $userStory
  use_case   = $useCase
  test_case  = $testCase
  summary    = $summary
}

# --- output folder + CSV ---
$stamp   = (Get-Date).ToString("yyyyMMdd_HHmmss")
$outDir  = Join-Path $root ("test_runs\" + $stamp)
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$csvPath = Join-Path $outDir "summary.csv"
"timestamp,kind,index,prompt,ms,chars,md_file,attempts,status" | Out-File -FilePath $csvPath -Encoding UTF8

function Run-One {
  param([string]$kind,[int]$idx,[string]$prompt,[string]$mdPath)
  $attempt=0; $max=3
  while($true){
    try{
      $attempt++
      $sw=[System.Diagnostics.Stopwatch]::StartNew()
      $output=& python $cli --user $user --kind $kind "$prompt" 2>&1
      $sw.Stop()
      $text = ($output -join "`r`n")
      $ms=[int]$sw.Elapsed.TotalMilliseconds
      $chars=$text.Length
      $header = "# Kind: $kind`n# Prompt`n`n$prompt`n`n# Response`n`n"
      Set-Content -Path $mdPath -Value ($header + $text) -Encoding UTF8
      ('{0},{1},{2},"{3}",{4},{5},{6},{7},{8}' -f (Get-Date).ToString("s"),$kind,$idx,$prompt.Replace('"','""'),$ms,$chars,(Split-Path $mdPath -Leaf),$attempt,"ok") |
        Add-Content -Path $csvPath -Encoding UTF8
      Write-Host ("[{0:00}] {1}  {2} ms  -> {3}" -f $idx,$kind,$ms,(Split-Path $mdPath -Leaf))
      break
    } catch {
      $err = $_.Exception.Message
      if($attempt -lt $max -and $err -match "database is locked"){
        Start-Sleep -Milliseconds 600
        continue
      } else {
        ('{0},{1},{2},"{3}",{4},{5},{6},{7},"{8}"' -f (Get-Date).ToString("s"),$kind,$idx,$prompt.Replace('"','""'),-1,0,(Split-Path $mdPath -Leaf),$attempt,$err.Replace('"','""')) |
          Add-Content -Path $csvPath -Encoding UTF8
        Write-Warning "FAILED [$kind #$idx] $err"
        break
      }
    }
  }
}

# --- run all ---
foreach($kind in $plan.Keys){
  $i=0
  foreach($p in $plan[$kind]){
    $i++
    $mdFile = Join-Path $outDir ("{0:00}_{1}.md" -f $i,$kind)
    Run-One -kind $kind -idx $i -prompt $p -mdPath $mdFile
    Start-Sleep -Milliseconds 300
  }
}

Write-Host "`nRuns complete. CSV -> $csvPath" -ForegroundColor Green
Write-Host "Markdown outputs -> $outDir" -ForegroundColor Green

# --- Export BI CSVs (PowerShell-safe) ---
$py = @"
from pathlib import Path
from core.router import Router
APP = Path(r"$root") / "paie_app"
SETTINGS = APP / "config" / "settings.yaml"
out = Router(str(SETTINGS)).export_bi()
print("BI exported to:", out)
"@
python -c $py
