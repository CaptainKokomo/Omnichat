const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');

const INSTALL_ROOT = path.join(process.env.LOCALAPPDATA || app.getPath('userData'), 'OmniChat');
const CONFIG_ROOT = path.join(INSTALL_ROOT, 'config');
const LOG_ROOT = path.join(INSTALL_ROOT, 'logs');
const SELECTOR_PATH = path.join(CONFIG_ROOT, 'selectors.json');
const SETTINGS_PATH = path.join(CONFIG_ROOT, 'settings.json');
const FIRST_RUN_PATH = path.join(INSTALL_ROOT, 'FIRST_RUN.txt');

let mainWindow;
let selectors = {};
let settings = {};
const agentWindows = new Map();
const agentState = new Map();
const logBuffer = [];

const DEFAULT_SETTINGS = {
  confirmBeforeSend: true,
  delayMin: 1200,
  delayMax: 2500,
  messageLimit: 5,
  roundTableTurns: 2,
  copilotHost: 'https://copilot.microsoft.com/'
};

const DEFAULT_SELECTORS = {
  chatgpt: {
    displayName: 'ChatGPT',
    patterns: ['https://chatgpt.com/*'],
    home: 'https://chatgpt.com/',
    input: ['textarea', "textarea[data-testid='chat-input']", "div[contenteditable='true']"],
    sendButton: ["button[data-testid='send-button']", "button[aria-label='Send']"],
    messageContainer: ['main', "div[class*='conversation']"]
  },
  claude: {
    displayName: 'Claude',
    patterns: ['https://claude.ai/*'],
    home: 'https://claude.ai/',
    input: ['textarea', "textarea[placeholder*='Message']", "div[contenteditable='true']"],
    sendButton: ["button[type='submit']", "button[aria-label='Send']"],
    messageContainer: ['main', "div[class*='conversation']"]
  },
  copilot: {
    displayName: 'Copilot',
    patterns: ['https://copilot.microsoft.com/*', 'https://www.bing.com/chat*'],
    home: 'https://copilot.microsoft.com/',
    input: ['textarea#userInput', 'textarea', "div[contenteditable='true']", "textarea[placeholder*='Ask me']"],
    sendButton: ["button[aria-label='Send']", "button[data-testid='send-button']"],
    messageContainer: ['main', "div[class*='conversation']"]
  },
  gemini: {
    displayName: 'Gemini',
    patterns: ['https://gemini.google.com/*'],
    home: 'https://gemini.google.com/',
    input: ['textarea', "div[contenteditable='true']", "textarea[aria-label*='Message']"],
    sendButton: ["button[aria-label='Send']", "button[type='submit']"],
    messageContainer: ['main', "div[class*='conversation']"]
  }
};

function ensureDirectories() {
  [INSTALL_ROOT, CONFIG_ROOT, LOG_ROOT].forEach((dir) => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });
}

function ensureFirstRunGuide() {
  if (!fs.existsSync(FIRST_RUN_PATH)) {
    const guide = [
      '1. Install OmniChat using OmniChat_install.bat.',
      '2. Open OmniChat from the desktop shortcut.',
      '3. Sign in to ChatGPT, Claude, Copilot, and Gemini.',
      '4. Use Broadcast to send a message to your selected assistants.',
      '5. Run a Round-table with your chosen turn count.'
    ].join('\n');
    fs.writeFileSync(FIRST_RUN_PATH, guide, 'utf8');
  }
}

function loadSelectors() {
  try {
    if (!fs.existsSync(SELECTOR_PATH)) {
      fs.writeFileSync(SELECTOR_PATH, JSON.stringify(DEFAULT_SELECTORS, null, 2), 'utf8');
    }
    const raw = fs.readFileSync(SELECTOR_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    return parsed;
  } catch (error) {
    console.error('Failed to load selectors', error);
    return JSON.parse(JSON.stringify(DEFAULT_SELECTORS));
  }
}

function loadSettings() {
  try {
    if (!fs.existsSync(SETTINGS_PATH)) {
      fs.writeFileSync(SETTINGS_PATH, JSON.stringify(DEFAULT_SETTINGS, null, 2), 'utf8');
      return { ...DEFAULT_SETTINGS };
    }
    const raw = fs.readFileSync(SETTINGS_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    return { ...DEFAULT_SETTINGS, ...parsed };
  } catch (error) {
    console.error('Failed to load settings', error);
    return { ...DEFAULT_SETTINGS };
  }
}

function saveSelectors(data) {
  selectors = data;
  fs.writeFileSync(SELECTOR_PATH, JSON.stringify(selectors, null, 2), 'utf8');
  broadcastStatus();
}

function saveSettings(data) {
  settings = { ...settings, ...data };
  fs.writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2), 'utf8');
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    title: 'OmniChat',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, 'index.html'));

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function getAgentConfig(key) {
  const data = selectors[key];
  if (!data) {
    throw new Error(`Unknown agent ${key}`);
  }
  return data;
}

async function ensureAgentWindow(key) {
  if (agentWindows.has(key)) {
    return agentWindows.get(key);
  }
  const config = getAgentConfig(key);
  const agentWin = new BrowserWindow({
    width: 1280,
    height: 800,
    show: false,
    title: `OmniChat – ${config.displayName}`,
    webPreferences: {
      preload: path.join(__dirname, 'agentPreload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      partition: `persist:omnichat-${key}`
    }
  });

  agentWin.on('close', (event) => {
    event.preventDefault();
    agentWin.hide();
  });

  agentWin.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  agentWin.webContents.on('did-finish-load', () => {
    updateAgentState(key, { status: 'ready', url: agentWin.webContents.getURL() });
  });

  agentWin.on('focus', () => updateAgentState(key, { visible: true }));
  agentWin.on('hide', () => updateAgentState(key, { visible: false }));

  agentWindows.set(key, agentWin);
  updateAgentState(key, { status: 'loading' });
  await agentWin.loadURL(config.home);
  return agentWin;
}

function updateAgentState(key, patch) {
  const existing = agentState.get(key) || {};
  const next = { ...existing, ...patch, key };
  agentState.set(key, next);
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('agent:status', next);
  }
}

function broadcastStatus() {
  if (mainWindow && !mainWindow.isDestroyed()) {
    const payload = Object.keys(selectors).map((key) => ({
      key,
      ...(agentState.get(key) || {}),
      displayName: selectors[key].displayName || key
    }));
    mainWindow.webContents.send('agent:status:init', payload);
  }
}

async function withAgentDOM(key, task) {
  const config = getAgentConfig(key);
  const agentWin = await ensureAgentWindow(key);
  return agentWin.webContents.executeJavaScript(`(function(){
    const cfg = ${JSON.stringify({
      input: config.input,
      sendButton: config.sendButton,
      messageContainer: config.messageContainer
    })};
    const findFirst = (selectors) => {
      if (!selectors) return null;
      for (const selector of selectors) {
        const el = document.querySelector(selector);
        if (el) return el;
      }
      return null;
    };
    return (${task.toString()})(cfg, ${settings.messageLimit});
  })();`, true);
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function recordLog(entry) {
  const timestamp = new Date().toISOString();
  const row = `[${timestamp}] ${entry}`;
  logBuffer.push(row);
  if (logBuffer.length > 5000) {
    logBuffer.shift();
  }
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('log:push', row);
  }
  const logFile = path.join(LOG_ROOT, `${new Date().toISOString().slice(0, 10)}.log`);
  fs.appendFile(logFile, row + '\n', () => {});
}

async function sendToAgent(key, text) {
  const min = Number(settings.delayMin) || 0;
  const max = Number(settings.delayMax) || min;
  const wait = Math.max(min, Math.floor(min + Math.random() * Math.max(0, max - min)));
  await delay(wait);
  try {
    const result = await withAgentDOM(key, function (cfg) {
      const findFirst = (selectors) => {
        if (!selectors) return null;
        for (const selector of selectors) {
          const el = document.querySelector(selector);
          if (el) return el;
        }
        return null;
      };
      const input = findFirst(cfg.input);
      if (!input) {
        return { ok: false, reason: 'input' };
      }
      const valueProp = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(input), 'value');
      if (valueProp && valueProp.set) {
        valueProp.set.call(input, text);
      } else {
        input.value = text;
      }
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.focus();
      const button = findFirst(cfg.sendButton);
      if (button) {
        button.click();
        return { ok: true, via: 'button' };
      }
      const event = new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', bubbles: true });
      input.dispatchEvent(event);
      return { ok: true, via: 'enter' };
    });
    if (!result || !result.ok) {
      await withAgentDOM(key, function (cfg) {
        const findFirst = (selectors) => {
          if (!selectors) return null;
          for (const selector of selectors) {
            const el = document.querySelector(selector);
            if (el) return el;
          }
          return null;
        };
        const input = findFirst(cfg.input);
        if (input) {
          input.focus();
        }
        let banner = document.getElementById('__omnichat_hint');
        if (!banner) {
          banner = document.createElement('div');
          banner.id = '__omnichat_hint';
          banner.style.position = 'fixed';
          banner.style.bottom = '16px';
          banner.style.right = '16px';
          banner.style.padding = '12px 18px';
          banner.style.background = '#1f2937';
          banner.style.color = '#ffffff';
          banner.style.fontFamily = 'Segoe UI, sans-serif';
          banner.style.borderRadius = '6px';
          banner.style.zIndex = '999999';
          document.body.appendChild(banner);
        }
        banner.textContent = 'Press Enter to send from OmniChat.';
        setTimeout(() => banner && banner.remove(), 4000);
        return { ok: false };
      });
      throw new Error(result ? result.reason : 'send');
    }
    recordLog(`${key}: message sent via ${result.via}`);
    return result;
  } catch (error) {
    recordLog(`${key}: send failed (${error.message})`);
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('app:toast', `${key}.${error.message || 'send'} selectors need attention.`);
    }
    throw error;
  }
}

async function readMessages(key) {
  try {
    const messages = await withAgentDOM(key, function (cfg, limit) {
      const findFirst = (selectors) => {
        if (!selectors) return null;
        for (const selector of selectors) {
          const el = document.querySelector(selector);
          if (el) return el;
        }
        return null;
      };
      const container = findFirst(cfg.messageContainer);
      if (!container) {
        return { ok: false, reason: 'messageContainer' };
      }
      const walker = document.createTreeWalker(container, NodeFilter.SHOW_ELEMENT, null);
      const transcript = [];
      while (walker.nextNode()) {
        const node = walker.currentNode;
        if (node.childElementCount === 0) {
          const text = node.textContent.trim();
          if (text) {
            transcript.push(text);
          }
        }
      }
      const deduped = [];
      for (const line of transcript) {
        if (!deduped.length || deduped[deduped.length - 1] !== line) {
          deduped.push(line);
        }
      }
      return { ok: true, messages: deduped.slice(-limit) };
    });
    if (!messages.ok) {
      throw new Error(messages.reason);
    }
    return messages.messages;
  } catch (error) {
    recordLog(`${key}: read failed (${error.message})`);
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.webContents.send('app:toast', `${key}.${error.message || 'read'} selectors need attention.`);
    }
    return [];
  }
}

ipcMain.handle('app:bootstrap', async () => {
  ensureDirectories();
  ensureFirstRunGuide();
  selectors = loadSelectors();
  settings = loadSettings();
  broadcastStatus();
  return {
    selectors,
    settings,
    log: logBuffer.slice(-200)
  };
});

ipcMain.handle('selectors:save', async (_event, payload) => {
  saveSelectors(payload);
  return { ok: true };
});

ipcMain.handle('settings:save', async (_event, payload) => {
  saveSettings(payload);
  return { ok: true };
});

ipcMain.handle('agent:ensure', async (_event, key) => {
  await ensureAgentWindow(key);
  return agentState.get(key) || { key };
});

ipcMain.handle('agent:connect', async (_event, key) => {
  const win = await ensureAgentWindow(key);
  win.show();
  win.focus();
  updateAgentState(key, { visible: true });
  return true;
});

ipcMain.handle('agent:hide', async (_event, key) => {
  if (agentWindows.has(key)) {
    const win = agentWindows.get(key);
    win.hide();
    updateAgentState(key, { visible: false });
  }
  return true;
});

ipcMain.handle('agent:read', async (_event, key) => {
  return await readMessages(key);
});

ipcMain.handle('agent:send', async (_event, payload) => {
  const { key, text } = payload;
  await ensureAgentWindow(key);
  const messages = await readMessages(key);
  await sendToAgent(key, text);
  return { ok: true, previous: messages };
});

ipcMain.handle('agent:captureSelection', async (_event, key) => {
  try {
    const result = await withAgentDOM(key, function () {
      const selection = window.getSelection();
      const text = selection ? selection.toString().trim() : '';
      return {
        ok: true,
        selection: text,
        title: document.title,
        url: location.href
      };
    });
    return result;
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('agent:snapshot', async (_event, { key, limit = 2000 }) => {
  try {
    const result = await withAgentDOM(key, function (_cfg, _limit) {
      const max = Number(_limit) || 2000;
      const text = document.body ? document.body.innerText || '' : '';
      return {
        ok: true,
        title: document.title,
        url: location.href,
        content: text.slice(0, max)
      };
    });
    return result;
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('log:export', async (_event, payload) => {
  if (!mainWindow || mainWindow.isDestroyed()) {
    return { ok: false };
  }
  const dialogResult = await dialog.showSaveDialog(mainWindow, {
    title: 'Export OmniChat Log',
    filters: [{ name: 'Text Files', extensions: ['txt'] }],
    defaultPath: path.join(app.getPath('documents'), `omnichat-log-${Date.now()}.txt`)
  });
  if (dialogResult.canceled || !dialogResult.filePath) {
    return { ok: false };
  }
  fs.writeFileSync(dialogResult.filePath, payload, 'utf8');
  return { ok: true, path: dialogResult.filePath };
});

ipcMain.handle('settings:resetAgent', async (_event, key) => {
  if (!DEFAULT_SELECTORS[key]) {
    return { ok: false, error: 'unknown' };
  }
  selectors[key] = JSON.parse(JSON.stringify(DEFAULT_SELECTORS[key]));
  saveSelectors(selectors);
  return { ok: true, selectors };
});

app.whenReady().then(() => {
  ensureDirectories();
  ensureFirstRunGuide();
  selectors = loadSelectors();
  settings = loadSettings();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
