import path from 'path';
import { app } from 'electron';
import { promises as fs } from 'fs';
import type { PersistedConfig } from '../types';
import type { ProviderConfigPayload, SessionState } from '@shared/types/chat';

const CONFIG_FILE = 'settings.json';

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
    options: { keepAlive: true, stream: false }
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
    }
  }
];

function mergeProviderDefaults(existing: ProviderConfigPayload[] | undefined): ProviderConfigPayload[] {
  if (!existing || existing.length === 0) {
    return [...DEFAULT_PROVIDERS];
  }

  const merged = new Map(existing.map((provider) => [provider.id, provider]));
  for (const provider of DEFAULT_PROVIDERS) {
    if (!merged.has(provider.id)) {
      merged.set(provider.id, provider);
    }
  }
  return Array.from(merged.values());
}

async function resolveConfigPath(): Promise<string> {
  const userData = app.getPath('userData');
  return path.join(userData, CONFIG_FILE);
}

export async function loadConfiguration(): Promise<PersistedConfig> {
  const configPath = await resolveConfigPath();
  try {
    const raw = await fs.readFile(configPath, 'utf-8');
    const parsed = JSON.parse(raw) as PersistedConfig;
    const providers = mergeProviderDefaults(parsed.providers);
    return {
      providers,
      systemPrompts: parsed.systemPrompts ?? {},
      sessions: parsed.sessions ?? []
    };
  } catch (error) {
    const now = new Date().toISOString();
    const defaultSession: SessionState = {
      sessionId: 'default',
      title: 'Getting started',
      systemPrompt: 'You are Omnichat, a helpful multi-model assistant.',
      createdAt: now,
      updatedAt: now,
      history: []
    };
    const defaultConfig: PersistedConfig = {
      providers: [...DEFAULT_PROVIDERS],
      systemPrompts: {},
      sessions: [defaultSession]
    };
    await persistConfiguration(defaultConfig);
    return defaultConfig;
  }
}

export async function persistConfiguration(config: PersistedConfig): Promise<void> {
  const configPath = await resolveConfigPath();
  await fs.mkdir(path.dirname(configPath), { recursive: true });
  await fs.writeFile(configPath, JSON.stringify(config, null, 2), 'utf-8');
}
