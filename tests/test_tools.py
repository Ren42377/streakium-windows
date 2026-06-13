from pathlib import Path

from streakium import snapchat_camera, stockfish


def test_stockfish_prefers_local_binary(monkeypatch, tmp_path):
    executable = tmp_path / "stockfish.exe"
    executable.write_bytes(b"")
    monkeypatch.setattr(stockfish, "get_stockfish_binary", lambda: executable)
    assert stockfish.resolve_stockfish_command() == str(executable)


def test_ffmpeg_prefers_local_binary(monkeypatch, tmp_path):
    executable = tmp_path / "ffmpeg.exe"
    executable.write_bytes(b"")
    monkeypatch.setattr(snapchat_camera, "get_ffmpeg_binary", lambda: executable)
    assert snapchat_camera.resolve_ffmpeg_command() == str(executable)


def test_camera_conversion_uses_local_ffmpeg(monkeypatch, tmp_path):
    source = tmp_path / "source.jpg"
    source.write_bytes(b"image")
    ffmpeg = tmp_path / "ffmpeg.exe"
    ffmpeg.write_bytes(b"")
    cache = tmp_path / "media"

    def run(command, **kwargs):
        Path(command[-1]).write_bytes(b"video")
        return type("Result", (), {"returncode": 0, "stderr": ""})()

    monkeypatch.setattr(snapchat_camera, "get_ffmpeg_binary", lambda: ffmpeg)
    monkeypatch.setattr(snapchat_camera, "get_media_cache_dir", lambda: cache)
    monkeypatch.setattr(snapchat_camera.subprocess, "run", run)
    output = snapchat_camera.prepare_snapchat_camera(source)
    assert output == cache / "snapchat-camera.y4m"
    assert output.read_bytes() == b"video"
