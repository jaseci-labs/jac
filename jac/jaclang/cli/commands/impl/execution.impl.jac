"""Implementation of execution commands.

Direct implementations - no delegation to cli.jac.
"""

import marshal;
import os;
import pickle;
import sys;
import types;

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
def _proc_file_sess(filename: str, session: str, <>root: (str | None) = None) -> tuple {
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
    mach = Jac.create_j_context(session=session, <>root=<>root);
    Jac.set_context(mach);
    return (base, mod, mach);
}

"""Run the specified .jac file."""
impl run(
    filename: str, session: str = '', main: bool = True, cache: bool = True
) -> int {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    (base, mod, mach) = _proc_file_sess(filename, session);
    lng = filename.split('.')[-1];
    Jac.set_base_path(base);
    try {
        if filename.endswith(('.jac', '.py')) {
            Jac.jac_import(
                target=mod,
                base_path=base,
                override_name='__main__' if main else None,
                lng=lng
            );
        } elif filename.endswith('.jir') {
            with open(filename, 'rb') as f {
                Jac.attach_program(pickle.load(f));
                Jac.jac_import(
                    target=mod,
                    base_path=base,
                    override_name='__main__' if main else None,
                    lng=lng
                );
            }
        }
    } except Exception as e {
        import from jaclang.pycore.helpers { dump_traceback }
        print(dump_traceback(e), file=sys.stderr);
        mach.close();
        return 1;
    }
    mach.close();
    return 0;
}

"""Run the specified entrypoint function in the given .jac file."""
impl enter(
    filename: str,
    entrypoint: str,
    args: list = [],
    session: str = '',
    main: bool = True,
    <>root: str = '',
    <>node: str = ''
) -> int {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    import from jaclang.pycore.constructs { WalkerArchetype }
    (base, mod, mach) = _proc_file_sess(filename, session, <>root);
    if filename.endswith('.jac') {
        ret_module = Jac.jac_import(
            target=mod, base_path=base, override_name='__main__' if main else None
        );
    } elif filename.endswith('.jir') {
        with open(filename, 'rb') as f {
            Jac.attach_program(pickle.load(f));
            ret_module = Jac.jac_import(
                target=mod, base_path=base, override_name='__main__' if main else None
            );
        }
    } else {
        mach.close();
        print('Not a valid file!\nOnly supports `.jac` and `.jir`', file=sys.stderr);
        return 1;
    }
    if ret_module {
        (loaded_mod, ) = ret_module;
        if not loaded_mod {
            print('Errors occurred while importing the module.', file=sys.stderr);
            mach.close();
            return 1;
        } else {
            archetype = getattr(loaded_mod, entrypoint)(*args);
            mach.set_entry_node(<>node);
            if (
                isinstance(archetype, WalkerArchetype)
                and Jac.check_read_access(mach.entry_node)
            ) {
                Jac.spawn(mach.entry_node.archetype, archetype);
            }
        }
    }
    mach.close();
    return 0;
}

"""Start REST API server for the specified .jac file."""
impl start(
    filename: str,
    session: str = '',
    port: int = 8000,
    main: bool = True,
    faux: bool = False
) -> int {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    # Compute session_path BEFORE proc_file_sess so context has proper persistence
    (base, mod) = os.path.split(filename);
    base = base or os.getcwd();
    if (filename.endswith('.jac') or filename.endswith('.jir')) {
        mod = mod[:-4];
    } elif filename.endswith('.py') {
        mod = mod[:-3];
    }
    # Use .jac/data/ directory for session files (runtime artifacts)
    data_dir = os.path.join(base, ".jac", "data");
    os.makedirs(data_dir, exist_ok=True);
    session_path = session or os.path.join(data_dir, f"{mod}.session");
    # Now call proc_file_sess with the computed session_path
    (base, mod, mach) = _proc_file_sess(filename, session_path);
    lng = filename.split('.')[-1];
    Jac.set_base_path(base);
    try {
        if filename.endswith(('.jac', '.py')) {
            Jac.jac_import(target=mod, base_path=base, lng=lng);
        } elif filename.endswith('.jir') {
            with open(filename, 'rb') as f {
                Jac.attach_program(pickle.load(f));
                Jac.jac_import(target=mod, base_path=base, lng=lng);
            }
        }
        if Jac.program.errors_had {
            for error in Jac.program.errors_had {
                print(f"Error: {error}", file=sys.stderr);
            }
            mach.close();
            return 1;
        }
    } except Exception as e {
        print(f"Error loading {filename}: {e}", file=sys.stderr);
        mach.close();
        return 1;
    }
    # Get server class from plugin hook (allows jac-scale to provide enhanced server)
    ServerClass = Jac.get_api_server_class();
    server = ServerClass(
        module_name=mod, session_path=session_path, port=port, base_path=base
    );
    if faux {
        try {
            server.print_endpoint_docs();
            mach.close();
            return 0;
        } except Exception as e {
            print(f"Error generating endpoint documentation: {e}", file=sys.stderr);
            mach.close();
            return 1;
        }
    }
    try {
        server.start();
        return 0;
    } except KeyboardInterrupt {
        print('\nServer stopped.');
        mach.close();
        return 0;
    } except Exception as e {
        print(f"Server error: {e}", file=sys.stderr);
        mach.close();
        return 1;
    }
}

"""Debug the specified .jac file."""
impl debug(filename: str, main: bool = True, cache: bool = False) -> int {
    import from jaclang.pycore.program { JacProgram }
    import from jaclang.pycore.helpers { debugger as db }
    (base, mod) = os.path.split(filename);
    base = base or './';
    mod = mod[:-4];
    if filename.endswith('.jac') {
        bytecode = JacProgram().compile(filename).gen.py_bytecode;
        if bytecode {
            code = marshal.loads(bytecode);
            if db.has_breakpoint(bytecode) {
                run(filename, '', main, cache);
            } else {
                func = types.FunctionType(code, globals());
                print('Debugging with Jac debugger.\n');
                db.runcall(func);
                print('Done debugging.');
            }
        } else {
            print(f"Error while generating bytecode in {filename}.", file=sys.stderr);
            return 1;
        }
    } else {
        print('Not a .jac file.', file=sys.stderr);
        return 1;
    }
    return 0;
}
