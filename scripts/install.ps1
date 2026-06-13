param(
    [string]$InstallRoot = "$env:LOCALAPPDATA\ClaudeLight"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $root
$project = Join-Path $repoRoot "src\ClaudeTrafficLight\ClaudeTrafficLight.csproj"
$appDir = Join-Path $InstallRoot "app"
$scriptsDir = Join-Path $InstallRoot "scripts"

New-Item -ItemType Directory -Force -Path $appDir, $scriptsDir | Out-Null

Copy-Item (Join-Path $repoRoot "scripts\signal.ps1") (Join-Path $scriptsDir "signal.ps1") -Force
Copy-Item (Join-Path $repoRoot "scripts\ensure-hooks.ps1") (Join-Path $scriptsDir "ensure-hooks.ps1") -Force
Copy-Item (Join-Path $repoRoot "scripts\start-claude.cmd") (Join-Path $scriptsDir "start-claude.cmd") -Force
Copy-Item (Join-Path $repoRoot "scripts\manual-test.ps1") (Join-Path $scriptsDir "manual-test.ps1") -Force

$builtApp = $false

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Warning "dotnet was not found. Scripts and Hooks will be installed, but ClaudeTrafficLight.exe cannot be built. Install .NET 8 SDK and rerun this script."
}
else {
    $sdks = & dotnet --list-sdks 2>$null
    if ([string]::IsNullOrWhiteSpace(($sdks | Out-String).Trim())) {
        Write-Warning "No .NET SDKs were found. Scripts and Hooks will be installed, but ClaudeTrafficLight.exe cannot be built. Install .NET 8 SDK and rerun this script."
    }
    else {
        & dotnet publish $project -c Release -r win-x64 -p:PublishSingleFile=true -p:SelfContained=false -o $appDir
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet publish failed with exit code $LASTEXITCODE."
        }
        $builtApp = Test-Path (Join-Path $appDir "ClaudeTrafficLight.exe")
    }
}

$template = Get-Content (Join-Path $repoRoot "hooks\settings.template.json") -Raw
$signal = (Join-Path $scriptsDir "signal.ps1").Replace("\", "\\")
$generated = $template.Replace("__SIGNAL_SCRIPT__", $signal)
$generatedPath = Join-Path $InstallRoot "settings.generated.json"
Set-Content -Path $generatedPath -Value $generated -Encoding UTF8

& (Join-Path $scriptsDir "ensure-hooks.ps1") -Force

Write-Host "Install complete: $InstallRoot"
Write-Host "Claude Hooks reference config generated: $generatedPath"
Write-Host "Hooks have been installed into: $HOME\.claude\settings.json"
Write-Host "Suggested launch: $scriptsDir\start-claude.cmd"

if (-not $builtApp) {
    Write-Warning "ClaudeTrafficLight.exe was not built because .NET 8 SDK is missing or unavailable. The desktop light window will not appear until the app is built."
}
