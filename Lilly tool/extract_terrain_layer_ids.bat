@echo off
setlocal

if "%~1"=="" (
    echo Drag and drop a .terrain file onto this batch file.
    echo.
    echo To also update config:
    echo   extract_terrain_layer_ids.bat your_file.terrain --update-config
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
where python >nul 2>nul
if %errorlevel%==0 (
    python "%SCRIPT_DIR%extract_terrain_layer_ids.py" %*
) else (
    py "%SCRIPT_DIR%extract_terrain_layer_ids.py" %*
)
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
pause
