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
mkdir "%RUNTIME_DIR%\node" >nul 2>nul
mkdir "%RUNTIME_DIR%\electron" >nul 2>nul
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

set "NODE_ZIP=%TEMP_DIR%\node.zip"
set "ELECTRON_ZIP=%TEMP_DIR%\electron.zip"

if exist "%NODE_ZIP%" del "%NODE_ZIP%"
if exist "%ELECTRON_ZIP%" del "%ELECTRON_ZIP%"

echo Downloading Node.js runtime...
curl.exe -L -# -o "%NODE_ZIP%" "%NODE_URL%"
if errorlevel 1 (
  echo Failed to download Node.js.
  exit /b 1
)

echo Extracting Node.js...
tar.exe -xf "%NODE_ZIP%" -C "%RUNTIME_DIR%\node" --strip-components=1
if errorlevel 1 (
  echo Failed to extract Node.js.
  exit /b 1
)
call :flatten_dir "%RUNTIME_DIR%\node" node.exe
if errorlevel 1 exit /b 1

echo Downloading Electron runtime...
curl.exe -L -# -o "%ELECTRON_ZIP%" "%ELECTRON_URL%"
if errorlevel 1 (
  echo Failed to download Electron.
  exit /b 1
)

echo Extracting Electron...
tar.exe -xf "%ELECTRON_ZIP%" -C "%RUNTIME_DIR%\electron" --strip-components=1
if errorlevel 1 (
  echo Failed to extract Electron.
  exit /b 1
)
call :flatten_dir "%RUNTIME_DIR%\electron" electron.exe
if errorlevel 1 exit /b 1

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

call :create_shortcut "%USERPROFILE%\Desktop\OmniChat.lnk"

echo Launching OmniChat...
start "" "%RUNTIME_DIR%\electron\electron.exe" "%APP_DIR%"

echo Cleaning up...
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%"

echo OmniChat is ready to use.
echo INSTALLATION_COMPLETE
exit /b 0


:create_shortcut
set "SHORTCUT_PATH=%~1"
set "VBS=%TEMP%\omnichat_shortcut.vbs"
> "%VBS%" (
  echo Set shell = CreateObject("WScript.Shell")
  echo Set shortcut = shell.CreateShortcut("%SHORTCUT_PATH%")
  echo shortcut.TargetPath = "%RUNTIME_DIR%\electron\electron.exe"
  echo shortcut.Arguments = ""%APP_DIR%""
  echo shortcut.Description = "%APP_NAME%"
  echo shortcut.WorkingDirectory = "%APP_DIR%"
  echo shortcut.IconLocation = "%RUNTIME_DIR%\electron\electron.exe,0"
  echo shortcut.Save
)
cscript //NoLogo "%VBS%"
del "%VBS%" >nul 2>nul
exit /b

:flatten_dir
setlocal EnableDelayedExpansion
set "TARGET_DIR=%~1"
set "TARGET_FILE=%~2"
if exist "!TARGET_DIR!\!TARGET_FILE!" (
  endlocal
  exit /b 0
)
for /d %%D in ("!TARGET_DIR!\*") do (
  if exist "%%~fD\!TARGET_FILE!" (
    echo Normalizing runtime layout in %%~nxD...
    robocopy "%%~fD" "!TARGET_DIR!" /E /MOVE >nul
    if errorlevel 8 (
      echo Failed to normalize %%~fD.
      endlocal
      exit /b 1
    )
    if exist "%%~fD" rd /s /q "%%~fD"
    goto :flatten_dir_check
  )
)
:flatten_dir_check
if not exist "!TARGET_DIR!\!TARGET_FILE!" (
  echo Required file !TARGET_FILE! not found under !TARGET_DIR!.
  endlocal
  exit /b 1
)
endlocal
exit /b 0

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
  echo       ^</section^>
  echo     ^</main^>
  echo     ^<aside class="pane pane-right"^>
  echo       ^<header class="pane-header"^>
  echo         ^<div^>
  echo           ^<h2^>Live Log^</h2^>
  echo           ^<button id="exportLogBtn" class="secondary"^>Export^</button^>
  echo         ^</div^>
  echo         ^<button id="openSettings" class="secondary"^>Settings^</button^>
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
  echo         ^<button id="closeSettings" class="secondary"^>Close^</button^>
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
  echo         ^</div^>
  echo       ^</section^>
  echo       ^<section^>
  echo         ^<h3^>Browser Assistants^</h3^>
  echo         ^<div id="siteEditor"^>^</div^>
  echo         ^<button id="addSiteBtn" class="secondary"^>Add Site^</button^>
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
  echo const INSTALL_ROOT = path.join^(process.env.LOCALAPPDATA ^|^| app.getPath^('userData'^), 'OmniChat'^);
  echo const CONFIG_ROOT = path.join^(INSTALL_ROOT, 'config'^);
  echo const LOG_ROOT = path.join^(INSTALL_ROOT, 'logs'^);
  echo const SELECTOR_PATH = path.join^(CONFIG_ROOT, 'selectors.json'^);
  echo const SETTINGS_PATH = path.join^(CONFIG_ROOT, 'settings.json'^);
  echo const FIRST_RUN_PATH = path.join^(INSTALL_ROOT, 'FIRST_RUN.txt'^);
  echo.
  echo let mainWindow;
  echo const agentWindows = new Map^(^);
  echo const agentState = new Map^(^);
  echo const logBuffer = [];
  echo.
  echo const DEFAULT_SETTINGS = {
  echo   confirmBeforeSend: true,
  echo   delayMin: 1200,
  echo   delayMax: 2500,
  echo   messageLimit: 5,
  echo   roundTableTurns: 2,
  echo   copilotHost: 'https://copilot.microsoft.com/'
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
  echo function loadSelectors^(^) {
  echo   try {
  echo     if ^(!fs.existsSync^(SELECTOR_PATH^)^) {
  echo       fs.writeFileSync^(SELECTOR_PATH, JSON.stringify^(DEFAULT_SELECTORS, null, 2^), 'utf8'^);
  echo     }
  echo     const raw = fs.readFileSync^(SELECTOR_PATH, 'utf8'^);
  echo     const parsed = JSON.parse^(raw^);
  echo     return parsed;
  echo   } catch ^(error^) {
  echo     console.error^('Failed to load selectors', error^);
  echo     return JSON.parse^(JSON.stringify^(DEFAULT_SELECTORS^)^);
  echo   }
  echo }
  echo.
  echo function loadSettings^(^) {
  echo   try {
  echo     if ^(!fs.existsSync^(SETTINGS_PATH^)^) {
  echo       fs.writeFileSync^(SETTINGS_PATH, JSON.stringify^(DEFAULT_SETTINGS, null, 2^), 'utf8'^);
  echo       return { ...DEFAULT_SETTINGS };
  echo     }
  echo     const raw = fs.readFileSync^(SETTINGS_PATH, 'utf8'^);
  echo     const parsed = JSON.parse^(raw^);
  echo     return { ...DEFAULT_SETTINGS, ...parsed };
  echo   } catch ^(error^) {
  echo     console.error^('Failed to load settings', error^);
  echo     return { ...DEFAULT_SETTINGS };
  echo   }
  echo }
  echo.
  echo function saveSelectors^(data^) {
  echo   selectors = data;
  echo   fs.writeFileSync^(SELECTOR_PATH, JSON.stringify^(selectors, null, 2^), 'utf8'^);
  echo   broadcastStatus^(^);
  echo }
  echo.
  echo function saveSettings^(data^) {
  echo   settings = { ...settings, ...data };
  echo   fs.writeFileSync^(SETTINGS_PATH, JSON.stringify^(settings, null, 2^), 'utf8'^);
  echo }
  echo.
  echo function createWindow^(^) {
  echo   mainWindow = new BrowserWindow^({
  echo     width: 1400,
  echo     height: 900,
  echo     title: 'OmniChat',
  echo     webPreferences: {
  echo       preload: path.join^(__dirname, 'preload.js'^),
  echo       contextIsolation: true,
  echo       nodeIntegration: false
  echo     }
  echo   }^);
  echo.
  echo   mainWindow.loadFile^(path.join^(__dirname, 'index.html'^)^);
  echo.
  echo   mainWindow.on^('closed', ^(^) =^> {
  echo     mainWindow = null;
  echo   }^);
  echo }
  echo.
  echo function getAgentConfig^(key^) {
  echo   const data = selectors[key];
  echo   if ^(!data^) {
  echo     throw new Error^(`Unknown agent ${key}`^);
  echo   }
  echo   return data;
  echo }
  echo.
  echo async function ensureAgentWindow^(key^) {
  echo   if ^(agentWindows.has^(key^)^) {
  echo     return agentWindows.get^(key^);
  echo   }
  echo   const config = getAgentConfig^(key^);
  echo   const agentWin = new BrowserWindow^({
  echo     width: 1280,
  echo     height: 800,
  echo     show: false,
  echo     title: `OmniChat – ${config.displayName}`,
  echo     webPreferences: {
  echo       preload: path.join^(__dirname, 'agentPreload.js'^),
  echo       contextIsolation: true,
  echo       nodeIntegration: false,
  echo       partition: `persist:omnichat-${key}`
  echo     }
  echo   }^);
  echo.
  echo   agentWin.on^('close', ^(event^) =^> {
  echo     event.preventDefault^(^);
  echo     agentWin.hide^(^);
  echo   }^);
  echo.
  echo   agentWin.webContents.setWindowOpenHandler^(^({ url }^) =^> {
  echo     shell.openExternal^(url^);
  echo     return { action: 'deny' };
  echo   }^);
  echo.
  echo   agentWin.webContents.on^('did-finish-load', ^(^) =^> {
  echo     updateAgentState^(key, { status: 'ready', url: agentWin.webContents.getURL^(^) }^);
  echo   }^);
  echo.
  echo   agentWin.on^('focus', ^(^) =^> updateAgentState^(key, { visible: true }^)^);
  echo   agentWin.on^('hide', ^(^) =^> updateAgentState^(key, { visible: false }^)^);
  echo.
  echo   agentWindows.set^(key, agentWin^);
  echo   updateAgentState^(key, { status: 'loading' }^);
  echo   await agentWin.loadURL^(config.home^);
  echo   return agentWin;
  echo }
  echo.
  echo function updateAgentState^(key, patch^) {
  echo   const existing = agentState.get^(key^) ^|^| {};
  echo   const next = { ...existing, ...patch, key };
  echo   agentState.set^(key, next^);
  echo   if ^(mainWindow ^&^& !mainWindow.isDestroyed^(^)^) {
  echo     mainWindow.webContents.send^('agent:status', next^);
  echo   }
  echo }
  echo.
  echo function broadcastStatus^(^) {
  echo   if ^(mainWindow ^&^& !mainWindow.isDestroyed^(^)^) {
  echo     const payload = Object.keys^(selectors^).map^(^(key^) =^> ^({
  echo       key,
  echo       ...^(agentState.get^(key^) ^|^| {}^),
  echo       displayName: selectors[key].displayName ^|^| key
  echo     }^)^);
  echo     mainWindow.webContents.send^('agent:status:init', payload^);
  echo   }
  echo }
  echo.
  echo async function withAgentDOM^(key, task^) {
  echo   const config = getAgentConfig^(key^);
  echo   const agentWin = await ensureAgentWindow^(key^);
  echo   return agentWin.webContents.executeJavaScript^(`^(function^(^){
  echo     const cfg = ${JSON.stringify^({
  echo       input: config.input,
  echo       sendButton: config.sendButton,
  echo       messageContainer: config.messageContainer
  echo     }^)};
  echo     const findFirst = ^(selectors^) =^> {
  echo       if ^(!selectors^) return null;
  echo       for ^(const selector of selectors^) {
  echo         const el = document.querySelector^(selector^);
  echo         if ^(el^) return el;
  echo       }
  echo       return null;
  echo     };
  echo     return ^(${task.toString^(^)}^)^(cfg, ${settings.messageLimit}^);
  echo   }^)^(^);`, true^);
  echo }
  echo.
  echo function delay^(ms^) {
  echo   return new Promise^(^(resolve^) =^> setTimeout^(resolve, ms^)^);
  echo }
  echo.
  echo function recordLog^(entry^) {
  echo   const timestamp = new Date^(^).toISOString^(^);
  echo   const row = `[${timestamp}] ${entry}`;
  echo   logBuffer.push^(row^);
  echo   if ^(logBuffer.length ^> 5000^) {
  echo     logBuffer.shift^(^);
  echo   }
  echo   if ^(mainWindow ^&^& !mainWindow.isDestroyed^(^)^) {
  echo     mainWindow.webContents.send^('log:push', row^);
  echo   }
  echo   const logFile = path.join^(LOG_ROOT, `${new Date^(^).toISOString^(^).slice^(0, 10^)}.log`^);
  echo   fs.appendFile^(logFile, row + '\n', ^(^) =^> {}^);
  echo }
  echo.
  echo async function sendToAgent^(key, text^) {
  echo   const min = Number^(settings.delayMin^) ^|^| 0;
  echo   const max = Number^(settings.delayMax^) ^|^| min;
  echo   const wait = Math.max^(min, Math.floor^(min + Math.random^(^) * Math.max^(0, max - min^)^)^);
  echo   await delay^(wait^);
  echo   try {
  echo     const result = await withAgentDOM^(key, function ^(cfg^) {
  echo       const findFirst = ^(selectors^) =^> {
  echo         if ^(!selectors^) return null;
  echo         for ^(const selector of selectors^) {
  echo           const el = document.querySelector^(selector^);
  echo           if ^(el^) return el;
  echo         }
  echo         return null;
  echo       };
  echo       const input = findFirst^(cfg.input^);
  echo       if ^(!input^) {
  echo         return { ok: false, reason: 'input' };
  echo       }
  echo       const valueProp = Object.getOwnPropertyDescriptor^(Object.getPrototypeOf^(input^), 'value'^);
  echo       if ^(valueProp ^&^& valueProp.set^) {
  echo         valueProp.set.call^(input, text^);
  echo       } else {
  echo         input.value = text;
  echo       }
  echo       input.dispatchEvent^(new Event^('input', { bubbles: true }^)^);
  echo       input.focus^(^);
  echo       const button = findFirst^(cfg.sendButton^);
  echo       if ^(button^) {
  echo         button.click^(^);
  echo         return { ok: true, via: 'button' };
  echo       }
  echo       const event = new KeyboardEvent^('keydown', { key: 'Enter', code: 'Enter', bubbles: true }^);
  echo       input.dispatchEvent^(event^);
  echo       return { ok: true, via: 'enter' };
  echo     }^);
  echo     if ^(!result ^|^| !result.ok^) {
  echo       await withAgentDOM^(key, function ^(cfg^) {
  echo         const findFirst = ^(selectors^) =^> {
  echo           if ^(!selectors^) return null;
  echo           for ^(const selector of selectors^) {
  echo             const el = document.querySelector^(selector^);
  echo             if ^(el^) return el;
  echo           }
  echo           return null;
  echo         };
  echo         const input = findFirst^(cfg.input^);
  echo         if ^(input^) {
  echo           input.focus^(^);
  echo         }
  echo         let banner = document.getElementById^('__omnichat_hint'^);
  echo         if ^(!banner^) {
  echo           banner = document.createElement^('div'^);
  echo           banner.id = '__omnichat_hint';
  echo           banner.style.position = 'fixed';
  echo           banner.style.bottom = '16px';
  echo           banner.style.right = '16px';
  echo           banner.style.padding = '12px 18px';
  echo           banner.style.background = '#1f2937';
  echo           banner.style.color = '#ffffff';
  echo           banner.style.fontFamily = 'Segoe UI, sans-serif';
  echo           banner.style.borderRadius = '6px';
  echo           banner.style.zIndex = '999999';
  echo           document.body.appendChild^(banner^);
  echo         }
  echo         banner.textContent = 'Press Enter to send from OmniChat.';
  echo         setTimeout^(^(^) =^> banner ^&^& banner.remove^(^), 4000^);
  echo         return { ok: false };
  echo       }^);
  echo       throw new Error^(result ? result.reason : 'send'^);
  echo     }
  echo     recordLog^(`${key}: message sent via ${result.via}`^);
  echo     return result;
  echo   } catch ^(error^) {
  echo     recordLog^(`${key}: send failed ^(${error.message}^)`^);
  echo     if ^(mainWindow ^&^& !mainWindow.isDestroyed^(^)^) {
  echo       mainWindow.webContents.send^('app:toast', `${key}.${error.message ^|^| 'send'} selectors need attention.`^);
  echo     }
  echo     throw error;
  echo   }
  echo }
  echo.
  echo async function readMessages^(key^) {
  echo   try {
  echo     const messages = await withAgentDOM^(key, function ^(cfg, limit^) {
  echo       const findFirst = ^(selectors^) =^> {
  echo         if ^(!selectors^) return null;
  echo         for ^(const selector of selectors^) {
  echo           const el = document.querySelector^(selector^);
  echo           if ^(el^) return el;
  echo         }
  echo         return null;
  echo       };
  echo       const container = findFirst^(cfg.messageContainer^);
  echo       if ^(!container^) {
  echo         return { ok: false, reason: 'messageContainer' };
  echo       }
  echo       const walker = document.createTreeWalker^(container, NodeFilter.SHOW_ELEMENT, null^);
  echo       const transcript = [];
  echo       while ^(walker.nextNode^(^)^) {
  echo         const node = walker.currentNode;
  echo         if ^(node.childElementCount === 0^) {
  echo           const text = node.textContent.trim^(^);
  echo           if ^(text^) {
  echo             transcript.push^(text^);
  echo           }
  echo         }
  echo       }
  echo       const deduped = [];
  echo       for ^(const line of transcript^) {
  echo         if ^(!deduped.length ^|^| deduped[deduped.length - 1] !== line^) {
  echo           deduped.push^(line^);
  echo         }
  echo       }
  echo       return { ok: true, messages: deduped.slice^(-limit^) };
  echo     }^);
  echo     if ^(!messages.ok^) {
  echo       throw new Error^(messages.reason^);
  echo     }
  echo     return messages.messages;
  echo   } catch ^(error^) {
  echo     recordLog^(`${key}: read failed ^(${error.message}^)`^);
  echo     if ^(mainWindow ^&^& !mainWindow.isDestroyed^(^)^) {
  echo       mainWindow.webContents.send^('app:toast', `${key}.${error.message ^|^| 'read'} selectors need attention.`^);
  echo     }
  echo     return [];
  echo   }
  echo }
  echo.
  echo ipcMain.handle^('app:bootstrap', async ^(^) =^> {
  echo   ensureDirectories^(^);
  echo   ensureFirstRunGuide^(^);
  echo   selectors = loadSelectors^(^);
  echo   settings = loadSettings^(^);
  echo   broadcastStatus^(^);
  echo   return {
  echo     selectors,
  echo     settings,
  echo     log: logBuffer.slice^(-200^)
  echo   };
  echo }^);
  echo.
  echo ipcMain.handle^('selectors:save', async ^(_event, payload^) =^> {
  echo   saveSelectors^(payload^);
  echo   return { ok: true };
  echo }^);
  echo.
  echo ipcMain.handle^('settings:save', async ^(_event, payload^) =^> {
  echo   saveSettings^(payload^);
  echo   return { ok: true };
  echo }^);
  echo.
  echo ipcMain.handle^('agent:ensure', async ^(_event, key^) =^> {
  echo   await ensureAgentWindow^(key^);
  echo   return agentState.get^(key^) ^|^| { key };
  echo }^);
  echo.
  echo ipcMain.handle^('agent:connect', async ^(_event, key^) =^> {
  echo   const win = await ensureAgentWindow^(key^);
  echo   win.show^(^);
  echo   win.focus^(^);
  echo   updateAgentState^(key, { visible: true }^);
  echo   return true;
  echo }^);
  echo.
  echo ipcMain.handle^('agent:hide', async ^(_event, key^) =^> {
  echo   if ^(agentWindows.has^(key^)^) {
  echo     const win = agentWindows.get^(key^);
  echo     win.hide^(^);
  echo     updateAgentState^(key, { visible: false }^);
  echo   }
  echo   return true;
  echo }^);
  echo.
  echo ipcMain.handle^('agent:read', async ^(_event, key^) =^> {
  echo   return await readMessages^(key^);
  echo }^);
  echo.
  echo ipcMain.handle^('agent:send', async ^(_event, payload^) =^> {
  echo   const { key, text } = payload;
  echo   await ensureAgentWindow^(key^);
  echo   const messages = await readMessages^(key^);
  echo   await sendToAgent^(key, text^);
  echo   return { ok: true, previous: messages };
  echo }^);
  echo.
  echo ipcMain.handle^('agent:captureSelection', async ^(_event, key^) =^> {
  echo   try {
  echo     const result = await withAgentDOM^(key, function ^(^) {
  echo       const selection = window.getSelection^(^);
  echo       const text = selection ? selection.toString^(^).trim^(^) : '';
  echo       return {
  echo         ok: true,
  echo         selection: text,
  echo         title: document.title,
  echo         url: location.href
  echo       };
  echo     }^);
  echo     return result;
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo ipcMain.handle^('agent:snapshot', async ^(_event, { key, limit = 2000 }^) =^> {
  echo   try {
  echo     const result = await withAgentDOM^(key, function ^(_cfg, _limit^) {
  echo       const max = Number^(_limit^) ^|^| 2000;
  echo       const text = document.body ? document.body.innerText ^|^| '' : '';
  echo       return {
  echo         ok: true,
  echo         title: document.title,
  echo         url: location.href,
  echo         content: text.slice^(0, max^)
  echo       };
  echo     }^);
  echo     return result;
  echo   } catch ^(error^) {
  echo     return { ok: false, error: error.message };
  echo   }
  echo }^);
  echo.
  echo ipcMain.handle^('log:export', async ^(_event, payload^) =^> {
  echo   if ^(!mainWindow ^|^| mainWindow.isDestroyed^(^)^) {
  echo     return { ok: false };
  echo   }
  echo   const dialogResult = await dialog.showSaveDialog^(mainWindow, {
  echo     title: 'Export OmniChat Log',
  echo     filters: [{ name: 'Text Files', extensions: ['txt'] }],
  echo     defaultPath: path.join^(app.getPath^('documents'^), `omnichat-log-${Date.now^(^)}.txt`^)
  echo   }^);
  echo   if ^(dialogResult.canceled ^|^| !dialogResult.filePath^) {
  echo     return { ok: false };
  echo   }
  echo   fs.writeFileSync^(dialogResult.filePath, payload, 'utf8'^);
  echo   return { ok: true, path: dialogResult.filePath };
  echo }^);
  echo.
  echo ipcMain.handle^('settings:resetAgent', async ^(_event, key^) =^> {
  echo   if ^(!DEFAULT_SELECTORS[key]^) {
  echo     return { ok: false, error: 'unknown' };
  echo   }
  echo   selectors[key] = JSON.parse^(JSON.stringify^(DEFAULT_SELECTORS[key]^)^);
  echo   saveSelectors^(selectors^);
  echo   return { ok: true, selectors };
  echo }^);
  echo.
  echo app.whenReady^(^).then^(^(^) =^> {
  echo   ensureDirectories^(^);
  echo   ensureFirstRunGuide^(^);
  echo   selectors = loadSelectors^(^);
  echo   settings = loadSettings^(^);
  echo   createWindow^(^);
  echo.
  echo   app.on^('activate', ^(^) =^> {
  echo     if ^(BrowserWindow.getAllWindows^(^).length === 0^) {
  echo       createWindow^(^);
  echo     }
  echo   }^);
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
  echo   onStatus: ^(handler^) =^> ipcRenderer.on^('agent:status', ^(_event, data^) =^> handler^(data^)^),
  echo   onStatusInit: ^(handler^) =^> ipcRenderer.on^('agent:status:init', ^(_event, data^) =^> handler^(data^)^),
  echo   onLog: ^(handler^) =^> ipcRenderer.on^('log:push', ^(_event, data^) =^> handler^(data^)^),
  echo   onToast: ^(handler^) =^> ipcRenderer.on^('app:toast', ^(_event, message^) =^> handler^(message^)^)
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
  echo   refreshAgents: document.getElementById^('refreshAgents'^),
  echo   composerInput: document.getElementById^('composerInput'^),
  echo   broadcastBtn: document.getElementById^('broadcastBtn'^),
  echo   singleTarget: document.getElementById^('singleTarget'^),
  echo   singleSendBtn: document.getElementById^('singleSendBtn'^),
  echo   roundTurns: document.getElementById^('roundTurns'^),
  echo   roundStart: document.getElementById^('roundStartBtn'^),
  echo   roundPause: document.getElementById^('roundPauseBtn'^),
  echo   roundResume: document.getElementById^('roundResumeBtn'^),
  echo   roundStop: document.getElementById^('roundStopBtn'^),
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
  echo   addSiteBtn: document.getElementById^('addSiteBtn'^),
  echo   confirmToggle: document.getElementById^('confirmToggle'^),
  echo   delayMin: document.getElementById^('delayMin'^),
  echo   delayMax: document.getElementById^('delayMax'^),
  echo   messageLimit: document.getElementById^('messageLimit'^),
  echo   defaultTurns: document.getElementById^('defaultTurns'^),
  echo   copilotHost: document.getElementById^('copilotHost'^)
  echo };
  echo.
  echo const DEFAULT_KEYS = ['chatgpt', 'claude', 'copilot', 'gemini'];
  echo.
  echo const state = {
  echo   selectors: {},
  echo   settings: {},
  echo   order: [],
  echo   selected: new Set^(^),
  echo   agents: {},
  echo   log: [],
  echo   attachments: [],
  echo   confirmResolver: null,
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
  echo   if ^(!state.settings.confirmBeforeSend^) {
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
  echo     const config = state.selectors[key];
  echo     if ^(!config^) return;
  echo     const item = document.createElement^('div'^);
  echo     item.className = 'agent-item';
  echo     if ^(state.selected.has^(key^)^) {
  echo       item.classList.add^('active'^);
  echo     }
  echo.
  echo     const top = document.createElement^('div'^);
  echo     top.className = 'agent-top';
  echo     const name = document.createElement^('div'^);
  echo     name.innerHTML = `^<strong^>${config.displayName ^|^| key}^</strong^> ^<span class="badge"^>${key}^</span^>`;
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
  echo       renderTargetDropdown^(^);
  echo     }^);
  echo.
  echo     top.appendChild^(name^);
  echo     top.appendChild^(toggle^);
  echo.
  echo     const status = document.createElement^('div'^);
  echo     status.className = 'agent-status';
  echo     const data = state.agents[key];
  echo     const statusBits = [];
  echo     if ^(data ^&^& data.status^) statusBits.push^(data.status^);
  echo     if ^(data ^&^& data.visible^) statusBits.push^('visible'^);
  echo     if ^(data ^&^& data.url^) statusBits.push^(new URL^(data.url^).hostname^);
  echo     status.textContent = statusBits.join^(' · '^) ^|^| 'offline';
  echo.
  echo     const actions = document.createElement^('div'^);
  echo     actions.className = 'agent-actions';
  echo.
  echo     const connectBtn = document.createElement^('button'^);
  echo     connectBtn.className = 'secondary';
  echo     connectBtn.textContent = 'Connect';
  echo     connectBtn.addEventListener^('click', async ^(^) =^> {
  echo       await api.connectAgent^(key^);
  echo     }^);
  echo.
  echo     const hideBtn = document.createElement^('button'^);
  echo     hideBtn.className = 'secondary';
  echo     hideBtn.textContent = 'Hide';
  echo     hideBtn.addEventListener^('click', async ^(^) =^> {
  echo       await api.hideAgent^(key^);
  echo     }^);
  echo.
  echo     const readBtn = document.createElement^('button'^);
  echo     readBtn.className = 'secondary';
  echo     readBtn.textContent = 'Read';
  echo     readBtn.addEventListener^('click', async ^(^) =^> {
  echo       await ensureAgent^(key^);
  echo       const messages = await api.readAgent^(key^);
  echo       appendLog^(`${key}:\n${messages.join^('\n'^)}`^);
  echo     }^);
  echo.
  echo     actions.appendChild^(connectBtn^);
  echo     actions.appendChild^(hideBtn^);
  echo     actions.appendChild^(readBtn^);
  echo.
  echo     const orderControls = buildAgentOrderControls^(key^);
  echo.
  echo     if ^(!DEFAULT_KEYS.includes^(key^)^) {
  echo       const removeBtn = document.createElement^('button'^);
  echo       removeBtn.className = 'secondary';
  echo       removeBtn.textContent = 'Remove';
  echo       removeBtn.addEventListener^('click', ^(^) =^> {
  echo         delete state.selectors[key];
  echo         state.order = state.order.filter^(^(k^) =^> k !== key^);
  echo         state.selected.delete^(key^);
  echo         persistSelectors^(^);
  echo         renderAgents^(^);
  echo         renderSiteEditor^(^);
  echo       }^);
  echo       actions.appendChild^(removeBtn^);
  echo     } else {
  echo       const resetBtn = document.createElement^('button'^);
  echo       resetBtn.className = 'secondary';
  echo       resetBtn.textContent = 'Reset';
  echo       resetBtn.addEventListener^('click', async ^(^) =^> {
  echo         await api.resetAgentSelectors^(key^);
  echo         await reloadSelectors^(^);
  echo         renderSiteEditor^(^);
  echo       }^);
  echo       actions.appendChild^(resetBtn^);
  echo     }
  echo.
  echo     item.appendChild^(top^);
  echo     item.appendChild^(status^);
  echo     item.appendChild^(actions^);
  echo     item.appendChild^(orderControls^);
  echo     elements.agentList.appendChild^(item^);
  echo   }^);
  echo   renderTargetDropdown^(^);
  echo }
  echo.
  echo function renderTargetDropdown^(^) {
  echo   const selected = Array.from^(state.order^).filter^(^(key^) =^> state.selectors[key]^);
  echo   elements.singleTarget.innerHTML = '';
  echo   selected.forEach^(^(key^) =^> {
  echo     const option = document.createElement^('option'^);
  echo     const config = state.selectors[key];
  echo     option.value = key;
  echo     option.textContent = config.displayName ^|^| key;
  echo     elements.singleTarget.appendChild^(option^);
  echo   }^);
  echo }
  echo.
  echo function renderSiteEditor^(^) {
  echo   elements.siteEditor.innerHTML = '';
  echo   Object.entries^(state.selectors^).forEach^(^([key, config]^) =^> {
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
  echo     if ^(!DEFAULT_KEYS.includes^(key^)^) {
  echo       const deleteBtn = document.createElement^('button'^);
  echo       deleteBtn.className = 'secondary';
  echo       deleteBtn.textContent = 'Delete';
  echo       deleteBtn.addEventListener^('click', ^(^) =^> {
  echo         delete state.selectors[key];
  echo         state.order = state.order.filter^(^(k^) =^> k !== key^);
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
  echo   state.order = state.order.filter^(^(key^) =^> next[key]^);
  echo   Object.keys^(next^).forEach^(^(key^) =^> {
  echo     if ^(!state.order.includes^(key^)^) {
  echo       state.order.push^(key^);
  echo     }
  echo   }^);
  echo   await api.saveSelectors^(next^);
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
  echo     copilotHost: elements.copilotHost.value.trim^(^)
  echo   };
  echo }
  echo.
  echo async function persistSettings^(^) {
  echo   const next = collectSettingsFromModal^(^);
  echo   state.settings = { ...state.settings, ...next };
  echo   await api.saveSettings^(state.settings^);
  echo   elements.roundTurns.value = state.settings.roundTableTurns;
  echo }
  echo.
  echo elements.openSettings.addEventListener^('click', ^(^) =^> {
  echo   elements.settingsModal.classList.remove^('hidden'^);
  echo }^);
  echo.
  echo elements.closeSettings.addEventListener^('click', async ^(^) =^> {
  echo   await persistSelectors^(^);
  echo   await persistSettings^(^);
  echo   elements.settingsModal.classList.add^('hidden'^);
  echo   showToast^('Settings saved.'^);
  echo }^);
  echo.
  echo elements.addSiteBtn.addEventListener^('click', ^(^) =^> {
  echo   let key = prompt^('Enter a unique key ^(letters, numbers, hyphen^):'^);
  echo   if ^(!key^) return;
  echo   key = key.trim^(^).toLowerCase^(^);
  echo   if ^(!/^^[a-z0-9\-]+$/.test^(key^)^) {
  echo     showToast^('Key must contain only letters, numbers, or hyphen.'^);
  echo     return;
  echo   }
  echo   if ^(state.selectors[key]^) {
  echo     showToast^('Key already exists.'^);
  echo     return;
  echo   }
  echo   state.selectors[key] = {
  echo     displayName: key,
  echo     home: '',
  echo     patterns: [],
  echo     input: [],
  echo     sendButton: [],
  echo     messageContainer: []
  echo   };
  echo   state.order.push^(key^);
  echo   renderSiteEditor^(^);
  echo   renderAgents^(^);
  echo }^);
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
  echo   if ^(!message^) {
  echo     showToast^('Composer is empty.'^);
  echo     return;
  echo   }
  echo   if ^(!targets.length^) {
  echo     showToast^('Select at least one assistant.'^);
  echo     return;
  echo   }
  echo   if ^(state.settings.confirmBeforeSend^) {
  echo     const ok = await confirmSend^(`Confirm ${modeLabel} to ${targets.length} assistant^(s^)?`^);
  echo     if ^(!ok^) {
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
  echo   if ^(!state.attachments.length^) return base;
  echo   const parts = [base];
  echo   state.attachments.forEach^(^(attachment, index^) =^> {
  echo     parts.push^(`\n\n[Attachment ${index + 1}] ${attachment.title}\n${attachment.meta}\n${attachment.body}`^);
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
  echo   if ^(!key^) {
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
  echo   const keys = Object.keys^(state.selectors^);
  echo   return keys[0];
  echo }
  echo.
  echo elements.quoteBtn.addEventListener^('click', async ^(^) =^> {
  echo   const key = getPrimaryAgentKey^(^);
  echo   if ^(!key^) {
  echo     showToast^('No assistants available.'^);
  echo     return;
  echo   }
  echo   await ensureAgent^(key^);
  echo   const result = await api.captureSelection^(key^);
  echo   if ^(!result ^|^| !result.ok ^|^| !result.selection^) {
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
  echo   if ^(!key^) {
  echo     showToast^('No assistants available.'^);
  echo     return;
  echo   }
  echo   await ensureAgent^(key^);
  echo   const result = await api.snapshotPage^({ key, limit: 2000 }^);
  echo   if ^(!result ^|^| !result.ok^) {
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
  echo   if ^(!text^) {
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
  echo function pushAttachment^(attachment^) {
  echo   state.attachments.push^(attachment^);
  echo   renderAttachments^(^);
  echo }
  echo.
  echo function renderAttachments^(^) {
  echo   elements.attachments.innerHTML = '';
  echo   if ^(!state.attachments.length^) {
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
  echo     body.textContent = attachment.body;
  echo     const actions = document.createElement^('div'^);
  echo     actions.className = 'site-actions';
  echo     const insertBtn = document.createElement^('button'^);
  echo     insertBtn.className = 'secondary';
  echo     insertBtn.textContent = 'Insert into composer';
  echo     insertBtn.addEventListener^('click', ^(^) =^> {
  echo       elements.composerInput.value = `${elements.composerInput.value}\n\n${attachment.body}`.trim^(^);
  echo     }^);
  echo     const removeBtn = document.createElement^('button'^);
  echo     removeBtn.className = 'secondary';
  echo     removeBtn.textContent = 'Remove';
  echo     removeBtn.addEventListener^('click', ^(^) =^> {
  echo       state.attachments.splice^(index, 1^);
  echo       renderAttachments^(^);
  echo     }^);
  echo     actions.appendChild^(insertBtn^);
  echo     actions.appendChild^(removeBtn^);
  echo     div.appendChild^(title^);
  echo     div.appendChild^(meta^);
  echo     div.appendChild^(body^);
  echo     div.appendChild^(actions^);
  echo     elements.attachments.appendChild^(div^);
  echo   }^);
  echo }
  echo.
  echo async function startRoundTable^(^) {
  echo   const targets = Array.from^(state.selected^);
  echo   if ^(!targets.length^) {
  echo     showToast^('Select assistants for the round-table.'^);
  echo     return;
  echo   }
  echo   const message = elements.composerInput.value.trim^(^);
  echo   if ^(!message^) {
  echo     showToast^('Composer is empty.'^);
  echo     return;
  echo   }
  echo   const turns = Number^(elements.roundTurns.value^) ^|^| state.settings.roundTableTurns ^|^| 1;
  echo   if ^(state.settings.confirmBeforeSend^) {
  echo     const ok = await confirmSend^(`Start round-table with ${targets.length} assistants for ${turns} turns?`^);
  echo     if ^(!ok^) return;
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
  echo   if ^(!state.round.active^) return;
  echo   state.round.paused = true;
  echo   appendLog^('Round-table paused.'^);
  echo }^);
  echo.
  echo elements.roundResume.addEventListener^('click', ^(^) =^> {
  echo   if ^(!state.round.active^) return;
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
  echo   if ^(!state.round.active^) return;
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
  echo   if ^(!state.round.active^) {
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
  echo   if ^(!state.order.length^) {
  echo     state.order = Object.keys^(state.selectors^);
  echo   }
  echo   renderLog^(^);
  echo   renderAgents^(^);
  echo   renderSiteEditor^(^);
  echo   hydrateSettings^(^);
  echo }
  echo.
  echo function hydrateSettings^(^) {
  echo   elements.confirmToggle.checked = !!state.settings.confirmBeforeSend;
  echo   elements.delayMin.value = state.settings.delayMin ^|^| 0;
  echo   elements.delayMax.value = state.settings.delayMax ^|^| 0;
  echo   elements.messageLimit.value = state.settings.messageLimit ^|^| 5;
  echo   elements.defaultTurns.value = state.settings.roundTableTurns ^|^| 2;
  echo   elements.copilotHost.value = state.settings.copilotHost ^|^| '';
  echo   elements.roundTurns.value = state.settings.roundTableTurns ^|^| 2;
  echo }
  echo.
  echo async function bootstrap^(^) {
  echo   const payload = await api.bootstrap^(^);
  echo   state.selectors = payload.selectors ^|^| {};
  echo   state.settings = payload.settings ^|^| {};
  echo   state.log = payload.log ^|^| [];
  echo   state.order = Object.keys^(state.selectors^);
  echo   state.order.forEach^(^(key^) =^> state.selected.add^(key^)^);
  echo   renderLog^(^);
  echo   renderAgents^(^);
  echo   renderSiteEditor^(^);
  echo   hydrateSettings^(^);
  echo }
  echo.
  echo api.onStatus^(^(status^) =^> {
  echo   state.agents[status.key] = { ...state.agents[status.key], ...status };
  echo   renderAgents^(^);
  echo }^);
  echo.
  echo api.onStatusInit^(^(entries^) =^> {
  echo   entries.forEach^(^(entry^) =^> {
  echo     state.agents[entry.key] = { ...state.agents[entry.key], ...entry };
  echo   }^);
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
