import { ProviderInstance, ProviderConfig, ProviderGenerateRequest, ProviderGenerateResponse } from '../types';

export class MockProvider implements ProviderInstance {
  readonly id: string;
  readonly config: ProviderConfig;

  constructor(config: ProviderConfig) {
    this.id = config.id;
    this.config = config;
  }

  async generate(request: ProviderGenerateRequest): Promise<ProviderGenerateResponse> {
    const reflection = request.history
      .slice(-3)
      .map((msg) => `${msg.modelId}: ${msg.content}`)
      .join('\n');

    return {
      content: `🤖 Mock response from ${this.config.label}\n---\nLast turns:\n${reflection}\n---\nEcho: ${request.input}`,
      metadata: {
        provider: 'mock',
        latencyMs: Math.round(Math.random() * 120) + 30
      }
    };
  }
}
