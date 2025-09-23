$root = "C:\Users\Jixen Biju\Desktop\PAIE and DABI"
$app  = Join-Path $root "paie_app"
$dirs = @(
  "$app\core", "$app\ui", "$app\config",
  "$app\data\templates", "$app\data\exports", "$app\tests", "$root\.vscode"
)
$dirs | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }

# --- requirements.txt ---
@'
requests
streamlit
plotly
pydantic
pyyaml
python-docx
pypdf
chromadb
sentence-transformers
'@ | Out-File "$root\requirements.txt" -Encoding UTF8

# --- README.md ---
@"
# PAIE and DABI

Offline, privacy-first Personalized AI Engine with Built-in Data Analytics/BI.

## Run (GUI)
1. Create venv: `py -m venv .venv && .\.venv\Scripts\activate`
2. Install deps: `pip install -r requirements.txt`
3. Start: `streamlit run paie_app/ui/app_streamlit.py`

## Run (CLI)
`python paie_app/ui/cli.py --model "llama3.2:latest" --user "alice"`
"@ | Out-File "$root\README.md" -Encoding UTF8

# --- VS Code launch.json ---
@'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "PAIE GUI (Streamlit)",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/.venv/Scripts/streamlit.exe",
      "args": ["run", "${workspaceFolder}/paie_app/ui/app_streamlit.py"],
      "console": "integratedTerminal"
    },
    {
      "name": "PAIE CLI",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/paie_app/ui/cli.py",
      "args": ["--model", "llama3.2:latest", "--user", "alice"],
      "console": "integratedTerminal"
    }
  ]
}
'@ | Out-File "$root\.vscode\launch.json" -Encoding UTF8

# --- __init__.py ---
@''@ | Out-File "$app\__init__.py" -Encoding UTF8

# --- config/settings.yaml ---
@'
model:
  name: llama3.2:latest
  host: http://127.0.0.1:11434
  temperature: 0.3
  top_p: 0.95
storage:
  db_path: ./paie_app/paie.db
  exports_dir: ./paie_app/data/exports
ui:
  theme: dark
  language: en
rag:
  enabled: false
  top_k: 5
  chunk_size: 800
  chunk_overlap: 80
privacy:
  telemetry: false
'@ | Out-File "$app\config\settings.yaml" -Encoding UTF8

# --- config/personas.yaml ---
@'
personas:
  default:
    tone: neutral
    formality: medium
    verbosity: medium
    markdown: true
  architect:
    tone: formal
    formality: high
    verbosity: medium
    markdown: true
    interests: ["architecture", "requirements", "diagrams"]
  qa_lead:
    tone: neutral
    formality: medium
    verbosity: medium
    markdown: true
    interests: ["testing", "quality", "automation"]
'@ | Out-File "$app\config\personas.yaml" -Encoding UTF8

# --- data/templates (four starters) ---
@'
name: user_story
display: "User Story"
markdown_order: ["Title","Description","Acceptance Criteria"]
rules:
  Title: "One concise line."
  Description: "As a <role>, I want <capability>, so that <benefit>."
  Acceptance Criteria:
    style: bullet
    min_items: 3
json_schema:
  type: object
  properties:
    title: {type: string}
    description: {type: string}
    acceptanceCriteria: {type: array, items: {type: string}}
  required: [title, description, acceptanceCriteria]
'@ | Out-File "$app\data\templates\user_story.yaml" -Encoding UTF8

@'
name: use_case
display: "Use Case"
markdown_order: ["Title","Description","Steps"]
rules:
  Steps:
    style: numbered
    min_items: 4
json_schema:
  type: object
  properties:
    title: {type: string}
    description: {type: string}
    steps: {type: array, items: {type: string}}
  required: [title, description, steps]
'@ | Out-File "$app\data\templates\use_case.yaml" -Encoding UTF8

@'
name: test_case
display: "Test Case"
markdown_order: ["Title","Description","Steps"]
rules:
  Steps:
    style: table_like
    min_items: 3
json_schema:
  type: object
  properties:
    title: {type: string}
    description: {type: string}
    steps: {type: array, items: {type: object, properties: {step: {type: string}, expected: {type: string}}, required: ["step","expected"]}}
  required: [title, description, steps]
'@ | Out-File "$app\data\templates\test_case.yaml" -Encoding UTF8

@'
name: summary
display: "Summary"
markdown_order: ["Topic","Key Points","Action Items"]
rules:
  Key Points:
    style: bullet
    min_items: 3
  Action Items:
    style: checkbox
json_schema:
  type: object
  properties:
    topic: {type: string}
    keyPoints: {type: array, items: {type: string}}
    actionItems: {type: array, items: {type: string}}
  required: [topic, keyPoints]
'@ | Out-File "$app\data\templates\summary.yaml" -Encoding UTF8

# --- core\memory.py ---
@'
import json, sqlite3, os
from datetime import datetime
from typing import Dict, List, Tuple

class Memory:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self._ensure_schema()

    def _conn(self):
        return sqlite3.connect(self.db_path)

    def _ensure_schema(self):
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        with self._conn() as con:
            cur = con.cursor()
            cur.execute("""CREATE TABLE IF NOT EXISTS users(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              username TEXT UNIQUE, personalization TEXT, created_at TEXT, updated_at TEXT)""")
            cur.execute("""CREATE TABLE IF NOT EXISTS interactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER, prompt TEXT, response TEXT,
              structure_kind TEXT, persona TEXT,
              latency_ms INTEGER, tokens_in INTEGER, tokens_out INTEGER,
              created_at TEXT, FOREIGN KEY(user_id) REFERENCES users(id))""")
            cur.execute("""CREATE TABLE IF NOT EXISTS documents(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              collection TEXT, filename TEXT, mime TEXT, hash TEXT,
              added_at TEXT, chunks INTEGER, status TEXT)""")
            con.commit()

    def get_or_create_user(self, username: str) -> int:
        with self._conn() as con:
            cur = con.cursor()
            cur.execute("SELECT id FROM users WHERE username=?", (username,))
            row = cur.fetchone()
            if row: return row[0]
            now = datetime.utcnow().isoformat()
            cur.execute("INSERT INTO users(username,personalization,created_at,updated_at) VALUES (?,?,?,?)",
                        (username, json.dumps({"tone":"neutral","formality":"medium","verbosity":"medium","markdown":True}), now, now))
            con.commit()
            return cur.lastrowid

    def get_personalization(self, user_id: int) -> Dict:
        with self._conn() as con:
            cur = con.cursor()
            cur.execute("SELECT personalization FROM users WHERE id=?", (user_id,))
            row = cur.fetchone()
            return json.loads(row[0]) if row and row[0] else {}

    def update_personalization(self, user_id: int, updates: Dict):
        current = self.get_personalization(user_id); current.update(updates)
        with self._conn() as con:
            cur = con.cursor()
            cur.execute("UPDATE users SET personalization=?, updated_at=? WHERE id=?",
                        (json.dumps(current), datetime.utcnow().isoformat(), user_id)); con.commit()

    def save_interaction(self, user_id: int, **kw):
        with self._conn() as con:
            cur = con.cursor()
            cur.execute("""INSERT INTO interactions(user_id,prompt,response,structure_kind,persona,
                        latency_ms,tokens_in,tokens_out,created_at) VALUES (?,?,?,?,?,?,?,?,?)""",
                        (user_id, kw.get("prompt",""), kw.get("response",""), kw.get("structure_kind"),
                         kw.get("persona"), kw.get("latency_ms"), kw.get("tokens_in"), kw.get("tokens_out"),
                         datetime.utcnow().isoformat()))
            con.commit()

    def export_csv(self, out_dir: str):
        os.makedirs(out_dir, exist_ok=True)
        with self._conn() as con:
            for table in ("users","interactions","documents"):
                rows = con.execute(f"SELECT * FROM {table}").fetchall()
                headers = [d[0] for d in con.execute(f"PRAGMA table_info({table})")]
                path = os.path.join(out_dir, f"{table}.csv")
                with open(path, "w", encoding="utf-8") as f:
                    f.write(",".join(headers)+"\n")
                    for r in rows:
                        f.write(",".join(['"'+str(x).replace('"','""')+'"' if x is not None else '' for x in r])+"\n")
        return out_dir
'@ | Out-File "$app\core\memory.py" -Encoding UTF8

# --- core\client_ollama.py ---
@'
import json, requests

class OllamaClient:
    def __init__(self, model: str, host: str):
        self.model, self.host = model, host.rstrip("/")

    def generate(self, prompt: str, temperature: float=0.3, top_p: float=0.95) -> str:
        url = f"{self.host}/api/generate"
        payload = {"model": self.model, "prompt": prompt, "options": {"temperature": temperature,"top_p": top_p}, "stream": False}
        r = requests.post(url, json=payload, timeout=300); r.raise_for_status()
        return r.json().get("response","")
'@ | Out-File "$app\core\client_ollama.py" -Encoding UTF8

# --- core\personalization.py ---
@'
import textwrap

SYSTEM_PROMPT = (
    "You are PAIE, a privacy-first, offline AI assistant. "
    "Follow user personalization strictly and keep responses well-structured."
)

def inject(profile: dict, user_prompt: str) -> str:
    tone = profile.get("tone","neutral"); formality = profile.get("formality","medium")
    verbosity = profile.get("verbosity","medium"); md = profile.get("markdown", True)
    interests = ", ".join(profile.get("interests",[]) or [])
    rules = [f"Tone: {tone}", f"Formality: {formality}", f"Verbosity: {verbosity}"]
    if interests: rules.append(f"User interests: {interests}")
    if md: rules.append("Use clean Markdown where appropriate.")
    rules_md = "\n".join(f"- {r}" for r in rules)
    return textwrap.dedent(f"""
    {SYSTEM_PROMPT}
    Personalization rules:
    {rules_md}

    === User Request ===
    {user_prompt}
    """)
'@ | Out-File "$app\core\personalization.py" -Encoding UTF8

# --- core\structure.py ---
@'
import os, yaml, re, json
from typing import Dict

class Templates:
    def __init__(self, dir_path: str):
        self.dir = dir_path
        self.cache = {}
        self._load()

    def _load(self):
        for fn in os.listdir(self.dir):
            if fn.endswith(".yaml"):
                with open(os.path.join(self.dir, fn), "r", encoding="utf-8") as f:
                    y = yaml.safe_load(f)
                    self.cache[y["name"]] = y

    def list(self): return list(self.cache.keys())

    def build_prompt(self, kind: str, base_prompt: str) -> str:
        t = self.cache[kind]
        sections = "\n\n".join([h+":" for h in t["markdown_order"]])
        header = f"Return ONLY the following sections in Markdown, in this exact order:\\n\\n{sections}\\n"
        return header + base_prompt

    def validate(self, kind: str, text: str) -> bool:
        t = self.cache[kind]; order = t["markdown_order"]
        # simple order check: all headings appear in order
        idx = 0
        for h in order:
            m = re.search(rf"^\\s*{re.escape(h)}\\s*:\\s*$", text, flags=re.MULTILINE|re.IGNORECASE)
            if not m: return False
            if m.start() < idx: return False
            idx = m.start()
        return True
'@ | Out-File "$app\core\structure.py" -Encoding UTF8

# --- core\router.py ---
@'
import time, json, yaml, os
from .client_ollama import OllamaClient
from .memory import Memory
from .personalization import inject
from .structure import Templates

class Router:
    def __init__(self, settings_path: str):
        with open(settings_path, "r", encoding="utf-8") as f:
            s = yaml.safe_load(f)
        self.settings = s
        self.mem = Memory(s["storage"]["db_path"])
        self.templates = Templates(os.path.join(os.path.dirname(settings_path), "..", "data", "templates"))
        self.client = OllamaClient(s["model"]["name"], s["model"]["host"])

    def run(self, username: str, prompt: str, kind: str=None, persona: str="default"):
        user_id = self.mem.get_or_create_user(username)
        profile = self.mem.get_personalization(user_id)
        t0 = time.time()
        base = inject(profile, prompt)
        if kind: base = self.templates.build_prompt(kind, base)
        out = self.client.generate(base, self.settings["model"]["temperature"], self.settings["model"]["top_p"])
        latency = int((time.time()-t0)*1000)
        self.mem.save_interaction(user_id, prompt=prompt, response=out, structure_kind=kind, persona=persona,
                                  latency_ms=latency, tokens_in=None, tokens_out=None)
        return out, latency

    def export_bi(self):
        return self.mem.export_csv(self.settings["storage"]["exports_dir"])
'@ | Out-File "$app\core\router.py" -Encoding UTF8

# --- ui\cli.py ---
@'
import argparse, os, sys
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parents[1]))
from core.router import Router

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--user", required=True)
    parser.add_argument("--model", default=None, help="Override model in settings.yaml")
    parser.add_argument("--kind", choices=["user_story","use_case","test_case","summary"])
    parser.add_argument("prompt", nargs="*", help="Your prompt")
    args = parser.parse_args()

    settings = os.path.join(Path(__file__).resolve().parents[1], "config", "settings.yaml")
    r = Router(settings)
    if args.model:
        r.settings["model"]["name"] = args.model
    prompt = " ".join(args.prompt) if args.prompt else input("Prompt > ")
    out, ms = r.run(username=args.user, prompt=prompt, kind=args.kind)
    print(f"\n---- Response ({ms} ms) ----\n{out}\n")

if __name__ == "__main__":
    main()
'@ | Out-File "$app\ui\cli.py" -Encoding UTF8

# --- ui\app_streamlit.py ---
@'
import os, sys, yaml, time
from pathlib import Path
import streamlit as st
sys.path.append(str(Path(__file__).resolve().parents[1]))
from core.router import Router

APP_DIR = Path(__file__).resolve().parents[1]
SETTINGS = APP_DIR / "config" / "settings.yaml"

st.set_page_config(page_title="PAIE", layout="wide")
st.title("PAIE – Offline Personalized AI + Analytics")

# Sidebar controls
st.sidebar.header("Session")
username = st.sidebar.text_input("User", value="alice")
with open(SETTINGS, "r", encoding="utf-8") as f:
    default_settings = yaml.safe_load(f)
model = st.sidebar.text_input("Model", value=default_settings["model"]["name"])
kind = st.sidebar.selectbox("Structure", ["(none)","user_story","use_case","test_case","summary"])
temp = st.sidebar.slider("Temperature", 0.0, 1.0, float(default_settings["model"]["temperature"]))
top_p = st.sidebar.slider("Top-p", 0.1, 1.0, float(default_settings["model"]["top_p"]))

r = Router(str(SETTINGS))
r.settings["model"]["name"] = model
r.settings["model"]["temperature"] = temp
r.settings["model"]["top_p"] = top_p

tabs = st.tabs(["Generate","Analytics","Export BI"])
with tabs[0]:
    prompt = st.text_area("Prompt", height=160, placeholder="Ask for a User Story / Use Case / Test Case ...")
    go = st.button("Generate", type="primary")
    if go and prompt.strip():
        with st.spinner("Thinking locally..."):
            k = None if kind=="(none)" else kind
            out, ms = r.run(username=username, prompt=prompt, kind=k)
        st.success(f"Done in {ms} ms")
        st.markdown(out)
        st.download_button("Download Markdown", data=out, file_name="output.md")

with tabs[1]:
    st.subheader("Usage & Performance (from SQLite)")
    import sqlite3, pandas as pd, plotly.express as px
    con = sqlite3.connect(str(APP_DIR / "paie.db"))
    df = pd.read_sql_query("SELECT created_at, structure_kind, latency_ms FROM interactions ORDER BY id DESC LIMIT 500", con)
    if len(df)==0:
        st.info("No data yet. Generate something first.")
    else:
        df["date"]=pd.to_datetime(df["created_at"]).dt.date
        c1,c2 = st.columns(2)
        c1.plotly_chart(px.bar(df, x="structure_kind", title="Structure usage count"))
        c2.plotly_chart(px.line(df.groupby("date")["latency_ms"].mean().reset_index(), x="date", y="latency_ms", title="Avg latency (ms) by day"))

with tabs[2]:
    if st.button("Export BI CSVs"):
        out_dir = r.export_bi()
        st.success(f"Exported to {out_dir}")
'@ | Out-File "$app\ui\app_streamlit.py" -Encoding UTF8

# --- tests (light stubs) ---
@'
def test_stub():
    assert True
'@ | Out-File "$app\tests\test_cli.py" -Encoding UTF8

Write-Host "Skeleton created." -ForegroundColor Green
"@

# --- end script ---

