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
- Internet access during installation
- `winget`, provided by Microsoft App Installer
- A writable project folder

Python 3.11 and Google Chrome are installed through `winget` when missing. The Python environment, ChromeDriver, Stockfish, FFmpeg, browser profile, logs, and scheduler state remain inside this repository.

## Fast Setup

Open PowerShell and run:

```powershell
git clone https://github.com/Ren42377/streakium-windows.git
cd streakium-windows
.\install.cmd
notepad .\config.txt
.\run.cmd
```

Complete any requested logins in the visible Chrome window. Later runs can use `run.cmd` directly.

## Installation

1. Double-click `install.cmd`.
2. Edit `config.txt`.
3. Double-click `run.cmd`.
4. Complete any requested logins in the visible Chrome window.

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
├── tools/      ChromeDriver, Stockfish, and FFmpeg
└── venv/       Local Python environment
```

The entire directory is ignored by Git. Do not share it because the Chrome profile contains authenticated sessions.

Set the user environment variable `STREAKIUM_HOME`, then rerun `install.cmd` to move the complete runtime directory. The installer, manual runner, and scheduled task will use the same location.

## Troubleshooting

- Run `install.cmd` again after Chrome updates, moving the repository, or an interrupted installation.
- Close Chrome windows using the Streakium profile if Chrome reports that the profile is already in use.
- Check `.streakium\logs\scheduler.log` for scheduled-run output.
- Open Task Scheduler and verify that `Streakium Scheduler` is enabled.
- Use `browser.headless=false` while diagnosing page changes.
- If Snapchat cannot create its camera video, rerun the installer to restore FFmpeg.
- If Chess.com or Duolingo reports a missing engine, rerun the installer to restore Stockfish.

## Development

After installation:

```bat
.streakium\venv\Scripts\python.exe -m pip install -r requirements-dev.txt
.streakium\venv\Scripts\python.exe -m pytest
```

The automation selectors depend on live websites and still require manual smoke testing on Windows.
