from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import TYPE_CHECKING

from streakium.config import BrowserConfig
from streakium.runtime_paths import get_chromedriver_binary

if TYPE_CHECKING:
    from selenium.webdriver.chrome.webdriver import WebDriver
    from selenium.webdriver.remote.webelement import WebElement


class BrowserAutomationError(RuntimeError):
    pass


def click_element(element: "WebElement") -> None:
    element.click()


def create_browser_driver(profile_dir: Path, config: BrowserConfig) -> "WebDriver":
    browser_binary = find_chrome_binary()
    driver_binary = get_chromedriver_binary()
    chromium_version = _read_chrome_version(browser_binary)
    if driver_binary is None:
        raise BrowserAutomationError("ChromeDriver was not found. Run install.cmd.")
    profile_dir.mkdir(parents=True, exist_ok=True)
    _clear_stale_profile_locks(profile_dir)
    try:
        import undetected_chromedriver as uc
    except ModuleNotFoundError as exc:
        raise BrowserAutomationError("undetected-chromedriver is not installed. Run install.cmd.") from exc
    options = uc.ChromeOptions()
    options.binary_location = str(browser_binary)
    options.page_load_strategy = "eager"
    if config.headless:
        options.add_argument("--headless=new")
        options.add_argument("--window-size=1280,2160")
        if chromium_version:
            options.add_argument(f"--user-agent={_desktop_user_agent(chromium_version)}")
    options.add_argument("--disable-notifications")
    options.add_argument("--disable-background-networking")
    _add_fake_media_options(options, config.fake_video_path)
    driver = None
    try:
        driver = uc.Chrome(
            options=options,
            driver_executable_path=str(driver_binary),
            browser_executable_path=str(browser_binary),
            user_data_dir=str(profile_dir),
            use_subprocess=True,
            version_main=_major_version(chromium_version),
        )
        if not config.headless:
            _fit_browser_to_screen(driver)
        driver.set_page_load_timeout(max(1, config.timeout_ms // 1000))
        return driver
    except Exception as exc:
        if driver is not None:
            try:
                driver.quit()
            except Exception:
                pass
        raise BrowserAutomationError(f"Chrome failed to start: {exc}") from exc


def find_chrome_binary() -> Path:
    candidates = [
        os.environ.get("CHROME_PATH", "").strip(),
        shutil.which("chrome"),
        shutil.which("chrome.exe"),
    ]
    for variable in ("PROGRAMFILES", "PROGRAMFILES(X86)", "LOCALAPPDATA"):
        root = os.environ.get(variable, "").strip()
        if root:
            candidates.append(str(Path(root) / "Google" / "Chrome" / "Application" / "chrome.exe"))
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate)
    raise BrowserAutomationError("Google Chrome was not found. Run install.cmd.")


def _add_fake_media_options(options: object, fake_video_path: Path | None) -> None:
    if fake_video_path is None:
        return
    options.add_argument("--use-fake-ui-for-media-stream")
    options.add_argument("--use-fake-device-for-media-stream")
    options.add_argument(f"--use-file-for-fake-video-capture={fake_video_path}")


def _fit_browser_to_screen(driver: "WebDriver") -> None:
    try:
        driver.maximize_window()
    except Exception:
        return


def _clear_stale_profile_locks(profile_dir: Path) -> None:
    if _profile_has_running_chrome(profile_dir):
        return
    for name in ("SingletonLock", "SingletonSocket", "SingletonCookie", "DevToolsActivePort"):
        path = profile_dir / name
        try:
            if path.exists() or path.is_symlink():
                path.unlink()
        except OSError:
            continue


def _profile_has_running_chrome(profile_dir: Path) -> bool:
    try:
        completed = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-Command",
                "Get-CimInstance Win32_Process -Filter \"Name='chrome.exe'\" | Select-Object -ExpandProperty CommandLine",
            ],
            capture_output=True,
            check=False,
            text=True,
            timeout=10,
        )
    except Exception:
        return True
    normalized_profile = str(profile_dir.resolve()).casefold()
    return any(normalized_profile in line.casefold() for line in completed.stdout.splitlines())


def _read_chrome_version(browser_binary: Path) -> str:
    try:
        completed = subprocess.run(
            [str(browser_binary), "--version"],
            capture_output=True,
            check=False,
            text=True,
            timeout=10,
        )
    except Exception:
        return ""
    for value in completed.stdout.split():
        if value and value[0].isdigit():
            return value
    escaped_path = str(browser_binary).replace("'", "''")
    try:
        completed = subprocess.run(
            [
                "powershell.exe",
                "-NoProfile",
                "-Command",
                f"(Get-Item -LiteralPath '{escaped_path}').VersionInfo.ProductVersion",
            ],
            capture_output=True,
            check=False,
            text=True,
            timeout=10,
        )
    except Exception:
        return ""
    return completed.stdout.strip()


def _major_version(version: str) -> int | None:
    if not version:
        return None
    try:
        return int(version.split(".", 1)[0])
    except ValueError:
        return None


def _desktop_user_agent(version: str) -> str:
    return f"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/{version} Safari/537.36"
