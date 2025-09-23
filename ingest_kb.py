# ingest_kb.py — Build local Chroma index (no LangChain)
from __future__ import annotations
import argparse, os, re
from pathlib import Path
from typing import List

import chromadb
from chromadb.utils import embedding_functions

try:
    import docx  # type: ignore
except Exception:
    docx = None

try:
    from pypdf import PdfReader  # type: ignore
except Exception:
    PdfReader = None

ROOT = Path(__file__).resolve().parent
VECTOR_DIR = Path(os.getenv("PAIE_VECTOR_DIR", str(ROOT / "data" / "chroma")))
EMBED_MODEL = os.getenv("PAIE_EMBED_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
COLLECTION = os.getenv("PAIE_COLLECTION", "paie_kb")

def read_text(path: Path) -> str:
    ext = path.suffix.lower()
    if ext in {".txt", ".md"}:
        return path.read_text(encoding="utf-8", errors="ignore")
    if ext == ".docx" and docx:
        d = docx.Document(str(path))
        return "\n".join(p.text for p in d.paragraphs)
    if ext == ".pdf" and PdfReader:
        text = []
        try:
            pdf = PdfReader(str(path))
            for page in pdf.pages:
                text.append(page.extract_text() or "")
        except Exception:
            pass
        return "\n".join(text)
    return ""

def chunk(text: str, max_len: int = 800, overlap: int = 100) -> List[str]:
    text = re.sub(r"\r\n?", "\n", text)
    parts: List[str] = []
    i = 0
    while i < len(text):
        parts.append(text[i:i+max_len])
        i += max_len - overlap
    return [p.strip() for p in parts if p.strip()]

def main(folder: str, vector_dir: str | None = None):
    vdir = Path(vector_dir or VECTOR_DIR)
    vdir.mkdir(parents=True, exist_ok=True)

    client = chromadb.PersistentClient(path=str(vdir))
    ef = embedding_functions.SentenceTransformerEmbeddingFunction(model_name=EMBED_MODEL)
    col = client.get_or_create_collection(COLLECTION, embedding_function=ef)

    kb = Path(folder)
    assert kb.exists(), f"KB folder not found: {kb}"

    docs, metas, ids = [], [], []
    for p in kb.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix.lower() not in {".txt", ".md", ".docx", ".pdf"}:
            continue
        raw = read_text(p)
        if not raw:
            continue
        for idx, ch in enumerate(chunk(raw)):
            docs.append(ch)
            metas.append({"source": str(p), "part": idx})
            ids.append(f"{p.stem}_{idx}_{abs(hash(str(p)+str(idx)))%10**8}")

    if not docs:
        print("No documents found to ingest."); return

    col.add(documents=docs, metadatas=metas, ids=ids)
    print(f"Ingested {len(docs)} chunks from {folder} into {vdir} (collection={COLLECTION}).")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("folder", help="Path to your KB folder (e.g., ./kb)")
    ap.add_argument("--vector-dir", default=None, help="Persist dir for Chroma (default: ./data/chroma)")
    a = ap.parse_args()
    main(a.folder, a.vector_dir)
