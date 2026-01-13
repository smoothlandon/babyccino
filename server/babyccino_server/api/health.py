"""Health check endpoint."""

import logging

from fastapi import APIRouter, Depends

from ..models.responses import HealthResponse
from ..services.llm_client import LLMClient

logger = logging.getLogger(__name__)

router = APIRouter()


async def get_llm_client() -> LLMClient:
    """Dependency injection for LLM client.

    This will be overridden in main.py with actual implementation.
    """
    raise NotImplementedError("LLM client dependency not configured")


@router.get("/health", response_model=HealthResponse)
async def health_check(llm_client: LLMClient = Depends(get_llm_client)):
    """Health check endpoint to verify server and LLM are operational.

    Args:
        llm_client: Injected LLM client

    Returns:
        Health status information
    """
    from .. import __version__

    # Check LLM health
    llm_health = await llm_client.health_check()

    return HealthResponse(
        status=llm_health.get("status", "unknown"),
        version=__version__,
        llm_provider="ollama",  # TODO: Make this dynamic based on config
        model=llm_client.get_model_name(),
        model_available=llm_health.get("model_available", False),
    )
