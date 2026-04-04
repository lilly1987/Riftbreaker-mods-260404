@echo off
setlocal

if "%~1"=="" (
    echo Drag and drop a .terrain file onto this batch file.
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
where python >nul 2>nul
if %errorlevel%==0 (
    python "%SCRIPT_DIR%terrain_apply_config.py" "%~1"
) else (
    py "%SCRIPT_DIR%terrain_apply_config.py" "%~1"
)
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
pause
