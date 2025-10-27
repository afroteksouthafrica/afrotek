from fastapi import FastAPI

app = FastAPI(title="Afrotek Auth Service")

@app.middleware("http")
async def hsts_header(request, call_next):
    resp = await call_next(request)
    # Browsers only honor HSTS over HTTPS; ALB already redirects HTTP->HTTPS
    resp.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
    return resp

@app.get("/health")
def health():
    return {"ok": True}

@app.get("/auth/health")
def health_alias():
    return {"ok": True}

@app.get("/")
def root():
    return {"service": "auth", "status": "running"}
