$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($env:STREAKIUM_HOME) {
    if ([System.IO.Path]::IsPathRooted($env:STREAKIUM_HOME)) {
        $RuntimeDir = [System.IO.Path]::GetFullPath($env:STREAKIUM_HOME)
    } else {
        $RuntimeDir = [System.IO.Path]::GetFullPath((Join-Path $ProjectDir $env:STREAKIUM_HOME))
    }
} else {
    $RuntimeDir = Join-Path $ProjectDir ".streakium"
}
$VenvDir = Join-Path $RuntimeDir "venv"
$ToolsDir = Join-Path $RuntimeDir "tools"
$DownloadDir = Join-Path $RuntimeDir "downloads"
$TaskName = "Streakium Scheduler"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

function Get-Python311 {
    if (Get-Command py.exe -ErrorAction SilentlyContinue) {
        $path = & py.exe -3.11 -c "import sys; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and $path) {
            return $path.Trim()
        }
    }
    if (Get-Command python.exe -ErrorAction SilentlyContinue) {
        $result = & python.exe -c "import sys; print(sys.executable if sys.version_info[:2] == (3, 11) else '')"
        if ($LASTEXITCODE -eq 0 -and $result) {
            return $result.Trim()
        }
    }
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "$env:PROGRAMFILES\Python311\python.exe",
        "${env:PROGRAMFILES(X86)}\Python311\python.exe"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }
    return $null
}

function Ensure-Winget {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "winget was not found. Install App Installer from Microsoft Store and run install.cmd again."
    }
}

function Get-ChromePath {
    $candidates = @(
        "$env:PROGRAMFILES\Google\Chrome\Application\chrome.exe",
        "${env:PROGRAMFILES(X86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }
    return $null
}

function Get-VerifiedDownload {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$ExpectedSha256
    )
    Invoke-WebRequest -Uri $Url -OutFile $Destination
    $actual = (Get-FileHash -Algorithm SHA256 -Path $Destination).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedSha256.ToLowerInvariant()) {
        Remove-Item -Force $Destination
        throw "SHA-256 verification failed for $Url."
    }
}

function Install-Stockfish {
    $destination = Join-Path $ToolsDir "stockfish"
    $existing = Get-ChildItem $destination -Filter "stockfish*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) {
        Write-Host "Stockfish already exists at $($existing.FullName)."
        return
    }
    Write-Step "Downloading Stockfish"
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/official-stockfish/Stockfish/releases/latest"
    $asset = $release.assets | Where-Object {
        $_.name -eq "stockfish-windows-x86-64.zip"
    } | Select-Object -First 1
    if (-not $asset) {
        throw "A compatible Stockfish Windows x64 archive was not found."
    }
    $digestMatch = [regex]::Match([string]$asset.digest, "^sha256:([0-9a-fA-F]{64})$")
    if (-not $digestMatch.Success) {
        throw "The Stockfish release did not provide a SHA-256 digest."
    }
    $archive = Join-Path $DownloadDir $asset.name
    Get-VerifiedDownload -Url $asset.browser_download_url -Destination $archive -ExpectedSha256 $digestMatch.Groups[1].Value
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Expand-Archive -Force -Path $archive -DestinationPath $destination
}

function Install-FFmpeg {
    $destination = Join-Path $ToolsDir "ffmpeg"
    $existing = Get-ChildItem $destination -Filter "ffmpeg.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existing) {
        Write-Host "FFmpeg already exists at $($existing.FullName)."
        return
    }
    Write-Step "Downloading FFmpeg"
    $archiveUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
    $checksumUrl = "$archiveUrl.sha256"
    $checksumText = (Invoke-WebRequest -Uri $checksumUrl).Content
    $match = [regex]::Match($checksumText, "[0-9a-fA-F]{64}")
    if (-not $match.Success) {
        throw "The FFmpeg SHA-256 checksum could not be read."
    }
    $archive = Join-Path $DownloadDir "ffmpeg-release-essentials.zip"
    Get-VerifiedDownload -Url $archiveUrl -Destination $archive -ExpectedSha256 $match.Value
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Expand-Archive -Force -Path $archive -DestinationPath $destination
}

function Install-ChromeDriver {
    param([string]$ChromePath)
    Write-Step "Installing matching ChromeDriver"
    $chromeVersion = (Get-Item $ChromePath).VersionInfo.ProductVersion
    if (-not $chromeVersion) {
        throw "The installed Chrome version could not be detected."
    }
    $parts = $chromeVersion.Split(".")
    $build = "$($parts[0]).$($parts[1]).$($parts[2])"
    $manifest = Invoke-RestMethod -Uri "https://googlechromelabs.github.io/chrome-for-testing/latest-patch-versions-per-build-with-downloads.json"
    $entry = $manifest.builds.$build
    if (-not $entry) {
        throw "ChromeDriver was not found for Chrome build $build."
    }
    $download = $entry.downloads.chromedriver | Where-Object {
        $_.platform -eq "win64"
    } | Select-Object -First 1
    if (-not $download) {
        throw "ChromeDriver win64 was not found for Chrome build $build."
    }
    $destination = Join-Path $ToolsDir "chromedriver"
    $versionFile = Join-Path $destination "version.txt"
    $driver = Get-ChildItem $destination -Filter "chromedriver.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $installedVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "" }
    if ($driver -and $installedVersion -eq $entry.version) {
        Write-Host "ChromeDriver $installedVersion is already installed."
        return
    }
    $archive = Join-Path $DownloadDir "chromedriver-win64.zip"
    Invoke-WebRequest -Uri $download.url -OutFile $archive
    if (Test-Path $destination) {
        Remove-Item -Recurse -Force $destination
    }
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Expand-Archive -Force -Path $archive -DestinationPath $destination
    Set-Content -Path $versionFile -Encoding ASCII -Value $entry.version
}

function Register-StreakiumTask {
    $scheduleCmd = Join-Path $ProjectDir "schedule.cmd"
    $action = New-ScheduledTaskAction -Execute $env:ComSpec -Argument "/d /c `"$scheduleCmd`"" -WorkingDirectory $ProjectDir
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
        -RepetitionInterval (New-TimeSpan -Minutes 1) `
        -RepetitionDuration (New-TimeSpan -Days 3650)
    $principal = New-ScheduledTaskPrincipal `
        -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
        -LogonType Interactive `
        -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet `
        -MultipleInstances IgnoreNew `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 6)
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Runs Streakium schedule checks once per minute while the user is logged in." `
        -Force | Out-Null
}

Set-Location $ProjectDir
New-Item -ItemType Directory -Force -Path $RuntimeDir, $ToolsDir, $DownloadDir | Out-Null

$python = Get-Python311
if (-not $python) {
    Write-Step "Installing Python 3.11"
    Ensure-Winget
    winget install --id Python.Python.3.11 --exact --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "Python 3.11 installation failed."
    }
    $python = Get-Python311
    if (-not $python) {
        throw "Python 3.11 was installed but could not be found. Restart Windows and run install.cmd again."
    }
}

$chrome = Get-ChromePath
if (-not $chrome) {
    Write-Step "Installing Google Chrome"
    Ensure-Winget
    winget install --id Google.Chrome --exact --source winget --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "Google Chrome installation failed."
    }
    $chrome = Get-ChromePath
    if (-not $chrome) {
        throw "Google Chrome was installed but could not be found."
    }
}

Write-Step "Creating local Python environment"
if (-not (Test-Path (Join-Path $VenvDir "Scripts\python.exe"))) {
    & $python -m venv $VenvDir
}
$venvPython = Join-Path $VenvDir "Scripts\python.exe"
& $venvPython -m pip install --disable-pip-version-check --upgrade pip setuptools
& $venvPython -m pip install --disable-pip-version-check -r (Join-Path $ProjectDir "requirements.txt")

Install-Stockfish
Install-FFmpeg
Install-ChromeDriver -ChromePath $chrome

Write-Step "Validating installation"
& $venvPython -c "from ai_edge_litert.interpreter import Interpreter; import numpy; import selenium; import undetected_chromedriver"
& $venvPython -c "from streakium.browser import find_chrome_binary; from streakium.runtime_paths import get_chromedriver_binary, get_ffmpeg_binary, get_stockfish_binary; assert find_chrome_binary(); assert get_chromedriver_binary(); assert get_ffmpeg_binary(); assert get_stockfish_binary()"

Write-Step "Registering Windows Task Scheduler"
Register-StreakiumTask

Remove-Item -Recurse -Force $DownloadDir -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Installation complete."
Write-Host "Edit config.txt, then run run.cmd."
Write-Host "Move the repository only after rerunning install.cmd at its new location."
