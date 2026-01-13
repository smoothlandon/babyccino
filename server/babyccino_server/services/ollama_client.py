"""Ollama LLM client implementation."""

import logging
from typing import Any

import ollama
from ollama import AsyncClient

from .llm_client import LLMClient

logger = logging.getLogger(__name__)


class OllamaClient(LLMClient):
    """Ollama client for local LLM inference."""

    def __init__(self, base_url: str = "http://localhost:11434", model: str = "deepseek-coder:33b"):
        """Initialize Ollama client.

        Args:
            base_url: Ollama server URL
            model: Model name to use
        """
        self.base_url = base_url
        self.model = model
        self.client = AsyncClient(host=base_url)
        logger.info(f"Initialized Ollama client with model: {model}")

    async def generate_completion(
        self,
        prompt: str,
        system_prompt: str | None = None,
        temperature: float = 0.7,
        max_tokens: int = 4000,
    ) -> str:
        """Generate a completion using Ollama.

        Args:
            prompt: The user prompt
            system_prompt: Optional system prompt
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate

        Returns:
            Generated text response
        """
        messages = []

        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})

        messages.append({"role": "user", "content": prompt})

        try:
            logger.debug(f"Generating completion with {self.model}")
            response = await self.client.chat(
                model=self.model,
                messages=messages,
                options={
                    "temperature": temperature,
                    "num_predict": max_tokens,
                },
            )

            content = response["message"]["content"]
            logger.debug(f"Generated {len(content)} characters")
            return content

        except Exception as e:
            logger.error(f"Error generating completion: {e}")
            raise RuntimeError(f"Failed to generate completion: {e}")

    async def health_check(self) -> dict[str, Any]:
        """Check if Ollama is running and the model is available.

        Returns:
            Health status dictionary
        """
        try:
            # List available models to verify connection
            response = await self.client.list()

            # Extract model names - handle different response structures
            models_list = response.get("models", [])
            model_names = []

            for model in models_list:
                # The Ollama client returns Model objects with a 'model' attribute
                if hasattr(model, 'model'):
                    # It's a Model object with attributes
                    model_names.append(model.model)
                elif isinstance(model, dict):
                    # Fallback: dict with 'name' or 'model' key
                    name = model.get("name") or model.get("model")
                    if name:
                        model_names.append(name)
                else:
                    # Last resort: convert to string
                    model_names.append(str(model))

            logger.info(f"Available models: {model_names}")
            logger.info(f"Looking for model: {self.model}")

            is_available = self.model in model_names

            return {
                "status": "ok" if is_available else "model_not_found",
                "base_url": self.base_url,
                "model": self.model,
                "available_models": model_names,
                "model_available": is_available,
            }
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return {
                "status": "error",
                "base_url": self.base_url,
                "model": self.model,
                "error": str(e),
            }

    def get_model_name(self) -> str:
        """Get the model name.

        Returns:
            Model name
        """
        return self.model
