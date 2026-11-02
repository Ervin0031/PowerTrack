"""OpenAI Chat Completions client. P0 base URL is DeepSeek."""

from dataclasses import dataclass

from openai import AsyncOpenAI

from app.core.config import settings


class CoachNotConfiguredError(RuntimeError):
    """LLM_API_KEY is empty."""


@dataclass
class ToolCall:
    id: str
    name: str
    arguments: str


@dataclass
class AssistantTurn:
    content: str | None
    tool_calls: list[ToolCall]
    reasoning: str | None = None


class OpenAICompatClient:
    """chat.completions + tools. Provider is only base_url, key, and model."""

    def __init__(self) -> None:
        key = settings.llm.LLM_API_KEY.get_secret_value()
        if not key:
            raise CoachNotConfiguredError("LLM_API_KEY is empty")
        self._client = AsyncOpenAI(
            api_key=key,
            base_url=settings.llm.LLM_BASE_URL,
        )
        self._model = settings.llm.LLM_MODEL

    async def complete(
        self,
        messages: list[dict],
        tools: list[dict],
        thinking: bool | None = None,
    ) -> AssistantTurn:
        kwargs: dict = {
            "model": self._model,
            "messages": messages,
            "tools": tools,
            "temperature": 0.3,
        }
        use_thinking = settings.llm.LLM_THINKING if thinking is None else thinking
        if use_thinking:
            kwargs["extra_body"] = {"thinking": {"type": "enabled"}}
        try:
            response = await self._client.chat.completions.create(**kwargs)
        except Exception:
            if "extra_body" not in kwargs:
                raise
            kwargs.pop("extra_body")
            response = await self._client.chat.completions.create(**kwargs)
        message = response.choices[0].message
        calls = [
            ToolCall(
                id=call.id,
                name=call.function.name,
                arguments=call.function.arguments or "{}",
            )
            for call in (message.tool_calls or [])
        ]
        dumped = message.model_dump()
        reasoning = dumped.get("reasoning_content")
        if not reasoning:
            extra = dumped.get("model_extra") or {}
            reasoning = extra.get("reasoning_content")
        if isinstance(reasoning, str):
            reasoning = reasoning.strip() or None
        else:
            reasoning = None
        return AssistantTurn(
            content=message.content,
            tool_calls=calls,
            reasoning=reasoning,
        )
