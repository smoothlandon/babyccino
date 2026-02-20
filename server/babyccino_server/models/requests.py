"""Request models for API endpoints."""

from pydantic import BaseModel, Field


class ApprovedTestCase(BaseModel):
    """A user-approved test case to use during code generation."""

    id: str = Field(..., description="ID matching the proposed test case")
    description: str = Field(..., description="Human-readable description")
    input: str = Field(..., description="Input value(s) as a string representation")
    expected_output: str = Field(..., description="Expected return value as a string")
    is_edge_case: bool = Field(default=False, description="Whether this is an edge/boundary case")


class FunctionParameter(BaseModel):
    """Parameter definition for a function."""

    name: str = Field(..., description="Parameter name")
    type: str = Field(..., description="Parameter type (e.g., 'int', 'str', 'list[int]')")
    description: str = Field(..., description="What this parameter is used for")


class FunctionExample(BaseModel):
    """Example input/output for a function."""

    input: str = Field(..., description="Example input (as string representation)")
    output: str = Field(..., description="Expected output (as string representation)")


class FunctionRequirements(BaseModel):
    """Structured requirements for a function to generate."""

    name: str = Field(..., description="Function name (snake_case)")
    purpose: str = Field(..., description="Brief description of what the function does")
    parameters: list[FunctionParameter] = Field(
        default_factory=list, description="Function parameters"
    )
    return_type: str = Field(..., description="Return type (e.g., 'bool', 'int', 'list[str]')")
    edge_cases: list[str] = Field(
        default_factory=list, description="Edge cases to handle (e.g., 'n < 2 returns False')"
    )
    examples: list[FunctionExample] = Field(
        default_factory=list, description="Example inputs and outputs"
    )
    conversation_transcript: str | None = Field(
        None,
        description="Full conversation transcript between user and assistant. "
                    "Contains user-defined rules, criteria, and requirements gathered during the conversation. "
                    "MUST be used as the primary source of truth for custom function logic."
    )


class GenerateTestsRequest(BaseModel):
    """Request to generate proposed test cases for user approval."""

    requirements: FunctionRequirements = Field(
        ..., description="Function requirements to generate tests for"
    )


class GenerateCodeRequest(BaseModel):
    """Request to generate code from structured requirements.

    Supports both single function and multi-function generation.
    For single function, provide a single-item list.
    """

    conversation_id: str | None = Field(
        None, description="UUID for tracking conversation (null for new)"
    )
    requirements: list[FunctionRequirements] = Field(
        ...,
        description="List of function requirements (single or multiple functions)",
        min_length=1
    )
    approved_tests: list[ApprovedTestCase] | None = Field(
        None,
        description="User-approved test cases. When provided, code generation targets these "
                    "exact tests instead of generating its own."
    )
