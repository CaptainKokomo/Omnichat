export type Role = 'user' | 'assistant' | 'system';

export interface ChatMessage {
  id: string;
  role: Role;
  content: string;
  createdAt: string;
  modelId: string;
  metadata?: Record<string, unknown>;
}

export interface ToolCall {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
}

export interface ChatRequest {
  sessionId?: string;
  systemPrompt?: string;
  message: string;
  modelIds?: string[];
  tools?: ToolCall[];
}

export interface ProviderMessage {
  role: Role;
  content: string;
  modelId: string;
}

export interface ProviderConfigPayload {
  id: string;
  label: string;
  type: string;
  enabled: boolean;
  apiKey?: string;
  baseUrl?: string;
  model?: string;
  options?: Record<string, unknown>;
}

export interface SessionState {
  sessionId: string;
  systemPrompt?: string;
  title?: string;
  createdAt: string;
  updatedAt: string;
  history: ChatMessage[];
}

export interface SessionCreatePayload {
  systemPrompt?: string;
  title?: string;
}

export interface SessionDeletePayload {
  sessionId: string;
}

export interface ModelConfigPayload {
  providers?: ProviderConfigPayload[];
  sessions?: SessionState[];
  systemPrompts?: Record<string, string>;
}

export interface SessionSummary {
  sessionId: string;
  title: string;
  lastUpdated: string;
}
