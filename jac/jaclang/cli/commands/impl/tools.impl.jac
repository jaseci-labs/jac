"""Implementation of tools commands.

Direct implementations - no delegation.
"""

import os;
import sys;

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
        print('Not a valid file!\nOnly supports `.jac` and `.py`', file=sys.stderr);
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
            print(
                getattr(AstTool(), tool)(args) if args else getattr(AstTool(), tool)()
            );
            return 0;
        } except Exception as e {
            print(
                f"Error while running ast tool {tool}, check args: {e}",
                file=sys.stderr
            );
            return 1;
        }
    } else {
        print(f"Ast tool {tool} not found.", file=sys.stderr);
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
            print(f"Error while generating graph: {e}");
            import traceback;
            traceback.print_exc();
            jac_machine.close();
            return 1;
        }
        if to_screen {
            print(graph);
        } else {
            file_name = saveto or f"{mod}.dot";
            with open(file_name, 'w') as file {
                file.write(graph);
            }
            print(f">>> Graph content saved to {os.path.join(os.getcwd(), file_name)}");
        }
        jac_machine.close();
        return 0;
    } else {
        print('Not a .jac file.', file=sys.stderr);
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
        print(f"Error: {e}", file=sys.stderr);
        return 1;
    }
}

"""Generate shell completion script."""
impl completions(shell: str = "bash", install: bool = False) -> int {
    import from jaclang.vendor { jaccomplete }
    import re;
    try {
        completion_code = jaccomplete.shellcode(executables=["jac"], shell=shell);

        if not install {
            # Just print the completion code
            print(completion_code);
            return 0;
        }

        # Determine the config file based on shell
        home = os.path.expanduser("~");
        if shell == "bash" {
            config_file = os.path.join(home, ".bashrc");
        } elif shell == "zsh" {
            config_file = os.path.join(home, ".zshrc");
        } elif shell == "fish" {
            config_file = os.path.join(home, ".config", "fish", "config.fish");
        } else {
            print(f"--install not supported for shell: {shell}", file=sys.stderr);
            print(
                "Please manually add the output of 'jac completions' to your shell config."
            );
            return 1;
        }

        # Markers for the completion block
        start_marker = "# >>> jac completion >>>";
        end_marker = "# <<< jac completion <<<";

        # Read existing config
        if os.path.exists(config_file) {
            with open(config_file, "r") as f {
                content = f.read();
            }
        } else {
            content = "";
        }

        # Build the new completion block
        new_block = f"{start_marker}\n{completion_code}{end_marker}\n";

        # Check if markers already exist
        pattern = re.compile(
            rf"{re.escape(start_marker)}.*?{re.escape(end_marker)}\n?", re.DOTALL
        );

        if pattern.search(content) {
            # Replace existing block
            new_content = pattern.sub(new_block, content);
            action = "Updated";
        } else {
            # Append new block
            new_content = content.rstrip() + "\n\n" + new_block
            if content.strip()
            else new_block;
            action = "Added";
        }

        # Write back
        with open(config_file, "w") as f {
            f.write(new_content);
        }

        print(f"{action} jac completions in {config_file}");
        print(f"Run 'source {config_file}' or restart your shell to activate.");
        return 0;
    } except Exception as e {
        print(f"Error generating completions: {e}", file=sys.stderr);
        return 1;
    }
}
