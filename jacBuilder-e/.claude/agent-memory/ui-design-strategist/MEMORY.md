# UI Design Strategist Memory

## Project: Jac IDE
- Web-based IDE for the Jac programming language
- Stack: jac-shadcn (shadcn/ui port), Tailwind CSS v4, HugeIcons, Monaco Editor
- Files: `.cl.jac` (client-side), `.jac` (backend)
- Entry: `frontend.cl.jac` -> `pages/JacIDE.cl.jac`

## Design System (current as of 2026-03-20)
- Colors: OKLCH semantic tokens in `global.css` (`:root` and `.dark`)
- Dark bg: oklch(0.12), card: oklch(0.16), primary: amber/orange, claude: violet
- 54 jac-shadcn components in `components/ui/`
- Icons: HugeIcons (`@hugeicons/react` + `@hugeicons/core-free-icons`)
- Styling: `cn()` from `lib/utils.cl.jac` for className merging, never `+`
- No hardcoded hex values -- all semantic tokens

## ChatPanel
- [ChatPanel redesign plan](project_chatpanel_state.md) -- gaps vs modern AI chat panels, brief at `docs/plans/chatpanel-redesign-brief.md`
- 5 sub-components: AssistantMessage, ClaudeStreamingMessage, ThreadList, ThreadItem, ActivityTimeline
- Used in JacIDE (JacCoder only) and AgentPage (both JacCoder + Claude)
- No markdown rendering (react-markdown not installed)
- Single-line Input (not Textarea)
- No code block copy/apply buttons
- ThreadList takes 45% panel height -- needs compact dropdown

## Jac Syntax Constraints for UI Changes
- `has` = useState (no explicit setters)
- `.call(None, arg)` for callbacks in lambdas
- No comments inside JSX return blocks
- `String.fromCharCode(10)` for newlines, not `"\n"`
- Use `cn()` never `+` for className
