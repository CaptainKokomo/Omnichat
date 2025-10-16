import { MockProvider } from '../providers/mockProvider';
import { OllamaProvider } from '../providers/ollamaProvider';
import { BrowserTabProvider } from '../providers/browserTabProvider';
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
    const nextProviders = new Map<string, ProviderInstance>();

    for (const config of configs) {
      const existing = this.providers.get(config.id);
      this.disposeProvider(existing, `replacing provider ${config.id}`);

      const instance = this.instantiate(config);
      nextProviders.set(config.id, instance);
    }

    for (const [id, instance] of this.providers.entries()) {
      if (!nextProviders.has(id)) {
        this.disposeProvider(instance, `removing provider ${id}`);
      }
    }

    this.providers = nextProviders;
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
      case 'ollama':
        return new OllamaProvider(config);
      case 'browser-tab':
        return new BrowserTabProvider(config);
      case 'mock':
      default:
        return new MockProvider(config);
    }
  }

  private disposeProvider(instance: ProviderInstance | undefined, context: string): void {
    if (!instance || typeof instance.dispose !== 'function') {
      return;
    }

    try {
      const result = instance.dispose();
      if (result && typeof (result as Promise<unknown>).catch === 'function') {
        (result as Promise<unknown>).catch((error) =>
          console.warn('Provider disposal rejected', context, error)
        );
      }
    } catch (error) {
      console.warn('Failed to dispose provider', context, error);
    }
  }
}
