@echo off
setlocal
title Claude Code - TrafficLight
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ensure-hooks.ps1"
set APP=%LOCALAPPDATA%\ClaudeLight\app\ClaudeTrafficLight.exe
if exist "%APP%" start "" "%APP%"
claude %*
endlocal
