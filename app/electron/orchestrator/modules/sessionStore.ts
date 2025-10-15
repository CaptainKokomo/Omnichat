import { v4 as uuid } from 'uuid';
import type { ChatMessage, SessionState } from '@shared/types/chat';

interface SessionMetadata {
  title: string;
  systemPrompt?: string;
  createdAt: string;
  updatedAt: string;
}

export class SessionStore {
  private sessions: Map<string, ChatMessage[]> = new Map();
  private metadata: Map<string, SessionMetadata> = new Map();

  createSession(systemPrompt?: string, title?: string): SessionState {
    const sessionId = uuid();
    const createdAt = new Date().toISOString();
    const initialTitle = this.deriveTitle([], systemPrompt, title);
    this.sessions.set(sessionId, []);
    this.metadata.set(sessionId, {
      title: initialTitle,
      systemPrompt,
      createdAt,
      updatedAt: createdAt
    });
    return this.getSessionState(sessionId);
  }

  getOrCreate(sessionId: string, systemPrompt?: string): ChatMessage[] {
    if (!this.sessions.has(sessionId)) {
      const createdAt = new Date().toISOString();
      this.sessions.set(sessionId, []);
      this.metadata.set(sessionId, {
        title: this.deriveTitle([], systemPrompt),
        systemPrompt,
        createdAt,
        updatedAt: createdAt
      });
    } else if (systemPrompt) {
      const existing = this.metadata.get(sessionId);
      if (existing) {
        this.metadata.set(sessionId, { ...existing, systemPrompt });
      }
    }
    return this.getHistory(sessionId);
  }

  getHistory(sessionId: string): ChatMessage[] {
    return [...(this.sessions.get(sessionId) ?? [])];
  }

  setHistory(sessionId: string, history: ChatMessage[]): void {
    this.sessions.set(sessionId, [...history]);
    this.touchMetadata(sessionId, history);
  }

  hasSession(sessionId: string): boolean {
    return this.sessions.has(sessionId);
  }

  getSessionState(sessionId: string): SessionState {
    const history = this.getHistory(sessionId);
    const metadata = this.metadata.get(sessionId);
    const fallbackTimestamp = new Date().toISOString();
    return {
      sessionId,
      history,
      systemPrompt: metadata?.systemPrompt,
      title: metadata?.title ?? this.deriveTitle(history, metadata?.systemPrompt),
      createdAt: metadata?.createdAt ?? fallbackTimestamp,
      updatedAt: metadata?.updatedAt ?? fallbackTimestamp
    };
  }

  listSummaries(): SessionState[] {
    return Array.from(this.sessions.keys()).map((sessionId) => this.getSessionState(sessionId));
  }

  serialize(): SessionState[] {
    return this.listSummaries().map((session) => ({
      ...session,
      history: [...session.history]
    }));
  }

  hydrate(sessions: SessionState[]): void {
    this.sessions.clear();
    this.metadata.clear();
    sessions.forEach((session) => {
      this.sessions.set(session.sessionId, [...(session.history ?? [])]);
      this.metadata.set(session.sessionId, {
        title: this.deriveTitle(session.history ?? [], session.systemPrompt, session.title),
        systemPrompt: session.systemPrompt,
        createdAt: session.createdAt ?? new Date().toISOString(),
        updatedAt: session.updatedAt ?? new Date().toISOString()
      });
    });
  }

  deleteSession(sessionId: string): boolean {
    const removedHistory = this.sessions.delete(sessionId);
    this.metadata.delete(sessionId);
    return removedHistory;
  }

  private touchMetadata(sessionId: string, history: ChatMessage[]): void {
    const metadata = this.metadata.get(sessionId);
    const updatedAt = new Date().toISOString();
    const title = this.deriveTitle(history, metadata?.systemPrompt, metadata?.title);
    if (metadata) {
      this.metadata.set(sessionId, {
        ...metadata,
        title,
        updatedAt
      });
    } else {
      this.metadata.set(sessionId, {
        title,
        systemPrompt: undefined,
        createdAt: updatedAt,
        updatedAt
      });
    }
  }

  private deriveTitle(
    history: ChatMessage[],
    systemPrompt?: string,
    fallbackTitle?: string
  ): string {
    const firstUser = history.find((message) => message.role === 'user');
    if (firstUser) {
      return firstUser.content.slice(0, 48) || 'New conversation';
    }
    if (systemPrompt) {
      return systemPrompt.slice(0, 48) || 'Configured session';
    }
    if (fallbackTitle) {
      return fallbackTitle;
    }
    return 'New conversation';
  }
}
