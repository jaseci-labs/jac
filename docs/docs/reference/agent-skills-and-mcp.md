# Agent Skills and MCP

AI coding assistants are good at Jac's *ideas* but often wrong about its *syntax* -- the language has evolved, and models routinely confuse Jac with Python or JSX. The `jac` CLI ships the corrective reference built in, so there is nothing to install.

- **`jac guide`** -- curated reference guides bundled with the compiler. They are the authoritative spec for writing correct, idiomatic Jac, and any agent that can run a shell command can read them.
- **The `jac mcp` server** -- a [Model Context Protocol](https://modelcontextprotocol.io/) server that gives your assistant live compiler tools: validate, format, lint, run, transpile, and search the docs. It also serves the same guides as MCP resources.
- **`jac ai`** -- Jac's own built-in coding agent, if you'd rather not bring an external assistant at all. It knows the guides already and works with fully local models, so it runs without an API key.

These are complementary: the guides tell a model *how* Jac works; MCP lets it *verify* what it wrote against the real compiler; `jac ai` packages both into a ready-made agent.

## `jac guide` -- the built-in reference

The guides ship inside the `jac` CLI -- one per topic (`jac-core-cheatsheet`, `jac-types`, `jac-walker-patterns`, `jac-by-llm`, the `jac-sv-*` server guides, the `jac-cl-*` client guides, and more). They are always version-matched to the compiler you have installed.

```bash
jac guide                      # list every available guide
jac guide jac-types            # print a specific guide
jac guide --search walker      # find guides by keyword
jac guide --json               # machine-readable list (for tools and agents)
```

Because the guides are part of the CLI, an AI agent working in your project can self-serve them with no setup -- it just runs `jac guide`. Two things reinforce this:

- **`jac create` seeds an `AGENTS.md`** in every new project, telling agents to consult `jac guide`.
- **`jac check` diagnostics link to guides.** When the type checker flags an error it points at the relevant guide -- e.g. a type error prints `→ run 'jac guide jac-types' for guidance` -- so the model is pulled to the fix at the moment it is wrong.

## Export as Agent Skills (Claude Code, Cursor)

Claude Code, Cursor, and the Claude Agent SDK can *auto-load* [Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills) -- reading a skill's frontmatter and pulling in the full guide when a task matches. To get that automatic behaviour, export the guides as a skills directory:

=== "Personal (all projects)"

    ```bash
    jac guide --export ~/.claude/skills
    ```

=== "Project (this repo only)"

    ```bash
    jac guide --export .claude/skills
    ```

    Commit `.claude/skills/` to version control so everyone on the project gets the same Jac guidance.

`jac guide --export` writes each guide as `<dir>/<name>/SKILL.md` -- the dir-per-skill layout Claude Code and Cursor discover. Re-run it after upgrading Jac to refresh the guides. The same command works for Cursor (`jac guide --export ~/.cursor/skills`).

!!! note "Export is optional"
    You only need to export if you want *automatic* skill loading. Any agent that can run `jac guide` already has the full reference on demand.

## MCP server (any MCP client)

The built-in `jac mcp` server exposes the Jac compiler (grammar, documentation, examples, the bundled guides, and tools to validate, format, lint, run, and transpile Jac) to any MCP-capable assistant, with nothing to install. The **[MCP Server reference](mcp.md)** has copy-paste configuration for every supported client, the full tool and resource catalog, transport options, and troubleshooting.

## `jac ai` -- the built-in coding agent

If you want an agent *now*, without wiring up an external assistant, the CLI ships one:

```bash
jac ai                                   # interactive session (project's configured model)
jac ai "add a walker that lists todos"   # one-shot request
jac ai -m local:gemma-4-e4b              # fully local -- no API key
jac ai --ui                              # web UI with a live phase-graph visualizer
```

It uses your `[byllm.model]` configuration (falling back to the bundled local model), reads the same built-in guides, and can edit files and run code in your project -- pass `--safe` to approve every write and command. See the [`jac ai` reference](cli/index.md#jac-ai).

## Structured code access for agents

Two more commands exist mainly to make your project legible to agents (yours or an external one):

- **`jac code`** -- compiler-backed structural queries (`symbol`, `uses`, `map`, `walkers`, `slice`, `diag`) that return JSON. An agent can ask "which walkers touch `Todo` nodes?" instead of grepping. See the [`jac code` reference](cli/index.md#jac-code).
- **`jac browse`** -- headless-browser automation over CDP (navigate, click, snapshot, screenshot), so an agent can drive and visually verify the web app it just built. See the [`jac browse` reference](cli/index.md#jac-browse).

## Which to use

| | `jac guide` | `jac guide --export` | MCP (`jac mcp`) |
|---|---|---|---|
| Provides | Reference knowledge, on demand | Auto-loading Agent Skills | Reference + live compiler tools |
| Discovery | Agent runs the CLI | Assistant loads by frontmatter | Client lists MCP resources/tools |
| Setup | None -- built in | One `--export` command | Run a server, register it |
| Best for | Any agent that runs a shell | Claude Code, Cursor, Agent SDK | Any MCP client; verifying code |

For the strongest setup, export the guides so your assistant *writes* idiomatic Jac, and connect `jac mcp` so it can *validate and run* what it writes against the real compiler before handing the code back to you.

---

**Related:** [Installation](../quick-guide/install.md) · [AI-Assisted Development tutorial](../tutorials/ai/mcp-quickstart.md) · [MCP Server reference](mcp.md) · [Import Anything](import-anything.md)
