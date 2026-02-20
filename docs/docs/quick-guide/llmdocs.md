# Using AI Tools with Jac

Jac is a new language. AI models tend to hallucinate syntax from outdated or nonexistent versions, and things break. To fix this, we maintain an official condensed language reference designed specifically for LLM context windows: [jaseci-llmdocs](https://github.com/jaseci-labs/jaseci-llmdocs).

Grab the latest `jac-llmdocs.md` from the [releases page](https://github.com/jaseci-labs/jaseci-llmdocs/releases/latest/) and paste it into your AI tool's persistent context.

```bash
curl -LO https://github.com/jaseci-labs/jaseci-llmdocs/releases/download/v0.10.4/jac-llmdocs.md
```

## Where to Put It

Every AI coding tool has a file or setting where you can drop persistent instructions. Paste the contents of `jac-llmdocs.md` there:

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
cat jac-llmdocs.md >> CLAUDE.md

# Gemini CLI
cat jac-llmdocs.md >> GEMINI.md

# Cursor
mkdir -p .cursor/rules && cp jac-llmdocs.md .cursor/rules/jac-reference.mdc

# Antigravity
cat jac-llmdocs.md >> GEMINI.md

# OpenAI Codex
cat jac-llmdocs.md >> AGENTS.md
```

When you update Jac, pull a fresh copy from the releases page to stay current.
