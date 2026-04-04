@echo off
setlocal

if "%~1"=="" (
    echo .scene 파일을 이 배치 파일에 드래그 앤 드롭하세요.
    pause
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
where python >nul 2>nul
if %errorlevel%==0 (
    python "%SCRIPT_DIR%scene_apply_config.py" "%~1"
) else (
    py "%SCRIPT_DIR%scene_apply_config.py" "%~1"
)
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
pause
