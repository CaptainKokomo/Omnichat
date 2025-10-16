import { useCallback, useEffect, useMemo, useState } from 'react';
import { useChatStore } from './state/useChatStore';
import { ChatPanel } from './components/ChatPanel';
import { SessionSidebar } from './components/SessionSidebar';
import { SettingsDrawer } from './components/SettingsDrawer';
import { getOmnichatApi } from './platform/omnichatApi';
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
  const api = useMemo(() => getOmnichatApi(), []);
  const currentMessages = useMemo(
    () => (currentSessionId ? sessions[currentSessionId] ?? [] : []),
    [sessions, currentSessionId]
  );

  const refreshConfiguration = useCallback(async () => {
    const config = await api.listConfigs();
    hydrateSessions(config.sessions ?? []);
    setProviders(config.providers ?? []);
    if (!config.sessions || config.sessions.length === 0) {
      const session = await api.createSession({});
      ensureSession(session);
      setCurrentSession(session.sessionId);
    }
  }, [api, ensureSession, hydrateSessions, setCurrentSession]);

  useEffect(() => {
    void refreshConfiguration();
  }, [refreshConfiguration]);

  useEffect(() => {
    if (!currentSessionId) {
      return;
    }
    api.getSession(currentSessionId).then((session) => {
      if (session) {
        upsertSession(session);
      }
    });
  }, [api, currentSessionId, upsertSession]);

  const ensureActiveSession = useCallback(async (): Promise<SessionState> => {
    if (currentSessionId) {
      const session = await api.getSession(currentSessionId);
      if (session) {
        upsertSession(session);
        return session;
      }
    }
    const created = await api.createSession({});
    ensureSession(created);
    setCurrentSession(created.sessionId);
    return created;
  }, [api, currentSessionId, ensureSession, setCurrentSession, upsertSession]);

  const handleSend = useCallback(
    async (message: string, modelIds: string[]) => {
      const session = await ensureActiveSession();
      const response = await api.sendChat({
        sessionId: session.sessionId,
        message,
        modelIds
      });
      upsertSession(response);
      setCurrentSession(response.sessionId);
    },
    [api, ensureActiveSession, setCurrentSession, upsertSession]
  );

  const handleCreateSession = useCallback(async () => {
    const session = await api.createSession({});
    ensureSession(session);
    setCurrentSession(session.sessionId);
  }, [api, ensureSession, setCurrentSession]);

  const handleDeleteSession = useCallback(
    async (sessionId: string) => {
      const success = await api.deleteSession(sessionId);
      if (!success) {
        return;
      }
      removeSession(sessionId);
      const nextSessionId = useChatStore.getState().currentSessionId;
      if (!nextSessionId) {
        const session = await api.createSession({});
        ensureSession(session);
        setCurrentSession(session.sessionId);
      }
    },
    [api, ensureSession, removeSession, setCurrentSession]
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
        api={api}
        onClose={() => setSettingsOpen(false)}
        onProvidersChange={setProviders}
        onPersist={refreshConfiguration}
      />
    </div>
  );
}

export default App;
