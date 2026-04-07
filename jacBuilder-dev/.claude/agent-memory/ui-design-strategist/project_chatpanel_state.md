---
name: ChatPanel current state and redesign plan
description: Current ChatPanel architecture, gaps vs modern AI IDE chat panels, and the approved redesign plan
type: project
---

ChatPanel redesign plan documented at `docs/plans/chatpanel-redesign-brief.md`.

**Why:** Current ChatPanel renders plain text (no markdown), uses single-line input, lacks code block copy buttons, and has no empty state suggestions -- all standard features in Cursor, Windsurf, Copilot, Lovable.

**How to apply:** When modifying ChatPanel or its related components, follow the brief's implementation order. Critical changes: (1) add react-markdown to jac.toml, (2) create MarkdownMessage.cl.jac, (3) replace Input with Textarea, (4) add empty state suggestions, (5) compact thread selector replacing ThreadList in header.

Key files: `components/ide/ChatPanel.cl.jac` (485 lines), `components/ide/ActivityTimeline.cl.jac` (117 lines), `hooks/useChatMode.cl.jac`, `hooks/useClaudeChat.cl.jac`.

No markdown rendering library currently installed. No `react-markdown` in jac.toml.
