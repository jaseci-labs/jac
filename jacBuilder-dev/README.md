# Jac Builder Studio

A web-based IDE for the Jac programming language, built entirely in Jac. Monaco editor with Jac syntax highlighting, file management, live preview via `jac start` subprocesses, git-backed versioning, JacPack import/export, community gallery, and AI chat.

## Getting Started

```bash
pip install jaclang jac-scale jac-client byllm
jac start main.jac
# Serves on http://localhost:8000
```

No separate build step, no package.json, no Makefile.

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `OPENAI_API_KEY` | For AI chat | Used by `ai_service.jac` via `byllm` with `gpt-4o` |
| `JAC_IDE_PROJECTS_ROOT` | No | Persistent project storage root (default: `~/.jac-ide/projects`) |
| `JAC_IDE_PREVIEW_PUBLIC_URL_TEMPLATE` | No | Preview URL template for deployed environments. Placeholders: `{user_id}`, `{port}`, `{api_port}` |
| `JAC_MCP_SERVER_URL` | No | MCP screenshot server URL for live preview thumbnails (default: `https://mcp.jaseci.org`) |

## Architecture

```
main.jac                         # Entry point — backend imports + cl{} mounts frontend
services/
  ideServer.jac                  # All walkers + graph node definitions
  project_manager.jac            # Project workspaces, git autosave, JacPack versioning
  preview_manager.jac            # Per-project preview subprocess lifecycle
  community_manager.jac          # Community gallery storage (~/.jac-ide/community/)
  ai_service.jac                 # GPT-4o integration via byllm, import resolution
  screenshot_service.jac         # MCP screenshot capture for project thumbnails
  preview_proxy.jac              # ASGI subdomain proxy for deployed preview routing
frontend.cl.jac                  # MantineProvider + React Router app shell
pages/
  LandingPage.cl.jac
  AuthPage.cl.jac
  DashboardPage.cl.jac           # Project grid + community gallery (AppShell + sidebar)
  JacIDE.cl.jac                  # 3-panel IDE layout (wires hooks, pure layout)
hooks/
  useIDE.cl.jac                  # Core IDE state: session, files, tabs, preview, auto-save
  useDashboard.cl.jac            # Dashboard state: projects, templates, create/share flows
  useCommunity.cl.jac            # Community gallery state: items, search, clone modal
  useChatMode.cl.jac             # AI chat state: messages, send, apply file updates
  useIDEModals.cl.jac            # Delete confirmation + shortcuts modal state
  useEditorSetup.cl.jac          # Monaco mount, content sync, language detection, Ctrl+S
  useResizablePanel.cl.jac       # Drag-to-resize for preview panel divider
components/
  auth/AuthGuard.cl.jac          # JWT guard — redirects to /auth if not logged in
  ide/FileTree.cl.jac            # Recursive tree, right-click menu, inline rename
  ide/EditorTabs.cl.jac          # Tab strip with dirty indicator
  ide/IDEToolbar.cl.jac          # Run/Stop, Save, status badge, Preview toggle
  ide/IDEPreviewPanel.cl.jac     # Preview iframe, viewport modes (desktop/tablet/mobile)
  ide/TerminalPanel.cl.jac       # Collapsible subprocess log viewer
  ide/CommandPalette.cl.jac      # Mantine Spotlight (Ctrl+K) — all IDE actions
  ide/KeyboardShortcuts.cl.jac   # Shortcuts help modal (Shift+?)
  ide/IDEModals.cl.jac           # Modal container (delete confirm + shortcuts)
  ide/ChatPanel.cl.jac           # Slide-in AI chat panel
  ide/CommunityGallery.cl.jac    # Community browse, search, clone
services/ideService.cl.jac       # Frontend HTTP + WebSocket bridge
utils/monaco_initializer.cl.jac  # TextMate grammar setup (onigasm WASM)
templates/
  manifest.json                  # Curated JacPack template catalog
  *.jacpack                      # Starter templates
assets/
  jac.tmLanguage.json            # Jac TextMate grammar
  onigasm.wasm                   # TextMate WASM engine
  logo-builder.png               # App icon
global.css                       # Design system (CSS vars, IDE + dashboard + landing styles)
docs/
  deployment-preview-routing.md  # Infra handoff for preview proxy setup
  jacpack-project-architecture.md
  git-versioning-flow.md
  websocket-limitations.md
```

## Graph Data Model

Node hierarchy per authenticated user:

```
user_root → UserProfile → Project → ProjectVersion
```

Walker auth: `walker:pub` runs from the global root (no auth, shared). `walker` (no modifier) runs from the user's personal root (JWT-isolated). Never use `walker:pub` for user-owned data.

## Features

- **Auth** — register/login, JWT-backed, per-user graph isolation
- **Projects** — create from template, import JacPack, rename, delete, multi-project switcher
- **Editor** — Monaco with Jac TextMate grammar, syntax highlighting, minimap, Ctrl+S save, 2s auto-save debounce, dirty-tab indicator, image tab support (base64)
- **File tree** — CRUD, rename, mkdir, right-click context menu, inline editing, `/`-separated path auto-creates directories
- **Live preview** — sandboxed `/tmp/jac-preview-{user_id}-{project_id}/`, Vite HMR, desktop/tablet/mobile viewport modes
- **Terminal** — read-only subprocess log viewer via shared WebSocket (`ide_preview_stream`)
- **Version history** — git-backed autosave commits + JacPack snapshots, rolling 50 versions, checkout + export
- **Command palette** — Ctrl+K (Mantine Spotlight), all IDE actions searchable
- **AI chat** — GPT-4o via `byllm`, current file + resolved imports as context, applies multi-file updates
- **Community gallery** — share projects as JacPack, browse/search/filter by tag, clone to own projects, owner-delete
- **Templates** — curated local JacPack catalog; user-saved templates appear alongside built-ins
- **Preview screenshots** — auto-captures a screenshot 5s after preview starts running (via MCP screenshot service), displayed as project card thumbnails on the dashboard

## Deployment

### Environments

| Environment | URL | Branch | Namespace |
|---|---|---|---|
| Production | https://jac-builder.jaseci.org | `main` | `jac-builder` |
| Dev | https://jac-builder-dev.jaseci.org | `dev` | `jac-builder-dev` |

Both environments are deployed to the `jaseci-cluster` EKS cluster (us-east-2) via GitHub Actions CI/CD.

### CI/CD

Pushing to `main` triggers `.github/workflows/deploy.yml` (production). Pushing to `dev` triggers `.github/workflows/deploy-dev.yml`.

The pipeline installs Jaseci packages from `jaseci-labs/jaseci@main`, runs `jac start main.jac --scale --experimental` to apply the K8s deployment, then verifies the rollout.

### GitHub Secrets

| Secret | Description |
|---|---|
| `JAC_IDE_PREVIEW_PUBLIC_URL_TEMPLATE` | Preview URL template for production (e.g. `https://{user_id}-p{port}.jaseci.org`) |
| `JAC_IDE_PREVIEW_PUBLIC_URL_TEMPLATE_DEV` | Preview URL template for dev |
| `JAC_MCP_SERVER_URL` | MCP screenshot server internal URL (e.g. `http://jaseci-mcp-server.jaseci-mcp-server.svc.cluster.local:8000`) |
| `OPENAI_API_KEY` | OpenAI API key for AI chat |
| `GH_PAT` | GitHub PAT for cloning private `jac-code` repo |

### Preview URL in Deployment

Default preview URLs are `http://localhost:{port}` (local dev only). For production set:

```bash
export JAC_IDE_PREVIEW_PUBLIC_URL_TEMPLATE="https://{user_id}-p{port}.example.com"
```

See `docs/deployment-preview-routing.md` for the full infra handoff.
