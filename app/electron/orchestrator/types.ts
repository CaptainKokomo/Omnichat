import type { ProviderMessage, SessionState, ToolCall } from '../../shared/types/chat';

export type ProviderType = 'openai' | 'claude' | 'gemini' | 'copilot' | 'ollama' | 'mock' | 'custom';

export interface ProviderConfig {
  id: string;
  label: string;
  type: ProviderType;
  enabled: boolean;
  apiKey?: string;
  baseUrl?: string;
  model?: string;
  options?: Record<string, unknown>;
}

export interface ProviderGenerateRequest {
  sessionId: string;
  input: string;
  history: ProviderMessage[];
  tools: ToolCall[];
  systemPrompt?: string;
}

export interface ProviderGenerateResponse {
  content: string;
  metadata?: Record<string, unknown>;
}

export interface ProviderInstance {
  readonly id: string;
  readonly config: ProviderConfig;
  generate(request: ProviderGenerateRequest): Promise<ProviderGenerateResponse>;
}

export interface PersistedConfig {
  providers: ProviderConfig[];
  systemPrompts: Record<string, string>;
  sessions?: SessionState[];
}
