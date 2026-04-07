# Jac IDE - Agent Memory (ide-feature-researcher)

## Project Summary

Jac IDE is a full-stack web IDE written entirely in Jac (backend `.jac`, frontend `.cl.jac`).
Entry point: `main.jac`. Start with: `jac start main.jac`.
Config: `jac.toml` (no package.json). Only one git commit (initial POC).

## Architecture

### Backend (Jac walkers as HTTP endpoints)

- `main.jac` - imports services, exposes client app
- `services/ideServer.jac` - two public walkers: `ide_file_ops` (POST /walker/ide_file_ops) and `preview_control` (POST /walker/preview_control)
- `services/preview_manager.jac` - subprocess/sandbox management
  - Sessions: `/tmp/jac-preview-{session_id}/` (ephemeral, copied from `preview-template/`)
  - Port pool: 5180+ in steps of 2 (Vite + API), max 10 concurrent sessions
  - Process lifecycle: `start_preview` -> `_poll_readiness` thread -> status updates
  - Sandbox protection: path traversal checks, `jac.toml` is protected
  - `apply_preview_patch` function exists (search/replace in files) - useful for AI edits

### Frontend (.cl.jac with JSX/React)

- `frontend.cl.jac` - MantineProvider + Router, violet theme, Monaco init
- `pages/JacIDE.cl.jac` - main 3-panel layout (220px FileTree | flex Editor | fixed PreviewWidth)
  - Drag-to-resize preview panel (clamp 200px-60vw)
  - Ctrl+S save binding
  - Language detection from file extension
  - Uses `window.prompt()` for new file/folder names (raw browser dialog - UX gap)
  - Uses `window.confirm()` for delete confirmation (raw browser dialog - UX gap)
- `hooks/useIDE.cl.jac` - central state: session, files, tabs, terminal, preview
  - Session in localStorage as `jac_ide_session`
  - Auth token in localStorage as `jac_token` (Bearer)
  - Log polling every 5s, status polling every 2s while starting
- `services/ideService.cl.jac` - fetch wrapper for walker calls, handles 3 response envelope shapes
- `components/ide/` - IDEToolbar, FileTree, EditorTabs, TerminalPanel, IDEPreviewPanel

### Monaco Setup

- `utils/monaco_initializer.cl.jac` - TextMate grammar via monaco-textmate + onigasm WASM
- Grammar fetched from GitHub (jaseci-labs/jac-vscode) at runtime with local fallback
- Custom "jac-theme" (vs-dark base, orange keywords, amber names, green strings, purple numbers)

### Preview Template

- `preview-template/` - copied per session, has component library (Badge, Button, Card, Container, Input, Select, Text)
- Pre-compiled `.jac/client/` artifacts included

## Key Gaps (confirmed by codebase inspection)

1. No user authentication (auth token is stored but no login/signup flow)
2. No AI features of any kind
3. Sessions are fully ephemeral (no persistence, no DB)
4. No project save/load system
5. File creation/deletion uses raw browser `window.prompt()`/`window.confirm()`
6. No auto-save
7. Terminal is read-only (log viewer only, not interactive)
8. No git integration
9. No deploy/publish feature
10. No command palette
11. No IntelliSense / LSP for Jac
12. No minimap (explicitly disabled in editor options)
13. No project templates beyond the single preview-template
14. No collaboration features
15. Port pool is hardcoded to 10 concurrent sessions maximum
16. No billing/subscription system
17. No rate limiting

## Walker Pattern (for new features)

```jac
walker :pub my_walker {
    has param1: str;
    has param2: int = 0;
    obj __specs__ { static has methods: list = ["post"]; }
    can handle with Root entry {
        report {"success": True, "data": ...};
    }
}
```

## apply_preview_patch

`preview_manager.jac` already has `apply_preview_patch(session_id, path, search, replace, replace_all)`.
This is the key primitive for AI-driven code edits without full file rewrites.

## Detailed Feature Analysis

See: `feature-analysis.md`

## Landing Page Research

See: `landing_page_research.md`
Researched 2026-03-20. Current page: hero-only (no feature section, no templates, no social proof, no footer nav).
Top P0 gaps vs competitors: prompt input in hero, feature explainer section, template gallery.

## Extension System Research

See: `project_extension_system_research.md`
Researched 2026-03-24. Full architecture comparison: VS Code, Theia, Replit, Gitpod, OpenSumi.
Key conclusion: Start with static JSON contributions (grammars/themes/snippets), then Web Worker runtime extensions,
then iframe UI extensions. Do NOT attempt full VS Code extension host compatibility.
Recommended manifest format and 4-phase rollout in that file.
