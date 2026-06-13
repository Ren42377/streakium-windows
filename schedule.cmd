@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
if defined STREAKIUM_HOME (set "RUNTIME=%STREAKIUM_HOME%") else (set "RUNTIME=%~dp0.streakium")
set "LOG_DIR=%RUNTIME%\logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
where py.exe >nul 2>&1
if not errorlevel 1 (
    py.exe -3 -c "import sys; raise SystemExit(0 if (3, 11) <= sys.version_info[:2] <= (3, 14) else 1)" >nul 2>&1
    if not errorlevel 1 (
        echo [%DATE% %TIME%] Scheduler check started.>>"%LOG_DIR%\scheduler.log"
        py.exe -3 -m streakium.scheduler >>"%LOG_DIR%\scheduler.log" 2>&1
        exit /b !ERRORLEVEL!
    )
)
where python.exe >nul 2>&1
if errorlevel 1 (
    echo [%DATE% %TIME%] A supported global Python installation was not found.>>"%LOG_DIR%\scheduler.log"
    exit /b 1
)
python.exe -c "import sys; raise SystemExit(0 if (3, 11) <= sys.version_info[:2] <= (3, 14) else 1)" >nul 2>&1
if errorlevel 1 (
    echo [%DATE% %TIME%] Python 3.11 through 3.14 is required.>>"%LOG_DIR%\scheduler.log"
    exit /b 1
)
echo [%DATE% %TIME%] Scheduler check started.>>"%LOG_DIR%\scheduler.log"
python.exe -m streakium.scheduler >>"%LOG_DIR%\scheduler.log" 2>&1
exit /b %ERRORLEVEL%
