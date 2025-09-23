import time, yaml, os
from .client_ollama import OllamaClient
from .memory import Memory
from .personalization import inject
from .structure import Templates

class Router:
    def __init__(self, settings_path: str):
        with open(settings_path, 'r', encoding='utf-8') as f:
            s = yaml.safe_load(f)
        self.settings = s
        self.mem = Memory(s['storage']['db_path'])
        self.templates = Templates(os.path.join(os.path.dirname(settings_path), '..', 'data', 'templates'))
        self.client = OllamaClient(s['model']['name'], s['model']['host'])

    def run(self, username: str, prompt: str, kind: str=None, persona: str='default'):
        user_id = self.mem.get_or_create_user(username)
        profile = self.mem.get_personalization(user_id)
        t0 = time.time()
        base = inject(profile, prompt)
        if kind: base = self.templates.build_prompt(kind, base)
        out = self.client.generate(base, self.settings['model']['temperature'], self.settings['model']['top_p'])
        latency = int((time.time()-t0)*1000)
        self.mem.save_interaction(user_id, prompt=prompt, response=out, structure_kind=kind, persona=persona,
                                  latency_ms=latency, tokens_in=None, tokens_out=None)
        return out, latency

    def export_bi(self):
        return self.mem.export_csv(self.settings['storage']['exports_dir'])
