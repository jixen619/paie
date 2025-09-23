import os, yaml, re

class Templates:
    def __init__(self, dir_path: str):
        self.dir = dir_path
        self.cache = {}
        self._load()

    def _load(self):
        for fn in os.listdir(self.dir):
            if fn.endswith('.yaml'):
                with open(os.path.join(self.dir, fn), 'r', encoding='utf-8') as f:
                    y = yaml.safe_load(f)
                    self.cache[y['name']] = y

    def list(self): return list(self.cache.keys())

    def build_prompt(self, kind: str, base_prompt: str) -> str:
        t = self.cache[kind]
        sections = '\\n\\n'.join([h+':' for h in t['markdown_order']])
        header = f'Return ONLY the following sections in Markdown, in this exact order:\\n\\n{sections}\\n'
        return header + base_prompt

    def validate(self, kind: str, text: str) -> bool:
        t = self.cache[kind]; order = t['markdown_order']
        idx = 0
        for h in order:
            m = re.search(rf'^\\s*{re.escape(h)}\\s*:\\s*$', text, flags=re.MULTILINE|re.IGNORECASE)
            if not m: return False
            if m.start() < idx: return False
            idx = m.start()
        return True
