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
  echo ^<!DOCTYPE html^>
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
  echo         ^<h1^>OmniChat^</h1^>
  echo         ^<button id="refreshAgents" class="secondary"^>Refresh^</button^>
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
  echo         ^<div id="siteEditor"^>^</div^>
  echo         ^<button id="addSiteBtn" class="secondary"^>Add Site^</button^>
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
  echo       if ^(!selectors^) return null;
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
  echo     if ^(!input^) {
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
  echo     if ^(!banner^) {
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
  echo       if ^(!selectors^) return null;
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
  echo     if ^(!container^) {
  echo       return { ok: false, reason: 'messageContainer' };
  echo     }
  echo.
  echo     const walker = document.createTreeWalker^(container, NodeFilter.SHOW_ELEMENT, null^);
  echo     const transcript = [];
  echo     while ^(walker.nextNode^(^)^) {
  echo       const node = walker.currentNode;
  echo       if ^(!node^) continue;
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
  echo       if ^(!deduped.length ^|^| deduped[deduped.length - 1] !== line^) {
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
  echo   if ^(!task^) {
  echo     throw new Error^(`Unknown DOM task ${taskName}`^);
  echo   }
  echo   const safeContext = {
  echo     ...context,
  echo     limit: context ^&^& typeof context.limit !== 'undefined' ? context.limit : settings.messageLimit ^|^| DEFAULT_SETTINGS.messageLimit
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
  echo       if ^(!fs.existsSync^(this.filePath^)^) {
  echo         const initial = JSON.stringify^(this.defaults, null, 2^);
  echo         fs.mkdirSync^(path.dirname^(this.filePath^), { recursive: true }^);
  echo         fs.writeFileSync^(this.filePath, initial, 'utf8'^);
  echo         return JSON.parse^(initial^);
  echo       }
  echo       const raw = fs.readFileSync^(this.filePath, 'utf8'^);
  echo       const data = JSON.parse^(raw^);
  echo       if ^(Array.isArray^(this.defaults^) ^|^| typeof this.defaults !== 'object'^) {
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
  echo     if ^(!this.getConfig^(^)^) {
  echo       this.destroy^(^);
  echo     }
  echo   }
  echo.
  echo   async ensureWindow^(^) {
  echo     if ^(this.destroyed^) {
  echo       throw new Error^('agent_removed'^);
  echo     }
  echo     if ^(this.window ^&^& !this.window.isDestroyed^(^)^) {
  echo       return this.window;
  echo     }
  echo.
  echo     const config = this.getConfig^(^);
  echo     if ^(!config^) {
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
  echo     if ^(this.window ^&^& !this.window.isDestroyed^(^)^) {
  echo       this.window.hide^(^);
  echo     }
  echo     updateAgentStatus^(this.key, { visible: false }^);
  echo   }
  echo.
  echo   async runTask^(taskName, context = {}^) {
  echo     const job = this.queue.then^(async ^(^) =^> {
  echo       const config = this.getConfig^(^);
  echo       if ^(!config^) {
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
  echo     if ^(this.window ^&^& !this.window.isDestroyed^(^)^) {
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
  echo   settings: { ...DEFAULT_SETTINGS }
  echo };
  echo.
  echo function ensureDirectories^(^) {
  echo   [INSTALL_ROOT, CONFIG_ROOT, LOG_ROOT].forEach^(^(dir^) =^> {
  echo     if ^(!fs.existsSync^(dir^)^) {
  echo       fs.mkdirSync^(dir, { recursive: true }^);
  echo     }
  echo   }^);
  echo }
  echo.
  echo function ensureFirstRunGuide^(^) {
  echo   if ^(!fs.existsSync^(FIRST_RUN_PATH^)^) {
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
  echo   const current = agentStatus.get^(key^) ^|^| {
  echo     key,
  echo     displayName: selector.displayName ^|^| key,
  echo     status: 'idle',
  echo     visible: false
  echo   };
  echo   const next = {
  echo     ...current,
  echo     ...patch,
  echo     displayName: selector.displayName ^|^| current.displayName ^|^| key
  echo   };
  echo   agentStatus.set^(key, next^);
  echo   if ^(appState.mainWindow ^&^& !appState.mainWindow.isDestroyed^(^)^) {
  echo     appState.mainWindow.webContents.send^('agent:status', next^);
  echo   }
  echo }
  echo.
  echo function broadcastAgentSnapshot^(^) {
  echo   const payload = Array.from^(agentStatus.values^(^)^).map^(^(entry^) =^> {
  echo     const selector = appState.selectors[entry.key] ^|^| {};
  echo     return {
  echo       ...entry,
  echo       displayName: selector.displayName ^|^| entry.displayName ^|^| entry.key
  echo     };
  echo   }^);
  echo   if ^(appState.mainWindow ^&^& !appState.mainWindow.isDestroyed^(^)^) {
  echo     appState.mainWindow.webContents.send^('agent:status:init', payload^);
  echo   }
  echo }
  echo.
  echo function refreshAgentSessions^(^) {
  echo   const keys = Object.keys^(appState.selectors^);
  echo   keys.forEach^(^(key^) =^> {
  echo     if ^(!agentSessions.has^(key^)^) {
  echo       const session = new AgentSession^(key, ^(^) =^> appState.selectors[key]^);
  echo       agentSessions.set^(key, session^);
  echo     } else {
  echo       agentSessions.get^(key^).updateConfig^(^);
  echo     }
  echo     updateAgentStatus^(key, {}^);
  echo   }^);
  echo.
  echo   for ^(const key of Array.from^(agentSessions.keys^(^)^)^) {
  echo     if ^(!appState.selectors[key]^) {
  echo       const session = agentSessions.get^(key^);
  echo       session.destroy^(^);
  echo       agentSessions.delete^(key^);
  echo       agentStatus.delete^(key^);
  echo     }
  echo   }
  echo.
  echo   broadcastAgentSnapshot^(^);
  echo }
  echo.
  echo function getAgentSession^(key^) {
  echo   if ^(!agentSessions.has^(key^)^) {
  echo     const config = appState.selectors[key];
  echo     if ^(!config^) {
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
  echo   if ^(appState.mainWindow ^&^& !appState.mainWindow.isDestroyed^(^)^) {
  echo     appState.mainWindow.webContents.send^('log:push', line^);
  echo   }
  echo   const logFile = path.join^(LOG_ROOT, `${new Date^(^).toISOString^(^).slice^(0, 10^)}.log`^);
  echo   fs.appendFile^(logFile, line + '\n', ^(^) =^> {}^);
  echo }
  echo.
  echo async function sendToAgent^(key, text^) {
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
  echo     if ^(!result ^|^| !result.ok^) {
  echo       throw new Error^(result ? result.reason ^|^| 'send' : 'send'^);
  echo     }
  echo     recordLog^(`${key}: message sent via ${result.via}`^);
  echo     return result;
  echo   } catch ^(error^) {
  echo     recordLog^(`${key}: send failed ^(${error.message ^|^| error}^)`^);
  echo     if ^(appState.mainWindow ^&^& !appState.mainWindow.isDestroyed^(^)^) {
  echo       appState.mainWindow.webContents.send^('app:toast', `${key}.${error.message ^|^| 'send'} selectors need attention.`^);
  echo     }
  echo     throw error;
  echo   }
  echo }
  echo.
  echo async function readMessages^(key^) {
  echo   try {
  echo     const session = getAgentSession^(key^);
  echo     const result = await session.runTask^('readMessages', { limit: appState.settings.messageLimit }^);
  echo     if ^(!result ^|^| !result.ok^) {
  echo       throw new Error^(result ? result.reason ^|^| 'read' : 'read'^);
  echo     }
  echo     return result.messages ^|^| [];
  echo   } catch ^(error^) {
  echo     recordLog^(`${key}: read failed ^(${error.message ^|^| error}^)`^);
  echo     if ^(appState.mainWindow ^&^& !appState.mainWindow.isDestroyed^(^)^) {
  echo       appState.mainWindow.webContents.send^('app:toast', `${key}.${error.message ^|^| 'read'} selectors need attention.`^);
  echo     }
  echo     return [];
  echo   }
  echo }
  echo.
  echo function withTrailingSlash^(url^) {
  echo   if ^(!url^) return '';
  echo   return url.endsWith^('/'^) ? url : `${url}/`;
  echo }
  echo.
  echo async function fetchJson^(url, options = {}^) {
  echo   const response = await fetch^(url, options^);
  echo   if ^(!response.ok^) {
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
  echo   if ^(!response.ok^) {
  echo     throw new Error^(`HTTP ${response.status}`^);
  echo   }
  echo   const arrayBuffer = await response.arrayBuffer^(^);
  echo   const buffer = Buffer.from^(arrayBuffer^);
  echo   const mime = asset.mime ^|^| guessMime^(asset.filename^);
  echo   return `data:${mime};base64,${buffer.toString^('base64'^)}`;
  echo }
  echo.
  echo async function runComfyWorkflowFromFile^(hostOverride^) {
  echo   if ^(!appState.mainWindow ^|^| appState.mainWindow.isDestroyed^(^)^) {
  echo     return { ok: false, error: 'window_closed' };
  echo   }
  echo   const result = await dialog.showOpenDialog^(appState.mainWindow, {
  echo     title: 'Choose ComfyUI workflow',
  echo     filters: [{ name: 'JSON Files', extensions: ['json'] }],
  echo     properties: ['openFile']
  echo   }^);
  echo   if ^(result.canceled ^|^| !result.filePaths.length^) {
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
  echo   if ^(!response.ok^) {
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
  echo   if ^(!response.ok^) {
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
  echo         if ^(!line^) continue;
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
  echo   refreshAgentSessions^(^);
  echo   return {
  echo     selectors: appState.selectors,
  echo     settings: appState.settings,
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
  echo   return { ok: true };
  echo }^);
  echo.
  echo ipcMain.handle^('selectors:importFile', async ^(^) =^> {
  echo   if ^(!appState.mainWindow ^|^| appState.mainWindow.isDestroyed^(^)^) {
  echo     return { ok: false, error: 'window_closed' };
  echo   }
  echo   const result = await dialog.showOpenDialog^(appState.mainWindow, {
  echo     title: 'Import selectors.json',
  echo     filters: [{ name: 'JSON Files', extensions: ['json'] }],
  echo     properties: ['openFile']
  echo   }^);
  echo   if ^(result.canceled ^|^| !result.filePaths.length^) {
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
  echo   if ^(!appState.mainWindow ^|^| appState.mainWindow.isDestroyed^(^)^) {
  echo     return { ok: false, error: 'window_closed' };
  echo   }
  echo   const result = await dialog.showSaveDialog^(appState.mainWindow, {
  echo     title: 'Export selectors.json',
  echo     filters: [{ name: 'JSON Files', extensions: ['json'] }],
  echo     defaultPath: path.join^(app.getPath^('documents'^), 'omnichat-selectors.json'^)
  echo   }^);
  echo   if ^(result.canceled ^|^| !result.filePath^) {
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
  echo   const session = getAgentSession^(key^);
  echo   await session.ensureWindow^(^);
  echo   return agentStatus.get^(key^) ^|^| { key };
  echo }^);
  echo.
  echo ipcMain.handle^('agent:connect', async ^(_event, key^) =^> {
  echo   const session = getAgentSession^(key^);
  echo   await session.show^(^);
  echo   return true;
  echo }^);
  echo.
  echo ipcMain.handle^('agent:hide', async ^(_event, key^) =^> {
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
  echo   if ^(!appState.mainWindow ^|^| appState.mainWindow.isDestroyed^(^)^) {
  echo     return { ok: false };
  echo   }
  echo   const dialogResult = await dialog.showSaveDialog^(appState.mainWindow, {
  echo     title: 'Export OmniChat Log',
  echo     filters: [{ name: 'Text Files', extensions: ['txt'] }],
  echo     defaultPath: path.join^(app.getPath^('documents'^), `omnichat-log-${Date.now^(^)}.txt`^)
  echo   }^);
  echo   if ^(dialogResult.canceled ^|^| !dialogResult.filePath^) {
  echo     return { ok: false };
  echo   }
  echo   fs.writeFileSync^(dialogResult.filePath, payload ^|^| '', 'utf8'^);
  echo   return { ok: true, path: dialogResult.filePath };
  echo }^);
  echo.
  echo ipcMain.handle^('settings:resetAgent', async ^(_event, key^) =^> {
  echo   if ^(!DEFAULT_SELECTORS[key]^) {
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
  echo   if ^(process.platform !== 'darwin'^) {
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
  echo   onToast: ^(handler^) =^> ipcRenderer.on^('app:toast', ^(_event, message^) =^> handler^(message^)^)
  echo }^);
)
endlocal
exit /b

:write_renderer_js
call :write_block "%~1" renderer_js
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
  echo   width: 100%;
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
  echo   max-width: 100%;
  echo   border-radius: 6px;
  echo   border: 1px solid #cbd5f5;
  echo }
  echo.
  echo .attachment-media-item {
  echo   max-width: 100%;
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
  echo .toast {
  echo   position: fixed;
  echo   left: 50%;
  echo   bottom: 32px;
  echo   transform: translateX^(-50%^);
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
  echo   width: 100%;
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
  echo   max-width: 100%;
  echo   border-radius: 8px;
  echo   border: 1px solid #cbd5f5;
  echo }
  echo.
  echo .gallery-item button {
  echo   width: 100%;
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

:write_block
setlocal DisableDelayedExpansion
set "TARGET=%~1"
set "MARKER=%~2"
call :emit_block %MARKER% > "%TARGET%"
endlocal
exit /b

:emit_block
setlocal DisableDelayedExpansion
set "MARKER=%~1"
set "BEGIN=%MARKER%_BEGIN"
set "END=%MARKER%_END"
set "COPY="
for /f "usebackq tokens=1* delims=:" %%A in (`findstr /n "^" "%~f0"`) do (
  if not defined COPY (
    if "%%B"=="%BEGIN%" (
      set "COPY=1"
    )
  ) else (
    if "%%B"=="%END%" goto :emit_block_done
    echo %%B
  )
)
:emit_block_done
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

:renderer_js_BEGIN
const api = window.omnichat;

const elements = {
  agentList: document.getElementById('agentList'),
  refreshAgents: document.getElementById('refreshAgents'),
  composerInput: document.getElementById('composerInput'),
  broadcastBtn: document.getElementById('broadcastBtn'),
  singleTarget: document.getElementById('singleTarget'),
  singleSendBtn: document.getElementById('singleSendBtn'),
  roundTurns: document.getElementById('roundTurns'),
  roundStart: document.getElementById('roundStartBtn'),
  roundPause: document.getElementById('roundPauseBtn'),
  roundResume: document.getElementById('roundResumeBtn'),
  roundStop: document.getElementById('roundStopBtn'),
  targetChips: document.getElementById('targetChips'),
  quoteBtn: document.getElementById('quoteBtn'),
  snapshotBtn: document.getElementById('snapshotBtn'),
  attachBtn: document.getElementById('attachBtn'),
  attachments: document.getElementById('attachments'),
  logView: document.getElementById('logView'),
  exportLogBtn: document.getElementById('exportLogBtn'),
  settingsModal: document.getElementById('settingsModal'),
  openSettings: document.getElementById('openSettings'),
  closeSettings: document.getElementById('closeSettings'),
  confirmModal: document.getElementById('confirmModal'),
  confirmMessage: document.getElementById('confirmMessage'),
  confirmCancel: document.getElementById('confirmCancel'),
  confirmOk: document.getElementById('confirmOk'),
  toast: document.getElementById('toast'),
  siteEditor: document.getElementById('siteEditor'),
  addSiteBtn: document.getElementById('addSiteBtn'),
  confirmToggle: document.getElementById('confirmToggle'),
  delayMin: document.getElementById('delayMin'),
  delayMax: document.getElementById('delayMax'),
  messageLimit: document.getElementById('messageLimit'),
  defaultTurns: document.getElementById('defaultTurns'),
  copilotHost: document.getElementById('copilotHost'),
  settingsComfyHost: document.getElementById('settingsComfyHost'),
  settingsComfyAuto: document.getElementById('settingsComfyAuto'),
  settingsOllamaHost: document.getElementById('settingsOllamaHost'),
  settingsOllamaModel: document.getElementById('settingsOllamaModel'),
  importSelectorsBtn: document.getElementById('importSelectorsBtn'),
  exportSelectorsBtn: document.getElementById('exportSelectorsBtn'),
  openConfigBtn: document.getElementById('openConfigBtn'),
  ollamaHostField: document.getElementById('ollamaHostField'),
  ollamaRefresh: document.getElementById('ollamaRefresh'),
  ollamaModelSelect: document.getElementById('ollamaModelSelect'),
  ollamaPrompt: document.getElementById('ollamaPrompt'),
  ollamaGenerate: document.getElementById('ollamaGenerate'),
  ollamaInsert: document.getElementById('ollamaInsert'),
  ollamaOutput: document.getElementById('ollamaOutput'),
  comfyHostField: document.getElementById('comfyHostField'),
  comfyRefresh: document.getElementById('comfyRefresh'),
  comfyRun: document.getElementById('comfyRun'),
  comfyStatus: document.getElementById('comfyStatus'),
  comfyGallery: document.getElementById('comfyGallery')
};

const DEFAULT_KEYS = ['chatgpt', 'claude', 'copilot', 'gemini'];

const state = {
  selectors: {},
  settings: {},
  order: [],
  selected: new Set(),
  agents: {},
  log: [],
  attachments: [],
  confirmResolver: null,
  local: {
    ollamaModels: [],
    ollamaOutput: '',
    ollamaBusy: false,
    comfyJobs: [],
    comfyBusy: false,
    comfyImported: new Set()
  },
  round: {
    active: false,
    paused: false,
    queue: [],
    turnsRemaining: 0,
    baseMessage: '',
    lastTranscript: '',
    timer: null
  }
};

let settingsSaveTimer = null;

function scheduleSettingsSave() {
  clearTimeout(settingsSaveTimer);
  settingsSaveTimer = setTimeout(() => {
    api.saveSettings(state.settings);
  }, 400);
}

function appendLog(entry) {
  state.log.push(entry);
  if (state.log.length > 2000) {
    state.log = state.log.slice(-2000);
  }
  renderLog();
}

function renderLog() {
  elements.logView.innerHTML = '';
  state.log.slice(-400).forEach((line) => {
    const div = document.createElement('div');
    div.className = 'log-entry';
    div.textContent = line;
    elements.logView.appendChild(div);
  });
  elements.logView.scrollTop = elements.logView.scrollHeight;
}

function showToast(message, timeout = 4000) {
  elements.toast.textContent = message;
  elements.toast.classList.remove('hidden');
  clearTimeout(elements.toast._timer);
  elements.toast._timer = setTimeout(() => {
    elements.toast.classList.add('hidden');
  }, timeout);
}

function confirmSend(message) {
  if (!state.settings.confirmBeforeSend) {
    return Promise.resolve(true);
  }
  elements.confirmMessage.textContent = message;
  elements.confirmModal.classList.remove('hidden');
  return new Promise((resolve) => {
    state.confirmResolver = resolve;
  });
}

elements.confirmCancel.addEventListener('click', () => {
  if (state.confirmResolver) {
    state.confirmResolver(false);
    state.confirmResolver = null;
  }
  elements.confirmModal.classList.add('hidden');
});

elements.confirmOk.addEventListener('click', () => {
  if (state.confirmResolver) {
    state.confirmResolver(true);
    state.confirmResolver = null;
  }
  elements.confirmModal.classList.add('hidden');
});

function buildAgentOrderControls(key) {
  const container = document.createElement('div');
  container.className = 'agent-order';
  const up = document.createElement('button');
  up.textContent = '▲';
  up.addEventListener('click', () => {
    const idx = state.order.indexOf(key);
    if (idx > 0) {
      const swap = state.order[idx - 1];
      state.order[idx - 1] = key;
      state.order[idx] = swap;
      renderAgents();
    }
  });
  const down = document.createElement('button');
  down.textContent = '▼';
  down.addEventListener('click', () => {
    const idx = state.order.indexOf(key);
    if (idx >= 0 && idx < state.order.length - 1) {
      const swap = state.order[idx + 1];
      state.order[idx + 1] = key;
      state.order[idx] = swap;
      renderAgents();
    }
  });
  const badge = document.createElement('span');
  badge.className = 'round-badge';
  badge.textContent = `#${state.order.indexOf(key) + 1}`;
  container.appendChild(up);
  container.appendChild(down);
  container.appendChild(badge);
  return container;
}

function renderAgents() {
  elements.agentList.innerHTML = '';
  state.order.forEach((key) => {
    const config = state.selectors[key];
    if (!config) return;
    const item = document.createElement('div');
    item.className = 'agent-item';
    if (state.selected.has(key)) {
      item.classList.add('active');
    }

    const top = document.createElement('div');
    top.className = 'agent-top';
    const name = document.createElement('div');
    name.innerHTML = `<strong>${config.displayName || key}</strong> <span class="badge">${key}</span>`;

    const toggle = document.createElement('input');
    toggle.type = 'checkbox';
    toggle.checked = state.selected.has(key);
    toggle.addEventListener('change', () => {
      if (toggle.checked) {
        state.selected.add(key);
      } else {
        state.selected.delete(key);
      }
      renderAgents();
    });

    top.appendChild(name);
    top.appendChild(toggle);

    const status = document.createElement('div');
    status.className = 'agent-status';
    const data = state.agents[key];
    const statusBits = [];
    if (data && data.status) {
      statusBits.push(data.status);
    }
    if (data && data.visible) {
      statusBits.push('visible');
    }
    if (data && data.error) {
      statusBits.push(`error: ${data.error}`);
    }
    if (data && data.url) {
      try {
        const url = new URL(data.url);
        statusBits.push(url.hostname);
      } catch (error) {
        statusBits.push(data.url);
      }
    }
    status.textContent = statusBits.join(' · ') || 'offline';

    const actions = document.createElement('div');
    actions.className = 'agent-actions';

    const connectBtn = document.createElement('button');
    connectBtn.className = 'secondary';
    connectBtn.textContent = 'Connect';
    connectBtn.addEventListener('click', async () => {
      await api.connectAgent(key);
    });

    const hideBtn = document.createElement('button');
    hideBtn.className = 'secondary';
    hideBtn.textContent = 'Hide';
    hideBtn.addEventListener('click', async () => {
      await api.hideAgent(key);
    });

    const readBtn = document.createElement('button');
    readBtn.className = 'secondary';
    readBtn.textContent = 'Read';
    readBtn.addEventListener('click', async () => {
      await ensureAgent(key);
      const messages = await api.readAgent(key);
      appendLog(`${key}:\n${messages.join('\n')}`);
    });

    actions.appendChild(connectBtn);
    actions.appendChild(hideBtn);
    actions.appendChild(readBtn);

    const orderControls = buildAgentOrderControls(key);

    if (!DEFAULT_KEYS.includes(key)) {
      const removeBtn = document.createElement('button');
      removeBtn.className = 'secondary';
      removeBtn.textContent = 'Remove';
      removeBtn.addEventListener('click', () => {
        delete state.selectors[key];
        state.order = state.order.filter((k) => k !== key);
        state.selected.delete(key);
        persistSelectors();
        renderAgents();
        renderSiteEditor();
      });
      actions.appendChild(removeBtn);
    } else {
      const resetBtn = document.createElement('button');
      resetBtn.className = 'secondary';
      resetBtn.textContent = 'Reset';
      resetBtn.addEventListener('click', async () => {
        await api.resetAgentSelectors(key);
        await reloadSelectors();
        renderSiteEditor();
      });
      actions.appendChild(resetBtn);
    }

    item.appendChild(top);
    item.appendChild(status);
    item.appendChild(actions);
    item.appendChild(orderControls);
    elements.agentList.appendChild(item);
  });
  updateTargetControls();
}

function renderTargetDropdown() {
  const selected = Array.from(state.order).filter((key) => state.selectors[key]);
  elements.singleTarget.innerHTML = '';
  selected.forEach((key) => {
    const option = document.createElement('option');
    const config = state.selectors[key];
    option.value = key;
    option.textContent = config.displayName || key;
    elements.singleTarget.appendChild(option);
  });
  const firstSelected = Array.from(state.selected)[0];
  if (firstSelected && state.selectors[firstSelected]) {
    elements.singleTarget.value = firstSelected;
  } else if (elements.singleTarget.options.length) {
    elements.singleTarget.selectedIndex = 0;
  }
  elements.singleSendBtn.disabled = elements.singleTarget.options.length === 0;
}

function renderTargetChips() {
  if (!elements.targetChips) return;
  elements.targetChips.innerHTML = '';
  const fragment = document.createDocumentFragment();
  let hasAny = false;
  state.order.forEach((key) => {
    if (!state.selectors[key]) return;
    hasAny = true;
    const config = state.selectors[key];
    const chip = document.createElement('button');
    chip.type = 'button';
    chip.className = 'chip';
    chip.textContent = config.displayName || key;
    if (state.selected.has(key)) {
      chip.classList.add('active');
    }
    chip.addEventListener('click', () => {
      if (state.selected.has(key)) {
        state.selected.delete(key);
      } else {
        state.selected.add(key);
      }
      renderAgents();
    });
    fragment.appendChild(chip);
  });

  if (!hasAny) {
    const empty = document.createElement('span');
    empty.className = 'chip-empty';
    empty.textContent = 'No assistants available.';
    fragment.appendChild(empty);
  }

  elements.targetChips.appendChild(fragment);
}

function updateTargetControls() {
  renderTargetDropdown();
  renderTargetChips();
}

function renderSiteEditor() {
  elements.siteEditor.innerHTML = '';
  const orderedKeys = state.order.length
    ? [...state.order]
    : Object.keys(state.selectors);
  const extras = Object.keys(state.selectors).filter((key) => !orderedKeys.includes(key));
  const keys = [...orderedKeys, ...extras];

  keys.forEach((key) => {
    const config = state.selectors[key];
    if (!config) return;
    const row = document.createElement('div');
    row.className = 'site-row';
    row.dataset.key = key;
    row.innerHTML = `
      <div class="agent-top">
        <strong>${config.displayName || key}</strong>
        <span class="badge">${key}</span>
      </div>
      <label>Display name
        <input type="text" class="field-name" value="${config.displayName || ''}" />
      </label>
      <label>Home URL
        <input type="text" class="field-home" value="${config.home || ''}" />
      </label>
      <label>URL patterns (one per line)
        <textarea class="field-patterns">${(config.patterns || []).join('\n')}</textarea>
      </label>
      <label>Input selectors
        <textarea class="field-input">${(config.input || []).join('\n')}</textarea>
      </label>
      <label>Send button selectors
        <textarea class="field-send">${(config.sendButton || []).join('\n')}</textarea>
      </label>
      <label>Message container selectors
        <textarea class="field-message">${(config.messageContainer || []).join('\n')}</textarea>
      </label>
    `;

    const actions = document.createElement('div');
    actions.className = 'site-actions';

    const saveBtn = document.createElement('button');
    saveBtn.className = 'secondary';
    saveBtn.textContent = 'Save';
    saveBtn.addEventListener('click', () => {
      persistSelectors();
      showToast(`${key} selectors saved.`);
    });

    actions.appendChild(saveBtn);

    if (!DEFAULT_KEYS.includes(key)) {
      const deleteBtn = document.createElement('button');
      deleteBtn.className = 'secondary';
      deleteBtn.textContent = 'Delete';
      deleteBtn.addEventListener('click', () => {
        delete state.selectors[key];
        state.order = state.order.filter((k) => k !== key);
        persistSelectors();
        renderSiteEditor();
        renderAgents();
      });
      actions.appendChild(deleteBtn);
    }

    row.appendChild(actions);
    elements.siteEditor.appendChild(row);
  });
}

function collectSelectorsFromEditor() {
  const rows = elements.siteEditor.querySelectorAll('.site-row');
  const next = {};
  rows.forEach((row) => {
    const key = row.dataset.key.trim();
    const displayName = row.querySelector('.field-name').value.trim() || key;
    const home = row.querySelector('.field-home').value.trim();
    const patterns = row
      .querySelector('.field-patterns')
      .value.split(/\r?\n/)
      .map((s) => s.trim())
      .filter(Boolean);
    const input = row
      .querySelector('.field-input')
      .value.split(/\r?\n/)
      .map((s) => s.trim())
      .filter(Boolean);
    const sendButton = row
      .querySelector('.field-send')
      .value.split(/\r?\n/)
      .map((s) => s.trim())
      .filter(Boolean);
    const messageContainer = row
      .querySelector('.field-message')
      .value.split(/\r?\n/)
      .map((s) => s.trim())
      .filter(Boolean);
    next[key] = {
      displayName,
      home,
      patterns: patterns.length ? patterns : home ? [home] : [],
      input,
      sendButton,
      messageContainer
    };
  });
  return next;
}

async function persistSelectors() {
  const next = collectSelectorsFromEditor();
  state.selectors = next;
  state.order = state.order.filter((key) => next[key]);
  Object.keys(next).forEach((key) => {
    if (!state.order.includes(key)) {
      state.order.push(key);
    }
  });
  await api.saveSelectors(next);
  renderAgents();
}

function collectSettingsFromModal() {
  return {
    confirmBeforeSend: elements.confirmToggle.checked,
    delayMin: Number(elements.delayMin.value) || 0,
    delayMax: Number(elements.delayMax.value) || 0,
    messageLimit: Number(elements.messageLimit.value) || 1,
    roundTableTurns: Number(elements.defaultTurns.value) || 1,
    copilotHost: elements.copilotHost.value.trim(),
    comfyHost: elements.settingsComfyHost.value.trim(),
    comfyAutoImport: elements.settingsComfyAuto.checked,
    ollamaHost: elements.settingsOllamaHost.value.trim(),
    ollamaModel: elements.settingsOllamaModel.value.trim()
  };
}

async function persistSettings() {
  const next = collectSettingsFromModal();
  const previousOllamaHost = state.settings.ollamaHost;
  const previousComfyHost = state.settings.comfyHost;
  const previousComfyAuto = state.settings.comfyAutoImport;
  state.settings = { ...state.settings, ...next };
  await api.saveSettings(state.settings);
  elements.roundTurns.value = state.settings.roundTableTurns;
  syncStudioHosts();
  if (next.ollamaHost !== previousOllamaHost) {
    state.local.ollamaOutput = '';
    renderOllamaOutput();
    refreshOllamaModels({ silent: true });
  }
  if (next.comfyHost !== previousComfyHost) {
    state.local.comfyImported = new Set();
    refreshComfyHistory({ silent: true });
  }
  if (!previousComfyAuto && state.settings.comfyAutoImport) {
    autoImportComfyResult();
  }
}

function openSettingsModal() {
  renderSiteEditor();
  hydrateSettings();
  elements.settingsModal.classList.remove('hidden');
  document.body.classList.add('modal-open');
}

async function closeSettingsModal(save = true) {
  if (save) {
    await persistSelectors();
    await persistSettings();
    showToast('Settings saved.');
  } else {
    renderSiteEditor();
    hydrateSettings();
  }
  elements.settingsModal.classList.add('hidden');
  document.body.classList.remove('modal-open');
}

elements.openSettings.addEventListener('click', () => {
  openSettingsModal();
});

elements.closeSettings.addEventListener('click', async () => {
  await closeSettingsModal(true);
});

elements.settingsModal.addEventListener('click', async (event) => {
  if (event.target === elements.settingsModal) {
    await closeSettingsModal(false);
  }
});

document.addEventListener('keydown', async (event) => {
  if (event.key === 'Escape' && !elements.settingsModal.classList.contains('hidden')) {
    await closeSettingsModal(false);
  }
});

elements.addSiteBtn.addEventListener('click', () => {
  let key = prompt('Enter a unique key (letters, numbers, hyphen):');
  if (!key) return;
  key = key.trim().toLowerCase();
  if (!/^[a-z0-9\-]+$/.test(key)) {
    showToast('Key must contain only letters, numbers, or hyphen.');
    return;
  }
  if (state.selectors[key]) {
    showToast('Key already exists.');
    return;
  }
  state.selectors[key] = {
    displayName: key,
    home: '',
    patterns: [],
    input: [],
    sendButton: [],
    messageContainer: []
  };
  state.order.push(key);
  state.selected.add(key);
  renderSiteEditor();
  renderAgents();
});

if (elements.importSelectorsBtn) {
  elements.importSelectorsBtn.addEventListener('click', async () => {
    const result = await api.importSelectors();
    if (result && result.ok) {
      state.selectors = result.selectors || state.selectors;
      state.order = Object.keys(state.selectors);
      renderSiteEditor();
      renderAgents();
      showToast('selectors.json imported.');
    } else if (result && result.error) {
      showToast(`Import failed: ${result.error}`);
    }
  });
}

if (elements.exportSelectorsBtn) {
  elements.exportSelectorsBtn.addEventListener('click', async () => {
    const result = await api.exportSelectors();
    if (result && result.ok) {
      showToast(`selectors.json exported to ${result.path}`);
    } else if (result && result.error) {
      showToast(`Export failed: ${result.error}`);
    }
  });
}

if (elements.openConfigBtn) {
  elements.openConfigBtn.addEventListener('click', async () => {
    await api.openConfigFolder();
    showToast('Config folder opened in Explorer.');
  });
}

async function ensureAgent(key) {
  try {
    const status = await api.ensureAgent(key);
    if (status) {
      state.agents[key] = { ...state.agents[key], ...status };
      renderAgents();
    }
  } catch (error) {
    showToast(`${key}: unable to reach agent window.`);
  }
}

async function sendToAgents(targets, message, modeLabel) {
  if (!message) {
    showToast('Composer is empty.');
    return;
  }
  if (!targets.length) {
    showToast('Select at least one assistant.');
    return;
  }
  if (state.settings.confirmBeforeSend) {
    const ok = await confirmSend(`Confirm ${modeLabel} to ${targets.length} assistant(s)?`);
    if (!ok) {
      return;
    }
  }
  for (const key of targets) {
    await ensureAgent(key);
    try {
      await api.sendAgent({ key, text: buildMessageWithAttachments(message) });
      appendLog(`${key}: message queued.`);
    } catch (error) {
      appendLog(`${key}: send error ${error.message || error}`);
      showToast(`${key}: failed to send. Check selectors.`);
    }
  }
}

function buildMessageWithAttachments(base) {
  if (!state.attachments.length) return base;
  const parts = [base];
  state.attachments.forEach((attachment, index) => {
    if (attachment.type === 'text') {
      parts.push(`\n\n[Attachment ${index + 1}] ${attachment.title}\n${attachment.meta}\n${attachment.body}`);
    } else {
      const meta = attachment.meta ? `\n${attachment.meta}` : '';
      parts.push(`\n\n[Attachment ${index + 1}] ${attachment.title}${meta}\n(${attachment.type || 'asset'} attached in OmniChat)`);
    }
  });
  return parts.join('');
}

elements.broadcastBtn.addEventListener('click', async () => {
  const targets = Array.from(state.selected);
  const message = elements.composerInput.value.trim();
  await sendToAgents(targets, message, 'broadcast');
});

elements.singleSendBtn.addEventListener('click', async () => {
  const key = elements.singleTarget.value;
  const message = elements.composerInput.value.trim();
  if (!key) {
    showToast('Choose a target.');
    return;
  }
  await sendToAgents([key], message, `send to ${key}`);
});

function getPrimaryAgentKey() {
  if (state.selected.size > 0) {
    return Array.from(state.selected)[0];
  }
  const keys = Object.keys(state.selectors);
  return keys[0];
}

elements.quoteBtn.addEventListener('click', async () => {
  const key = getPrimaryAgentKey();
  if (!key) {
    showToast('No assistants available.');
    return;
  }
  await ensureAgent(key);
  const result = await api.captureSelection(key);
  if (!result || !result.ok || !result.selection) {
    showToast('No selection captured.');
    return;
  }
  pushAttachment({
    title: `Quote from ${result.title || key}`,
    meta: result.url || '',
    body: result.selection
  });
});

elements.snapshotBtn.addEventListener('click', async () => {
  const key = getPrimaryAgentKey();
  if (!key) {
    showToast('No assistants available.');
    return;
  }
  await ensureAgent(key);
  const result = await api.snapshotPage({ key, limit: 2000 });
  if (!result || !result.ok) {
    showToast('Snapshot failed.');
    return;
  }
  pushAttachment({
    title: `Snapshot: ${result.title || key}`,
    meta: result.url || '',
    body: result.content || ''
  });
});

elements.attachBtn.addEventListener('click', () => {
  const text = prompt('Paste text to attach.');
  if (!text) {
    return;
  }
  const chunks = text.match(/.{1,1800}/gs) || [];
  chunks.forEach((chunk, index) => {
    pushAttachment({
      title: index === 0 ? 'Snippet' : `Snippet part ${index + 1}`,
      meta: `Length ${chunk.length} characters`,
      body: chunk
    });
  });
});

if (elements.ollamaRefresh) {
  elements.ollamaRefresh.addEventListener('click', () => {
    refreshOllamaModels();
  });
}

if (elements.ollamaGenerate) {
  elements.ollamaGenerate.addEventListener('click', () => {
    runOllamaGeneration();
  });
}

if (elements.ollamaInsert) {
  elements.ollamaInsert.addEventListener('click', () => {
    if (!state.local.ollamaOutput) {
      showToast('Generate with Ollama first.');
      return;
    }
    const existing = elements.composerInput.value.trim();
    const snippet = `Ollama (${state.settings.ollamaModel || 'model'}):\n${state.local.ollamaOutput}`;
    elements.composerInput.value = existing ? `${existing}\n\n${snippet}` : snippet;
  });
}

if (elements.ollamaModelSelect) {
  elements.ollamaModelSelect.addEventListener('change', () => {
    const value = elements.ollamaModelSelect.value;
    state.settings.ollamaModel = value;
    scheduleSettingsSave();
  });
}

if (elements.ollamaHostField) {
  elements.ollamaHostField.addEventListener('change', () => {
    state.settings.ollamaHost = elements.ollamaHostField.value.trim();
    scheduleSettingsSave();
    state.local.ollamaOutput = '';
    renderOllamaOutput();
    refreshOllamaModels({ silent: true });
  });
}

if (elements.comfyHostField) {
  elements.comfyHostField.addEventListener('change', () => {
    state.settings.comfyHost = elements.comfyHostField.value.trim();
    scheduleSettingsSave();
    state.local.comfyImported = new Set();
    refreshComfyHistory({ silent: true });
  });
}

if (elements.comfyRefresh) {
  elements.comfyRefresh.addEventListener('click', () => {
    refreshComfyHistory();
  });
}

if (elements.comfyRun) {
  elements.comfyRun.addEventListener('click', async () => {
    try {
      setComfyBusy(true);
      const host = elements.comfyHostField.value.trim();
      state.settings.comfyHost = host;
      scheduleSettingsSave();
      const result = await api.runComfyWorkflow(host || undefined);
      if (!result || !result.ok) {
        if (result?.canceled) {
          renderComfyStatus('Workflow selection canceled.');
          return;
        }
        throw new Error(result?.error || 'Workflow launch failed.');
      }
      renderComfyStatus('Workflow queued. Waiting for results…');
      showToast('ComfyUI workflow submitted.');
      setTimeout(() => refreshComfyHistory({ silent: true }), 3000);
    } catch (error) {
      renderComfyStatus(error.message || 'Workflow launch failed.', true);
      showToast(`ComfyUI: ${error.message}`);
    } finally {
      setComfyBusy(false);
    }
  });
}

function pushAttachment(attachment) {
  state.attachments.push({ type: 'text', ...attachment });
  renderAttachments();
}

function renderAttachments() {
  elements.attachments.innerHTML = '';
  if (!state.attachments.length) {
    elements.attachments.textContent = 'No attachments yet.';
    return;
  }
  state.attachments.forEach((attachment, index) => {
    const div = document.createElement('div');
    div.className = 'attachment';
    const title = document.createElement('div');
    title.className = 'attachment-title';
    title.textContent = `${index + 1}. ${attachment.title}`;
    const meta = document.createElement('div');
    meta.className = 'attachment-meta';
    meta.textContent = attachment.meta;
    const body = document.createElement('div');
    body.className = 'attachment-body';
    if (attachment.type === 'text') {
      body.textContent = attachment.body;
    } else {
      body.textContent = attachment.body || `${attachment.type} attachment`;
    }
    const actions = document.createElement('div');
    actions.className = 'site-actions';
    const insertBtn = document.createElement('button');
    insertBtn.className = 'secondary';
    insertBtn.textContent = 'Insert into composer';
    insertBtn.addEventListener('click', () => {
      const chunk = attachment.type === 'text'
        ? attachment.body
        : `${attachment.title}\n${attachment.meta || ''}`.trim();
      elements.composerInput.value = `${elements.composerInput.value}\n\n${chunk}`.trim();
    });
    const removeBtn = document.createElement('button');
    removeBtn.className = 'secondary';
    removeBtn.textContent = 'Remove';
    removeBtn.addEventListener('click', () => {
      state.attachments.splice(index, 1);
      if (attachment.assetKey && state.local.comfyImported?.has(attachment.assetKey)) {
        state.local.comfyImported.delete(attachment.assetKey);
      }
      renderAttachments();
    });
    actions.appendChild(insertBtn);
    actions.appendChild(removeBtn);
    let mediaWrapper = null;
    if (attachment.dataUrl) {
      const media = document.createElement(attachment.type === 'video' ? 'video' : 'img');
      media.src = attachment.dataUrl;
      media.className = 'attachment-media-item';
      if (attachment.type === 'video') {
        media.controls = true;
      }
      mediaWrapper = document.createElement('div');
      mediaWrapper.className = 'attachment-media';
      mediaWrapper.appendChild(media);
    }
    div.appendChild(title);
    div.appendChild(meta);
    div.appendChild(body);
    if (mediaWrapper) {
      div.appendChild(mediaWrapper);
    }
    div.appendChild(actions);
    elements.attachments.appendChild(div);
  });
}

function syncStudioHosts() {
  if (elements.ollamaHostField) {
    elements.ollamaHostField.value = state.settings.ollamaHost || elements.ollamaHostField.placeholder || '';
  }
  if (elements.comfyHostField) {
    elements.comfyHostField.value = state.settings.comfyHost || elements.comfyHostField.placeholder || '';
  }
  renderOllamaModels();
  renderOllamaOutput();
  renderComfyGallery();
}

function renderOllamaModels() {
  if (!elements.ollamaModelSelect) return;
  elements.ollamaModelSelect.innerHTML = '';
  if (!state.local.ollamaModels.length) {
    const option = document.createElement('option');
    option.value = '';
    option.textContent = 'No models detected';
    elements.ollamaModelSelect.appendChild(option);
    elements.ollamaModelSelect.disabled = true;
    if (state.settings.ollamaModel) {
      state.settings.ollamaModel = '';
      scheduleSettingsSave();
    }
    return;
  }
  elements.ollamaModelSelect.disabled = false;
  state.local.ollamaModels.forEach((model) => {
    const option = document.createElement('option');
    option.value = model;
    option.textContent = model;
    elements.ollamaModelSelect.appendChild(option);
  });
  const preferred = state.settings.ollamaModel;
  if (preferred && state.local.ollamaModels.includes(preferred)) {
    elements.ollamaModelSelect.value = preferred;
  } else {
    elements.ollamaModelSelect.selectedIndex = 0;
    state.settings.ollamaModel = elements.ollamaModelSelect.value;
    scheduleSettingsSave();
  }
}

function renderOllamaOutput() {
  if (!elements.ollamaOutput) return;
  elements.ollamaOutput.textContent = state.local.ollamaOutput || 'Generated text will appear here.';
}

function setOllamaBusy(isBusy) {
  state.local.ollamaBusy = isBusy;
  if (elements.ollamaGenerate) {
    elements.ollamaGenerate.disabled = isBusy;
  }
  if (elements.ollamaRefresh) {
    elements.ollamaRefresh.disabled = isBusy;
  }
}

async function refreshOllamaModels({ silent = false } = {}) {
  if (!elements.ollamaHostField) return;
  try {
    setOllamaBusy(true);
    const host = elements.ollamaHostField.value.trim();
    state.settings.ollamaHost = host;
    scheduleSettingsSave();
    const result = await api.listOllamaModels(host || undefined);
    if (!result || !result.ok) {
      throw new Error(result?.error || 'Unable to reach Ollama.');
    }
    state.local.ollamaModels = result.models || [];
    renderOllamaModels();
    if (!silent) {
      showToast('Ollama models refreshed.');
    }
  } catch (error) {
    state.local.ollamaModels = [];
    renderOllamaModels();
    if (!silent) {
      showToast(`Ollama: ${error.message}`);
    }
  } finally {
    setOllamaBusy(false);
  }
}

async function runOllamaGeneration() {
  const model = elements.ollamaModelSelect.value || state.settings.ollamaModel;
  const prompt = elements.ollamaPrompt.value.trim();
  if (!model) {
    showToast('Choose an Ollama model.');
    return;
  }
  if (!prompt) {
    showToast('Enter a prompt for Ollama.');
    return;
  }
  try {
    setOllamaBusy(true);
    const host = elements.ollamaHostField.value.trim();
    state.settings.ollamaHost = host;
    scheduleSettingsSave();
    const result = await api.generateOllama({ model, prompt, host: host || undefined });
    if (!result || !result.ok) {
      throw new Error(result?.error || 'Generation failed.');
    }
    const text = (result.text || '').trim();
    state.local.ollamaOutput = text;
    renderOllamaOutput();
    if (text) {
      pushAttachment({
        type: 'text',
        title: `Ollama (${model})`,
        meta: host ? `Host ${host}` : 'Local host',
        body: text
      });
    }
    showToast('Ollama response ready.');
  } catch (error) {
    showToast(`Ollama: ${error.message}`);
  } finally {
    setOllamaBusy(false);
  }
}

function renderComfyStatus(message, isError = false) {
  if (!elements.comfyStatus) return;
  elements.comfyStatus.textContent = message;
  elements.comfyStatus.classList.toggle('error', !!isError);
}

function setComfyBusy(isBusy) {
  state.local.comfyBusy = isBusy;
  if (elements.comfyRefresh) {
    elements.comfyRefresh.disabled = isBusy;
  }
  if (elements.comfyRun) {
    elements.comfyRun.disabled = isBusy;
  }
}

function renderComfyGallery() {
  if (!elements.comfyGallery) return;
  elements.comfyGallery.innerHTML = '';
  if (!state.local.comfyJobs.length) {
    renderComfyStatus('No ComfyUI results yet.');
    return;
  }
  renderComfyStatus(`Showing ${state.local.comfyJobs.length} recent ComfyUI jobs.`);
  let assetCount = 0;
  state.local.comfyJobs.forEach((job) => {
    const assets = [...(job.images || []), ...(job.videos || [])];
    if (!assets.length) return;
    assets.forEach((asset) => {
      const item = document.createElement('div');
      item.className = 'gallery-item';
      const isVideo = (asset.mime || '').startsWith('video/');
      const media = document.createElement(isVideo ? 'video' : 'img');
      media.src = asset.url;
      if (isVideo) {
        media.controls = true;
      }
      item.appendChild(media);
      const caption = document.createElement('div');
      const created = job.created ? new Date(job.created).toLocaleTimeString() : '';
      caption.textContent = `${job.title || job.id}${created ? ` · ${created}` : ''}`;
      item.appendChild(caption);
      const meta = document.createElement('div');
      meta.className = 'attachment-meta';
      meta.textContent = asset.filename || '';
      item.appendChild(meta);
      const btn = document.createElement('button');
      btn.className = 'secondary';
      btn.textContent = 'Import to attachments';
      btn.addEventListener('click', async () => {
        await importComfyAsset(job, asset);
      });
      item.appendChild(btn);
      elements.comfyGallery.appendChild(item);
      assetCount += 1;
    });
  });
  if (!assetCount) {
    renderComfyStatus('Recent jobs do not contain downloadable assets yet.');
  }
}

async function refreshComfyHistory({ silent = false } = {}) {
  if (!elements.comfyHostField) return;
  try {
    setComfyBusy(true);
    const host = elements.comfyHostField.value.trim();
    state.settings.comfyHost = host;
    scheduleSettingsSave();
    const result = await api.listComfyJobs({ limit: 12, host });
    if (!result || !result.ok) {
      throw new Error(result?.error || 'Unable to reach ComfyUI.');
    }
    state.local.comfyJobs = result.jobs || [];
    renderComfyGallery();
    if (!silent) {
      showToast('ComfyUI results updated.');
    }
    if (state.settings.comfyAutoImport) {
      autoImportComfyResult();
    }
  } catch (error) {
    state.local.comfyJobs = [];
    renderComfyGallery();
    renderComfyStatus(error.message || 'Unable to reach ComfyUI.', true);
    if (!silent) {
      showToast(`ComfyUI: ${error.message}`);
    }
  } finally {
    setComfyBusy(false);
  }
}

function buildComfyAssetKey(job, asset) {
  return `${job.id || 'job'}:${asset.filename || 'asset'}:${asset.subfolder || ''}`;
}

async function importComfyAsset(job, asset) {
  try {
    const key = buildComfyAssetKey(job, asset);
    if (state.local.comfyImported.has(key)) {
      showToast('Asset already imported.');
      return;
    }
    state.local.comfyImported.add(key);
    const host = elements.comfyHostField ? elements.comfyHostField.value.trim() : '';
    const result = await api.fetchComfyAsset({
      filename: asset.filename,
      subfolder: asset.subfolder,
      type: asset.type,
      mime: asset.mime,
      host: host || undefined
    });
    if (!result || !result.ok) {
      throw new Error(result?.error || 'Unable to fetch asset.');
    }
    const type = (asset.mime || '').startsWith('video/') ? 'video' : 'image';
    pushAttachment({
      type,
      title: `${job.title || 'ComfyUI asset'}`,
      meta: asset.filename || '',
      body: `${job.title || job.id} · ${asset.filename || ''}`.trim(),
      dataUrl: result.dataUrl,
      assetKey: key
    });
    showToast('ComfyUI asset imported.');
  } catch (error) {
    const key = buildComfyAssetKey(job, asset);
    if (state.local.comfyImported.has(key) && !state.attachments.some((att) => att.assetKey === key)) {
      state.local.comfyImported.delete(key);
    }
    showToast(`ComfyUI: ${error.message}`);
  }
}

function autoImportComfyResult() {
  const jobs = state.local.comfyJobs || [];
  for (const job of jobs) {
    const assets = [...(job.images || []), ...(job.videos || [])];
    for (const asset of assets) {
      const key = buildComfyAssetKey(job, asset);
      if (!state.local.comfyImported.has(key)) {
        importComfyAsset(job, asset);
        return;
      }
    }
  }
}

async function startRoundTable() {
  const targets = Array.from(state.selected);
  if (!targets.length) {
    showToast('Select assistants for the round-table.');
    return;
  }
  const message = elements.composerInput.value.trim();
  if (!message) {
    showToast('Composer is empty.');
    return;
  }
  const turns = Number(elements.roundTurns.value) || state.settings.roundTableTurns || 1;
  if (state.settings.confirmBeforeSend) {
    const ok = await confirmSend(`Start round-table with ${targets.length} assistants for ${turns} turns?`);
    if (!ok) return;
  }
  state.round.active = true;
  state.round.paused = false;
  state.round.baseMessage = message;
  state.round.turnsRemaining = turns;
  state.round.queue = buildRoundQueue(targets);
  state.round.lastTranscript = '';
  appendLog(`Round-table started (${turns} turns).`);
  processRoundStep();
}

elements.roundStart.addEventListener('click', startRoundTable);

elements.roundPause.addEventListener('click', () => {
  if (!state.round.active) return;
  state.round.paused = true;
  appendLog('Round-table paused.');
});

elements.roundResume.addEventListener('click', () => {
  if (!state.round.active) return;
  state.round.paused = false;
  appendLog('Round-table resumed.');
  processRoundStep();
});

elements.roundStop.addEventListener('click', stopRoundTable);

elements.exportLogBtn.addEventListener('click', async () => {
  const payload = state.log.join('\n');
  const result = await api.exportLog(payload);
  if (result && result.ok) {
    showToast(`Log exported to ${result.path}`);
  }
});

elements.refreshAgents.addEventListener('click', async () => {
  for (const key of Object.keys(state.selectors)) {
    await ensureAgent(key);
  }
  showToast('Agent status refreshed.');
});

function stopRoundTable() {
  if (!state.round.active) return;
  state.round.active = false;
  state.round.paused = false;
  state.round.queue = [];
  state.round.turnsRemaining = 0;
  if (state.round.timer) {
    clearTimeout(state.round.timer);
    state.round.timer = null;
  }
  appendLog('Round-table stopped.');
}

function buildRoundQueue(targets) {
  const ordered = state.order.filter((key) => targets.includes(key));
  return [...ordered];
}

async function processRoundStep() {
  if (!state.round.active) {
    return;
  }
  if (state.round.paused) {
    state.round.timer = setTimeout(processRoundStep, 500);
    return;
  }
  if (state.round.queue.length === 0) {
    state.round.turnsRemaining -= 1;
    if (state.round.turnsRemaining <= 0) {
      appendLog('Round-table completed.');
      stopRoundTable();
      return;
    }
    state.round.queue = buildRoundQueue(Array.from(state.selected));
  }
  const key = state.round.queue.shift();
  const message = buildRoundMessage(key);
  try {
    await ensureAgent(key);
    await api.sendAgent({ key, text: message });
    appendLog(`Round-table: sent turn to ${key}.`);
    const messages = await api.readAgent(key);
    state.round.lastTranscript = messages.join('\n');
  } catch (error) {
    appendLog(`Round-table: ${key} failed (${error.message || error}).`);
    showToast(`${key} send failed during round-table.`);
  }
  state.round.timer = setTimeout(processRoundStep, 400);
}

function buildRoundMessage(key) {
  const history = state.round.lastTranscript
    ? `\n\nLatest transcript:\n${state.round.lastTranscript}`
    : '';
  return `${state.round.baseMessage}${history}`;
}

async function reloadSelectors() {
  const payload = await api.bootstrap();
  state.selectors = payload.selectors;
  state.settings = payload.settings;
  state.log = payload.log || [];
  if (!state.order.length) {
    state.order = Object.keys(state.selectors);
  }
  renderLog();
  renderAgents();
  renderSiteEditor();
  hydrateSettings();
  refreshOllamaModels({ silent: true });
  refreshComfyHistory({ silent: true });
  renderAttachments();
}

function hydrateSettings() {
  elements.confirmToggle.checked = !!state.settings.confirmBeforeSend;
  elements.delayMin.value = state.settings.delayMin || 0;
  elements.delayMax.value = state.settings.delayMax || 0;
  elements.messageLimit.value = state.settings.messageLimit || 5;
  elements.defaultTurns.value = state.settings.roundTableTurns || 2;
  elements.copilotHost.value = state.settings.copilotHost || '';
  elements.roundTurns.value = state.settings.roundTableTurns || 2;
  elements.settingsComfyHost.value = state.settings.comfyHost || '';
  elements.settingsComfyAuto.checked = !!state.settings.comfyAutoImport;
  elements.settingsOllamaHost.value = state.settings.ollamaHost || '';
  elements.settingsOllamaModel.value = state.settings.ollamaModel || '';
  syncStudioHosts();
}

async function bootstrap() {
  const payload = await api.bootstrap();
  state.selectors = payload.selectors || {};
  state.settings = payload.settings || {};
  state.log = payload.log || [];
  state.order = Object.keys(state.selectors);
  state.order.forEach((key) => state.selected.add(key));
  renderLog();
  renderAgents();
  renderSiteEditor();
  hydrateSettings();
  refreshOllamaModels({ silent: true });
  refreshComfyHistory({ silent: true });
  renderAttachments();
}

api.onStatus((status) => {
  state.agents[status.key] = { ...state.agents[status.key], ...status };
  renderAgents();
});

api.onStatusInit((entries) => {
  entries.forEach((entry) => {
    state.agents[entry.key] = { ...state.agents[entry.key], ...entry };
  });
  renderAgents();
});

api.onLog((entry) => {
  appendLog(entry);
});

api.onToast((message) => {
  showToast(message);
});

window.addEventListener('beforeunload', () => {
  stopRoundTable();
});

bootstrap();
:renderer_js_END
