import { v4 as uuid } from 'uuid';
import type { ChatRequest, ChatMessage, ProviderMessage, SessionState } from '../../../shared/types/chat';
import type { SessionStore } from './sessionStore';
import type { ProviderRegistry } from './providerRegistry';

export class ConversationEngine {
  constructor(private readonly sessionStore: SessionStore, private readonly registry: ProviderRegistry) {}

  async handleRequest(request: ChatRequest): Promise<SessionState> {
    const sessionId = request.sessionId ?? uuid();
    const session = this.sessionStore.getOrCreate(sessionId, request.systemPrompt);
    const userMessage: ChatMessage = {
      id: uuid(),
      role: 'user',
      content: request.message,
      createdAt: new Date().toISOString(),
      modelId: 'user'
    };
    session.push(userMessage);

    const sessionState = this.sessionStore.getSessionState(sessionId);
    const systemPrompt = sessionState.systemPrompt;
    const providers = this.registry.getActiveProviders(request.modelIds);

    for (const provider of providers) {
      const providerMessages: ProviderMessage[] = session.map((message) => ({
        role: message.role,
        content: message.content,
        modelId: message.modelId
      }));

      try {
        const reply = await provider.generate({
          sessionId,
          history: providerMessages,
          input: request.message,
          tools: request.tools ?? [],
          systemPrompt
        });

        const assistantMessage: ChatMessage = {
          id: uuid(),
          role: 'assistant',
          content: reply.content,
          createdAt: new Date().toISOString(),
          modelId: provider.id,
          metadata: reply.metadata
        };

        session.push(assistantMessage);
      } catch (error) {
        const assistantMessage: ChatMessage = {
          id: uuid(),
          role: 'assistant',
          content:
            error instanceof Error
              ? `⚠️ ${provider.config.label} error: ${error.message}`
              : `⚠️ ${provider.config.label} experienced an unknown error.`,
          createdAt: new Date().toISOString(),
          modelId: provider.id,
          metadata: {
            provider: provider.id,
            error: true
          }
        };
        session.push(assistantMessage);
      }
    }

    this.sessionStore.setHistory(sessionId, session);
    return this.sessionStore.getSessionState(sessionId);
  }
}
