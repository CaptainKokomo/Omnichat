import { useCallback, useEffect, useMemo, useState } from 'react';
import { useChatStore } from './state/useChatStore';
import { ChatPanel } from './components/ChatPanel';
import { SessionSidebar } from './components/SessionSidebar';
import { SettingsDrawer } from './components/SettingsDrawer';
import type { ProviderConfigPayload, SessionState } from './types/chat';

function App(): JSX.Element {
  const {
    currentSessionId,
    sessions,
    setCurrentSession,
    upsertSession,
    hydrateSessions,
    ensureSession,
    removeSession
  } = useChatStore();
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [providers, setProviders] = useState<ProviderConfigPayload[]>([]);
  const currentMessages = useMemo(
    () => (currentSessionId ? sessions[currentSessionId] ?? [] : []),
    [sessions, currentSessionId]
  );

  const refreshConfiguration = useCallback(async () => {
    const config = await window.omnichat.listConfigs();
    hydrateSessions(config.sessions ?? []);
    setProviders(config.providers ?? []);
    if (!config.sessions || config.sessions.length === 0) {
      const session = await window.omnichat.createSession({});
      ensureSession(session);
      setCurrentSession(session.sessionId);
    }
  }, [ensureSession, hydrateSessions, setCurrentSession]);

  useEffect(() => {
    void refreshConfiguration();
  }, [refreshConfiguration]);

  useEffect(() => {
    if (!currentSessionId) {
      return;
    }
    window.omnichat.getSession(currentSessionId).then((session) => {
      if (session) {
        upsertSession(session);
      }
    });
  }, [currentSessionId, upsertSession]);

  const ensureActiveSession = useCallback(async (): Promise<SessionState> => {
    if (currentSessionId) {
      const session = await window.omnichat.getSession(currentSessionId);
      if (session) {
        upsertSession(session);
        return session;
      }
    }
    const created = await window.omnichat.createSession({});
    ensureSession(created);
    setCurrentSession(created.sessionId);
    return created;
  }, [currentSessionId, ensureSession, setCurrentSession, upsertSession]);

  const handleSend = useCallback(
    async (message: string, modelIds: string[]) => {
      const session = await ensureActiveSession();
      const response = await window.omnichat.sendChat({
        sessionId: session.sessionId,
        message,
        modelIds
      });
      upsertSession(response);
      setCurrentSession(response.sessionId);
    },
    [ensureActiveSession, setCurrentSession, upsertSession]
  );

  const handleCreateSession = useCallback(async () => {
    const session = await window.omnichat.createSession({});
    ensureSession(session);
    setCurrentSession(session.sessionId);
  }, [ensureSession, setCurrentSession]);

  const handleDeleteSession = useCallback(
    async (sessionId: string) => {
      const success = await window.omnichat.deleteSession(sessionId);
      if (!success) {
        return;
      }
      removeSession(sessionId);
      const nextSessionId = useChatStore.getState().currentSessionId;
      if (!nextSessionId) {
        const session = await window.omnichat.createSession({});
        ensureSession(session);
        setCurrentSession(session.sessionId);
      }
    },
    [ensureSession, removeSession, setCurrentSession]
  );

  return (
    <div className="app-shell">
      <SessionSidebar
        activeSessionId={currentSessionId}
        onSelect={setCurrentSession}
        onCreate={handleCreateSession}
        onDelete={handleDeleteSession}
      />
      <ChatPanel
        messages={currentMessages}
        onSend={handleSend}
        onOpenSettings={() => setSettingsOpen(true)}
        providers={providers}
      />
      <SettingsDrawer
        open={settingsOpen}
        providers={providers}
        onClose={() => setSettingsOpen(false)}
        onProvidersChange={setProviders}
        onPersist={refreshConfiguration}
      />
    </div>
  );
}

export default App;
