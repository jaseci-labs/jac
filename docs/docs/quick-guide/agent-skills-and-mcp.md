# Agent Skills and MCP

AI coding assistants are good at Jac's *ideas* but often wrong about its *syntax* -- the language has evolved, and models routinely confuse Jac with Python or JSX. Two tools correct that, and they work together:

- **Agent Skills** -- a curated set of reference guides ([`Jac-Skills`](https://github.com/jaseci-labs/Jac-Skills)) that load into your assistant's context so it writes correct, idiomatic Jac.
- **The `jac-mcp` server** -- a [Model Context Protocol](https://modelcontextprotocol.io/) server that gives your assistant live compiler tools: validate, format, lint, run, transpile, and search the docs.

Set up whichever your tool of choice supports -- or both.

| | Agent Skills | MCP (`jac-mcp`) |
|---|---|---|
| What it provides | Reference knowledge -- *how* to write Jac | Live tools -- validate / format / run / search |
| How it helps | Corrects the model's stale syntax assumptions | Lets the model check its work against the real compiler |
| Supported by | Claude Code | Any MCP client -- Claude Code, Claude Desktop, Cursor, Windsurf, VS Code |
| Setup | Copy skill folders into a directory | Run a server, add it to your client config |

The two are complementary: Skills tell the model *how* Jac works; MCP lets it *verify* what it wrote. Using both gives the best results.

## Agent Skills (Claude Code)

[`Jac-Skills`](https://github.com/jaseci-labs/Jac-Skills) is a collection of focused skills -- one per topic (`jac-core-cheatsheet`, `jac-types`, `jac-walker-patterns`, `jac-by-llm`, the `jac-sv-*` server guides, the `jac-cl-*` client guides, and more). Each skill is a directory containing a single `SKILL.md`. Claude Code loads the relevant skill automatically when you work on matching code.

Claude Code discovers skills exactly one level deep -- `<skills-dir>/<skill-name>/SKILL.md` -- so copy the individual `jac-*` folders into your skills directory rather than nesting the whole repo inside it.

=== "Personal (all projects)"

    ```bash
    git clone https://github.com/jaseci-labs/Jac-Skills.git /tmp/jac-skills
    mkdir -p ~/.claude/skills
    cp -r /tmp/jac-skills/jac-* ~/.claude/skills/
    ```

=== "Project (this repo only)"

    ```bash
    git clone https://github.com/jaseci-labs/Jac-Skills.git /tmp/jac-skills
    mkdir -p .claude/skills
    cp -r /tmp/jac-skills/jac-* .claude/skills/
    ```

    Commit `.claude/skills/` to version control so everyone on the project gets the same Jac guidance.

Claude Code picks the skills up immediately -- no restart needed. To confirm, ask your assistant to list its available skills; the `jac-*` entries should appear. To update later, re-run the clone-and-copy.

!!! note "Skills are a Claude Code feature"
    Agent Skills are read by Claude Code. If your tool of choice is Cursor, Windsurf, or another assistant, use the MCP route below -- it delivers Jac knowledge through tools instead.

## MCP server (any MCP client)

The `jac-mcp` plugin runs a Model Context Protocol server that exposes the Jac compiler -- grammar, documentation, examples, and tools to validate, format, lint, run, and transpile Jac -- to any MCP-capable assistant.

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

## Using both

Skills and MCP solve different halves of the problem, so the strongest setup combines them: install the Jac-Skills so your assistant *writes* idiomatic Jac, and connect `jac-mcp` so it can *validate and run* what it writes against the real compiler before handing the code back to you.

---

**Related:** [Installation](install.md) · [MCP Server reference](../reference/mcp.md) · [Import Anything](import-anything.md)
