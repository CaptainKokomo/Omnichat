import { BrowserWindow, app } from 'electron';
import { once } from 'events';
import type {
  ProviderConfig,
  ProviderGenerateRequest,
  ProviderGenerateResponse,
  ProviderInstance
} from '../types';
import type { BrowserTabProviderOptions } from '@shared/types/chat';

const DEFAULT_WAIT_TIMEOUT = 15_000;

function resolveBrowserOptions(config: ProviderConfig): BrowserTabProviderOptions {
  const options = (config.options ?? {}) as Partial<BrowserTabProviderOptions>;
  if (!options.url || typeof options.url !== 'string') {
    throw new Error(
      `Browser tab provider "${config.label}" is missing a valid url option. Configure the URL in settings.`
    );
  }

  const waitTimeout =
    typeof options.waitTimeoutMs === 'string'
      ? Number(options.waitTimeoutMs)
      : options.waitTimeoutMs;

  const width = typeof options.width === 'string' ? Number(options.width) : options.width;
  const height = typeof options.height === 'string' ? Number(options.height) : options.height;

  return {
    waitTimeoutMs: Number.isFinite(waitTimeout) && waitTimeout ? waitTimeout : DEFAULT_WAIT_TIMEOUT,
    ...options,
    width: Number.isFinite(width) && width ? width : undefined,
    height: Number.isFinite(height) && height ? height : undefined
  } as BrowserTabProviderOptions;
}

async function waitForSelector(window: BrowserWindow, selector: string, timeout: number): Promise<void> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const found = await window.webContents.executeJavaScript(
      `document.querySelector(${JSON.stringify(selector)}) !== null`
    );
    if (found === true) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error(`Timed out waiting for selector ${selector}`);
}

export class BrowserTabProvider implements ProviderInstance {
  readonly id: string;
  readonly config: ProviderConfig;
  private browserWindow: BrowserWindow | null = null;

  constructor(config: ProviderConfig) {
    this.id = config.id;
    this.config = config;
  }

  async dispose(): Promise<void> {
    if (this.browserWindow && !this.browserWindow.isDestroyed()) {
      this.browserWindow.destroy();
    }
    this.browserWindow = null;
  }

  private async ensureWindow(): Promise<BrowserWindow> {
    if (this.browserWindow && !this.browserWindow.isDestroyed()) {
      return this.browserWindow;
    }

    const options = resolveBrowserOptions(this.config);
    await app.whenReady();
    const window = new BrowserWindow({
      show: options.showWindow ?? false,
      width: options.width ?? 1280,
      height: options.height ?? 720,
      backgroundColor: '#111111',
      webPreferences: {
        contextIsolation: true,
        nodeIntegration: false
      }
    });

    window.on('closed', () => {
      this.browserWindow = null;
    });

    await window.loadURL(options.url);
    await once(window.webContents, 'did-finish-load');

    if (options.readySelector) {
      await waitForSelector(window, options.readySelector, options.waitTimeoutMs ?? DEFAULT_WAIT_TIMEOUT);
    }

    if (options.initScript) {
      const initExpression = `((0, eval)(${JSON.stringify(options.initScript)}))`;
      await window.webContents.executeJavaScript(`(async () => {
        const initializer = ${initExpression};
        if (typeof initializer === 'function') {
          await initializer();
        }
      })();`);
    }

    this.browserWindow = window;
    return window;
  }

  async generate(request: ProviderGenerateRequest): Promise<ProviderGenerateResponse> {
    const options = resolveBrowserOptions(this.config);
    const window = await this.ensureWindow();

    const context = {
      input: request.input,
      history: request.history,
      systemPrompt: request.systemPrompt ?? null,
      sessionId: request.sessionId,
      providerId: this.id
    };

    const script = options.script
      ? `((0, eval)(${JSON.stringify(options.script)}))`
      : `async (ctx) => {
          if (window.omnichatBridge && typeof window.omnichatBridge.handlePrompt === 'function') {
            const reply = await window.omnichatBridge.handlePrompt(ctx);
            if (typeof reply === 'string') {
              return reply;
            }
            if (reply && typeof reply === 'object' && 'content' in reply) {
              return String(reply.content ?? '');
            }
            return JSON.stringify(reply ?? {});
          }
          return 'No bridge detected in the target tab. Define window.omnichatBridge.handlePrompt(ctx) to enable replies.';
        }`;

    try {
      const result = await window.webContents.executeJavaScript(
        `(async () => {
          const handler = ${script};
          if (typeof handler !== 'function') {
            throw new Error('Configured browser script did not evaluate to a function.');
          }
          const context = ${JSON.stringify(context)};
          const response = await handler(context);
          return response;
        })();`
      );

      const content =
        typeof result === 'string'
          ? result
          : result && typeof result === 'object' && 'content' in (result as Record<string, unknown>)
          ? String((result as Record<string, unknown>).content ?? '')
          : JSON.stringify(result ?? {});

      return {
        content: content || 'Browser tab handler returned an empty response.',
        metadata: {
          provider: 'browser-tab',
          url: options.url
        }
      };
    } catch (error) {
      return {
        content: `⚠️ Browser provider failed: ${(error as Error).message}`,
        metadata: {
          provider: 'browser-tab',
          url: options.url,
          error: String(error)
        }
      };
    }
  }
}
