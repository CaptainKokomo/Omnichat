import type { ChatMessage } from '../types/chat';

interface MessageBubbleProps {
  message: ChatMessage;
}

export function MessageBubble({ message }: MessageBubbleProps): JSX.Element {
  const isUser = message.role === 'user';
  return (
    <article className={`message-bubble ${isUser ? 'user' : 'assistant'}`}>
      <header>
        <span className="model">{isUser ? 'You' : message.modelId}</span>
        <time>{new Date(message.createdAt).toLocaleTimeString()}</time>
      </header>
      <p>{message.content}</p>
      {message.metadata && !isUser ? (
        <footer>
          {Object.entries(message.metadata).map(([key, value]) => (
            <span key={key} className="metadata-chip">
              {key}: {String(value)}
            </span>
          ))}
        </footer>
      ) : null}
    </article>
  );
}
