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
    """Generated code with tests and analysis."""

    function: str = Field(..., description="Generated Python function code")
    tests: TestResult = Field(..., description="Test results")
    complexity: ComplexityResult = Field(..., description="Complexity analysis")


class GenerateCodeResponse(BaseModel):
    """Response from code generation endpoint."""

    conversation_id: str = Field(..., description="Conversation UUID")
    code: CodeResult = Field(..., description="Generated code, tests, and analysis")
