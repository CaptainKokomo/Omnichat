const { contextBridge } = require('electron');

contextBridge.exposeInMainWorld('OmniChatAgent', {
  ping: () => true
});
