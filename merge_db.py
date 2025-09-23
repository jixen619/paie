import sqlite3, os, shutil

CANONICAL = r".\paie_app\paie.db"
OTHERS    = [r".\data\paie.db", r".\paie_app\data\paie.db"]

def count(con, table):
    try:
        return con.execute(f"select count(*) from {table}").fetchone()[0]
    except sqlite3.Error:
        return None

# backup once
if os.path.exists(CANONICAL):
    try: shutil.copy2(CANONICAL, CANONICAL + ".bak")
    except Exception: pass

# show counts before
con = sqlite3.connect(CANONICAL)
print("Before:", {t: count(con,t) for t in ("interactions","feedback")})
con.close()

def merge(src):
    if not os.path.exists(src) or os.path.getsize(src) == 0:
        print(f"Skip {src} (missing/empty)"); return
    con = sqlite3.connect(CANONICAL)
    cur = con.cursor()
    cur.execute("ATTACH DATABASE ? AS other", (src,))
    for t in ("interactions","feedback"):
        try:
            cur.execute(f"SELECT 1 FROM other.sqlite_master WHERE type='table' AND name='{t}'")
            if cur.fetchone():
                # copy by column list; ignore dup primary keys
                cur.execute(f"PRAGMA table_info({t})")
                cols = [c[1] for c in cur.fetchall()]
                col_list = ",".join(cols)
                cur.execute(
                    f"INSERT OR IGNORE INTO {t} ({col_list}) "
                    f"SELECT {col_list} FROM other.{t}"
                )
                print(f"Merged {t} from {src}")
        except sqlite3.Error as e:
            print(f"Skip {t} from {src}: {e}")
    con.commit()
    cur.execute("DETACH DATABASE other")
    con.close()

for s in OTHERS:
    merge(s)

con = sqlite3.connect(CANONICAL)
print("After:", {t: count(con,t) for t in ("interactions","feedback")})
con.close()
print("Done")
