"""
Flowchart generation service using LLM
"""

import json
import logging
from babyccino_server.models.requests import FunctionRequirements
from babyccino_server.models.flowchart import (
    Flowchart,
    FlowchartNode,
    FlowchartEdge,
    FlowchartNodeType,
)
from babyccino_server.services.llm_client import LLMClient

logger = logging.getLogger(__name__)


class FlowchartGenerator:
    """Generates flowcharts from function requirements using LLM"""

    def __init__(self, llm_client: LLMClient):
        self.llm_client = llm_client

    async def generate_flowchart(self, requirements: FunctionRequirements) -> Flowchart:
        """
        Generate a flowchart for the given function requirements.

        Uses the LLM to:
        1. Analyze the function logic flow
        2. Identify decision points, loops, and processes
        3. Generate nodes with proper types
        4. Calculate spatial layout coordinates
        5. Create edges with appropriate labels
        """
        logger.info(f"Generating flowchart for function: {requirements.name}")

        # Build the LLM prompt
        prompt = self._build_flowchart_prompt(requirements)

        # Get flowchart from LLM
        response = await self.llm_client.generate_completion(
            prompt=prompt,
            temperature=0.3,  # Lower temperature for more consistent structure
            max_tokens=2000,
        )

        # Parse the JSON response
        try:
            # Try to extract JSON from response (LLM might wrap it in markdown)
            json_text = response.strip()
            if "```json" in json_text:
                # Extract JSON from markdown code block
                start = json_text.find("```json") + 7
                end = json_text.find("```", start)
                json_text = json_text[start:end].strip()
            elif "```" in json_text:
                # Extract from generic code block
                start = json_text.find("```") + 3
                end = json_text.find("```", start)
                json_text = json_text[start:end].strip()

            flowchart_data = json.loads(json_text)
            flowchart = self._parse_flowchart_response(flowchart_data, requirements)
            logger.info(
                f"Generated flowchart with {len(flowchart.nodes)} nodes and {len(flowchart.edges)} edges"
            )
            return flowchart

        except (json.JSONDecodeError, KeyError) as e:
            logger.error(f"Failed to parse flowchart JSON: {e}")
            logger.error(f"LLM response: {response[:500]}...")
            # Fallback to simple flowchart
            return self._create_fallback_flowchart(requirements)

    def _build_flowchart_prompt(self, requirements: FunctionRequirements) -> str:
        """Build the LLM prompt for flowchart generation"""

        # Format parameters
        params_str = ", ".join(
            f"{p.name}: {p.type}" for p in requirements.parameters
        )

        # Format edge cases
        edge_cases_str = "\n".join(f"  - {case}" for case in requirements.edge_cases)

        # Format examples
        examples_str = "\n".join(
            f"  - {ex.input} → {ex.output}" for ex in requirements.examples
        )

        prompt = f"""Generate a flowchart in JSON format for this function:

Function: {requirements.name}({params_str}) -> {requirements.return_type}
Purpose: {requirements.purpose}

Edge Cases:
{edge_cases_str}

Examples:
{examples_str}

IMPORTANT: Return ONLY the JSON object, no markdown, no explanations, no code blocks.

Required JSON format:
{{
  "nodes": [
    {{"id": "node1", "type": "start", "label": "Start", "x": 200, "y": 50}},
    {{"id": "node2", "type": "input", "label": "Input: n", "x": 200, "y": 170}},
    {{"id": "node3", "type": "decision", "label": "n < 0?", "x": 200, "y": 290}},
    {{"id": "node4", "type": "end", "label": "Return None", "x": 50, "y": 410}},
    {{"id": "node5", "type": "decision", "label": "n == 0?", "x": 200, "y": 410}},
    {{"id": "node6", "type": "end", "label": "Return 0", "x": 350, "y": 530}},
    {{"id": "node7", "type": "decision", "label": "n == 1?", "x": 200, "y": 530}},
    {{"id": "node8", "type": "end", "label": "Return 1", "x": 350, "y": 650}},
    {{"id": "node9", "type": "process", "label": "Recursive calls", "x": 200, "y": 650}},
    {{"id": "node10", "type": "end", "label": "Return sum", "x": 200, "y": 770}}
  ],
  "edges": [
    {{"id": "e1", "from": "node1", "to": "node2"}},
    {{"id": "e2", "from": "node2", "to": "node3"}},
    {{"id": "e3", "from": "node3", "to": "node4", "label": "Yes"}},
    {{"id": "e4", "from": "node3", "to": "node5", "label": "No"}},
    {{"id": "e5", "from": "node5", "to": "node6", "label": "Yes"}},
    {{"id": "e6", "from": "node5", "to": "node7", "label": "No"}},
    {{"id": "e7", "from": "node7", "to": "node8", "label": "Yes"}},
    {{"id": "e8", "from": "node7", "to": "node9", "label": "No"}},
    {{"id": "e9", "from": "node9", "to": "node10"}}
  ],
  "title": "{requirements.name}() Algorithm",
  "description": "Flowchart showing the logic flow"
}}

Rules:
- Node types: start, end, process, decision, input, output, function
- Center x=200, space nodes 120px vertically
- Decision "Yes" branch to right (x+150), "No" continues down
- Keep labels under 5 words
- Show all edge cases as decision nodes

JSON only, no other text:"""

        return prompt

    def _parse_flowchart_response(
        self, data: dict, requirements: FunctionRequirements
    ) -> Flowchart:
        """Parse LLM response into Flowchart model"""

        # Parse nodes
        nodes = []
        for node_data in data.get("nodes", []):
            node = FlowchartNode(
                id=node_data["id"],
                type=FlowchartNodeType(node_data["type"]),
                label=node_data["label"],
                x=float(node_data["x"]),
                y=float(node_data["y"]),
                function_name=node_data.get("function_name"),
                description=node_data.get("description"),
            )
            nodes.append(node)

        # Parse edges
        edges = []
        for edge_data in data.get("edges", []):
            edge = FlowchartEdge(
                id=edge_data["id"],
                from_node=edge_data["from"],
                to_node=edge_data["to"],
                label=edge_data.get("label"),
            )
            edges.append(edge)

        return Flowchart(
            nodes=nodes,
            edges=edges,
            title=data.get("title", f"{requirements.name}() Algorithm"),
            description=data.get(
                "description", f"Flowchart for {requirements.purpose}"
            ),
        )

    def _create_fallback_flowchart(
        self, requirements: FunctionRequirements
    ) -> Flowchart:
        """Create a simple fallback flowchart when LLM fails"""
        logger.warning("Using fallback flowchart generation")

        nodes = []
        edges = []
        current_y = 50
        spacing = 120

        # Start
        nodes.append(
            FlowchartNode(
                id="start", type=FlowchartNodeType.START, label="Start", x=200, y=current_y
            )
        )
        last_id = "start"
        current_y += spacing

        # Input
        if requirements.parameters:
            param_names = ", ".join(p.name for p in requirements.parameters)
            nodes.append(
                FlowchartNode(
                    id="input",
                    type=FlowchartNodeType.INPUT,
                    label=f"Input: {param_names}",
                    x=200,
                    y=current_y,
                )
            )
            edges.append(FlowchartEdge(id="e1", from_node=last_id, to_node="input"))
            last_id = "input"
            current_y += spacing

        # Main process
        nodes.append(
            FlowchartNode(
                id="process",
                type=FlowchartNodeType.FUNCTION,
                label=f"{requirements.name}()",
                x=200,
                y=current_y,
                function_name=requirements.name,
            )
        )
        edges.append(
            FlowchartEdge(id=f"e{len(edges)+1}", from_node=last_id, to_node="process")
        )
        last_id = "process"
        current_y += spacing

        # Output
        nodes.append(
            FlowchartNode(
                id="output",
                type=FlowchartNodeType.OUTPUT,
                label=f"Return {requirements.return_type}",
                x=200,
                y=current_y,
            )
        )
        edges.append(
            FlowchartEdge(id=f"e{len(edges)+1}", from_node=last_id, to_node="output")
        )
        last_id = "output"
        current_y += spacing

        # End
        nodes.append(
            FlowchartNode(
                id="end", type=FlowchartNodeType.END, label="End", x=200, y=current_y
            )
        )
        edges.append(
            FlowchartEdge(id=f"e{len(edges)+1}", from_node=last_id, to_node="end")
        )

        return Flowchart(
            nodes=nodes,
            edges=edges,
            title=f"{requirements.name}() Algorithm",
            description=f"Simple flowchart for {requirements.purpose}",
        )
