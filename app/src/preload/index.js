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
