# Afrotek Auth Service (starter)

This is a minimal FastAPI service skeleton used by the Afrotek monorepo for authentication-related endpoints.

Quick start (Windows / PowerShell):

```powershell
cd services\auth
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```

Quick start (Linux / macOS):

```bash
cd services/auth
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```

Health endpoint: GET /health
# touch
# touch
