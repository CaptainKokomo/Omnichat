import { useEffect, useState } from 'react';
import type { ModelConfigPayload, ProviderConfigPayload } from '../types/chat';
import type { OmnichatAPI } from '../platform/omnichatApi';

interface SettingsDrawerProps {
  open: boolean;
  providers: ProviderConfigPayload[];
  api: OmnichatAPI;
  onClose: () => void;
  onProvidersChange: (providers: ProviderConfigPayload[]) => void;
  onPersist: () => Promise<void>;
}

export function SettingsDrawer({
  open,
  providers,
  api,
  onClose,
  onProvidersChange,
  onPersist
}: SettingsDrawerProps): JSX.Element {
  const [localProviders, setLocalProviders] = useState<ProviderConfigPayload[]>(providers);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setLocalProviders(providers);
  }, [providers, open]);

  const toggleProvider = (providerId: string) => {
    setLocalProviders((prev) =>
      prev.map((provider) =>
        provider.id === providerId ? { ...provider, enabled: !provider.enabled } : provider
      )
    );
  };

  const handleFieldChange = (
    providerId: string,
    field: 'apiKey' | 'baseUrl' | 'model' | 'label',
    value: string
  ) => {
    setLocalProviders((prev) =>
      prev.map((provider) =>
        provider.id === providerId
          ? {
              ...provider,
              [field]: value.length === 0 ? undefined : value
            }
          : provider
      )
    );
  };

  const handleOptionChange = (providerId: string, key: string, value: string | boolean | number) => {
    setLocalProviders((prev) =>
      prev.map((provider) => {
        if (provider.id !== providerId) {
          return provider;
        }
        const current = (provider.options ?? {}) as Record<string, unknown>;
        const options: Record<string, unknown> = { ...current };
        if (typeof value === 'string') {
          const trimmed = value.trim();
          if (trimmed.length === 0) {
            delete options[key];
          } else {
            options[key] = value;
          }
        } else {
          options[key] = value;
        }
        return {
          ...provider,
          options: Object.keys(options).length === 0 ? undefined : options
        };
      })
    );
  };

  const renderProviderFields = (provider: ProviderConfigPayload) => {
    switch (provider.type) {
      case 'ollama':
        return (
          <div className="provider-fields">
            <label>
              Base URL
              <input
                type="text"
                placeholder="http://127.0.0.1:11434"
                value={provider.baseUrl ?? ''}
                onChange={(event) => handleFieldChange(provider.id, 'baseUrl', event.target.value)}
              />
            </label>
            <label>
              Model
              <input
                type="text"
                placeholder="llama3"
                value={provider.model ?? ''}
                onChange={(event) => handleFieldChange(provider.id, 'model', event.target.value)}
              />
            </label>
            <p className="provider-hint">
              Ensure the Ollama daemon is running locally (<code>ollama serve</code>) and the selected model is pulled.
            </p>
          </div>
        );
      case 'browser-tab': {
        const options = provider.options as Record<string, unknown> | undefined;
        const url = typeof options?.url === 'string' ? options.url : '';
        const script = typeof options?.script === 'string' ? options.script : '';
        const waitTimeoutMs =
          typeof options?.waitTimeoutMs === 'number' ? String(options.waitTimeoutMs) : '';
        const showWindow = typeof options?.showWindow === 'boolean' ? options.showWindow : false;

        return (
          <div className="provider-fields">
            <label>
              Tab URL
              <input
                type="text"
                placeholder="http://localhost:3000"
                value={url}
                onChange={(event) => handleOptionChange(provider.id, 'url', event.target.value)}
              />
            </label>
            <label>
              Wait timeout (ms)
              <input
                type="number"
                min={1000}
                step={500}
                value={waitTimeoutMs}
                onChange={(event) => {
                  const numeric = Number(event.target.value);
                  handleOptionChange(
                    provider.id,
                    'waitTimeoutMs',
                    Number.isNaN(numeric) ? '' : numeric
                  );
                }}
              />
            </label>
            <label>
              Bridge script
              <textarea
                rows={6}
                spellCheck={false}
                value={script}
                onChange={(event) => handleOptionChange(provider.id, 'script', event.target.value)}
              />
            </label>
            <label className="checkbox-inline">
              <input
                type="checkbox"
                checked={showWindow}
                onChange={(event) => handleOptionChange(provider.id, 'showWindow', event.target.checked)}
              />
              Keep the browser tab visible during conversations
            </label>
            <p className="provider-hint">
              The script runs inside the target page. Expose <code>window.omnichatBridge.handlePrompt(ctx)</code> or
              customize the script to control the page DOM.
            </p>
          </div>
        );
      }
      case 'custom':
      default:
        return null;
    }
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      const payload: ModelConfigPayload = {
        providers: localProviders
      };
      await api.updateConfigs(payload);
      await onPersist();
      onProvidersChange(localProviders);
      onClose();
    } finally {
      setSaving(false);
    }
  };

  return (
    <aside className={`settings-drawer ${open ? 'open' : ''}`}>
      <header>
        <h2>Model Settings</h2>
        <button type="button" onClick={onClose}>
          ✕
        </button>
      </header>
      <section>
        <h3>Enabled Models</h3>
        <ul>
          {localProviders.map((provider) => (
            <li key={provider.id}>
              <div className="provider-toggle">
                <label>
                  <input
                    type="checkbox"
                    checked={provider.enabled}
                    onChange={() => toggleProvider(provider.id)}
                  />
                  <span>
                    {provider.label}
                    <small>{provider.type}</small>
                  </span>
                </label>
              </div>
              {renderProviderFields(provider)}
            </li>
          ))}
          {localProviders.length === 0 ? <p>No providers configured yet.</p> : null}
        </ul>
      </section>
      <footer>
        <button type="button" onClick={handleSave} disabled={saving || localProviders.length === 0}>
          {saving ? 'Saving…' : 'Save changes'}
        </button>
      </footer>
    </aside>
  );
}
