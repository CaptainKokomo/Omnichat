import type {
  ChatRequest,
  ModelConfigPayload,
  SessionCreatePayload,
  SessionDeletePayload,
  SessionState
} from './chat';

declare global {
  interface OmnichatAPI {
    invoke<T>(channel: string, payload?: unknown): Promise<T>;
    on(channel: string, listener: (event: unknown, ...args: unknown[]) => void): void;
    off(channel: string, listener: (event: unknown, ...args: unknown[]) => void): void;
    sendChat(request: ChatRequest): Promise<SessionState>;
    getSession(sessionId: string): Promise<SessionState | null>;
    listConfigs(): Promise<ModelConfigPayload>;
    updateConfigs(payload: ModelConfigPayload): Promise<ModelConfigPayload>;
    createSession(payload: SessionCreatePayload): Promise<SessionState>;
    deleteSession(sessionId: SessionDeletePayload['sessionId']): Promise<boolean>;
  }

  interface Window {
    omnichat: OmnichatAPI;
  }
}

export {};
