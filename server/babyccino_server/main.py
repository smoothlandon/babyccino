"""Main FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api import generate, health
from .config import settings
from .services.ollama_client import OllamaClient

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)

# Global LLM client instance
llm_client: OllamaClient | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager for startup/shutdown."""
    global llm_client

    # Startup
    logger.info("Starting Babyccino server...")
    logger.info(f"LLM Provider: {settings.llm_provider}")
    logger.info(f"Model: {settings.ollama_model}")

    # Initialize LLM client based on provider
    if settings.llm_provider == "ollama":
        llm_client = OllamaClient(
            base_url=settings.ollama_base_url,
            model=settings.ollama_model,
        )
        logger.info("Ollama client initialized")
    else:
        raise ValueError(f"Unsupported LLM provider: {settings.llm_provider}")

    # Check LLM health
    health_status = await llm_client.health_check()
    if health_status["status"] != "ok":
        logger.warning(f"LLM health check failed: {health_status}")
        logger.warning("Server will start but code generation may fail")
    else:
        logger.info("LLM health check passed")

    yield

    # Shutdown
    logger.info("Shutting down Babyccino server...")


# Create FastAPI app
app = FastAPI(
    title="Babyccino Server",
    description="Code generation server with local LLM support",
    version="0.1.0",
    lifespan=lifespan,
)

# Configure CORS for local network access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for local network
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Dependency for LLM client injection
async def get_llm_client_dependency():
    """Provide LLM client instance to endpoints."""
    if llm_client is None:
        raise RuntimeError("LLM client not initialized")
    return llm_client


# Include routers
app.include_router(health.router, tags=["health"])
app.include_router(generate.router, tags=["generation"])

# Override dependencies using FastAPI's dependency_overrides
app.dependency_overrides[health.get_llm_client] = get_llm_client_dependency
app.dependency_overrides[generate.get_llm_client] = get_llm_client_dependency


@app.get("/")
async def root():
    """Root endpoint with basic info."""
    return {
        "name": "Babyccino Server",
        "version": "0.1.0",
        "status": "running",
        "docs": "/docs",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "babyccino_server.main:app",
        host=settings.host,
        port=settings.port,
        reload=True,  # Enable auto-reload during development
        log_level=settings.log_level.lower(),
    )
