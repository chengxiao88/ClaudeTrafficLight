param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# ClaudeTrafficLight hook installer.
# Compatible with Windows PowerShell 5.1 and PowerShell 7+.
# Generates Hook commands with the real signal.ps1 path at runtime and merges
# them into the user's Claude Code settings. It is idempotent: if the current
# settings already point to this signal.ps1, it exits without rewriting.

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$settingsFile = Join-Path $claudeDir "settings.json"
$signalScript = Join-Path $PSScriptRoot "signal.ps1"

if (-not (Test-Path $signalScript)) {
    throw "signal.ps1 not found: $signalScript"
}

New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

function New-EmptyJsonObject {
    return [pscustomobject]@{}
}

function Set-JsonProperty {
    param(
        [Parameter(Mandatory = $true)] [object]$Object,
        [Parameter(Mandatory = $true)] [string]$Name,
        [Parameter(Mandatory = $true)] $Value
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    }
    else {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
}

function ConvertTo-NormalizedPathText {
    param([Parameter(Mandatory = $true)] [string]$Path)
    return ([System.IO.Path]::GetFullPath($Path)).TrimEnd('\')
}

function Test-SettingsAlreadyInstalled {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$ExpectedSignalScript
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    $raw = Get-Content -Path $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $false
    }

    try {
        $null = $raw | ConvertFrom-Json
    }
    catch {
        return $false
    }

    $expected = ConvertTo-NormalizedPathText -Path $ExpectedSignalScript
    $normalizedRaw = $raw -replace '\\\\', '\'
    return ($normalizedRaw -like "*$expected*")
}

function Read-ClaudeSettings {
    param([Parameter(Mandatory = $true)] [string]$Path)

    if (-not (Test-Path $Path)) {
        return New-EmptyJsonObject
    }

    $raw = Get-Content -Path $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return New-EmptyJsonObject
    }

    try {
        $settings = $raw | ConvertFrom-Json
        if ($null -eq $settings) {
            return New-EmptyJsonObject
        }
        return $settings
    }
    catch {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backup = "$Path.invalid-$timestamp.bak"
        Copy-Item -Path $Path -Destination $backup -Force
        Write-Warning "Existing Claude settings.json is not valid JSON. Backed it up to: $backup"
        return New-EmptyJsonObject
    }
}

function New-ClaudeTrafficLightHook {
    param(
        [Parameter(Mandatory = $false)] [string]$Matcher = "",
        [Parameter(Mandatory = $true)] [string]$State,
        [Parameter(Mandatory = $true)] [string]$SignalScriptPath
    )

    # Backtick-quote the script path for PowerShell. This keeps paths with spaces working.
    $escapedSignalScriptPath = $SignalScriptPath.Replace('"', '`"')
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$escapedSignalScriptPath`" $State"

    return [pscustomobject]@{
        matcher = $Matcher
        hooks   = @(
            [pscustomobject]@{
                type    = "command"
                command = $command
            }
        )
    }
}

function Test-IsClaudeTrafficLightHook {
    param([Parameter(Mandatory = $false)] $HookEntry)

    if ($null -eq $HookEntry) {
        return $false
    }

    foreach ($hook in @($HookEntry.hooks)) {
        $command = [string]$hook.command
        if ($command -match "signal\.ps1") {
            return $true
        }
    }

    return $false
}

function Write-TextFileUtf8NoBom {
    param(
        [Parameter(Mandatory = $true)] [string]$TargetPath,
        [Parameter(Mandatory = $true)] [string]$Content
    )

    # Use direct .NET APIs instead of Set-Content so Windows PowerShell 5.1
    # and PowerShell 7 write identical UTF-8 without BOM.
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($TargetPath, $Content, $utf8NoBom)
}

if (-not $Force) {
    if (Test-SettingsAlreadyInstalled -Path $settingsFile -ExpectedSignalScript $signalScript) {
        Write-Host "ClaudeTrafficLight hooks already installed: $settingsFile"
        Write-Host "Signal script: $signalScript"
        return
    }
}

$settings = Read-ClaudeSettings -Path $settingsFile

if (-not ($settings.PSObject.Properties.Name -contains "hooks") -or $null -eq $settings.hooks) {
    Set-JsonProperty -Object $settings -Name "hooks" -Value (New-EmptyJsonObject)
}

$hooksRoot = $settings.hooks

$hookDefinitions = @(
    @{ Event = "SessionStart";       Matcher = "";                  State = "session_start" },
    @{ Event = "UserPromptSubmit";   Matcher = "";                  State = "thinking" },
    @{ Event = "PreToolUse";         Matcher = "";                  State = "working" },
    @{ Event = "PostToolUse";        Matcher = "";                  State = "thinking" },
    @{ Event = "PostToolUseFailure"; Matcher = "";                  State = "error" },
    @{ Event = "PostToolBatch";      Matcher = "";                  State = "thinking" },
    @{ Event = "PermissionRequest";  Matcher = "";                  State = "permission" },
    @{ Event = "Stop";               Matcher = "";                  State = "done" },
    @{ Event = "StopFailure";        Matcher = "";                  State = "error" },
    @{ Event = "SessionEnd";         Matcher = "";                  State = "off" },
    @{ Event = "Notification";       Matcher = "permission_prompt"; State = "permission" },
    @{ Event = "Notification";       Matcher = "idle_prompt";       State = "done" }
)

$newHooksByEvent = [ordered]@{}
foreach ($definition in $hookDefinitions) {
    $eventName = [string]$definition.Event
    if (-not $newHooksByEvent.Contains($eventName)) {
        $newHooksByEvent[$eventName] = @()
    }

    $newHook = New-ClaudeTrafficLightHook `
        -Matcher ([string]$definition.Matcher) `
        -State ([string]$definition.State) `
        -SignalScriptPath $signalScript

    $newHooksByEvent[$eventName] = @($newHooksByEvent[$eventName]) + $newHook
}

foreach ($eventName in $newHooksByEvent.Keys) {
    $existingNonTrafficLightHooks = @()

    if ($hooksRoot.PSObject.Properties.Name -contains $eventName) {
        foreach ($existingHook in @($hooksRoot.$eventName)) {
            if (-not (Test-IsClaudeTrafficLightHook -HookEntry $existingHook)) {
                $existingNonTrafficLightHooks += $existingHook
            }
        }
    }

    $mergedHooks = @($existingNonTrafficLightHooks) + @($newHooksByEvent[$eventName])
    Set-JsonProperty -Object $hooksRoot -Name $eventName -Value ([object[]]$mergedHooks)
}

if (Test-Path $settingsFile) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$settingsFile.bak-$timestamp"
    Copy-Item -Path $settingsFile -Destination $backupPath -Force
}

$json = $settings | ConvertTo-Json -Depth 100

# Verify JSON before writing. This prevents a broken settings.json from replacing
# the user's existing Claude configuration.
$null = $json | ConvertFrom-Json

Write-TextFileUtf8NoBom -TargetPath $settingsFile -Content $json

# Verify the file after writing as well.
$verifyRaw = [System.IO.File]::ReadAllText($settingsFile)
$null = $verifyRaw | ConvertFrom-Json

Write-Host "ClaudeTrafficLight hooks installed: $settingsFile"
Write-Host "Signal script: $signalScript"
