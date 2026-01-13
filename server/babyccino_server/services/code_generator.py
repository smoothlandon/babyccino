"""Code generation service orchestrating LLM, testing, and analysis."""

import logging
import uuid

from ..models.requests import FunctionRequirements
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

    async def generate_function(self, requirements: FunctionRequirements) -> CodeResult:
        """Generate complete function with tests and analysis.

        Args:
            requirements: Structured function requirements

        Returns:
            Complete code result with function, tests, and complexity
        """
        logger.info(f"Generating function: {requirements.name}")

        # Generate function code
        function_code = await self._generate_function_code(requirements)

        # Generate tests
        test_code = await self._generate_tests(requirements, function_code)

        # Run tests
        test_results, test_summary = await self.test_runner.run_tests(function_code, test_code)

        # Analyze complexity
        complexity = await self.complexity_analyzer.analyze(function_code)

        return CodeResult(
            function=function_code,
            tests=TestResult(
                code=test_code,
                results=test_results,
                summary=test_summary,
            ),
            complexity=complexity,
        )

    async def _generate_function_code(self, requirements: FunctionRequirements) -> str:
        """Generate the function code from requirements.

        Args:
            requirements: Function requirements

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

        prompt = f"""Generate a Python function with these requirements:

Function Name: {requirements.name}
Purpose: {requirements.purpose}
Return Type: {requirements.return_type}

Parameters:
{params_desc if params_desc else "  - No parameters"}

Edge Cases to Handle:
{edge_cases_desc if edge_cases_desc else "  - None specified"}

Examples:
{examples_desc if examples_desc else "  - None provided"}

Requirements:
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
