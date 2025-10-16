import { fetch } from 'undici';
import type {
  ProviderConfig,
  ProviderGenerateRequest,
  ProviderGenerateResponse,
  ProviderInstance
} from '../types';
import type { OllamaProviderOptions } from '@shared/types/chat';

interface OllamaChatResponse {
  message?: {
    content?: string;
  };
  response?: string;
  error?: string;
}

function resolveOllamaOptions(config: ProviderConfig): OllamaProviderOptions {
  const options = (config.options ?? {}) as Partial<OllamaProviderOptions>;
  return {
    keepAlive: true,
    stream: false,
    ...options
  } as OllamaProviderOptions;
}

export class OllamaProvider implements ProviderInstance {
  readonly id: string;
  readonly config: ProviderConfig;

  constructor(config: ProviderConfig) {
    this.id = config.id;
    this.config = config;
  }

  async generate(request: ProviderGenerateRequest): Promise<ProviderGenerateResponse> {
    const options = resolveOllamaOptions(this.config);
    const baseUrl = (this.config.baseUrl ?? options.baseUrl ?? 'http://127.0.0.1:11434').replace(/\/$/, '');
    const model = this.config.model ?? options.model ?? 'llama3';

    const messages = request.history.map((message) => ({
      role: message.role,
      content: message.content
    }));

    messages.push({ role: 'user', content: request.input });

    if (request.systemPrompt) {
      messages.unshift({ role: 'system', content: request.systemPrompt });
    }

    const body = {
      model,
      messages,
      stream: options.stream ?? false,
      keep_alive: options.keepAlive ?? true
    };

    const response = await fetch(`${baseUrl}/api/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      const errorPayload = await response.text();
      throw new Error(
        `Ollama request failed (${response.status} ${response.statusText}): ${errorPayload || 'Unknown error'}`
      );
    }

    const payload = (await response.json()) as OllamaChatResponse;
    const content = payload.message?.content ?? payload.response;

    if (payload.error) {
      throw new Error(payload.error);
    }

    if (!content) {
      throw new Error('Ollama response did not contain any message content.');
    }

    return {
      content: content.trim(),
      metadata: {
        provider: 'ollama',
        model,
        baseUrl
      }
    };
  }
}
