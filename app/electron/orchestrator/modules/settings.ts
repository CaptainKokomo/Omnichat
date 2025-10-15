import path from 'path';
import { app } from 'electron';
import { promises as fs } from 'fs';
import type { PersistedConfig } from '../types';
import type { SessionState } from '@shared/types/chat';

const CONFIG_FILE = 'settings.json';

async function resolveConfigPath(): Promise<string> {
  const userData = app.getPath('userData');
  return path.join(userData, CONFIG_FILE);
}

export async function loadConfiguration(): Promise<PersistedConfig> {
  const configPath = await resolveConfigPath();
  try {
    const raw = await fs.readFile(configPath, 'utf-8');
    const parsed = JSON.parse(raw) as PersistedConfig;
    const providers = [...(parsed.providers ?? [])];
    if (!providers.some((provider) => provider.id === 'openai-gpt-4o-mini')) {
      providers.push({
        id: 'openai-gpt-4o-mini',
        label: 'OpenAI GPT-4o mini',
        type: 'openai',
        enabled: false,
        model: 'gpt-4o-mini',
        baseUrl: 'https://api.openai.com/v1'
      });
    }
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
      providers: [
        {
          id: 'mock-gpt',
          label: 'Mock GPT',
          type: 'mock',
          enabled: true
        },
        {
          id: 'mock-claude',
          label: 'Mock Claude',
          type: 'mock',
          enabled: true
        },
        {
          id: 'openai-gpt-4o-mini',
          label: 'OpenAI GPT-4o mini',
          type: 'openai',
          enabled: false,
          model: 'gpt-4o-mini',
          baseUrl: 'https://api.openai.com/v1'
        }
      ],
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
