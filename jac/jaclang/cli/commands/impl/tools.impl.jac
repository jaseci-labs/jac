"""Implementation of tools commands.

Direct implementations - no delegation.
"""

import os;
import from jaclang.cli.console { console }

glob _runtime_initialized = False;

"""Initialize Jac runtime once on first use."""
def _ensure_jac_runtime -> None {
    global _runtime_initialized;
    if not _runtime_initialized {
        import from jaclang.pycore.runtime { JacRuntime as Jac }
        Jac.setup();
        _runtime_initialized = True;
    }
}

"""Create JacRuntime and return the base path, module name, and runtime state."""
def _proc_file(filename: str) -> tuple {
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    (base, mod) = os.path.split(filename);
    base = base or './';
    if filename.endswith('.jac') {
        mod = mod[:-4];
    } elif filename.endswith('.py') {
        mod = mod[:-3];
    } else {
        console.error('Not a valid file!\nOnly supports `.jac` and `.py`');
        <>exit(1);
    }
    # Only set base path if not already set (allows tests to override)
    if not Jac.base_path_dir {
        Jac.set_base_path(base);
    }
    # Tools run in system context (no user authentication)
    mach = Jac.create_j_context(user_root=None);
    Jac.set_context(mach);
    return (base, mod, mach);
}

"""Run the specified AST tool with optional arguments."""
impl tool(tool: str, args: list = []) -> int {
    import from jaclang.utils.lang_tools { AstTool }
    if hasattr(AstTool, tool) {
        try {
            console.print(
                getattr(AstTool(), tool)(args) if args else getattr(AstTool(), tool)()
            );
            return 0;
        } except Exception as e {
            console.error(f"Error while running ast tool {tool}, check args: {e}");
            return 1;
        }
    } else {
        console.error(f"Ast tool {tool} not found.");
        return 1;
    }
}

"""Generate graph visualization."""
impl dot(
    filename: str,
    initial: str = "",
    depth: int = -1,
    traverse: bool = False,
    connection: list = [],
    bfs: bool = False,
    edge_limit: int = 512,
    node_limit: int = 512,
    saveto: str = "",
    to_screen: bool = False,
    format: str = "dot"
) -> int {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    import from jaclang.runtimelib.builtin { printgraph }
    (base, mod, jac_machine) = _proc_file(filename);
    if filename.endswith('.jac') {
        Jac.jac_import(target=mod, base_path=base, override_name='__main__');
        module = Jac.loaded_modules.get('__main__');
        mod_ns = vars(module) if module else {};
        try {
            <>node = mod_ns.get(initial, eval(initial, mod_ns)) if initial else None;
            graph = printgraph(
                <>node=<>node,
                depth=depth,
                traverse=traverse,
                edge_type=connection,
                bfs=bfs,
                edge_limit=edge_limit,
                node_limit=node_limit,
                format=format
            );
        } except Exception as e {
            console.print(f"Error while generating graph: {e}");
            import traceback;
            traceback.print_exc();
            jac_machine.close();
            return 1;
        }
        if to_screen {
            console.print(graph);
        } else {
            file_name = saveto or f"{mod}.dot";
            with open(file_name, 'w') as file {
                file.write(graph);
            }
            console.print(
                f">>> Graph content saved to {os.path.join(os.getcwd(), file_name)}"
            );
        }
        jac_machine.close();
        return 0;
    } else {
        console.error('Not a .jac file.');
        return 1;
    }
}

"""Run Jac Language Server Protocol."""
impl lsp -> int {
    import from jaclang.langserve.server { run_lang_server }
    try {
        run_lang_server();
        return 0;
    } except Exception as e {
        console.error(f"Error: {e}");
        return 1;
    }
}

"""Generate shell completion script."""
impl completions(shell: str = "bash", install: bool = False) -> int {
    import from jaclang.cli.jaccomplete { static_shellcode as shellcode }
    import from jaclang.cli.registry { get_registry }
    import from jaclang.cli.command { ArgKind }
    code = shellcode(_extract_commands(get_registry()), executable="jac", shell=shell);
    if install {
        return _install_completion(shell, code);
    }
    console.print(code);
    return 0;
}

"""Extract command data from registry into simple dicts for shellcode generation."""
def _extract_commands(registry: Any) -> list {
    import from jaclang.cli.command { ArgKind }
    commands = [];
    for (name, spec) in sorted(registry.commands.items()) {
        flags = [];
        value_opts = [];
        has_file_positional = False;
        for arg in spec.get_all_args() {
            short = f"-{arg.short}" if arg.short else None;
            if arg.kind == ArgKind.FLAG or arg.typ == bool {
                flags.append((f"--{arg.name}", short, arg.help or ""));
                flags.append((f"--no-{arg.name}", None, f"Disable {arg.name}"));
            } elif arg.kind == ArgKind.OPTION {
                if arg.choices {
                    value_opts.append(
                        (f"--{arg.name}", short, [str(c) for c in arg.choices])
                    );
                } else {
                    flags.append((f"--{arg.name}", short, arg.help or ""));
                }
            } elif arg.kind in (ArgKind.POSITIONAL, ArgKind.MULTI, ArgKind.REMAINDER) {
                has_file_positional = True;
            }
        }
        commands.append(
            {
                "name": name,
                "help": spec.help or "",
                "flags": flags,
                "value_opts": value_opts,
                "has_file_positional": has_file_positional,

            }
        );
    }
    return commands;
}

def _install_completion(shell: str, code: str) -> int {
    import re;
    home = os.path.expanduser("~");
    jac_dir = os.path.join(home, ".jac");
    os.makedirs(jac_dir, exist_ok=True);
    # Shell config files
    config_map = {
        "bash": os.path.join(home, ".bashrc"),
        "zsh": os.path.join(home, ".zshrc"),
        "fish": os.path.join(home, ".config", "fish", "config.fish"),

    };
    # Completion script files stored in ~/.jac/
    ext_map = {"bash": "bash", "zsh": "zsh", "fish": "fish"};
    if shell not in config_map {
        console.error(f"Shell {shell} not supported for automatic installation.");
        return 1;
    }
    # Write completion script to ~/.jac/completions.<shell>
    comp_file = os.path.join(jac_dir, f"completions.{ext_map[shell]}");
    try {
        with open(comp_file, "w") as f {
            f.write(code);
        }
    } except Exception as e {
        console.error(f"Error writing completion script: {e}");
        return 1;
    }
    # Add a source line to shell config
    config_file = config_map[shell];
    start_marker = "# >>> jac completion >>>";
    end_marker = "# <<< jac completion <<<";
    q = '"';
    if shell == "fish" {
        source_line = "source " + comp_file;
    } else {
        source_line = "[[ -f " + q + comp_file + q + " ]] && source " + q + comp_file + q;
    }
    new_block = f"{start_marker}\n{source_line}\n{end_marker}\n";
    if os.path.exists(config_file) {
        with open(config_file, "r") as f {
            content = f.read();
        }
    } else {
        content = "";
    }
    pattern = re.compile(
        rf"{re.escape(start_marker)}.*?{re.escape(end_marker)}\n?", re.DOTALL
    );
    if pattern.search(content) {
        content = pattern.sub(new_block, content);
        action = "Updated";
    } else {
        content = content.rstrip() + "\n\n" + new_block
        if content.strip()
        else new_block;
        action = "Added";
    }
    try {
        os.makedirs(os.path.dirname(config_file), exist_ok=True);
        with open(config_file, "w") as f {
            f.write(content);
        }
        console.print(f"Completion script written to {comp_file}");
        console.print(f"{action} source line in {config_file}");
        console.print(f"Run 'source {config_file}' or restart your shell to activate.");
        return 0;
    } except Exception as e {
        console.error(f"Error writing config: {e}");
        return 1;
    }
}
