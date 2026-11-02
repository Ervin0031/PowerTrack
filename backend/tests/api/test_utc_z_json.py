"""naive UTC JSON datetime 补 Z。"""

from datetime import datetime, timedelta, timezone

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.utc_z_json import (
    UtcZJsonMiddleware,
    datetime_to_utc_z,
    patch_naive_utc_json,
)


def test_datetime_to_utc_z_naive():
    out = datetime_to_utc_z(datetime(2026, 9, 12, 14, 0, 0))
    assert out.endswith("Z")
    assert out.startswith("2026-09-12T14:00:00")


def test_datetime_to_utc_z_aware_plus8():
    dt = datetime(2026, 9, 12, 22, 0, 0, tzinfo=timezone(timedelta(hours=8)))
    assert datetime_to_utc_z(dt) == "2026-09-12T14:00:00Z"


def test_patch_naive_utc_json():
    raw = b'{"at":"2026-09-12T14:00:00","day":"2026-09-12"}'
    assert (
        patch_naive_utc_json(raw) == b'{"at":"2026-09-12T14:00:00Z","day":"2026-09-12"}'
    )


def test_middleware_json_response():
    app = FastAPI()
    app.add_middleware(UtcZJsonMiddleware)

    @app.get("/x")
    def x():
        return {"at": "2026-09-12T14:00:00"}

    client = TestClient(app)
    r = client.get("/x")
    assert r.status_code == 200
    assert r.json()["at"] == "2026-09-12T14:00:00Z"
