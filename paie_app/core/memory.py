import json, sqlite3, os
from datetime import datetime
from typing import Dict

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
            cur.execute('''CREATE TABLE IF NOT EXISTS users(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              username TEXT UNIQUE, personalization TEXT, created_at TEXT, updated_at TEXT)''')
            cur.execute('''CREATE TABLE IF NOT EXISTS interactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER, prompt TEXT, response TEXT,
              structure_kind TEXT, persona TEXT,
              latency_ms INTEGER, tokens_in INTEGER, tokens_out INTEGER,
              created_at TEXT, FOREIGN KEY(user_id) REFERENCES users(id))''')
            cur.execute('''CREATE TABLE IF NOT EXISTS documents(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              collection TEXT, filename TEXT, mime TEXT, hash TEXT,
              added_at TEXT, chunks INTEGER, status TEXT)''')
            con.commit()

    def get_or_create_user(self, username: str) -> int:
        with self._conn() as con:
            cur = con.cursor()
            cur.execute('SELECT id FROM users WHERE username=?', (username,))
            row = cur.fetchone()
            if row: return row[0]
            now = datetime.utcnow().isoformat()
            cur.execute('INSERT INTO users(username,personalization,created_at,updated_at) VALUES (?,?,?,?)',
                        (username, json.dumps({"tone":"neutral","formality":"medium","verbosity":"medium","markdown":True}), now, now))
            con.commit()
            return cur.lastrowid

    def get_personalization(self, user_id: int) -> Dict:
        with self._conn() as con:
            cur = con.cursor()
            cur.execute('SELECT personalization FROM users WHERE id=?', (user_id,))
            row = cur.fetchone()
            return json.loads(row[0]) if row and row[0] else {}

    def update_personalization(self, user_id: int, updates: Dict):
        current = self.get_personalization(user_id); current.update(updates)
        with self._conn() as con:
            cur = con.cursor()
            cur.execute('UPDATE users SET personalization=?, updated_at=? WHERE id=?',
                        (json.dumps(current), datetime.utcnow().isoformat(), user_id))
            con.commit()

    def save_interaction(self, user_id: int, **kw):
        with self._conn() as con:
            cur = con.cursor()
            cur.execute('''INSERT INTO interactions(user_id,prompt,response,structure_kind,persona,
                        latency_ms,tokens_in,tokens_out,created_at) VALUES (?,?,?,?,?,?,?,?,?)''',
                        (user_id, kw.get('prompt',''), kw.get('response',''), kw.get('structure_kind'),
                         kw.get('persona'), kw.get('latency_ms'), kw.get('tokens_in'), kw.get('tokens_out'),
                         datetime.utcnow().isoformat()))
            con.commit()

    def export_csv(self, out_dir: str):
        os.makedirs(out_dir, exist_ok=True)
        with self._conn() as con:
            for table in ('users','interactions','documents'):
                rows = con.execute(f'SELECT * FROM {table}').fetchall()
                headers = [d[1] for d in con.execute(f'PRAGMA table_info({table})')]
                path = os.path.join(out_dir, f'{table}.csv')
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(','.join(headers)+'\n')
                    for r in rows:
                        f.write(','.join(['\"'+str(x).replace('\"','\"\"')+'\"' if x is not None else '' for x in r])+'\\n')
        return out_dir
