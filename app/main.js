const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');

const APP_NAME = 'OmniChat';
const INSTALL_ROOT = path.join(process.env.LOCALAPPDATA || app.getPath('userData'), APP_NAME);
const CONFIG_ROOT = path.join(INSTALL_ROOT, 'config');
const LOG_ROOT = path.join(INSTALL_ROOT, 'logs');
const SELECTOR_PATH = path.join(CONFIG_ROOT, 'selectors.json');
const SETTINGS_PATH = path.join(CONFIG_ROOT, 'settings.json');
const FIRST_RUN_PATH = path.join(INSTALL_ROOT, 'FIRST_RUN.txt');

const DEFAULT_SETTINGS = {
  confirmBeforeSend: true,
  delayMin: 1200,
  delayMax: 2500,
  messageLimit: 5,
  roundTableTurns: 2,
  copilotHost: 'https://copilot.microsoft.com/',
  comfyHost: 'http://127.0.0.1:8188',
  comfyAutoImport: true,
  ollamaHost: 'http://127.0.0.1:11434',
  ollamaModel: ''
};

const LOCAL_AGENT_KEY = 'local-ollama';
const LOCAL_AGENT_MANIFEST = {
  key: LOCAL_AGENT_KEY,
  displayName: 'Local (Ollama)',
  type: 'local'
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

const DOM_TASKS = {
  sendMessage(cfg, context = {}) {
    const { text = '' } = context;
    const findFirst = (selectors) => {
      if (!selectors) return null;
      for (const selector of selectors) {
        try {
          const el = document.querySelector(selector);
          if (el) return el;
        } catch (error) {
          // ignore selector errors
        }
      }
      return null;
    };

    const input = findFirst(cfg.input);
    if (!input) {
      return { ok: false, reason: 'input' };
    }

    const setValue = (element, value) => {
      const proto = Object.getPrototypeOf(element);
      const descriptor = Object.getOwnPropertyDescriptor(proto, 'value');
      if (descriptor && typeof descriptor.set === 'function') {
        descriptor.set.call(element, value);
      } else {
        element.value = value;
      }
    };

    setValue(input, text);
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.focus();

    const button = findFirst(cfg.sendButton);
    if (button) {
      button.click();
      return { ok: true, via: 'button' };
    }

    const keyboardEvent = new KeyboardEvent('keydown', {
      key: 'Enter',
      code: 'Enter',
      bubbles: true,
      cancelable: true
    });
    input.dispatchEvent(keyboardEvent);

    if (keyboardEvent.defaultPrevented) {
      const enterEvent = new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', bubbles: true });
      input.dispatchEvent(enterEvent);
    }

    const bannerId = '__omnichat_hint';
    let banner = document.getElementById(bannerId);
    if (!banner) {
      banner = document.createElement('div');
      banner.id = bannerId;
      banner.style.position = 'fixed';
      banner.style.bottom = '16px';
      banner.style.right = '16px';
      banner.style.padding = '12px 18px';
      banner.style.background = '#1f2937';
      banner.style.color = '#ffffff';
      banner.style.fontFamily = 'Segoe UI, sans-serif';
      banner.style.borderRadius = '6px';
      banner.style.boxShadow = '0 12px 32px rgba(15, 23, 42, 0.35)';
      banner.style.zIndex = '2147483647';
      document.body.appendChild(banner);
    }
    banner.textContent = 'Press Enter in the site tab if the message did not send.';
    setTimeout(() => {
      if (banner && banner.parentElement) {
        banner.remove();
      }
    }, 4500);

    return { ok: true, via: 'enter' };
  },

  readMessages(cfg, context = {}) {
    const { limit = 5 } = context;
    const findFirst = (selectors) => {
      if (!selectors) return null;
      for (const selector of selectors) {
        try {
          const el = document.querySelector(selector);
          if (el) return el;
        } catch (error) {
          // ignore selector errors
        }
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
      if (!node) continue;
      if (node.childElementCount === 0) {
        const text = (node.textContent || '').trim();
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
  },

  captureSelection() {
    const selection = window.getSelection();
    const text = selection ? selection.toString().trim() : '';
    return {
      ok: true,
      selection: text,
      title: document.title,
      url: location.href
    };
  },

  snapshotPage(_cfg, context = {}) {
    const limit = Number(context.limit) || 2000;
    const text = document.body ? document.body.innerText || '' : '';
    return {
      ok: true,
      title: document.title,
      url: location.href,
      content: text.slice(0, limit)
    };
  }
};

function pickSelectors(config = {}) {
  return {
    input: Array.isArray(config.input) ? config.input : [],
    sendButton: Array.isArray(config.sendButton) ? config.sendButton : [],
    messageContainer: Array.isArray(config.messageContainer) ? config.messageContainer : []
  };
}

function createDomScript(config, taskName, context, settings) {
  const task = DOM_TASKS[taskName];
  if (!task) {
    throw new Error(`Unknown DOM task ${taskName}`);
  }
  const safeContext = {
    ...context,
    limit: context && typeof context.limit !== 'undefined' ? context.limit : settings.messageLimit || DEFAULT_SETTINGS.messageLimit
  };
  const payload = {
    cfg: pickSelectors(config),
    context: safeContext
  };
  return `(() => {\nconst cfg = ${JSON.stringify(payload.cfg)};\nconst context = ${JSON.stringify(payload.context)};\nconst task = ${task.toString()};\nreturn task(cfg, context);\n})()`;
}

class JsonStore {
  constructor(filePath, defaults) {
    this.filePath = filePath;
    this.defaults = defaults;
  }

  load() {
    try {
      if (!fs.existsSync(this.filePath)) {
        const initial = JSON.stringify(this.defaults, null, 2);
        fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
        fs.writeFileSync(this.filePath, initial, 'utf8');
        return JSON.parse(initial);
      }
      const raw = fs.readFileSync(this.filePath, 'utf8');
      const data = JSON.parse(raw);
      if (Array.isArray(this.defaults) || typeof this.defaults !== 'object') {
        return data;
      }
      return { ...this.defaults, ...data };
    } catch (error) {
      console.error(`Failed to load ${this.filePath}`, error);
      return JSON.parse(JSON.stringify(this.defaults));
    }
  }

  save(value) {
    try {
      const serialised = JSON.stringify(value, null, 2);
      fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
      fs.writeFileSync(this.filePath, serialised, 'utf8');
    } catch (error) {
      console.error(`Failed to save ${this.filePath}`, error);
    }
  }
}

class AgentSession {
  constructor(key, getConfig) {
    this.key = key;
    this.getConfig = getConfig;
    this.window = null;
    this.queue = Promise.resolve();
    this.destroyed = false;
    this.lastUrl = '';
  }

  updateConfig() {
    if (!this.getConfig()) {
      this.destroy();
    }
  }

  async ensureWindow() {
    if (this.destroyed) {
      throw new Error('agent_removed');
    }
    if (this.window && !this.window.isDestroyed()) {
      return this.window;
    }

    const config = this.getConfig();
    if (!config) {
      throw new Error('unknown_agent');
    }

    const agentWin = new BrowserWindow({
      width: 1280,
      height: 800,
      show: false,
      title: `OmniChat – ${config.displayName || this.key}`,
      autoHideMenuBar: true,
      webPreferences: {
        preload: path.join(__dirname, 'agentPreload.js'),
        contextIsolation: true,
        nodeIntegration: false,
        partition: `persist:omnichat-${this.key}`,
        sandbox: false
      }
    });

    agentWin.webContents.setWindowOpenHandler(({ url }) => {
      shell.openExternal(url);
      return { action: 'deny' };
    });

    agentWin.on('close', (event) => {
      event.preventDefault();
      agentWin.hide();
      updateAgentStatus(this.key, { visible: false });
    });

    agentWin.on('hide', () => updateAgentStatus(this.key, { visible: false }));
    agentWin.on('focus', () => updateAgentStatus(this.key, { visible: true }));
    agentWin.on('blur', () => updateAgentStatus(this.key, { visible: false }));

    agentWin.webContents.on('did-start-loading', () => {
      updateAgentStatus(this.key, { status: 'loading' });
    });

    agentWin.webContents.on('did-finish-load', () => {
      this.lastUrl = agentWin.webContents.getURL();
      updateAgentStatus(this.key, { status: 'ready', url: this.lastUrl });
    });

    agentWin.webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL) => {
      updateAgentStatus(this.key, {
        status: 'error',
        error: `${errorDescription || errorCode}`,
        url: validatedURL || this.lastUrl
      });
    });

    const target = config.home || (Array.isArray(config.patterns) && config.patterns.length ? config.patterns[0].replace('*', '') : '');
    if (target) {
      updateAgentStatus(this.key, { status: 'loading' });
      await agentWin.loadURL(target);
    } else {
      await agentWin.loadURL('about:blank');
      updateAgentStatus(this.key, { status: 'ready', url: 'about:blank' });
    }

    this.window = agentWin;
    return agentWin;
  }

  async show() {
    const win = await this.ensureWindow();
    win.show();
    win.focus();
    updateAgentStatus(this.key, { visible: true });
  }

  hide() {
    if (this.window && !this.window.isDestroyed()) {
      this.window.hide();
    }
    updateAgentStatus(this.key, { visible: false });
  }

  async runTask(taskName, context = {}) {
    const job = this.queue.then(async () => {
      const config = this.getConfig();
      if (!config) {
        throw new Error('unknown_agent');
      }
      const win = await this.ensureWindow();
      const script = createDomScript(config, taskName, context, appState.settings);
      return win.webContents.executeJavaScript(script, true);
    });

    this.queue = job.then(() => undefined, () => undefined);
    return job;
  }

  destroy() {
    this.destroyed = true;
    if (this.window && !this.window.isDestroyed()) {
      const win = this.window;
      this.window = null;
      win.removeAllListeners('close');
      win.destroy();
    }
    updateAgentStatus(this.key, { status: 'removed', visible: false });
  }
}

const selectorStore = new JsonStore(SELECTOR_PATH, DEFAULT_SELECTORS);
const settingsStore = new JsonStore(SETTINGS_PATH, DEFAULT_SETTINGS);

const agentSessions = new Map();
const agentStatus = new Map();
const logBuffer = [];

const appState = {
  mainWindow: null,
  selectors: JSON.parse(JSON.stringify(DEFAULT_SELECTORS)),
  settings: { ...DEFAULT_SETTINGS },
  localHistory: []
};

function isLocalAgent(key) {
  return key === LOCAL_AGENT_KEY;
}

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

function updateAgentStatus(key, patch) {
  const selector = appState.selectors[key] || {};
  const baseDisplayName = selector.displayName || patch?.displayName || LOCAL_AGENT_MANIFEST.displayName || key;
  const current = agentStatus.get(key) || {
    key,
    displayName: baseDisplayName,
    status: 'idle',
    visible: false,
    type: isLocalAgent(key) ? 'local' : 'web'
  };
  const next = {
    ...current,
    ...patch,
    displayName: patch?.displayName || selector.displayName || current.displayName || key,
    type: patch?.type || current.type || (isLocalAgent(key) ? 'local' : 'web')
  };
  agentStatus.set(key, next);
  if (appState.mainWindow && !appState.mainWindow.isDestroyed()) {
    appState.mainWindow.webContents.send('agent:status', next);
  }
}

function ensureLocalAgentStatus(patch = {}) {
  const host = appState.settings.ollamaHost || DEFAULT_SETTINGS.ollamaHost;
  const model = appState.settings.ollamaModel || '';
  updateAgentStatus(LOCAL_AGENT_KEY, {
    displayName: LOCAL_AGENT_MANIFEST.displayName,
    type: 'local',
    visible: true,
    status: patch.status || agentStatus.get(LOCAL_AGENT_KEY)?.status || 'idle',
    host,
    model,
    ...patch
  });
}

function broadcastAgentSnapshot() {
  const payload = Array.from(agentStatus.values()).map((entry) => {
    const selector = appState.selectors[entry.key] || {};
    return {
      ...entry,
      displayName: selector.displayName || entry.displayName || entry.key,
      type: entry.type || (isLocalAgent(entry.key) ? 'local' : 'web')
    };
  });
  if (appState.mainWindow && !appState.mainWindow.isDestroyed()) {
    appState.mainWindow.webContents.send('agent:status:init', payload);
  }
}

function refreshAgentSessions() {
  const keys = Object.keys(appState.selectors);
  keys.forEach((key) => {
    if (!agentSessions.has(key)) {
      const session = new AgentSession(key, () => appState.selectors[key]);
      agentSessions.set(key, session);
    } else {
      agentSessions.get(key).updateConfig();
    }
    updateAgentStatus(key, {});
  });

  for (const key of Array.from(agentSessions.keys())) {
    if (!appState.selectors[key]) {
      const session = agentSessions.get(key);
      session.destroy();
      agentSessions.delete(key);
      agentStatus.delete(key);
    }
  }

  ensureLocalAgentStatus();
  broadcastAgentSnapshot();
}

function getAssistantManifest() {
  const selectors = appState.selectors || {};
  const manifest = {};
  Object.entries(selectors).forEach(([key, value]) => {
    manifest[key] = {
      key,
      type: 'web',
      displayName: value.displayName || key,
      home: value.home || '',
      patterns: value.patterns || []
    };
  });
  manifest[LOCAL_AGENT_KEY] = {
    ...LOCAL_AGENT_MANIFEST,
    host: appState.settings.ollamaHost || DEFAULT_SETTINGS.ollamaHost,
    model: appState.settings.ollamaModel || ''
  };
  return manifest;
}

function sanitizeLocalHistory() {
  if (!Array.isArray(appState.localHistory)) {
    appState.localHistory = [];
  }
  if (appState.localHistory.length > 100) {
    appState.localHistory = appState.localHistory.slice(-100);
  }
}

function getAgentSession(key) {
  if (!agentSessions.has(key)) {
    const config = appState.selectors[key];
    if (!config) {
      throw new Error('unknown_agent');
    }
    const session = new AgentSession(key, () => appState.selectors[key]);
    agentSessions.set(key, session);
    updateAgentStatus(key, {});
  }
  return agentSessions.get(key);
}

function createMainWindow() {
  const mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    title: APP_NAME,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false
    }
  });

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.on('closed', () => {
    appState.mainWindow = null;
  });

  mainWindow.loadFile(path.join(__dirname, 'index.html'));
  appState.mainWindow = mainWindow;
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function recordLog(entry) {
  const timestamp = new Date().toISOString();
  const line = `[${timestamp}] ${entry}`;
  logBuffer.push(line);
  if (logBuffer.length > 5000) {
    logBuffer.shift();
  }
  if (appState.mainWindow && !appState.mainWindow.isDestroyed()) {
    appState.mainWindow.webContents.send('log:push', line);
  }
  const logFile = path.join(LOG_ROOT, `${new Date().toISOString().slice(0, 10)}.log`);
  fs.appendFile(logFile, line + '\n', () => {});
}

async function sendToAgent(key, text) {
  if (isLocalAgent(key)) {
    throw new Error('local_agent');
  }
  const session = getAgentSession(key);
  const min = Number(appState.settings.delayMin) || DEFAULT_SETTINGS.delayMin;
  const max = Number(appState.settings.delayMax) || min;
  const wait = Math.max(min, Math.floor(min + Math.random() * Math.max(0, max - min)));
  if (wait > 0) {
    await delay(wait);
  }

  try {
    const result = await session.runTask('sendMessage', { text });
    if (!result || !result.ok) {
      throw new Error(result ? result.reason || 'send' : 'send');
    }
    recordLog(`${key}: message sent via ${result.via}`);
    return result;
  } catch (error) {
    recordLog(`${key}: send failed (${error.message || error})`);
    if (appState.mainWindow && !appState.mainWindow.isDestroyed()) {
      appState.mainWindow.webContents.send('app:toast', `${key}.${error.message || 'send'} selectors need attention.`);
    }
    throw error;
  }
}

async function readMessages(key) {
  if (isLocalAgent(key)) {
    sanitizeLocalHistory();
    return appState.localHistory.map((item) => `${item.direction === 'out' ? 'You' : item.model || 'Local'}: ${item.text}`);
  }
  try {
    const session = getAgentSession(key);
    const result = await session.runTask('readMessages', { limit: appState.settings.messageLimit });
    if (!result || !result.ok) {
      throw new Error(result ? result.reason || 'read' : 'read');
    }
    return result.messages || [];
  } catch (error) {
    recordLog(`${key}: read failed (${error.message || error})`);
    if (appState.mainWindow && !appState.mainWindow.isDestroyed()) {
      appState.mainWindow.webContents.send('app:toast', `${key}.${error.message || 'read'} selectors need attention.`);
    }
    return [];
  }
}

function withTrailingSlash(url) {
  if (!url) return '';
  return url.endsWith('/') ? url : `${url}/`;
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, options);
  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`HTTP ${response.status}: ${text.slice(0, 140)}`);
  }
  return await response.json();
}

function buildComfyAssetURL(host, asset) {
  const base = withTrailingSlash(host || DEFAULT_SETTINGS.comfyHost);
  const url = new URL('view', base);
  url.searchParams.set('filename', asset.filename || '');
  url.searchParams.set('type', asset.type || 'output');
  url.searchParams.set('subfolder', asset.subfolder || '');
  return url.toString();
}

function guessMime(filename = '') {
  const lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.webm')) return 'video/webm';
  return 'application/octet-stream';
}

async function listComfyHistory(limit = 8, hostOverride) {
  const host = hostOverride || appState.settings.comfyHost || DEFAULT_SETTINGS.comfyHost;
  const url = new URL('history', withTrailingSlash(host));
  const payload = await fetchJson(url);
  const entries = Object.entries(payload || {})
    .map(([id, info]) => ({ id, info }))
    .sort((a, b) => {
      const at = a.info?.prompt?.extra?.creation_time || a.info?.timestamp || 0;
      const bt = b.info?.prompt?.extra?.creation_time || b.info?.timestamp || 0;
      return bt - at;
    })
    .slice(0, limit);

  return entries.map(({ id, info }) => {
    const outputs = info?.outputs || {};
    const images = [];
    const videos = [];
    Object.values(outputs).forEach((node) => {
      if (Array.isArray(node?.images)) {
        node.images.forEach((image) => {
          images.push({
            ...image,
            url: buildComfyAssetURL(host, image),
            mime: guessMime(image.filename)
          });
        });
      }
      if (Array.isArray(node?.videos)) {
        node.videos.forEach((video) => {
          videos.push({
            ...video,
            url: buildComfyAssetURL(host, video),
            mime: guessMime(video.filename)
          });
        });
      }
    });

    return {
      id,
      title: info?.prompt?.extra?.title || info?.prompt?.extra?.workflow || id,
      created: info?.prompt?.extra?.creation_time || info?.timestamp || Date.now(),
      images,
      videos
    };
  });
}

async function fetchComfyAsset(asset) {
  const host = asset.host || appState.settings.comfyHost || DEFAULT_SETTINGS.comfyHost;
  const assetUrl = buildComfyAssetURL(host, asset);
  const response = await fetch(assetUrl);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  const mime = asset.mime || guessMime(asset.filename);
  return `data:${mime};base64,${buffer.toString('base64')}`;
}

async function runComfyWorkflowFromFile(hostOverride) {
  if (!appState.mainWindow || appState.mainWindow.isDestroyed()) {
    return { ok: false, error: 'window_closed' };
  }
  const result = await dialog.showOpenDialog(appState.mainWindow, {
    title: 'Choose ComfyUI workflow',
    filters: [{ name: 'JSON Files', extensions: ['json'] }],
    properties: ['openFile']
  });
  if (result.canceled || !result.filePaths.length) {
    return { ok: false, canceled: true };
  }
  const host = hostOverride || appState.settings.comfyHost || DEFAULT_SETTINGS.comfyHost;
  const filePath = result.filePaths[0];
  const workflow = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const url = new URL('prompt', withTrailingSlash(host));
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(workflow)
  });
  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`HTTP ${response.status}: ${text.slice(0, 140)}`);
  }
  return { ok: true };
}

async function listOllamaModels(hostOverride) {
  const host = hostOverride || appState.settings.ollamaHost || DEFAULT_SETTINGS.ollamaHost;
  const url = new URL('api/tags', withTrailingSlash(host));
  const data = await fetchJson(url);
  return Array.isArray(data?.models) ? data.models.map((model) => model.name) : [];
}

async function generateWithOllama({ model, prompt, host }) {
  const ollamaHost = host || appState.settings.ollamaHost || DEFAULT_SETTINGS.ollamaHost;
  const url = new URL('api/generate', withTrailingSlash(ollamaHost));
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ model, prompt, stream: true })
  });
  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`HTTP ${response.status}: ${text.slice(0, 140)}`);
  }

  let output = '';
  const reader = response.body?.getReader ? response.body.getReader() : null;
  if (reader) {
    const decoder = new TextDecoder();
    let remainder = '';
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      remainder += decoder.decode(value, { stream: true });
      let index;
      while ((index = remainder.indexOf('\n')) >= 0) {
        const line = remainder.slice(0, index).trim();
        remainder = remainder.slice(index + 1);
        if (!line) continue;
        try {
          const parsed = JSON.parse(line);
          if (parsed.response) {
            output += parsed.response;
          }
        } catch (error) {
          // ignore malformed chunks
        }
      }
    }
    const tail = remainder.trim();
    if (tail) {
      try {
        const parsed = JSON.parse(tail);
        if (parsed.response) {
          output += parsed.response;
        }
      } catch (error) {
        // ignore
      }
    }
  } else {
    const text = await response.text();
    output = text;
  }

  return output;
}

ipcMain.handle('app:bootstrap', async () => {
  ensureDirectories();
  ensureFirstRunGuide();
  appState.selectors = selectorStore.load();
  appState.settings = settingsStore.load();
  ensureLocalAgentStatus();
  refreshAgentSessions();
  return {
    selectors: appState.selectors,
    settings: appState.settings,
    assistants: getAssistantManifest(),
    order: [...Object.keys(appState.selectors), LOCAL_AGENT_KEY],
    log: logBuffer.slice(-200)
  };
});

ipcMain.handle('selectors:save', async (_event, payload) => {
  appState.selectors = payload || {};
  selectorStore.save(appState.selectors);
  refreshAgentSessions();
  return { ok: true };
});

ipcMain.handle('settings:save', async (_event, payload) => {
  appState.settings = { ...appState.settings, ...(payload || {}) };
  settingsStore.save(appState.settings);
  ensureLocalAgentStatus();
  return { ok: true };
});

ipcMain.handle('selectors:importFile', async () => {
  if (!appState.mainWindow || appState.mainWindow.isDestroyed()) {
    return { ok: false, error: 'window_closed' };
  }
  const result = await dialog.showOpenDialog(appState.mainWindow, {
    title: 'Import selectors.json',
    filters: [{ name: 'JSON Files', extensions: ['json'] }],
    properties: ['openFile']
  });
  if (result.canceled || !result.filePaths.length) {
    return { ok: false, canceled: true };
  }
  const filePath = result.filePaths[0];
  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    const data = JSON.parse(raw);
    appState.selectors = data;
    selectorStore.save(appState.selectors);
    refreshAgentSessions();
    return { ok: true, selectors: appState.selectors };
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('selectors:exportFile', async () => {
  if (!appState.mainWindow || appState.mainWindow.isDestroyed()) {
    return { ok: false, error: 'window_closed' };
  }
  const result = await dialog.showSaveDialog(appState.mainWindow, {
    title: 'Export selectors.json',
    filters: [{ name: 'JSON Files', extensions: ['json'] }],
    defaultPath: path.join(app.getPath('documents'), 'omnichat-selectors.json')
  });
  if (result.canceled || !result.filePath) {
    return { ok: false, canceled: true };
  }
  try {
    selectorStore.save(appState.selectors);
    fs.copyFileSync(SELECTOR_PATH, result.filePath);
    return { ok: true, path: result.filePath };
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('config:openFolder', async () => {
  await shell.openPath(CONFIG_ROOT);
  return { ok: true };
});

ipcMain.handle('agent:ensure', async (_event, key) => {
  if (isLocalAgent(key)) {
    ensureLocalAgentStatus({ status: 'ready' });
    return agentStatus.get(key) || { key: LOCAL_AGENT_KEY, type: 'local' };
  }
  const session = getAgentSession(key);
  await session.ensureWindow();
  return agentStatus.get(key) || { key };
});

ipcMain.handle('agent:connect', async (_event, key) => {
  if (isLocalAgent(key)) {
    ensureLocalAgentStatus({ status: 'ready' });
    return true;
  }
  const session = getAgentSession(key);
  await session.show();
  return true;
});

ipcMain.handle('agent:hide', async (_event, key) => {
  if (isLocalAgent(key)) {
    ensureLocalAgentStatus({ visible: false });
    return true;
  }
  if (agentSessions.has(key)) {
    agentSessions.get(key).hide();
  }
  return true;
});

ipcMain.handle('agent:read', async (_event, key) => {
  return await readMessages(key);
});

ipcMain.handle('agent:send', async (_event, payload) => {
  const { key, text } = payload || {};
  if (isLocalAgent(key)) {
    const prompt = text || '';
    if (!prompt.trim()) {
      throw new Error('empty_prompt');
    }
    try {
      appState.localHistory.push({ direction: 'out', text: prompt, timestamp: Date.now() });
      sanitizeLocalHistory();
      const existingModel = appState.settings.ollamaModel;
      let model = existingModel;
      if (!model) {
        const models = await listOllamaModels();
        if (!models.length) {
          throw new Error('no_local_models');
        }
        model = models[0];
        appState.settings.ollamaModel = model;
        settingsStore.save(appState.settings);
        ensureLocalAgentStatus({ model });
      }
      ensureLocalAgentStatus({ status: 'generating' });
      recordLog(`${key}: generating with ${model}`);
      const response = await generateWithOllama({ model, prompt });
      ensureLocalAgentStatus({ status: 'ready', model });
      appState.localHistory.push({ direction: 'in', text: response, model, timestamp: Date.now() });
      sanitizeLocalHistory();
      recordLog(`${key}: ${response.slice(0, 140)}${response.length > 140 ? '…' : ''}`);
      if (appState.mainWindow && !appState.mainWindow.isDestroyed()) {
        appState.mainWindow.webContents.send('agent:localMessage', {
          key,
          model,
          prompt,
          response,
          timestamp: Date.now()
        });
      }
      return { ok: true, response, model };
    } catch (error) {
      ensureLocalAgentStatus({ status: 'error', error: error.message || String(error) });
      recordLog(`${key}: generation failed (${error.message || error})`);
      if (appState.mainWindow && !appState.mainWindow.isDestroyed()) {
        appState.mainWindow.webContents.send('app:toast', `Local model: ${error.message || error}`);
      }
      throw error;
    }
  }
  await getAgentSession(key).ensureWindow();
  const messages = await readMessages(key);
  await sendToAgent(key, text || '');
  return { ok: true, previous: messages };
});

ipcMain.handle('agent:captureSelection', async (_event, key) => {
  try {
    const session = getAgentSession(key);
    const result = await session.runTask('captureSelection', {});
    return result;
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('agent:snapshot', async (_event, { key, limit = 2000 }) => {
  try {
    const session = getAgentSession(key);
    const result = await session.runTask('snapshotPage', { limit });
    return result;
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('log:export', async (_event, payload) => {
  if (!appState.mainWindow || appState.mainWindow.isDestroyed()) {
    return { ok: false };
  }
  const dialogResult = await dialog.showSaveDialog(appState.mainWindow, {
    title: 'Export OmniChat Log',
    filters: [{ name: 'Text Files', extensions: ['txt'] }],
    defaultPath: path.join(app.getPath('documents'), `omnichat-log-${Date.now()}.txt`)
  });
  if (dialogResult.canceled || !dialogResult.filePath) {
    return { ok: false };
  }
  fs.writeFileSync(dialogResult.filePath, payload || '', 'utf8');
  return { ok: true, path: dialogResult.filePath };
});

ipcMain.handle('settings:resetAgent', async (_event, key) => {
  if (!DEFAULT_SELECTORS[key]) {
    return { ok: false, error: 'unknown' };
  }
  appState.selectors[key] = JSON.parse(JSON.stringify(DEFAULT_SELECTORS[key]));
  selectorStore.save(appState.selectors);
  refreshAgentSessions();
  return { ok: true, selectors: appState.selectors };
});

ipcMain.handle('local:comfy:list', async (_event, options = {}) => {
  const { limit = 8, host } = options;
  try {
    const jobs = await listComfyHistory(limit, host);
    return { ok: true, jobs };
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('local:comfy:asset', async (_event, asset) => {
  try {
    const dataUrl = await fetchComfyAsset(asset || {});
    return { ok: true, dataUrl };
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('local:comfy:run', async (_event, hostOverride) => {
  try {
    const result = await runComfyWorkflowFromFile(hostOverride);
    return result;
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('local:ollama:models', async (_event, hostOverride) => {
  try {
    const models = await listOllamaModels(hostOverride);
    return { ok: true, models };
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('local:ollama:generate', async (_event, payload = {}) => {
  try {
    const response = await generateWithOllama(payload);
    return { ok: true, text: response };
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

app.whenReady().then(() => {
  ensureDirectories();
  ensureFirstRunGuide();
  appState.selectors = selectorStore.load();
  appState.settings = settingsStore.load();
  refreshAgentSessions();
  createMainWindow();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createMainWindow();
  }
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
