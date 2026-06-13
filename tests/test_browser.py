from streakium import browser


def test_chrome_is_found_from_program_files(monkeypatch, tmp_path):
    chrome = tmp_path / "Google" / "Chrome" / "Application" / "chrome.exe"
    chrome.parent.mkdir(parents=True)
    chrome.write_bytes(b"")
    monkeypatch.delenv("CHROME_PATH", raising=False)
    monkeypatch.setenv("PROGRAMFILES", str(tmp_path))
    monkeypatch.delenv("PROGRAMFILES(X86)", raising=False)
    monkeypatch.delenv("LOCALAPPDATA", raising=False)
    monkeypatch.setattr(browser.shutil, "which", lambda _: None)
    assert browser.find_chrome_binary() == chrome
