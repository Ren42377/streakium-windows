param(
    [switch]$LoadOnly
)

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
$ToolsDir = Join-Path $RuntimeDir "tools"
$DownloadDir = Join-Path $RuntimeDir "downloads"
$TaskName = "Streakium Scheduler"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

function Invoke-NativeProbe {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )
    $previousErrorActionPreference = $ErrorActionPreference
    $nativePreferenceExists = Test-Path variable:PSNativeCommandUseErrorActionPreference
    if ($nativePreferenceExists) {
        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
    }
    try {
        $ErrorActionPreference = "Continue"
        if ($nativePreferenceExists) {
            $PSNativeCommandUseErrorActionPreference = $false
        }
        $output = & $FilePath @Arguments 2>$null
        $exitCode = $LASTEXITCODE
    } catch {
        return $null
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if ($nativePreferenceExists) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }
    if ($exitCode -ne 0 -or -not $output) {
        return $null
    }
    return ([string]($output | Select-Object -First 1)).Trim()
}

function Invoke-CheckedNativeCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$FailureMessage
    )
    $previousErrorActionPreference = $ErrorActionPreference
    $nativePreferenceExists = Test-Path variable:PSNativeCommandUseErrorActionPreference
    if ($nativePreferenceExists) {
        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
    }
    try {
        $ErrorActionPreference = "Continue"
        if ($nativePreferenceExists) {
            $PSNativeCommandUseErrorActionPreference = $false
        }
        & $FilePath @Arguments
        $exitCode = $LASTEXITCODE
    } catch {
        throw "$FailureMessage $($_.Exception.Message)"
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if ($nativePreferenceExists) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }
    if ($exitCode -ne 0) {
        throw "$FailureMessage Exit code: $exitCode."
    }
}

function Get-GlobalPython {
    param(
        [string]$LauncherCommand = "py.exe",
        [string]$PythonCommand = "python.exe",
        [AllowEmptyCollection()]
        [string[]]$CandidatePaths
    )
    $versionScript = "import sys; print(sys.executable if (3, 11) <= sys.version_info[:2] <= (3, 14) else '')"
    if (Get-Command $LauncherCommand -ErrorAction SilentlyContinue) {
        $path = Invoke-NativeProbe -FilePath $LauncherCommand -Arguments @(
            "-3",
            "-c",
            $versionScript
        )
        if ($path) {
            return $path
        }
    }
    if (Get-Command $PythonCommand -ErrorAction SilentlyContinue) {
        $result = Invoke-NativeProbe -FilePath $PythonCommand -Arguments @(
            "-c",
            $versionScript
        )
        if ($result) {
            return $result
        }
    }
    if ($null -eq $CandidatePaths) {
        $CandidatePaths = @(
            "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe",
            "$env:LOCALAPPDATA\Programs\Python\Python313\python.exe",
            "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
            "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe"
        )
    }
    foreach ($candidate in $CandidatePaths) {
        if ($candidate -and (Test-Path $candidate)) {
            $result = Invoke-NativeProbe -FilePath $candidate -Arguments @("-c", $versionScript)
            if ($result) {
                return $result
            }
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

if ($LoadOnly) {
    return
}

Set-Location $ProjectDir
New-Item -ItemType Directory -Force -Path $RuntimeDir, $ToolsDir, $DownloadDir | Out-Null

$python = Get-GlobalPython
if (-not $python) {
    throw "A supported global Python installation was not found. Install the latest 64-bit Python from python.org, enable the Python launcher or PATH option, then run install.cmd again."
}

$chrome = Get-ChromePath
if (-not $chrome) {
    Write-Step "Installing Google Chrome"
    Ensure-Winget
    Invoke-CheckedNativeCommand `
        -FilePath "winget.exe" `
        -Arguments @(
            "install",
            "--id",
            "Google.Chrome",
            "--exact",
            "--source",
            "winget",
            "--accept-package-agreements",
            "--accept-source-agreements"
        ) `
        -FailureMessage "Google Chrome installation failed."
    $chrome = Get-ChromePath
    if (-not $chrome) {
        throw "Google Chrome was installed but could not be found."
    }
}

Write-Step "Installing Python dependencies"
Invoke-CheckedNativeCommand `
    -FilePath $python `
    -Arguments @("-m", "pip", "install", "--user", "--disable-pip-version-check", "--upgrade", "pip", "setuptools") `
    -FailureMessage "pip and setuptools could not be upgraded."
Invoke-CheckedNativeCommand `
    -FilePath $python `
    -Arguments @("-m", "pip", "install", "--user", "--disable-pip-version-check", "-r", (Join-Path $ProjectDir "requirements.txt")) `
    -FailureMessage "Python dependencies could not be installed."

Install-Stockfish
Install-FFmpeg
Install-ChromeDriver -ChromePath $chrome

Write-Step "Validating installation"
Invoke-CheckedNativeCommand `
    -FilePath $python `
    -Arguments @("-c", "from ai_edge_litert.interpreter import Interpreter; import numpy; import selenium; import undetected_chromedriver") `
    -FailureMessage "Python dependency validation failed."
Invoke-CheckedNativeCommand `
    -FilePath $python `
    -Arguments @("-c", "from streakium.browser import find_chrome_binary; from streakium.runtime_paths import get_chromedriver_binary, get_ffmpeg_binary, get_stockfish_binary; assert find_chrome_binary(); assert get_chromedriver_binary(); assert get_ffmpeg_binary(); assert get_stockfish_binary()") `
    -FailureMessage "Streakium tool validation failed."

Write-Step "Registering Windows Task Scheduler"
Register-StreakiumTask

Remove-Item -Recurse -Force $DownloadDir -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "Installation complete."
Write-Host "Edit config.txt, then run run.cmd."
Write-Host "Move the repository only after rerunning install.cmd at its new location."
