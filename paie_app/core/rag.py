# paie_app/core/router_rag.py
from __future__ import annotations
import time, yaml, os
from pathlib import Path
from typing import Optional
from .client_ollama import OllamaClient
from .memory import Memory
from .personalization import inject
from .structure import Templates
import rag  # <- our pure ChromaDB helper

class Router:
    def __init__(self, settings_path: str):
        with open(settings_path, "r", encoding="utf-8") as f:
            cfg = yaml.safe_load(f) or {}
        self.settings = cfg
        self.mem = Memory(cfg["storage"]["db_path"])
        self.templates = Templates(Path(settings_path).resolve().parent.parent / "data" / "templates")
        self.client = OllamaClient(cfg["model"]["name"], cfg["model"]["host"])

    def run(
        self,
        username: str,
        prompt: str,
        kind: Optional[str] = None,
        persona: str = "default",
        temperature: float = 0.3,
        top_p: float = 0.95,
        use_rag: bool = True,
        rag_top_k: int = 4,
    ):
        uid = self.mem.get_or_create_user(username)
        profile = self.mem.get_personalization(uid)

        final = inject(profile, prompt)
        if kind:
            final = self.templates.build_prompt(kind, final)

        # Strict RAG mode if toggled on
        if use_rag:
            hits = rag.retrieve(prompt, k=int(rag_top_k))
            ctx_blocks = [t for (t, _m) in hits if isinstance(t, str)]
            if ctx_blocks:
                policy = (
                    "[RAG POLICY]\n"
                    "- Use the CONTEXT as your only factual source.\n"
                    '- If the answer is NOT present in the context, reply exactly: Not found in local KB.\n'
                    "- Keep answers concise (one or two sentences max).\n"
                    "[/RAG POLICY]\n"
                )
                untrusted = "[CONTEXT — UNTRUSTED]\n" + "\n\n".join(ctx_blocks) + "\n[/CONTEXT]\n"
                final = policy + untrusted + final

        t0 = time.time()
        out = self.client.complete(final, temperature=temperature, top_p=top_p)
        ms = int((time.time() - t0) * 1000)

        # basic logging to SQLite
        self.mem.save_interaction(uid, kind or "(none)", final, out, ms)
        return out, ms
