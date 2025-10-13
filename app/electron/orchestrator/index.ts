import { ConversationEngine } from './modules/conversationEngine';
import { ProviderRegistry } from './modules/providerRegistry';
import { SessionStore } from './modules/sessionStore';
import { loadConfiguration, persistConfiguration } from './modules/settings';
import type {
  ChatRequest,
  ModelConfigPayload,
  SessionCreatePayload,
  SessionState
} from '../../shared/types/chat';

export interface ModelOrchestrator {
  processChat(request: ChatRequest): Promise<SessionState>;
  getSession(sessionId: string): Promise<SessionState | null>;
  listConfigurations(): Promise<ModelConfigPayload>;
  updateConfigurations(payload: ModelConfigPayload): Promise<ModelConfigPayload>;
  createSession(payload: SessionCreatePayload): Promise<SessionState>;
  deleteSession(sessionId: string): Promise<boolean>;
}

export async function createOrchestrator(): Promise<ModelOrchestrator> {
  let config = await loadConfiguration();
  const sessionStore = new SessionStore();
  const registry = new ProviderRegistry(config.providers ?? []);
  const engine = new ConversationEngine(sessionStore, registry);

  if (config.sessions) {
    sessionStore.hydrate(config.sessions);
  }

  return {
    async processChat(request) {
      const session = await engine.handleRequest(request);
      config = {
        ...config,
        providers: registry.listProviders(),
        sessions: sessionStore.serialize()
      };
      await persistConfiguration(config);
      return session;
    },
    async getSession(sessionId) {
      if (!sessionStore.hasSession(sessionId)) {
        return null;
      }
      return sessionStore.getSessionState(sessionId);
    },
    async listConfigurations() {
      return {
        providers: registry.listProviders(),
        sessions: sessionStore.serialize(),
        systemPrompts: config.systemPrompts
      };
    },
    async updateConfigurations(payload) {
      registry.upsertProviders(payload.providers ?? []);
      if (payload.sessions) {
        sessionStore.hydrate(payload.sessions);
      }
      config = {
        ...config,
        providers: registry.listProviders(),
        systemPrompts: payload.systemPrompts ?? config.systemPrompts,
        sessions: sessionStore.serialize()
      };
      await persistConfiguration(config);
      return config;
    },
    async createSession(payload) {
      const session = sessionStore.createSession(payload.systemPrompt, payload.title);
      config = {
        ...config,
        sessions: sessionStore.serialize()
      };
      await persistConfiguration(config);
      return session;
    },
    async deleteSession(sessionId) {
      const removed = sessionStore.deleteSession(sessionId);
      if (!removed) {
        return false;
      }
      config = {
        ...config,
        sessions: sessionStore.serialize()
      };
      await persistConfiguration(config);
      return true;
    }
  };
}
