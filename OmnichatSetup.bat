@echo off
setlocal EnableExtensions

if /I "%~1" NEQ "run" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList run -WindowStyle Hidden"
    exit /b
)

set "PS1=%TEMP%\OmnichatSetup.ps1"
call :extract_ps "%PS1%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "exitCode=%ERRORLEVEL%"
del "%PS1%" >nul 2>nul
exit /b %exitCode%

:extract_ps
set "out=%~1"
for /f "tokens=1 delims=:" %%A in ('findstr /n "^:psPayload$" "%~f0"') do set "line=%%A"
set /a line+=1
more +%line% "%~f0" > "%out%"
exit /b

:psPayload
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Net.Http

function Write-Log([string]$message) {
    Write-Host "[Omnichat] $message"
}

function Stop-Omnichat {
    Get-Process -Name 'Omnichat' -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $_.CloseMainWindow() | Out-Null
            Start-Sleep -Seconds 1
            if (!$_.HasExited) {
                $_ | Stop-Process -Force
            }
        } catch {
            $_ | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
}

function Download-File([string]$uri, [string]$destination) {
    Write-Log "Downloading $(Split-Path $destination -Leaf)..."
    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromMinutes(10)
    try {
        $data = $client.GetByteArrayAsync($uri).GetAwaiter().GetResult()
    } finally {
        $client.Dispose()
    }
    [System.IO.File]::WriteAllBytes($destination, $data)
}

function Extract-Zip([string]$zipPath, [string]$destination) {
    Write-Log "Extracting $(Split-Path $zipPath -Leaf)..."
    if (Test-Path $destination) {
        Remove-Item $destination -Recurse -Force
    }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $destination)
}

function Write-Utf8File([string]$path, [string]$content) {
    $directory = Split-Path $path -Parent
    if ($directory -and !(Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $encoding)
}

function Create-Shortcut([string]$shortcutPath, [string]$targetPath, [string]$workingDirectory) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    $shortcut.WorkingDirectory = $workingDirectory
    $shortcut.IconLocation = $targetPath
    $shortcut.Save()
}

function Show-Message([string]$text) {
    try {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        [System.Windows.Forms.MessageBox]::Show($text, 'Omnichat Setup', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    } catch {
        Write-Log $text
    }
}

try {
$electronVersion = '28.2.0'
$electronFileName = "electron-$electronVersion-win32-x64.zip"
$electronUrl = "https://github.com/electron/electron/releases/download/v$electronVersion/electron-v$electronVersion-win32-x64.zip"

$localAppData = $env:LOCALAPPDATA
if (-not $localAppData) {
    throw 'Unable to locate LocalAppData folder.'
}

$installRoot = Join-Path $localAppData 'Omnichat'
$resourcesRoot = Join-Path $installRoot 'resources'
$appRoot = Join-Path $resourcesRoot 'app'
$desktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Omnichat.lnk'

$temp = [IO.Path]::GetTempPath()
$zipPath = Join-Path $temp $electronFileName
$extractPath = Join-Path $temp 'omnichat-electron'

Write-Log 'Preparing installation...'
Stop-Omnichat

if (Test-Path $installRoot) {
    Write-Log 'Removing previous installation...'
    Remove-Item $installRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $installRoot -Force | Out-Null

Download-File -uri $electronUrl -destination $zipPath
Extract-Zip -zipPath $zipPath -destination $extractPath

$extractedRoot = Join-Path $extractPath "electron-v$electronVersion-win32-x64"
if (-not (Test-Path $extractedRoot)) {
    $extractedRoot = $extractPath
}

Copy-Item -Path (Join-Path $extractedRoot '*') -Destination $installRoot -Recurse -Force

$electronExe = Join-Path $installRoot 'electron.exe'
$omnichatExe = Join-Path $installRoot 'Omnichat.exe'
if (Test-Path $electronExe) {
    Move-Item $electronExe $omnichatExe -Force
}

$defaultAsar = Join-Path $installRoot 'resources\default_app.asar'
if (Test-Path $defaultAsar) {
    Remove-Item $defaultAsar -Force
}

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }

New-Item -ItemType Directory -Path $appRoot -Force | Out-Null

$files = @{}
$files['app/package.json'] = @'
{
  "name": "omnichat",
  "version": "0.1.0",
  "description": "Omnichat desktop orchestration app for AI assistants.",
  "main": "src/main/main.js",
  "author": "",
  "license": "MIT",
  "scripts": {
    "start": "electron .",
    "package": "electron-builder --win portable"
  },
  "dependencies": {},
  "devDependencies": {
    "electron": "^28.2.0",
    "electron-builder": "^24.6.0"
  }
}
'@

$files['app/resources/FIRST_RUN.txt'] = @'
Welcome to Omnichat!

1. Double-click OmnichatSetup to install everything automatically.
2. Open Omnichat from your new desktop shortcut.
3. Sign in to each assistant tab (ChatGPT, Claude, Copilot, Gemini).
4. Use Broadcast to send a message to the selected assistants.
5. Start a Round-table session to orchestrate K conversational turns.
'@

$files['app/resources/selectors.json'] = @'
{
  "chatgpt": {
    "input": [
      "textarea",
      "textarea[data-testid='chat-input']",
      "div[contenteditable='true']"
    ],
    "sendButton": [
      "button[data-testid='send-button']",
      "button[aria-label='Send']"
    ],
    "messageContainer": [
      "main",
      "div[class*='conversation']"
    ]
  },
  "claude": {
    "input": [
      "textarea",
      "textarea[placeholder*='Message']",
      "div[contenteditable='true']"
    ],
    "sendButton": [
      "button[type='submit']",
      "button[aria-label='Send']"
    ],
    "messageContainer": [
      "main",
      "div[class*='conversation']"
    ]
  },
  "copilot": {
    "input": [
      "textarea#userInput",
      "textarea",
      "div[contenteditable='true']",
      "textarea[placeholder*='Ask me']"
    ],
    "sendButton": [
      "button[aria-label='Send']",
      "button[data-testid='send-button']"
    ],
    "messageContainer": [
      "main",
      "div[class*='conversation']"
    ]
  },
  "gemini": {
    "input": [
      "textarea",
      "div[contenteditable='true']",
      "textarea[aria-label*='Message']"
    ],
    "sendButton": [
      "button[aria-label='Send']",
      "button[type='submit']"
    ],
    "messageContainer": [
      "main",
      "div[class*='conversation']"
    ]
  }
}
'@

$files['app/src/main/log-store.js'] = @'
const { app } = require('electron');
const fs = require('fs');
const path = require('path');

class LogStore {
  constructor() {
    this.entries = [];
  }

  append(entry) {
    const enriched = {
      timestamp: new Date().toISOString(),
      ...entry
    };
    this.entries.push(enriched);
  }

  getEntries() {
    return this.entries.slice(-500);
  }

  serialize() {
    return this.entries
      .map((entry) => `${entry.timestamp}\t${entry.type.toUpperCase()}\t${entry.message}`)
      .join('\n');
  }

  exportToFile(filename = 'Omnichat-log.txt') {
    const exportPath = path.join(app.getPath('documents'), filename);
    fs.writeFileSync(exportPath, this.serialize(), 'utf8');
    return exportPath;
  }
}

module.exports = { LogStore };
'@

$files['app/src/main/main.js'] = @'
const path = require('path');
const fs = require('fs');
const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const { SettingsStore } = require('./settings-store');
const { AgentManager } = require('./manager');
const { LogStore } = require('./log-store');

const APP_NAME = 'Omnichat';
const SELECTOR_FILE = 'selectors.json';
const FIRST_RUN_FILE = 'FIRST_RUN.txt';

const defaultSettings = {
  manualConfirm: true,
  delayRange: { min: 1200, max: 2500 },
  throttleMs: 8000,
  messagesToRead: 10,
  roundTableTurns: 2,
  copilotHost: 'https://copilot.microsoft.com',
  localModel: {
    enabled: false,
    endpoint: 'http://localhost:11434/api/generate'
  }
};

const store = new SettingsStore({ name: 'settings.json', defaults: defaultSettings });
const logStore = new LogStore();

let mainWindow;
let agentManager;

function resolveResource(relPath) {
  const appDir = app.isPackaged ? process.resourcesPath : path.join(__dirname, '../../resources');
  return path.join(appDir, relPath);
}

function ensureSelectorsFile() {
  const target = path.join(app.getPath('userData'), SELECTOR_FILE);
  if (!fs.existsSync(target)) {
    const source = resolveResource(SELECTOR_FILE);
    fs.copyFileSync(source, target);
  }
  return target;
}

function ensureFirstRunFile() {
  const target = path.join(app.getPath('userData'), FIRST_RUN_FILE);
  if (!fs.existsSync(target)) {
    fs.copyFileSync(resolveResource(FIRST_RUN_FILE), target);
  }
  return target;
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    title: APP_NAME,
    webPreferences: {
      preload: path.join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));

  mainWindow.on('closed', () => {
    mainWindow = null;
    agentManager?.dispose();
  });
}

function bootstrapAgentManager() {
  const selectorsPath = ensureSelectorsFile();
  const selectors = JSON.parse(fs.readFileSync(selectorsPath, 'utf8'));
  agentManager = new AgentManager({
    selectors,
    selectorsPath,
    logStore,
    settingsStore: store
  });
}

app.on('ready', () => {
  ensureSelectorsFile();
  ensureFirstRunFile();
  bootstrapAgentManager();
  createWindow();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (mainWindow === null) {
    createWindow();
  }
});

ipcMain.handle('selectors:get', async () => {
  const selectorsPath = ensureSelectorsFile();
  const content = fs.readFileSync(selectorsPath, 'utf8');
  return JSON.parse(content);
});

ipcMain.handle('selectors:save', async (_, payload) => {
  const selectorsPath = ensureSelectorsFile();
  fs.writeFileSync(selectorsPath, JSON.stringify(payload, null, 2), 'utf8');
  agentManager?.updateSelectors(payload);
  return true;
});

ipcMain.handle('settings:get', () => store.all);

ipcMain.handle('settings:save', (_, newSettings) => {
  const updated = { ...store.all, ...newSettings };
  store.all = updated;
  return updated;
});

ipcMain.handle('agents:list', () => agentManager.getAgentsInfo());
ipcMain.handle('agents:broadcast', (_, payload) => agentManager.broadcast(payload));
ipcMain.handle('agents:send-single', (_, payload) => agentManager.sendToSingle(payload));
ipcMain.handle('agents:start-round-table', (_, payload) => agentManager.startRoundTable(payload));
ipcMain.handle('agents:pause-round-table', () => agentManager.pauseRoundTable());
ipcMain.handle('agents:resume-round-table', () => agentManager.resumeRoundTable());
ipcMain.handle('agents:stop-round-table', () => agentManager.stopRoundTable());
ipcMain.handle('agents:local-model', (_, payload) => agentManager.invokeLocalModel(payload));
ipcMain.handle('agents:selection', (_, payload) => agentManager.captureSelection(payload));
ipcMain.handle('agents:snapshot', (_, payload) => agentManager.captureSnapshot(payload));

ipcMain.handle('log:get', () => logStore.getEntries());
ipcMain.handle('log:export', async (_, targetPath) => {
  const filePath = targetPath || dialog.showSaveDialogSync(mainWindow, {
    title: 'Export Log',
    defaultPath: path.join(app.getPath('documents'), 'Omnichat-log.txt'),
    filters: [{ name: 'Text', extensions: ['txt'] }]
  });

  if (!filePath) {
    return null;
  }

  fs.writeFileSync(filePath, logStore.serialize(), 'utf8');
  shell.showItemInFolder(filePath);
  return filePath;
});

ipcMain.handle('open-external', (_, url) => {
  if (url) {
    shell.openExternal(url);
  }
  return true;
});

ipcMain.handle('first-run:get-path', () => ensureFirstRunFile());
'@

$files['app/src/main/manager.js'] = @'
const path = require('path');
const { BrowserWindow, dialog } = require('electron');
const { randomUUID } = require('crypto');
const { randomInt } = require('./utils');

const SITES = {
  chatgpt: { name: 'ChatGPT', url: 'https://chatgpt.com/' },
  claude: { name: 'Claude', url: 'https://claude.ai/' },
  copilot: { name: 'Copilot', url: 'https://copilot.microsoft.com/' },
  gemini: { name: 'Gemini', url: 'https://gemini.google.com/' }
};

class AgentManager {
  constructor({ selectors, selectorsPath, logStore, settingsStore }) {
    this.selectors = selectors;
    this.selectorsPath = selectorsPath;
    this.logStore = logStore;
    this.settingsStore = settingsStore;
    this.roundTable = null;
    this.initAgents();
  }

  initAgents() {
    this.agents = new Map();
    Object.entries(SITES).forEach(([key, site]) => {
      const win = new BrowserWindow({
        width: 1280,
        height: 720,
        show: false,
        title: `${site.name} - Omnichat`,
        webPreferences: {
          preload: path.join(__dirname, '../preload/agent-preload.js'),
          contextIsolation: true,
          nodeIntegration: false,
          additionalArguments: [`--agent-key=${key}`]
        }
      });
      win.loadURL(site.url);
      this.agents.set(key, { key, site, window: win, status: 'idle' });
    });
  }

  dispose() {
    this.agents?.forEach(({ window }) => window.destroy());
    this.agents?.clear();
  }

  updateSelectors(newSelectors) {
    this.selectors = newSelectors;
  }

  getAgentsInfo() {
    return Array.from(this.agents.values()).map(({ key, site, status }) => ({
      key,
      name: site.name,
      status
    }));
  }

  async confirmSend(targets, message) {
    if (!this.settingsStore.get('manualConfirm')) {
      return true;
    }
    const response = dialog.showMessageBoxSync({
      type: 'question',
      buttons: ['Send', 'Cancel'],
      defaultId: 0,
      cancelId: 1,
      title: 'Confirm broadcast',
      message: `Send to ${targets.join(', ')}?`,
      detail: message
    });
    return response === 0;
  }

  async broadcast({ agents, message }) {
    const activeAgents = agents.filter((key) => this.agents.has(key));
    if (!activeAgents.length) return false;
    if (!(await this.confirmSend(activeAgents.map((k) => SITES[k].name), message))) {
      return false;
    }
    for (const agentKey of activeAgents) {
      await this.performSend(agentKey, message);
    }
    return true;
  }

  async sendToSingle({ agent, message }) {
    if (!this.agents.has(agent)) return false;
    if (!(await this.confirmSend([SITES[agent].name], message))) {
      return false;
    }
    await this.performSend(agent, message);
    return true;
  }

  async performSend(agentKey, message) {
    const agent = this.agents.get(agentKey);
    if (!agent) return;

    const delay = this.randomizedDelay();
    agent.status = 'sending';
    this.logStore.append({
      id: randomUUID(),
      type: 'status',
      message: `Scheduled send to ${agent.site.name} in ${delay}ms`
    });
    await new Promise((resolve) => setTimeout(resolve, delay));

    const selectors = this.selectors[agentKey] || {};
    await agent.window.webContents.executeJavaScript(`window.agentBridge ? window.agentBridge.sendMessage(${JSON.stringify({ message, selectors })}) : false`);
    agent.status = 'idle';
    this.logStore.append({
      id: randomUUID(),
      type: 'event',
      message: `Sent message to ${agent.site.name}`
    });
  }

  async startRoundTable({ agents, message, turns }) {
    const activeAgents = agents.filter((key) => this.agents.has(key));
    if (!activeAgents.length) return false;
    const confirm = await this.confirmSend(activeAgents.map((k) => SITES[k].name), `Round-table for ${turns} turns. Initial message: ${message}`);
    if (!confirm) return false;

    this.roundTable = {
      queue: [...activeAgents],
      turnsRemaining: turns,
      paused: false,
      baseMessage: message
    };
    this.logStore.append({ id: randomUUID(), type: 'event', message: 'Round-table session started.' });
    this.advanceRoundTable();
    return true;
  }

  async advanceRoundTable() {
    if (!this.roundTable || this.roundTable.paused || this.roundTable.turnsRemaining <= 0) {
      if (this.roundTable && this.roundTable.turnsRemaining <= 0) {
        this.logStore.append({ id: randomUUID(), type: 'event', message: 'Round-table session completed.' });
        this.roundTable = null;
      }
      return;
    }

    const agentKey = this.roundTable.queue[0];
    this.roundTable.queue.push(this.roundTable.queue.shift());
    this.roundTable.turnsRemaining -= 1;

    const composedMessage = `${this.roundTable.baseMessage}\nTurn remaining: ${this.roundTable.turnsRemaining}`;
    await this.performSend(agentKey, composedMessage);
    const throttle = this.settingsStore.get('throttleMs');
    setTimeout(() => this.advanceRoundTable(), throttle);
  }

  pauseRoundTable() {
    if (!this.roundTable) return false;
    this.roundTable.paused = true;
    this.logStore.append({ id: randomUUID(), type: 'status', message: 'Round-table paused.' });
    return true;
  }

  resumeRoundTable() {
    if (!this.roundTable) return false;
    this.roundTable.paused = false;
    this.logStore.append({ id: randomUUID(), type: 'status', message: 'Round-table resumed.' });
    this.advanceRoundTable();
    return true;
  }

  stopRoundTable() {
    if (!this.roundTable) return false;
    this.roundTable = null;
    this.logStore.append({ id: randomUUID(), type: 'event', message: 'Round-table stopped.' });
    return true;
  }

  randomizedDelay() {
    const { min, max } = this.settingsStore.get('delayRange');
    return randomInt(min, max);
  }

  async invokeLocalModel({ prompt }) {
    const localModel = this.settingsStore.get('localModel');
    if (!localModel.enabled) {
      return { error: 'Local model disabled.' };
    }
    try {
      const response = await fetch(localModel.endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt })
      });
      const data = await response.json();
      return data;
    } catch (err) {
      return { error: err.message };
    }
  }

  async captureSelection({ agent }) {
    const agentData = this.agents.get(agent);
    if (!agentData) return null;
    const result = await agentData.window.webContents.executeJavaScript('window.agentBridge.captureSelection()');
    return result;
  }

  async captureSnapshot({ agent, maxLength = 2000 }) {
    const agentData = this.agents.get(agent);
    if (!agentData) return null;
    const result = await agentData.window.webContents.executeJavaScript(`window.agentBridge.captureSnapshot(${maxLength})`);
    return result;
  }
}

module.exports = { AgentManager, SITES };
'@

$files['app/src/main/settings-store.js'] = @'
const fs = require('fs');
const path = require('path');
const { app } = require('electron');

class SettingsStore {
  constructor({ name = 'settings.json', defaults = {} } = {}) {
    this.name = name;
    this.defaults = defaults;
    this.filePath = path.join(app.getPath('userData'), name);
    this._data = null;
  }

  load() {
    if (this._data) {
      return this._data;
    }
    try {
      const raw = fs.readFileSync(this.filePath, 'utf8');
      this._data = JSON.parse(raw);
    } catch (err) {
      this._data = { ...this.defaults };
      this.save(this._data);
    }
    return this._data;
  }

  get(key) {
    const data = this.load();
    return data[key];
  }

  set(key, value) {
    const data = this.load();
    data[key] = value;
    this.save(data);
  }

  save(newData) {
    this._data = { ...this.defaults, ...newData };
    fs.writeFileSync(this.filePath, JSON.stringify(this._data, null, 2), 'utf8');
  }

  get all() {
    return this.load();
  }

  set all(newData) {
    this.save(newData);
  }
}

module.exports = { SettingsStore };
'@

$files['app/src/main/utils.js'] = @'
function randomInt(min, max) {
  const lower = Math.ceil(min);
  const upper = Math.floor(max);
  return Math.floor(Math.random() * (upper - lower + 1)) + lower;
}

module.exports = { randomInt };
'@

$files['app/src/preload/agent-preload.js'] = @'
const { contextBridge } = require('electron');

const getArgumentValue = (name) => {
  const prefix = `--${name}=`;
  for (const arg of process.argv) {
    if (arg.startsWith(prefix)) {
      return arg.replace(prefix, '');
    }
  }
  return null;
};

contextBridge.exposeInMainWorld('agentBridge', {
  sendMessage: async ({ message, selectors }) => {
    const inputSelector = selectors.input?.find((sel) => document.querySelector(sel));
    const sendButtonSelector = selectors.sendButton?.find((sel) => document.querySelector(sel));

    if (inputSelector) {
      const inputEl = document.querySelector(inputSelector);
      const prop = inputEl.tagName === 'TEXTAREA' || inputEl.tagName === 'INPUT' ? 'value' : 'textContent';
      inputEl.focus();
      inputEl[prop] = message;
      inputEl.dispatchEvent(new Event('input', { bubbles: true }));
    }

    if (sendButtonSelector) {
      const btn = document.querySelector(sendButtonSelector);
      btn?.click();
    } else if (inputSelector) {
      const inputEl = document.querySelector(inputSelector);
      inputEl?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
      inputEl?.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', bubbles: true }));
    }

    return true;
  },
  captureSelection: () => {
    const selection = window.getSelection();
    return {
      agent: getArgumentValue('agent-key'),
      selection: selection ? selection.toString() : ''
    };
  },
  captureSnapshot: (maxLength = 2000) => {
    const title = document.title;
    const url = window.location.href;
    const containerSelector = ['main', 'article', 'body'];
    const container = containerSelector
      .map((sel) => document.querySelector(sel))
      .find(Boolean);
    const text = container ? container.innerText.slice(0, maxLength) : '';
    return { agent: getArgumentValue('agent-key'), title, url, text };
  }
});
'@

$files['app/src/preload/index.js'] = @'
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('omniSwitch', {
  getSelectors: () => ipcRenderer.invoke('selectors:get'),
  saveSelectors: (payload) => ipcRenderer.invoke('selectors:save', payload),
  getSettings: () => ipcRenderer.invoke('settings:get'),
  saveSettings: (payload) => ipcRenderer.invoke('settings:save', payload),
  listAgents: () => ipcRenderer.invoke('agents:list'),
  broadcast: (payload) => ipcRenderer.invoke('agents:broadcast', payload),
  sendToAgent: (payload) => ipcRenderer.invoke('agents:send-single', payload),
  startRoundTable: (payload) => ipcRenderer.invoke('agents:start-round-table', payload),
  pauseRoundTable: () => ipcRenderer.invoke('agents:pause-round-table'),
  resumeRoundTable: () => ipcRenderer.invoke('agents:resume-round-table'),
  stopRoundTable: () => ipcRenderer.invoke('agents:stop-round-table'),
  invokeLocalModel: (payload) => ipcRenderer.invoke('agents:local-model', payload),
  captureSelection: (payload) => ipcRenderer.invoke('agents:selection', payload),
  captureSnapshot: (payload) => ipcRenderer.invoke('agents:snapshot', payload),
  getLog: () => ipcRenderer.invoke('log:get'),
  exportLog: (targetPath) => ipcRenderer.invoke('log:export', targetPath),
  getFirstRunPath: () => ipcRenderer.invoke('first-run:get-path')
});

contextBridge.exposeInMainWorld('dialogAPI', {
  openExternal: (url) => ipcRenderer.invoke('open-external', url)
});
'@

$files['app/src/renderer/index.html'] = @'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Omnichat</title>
    <link rel="stylesheet" href="styles.css" />
  </head>
  <body>
    <div id="app">
      <aside class="sidebar">
        <h1>Agents</h1>
        <div id="agent-list" class="agent-list"></div>
        <div class="sidebar-actions">
          <button id="refresh-agents">Refresh</button>
          <button id="open-settings">Settings</button>
          <button id="open-first-run">First Run Guide</button>
        </div>
      </aside>
      <main class="main">
        <section class="composer">
          <textarea id="composer-input" placeholder="Compose your broadcast..." rows="6"></textarea>
          <div class="composer-actions">
            <button id="broadcast-btn">Broadcast</button>
            <button id="send-selected-btn" disabled>Send to Selected</button>
            <button id="round-table-btn">Start Round-table</button>
            <button id="pause-round-table-btn" disabled>Pause</button>
            <button id="resume-round-table-btn" disabled>Resume</button>
            <button id="stop-round-table-btn" disabled>Stop</button>
          </div>
          <div class="toolbox">
            <button id="quote-selection-btn">Quote selection → composer</button>
            <button id="snapshot-btn">Page snapshot → composer</button>
            <button id="quick-snippet-btn">Quick attach snippet</button>
            <button id="local-model-btn">Run local model</button>
          </div>
          <div class="tool-output" id="tool-output"></div>
        </section>
      </main>
      <aside class="log-panel">
        <h2>Live Log</h2>
        <div id="log-entries" class="log-entries"></div>
        <button id="export-log-btn">Export .txt</button>
      </aside>
    </div>

    <div id="settings-modal" class="modal hidden">
      <div class="modal-content">
        <header>
          <h2>Settings</h2>
          <button id="close-settings">×</button>
        </header>
        <section class="modal-body">
          <form id="settings-form">
            <label>
              Manual confirm before send
              <input type="checkbox" name="manualConfirm" />
            </label>
            <label>
              Delay range (ms)
              <div class="inline">
                <input type="number" name="delayMin" min="0" />
                <span>to</span>
                <input type="number" name="delayMax" min="0" />
              </div>
            </label>
            <label>
              Throttle interval (ms)
              <input type="number" name="throttleMs" min="0" />
            </label>
            <label>
              Messages to read (N)
              <input type="number" name="messagesToRead" min="1" />
            </label>
            <label>
              Round-table turns (K)
              <input type="number" name="roundTableTurns" min="1" />
            </label>
            <label>
              Copilot host
              <input type="text" name="copilotHost" />
            </label>
            <fieldset>
              <legend>Local model</legend>
              <label>
                Enable
                <input type="checkbox" name="localModelEnabled" />
              </label>
              <label>
                Endpoint
                <input type="text" name="localModelEndpoint" />
              </label>
            </fieldset>
            <fieldset>
              <legend>Selectors JSON</legend>
              <textarea id="selectors-json" rows="10"></textarea>
            </fieldset>
            <div class="modal-actions">
              <button type="submit">Save</button>
            </div>
          </form>
        </section>
      </div>
    </div>

    <script src="renderer.js" type="module"></script>
  </body>
</html>
'@

$files['app/src/renderer/renderer.js'] = @'
const agentListEl = document.getElementById('agent-list');
const refreshAgentsBtn = document.getElementById('refresh-agents');
const openSettingsBtn = document.getElementById('open-settings');
const firstRunBtn = document.getElementById('open-first-run');
const settingsModal = document.getElementById('settings-modal');
const closeSettingsBtn = document.getElementById('close-settings');
const settingsForm = document.getElementById('settings-form');
const selectorsTextArea = document.getElementById('selectors-json');
const composerInput = document.getElementById('composer-input');
const broadcastBtn = document.getElementById('broadcast-btn');
const sendSelectedBtn = document.getElementById('send-selected-btn');
const roundTableBtn = document.getElementById('round-table-btn');
const pauseRoundTableBtn = document.getElementById('pause-round-table-btn');
const resumeRoundTableBtn = document.getElementById('resume-round-table-btn');
const stopRoundTableBtn = document.getElementById('stop-round-table-btn');
const logEntriesEl = document.getElementById('log-entries');
const exportLogBtn = document.getElementById('export-log-btn');
const quoteSelectionBtn = document.getElementById('quote-selection-btn');
const snapshotBtn = document.getElementById('snapshot-btn');
const quickSnippetBtn = document.getElementById('quick-snippet-btn');
const localModelBtn = document.getElementById('local-model-btn');
const toolOutputEl = document.getElementById('tool-output');

let agentCache = [];
let selectedAgents = new Set();
let currentSettings = null;

async function loadAgents() {
  agentCache = await window.omniSwitch.listAgents();
  agentListEl.innerHTML = '';
  agentCache.forEach((agent) => {
    const item = document.createElement('label');
    item.className = 'agent-item';
    item.innerHTML = `
      <div>
        <input type="checkbox" data-agent="${agent.key}" ${selectedAgents.has(agent.key) ? 'checked' : ''} />
        <span>${agent.name}</span>
      </div>
      <span class="agent-status">${agent.status}</span>
    `;
    item.querySelector('input').addEventListener('change', (event) => {
      const key = event.target.dataset.agent;
      if (event.target.checked) {
        selectedAgents.add(key);
      } else {
        selectedAgents.delete(key);
      }
      updateActionStates();
    });
    agentListEl.appendChild(item);
  });
  updateActionStates();
}

function updateActionStates() {
  const hasSelection = selectedAgents.size > 0;
  sendSelectedBtn.disabled = !hasSelection;
  roundTableBtn.disabled = !hasSelection;
}

function openSettings() {
  settingsModal.classList.remove('hidden');
}

function closeSettings() {
  settingsModal.classList.add('hidden');
}

async function loadSettings() {
  currentSettings = await window.omniSwitch.getSettings();
  settingsForm.manualConfirm.checked = currentSettings.manualConfirm;
  settingsForm.delayMin.value = currentSettings.delayRange.min;
  settingsForm.delayMax.value = currentSettings.delayRange.max;
  settingsForm.throttleMs.value = currentSettings.throttleMs;
  settingsForm.messagesToRead.value = currentSettings.messagesToRead;
  settingsForm.roundTableTurns.value = currentSettings.roundTableTurns;
  settingsForm.copilotHost.value = currentSettings.copilotHost;
  settingsForm.localModelEnabled.checked = currentSettings.localModel.enabled;
  settingsForm.localModelEndpoint.value = currentSettings.localModel.endpoint;

  const selectors = await window.omniSwitch.getSelectors();
  selectorsTextArea.value = JSON.stringify(selectors, null, 2);
}

settingsForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const manualConfirm = settingsForm.manualConfirm.checked;
  const delayMin = Number(settingsForm.delayMin.value);
  const delayMax = Number(settingsForm.delayMax.value);
  const throttleMs = Number(settingsForm.throttleMs.value);
  const messagesToRead = Number(settingsForm.messagesToRead.value);
  const roundTableTurns = Number(settingsForm.roundTableTurns.value);
  const copilotHost = settingsForm.copilotHost.value;
  const localModelEnabled = settingsForm.localModelEnabled.checked;
  const localModelEndpoint = settingsForm.localModelEndpoint.value;

  let selectors;
  try {
    selectors = JSON.parse(selectorsTextArea.value);
  } catch (err) {
    alert('Invalid selectors JSON');
    return;
  }

  await window.omniSwitch.saveSettings({
    manualConfirm,
    delayRange: { min: delayMin, max: delayMax },
    throttleMs,
    messagesToRead,
    roundTableTurns,
    copilotHost,
    localModel: {
      enabled: localModelEnabled,
      endpoint: localModelEndpoint
    }
  });
  await window.omniSwitch.saveSelectors(selectors);
  await loadSettings();
  closeSettings();
});

async function broadcast() {
  const message = composerInput.value.trim();
  if (!message) return;
  await window.omniSwitch.broadcast({ agents: Array.from(selectedAgents), message });
  await refreshLog();
}

async function sendSelected() {
  const message = composerInput.value.trim();
  if (!message) return;
  for (const agent of selectedAgents) {
    await window.omniSwitch.sendToAgent({ agent, message });
  }
  await refreshLog();
}

async function startRoundTable() {
  const message = composerInput.value.trim();
  if (!message) return;
  const turns = Number(currentSettings.roundTableTurns || 2);
  await window.omniSwitch.startRoundTable({ agents: Array.from(selectedAgents), message, turns });
  pauseRoundTableBtn.disabled = false;
  resumeRoundTableBtn.disabled = false;
  stopRoundTableBtn.disabled = false;
  await refreshLog();
}

async function pauseRoundTable() {
  await window.omniSwitch.pauseRoundTable();
  await refreshLog();
}

async function resumeRoundTable() {
  await window.omniSwitch.resumeRoundTable();
  await refreshLog();
}

async function stopRoundTable() {
  await window.omniSwitch.stopRoundTable();
  pauseRoundTableBtn.disabled = true;
  resumeRoundTableBtn.disabled = true;
  stopRoundTableBtn.disabled = true;
  await refreshLog();
}

async function refreshLog() {
  const entries = await window.omniSwitch.getLog();
  logEntriesEl.innerHTML = '';
  entries.forEach((entry) => {
    const el = document.createElement('div');
    el.className = 'log-entry';
    el.innerHTML = `
      <div class="timestamp">${new Date(entry.timestamp).toLocaleString()}</div>
      <div>${entry.message}</div>
    `;
    logEntriesEl.appendChild(el);
  });
  logEntriesEl.scrollTop = logEntriesEl.scrollHeight;
}

async function exportLog() {
  await window.omniSwitch.exportLog();
}

async function quoteSelection() {
  if (!selectedAgents.size) {
    alert('Select an agent to capture selection.');
    return;
  }
  const agent = Array.from(selectedAgents)[0];
  const result = await window.omniSwitch.captureSelection({ agent });
  if (!result || !result.selection) {
    toolOutputEl.textContent = 'No selection found.';
    return;
  }
  const composed = `> ${result.selection.replace(/\n/g, '\n> ')}\n\n`;
  composerInput.value += `\n${composed}`;
  toolOutputEl.textContent = `Quoted from ${agent}:\n${result.selection}`;
}

async function snapshotPage() {
  if (!selectedAgents.size) {
    alert('Select an agent to snapshot.');
    return;
  }
  const agent = Array.from(selectedAgents)[0];
  const result = await window.omniSwitch.captureSnapshot({ agent, maxLength: 2000 });
  if (!result) {
    toolOutputEl.textContent = 'Unable to capture snapshot.';
    return;
  }
  const snippet = `# ${result.title}\n${result.url}\n\n${result.text}\n\n`;
  composerInput.value += `\n${snippet}`;
  toolOutputEl.textContent = `Snapshot from ${result.title}`;
}

function quickSnippet() {
  const base = composerInput.value.trim();
  if (!base) {
    toolOutputEl.textContent = 'Nothing to split.';
    return;
  }
  const parts = [];
  const maxLen = 2000;
  for (let i = 0; i < base.length; i += maxLen) {
    parts.push(base.slice(i, i + maxLen));
  }
  toolOutputEl.textContent = `Prepared ${parts.length} snippet(s). Ready to send sequentially.`;
}

async function runLocalModel() {
  const prompt = composerInput.value.trim();
  if (!prompt) {
    toolOutputEl.textContent = 'Enter prompt for local model.';
    return;
  }
  const response = await window.omniSwitch.invokeLocalModel({ prompt });
  if (response?.error) {
    toolOutputEl.textContent = `Local model error: ${response.error}`;
    return;
  }
  if (response?.output) {
    toolOutputEl.textContent = `Local model output:\n${response.output}`;
  } else {
    toolOutputEl.textContent = JSON.stringify(response, null, 2);
  }
}

refreshAgentsBtn.addEventListener('click', loadAgents);
openSettingsBtn.addEventListener('click', () => {
  loadSettings();
  openSettings();
});
firstRunBtn.addEventListener('click', async () => {
  const path = await window.omniSwitch.getFirstRunPath();
  toolOutputEl.textContent = `FIRST_RUN file located at: ${path}`;
});
closeSettingsBtn.addEventListener('click', closeSettings);
broadcastBtn.addEventListener('click', broadcast);
sendSelectedBtn.addEventListener('click', sendSelected);
roundTableBtn.addEventListener('click', startRoundTable);
pauseRoundTableBtn.addEventListener('click', pauseRoundTable);
resumeRoundTableBtn.addEventListener('click', resumeRoundTable);
stopRoundTableBtn.addEventListener('click', stopRoundTable);
exportLogBtn.addEventListener('click', exportLog);
quoteSelectionBtn.addEventListener('click', quoteSelection);
snapshotBtn.addEventListener('click', snapshotPage);
quickSnippetBtn.addEventListener('click', quickSnippet);
localModelBtn.addEventListener('click', runLocalModel);

loadAgents();
loadSettings();
refreshLog();
setInterval(refreshLog, 4000);
'@

$files['app/src/renderer/styles.css'] = @'
:root {
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  background-color: #1e1f26;
  color: #f8f9ff;
}

body, html {
  margin: 0;
  padding: 0;
  height: 100%;
}

#app {
  display: flex;
  height: 100vh;
}

.sidebar {
  width: 280px;
  background-color: #15161c;
  border-right: 1px solid #2b2d3a;
  padding: 16px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
}

.sidebar h1 {
  margin: 0 0 12px 0;
  font-size: 22px;
}

.agent-list {
  flex: 1;
  overflow-y: auto;
}

.agent-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px;
  margin-bottom: 8px;
  border-radius: 8px;
  background-color: #1f2029;
  cursor: pointer;
}

.agent-item input[type='checkbox'] {
  margin-right: 8px;
}

.agent-status {
  font-size: 12px;
  color: #9aa0b8;
}

.sidebar-actions {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.main {
  flex: 1;
  padding: 16px;
  background-color: #1e1f26;
}

.composer textarea {
  width: 100%;
  border-radius: 8px;
  border: 1px solid #34364b;
  background-color: #111218;
  color: #f8f9ff;
  padding: 12px;
  resize: vertical;
}

.composer-actions {
  margin-top: 12px;
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.toolbox {
  margin-top: 12px;
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

button {
  border: none;
  border-radius: 6px;
  padding: 8px 16px;
  background-color: #3f46ff;
  color: #fff;
  cursor: pointer;
  font-weight: 600;
}

button:disabled {
  background-color: #2a2d44;
  cursor: not-allowed;
}

.log-panel {
  width: 320px;
  background-color: #15161c;
  border-left: 1px solid #2b2d3a;
  padding: 16px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
}

.log-panel h2 {
  margin-top: 0;
}

.log-entries {
  flex: 1;
  overflow-y: auto;
  background-color: #1f2029;
  padding: 12px;
  border-radius: 8px;
  font-size: 13px;
  line-height: 1.4;
}

.log-entry {
  margin-bottom: 8px;
}

.log-entry .timestamp {
  color: #9aa0b8;
  font-size: 11px;
}

.modal {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.5);
}

.modal.hidden {
  display: none;
}

.modal-content {
  width: 720px;
  max-height: 90vh;
  overflow-y: auto;
  background-color: #111218;
  border-radius: 12px;
  padding: 24px;
}

.modal-content header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.modal-content textarea,
.modal-content input[type='text'],
.modal-content input[type='number'] {
  width: 100%;
  box-sizing: border-box;
  border-radius: 6px;
  border: 1px solid #34364b;
  background-color: #1e1f26;
  color: #f8f9ff;
  padding: 8px;
}

.modal-content fieldset {
  border: 1px solid #34364b;
  border-radius: 8px;
  margin-bottom: 16px;
  padding: 12px;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
}

.inline {
  display: flex;
  gap: 8px;
  align-items: center;
}

.tool-output {
  margin-top: 16px;
  background-color: #111218;
  border-radius: 8px;
  padding: 12px;
  min-height: 60px;
  border: 1px dashed #34364b;
  font-size: 13px;
  color: #c7cbe2;
  white-space: pre-wrap;
}
'@

foreach ($item in $files.GetEnumerator()) {
    $relativePath = $item.Key
    if ($relativePath.StartsWith('app/')) {
        $relativePath = $relativePath.Substring(4)
    }
    $relativePath = $relativePath -replace '/', [IO.Path]::DirectorySeparatorChar
    $targetPath = Join-Path $appRoot $relativePath
    Write-Utf8File -path $targetPath -content $item.Value
}

Create-Shortcut -shortcutPath $desktopShortcut -targetPath $omnichatExe -workingDirectory $installRoot

Start-Process -FilePath $omnichatExe | Out-Null

Show-Message 'Omnichat is ready to use.'
}
catch {
    $message = 'Omnichat setup failed: ' + $_.Exception.Message
    Show-Message $message
    throw
}

