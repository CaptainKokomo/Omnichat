@echo off
setlocal EnableDelayedExpansion

set "APP_NAME=OmniChat"
set "INSTALL_ROOT=%LOCALAPPDATA%\OmniChat"
set "APP_DIR=%INSTALL_ROOT%\app"
set "RUNTIME_DIR=%INSTALL_ROOT%\runtime"
set "NODE_VERSION=node-v20.12.2-win-x64"
set "NODE_URL=https://nodejs.org/dist/v20.12.2/%NODE_VERSION%.zip"
set "ELECTRON_VERSION=electron-v28.2.0-win32-x64"
set "ELECTRON_URL=https://github.com/electron/electron/releases/download/v28.2.0/%ELECTRON_VERSION%.zip"
set "TEMP_DIR=%TEMP%\OmniChatInstaller"
set "CONFIG_DIR=%INSTALL_ROOT%\config"
set "LOG_DIR=%INSTALL_ROOT%\logs"
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
mkdir "%RUNTIME_DIR%\node" >nul 2>nul
mkdir "%RUNTIME_DIR%\electron" >nul 2>nul
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

set "NODE_ZIP=%TEMP_DIR%\node.zip"
set "ELECTRON_ZIP=%TEMP_DIR%\electron.zip"

if exist "%NODE_ZIP%" del "%NODE_ZIP%"
if exist "%ELECTRON_ZIP%" del "%ELECTRON_ZIP%"

echo Downloading Node.js runtime...
curl.exe -L -# -o "%NODE_ZIP%" "%NODE_URL%"
if errorlevel 1 (
  set "ERROR_MSG=Failed to download Node.js."
  goto :fail
)

echo Extracting Node.js...
tar.exe -xf "%NODE_ZIP%" -C "%RUNTIME_DIR%\node"
if errorlevel 1 (
  set "ERROR_MSG=Failed to extract Node.js."
  goto :fail
)
call :flatten_dir "%RUNTIME_DIR%\node" node.exe
if errorlevel 1 goto :fail

echo Downloading Electron runtime...
curl.exe -L -# -o "%ELECTRON_ZIP%" "%ELECTRON_URL%"
if errorlevel 1 (
  set "ERROR_MSG=Failed to download Electron."
  goto :fail
)

echo Extracting Electron...
tar.exe -xf "%ELECTRON_ZIP%" -C "%RUNTIME_DIR%\electron"
if errorlevel 1 (
  set "ERROR_MSG=Failed to extract Electron."
  goto :fail
)
call :flatten_dir "%RUNTIME_DIR%\electron" electron.exe
if errorlevel 1 goto :fail

echo Writing application files...
call :write_agentPreload_js "%APP_DIR%\agentPreload.js"
call :write_index_html "%APP_DIR%\index.html"
call :write_main_js "%APP_DIR%\main.js"
call :write_package_json "%APP_DIR%\package.json"
call :write_preload_js "%APP_DIR%\preload.js"
call :write_renderer_js "%APP_DIR%\renderer.js"
call :write_styles_css "%APP_DIR%\styles.css"


call :write_selectors_json "%CONFIG_DIR%\selectors.json"
call :write_FIRST_RUN_txt "%INSTALL_ROOT%\FIRST_RUN.txt"

for %%F in (main.js preload.js renderer.js agentPreload.js index.html package.json styles.css) do (
  if not exist "%APP_DIR%\%%F" (
    set "ERROR_MSG=Required file %%F is missing."
    goto :fail
  )
)

call :create_shortcut "%USERPROFILE%\Desktop\OmniChat.lnk"

echo Launching OmniChat...
if exist "%RUNTIME_DIR%\electron\electron.exe" (
  start "" "%RUNTIME_DIR%\electron\electron.exe" "%APP_DIR%"
) else (
  set "ERROR_MSG=Electron executable missing after install."
  goto :fail
)

echo Cleaning up...
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"

echo OmniChat is ready to use.
echo INSTALLATION_COMPLETE
goto :success


:create_shortcut
set "SHORTCUT_PATH=%~1"
set "VBS=%TEMP%\omnichat_shortcut.vbs"
> "%VBS%" (
  echo Set shell = CreateObject("WScript.Shell")
  echo Set shortcut = shell.CreateShortcut("%SHORTCUT_PATH%")
  echo shortcut.TargetPath = "%RUNTIME_DIR%\electron\electron.exe"
  echo shortcut.Arguments = """%APP_DIR%"""
  echo shortcut.Description = "%APP_NAME%"
  echo shortcut.WorkingDirectory = "%APP_DIR%"
  echo shortcut.IconLocation = "%RUNTIME_DIR%\electron\electron.exe,0"
  echo shortcut.Save
)
cscript //NoLogo "%VBS%"
del "%VBS%" >nul 2>nul
exit /b

:write_agentPreload_js
setlocal DisableDelayedExpansion
> "%~1" (
  echo const { contextBridge } = require^('electron'^);
  echo.
  echo contextBridge.exposeInMainWorld^('OmniChatAgent', {
  echo   ping: ^(^) =^> true
  echo }^);
)
endlocal
exit /b

:write_index_html
setlocal DisableDelayedExpansion
> "%~1" (
  echo ^<^!DOCTYPE html^>
  echo ^<html lang="en"^>
  echo ^<head^>
  echo   ^<meta charset="UTF-8" /^>
  echo   ^<meta name="viewport" content="width=device-width, initial-scale=1.0" /^>
  echo   ^<title^>OmniChat^</title^>
  echo   ^<link rel="stylesheet" href="styles.css" /^>
  echo ^</head^>
  echo ^<body^>
  echo   ^<div id="app"^>
  echo     ^<aside class="pane pane-left"^>
  echo       ^<header^>
  echo         ^<div class="title-block"^>
  echo           ^<h1^>OmniChat^</h1^>
  echo           ^<p id="assistantSummary" class="subtitle"^>Loading assistants…^</p^>
  echo         ^</div^>
  echo         ^<div class="header-actions"^>
  echo           ^<button id="refreshAgents" class="secondary"^>Refresh^</button^>
  echo           ^<button id="manageAssistants" class="secondary"^>Manage^</button^>
  echo         ^</div^>
  echo       ^</header^>
  echo       ^<div id="agentList" class="list"^>^</div^>
  echo     ^</aside^>
  echo     ^<main class="pane pane-center"^>
  echo       ^<section class="composer"^>
  echo         ^<textarea id="composerInput" placeholder="Type your broadcast message..."^>^</textarea^>
  echo         ^<div class="composer-actions"^>
  echo           ^<button id="broadcastBtn" class="primary"^>Broadcast^</button^>
  echo           ^<select id="singleTarget"^>^</select^>
  echo           ^<button id="singleSendBtn" class="secondary"^>Send to Selected^</button^>
  echo         ^</div^>
  echo         ^<div class="target-chips"^>
  echo           ^<span class="target-label"^>Choose assistants:^</span^>
  echo           ^<div id="targetChips" class="chip-list"^>^</div^>
  echo         ^</div^>
  echo         ^<div class="round-table"^>
  echo           ^<div class="controls"^>
  echo             ^<label^>Turns
  echo               ^<input type="number" id="roundTurns" min="1" value="2" /^>
  echo             ^</label^>
  echo             ^<button id="roundStartBtn" class="secondary"^>Start Round-table^</button^>
  echo             ^<button id="roundPauseBtn" class="secondary"^>Pause^</button^>
  echo             ^<button id="roundResumeBtn" class="secondary"^>Resume^</button^>
  echo             ^<button id="roundStopBtn" class="secondary"^>Stop^</button^>
  echo           ^</div^>
  echo         ^</div^>
  echo       ^</section^>
  echo       ^<section class="tools"^>
  echo         ^<h2^>Tools^</h2^>
  echo         ^<div class="tool-buttons"^>
  echo           ^<button id="quoteBtn" class="secondary"^>Quote Selection^</button^>
  echo           ^<button id="snapshotBtn" class="secondary"^>Page Snapshot^</button^>
  echo           ^<button id="attachBtn" class="secondary"^>Quick Attach Snippet^</button^>
  echo         ^</div^>
  echo         ^<div class="attachments" id="attachments"^>^</div^>
  echo         ^<section class="local-studio"^>
  echo           ^<header class="studio-header"^>
  echo             ^<h2^>Local Studio^</h2^>
  echo             ^<p^>Blend local AI outputs with your broadcast without leaving OmniChat.^</p^>
  echo           ^</header^>
  echo           ^<div class="studio-grid"^>
  echo             ^<div class="studio-card"^>
  echo               ^<header^>
  echo                 ^<h3^>Ollama Text Models^</h3^>
  echo                 ^<div class="inline-controls"^>
  echo                   ^<label^>Host
  echo                     ^<input type="text" id="ollamaHostField" placeholder="http://127.0.0.1:11434" /^>
  echo                   ^</label^>
  echo                   ^<button id="ollamaRefresh" class="secondary" type="button"^>Refresh Models^</button^>
  echo                 ^</div^>
  echo               ^</header^>
  echo               ^<div class="studio-body"^>
  echo                 ^<label^>Model
  echo                   ^<select id="ollamaModelSelect"^>^</select^>
  echo                 ^</label^>
  echo                 ^<label^>Prompt
  echo                   ^<textarea id="ollamaPrompt" rows="6" placeholder="Ask your local model..."^>^</textarea^>
  echo                 ^</label^>
  echo                 ^<div class="studio-actions"^>
  echo                   ^<button id="ollamaGenerate" class="primary" type="button"^>Generate^</button^>
  echo                   ^<button id="ollamaInsert" class="secondary" type="button"^>Insert to Composer^</button^>
  echo                 ^</div^>
  echo                 ^<div id="ollamaOutput" class="studio-output" aria-live="polite"^>^</div^>
  echo               ^</div^>
  echo             ^</div^>
  echo             ^<div class="studio-card"^>
  echo               ^<header^>
  echo                 ^<h3^>ComfyUI Visuals^</h3^>
  echo                 ^<div class="inline-controls"^>
  echo                   ^<label^>Host
  echo                     ^<input type="text" id="comfyHostField" placeholder="http://127.0.0.1:8188" /^>
  echo                   ^</label^>
  echo                   ^<button id="comfyRefresh" class="secondary" type="button"^>Fetch Latest^</button^>
  echo                   ^<button id="comfyRun" class="secondary" type="button"^>Run Workflow…^</button^>
  echo                 ^</div^>
  echo               ^</header^>
  echo               ^<div class="studio-body"^>
  echo                 ^<div id="comfyStatus" class="studio-status"^>No ComfyUI results yet.^</div^>
  echo                 ^<div id="comfyGallery" class="gallery"^>^</div^>
  echo               ^</div^>
  echo             ^</div^>
  echo           ^</div^>
  echo         ^</section^>
  echo       ^</section^>
  echo     ^</main^>
  echo     ^<aside class="pane pane-right"^>
  echo       ^<header class="pane-header"^>
  echo         ^<div^>
  echo           ^<h2^>Live Log^</h2^>
  echo           ^<button id="exportLogBtn" class="secondary"^>Export^</button^>
  echo         ^</div^>
  echo         ^<button id="openSettings" class="secondary" type="button"^>Settings^</button^>
  echo       ^</header^>
  echo       ^<div id="logView" class="log"^>^</div^>
  echo     ^</aside^>
  echo   ^</div^>
  echo.
  echo   ^<div id="confirmModal" class="modal hidden"^>
  echo     ^<div class="modal-body"^>
  echo       ^<p id="confirmMessage"^>Send this message?^</p^>
  echo       ^<div class="modal-actions"^>
  echo         ^<button id="confirmCancel" class="secondary"^>Cancel^</button^>
  echo         ^<button id="confirmOk" class="primary"^>Send^</button^>
  echo       ^</div^>
  echo     ^</div^>
  echo   ^</div^>
  echo.
  echo   ^<div id="settingsModal" class="modal hidden"^>
  echo     ^<div class="modal-body settings"^>
  echo       ^<header^>
  echo         ^<h2^>Settings^</h2^>
  echo         ^<button id="closeSettings" class="secondary" type="button"^>Save ^&amp; Close^</button^>
  echo       ^</header^>
  echo       ^<section^>
  echo         ^<h3^>Delays ^& Limits^</h3^>
  echo         ^<div class="grid"^>
  echo           ^<label^>Confirm before send
  echo             ^<input type="checkbox" id="confirmToggle" checked /^>
  echo           ^</label^>
  echo           ^<label^>Delay min ^(ms^)
  echo             ^<input type="number" id="delayMin" min="0" /^>
  echo           ^</label^>
  echo           ^<label^>Delay max ^(ms^)
  echo             ^<input type="number" id="delayMax" min="0" /^>
  echo           ^</label^>
  echo           ^<label^>Message memory ^(N^)
  echo             ^<input type="number" id="messageLimit" min="1" /^>
  echo           ^</label^>
  echo           ^<label^>Default turns ^(K^)
  echo             ^<input type="number" id="defaultTurns" min="1" /^>
  echo           ^</label^>
  echo           ^<label^>Copilot host
  echo             ^<input type="text" id="copilotHost" /^>
  echo           ^</label^>
  echo           ^<label^>ComfyUI host
  echo             ^<input type="text" id="settingsComfyHost" /^>
  echo           ^</label^>
  echo           ^<label class="checkbox"^>Auto-import ComfyUI results
  echo             ^<input type="checkbox" id="settingsComfyAuto" /^>
  echo           ^</label^>
  echo           ^<label^>Ollama host
  echo             ^<input type="text" id="settingsOllamaHost" /^>
  echo           ^</label^>
  echo           ^<label^>Preferred Ollama model
  echo             ^<input type="text" id="settingsOllamaModel" /^>
  echo           ^</label^>
  echo         ^</div^>
  echo       ^</section^>
  echo       ^<section^>
  echo         ^<h3^>Browser Assistants^</h3^>
  echo         ^<p class="section-help"^>Toggle or edit any assistant below. Use the guided form to add new browser UIs without touching JSON.^</p^>
  echo         ^<div class="add-site-form"^>
  echo           ^<h4^>Add new assistant^</h4^>
  echo           ^<div class="grid"^>
  echo             ^<label^>Assistant name
  echo               ^<input type="text" id="newSiteName" placeholder="Perplexity" /^>
  echo             ^</label^>
  echo             ^<label^>Assistant key
  echo               ^<input type="text" id="newSiteKey" placeholder="perplexity" /^>
  echo             ^</label^>
  echo             ^<label^>Start with template
  echo               ^<select id="newSiteTemplate"^>^</select^>
  echo             ^</label^>
  echo             ^<label^>Home URL
  echo               ^<input type="text" id="newSiteHome" placeholder="https://example.com/" /^>
  echo             ^</label^>
  echo             ^<label^>URL patterns ^(one per line^)
  echo               ^<textarea id="newSitePatterns" rows="3" placeholder="https://example.com/*"^>^</textarea^>
  echo             ^</label^>
  echo             ^<label^>Input selectors
  echo               ^<textarea id="newSiteInput" rows="3" placeholder="textarea^&#10;div[contenteditable='true']"^>^</textarea^>
  echo             ^</label^>
  echo             ^<label^>Send button selectors
  echo               ^<textarea id="newSiteSend" rows="3" placeholder="button[type='submit']"^>^</textarea^>
  echo             ^</label^>
  echo             ^<label^>Message container selectors
  echo               ^<textarea id="newSiteMessages" rows="3" placeholder="main^&#10;div[class*='conversation']"^>^</textarea^>
  echo             ^</label^>
  echo           ^</div^>
  echo           ^<div class="add-site-actions"^>
  echo             ^<button id="addSiteBtn" class="primary" type="button"^>Create Assistant^</button^>
  echo             ^<button id="resetSiteForm" class="secondary" type="button"^>Clear Form^</button^>
  echo           ^</div^>
  echo           ^<p class="section-hint"^>Keys must use letters, numbers, or hyphen. OmniChat copies the template selectors if you pick one, so you only need to tweak the pieces that differ.^</p^>
  echo         ^</div^>
  echo         ^<div id="siteEditor"^>^</div^>
  echo       ^</section^>
  echo       ^<section^>
  echo         ^<h3^>Utilities^</h3^>
  echo         ^<div class="utility-actions"^>
  echo           ^<button id="importSelectorsBtn" class="secondary" type="button"^>Import selectors.json…^</button^>
  echo           ^<button id="exportSelectorsBtn" class="secondary" type="button"^>Export selectors.json…^</button^>
  echo           ^<button id="openConfigBtn" class="secondary" type="button"^>Open config folder^</button^>
  echo         ^</div^>
  echo       ^</section^>
  echo     ^</div^>
  echo   ^</div^>
  echo.
  echo   ^<div id="toast" class="toast hidden"^>^</div^>
  echo   ^<script src="renderer.js"^>^</script^>
  echo ^</body^>
  echo ^</html^>
)
endlocal
exit /b

:write_main_js
setlocal DisableDelayedExpansion
> "%~1" (
  echo const { app, BrowserWindow, ipcMain, dialog, shell } = require^('electron'^);
  echo const path = require^('path'^);
  echo const fs = require^('fs'^);
  echo.
  echo const APP_NAME = 'OmniChat';
  echo const INSTALL_ROOT = path.join^(process.env.LOCALAPPDATA ^|^| app.getPath^('userData'^), APP_NAME^);
  echo const CONFIG_ROOT = path.join^(INSTALL_ROOT, 'config'^);
  echo const LOG_ROOT = path.join^(INSTALL_ROOT, 'logs'^);
  echo const SELECTOR_PATH = path.join^(CONFIG_ROOT, 'selectors.json'^);
  echo const SETTINGS_PATH = path.join^(CONFIG_ROOT, 'settings.json'^);
  echo const FIRST_RUN_PATH = path.join^(INSTALL_ROOT, 'FIRST_RUN.txt'^);
  echo.
  echo const DEFAULT_SETTINGS = {
  echo   confirmBeforeSend: true,
  echo   delayMin: 1200,
  echo   delayMax: 2500,
  echo   messageLimit: 5,
  echo   roundTableTurns: 2,
  echo   copilotHost: 'https://copilot.microsoft.com/',
  echo   comfyHost: 'http://127.0.0.1:8188',
  echo   comfyAutoImport: true,
  echo   ollamaHost: 'http://127.0.0.1:11434',
  echo   ollamaModel: ''
  echo };
  echo.
  echo const LOCAL_AGENT_KEY = 'local-ollama';
  echo const LOCAL_AGENT_MANIFEST = {
  echo   key: LOCAL_AGENT_KEY,
  echo   displayName: 'Local ^(Ollama^)',
  echo   type: 'local'
  echo };
  echo.
  echo const DEFAULT_SELECTORS = {
  echo   chatgpt: {
  echo     displayName: 'ChatGPT',
  echo     patterns: ['https://chatgpt.com/*'],
  echo     home: 'https://chatgpt.com/',
  echo     input: ['textarea', "textarea[data-testid='chat-input']", "div[contenteditable='true']"],
  echo     sendButton: ["button[data-testid='send-button']", "button[aria-label='Send']"],
  echo     messageContainer: ['main', "div[class*='conversation']"]
  echo   },
  echo   claude: {
  echo     displayName: 'Claude',
  echo     patterns: ['https://claude.ai/*'],
  echo     home: 'https://claude.ai/',
  echo     input: ['textarea', "textarea[placeholder*='Message']", "div[contenteditable='true']"],
  echo     sendButton: ["button[type='submit']", "button[aria-label='Send']"],
  echo     messageContainer: ['main', "div[class*='conversation']"]
  echo   },
  echo   copilot: {
  echo     displayName: 'Copilot',
  echo     patterns: ['https://copilot.microsoft.com/*', 'https://www.bing.com/chat*'],
  echo     home: 'https://copilot.microsoft.com/',
  echo     input: ['textarea#userInput', 'textarea', "div[contenteditable='true']", "textarea[placeholder*='Ask me']"],
  echo     sendButton: ["button[aria-label='Send']", "button[data-testid='send-button']"],
  echo     messageContainer: ['main', "div[class*='conversation']"]
  echo   },
  echo   gemini: {
  echo     displayName: 'Gemini',
  echo     patterns: ['https://gemini.google.com/*'],
  echo     home: 'https://gemini.google.com/',
  echo     input: ['textarea', "div[contenteditable='true']", "textarea[aria-label*='Message']"],
  echo     sendButton: ["button[aria-label='Send']", "button[type='submit']"],
  echo     messageContainer: ['main', "div[class*='conversation']"]
  echo   }
  echo };
  echo.
  echo const DOM_TASKS = {
  echo   sendMessage^(cfg, context = {}^) {
  echo     const { text = '' } = context;
  echo     const findFirst = ^(selectors^) =^> {
  echo       if ^(^!selectors^) return null;
  echo       for ^(const selector of selectors^) {
  echo         try {
  echo           const el = document.querySelector^(selector^);
  echo           if ^(el^) return el;
  echo         } catch ^(error^) {
  echo           // ignore selector errors
  echo         }
  echo       }
  echo       return null;
  echo     };
  echo.
  echo     const input = findFirst^(cfg.input^);
  echo     if ^(^!input^) {
  echo       return { ok: false, reason: 'input' };
  echo     }
  echo.
  echo     const setValue = ^(element, value^) =^> {
  echo       const proto = Object.getPrototypeOf^(element^);
  echo       const descriptor = Object.getOwnPropertyDescriptor^(proto, 'value'^);
  echo       if ^(descriptor ^&^& typeof descriptor.set === 'function'^) {
  echo         descriptor.set.call^(element, value^);
  echo       } else {
  echo         element.value = value;
  echo       }
  echo     };
  echo.
  echo     setValue^(input, text^);
  echo     input.dispatchEvent^(new Event^('input', { bubbles: true }^)^);
  echo     input.focus^(^);
  echo.
  echo     const button = findFirst^(cfg.sendButton^);
  echo     if ^(button^) {
  echo       button.click^(^);
  echo       return { ok: true, via: 'button' };
  echo     }
  echo.
  echo     const keyboardEvent = new KeyboardEvent^('keydown', {
  echo       key: 'Enter',
  echo       code: 'Enter',
  echo       bubbles: true,
  echo       cancelable: true
  echo     }^);
  echo     input.dispatchEvent^(keyboardEvent^);
  echo.
  echo     if ^(keyboardEvent.defaultPrevented^) {
  echo       const enterEvent = new KeyboardEvent^('keyup', { key: 'Enter', code: 'Enter', bubbles: true }^);
  echo       input.dispatchEvent^(enterEvent^);
  echo     }
  echo.
  echo     const bannerId = '__omnichat_hint';
  echo     let banner = document.getElementById^(bannerId^);
  echo     if ^(^!banner^) {
  echo       banner = document.createElement^('div'^);
  echo       banner.id = bannerId;
  echo       banner.style.position = 'fixed';
  echo       banner.style.bottom = '16px';
  echo       banner.style.right = '16px';
  echo       banner.style.padding = '12px 18px';
  echo       banner.style.background = '#1f2937';
  echo       banner.style.color = '#ffffff';
  echo       banner.style.fontFamily = 'Segoe UI, sans-serif';
  echo       banner.style.borderRadius = '6px';
  echo       banner.style.boxShadow = '0 12px 32px rgba^(15, 23, 42, 0.35^)';
  echo       banner.style.zIndex = '2147483647';
  echo       document.body.appendChild^(banner^);
  echo     }
  echo     banner.textContent = 'Press Enter in the site tab if the message did not send.';
  echo     setTimeout^(^(^) =^> {
  echo       if ^(banner ^&^& banner.parentElement^) {
  echo         banner.remove^(^);
  echo       }
  echo     }, 4500^);
  echo.
  echo     return { ok: true, via: 'enter' };
  echo   },
  echo.
  echo   readMessages^(cfg, context = {}^) {
  echo     const { limit = 5 } = context;
  echo     const findFirst = ^(selectors^) =^> {
  echo       if ^(^!selectors^) return null;
  echo       for ^(const selector of selectors^) {
  echo         try {
  echo           const el = document.querySelector^(selector^);
  echo           if ^(el^) return el;
  echo         } catch ^(error^) {
  echo           // ignore selector errors
  echo         }
  echo       }
  echo       return null;
  echo     };
  echo.
  echo     const container = findFirst^(cfg.messageContainer^);
  echo     if ^(^!container^) {
  echo       return { ok: false, reason: 'messageContainer' };
  echo     }
  echo.
  echo     const walker = document.createTreeWalker^(container, NodeFilter.SHOW_ELEMENT, null^);
  echo     const transcript = [];
  echo     while ^(walker.nextNode^(^)^) {
  echo       const node = walker.currentNode;
  echo       if ^(^!node^) continue;
  echo       if ^(node.childElementCount === 0^) {
  echo         const text = ^(node.textContent ^|^| ''^).trim^(^);
  echo         if ^(text^) {
  echo           transcript.push^(text^);
  echo         }
  echo       }
  echo     }
  echo.
  echo     const deduped = [];
  echo     for ^(const line of transcript^) {
  echo       if ^(^!deduped.length ^|^| deduped[deduped.length - 1] ^!== line^) {
  echo         deduped.push^(line^);
  echo       }
  echo     }
  echo.
  echo     return { ok: true, messages: deduped.slice^(-limit^) };
  echo   },
  echo.
  echo   captureSelection^(^) {
  echo     const selection = window.getSelection^(^);
  echo     const text = selection ? selection.toString^(^).trim^(^) : '';
  echo     return {
  echo       ok: true,
  echo       selection: text,
  echo       title: document.title,
  echo       url: location.href
  echo     };
  echo   },
  echo.
  echo   snapshotPage^(_cfg, context = {}^) {
  echo     const limit = Number^(context.limit^) ^|^| 2000;
  echo     const text = document.body ? document.body.innerText ^|^| '' : '';
  echo     return {
  echo       ok: true,
  echo       title: document.title,
  echo       url: location.href,
  echo       content: text.slice^(0, limit^)
  echo     };
  echo   }
  echo };
  echo.
  echo function pickSelectors^(config = {}^) {
  echo   return {
  echo     input: Array.isArray^(config.input^) ? config.input : [],
  echo     sendButton: Array.isArray^(config.sendButton^) ? config.sendButton : [],
  echo     messageContainer: Array.isArray^(config.messageContainer^) ? config.messageContainer : []
  echo   };
  echo }
  echo.
  echo function createDomScript^(config, taskName, context, settings^) {
  echo   const task = DOM_TASKS[taskName];
  echo   if ^(^!task^) {
  echo     throw new Error^(`Unknown DOM task ${taskName}`^);
  echo   }
  echo   const safeContext = {
  echo     ...context,
  echo     limit: context ^&^& typeof context.limit ^!== 'undefined' ? context.limit : settings.messageLimit ^|^| DEFAULT_SETTINGS.messageLimit
  echo   };
  echo   const payload = {
  echo     cfg: pickSelectors^(config^),
  echo     context: safeContext
  echo   };
  echo   return `^(^(^) =^> {\nconst cfg = ${JSON.stringify^(payload.cfg^)};\nconst context = ${JSON.stringify^(payload.context^)};\nconst task = ${task.toString^(^)};\nreturn task^(cfg, context^);\n}^)^(^)`;
  echo }
  echo.
  echo class JsonStore {
  echo   constructor^(filePath, defaults^) {
  echo     this.filePath = filePath;
  echo     this.defaults = defaults;
  echo   }
  echo.
  echo   load^(^) {
  echo     try {
  echo       if ^(^!fs.existsSync^(this.filePath^)^) {
  echo         const initial = JSON.stringify^(this.defaults, null, 2^);
  echo         fs.mkdirSync^(path.dirname^(this.filePath^), { recursive: true }^);
  echo         fs.writeFileSync^(this.filePath, initial, 'utf8'^);
  echo         return JSON.parse^(initial^);
  echo       }
  echo       const raw = fs.readFileSync^(this.filePath, 'utf8'^);
  echo       const data = JSON.parse^(raw^);
  echo       if ^(Array.isArray^(this.defaults^) ^|^| typeof this.defaults ^!== 'object'^) {
  echo         return data;
  echo       }
  echo       return { ...this.defaults, ...data };
  echo     } catch ^(error^) {
  echo       console.error^(`Failed to load ${this.filePath}`, error^);
  echo       return JSON.parse^(JSON.stringify^(this.defaults^)^);
  echo     }
  echo   }
  echo.
  echo   save^(value^) {
  echo     try {
  echo       const serialised = JSON.stringify^(value, null, 2^);
  echo       fs.mkdirSync^(path.dirname^(this.filePath^), { recursive: true }^);
  echo       fs.writeFileSync^(this.filePath, serialised, 'utf8'^);
  echo     } catch ^(error^) {
  echo       console.error^(`Failed to save ${this.filePath}`, error^);
  echo     }
  echo   }
  echo }
  echo.
  echo class AgentSession {
  echo   constructor^(key, getConfig^) {
  echo     this.key = key;
  echo     this.getConfig = getConfig;
  echo     this.window = null;
  echo     this.queue = Promise.resolve^(^);
  echo     this.destroyed = false;
  echo     this.lastUrl = '';
  echo   }
  echo.
  echo   updateConfig^(^) {
  echo     if ^(^!this.getConfig^(^)^) {
  echo       this.destroy^(^);
  echo     }
  echo   }
  echo.
  echo   async ensureWindow^(^) {
  echo     if ^(this.destroyed^) {
  echo       throw new Error^('agent_removed'^);
  echo     }
  echo     if ^(this.window ^&^& ^!this.window.isDestroyed^(^)^) {
  echo       return this.window;
  echo     }
  echo.
  echo     const config = this.getConfig^(^);
  echo     if ^(^!config^) {
  echo       throw new Error^('unknown_agent'^);
  echo     }
  echo.
  echo     const agentWin = new BrowserWindow^({
  echo       width: 1280,
  echo       height: 800,
  echo       show: false,
  echo       title: `OmniChat – ${config.displayName ^|^| this.key}`,
  echo       autoHideMenuBar: true,
  echo       webPreferences: {
  echo         preload: path.join^(__dirname, 'agentPreload.js'^),
  echo         contextIsolation: true,
  echo         nodeIntegration: false,
  echo         partition: `persist:omnichat-${this.key}`,
  echo         sandbox: false
  echo       }
  echo     }^);
  echo.
  echo     agentWin.webContents.setWindowOpenHandler^(^({ url }^) =^> {
  echo       shell.openExternal^(url^);
  echo       return { action: 'deny' };
  echo     }^);
  echo.
  echo     agentWin.on^('close', ^(event^) =^> {
  echo       event.preventDefault^(^);
  echo       agentWin.hide^(^);
  echo       updateAgentStatus^(this.key, { visible: false }^);
  echo     }^);
  echo.
  echo     agentWin.on^('hide', ^(^) =^> updateAgentStatus^(this.key, { visible: false }^)^);
  echo     agentWin.on^('focus', ^(^) =^> updateAgentStatus^(this.key, { visible: true }^)^);
  echo     agentWin.on^('blur', ^(^) =^> updateAgentStatus^(this.key, { visible: false }^)^);
  echo.
  echo     agentWin.webContents.on^('did-start-loading', ^(^) =^> {
  echo       updateAgentStatus^(this.key, { status: 'loading' }^);
  echo     }^);
  echo.
  echo     agentWin.webContents.on^('did-finish-load', ^(^) =^> {
  echo       this.lastUrl = agentWin.webContents.getURL^(^);
  echo       updateAgentStatus^(this.key, { status: 'ready', url: this.lastUrl }^);
  echo     }^);
  echo.
  echo     agentWin.webContents.on^('did-fail-load', ^(_event, errorCode, errorDescription, validatedURL^) =^> {
  echo       updateAgentStatus^(this.key, {
  echo         status: 'error',
  echo         error: `${errorDescription ^|^| errorCode}`,
  echo         url: validatedURL ^|^| this.lastUrl
  echo       }^);
  echo     }^);
  echo.
  echo     const target = config.home ^|^| ^(Array.isArray^(config.patterns^) ^&^& config.patterns.length ? config.patterns[0].replace^('*', ''^) : ''^);
  echo     if ^(target^) {
  echo       updateAgentStatus^(this.key, { status: 'loading' }^);
  echo       await agentWin.loadURL^(target^);
  echo     } else {
  echo       await agentWin.loadURL^('about:blank'^);
  echo       updateAgentStatus^(this.key, { status: 'ready', url: 'about:blank' }^);
  echo     }
  echo.
  echo     this.window = agentWin;
  echo     return agentWin;
  echo   }
  echo.
  echo   async show^(^) {
  echo     const win = await this.ensureWindow^(^);
  echo     win.show^(^);
  echo     win.focus^(^);
  echo     updateAgentStatus^(this.key, { visible: true }^);
  echo   }
  echo.
  echo   hide^(^) {
  echo     if ^(this.window ^&^& ^!this.window.isDestroyed^(^)^) {
  echo       this.window.hide^(^);
  echo     }
  echo     updateAgentStatus^(this.key, { visible: false }^);
  echo   }
  echo.
  echo   async runTask^(taskName, context = {}^) {
  echo     const job = this.queue.then^(async ^(^) =^> {
  echo       const config = this.getConfig^(^);
  echo       if ^(^!config^) {
  echo         throw new Error^('unknown_agent'^);
  echo       }
  echo       const win = await this.ensureWindow^(^);
  echo       const script = createDomScript^(config, taskName, context, appState.settings^);
  echo       return win.webContents.executeJavaScript^(script, true^);
  echo     }^);
  echo.
  echo     this.queue = job.then^(^(^) =^> undefined, ^(^) =^> undefined^);
  echo     return job;
  echo   }
  echo.
  echo   destroy^(^) {
  echo     this.destroyed = true;
  echo     if ^(this.window ^&^& ^!this.window.isDestroyed^(^)^) {
  echo       const win = this.window;
  echo       this.window = null;
  echo       win.removeAllListeners^('close'^);
  echo       win.destroy^(^);
  echo     }
  echo     updateAgentStatus^(this.key, { status: 'removed', visible: false }^);
  echo   }
  echo }
  echo.
  echo const selectorStore = new JsonStore^(SELECTOR_PATH, DEFAULT_SELECTORS^);
  echo const settingsStore = new JsonStore^(SETTINGS_PATH, DEFAULT_SETTINGS^);
  echo.
  echo const agentSessions = new Map^(^);
  echo const agentStatus = new Map^(^);
  echo const logBuffer = [];
  echo.
  echo const appState = {
  echo   mainWindow: null,
  echo   selectors: JSON.parse^(JSON.stringify^(DEFAULT_SELECTORS^)^),
  echo   settings: { ...DEFAULT_SETTINGS },
  echo   localHistory: []
  echo };
  echo.
  echo function isLocalAgent^(key^) {
  echo   return key === LOCAL_AGENT_KEY;
  echo }
  echo.
  echo function ensureDirectories^(^) {
  echo   [INSTALL_ROOT, CONFIG_ROOT, LOG_ROOT].forEach^(^(dir^) =^> {
  echo     if ^(^!fs.existsSync^(dir^)^) {
  echo       fs.mkdirSync^(dir, { recursive: true }^);
  echo     }
  echo   }^);
  echo }
  echo.
  echo function ensureFirstRunGuide^(^) {
  echo   if ^(^!fs.existsSync^(FIRST_RUN_PATH^)^) {
  echo     const guide = [
  echo       '1. Install OmniChat using OmniChat_install.bat.',
  echo       '2. Open OmniChat from the desktop shortcut.',
  echo       '3. Sign in to ChatGPT, Claude, Copilot, and Gemini.',
  echo       '4. Use Broadcast to send a message to your selected assistants.',
  echo       '5. Run a Round-table with your chosen turn count.'
  echo     ].join^('\n'^);
  echo     fs.writeFileSync^(FIRST_RUN_PATH, guide, 'utf8'^);
  echo   }
  echo }
  echo.
  echo function updateAgentStatus^(key, patch^) {
  echo   const selector = appState.selectors[key] ^|^| {};
  echo   const baseDisplayName = selector.displayName ^|^| patch?.displayName ^|^| LOCAL_AGENT_MANIFEST.displayName ^|^| key;
  echo   const current = agentStatus.get^(key^) ^|^| {
  echo     key,
  echo     displayName: baseDisplayName,
  echo     status: 'idle',
  echo     visible: false,
  echo     type: isLocalAgent^(key^) ? 'local' : 'web'
  echo   };
  echo   const next = {
  echo     ...current,
  echo     ...patch,
  echo     displayName: patch?.displayName ^|^| selector.displayName ^|^| current.displayName ^|^| key,
  echo     type: patch?.type ^|^| current.type ^|^| ^(isLocalAgent^(key^) ? 'local' : 'web'^)
  echo   };
  echo   agentStatus.set^(key, next^);
  echo   if ^(appState.mainWindow ^&^& ^!appState.mainWindow.isDestroyed^(^)^) {
  echo     appState.mainWindow.webContents.send^('agent:status', next^);
  echo   }
  echo }
  echo.
  echo function ensureLocalAgentStatus^(patch = {}^) {
  echo   const host = appState.settings.ollamaHost ^|^| DEFAULT_SETTINGS.ollamaHost;
  echo   const model = appState.settings.ollamaModel ^|^| '';
  echo   updateAgentStatus^(LOCAL_AGENT_KEY, {
  echo     displayName: LOCAL_AGENT_MANIFEST.displayName,
  echo     type: 'local',
  echo     visible: true,
  echo     status: patch.status ^|^| agentStatus.get^(LOCAL_AGENT_KEY^)?.status ^|^| 'idle',
  echo     host,
  echo     model,
  echo     ...patch
  echo   }^);
  echo }
  echo.
  echo function broadcastAgentSnapshot^(^) {
  echo   const payload = Array.from^(agentStatus.values^(^)^).map^(^(entry^) =^> {
  echo     const selector = appState.selectors[entry.key] ^|^| {};
  echo     return {
  echo       ...entry,
  echo       displayName: selector.displayName ^|^| entry.displayName ^|^| entry.key,
  echo       type: entry.type ^|^| ^(isLocalAgent^(entry.key^) ? 'local' : 'web'^)
  echo     };
  echo   }^);
  echo   if ^(appState.mainWindow ^&^& ^!appState.mainWindow.isDestroyed^(^)^) {
  echo     appState.mainWindow.webContents.send^('agent:status:init', payload^);
  echo   }
  echo }
  echo.
  echo function refreshAgentSessions^(^) {
  echo   const keys = Object.keys^(appState.selectors^);
  echo   keys.forEach^(^(key^) =^> {
  echo     if ^(^!agentSessions.has^(key^)^) {
  echo       const session = new AgentSession^(key, ^(^) =^> appState.selectors[key]^);
  echo       agentSessions.set^(key, session^);
  echo     } else {
  echo       agentSessions.get^(key^).updateConfig^(^);
  echo     }
  echo     updateAgentStatus^(key, {}^);
  echo   }^);
  echo.
  echo   for ^(const key of Array.from^(agentSessions.keys^(^)^)^) {
  echo     if ^(^!appState.selectors[key]^) {
  echo       const session = agentSessions.get^(key^);
  echo       session.destroy^(^);
  echo       agentSessions.delete^(key^);
  echo       agentStatus.delete^(key^);
  echo     }
  echo   }
  echo.
  echo   ensureLocalAgentStatus^(^);
  echo   broadcastAgentSnapshot^(^);
  echo }
  echo.
  echo function getAssistantManifest^(^) {
  echo   const selectors = appState.selectors ^|^| {};
  echo   const manifest = {};
  echo   Object.entries^(selectors^).forEach^(^([key, value]^) =^> {
  echo     manifest[key] = {
  echo       key,
  echo       type: 'web',
  echo       displayName: value.displayName ^|^| key,
  echo       home: value.home ^|^| '',
  echo       patterns: value.patterns ^|^| []
  echo     };
  echo   }^);
  echo   manifest[LOCAL_AGENT_KEY] = {
  echo     ...LOCAL_AGENT_MANIFEST,
  echo     host: appState.settings.ollamaHost ^|^| DEFAULT_SETTINGS.ollamaHost,
  echo     model: appState.settings.ollamaModel ^|^| ''
  echo   };
  echo   return manifest;
  echo }
  echo.
  echo function sanitizeLocalHistory^(^) {
  echo   if ^(^!Array.isArray^(appState.localHistory^)^) {
  echo     appState.localHistory = [];
  echo   }
  echo   if ^(appState.localHistory.length ^> 100^) {
  echo     appState.localHistory = appState.localHistory.slice^(-100^);
  echo   }
  echo }
  echo.
  echo function getAgentSession^(key^) {
  echo   if ^(^!agentSessions.has^(key^)^) {
  echo     const config = appState.selectors[key];
  echo     if ^(^!config^) {
  echo       throw new Error^('unknown_agent'^);
  echo     }
  echo     const session = new AgentSession^(key, ^(^) =^> appState.selectors[key]^);
  echo     agentSessions.set^(key, session^);
  echo     updateAgentStatus^(key, {}^);
  echo   }
  echo   return agentSessions.get^(key^);
  echo }
  echo.
  echo function createMainWindow^(^) {
  echo   const mainWindow = new BrowserWindow^({
  echo     width: 1400,
  echo     height: 900,
  echo     title: APP_NAME,
  echo     show: false,
  echo     webPreferences: {
  echo       preload: path.join^(__dirname, 'preload.js'^),
  echo       contextIsolation: true,
  echo       nodeIntegration: false,
  echo       sandbox: false
  echo     }
  echo   }^);
  echo.
  echo   mainWindow.once^('ready-to-show', ^(^) =^> {
  echo     mainWindow.show^(^);
  echo   }^);
  echo.
  echo   mainWindow.on^('closed', ^(^) =^> {
  echo     appState.mainWindow = null;
  echo   }^);
  echo.
  echo   mainWindow.loadFile^(path.join^(__dirname, 'index.html'^)^);
  echo   appState.mainWindow = mainWindow;
  echo }
  echo.
  echo function delay^(ms^) {
  echo   return new Promise^(^(resolve^) =^> setTimeout^(resolve, ms^)^);
  echo }
  echo.
  echo function recordLog^(entry^) {
  echo   const timestamp = new Date^(^).toISOString^(^);
  echo   const line = `[${timestamp}] ${entry}`;
  echo   logBuffer.push^(line^);
  echo   if ^(logBuffer.length ^> 5000^) {
  echo     logBuffer.shift^(^);
  echo   }
  echo   if ^(appState.mainWindow ^&^& ^!appState.mainWindow.isDestroyed^(^)^) {
  echo     appState.mainWindow.webContents.send^('log:push', line^);
  echo   }
  echo   const logFile = path.join^(LOG_ROOT, `${new Date^(^).toISOString^(^).slice^(0, 10^)}.log`^);
  echo   fs.appendFile^(logFile, line + '\n', ^(^) =^> {}^);
  echo }
  echo.
  echo async function sendToAgent^(key, text^) {
  echo   if ^(isLocalAgent^(key^)^) {
  echo     throw new Error^('local_agent'^);
  echo   }
  echo   const session = getAgentSession^(key^);
  echo   const min = Number^(appState.settings.delayMin^) ^|^| DEFAULT_SETTINGS.delayMin;
  echo   const max = Number^(appState.settings.delayMax^) ^|^| min;
  echo   const wait = Math.max^(min, Math.floor^(min + Math.random^(^) * Math.max^(0, max - min^)^)^);
  echo   if ^(wait ^> 0^) {
  echo     await delay^(wait^);
  echo   }
  echo.
  echo   try {
  echo     const result = await session.runTask^('sendMessage', { text }^);
  echo     if ^(^!result ^|^| ^!result.ok^) {
  echo       throw new Error^(result ? result.reason ^|^| 'send' : 'send'^);
  echo     }
  echo     recordLog^(`${key}: message sent via ${result.via}`^);
  echo     return result;
  echo   } catch ^(error^) {
  echo     recordLog^(`${key}: send failed ^(${error.message ^|^| error}^)`^);
  echo     if ^(appState.mainWindow ^&^& ^!appState.mainWindow.isDestroyed^(^)^) {
  echo       appState.mainWindow.webContents.send^('app:toast', `${key}.${error.message ^|^| 'send'} selectors need attention.`^);
  echo     }
  echo     throw error;
  echo   }
  echo }
  echo.
  echo async function readMessages^(key^) {
  echo   if ^(isLocalAgent^(key^)^) {
  echo     sanitizeLocalHistory^(^);
  echo     return appState.localHistory.map^(^(item^) =^> `${item.direction === 'out' ? 'You' : item.model ^|^| 'Local'}: ${item.text}`^);
  echo   }
  echo   try {
  echo     const session = getAgentSession^(key^);
  echo     const result = await session.runTask^('readMessages', { limit: appState.settings.messageLimit }^);
  echo     if ^(^!result ^|^| ^!result.ok^) {
  echo       throw new Error^(result ? result.reason ^|^| 'read' : 'read'^);
  echo     }
  echo     return result.messages ^|^| [];
  echo   } catch ^(error^) {
  echo     recordLog^(`${key}: read failed ^(${error.message ^|^| error}^)`^);
  echo     if ^(appState.mainWindow ^&^& ^!appState.mainWindow.isDestroyed^(^)^) {
  echo       appState.mainWindow.webContents.send^('app:toast', `${key}.${error.message ^|^| 'read'} selectors need attention.`^);
  echo     }
  echo     return [];
  echo   }
  echo }
  echo.
  echo function withTrailingSlash^(url^) {
  echo   if ^(^!url^) return '';
  echo   return url.endsWith^('/'^) ? url : `${url}/`;
  echo }
  echo.
  echo async function fetchJson^(url, options = {}^) {
  echo   const response = await fetch^(url, options^);
  echo   if ^(^!response.ok^) {
  echo     const text = await response.text^(^).catch^(^(^) =^> ''^);
  echo     throw new Error^(`HTTP ${response.status}: ${text.slice^(0, 140^)}`^);
  echo   }
  echo   return await response.json^(^);
  echo }
  echo.
  echo function buildComfyAssetURL^(host, asset^) {
  echo   const base = withTrailingSlash^(host ^|^| DEFAULT_SETTINGS.comfyHost^);
  echo   const url = new URL^('view', base^);
  echo   url.searchParams.set^('filename', asset.filename ^|^| ''^);
  echo   url.searchParams.set^('type', asset.type ^|^| 'output'^);
  echo   url.searchParams.set^('subfolder', asset.subfolder ^|^| ''^);
  echo   return url.toString^(^);
  echo }
  echo.
  echo function guessMime^(filename = ''^) {
  echo   const lower = filename.toLowerCase^(^);
  echo   if ^(lower.endsWith^('.png'^)^) return 'image/png';
  echo   if ^(lower.endsWith^('.jpg'^) ^|^| lower.endsWith^('.jpeg'^)^) return 'image/jpeg';
  echo   if ^(lower.endsWith^('.webp'^)^) return 'image/webp';
  echo   if ^(lower.endsWith^('.gif'^)^) return 'image/gif';
  echo   if ^(lower.endsWith^('.mp4'^)^) return 'video/mp4';
  echo   if ^(lower.endsWith^('.webm'^)^) return 'video/webm';
  echo   return 'application/octet-stream';
  echo }
  echo.
  echo async function listComfyHistory^(limit = 8, hostOverride^) {
  echo   const host = hostOverride ^|^| appState.settings.comfyHost ^|^| DEFAULT_SETTINGS.comfyHost;
  echo   const url = new URL^('history', withTrailingSlash^(host^)^);
  echo   const payload = await fetchJson^(url^);
  echo   const entries = Object.entries^(payload ^|^| {}^)
  echo     .map^(^([id, info]^) =^> ^({ id, info }^)^)
  echo     .sort^(^(a, b^) =^> {
  echo       const at = a.info?.prompt?.extra?.creation_time ^|^| a.info?.timestamp ^|^| 0;
  echo       const bt = b.info?.prompt?.extra?.creation_time ^|^| b.info?.timestamp ^|^| 0;
  echo       return bt - at;
  echo     }^)
  echo     .slice^(0, limit^);
  echo.
  echo   return entries.map^(^({ id, info }^) =^> {
  echo     const outputs = info?.outputs ^|^| {};
  echo     const images = [];
  echo     const videos = [];
  echo     Object.values^(outputs^).forEach^(^(node^) =^> {
  echo       if ^(Array.isArray^(node?.images^)^) {
  echo         node.images.forEach^(^(image^) =^> {
  echo           images.push^({
  echo             ...image,
  echo             url: buildComfyAssetURL^(host, image^),
  echo             mime: guessMime^(image.filename^)
  echo           }^);
  echo         }^);
  echo       }
  echo       if ^(Array.isArray^(node?.videos^)^) {
  echo         node.videos.forEach^(^(video^) =^> {
  echo           videos.push^({
  echo             ...video,
  echo             url: buildComfyAssetURL^(host, video^),
  echo             mime: guessMime^(video.filename^)
  echo           }^);
  echo         }^);
  echo       }
  echo     }^);
  echo.
  echo     return {
  echo       id,
  echo       title: info?.prompt?.extra?.title ^|^| info?.prompt?.extra?.workflow ^|^| id,
  echo       created: info?.prompt?.extra?.creation_time ^|^| info?.timestamp ^|^| Date.now^(^),
  echo       images,
  echo       videos
  echo     };
  echo   }^);
  echo }
  echo.
  echo async function fetchComfyAsset^(asset^) {
  echo   const host = asset.host ^|^| appState.settings.comfyHost ^|^| DEFAULT_SETTINGS.comfyHost;
  echo   const assetUrl = buildComfyAssetURL^(host, asset^);
  echo   const response = await fetch^(assetUrl^);
  echo   if ^(^!response.ok^) {
  echo     throw new Error^(`HTTP ${response.status}`^);
  echo   }
  echo   const arrayBuffer = await response.arrayBuffer^(^);
  echo   const buffer = Buffer.from^(arrayBuffer^);
  echo   const mime = asset.mime ^|^| guessMime^(asset.filename^);
  echo   return `data:${mime};base64,${buffer.toString^('base64'^)}`;
  echo }
  echo.
  echo async function runComfyWorkflowFromFile^(hostOverride^) {
  echo   if ^(^!appState.mainWindow ^|^| appState.mainWindow.isDestroyed^(^)^) {
  echo     return { ok: false, error: 'window_closed' };
  echo   }
  echo   const result = await dialog.showOpenDialog^(appState.mainWindow, {
  echo     title: 'Choose ComfyUI workflow',
  echo     filters: [{ name: 'JSON Files', extensions: ['json'] }],
  echo     properties: ['openFile']
  echo   }^);
  echo   if ^(result.canceled ^|^| ^!result.filePaths.length^) {
  echo     return { ok: false, canceled: true };
  echo   }
  echo   const host = hostOverride ^|^| appState.settings.comfyHost ^|^| DEFAULT_SETTINGS.comfyHost;
  echo   const filePath = result.filePaths[0];
  echo   const workflow = JSON.parse^(fs.readFileSync^(filePath, 'utf8'^)^);
  echo   const url = new URL^('prompt', withTrailingSlash^(host^)^);
  echo   const response = await fetch^(url, {
  echo     method: 'POST',
  echo     headers: { 'Content-Type': 'application/json' },
  echo     body: JSON.stringify^(workflow^)
  echo   }^);
  echo   if ^(^!response.ok^) {
  echo     const text = await response.text^(^).catch^(^(^) =^> ''^);
  echo     throw new Error^(`HTTP ${response.status}: ${text.slice^(0, 140^)}`^);
  echo   }
  echo   return { ok: true };
  echo }
  echo.
  echo async function listOllamaModels^(hostOverride^) {
  echo   const host = hostOverride ^|^| appState.settings.ollamaHost ^|^| DEFAULT_SETTINGS.ollamaHost;
  echo   const url = new URL^('api/tags', withTrailingSlash^(host^)^);
  echo   const data = await fetchJson^(url^);
  echo   return Array.isArray^(data?.models^) ? data.models.map^(^(model^) =^> model.name^) : [];
  echo }
  echo.
  echo async function generateWithOllama^({ model, prompt, host }^) {
  echo   const ollamaHost = host ^|^| appState.settings.ollamaHost ^|^| DEFAULT_SETTINGS.ollamaHost;
  echo   const url = new URL^('api/generate', withTrailingSlash^(ollamaHost^)^);
  echo   const response = await fetch^(url, {
  echo     method: 'POST',
  echo     headers: { 'Content-Type': 'application/json' },
  echo     body: JSON.stringify^({ model, prompt, stream: true }^)
  echo   }^);
  echo   if ^(^!response.ok^) {
  echo     const text = await response.text^(^).catch^(^(^) =^> ''^);
  echo     throw new Error^(`HTTP ${response.status}: ${text.slice^(0, 140^)}`^);
  echo   }
  echo.
  echo   let output = '';
  echo   const reader = response.body?.getReader ? response.body.getReader^(^) : null;
  echo   if ^(reader^) {
  echo     const decoder = new TextDecoder^(^);
  echo     let remainder = '';
  echo     while ^(true^) {
  echo       const { value, done } = await reader.read^(^);
  echo       if ^(done^) break;
  echo       remainder += decoder.decode^(value, { stream: true }^);
  echo       let index;
  echo       while ^(^(index = remainder.indexOf^('\n'^)^) ^>= 0^) {
  echo         const line = remainder.slice^(0, index^).trim^(^);
  echo         remainder = remainder.slice^(index + 1^);
  echo         if ^(^!line^) continue;
  echo         try {
  echo           const parsed = JSON.parse^(line^);
  echo           if ^(parsed.response^) {
  echo             output += parsed.response;
  echo           }
  echo         } catch ^(error^) {
  echo           // ignore malformed chunks
  echo         }
  echo       }
  echo     }
  echo     const tail = remainder.trim^(^);
  echo     if ^(tail^) {
  echo       try {
  echo         const parsed = JSON.parse^(tail^);
  echo         if ^(parsed.response^) {
  echo           output += parsed.response;
  echo         }
  echo       } catch ^(error^) {
  echo         // ignore
  echo       }
  echo     }
  echo   } else {
  echo     const text = await response.text^(^);
  echo     output = text;
  echo   }
  echo.
  echo   return output;
  echo }
  echo.
  echo ipcMain.handle^('app:bootstrap', async ^(^) =^> {
  echo   ensureDirectories^(^);
  echo   ensureFirstRunGuide^(^);
  echo   appState.selectors = selectorStore.load^(^);
  echo   appState.settings = settingsStore.load^(^);
  echo   ensureLocalAgentStatus^(^);
  echo   refreshAgentSessions^(^);
  echo   return {
  echo     selectors: appState.selectors,
  echo     settings: appState.settings,
  echo     assistants: getAssistantManifest^(^),
  echo     defaults: JSON.parse^(JSON.stringify^(DEFAULT_SELECTORS^)^),
  echo     defaultKeys: Object.keys^(DEFAULT_SELECTORS^),
  echo     order: [...Object.keys^(appState.selectors^), LOCAL_AGENT_KEY],
  echo     log: logBuffer.slice^(-200^)
  echo   };
  echo }^);
  echo.
  echo ipcMain.handle^('selectors:save', async ^(_event, payload^) =^> {
  echo   appState.selectors = payload ^|^| {};
  echo   selectorStore.save^(appState.selectors^);
  echo   refreshAgentSessions^(^);
  echo   return { ok: true };
  echo }^);
  echo.
  echo ipcMain.handle^('settings:save', async ^(_event, payload^) =^> {
  echo   appState.settings = { ...appState.settings, ...^(payload ^|^| {}^) };
  echo   settingsStore.save^(appState.settings^);
  echo   ensureLocalAgentStatus^(^);
  echo   return { ok: true };
  echo }^);
  echo.
  echo ipcMain.handle^('selectors:importFile', async ^(^) =^> {
  echo   if ^(^!appState.mainWindow ^|^| appState.mainWindow.isDestroyed^(^)^) {
  echo     return { ok: false, error: 'window_closed' };
  echo   }
  echo   const result = await dialog.showOpenDialog^(appState.mainWindow, {
  echo     title: 'Import selectors.json',
  echo     filters: [{ name: 'JSON Files', extensions: ['json'] }],
  echo     properties: ['openFile']
  echo   }^);
  echo   if ^(result.canceled ^|^| ^!result.filePaths.length^) {
  echo     return { ok: false, canceled: true };
  echo   }
  echo   const filePath = result.filePaths[0];
  echo   try {
  echo     const raw = fs.readFileSync^(filePath, 'utf8'^);
  echo     const data = JSON.parse^(raw^);
  echo     appState.selectors = data;
  echo     selectorStore.save^(appState.selectors^);
  echo     refreshAgentSessions^(^);
  echo     return { ok: true, selectors: appState.selectors };
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo ipcMain.handle^('selectors:exportFile', async ^(^) =^> {
  echo   if ^(^!appState.mainWindow ^|^| appState.mainWindow.isDestroyed^(^)^) {
  echo     return { ok: false, error: 'window_closed' };
  echo   }
  echo   const result = await dialog.showSaveDialog^(appState.mainWindow, {
  echo     title: 'Export selectors.json',
  echo     filters: [{ name: 'JSON Files', extensions: ['json'] }],
  echo     defaultPath: path.join^(app.getPath^('documents'^), 'omnichat-selectors.json'^)
  echo   }^);
  echo   if ^(result.canceled ^|^| ^!result.filePath^) {
  echo     return { ok: false, canceled: true };
  echo   }
  echo   try {
  echo     selectorStore.save^(appState.selectors^);
  echo     fs.copyFileSync^(SELECTOR_PATH, result.filePath^);
  echo     return { ok: true, path: result.filePath };
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo ipcMain.handle^('config:openFolder', async ^(^) =^> {
  echo   await shell.openPath^(CONFIG_ROOT^);
  echo   return { ok: true };
  echo }^);
  echo.
  echo ipcMain.handle^('agent:ensure', async ^(_event, key^) =^> {
  echo   if ^(isLocalAgent^(key^)^) {
  echo     ensureLocalAgentStatus^({ status: 'ready' }^);
  echo     return agentStatus.get^(key^) ^|^| { key: LOCAL_AGENT_KEY, type: 'local' };
  echo   }
  echo   const session = getAgentSession^(key^);
  echo   await session.ensureWindow^(^);
  echo   return agentStatus.get^(key^) ^|^| { key };
  echo }^);
  echo.
  echo ipcMain.handle^('agent:connect', async ^(_event, key^) =^> {
  echo   if ^(isLocalAgent^(key^)^) {
  echo     ensureLocalAgentStatus^({ status: 'ready' }^);
  echo     return true;
  echo   }
  echo   const session = getAgentSession^(key^);
  echo   await session.show^(^);
  echo   return true;
  echo }^);
  echo.
  echo ipcMain.handle^('agent:hide', async ^(_event, key^) =^> {
  echo   if ^(isLocalAgent^(key^)^) {
  echo     ensureLocalAgentStatus^({ visible: false }^);
  echo     return true;
  echo   }
  echo   if ^(agentSessions.has^(key^)^) {
  echo     agentSessions.get^(key^).hide^(^);
  echo   }
  echo   return true;
  echo }^);
  echo.
  echo ipcMain.handle^('agent:read', async ^(_event, key^) =^> {
  echo   return await readMessages^(key^);
  echo }^);
  echo.
  echo ipcMain.handle^('agent:send', async ^(_event, payload^) =^> {
  echo   const { key, text } = payload ^|^| {};
  echo   if ^(isLocalAgent^(key^)^) {
  echo     const prompt = text ^|^| '';
  echo     if ^(^!prompt.trim^(^)^) {
  echo       throw new Error^('empty_prompt'^);
  echo     }
  echo     try {
  echo       appState.localHistory.push^({ direction: 'out', text: prompt, timestamp: Date.now^(^) }^);
  echo       sanitizeLocalHistory^(^);
  echo       const existingModel = appState.settings.ollamaModel;
  echo       let model = existingModel;
  echo       if ^(^!model^) {
  echo         const models = await listOllamaModels^(^);
  echo         if ^(^!models.length^) {
  echo           throw new Error^('no_local_models'^);
  echo         }
  echo         model = models[0];
  echo         appState.settings.ollamaModel = model;
  echo         settingsStore.save^(appState.settings^);
  echo         ensureLocalAgentStatus^({ model }^);
  echo       }
  echo       ensureLocalAgentStatus^({ status: 'generating' }^);
  echo       recordLog^(`${key}: generating with ${model}`^);
  echo       const response = await generateWithOllama^({ model, prompt }^);
  echo       ensureLocalAgentStatus^({ status: 'ready', model }^);
  echo       appState.localHistory.push^({ direction: 'in', text: response, model, timestamp: Date.now^(^) }^);
  echo       sanitizeLocalHistory^(^);
  echo       recordLog^(`${key}: ${response.slice^(0, 140^)}${response.length ^> 140 ? '…' : ''}`^);
  echo       if ^(appState.mainWindow ^&^& ^!appState.mainWindow.isDestroyed^(^)^) {
  echo         appState.mainWindow.webContents.send^('agent:localMessage', {
  echo           key,
  echo           model,
  echo           prompt,
  echo           response,
  echo           timestamp: Date.now^(^)
  echo         }^);
  echo       }
  echo       return { ok: true, response, model };
  echo     } catch ^(error^) {
  echo       ensureLocalAgentStatus^({ status: 'error', error: error.message ^|^| String^(error^) }^);
  echo       recordLog^(`${key}: generation failed ^(${error.message ^|^| error}^)`^);
  echo       if ^(appState.mainWindow ^&^& ^!appState.mainWindow.isDestroyed^(^)^) {
  echo         appState.mainWindow.webContents.send^('app:toast', `Local model: ${error.message ^|^| error}`^);
  echo       }
  echo       throw error;
  echo     }
  echo   }
  echo   await getAgentSession^(key^).ensureWindow^(^);
  echo   const messages = await readMessages^(key^);
  echo   await sendToAgent^(key, text ^|^| ''^);
  echo   return { ok: true, previous: messages };
  echo }^);
  echo.
  echo ipcMain.handle^('agent:captureSelection', async ^(_event, key^) =^> {
  echo   try {
  echo     const session = getAgentSession^(key^);
  echo     const result = await session.runTask^('captureSelection', {}^);
  echo     return result;
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo ipcMain.handle^('agent:snapshot', async ^(_event, { key, limit = 2000 }^) =^> {
  echo   try {
  echo     const session = getAgentSession^(key^);
  echo     const result = await session.runTask^('snapshotPage', { limit }^);
  echo     return result;
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo ipcMain.handle^('log:export', async ^(_event, payload^) =^> {
  echo   if ^(^!appState.mainWindow ^|^| appState.mainWindow.isDestroyed^(^)^) {
  echo     return { ok: false };
  echo   }
  echo   const dialogResult = await dialog.showSaveDialog^(appState.mainWindow, {
  echo     title: 'Export OmniChat Log',
  echo     filters: [{ name: 'Text Files', extensions: ['txt'] }],
  echo     defaultPath: path.join^(app.getPath^('documents'^), `omnichat-log-${Date.now^(^)}.txt`^)
  echo   }^);
  echo   if ^(dialogResult.canceled ^|^| ^!dialogResult.filePath^) {
  echo     return { ok: false };
  echo   }
  echo   fs.writeFileSync^(dialogResult.filePath, payload ^|^| '', 'utf8'^);
  echo   return { ok: true, path: dialogResult.filePath };
  echo }^);
  echo.
  echo ipcMain.handle^('settings:resetAgent', async ^(_event, key^) =^> {
  echo   if ^(^!DEFAULT_SELECTORS[key]^) {
  echo     return { ok: false, error: 'unknown' };
  echo   }
  echo   appState.selectors[key] = JSON.parse^(JSON.stringify^(DEFAULT_SELECTORS[key]^)^);
  echo   selectorStore.save^(appState.selectors^);
  echo   refreshAgentSessions^(^);
  echo   return { ok: true, selectors: appState.selectors };
  echo }^);
  echo.
  echo ipcMain.handle^('local:comfy:list', async ^(_event, options = {}^) =^> {
  echo   const { limit = 8, host } = options;
  echo   try {
  echo     const jobs = await listComfyHistory^(limit, host^);
  echo     return { ok: true, jobs };
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo ipcMain.handle^('local:comfy:asset', async ^(_event, asset^) =^> {
  echo   try {
  echo     const dataUrl = await fetchComfyAsset^(asset ^|^| {}^);
  echo     return { ok: true, dataUrl };
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo ipcMain.handle^('local:comfy:run', async ^(_event, hostOverride^) =^> {
  echo   try {
  echo     const result = await runComfyWorkflowFromFile^(hostOverride^);
  echo     return result;
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo ipcMain.handle^('local:ollama:models', async ^(_event, hostOverride^) =^> {
  echo   try {
  echo     const models = await listOllamaModels^(hostOverride^);
  echo     return { ok: true, models };
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo ipcMain.handle^('local:ollama:generate', async ^(_event, payload = {}^) =^> {
  echo   try {
  echo     const response = await generateWithOllama^(payload^);
  echo     return { ok: true, text: response };
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo app.whenReady^(^).then^(^(^) =^> {
  echo   ensureDirectories^(^);
  echo   ensureFirstRunGuide^(^);
  echo   appState.selectors = selectorStore.load^(^);
  echo   appState.settings = settingsStore.load^(^);
  echo   refreshAgentSessions^(^);
  echo   createMainWindow^(^);
  echo }^);
  echo.
  echo app.on^('activate', ^(^) =^> {
  echo   if ^(BrowserWindow.getAllWindows^(^).length === 0^) {
  echo     createMainWindow^(^);
  echo   }
  echo }^);
  echo.
  echo app.on^('window-all-closed', ^(^) =^> {
  echo   if ^(process.platform ^!== 'darwin'^) {
  echo     app.quit^(^);
  echo   }
  echo }^);
)
endlocal
exit /b

:write_package_json
setlocal DisableDelayedExpansion
> "%~1" (
  echo {
  echo   "name": "omnichat",
  echo   "version": "1.0.0",
  echo   "description": "OmniChat orchestrates browser-based AI assistants.",
  echo   "main": "main.js",
  echo   "author": "OmniChat",
  echo   "license": "SEE LICENSE IN INSTALLER",
  echo   "dependencies": {},
  echo   "type": "commonjs"
  echo }
)
endlocal
exit /b

:write_preload_js
setlocal DisableDelayedExpansion
> "%~1" (
  echo const { contextBridge, ipcRenderer } = require^('electron'^);
  echo.
  echo contextBridge.exposeInMainWorld^('omnichat', {
  echo   bootstrap: ^(^) =^> ipcRenderer.invoke^('app:bootstrap'^),
  echo   saveSelectors: ^(selectors^) =^> ipcRenderer.invoke^('selectors:save', selectors^),
  echo   saveSettings: ^(settings^) =^> ipcRenderer.invoke^('settings:save', settings^),
  echo   ensureAgent: ^(key^) =^> ipcRenderer.invoke^('agent:ensure', key^),
  echo   connectAgent: ^(key^) =^> ipcRenderer.invoke^('agent:connect', key^),
  echo   hideAgent: ^(key^) =^> ipcRenderer.invoke^('agent:hide', key^),
  echo   readAgent: ^(key^) =^> ipcRenderer.invoke^('agent:read', key^),
  echo   sendAgent: ^(payload^) =^> ipcRenderer.invoke^('agent:send', payload^),
  echo   captureSelection: ^(key^) =^> ipcRenderer.invoke^('agent:captureSelection', key^),
  echo   snapshotPage: ^(payload^) =^> ipcRenderer.invoke^('agent:snapshot', payload^),
  echo   exportLog: ^(text^) =^> ipcRenderer.invoke^('log:export', text^),
  echo   resetAgentSelectors: ^(key^) =^> ipcRenderer.invoke^('settings:resetAgent', key^),
  echo   importSelectors: ^(^) =^> ipcRenderer.invoke^('selectors:importFile'^),
  echo   exportSelectors: ^(^) =^> ipcRenderer.invoke^('selectors:exportFile'^),
  echo   openConfigFolder: ^(^) =^> ipcRenderer.invoke^('config:openFolder'^),
  echo   listComfyJobs: ^(options^) =^> ipcRenderer.invoke^('local:comfy:list', options^),
  echo   fetchComfyAsset: ^(asset^) =^> ipcRenderer.invoke^('local:comfy:asset', asset^),
  echo   runComfyWorkflow: ^(host^) =^> ipcRenderer.invoke^('local:comfy:run', host^),
  echo   listOllamaModels: ^(host^) =^> ipcRenderer.invoke^('local:ollama:models', host^),
  echo   generateOllama: ^(payload^) =^> ipcRenderer.invoke^('local:ollama:generate', payload^),
  echo   onStatus: ^(handler^) =^> ipcRenderer.on^('agent:status', ^(_event, data^) =^> handler^(data^)^),
  echo   onStatusInit: ^(handler^) =^> ipcRenderer.on^('agent:status:init', ^(_event, data^) =^> handler^(data^)^),
  echo   onLog: ^(handler^) =^> ipcRenderer.on^('log:push', ^(_event, data^) =^> handler^(data^)^),
  echo   onToast: ^(handler^) =^> ipcRenderer.on^('app:toast', ^(_event, message^) =^> handler^(message^)^),
  echo   onLocalMessage: ^(handler^) =^> ipcRenderer.on^('agent:localMessage', ^(_event, data^) =^> handler^(data^)^)
  echo }^);
)
endlocal
exit /b

:write_renderer_js
setlocal DisableDelayedExpansion
> "%~1" (
  echo const api = window.omnichat;
  echo.
  echo const elements = {
  echo   agentList: document.getElementById^('agentList'^),
  echo   assistantSummary: document.getElementById^('assistantSummary'^),
  echo   refreshAgents: document.getElementById^('refreshAgents'^),
  echo   manageAssistants: document.getElementById^('manageAssistants'^),
  echo   composerInput: document.getElementById^('composerInput'^),
  echo   broadcastBtn: document.getElementById^('broadcastBtn'^),
  echo   singleTarget: document.getElementById^('singleTarget'^),
  echo   singleSendBtn: document.getElementById^('singleSendBtn'^),
  echo   roundTurns: document.getElementById^('roundTurns'^),
  echo   roundStart: document.getElementById^('roundStartBtn'^),
  echo   roundPause: document.getElementById^('roundPauseBtn'^),
  echo   roundResume: document.getElementById^('roundResumeBtn'^),
  echo   roundStop: document.getElementById^('roundStopBtn'^),
  echo   targetChips: document.getElementById^('targetChips'^),
  echo   quoteBtn: document.getElementById^('quoteBtn'^),
  echo   snapshotBtn: document.getElementById^('snapshotBtn'^),
  echo   attachBtn: document.getElementById^('attachBtn'^),
  echo   attachments: document.getElementById^('attachments'^),
  echo   logView: document.getElementById^('logView'^),
  echo   exportLogBtn: document.getElementById^('exportLogBtn'^),
  echo   settingsModal: document.getElementById^('settingsModal'^),
  echo   openSettings: document.getElementById^('openSettings'^),
  echo   closeSettings: document.getElementById^('closeSettings'^),
  echo   confirmModal: document.getElementById^('confirmModal'^),
  echo   confirmMessage: document.getElementById^('confirmMessage'^),
  echo   confirmCancel: document.getElementById^('confirmCancel'^),
  echo   confirmOk: document.getElementById^('confirmOk'^),
  echo   toast: document.getElementById^('toast'^),
  echo   siteEditor: document.getElementById^('siteEditor'^),
  echo   resetSiteForm: document.getElementById^('resetSiteForm'^),
  echo   newSiteName: document.getElementById^('newSiteName'^),
  echo   newSiteKey: document.getElementById^('newSiteKey'^),
  echo   newSiteTemplate: document.getElementById^('newSiteTemplate'^),
  echo   newSiteHome: document.getElementById^('newSiteHome'^),
  echo   newSitePatterns: document.getElementById^('newSitePatterns'^),
  echo   newSiteInput: document.getElementById^('newSiteInput'^),
  echo   newSiteSend: document.getElementById^('newSiteSend'^),
  echo   newSiteMessages: document.getElementById^('newSiteMessages'^),
  echo   addSiteBtn: document.getElementById^('addSiteBtn'^),
  echo   confirmToggle: document.getElementById^('confirmToggle'^),
  echo   delayMin: document.getElementById^('delayMin'^),
  echo   delayMax: document.getElementById^('delayMax'^),
  echo   messageLimit: document.getElementById^('messageLimit'^),
  echo   defaultTurns: document.getElementById^('defaultTurns'^),
  echo   copilotHost: document.getElementById^('copilotHost'^),
  echo   settingsComfyHost: document.getElementById^('settingsComfyHost'^),
  echo   settingsComfyAuto: document.getElementById^('settingsComfyAuto'^),
  echo   settingsOllamaHost: document.getElementById^('settingsOllamaHost'^),
  echo   settingsOllamaModel: document.getElementById^('settingsOllamaModel'^),
  echo   importSelectorsBtn: document.getElementById^('importSelectorsBtn'^),
  echo   exportSelectorsBtn: document.getElementById^('exportSelectorsBtn'^),
  echo   openConfigBtn: document.getElementById^('openConfigBtn'^),
  echo   ollamaHostField: document.getElementById^('ollamaHostField'^),
  echo   ollamaRefresh: document.getElementById^('ollamaRefresh'^),
  echo   ollamaModelSelect: document.getElementById^('ollamaModelSelect'^),
  echo   ollamaPrompt: document.getElementById^('ollamaPrompt'^),
  echo   ollamaGenerate: document.getElementById^('ollamaGenerate'^),
  echo   ollamaInsert: document.getElementById^('ollamaInsert'^),
  echo   ollamaOutput: document.getElementById^('ollamaOutput'^),
  echo   comfyHostField: document.getElementById^('comfyHostField'^),
  echo   comfyRefresh: document.getElementById^('comfyRefresh'^),
  echo   comfyRun: document.getElementById^('comfyRun'^),
  echo   comfyStatus: document.getElementById^('comfyStatus'^),
  echo   comfyGallery: document.getElementById^('comfyGallery'^)
  echo };
  echo.
  echo const DEFAULT_KEY_FALLBACK = ['chatgpt', 'claude', 'copilot', 'gemini'];
  echo const LOCAL_AGENT_KEY = 'local-ollama';
  echo.
  echo const state = {
  echo   selectors: {},
  echo   defaultSelectors: {},
  echo   assistants: {},
  echo   localManifest: null,
  echo   settings: {},
  echo   order: [],
  echo   defaultKeys: [...DEFAULT_KEY_FALLBACK],
  echo   selected: new Set^(^),
  echo   agents: {},
  echo   log: [],
  echo   attachments: [],
  echo   confirmResolver: null,
  echo   local: {
  echo     ollamaModels: [],
  echo     ollamaOutput: '',
  echo     ollamaBusy: false,
  echo     comfyJobs: [],
  echo     comfyBusy: false,
  echo     comfyImported: new Set^(^)
  echo   },
  echo   round: {
  echo     active: false,
  echo     paused: false,
  echo     queue: [],
  echo     turnsRemaining: 0,
  echo     baseMessage: '',
  echo     lastTranscript: '',
  echo     timer: null
  echo   }
  echo };
  echo.
  echo let settingsSaveTimer = null;
  echo.
  echo function isDefaultKey^(key^) {
  echo   const defaults = state.defaultKeys ^&^& state.defaultKeys.length ? state.defaultKeys : DEFAULT_KEY_FALLBACK;
  echo   return defaults.includes^(key^);
  echo }
  echo.
  echo function getDefaultLocalManifest^(^) {
  echo   return {
  echo     key: LOCAL_AGENT_KEY,
  echo     type: 'local',
  echo     displayName: 'Local ^(Ollama^)',
  echo     host: state.settings.ollamaHost ^|^| '',
  echo     model: state.settings.ollamaModel ^|^| ''
  echo   };
  echo }
  echo.
  echo function syncAssistantManifest^(orderOverride^) {
  echo   const manifest = {};
  echo   Object.entries^(state.selectors ^|^| {}^).forEach^(^([key, config]^) =^> {
  echo     manifest[key] = {
  echo       key,
  echo       type: 'web',
  echo       displayName: config.displayName ^|^| key,
  echo       home: config.home ^|^| '',
  echo       patterns: config.patterns ^|^| []
  echo     };
  echo   }^);
  echo   const local = state.localManifest ^|^| getDefaultLocalManifest^(^);
  echo   const normalizedLocal = {
  echo     ...local,
  echo     host: state.settings.ollamaHost ^|^| local.host ^|^| '',
  echo     model: state.settings.ollamaModel ^|^| local.model ^|^| ''
  echo   };
  echo   manifest[normalizedLocal.key] = { ...normalizedLocal };
  echo   state.assistants = manifest;
  echo   updateLocalManifest^(normalizedLocal, { skipSummary: true }^);
  echo.
  echo   const currentOrder = Array.isArray^(orderOverride^) ? orderOverride : state.order;
  echo   const nextOrder = [];
  echo   ^(currentOrder ^|^| []^).forEach^(^(key^) =^> {
  echo     if ^(manifest[key] ^&^& ^!nextOrder.includes^(key^)^) {
  echo       nextOrder.push^(key^);
  echo     }
  echo   }^);
  echo   Object.keys^(manifest^).forEach^(^(key^) =^> {
  echo     if ^(^!nextOrder.includes^(key^)^) {
  echo       nextOrder.push^(key^);
  echo     }
  echo   }^);
  echo   state.order = nextOrder;
  echo.
  echo   const previousSelection = new Set^(state.selected ^|^| []^);
  echo   const nextSelection = new Set^(^);
  echo   previousSelection.forEach^(^(key^) =^> {
  echo     if ^(manifest[key]^) {
  echo       nextSelection.add^(key^);
  echo     }
  echo   }^);
  echo   if ^(^!nextSelection.size^) {
  echo     nextOrder.forEach^(^(key^) =^> nextSelection.add^(key^)^);
  echo   }
  echo   state.selected = nextSelection;
  echo   renderAssistantSummary^(^);
  echo }
  echo.
  echo function renderAssistantSummary^(^) {
  echo   if ^(^!elements.assistantSummary^) return;
  echo   const assistants = Object.values^(state.assistants ^|^| {}^);
  echo   const browserAssistants = assistants
  echo     .filter^(^(item^) =^> item.type === 'web'^)
  echo     .map^(^(item^) =^> item.displayName ^|^| item.key^);
  echo   const local = assistants.find^(^(item^) =^> item.type === 'local'^);
  echo   let hostLabel = '';
  echo   if ^(local?.host^) {
  echo     try {
  echo       hostLabel = new URL^(local.host^).host ^|^| local.host;
  echo     } catch ^(error^) {
  echo       hostLabel = local.host;
  echo     }
  echo   }
  echo   const browserInfo = browserAssistants.length
  echo     ? `Browser: ${browserAssistants.join^(', '^)}`
  echo     : 'Browser: none linked';
  echo   const localInfo = local
  echo     ? `Local: ${local.model ? local.model : 'model not selected'}${hostLabel ? ` @ ${hostLabel}` : ''}`
  echo     : 'Local: unavailable';
  echo   elements.assistantSummary.textContent = `${browserInfo} · ${localInfo}`;
  echo }
  echo.
  echo function updateLocalManifest^(patch = {}, options = {}^) {
  echo   const next = {
  echo     ...^(state.localManifest ^|^| getDefaultLocalManifest^(^)^),
  echo     ...patch
  echo   };
  echo   state.localManifest = next;
  echo   if ^(^!state.assistants^) {
  echo     state.assistants = {};
  echo   }
  echo   state.assistants[LOCAL_AGENT_KEY] = { ...next };
  echo   if ^(^!options.skipSummary^) {
  echo     renderAssistantSummary^(^);
  echo   }
  echo }
  echo.
  echo function scheduleSettingsSave^(^) {
  echo   clearTimeout^(settingsSaveTimer^);
  echo   settingsSaveTimer = setTimeout^(^(^) =^> {
  echo     api.saveSettings^(state.settings^);
  echo   }, 400^);
  echo }
  echo.
  echo function appendLog^(entry^) {
  echo   state.log.push^(entry^);
  echo   if ^(state.log.length ^> 2000^) {
  echo     state.log = state.log.slice^(-2000^);
  echo   }
  echo   renderLog^(^);
  echo }
  echo.
  echo function renderLog^(^) {
  echo   elements.logView.innerHTML = '';
  echo   state.log.slice^(-400^).forEach^(^(line^) =^> {
  echo     const div = document.createElement^('div'^);
  echo     div.className = 'log-entry';
  echo     div.textContent = line;
  echo     elements.logView.appendChild^(div^);
  echo   }^);
  echo   elements.logView.scrollTop = elements.logView.scrollHeight;
  echo }
  echo.
  echo function showToast^(message, timeout = 4000^) {
  echo   elements.toast.textContent = message;
  echo   elements.toast.classList.remove^('hidden'^);
  echo   clearTimeout^(elements.toast._timer^);
  echo   elements.toast._timer = setTimeout^(^(^) =^> {
  echo     elements.toast.classList.add^('hidden'^);
  echo   }, timeout^);
  echo }
  echo.
  echo function confirmSend^(message^) {
  echo   if ^(^!state.settings.confirmBeforeSend^) {
  echo     return Promise.resolve^(true^);
  echo   }
  echo   elements.confirmMessage.textContent = message;
  echo   elements.confirmModal.classList.remove^('hidden'^);
  echo   return new Promise^(^(resolve^) =^> {
  echo     state.confirmResolver = resolve;
  echo   }^);
  echo }
  echo.
  echo elements.confirmCancel.addEventListener^('click', ^(^) =^> {
  echo   if ^(state.confirmResolver^) {
  echo     state.confirmResolver^(false^);
  echo     state.confirmResolver = null;
  echo   }
  echo   elements.confirmModal.classList.add^('hidden'^);
  echo }^);
  echo.
  echo elements.confirmOk.addEventListener^('click', ^(^) =^> {
  echo   if ^(state.confirmResolver^) {
  echo     state.confirmResolver^(true^);
  echo     state.confirmResolver = null;
  echo   }
  echo   elements.confirmModal.classList.add^('hidden'^);
  echo }^);
  echo.
  echo function buildAgentOrderControls^(key^) {
  echo   const container = document.createElement^('div'^);
  echo   container.className = 'agent-order';
  echo   const up = document.createElement^('button'^);
  echo   up.textContent = '▲';
  echo   up.addEventListener^('click', ^(^) =^> {
  echo     const idx = state.order.indexOf^(key^);
  echo     if ^(idx ^> 0^) {
  echo       const swap = state.order[idx - 1];
  echo       state.order[idx - 1] = key;
  echo       state.order[idx] = swap;
  echo       renderAgents^(^);
  echo     }
  echo   }^);
  echo   const down = document.createElement^('button'^);
  echo   down.textContent = '▼';
  echo   down.addEventListener^('click', ^(^) =^> {
  echo     const idx = state.order.indexOf^(key^);
  echo     if ^(idx ^>= 0 ^&^& idx ^< state.order.length - 1^) {
  echo       const swap = state.order[idx + 1];
  echo       state.order[idx + 1] = key;
  echo       state.order[idx] = swap;
  echo       renderAgents^(^);
  echo     }
  echo   }^);
  echo   const badge = document.createElement^('span'^);
  echo   badge.className = 'round-badge';
  echo   badge.textContent = `#${state.order.indexOf^(key^) + 1}`;
  echo   container.appendChild^(up^);
  echo   container.appendChild^(down^);
  echo   container.appendChild^(badge^);
  echo   return container;
  echo }
  echo.
  echo function renderAgents^(^) {
  echo   elements.agentList.innerHTML = '';
  echo   state.order.forEach^(^(key^) =^> {
  echo     const assistant = state.assistants[key];
  echo     if ^(^!assistant^) return;
  echo     const config = state.selectors[key];
  echo     const item = document.createElement^('div'^);
  echo     item.className = 'agent-item';
  echo     if ^(assistant.type === 'local'^) {
  echo       item.classList.add^('local'^);
  echo     }
  echo     if ^(state.selected.has^(key^)^) {
  echo       item.classList.add^('active'^);
  echo     }
  echo.
  echo     const top = document.createElement^('div'^);
  echo     top.className = 'agent-top';
  echo     const name = document.createElement^('div'^);
  echo     const label = assistant.displayName ^|^| config?.displayName ^|^| key;
  echo     name.innerHTML = `^<strong^>${label}^</strong^> ^<span class="badge"^>${key}^</span^>`;
  echo.
  echo     const toggle = document.createElement^('input'^);
  echo     toggle.type = 'checkbox';
  echo     toggle.checked = state.selected.has^(key^);
  echo     toggle.addEventListener^('change', ^(^) =^> {
  echo       if ^(toggle.checked^) {
  echo         state.selected.add^(key^);
  echo       } else {
  echo         state.selected.delete^(key^);
  echo       }
  echo       renderAgents^(^);
  echo     }^);
  echo.
  echo     top.appendChild^(name^);
  echo     top.appendChild^(toggle^);
  echo.
  echo     const status = document.createElement^('div'^);
  echo     status.className = 'agent-status';
  echo     const data = state.agents[key];
  echo     const statusBits = [];
  echo     if ^(data ^&^& data.status^) {
  echo       statusBits.push^(data.status^);
  echo     }
  echo     if ^(data ^&^& data.visible ^&^& assistant.type ^!== 'local'^) {
  echo       statusBits.push^('visible'^);
  echo     }
  echo     if ^(data ^&^& data.error^) {
  echo       statusBits.push^(`error: ${data.error}`^);
  echo     }
  echo     if ^(assistant.type === 'local'^) {
  echo       const host = ^(data ^&^& data.host^) ^|^| state.settings.ollamaHost ^|^| '';
  echo       const model = ^(data ^&^& data.model^) ^|^| state.settings.ollamaModel ^|^| '';
  echo       statusBits.push^(model ? `model: ${model}` : 'model pending'^);
  echo       if ^(host^) {
  echo         try {
  echo           const parsed = new URL^(host^);
  echo           statusBits.push^(parsed.host ^|^| host^);
  echo         } catch ^(error^) {
  echo           statusBits.push^(host^);
  echo         }
  echo       } else {
  echo         statusBits.push^('host offline'^);
  echo       }
  echo     } else if ^(data ^&^& data.url^) {
  echo       try {
  echo         const url = new URL^(data.url^);
  echo         statusBits.push^(url.hostname^);
  echo       } catch ^(error^) {
  echo         statusBits.push^(data.url^);
  echo       }
  echo     }
  echo     status.textContent = statusBits.join^(' · '^) ^|^| 'offline';
  echo.
  echo     const actions = document.createElement^('div'^);
  echo     actions.className = 'agent-actions';
  echo.
  echo     if ^(assistant.type === 'local'^) {
  echo       const studioBtn = document.createElement^('button'^);
  echo       studioBtn.className = 'secondary';
  echo       studioBtn.textContent = 'Focus Studio';
  echo       studioBtn.addEventListener^('click', ^(^) =^> {
  echo         document.getElementById^('ollamaHostField'^)?.scrollIntoView^({ behavior: 'smooth', block: 'center' }^);
  echo         showToast^('Local Studio ready below.'^);
  echo       }^);
  echo       const refreshBtn = document.createElement^('button'^);
  echo       refreshBtn.className = 'secondary';
  echo       refreshBtn.textContent = 'Refresh models';
  echo       refreshBtn.addEventListener^('click', ^(^) =^> refreshOllamaModels^(^)^);
  echo       actions.appendChild^(studioBtn^);
  echo       actions.appendChild^(refreshBtn^);
  echo     } else {
  echo       const connectBtn = document.createElement^('button'^);
  echo       connectBtn.className = 'secondary';
  echo       connectBtn.textContent = 'Connect';
  echo       connectBtn.addEventListener^('click', async ^(^) =^> {
  echo         await api.connectAgent^(key^);
  echo       }^);
  echo.
  echo       const hideBtn = document.createElement^('button'^);
  echo       hideBtn.className = 'secondary';
  echo       hideBtn.textContent = 'Hide';
  echo       hideBtn.addEventListener^('click', async ^(^) =^> {
  echo         await api.hideAgent^(key^);
  echo       }^);
  echo.
  echo       const readBtn = document.createElement^('button'^);
  echo       readBtn.className = 'secondary';
  echo       readBtn.textContent = 'Read';
  echo       readBtn.addEventListener^('click', async ^(^) =^> {
  echo         await ensureAgent^(key^);
  echo         const messages = await api.readAgent^(key^);
  echo         appendLog^(`${key}:\n${messages.join^('\n'^)}`^);
  echo       }^);
  echo.
  echo       actions.appendChild^(connectBtn^);
  echo       actions.appendChild^(hideBtn^);
  echo       actions.appendChild^(readBtn^);
  echo.
  echo       if ^(^!isDefaultKey^(key^)^) {
  echo         const removeBtn = document.createElement^('button'^);
  echo         removeBtn.className = 'secondary';
  echo         removeBtn.textContent = 'Remove';
  echo         removeBtn.addEventListener^('click', ^(^) =^> {
  echo           delete state.selectors[key];
  echo           state.order = state.order.filter^(^(k^) =^> k ^!== key^);
  echo           state.selected.delete^(key^);
  echo           persistSelectors^(^);
  echo           renderAgents^(^);
  echo           renderSiteEditor^(^);
  echo         }^);
  echo         actions.appendChild^(removeBtn^);
  echo       } else {
  echo         const resetBtn = document.createElement^('button'^);
  echo         resetBtn.className = 'secondary';
  echo         resetBtn.textContent = 'Reset';
  echo         resetBtn.addEventListener^('click', async ^(^) =^> {
  echo           await api.resetAgentSelectors^(key^);
  echo           await reloadSelectors^(^);
  echo           renderSiteEditor^(^);
  echo         }^);
  echo         actions.appendChild^(resetBtn^);
  echo       }
  echo     }
  echo.
  echo     const orderControls = buildAgentOrderControls^(key^);
  echo.
  echo     item.appendChild^(top^);
  echo     item.appendChild^(status^);
  echo     item.appendChild^(actions^);
  echo     item.appendChild^(orderControls^);
  echo     elements.agentList.appendChild^(item^);
  echo   }^);
  echo   updateTargetControls^(^);
  echo }
  echo.
  echo function renderTargetDropdown^(^) {
  echo   const selected = Array.from^(state.order^).filter^(^(key^) =^> state.assistants[key]^);
  echo   elements.singleTarget.innerHTML = '';
  echo   selected.forEach^(^(key^) =^> {
  echo     const option = document.createElement^('option'^);
  echo     const assistant = state.assistants[key];
  echo     option.value = key;
  echo     option.textContent = assistant.displayName ^|^| key;
  echo     elements.singleTarget.appendChild^(option^);
  echo   }^);
  echo   const firstSelected = Array.from^(state.selected^)[0];
  echo   if ^(firstSelected ^&^& state.selectors[firstSelected]^) {
  echo     elements.singleTarget.value = firstSelected;
  echo   } else if ^(elements.singleTarget.options.length^) {
  echo     elements.singleTarget.selectedIndex = 0;
  echo   }
  echo   elements.singleSendBtn.disabled = elements.singleTarget.options.length === 0;
  echo }
  echo.
  echo function renderTargetChips^(^) {
  echo   if ^(^!elements.targetChips^) return;
  echo   elements.targetChips.innerHTML = '';
  echo   const fragment = document.createDocumentFragment^(^);
  echo   let hasAny = false;
  echo   state.order.forEach^(^(key^) =^> {
  echo     if ^(^!state.assistants[key]^) return;
  echo     hasAny = true;
  echo     const assistant = state.assistants[key];
  echo     const chip = document.createElement^('button'^);
  echo     chip.type = 'button';
  echo     chip.className = 'chip';
  echo     chip.textContent = assistant.displayName ^|^| key;
  echo     if ^(state.selected.has^(key^)^) {
  echo       chip.classList.add^('active'^);
  echo     }
  echo     chip.addEventListener^('click', ^(^) =^> {
  echo       if ^(state.selected.has^(key^)^) {
  echo         state.selected.delete^(key^);
  echo       } else {
  echo         state.selected.add^(key^);
  echo       }
  echo       renderAgents^(^);
  echo     }^);
  echo     fragment.appendChild^(chip^);
  echo   }^);
  echo.
  echo   if ^(^!hasAny^) {
  echo     const empty = document.createElement^('span'^);
  echo     empty.className = 'chip-empty';
  echo     empty.textContent = 'No assistants available.';
  echo     fragment.appendChild^(empty^);
  echo   }
  echo.
  echo   elements.targetChips.appendChild^(fragment^);
  echo }
  echo.
  echo function updateTargetControls^(^) {
  echo   renderTargetDropdown^(^);
  echo   renderTargetChips^(^);
  echo }
  echo.
  echo function renderSiteEditor^(^) {
  echo   elements.siteEditor.innerHTML = '';
  echo   const orderedKeys = state.order.length
  echo     ? state.order.filter^(^(key^) =^> state.selectors[key]^)
  echo     : Object.keys^(state.selectors^);
  echo   const extras = Object.keys^(state.selectors^).filter^(^(key^) =^> ^!orderedKeys.includes^(key^)^);
  echo   const keys = [...orderedKeys, ...extras];
  echo.
  echo   keys.forEach^(^(key^) =^> {
  echo     const config = state.selectors[key];
  echo     if ^(^!config^) return;
  echo     const row = document.createElement^('div'^);
  echo     row.className = 'site-row';
  echo     row.dataset.key = key;
  echo     row.innerHTML = `
  echo       ^<div class="agent-top"^>
  echo         ^<strong^>${config.displayName ^|^| key}^</strong^>
  echo         ^<span class="badge"^>${key}^</span^>
  echo       ^</div^>
  echo       ^<label^>Display name
  echo         ^<input type="text" class="field-name" value="${config.displayName ^|^| ''}" /^>
  echo       ^</label^>
  echo       ^<label^>Home URL
  echo         ^<input type="text" class="field-home" value="${config.home ^|^| ''}" /^>
  echo       ^</label^>
  echo       ^<label^>URL patterns ^(one per line^)
  echo         ^<textarea class="field-patterns"^>${^(config.patterns ^|^| []^).join^('\n'^)}^</textarea^>
  echo       ^</label^>
  echo       ^<label^>Input selectors
  echo         ^<textarea class="field-input"^>${^(config.input ^|^| []^).join^('\n'^)}^</textarea^>
  echo       ^</label^>
  echo       ^<label^>Send button selectors
  echo         ^<textarea class="field-send"^>${^(config.sendButton ^|^| []^).join^('\n'^)}^</textarea^>
  echo       ^</label^>
  echo       ^<label^>Message container selectors
  echo         ^<textarea class="field-message"^>${^(config.messageContainer ^|^| []^).join^('\n'^)}^</textarea^>
  echo       ^</label^>
  echo     `;
  echo.
  echo     const actions = document.createElement^('div'^);
  echo     actions.className = 'site-actions';
  echo.
  echo     const saveBtn = document.createElement^('button'^);
  echo     saveBtn.className = 'secondary';
  echo     saveBtn.textContent = 'Save';
  echo     saveBtn.addEventListener^('click', ^(^) =^> {
  echo       persistSelectors^(^);
  echo       showToast^(`${key} selectors saved.`^);
  echo     }^);
  echo.
  echo     actions.appendChild^(saveBtn^);
  echo.
  echo     if ^(^!isDefaultKey^(key^)^) {
  echo       const deleteBtn = document.createElement^('button'^);
  echo       deleteBtn.className = 'secondary';
  echo       deleteBtn.textContent = 'Delete';
  echo       deleteBtn.addEventListener^('click', ^(^) =^> {
  echo         delete state.selectors[key];
  echo         state.order = state.order.filter^(^(k^) =^> k ^!== key^);
  echo         persistSelectors^(^);
  echo         renderSiteEditor^(^);
  echo         renderAgents^(^);
  echo       }^);
  echo       actions.appendChild^(deleteBtn^);
  echo     }
  echo.
  echo     row.appendChild^(actions^);
  echo     elements.siteEditor.appendChild^(row^);
  echo   }^);
  echo   populateTemplateSelect^(^);
  echo }
  echo.
  echo function slugifyKey^(value = ''^) {
  echo   return value
  echo     .toLowerCase^(^)
  echo     .trim^(^)
  echo     .replace^(/[^^a-z0-9]+/g, '-'^)
  echo     .replace^(/^^-+^|-+$/g, ''^)
  echo     .slice^(0, 48^);
  echo }
  echo.
  echo function clearNewSiteForm^(^) {
  echo   if ^(^!elements.newSiteName^) return;
  echo   elements.newSiteName.value = '';
  echo   if ^(elements.newSiteHome^) elements.newSiteHome.value = '';
  echo   if ^(elements.newSitePatterns^) elements.newSitePatterns.value = '';
  echo   if ^(elements.newSiteInput^) elements.newSiteInput.value = '';
  echo   if ^(elements.newSiteSend^) elements.newSiteSend.value = '';
  echo   if ^(elements.newSiteMessages^) elements.newSiteMessages.value = '';
  echo   if ^(elements.newSiteTemplate^) elements.newSiteTemplate.value = '';
  echo   if ^(elements.newSiteKey^) {
  echo     elements.newSiteKey.value = '';
  echo     delete elements.newSiteKey.dataset.manual;
  echo   }
  echo }
  echo.
  echo function populateTemplateSelect^(^) {
  echo   if ^(^!elements.newSiteTemplate^) return;
  echo   const currentValue = elements.newSiteTemplate.value;
  echo   elements.newSiteTemplate.innerHTML = '';
  echo   const placeholder = document.createElement^('option'^);
  echo   placeholder.value = '';
  echo   placeholder.textContent = 'Choose template…';
  echo   elements.newSiteTemplate.appendChild^(placeholder^);
  echo.
  echo   const seen = new Set^(^);
  echo   const addOption = ^(value, label^) =^> {
  echo     if ^(^!value ^|^| seen.has^(value^)^) return;
  echo     seen.add^(value^);
  echo     const option = document.createElement^('option'^);
  echo     option.value = value;
  echo     option.textContent = label;
  echo     elements.newSiteTemplate.appendChild^(option^);
  echo   };
  echo.
  echo   Object.entries^(state.defaultSelectors ^|^| {}^).forEach^(^([key, config]^) =^> {
  echo     addOption^(`default:${key}`, `${config.displayName ^|^| key} ^(default^)`^);
  echo   }^);
  echo   Object.entries^(state.selectors ^|^| {}^).forEach^(^([key, config]^) =^> {
  echo     addOption^(`current:${key}`, `${config.displayName ^|^| key} ^(current^)`^);
  echo   }^);
  echo.
  echo   if ^(currentValue ^&^& seen.has^(currentValue^)^) {
  echo     elements.newSiteTemplate.value = currentValue;
  echo   }
  echo }
  echo.
  echo function applyTemplateSelection^(value^) {
  echo   if ^(^!value ^|^| ^!elements.newSiteKey^) return;
  echo   const [scope, key] = value.split^(':'^);
  echo   if ^(^!key^) return;
  echo   let template = null;
  echo   if ^(scope === 'default'^) {
  echo     template = state.defaultSelectors?.[key] ^|^| null;
  echo   } else if ^(scope === 'current'^) {
  echo     template = state.selectors?.[key] ^|^| null;
  echo   }
  echo   if ^(^!template^) return;
  echo   const displayName = template.displayName ^|^| key;
  echo   if ^(^!elements.newSiteName.value.trim^(^)^) {
  echo     elements.newSiteName.value = displayName;
  echo   }
  echo   if ^(^!elements.newSiteKey.dataset.manual ^|^| ^!elements.newSiteKey.value.trim^(^)^) {
  echo     elements.newSiteKey.value = slugifyKey^(elements.newSiteName.value ^|^| displayName^);
  echo   }
  echo   elements.newSiteHome.value = template.home ^|^| '';
  echo   elements.newSitePatterns.value = ^(template.patterns ^|^| []^).join^('\n'^);
  echo   elements.newSiteInput.value = ^(template.input ^|^| []^).join^('\n'^);
  echo   elements.newSiteSend.value = ^(template.sendButton ^|^| []^).join^('\n'^);
  echo   elements.newSiteMessages.value = ^(template.messageContainer ^|^| []^).join^('\n'^);
  echo }
  echo.
  echo function collectNewSiteForm^(^) {
  echo   if ^(^!elements.newSiteName^) return null;
  echo   const name = elements.newSiteName.value.trim^(^);
  echo   let key = elements.newSiteKey.value.trim^(^).toLowerCase^(^);
  echo   if ^(^!key^) {
  echo     key = slugifyKey^(name^);
  echo     elements.newSiteKey.value = key;
  echo   }
  echo   if ^(^!key^) {
  echo     showToast^('Enter an assistant key.'^);
  echo     return null;
  echo   }
  echo   if ^(^!/^^[a-z0-9\-]+$/.test^(key^)^) {
  echo     showToast^('Key must use letters, numbers, or hyphen.'^);
  echo     return null;
  echo   }
  echo   if ^(state.selectors[key]^) {
  echo     showToast^('That key already exists.'^);
  echo     return null;
  echo   }
  echo   const homeField = elements.newSiteHome;
  echo   const patternField = elements.newSitePatterns;
  echo   const inputField = elements.newSiteInput;
  echo   const sendField = elements.newSiteSend;
  echo   const messageField = elements.newSiteMessages;
  echo   const home = homeField ? homeField.value.trim^(^) : '';
  echo   const patterns = ^(patternField ? patternField.value : ''^)
  echo     .split^(/\r?\n/^)
  echo     .map^(^(line^) =^> line.trim^(^)^)
  echo     .filter^(Boolean^);
  echo   const input = ^(inputField ? inputField.value : ''^)
  echo     .split^(/\r?\n/^)
  echo     .map^(^(line^) =^> line.trim^(^)^)
  echo     .filter^(Boolean^);
  echo   const sendButton = ^(sendField ? sendField.value : ''^)
  echo     .split^(/\r?\n/^)
  echo     .map^(^(line^) =^> line.trim^(^)^)
  echo     .filter^(Boolean^);
  echo   const messageContainer = ^(messageField ? messageField.value : ''^)
  echo     .split^(/\r?\n/^)
  echo     .map^(^(line^) =^> line.trim^(^)^)
  echo     .filter^(Boolean^);
  echo.
  echo   if ^(^!patterns.length ^&^& home^) {
  echo     patterns.push^(home^);
  echo   }
  echo   if ^(^!patterns.length^) {
  echo     showToast^('Provide at least one URL pattern.'^);
  echo     return null;
  echo   }
  echo   if ^(^!input.length^) {
  echo     showToast^('Provide at least one input selector.'^);
  echo     return null;
  echo   }
  echo   if ^(^!sendButton.length^) {
  echo     showToast^('Provide at least one send button selector.'^);
  echo     return null;
  echo   }
  echo   if ^(^!messageContainer.length^) {
  echo     showToast^('Provide at least one message container selector.'^);
  echo     return null;
  echo   }
  echo.
  echo   const config = {
  echo     displayName: name ^|^| key,
  echo     home,
  echo     patterns,
  echo     input,
  echo     sendButton,
  echo     messageContainer
  echo   };
  echo.
  echo   return { key, config };
  echo }
  echo.
  echo function collectSelectorsFromEditor^(^) {
  echo   const rows = elements.siteEditor.querySelectorAll^('.site-row'^);
  echo   const next = {};
  echo   rows.forEach^(^(row^) =^> {
  echo     const key = row.dataset.key.trim^(^);
  echo     const displayName = row.querySelector^('.field-name'^).value.trim^(^) ^|^| key;
  echo     const home = row.querySelector^('.field-home'^).value.trim^(^);
  echo     const patterns = row
  echo       .querySelector^('.field-patterns'^)
  echo       .value.split^(/\r?\n/^)
  echo       .map^(^(s^) =^> s.trim^(^)^)
  echo       .filter^(Boolean^);
  echo     const input = row
  echo       .querySelector^('.field-input'^)
  echo       .value.split^(/\r?\n/^)
  echo       .map^(^(s^) =^> s.trim^(^)^)
  echo       .filter^(Boolean^);
  echo     const sendButton = row
  echo       .querySelector^('.field-send'^)
  echo       .value.split^(/\r?\n/^)
  echo       .map^(^(s^) =^> s.trim^(^)^)
  echo       .filter^(Boolean^);
  echo     const messageContainer = row
  echo       .querySelector^('.field-message'^)
  echo       .value.split^(/\r?\n/^)
  echo       .map^(^(s^) =^> s.trim^(^)^)
  echo       .filter^(Boolean^);
  echo     next[key] = {
  echo       displayName,
  echo       home,
  echo       patterns: patterns.length ? patterns : home ? [home] : [],
  echo       input,
  echo       sendButton,
  echo       messageContainer
  echo     };
  echo   }^);
  echo   return next;
  echo }
  echo.
  echo async function persistSelectors^(^) {
  echo   const next = collectSelectorsFromEditor^(^);
  echo   state.selectors = next;
  echo   await api.saveSelectors^(next^);
  echo   syncAssistantManifest^(^);
  echo   renderAgents^(^);
  echo }
  echo.
  echo function collectSettingsFromModal^(^) {
  echo   return {
  echo     confirmBeforeSend: elements.confirmToggle.checked,
  echo     delayMin: Number^(elements.delayMin.value^) ^|^| 0,
  echo     delayMax: Number^(elements.delayMax.value^) ^|^| 0,
  echo     messageLimit: Number^(elements.messageLimit.value^) ^|^| 1,
  echo     roundTableTurns: Number^(elements.defaultTurns.value^) ^|^| 1,
  echo     copilotHost: elements.copilotHost.value.trim^(^),
  echo     comfyHost: elements.settingsComfyHost.value.trim^(^),
  echo     comfyAutoImport: elements.settingsComfyAuto.checked,
  echo     ollamaHost: elements.settingsOllamaHost.value.trim^(^),
  echo     ollamaModel: elements.settingsOllamaModel.value.trim^(^)
  echo   };
  echo }
  echo.
  echo async function persistSettings^(^) {
  echo   const next = collectSettingsFromModal^(^);
  echo   const previousOllamaHost = state.settings.ollamaHost;
  echo   const previousComfyHost = state.settings.comfyHost;
  echo   const previousComfyAuto = state.settings.comfyAutoImport;
  echo   state.settings = { ...state.settings, ...next };
  echo   await api.saveSettings^(state.settings^);
  echo   updateLocalManifest^({
  echo     host: state.settings.ollamaHost ^|^| '',
  echo     model: state.settings.ollamaModel ^|^| state.localManifest?.model ^|^| ''
  echo   }^);
  echo   elements.roundTurns.value = state.settings.roundTableTurns;
  echo   syncStudioHosts^(^);
  echo   if ^(next.ollamaHost ^!== previousOllamaHost^) {
  echo     state.local.ollamaOutput = '';
  echo     renderOllamaOutput^(^);
  echo     refreshOllamaModels^({ silent: true }^);
  echo   }
  echo   if ^(next.comfyHost ^!== previousComfyHost^) {
  echo     state.local.comfyImported = new Set^(^);
  echo     refreshComfyHistory^({ silent: true }^);
  echo   }
  echo   if ^(^!previousComfyAuto ^&^& state.settings.comfyAutoImport^) {
  echo     autoImportComfyResult^(^);
  echo   }
  echo }
  echo.
  echo function openSettingsModal^(^) {
  echo   renderSiteEditor^(^);
  echo   hydrateSettings^(^);
  echo   elements.settingsModal.classList.remove^('hidden'^);
  echo   document.body.classList.add^('modal-open'^);
  echo }
  echo.
  echo async function closeSettingsModal^(save = true^) {
  echo   if ^(save^) {
  echo     await persistSelectors^(^);
  echo     await persistSettings^(^);
  echo     showToast^('Settings saved.'^);
  echo   } else {
  echo     renderSiteEditor^(^);
  echo     hydrateSettings^(^);
  echo   }
  echo   elements.settingsModal.classList.add^('hidden'^);
  echo   document.body.classList.remove^('modal-open'^);
  echo }
  echo.
  echo elements.openSettings.addEventListener^('click', ^(^) =^> {
  echo   openSettingsModal^(^);
  echo }^);
  echo.
  echo if ^(elements.manageAssistants^) {
  echo   elements.manageAssistants.addEventListener^('click', ^(^) =^> {
  echo     openSettingsModal^(^);
  echo   }^);
  echo }
  echo.
  echo elements.closeSettings.addEventListener^('click', async ^(^) =^> {
  echo   await closeSettingsModal^(true^);
  echo }^);
  echo.
  echo elements.settingsModal.addEventListener^('click', async ^(event^) =^> {
  echo   if ^(event.target === elements.settingsModal^) {
  echo     await closeSettingsModal^(false^);
  echo   }
  echo }^);
  echo.
  echo document.addEventListener^('keydown', async ^(event^) =^> {
  echo   if ^(event.key === 'Escape' ^&^& ^!elements.settingsModal.classList.contains^('hidden'^)^) {
  echo     await closeSettingsModal^(false^);
  echo   }
  echo }^);
  echo.
  echo if ^(elements.addSiteBtn^) {
  echo   elements.addSiteBtn.addEventListener^('click', async ^(^) =^> {
  echo     const entry = collectNewSiteForm^(^);
  echo     if ^(^!entry^) {
  echo       return;
  echo     }
  echo     const { key, config } = entry;
  echo     state.selectors[key] = config;
  echo     if ^(^!state.order.includes^(key^)^) {
  echo       state.order.push^(key^);
  echo     }
  echo     state.selected.add^(key^);
  echo     await api.saveSelectors^(state.selectors^);
  echo     syncAssistantManifest^(^);
  echo     renderAgents^(^);
  echo     renderSiteEditor^(^);
  echo     showToast^(`${config.displayName ^|^| key} added.`^);
  echo     clearNewSiteForm^(^);
  echo   }^);
  echo }
  echo.
  echo if ^(elements.resetSiteForm^) {
  echo   elements.resetSiteForm.addEventListener^('click', ^(^) =^> {
  echo     clearNewSiteForm^(^);
  echo   }^);
  echo }
  echo.
  echo if ^(elements.newSiteTemplate^) {
  echo   elements.newSiteTemplate.addEventListener^('change', ^(^) =^> {
  echo     applyTemplateSelection^(elements.newSiteTemplate.value^);
  echo   }^);
  echo }
  echo.
  echo if ^(elements.newSiteName ^&^& elements.newSiteKey^) {
  echo   elements.newSiteName.addEventListener^('input', ^(^) =^> {
  echo     if ^(^!elements.newSiteKey.dataset.manual^) {
  echo       elements.newSiteKey.value = slugifyKey^(elements.newSiteName.value^);
  echo     }
  echo   }^);
  echo }
  echo.
  echo if ^(elements.newSiteKey^) {
  echo   elements.newSiteKey.addEventListener^('input', ^(^) =^> {
  echo     if ^(elements.newSiteKey.value.trim^(^)^) {
  echo       elements.newSiteKey.dataset.manual = '1';
  echo     } else {
  echo       delete elements.newSiteKey.dataset.manual;
  echo       if ^(elements.newSiteName ^&^& elements.newSiteName.value.trim^(^)^) {
  echo         elements.newSiteKey.value = slugifyKey^(elements.newSiteName.value^);
  echo       }
  echo     }
  echo   }^);
  echo }
  echo.
  echo if ^(elements.importSelectorsBtn^) {
  echo   elements.importSelectorsBtn.addEventListener^('click', async ^(^) =^> {
  echo     const result = await api.importSelectors^(^);
  echo     if ^(result ^&^& result.ok^) {
  echo       state.selectors = result.selectors ^|^| state.selectors;
  echo       state.order = Object.keys^(state.selectors^);
  echo       syncAssistantManifest^(^);
  echo       renderAgents^(^);
  echo       renderSiteEditor^(^);
  echo       clearNewSiteForm^(^);
  echo       showToast^('selectors.json imported.'^);
  echo     } else if ^(result ^&^& result.error^) {
  echo       showToast^(`Import failed: ${result.error}`^);
  echo     }
  echo   }^);
  echo }
  echo.
  echo if ^(elements.exportSelectorsBtn^) {
  echo   elements.exportSelectorsBtn.addEventListener^('click', async ^(^) =^> {
  echo     const result = await api.exportSelectors^(^);
  echo     if ^(result ^&^& result.ok^) {
  echo       showToast^(`selectors.json exported to ${result.path}`^);
  echo     } else if ^(result ^&^& result.error^) {
  echo       showToast^(`Export failed: ${result.error}`^);
  echo     }
  echo   }^);
  echo }
  echo.
  echo if ^(elements.openConfigBtn^) {
  echo   elements.openConfigBtn.addEventListener^('click', async ^(^) =^> {
  echo     await api.openConfigFolder^(^);
  echo     showToast^('Config folder opened in Explorer.'^);
  echo   }^);
  echo }
  echo.
  echo async function ensureAgent^(key^) {
  echo   try {
  echo     const status = await api.ensureAgent^(key^);
  echo     if ^(status^) {
  echo       state.agents[key] = { ...state.agents[key], ...status };
  echo       renderAgents^(^);
  echo     }
  echo   } catch ^(error^) {
  echo     showToast^(`${key}: unable to reach agent window.`^);
  echo   }
  echo }
  echo.
  echo async function sendToAgents^(targets, message, modeLabel^) {
  echo   if ^(^!message^) {
  echo     showToast^('Composer is empty.'^);
  echo     return;
  echo   }
  echo   if ^(^!targets.length^) {
  echo     showToast^('Select at least one assistant.'^);
  echo     return;
  echo   }
  echo   if ^(state.settings.confirmBeforeSend^) {
  echo     const ok = await confirmSend^(`Confirm ${modeLabel} to ${targets.length} assistant^(s^)?`^);
  echo     if ^(^!ok^) {
  echo       return;
  echo     }
  echo   }
  echo   for ^(const key of targets^) {
  echo     await ensureAgent^(key^);
  echo     try {
  echo       await api.sendAgent^({ key, text: buildMessageWithAttachments^(message^) }^);
  echo       appendLog^(`${key}: message queued.`^);
  echo     } catch ^(error^) {
  echo       appendLog^(`${key}: send error ${error.message ^|^| error}`^);
  echo       showToast^(`${key}: failed to send. Check selectors.`^);
  echo     }
  echo   }
  echo }
  echo.
  echo function buildMessageWithAttachments^(base^) {
  echo   if ^(^!state.attachments.length^) return base;
  echo   const parts = [base];
  echo   state.attachments.forEach^(^(attachment, index^) =^> {
  echo     if ^(attachment.type === 'text'^) {
  echo       parts.push^(`\n\n[Attachment ${index + 1}] ${attachment.title}\n${attachment.meta}\n${attachment.body}`^);
  echo     } else {
  echo       const meta = attachment.meta ? `\n${attachment.meta}` : '';
  echo       parts.push^(`\n\n[Attachment ${index + 1}] ${attachment.title}${meta}\n^(${attachment.type ^|^| 'asset'} attached in OmniChat^)`^);
  echo     }
  echo   }^);
  echo   return parts.join^(''^);
  echo }
  echo.
  echo elements.broadcastBtn.addEventListener^('click', async ^(^) =^> {
  echo   const targets = Array.from^(state.selected^);
  echo   const message = elements.composerInput.value.trim^(^);
  echo   await sendToAgents^(targets, message, 'broadcast'^);
  echo }^);
  echo.
  echo elements.singleSendBtn.addEventListener^('click', async ^(^) =^> {
  echo   const key = elements.singleTarget.value;
  echo   const message = elements.composerInput.value.trim^(^);
  echo   if ^(^!key^) {
  echo     showToast^('Choose a target.'^);
  echo     return;
  echo   }
  echo   await sendToAgents^([key], message, `send to ${key}`^);
  echo }^);
  echo.
  echo function getPrimaryAgentKey^(^) {
  echo   if ^(state.selected.size ^> 0^) {
  echo     return Array.from^(state.selected^)[0];
  echo   }
  echo   const keys = state.order.filter^(^(key^) =^> state.assistants[key]^);
  echo   return keys[0];
  echo }
  echo.
  echo elements.quoteBtn.addEventListener^('click', async ^(^) =^> {
  echo   const key = getPrimaryAgentKey^(^);
  echo   if ^(^!key^) {
  echo     showToast^('No assistants available.'^);
  echo     return;
  echo   }
  echo   await ensureAgent^(key^);
  echo   const result = await api.captureSelection^(key^);
  echo   if ^(^!result ^|^| ^!result.ok ^|^| ^!result.selection^) {
  echo     showToast^('No selection captured.'^);
  echo     return;
  echo   }
  echo   pushAttachment^({
  echo     title: `Quote from ${result.title ^|^| key}`,
  echo     meta: result.url ^|^| '',
  echo     body: result.selection
  echo   }^);
  echo }^);
  echo.
  echo elements.snapshotBtn.addEventListener^('click', async ^(^) =^> {
  echo   const key = getPrimaryAgentKey^(^);
  echo   if ^(^!key^) {
  echo     showToast^('No assistants available.'^);
  echo     return;
  echo   }
  echo   await ensureAgent^(key^);
  echo   const result = await api.snapshotPage^({ key, limit: 2000 }^);
  echo   if ^(^!result ^|^| ^!result.ok^) {
  echo     showToast^('Snapshot failed.'^);
  echo     return;
  echo   }
  echo   pushAttachment^({
  echo     title: `Snapshot: ${result.title ^|^| key}`,
  echo     meta: result.url ^|^| '',
  echo     body: result.content ^|^| ''
  echo   }^);
  echo }^);
  echo.
  echo elements.attachBtn.addEventListener^('click', ^(^) =^> {
  echo   const text = prompt^('Paste text to attach.'^);
  echo   if ^(^!text^) {
  echo     return;
  echo   }
  echo   const chunks = text.match^(/.{1,1800}/gs^) ^|^| [];
  echo   chunks.forEach^(^(chunk, index^) =^> {
  echo     pushAttachment^({
  echo       title: index === 0 ? 'Snippet' : `Snippet part ${index + 1}`,
  echo       meta: `Length ${chunk.length} characters`,
  echo       body: chunk
  echo     }^);
  echo   }^);
  echo }^);
  echo.
  echo if ^(elements.ollamaRefresh^) {
  echo   elements.ollamaRefresh.addEventListener^('click', ^(^) =^> {
  echo     refreshOllamaModels^(^);
  echo   }^);
  echo }
  echo.
  echo if ^(elements.ollamaGenerate^) {
  echo   elements.ollamaGenerate.addEventListener^('click', ^(^) =^> {
  echo     runOllamaGeneration^(^);
  echo   }^);
  echo }
  echo.
  echo if ^(elements.ollamaInsert^) {
  echo   elements.ollamaInsert.addEventListener^('click', ^(^) =^> {
  echo     if ^(^!state.local.ollamaOutput^) {
  echo       showToast^('Generate with Ollama first.'^);
  echo       return;
  echo     }
  echo     const existing = elements.composerInput.value.trim^(^);
  echo     const snippet = `Ollama ^(${state.settings.ollamaModel ^|^| 'model'}^):\n${state.local.ollamaOutput}`;
  echo     elements.composerInput.value = existing ? `${existing}\n\n${snippet}` : snippet;
  echo   }^);
  echo }
  echo.
  echo if ^(elements.ollamaModelSelect^) {
  echo   elements.ollamaModelSelect.addEventListener^('change', ^(^) =^> {
  echo     const value = elements.ollamaModelSelect.value;
  echo     state.settings.ollamaModel = value;
  echo     scheduleSettingsSave^(^);
  echo     updateLocalManifest^({ model: value }^);
  echo   }^);
  echo }
  echo.
  echo if ^(elements.ollamaHostField^) {
  echo   elements.ollamaHostField.addEventListener^('change', ^(^) =^> {
  echo     state.settings.ollamaHost = elements.ollamaHostField.value.trim^(^);
  echo     scheduleSettingsSave^(^);
  echo     updateLocalManifest^({ host: state.settings.ollamaHost }^);
  echo     state.local.ollamaOutput = '';
  echo     renderOllamaOutput^(^);
  echo     refreshOllamaModels^({ silent: true }^);
  echo   }^);
  echo }
  echo.
  echo if ^(elements.comfyHostField^) {
  echo   elements.comfyHostField.addEventListener^('change', ^(^) =^> {
  echo     state.settings.comfyHost = elements.comfyHostField.value.trim^(^);
  echo     scheduleSettingsSave^(^);
  echo     state.local.comfyImported = new Set^(^);
  echo     refreshComfyHistory^({ silent: true }^);
  echo   }^);
  echo }
  echo.
  echo if ^(elements.comfyRefresh^) {
  echo   elements.comfyRefresh.addEventListener^('click', ^(^) =^> {
  echo     refreshComfyHistory^(^);
  echo   }^);
  echo }
  echo.
  echo if ^(elements.comfyRun^) {
  echo   elements.comfyRun.addEventListener^('click', async ^(^) =^> {
  echo     try {
  echo       setComfyBusy^(true^);
  echo       const host = elements.comfyHostField.value.trim^(^);
  echo       state.settings.comfyHost = host;
  echo       scheduleSettingsSave^(^);
  echo       const result = await api.runComfyWorkflow^(host ^|^| undefined^);
  echo       if ^(^!result ^|^| ^!result.ok^) {
  echo         if ^(result?.canceled^) {
  echo           renderComfyStatus^('Workflow selection canceled.'^);
  echo           return;
  echo         }
  echo         throw new Error^(result?.error ^|^| 'Workflow launch failed.'^);
  echo       }
  echo       renderComfyStatus^('Workflow queued. Waiting for results…'^);
  echo       showToast^('ComfyUI workflow submitted.'^);
  echo       setTimeout^(^(^) =^> refreshComfyHistory^({ silent: true }^), 3000^);
  echo     } catch ^(error^) {
  echo       renderComfyStatus^(error.message ^|^| 'Workflow launch failed.', true^);
  echo       showToast^(`ComfyUI: ${error.message}`^);
  echo     } finally {
  echo       setComfyBusy^(false^);
  echo     }
  echo   }^);
  echo }
  echo.
  echo function pushAttachment^(attachment^) {
  echo   state.attachments.push^({ type: 'text', ...attachment }^);
  echo   renderAttachments^(^);
  echo }
  echo.
  echo function renderAttachments^(^) {
  echo   elements.attachments.innerHTML = '';
  echo   if ^(^!state.attachments.length^) {
  echo     elements.attachments.textContent = 'No attachments yet.';
  echo     return;
  echo   }
  echo   state.attachments.forEach^(^(attachment, index^) =^> {
  echo     const div = document.createElement^('div'^);
  echo     div.className = 'attachment';
  echo     const title = document.createElement^('div'^);
  echo     title.className = 'attachment-title';
  echo     title.textContent = `${index + 1}. ${attachment.title}`;
  echo     const meta = document.createElement^('div'^);
  echo     meta.className = 'attachment-meta';
  echo     meta.textContent = attachment.meta;
  echo     const body = document.createElement^('div'^);
  echo     body.className = 'attachment-body';
  echo     if ^(attachment.type === 'text'^) {
  echo       body.textContent = attachment.body;
  echo     } else {
  echo       body.textContent = attachment.body ^|^| `${attachment.type} attachment`;
  echo     }
  echo     const actions = document.createElement^('div'^);
  echo     actions.className = 'site-actions';
  echo     const insertBtn = document.createElement^('button'^);
  echo     insertBtn.className = 'secondary';
  echo     insertBtn.textContent = 'Insert into composer';
  echo     insertBtn.addEventListener^('click', ^(^) =^> {
  echo       const chunk = attachment.type === 'text'
  echo         ? attachment.body
  echo         : `${attachment.title}\n${attachment.meta ^|^| ''}`.trim^(^);
  echo       elements.composerInput.value = `${elements.composerInput.value}\n\n${chunk}`.trim^(^);
  echo     }^);
  echo     const removeBtn = document.createElement^('button'^);
  echo     removeBtn.className = 'secondary';
  echo     removeBtn.textContent = 'Remove';
  echo     removeBtn.addEventListener^('click', ^(^) =^> {
  echo       state.attachments.splice^(index, 1^);
  echo       if ^(attachment.assetKey ^&^& state.local.comfyImported?.has^(attachment.assetKey^)^) {
  echo         state.local.comfyImported.delete^(attachment.assetKey^);
  echo       }
  echo       renderAttachments^(^);
  echo     }^);
  echo     actions.appendChild^(insertBtn^);
  echo     actions.appendChild^(removeBtn^);
  echo     let mediaWrapper = null;
  echo     if ^(attachment.dataUrl^) {
  echo       const media = document.createElement^(attachment.type === 'video' ? 'video' : 'img'^);
  echo       media.src = attachment.dataUrl;
  echo       media.className = 'attachment-media-item';
  echo       if ^(attachment.type === 'video'^) {
  echo         media.controls = true;
  echo       }
  echo       mediaWrapper = document.createElement^('div'^);
  echo       mediaWrapper.className = 'attachment-media';
  echo       mediaWrapper.appendChild^(media^);
  echo     }
  echo     div.appendChild^(title^);
  echo     div.appendChild^(meta^);
  echo     div.appendChild^(body^);
  echo     if ^(mediaWrapper^) {
  echo       div.appendChild^(mediaWrapper^);
  echo     }
  echo     div.appendChild^(actions^);
  echo     elements.attachments.appendChild^(div^);
  echo   }^);
  echo }
  echo.
  echo function syncStudioHosts^(^) {
  echo   if ^(elements.ollamaHostField^) {
  echo     elements.ollamaHostField.value = state.settings.ollamaHost ^|^| elements.ollamaHostField.placeholder ^|^| '';
  echo   }
  echo   if ^(elements.comfyHostField^) {
  echo     elements.comfyHostField.value = state.settings.comfyHost ^|^| elements.comfyHostField.placeholder ^|^| '';
  echo   }
  echo   updateLocalManifest^(
  echo     {
  echo       host: state.settings.ollamaHost ^|^| state.localManifest?.host ^|^| '',
  echo       model: state.settings.ollamaModel ^|^| state.localManifest?.model ^|^| ''
  echo     },
  echo     { skipSummary: true }
  echo   ^);
  echo   renderOllamaModels^(^);
  echo   renderOllamaOutput^(^);
  echo   renderComfyGallery^(^);
  echo   renderAssistantSummary^(^);
  echo }
  echo.
  echo function renderOllamaModels^(^) {
  echo   if ^(^!elements.ollamaModelSelect^) return;
  echo   elements.ollamaModelSelect.innerHTML = '';
  echo   if ^(^!state.local.ollamaModels.length^) {
  echo     const option = document.createElement^('option'^);
  echo     option.value = '';
  echo     option.textContent = 'No models detected';
  echo     elements.ollamaModelSelect.appendChild^(option^);
  echo     elements.ollamaModelSelect.disabled = true;
  echo     if ^(state.settings.ollamaModel^) {
  echo       state.settings.ollamaModel = '';
  echo       scheduleSettingsSave^(^);
  echo     }
  echo     return;
  echo   }
  echo   elements.ollamaModelSelect.disabled = false;
  echo   state.local.ollamaModels.forEach^(^(model^) =^> {
  echo     const option = document.createElement^('option'^);
  echo     option.value = model;
  echo     option.textContent = model;
  echo     elements.ollamaModelSelect.appendChild^(option^);
  echo   }^);
  echo   const preferred = state.settings.ollamaModel;
  echo   if ^(preferred ^&^& state.local.ollamaModels.includes^(preferred^)^) {
  echo     elements.ollamaModelSelect.value = preferred;
  echo   } else {
  echo     elements.ollamaModelSelect.selectedIndex = 0;
  echo     state.settings.ollamaModel = elements.ollamaModelSelect.value;
  echo     scheduleSettingsSave^(^);
  echo   }
  echo }
  echo.
  echo function renderOllamaOutput^(^) {
  echo   if ^(^!elements.ollamaOutput^) return;
  echo   elements.ollamaOutput.textContent = state.local.ollamaOutput ^|^| 'Generated text will appear here.';
  echo }
  echo.
  echo function setOllamaBusy^(isBusy^) {
  echo   state.local.ollamaBusy = isBusy;
  echo   if ^(elements.ollamaGenerate^) {
  echo     elements.ollamaGenerate.disabled = isBusy;
  echo   }
  echo   if ^(elements.ollamaRefresh^) {
  echo     elements.ollamaRefresh.disabled = isBusy;
  echo   }
  echo }
  echo.
  echo async function refreshOllamaModels^({ silent = false } = {}^) {
  echo   if ^(^!elements.ollamaHostField^) return;
  echo   try {
  echo     setOllamaBusy^(true^);
  echo     const host = elements.ollamaHostField.value.trim^(^);
  echo     state.settings.ollamaHost = host;
  echo     scheduleSettingsSave^(^);
  echo     const result = await api.listOllamaModels^(host ^|^| undefined^);
  echo     if ^(^!result ^|^| ^!result.ok^) {
  echo       throw new Error^(result?.error ^|^| 'Unable to reach Ollama.'^);
  echo     }
  echo     state.local.ollamaModels = result.models ^|^| [];
  echo     updateLocalManifest^(
  echo       {
  echo         host: host ^|^| state.localManifest?.host ^|^| '',
  echo         model: state.settings.ollamaModel ^|^| state.localManifest?.model ^|^| ''
  echo       },
  echo       { skipSummary: true }
  echo     ^);
  echo     renderOllamaModels^(^);
  echo     renderAssistantSummary^(^);
  echo     if ^(^!silent^) {
  echo       showToast^('Ollama models refreshed.'^);
  echo     }
  echo   } catch ^(error^) {
  echo     state.local.ollamaModels = [];
  echo     renderOllamaModels^(^);
  echo     updateLocalManifest^(
  echo       {
  echo         host: elements.ollamaHostField.value.trim^(^) ^|^| state.localManifest?.host ^|^| ''
  echo       },
  echo       { skipSummary: false }
  echo     ^);
  echo     if ^(^!silent^) {
  echo       showToast^(`Ollama: ${error.message}`^);
  echo     }
  echo   } finally {
  echo     setOllamaBusy^(false^);
  echo   }
  echo }
  echo.
  echo async function runOllamaGeneration^(^) {
  echo   const model = elements.ollamaModelSelect.value ^|^| state.settings.ollamaModel;
  echo   const prompt = elements.ollamaPrompt.value.trim^(^);
  echo   if ^(^!model^) {
  echo     showToast^('Choose an Ollama model.'^);
  echo     return;
  echo   }
  echo   if ^(^!prompt^) {
  echo     showToast^('Enter a prompt for Ollama.'^);
  echo     return;
  echo   }
  echo   try {
  echo     setOllamaBusy^(true^);
  echo     const host = elements.ollamaHostField.value.trim^(^);
  echo     state.settings.ollamaHost = host;
  echo     scheduleSettingsSave^(^);
  echo     const result = await api.generateOllama^({ model, prompt, host: host ^|^| undefined }^);
  echo     if ^(^!result ^|^| ^!result.ok^) {
  echo       throw new Error^(result?.error ^|^| 'Generation failed.'^);
  echo     }
  echo     const text = ^(result.text ^|^| ''^).trim^(^);
  echo     state.local.ollamaOutput = text;
  echo     updateLocalManifest^({ host: host ^|^| state.localManifest?.host ^|^| '', model }^);
  echo     renderOllamaOutput^(^);
  echo     if ^(text^) {
  echo       pushAttachment^({
  echo         type: 'text',
  echo         title: `Ollama ^(${model}^)`,
  echo         meta: host ? `Host ${host}` : 'Local host',
  echo         body: text
  echo       }^);
  echo     }
  echo     showToast^('Ollama response ready.'^);
  echo   } catch ^(error^) {
  echo     showToast^(`Ollama: ${error.message}`^);
  echo   } finally {
  echo     setOllamaBusy^(false^);
  echo   }
  echo }
  echo.
  echo function renderComfyStatus^(message, isError = false^) {
  echo   if ^(^!elements.comfyStatus^) return;
  echo   elements.comfyStatus.textContent = message;
  echo   elements.comfyStatus.classList.toggle^('error', ^!^!isError^);
  echo }
  echo.
  echo function setComfyBusy^(isBusy^) {
  echo   state.local.comfyBusy = isBusy;
  echo   if ^(elements.comfyRefresh^) {
  echo     elements.comfyRefresh.disabled = isBusy;
  echo   }
  echo   if ^(elements.comfyRun^) {
  echo     elements.comfyRun.disabled = isBusy;
  echo   }
  echo }
  echo.
  echo function renderComfyGallery^(^) {
  echo   if ^(^!elements.comfyGallery^) return;
  echo   elements.comfyGallery.innerHTML = '';
  echo   if ^(^!state.local.comfyJobs.length^) {
  echo     renderComfyStatus^('No ComfyUI results yet.'^);
  echo     return;
  echo   }
  echo   renderComfyStatus^(`Showing ${state.local.comfyJobs.length} recent ComfyUI jobs.`^);
  echo   let assetCount = 0;
  echo   state.local.comfyJobs.forEach^(^(job^) =^> {
  echo     const assets = [...^(job.images ^|^| []^), ...^(job.videos ^|^| []^)];
  echo     if ^(^!assets.length^) return;
  echo     assets.forEach^(^(asset^) =^> {
  echo       const item = document.createElement^('div'^);
  echo       item.className = 'gallery-item';
  echo       const isVideo = ^(asset.mime ^|^| ''^).startsWith^('video/'^);
  echo       const media = document.createElement^(isVideo ? 'video' : 'img'^);
  echo       media.src = asset.url;
  echo       if ^(isVideo^) {
  echo         media.controls = true;
  echo       }
  echo       item.appendChild^(media^);
  echo       const caption = document.createElement^('div'^);
  echo       const created = job.created ? new Date^(job.created^).toLocaleTimeString^(^) : '';
  echo       caption.textContent = `${job.title ^|^| job.id}${created ? ` · ${created}` : ''}`;
  echo       item.appendChild^(caption^);
  echo       const meta = document.createElement^('div'^);
  echo       meta.className = 'attachment-meta';
  echo       meta.textContent = asset.filename ^|^| '';
  echo       item.appendChild^(meta^);
  echo       const btn = document.createElement^('button'^);
  echo       btn.className = 'secondary';
  echo       btn.textContent = 'Import to attachments';
  echo       btn.addEventListener^('click', async ^(^) =^> {
  echo         await importComfyAsset^(job, asset^);
  echo       }^);
  echo       item.appendChild^(btn^);
  echo       elements.comfyGallery.appendChild^(item^);
  echo       assetCount += 1;
  echo     }^);
  echo   }^);
  echo   if ^(^!assetCount^) {
  echo     renderComfyStatus^('Recent jobs do not contain downloadable assets yet.'^);
  echo   }
  echo }
  echo.
  echo async function refreshComfyHistory^({ silent = false } = {}^) {
  echo   if ^(^!elements.comfyHostField^) return;
  echo   try {
  echo     setComfyBusy^(true^);
  echo     const host = elements.comfyHostField.value.trim^(^);
  echo     state.settings.comfyHost = host;
  echo     scheduleSettingsSave^(^);
  echo     const result = await api.listComfyJobs^({ limit: 12, host }^);
  echo     if ^(^!result ^|^| ^!result.ok^) {
  echo       throw new Error^(result?.error ^|^| 'Unable to reach ComfyUI.'^);
  echo     }
  echo     state.local.comfyJobs = result.jobs ^|^| [];
  echo     renderComfyGallery^(^);
  echo     if ^(^!silent^) {
  echo       showToast^('ComfyUI results updated.'^);
  echo     }
  echo     if ^(state.settings.comfyAutoImport^) {
  echo       autoImportComfyResult^(^);
  echo     }
  echo   } catch ^(error^) {
  echo     state.local.comfyJobs = [];
  echo     renderComfyGallery^(^);
  echo     renderComfyStatus^(error.message ^|^| 'Unable to reach ComfyUI.', true^);
  echo     if ^(^!silent^) {
  echo       showToast^(`ComfyUI: ${error.message}`^);
  echo     }
  echo   } finally {
  echo     setComfyBusy^(false^);
  echo   }
  echo }
  echo.
  echo function buildComfyAssetKey^(job, asset^) {
  echo   return `${job.id ^|^| 'job'}:${asset.filename ^|^| 'asset'}:${asset.subfolder ^|^| ''}`;
  echo }
  echo.
  echo async function importComfyAsset^(job, asset^) {
  echo   try {
  echo     const key = buildComfyAssetKey^(job, asset^);
  echo     if ^(state.local.comfyImported.has^(key^)^) {
  echo       showToast^('Asset already imported.'^);
  echo       return;
  echo     }
  echo     state.local.comfyImported.add^(key^);
  echo     const host = elements.comfyHostField ? elements.comfyHostField.value.trim^(^) : '';
  echo     const result = await api.fetchComfyAsset^({
  echo       filename: asset.filename,
  echo       subfolder: asset.subfolder,
  echo       type: asset.type,
  echo       mime: asset.mime,
  echo       host: host ^|^| undefined
  echo     }^);
  echo     if ^(^!result ^|^| ^!result.ok^) {
  echo       throw new Error^(result?.error ^|^| 'Unable to fetch asset.'^);
  echo     }
  echo     const type = ^(asset.mime ^|^| ''^).startsWith^('video/'^) ? 'video' : 'image';
  echo     pushAttachment^({
  echo       type,
  echo       title: `${job.title ^|^| 'ComfyUI asset'}`,
  echo       meta: asset.filename ^|^| '',
  echo       body: `${job.title ^|^| job.id} · ${asset.filename ^|^| ''}`.trim^(^),
  echo       dataUrl: result.dataUrl,
  echo       assetKey: key
  echo     }^);
  echo     showToast^('ComfyUI asset imported.'^);
  echo   } catch ^(error^) {
  echo     const key = buildComfyAssetKey^(job, asset^);
  echo     if ^(state.local.comfyImported.has^(key^) ^&^& ^!state.attachments.some^(^(att^) =^> att.assetKey === key^)^) {
  echo       state.local.comfyImported.delete^(key^);
  echo     }
  echo     showToast^(`ComfyUI: ${error.message}`^);
  echo   }
  echo }
  echo.
  echo function autoImportComfyResult^(^) {
  echo   const jobs = state.local.comfyJobs ^|^| [];
  echo   for ^(const job of jobs^) {
  echo     const assets = [...^(job.images ^|^| []^), ...^(job.videos ^|^| []^)];
  echo     for ^(const asset of assets^) {
  echo       const key = buildComfyAssetKey^(job, asset^);
  echo       if ^(^!state.local.comfyImported.has^(key^)^) {
  echo         importComfyAsset^(job, asset^);
  echo         return;
  echo       }
  echo     }
  echo   }
  echo }
  echo.
  echo async function startRoundTable^(^) {
  echo   const targets = Array.from^(state.selected^);
  echo   if ^(^!targets.length^) {
  echo     showToast^('Select assistants for the round-table.'^);
  echo     return;
  echo   }
  echo   const message = elements.composerInput.value.trim^(^);
  echo   if ^(^!message^) {
  echo     showToast^('Composer is empty.'^);
  echo     return;
  echo   }
  echo   const turns = Number^(elements.roundTurns.value^) ^|^| state.settings.roundTableTurns ^|^| 1;
  echo   if ^(state.settings.confirmBeforeSend^) {
  echo     const ok = await confirmSend^(`Start round-table with ${targets.length} assistants for ${turns} turns?`^);
  echo     if ^(^!ok^) return;
  echo   }
  echo   state.round.active = true;
  echo   state.round.paused = false;
  echo   state.round.baseMessage = message;
  echo   state.round.turnsRemaining = turns;
  echo   state.round.queue = buildRoundQueue^(targets^);
  echo   state.round.lastTranscript = '';
  echo   appendLog^(`Round-table started ^(${turns} turns^).`^);
  echo   processRoundStep^(^);
  echo }
  echo.
  echo elements.roundStart.addEventListener^('click', startRoundTable^);
  echo.
  echo elements.roundPause.addEventListener^('click', ^(^) =^> {
  echo   if ^(^!state.round.active^) return;
  echo   state.round.paused = true;
  echo   appendLog^('Round-table paused.'^);
  echo }^);
  echo.
  echo elements.roundResume.addEventListener^('click', ^(^) =^> {
  echo   if ^(^!state.round.active^) return;
  echo   state.round.paused = false;
  echo   appendLog^('Round-table resumed.'^);
  echo   processRoundStep^(^);
  echo }^);
  echo.
  echo elements.roundStop.addEventListener^('click', stopRoundTable^);
  echo.
  echo elements.exportLogBtn.addEventListener^('click', async ^(^) =^> {
  echo   const payload = state.log.join^('\n'^);
  echo   const result = await api.exportLog^(payload^);
  echo   if ^(result ^&^& result.ok^) {
  echo     showToast^(`Log exported to ${result.path}`^);
  echo   }
  echo }^);
  echo.
  echo elements.refreshAgents.addEventListener^('click', async ^(^) =^> {
  echo   for ^(const key of Object.keys^(state.selectors^)^) {
  echo     await ensureAgent^(key^);
  echo   }
  echo   showToast^('Agent status refreshed.'^);
  echo }^);
  echo.
  echo function stopRoundTable^(^) {
  echo   if ^(^!state.round.active^) return;
  echo   state.round.active = false;
  echo   state.round.paused = false;
  echo   state.round.queue = [];
  echo   state.round.turnsRemaining = 0;
  echo   if ^(state.round.timer^) {
  echo     clearTimeout^(state.round.timer^);
  echo     state.round.timer = null;
  echo   }
  echo   appendLog^('Round-table stopped.'^);
  echo }
  echo.
  echo function buildRoundQueue^(targets^) {
  echo   const ordered = state.order.filter^(^(key^) =^> targets.includes^(key^)^);
  echo   return [...ordered];
  echo }
  echo.
  echo async function processRoundStep^(^) {
  echo   if ^(^!state.round.active^) {
  echo     return;
  echo   }
  echo   if ^(state.round.paused^) {
  echo     state.round.timer = setTimeout^(processRoundStep, 500^);
  echo     return;
  echo   }
  echo   if ^(state.round.queue.length === 0^) {
  echo     state.round.turnsRemaining -= 1;
  echo     if ^(state.round.turnsRemaining ^<= 0^) {
  echo       appendLog^('Round-table completed.'^);
  echo       stopRoundTable^(^);
  echo       return;
  echo     }
  echo     state.round.queue = buildRoundQueue^(Array.from^(state.selected^)^);
  echo   }
  echo   const key = state.round.queue.shift^(^);
  echo   const message = buildRoundMessage^(key^);
  echo   try {
  echo     await ensureAgent^(key^);
  echo     await api.sendAgent^({ key, text: message }^);
  echo     appendLog^(`Round-table: sent turn to ${key}.`^);
  echo     const messages = await api.readAgent^(key^);
  echo     state.round.lastTranscript = messages.join^('\n'^);
  echo   } catch ^(error^) {
  echo     appendLog^(`Round-table: ${key} failed ^(${error.message ^|^| error}^).`^);
  echo     showToast^(`${key} send failed during round-table.`^);
  echo   }
  echo   state.round.timer = setTimeout^(processRoundStep, 400^);
  echo }
  echo.
  echo function buildRoundMessage^(key^) {
  echo   const history = state.round.lastTranscript
  echo     ? `\n\nLatest transcript:\n${state.round.lastTranscript}`
  echo     : '';
  echo   return `${state.round.baseMessage}${history}`;
  echo }
  echo.
  echo async function reloadSelectors^(^) {
  echo   const payload = await api.bootstrap^(^);
  echo   state.selectors = payload.selectors;
  echo   state.settings = payload.settings;
  echo   state.log = payload.log ^|^| [];
  echo   if ^(payload.defaults^) {
  echo     state.defaultSelectors = payload.defaults;
  echo   }
  echo   if ^(payload.defaultKeys ^&^& payload.defaultKeys.length^) {
  echo     state.defaultKeys = payload.defaultKeys;
  echo   }
  echo   state.localManifest = payload.assistants ? payload.assistants[LOCAL_AGENT_KEY] : state.localManifest;
  echo   syncAssistantManifest^(payload.order ^|^| state.order^);
  echo   renderLog^(^);
  echo   renderAgents^(^);
  echo   renderSiteEditor^(^);
  echo   hydrateSettings^(^);
  echo   refreshOllamaModels^({ silent: true }^);
  echo   refreshComfyHistory^({ silent: true }^);
  echo   renderAttachments^(^);
  echo   clearNewSiteForm^(^);
  echo }
  echo.
  echo function hydrateSettings^(^) {
  echo   elements.confirmToggle.checked = ^!^!state.settings.confirmBeforeSend;
  echo   elements.delayMin.value = state.settings.delayMin ^|^| 0;
  echo   elements.delayMax.value = state.settings.delayMax ^|^| 0;
  echo   elements.messageLimit.value = state.settings.messageLimit ^|^| 5;
  echo   elements.defaultTurns.value = state.settings.roundTableTurns ^|^| 2;
  echo   elements.copilotHost.value = state.settings.copilotHost ^|^| '';
  echo   elements.roundTurns.value = state.settings.roundTableTurns ^|^| 2;
  echo   elements.settingsComfyHost.value = state.settings.comfyHost ^|^| '';
  echo   elements.settingsComfyAuto.checked = ^!^!state.settings.comfyAutoImport;
  echo   elements.settingsOllamaHost.value = state.settings.ollamaHost ^|^| '';
  echo   elements.settingsOllamaModel.value = state.settings.ollamaModel ^|^| '';
  echo   syncStudioHosts^(^);
  echo }
  echo.
  echo async function bootstrap^(^) {
  echo   const payload = await api.bootstrap^(^);
  echo   state.selectors = payload.selectors ^|^| {};
  echo   state.settings = payload.settings ^|^| {};
  echo   state.log = payload.log ^|^| [];
  echo   state.defaultSelectors = payload.defaults ^|^| state.defaultSelectors ^|^| {};
  echo   if ^(payload.defaultKeys ^&^& payload.defaultKeys.length^) {
  echo     state.defaultKeys = payload.defaultKeys;
  echo   } else if ^(payload.defaults^) {
  echo     state.defaultKeys = Object.keys^(payload.defaults^);
  echo   }
  echo   state.localManifest = payload.assistants ? payload.assistants[LOCAL_AGENT_KEY] : null;
  echo   syncAssistantManifest^(payload.order ^|^| []^);
  echo   renderLog^(^);
  echo   renderAgents^(^);
  echo   renderSiteEditor^(^);
  echo   hydrateSettings^(^);
  echo   refreshOllamaModels^({ silent: true }^);
  echo   refreshComfyHistory^({ silent: true }^);
  echo   renderAttachments^(^);
  echo   clearNewSiteForm^(^);
  echo }
  echo.
  echo api.onStatus^(^(status^) =^> {
  echo   state.agents[status.key] = { ...state.agents[status.key], ...status };
  echo   if ^(status.key === LOCAL_AGENT_KEY^) {
  echo     updateLocalManifest^({
  echo       host: status.host ^|^| state.localManifest?.host ^|^| state.settings.ollamaHost ^|^| '',
  echo       model: status.model ^|^| state.localManifest?.model ^|^| state.settings.ollamaModel ^|^| ''
  echo     }^);
  echo   }
  echo   renderAgents^(^);
  echo }^);
  echo.
  echo api.onStatusInit^(^(entries^) =^> {
  echo   entries.forEach^(^(entry^) =^> {
  echo     state.agents[entry.key] = { ...state.agents[entry.key], ...entry };
  echo     if ^(entry.key === LOCAL_AGENT_KEY^) {
  echo       updateLocalManifest^(
  echo         {
  echo           host: entry.host ^|^| state.localManifest?.host ^|^| state.settings.ollamaHost ^|^| '',
  echo           model: entry.model ^|^| state.localManifest?.model ^|^| state.settings.ollamaModel ^|^| ''
  echo         },
  echo         { skipSummary: true }
  echo       ^);
  echo     }
  echo   }^);
  echo   renderAssistantSummary^(^);
  echo   renderAgents^(^);
  echo }^);
  echo.
  echo api.onLog^(^(entry^) =^> {
  echo   appendLog^(entry^);
  echo }^);
  echo.
  echo api.onToast^(^(message^) =^> {
  echo   showToast^(message^);
  echo }^);
  echo.
  echo api.onLocalMessage^(^(payload^) =^> {
  echo   if ^(^!payload ^|^| ^!payload.response^) {
  echo     return;
  echo   }
  echo   const timestamp = payload.timestamp ? new Date^(payload.timestamp^) : new Date^(^);
  echo   const stamp = timestamp.toLocaleString^(^);
  echo   const modelLabel = payload.model ^|^| state.settings.ollamaModel ^|^| 'local model';
  echo   updateLocalManifest^({
  echo     model: modelLabel,
  echo     host: state.localManifest?.host ^|^| state.settings.ollamaHost ^|^| ''
  echo   }^);
  echo   pushAttachment^({
  echo     type: 'text',
  echo     title: `Local ^(${modelLabel}^)`,
  echo     meta: `Generated ${stamp}`,
  echo     body: payload.response.trim^(^)
  echo   }^);
  echo   showToast^('Local model response added to attachments.'^);
  echo }^);
  echo.
  echo window.addEventListener^('beforeunload', ^(^) =^> {
  echo   stopRoundTable^(^);
  echo }^);
  echo.
  echo bootstrap^(^);
)
endlocal
exit /b

:write_styles_css
setlocal DisableDelayedExpansion
> "%~1" (
  echo * {
  echo   box-sizing: border-box;
  echo }
  echo.
  echo body {
  echo   margin: 0;
  echo   font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  echo   color: #0f172a;
  echo   background: #f8fafc;
  echo   height: 100vh;
  echo }
  echo.
  echo body.modal-open {
  echo   overflow: hidden;
  echo }
  echo.
  echo #app {
  echo   display: grid;
  echo   grid-template-columns: 280px 1fr 340px;
  echo   height: 100vh;
  echo }
  echo.
  echo .pane {
  echo   border-right: 1px solid #e2e8f0;
  echo   display: flex;
  echo   flex-direction: column;
  echo   background: #ffffff;
  echo }
  echo.
  echo .pane-right {
  echo   border-right: none;
  echo   border-left: 1px solid #e2e8f0;
  echo }
  echo.
  echo .pane header,
  echo .pane-header {
  echo   padding: 16px;
  echo   border-bottom: 1px solid #e2e8f0;
  echo   display: flex;
  echo   align-items: center;
  echo   justify-content: space-between;
  echo }
  echo.
  echo .title-block {
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 4px;
  echo }
  echo.
  echo .subtitle {
  echo   margin: 0;
  echo   font-size: 13px;
  echo   color: #64748b;
  echo }
  echo.
  echo .header-actions {
  echo   display: flex;
  echo   gap: 8px;
  echo   align-items: center;
  echo }
  echo.
  echo .pane header h1 {
  echo   margin: 0;
  echo   font-size: 22px;
  echo }
  echo.
  echo .list {
  echo   flex: 1;
  echo   overflow-y: auto;
  echo   padding: 8px 16px;
  echo }
  echo.
  echo .agent-item {
  echo   border: 1px solid #cbd5f5;
  echo   border-radius: 8px;
  echo   padding: 12px;
  echo   margin-bottom: 12px;
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 8px;
  echo   background: #f8fafc;
  echo }
  echo.
  echo .agent-item.local {
  echo   border-color: #f97316;
  echo   background: #fff7ed;
  echo }
  echo.
  echo .agent-item.local .badge {
  echo   background: #fed7aa;
  echo   color: #9a3412;
  echo }
  echo.
  echo .agent-item.active {
  echo   border-color: #3b82f6;
  echo }
  echo.
  echo .agent-top {
  echo   display: flex;
  echo   justify-content: space-between;
  echo   align-items: center;
  echo   gap: 8px;
  echo }
  echo.
  echo .agent-actions {
  echo   display: flex;
  echo   gap: 8px;
  echo }
  echo.
  echo .agent-status {
  echo   font-size: 12px;
  echo   color: #475569;
  echo }
  echo.
  echo .composer {
  echo   padding: 16px;
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 12px;
  echo }
  echo.
  echo #composerInput {
  echo   width: 100%%;
  echo   min-height: 220px;
  echo   padding: 12px;
  echo   font-size: 15px;
  echo   border: 1px solid #cbd5f5;
  echo   border-radius: 8px;
  echo   resize: vertical;
  echo }
  echo.
  echo .composer-actions {
  echo   display: flex;
  echo   gap: 12px;
  echo   align-items: center;
  echo }
  echo.
  echo .target-chips {
  echo   display: flex;
  echo   align-items: center;
  echo   gap: 12px;
  echo   flex-wrap: wrap;
  echo }
  echo.
  echo .target-label {
  echo   font-size: 14px;
  echo   font-weight: 600;
  echo }
  echo.
  echo .chip-list {
  echo   display: flex;
  echo   flex-wrap: wrap;
  echo   gap: 8px;
  echo }
  echo.
  echo .chip-empty {
  echo   font-size: 13px;
  echo   color: #64748b;
  echo }
  echo.
  echo .chip {
  echo   border-radius: 999px;
  echo   padding: 6px 14px;
  echo   background: #e2e8f0;
  echo   color: #0f172a;
  echo   border: 1px solid transparent;
  echo   font-size: 13px;
  echo   cursor: pointer;
  echo   transition: background 0.2s ease, color 0.2s ease, border 0.2s ease;
  echo }
  echo.
  echo .chip.active {
  echo   background: #2563eb;
  echo   color: #ffffff;
  echo   border-color: #1d4ed8;
  echo }
  echo.
  echo .chip:focus {
  echo   outline: 2px solid #3b82f6;
  echo   outline-offset: 2px;
  echo }
  echo.
  echo .round-table .controls {
  echo   display: flex;
  echo   gap: 12px;
  echo   align-items: center;
  echo }
  echo.
  echo .round-table input[type="number"] {
  echo   width: 80px;
  echo }
  echo.
  echo .tools {
  echo   padding: 16px;
  echo   border-top: 1px solid #e2e8f0;
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 12px;
  echo   flex: 1;
  echo }
  echo.
  echo .tool-buttons {
  echo   display: flex;
  echo   gap: 10px;
  echo   flex-wrap: wrap;
  echo }
  echo.
  echo .attachments {
  echo   flex: 1;
  echo   overflow-y: auto;
  echo   border: 1px dashed #cbd5f5;
  echo   border-radius: 8px;
  echo   padding: 12px;
  echo   background: #f1f5f9;
  echo }
  echo.
  echo .attachment {
  echo   border-radius: 6px;
  echo   background: #ffffff;
  echo   border: 1px solid #cbd5f5;
  echo   padding: 8px;
  echo   margin-bottom: 8px;
  echo }
  echo .attachment-body {
  echo   white-space: pre-wrap;
  echo }
  echo .attachment-media {
  echo   margin-top: 6px;
  echo   display: flex;
  echo   justify-content: center;
  echo }
  echo .attachment-media img,
  echo .attachment-media video {
  echo   max-width: 100%%;
  echo   border-radius: 6px;
  echo   border: 1px solid #cbd5f5;
  echo }
  echo.
  echo .attachment-media-item {
  echo   max-width: 100%%;
  echo }
  echo.
  echo .log {
  echo   flex: 1;
  echo   overflow-y: auto;
  echo   padding: 16px;
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 6px;
  echo   font-family: 'Cascadia Mono', 'Consolas', monospace;
  echo   font-size: 12px;
  echo }
  echo.
  echo .log-entry {
  echo   padding: 6px 8px;
  echo   border-radius: 6px;
  echo   background: #f1f5f9;
  echo   border: 1px solid #cbd5f5;
  echo }
  echo.
  echo button {
  echo   border: none;
  echo   border-radius: 6px;
  echo   padding: 8px 14px;
  echo   font-size: 14px;
  echo   cursor: pointer;
  echo   font-family: inherit;
  echo }
  echo.
  echo button.primary {
  echo   background: #2563eb;
  echo   color: #ffffff;
  echo }
  echo.
  echo button.secondary {
  echo   background: #e2e8f0;
  echo   color: #0f172a;
  echo }
  echo.
  echo button:disabled {
  echo   background: #94a3b8;
  echo   cursor: not-allowed;
  echo }
  echo.
  echo .modal {
  echo   position: fixed;
  echo   inset: 0;
  echo   background: rgba^(15, 23, 42, 0.55^);
  echo   display: flex;
  echo   align-items: center;
  echo   justify-content: center;
  echo   z-index: 9999;
  echo }
  echo.
  echo .modal.hidden {
  echo   display: none;
  echo }
  echo.
  echo .modal-body {
  echo   background: #ffffff;
  echo   border-radius: 12px;
  echo   padding: 24px;
  echo   min-width: 320px;
  echo   max-width: 640px;
  echo   box-shadow: 0 12px 32px rgba^(15, 23, 42, 0.25^);
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 16px;
  echo }
  echo.
  echo .modal-actions {
  echo   display: flex;
  echo   justify-content: flex-end;
  echo   gap: 12px;
  echo }
  echo.
  echo .settings header {
  echo   display: flex;
  echo   justify-content: space-between;
  echo   align-items: center;
  echo }
  echo.
  echo .settings section {
  echo   border-top: 1px solid #e2e8f0;
  echo   padding-top: 12px;
  echo }
  echo.
  echo .settings .section-help {
  echo   margin: 0 0 12px;
  echo   color: #475569;
  echo   font-size: 14px;
  echo }
  echo.
  echo .settings .section-hint {
  echo   margin: 12px 0 0;
  echo   color: #64748b;
  echo   font-size: 13px;
  echo }
  echo.
  echo .settings h3 {
  echo   margin-top: 0;
  echo }
  echo.
  echo .grid {
  echo   display: grid;
  echo   grid-template-columns: repeat^(auto-fill, minmax^(200px, 1fr^)^);
  echo   gap: 16px;
  echo }
  echo.
  echo .grid label {
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 6px;
  echo   font-size: 14px;
  echo }
  echo.
  echo .add-site-form {
  echo   background: #f8fafc;
  echo   border: 1px solid #e2e8f0;
  echo   border-radius: 10px;
  echo   padding: 16px;
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 12px;
  echo   margin-bottom: 20px;
  echo }
  echo.
  echo .add-site-form h4 {
  echo   margin: 0;
  echo }
  echo.
  echo .add-site-actions {
  echo   display: flex;
  echo   gap: 12px;
  echo   flex-wrap: wrap;
  echo }
  echo.
  echo .add-site-actions button {
  echo   min-width: 160px;
  echo }
  echo.
  echo .toast {
  echo   position: fixed;
  echo   left: 50%%;
  echo   bottom: 32px;
  echo   transform: translateX^(-50%%^);
  echo   background: #1e293b;
  echo   color: #ffffff;
  echo   padding: 12px 20px;
  echo   border-radius: 999px;
  echo   box-shadow: 0 10px 25px rgba^(15, 23, 42, 0.3^);
  echo   font-size: 14px;
  echo   z-index: 10000;
  echo }
  echo.
  echo .toast.hidden {
  echo   display: none;
  echo }
  echo.
  echo .site-row {
  echo   border: 1px solid #cbd5f5;
  echo   border-radius: 8px;
  echo   padding: 12px;
  echo   margin-bottom: 12px;
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 8px;
  echo   background: #f8fafc;
  echo }
  echo.
  echo .site-row input[type="text"],
  echo .site-row input[type="url"],
  echo .site-row textarea {
  echo   width: 100%%;
  echo   padding: 8px;
  echo   border-radius: 6px;
  echo   border: 1px solid #cbd5f5;
  echo }
  echo.
  echo .site-row textarea {
  echo   resize: vertical;
  echo   min-height: 60px;
  echo }
  echo.
  echo .site-row .site-actions {
  echo   display: flex;
  echo   gap: 8px;
  echo }
  echo.
  echo .badge {
  echo   display: inline-flex;
  echo   align-items: center;
  echo   padding: 2px 8px;
  echo   border-radius: 999px;
  echo   background: #e2e8f0;
  echo   font-size: 12px;
  echo   color: #0f172a;
  echo }
  echo.
  echo .attachment-title {
  echo   font-weight: 600;
  echo   margin-bottom: 4px;
  echo }
  echo.
  echo .attachment-meta {
  echo   font-size: 12px;
  echo   color: #475569;
  echo   margin-bottom: 6px;
  echo }
  echo.
  echo .round-badge {
  echo   background: #2563eb;
  echo   color: #ffffff;
  echo   padding: 2px 6px;
  echo   border-radius: 4px;
  echo   font-size: 12px;
  echo }
  echo.
  echo .agent-order {
  echo   display: flex;
  echo   gap: 6px;
  echo   align-items: center;
  echo }
  echo.
  echo .agent-order button {
  echo   padding: 4px 8px;
  echo   font-size: 12px;
  echo }
  echo.
  echo .local-studio {
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 16px;
  echo   margin-top: 16px;
  echo }
  echo.
  echo .studio-header h2 {
  echo   margin: 0;
  echo }
  echo.
  echo .studio-header p {
  echo   margin: 0;
  echo   color: #475569;
  echo   font-size: 13px;
  echo }
  echo.
  echo .studio-grid {
  echo   display: grid;
  echo   grid-template-columns: repeat^(auto-fit, minmax^(300px, 1fr^)^);
  echo   gap: 16px;
  echo }
  echo.
  echo .studio-card {
  echo   border: 1px solid #cbd5f5;
  echo   border-radius: 12px;
  echo   background: #ffffff;
  echo   padding: 16px;
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 12px;
  echo   box-shadow: 0 8px 18px rgba^(15, 23, 42, 0.08^);
  echo }
  echo.
  echo .studio-card header {
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 8px;
  echo }
  echo.
  echo .inline-controls {
  echo   display: flex;
  echo   gap: 12px;
  echo   flex-wrap: wrap;
  echo   align-items: flex-end;
  echo }
  echo.
  echo .inline-controls label {
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 4px;
  echo   font-size: 13px;
  echo }
  echo.
  echo .studio-body {
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 12px;
  echo }
  echo.
  echo .studio-body label {
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 6px;
  echo   font-size: 14px;
  echo }
  echo.
  echo .studio-body textarea {
  echo   resize: vertical;
  echo   min-height: 120px;
  echo   font-size: 14px;
  echo   padding: 10px;
  echo   border-radius: 8px;
  echo   border: 1px solid #cbd5f5;
  echo }
  echo.
  echo .studio-body select,
  echo .studio-body input[type="text"] {
  echo   padding: 8px;
  echo   border-radius: 8px;
  echo   border: 1px solid #cbd5f5;
  echo   font-size: 14px;
  echo }
  echo.
  echo .studio-actions {
  echo   display: flex;
  echo   gap: 10px;
  echo   flex-wrap: wrap;
  echo }
  echo.
  echo .studio-output {
  echo   border: 1px solid #e2e8f0;
  echo   border-radius: 8px;
  echo   padding: 12px;
  echo   min-height: 100px;
  echo   background: #f8fafc;
  echo   font-size: 14px;
  echo   line-height: 1.5;
  echo   white-space: pre-wrap;
  echo }
  echo.
  echo .studio-status {
  echo   font-size: 13px;
  echo   color: #475569;
  echo }
  echo.
  echo .studio-status.error {
  echo   color: #b91c1c;
  echo }
  echo.
  echo .gallery {
  echo   display: grid;
  echo   grid-template-columns: repeat^(auto-fit, minmax^(120px, 1fr^)^);
  echo   gap: 12px;
  echo }
  echo.
  echo .gallery-item {
  echo   border: 1px solid #cbd5f5;
  echo   border-radius: 10px;
  echo   background: #f8fafc;
  echo   padding: 8px;
  echo   display: flex;
  echo   flex-direction: column;
  echo   gap: 6px;
  echo   align-items: center;
  echo   text-align: center;
  echo }
  echo.
  echo .gallery-item img,
  echo .gallery-item video {
  echo   max-width: 100%%;
  echo   border-radius: 8px;
  echo   border: 1px solid #cbd5f5;
  echo }
  echo.
  echo .gallery-item button {
  echo   width: 100%%;
  echo }
  echo.
  echo .utility-actions {
  echo   display: flex;
  echo   flex-wrap: wrap;
  echo   gap: 12px;
  echo }
  echo.
  echo label.checkbox {
  echo   flex-direction: row;
  echo   align-items: center;
  echo   gap: 8px;
  echo }
)
endlocal
exit /b

:write_selectors_json
setlocal DisableDelayedExpansion
> "%~1" (
  echo {
  echo   "chatgpt": {
  echo     "displayName": "ChatGPT",
  echo     "patterns": [
  echo       "https://chatgpt.com/*"
  echo     ],
  echo     "home": "https://chatgpt.com/",
  echo     "input": [
  echo       "textarea",
  echo       "textarea[data-testid='chat-input']",
  echo       "div[contenteditable='true']"
  echo     ],
  echo     "sendButton": [
  echo       "button[data-testid='send-button']",
  echo       "button[aria-label='Send']"
  echo     ],
  echo     "messageContainer": [
  echo       "main",
  echo       "div[class*='conversation']"
  echo     ]
  echo   },
  echo   "claude": {
  echo     "displayName": "Claude",
  echo     "patterns": [
  echo       "https://claude.ai/*"
  echo     ],
  echo     "home": "https://claude.ai/",
  echo     "input": [
  echo       "textarea",
  echo       "textarea[placeholder*='Message']",
  echo       "div[contenteditable='true']"
  echo     ],
  echo     "sendButton": [
  echo       "button[type='submit']",
  echo       "button[aria-label='Send']"
  echo     ],
  echo     "messageContainer": [
  echo       "main",
  echo       "div[class*='conversation']"
  echo     ]
  echo   },
  echo   "copilot": {
  echo     "displayName": "Copilot",
  echo     "patterns": [
  echo       "https://copilot.microsoft.com/*",
  echo       "https://www.bing.com/chat*"
  echo     ],
  echo     "home": "https://copilot.microsoft.com/",
  echo     "input": [
  echo       "textarea#userInput",
  echo       "textarea",
  echo       "div[contenteditable='true']",
  echo       "textarea[placeholder*='Ask me']"
  echo     ],
  echo     "sendButton": [
  echo       "button[aria-label='Send']",
  echo       "button[data-testid='send-button']"
  echo     ],
  echo     "messageContainer": [
  echo       "main",
  echo       "div[class*='conversation']"
  echo     ]
  echo   },
  echo   "gemini": {
  echo     "displayName": "Gemini",
  echo     "patterns": [
  echo       "https://gemini.google.com/*"
  echo     ],
  echo     "home": "https://gemini.google.com/",
  echo     "input": [
  echo       "textarea",
  echo       "div[contenteditable='true']",
  echo       "textarea[aria-label*='Message']"
  echo     ],
  echo     "sendButton": [
  echo       "button[aria-label='Send']",
  echo       "button[type='submit']"
  echo     ],
  echo     "messageContainer": [
  echo       "main",
  echo       "div[class*='conversation']"
  echo     ]
  echo   }
  echo }
)
endlocal
exit /b

:write_FIRST_RUN_txt
setlocal DisableDelayedExpansion
> "%~1" (
  echo 1. Install OmniChat using OmniChat_install.bat.
  echo 2. Open OmniChat from the desktop shortcut.
  echo 3. Sign in to ChatGPT, Claude, Copilot, and Gemini.
  echo 4. Use Broadcast to send a message to your selected assistants.
  echo 5. Run a Round-table with your chosen turn count.
)
endlocal
exit /b

:flatten_dir
setlocal EnableDelayedExpansion
set "TARGET_DIR=%~1"
set "TARGET_FILE=%~2"
set "SOURCE_DIR="

if exist "%TARGET_DIR%\%TARGET_FILE%" (
  endlocal
  exit /b 0
)

for /f "delims=" %%D in ('dir "%TARGET_DIR%" /ad /b') do (
  if exist "%TARGET_DIR%\%%D\%TARGET_FILE%" (
    set "SOURCE_DIR=%TARGET_DIR%\%%D"
  )
)

if not defined SOURCE_DIR (
  endlocal & set "ERROR_MSG=Could not find %TARGET_FILE% inside %TARGET_DIR%." & exit /b 1
)

for /f "delims=" %%F in ('dir "%SOURCE_DIR%" /b') do (
  move /y "%SOURCE_DIR%\%%F" "%TARGET_DIR%" >nul
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
