import type { IpcMain } from 'electron';
import type { ModelOrchestrator } from './orchestrator';
import type { ChatRequest, ModelConfigPayload, SessionCreatePayload } from '@shared/types/chat';

export function registerIpcHandlers(ipcMain: IpcMain, orchestrator: ModelOrchestrator): void {
  ipcMain.handle('chat:send', async (_event, payload: ChatRequest) => {
    return orchestrator.processChat(payload);
  });

  ipcMain.handle('session:get', async (_event, { sessionId }: { sessionId: string }) => {
    return orchestrator.getSession(sessionId);
  });

  ipcMain.handle('session:create', async (_event, payload: SessionCreatePayload) => {
    return orchestrator.createSession(payload);
  });

  ipcMain.handle('session:delete', async (_event, { sessionId }: { sessionId: string }) => {
    return orchestrator.deleteSession(sessionId);
  });

  ipcMain.handle('config:list', async () => {
    return orchestrator.listConfigurations();
  });

  ipcMain.handle('config:update', async (_event, payload: ModelConfigPayload) => {
    return orchestrator.updateConfigurations(payload);
  });
}
