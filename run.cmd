@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
where py.exe >nul 2>&1
if not errorlevel 1 (
    py.exe -3 -c "import sys; raise SystemExit(0 if (3, 11) <= sys.version_info[:2] <= (3, 14) else 1)" >nul 2>&1
    if not errorlevel 1 (
        py.exe -3 -m streakium %*
        set "EXIT_CODE=!ERRORLEVEL!"
        echo.
        pause
        exit /b !EXIT_CODE!
    )
)
where python.exe >nul 2>&1
if errorlevel 1 (
    echo A supported global Python installation was not found. Install the latest 64-bit Python from python.org.
    pause
    exit /b 1
)
python.exe -c "import sys; raise SystemExit(0 if (3, 11) <= sys.version_info[:2] <= (3, 14) else 1)" >nul 2>&1
if errorlevel 1 (
    echo Python 3.11 through 3.14 is required. Install the latest 64-bit Python from python.org.
    pause
    exit /b 1
)
python.exe -m streakium %*
set "EXIT_CODE=%ERRORLEVEL%"
echo.
pause
exit /b %EXIT_CODE%
