"""Ensure JSON datetime strings from naive UTC carry a Z suffix."""

from __future__ import annotations

import re
from datetime import datetime, timezone

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

# Match full datetimes only — not date-only "YYYY-MM-DD".
_NAIVE_DT = re.compile(rb'"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?)"')


def datetime_to_utc_z(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)
    return dt.isoformat().replace("+00:00", "Z")


def patch_naive_utc_json(body: bytes) -> bytes:
    return _NAIVE_DT.sub(lambda m: m.group(0)[:-1] + b'Z"', body)


class UtcZJsonMiddleware(BaseHTTPMiddleware):
    """Append Z to timezone-less ISO datetimes in JSON responses."""

    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        content_type = response.headers.get("content-type", "")
        if "application/json" not in content_type:
            return response

        body = b""
        async for chunk in response.body_iterator:
            body += chunk if isinstance(chunk, (bytes, bytearray)) else chunk.encode()

        patched = patch_naive_utc_json(body)
        headers = {
            k: v for k, v in response.headers.items() if k.lower() != "content-length"
        }
        return Response(
            content=patched,
            status_code=response.status_code,
            headers=headers,
            media_type=response.media_type,
            background=response.background,
        )
