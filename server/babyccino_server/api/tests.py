"""Test case generation endpoint — proposes test cases for user approval."""

import logging

from fastapi import APIRouter, Depends, HTTPException

from ..models.requests import GenerateTestsRequest
from ..models.responses import GenerateTestsResponse
from ..services.llm_client import LLMClient
from ..services.test_proposer import TestProposer

logger = logging.getLogger(__name__)

router = APIRouter()


async def get_llm_client() -> LLMClient:
    """Dependency injection for LLM client."""
    raise NotImplementedError("LLM client dependency not configured")


@router.post("/generate-tests", response_model=GenerateTestsResponse)
async def generate_tests(
    request: GenerateTestsRequest,
    llm_client: LLMClient = Depends(get_llm_client),
):
    """Generate proposed test cases for user review and approval.

    The user reviews these before code is generated, ensuring the
    implementation contract is correct before any code is written.

    Args:
        request: Function requirements to propose tests for
        llm_client: Injected LLM client

    Returns:
        Proposed test cases for the user to approve/edit/reject

    Raises:
        HTTPException: If test generation fails
    """
    req = request.requirements
    logger.info(f"━━━ /generate-tests ━━━")
    logger.info(f"  function: {req.name}")
    logger.info(f"  purpose: {req.purpose}")
    logger.info(f"  return_type: {req.return_type}")
    logger.info(f"  parameters: {[(p.name, p.type) for p in req.parameters]}")
    logger.info(f"  edge_cases ({len(req.edge_cases)}): {req.edge_cases}")
    logger.info(f"  transcript: {len(req.conversation_transcript or '')} chars")
    if req.conversation_transcript:
        logger.info(f"  transcript preview:\n{req.conversation_transcript[:500]}")

    try:
        proposer = TestProposer(llm_client)
        proposed_tests = await proposer.propose_tests(req)

        logger.info(f"  → proposed {len(proposed_tests)} test cases:")
        for t in proposed_tests:
            logger.info(f"    [{t.id[:8]}] {t.description}: {req.name}({t.input}) == {t.expected_output} edge={t.is_edge_case}")

        return GenerateTestsResponse(
            function_name=req.name,
            proposed_tests=proposed_tests,
        )

    except Exception as e:
        logger.error(f"Test generation failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Test generation failed: {str(e)}",
        )
