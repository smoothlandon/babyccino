"""
Flowchart data models for visualization
"""

from enum import Enum
from pydantic import BaseModel, Field


class FlowchartNodeType(str, Enum):
    """Types of flowchart nodes"""
    START = "start"
    END = "end"
    PROCESS = "process"
    DECISION = "decision"
    INPUT = "input"
    OUTPUT = "output"
    FUNCTION = "function"


class FlowchartNode(BaseModel):
    """A node in the flowchart"""
    id: str = Field(..., description="Unique node identifier")
    type: FlowchartNodeType = Field(..., description="Node type")
    label: str = Field(..., description="Display label")
    x: float = Field(..., description="X coordinate for positioning")
    y: float = Field(..., description="Y coordinate for positioning")
    function_name: str | None = Field(None, description="Function name if type is FUNCTION")
    description: str | None = Field(None, description="Optional description")


class FlowchartEdge(BaseModel):
    """An edge connecting two nodes"""
    id: str = Field(..., description="Unique edge identifier")
    from_node: str = Field(..., alias="from", description="Source node ID")
    to_node: str = Field(..., alias="to", description="Target node ID")
    label: str | None = Field(None, description="Edge label (e.g., 'Yes', 'No')")

    class Config:
        populate_by_name = True


class Flowchart(BaseModel):
    """Complete flowchart representation"""
    nodes: list[FlowchartNode] = Field(..., min_length=1, description="List of nodes")
    edges: list[FlowchartEdge] = Field(..., description="List of edges")
    title: str | None = Field(None, description="Flowchart title")
    description: str | None = Field(None, description="Flowchart description")


class GenerateFlowchartRequest(BaseModel):
    """Request to generate a flowchart"""
    requirements: "FunctionRequirements" = Field(..., description="Function requirements")


class GenerateFlowchartResponse(BaseModel):
    """Response with generated flowchart"""
    flowchart: Flowchart = Field(..., description="Generated flowchart")


# Avoid circular import
from babyccino_server.models.requests import FunctionRequirements
GenerateFlowchartRequest.model_rebuild()
