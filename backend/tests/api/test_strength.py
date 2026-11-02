"""1RM / volume / deload."""

from datetime import date, datetime

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise, MuscleGroup
from app.services.strength import (
    EstimateSample,
    RecoveryObservation,
    RecoverySet,
    WeekVolume,
    baseline_window_hours,
    blend_estimates,
    build_weekly_report,
    compute_muscle_group_status,
    compute_recovery_factor,
    counts_as_load,
    epley_1rm,
    estimate_1rm,
    is_effective_session,
    percent_1rm,
    performance_change,
    recovery_confidence,
    recovery_delta,
    session_estimated_1rm,
    should_suggest_deload,
    working_weight,
)


def test_counts_as_load_treats_missing_kind_as_working():
    assert counts_as_load(None)
    assert counts_as_load("")
    assert counts_as_load("working")
    assert counts_as_load("drop")
    assert not counts_as_load("warmup")
    assert not counts_as_load("cooldown")


async def _create_exercise(db: AsyncSession) -> Exercise:
    mg = MuscleGroup(name="胸部", name_en="Chest", category="upper")
    db.add(mg)
    await db.flush()
    ex = Exercise(
        name="杠铃卧推",
        name_en="Barbell Bench Press",
        exercise_type="compound",
        primary_muscle_group_id=mg.id,
    )
    db.add(ex)
    await db.commit()
    await db.refresh(ex)
    return ex


def test_epley_5_reps():
    assert epley_1rm(100, 5) == pytest.approx(116.666, abs=0.01)
    assert epley_1rm(100, 1) == 100
    assert epley_1rm(100, 12) is None


def test_rpe_chart_matches_examples():
    assert percent_1rm(3, 8.5) == pytest.approx(87.8, abs=0.2)
    assert percent_1rm(3, 7) == pytest.approx(83.7, abs=0.2)
    assert percent_1rm(10, 8.5) == pytest.approx(71.6, abs=1.0)


def test_estimate_prefers_rpe_over_epley():
    with_rpe = estimate_1rm(100, 3, 8.5)
    epley = epley_1rm(100, 3)
    assert with_rpe is not None and epley is not None
    assert with_rpe == pytest.approx(100 / 0.878, abs=1.5)
    assert with_rpe != pytest.approx(epley, abs=0.01)


def test_blend_uses_median():
    assert blend_estimates([100, 200, 120]).estimated_kg == 120
    assert blend_estimates([100, 140]).estimated_kg == 120


def test_blend_filters_to_recent_window():
    now = datetime(2026, 9, 11)
    result = blend_estimates(
        [
            EstimateSample(100, datetime(2026, 6, 1)),
            EstimateSample(140, datetime(2026, 9, 1)),
        ],
        now=now,
    )
    assert result.estimated_kg == 140
    assert result.samples_count == 1
    assert result.stale is False


def test_blend_falls_back_when_all_stale():
    now = datetime(2026, 9, 11)
    result = blend_estimates(
        [
            EstimateSample(100, datetime(2026, 6, 1)),
            EstimateSample(140, datetime(2026, 6, 2)),
        ],
        now=now,
    )
    assert result.stale is True
    assert result.estimated_kg == 120
    assert result.samples_count == 2


def test_working_weight_hypertrophy_zone():
    # 200kg 1RM × 70% → 140, already on plate
    assert working_weight(200, "muscle_gain") == 140.0


def test_deload_after_five_loaded_weeks():
    weeks = [
        WeekVolume(date(2026, 8, 3 + i * 7), 10000, 8000, 10, 8.0) for i in range(5)
    ]
    suggest, reason = should_suggest_deload(weeks)
    assert suggest is True
    assert reason is not None


def test_deload_when_volume_drops_and_rpe_rises():
    weeks = [
        WeekVolume(date(2026, 8, 31), 12000, 9000, 12, 7.8),
        WeekVolume(date(2026, 9, 7), 10000, 8000, 10, 8.4),
    ]
    suggest, reason = should_suggest_deload(weeks)
    assert suggest is True
    assert "RPE" in (reason or "")


def test_weekly_report_groups_hard_sets():
    monday = date(2026, 9, 7)
    rows = [
        (datetime(2026, 9, 8, 10, 0), 8, 100.0, 8.5, "胸部"),
        (datetime(2026, 9, 8, 10, 5), 12, 60.0, 6.0, "胸部"),
    ]
    reports = build_weekly_report(rows, monday, n_weeks=1)
    assert len(reports) == 1
    week = reports[0]
    assert week.volume == pytest.approx(8 * 100 + 12 * 60)
    assert week.hard_sets == 1
    assert week.hard_volume == pytest.approx(800)
    assert week.by_muscle[0].name == "胸部"


@pytest.mark.asyncio
async def test_complete_session_updates_one_rm(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _create_exercise(db_session)
    created = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "1rm-session-1", "started_at": "2026-09-08T10:00:00Z"},
        headers=auth_headers,
    )
    assert created.status_code == 201
    session_id = created.json()["id"]
    resp = await client.put(
        f"/api/v1/sessions/{session_id}/complete",
        json={
            "client_uuid": "1rm-session-1",
            "started_at": "2026-09-08T10:00:00Z",
            "completed_at": "2026-09-08T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "1rm-set-1",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 5,
                    "weight_kg": 100.0,
                    "rpe": 8.0,
                    "completed_at": "2026-09-08T10:08:00Z",
                }
            ],
        },
        headers=auth_headers,
    )
    assert resp.status_code == 200

    one = await client.get(f"/api/v1/exercises/{ex.id}/one-rm", headers=auth_headers)
    assert one.status_code == 200
    body = one.json()
    assert body["estimated_kg"] > 100
    assert body["needs_recalibrate"] is False
    assert body["samples_count"] >= 1

    hist = await client.get(
        f"/api/v1/exercises/{ex.id}/one-rm/history", headers=auth_headers
    )
    assert hist.status_code == 200
    points = hist.json()["items"]
    assert points
    assert points[0]["estimated_kg"] > 100
    assert points[0]["source_set_id"] > 0

    vol = await client.get("/api/v1/volume/weekly", headers=auth_headers)
    assert vol.status_code == 200
    data = vol.json()
    loaded = [w for w in data["weeks"] if w["volume"] > 0]
    assert loaded
    assert loaded[-1]["volume"] == pytest.approx(500)
    assert loaded[-1]["hard_sets"] == 1


@pytest.mark.asyncio
async def test_one_rm_missing(client: AsyncClient, auth_headers: dict):
    resp = await client.get("/api/v1/exercises/99999/one-rm", headers=auth_headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_true_1rm_set_is_stored(
    client: AsyncClient, auth_headers: dict, db_session: AsyncSession
):
    ex = await _create_exercise(db_session)
    created = await client.post(
        "/api/v1/sessions",
        json={"client_uuid": "1rm-true-1", "started_at": "2026-09-08T10:00:00Z"},
        headers=auth_headers,
    )
    session_id = created.json()["id"]
    resp = await client.put(
        f"/api/v1/sessions/{session_id}/complete",
        json={
            "client_uuid": "1rm-true-1",
            "started_at": "2026-09-08T10:00:00Z",
            "completed_at": "2026-09-08T11:00:00Z",
            "sets": [
                {
                    "client_uuid": "1rm-true-set",
                    "exercise_id": ex.id,
                    "set_number": 1,
                    "reps": 1,
                    "weight_kg": 140.0,
                    "completed_at": "2026-09-08T10:20:00Z",
                }
            ],
        },
        headers=auth_headers,
    )
    assert resp.status_code == 200
    one = await client.get(f"/api/v1/exercises/{ex.id}/one-rm", headers=auth_headers)
    assert one.status_code == 200
    assert one.json()["estimated_kg"] == 140.0
    assert one.json()["samples_count"] == 1


def _hard_sets(n: int = 3, rpe: float = 8.0) -> list[RecoverySet]:
    return [RecoverySet(rpe=rpe, weight_kg=100, reps=5) for _ in range(n)]


def test_effective_session_needs_three_hard_sets():
    assert is_effective_session(_hard_sets(3)) is True
    assert is_effective_session(_hard_sets(2)) is False


def test_effective_session_rejects_low_average_rpe():
    sets = _hard_sets(3, rpe=8.0) + [
        RecoverySet(rpe=5.0, weight_kg=60, reps=12) for _ in range(6)
    ]
    assert is_effective_session(sets) is False


def test_performance_change_relative():
    assert performance_change(110, 100) == pytest.approx(0.1)
    assert performance_change(97, 100) == pytest.approx(-0.03)
    assert performance_change(100, 0) is None


def test_recovery_delta_high_freq_no_drop_decreases_factor():
    delta = recovery_delta(24, 60, 0.02)
    assert delta == pytest.approx(-0.036, abs=0.001)


def test_recovery_delta_high_freq_drop_increases_factor():
    delta = recovery_delta(24, 60, -0.05)
    assert delta == pytest.approx(0.036, abs=0.001)


def test_recovery_delta_ignores_at_or_above_baseline():
    assert recovery_delta(60, 60, 0.1) == 0
    assert recovery_delta(80, 60, -0.1) == 0


def test_recovery_delta_small_drop_is_neutral():
    assert recovery_delta(24, 60, -0.02) == 0


def test_session_estimated_1rm_uses_median():
    sets = [
        RecoverySet(rpe=8.0, weight_kg=100, reps=5),
        RecoverySet(rpe=8.0, weight_kg=80, reps=5),
        RecoverySet(weight_kg=200, reps=12),
    ]
    est = session_estimated_1rm(sets)
    assert est is not None
    low = estimate_1rm(80, 5, 8.0)
    high = estimate_1rm(100, 5, 8.0)
    assert est == pytest.approx((low + high) / 2, abs=0.2)


def test_baseline_large_vs_small():
    assert baseline_window_hours("胸部", "Chest") == 60
    assert baseline_window_hours("肱二头肌", "Biceps") == 36


def test_recovery_factor_locked_until_enough_samples():
    now = datetime(2026, 9, 11)
    obs = [RecoveryObservation(now, 24, 60, 0.01, -0.03) for _ in range(4)]
    factor, count = compute_recovery_factor(obs, now, min_count=5)
    assert factor == 1.0
    assert count == 4


def test_recovery_factor_moves_after_enough_samples():
    now = datetime(2026, 9, 11)
    obs = [RecoveryObservation(now, 24, 60, 0.01, -0.03) for _ in range(5)]
    factor, count = compute_recovery_factor(obs, now, min_count=5)
    assert count == 5
    assert factor == pytest.approx(0.85)


def test_recovery_factor_decays_old_observations():
    now = datetime(2026, 9, 11)
    old = datetime(2025, 11, 11)
    obs = [RecoveryObservation(old, 24, 60, 0.01, -0.03) for _ in range(5)]
    factor, count = compute_recovery_factor(obs, now, min_count=5)
    assert count == 0
    assert factor == 1.0


def test_recovery_factor_clamped():
    now = datetime(2026, 9, 11)
    obs = [RecoveryObservation(now, 12, 60, 0.05, -0.04) for _ in range(20)]
    factor, _ = compute_recovery_factor(obs, now, min_count=5)
    assert factor == 0.6


def test_recovery_confidence_buckets():
    assert recovery_confidence(0) == "low"
    assert recovery_confidence(5) == "medium"
    assert recovery_confidence(20) == "high"


def test_compute_muscle_group_status_uses_calibrated_window():
    now = datetime(2026, 9, 11, 12, 0, 0)
    last = datetime(2026, 9, 10, 12, 0, 0)
    muscle_obs = [RecoveryObservation(now, 24, 60, 0.02, -0.03) for _ in range(5)]
    status = compute_muscle_group_status(
        muscle_group_id=1,
        name="胸部",
        name_en="Chest",
        category="upper",
        last_trained_at=last,
        now=now,
        muscle_observations=muscle_obs,
        global_observations=[],
    )
    assert status.baseline_window_hours == 60
    assert status.muscle_factor == pytest.approx(0.85)
    assert status.global_factor == 1.0
    assert status.recovery_window_hours == pytest.approx(51.0)
    assert status.hours_since_last == pytest.approx(24)
    assert status.recovery_progress == pytest.approx(24 / 51, abs=0.001)
    assert status.recovery_confidence == "medium"
    assert status.observations_count == 5
