"""Complexity analysis service using LLM."""

import json
import logging

from ..models.responses import ComplexityResult
from .llm_client import LLMClient

logger = logging.getLogger(__name__)


class ComplexityAnalyzer:
    """Analyzes time and space complexity of code using LLM."""

    def __init__(self, llm_client: LLMClient):
        """Initialize complexity analyzer.

        Args:
            llm_client: LLM client for analysis
        """
        self.llm_client = llm_client

    async def analyze(self, function_code: str) -> ComplexityResult:
        """Analyze complexity of a function.

        Args:
            function_code: The function code to analyze

        Returns:
            Complexity analysis result
        """
        system_prompt = """You are a computer science expert specializing in algorithm analysis.
Analyze the time and space complexity of functions accurately and concisely."""

        prompt = f"""Analyze the time and space complexity of this Python function:

```python
{function_code}
```

Provide your analysis in JSON format with these exact keys:
- "time": Time complexity in Big-O notation (e.g., "O(n)", "O(n log n)", "O(1)")
- "space": Space complexity in Big-O notation
- "explanation": Brief 2-3 sentence explanation of both complexities

Output only valid JSON, no markdown formatting."""

        try:
            response = await self.llm_client.generate_completion(
                prompt=prompt,
                system_prompt=system_prompt,
                temperature=0.3,  # Lower temperature for more consistent output
                max_tokens=500,
            )

            # Clean up response (remove markdown if present)
            response = response.strip()
            if response.startswith("```json"):
                response = response[7:]
            if response.startswith("```"):
                response = response[3:]
            if response.endswith("```"):
                response = response[:-3]
            response = response.strip()

            # Parse JSON
            data = json.loads(response)

            return ComplexityResult(
                time=data["time"],
                space=data["space"],
                explanation=data["explanation"],
            )

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse complexity JSON: {e}\nResponse: {response}")
            return ComplexityResult(
                time="O(?)",
                space="O(?)",
                explanation="Failed to analyze complexity - invalid response format.",
            )
        except Exception as e:
            logger.error(f"Error analyzing complexity: {e}")
            return ComplexityResult(
                time="O(?)",
                space="O(?)",
                explanation=f"Failed to analyze complexity: {e}",
            )
