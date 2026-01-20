"""Code generation endpoint."""

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException

from ..models.requests import GenerateCodeRequest
from ..models.responses import GenerateCodeResponse
from ..services.code_generator import CodeGenerator
from ..services.llm_client import LLMClient

logger = logging.getLogger(__name__)

router = APIRouter()


async def get_llm_client() -> LLMClient:
    """Dependency injection for LLM client.

    This will be overridden in main.py with actual implementation.
    """
    raise NotImplementedError("LLM client dependency not configured")


@router.post("/generate-code", response_model=GenerateCodeResponse)
async def generate_code(
    request: GenerateCodeRequest,
    llm_client: LLMClient = Depends(get_llm_client),
):
    """Generate Python function code with tests and complexity analysis.

    Supports both single and multi-function generation.
    Request contains a list of function requirements.

    Args:
        request: Code generation request with structured requirements (list)
        llm_client: Injected LLM client

    Returns:
        Generated code, tests, and complexity analysis for each function

    Raises:
        HTTPException: If code generation fails
    """
    # Generate or use existing conversation ID
    conversation_id = request.conversation_id or str(uuid.uuid4())

    num_functions = len(request.requirements)
    logger.info(
        f"Generating {num_functions} function(s) for conversation {conversation_id}"
    )

    try:
        # Create code generator
        generator = CodeGenerator(llm_client)

        # Generate all functions with tests and analysis
        results = await generator.generate_functions(request.requirements)

        return GenerateCodeResponse(
            conversation_id=conversation_id,
            results=results,
        )

    except Exception as e:
        logger.error(f"Code generation failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Code generation failed: {str(e)}",
        )
