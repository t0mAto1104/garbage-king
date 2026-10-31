@echo off
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel% equ 0 (
  py -3 tools\dev.py run
) else (
  python tools\dev.py run
)
if errorlevel 1 pause
