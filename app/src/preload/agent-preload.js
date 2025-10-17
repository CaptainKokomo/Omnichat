const { contextBridge } = require('electron');

const getArgumentValue = (name) => {
  const prefix = `--${name}=`;
  for (const arg of process.argv) {
    if (arg.startsWith(prefix)) {
      return arg.replace(prefix, '');
    }
  }
  return null;
};

contextBridge.exposeInMainWorld('agentBridge', {
  sendMessage: async ({ message, selectors }) => {
    const inputSelector = selectors.input?.find((sel) => document.querySelector(sel));
    const sendButtonSelector = selectors.sendButton?.find((sel) => document.querySelector(sel));

    if (inputSelector) {
      const inputEl = document.querySelector(inputSelector);
      const prop = inputEl.tagName === 'TEXTAREA' || inputEl.tagName === 'INPUT' ? 'value' : 'textContent';
      inputEl.focus();
      inputEl[prop] = message;
      inputEl.dispatchEvent(new Event('input', { bubbles: true }));
    }

    if (sendButtonSelector) {
      const btn = document.querySelector(sendButtonSelector);
      btn?.click();
    } else if (inputSelector) {
      const inputEl = document.querySelector(inputSelector);
      inputEl?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
      inputEl?.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', bubbles: true }));
    }

    return true;
  },
  captureSelection: () => {
    const selection = window.getSelection();
    return {
      agent: getArgumentValue('agent-key'),
      selection: selection ? selection.toString() : ''
    };
  },
  captureSnapshot: (maxLength = 2000) => {
    const title = document.title;
    const url = window.location.href;
    const containerSelector = ['main', 'article', 'body'];
    const container = containerSelector
      .map((sel) => document.querySelector(sel))
      .find(Boolean);
    const text = container ? container.innerText.slice(0, maxLength) : '';
    return { agent: getArgumentValue('agent-key'), title, url, text };
  }
});
