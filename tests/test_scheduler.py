from datetime import datetime

from streakium.config import (
    AppConfig,
    BrowserConfig,
    ChessConfig,
    DuolingoConfig,
    ScheduleConfig,
    SnapchatConfig,
    TikTokConfig,
)
from streakium.scheduler import (
    RetryPlan,
    SchedulerState,
    add_retry_plans,
    parse_failed_platforms,
    scheduler_action,
    scheduler_lock,
)


def make_config(schedule_time="09:00", enabled=True):
    return AppConfig(
        tiktok_enabled=True,
        chess_enabled=False,
        duolingo_enabled=False,
        snapchat_enabled=False,
        browser=BrowserConfig(True, 30000, None),
        tiktok=TikTokConfig("", "", "streak", 1, 1, 1),
        chess=ChessConfig("", "", 0.1, 30),
        duolingo=DuolingoConfig(""),
        snapchat=SnapchatConfig("", (), None, "random"),
        schedule=ScheduleConfig(enabled, schedule_time),
    )


def test_scheduler_runs_after_daily_time():
    now = datetime(2026, 6, 13, 9, 1)
    assert scheduler_action(make_config(), now, SchedulerState()) == "run"


def test_scheduler_does_not_repeat_completed_run():
    now = datetime(2026, 6, 13, 9, 1)
    state = SchedulerState("2026-06-13 09:00", "09:00")
    assert scheduler_action(make_config(), now, state) == "none"


def test_due_retry_is_selected():
    now = datetime(2026, 6, 13, 10, 0)
    state = SchedulerState(
        "2026-06-13 09:00",
        "09:00",
        (RetryPlan("tiktok", "2026-06-13", ("09:30",)),),
    )
    assert scheduler_action(make_config(), now, state) == "retry:tiktok"


def test_retry_plans_use_distinct_times():
    now = datetime(2026, 6, 13, 12, 0)
    state = add_retry_plans(SchedulerState(), now, {"tiktok", "snapchat"})
    times = [value for retry in state.retries for value in retry.times]
    assert len(times) == 6
    assert len(set(times)) == 6


def test_failed_platform_parser():
    output = "TikTok status: ok\nSnapchat status: partial\nChess.com status: stopped\n"
    assert parse_failed_platforms(output) == {"snapchat", "chess"}


def test_scheduler_lock_prevents_overlap(tmp_path):
    path = tmp_path / "scheduler.lock"
    with scheduler_lock(path) as first:
        with scheduler_lock(path) as second:
            assert first is True
            assert second is False
    assert not path.exists()
