import { contextBridge, ipcRenderer } from 'electron';
import type { ChatRequest, ModelConfigPayload, SessionCreatePayload, SessionState } from '@shared/types/chat';

type Channels =
  | 'chat:send'
  | 'config:list'
  | 'config:update'
  | 'session:get'
  | 'session:create'
  | 'session:delete';

const api = {
  invoke<T>(channel: Channels, payload?: unknown): Promise<T> {
    return ipcRenderer.invoke(channel, payload ?? null) as Promise<T>;
  },
  on(channel: Channels, listener: (event: Electron.IpcRendererEvent, ...args: unknown[]) => void): void {
    ipcRenderer.on(channel, listener);
  },
  off(channel: Channels, listener: (event: Electron.IpcRendererEvent, ...args: unknown[]) => void): void {
    ipcRenderer.removeListener(channel, listener);
  },
  sendChat(request: ChatRequest): Promise<SessionState> {
    return ipcRenderer.invoke('chat:send', request) as Promise<SessionState>;
  },
  getSession(sessionId: string): Promise<SessionState | null> {
    return ipcRenderer.invoke('session:get', { sessionId }) as Promise<SessionState | null>;
  },
  listConfigs(): Promise<ModelConfigPayload> {
    return ipcRenderer.invoke('config:list') as Promise<ModelConfigPayload>;
  },
  updateConfigs(payload: ModelConfigPayload): Promise<ModelConfigPayload> {
    return ipcRenderer.invoke('config:update', payload) as Promise<ModelConfigPayload>;
  },
  createSession(payload: SessionCreatePayload): Promise<SessionState> {
    return ipcRenderer.invoke('session:create', payload) as Promise<SessionState>;
  },
  deleteSession(sessionId: string): Promise<boolean> {
    return ipcRenderer.invoke('session:delete', { sessionId }) as Promise<boolean>;
  }
};

contextBridge.exposeInMainWorld('omnichat', api);

export type OmnichatAPI = typeof api;
