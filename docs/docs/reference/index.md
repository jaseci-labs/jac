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

## Quick Start

```bash
# 1. Install
pip install jaseci

# 2. Scaffold a new project
jac create myapp --use client

# 3. Run
jac start main.jac
```

---

## CLI Quick Reference

The `jac` command is your primary interface to the Jac toolchain. For the full reference, see [CLI Commands](cli/index.md).

### Execution Commands

| Command | Description |
|---------|-------------|
| `jac run <file>` | Execute Jac program |
| `jac enter <file> <entry>` | Run named entry point |
| `jac start [file]` | Start web server |
| `jac debug <file>` | Run in debug mode |

### Analysis Commands

| Command | Description |
|---------|-------------|
| `jac check` | Type check code |
| `jac format` | Format source files |
| `jac test` | Run test suite |

### Transform Commands

| Command | Description |
|---------|-------------|
| `jac py2jac <file>` | Convert Python to Jac |
| `jac jac2py <file>` | Convert Jac to Python |
| `jac js <file>` | Compile to JavaScript |

### Project Commands

| Command | Description |
|---------|-------------|
| `jac create` | Create new project |
| `jac install` | Install all dependencies (pip, git, plugins) |
| `jac add <pkg>` | Add dependency |
| `jac remove <pkg>` | Remove dependency |
| `jac update [pkg]` | Update dependencies to latest compatible versions |
| `jac clean` | Clean build artifacts |
| `jac purge` | Purge global bytecode cache |
| `jac script <name>` | Run project script |

### Tool Commands

| Command | Description |
|---------|-------------|
| `jac dot <file>` | Generate graph visualization |
| `jac lsp` | Start language server |
| `jac config` | Manage configuration |
| `jac plugins` | Manage plugins |

---

## Plugin System

### Available Plugins

| Plugin | Package | Description |
|--------|---------|-------------|
| byllm | `pip install byllm` | LLM integration |
| jac-client | `pip install jac-client` | Full-stack web development |
| jac-scale | `pip install jac-scale` | Production deployment |
| jac-super | `pip install jac-super` | Enhanced console output |

### Managing Plugins

```bash
# List plugins
jac plugins list

# Enable plugin
jac plugins enable byllm

# Disable plugin
jac plugins disable byllm

# Plugin info
jac plugins info byllm
```

### Plugin Configuration

In `jac.toml`:

```toml
[plugins.byllm]
enabled = true
default_model = "gpt-4"

[plugins.client]
port = 5173
typescript = false

[plugins.scale]
replicas = 3
```

---

## Project Configuration

For the full reference, see [Configuration](config/index.md).

### jac.toml Structure

```toml
[project]
name = "my-app"
version = "1.0.0"
description = "My Jac application"
entry = "main.jac"

[dependencies]
numpy = "^1.24.0"
pandas = "^2.0.0"

[dependencies.dev]
pytest = "^7.0.0"

[dependencies.npm]
react = "^18.0.0"
"@mui/material" = "^5.0.0"

[plugins.byllm]
default_model = "gpt-4"

[plugins.client]
port = 5173

# Private npm registries (generates .npmrc)
[plugins.client.npm.scoped_registries]
"@mycompany" = "https://npm.pkg.github.com"

[plugins.client.npm.auth."//npm.pkg.github.com/"]
_authToken = "${NODE_AUTH_TOKEN}"

[scripts]
dev = "jac start main.jac --dev"
test = "jac test"
build = "jac build"

[environments.production]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
```

### Running Scripts

```bash
jac script dev
jac script test
jac script build
```

### Configuration Profiles

Jac supports multi-file configuration with profile-based overrides.

**File loading order** (lowest to highest priority):

| File | When loaded | Git tracked? |
|------|-------------|--------------|
| `jac.toml` | Always | Yes |
| `jac.<profile>.toml` | When `--profile` or `JAC_PROFILE` is set | Yes |
| `[environments.<profile>]` in `jac.toml` | When profile is set | Yes |
| `jac.local.toml` | Always if present | No (gitignored) |

**Using profiles:**

```bash
# Via --profile flag
jac run --profile prod app.jac
jac start --profile staging

# Via JAC_PROFILE environment variable
JAC_PROFILE=ci jac test

# Via jac.toml default
# [environment]
# default_profile = "dev"
```

**Example profile files:**

=== "jac.prod.toml"
    ```toml
    [serve]
    port = 80

    [plugins.byllm]
    default_model = "gpt-4"
    ```

=== "jac.local.toml (gitignored, developer-specific)"
    ```toml
    [serve]
    port = 9000

    [run]
    cache = false
    ```

> **Note:** `JAC_ENV` is deprecated. Use `JAC_PROFILE` instead.

### Environment Variables

**Server-side:**

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `REDIS_URL` | Redis connection URL |
| `MONGODB_URI` | MongoDB connection URI |
| `JWT_SECRET` | JWT signing secret |

**Client-side (Vite):**

Variables prefixed with `VITE_` are exposed to client. Define them in a `.env` file:

```toml
# .env
VITE_API_URL=https://api.example.com
```

Then access in client code:

```jac
cl {
    def:pub app() -> JsxElement {
        api_url = import.meta.env.VITE_API_URL;
        return <div>{api_url}</div>;
    }
}
```

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
