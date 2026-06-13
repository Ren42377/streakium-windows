from pathlib import Path

import pytest

from streakium.config import StreakiumConfigError, load_config


VALID_CONFIG = """\
tiktok=true
chess=true
duolingo=true
snapchat=false
browser.headless=true
tiktok.message=streak
tiktok.max_chats=1
chess.engine_time=0.1
snapchat.usernames=
schedule.enabled=true
schedule.time=7:05
"""


def test_load_config_uses_local_runtime(monkeypatch, tmp_path):
    monkeypatch.setenv("STREAKIUM_HOME", str(tmp_path / "runtime"))
    config_path = tmp_path / "config.txt"
    config_path.write_text(VALID_CONFIG, encoding="utf-8")
    config = load_config(config_path)
    assert config.browser.profile_dir == (tmp_path / "runtime").resolve() / "auth" / "selenium-profile"
    assert config.schedule.time == "07:05"
    assert config.snapchat.usernames == ()


def test_duplicate_setting_is_rejected(tmp_path):
    config_path = tmp_path / "config.txt"
    config_path.write_text(VALID_CONFIG + "tiktok=false\n", encoding="utf-8")
    with pytest.raises(StreakiumConfigError, match="Duplicate config key"):
        load_config(config_path)
