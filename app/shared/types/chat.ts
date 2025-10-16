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

export type ProviderType = 'mock' | 'ollama' | 'browser-tab' | 'custom';

export interface OllamaProviderOptions {
  baseUrl?: string;
  model?: string;
  stream?: boolean;
  keepAlive?: boolean;
}

export interface BrowserTabProviderOptions {
  url: string;
  readySelector?: string;
  waitTimeoutMs?: number;
  script?: string;
  initScript?: string;
  showWindow?: boolean;
  width?: number;
  height?: number;
}

export interface ProviderConfigPayloadBase<TType extends ProviderType = ProviderType> {
  id: string;
  label: string;
  type: TType;
  enabled: boolean;
  apiKey?: string;
  baseUrl?: string;
  model?: string;
}

export type ProviderConfigPayload<TType extends ProviderType = ProviderType> = ProviderConfigPayloadBase<TType> &
  (TType extends 'ollama'
    ? { options?: Partial<OllamaProviderOptions> }
    : TType extends 'browser-tab'
    ? { options?: Partial<BrowserTabProviderOptions> }
    : { options?: Record<string, unknown> });

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
