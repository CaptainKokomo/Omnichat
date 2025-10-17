# Omnichat

## One-click install
1. Download and extract the Omnichat bundle to any folder.
2. Double-click **OmnichatSetup.hta** (or **OmnichatSetup.cmd** as a fallback). A friendly window walks you through the process while it downloads the Electron runtime, places the Omnichat files in your profile, and creates a desktop shortcut.
3. Omnichat launches automatically when the installer finishes, and you can relaunch it anytime from the new desktop shortcut.

## Contents
- `OmnichatSetup.hta` — double-click installer with a guided Windows experience.
- `OmnichatSetup.cmd` — compatibility launcher that falls back to the PowerShell installer when HTA is unavailable.
- `Omnichat.install.ps1` — PowerShell installer used by the setup script.
- `app/` — Omnichat Electron application source packaged during installation.
