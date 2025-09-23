# rag.py — Pure ChromaDB + sentence-transformers (no LangChain)
from __future__ import annotations
import os
from pathlib import Path
from typing import List, Tuple, Dict, Any

import chromadb
from chromadb.utils import embedding_functions

ROOT = Path(__file__).resolve().parent
VECTOR_DIR = Path(os.getenv("PAIE_VECTOR_DIR", str(ROOT / "data" / "chroma")))
EMBED_MODEL = os.getenv("PAIE_EMBED_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
COLLECTION = os.getenv("PAIE_COLLECTION", "paie_kb")

def _col():
    VECTOR_DIR.mkdir(parents=True, exist_ok=True)
    client = chromadb.PersistentClient(path=str(VECTOR_DIR))
    ef = embedding_functions.SentenceTransformerEmbeddingFunction(model_name=EMBED_MODEL)
    return client.get_or_create_collection(COLLECTION, embedding_function=ef)

def retrieve(query: str, k: int = 4) -> List[Tuple[str, Dict[str, Any]]]:
    q = (query or "").strip()
    if not q:
        return []
    col = _col()
    res = col.query(query_texts=[q], n_results=k, include=["documents", "metadatas"])
    docs = (res.get("documents") or [[]])[0]
    metas = (res.get("metadatas") or [[]])[0]
    out: List[Tuple[str, Dict[str, Any]]] = []
    for i in range(min(len(docs), len(metas))):
        out.append((docs[i] or "", metas[i] or {}))
    return out
