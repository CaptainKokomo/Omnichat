const api = window.omnichat;

const elements = {
  agentList: document.getElementById('agentList'),
  assistantSummary: document.getElementById('assistantSummary'),
  refreshAgents: document.getElementById('refreshAgents'),
  manageAssistants: document.getElementById('manageAssistants'),
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
  resetSiteForm: document.getElementById('resetSiteForm'),
  newSiteName: document.getElementById('newSiteName'),
  newSiteKey: document.getElementById('newSiteKey'),
  newSiteTemplate: document.getElementById('newSiteTemplate'),
  newSiteHome: document.getElementById('newSiteHome'),
  newSitePatterns: document.getElementById('newSitePatterns'),
  newSiteInput: document.getElementById('newSiteInput'),
  newSiteSend: document.getElementById('newSiteSend'),
  newSiteMessages: document.getElementById('newSiteMessages'),
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

const DEFAULT_KEY_FALLBACK = ['chatgpt', 'claude', 'copilot', 'gemini'];
const LOCAL_AGENT_KEY = 'local-ollama';

const state = {
  selectors: {},
  defaultSelectors: {},
  assistants: {},
  localManifest: null,
  settings: {},
  order: [],
  defaultKeys: [...DEFAULT_KEY_FALLBACK],
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

function isDefaultKey(key) {
  const defaults = state.defaultKeys && state.defaultKeys.length ? state.defaultKeys : DEFAULT_KEY_FALLBACK;
  return defaults.includes(key);
}

function getDefaultLocalManifest() {
  return {
    key: LOCAL_AGENT_KEY,
    type: 'local',
    displayName: 'Local (Ollama)',
    host: state.settings.ollamaHost || '',
    model: state.settings.ollamaModel || ''
  };
}

function syncAssistantManifest(orderOverride) {
  const manifest = {};
  Object.entries(state.selectors || {}).forEach(([key, config]) => {
    manifest[key] = {
      key,
      type: 'web',
      displayName: config.displayName || key,
      home: config.home || '',
      patterns: config.patterns || []
    };
  });
  const local = state.localManifest || getDefaultLocalManifest();
  const normalizedLocal = {
    ...local,
    host: state.settings.ollamaHost || local.host || '',
    model: state.settings.ollamaModel || local.model || ''
  };
  manifest[normalizedLocal.key] = { ...normalizedLocal };
  state.assistants = manifest;
  updateLocalManifest(normalizedLocal, { skipSummary: true });

  const currentOrder = Array.isArray(orderOverride) ? orderOverride : state.order;
  const nextOrder = [];
  (currentOrder || []).forEach((key) => {
    if (manifest[key] && !nextOrder.includes(key)) {
      nextOrder.push(key);
    }
  });
  Object.keys(manifest).forEach((key) => {
    if (!nextOrder.includes(key)) {
      nextOrder.push(key);
    }
  });
  state.order = nextOrder;

  const previousSelection = new Set(state.selected || []);
  const nextSelection = new Set();
  previousSelection.forEach((key) => {
    if (manifest[key]) {
      nextSelection.add(key);
    }
  });
  if (!nextSelection.size) {
    nextOrder.forEach((key) => nextSelection.add(key));
  }
  state.selected = nextSelection;
  renderAssistantSummary();
}

function renderAssistantSummary() {
  if (!elements.assistantSummary) return;
  const assistants = Object.values(state.assistants || {});
  const browserAssistants = assistants
    .filter((item) => item.type === 'web')
    .map((item) => item.displayName || item.key);
  const local = assistants.find((item) => item.type === 'local');
  let hostLabel = '';
  if (local?.host) {
    try {
      hostLabel = new URL(local.host).host || local.host;
    } catch (error) {
      hostLabel = local.host;
    }
  }
  const browserInfo = browserAssistants.length
    ? `Browser: ${browserAssistants.join(', ')}`
    : 'Browser: none linked';
  const localInfo = local
    ? `Local: ${local.model ? local.model : 'model not selected'}${hostLabel ? ` @ ${hostLabel}` : ''}`
    : 'Local: unavailable';
  elements.assistantSummary.textContent = `${browserInfo} · ${localInfo}`;
}

function updateLocalManifest(patch = {}, options = {}) {
  const next = {
    ...(state.localManifest || getDefaultLocalManifest()),
    ...patch
  };
  state.localManifest = next;
  if (!state.assistants) {
    state.assistants = {};
  }
  state.assistants[LOCAL_AGENT_KEY] = { ...next };
  if (!options.skipSummary) {
    renderAssistantSummary();
  }
}

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
    const assistant = state.assistants[key];
    if (!assistant) return;
    const config = state.selectors[key];
    const item = document.createElement('div');
    item.className = 'agent-item';
    if (assistant.type === 'local') {
      item.classList.add('local');
    }
    if (state.selected.has(key)) {
      item.classList.add('active');
    }

    const top = document.createElement('div');
    top.className = 'agent-top';
    const name = document.createElement('div');
    const label = assistant.displayName || config?.displayName || key;
    name.innerHTML = `<strong>${label}</strong> <span class="badge">${key}</span>`;

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
    if (data && data.visible && assistant.type !== 'local') {
      statusBits.push('visible');
    }
    if (data && data.error) {
      statusBits.push(`error: ${data.error}`);
    }
    if (assistant.type === 'local') {
      const host = (data && data.host) || state.settings.ollamaHost || '';
      const model = (data && data.model) || state.settings.ollamaModel || '';
      statusBits.push(model ? `model: ${model}` : 'model pending');
      if (host) {
        try {
          const parsed = new URL(host);
          statusBits.push(parsed.host || host);
        } catch (error) {
          statusBits.push(host);
        }
      } else {
        statusBits.push('host offline');
      }
    } else if (data && data.url) {
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

    if (assistant.type === 'local') {
      const studioBtn = document.createElement('button');
      studioBtn.className = 'secondary';
      studioBtn.textContent = 'Focus Studio';
      studioBtn.addEventListener('click', () => {
        document.getElementById('ollamaHostField')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
        showToast('Local Studio ready below.');
      });
      const refreshBtn = document.createElement('button');
      refreshBtn.className = 'secondary';
      refreshBtn.textContent = 'Refresh models';
      refreshBtn.addEventListener('click', () => refreshOllamaModels());
      actions.appendChild(studioBtn);
      actions.appendChild(refreshBtn);
    } else {
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

      if (!isDefaultKey(key)) {
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
    }

    const orderControls = buildAgentOrderControls(key);

    item.appendChild(top);
    item.appendChild(status);
    item.appendChild(actions);
    item.appendChild(orderControls);
    elements.agentList.appendChild(item);
  });
  updateTargetControls();
}

function renderTargetDropdown() {
  const selected = Array.from(state.order).filter((key) => state.assistants[key]);
  elements.singleTarget.innerHTML = '';
  selected.forEach((key) => {
    const option = document.createElement('option');
    const assistant = state.assistants[key];
    option.value = key;
    option.textContent = assistant.displayName || key;
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
    if (!state.assistants[key]) return;
    hasAny = true;
    const assistant = state.assistants[key];
    const chip = document.createElement('button');
    chip.type = 'button';
    chip.className = 'chip';
    chip.textContent = assistant.displayName || key;
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
    ? state.order.filter((key) => state.selectors[key])
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

    if (!isDefaultKey(key)) {
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
  populateTemplateSelect();
}

function slugifyKey(value = '') {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
}

function clearNewSiteForm() {
  if (!elements.newSiteName) return;
  elements.newSiteName.value = '';
  if (elements.newSiteHome) elements.newSiteHome.value = '';
  if (elements.newSitePatterns) elements.newSitePatterns.value = '';
  if (elements.newSiteInput) elements.newSiteInput.value = '';
  if (elements.newSiteSend) elements.newSiteSend.value = '';
  if (elements.newSiteMessages) elements.newSiteMessages.value = '';
  if (elements.newSiteTemplate) elements.newSiteTemplate.value = '';
  if (elements.newSiteKey) {
    elements.newSiteKey.value = '';
    delete elements.newSiteKey.dataset.manual;
  }
}

function populateTemplateSelect() {
  if (!elements.newSiteTemplate) return;
  const currentValue = elements.newSiteTemplate.value;
  elements.newSiteTemplate.innerHTML = '';
  const placeholder = document.createElement('option');
  placeholder.value = '';
  placeholder.textContent = 'Choose template…';
  elements.newSiteTemplate.appendChild(placeholder);

  const seen = new Set();
  const addOption = (value, label) => {
    if (!value || seen.has(value)) return;
    seen.add(value);
    const option = document.createElement('option');
    option.value = value;
    option.textContent = label;
    elements.newSiteTemplate.appendChild(option);
  };

  Object.entries(state.defaultSelectors || {}).forEach(([key, config]) => {
    addOption(`default:${key}`, `${config.displayName || key} (default)`);
  });
  Object.entries(state.selectors || {}).forEach(([key, config]) => {
    addOption(`current:${key}`, `${config.displayName || key} (current)`);
  });

  if (currentValue && seen.has(currentValue)) {
    elements.newSiteTemplate.value = currentValue;
  }
}

function applyTemplateSelection(value) {
  if (!value || !elements.newSiteKey) return;
  const [scope, key] = value.split(':');
  if (!key) return;
  let template = null;
  if (scope === 'default') {
    template = state.defaultSelectors?.[key] || null;
  } else if (scope === 'current') {
    template = state.selectors?.[key] || null;
  }
  if (!template) return;
  const displayName = template.displayName || key;
  if (!elements.newSiteName.value.trim()) {
    elements.newSiteName.value = displayName;
  }
  if (!elements.newSiteKey.dataset.manual || !elements.newSiteKey.value.trim()) {
    elements.newSiteKey.value = slugifyKey(elements.newSiteName.value || displayName);
  }
  elements.newSiteHome.value = template.home || '';
  elements.newSitePatterns.value = (template.patterns || []).join('\n');
  elements.newSiteInput.value = (template.input || []).join('\n');
  elements.newSiteSend.value = (template.sendButton || []).join('\n');
  elements.newSiteMessages.value = (template.messageContainer || []).join('\n');
}

function collectNewSiteForm() {
  if (!elements.newSiteName) return null;
  const name = elements.newSiteName.value.trim();
  let key = elements.newSiteKey.value.trim().toLowerCase();
  if (!key) {
    key = slugifyKey(name);
    elements.newSiteKey.value = key;
  }
  if (!key) {
    showToast('Enter an assistant key.');
    return null;
  }
  if (!/^[a-z0-9\-]+$/.test(key)) {
    showToast('Key must use letters, numbers, or hyphen.');
    return null;
  }
  if (state.selectors[key]) {
    showToast('That key already exists.');
    return null;
  }
  const homeField = elements.newSiteHome;
  const patternField = elements.newSitePatterns;
  const inputField = elements.newSiteInput;
  const sendField = elements.newSiteSend;
  const messageField = elements.newSiteMessages;
  const home = homeField ? homeField.value.trim() : '';
  const patterns = (patternField ? patternField.value : '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const input = (inputField ? inputField.value : '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const sendButton = (sendField ? sendField.value : '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  const messageContainer = (messageField ? messageField.value : '')
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  if (!patterns.length && home) {
    patterns.push(home);
  }
  if (!patterns.length) {
    showToast('Provide at least one URL pattern.');
    return null;
  }
  if (!input.length) {
    showToast('Provide at least one input selector.');
    return null;
  }
  if (!sendButton.length) {
    showToast('Provide at least one send button selector.');
    return null;
  }
  if (!messageContainer.length) {
    showToast('Provide at least one message container selector.');
    return null;
  }

  const config = {
    displayName: name || key,
    home,
    patterns,
    input,
    sendButton,
    messageContainer
  };

  return { key, config };
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
  await api.saveSelectors(next);
  syncAssistantManifest();
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
  updateLocalManifest({
    host: state.settings.ollamaHost || '',
    model: state.settings.ollamaModel || state.localManifest?.model || ''
  });
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

if (elements.manageAssistants) {
  elements.manageAssistants.addEventListener('click', () => {
    openSettingsModal();
  });
}

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

if (elements.addSiteBtn) {
  elements.addSiteBtn.addEventListener('click', async () => {
    const entry = collectNewSiteForm();
    if (!entry) {
      return;
    }
    const { key, config } = entry;
    state.selectors[key] = config;
    if (!state.order.includes(key)) {
      state.order.push(key);
    }
    state.selected.add(key);
    await api.saveSelectors(state.selectors);
    syncAssistantManifest();
    renderAgents();
    renderSiteEditor();
    showToast(`${config.displayName || key} added.`);
    clearNewSiteForm();
  });
}

if (elements.resetSiteForm) {
  elements.resetSiteForm.addEventListener('click', () => {
    clearNewSiteForm();
  });
}

if (elements.newSiteTemplate) {
  elements.newSiteTemplate.addEventListener('change', () => {
    applyTemplateSelection(elements.newSiteTemplate.value);
  });
}

if (elements.newSiteName && elements.newSiteKey) {
  elements.newSiteName.addEventListener('input', () => {
    if (!elements.newSiteKey.dataset.manual) {
      elements.newSiteKey.value = slugifyKey(elements.newSiteName.value);
    }
  });
}

if (elements.newSiteKey) {
  elements.newSiteKey.addEventListener('input', () => {
    if (elements.newSiteKey.value.trim()) {
      elements.newSiteKey.dataset.manual = '1';
    } else {
      delete elements.newSiteKey.dataset.manual;
      if (elements.newSiteName && elements.newSiteName.value.trim()) {
        elements.newSiteKey.value = slugifyKey(elements.newSiteName.value);
      }
    }
  });
}

if (elements.importSelectorsBtn) {
  elements.importSelectorsBtn.addEventListener('click', async () => {
    const result = await api.importSelectors();
    if (result && result.ok) {
      state.selectors = result.selectors || state.selectors;
      state.order = Object.keys(state.selectors);
      syncAssistantManifest();
      renderAgents();
      renderSiteEditor();
      clearNewSiteForm();
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
  const keys = state.order.filter((key) => state.assistants[key]);
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
    updateLocalManifest({ model: value });
  });
}

if (elements.ollamaHostField) {
  elements.ollamaHostField.addEventListener('change', () => {
    state.settings.ollamaHost = elements.ollamaHostField.value.trim();
    scheduleSettingsSave();
    updateLocalManifest({ host: state.settings.ollamaHost });
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
  updateLocalManifest(
    {
      host: state.settings.ollamaHost || state.localManifest?.host || '',
      model: state.settings.ollamaModel || state.localManifest?.model || ''
    },
    { skipSummary: true }
  );
  renderOllamaModels();
  renderOllamaOutput();
  renderComfyGallery();
  renderAssistantSummary();
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
    updateLocalManifest(
      {
        host: host || state.localManifest?.host || '',
        model: state.settings.ollamaModel || state.localManifest?.model || ''
      },
      { skipSummary: true }
    );
    renderOllamaModels();
    renderAssistantSummary();
    if (!silent) {
      showToast('Ollama models refreshed.');
    }
  } catch (error) {
    state.local.ollamaModels = [];
    renderOllamaModels();
    updateLocalManifest(
      {
        host: elements.ollamaHostField.value.trim() || state.localManifest?.host || ''
      },
      { skipSummary: false }
    );
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
    updateLocalManifest({ host: host || state.localManifest?.host || '', model });
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
  if (payload.defaults) {
    state.defaultSelectors = payload.defaults;
  }
  if (payload.defaultKeys && payload.defaultKeys.length) {
    state.defaultKeys = payload.defaultKeys;
  }
  state.localManifest = payload.assistants ? payload.assistants[LOCAL_AGENT_KEY] : state.localManifest;
  syncAssistantManifest(payload.order || state.order);
  renderLog();
  renderAgents();
  renderSiteEditor();
  hydrateSettings();
  refreshOllamaModels({ silent: true });
  refreshComfyHistory({ silent: true });
  renderAttachments();
  clearNewSiteForm();
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
  state.defaultSelectors = payload.defaults || state.defaultSelectors || {};
  if (payload.defaultKeys && payload.defaultKeys.length) {
    state.defaultKeys = payload.defaultKeys;
  } else if (payload.defaults) {
    state.defaultKeys = Object.keys(payload.defaults);
  }
  state.localManifest = payload.assistants ? payload.assistants[LOCAL_AGENT_KEY] : null;
  syncAssistantManifest(payload.order || []);
  renderLog();
  renderAgents();
  renderSiteEditor();
  hydrateSettings();
  refreshOllamaModels({ silent: true });
  refreshComfyHistory({ silent: true });
  renderAttachments();
  clearNewSiteForm();
}

api.onStatus((status) => {
  state.agents[status.key] = { ...state.agents[status.key], ...status };
  if (status.key === LOCAL_AGENT_KEY) {
    updateLocalManifest({
      host: status.host || state.localManifest?.host || state.settings.ollamaHost || '',
      model: status.model || state.localManifest?.model || state.settings.ollamaModel || ''
    });
  }
  renderAgents();
});

api.onStatusInit((entries) => {
  entries.forEach((entry) => {
    state.agents[entry.key] = { ...state.agents[entry.key], ...entry };
    if (entry.key === LOCAL_AGENT_KEY) {
      updateLocalManifest(
        {
          host: entry.host || state.localManifest?.host || state.settings.ollamaHost || '',
          model: entry.model || state.localManifest?.model || state.settings.ollamaModel || ''
        },
        { skipSummary: true }
      );
    }
  });
  renderAssistantSummary();
  renderAgents();
});

api.onLog((entry) => {
  appendLog(entry);
});

api.onToast((message) => {
  showToast(message);
});

api.onLocalMessage((payload) => {
  if (!payload || !payload.response) {
    return;
  }
  const timestamp = payload.timestamp ? new Date(payload.timestamp) : new Date();
  const stamp = timestamp.toLocaleString();
  const modelLabel = payload.model || state.settings.ollamaModel || 'local model';
  updateLocalManifest({
    model: modelLabel,
    host: state.localManifest?.host || state.settings.ollamaHost || ''
  });
  pushAttachment({
    type: 'text',
    title: `Local (${modelLabel})`,
    meta: `Generated ${stamp}`,
    body: payload.response.trim()
  });
  showToast('Local model response added to attachments.');
});

window.addEventListener('beforeunload', () => {
  stopRoundTable();
});

bootstrap();
