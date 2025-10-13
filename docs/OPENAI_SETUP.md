# Configuring the OpenAI Provider

Omnichat now ships with a disabled-by-default OpenAI provider. Follow these steps to enable it locally:

1. Generate an OpenAI API key with access to the Chat Completions API.
2. Launch Omnichat in development (`npm run dev`) or run the packaged build.
3. Open the **Settings** drawer (gear icon in the chat header).
4. Enable **OpenAI GPT-4o mini** and paste your API key into the **API Key** field.
5. Optionally adjust the **Model** (e.g., `gpt-4o` or `gpt-4o-mini`) or override the **Base URL** if you proxy requests.
6. Save your changes. The configuration is persisted to the Electron user data directory so future sessions reuse the credentials.

> **Security tip:** if you prefer not to store secrets on disk, omit the API key in settings and set the `OPENAI_API_KEY` environment variable before launching the app. The provider automatically falls back to the environment variable when the stored key is absent.

