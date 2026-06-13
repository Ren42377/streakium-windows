from pathlib import Path

from streakium import runtime_paths


def test_default_home_is_inside_project(monkeypatch):
    monkeypatch.delenv("STREAKIUM_HOME", raising=False)
    assert runtime_paths.get_streakium_home() == runtime_paths.get_project_dir() / ".streakium"


def test_home_override_is_respected(monkeypatch, tmp_path):
    monkeypatch.setenv("STREAKIUM_HOME", str(tmp_path))
    assert runtime_paths.get_streakium_home() == tmp_path.resolve()
    assert runtime_paths.get_auth_profile_dir() == tmp_path.resolve() / "auth" / "selenium-profile"


def test_local_tools_are_discovered_recursively(monkeypatch, tmp_path):
    monkeypatch.setenv("STREAKIUM_HOME", str(tmp_path))
    expected = tmp_path / "tools" / "stockfish" / "bin" / "stockfish.exe"
    expected.parent.mkdir(parents=True)
    expected.write_bytes(b"")
    assert runtime_paths.get_stockfish_binary() == expected
