"""Response models for API endpoints."""

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Health check response."""

    status: str = Field(..., description="Health status ('ok', 'error', etc.)")
    version: str = Field(..., description="Server version")
    llm_provider: str = Field(..., description="LLM provider name (e.g., 'ollama')")
    model: str = Field(..., description="Model name being used")
    model_available: bool = Field(..., description="Whether the model is loaded and ready")


class TestCaseResult(BaseModel):
    """Result of a single test case."""

    name: str = Field(..., description="Test function name")
    passed: bool = Field(..., description="Whether test passed")
    output: str = Field(default="", description="Test output or error message")


class TestResult(BaseModel):
    """Test execution results."""

    code: str = Field(..., description="The test code that was executed")
    results: list[TestCaseResult] = Field(..., description="Individual test case results")
    summary: str = Field(..., description="Summary (e.g., '3 passed, 0 failed')")


class ComplexityResult(BaseModel):
    """Complexity analysis result."""

    time: str = Field(..., description="Time complexity in Big-O notation (e.g., 'O(n)')")
    space: str = Field(..., description="Space complexity in Big-O notation (e.g., 'O(1)')")
    explanation: str = Field(..., description="Brief explanation of the complexity")


class CodeResult(BaseModel):
    """Generated code with tests and analysis for a single function."""

    function_name: str = Field(..., description="Name of the generated function")
    function: str = Field(..., description="Generated Python function code")
    tests: TestResult = Field(..., description="Test results")
    complexity: ComplexityResult = Field(..., description="Complexity analysis")


class ProposedTestCase(BaseModel):
    """A single proposed test case for user approval."""

    id: str = Field(..., description="Unique identifier for this test case")
    description: str = Field(..., description="Human-readable description of what this tests")
    input: str = Field(..., description="Input value(s) as a string representation")
    expected_output: str = Field(..., description="Expected return value as a string")
    is_edge_case: bool = Field(default=False, description="Whether this is an edge/boundary case")


class GenerateTestsResponse(BaseModel):
    """Response from test generation endpoint — proposed test cases for user approval."""

    function_name: str = Field(..., description="Name of the function being tested")
    proposed_tests: list[ProposedTestCase] = Field(
        ..., description="Proposed test cases for user to review and approve"
    )


class GenerateCodeResponse(BaseModel):
    """Response from code generation endpoint.

    Supports both single and multi-function generation.
    Results list will have one item for single function, multiple for batch.
    """

    conversation_id: str = Field(..., description="Conversation UUID")
    results: list[CodeResult] = Field(
        ...,
        description="Generated code results (one per function)",
        min_length=1
    )

    # Legacy compatibility: expose first result as 'code' for single-function calls
    @property
    def code(self) -> CodeResult:
        """Legacy accessor for single function generation."""
        return self.results[0]
