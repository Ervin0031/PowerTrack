"""Tool loop for one coach turn. The model proposes; it does not write rows."""

import json
from collections.abc import Awaitable, Callable

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.services.coach.llm import AssistantTurn
from app.services.coach.prompts import (
    DEFAULT_USER_PROMPT,
    SYSTEM_PROMPT,
    TOOL_STATUS,
    user_wants_plan,
)
from app.services.coach.tools import TOOLS, ToolContext, parse_arguments


class CoachResult:
    def __init__(
        self,
        text: str,
        proposal: dict | None,
        steps: list[dict] | None = None,
        suggestion: dict | None = None,
    ) -> None:
        self.text = text
        self.proposal = proposal
        self.steps = steps or []
        self.suggestion = suggestion


class LLMClient:
    async def complete(
        self,
        messages: list[dict],
        tools: list[dict],
        thinking: bool | None = None,
    ) -> AssistantTurn:  # pragma: no cover - protocol
        raise NotImplementedError


async def run_coach(
    db: AsyncSession,
    user_id: int,
    history: list[dict],
    user_text: str,
    llm: LLMClient,
    on_step: Callable[[dict], Awaitable[None]] | None = None,
    system_prompt: str = SYSTEM_PROMPT,
    tools: list[dict] | None = None,
    blocked_ids: set[int] | None = None,
    thinking: bool | None = None,
) -> CoachResult:
    """history is prior user/assistant content only."""
    context = ToolContext(db, user_id, blocked_ids=blocked_ids)
    asked = user_text or DEFAULT_USER_PROMPT
    context.allow_plan = user_wants_plan(asked)
    chosen_tools = tools if tools is not None else TOOLS
    messages: list[dict] = [{"role": "system", "content": system_prompt}]
    messages.extend(history)
    messages.append({"role": "user", "content": asked})
    raw_steps: list[dict] = []

    async def emit(
        kind: str,
        title: str,
        detail: str = "",
        state: str = "done",
    ) -> None:
        step = {"kind": kind, "title": title, "detail": detail, "state": state}
        raw_steps.append(step)
        if on_step:
            await on_step(step)

    await emit("thinking", "理解问题", state="running")

    final_text = ""
    understood = False
    for _ in range(settings.llm.LLM_MAX_TOOL_ROUNDS):
        turn = await llm.complete(messages, chosen_tools, thinking=thinking)
        if not understood:
            await emit("thinking", "理解问题", state="done")
            understood = True
        if turn.reasoning:
            await emit("reasoning", "推理", _clip(turn.reasoning))
        if turn.tool_calls:
            messages.append(_assistant_message(turn))
            for call in turn.tool_calls:
                title = TOOL_STATUS.get(call.name, "正在整理")
                await emit("tool", title, state="running")
                arguments = parse_arguments(call.arguments)
                payload = await context.call(call.name, arguments)
                await emit("tool", title, _step_detail(call.name, arguments, payload))
                messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": call.id,
                        "content": json.dumps(payload, ensure_ascii=False),
                    }
                )
            continue
        final_text = (turn.content or "").strip()
        break

    if not final_text and context.proposal:
        final_text = str(context.proposal.get("summary") or "今天的课表好了。")
    if not final_text:
        final_text = "这次没排出课表。可以说想练的部位，或单次大概多久。"
    return CoachResult(
        final_text, context.proposal, _collapse(raw_steps), context.suggestion
    )


def _assistant_message(turn: AssistantTurn) -> dict:
    return {
        "role": "assistant",
        "content": turn.content or "",
        "tool_calls": [
            {
                "id": call.id,
                "type": "function",
                "function": {"name": call.name, "arguments": call.arguments},
            }
            for call in turn.tool_calls
        ],
    }


def _clip(text: str, limit: int = 360) -> str:
    compact = " ".join(text.split())
    if len(compact) <= limit:
        return compact
    return f"{compact[:limit]}…"


def _step_detail(name: str, arguments: dict, payload: dict) -> str:
    if payload.get("error"):
        return str(payload["error"])[:80]
    if name == "get_profile":
        if not payload.get("complete", True) and "goal" not in payload:
            return "档案还没填"
        bits = [
            payload.get("goal"),
            payload.get("experience"),
            payload.get("equipment"),
        ]
        return " · ".join(str(bit) for bit in bits if bit)
    if name == "get_training_block":
        if not payload.get("active"):
            return "还没有周期"
        title = payload.get("title") or "当前周期"
        week = payload.get("current_week")
        marker = "减量周" if payload.get("is_deload") else f"第 {week} 周"
        return f"{title} · {marker}"
    if name == "adjust_block" and payload.get("ok"):
        if payload.get("is_deload"):
            return "已改成减量周"
        return f"第 {payload.get('deload_week')} 周减量"
    if name == "get_training_context":
        zones = payload.get("week_zones") or []
        if not zones:
            return "本周还没有训练量"
        return "、".join(f"{item['name']} {item['zone']}" for item in zones[:3])
    if name == "search_exercises":
        items = payload.get("items") or []
        if not items:
            return f"没有找到「{arguments.get('search', '')}」"
        return "、".join(item["name"] for item in items[:3])
    if name == "get_exercise_loads":
        items = payload.get("items") or []
        parts = []
        for item in items[:3]:
            kg = item.get("estimated_1rm_kg")
            label = item.get("name") or str(item.get("exercise_id"))
            if isinstance(kg, (int, float)):
                label = f"{label} 1RM {kg:g}kg"
            parts.append(label)
        return "、".join(parts)
    if name == "propose_session" and payload.get("ok"):
        return f"{payload.get('exercise_count', 0)} 个动作"
    if name == "suggest_next" and payload.get("ok"):
        return str(payload.get("name") or "")
    return ""


def _collapse(steps: list[dict]) -> list[dict]:
    folded: list[dict] = []
    for step in steps:
        if (
            folded
            and folded[-1]["title"] == step["title"]
            and folded[-1]["state"] == "running"
        ):
            folded[-1] = step
        else:
            folded.append(step)
    return [step for step in folded if step.get("state") != "running"]


def history_from_rows(rows: list) -> list[dict]:
    kept = [row for row in rows if row.role in {"user", "assistant"}]
    return [{"role": row.role, "content": row.content} for row in kept]
