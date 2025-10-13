# Omnichat Desktop

Omnichat is a Windows-focused desktop AI chat orchestrator that coordinates multiple language models and local tools inside a unified Electron shell. This initial milestone sets up the project structure, renderer shell, orchestration core, and configuration plan for upcoming integrations.

## Key Features
- Multi-session chat workspace that automatically persists history, titles, and system prompts across restarts.
- Session management UI with quick create/delete controls and automatic fallback when the last session is removed.
- Provider registry with enable/disable controls and a mock multi-model conversation engine for rapid prototyping.
- Windows-friendly packaging (portable EXE + installer) via `electron-builder`.
- Roadmap: additional AI providers (GPT, Claude, Gemini, Copilot, Ollama, custom), inter-model relays, and tool execution.

## Repository Layout
```
app/
  electron/           # Electron main process, orchestration engine, provider registry
  src/                # React renderer, Zustand state store, UI components
  config/             # Future configuration templates and schema files
  index.html          # Vite entrypoint
  package.json        # Workspace scripts and build config
  vite.config.ts      # Vite bundler configuration
  tsconfig*.json      # TypeScript compiler settings
```
docs/
  PLAN.md             # Development plan and milestones
```

## Getting Started

### Prerequisites
- Node.js >= 18.17 (LTS recommended)
- npm 9+ (bundled with Node LTS)
- Windows build tools for Electron (PowerShell admin prompt: `npm install --global --production windows-build-tools`)
- Rust toolchain + Python 3.10 (planned for future provider/tool adapters)

### Install Dependencies
```powershell
cd app
npm install
```

### Development Mode
```powershell
npm run dev
```
This command compiles the Electron process, starts the Vite dev server, and launches the Electron shell once the renderer is ready.

### Production Build
```powershell
npm run build
```
Outputs compiled assets to `app/dist`. To produce distributables:
```powershell
npm run package
```
Artifacts are emitted to `app/release/` as portable and NSIS installer binaries.

## Architecture Overview
- **Electron Orchestrator**: Manages provider registry, session history, and configuration persistence (`app/electron`).
- **Provider Abstraction**: Providers implement a unified interface (`orchestrator/types.ts`) enabling HTTP or local-model connectors. A mock provider simulates responses for early testing.
- **Conversation Engine**: Coordinates dispatching user prompts to selected models and appends responses to session history (`modules/conversationEngine.ts`).
- **Renderer UI**: React + Vite front-end with chat view, session sidebar, and settings drawer (`app/src/components`).
- **State Management**: Zustand store tracks session history and metadata (`app/src/state`).

## Next Steps
1. Integrate real OpenAI/GPT provider via REST client.
2. Add secure credential vaulting and environment variable support.
3. Implement inter-model relay controls and tool execution pipeline.
4. Extend settings UI for detailed provider configuration, per-session prompts, and tool management.
5. Configure automated testing (unit + E2E) and CI packaging workflows.

## Sharing the Project with GitHub or Other Destinations

### Option 1 – Push the Existing Git History to GitHub
1. Create a new empty repository on GitHub (do **not** initialize it with a README or license so the history can fast-forward cleanly).
2. In this workspace, add the new repository URL as a remote and push the current commits:
   ```bash
   git remote add origin https://github.com/<your-username>/<repo-name>.git
   git push -u origin main
   ```
   - Replace `main` with the active branch name if it differs.
   - If GitHub requires credentials, generate a Personal Access Token (classic with `repo` scope) and use it in place of a password. Store it securely in a password manager.
3. Subsequent updates can be pushed with `git push` once authenticated.

### Option 2 – Use GitHub CLI for Authenticated Pushes
1. Install the GitHub CLI (`gh`) on your local machine and authenticate:
   ```bash
   gh auth login
   ```
   Choose HTTPS, paste your one-time code in the browser, and authorize the CLI.
2. From the project root, create or connect to a repository:
   ```bash
   gh repo create <repo-name> --private --source=. --remote=origin --push
   ```
   This command provisions the repository, adds the remote, and pushes the current branch in a single step.

### Option 3 – Transfer Without Direct GitHub Access
If direct pushes from this environment are blocked, you can still deliver the codebase safely:

- **Zip Artifact Upload**: Use the already generated `/workspace/codex_project_dump.zip`. Download it locally, then upload the archive to GitHub Releases, Google Drive, Dropbox, or another file sharing service.
- **Git Bundle**: Create a self-contained bundle that preserves commit history:
  ```bash
  git bundle create omnichat.bundle --all
  ```
  Share `omnichat.bundle`; it can be cloned elsewhere via `git clone omnichat.bundle -b <branch>`.
- **Patch Series**: Generate patches for email or manual review:
  ```bash
  git format-patch origin/main
  ```
  Recipients can apply them with `git am`.

### Tips for Smoother GitHub Integration
- Double-check that your Git configuration includes a valid user name and email (`git config --global user.name` / `git config --global user.email`).
- If two-factor authentication is enabled on GitHub, Personal Access Tokens or the GitHub CLI are required for HTTPS operations.
- For large binaries, enable Git LFS before pushing (`git lfs install`), then track the files that exceed GitHub's size limits.
- When working behind restrictive networks, configure HTTPS proxies via `git config --global http.proxy` to allow outbound GitHub traffic.

## License
MIT
