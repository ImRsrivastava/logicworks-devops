import os
from fastapi import FastAPI

app = FastAPI(title="Logicworks DevOps Demo")

REGION = os.getenv("AWS_REGION", "unknown")
ENV = os.getenv("APP_ENV", "staging")


@app.get("/")
def root():
    return {
        "service": "logicworks-fastapi-app",
        "environment": ENV,
        "region": REGION,
        "status": "ok",
    }


@app.get("/health")
def health():
    return {"status": "healthy", "environment": ENV, "region": REGION}