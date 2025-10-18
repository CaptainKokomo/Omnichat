# OmniChat

OmniChat is a Windows desktop hub that orchestrates conversations across browser-based AI assistants (ChatGPT, Claude, Copilot, Gemini) and a local Ollama model. The bundled installer (`OmniChat_install.bat`) handles every dependency download and launches the Electron app in one double-click.

## Quick install
1. Double-click `OmniChat_install.bat`.
2. Wait for the console to show `OmniChat is ready to use.`
3. Use the new **OmniChat** desktop shortcut to reopen the app later.

The installer downloads portable Node.js and Electron builds, writes OmniChat under `%LOCALAPPDATA%\OmniChat\app`, seeds `selectors.json`, and drops a `FIRST_RUN.txt` checklist.

## First run checklist
1. Open OmniChat from the desktop shortcut.
2. Press **Connect** beside each browser assistant to open its live tab.
3. Sign in to ChatGPT, Claude, Copilot, and Gemini inside the spawned tabs.
4. Type a message in the composer and press **Broadcast**.
5. Try **Start Round-table** to watch the assistants trade replies for *K* turns.

`FIRST_RUN.txt` inside `%LOCALAPPDATA%\OmniChat` repeats these steps if you need them later.

## Selecting which assistants respond
- Use the toggle switches in the left **Assistants** column or click the name chips above the composer to include/exclude assistants.
- The dropdown beside **Send to Selected** lists the current active assistant for single-send messages.
- Status lines show when a site window is visible, the current URL host, or if OmniChat needs you to log in.

## Local (Ollama) model setup
1. Install [Ollama](https://ollama.com/download) on Windows and start it once so the service listens on `http://127.0.0.1:11434`.
2. In OmniChat’s **Local Studio** (center column → *Local Studio* card), set **Host** if you changed it and click **Refresh Models**.
3. Choose a model from the dropdown (examples: `llama3`, `mistral`, `phi3:medium`). Click **Generate** to run a prompt.
4. OmniChat saves the model + host under **Settings → Delays & Limits → Preferred Ollama model** so the local agent joins broadcasts automatically.

Ollama responses appear in the attachments tray and within the conversation log alongside the browser assistants.

## Adding or removing browser assistants
Open **Settings** (gear icon or **Manage** button) and use the **Browser Assistants** section:

1. Fill in the **Add new assistant** form:
   - **Assistant name** – what OmniChat shows in the UI.
   - **Assistant key** – letters/numbers/hyphen (auto-filled from the name). Example: `perplexity`.
   - **Home URL** – the page OmniChat opens when you press **Connect**.
   - **URL patterns** – one per line, using `*` wildcards for matching tabs.
   - **Input / Send button / Message container selectors** – CSS selectors OmniChat uses to inject or read messages.
2. Pick **Start with template** to copy selectors from ChatGPT, Claude, Copilot, or Gemini if the target layout is similar.
3. Click **Create Assistant**. The new assistant appears immediately in the left column with toggles, status, and Connect/Hide/Read buttons.

Existing assistants show editable cards in the same panel. Update any field and press **Save** to persist the selectors. Press **Reset** on a built-in assistant to restore its default selectors, or **Remove** on a custom assistant to delete it entirely.

## Selector import/export & config folder
Within Settings → **Utilities**:
- **Import selectors.json…** merges a JSON file into your current selector list.
- **Export selectors.json…** saves the current configuration for backup or sharing.
- **Open config folder** reveals `%LOCALAPPDATA%\OmniChat\config` in File Explorer where OmniChat stores selectors, settings, and logs.

## ComfyUI integration
1. Run [ComfyUI](https://github.com/comfyanonymous/ComfyUI) locally. Default host is `http://127.0.0.1:8188`.
2. In **Local Studio → ComfyUI Visuals**, confirm the host and click **Fetch Latest** to pull recent images/videos.
3. Click any thumbnail to attach it to the composer. Enable **Auto-import ComfyUI results** in Settings to pull the most recent asset into OmniChat automatically.

## Troubleshooting
- **Selector errors**: OmniChat pops a toast like `chatgpt.input` if a CSS selector fails. Open Settings → Browser Assistants and adjust the selectors for that site.
- **Site not logged in**: OmniChat shows a **Connect** button. Click it to bring the window forward and sign in manually.
- **Local model unavailable**: Check that the Ollama service is running and click **Refresh Models**.
- **Installer failures**: The batch installer now pauses on error with a clear message. Rerun it after addressing the missing dependency.

## Updating OmniChat
Re-run `OmniChat_install.bat` from the latest repository snapshot. The script removes the previous installation, installs fresh files, and recreates the desktop shortcut.

## Logs & exports
OmniChat writes timestamped log files under `%LOCALAPPDATA%\OmniChat\logs`. Use the **Export** button above the right-side log panel to save the current session transcript as a `.txt` file.

Enjoy orchestrating your AI assistants in one place!
