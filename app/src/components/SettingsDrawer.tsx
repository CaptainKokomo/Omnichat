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

  const handleFieldChange = (providerId: string, field: 'apiKey' | 'baseUrl' | 'model', value: string) => {
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
              {provider.type === 'openai' ? (
                <div className="provider-fields">
                  <label>
                    API Key
                    <input
                      type="password"
                      placeholder="sk-..."
                      value={provider.apiKey ?? ''}
                      onChange={(event) =>
                        handleFieldChange(provider.id, 'apiKey', event.target.value)
                      }
                    />
                  </label>
                  <label>
                    Model
                    <input
                      type="text"
                      placeholder="gpt-4o-mini"
                      value={provider.model ?? ''}
                      onChange={(event) =>
                        handleFieldChange(provider.id, 'model', event.target.value)
                      }
                    />
                  </label>
                  <label>
                    Base URL
                    <input
                      type="text"
                      placeholder="https://api.openai.com/v1"
                      value={provider.baseUrl ?? ''}
                      onChange={(event) =>
                        handleFieldChange(provider.id, 'baseUrl', event.target.value)
                      }
                    />
                  </label>
                </div>
              ) : null}
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
