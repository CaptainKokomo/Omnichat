import os
import json
import textwrap

INSTALLER_NAME = 'OmniChat_install.bat'
APP_ROOT = 'app'

FILES = []
for root, _, files in os.walk(APP_ROOT):
    for name in sorted(files):
        path = os.path.join(root, name)
        rel = os.path.relpath(path, APP_ROOT)
        with open(path, 'r', encoding='utf-8') as handle:
            lines = handle.read().splitlines()
        FILES.append((rel.replace('\\', '/'), lines))


def escape_line(line: str) -> str:
    if line == '':
        return 'echo.'
    escaped = line
    replacements = [
        ('^', '^^'),
        ('&', '^&'),
        ('|', '^|'),
        ('>', '^>'),
        ('<', '^<'),
        ('(', '^('),
        (')', '^)'),
        ('%', '%%'),
        ('!', '^!')
    ]
    for src, target in replacements:
        escaped = escaped.replace(src, target)
    return f'echo {escaped}'


def make_label_name(rel_path: str) -> str:
    label = rel_path.replace('/', '_').replace('.', '_')
    return f'write_{label}'


def build_file_section(rel_path: str, lines):
    label = make_label_name(rel_path)
    body_lines = [f'  {escape_line(line)}' for line in lines] or ['  echo.']
    section_lines = [
        f':{label}',
        'setlocal DisableDelayedExpansion',
        '> "%~1" (',
        *body_lines,
        ')',
        'endlocal',
        'exit /b'
    ]
    section = '\n'.join(section_lines)
    return label, section


sections = []
main_calls = []
for rel_path, lines in FILES:
    label, section = build_file_section(rel_path, lines)
    main_calls.append(f'call :{label} "%APP_DIR%\\{rel_path.replace("/", "\\")}"')
    sections.append(section)

main_logic = textwrap.dedent('''
@echo off
setlocal EnableDelayedExpansion

set "APP_NAME=OmniChat"
set "INSTALL_ROOT=%LOCALAPPDATA%\\OmniChat"
set "APP_DIR=%INSTALL_ROOT%\\app"
set "RUNTIME_DIR=%INSTALL_ROOT%\\runtime"
set "NODE_VERSION=node-v20.12.2-win-x64"
set "NODE_URL=https://nodejs.org/dist/v20.12.2/%NODE_VERSION%.zip"
set "ELECTRON_VERSION=electron-v28.2.0-win32-x64"
set "ELECTRON_URL=https://github.com/electron/electron/releases/download/v28.2.0/%ELECTRON_VERSION%.zip"
set "TEMP_DIR=%TEMP%\\OmniChatInstaller"
set "CONFIG_DIR=%INSTALL_ROOT%\\config"
set "LOG_DIR=%INSTALL_ROOT%\\logs"
set "ERROR_MSG="

call :main
goto :end

:main
cls
echo Installing %APP_NAME%...
if not defined LOCALAPPDATA (
  set "ERROR_MSG=LOCALAPPDATA is not set."
  goto :fail
)

if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%" >nul 2>nul

if exist "%INSTALL_ROOT%" (
  echo Removing previous installation...
  rd /s /q "%INSTALL_ROOT%"
)

echo Creating folders...
mkdir "%APP_DIR%" >nul 2>nul
mkdir "%RUNTIME_DIR%" >nul 2>nul
mkdir "%RUNTIME_DIR%\\node" >nul 2>nul
mkdir "%RUNTIME_DIR%\\electron" >nul 2>nul
mkdir "%CONFIG_DIR%" >nul 2>nul
mkdir "%LOG_DIR%" >nul 2>nul

where curl.exe >nul 2>nul
if errorlevel 1 (
  set "ERROR_MSG=curl.exe not found. Update Windows or install the App Installer package."
  goto :fail
)

where tar.exe >nul 2>nul
if errorlevel 1 (
  set "ERROR_MSG=tar.exe not found. Requires Windows 10 build 17063 or newer."
  goto :fail
)

set "NODE_ZIP=%TEMP_DIR%\\node.zip"
set "ELECTRON_ZIP=%TEMP_DIR%\\electron.zip"

if exist "%NODE_ZIP%" del "%NODE_ZIP%"
if exist "%ELECTRON_ZIP%" del "%ELECTRON_ZIP%"

echo Downloading Node.js runtime...
curl.exe -L -# -o "%NODE_ZIP%" "%NODE_URL%"
if errorlevel 1 (
  set "ERROR_MSG=Failed to download Node.js."
  goto :fail
)

echo Extracting Node.js...
tar.exe -xf "%NODE_ZIP%" -C "%RUNTIME_DIR%\\node"
if errorlevel 1 (
  set "ERROR_MSG=Failed to extract Node.js."
  goto :fail
)
call :flatten_dir "%RUNTIME_DIR%\\node" node.exe
if errorlevel 1 goto :fail

echo Downloading Electron runtime...
curl.exe -L -# -o "%ELECTRON_ZIP%" "%ELECTRON_URL%"
if errorlevel 1 (
  set "ERROR_MSG=Failed to download Electron."
  goto :fail
)

echo Extracting Electron...
tar.exe -xf "%ELECTRON_ZIP%" -C "%RUNTIME_DIR%\\electron"
if errorlevel 1 (
  set "ERROR_MSG=Failed to extract Electron."
  goto :fail
)
call :flatten_dir "%RUNTIME_DIR%\\electron" electron.exe
if errorlevel 1 goto :fail

echo Writing application files...
''').strip('\n')

main_logic += '\n' + '\n'.join(main_calls) + '\n'

main_logic += textwrap.dedent('''

call :write_selectors "%CONFIG_DIR%\\selectors.json"
call :write_first_run "%INSTALL_ROOT%\\FIRST_RUN.txt"

for %%F in (main.js preload.js renderer.js agentPreload.js index.html package.json styles.css) do (
  if not exist "%APP_DIR%\\%%F" (
    set "ERROR_MSG=Required file %%F is missing."
    goto :fail
  )
)

call :create_shortcut "%USERPROFILE%\\Desktop\\OmniChat.lnk"

echo Launching OmniChat...
if exist "%RUNTIME_DIR%\\electron\\electron.exe" (
  start "" "%RUNTIME_DIR%\\electron\\electron.exe" "%APP_DIR%"
) else (
  set "ERROR_MSG=Electron executable missing after install."
  goto :fail
)

echo Cleaning up...
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"

echo OmniChat is ready to use.
echo INSTALLATION_COMPLETE
goto :success
''')

selector_defaults = {
    "chatgpt": {
        "displayName": "ChatGPT",
        "patterns": ["https://chatgpt.com/*"],
        "home": "https://chatgpt.com/",
        "input": ["textarea", "textarea[data-testid='chat-input']", "div[contenteditable='true']"],
        "sendButton": ["button[data-testid='send-button']", "button[aria-label='Send']"],
        "messageContainer": ["main", "div[class*='conversation']"]
    },
    "claude": {
        "displayName": "Claude",
        "patterns": ["https://claude.ai/*"],
        "home": "https://claude.ai/",
        "input": ["textarea", "textarea[placeholder*='Message']", "div[contenteditable='true']"],
        "sendButton": ["button[type='submit']", "button[aria-label='Send']"],
        "messageContainer": ["main", "div[class*='conversation']"]
    },
    "copilot": {
        "displayName": "Copilot",
        "patterns": ["https://copilot.microsoft.com/*", "https://www.bing.com/chat*"],
        "home": "https://copilot.microsoft.com/",
        "input": ["textarea#userInput", "textarea", "div[contenteditable='true']", "textarea[placeholder*='Ask me']"],
        "sendButton": ["button[aria-label='Send']", "button[data-testid='send-button']"],
        "messageContainer": ["main", "div[class*='conversation']"]
    },
    "gemini": {
        "displayName": "Gemini",
        "patterns": ["https://gemini.google.com/*"],
        "home": "https://gemini.google.com/",
        "input": ["textarea", "div[contenteditable='true']", "textarea[aria-label*='Message']"],
        "sendButton": ["button[aria-label='Send']", "button[type='submit']"],
        "messageContainer": ["main", "div[class*='conversation']"]
    }
}

selector_text = json.dumps(selector_defaults, indent=2)
selector_lines = selector_text.splitlines()
selector_label, selector_section = build_file_section('selectors.json', selector_lines)
sections.append(selector_section)

first_run_lines = [
    '1. Install OmniChat using OmniChat_install.bat.',
    '2. Open OmniChat from the desktop shortcut.',
    '3. Sign in to ChatGPT, Claude, Copilot, and Gemini.',
    '4. Use Broadcast to send a message to your selected assistants.',
    '5. Run a Round-table with your chosen turn count.'
]
first_run_label, first_run_section = build_file_section('FIRST_RUN.txt', first_run_lines)
sections.append(first_run_section)

main_logic = main_logic.replace('call :write_selectors "%CONFIG_DIR%\\selectors.json"', f'call :{selector_label} "%CONFIG_DIR%\\selectors.json"')
main_logic = main_logic.replace('call :write_first_run "%INSTALL_ROOT%\\FIRST_RUN.txt"', f'call :{first_run_label} "%INSTALL_ROOT%\\FIRST_RUN.txt"')

shortcut_section = textwrap.dedent('''
:create_shortcut
set "SHORTCUT_PATH=%~1"
set "VBS=%TEMP%\\omnichat_shortcut.vbs"
> "%VBS%" (
  echo Set shell = CreateObject("WScript.Shell")
  echo Set shortcut = shell.CreateShortcut("%SHORTCUT_PATH%")
  echo shortcut.TargetPath = "%RUNTIME_DIR%\\electron\\electron.exe"
  echo shortcut.Arguments = """%APP_DIR%"""
  echo shortcut.Description = "%APP_NAME%"
  echo shortcut.WorkingDirectory = "%APP_DIR%"
  echo shortcut.IconLocation = "%RUNTIME_DIR%\\electron\\electron.exe,0"
  echo shortcut.Save
)
cscript //NoLogo "%VBS%"
del "%VBS%" >nul 2>nul
exit /b
''').strip('\n')

utilities = textwrap.dedent('''
:flatten_dir
setlocal EnableDelayedExpansion
set "TARGET_DIR=%~1"
set "TARGET_FILE=%~2"
set "SOURCE_DIR="

if exist "%TARGET_DIR%\\%TARGET_FILE%" (
  endlocal
  exit /b 0
)

for /f "delims=" %%D in ('dir "%TARGET_DIR%" /ad /b') do (
  if exist "%TARGET_DIR%\\%%D\\%TARGET_FILE%" (
    set "SOURCE_DIR=%TARGET_DIR%\\%%D"
  )
)

if not defined SOURCE_DIR (
  endlocal & set "ERROR_MSG=Could not find %TARGET_FILE% inside %TARGET_DIR%." & exit /b 1
)

for /f "delims=" %%F in ('dir "%SOURCE_DIR%" /b') do (
  move /y "%SOURCE_DIR%\\%%F" "%TARGET_DIR%" >nul
)

rd /s /q "%SOURCE_DIR%"
endlocal
exit /b 0

:fail
if not "%ERROR_MSG%"=="" echo ERROR: %ERROR_MSG%
echo.
echo Press any key to close this window.
pause >nul
exit /b 1

:success
echo.
echo Press any key to close this window.
pause >nul
exit /b 0

:end
endlocal
goto :EOF
''').strip('\n')

with open(INSTALLER_NAME, 'w', encoding='utf-8') as output:
    output.write(main_logic)
    output.write('\n\n')
    output.write(shortcut_section)
    output.write('\n\n')
    output.write('\n\n'.join(sections))
    output.write('\n\n')
    output.write(utilities)
    output.write('\n')
