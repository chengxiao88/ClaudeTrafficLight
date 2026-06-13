@echo off
setlocal
title Claude Code - TrafficLight

rem If this script is being run from the source tree but an installed copy exists,
rem delegate to the installed copy. This prevents Hooks from being rewritten with
rem the source-tree signal.ps1 path.
set "THIS=%~f0"
set "INSTALLED=%LOCALAPPDATA%\ClaudeLight\scripts\start-claude.cmd"
if exist "%INSTALLED%" (
    if /I not "%THIS%"=="%INSTALLED%" (
        call "%INSTALLED%" %*
        exit /b %ERRORLEVEL%
    )
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ensure-hooks.ps1"
if errorlevel 1 (
    echo [ClaudeTrafficLight] Failed to install Claude hooks.
    pause
    exit /b 1
)

set "APP=%~dp0..\app\ClaudeTrafficLight.exe"
for %%I in ("%APP%") do set "APP=%%~fI"
if not exist "%APP%" set "APP=%LOCALAPPDATA%\ClaudeLight\app\ClaudeTrafficLight.exe"

if exist "%APP%" (
    start "" "%APP%"
) else (
    echo [ClaudeTrafficLight] Warning: ClaudeTrafficLight.exe was not found.
    echo [ClaudeTrafficLight] Hooks can still write status.json, but the desktop light will not appear.
    echo [ClaudeTrafficLight] Install .NET 8 SDK and rerun scripts\install.ps1 to build the app.
)

claude %*
endlocal
