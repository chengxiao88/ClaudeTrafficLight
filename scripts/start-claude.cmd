@echo off
setlocal
title Claude Code - TrafficLight
set APP=%LOCALAPPDATA%\ClaudeLight\app\ClaudeTrafficLight.exe
if exist "%APP%" start "" "%APP%"
claude %*
endlocal
