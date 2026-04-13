@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

echo Missing workshop zip:
"%POWERSHELL_EXE%" -NoProfile -Command "& python '%SCRIPT_DIR%compare_workshop_mod_archives.py' --list-missing-only"
echo.
echo Different from workshop zip:
"%POWERSHELL_EXE%" -NoProfile -Command "& python '%SCRIPT_DIR%compare_workshop_mod_archives.py' --list-different-with-files"

echo.
pause
