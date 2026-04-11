@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
where python >nul 2>nul
if %errorlevel%==0 (
    python "%SCRIPT_DIR%replace_scene_strings.py"
) else (
    py "%SCRIPT_DIR%replace_scene_strings.py"
)
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
pause
