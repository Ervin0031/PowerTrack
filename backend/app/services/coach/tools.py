"""Coach tools. Reads existing services. propose_session only builds JSON."""

import json
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.one_rm import one_rm_crud
from app.crud.profile import parse_tags, profile_crud
from app.crud.recovery import recovery_crud
from app.crud.workout import set_crud
from app.models.exercise import Exercise, MuscleGroup
from app.schemas.coach import SET_KINDS, ProposedExercise, SessionProposal
from app.services.program import patch_block, program_view
from app.services.strength import (
    WeekVolume,
    build_weekly_report,
    should_suggest_deload,
    week_monday,
)
from app.services.volume_landmarks import volume_landmarks

TOOLS: list[dict] = [
    {
        "type": "function",
        "function": {
            "name": "get_profile",
            "description": "健身档案：目标、经验、伤病、器械、时长。",
            "parameters": {
                "type": "object",
                "properties": {},
                "additionalProperties": False,
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_training_block",
            "description": "当前周期：第几周、今天的模板和每个动作的下次课处方。",
            "parameters": {
                "type": "object",
                "properties": {},
                "additionalProperties": False,
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "adjust_block",
            "description": (
                "改当前周期，而不是另排今天。"
                "可改标题、周数、减量周、开始日期，或替换训练日。"
                "训练日的 template_id 必须是用户已有模板。"
                "还没有周期时必须带上 days。"
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "week_count": {"type": "integer"},
                    "deload_week": {"type": "integer"},
                    "started_on": {
                        "type": "string",
                        "description": "YYYY-MM-DD",
                    },
                    "days": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "weekday": {
                                    "type": "integer",
                                    "description": "0 周一 … 6 周日",
                                },
                                "template_id": {"type": "integer"},
                            },
                            "required": ["weekday", "template_id"],
                        },
                    },
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_training_context",
            "description": "肌群恢复，以及本周 hard set 容量区间。",
            "parameters": {
                "type": "object",
                "properties": {},
                "additionalProperties": False,
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_exercises",
            "description": "按中文名搜动作库，返回真实 exercise_id。",
            "parameters": {
                "type": "object",
                "properties": {
                    "search": {
                        "type": "string",
                        "description": "动作名，如卧推、深蹲",
                    },
                    "limit": {"type": "integer", "description": "1-8，默认 6"},
                },
                "required": ["search"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_exercise_loads",
            "description": "动作的 1RM 和上次各组。id 必须来自搜索。",
            "parameters": {
                "type": "object",
                "properties": {
                    "exercise_ids": {
                        "type": "array",
                        "items": {"type": "integer"},
                    }
                },
                "required": ["exercise_ids"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "propose_session",
            "description": "只在用户要求排课或生成计划时提交课表。",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "summary": {"type": "string"},
                    "estimated_minutes": {"type": "integer"},
                    "exercises": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "exercise_id": {"type": "integer"},
                                "notes": {"type": "string"},
                                "rest_target_seconds": {"type": "integer"},
                                "sets": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "set_number": {"type": "integer"},
                                            "set_kind": {
                                                "type": "string",
                                                "enum": list(SET_KINDS),
                                            },
                                            "reps": {"type": "integer"},
                                            "weight_kg": {"type": "number"},
                                        },
                                        "required": ["set_number", "set_kind"],
                                    },
                                },
                            },
                            "required": ["exercise_id", "sets"],
                        },
                    },
                },
                "required": ["title", "summary", "estimated_minutes", "exercises"],
            },
        },
    },
]

SUGGEST_NEXT_TOOL: dict = {
    "type": "function",
    "function": {
        "name": "suggest_next",
        "description": "建议本场的下一个动作。不会写入训练记录。",
        "parameters": {
            "type": "object",
            "properties": {
                "reason": {"type": "string"},
                "exercise": {
                    "type": "object",
                    "properties": {
                        "exercise_id": {"type": "integer"},
                        "notes": {"type": "string"},
                        "sets": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "set_number": {"type": "integer"},
                                    "set_kind": {
                                        "type": "string",
                                        "enum": list(SET_KINDS),
                                    },
                                    "reps": {"type": "integer"},
                                    "weight_kg": {"type": "number"},
                                },
                                "required": ["set_number", "set_kind"],
                            },
                        },
                    },
                    "required": ["exercise_id", "sets"],
                },
            },
            "required": ["reason", "exercise"],
        },
    },
}

_NEXT_SKIP = {"propose_session", "get_training_block", "adjust_block"}
NEXT_TOOLS = [tool for tool in TOOLS if tool["function"]["name"] not in _NEXT_SKIP]
NEXT_TOOLS.append(SUGGEST_NEXT_TOOL)


class ToolContext:
    """Ids the model has actually seen this turn. Proposals outside this set fail."""

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        blocked_ids: Optional[set[int]] = None,
    ) -> None:
        self.db = db
        self.user_id = user_id
        self.blocked_ids = blocked_ids or set()
        self.catalog: dict[int, dict[str, str]] = {}
        self.proposal: Optional[dict] = None
        self.suggestion: Optional[dict] = None
        self.allow_plan = True

    async def call(self, name: str, arguments: dict) -> dict:
        handler = {
            "get_profile": self.get_profile,
            "get_training_block": self.get_training_block,
            "adjust_block": self.adjust_block,
            "get_training_context": self.get_training_context,
            "search_exercises": self.search_exercises,
            "get_exercise_loads": self.get_exercise_loads,
            "propose_session": self.propose_session,
            "suggest_next": self.suggest_next,
        }.get(name)
        if handler is None:
            return {"error": f"unknown tool {name}"}
        try:
            return await handler(arguments)
        except ValidationError as exc:
            return {"error": exc.errors()[:3]}

    async def get_profile(self, _args: dict) -> dict:
        profile = await profile_crud.get_by_user(self.db, self.user_id)
        if profile is None:
            return {"complete": False}
        return {
            "complete": True,
            "goal": profile.goal,
            "experience": profile.experience,
            "weight_kg": profile.weight_kg,
            "injury_tags": parse_tags(profile.injury_tags),
            "weekly_days": profile.weekly_days,
            "session_minutes": profile.session_minutes,
            "equipment": profile.equipment,
        }

    async def get_training_block(self, _args: dict) -> dict:
        return await program_view(self.db, self.user_id)

    async def adjust_block(self, args: dict) -> dict:
        try:
            view = await patch_block(self.db, self.user_id, args)
        except HTTPException as exc:
            return {"error": str(exc.detail)}
        except ValidationError as exc:
            return {"error": _short_errors(exc)}
        return {
            "ok": True,
            "title": view.get("title"),
            "current_week": view.get("current_week"),
            "is_deload": view.get("is_deload"),
            "deload_week": view.get("deload_week"),
        }

    async def get_training_context(self, _args: dict) -> dict:
        status = await recovery_crud.list_status(self.db, self.user_id)
        recovery = [
            {
                "name": item.name,
                "recovery_progress": round(float(item.recovery_progress), 2),
                "hours_since_last": item.hours_since_last,
            }
            for item in status["items"]
        ]
        today = datetime.now(timezone.utc).date()
        since = datetime.combine(
            week_monday(today) - timedelta(weeks=7), datetime.min.time()
        )
        rows = await one_rm_crud.list_completed_set_loads(self.db, self.user_id, since)
        reports = build_weekly_report(rows, today)
        suggest, reason = should_suggest_deload(
            [
                WeekVolume(
                    week_start=week.week_start,
                    volume=week.volume,
                    hard_volume=week.hard_volume,
                    hard_sets=week.hard_sets,
                    avg_rpe=week.avg_rpe,
                )
                for week in reports
            ]
        )
        current = reports[-1] if reports else None
        muscles = current.by_muscle if current else []
        trained = {muscle.name: muscle.hard_sets for muscle in muscles}
        zones = [
            {"name": item["name"], "hard_sets": item["hard_sets"], "zone": item["zone"]}
            for item in volume_landmarks(trained)
            if item["hard_sets"] > 0
        ]
        return {
            "recovery": recovery,
            "week_zones": zones,
            "suggest_deload": suggest,
            "deload_reason": reason,
        }

    async def search_exercises(self, args: dict) -> dict:
        search = str(args.get("search") or "").strip()
        if not search:
            return {"error": "search 不能为空"}
        limit = args.get("limit") or 6
        try:
            limit = max(1, min(8, int(limit)))
        except (TypeError, ValueError):
            limit = 6
        stmt = (
            select(
                Exercise.id,
                Exercise.name,
                Exercise.exercise_type,
                MuscleGroup.name,
            )
            .join(MuscleGroup, MuscleGroup.id == Exercise.primary_muscle_group_id)
            .where(Exercise.name.ilike(f"%{search}%"))
            .order_by(Exercise.id)
            .limit(limit)
        )
        rows = (await self.db.execute(stmt)).all()
        items = []
        for exercise_id, name, exercise_type, muscle in rows:
            self.catalog[int(exercise_id)] = {
                "name": name,
                "exercise_type": exercise_type,
            }
            items.append(
                {
                    "exercise_id": int(exercise_id),
                    "name": name,
                    "exercise_type": exercise_type,
                    "muscle": muscle,
                }
            )
        return {"items": items}

    async def get_exercise_loads(self, args: dict) -> dict:
        raw_ids = args.get("exercise_ids") or []
        if not isinstance(raw_ids, list):
            return {"error": "exercise_ids 必须是数组"}
        items = []
        for raw in raw_ids[:8]:
            try:
                exercise_id = int(raw)
            except (TypeError, ValueError):
                continue
            if exercise_id not in self.catalog:
                items.append({"exercise_id": exercise_id, "error": "先搜索这个动作"})
                continue
            record = await one_rm_crud.get(self.db, self.user_id, exercise_id)
            last = await set_crud.get_last_session_sets(
                self.db, exercise_id, self.user_id
            )
            sets = []
            if last:
                for workout_set in last["sets"][:8]:
                    sets.append(
                        {
                            "set_number": workout_set.set_number,
                            "set_kind": workout_set.set_kind,
                            "reps": workout_set.reps,
                            "weight_kg": workout_set.weight_kg,
                            "rpe": workout_set.rpe,
                        }
                    )
            items.append(
                {
                    "exercise_id": exercise_id,
                    "name": self.catalog[exercise_id]["name"],
                    "estimated_1rm_kg": None if record is None else record.estimated_kg,
                    "last_sets": sets,
                }
            )
        return {"items": items}

    async def propose_session(self, args: dict) -> dict:
        if not self.allow_plan:
            return {"error": "用户这次不是要排课。用文字回答，不要提交课表。"}
        block = (
            await program_view(self.db, self.user_id) if self.db is not None else {}
        )
        if block.get("active"):
            today = next((day for day in block["days"] if day.get("is_today")), None)
            if today is None:
                return {
                    "error": (
                        "今天在周期里是休息日。"
                        "要改哪一天用 adjust_block，不要另排一堂。"
                    )
                }
            return {
                "error": "今天按周期练，不要另排一堂。要改下周用 adjust_block。",
                "today": today,
                "current_week": block.get("current_week"),
                "is_deload": block.get("is_deload"),
            }
        if not self.catalog:
            return {"error": "先 search_exercises，再用返回的 exercise_id"}
        try:
            proposal = SessionProposal.model_validate(args)
        except ValidationError as exc:
            return {"error": _short_errors(exc)}
        unknown = [
            item.exercise_id
            for item in proposal.exercises
            if item.exercise_id not in self.catalog
        ]
        if unknown:
            return {"error": f"这些 id 不在本次搜索结果里: {unknown}"}
        filled = []
        for item in proposal.exercises:
            known = self.catalog[item.exercise_id]
            dumped = item.model_dump()
            dumped["name"] = known["name"]
            dumped["exercise_type"] = known["exercise_type"]
            for planned in dumped["sets"]:
                if planned.get("set_kind") not in SET_KINDS:
                    planned["set_kind"] = "working"
            filled.append(dumped)
        accepted = proposal.model_dump()
        accepted["exercises"] = filled
        self.proposal = accepted
        return {"ok": True, "exercise_count": len(filled)}

    async def suggest_next(self, args: dict) -> dict:
        if not self.catalog:
            return {"error": "先 search_exercises，再用返回的 exercise_id"}
        exercise = args.get("exercise")
        if not isinstance(exercise, dict):
            return {"error": "exercise 必须是一个动作"}
        try:
            parsed = ProposedExercise.model_validate(exercise)
        except ValidationError as exc:
            return {"error": _short_errors(exc)}
        if parsed.exercise_id not in self.catalog:
            return {"error": "这个 id 不在本次搜索结果里"}
        if parsed.exercise_id in self.blocked_ids:
            return {"error": "这个动作本场已经在练"}
        known = self.catalog[parsed.exercise_id]
        dumped = parsed.model_dump()
        dumped["name"] = known["name"]
        dumped["exercise_type"] = known["exercise_type"]
        for planned in dumped["sets"]:
            if planned.get("set_kind") not in SET_KINDS:
                planned["set_kind"] = "working"
        reason = str(args.get("reason") or "").strip()[:180]
        self.suggestion = {"reason": reason, "exercise": dumped}
        return {"ok": True, "name": known["name"]}


def _short_errors(exc: ValidationError) -> list[dict]:
    return [
        {"loc": list(err.get("loc", [])), "msg": err.get("msg", "")}
        for err in exc.errors()[:4]
    ]


def parse_arguments(raw: str) -> dict[str, Any]:
    try:
        data = json.loads(raw or "{}")
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}
