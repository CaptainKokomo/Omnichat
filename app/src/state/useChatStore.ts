import create from 'zustand';
import type { ChatMessage, SessionState, SessionSummary } from '../types/chat';

interface ChatState {
  currentSessionId: string | null;
  sessions: Record<string, ChatMessage[]>;
  sessionSummaries: SessionSummary[];
  setCurrentSession: (sessionId: string) => void;
  upsertSession: (session: SessionState) => void;
  hydrateSessions: (sessions: SessionState[]) => void;
  ensureSession: (session: SessionState) => void;
  removeSession: (sessionId: string) => void;
}

function deriveSummary(session: SessionState): SessionSummary {
  return {
    sessionId: session.sessionId,
    title: session.title ?? 'New conversation',
    lastUpdated: session.updatedAt ?? new Date().toISOString()
  };
}

export const useChatStore = create<ChatState>((set) => ({
  currentSessionId: null,
  sessions: {},
  sessionSummaries: [],
  setCurrentSession: (sessionId) => set({ currentSessionId: sessionId }),
  upsertSession: (session) =>
    set((state) => {
      const summary = deriveSummary(session);
      const existingSummaries = state.sessionSummaries.filter(
        (entry) => entry.sessionId !== session.sessionId
      );
      return {
        sessions: { ...state.sessions, [session.sessionId]: session.history },
        sessionSummaries: [...existingSummaries, summary].sort((a, b) =>
          new Date(b.lastUpdated).getTime() - new Date(a.lastUpdated).getTime()
        ),
        currentSessionId: state.currentSessionId ?? session.sessionId
      };
    }),
  hydrateSessions: (sessions) => {
    set((state) => {
      const sorted = [...sessions].sort(
        (a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
      );
      const summaries = sorted.map(deriveSummary);
      const sessionMap: Record<string, ChatMessage[]> = {};
      sorted.forEach((session) => {
        sessionMap[session.sessionId] = session.history ?? [];
      });
      const nextCurrent = state.currentSessionId && sessionMap[state.currentSessionId]
        ? state.currentSessionId
        : sorted[0]?.sessionId ?? null;
      return {
        sessions: sessionMap,
        sessionSummaries: summaries,
        currentSessionId: nextCurrent
      };
    });
  },
  ensureSession: (session) =>
    set((state) => {
      if (state.sessions[session.sessionId]) {
        return state;
      }
      const summary = deriveSummary(session);
      return {
        sessions: { ...state.sessions, [session.sessionId]: session.history ?? [] },
        sessionSummaries: [summary, ...state.sessionSummaries].sort((a, b) =>
          new Date(b.lastUpdated).getTime() - new Date(a.lastUpdated).getTime()
        ),
        currentSessionId: session.sessionId
      };
    }),
  removeSession: (sessionId) =>
    set((state) => {
      if (!state.sessions[sessionId]) {
        return state;
      }
      const { [sessionId]: _removed, ...remaining } = state.sessions;
      const summaries = state.sessionSummaries.filter((entry) => entry.sessionId !== sessionId);
      const nextCurrent =
        state.currentSessionId === sessionId ? summaries[0]?.sessionId ?? null : state.currentSessionId;
      return {
        sessions: remaining,
        sessionSummaries: summaries,
        currentSessionId: nextCurrent
      };
    })
}));
