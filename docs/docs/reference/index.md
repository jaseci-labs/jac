# Reference

This section is the complete technical reference for Jac. Use the sidebar to navigate to the topic you need, or use the summaries below to find the right starting point.

---

## Language Specification

The language spec covers all core Jac constructs:

- **[Foundation](language/foundation.md)** - Syntax, types, literals, variables, scoping, operators, control flow, pattern matching
- **[Functions & Objects](language/functions-objects.md)** - Function declarations, `can` vs `def`, OOP, inheritance, enums, access modifiers, impl blocks
- **[Object-Spatial Programming](language/osp.md)** - Nodes, edges, walkers, `visit`, `report`, `disengage`, graph construction, data spatial queries, common patterns
- **[Concurrency](language/concurrency.md)** - Async/await, `flow`/`wait` concurrent expressions, parallel operations
- **[Comprehensions & Filters](language/advanced.md)** - Filter/assign comprehensions, typed filters

## AI Integration

- **[byLLM Reference](plugins/byllm.md)** - `by llm()`, model configuration, tool calling, streaming, multimodal input, agentic patterns

## Full-Stack Development

- **[jac-client Reference](plugins/jac-client.md)** - Codespaces, components, state, routing, authentication, npm packages

## Deployment & Scaling

- **[jac-scale Reference](plugins/jac-scale.md)** - Production deployment, API generation, Kubernetes, monitoring

## Tools & Config

- **[CLI Commands](cli/index.md)** - Every `jac` subcommand with options and examples
- **[Configuration](config/index.md)** - Project settings via `jac.toml`
- **[Testing](testing.md)** - Test syntax, assertions, and CLI test commands

## Python Integration

- **[Interoperability](language/python-integration.md)** - Importing and using Python packages in Jac, five adoption patterns
- **[Library Mode](language/library-mode.md)** - Using Jac features from pure Python code

## Quick Reference

- **[Walker Patterns](language/walker-responses.md)** - The `.reports` array, response patterns, nested walker spawning
- **[Appendices](language/appendices.md)** - Complete keyword reference, operator quick reference, grammar, gotchas, migration guide

---

## JavaScript/npm Interoperability

### npm Packages

```jac
cl {
    import from react { useState, useEffect, useCallback }
    import from "@tanstack/react-query" { useQuery, useMutation }
    import from lodash { debounce, throttle }
    import from axios { default as axios }
}
```

### TypeScript Configuration

TypeScript is supported through the jac-client Vite toolchain for client-side code. Configure in `jac.toml`:

```toml
[plugins.client]
typescript = true
```

> **Note:** Jac does not parse TypeScript files directly. TypeScript support is provided through Vite's built-in TypeScript handling in client-side (`cl {}`) code.

### Browser APIs

```jac
cl {
    def:pub app() -> JsxElement {
        # Window
        width = window.innerWidth;

        # LocalStorage
        window.localStorage.setItem("key", "value");
        value = window.localStorage.getItem("key");

        # Document
        element = document.getElementById("my-id");

        return <div>{width}</div>;
    }

    # Fetch
    async def load_data() -> None {
        response = await fetch("/api/data");
        data = await response.json();
    }
}
```

---

## IDE & AI Tool Integration

Jac is a new language, so AI coding assistants may hallucinate syntax from outdated or nonexistent versions. The Jaseci team maintains an official condensed language reference designed for LLM context windows: [jaseci-llmdocs](https://github.com/jaseci-labs/jaseci-llmdocs).

### Setup

Grab the latest `candidate.txt` and add it to your AI tool's persistent context:

```bash
curl -LO https://github.com/jaseci-labs/jaseci-llmdocs/releases/latest/download/candidate.txt
```

### Context File Locations

| Tool | Context File |
|------|-------------|
| Claude Code | `CLAUDE.md` in project root (or `~/.claude/CLAUDE.md` for global) |
| Gemini CLI | `GEMINI.md` in project root (or `~/.gemini/GEMINI.md` for global) |
| Cursor | `.cursor/rules/jac-reference.mdc` (or Settings > Rules) |
| Antigravity | `GEMINI.md` in project root (or `.antigravity/rules.md`) |
| OpenAI Codex | `AGENTS.md` in project root (or `~/.codex/AGENTS.md` for global) |

### Quick Setup Commands

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
