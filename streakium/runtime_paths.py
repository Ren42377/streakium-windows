from __future__ import annotations

import os
from pathlib import Path


def get_project_dir() -> Path:
    return Path(__file__).resolve().parent.parent


def get_streakium_home() -> Path:
    value = os.environ.get("STREAKIUM_HOME", "").strip()
    if value:
        return Path(value).expanduser().resolve()
    return get_project_dir() / ".streakium"


def get_auth_profile_dir() -> Path:
    return get_streakium_home() / "auth" / "selenium-profile"


def get_tools_dir() -> Path:
    return get_streakium_home() / "tools"


def get_driver_cache_dir() -> Path:
    return get_tools_dir() / "chromedriver"


def get_media_cache_dir() -> Path:
    return get_streakium_home() / "media"


def get_logs_dir() -> Path:
    return get_streakium_home() / "logs"


def get_state_dir() -> Path:
    return get_streakium_home() / "state"


def get_scheduler_state_path() -> Path:
    return get_state_dir() / "scheduler.json"


def get_scheduler_lock_path() -> Path:
    return get_state_dir() / "scheduler.lock"


def get_snapchat_camera_folder() -> Path:
    return get_project_dir() / "assets"


def get_duolingo_model_dir() -> Path:
    return Path(__file__).resolve().parent / "models" / "duolingo"


def get_stockfish_binary() -> Path | None:
    return _find_local_tool("stockfish.exe", "stockfish")


def get_ffmpeg_binary() -> Path | None:
    return _find_local_tool("ffmpeg.exe", "ffmpeg")


def get_chromedriver_binary() -> Path | None:
    return _find_local_tool("chromedriver.exe", "chromedriver")


def _find_local_tool(*names: str) -> Path | None:
    tools_dir = get_tools_dir()
    if not tools_dir.is_dir():
        return None
    lowered_names = {name.casefold() for name in names}
    for path in sorted(tools_dir.rglob("*")):
        if path.is_file() and path.name.casefold() in lowered_names:
            return path
    return None
