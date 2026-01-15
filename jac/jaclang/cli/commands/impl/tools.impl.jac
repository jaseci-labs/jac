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
    if (filename.endswith('.jac') or filename.endswith('.jir')) {
        mod = mod[:-4];
    } elif filename.endswith('.py') {
        mod = mod[:-3];
    } else {
        print(
            'Not a valid file!\nOnly supports `.jac`, `.jir`, and `.py`',
            file=sys.stderr
        );
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
