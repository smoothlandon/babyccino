"""Test proposer service — generates proposed test cases for user approval."""

import json
import logging
import uuid

from ..models.requests import FunctionRequirements
from ..models.responses import ProposedTestCase
from .llm_client import LLMClient

logger = logging.getLogger(__name__)


class TestProposer:
    """Generates human-readable proposed test cases from function requirements."""

    def __init__(self, llm_client: LLMClient):
        self.llm_client = llm_client

    async def propose_tests(self, requirements: FunctionRequirements) -> list[ProposedTestCase]:
        """Generate proposed test cases grounded in the conversation transcript.

        Args:
            requirements: Function requirements including conversation transcript

        Returns:
            List of proposed test cases for user approval
        """
        logger.info(f"Proposing tests for: {requirements.name}")

        system_prompt = """You are a test case designer. Given a function specification and conversation transcript, generate concrete test cases as JSON.

Output ONLY a JSON array. No explanation, no markdown. Each element must have:
{
  "description": "plain English description of what this tests",
  "input": "the argument value(s) as Python literal(s)",
  "expected_output": "the return value as a Python literal",
  "is_edge_case": true or false
}

Rules:
- Base test cases STRICTLY on the rules the user stated in the conversation transcript
- Cover: normal cases that return true, normal cases that return false, and boundary/edge cases
- 4-7 test cases total
- inputs and expected_outputs must be valid Python literals (e.g. "\"Alice\"", "True", "42")
- Do not invent rules that weren't stated"""

        transcript_section = ""
        if requirements.conversation_transcript:
            transcript_section = f"\n\nConversation Transcript (the user's exact rules):\n{requirements.conversation_transcript}"

        params_desc = ", ".join(
            [f"{p.name}: {p.type}" for p in requirements.parameters]
        )
        edge_cases_desc = "\n".join([f"- {c}" for c in requirements.edge_cases])

        prompt = f"""Function: {requirements.name}({params_desc}) -> {requirements.return_type}
Purpose: {requirements.purpose}

User-defined rules (edge cases):
{edge_cases_desc if edge_cases_desc else "See transcript"}{transcript_section}

Generate test cases as a JSON array."""

        logger.info(f"TestProposer prompt:\n{prompt}")

        response = await self.llm_client.generate_completion(
            prompt=prompt,
            system_prompt=system_prompt,
            temperature=0.2,
            max_tokens=1500,
        )

        logger.info(f"TestProposer raw LLM response:\n{response}")

        return self._parse_proposed_tests(response, requirements.name)

    def _parse_proposed_tests(
        self, raw_response: str, function_name: str
    ) -> list[ProposedTestCase]:
        """Parse LLM JSON response into ProposedTestCase objects."""
        # Strip markdown fences if present
        cleaned = raw_response.strip()
        if cleaned.startswith("```"):
            lines = cleaned.split("\n")
            cleaned = "\n".join(lines[1:-1] if lines[-1].strip() == "```" else lines[1:])

        # Find JSON array
        start = cleaned.find("[")
        end = cleaned.rfind("]")
        if start == -1 or end == -1:
            logger.warning(f"No JSON array found in response: {cleaned[:200]}")
            return self._fallback_tests(function_name)

        try:
            data = json.loads(cleaned[start : end + 1])
        except json.JSONDecodeError as e:
            logger.warning(f"Failed to parse test cases JSON: {e}")
            return self._fallback_tests(function_name)

        tests = []
        for item in data:
            try:
                tests.append(
                    ProposedTestCase(
                        id=str(uuid.uuid4()),
                        description=item.get("description", "Test case"),
                        input=str(item.get("input", "")),
                        expected_output=str(item.get("expected_output", "")),
                        is_edge_case=bool(item.get("is_edge_case", False)),
                    )
                )
            except Exception as e:
                logger.warning(f"Skipping malformed test case: {e}")

        if not tests:
            return self._fallback_tests(function_name)

        logger.info(f"Proposed {len(tests)} test cases for {function_name}")
        return tests

    def _fallback_tests(self, function_name: str) -> list[ProposedTestCase]:
        """Minimal fallback if LLM fails to produce valid test cases."""
        return [
            ProposedTestCase(
                id=str(uuid.uuid4()),
                description="Basic test — replace with actual test cases",
                input="\"example\"",
                expected_output="True",
                is_edge_case=False,
            )
        ]
