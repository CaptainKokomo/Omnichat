const agentListEl = document.getElementById('agent-list');
const refreshAgentsBtn = document.getElementById('refresh-agents');
const openSettingsBtn = document.getElementById('open-settings');
const firstRunBtn = document.getElementById('open-first-run');
const settingsModal = document.getElementById('settings-modal');
const closeSettingsBtn = document.getElementById('close-settings');
const settingsForm = document.getElementById('settings-form');
const selectorsTextArea = document.getElementById('selectors-json');
const siteListEl = document.getElementById('site-list');
const addSiteBtn = document.getElementById('add-site-btn');
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
let currentSites = [];

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
  await loadSites();
}

async function loadSites() {
  const sites = await window.omniSwitch.getSites();
  currentSites = Object.entries(sites || {}).map(([key, site]) => ({
    key,
    name: site?.name || key,
    url: site?.url || ''
  }));
  renderSites();
}

function renderSites() {
  if (!siteListEl) return;
  siteListEl.innerHTML = '';

  if (!currentSites.length) {
    const empty = document.createElement('p');
    empty.className = 'hint';
    empty.textContent = 'No browser assistants yet. Add one to get started.';
    siteListEl.appendChild(empty);
    return;
  }

  currentSites.forEach((site) => {
    const item = document.createElement('div');
    item.className = 'site-item';
    item.dataset.siteKey = site.key;

    const header = document.createElement('header');
    const title = document.createElement('span');
    title.textContent = `${site.name || 'Unnamed'} · ${site.key}`;
    header.appendChild(title);

    const removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.textContent = 'Remove';
    removeBtn.addEventListener('click', () => removeSite(site.key));
    header.appendChild(removeBtn);

    item.appendChild(header);

    const nameLabel = document.createElement('label');
    nameLabel.textContent = 'Display name';
    const nameInput = document.createElement('input');
    nameInput.type = 'text';
    nameInput.value = site.name;
    nameInput.addEventListener('input', (event) => {
      updateSiteField(site.key, 'name', event.target.value);
      title.textContent = `${event.target.value || 'Unnamed'} · ${site.key}`;
    });
    nameLabel.appendChild(nameInput);
    item.appendChild(nameLabel);

    const urlLabel = document.createElement('label');
    urlLabel.textContent = 'Start URL';
    const urlInput = document.createElement('input');
    urlInput.type = 'text';
    urlInput.value = site.url;
    urlInput.addEventListener('input', (event) => {
      updateSiteField(site.key, 'url', event.target.value);
    });
    urlLabel.appendChild(urlInput);
    item.appendChild(urlLabel);

    siteListEl.appendChild(item);
  });
}

function updateSiteField(key, field, value) {
  const site = currentSites.find((entry) => entry.key === key);
  if (site) {
    site[field] = value;
  }
}

function generateKeyFromName(name) {
  const base = (name || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 32);
  let candidate = base || `model-${currentSites.length + 1}`;
  let index = 1;
  while (currentSites.some((site) => site.key === candidate)) {
    candidate = `${base || 'model'}-${index}`;
    index += 1;
  }
  return candidate;
}

function normalizeUrl(url) {
  if (!url) return '';
  if (!/^https?:\/\//i.test(url)) {
    return `https://${url}`;
  }
  return url;
}

function ensureSelectorsEntry(siteKey) {
  let selectors;
  try {
    selectors = JSON.parse(selectorsTextArea.value || '{}');
  } catch (err) {
    alert('Fix the selectors JSON before adding a new browser assistant.');
    return false;
  }
  if (!selectors[siteKey]) {
    selectors[siteKey] = {
      input: ['textarea', "div[contenteditable='true']"],
      sendButton: ["button[type='submit']", "button[aria-label='Send']"],
      messageContainer: ['main', "div[class*='conversation']"]
    };
    selectorsTextArea.value = JSON.stringify(selectors, null, 2);
  }
  return true;
}

function removeSelectorsEntry(siteKey) {
  try {
    const selectors = JSON.parse(selectorsTextArea.value || '{}');
    if (selectors[siteKey]) {
      delete selectors[siteKey];
      selectorsTextArea.value = JSON.stringify(selectors, null, 2);
    }
  } catch (err) {
    // Ignore invalid JSON here; the save routine will surface errors.
  }
}

function addSite() {
  const name = prompt('Name this browser assistant (e.g., Perplexity).');
  if (!name) {
    return;
  }
  const urlInput = prompt('Paste the chat URL you use for it (https://...).');
  if (!urlInput) {
    return;
  }
  const url = normalizeUrl(urlInput.trim());
  const key = generateKeyFromName(name.trim());
  if (!ensureSelectorsEntry(key)) {
    return;
  }
  currentSites.push({ key, name: name.trim(), url });
  renderSites();
}

function removeSite(key) {
  currentSites = currentSites.filter((site) => site.key !== key);
  selectedAgents.delete(key);
  removeSelectorsEntry(key);
  renderSites();
}

function buildSitesPayload() {
  const payload = {};
  for (const site of currentSites) {
    const name = site.name?.trim();
    const url = normalizeUrl(site.url?.trim());
    if (!name || !url) {
      alert('Please fill in the name and URL for every browser assistant.');
      return null;
    }
    payload[site.key] = { name, url };
  }
  return payload;
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

  const sitesPayload = buildSitesPayload();
  if (!sitesPayload) {
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
  await window.omniSwitch.saveSites(sitesPayload);
  await window.omniSwitch.saveSelectors(selectors);
  await loadSettings();
  await loadAgents();
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
addSiteBtn.addEventListener('click', addSite);

loadAgents();
loadSettings();
refreshLog();
setInterval(refreshLog, 4000);
