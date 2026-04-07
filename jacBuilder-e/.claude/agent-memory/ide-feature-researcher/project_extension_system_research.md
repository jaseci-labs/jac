---
name: Extension System Architecture Research
description: Deep research on VS Code, Theia, Replit, and web IDE extension system architectures for planning Jac Builder Studio extension support
type: project
---

Research completed: 2026-03-24

## VS Code Extension Architecture

### Three-Layer Isolation
1. **Renderer Process** — UI (Electron/browser). Never runs extension code.
2. **Extension Host Process** — Dedicated Node.js process (one per window). Runs ALL extensions. Exposes the `vscode` API module.
3. **Language Server Protocol** — Optional separate process per language server, communicates with extension host via JSON-RPC over stdio/socket.

### Web Extension Host (browser context)
- Runs in a **Browser WebWorker** (not Node.js)
- Single-file bundle required (webpack/esbuild — no `importScripts`)
- No child processes, no `path`/`os`/`fs` — use `vscode.workspace.fs` instead
- Language servers run as **Web Workers** using `vscode-languageclient/browser` + `vscode-languageserver/browser`
- Communication: postMessage between worker and extension host

### Extension Manifest (package.json)
Required fields: `name`, `version`, `publisher`, `engines` (`{"vscode": "^1.x.x"}`)
Key fields: `main` (Node.js entry), `browser` (web entry), `activationEvents[]`, `contributes{}`

### Activation Events (lazy loading)
- `onCommand:myext.myCmd` — activate only when command is invoked
- `onLanguage:jac` — activate when a .jac file is opened
- `onStartupFinished` — after IDE is loaded (preferred over `*`)
- `*` — always activated at startup (avoid — kills perf)

### Contribution Points (34 total)
**Editor/Language**: `languages`, `grammars`, `snippets`, `semanticTokenTypes`, `semanticTokenModifiers`, `semanticTokenScopes`
**UI/Views**: `views`, `viewsContainers`, `menus`, `submenus`, `colors`, `icons`, `walkthroughs`
**Themes**: `themes`, `iconThemes`, `productIconThemes`
**Config**: `configuration`, `configurationDefaults`, `jsonValidation`
**Commands**: `commands`, `keybindings`, `taskDefinitions`, `terminal`
**Debug**: `debuggers`, `breakpoints`
**Editors**: `customEditors`
**Build**: `problemMatchers`, `problemPatterns`
**AI**: `chatInstructions`, `chatPromptFiles`
**TS**: `typescriptServerPlugins`
**Auth**: `authentication`

## Theia Extension Architecture

Four extension types with different trade-offs:

| Type | Install Time | Process | API Access | Limitation |
|------|-------------|---------|------------|------------|
| VS Code Extensions | Runtime | Separate per frontend | VS Code API only | Most restricted |
| Theia Plugins | Runtime | Separate per frontend | VS Code + Theia APIs | Theia-only |
| Headless Plugins | Runtime | Separate, no frontend | Backend only | No UI |
| Theia Extensions | Compile time | Same process | Full internals via DI | Requires rebuild |

- Uses **Open VSX Registry** (https://open-vsx.org/) as marketplace
- DI-based contribution system for Theia Extensions
- VS Code extensions get ~full API parity (coverage at eclipse-theia.github.io/vscode-theia-comparator)

## Replit Extensions Architecture

- Extensions run as **React web apps in iframes**
- Communication: `@replit/extensions` npm library over **postMessage**
- `useReplit()` hook: provides IDE API surface to extension React code
- Manifest: `extension.json` served at `/extension.json` (public dir)
- Three extension types:
  - **Tools** — custom UI panels/sidebar tabs
  - **File Handlers** — custom editors for specific file types
  - **Commands** — actions in command palette
- Extensions published to a store; activated per-user-account
- No Node.js — browser-only, iframe sandbox

## Gitpod/OpenVSCode Server

- Ships upstream VS Code as a remote server (openvscode-server)
- Uses **Open VSX Registry** (not Microsoft Marketplace — TOS restriction)
- Extensions run in Node.js extension host on server
- Full VS Code extension API compatibility

## OpenSumi (Alibaba) Architecture

- Multi-environment: Frontend UI + Web Worker + Backend process + Extension process
- Extensions get THREE entry points: `main` (backend), `browserMain` (frontend/renderer), `workerMain` (web worker)
- Contribution points include panels (left/right/bottom) and toolbar
- Extension host per environment type

## Security Isolation Options for Web IDEs

### Option A: iframe sandbox
- `<iframe sandbox="allow-scripts allow-same-origin">` + postMessage
- Pros: browser-native, familiar pattern, works with React apps
- Cons: shared page thread (DoS possible), cannot spawn workers easily
- Best for: UI extensions (panels, custom editors)

### Option B: Web Worker
- `new Worker(extensionBundle)` — separate thread, no DOM access
- Pros: true thread isolation, no DoS on UI thread, can use Atomics/SharedArrayBuffer
- Cons: no DOM/UI access, must use postMessage for all API calls
- Best for: language features (LSP, formatters, linters, AI)

### Option C: Service Worker
- Intercepts network requests, shared across tabs
- Pros: persistent background execution
- Cons: complex lifecycle, CSP complications
- Best for: offline caching, network interception

### CSP hardening
```
Content-Security-Policy: default-src 'self'; worker-src blob:; frame-src blob: data: https://trusted-ext-cdn.com
```

## Minimal Viable Extension System for Jac Builder Studio

### Manifest format (jac-extension.json)
```json
{
  "id": "my-org.my-ext",
  "name": "My Extension",
  "version": "1.0.0",
  "description": "...",
  "author": "...",
  "engines": { "jac-builder": ">=0.1.0" },
  "activationEvents": ["onLanguage:jac", "onStartup"],
  "contributes": {
    "commands": [{"id": "myext.run", "title": "Run Something"}],
    "languages": [{"id": "mylang", "extensions": [".myl"], "aliases": ["MyLang"]}],
    "grammars": [{"language": "mylang", "scopeName": "source.mylang", "path": "./grammar.json"}],
    "themes": [{"label": "My Dark", "uiTheme": "vs-dark", "path": "./theme.json"}],
    "views": [{"id": "myext.panel", "name": "My Panel", "location": "sidebar"}],
    "snippets": [{"language": "jac", "path": "./snippets.json"}]
  },
  "main": "./dist/extension.js",
  "browser": "./dist/extension.browser.js"
}
```

### Recommended Architecture for Jac Builder Studio

**Layer 1: Extension Registry (backend)**
- Walker: `extension_ops` — `install`, `uninstall`, `list`, `search`, `enable`, `disable`
- Storage: `~/.jac-ide/extensions/{ext-id}/` (extracted zip) per user
- Per-project activation via Project node metadata

**Layer 2: Extension Host (frontend web worker)**
- One `ExtensionHostWorker` per active project
- Loads extension bundles as worker modules
- Bridges `vscode.*` API calls → IDE state via postMessage to main thread
- Sandboxed: no DOM access, timeout watchdog for infinite loops

**Layer 3: Extension UI (iframe per UI extension)**
- UI extensions get their own `<iframe>` with `sandbox="allow-scripts"`
- `@jac-builder/extension-api` npm lib handles postMessage protocol
- Panel extensions mounted in sidebar/bottom panel slots

**Layer 4: Contribution Registry**
- IDE reads `jac-extension.json` at activation time
- Static contributions (grammars, themes, snippets) loaded immediately
- Dynamic contributions (commands, views) registered with IDE command registry and panel slots

**Layer 5: Language Feature Bridge**
- Language extensions provide LSP-over-WebSocket or in-worker LSP
- useLSP hook extended to support multiple language server registrations
- Formatters, linters registered as Monaco `DocumentFormattingEditProvider`

## Why: Key Decisions

**Why start with grammar/theme/snippet contributions only?**
These are static JSON files — zero security risk, high value. No runtime code execution. Easy to parse and apply at load time.

**Why Web Worker for code-running extensions?**
Prevents UI freeze from malicious/slow extensions. Extensions that need to compute (formatters, linters, AI) should run off the main thread.

**Why iframe for UI extensions?**
Replit's model works well. Allows extensions to use any framework (React, plain JS). postMessage is battle-tested. CSP can lock down capabilities.

**Why NOT ship a full VS Code extension host?**
Building a fully compatible VS Code extension host is a massive multi-year effort. The `vscode` API has 500+ methods. Instead, expose a curated Jac Builder API subset that covers 80% of use cases.

## Rollout Priority

Phase 1 (Static, zero risk):
- Grammar contributions (TextMate JSON)
- Theme contributions (JSON color definitions)
- Snippet contributions (JSON snippets)
- Language file associations

Phase 2 (Active, sandboxed worker):
- Formatter contributions (worker, returns edit ops)
- Linter/diagnostic contributions (worker, returns markers)
- Command contributions (invoked by command palette)
- Completion providers (worker, returns CompletionList)

Phase 3 (UI extensions, iframe):
- Panel/view contributions (sidebar, bottom panel)
- Custom file editor contributions (webview-style)
- Status bar contributions

Phase 4 (Deep integration):
- LSP proxy contributions (full language servers)
- Debug adapter contributions
- AI agent contributions (chat panel providers)

**Why:** How to apply: Use this as the architecture blueprint when planning or implementing the Jac Builder extension system. Always start with Phase 1 (static JSON contributions) before building any runtime.
