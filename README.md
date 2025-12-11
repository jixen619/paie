PAIE — Personalized AI Engine

Offline, privacy-first assistant using local LLMs (Ollama), Streamlit UI, RAG, and an SQLite audit trail.

Overview:

PAIE (Personalized AI Engine) is a fully offline, privacy-preserving AI assistant designed for personal and professional productivity.
It runs local LLMs via Ollama, features a modern Streamlit GUI, includes CLI support, and integrates Retrieval-Augmented Generation (RAG) with a secure SQLite audit trail.

This project demonstrates:

Applied AI/ML deployment
Full-stack Streamlit development
Secure offline inference
Data Analytics & BI integration
Python automation + RAG pipelines

Features:

🔒 100% offline (no cloud API required)
🤖 Local LLMs (Ollama-supported models like Llama 3)
🖥 Streamlit GUI for interactive use
💬 CLI interface for automation
📚 RAG-based knowledge retrieval
🗃 SQLite audit logging for conversations
⚡ Fast, lightweight, and easily customizable

| Component                | Technology            |
| ------------------------ | --------------------- |
| Language                 | Python                |
| Local LLM Runtime        | Ollama                |
| Frontend UI              | Streamlit             |
| RAG / Document Retrieval | Custom pipeline       |
| Database                 | SQLite                |
| Logging                  | JSON + DB audit trail |


<img width="1674" height="850" alt="image" src="https://github.com/user-attachments/assets/5584860d-19aa-4c6a-8bc0-61b599425329" />


<img width="1920" height="1020" alt="Screenshot 2025-09-22 102847" src="https://github.com/user-attachments/assets/eea9659c-c272-466a-b871-2a4dd813fb0e" />

<img width="1197" height="750" alt="Screenshot 2025-09-21 184204" src="https://github.com/user-attachments/assets/3f30c747-10ce-4141-8b73-0f041fb1eeb2" />

<img width="1920" height="1020" alt="Screenshot 2025-09-18 144808" src="https://github.com/user-attachments/assets/0f466d85-4e55-4cbb-a50b-a8d282a50fcf" />

<img width="321" height="358" alt="Screenshot 2025-09-22 204954" src="https://github.com/user-attachments/assets/0d5ce030-bef7-43c0-9f5b-97dda6c1d8a1" />

<img width="869" height="901" alt="image" src="https://github.com/user-attachments/assets/b5c4507e-a53e-41f9-a70e-ac5c11f5d080" />

Run (GUI)
1.Create virtual environment
py -m venv .venv && .\.venv\Scripts\activate

2.Install dependencies
pip install -r requirements.txt

3.Start Streamlit app
streamlit run paie_app/ui/app_streamlit.py

Run (CLI)
python paie_app/ui/cli.py --model "llama3.2:latest" --user "alice"

VS Code launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "PAIE GUI (Streamlit)",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/.venv/Scripts/streamlit.exe",
      "args": ["run", "paie_app/ui/app_streamlit.py"],
      "console": "integratedTerminal"
    },
    {
      "name": "PAIE CLI",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/paie_app/ui/cli.py",
      "args": ["--model", "llama3.2:latest", "--user", "alice"],
      "console": "integratedTerminal"
    }
  ]
}

Project Structure
paie/
│
├── paie_app/
│   ├── ui/
│   │   ├── app_streamlit.py      # GUI
│   │   ├── cli.py                # CLI
│   ├── rag/                      # RAG utilities
│   ├── core/                     # LLM + logic
│
├── data/                         # Knowledge base + embeddings
├── backups/                      # Audit backups
├── deliverables/                 # Reports and exports
│
├── requirements.txt
└── README.md

