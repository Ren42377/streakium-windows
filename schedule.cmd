@echo off
setlocal
cd /d "%~dp0"
if defined STREAKIUM_HOME (
    set "RUNTIME=%STREAKIUM_HOME%"
) else (
    set "RUNTIME=%~dp0.streakium"
)
set "PYTHON=%RUNTIME%\venv\Scripts\python.exe"
set "LOG_DIR=%RUNTIME%\logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if not exist "%PYTHON%" (
    echo [%DATE% %TIME%] Streakium is not installed. Run install.cmd first.>>"%LOG_DIR%\scheduler.log"
    exit /b 1
)
echo [%DATE% %TIME%] Scheduler check started.>>"%LOG_DIR%\scheduler.log"
"%PYTHON%" -m streakium.scheduler >>"%LOG_DIR%\scheduler.log" 2>&1
exit /b %ERRORLEVEL%
