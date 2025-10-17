# Omnichat

## Double-click install
1. Download the Omnichat package and place `OmnichatSetup.bat` anywhere you like (your Desktop works great).
2. Double-click **OmnichatSetup.bat**. It quietly downloads the Electron runtime, installs Omnichat into your profile, and creates a desktop shortcut without leaving any command windows open.
3. When the installer finishes it launches Omnichat automatically. You can reopen it anytime from the new desktop shortcut.

## Contents
- `OmnichatSetup.bat` — double-click Windows installer that runs silently without extra prompts.
- `app/` — Omnichat Electron application source for maintainers.
- `package.json` — metadata for building the Electron app from source if needed.

## Add your own browser assistants (no paid APIs)

1. Launch Omnichat from the desktop shortcut the installer creates.
2. Click **Settings → Browser assistants → Add browser model**.
3. Enter the friendly name (for example, “Perplexity”) and paste the chat URL you open in your browser. Omnichat drives the live web page directly—no API keys or paid requests.
4. Adjust the suggested DOM selectors if the new site needs custom tweaks.
5. Save. Omnichat spins up a tab for the new assistant instantly so you can broadcast and orchestrate alongside the built-in models.
