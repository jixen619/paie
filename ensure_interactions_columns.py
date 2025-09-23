import os, sqlite3, sys

candidates = [
    os.path.join("paie_app","data","paie.db"),
    os.path.join("paie_app","paie.db"),
]

def has_table(db, name):
    if not os.path.exists(db):
        return False
    con = sqlite3.connect(db); cur = con.cursor()
    try:
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (name,))
        ok = cur.fetchone() is not None
    finally:
        con.close()
    return ok

DB = next((p for p in candidates if has_table(p, "interactions")), None)
if DB is None:
    print("No 'interactions' table found in any known DB path.")
    print("Create it by running the app once or a single CLI generation, then re-run this script.")
    sys.exit(2)

con = sqlite3.connect(DB); cur = con.cursor()

def ensure(col, default=None):
    cur.execute("PRAGMA table_info(interactions)")
    cols = [r[1] for r in cur.fetchall()]
    if col not in cols:
        cur.execute(f"ALTER TABLE interactions ADD COLUMN {col} TEXT")
    if default is not None:
        cur.execute(f"""
            UPDATE interactions
               SET {col} = COALESCE(NULLIF({col}, ''), ?)
             WHERE {col} IS NULL OR {col} = ''
        """, (default,))

for c, d in (
    ("model_name","llama3.2:latest"),
    ("profile_name","default"),
    ("template_name","(none)")
):
    ensure(c, d)

con.commit(); con.close()
print(f"OK: {DB} — columns ensured/backfilled.")
