const path = require('path');
const fs = require('fs');
const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const { SettingsStore } = require('./settings-store');
const { AgentManager } = require('./manager');
const { LogStore } = require('./log-store');

const APP_NAME = 'Omnichat';
const SELECTOR_FILE = 'selectors.json';
const SITES_FILE = 'sites.json';
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

function ensureSitesFile() {
  const target = path.join(app.getPath('userData'), SITES_FILE);
  if (!fs.existsSync(target)) {
    const source = resolveResource(SITES_FILE);
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
  const sitesPath = ensureSitesFile();
  const sites = JSON.parse(fs.readFileSync(sitesPath, 'utf8'));
  agentManager = new AgentManager({
    selectors,
    selectorsPath,
    sites,
    logStore,
    settingsStore: store
  });
}

app.on('ready', () => {
  ensureSelectorsFile();
  ensureSitesFile();
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

ipcMain.handle('sites:get', async () => {
  const sitesPath = ensureSitesFile();
  const content = fs.readFileSync(sitesPath, 'utf8');
  return JSON.parse(content);
});

ipcMain.handle('sites:save', async (_, payload) => {
  const sitesPath = ensureSitesFile();
  fs.writeFileSync(sitesPath, JSON.stringify(payload, null, 2), 'utf8');
  agentManager?.updateSites(payload);
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
