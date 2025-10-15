import { useChatStore } from '../state/useChatStore';

interface SessionSidebarProps {
  activeSessionId: string | null;
  onSelect: (sessionId: string) => void;
  onCreate: () => void;
  onDelete: (sessionId: string) => void;
}

export function SessionSidebar({ activeSessionId, onSelect, onCreate, onDelete }: SessionSidebarProps): JSX.Element {
  const { sessionSummaries } = useChatStore();

  return (
    <aside className="session-sidebar">
      <header>
        <h2>Sessions</h2>
        <button type="button" className="create-session" onClick={onCreate} aria-label="Create session">
          +
        </button>
      </header>
      {sessionSummaries.length === 0 ? (
        <p className="empty">No conversations yet. Start one to see it here.</p>
      ) : (
        <ul>
          {sessionSummaries.map((session) => (
            <li key={session.sessionId}>
              <div className="session-entry">
                <button
                  type="button"
                  className={`session-select${session.sessionId === activeSessionId ? ' active' : ''}`}
                  onClick={() => onSelect(session.sessionId)}
                >
                  <span>{session.title}</span>
                  <time>{new Date(session.lastUpdated).toLocaleTimeString()}</time>
                </button>
                <button
                  type="button"
                  className="session-delete"
                  onClick={(event) => {
                    event.stopPropagation();
                    onDelete(session.sessionId);
                  }}
                  aria-label={`Delete ${session.title}`}
                >
                  ×
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </aside>
  );
}
