"""Abstract LLM client interface for model-agnostic code generation."""

from abc import ABC, abstractmethod
from typing import Any


class LLMClient(ABC):
    """Abstract base class for LLM clients.

    This allows easy swapping between Ollama, Anthropic, OpenAI, etc.
    """

    @abstractmethod
    async def generate_completion(
        self,
        prompt: str,
        system_prompt: str | None = None,
        temperature: float = 0.7,
        max_tokens: int = 4000,
    ) -> str:
        """Generate a completion from the LLM.

        Args:
            prompt: The user prompt/question
            system_prompt: Optional system prompt to set context
            temperature: Sampling temperature (0.0-1.0)
            max_tokens: Maximum tokens to generate

        Returns:
            Generated text response
        """
        pass

    @abstractmethod
    async def health_check(self) -> dict[str, Any]:
        """Check if the LLM service is available and responding.

        Returns:
            Dictionary with health status information
        """
        pass

    @abstractmethod
    def get_model_name(self) -> str:
        """Get the name of the model being used.

        Returns:
            Model name/identifier
        """
        pass


# Dependency injection stub - will be overridden in main.py
async def get_llm_client() -> LLMClient:
    """Dependency injection for LLM client.

    This is overridden in main.py with the actual implementation.
    """
    raise NotImplementedError("LLM client dependency not configured")
