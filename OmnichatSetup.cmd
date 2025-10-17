@echo off
setlocal
set SCRIPT=%~dp0Omnichat.install.ps1
if not exist "%SCRIPT%" (
  echo Unable to locate Omnichat.install.ps1 next to this setup.
  pause
  exit /b 1
)
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
if errorlevel 1 (
  echo.
  echo The installer reported an error. Review the messages above.
  pause
)
endlocal
