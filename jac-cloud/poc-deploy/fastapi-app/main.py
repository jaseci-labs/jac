"""File covering example fastapi implementation."""

from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def read_root() -> dict:
    """Get root."""
    return {"Hello": "World", "message": "FastAPI is running on Elastic Beanstalk!"}


@app.get("/health")
def health_check() -> dict:
    """Health check."""
    return {"status": "healthy"}
