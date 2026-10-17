@echo off
rem Drawbridge one-click launcher for Windows.
rem
rem Keep this file ASCII-only. Non-ASCII text in a .bat gets mangled when the
rem console codepage is not UTF-8 (e.g. GBK on Chinese Windows) and cmd.exe
rem then tries to run the garbage as a command.
rem
rem pushd is required, not cd: it maps a temporary drive letter, which is the
rem only way cmd.exe can use a UNC path (\\server\share\...) as a directory.

pushd "%~dp0"
if errorlevel 1 (
    echo.
    echo Cannot enter the project folder: %~dp0
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-windows.ps1" %*
set "RC=%ERRORLEVEL%"

popd
if not "%RC%"=="0" pause
exit /b %RC%
