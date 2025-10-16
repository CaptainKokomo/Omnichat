import type { ProviderConfigPayload, ProviderMessage, SessionState, ToolCall } from '@shared/types/chat';

export type ProviderConfig = ProviderConfigPayload;

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
  dispose?(): Promise<void> | void;
}

export interface PersistedConfig {
  providers: ProviderConfig[];
  systemPrompts: Record<string, string>;
  sessions?: SessionState[];
}
