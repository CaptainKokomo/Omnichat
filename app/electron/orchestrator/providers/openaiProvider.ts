import { fetch } from 'undici';
import type {
  ProviderConfig,
  ProviderGenerateRequest,
  ProviderGenerateResponse,
  ProviderInstance
} from '../types';

interface OpenAIChatCompletionResponse {
  choices?: Array<{
    message?: {
      role?: string;
      content?: string;
    };
    finish_reason?: string;
  }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    total_tokens?: number;
  };
}

export class OpenAIProvider implements ProviderInstance {
  readonly id: string;
  readonly config: ProviderConfig;

  constructor(config: ProviderConfig) {
    this.id = config.id;
    this.config = config;
  }

  private resolveApiKey(): string | undefined {
    return this.config.apiKey || process.env.OPENAI_API_KEY;
  }

  async generate(request: ProviderGenerateRequest): Promise<ProviderGenerateResponse> {
    const apiKey = this.resolveApiKey();
    if (!apiKey) {
      return {
        content:
          '⚠️ Unable to contact OpenAI because no API key is configured. Add a key in Settings to enable this model.',
        metadata: {
          provider: 'openai',
          error: 'missing_api_key'
        }
      };
    }

    const baseUrl = (this.config.baseUrl ?? 'https://api.openai.com/v1').replace(/\/$/, '');
    const model = this.config.model ?? 'gpt-4o-mini';

    const body = {
      model,
      messages: this.buildMessages(request),
      temperature: (this.config.options?.temperature as number | undefined) ?? 0.7
    };

    const response = await fetch(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`
      },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      const errorPayload = await response.text();
      throw new Error(
        `OpenAI request failed (${response.status} ${response.statusText}): ${errorPayload || 'Unknown error'}`
      );
    }

    const payload = (await response.json()) as OpenAIChatCompletionResponse;
    const message = payload.choices?.[0]?.message?.content;

    if (!message) {
      throw new Error('OpenAI response did not contain any message content.');
    }

    return {
      content: message.trim(),
      metadata: {
        provider: 'openai',
        model,
        finishReason: payload.choices?.[0]?.finish_reason,
        usage: payload.usage
      }
    };
  }

  private buildMessages(request: ProviderGenerateRequest) {
    const systemPrompt = request.systemPrompt ?? this.config.options?.systemPrompt;
    const history = request.history.map((message) => ({
      role: message.role,
      content: message.content
    }));

    if (systemPrompt) {
      return [{ role: 'system', content: systemPrompt }, ...history];
    }

    return history;
  }
}

