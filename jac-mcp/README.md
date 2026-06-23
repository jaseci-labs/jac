<div align="center">

[About Jac] | [Quick Start] | [Full Reference] | [Discord]

</div>

[About Jac]: https://www.jac-lang.org
[Quick Start]: https://docs.jaseci.org/quick-guide/agent-skills-and-mcp/
[Full Reference]: https://docs.jaseci.org/reference/mcp/
[Discord]: https://discord.gg/6j3QNdtcN6

# jac-mcp : MCP Server for AI-Assisted Jac Development

`jac-mcp` is a plugin for the Jac language that provides a [Model Context Protocol](https://modelcontextprotocol.io/) server, giving AI assistants deep knowledge of Jac. It exposes grammar specifications, documentation, code examples, compiler tools, and prompt templates through a standardized protocol -- so any MCP-compatible AI client can write, validate, format, and debug Jac code.

## Installation

`jac-mcp` is a plugin that runs on top of the `jac` binary, which provides the jaclang runtime. Install the binary first (see the [installation guide](https://docs.jaseci.org/quick-guide/install/)), then add the plugin:

```bash
jac install jac-mcp
```

> `jaclang` is provided by the `jac` binary at runtime (a host dependency); it is not pulled from PyPI.

## Quick Start

Start the MCP server with the default **stdio** transport, ready for IDE integration:

```bash
jac mcp
```

Inspect the available resources, tools, and prompts:

```bash
jac mcp --inspect
```

Then add the server to your AI client's MCP configuration. A minimal entry looks like:

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

See the [MCP reference](https://docs.jaseci.org/reference/mcp/) for the full list of tools, resources, prompts, transport options, and per-IDE integration steps.

## Documentation

- **Agent Skills & MCP guide**: [https://docs.jaseci.org/quick-guide/agent-skills-and-mcp/](https://docs.jaseci.org/quick-guide/agent-skills-and-mcp/)
- **MCP reference**: [https://docs.jaseci.org/reference/mcp/](https://docs.jaseci.org/reference/mcp/)
- **Jac language**: [https://www.jac-lang.org](https://www.jac-lang.org)
- **GitHub repository**: [https://github.com/jaseci-labs/jaseci](https://github.com/jaseci-labs/jaseci)

## License

MIT
