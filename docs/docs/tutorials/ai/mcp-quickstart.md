# AI-Assisted Development with MCP

Connect your AI coding assistant to the live Jac compiler in five minutes. The built-in `jac mcp` server exposes ~19 tools (validate, lint, run, transpile, explain errors, search docs), the bundled reference guides, and every example project over the [Model Context Protocol](https://modelcontextprotocol.io/) -- so your assistant stops guessing at Jac syntax and starts checking its work against the real compiler.

**What you'll do:**

1. Start the MCP server and inspect what it offers
2. Connect Claude Code (or any MCP client)
3. Use it: a write → validate → run loop where the assistant verifies its own Jac

**Time:** ~10 minutes. Nothing to install -- the server ships inside the `jac` binary with zero third-party dependencies.

---

## 1. See what the server offers

```bash
jac mcp --inspect
```

This prints the full inventory and exits: **51 resources** (the bundled guides like `jac://guide/jac-walker-patterns`, the grammar spec, and complete example apps), **19 tools**, and **9 prompts** (scaffolds like `write_walker` and `fix_type_error`). The tools your assistant will lean on most:

| Tool | What it does |
|---|---|
| `validate_jac` | Full type-checked validation with structured errors |
| `check_syntax` | Fast parse-only check |
| `run_jac` | Execute code and return stdout/stderr |
| `lint_jac` / `format_jac` | Style checks with auto-fix |
| `explain_error` | Root cause + fix example for a compiler error |
| `jac_to_py` / `jac_to_js` | Show the generated Python / JavaScript |
| `search_docs` | Ranked snippets from the guides and reference |
| `graph_visualize` | Run code and return the resulting graph as DOT/JSON |

## 2. Connect your client

For **Claude Code**, one command:

```bash
claude mcp add jac -- jac mcp
```

For **Claude Desktop, Cursor, Windsurf, or VS Code**, add the standard stdio-server block to the client's MCP config (exact file locations and copy-paste snippets for each client are in the [MCP Server reference](../../reference/mcp.md)):

```json
{
  "mcpServers": {
    "jac": {
      "command": "jac",
      "args": ["mcp"]
    }
  }
}
```

Restart the client and the Jac tools appear in its tool list. If your model is small or its context is tight, register the server as `jac mcp --mode lite` to expose a reduced tool set.

## 3. Use it -- the verify loop

Open a conversation in your connected assistant and try:

> *"Write a Jac walker that counts all nodes reachable from root, **validate it with the jac tools**, and run it on a small example graph."*

Watch the tool calls: the assistant drafts code, calls `validate_jac`, gets structured type errors back (not a guess -- the actual compiler), fixes them, then `run_jac` executes the result and returns real output. Two habits make this loop reliable:

- **Ask for validation explicitly** at first ("validate with the jac tools before showing me code"); most assistants then adopt the habit for the rest of the session.
- **Point it at the guides for idioms**: "check `jac://guide/jac-walker-patterns` first" -- or let it discover them with `search_docs`.

When the assistant hits a compiler error it can't parse, `explain_error` returns the error's category, root cause, and a fix example -- the same content `jac check` links to in your terminal.

## Beyond MCP

- **Auto-loaded skills instead of a server**: `jac guide --export ~/.claude/skills` writes the same guides as Agent Skills that Claude Code and Cursor load automatically -- see [Agent Skills and MCP](../../quick-guide/agent-skills-and-mcp.md) for when to use which.
- **Jac's own agent**: `jac ai` is a built-in coding agent that already knows the guides and runs against local models with no API key -- see the [`jac ai` reference](../../reference/cli/index.md#jac-ai).
- **Full tool catalog, transports, troubleshooting**: the [MCP Server reference](../../reference/mcp.md).
