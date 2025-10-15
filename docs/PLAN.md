# Omnichat Desktop AI Orchestrator — Development Plan

## 1. Vision & Objectives
- Deliver a Windows-compatible desktop chat application that can host multiple AI models simultaneously.
- Allow configurable per-session system prompts and model settings.
- Enable models to communicate with each other and execute local tools.
- Package as a portable installer/executable with simple onboarding.

## 2. High-Level Architecture Steps
1. **Foundational Setup**
   - Scaffold a cross-platform desktop shell using Electron + Vite (React) with TypeScript for modularity.
   - Establish a Node.js orchestration layer in the Electron main process for model routing, tool execution, and configuration persistence.
   - Provide inter-process communication (IPC) contracts between the renderer and backend orchestrator.
2. **Configuration & Storage**
   - Implement a configuration manager that persists workspace settings (models, API keys, tool paths) to JSON files within the user data directory.
   - Build a session manager to handle multiple chat tabs with unique system prompts.
3. **Model Providers Integration**
   - Abstract model providers via a unified interface, enabling GPT, Claude, Gemini, Copilot, and Ollama.
   - Support both HTTP-based providers and local connectors (e.g., Ollama REST, ComfyUI workflows).
   - Allow tool execution via Node child processes or HTTP client modules.
4. **Conversation Orchestration**
   - Implement a conversation engine that:
     - Receives user messages.
     - Dispatches to selected models in parallel.
     - Handles inter-model message passing.
     - Streams responses back to the UI via IPC.
5. **UI/UX Flow**
   - Create a tabbed chat interface with message threads and model selection.
   - Provide settings modals for global and per-session configurations.
   - Visualize inter-model exchanges and tool execution status.
6. **Packaging & Distribution**
   - Configure electron-builder for Windows portable and installer builds (EXE/MSI).
   - Bundle Node/Python scripts and document dependencies.

## 3. Component Breakdown
- **Electron Main Process**
  - `AppBootstrap`: bootstraps app, loads configuration, spawns orchestrator.
  - `IPCServer`: registers channels for chat, configuration, and tool commands.
  - `ModelOrchestrator`: manages provider registry, routing logic, and conversation state.
  - `ToolRuntime`: executes registered tools (ComfyUI, local scripts, plugins).
- **Renderer (React)**
  - `ChatWindow`: displays message threads with model tags.
- `SessionSidebar`: lists active sessions, allows switching/adding/deleting.
  - `SettingsPanel`: manages API keys, system prompts, provider toggles.
  - `ModelConfigDrawer`: fine-tunes provider parameters.
- **Shared**
  - Type definitions for messages, sessions, models, and IPC payloads.
  - Utility hooks for state management (Zustand/Context).
- **Support Scripts**
  - Python/Node scripts for bridging ComfyUI or other local tools.
  - CLI utilities for diagnostics.

## 4. Milestones
1. Scaffold project and implement IPC skeleton. *(Current work)*
2. Basic chat UI with fake model responses for testing the loop.
3. Integrate real OpenAI/GPT API via provider abstraction.
4. Add additional providers (Ollama, Claude, Gemini, Copilot).
5. Implement tool execution pipeline and inter-model collaboration features.
6. Polish UI, add packaging scripts, and produce installer.

## 5. Testing Strategy
- Unit tests for provider adapters and IPC handlers (Jest + ts-jest).
- Integration tests for orchestrator flows with mocked providers.
- E2E smoke tests for Electron app using Playwright.

## 6. Documentation & Support
- Developer onboarding guide (README updates).
- Configuration reference and environment variable documentation.
- Troubleshooting section for Windows-specific setup.

## 7. Next Steps
- Initialize project structure with Electron + Vite scaffold.
- Implement starter orchestrator modules and type definitions.
- Provide mock providers to simulate multi-model chat.
- Document installation and development commands.

