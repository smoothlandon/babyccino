"""
Flowchart generation endpoint
"""

import logging
from fastapi import APIRouter, Depends, HTTPException

from babyccino_server.models.flowchart import (
    GenerateFlowchartRequest,
    GenerateFlowchartResponse,
)
from babyccino_server.services.flowchart_generator import FlowchartGenerator
from babyccino_server.services.llm_client import LLMClient, get_llm_client

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/generate-flowchart", response_model=GenerateFlowchartResponse)
async def generate_flowchart(
    request: GenerateFlowchartRequest,
    llm_client: LLMClient = Depends(get_llm_client),
) -> GenerateFlowchartResponse:
    """
    Generate a flowchart for complex function logic.

    This endpoint is used for complex flowcharts that require:
    - Multiple decision points
    - Loops or recursion
    - Complex control flow

    Simple linear functions are handled client-side with deterministic generation.
    """
    try:
        logger.info(f"Flowchart generation request for: {request.requirements.name}")

        generator = FlowchartGenerator(llm_client)
        flowchart = await generator.generate_flowchart(request.requirements)

        return GenerateFlowchartResponse(flowchart=flowchart)

    except Exception as e:
        logger.error(f"Flowchart generation failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=500, detail=f"Flowchart generation failed: {str(e)}"
        )
