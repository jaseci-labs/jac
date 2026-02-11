# Using AI Tools with Jac

Jac is a new language. AI models tend to hallucinate syntax from outdated or nonexistent versions, and things break. To fix this, we maintain an official condensed language reference designed specifically for LLM context windows: [jaseci-llmdocs](https://github.com/jaseci-labs/jaseci-llmdocs).

Grab the latest `candidate.txt` from the [releases page](https://github.com/jaseci-labs/jaseci-llmdocs/releases/latest) and paste it into your AI tool's persistent context.

```bash
curl -LO https://github.com/jaseci-labs/jaseci-llmdocs/releases/latest/download/candidate.txt
```

## Where to Put It

Every AI coding tool has a file or setting where you can drop persistent instructions. Paste the contents of `candidate.txt` there:

| Tool | Context File |
|------|-------------|
| Claude Code | `CLAUDE.md` in project root (or `~/.claude/CLAUDE.md` for global) |
| Gemini CLI | `GEMINI.md` in project root (or `~/.gemini/GEMINI.md` for global) |
| Cursor | `.cursor/rules/jac-reference.mdc` (or Settings > Rules) |
| Antigravity | `GEMINI.md` in project root (or `.antigravity/rules.md`) |
| OpenAI Codex | `AGENTS.md` in project root (or `~/.codex/AGENTS.md` for global) |

Quick setup:

```bash
# Claude Code
cat candidate.txt >> CLAUDE.md

# Gemini CLI
cat candidate.txt >> GEMINI.md

# Cursor
mkdir -p .cursor/rules && cp candidate.txt .cursor/rules/jac-reference.mdc

# Antigravity
cat candidate.txt >> GEMINI.md

# OpenAI Codex
cat candidate.txt >> AGENTS.md
```

When you update Jac, pull a fresh copy from the releases page to stay current.
