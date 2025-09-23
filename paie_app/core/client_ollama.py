import requests

class OllamaClient:
    def __init__(self, model: str, host: str):
        self.model, self.host = model, host.rstrip('/')

    def generate(self, prompt: str, temperature: float=0.3, top_p: float=0.95) -> str:
        url = f'{self.host}/api/generate'
        payload = {'model': self.model, 'prompt': prompt,
                   'options': {'temperature': temperature, 'top_p': top_p}, 'stream': False}
        r = requests.post(url, json=payload, timeout=300); r.raise_for_status()
        return r.json().get('response','')
