param(
    [string]$InstallRoot = "$env:LOCALAPPDATA\ClaudeLight"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $root
$project = Join-Path $repoRoot "src\ClaudeTrafficLight\ClaudeTrafficLight.csproj"
$appDir = Join-Path $InstallRoot "app"
$scriptsDir = Join-Path $InstallRoot "scripts"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "dotnet not found. Please install .NET 8 SDK first."
}

New-Item -ItemType Directory -Force -Path $appDir, $scriptsDir | Out-Null

dotnet publish $project -c Release -r win-x64 -p:PublishSingleFile=true -p:SelfContained=false -o $appDir
Copy-Item (Join-Path $repoRoot "scripts\signal.ps1") (Join-Path $scriptsDir "signal.ps1") -Force
Copy-Item (Join-Path $repoRoot "scripts\start-claude.cmd") (Join-Path $scriptsDir "start-claude.cmd") -Force

$template = Get-Content (Join-Path $repoRoot "hooks\settings.template.json") -Raw
$signal = (Join-Path $scriptsDir "signal.ps1").Replace("\", "\\")
$generated = $template.Replace("__SIGNAL_SCRIPT__", $signal)
$generatedPath = Join-Path $InstallRoot "settings.generated.json"
Set-Content -Path $generatedPath -Value $generated -Encoding UTF8

Write-Host "Install complete: $InstallRoot"
Write-Host "Claude Hooks config template generated: $generatedPath"
Write-Host "Merge the hooks node into: $HOME\.claude\settings.json"
Write-Host "Suggested launch: $scriptsDir\start-claude.cmd"