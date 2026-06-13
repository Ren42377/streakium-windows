@echo off
setlocal
cd /d "%~dp0"
if defined STREAKIUM_HOME (
    set "RUNTIME=%STREAKIUM_HOME%"
) else (
    set "RUNTIME=%~dp0.streakium"
)
set "PYTHON=%RUNTIME%\venv\Scripts\python.exe"
if not exist "%PYTHON%" (
    echo Streakium is not installed. Run install.cmd first.
    pause
    exit /b 1
)
"%PYTHON%" -m streakium %*
set "EXIT_CODE=%ERRORLEVEL%"
echo.
pause
exit /b %EXIT_CODE%
