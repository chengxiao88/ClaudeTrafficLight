param(
    [Parameter(Mandatory = $false)]
    [string]$State = "idle"
)

# Claude Traffic Light signal bridge.
# Design rule: never print to stdout/stderr unless you intentionally want Claude Code to see a hook error.
$ErrorActionPreference = "SilentlyContinue"

function Normalize-State([string]$s) {
    if ($null -eq $s) { $s = "" }
    switch ($s.ToLowerInvariant()) {
        "session_start" { return "idle" }
        "idle" { return "idle" }
        "done" { return "done" }
        "thinking" { return "thinking" }
        "working" { return "working" }
        "permission" { return "permission" }
        "error" { return "error" }
        "off" { return "off" }
        default { return "idle" }
    }
}

try {
    $baseDir = Join-Path $env:LOCALAPPDATA "ClaudeLight"
    $sessionsDir = Join-Path $baseDir "sessions"
    $statusFile = Join-Path $baseDir "status.json"
    New-Item -ItemType Directory -Force -Path $baseDir, $sessionsDir | Out-Null

    $appExe = Join-Path $baseDir "app\ClaudeTrafficLight.exe"
    if (Test-Path $appExe) {
        $running = Get-Process -Name "ClaudeTrafficLight" -ErrorAction SilentlyContinue
        if (-not $running) {
            Start-Process -FilePath $appExe | Out-Null
        }
    }

    $raw = [Console]::In.ReadToEnd()
    $ctx = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try { $ctx = $raw | ConvertFrom-Json } catch { $ctx = $null }
    }

    $normalizedState = Normalize-State $State
    $sessionId = ""
    if ($ctx -and $ctx.session_id) { $sessionId = [string]$ctx.session_id }
    if ([string]::IsNullOrWhiteSpace($sessionId)) { $sessionId = "default" }
    $safeSessionId = ($sessionId -replace '[^a-zA-Z0-9_.-]', '_')

    $payload = [ordered]@{
        state             = $normalizedState
        time              = (Get-Date).ToString("o")
        session_id        = $sessionId
        cwd               = if ($ctx -and $ctx.cwd) { [string]$ctx.cwd } else { "" }
        hook_event_name   = if ($ctx -and $ctx.hook_event_name) { [string]$ctx.hook_event_name } else { "" }
        tool_name         = if ($ctx -and $ctx.tool_name) { [string]$ctx.tool_name } else { "" }
        notification_type = if ($ctx -and $ctx.notification_type) { [string]$ctx.notification_type } else { "" }
        source            = if ($ctx -and $ctx.source) { [string]$ctx.source } else { "" }
    }

    $json = $payload | ConvertTo-Json -Compress
    $tmp = "$statusFile.tmp"
    Set-Content -Path $tmp -Value $json -Encoding UTF8
    Move-Item -Path $tmp -Destination $statusFile -Force

    $sessionFile = Join-Path $sessionsDir "$safeSessionId.json"
    Set-Content -Path "$sessionFile.tmp" -Value $json -Encoding UTF8
    Move-Item -Path "$sessionFile.tmp" -Destination $sessionFile -Force
}
catch {
    # Stay silent; hook failures should not interrupt Claude workflow.
}

exit 0
