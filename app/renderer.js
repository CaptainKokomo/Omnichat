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
  copilotHost: document.getElementById('copilotHost')
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
      renderTargetDropdown();
    });

    top.appendChild(name);
    top.appendChild(toggle);

    const status = document.createElement('div');
    status.className = 'agent-status';
    const data = state.agents[key];
    const statusBits = [];
    if (data && data.status) statusBits.push(data.status);
    if (data && data.visible) statusBits.push('visible');
    if (data && data.url) statusBits.push(new URL(data.url).hostname);
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
  renderTargetDropdown();
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
}

function renderSiteEditor() {
  elements.siteEditor.innerHTML = '';
  Object.entries(state.selectors).forEach(([key, config]) => {
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
    copilotHost: elements.copilotHost.value.trim()
  };
}

async function persistSettings() {
  const next = collectSettingsFromModal();
  state.settings = { ...state.settings, ...next };
  await api.saveSettings(state.settings);
  elements.roundTurns.value = state.settings.roundTableTurns;
}

elements.openSettings.addEventListener('click', () => {
  elements.settingsModal.classList.remove('hidden');
});

elements.closeSettings.addEventListener('click', async () => {
  await persistSelectors();
  await persistSettings();
  elements.settingsModal.classList.add('hidden');
  showToast('Settings saved.');
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
  renderSiteEditor();
  renderAgents();
});

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
    parts.push(`\n\n[Attachment ${index + 1}] ${attachment.title}\n${attachment.meta}\n${attachment.body}`);
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

function pushAttachment(attachment) {
  state.attachments.push(attachment);
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
    body.textContent = attachment.body;
    const actions = document.createElement('div');
    actions.className = 'site-actions';
    const insertBtn = document.createElement('button');
    insertBtn.className = 'secondary';
    insertBtn.textContent = 'Insert into composer';
    insertBtn.addEventListener('click', () => {
      elements.composerInput.value = `${elements.composerInput.value}\n\n${attachment.body}`.trim();
    });
    const removeBtn = document.createElement('button');
    removeBtn.className = 'secondary';
    removeBtn.textContent = 'Remove';
    removeBtn.addEventListener('click', () => {
      state.attachments.splice(index, 1);
      renderAttachments();
    });
    actions.appendChild(insertBtn);
    actions.appendChild(removeBtn);
    div.appendChild(title);
    div.appendChild(meta);
    div.appendChild(body);
    div.appendChild(actions);
    elements.attachments.appendChild(div);
  });
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
}

function hydrateSettings() {
  elements.confirmToggle.checked = !!state.settings.confirmBeforeSend;
  elements.delayMin.value = state.settings.delayMin || 0;
  elements.delayMax.value = state.settings.delayMax || 0;
  elements.messageLimit.value = state.settings.messageLimit || 5;
  elements.defaultTurns.value = state.settings.roundTableTurns || 2;
  elements.copilotHost.value = state.settings.copilotHost || '';
  elements.roundTurns.value = state.settings.roundTableTurns || 2;
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
