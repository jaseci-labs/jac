# Reference

The complete technical reference for Jac -- pure lookup, organized by subject. If you're new, start with [**Build Anything**](../quick-guide/project-kinds.md) and the guided [**"I like to build…"** tracks](../build/cli-and-native.md), or work through the [**Learn**](../tutorials/language/basics.md) tutorials. Come here when you need the exact syntax, option, or API.

## How to use this reference

- **Looking up language syntax?** → [Language](#language) below.
- **Looking up a `jac` command?** → [CLI Commands](cli/index.md).
- **Configuring a project?** → [Configuration (`jac.toml`)](config/index.md).
- **Wiring AI, deployment, or the full-stack client?** → [Capabilities and Plugins](#capabilities-and-plugins).

---

## Language

The core language -- syntax, types, objects, graphs, concurrency, and native compilation.

- **[Foundation](language/foundation.md)** -- syntax, types, literals, variables, scoping, operators, control flow, pattern matching
- **[Primitives & Codespace Semantics](language/primitives.md)** -- values, the `sv`/`cl`/`na` codespaces
- **[Functions & Objects](language/functions-objects.md)** -- `can` vs `def`, OOP, inheritance, enums, impl blocks
- **[Access Modifiers](language/access-modifiers.md)** -- `:pub` / `:protect` / `:priv` across member, module, and service contexts
- **[Object-Spatial Programming](language/osp.md)** -- nodes, edges, walkers, `visit`/`report`/`disengage`, graph queries
- **[Concurrency](language/concurrency.md)** -- async/await, `flow`/`wait`, parallel operations
- **[Comprehensions & Filters](language/advanced.md)** -- filter/assign comprehensions, typed filters
- **[Walker Patterns](language/walker-responses.md)** -- the `.reports` array, response patterns, nested spawning
- **[Appendices](language/appendices.md)** -- keyword & operator reference, grammar, gotchas, migration
- **[Syntax Cheatsheet](../quick-guide/syntax-cheatsheet.md)** -- one-page lookup
- **[Native Compilation](language/native-pathway.md)** -- compiling to native binaries and C-ABI shared libraries

## Capabilities and Plugins

AI, deployment, and the full-stack frameworks. byLLM and Scale are **built into the `jac` binary** (capability-gated); jac-client and jac-desktop are first-party plugins that ship with core.

- **[byLLM](plugins/byllm.md)** -- `by llm()`, model config, tool calling, streaming, multimodal, agentic patterns
- **Scale** -- production serving, storage, and Kubernetes (built into `jaclang` core):
  - [Overview](plugins/jac-scale.md) · [HTTP API & Walkers](plugins/jac-scale-http.md) · [Data & Storage](plugins/jac-scale-persistence.md) · [Kubernetes & Operations](plugins/jac-scale-kubernetes.md)
- **[jac-client](plugins/jac-client.md)** -- codespaces, components, state, routing, auth, npm packages, web/PWA/mobile targets
- **[jac-desktop](plugins/jac-desktop.md)** -- native desktop window, sidecar bundling, `[plugins.desktop]` config

## Python Integration

- **[Interoperability](language/python-integration.md)** -- importing and using Python packages in Jac, the adoption patterns
- **[Library Mode](language/library-mode.md)** -- using Jac from pure Python (`jaclang.lib`, `jac2py`)
- **[Import Anything](../quick-guide/import-anything.md)** -- importing from PyPI, npm, and C across the codespaces

## Developer Workflow

- **[CLI Commands](cli/index.md)** -- every `jac` subcommand with options and examples
- **[MCP Server](mcp.md)** -- expose your project to AI coding assistants via `jac mcp`
- **[Agent Skills & MCP](../quick-guide/agent-skills-and-mcp.md)** -- `jac guide`, exportable skills, and when to use each
- **[Plugin Authoring](plugin-authoring.md)** -- write your own CLI/runtime/config plugin
- **[Configuration](config/index.md)** -- `jac.toml`, profiles, environments
- **[Publishing Packages](publishing.md)** -- building wheels and npm tarballs
- **[Persistence & Schema Migration](persistence.md)** -- the `root` graph, schema drift, migrations
- **[Errors & Warnings](diagnostics.md)** -- diagnostic codes
- **[Code Organization](code-organization.md)** · **[Testing](testing.md)**

---

## Quick start

```bash
# 1. Install the jac binary
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash

# 2. Scaffold a new project (pick a kind -- see Build Anything)
jac create myapp --kind web-app

# 3. Run it
jac start
```

`main.jac` is the default entry point; pass a different name explicitly (e.g. `jac start app.jac`). See [Installation](../quick-guide/install.md) for details.

---

## Using Jac with AI coding assistants

Jac is a young language, so AI assistants may hallucinate outdated syntax. The Jaseci team maintains an official condensed reference sized for LLM context windows: [jaseci-llmdocs](https://github.com/jaseci-labs/jaseci-llmdocs). Add it to your assistant's persistent context:

```bash
curl -LO https://github.com/jaseci-labs/jaseci-llmdocs/releases/latest/download/candidate.txt
```

| Tool | Context file | Quick setup |
|------|-------------|-------------|
| Claude Code | `CLAUDE.md` (or `~/.claude/CLAUDE.md`) | `cat candidate.txt >> CLAUDE.md` |
| Gemini CLI / Antigravity | `GEMINI.md` | `cat candidate.txt >> GEMINI.md` |
| Cursor | `.cursor/rules/jac-reference.mdc` | `mkdir -p .cursor/rules && cp candidate.txt .cursor/rules/jac-reference.mdc` |
| OpenAI Codex | `AGENTS.md` (or `~/.codex/AGENTS.md`) | `cat candidate.txt >> AGENTS.md` |

For a live, always-current option, point your assistant at the built-in [MCP server](mcp.md) (`jac mcp`) instead. Pull a fresh `candidate.txt` when you upgrade Jac.
