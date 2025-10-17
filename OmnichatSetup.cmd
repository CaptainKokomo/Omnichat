@echo off
setlocal
set HTA=%~dp0OmnichatSetup.hta
if exist "%HTA%" (
  mshta.exe "%HTA%"
) else (
  set SCRIPT=%~dp0Omnichat.install.ps1
  if not exist "%SCRIPT%" (
    echo Unable to locate Omnichat setup files.
    pause
    exit /b 1
  )
  PowerShell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
  if errorlevel 1 (
    echo.
    echo The installer reported an error. Review the messages above.
    pause
  )
)
endlocal
