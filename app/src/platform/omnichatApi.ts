import { v4 as uuid } from 'uuid';
import type {
  BrowserTabProviderOptions,
  ChatMessage,
  ChatRequest,
  ModelConfigPayload,
  OllamaProviderOptions,
  ProviderConfigPayload,
  SessionCreatePayload,
  SessionState
} from '../types/chat';

export interface OmnichatAPI {
  sendChat(request: ChatRequest): Promise<SessionState>;
  getSession(sessionId: string): Promise<SessionState | null>;
  listConfigs(): Promise<ModelConfigPayload>;
  updateConfigs(payload: ModelConfigPayload): Promise<ModelConfigPayload>;
  createSession(payload: SessionCreatePayload): Promise<SessionState>;
  deleteSession(sessionId: string): Promise<boolean>;
}

const DEFAULT_SYSTEM_PROMPT = 'You are Omnichat, a helpful multi-model assistant.';
const DEFAULT_SESSION_TITLE = 'Getting started';

const DEFAULT_BROWSER_SCRIPT = `async function handlePrompt(ctx) {
  if (window.omnichatBridge && typeof window.omnichatBridge.handlePrompt === 'function') {
    const reply = await window.omnichatBridge.handlePrompt(ctx);
    if (typeof reply === 'string') {
      return reply;
    }
    if (reply && typeof reply === 'object' && 'content' in reply) {
      return String(reply.content ?? '');
    }
    return JSON.stringify(reply ?? {});
  }
  return 'window.omnichatBridge.handlePrompt(ctx) is not defined in this tab.';
}`;

const DEFAULT_PROVIDERS: ProviderConfigPayload[] = [
  { id: 'mock-gpt', label: 'Mock GPT', type: 'mock', enabled: true },
  { id: 'mock-claude', label: 'Mock Claude', type: 'mock', enabled: true },
  {
    id: 'ollama-local',
    label: 'Ollama (local)',
    type: 'ollama',
    enabled: false,
    model: 'llama3',
    baseUrl: 'http://127.0.0.1:11434',
    options: { keepAlive: true, stream: false } satisfies Partial<OllamaProviderOptions>
  },
  {
    id: 'browser-bridge',
    label: 'Browser Bridge',
    type: 'browser-tab',
    enabled: false,
    options: {
      url: 'http://localhost:3000',
      script: DEFAULT_BROWSER_SCRIPT,
      waitTimeoutMs: 15000
    } satisfies Partial<BrowserTabProviderOptions>
  }
];

function cloneProvider(provider: ProviderConfigPayload): ProviderConfigPayload {
  return {
    ...provider,
    options: provider.options ? { ...provider.options } : undefined
  };
}

function cloneProviders(providers: ProviderConfigPayload[]): ProviderConfigPayload[] {
  return providers.map(cloneProvider);
}

function cloneMessage(message: ChatMessage): ChatMessage {
  return {
    ...message,
    metadata: message.metadata ? { ...message.metadata } : undefined
  };
}

function cloneSession(session: SessionState): SessionState {
  return {
    ...session,
    history: session.history.map(cloneMessage)
  };
}

function deriveTitle(history: ChatMessage[], systemPrompt?: string, fallbackTitle?: string): string {
  const firstUser = history.find((message) => message.role === 'user');
  if (firstUser && firstUser.content.trim().length > 0) {
    return firstUser.content.slice(0, 48);
  }
  if (fallbackTitle && fallbackTitle.trim().length > 0) {
    return fallbackTitle;
  }
  if (systemPrompt && systemPrompt.trim().length > 0) {
    return systemPrompt.slice(0, 48);
  }
  return 'New conversation';
}

function createSessionState(systemPrompt?: string, title?: string, sessionId?: string): SessionState {
  const createdAt = new Date().toISOString();
  return {
    sessionId: sessionId ?? uuid(),
    systemPrompt,
    title: deriveTitle([], systemPrompt, title ?? DEFAULT_SESSION_TITLE),
    createdAt,
    updatedAt: createdAt,
    history: []
  };
}

function createFallbackApi(): OmnichatAPI {
  let providers = cloneProviders(DEFAULT_PROVIDERS);
  let sessions: SessionState[] = [createSessionState(DEFAULT_SYSTEM_PROMPT, DEFAULT_SESSION_TITLE)];
  let systemPrompts: Record<string, string> = {};

  function storeSession(session: SessionState): SessionState {
    const normalized: SessionState = {
      ...session,
      title: deriveTitle(session.history, session.systemPrompt, session.title),
      createdAt: session.createdAt ?? new Date().toISOString(),
      updatedAt: session.updatedAt ?? new Date().toISOString(),
      history: session.history.map(cloneMessage)
    };
    const index = sessions.findIndex((entry) => entry.sessionId === normalized.sessionId);
    if (index >= 0) {
      sessions[index] = normalized;
    } else {
      sessions.push(normalized);
    }
    return normalized;
  }

  function selectProviders(modelIds?: string[]): ProviderConfigPayload[] {
    if (modelIds && modelIds.length > 0) {
      const requested = providers.filter((provider) => modelIds.includes(provider.id));
      if (requested.length > 0) {
        return requested;
      }
    }
    const enabled = providers.filter((provider) => provider.enabled);
    if (enabled.length > 0) {
      return enabled;
    }
    return providers.length > 0 ? [providers[0]] : [];
  }

  return {
    async sendChat(request) {
      const existing = request.sessionId
        ? sessions.find((session) => session.sessionId === request.sessionId)
        : undefined;
      const workingSession = existing
        ? cloneSession(existing)
        : createSessionState(request.systemPrompt, undefined, request.sessionId);
      const history = [...workingSession.history];
      const now = new Date().toISOString();

      history.push({
        id: uuid(),
        role: 'user',
        content: request.message,
        createdAt: now,
        modelId: 'user'
      });

      const activeProviders = selectProviders(request.modelIds);
      const systemPrompt = request.systemPrompt ?? workingSession.systemPrompt;

      activeProviders.forEach((provider) => {
        history.push({
          id: uuid(),
          role: 'assistant',
          content:
            provider.type === 'mock'
              ? `(${provider.label}) ${request.message ? `Echo: ${request.message}` : 'Ready to help.'}`
              : provider.type === 'ollama'
              ? `${provider.label} is disabled. Start Ollama locally and enable the provider to stream real responses.`
              : provider.type === 'browser-tab'
              ? `${provider.label} is waiting for a bridge script. Expose window.omnichatBridge.handlePrompt(ctx) in the target tab to exchange messages.`
              : `${provider.label} is disabled. Enable or configure the provider to activate replies.`,
          createdAt: new Date().toISOString(),
          modelId: provider.id,
          metadata: { provider: provider.id, mock: true }
        });
      });

      const updatedSession: SessionState = {
        ...workingSession,
        systemPrompt,
        history,
        updatedAt: new Date().toISOString(),
        title: deriveTitle(history, systemPrompt, workingSession.title)
      };
      const persisted = storeSession(updatedSession);
      return cloneSession(persisted);
    },

    async getSession(sessionId) {
      const session = sessions.find((entry) => entry.sessionId === sessionId);
      return session ? cloneSession(session) : null;
    },

    async listConfigs() {
      return {
        providers: cloneProviders(providers),
        sessions: sessions.map(cloneSession),
        systemPrompts: { ...systemPrompts }
      };
    },

    async updateConfigs(payload) {
      if (payload.providers) {
        providers = cloneProviders(payload.providers);
      }
      if (payload.sessions) {
        sessions = [];
        payload.sessions.forEach((session) => {
          const normalizedHistory = session.history.map(cloneMessage);
          sessions.push({
            ...session,
            history: normalizedHistory,
            title: deriveTitle(normalizedHistory, session.systemPrompt, session.title),
            createdAt: session.createdAt ?? new Date().toISOString(),
            updatedAt: session.updatedAt ?? session.createdAt ?? new Date().toISOString()
          });
        });
        if (sessions.length === 0) {
          sessions = [createSessionState(DEFAULT_SYSTEM_PROMPT, DEFAULT_SESSION_TITLE)];
        }
      }
      if (payload.systemPrompts) {
        systemPrompts = { ...payload.systemPrompts };
      }
      return {
        providers: cloneProviders(providers),
        sessions: sessions.map(cloneSession),
        systemPrompts: { ...systemPrompts }
      };
    },

    async createSession(payload) {
      const session = createSessionState(payload.systemPrompt, payload.title);
      const persisted = storeSession(session);
      return cloneSession(persisted);
    },

    async deleteSession(sessionId) {
      const originalLength = sessions.length;
      sessions = sessions.filter((session) => session.sessionId !== sessionId);
      const removed = sessions.length !== originalLength;
      if (sessions.length === 0) {
        sessions.push(createSessionState(DEFAULT_SYSTEM_PROMPT, DEFAULT_SESSION_TITLE));
      }
      return removed;
    }
  };
}

let cachedApi: OmnichatAPI | null = null;

export function getOmnichatApi(): OmnichatAPI {
  if (typeof window !== 'undefined' && window.omnichat) {
    return window.omnichat;
  }
  if (!cachedApi) {
    cachedApi = createFallbackApi();
  }
  return cachedApi;
}
