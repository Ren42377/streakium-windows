from pathlib import Path


def test_installer_keeps_runtime_local_and_registers_recurring_task():
    script = Path("install.ps1").read_text(encoding="utf-8")
    assert 'Join-Path $ProjectDir ".streakium"' in script
    assert 'Join-Path $RuntimeDir "venv"' in script
    assert 'Join-Path $RuntimeDir "tools"' in script
    assert "Get-VerifiedDownload" in script
    assert "New-ScheduledTaskTrigger" in script
    assert "RepetitionInterval" in script
    assert "RepetitionDuration" in script
    assert "LogonType Interactive" in script
    assert "MultipleInstances IgnoreNew" in script
    assert "[switch]$LoadOnly" in script
    assert "Invoke-NativeProbe" in script
    assert "Invoke-CheckedNativeCommand" in script
