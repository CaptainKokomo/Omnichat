import os
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
        (')', '^)')
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

call :main
exit /b

:main
cls
echo Installing %APP_NAME%...
if not defined LOCALAPPDATA (
  echo LOCALAPPDATA is not set. Aborting.
  exit /b 1
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
  echo curl.exe not found. Please update Windows 10 or later.
  exit /b 1
)

where tar.exe >nul 2>nul
if errorlevel 1 (
  echo tar.exe not found. Ensure Windows 10 build 17063 or newer.
  exit /b 1
)

set "NODE_ZIP=%TEMP_DIR%\\node.zip"
set "ELECTRON_ZIP=%TEMP_DIR%\\electron.zip"

if exist "%NODE_ZIP%" del "%NODE_ZIP%"
if exist "%ELECTRON_ZIP%" del "%ELECTRON_ZIP%"

echo Downloading Node.js runtime...
curl.exe -L -# -o "%NODE_ZIP%" "%NODE_URL%"
if errorlevel 1 (
  echo Failed to download Node.js.
  exit /b 1
)

echo Extracting Node.js...
tar.exe -xf "%NODE_ZIP%" -C "%RUNTIME_DIR%\\node" --strip-components=1
if errorlevel 1 (
  echo Failed to extract Node.js.
  exit /b 1
)

echo Downloading Electron runtime...
curl.exe -L -# -o "%ELECTRON_ZIP%" "%ELECTRON_URL%"
if errorlevel 1 (
  echo Failed to download Electron.
  exit /b 1
)

echo Extracting Electron...
tar.exe -xf "%ELECTRON_ZIP%" -C "%RUNTIME_DIR%\\electron" --strip-components=1
if errorlevel 1 (
  echo Failed to extract Electron.
  exit /b 1
)

echo Writing application files...
''').strip('\n')

main_logic += '\n' + '\n'.join(main_calls) + '\n'

main_logic += textwrap.dedent('''

call :write_selectors "%CONFIG_DIR%\\selectors.json"
call :write_first_run "%INSTALL_ROOT%\\FIRST_RUN.txt"

call :create_shortcut "%USERPROFILE%\\Desktop\\OmniChat.lnk"

echo Launching OmniChat...
start "" "%RUNTIME_DIR%\\electron\\electron.exe" "%APP_DIR%"

echo Cleaning up...
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"

echo OmniChat is ready to use.
echo INSTALLATION_COMPLETE
exit /b 0
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

import json
selector_text = json.dumps(selector_defaults, indent=2)
selector_lines = selector_text.splitlines()
selector_label, selector_section = build_file_section('selectors.json', selector_lines)
sections.append(selector_section.replace('"%~1"', '"%~1"'))

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
  echo shortcut.Arguments = "\"%APP_DIR%\""
  echo shortcut.Description = "%APP_NAME%"
  echo shortcut.WorkingDirectory = "%APP_DIR%"
  echo shortcut.IconLocation = "%RUNTIME_DIR%\\electron\\electron.exe,0"
  echo shortcut.Save
)
cscript //NoLogo "%VBS%"
del "%VBS%" >nul 2>nul
exit /b
''').strip('\n')

with open(INSTALLER_NAME, 'w', encoding='utf-8') as output:
    output.write(main_logic)
    output.write('\n\n')
    output.write(shortcut_section)
    output.write('\n\n')
    output.write('\n\n'.join(sections))
    output.write('\n')

