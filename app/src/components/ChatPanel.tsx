import { useEffect, useMemo, useState } from 'react';
import type { ChatMessage, ProviderConfigPayload } from '../types/chat';
import { MessageBubble } from './MessageBubble';

interface ChatPanelProps {
  messages: ChatMessage[];
  providers: ProviderConfigPayload[];
  onSend: (message: string, modelIds: string[]) => Promise<void>;
  onOpenSettings: () => void;
}

export function ChatPanel({ messages, providers, onSend, onOpenSettings }: ChatPanelProps): JSX.Element {
  const [input, setInput] = useState('');
  const [selectedModels, setSelectedModels] = useState<string[]>([]);

  useEffect(() => {
    const enabled = providers.filter((provider) => provider.enabled).map((provider) => provider.id);
    setSelectedModels((prev) => {
      if (prev.length === 0) {
        return enabled;
      }
      return prev.filter((id) => providers.some((provider) => provider.id === id));
    });
  }, [providers]);

  const isSendDisabled = input.trim().length === 0 || selectedModels.length === 0;

  const handleSend = async () => {
    if (isSendDisabled) return;
    await onSend(input.trim(), selectedModels);
    setInput('');
  };

  const handleSelectModel = (modelId: string) => {
    const provider = providers.find((item) => item.id === modelId);
    if (provider && !provider.enabled) {
      return;
    }
    setSelectedModels((prev) =>
      prev.includes(modelId) ? prev.filter((id) => id !== modelId) : [...prev, modelId]
    );
  };

  const sessionTitle = useMemo(() => {
    const lastUser = [...messages].reverse().find((message) => message.role === 'user');
    return lastUser?.content.slice(0, 48) ?? 'New conversation';
  }, [messages]);

  return (
    <section className="chat-panel">
      <header className="chat-header">
        <div>
          <h1>{sessionTitle}</h1>
          <p>Send a message and watch multiple models respond.</p>
        </div>
        <div className="model-selector">
          {providers.map((model) => (
            <button
              key={model.id}
              type="button"
              className={`${selectedModels.includes(model.id) ? 'active' : ''} ${
                model.enabled ? '' : 'disabled'
              }`}
              disabled={!model.enabled}
              onClick={() => handleSelectModel(model.id)}
            >
              {model.label}
            </button>
          ))}
          <button className="settings" type="button" onClick={onOpenSettings}>
            ⚙️
          </button>
        </div>
      </header>
      <main className="chat-history">
        {messages.map((message) => (
          <MessageBubble key={message.id} message={message} />
        ))}
      </main>
      <footer className="chat-composer">
        <textarea
          value={input}
          placeholder="Ask anything..."
          onChange={(event) => setInput(event.target.value)}
          rows={3}
        />
        <button type="button" onClick={handleSend} disabled={isSendDisabled}>
          Send
        </button>
      </footer>
    </section>
  );
}
