"""OpenAI-compatible LLM settings. P0 points at DeepSeek."""

from pydantic import Field, SecretStr

from app.core.config.base import EnvBaseSettings


class LLMSettings(EnvBaseSettings):
    """Chat Completions gateway. Swap provider by changing these three."""

    LLM_BASE_URL: str = Field(
        default="https://api.deepseek.com",
        description="OpenAI-compatible base URL",
    )
    LLM_API_KEY: SecretStr = Field(
        default=SecretStr(""),
        repr=False,
        description="Bearer token for the gateway. Empty disables the coach.",
    )
    LLM_MODEL: str = Field(
        default="deepseek-flash",
        description="Chat Completions model id",
    )
    LLM_MAX_TOOL_ROUNDS: int = Field(default=8, ge=1, le=16)
    LLM_THINKING: bool = Field(
        default=True,
        description="Ask the gateway for reasoning text when it supports it",
    )
