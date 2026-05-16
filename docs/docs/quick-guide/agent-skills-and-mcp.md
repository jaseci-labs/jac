# Agent Skills and MCP

AI coding assistants are good at Jac's *ideas* but often wrong about its *syntax* -- the language has evolved, and models routinely confuse Jac with Python or JSX. The `jac` CLI ships the corrective reference built in, so there is nothing to install.

- **`jac guide`** -- curated reference guides bundled with the compiler. They are the authoritative spec for writing correct, idiomatic Jac, and any agent that can run a shell command can read them.
- **The `jac-mcp` server** -- a [Model Context Protocol](https://modelcontextprotocol.io/) server that gives your assistant live compiler tools: validate, format, lint, run, transpile, and search the docs. It also serves the same guides as MCP resources.

The two are complementary: the guides tell the model *how* Jac works; MCP lets it *verify* what it wrote against the real compiler.

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

The `jac-mcp` plugin runs a Model Context Protocol server that exposes the Jac compiler -- grammar, documentation, examples, the bundled guides, and tools to validate, format, lint, run, and transpile Jac -- to any MCP-capable assistant.

Start it with:

```bash
jac mcp
```

Then register it with your client. For Claude Code:

```bash
claude mcp add jac -- jac mcp
```

Other clients (Claude Desktop, Cursor, Windsurf, VS Code) use a JSON configuration block. The **[MCP Server reference](../reference/mcp.md)** has copy-paste configuration for every supported client, the full tool and resource catalog, transport options, and troubleshooting.

!!! tip
    Already installed Jaseci via PyPI or the install script? `jac-mcp` is likely bundled -- run `jac --version` to check. If it is missing, install it with `pip install jac-mcp`.

## Which to use

| | `jac guide` | `jac guide --export` | MCP (`jac-mcp`) |
|---|---|---|---|
| Provides | Reference knowledge, on demand | Auto-loading Agent Skills | Reference + live compiler tools |
| Discovery | Agent runs the CLI | Assistant loads by frontmatter | Client lists MCP resources/tools |
| Setup | None -- built in | One `--export` command | Run a server, register it |
| Best for | Any agent that runs a shell | Claude Code, Cursor, Agent SDK | Any MCP client; verifying code |

For the strongest setup, export the guides so your assistant *writes* idiomatic Jac, and connect `jac-mcp` so it can *validate and run* what it writes against the real compiler before handing the code back to you.

---

**Related:** [Installation](install.md) · [MCP Server reference](../reference/mcp.md) · [Import Anything](import-anything.md)
