$ErrorActionPreference = "Stop"

. "$PSScriptRoot\..\install.ps1" -LoadOnly

$originalPreference = $ErrorActionPreference
$temporaryDirectory = Join-Path $env:TEMP "streakium-installer-tests-$PID"
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
$failingLauncher = Join-Path $temporaryDirectory "py.exe.cmd"
$successfulLauncher = Join-Path $temporaryDirectory "python-success.cmd"
$missingPython = Join-Path $temporaryDirectory "missing-python.exe"

try {
    Set-Content -Path $failingLauncher -Encoding ASCII -Value @(
        "@echo off",
        "echo No suitable Python runtime found 1>&2",
        "exit /b 1"
    )
    Set-Content -Path $successfulLauncher -Encoding ASCII -Value @(
        "@echo off",
        "echo C:\Python311\python.exe",
        "exit /b 0"
    )

    $missingRuntime = Get-Python311 `
        -LauncherCommand $failingLauncher `
        -PythonCommand $missingPython `
        -CandidatePaths @()
    if ($null -ne $missingRuntime) {
        throw "A missing Python 3.11 runtime must return null."
    }
    if ($ErrorActionPreference -ne $originalPreference) {
        throw "The Python probe did not restore ErrorActionPreference."
    }

    $runtime = Get-Python311 `
        -LauncherCommand $successfulLauncher `
        -PythonCommand $missingPython `
        -CandidatePaths @()
    if ($runtime -ne "C:\Python311\python.exe") {
        throw "A successful Python probe did not return the runtime path."
    }
} finally {
    Remove-Item -Recurse -Force $temporaryDirectory -ErrorAction SilentlyContinue
}

Write-Host "Installer PowerShell regression tests passed."
