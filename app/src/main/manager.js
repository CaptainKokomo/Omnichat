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
