from pathlib import Path
import sqlite3, csv, os

ROOT = Path(__file__).resolve().parent
APP  = ROOT / "paie_app"
DB   = APP / "data" / "paie.db"
OUT  = APP / "data" / "exports"
OUT.mkdir(parents=True, exist_ok=True)

def table_has(conn, table):
    cur = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?;", (table,))
    return cur.fetchone() is not None

def cols(conn, table):
    return [r[1] for r in conn.execute(f"PRAGMA table_info({table})").fetchall()]

def export_table(conn, table, dest, wanted=None):
    if not table_has(conn, table): 
        return None
    available = cols(conn, table)
    if wanted is None:
        select_cols = available
    else:
        # keep order: wanted first (only those that exist), then any remaining available (optional)
        select_cols = [c for c in wanted if c in available]
        # If you also want common extras (prompt/response/tokens), include when present
        extras = [c for c in ["prompt","response","tokens_in","tokens_out","persona"] if c in available]
        select_cols += [c for c in extras if c not in select_cols]
    if not select_cols: 
        return None

    rows = conn.execute(f"SELECT {', '.join(select_cols)} FROM {table} ORDER BY 1").fetchall()
    with open(dest, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(select_cols)
        w.writerows(rows)
    return dest

def run_export():
    with sqlite3.connect(DB) as con:
        # interactions: prefer these, fall back to what's there
        preferred = [
            "id","user_id","document_id","structure_kind","created_at",
            "latency_ms","model_name","profile_name","template_name","rating"
        ]
        interactions = export_table(con, "interactions", OUT / "interactions.csv", wanted=preferred)
        documents    = export_table(con, "documents",    OUT / "documents.csv")
        users        = export_table(con, "users",        OUT / "users.csv")
    return OUT

if __name__ == "__main__":
    out = run_export()
    print("BI exported to:", out)
