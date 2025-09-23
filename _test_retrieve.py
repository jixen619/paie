import os
from rag import retrieve, VECTOR_DIR
print("APP_DIR        =", os.getenv("PAIE_APP_DIR"))
print("VECTOR_DIR env =", os.getenv("PAIE_VECTOR_DIR"))
print("rag.VECTOR_DIR =", VECTOR_DIR)
hits = retrieve("what's the secret color?", k=3)
print("hits =", len(hits))
for i,(t,m) in enumerate(hits,1):
    print(i, (m or {}).get("source",""), "…", (t or "")[:80].replace("\\n"," "))
