# paie_app/core/router_rag.py
from __future__ import annotations

import os, re, time, yaml
from pathlib import Path
from typing import Optional

# local package modules (these files already exist in paie_app/core/)
from .client_ollama import OllamaClient
from .memory import Memory
from .personalization import inject  # we'll skip inject if prompt already has [PROFILE]

# we import the root-level rag.py (ONE copy at repo root)
import sys
PKG_ROOT = Path(__file__).resolve().parents[2]  # .../PAIE and DABI
if str(PKG_ROOT) not in sys.path:
    sys.path.append(str(PKG_ROOT))
import rag  # noqa: E402


class Router:
    """
    Loads settings.yaml, talks to Ollama, writes history to SQLite.
    Can optionally prepend UNTRUSTED RAG context with a strict policy.
    """

    def __init__(self, settings_path: str):
        self.settings_path = Path(settings_path)
        with open(settings_path, "r", encoding="utf-8") as f:
            s = yaml.safe_load(f) or {}
        self.settings = s

        db_path = (s.get("storage") or {}).get("db_path")
        if not db_path:
            # default fallback if not present
            db_path = str(PKG_ROOT / "paie_app" / "paie.db")

        self.mem = Memory(db_path)

        model_cfg = s.get("model") or {}
        self.client = OllamaClient(model_cfg.get("name", "llama3.2:latest"),
                                   model_cfg.get("host", "http://localhost:11434"))

    # ------------------------- helpers ---------------------------------
    def _maybe_inject_profile(self, prompt: str, user_profile: dict) -> str:
        """If prompt already contains [PROFILE]...[/PROFILE], don't double-inject."""
        if "[/PROFILE]" in (prompt or ""):
            return prompt
        return inject(user_profile, prompt)

    def _extract_user_query(self, prompt: str) -> str:
        """
        Try to extract the user's actual question from a structured prompt.
        Very lenient: last non-empty line; strips [TEMPLATE]/[PROFILE] blocks.
        """
        if not prompt:
            return ""
        text = re.sub(r"\[/?PROFILE\]|\[/?TEMPLATE\]", "", prompt, flags=re.IGNORECASE)
        lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
        return lines[-1] if lines else text.strip()

    # --------------------------- API -----------------------------------
    def run(
        self,
        username: str,
        prompt: str,
        kind: Optional[str] = None,
        persona: str = "default",
        *,
        temperature: Optional[float] = None,
        top_p: Optional[float] = None,
        use_rag: bool = True,
        rag_top_k: int = 4,
    ):
        """
        Returns (output_text, latency_ms).
        """
        user_id = self.mem.get_or_create_user(username)
        user_profile = self.mem.get_personalization(user_id)

        # Build base prompt (avoid double profile)
        base = self._maybe_inject_profile(prompt, user_profile)

        # Optional RAG
        if use_rag:
            try:
                query = self._extract_user_query(prompt)
                hits = rag.retrieve(query, k=int(rag_top_k))
                ctx_blocks = [t for (t, _m) in hits if isinstance(t, str)]
                if ctx_blocks:
                    policy = (
                        "[RAG POLICY]\n"
                        "- Use the CONTEXT as your only factual source.\n"
                        "- If the answer is NOT present, reply exactly: Not found in local KB.\n"
                        "- Keep answers concise (one or two sentences max).\n"
                        " - After each fact, include [source] using the file name from the CONTEXT metadata if available.\n"
                    )
                    untrusted = "[CONTEXT — UNTRUSTED]\n" + ("\n\n".join(ctx_blocks)) + "\n[/CONTEXT]\n"
                    base = policy + untrusted + base
            except Exception:
                # never break chat if RAG is misconfigured
                pass

        # Sampling params (UI may override; else use settings.yaml)
        model_cfg = self.settings.get("model") or {}
        temperature = float(model_cfg.get("temperature", 0.3) if temperature is None else temperature)
        top_p       = float(model_cfg.get("top_p",       0.95) if top_p       is None else top_p)

        # Call LLM
        t0 = time.time()
        out = self.client.generate(base, temperature=temperature, top_p=top_p)
        latency = int((time.time() - t0) * 1000)

        # Persist
        self.mem.save_interaction(
            user_id,
            prompt=prompt,
            response=out,
            structure_kind=kind,
            persona=persona,
            latency_ms=latency,
            tokens_in=None,
            tokens_out=None,
        )
        return out, latency
