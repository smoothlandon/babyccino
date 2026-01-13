"""Request models for API endpoints."""

from pydantic import BaseModel, Field


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


class GenerateCodeRequest(BaseModel):
    """Request to generate code from structured requirements."""

    conversation_id: str | None = Field(
        None, description="UUID for tracking conversation (null for new)"
    )
    requirements: FunctionRequirements = Field(..., description="Structured function requirements")
