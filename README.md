# PAIE and DABI

Offline, privacy-first Personalized AI Engine with built-in Data Analytics/BI.

## Run (GUI)
1. Create venv: \py -m venv .venv && .\.venv\Scripts\activate\
2. Install deps: \pip install -r requirements.txt\
3. Start: \streamlit run paie_app/ui/app_streamlit.py\

## Run (CLI)
\python paie_app/ui/cli.py --model "llama3.2:latest" --user "alice"\
"@

# 5) VS Code launch.json (escape $)
Write-Text "C:\Users\Jixen Biju\Desktop\PAIE and DABI\.vscode\launch.json" @"
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "PAIE GUI (Streamlit)",
      "type": "python",
      "request": "launch",
      "program": "/.venv/Scripts/streamlit.exe",
      "args": ["run", "/paie_app/ui/app_streamlit.py"],
      "console": "integratedTerminal"
    },
    {
      "name": "PAIE CLI",
      "type": "python",
      "request": "launch",
      "program": "/paie_app/ui/cli.py",
      "args": ["--model", "llama3.2:latest", "--user", "alice"],
      "console": "integratedTerminal"
    }
  ]
}
