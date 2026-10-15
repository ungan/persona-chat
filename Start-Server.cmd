@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Start.ps1" -ServerOnly
if errorlevel 1 pause
