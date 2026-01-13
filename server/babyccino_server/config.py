"""Configuration management using pydantic-settings."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Server configuration
    host: str = "0.0.0.0"
    port: int = 8000

    # Ollama configuration
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "deepseek-coder:33b"

    # LLM provider selection (for future use)
    llm_provider: str = "ollama"

    # Optional API keys for future providers
    anthropic_api_key: str | None = None
    openai_api_key: str | None = None

    # Logging
    log_level: str = "INFO"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


# Global settings instance
settings = Settings()
