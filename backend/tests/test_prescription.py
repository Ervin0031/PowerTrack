"""下次课处方与周期周次。"""

from datetime import date

from app.services.prescription import Exposure, block_week, prescribe


def _exp(weight, rpe, sets=4, e1rm=120.0, reps=5):
    return Exposure(weight, reps, rpe, e1rm, sets)


def test_add_one_plate_in_the_sweet_spot():
    result = prescribe([_exp(100, 8)], deload=False)
    assert result.action == "add_load"
    assert result.weight_kg == 102.5
    assert result.sets == 4
    assert result.stalled is False


def test_light_set_adds_two_plates():
    result = prescribe([_exp(100, 6)], deload=False)
    assert result.action == "add_load"
    assert result.weight_kg == 105


def test_failure_drops_one_set():
    result = prescribe([_exp(100, 10)], deload=False)
    assert result.action == "drop_set"
    assert result.sets == 3
    assert result.weight_kg == 100


def test_single_set_failure_drops_one_plate():
    result = prescribe([_exp(100, 10, sets=1)], deload=False)
    assert result.action == "drop_set"
    assert result.weight_kg == 97.5


def test_three_flat_heavy_sessions_swap():
    result = prescribe([_exp(100, 8.5)] * 3, deload=False)
    assert result.stalled is True
    assert result.action == "swap"


def test_flat_but_easy_still_adds():
    result = prescribe([_exp(100, 7)] * 3, deload=False)
    assert result.stalled is True
    assert result.action == "add_load"
    assert result.weight_kg == 102.5


def test_deload_halves_sets_and_wins():
    result = prescribe([_exp(100, 10, sets=5)] * 3, deload=True)
    assert result.action == "deload"
    assert result.sets == 2
    assert result.weight_kg == 100
    assert result.stalled is True


def test_missing_rpe_holds():
    result = prescribe([_exp(80, None, e1rm=None)], deload=False)
    assert result.action == "hold"
    assert result.weight_kg == 80


def test_no_history_holds_without_weight():
    result = prescribe([], deload=False)
    assert result.action == "hold"
    assert result.weight_kg is None


def test_block_week_loops_after_the_block():
    start = date(2026, 10, 5)
    assert block_week(start, start, 4) == 1
    assert block_week(start, date(2026, 10, 12), 4) == 2
    assert block_week(start, date(2026, 11, 2), 4) == 1
    assert block_week(date(2026, 10, 20), date(2026, 10, 19), 4) == 1
