import { MockProvider } from '../providers/mockProvider';
import { OpenAIProvider } from '../providers/openaiProvider';
import type { ProviderConfig, ProviderInstance } from '../types';

export class ProviderRegistry {
  private providers: Map<string, ProviderInstance> = new Map();

  constructor(initialConfigs: ProviderConfig[] = []) {
    this.upsertProviders(initialConfigs);

    if (this.providers.size === 0) {
      const mock = new MockProvider({
        id: 'mock-gpt',
        label: 'Mock GPT',
        type: 'mock',
        enabled: true
      });
      this.providers.set(mock.id, mock);
    }
  }

  listProviders(): ProviderConfig[] {
    return Array.from(this.providers.values()).map((provider) => provider.config);
  }

  upsertProviders(configs: ProviderConfig[]): void {
    for (const config of configs) {
      const instance = this.instantiate(config);
      this.providers.set(config.id, instance);
    }
  }

  getActiveProviders(modelIds?: string[]): ProviderInstance[] {
    const available = Array.from(this.providers.values()).filter((provider) => provider.config.enabled);
    if (!modelIds || modelIds.length === 0) {
      return available;
    }
    return available.filter((provider) => modelIds.includes(provider.id));
  }

  private instantiate(config: ProviderConfig): ProviderInstance {
    switch (config.type) {
      case 'openai':
        return new OpenAIProvider(config);
      case 'mock':
      default:
        return new MockProvider(config);
    }
  }
}
