# Streakium for Windows

Streakium automates daily streak actions for TikTok, Chess.com, Duolingo, and Snapchat from Windows 10 or Windows 11.

## Supported Flows

- TikTok opens messages and sends the configured text to a limited number of chats.
- Chess.com opens a rated puzzle and intentionally plays one legal non-best move.
- Duolingo opens Chess Match, reads the board with the bundled LiteRT model, and uses Stockfish to play the logged-in side.
- Snapchat uses an image from `assets` as a fake Chrome camera and sends one Snap to every configured username.

Automation can violate platform rules and may put accounts at risk. Use conservative limits and accounts you are prepared to recover.

## Requirements

- Windows 10 or Windows 11 x64
- Latest 64-bit Python from [python.org](https://www.python.org/downloads/windows/)
- Internet access during installation
- `winget`, provided by Microsoft App Installer
- A writable project folder

Install Python manually and enable the Python launcher or add Python to `PATH`. Streakium supports Python 3.11 through 3.14 and recommends the latest stable Python 3.14 release. The installer uses that global Python installation and installs required packages to the current user's Python site.

Google Chrome is installed through `winget` when missing. ChromeDriver, Stockfish, FFmpeg, browser profile, logs, and scheduler state remain inside this repository.

### Installing Python on Windows

**Command-line (recommended):**
```powershell
winget install Python.Python.3.14
```
Then restart PowerShell and verify:
```powershell
python --version
```

**Manual:**  
1. Open [python.org/downloads/windows](https://www.python.org/downloads/windows/) in a browser.
2. Download the **latest stable 64-bit installer** (e.g. `python-3.14.x-amd64.exe`).
3. Run the installer.
4. At the bottom of the first page, **check "Add Python to PATH"**.
5. Click **"Install Now"** and let the installer finish.
6. Verify the installation as above.

If the `python` command is not found, restart PowerShell or add Python manually to `PATH` through System Environment Variables.

## Fast Setup

Open PowerShell and run:

```powershell
python --version
git clone https://github.com/Ren42377/streakium-windows.git
cd streakium-windows
.\install.cmd
notepad .\config.txt
.\run.cmd
```

Complete any requested logins in the visible Chrome window. Later runs can use `run.cmd` directly.

## Installation

1. Install the latest 64-bit Python from python.org.
2. During installation, enable the Python launcher or add Python to `PATH`.
3. Double-click `install.cmd`.
4. Edit `config.txt`.
5. Double-click `run.cmd`.
6. Complete any requested logins in the visible Chrome window.

The installer is safe to rerun. It also registers `Streakium Scheduler` in Windows Task Scheduler. If the repository is moved, rerun `install.cmd` so the task points to the new location.

## Configuration

```txt
tiktok=true
chess=true
duolingo=true
snapchat=true
browser.headless=true
tiktok.message=streak
tiktok.max_chats=1
chess.engine_time=0.1
snapchat.usernames=user1,user2
snapchat.camera_folder=assets
snapchat.camera_mode=random
schedule.enabled=false
schedule.time=09:00
```

`browser.headless=true` uses headless Chrome after login sessions exist. When a login expires, Streakium opens visible Chrome and waits for confirmation in the command window.

`snapchat.camera_mode` accepts `random` or `newest`. Supported source image types are JPG, PNG, WebP, and BMP.

`schedule.time` uses the Windows user's local timezone and 24-hour `HH:MM` format.

## Usage

Run every enabled platform:

```bat
run.cmd
```

Run one platform from Command Prompt:

```bat
run.cmd --platform tiktok
run.cmd --platform chess
run.cmd --platform duolingo
run.cmd --platform snapchat
```

Run one scheduler check manually:

```bat
schedule.cmd
```

The scheduled task checks once per minute while the user is logged in. The Python scheduler performs at most one daily run, catches up after a missed time on the same day, and creates up to three random retries for failed platforms. A lock prevents overlapping runs. Rerun `install.cmd` at least once every ten years to renew the task trigger.

## Local Data

All application-owned files are stored under `.streakium/`:

```text
.streakium/
├── auth/       Chrome profile and login sessions
├── logs/       Scheduler output
├── media/      Generated Snapchat camera video
├── state/      Scheduler state and lock
└── tools/      ChromeDriver, Stockfish, and FFmpeg
```

The entire directory is ignored by Git. Do not share it because the Chrome profile contains authenticated sessions.

Set the user environment variable `STREAKIUM_HOME`, then rerun `install.cmd` to move the runtime directory. The installer, manual runner, and scheduled task will use the same location.

## Troubleshooting

- Run `install.cmd` again after Chrome updates, moving the repository, or an interrupted installation.
- Run `py -3 --version` or `python --version` and confirm Python 3.11 through 3.14 is available.
- Close Chrome windows using the Streakium profile if Chrome reports that the profile is already in use.
- Check `.streakium\logs\scheduler.log` for scheduled-run output.
- Open Task Scheduler and verify that `Streakium Scheduler` is enabled.
- Use `browser.headless=false` while diagnosing page changes.
- If Snapchat cannot create its camera video, rerun the installer to restore FFmpeg.
- If Chess.com or Duolingo reports a missing engine, rerun the installer to restore Stockfish.

## Development

After installation:

```bat
py -3 -m pip install --user -r requirements-dev.txt
py -3 -m pytest
```

The automation selectors depend on live websites and still require manual smoke testing on Windows.
