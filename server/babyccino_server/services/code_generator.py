"""Code generation service orchestrating LLM, testing, and analysis."""

import logging
import uuid

from ..models.requests import ApprovedTestCase, FunctionRequirements
from ..models.responses import CodeResult, TestResult
from .complexity_analyzer import ComplexityAnalyzer
from .llm_client import LLMClient
from .test_runner import TestRunner

logger = logging.getLogger(__name__)


class CodeGenerator:
    """Orchestrates code generation, testing, and analysis."""

    def __init__(self, llm_client: LLMClient):
        """Initialize code generator.

        Args:
            llm_client: LLM client for code generation
        """
        self.llm_client = llm_client
        self.test_runner = TestRunner()
        self.complexity_analyzer = ComplexityAnalyzer(llm_client)

    async def generate_functions(
        self,
        requirements_list: list[FunctionRequirements],
        approved_tests: list[ApprovedTestCase] | None = None,
    ) -> list[CodeResult]:
        """Generate multiple functions with tests and analysis.

        Args:
            requirements_list: List of function requirements
            approved_tests: Optional user-approved test cases to target

        Returns:
            List of code results, one per function
        """
        logger.info(f"Generating {len(requirements_list)} function(s)")

        results = []
        for requirements in requirements_list:
            # For multi-function requests, approved tests apply to the first function
            tests_for_this = approved_tests if requirements == requirements_list[0] else None
            result = await self.generate_function(requirements, approved_tests=tests_for_this)
            results.append(result)

        return results

    async def generate_function(
        self,
        requirements: FunctionRequirements,
        approved_tests: list[ApprovedTestCase] | None = None,
    ) -> CodeResult:
        """Generate complete function with tests and analysis.

        Args:
            requirements: Structured function requirements

        Returns:
            Complete code result with function, tests, and complexity
        """
        logger.info(f"Generating function: {requirements.name}")
        if approved_tests:
            logger.info(f"Using {len(approved_tests)} user-approved test cases")

        # Generate function code — pass approved tests so it can target them
        function_code = await self._generate_function_code(requirements, approved_tests)

        # Build test code from approved tests if provided, otherwise generate fresh
        if approved_tests:
            test_code = self._build_test_code_from_approved(requirements, approved_tests)
        else:
            test_code = await self._generate_tests(requirements, function_code)

        # Run tests
        test_results, test_summary = await self.test_runner.run_tests(function_code, test_code)

        # Analyze complexity
        complexity = await self.complexity_analyzer.analyze(function_code)

        return CodeResult(
            function_name=requirements.name,
            function=function_code,
            tests=TestResult(
                code=test_code,
                results=test_results,
                summary=test_summary,
            ),
            complexity=complexity,
        )

    def _build_test_code_from_approved(
        self,
        requirements: FunctionRequirements,
        approved_tests: list[ApprovedTestCase],
    ) -> str:
        """Convert user-approved test cases into runnable pytest code.

        Args:
            requirements: Function requirements (for function name)
            approved_tests: User-approved test cases

        Returns:
            Pytest test code as a string
        """
        fn = requirements.name
        lines = [f"from function import {fn}", ""]

        for test in approved_tests:
            # Sanitize description into a valid Python identifier
            safe_desc = (
                test.description.lower()
                .replace(" ", "_")
                .replace("'", "")
                .replace('"', "")
                .replace("-", "_")
                .replace("/", "_")
            )
            safe_desc = "".join(c for c in safe_desc if c.isalnum() or c == "_")
            safe_desc = safe_desc[:60]  # Keep it reasonable length

            lines.append(f"def test_{safe_desc}():")
            lines.append(f'    """{ test.description }"""')
            lines.append(f"    assert {fn}({test.input}) == {test.expected_output}")
            lines.append("")

        return "\n".join(lines)

    async def _generate_function_code(
        self,
        requirements: FunctionRequirements,
        approved_tests: list[ApprovedTestCase] | None = None,
    ) -> str:
        """Generate the function code from requirements.

        Args:
            requirements: Function requirements
            approved_tests: Optional user-approved test cases to target

        Returns:
            Generated Python function code
        """
        system_prompt = """You are an expert Python developer who writes clean, well-documented code.
Follow PEP 8 style guidelines and use type hints appropriately."""

        # Build parameters description
        params_desc = "\n".join(
            [f"  - {p.name} ({p.type}): {p.description}" for p in requirements.parameters]
        )

        # Build edge cases description
        edge_cases_desc = "\n".join([f"  - {case}" for case in requirements.edge_cases])

        # Build examples description
        examples_desc = "\n".join(
            [f"  - Input: {ex.input} → Output: {ex.output}" for ex in requirements.examples]
        )

        # Include conversation transcript if available - it contains user-defined rules
        # that must be implemented exactly as specified
        transcript_section = ""
        if requirements.conversation_transcript:
            transcript_section = f"""

Conversation Transcript (contains the exact rules and criteria defined by the user - implement these precisely):
{requirements.conversation_transcript}"""

        # Build approved test cases section — highest priority signal for implementation
        approved_tests_section = ""
        if approved_tests:
            test_lines = "\n".join(
                [f"  - {t.description}: {requirements.name}({t.input}) == {t.expected_output}"
                 for t in approved_tests]
            )
            approved_tests_section = f"""

User-Approved Test Cases (your implementation MUST pass ALL of these exactly):
{test_lines}"""

        prompt = f"""Generate a Python function with these requirements:

Function Name: {requirements.name}
Purpose: {requirements.purpose}
Return Type: {requirements.return_type}

Parameters:
{params_desc if params_desc else "  - No parameters"}

Edge Cases to Handle:
{edge_cases_desc if edge_cases_desc else "  - None specified"}

Examples:
{examples_desc if examples_desc else "  - None provided"}{approved_tests_section}{transcript_section}

Requirements:
- If user-approved test cases are provided above, your implementation MUST pass ALL of them — they define the exact expected behaviour
- If a conversation transcript is provided, implement the EXACT rules the user described - do not invent your own logic
- Include a comprehensive docstring with Args and Returns sections
- Use type hints for parameters and return type
- Handle all specified edge cases
- Write clean, readable code following PEP 8
- Do not include any import statements unless absolutely necessary

Output only the Python function code, no markdown formatting or explanations."""

        response = await self.llm_client.generate_completion(
            prompt=prompt,
            system_prompt=system_prompt,
            temperature=0.5,
            max_tokens=2000,
        )

        # Clean up response (remove markdown if present)
        code = response.strip()
        if code.startswith("```python"):
            code = code[9:]
        elif code.startswith("```"):
            code = code[3:]
        if code.endswith("```"):
            code = code[:-3]

        return code.strip()

    async def _generate_tests(
        self, requirements: FunctionRequirements, function_code: str
    ) -> str:
        """Generate pytest tests for the function.

        Args:
            requirements: Function requirements
            function_code: The generated function code

        Returns:
            Generated pytest test code
        """
        system_prompt = """You are an expert at writing comprehensive pytest unit tests.
Write clear, thorough tests that cover edge cases and validate behavior."""

        # Build examples for test generation
        examples_desc = "\n".join(
            [f"  - assert {requirements.name}({ex.input}) == {ex.output}" for ex in requirements.examples]
        )

        prompt = f"""Generate pytest unit tests for this function:

```python
{function_code}
```

Requirements Context:
- Purpose: {requirements.purpose}
- Edge cases to test: {', '.join(requirements.edge_cases) if requirements.edge_cases else 'None specified'}
- Examples: {examples_desc if examples_desc else 'None provided'}

Requirements:
- Import the function from 'function' module
- Write multiple test functions (test_normal_cases, test_edge_cases, etc.)
- Use clear test names that describe what is being tested
- Include assertions for all examples and edge cases
- Cover both positive and negative test cases

Output only the Python test code, no markdown formatting or explanations."""

        response = await self.llm_client.generate_completion(
            prompt=prompt,
            system_prompt=system_prompt,
            temperature=0.5,
            max_tokens=2000,
        )

        # Clean up response
        code = response.strip()
        if code.startswith("```python"):
            code = code[9:]
        elif code.startswith("```"):
            code = code[3:]
        if code.endswith("```"):
            code = code[:-3]

        return code.strip()
