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

    Args:
        request: Code generation request with structured requirements
        llm_client: Injected LLM client

    Returns:
        Generated code, tests, and complexity analysis

    Raises:
        HTTPException: If code generation fails
    """
    # Generate or use existing conversation ID
    conversation_id = request.conversation_id or str(uuid.uuid4())

    logger.info(f"Generating code for conversation {conversation_id}")

    try:
        # Create code generator
        generator = CodeGenerator(llm_client)

        # Generate function with tests and analysis
        code_result = await generator.generate_function(request.requirements)

        return GenerateCodeResponse(
            conversation_id=conversation_id,
            code=code_result,
        )

    except Exception as e:
        logger.error(f"Code generation failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Code generation failed: {str(e)}",
        )
