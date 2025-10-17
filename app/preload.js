const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('omnichat', {
  bootstrap: () => ipcRenderer.invoke('app:bootstrap'),
  saveSelectors: (selectors) => ipcRenderer.invoke('selectors:save', selectors),
  saveSettings: (settings) => ipcRenderer.invoke('settings:save', settings),
  ensureAgent: (key) => ipcRenderer.invoke('agent:ensure', key),
  connectAgent: (key) => ipcRenderer.invoke('agent:connect', key),
  hideAgent: (key) => ipcRenderer.invoke('agent:hide', key),
  readAgent: (key) => ipcRenderer.invoke('agent:read', key),
  sendAgent: (payload) => ipcRenderer.invoke('agent:send', payload),
  captureSelection: (key) => ipcRenderer.invoke('agent:captureSelection', key),
  snapshotPage: (payload) => ipcRenderer.invoke('agent:snapshot', payload),
  exportLog: (text) => ipcRenderer.invoke('log:export', text),
  resetAgentSelectors: (key) => ipcRenderer.invoke('settings:resetAgent', key),
  onStatus: (handler) => ipcRenderer.on('agent:status', (_event, data) => handler(data)),
  onStatusInit: (handler) => ipcRenderer.on('agent:status:init', (_event, data) => handler(data)),
  onLog: (handler) => ipcRenderer.on('log:push', (_event, data) => handler(data)),
  onToast: (handler) => ipcRenderer.on('app:toast', (_event, message) => handler(message))
});
