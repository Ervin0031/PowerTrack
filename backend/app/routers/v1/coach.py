"""今日课表教练。模型只产出提案，确认开练走现有会话接口。"""

import asyncio
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import get_current_user
from app.crud.profile import profile_crud
from app.decorators.rate_limit import rate_limiter
from app.models.coach import CoachMessage, CoachThread
from app.models.user import User
from app.schemas.coach import (
    CoachMessageCreate,
    CoachTurnImport,
    NextExerciseRequest,
    StoredCoachMessage,
    ThreadCreated,
    ThreadDetail,
    ThreadSummary,
)
from app.services.coach.agent import history_from_rows, run_coach
from app.services.coach.llm import CoachNotConfiguredError, OpenAICompatClient
from app.services.coach.prompts import DEFAULT_USER_PROMPT, NEXT_SYSTEM_PROMPT
from app.services.coach.tools import NEXT_TOOLS

router = APIRouter(prefix="/coach", tags=["Coach"])


def get_llm():
    """Missing key does not raise here, so profile/auth errors stay reachable."""
    try:
        return OpenAICompatClient()
    except CoachNotConfiguredError:
        return None


def _sse(event: str, data: dict) -> str:
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


@router.post(
    "/threads",
    response_model=ThreadCreated,
    summary="新建教练对话",
)
async def create_thread(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    thread = CoachThread(user_id=current_user.id)
    db.add(thread)
    await db.commit()
    await db.refresh(thread)
    return ThreadCreated(id=thread.id)


def _title(content: str | None) -> str:
    text = " ".join((content or "").split())
    if not text:
        return "新对话"
    if len(text) <= 24:
        return text
    return f"{text[:24]}…"


async def _owned_thread(db: AsyncSession, thread_id: int, user_id: int) -> CoachThread:
    thread = await db.get(CoachThread, thread_id)
    if thread is None or thread.user_id != user_id:
        raise HTTPException(404, "对话不存在")
    return thread


@router.get("/threads", response_model=list[ThreadSummary], summary="教练对话列表")
async def list_threads(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    threads = (
        (
            await db.execute(
                select(CoachThread)
                .where(CoachThread.user_id == current_user.id)
                .order_by(CoachThread.updated_at.desc())
                .limit(40)
            )
        )
        .scalars()
        .all()
    )
    ids = [thread.id for thread in threads]
    first_user: dict[int, str] = {}
    if ids:
        rows = (
            (
                await db.execute(
                    select(CoachMessage)
                    .where(CoachMessage.thread_id.in_(ids), CoachMessage.role == "user")
                    .order_by(CoachMessage.id)
                )
            )
            .scalars()
            .all()
        )
        for row in rows:
            first_user.setdefault(row.thread_id, row.content)
    return [
        ThreadSummary(
            id=thread.id,
            title=_title(first_user.get(thread.id)),
            updated_at=thread.updated_at,
        )
        for thread in threads
    ]


@router.get(
    "/threads/{thread_id}",
    response_model=ThreadDetail,
    summary="读取一段教练对话",
)
async def get_thread(
    thread_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    thread = await _owned_thread(db, thread_id, current_user.id)
    rows = (
        (
            await db.execute(
                select(CoachMessage)
                .where(CoachMessage.thread_id == thread.id)
                .order_by(CoachMessage.id)
            )
        )
        .scalars()
        .all()
    )
    title_source = next((row.content for row in rows if row.role == "user"), None)
    messages = []
    for row in rows:
        proposal = None
        if row.proposal_json:
            try:
                proposal = json.loads(row.proposal_json)
            except json.JSONDecodeError:
                proposal = None
        trace = None
        if row.trace_json:
            try:
                parsed = json.loads(row.trace_json)
                trace = parsed if isinstance(parsed, list) else None
            except json.JSONDecodeError:
                trace = None
        messages.append(
            StoredCoachMessage(
                role=row.role,
                content=row.content,
                proposal=proposal,
                trace=trace,
            )
        )
    return ThreadDetail(id=thread.id, title=_title(title_source), messages=messages)


@router.post(
    "/threads/{thread_id}/messages/import",
    status_code=204,
    summary="写入客户端已生成的一轮对话",
    description="需认证。只保存消息，不调用模型。响应 204。",
)
async def import_turn(
    thread_id: int,
    body: CoachTurnImport,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    thread = await _owned_thread(db, thread_id, current_user.id)
    proposal_json = (
        json.dumps(body.proposal.model_dump(), ensure_ascii=False)
        if body.proposal is not None
        else None
    )
    trace_json = (
        json.dumps([step.model_dump() for step in body.trace], ensure_ascii=False)
        if body.trace
        else None
    )
    db.add(CoachMessage(thread_id=thread.id, role="user", content=body.user_content))
    db.add(
        CoachMessage(
            thread_id=thread.id,
            role="assistant",
            content=body.assistant_content,
            proposal_json=proposal_json,
            trace_json=trace_json,
        )
    )
    thread.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    await db.commit()


@router.post(
    "/threads/{thread_id}/messages",
    summary="发送一句并流式返回课表提案",
    description=(
        "需认证。空 content 会按档案排今天的力量训练。"
        "响应是 SSE：status / message / proposal / done / error。"
        "proposal 不落训练记录。"
    ),
)
async def post_message(
    thread_id: int,
    body: CoachMessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm=Depends(get_llm),
):
    if llm is None:
        raise HTTPException(503, "教练还没配置")
    thread = await _owned_thread(db, thread_id, current_user.id)
    profile = await profile_crud.get_by_user(db, current_user.id)
    if profile is None:
        raise HTTPException(409, "请先完成健身档案")
    if not rate_limiter.is_allowed(f"coach:{current_user.id}", 8, 3600):
        raise HTTPException(429, "教练请求太频繁，请一小时后再试")

    text = (body.content or "").strip() or DEFAULT_USER_PROMPT
    rows = (
        (
            await db.execute(
                select(CoachMessage)
                .where(CoachMessage.thread_id == thread.id)
                .order_by(CoachMessage.id)
            )
        )
        .scalars()
        .all()
    )

    async def events():
        queue: asyncio.Queue = asyncio.Queue()
        holder: dict = {}

        async def on_step(step: dict) -> None:
            await queue.put(("thought", step))

        async def work() -> None:
            try:
                holder["result"] = await run_coach(
                    db,
                    current_user.id,
                    history_from_rows(rows),
                    text,
                    llm,
                    on_step,
                )
            except CoachNotConfiguredError:
                holder["error"] = "教练还没配置"
            except Exception:
                holder["error"] = "这次没排出来，稍后再试"
            await queue.put(("end", None))

        task = asyncio.create_task(work())
        try:
            while True:
                kind, payload = await queue.get()
                if kind == "end":
                    break
                yield _sse("thought", payload)
        finally:
            await task

        if holder.get("error"):
            yield _sse("error", {"text": holder["error"]})
            return

        result = holder["result"]
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        proposal_json = None
        if result.proposal is not None:
            proposal_json = json.dumps(result.proposal, ensure_ascii=False)
        trace_json = None
        if result.steps:
            trace_json = json.dumps(result.steps, ensure_ascii=False)
        db.add(CoachMessage(thread_id=thread.id, role="user", content=text))
        db.add(
            CoachMessage(
                thread_id=thread.id,
                role="assistant",
                content=result.text,
                proposal_json=proposal_json,
                trace_json=trace_json,
            )
        )
        thread.updated_at = now
        await db.commit()

        yield _sse("message", {"text": result.text})
        if result.proposal is not None:
            yield _sse("proposal", result.proposal)
        yield _sse("done", {})

    return StreamingResponse(events(), media_type="text/event-stream")


def _session_prompt(body: NextExerciseRequest) -> str:
    if not body.exercises:
        return "这场训练还没有动作。请根据恢复和历史建议第一个动作。"
    lines = ["这场已经在练："]
    for item in body.exercises:
        line = (
            f"- {item.name} id={item.exercise_id} "
            f"完成 {item.sets_done}/{item.sets_planned}"
        )
        if item.last_weight_kg is not None:
            line += f" 最近 {item.last_weight_kg:g}kg"
            if item.last_reps is not None:
                line += f"×{item.last_reps}"
        lines.append(line)
    lines.append("请建议下一个还没练的动作。")
    return "\n".join(lines)


@router.post(
    "/suggest-next",
    summary="根据当前训练建议下一个动作",
    description="需认证。结合本场动作、恢复和历史重量，返回下一个动作。",
)
async def suggest_next(
    body: NextExerciseRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    llm=Depends(get_llm),
):
    if llm is None:
        raise HTTPException(503, "教练还没配置")
    profile = await profile_crud.get_by_user(db, current_user.id)
    if profile is None:
        raise HTTPException(409, "请先完成健身档案")
    if not rate_limiter.is_allowed(f"coach:{current_user.id}", 8, 3600):
        raise HTTPException(429, "教练请求太频繁，请一小时后再试")

    blocked = {item.exercise_id for item in body.exercises}

    async def events():
        queue: asyncio.Queue = asyncio.Queue()
        holder: dict = {}

        async def on_step(step: dict) -> None:
            await queue.put(step)

        async def work() -> None:
            try:
                holder["result"] = await run_coach(
                    db,
                    current_user.id,
                    [],
                    _session_prompt(body),
                    llm,
                    on_step,
                    system_prompt=NEXT_SYSTEM_PROMPT,
                    tools=NEXT_TOOLS,
                    blocked_ids=blocked,
                    thinking=False,
                )
            except CoachNotConfiguredError:
                holder["error"] = "教练还没配置"
            except Exception:
                holder["error"] = "这次没想出下一个动作"
            await queue.put(None)

        task = asyncio.create_task(work())
        try:
            while True:
                step = await queue.get()
                if step is None:
                    break
                yield _sse("thought", step)
        finally:
            await task

        if holder.get("error"):
            yield _sse("error", {"text": holder["error"]})
            return
        result = holder["result"]
        yield _sse("message", {"text": result.text})
        if result.suggestion is not None:
            yield _sse("suggestion", result.suggestion)
        yield _sse("done", {})

    return StreamingResponse(events(), media_type="text/event-stream")
