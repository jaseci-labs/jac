impl mcp_cmd(
    transport: str = "stdio",
    port: int = 3001,
    host: str = "127.0.0.1",
    mode: str = "",
    inspect: bool = False
) -> int {
    import from jaclang.project.config { get_config }
    jac_cfg = get_config();
    mcp_cfg: dict = {};
    if jac_cfg {
        mcp_cfg = jac_cfg.get_plugin_config("mcp");
    }
    transport = transport
        if transport != "stdio"
        else mcp_cfg.get("transport", transport);
    port = port if port != 3001 else mcp_cfg.get("port", port);
    host = host if host != "127.0.0.1" else mcp_cfg.get("host", host);

    if mode {
        import from jaclang.cli.mcp.mode { set_mcp_mode }
        set_mcp_mode(str(mode));
    }

    if inspect {
        _print_mcp_inventory();
        return 0;
    }

    import from jaclang.cli.mcp.server { JacMcpServer }
    JacMcpServer(transport=str(transport), port=int(port), host=str(host)).start();
    return 0;
}

impl _print_mcp_inventory -> None {
    import sys;
    import from jaclang.cli.mcp.resources { ResourceProvider }
    import from jaclang.cli.mcp.tools { ToolProvider }
    import from jaclang.cli.mcp.prompts { PromptProvider }

    rp = ResourceProvider();
    rp.index_resources();
    resources = rp.list_resources();
    tools = ToolProvider().list_tools();
    prompts = PromptProvider().list_prompts();

    w = sys.stdout.write;
    w("jac-mcp inventory\n\n");
    w(f"Resources ({len(resources)}):\n");
    for r in resources {
        w(f"  {r['uri']:40s} {r['name']}\n");
    }
    w(f"\nTools ({len(tools)}):\n");
    for t in tools {
        w(f"  {t['name']:25s} {t['description']}\n");
    }
    w(f"\nPrompts ({len(prompts)}):\n");
    for p in prompts {
        w(f"  {p['name']:25s} {p['description']}\n");
    }
}
