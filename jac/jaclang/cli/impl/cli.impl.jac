"""Start the command line interface."""

impl start_cli -> None {
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    # Auto-discover and load jac.toml project configuration
    _load_project_config();
    Jac.create_cmd();
    cmd_registry.finalize();
    parser = cmd_registry.parser;
    raw_argv = sys.argv[1:];
    if (
        raw_argv
        and not raw_argv[0].startswith('-')
        and raw_argv[0].lower().endswith(('.jac', '.jir', '.py'))
    ) {
        sys.argv = [sys.argv[0], 'run'] + raw_argv;
    }
    args = parser.parse_args();
    cmd_registry.args = args;
    if args.version {
        print(f"Jac version {pkg_version('jaclang')}");
        print('Jac path:', __file__);
        return;
    }
    if (args.command is None) {
        parser.print_help();
        return;
    }
    command = cmd_registry.get(args.command);
    if not command {
        print(f"Unknown command: {args.command}", file=sys.stderr);
        parser.print_help();
        return;
    }
    args_dict = vars(args);
    args_dict.pop('command');
    args_dict.pop('version', None);
    # Apply environment profile if specified
    _apply_env_profile(args_dict);
    allowed_params = <>set(command.sig.parameters.keys());
    filtered_args = {
        k: v
        for (k, v) in args_dict.items()
        if (k in allowed_params)
    };
    ret = command.call(**filtered_args);
    if ret {
        print(ret);
    }
}

"""Load project configuration from jac.toml if present."""
def _load_project_config -> None {
    try {
        import from jaclang.project.config { get_config, set_config }
        import from jaclang.project.dependencies { add_packages_to_path }

        # Auto-discover jac.toml
        config = get_config();
        if config is not None {
            # Add packages/ directory to Python path
            add_packages_to_path(config);
        }

        # Initialize plugin-registered dependency types
        _initialize_dependency_registry();
    } except Exception {
        # Silently ignore if project module not available or config discovery fails
        pass;
    }
}

"""Initialize the dependency registry from plugin hooks."""
def _initialize_dependency_registry -> None {
    try {
        import from jaclang.project.dep_registry { initialize_dependency_registry }
        initialize_dependency_registry();
    } except Exception {
        # Silently ignore if registry initialization fails
        pass;
    }
}

"""Apply environment profile from --env flag or JAC_ENV environment variable."""
def _apply_env_profile(args_dict: dict) -> None {
    try {
        import from jaclang.project.config { get_config }

        config = get_config();
        if config is None {
            return;
        }

        # Check for --env argument or JAC_ENV environment variable
        profile = args_dict.pop('env', None);
        if profile is None {
            profile = os.environ.get('JAC_ENV');
        }
        if profile is None and config.environment.default_profile {
            profile = config.environment.default_profile;
        }

        if profile {
            config.apply_profile(profile);
        }
    } except Exception {
        # Silently ignore profile loading errors
        pass;
    }
}

"""Start a REST API server for the specified .jac file.

Executes the target module and turns all functions into authenticated REST API
endpoints. Function signatures are introspected to create the API interface.
Walkers are converted to REST APIs where their fields become the interface,
with an additional target_node field for spawning location.

Each user gets their own persistent root node that persists across runs.
Users must create an account and authenticate to access the API.

Args:
filename: Path to the .jac file to serve
session: Session identifier for persistent state (default: auto-generated)
port: Port to run the server on (default: 8000)
main: Treat the module as __main__ (default: True)
faux: Perform introspection and print endpoint docs without starting server (default: False)

Examples:
jac serve myprogram.jac
jac serve myprogram.jac --port 8080
jac serve myprogram.jac --session myapp.session
jac serve myprogram.jac --faux
"""
impl serve(
    filename: str,
    session: str = '',
    port: int = 8000,
    main: bool = True,
    faux: bool = False
) -> None {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    import from jaclang.runtimelib.server { JacAPIServer }
    (base, mod, mach) = proc_file_sess(filename, session);
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
            <>exit(1);
        }
    } except Exception as e {
        print(f"Error loading {filename}: {e}", file=sys.stderr);
        mach.close();
        <>exit(1);
    }
    session_path = session or os.path.join(base, f"{mod}.session");
    server = JacAPIServer(
        module_name=mod, session_path=session_path, port=port, base_path=base
    );
    if faux {
        try {
            server.print_endpoint_docs();
            mach.close();
            return;
        } except Exception as e {
            print(f"Error generating endpoint documentation: {e}", file=sys.stderr);
            mach.close();
            <>exit(1);
        }
    }
    try {
        server.start();
    } except KeyboardInterrupt {
        print('\nServer stopped.');
        mach.close();
    } except Exception as e {
        print(f"Server error: {e}", file=sys.stderr);
        mach.close();
        <>exit(1);
    }
}

"""Convert a Jac file to JavaScript code.

Translates Jac source code to equivalent JavaScript/ECMAScript code using
the ESTree AST specification. This allows Jac programs to run in JavaScript
environments like Node.js or web browsers.

Args:
filename: Path to the .jac file to convert

Examples:
jac js myprogram.jac > myprogram.js
jac js myprogram.jac
"""
impl js(filename: str) -> None {
    import from jaclang.pycore.program { JacProgram }
    if filename.endswith('.jac') {
        try {
            prog = JacProgram();
            ir = prog.compile(file_path=filename);
            if prog.errors_had {
                for error in prog.errors_had {
                    print(f"Error: {error}", file=sys.stderr);
                }
                <>exit(1);
            }
            js_output = ir.gen.js or '';
            if not js_output.strip() {
                print(
                    'ECMAScript code generation produced no output.', file=sys.stderr
                );
                <>exit(1);
            }
            print(js_output);
        } except Exception as e {
            print(f"Error generating JavaScript: {e}", file=sys.stderr);
            import traceback;
            traceback.print_exc();
            <>exit(1);
        }
    } else {
        print('Not a .jac file.', file=sys.stderr);
        <>exit(1);
    }
}

"""Convert a Jac file to Python code.

Translates Jac source code to equivalent Python code. The generated Python
uses direct imports from jaclang.lib, making the output clean and suitable
for use as a standalone library or for integrating Jac components with
Python projects.

Args:
filename: Path to the .jac file to convert

Examples:
jac jac2py myprogram.jac > converted.py
"""
impl jac2py(filename: str) -> None {
    import from jaclang.pycore.program { JacProgram }
    if filename.endswith('.jac') {
        code = JacProgram().compile(file_path=filename).gen.py;
        if code {
            print(code);
        } else {
            <>exit(1);
        }
    } else {
        print('Not a .jac file.', file=sys.stderr);
        <>exit(1);
    }
}

"""Convert a Python file to Jac code.

Translates Python source code to equivalent Jac code, helping with migration
from Python to Jac. The conversion handles basic syntax and structures but
may require manual adjustments for complex code.

Args:
filename: Path to the .py file to convert

Examples:
jac py2jac myscript.py > converted.jac
"""
impl py2jac(filename: str) -> None {
    import jaclang.pycore.unitree as uni;
    import from jaclang.compiler.passes.main { PyastBuildPass }
    import from jaclang.pycore.program { JacProgram }
    import from jaclang.pycore.helpers { read_file_with_encoding }
    if filename.endswith('.py') {
        file_source = read_file_with_encoding(filename);
        code = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                ast3.parse(file_source), orig_src=uni.Source(file_source, filename)
            ),
            prog=JacProgram()
        ).ir_out.unparse(
            requires_format=False
        );
        prog = JacProgram.jac_str_formatter(
            source_str=code, file_path=filename, auto_lint=True
        );
        if prog.errors_had {
            print('Error converting Python code to Jac.', file=sys.stderr);
            <>exit(1);
        }
        print(prog.mod.main.gen.jac);
    } else {
        print('Not a .py file.');
        <>exit(1);
    }
}

"""Generate a DOT graph visualization from a Jac program.

Creates a visual representation of the node graph in a Jac program using the
DOT graph description language. The generated file can be visualized with
tools like Graphviz.

Args:
filename: Path to the .jac file to visualize
session: Optional session identifier for persistent state
initial: Starting node for graph traversal (default: root node)
depth: Maximum traversal depth (-1 for unlimited)
traverse: Whether to traverse the graph structure (default: False)
connection: List of edge types to include in the visualization
bfs: Use breadth-first search for traversal (default: False)
edge_limit: Maximum number of edges to include (default: 512)
node_limit: Maximum number of nodes to include (default: 512)
saveto: Output file path for the DOT file (default: <module_name>.dot)
to_screen: Print DOT output to stdout instead of saving to file (default: False)

Examples:
jac dot myprogram.jac
jac dot myprogram.jac --initial root_node --depth 3
jac dot myprogram.jac --traverse --connection edge_type1 edge_type2
jac dot myprogram.jac --saveto graph.dot
jac dot myprogram.jac --to_screen
"""
impl dot(
    filename: str,
    session: str = '',
    initial: str = '',
    depth: int = -1,
    traverse: bool = False,
    connection: list[str] = [],
    bfs: bool = False,
    edge_limit: int = 512,
    node_limit: int = 512,
    saveto: str = '',
    to_screen: bool = False,
    format: str = 'dot'
) -> None {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    import from jaclang.runtimelib.builtin { printgraph }
    (base, mod, jac_machine) = proc_file_sess(filename, session);
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
            return;
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
    } else {
        print('Not a .jac file.', file=sys.stderr);
        <>exit(1);
    }
}

"""Debug the specified .jac file using the Python debugger.

Runs a Jac program in debug mode, allowing you to set breakpoints, step through
code execution, inspect variables, and troubleshoot issues interactively.

Args:
filename: Path to the .jac file to debug
main: Treat the module as __main__ (default: True)
cache: Use cached compilation if available (default: False)

Examples:
jac debug myprogram.jac

Note:
Add breakpoints in your code using the 'breakpoint()' function.
"""
impl debug(filename: str, main: bool = True, cache: bool = False) -> None {
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
                run(filename, main, cache);
            } else {
                func = types.FunctionType(code, globals());
                print('Debugging with Jac debugger.\n');
                db.runcall(func);
                print('Done debugging.');
            }
        } else {
            print(f"Error while generating bytecode in {filename}.", file=sys.stderr);
            <>exit(1);
        }
    } else {
        print('Not a .jac file.', file=sys.stderr);
        <>exit(1);
    }
}

"""Run the specified AST tool with optional arguments.

Executes specialized tools for working with Jac's Abstract Syntax Tree (AST).
These tools help with code analysis, transformation, and debugging.

Args:
tool: Name of the AST tool to run
args: Optional arguments to pass to the tool

Available Tools:
list_tools: List all available AST tools

Examples:
jac tool list_tools
jac tool <tool_name> [args...]
"""
impl tool(tool: str, args: (list | None) = None) -> None {
    import from jaclang.utils.lang_tools { AstTool }
    if hasattr(AstTool, tool) {
        try {
            print(
                getattr(AstTool(), tool)(args) if args else getattr(AstTool(), tool)()
            );
        } except Exception as e {
            print(
                f"Error while running ast tool {tool}, check args: {e}",
                file=sys.stderr
            );
            raise e ;
        }
    } else {
        print(f"Ast tool {tool} not found.", file=sys.stderr);
        <>exit(1);
    }
}

"""Run the test suite in the specified .jac file or directory.

Executes test functions in Jac files to verify code correctness. Tests are
identified by functions with names starting with 'test_'. Provides various
options to control test execution and reporting.

Args:
filepath: Path to the .jac file or directory containing tests
test_name: Run a specific test (without the 'test_' prefix)
filter: Filter test files using Unix shell style patterns
xit: Stop running tests as soon as an error is found
maxfail: Stop running tests after specified number of failures
directory: Run tests from the specified directory
verbose: Show detailed test information and results

Examples:
jac test                     # Run all tests in current directory
jac test mytest.jac          # Run all tests in mytest.jac
jac test --test_name my_test # Run only test_my_test
jac test --directory tests/  # Run all tests in tests/ directory
jac test --filter "*_unit_*" # Run tests matching the pattern
jac test --xit               # Stop on first failure
jac test --verbose           # Show detailed output
"""
impl <>test(
    filepath: str,
    test_name: str = '',
    filter: str = '',
    xit: bool = False,
    maxfail: int = None,
    directory: str = '',
    verbose: bool = False
) -> None {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    failcount = Jac.run_test(
        filepath=filepath,
        func_name=('test_' + test_name) if test_name else None,
        filter=filter,
        xit=xit,
        maxfail=maxfail,
        directory=directory,
        verbose=verbose
    );
    if failcount {
        raise SystemExit(f"Tests failed: {failcount}") ;
    }
}

"""Run the specified entrypoint function in the given .jac file.

Executes a specific function within a Jac program, allowing you to target
particular functionality without running the entire program. Useful for
testing specific components or running specific tasks.

Args:
filename: Path to the .jac or .jir file
entrypoint: Name of the function to execute
args: Arguments to pass to the entrypoint function
session: Optional session identifier for persistent state
main: Treat the module as __main__ (default: True)
root: Root executor identifier
node: Starting node identifier

Examples:
jac enter myprogram.jac main_function arg1 arg2
jac enter myprogram.jac process_data --node data_node data.json
"""
impl enter(
    filename: str,
    entrypoint: str,
    args: list,
    session: str = '',
    main: bool = True,
    <>root: str = '',
    <>node: str = ''
) -> None {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    import from jaclang.pycore.constructs { WalkerArchetype }
    (base, mod, mach) = proc_file_sess(filename, session, <>root);
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
        raise ValueError('Not a valid file!\nOnly supports `.jac` and `.jir`') ;
    }
    if ret_module {
        (loaded_mod, ) = ret_module;
        if not loaded_mod {
            print('Errors occurred while importing the module.', file=sys.stderr);
            mach.close();
            <>exit(1);
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
}

"""Run Jac Language Server Protocol.

Starts the Jac Language Server that provides IDE features like code completion,
error checking, and navigation for Jac files. Used by editor extensions.

Args:
This command takes no parameters.

Examples:
jac lsp
"""
impl lsp -> None {
    import from jaclang.langserve.server { run_lang_server }
    run_lang_server();
}

"""Run type checker for specified .jac files.

Performs static type analysis on Jac programs to identify potential type errors
without executing the code. Useful for catching errors early in development.

Args:
paths: One or more paths to .jac files or directories containing .jac files
print_errs: Print detailed error messages (default: True)
warnonly: Treat errors as warnings - report but exit with success (default: False)

Examples:
jac check myprogram.jac
jac check file1.jac file2.jac file3.jac
jac check myproject/
jac check myprogram.jac --no-print_errs
jac check myprogram.jac --warnonly
"""
impl check(paths: list, print_errs: bool = True, warnonly: bool = False) -> None {
    import from jaclang.pycore.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    def check_single_file(prog: JacProgram, file_path: str) -> tuple[bool, int, int] {
        path_obj = Path(file_path);
        if not path_obj.exists() {
            print(f"Error: File '{file_path}' does not exist.", file=sys.stderr);
            return (False, 1, 0);
        }
        try {
            (err_start, warn_start) = (len(prog.errors_had), len(prog.warnings_had));
            prog.compile(file_path=file_path, type_check=True, no_cgen=True);
            new_errors = prog.errors_had[err_start:];
            new_warnings = prog.warnings_had[warn_start:];
            if print_errs {
                for e in new_errors {
                    print(f"Error: {e}", file=sys.stderr);
                }
                for w in new_warnings {
                    print(f"Warning: {w}", file=sys.stderr);
                }
            }
            return ((len(new_errors) == 0), len(new_errors), len(new_warnings));
        } except Exception as e {
            print(f"Error checking '{file_path}': {e}", file=sys.stderr);
            return (False, 1, 0);
        }
    }
    total_files = failed_files=total_errors=total_warnings=0;
    prog = JacProgram();
    for path in paths {
        path_obj = Path(path);
        if path.endswith('.jac') {
            total_files += 1;
            (success, errs, warns) = check_single_file(prog, path);
            total_errors += errs;
            total_warnings += warns;
            if not success {
                failed_files += 1;
            }
        } elif path_obj.is_dir() {
            for jac_file in path_obj.glob('**/*.jac') {
                total_files += 1;
                (success, errs, warns) = check_single_file(prog, str(jac_file));
                total_errors += errs;
                total_warnings += warns;
                if not success {
                    failed_files += 1;
                }
            }
        } else {
            print(f"Error: '{path}' is not a .jac file or directory.", file=sys.stderr);
            failed_files += 1;
            total_errors += 1;
        }
    }
    print(
        f"Checked {total_files} '.jac' files: {(total_files - failed_files)} passed, {failed_files} with errors ({total_errors} errors, {total_warnings} warnings).",
        file=sys.stderr if total_errors else sys.stdout
    );
    if (total_errors > 0 and not warnonly) {
        <>exit(1);
    }
}

"""Build the specified .jac file.

Compiles a Jac source file into a Jac Intermediate Representation (.jir) file,
which can be executed more efficiently. Optionally performs type checking.

Args:
filename: Path to the .jac file to build
typecheck: Perform type checking during build (default: False)

Examples:
jac build myprogram.jac
jac build myprogram.jac --typecheck
"""
impl build(filename: str, typecheck: bool = False) -> None {
    import from jaclang.pycore.program { JacProgram }
    if not filename.endswith('.jac') {
        print('Not a .jac file.', file=sys.stderr);
        <>exit(1);
    }
    (out := JacProgram()).compile(file_path=filename, type_check=typecheck);
    errs = len(out.errors_had);
    warnings = len(out.warnings_had);
    print(f"Errors: {errs}, Warnings: {warnings}");
    for alrt in (out.errors_had + out.warnings_had) {
        print(alrt.pretty_print(), file=sys.stderr);
    }
    if (errs > 0) {
        <>exit(1);
    }
    with open((filename[:-4] + '.jir'), 'wb') as f {
        pickle.dump(out, f);
    }
}

"""Get the object with the specified id.

Retrieves a specific object from a Jac program by its unique identifier.
Returns the object's state as a dictionary.

Args:
filename: Path to the .jac or .jir file containing the object
id: Unique identifier of the object to retrieve
session: Optional session identifier for persistent state
main: Treat the module as __main__ (default: True)

Examples:
jac get_object myprogram.jac obj123
jac get_object myprogram.jac obj123 --session mysession
"""
impl get_object(filename: str, id: str, session: str = '', main: bool = True) -> dict {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    (base, mod, mach) = proc_file_sess(filename, session);
    if filename.endswith('.jac') {
        Jac.jac_import(
            target=mod, base_path=base, override_name='__main__' if main else None
        );
    } elif filename.endswith('.jir') {
        with open(filename, 'rb') as f {
            Jac.attach_program(pickle.load(f));
            Jac.jac_import(
                target=mod, base_path=base, override_name='__main__' if main else None
            );
        }
    } else {
        mach.close();
        raise ValueError('Not a valid file!\nOnly supports `.jac` and `.jir`') ;
    }
    <>obj = Jac.get_object(id);
    if <>obj {
        data = <>obj.__jac__.__getstate__();
    } else {
        print(f"Object with id {id} not found.", file=sys.stderr);
        mach.close();
        <>exit(1);
    }
    mach.close();
    return data;
}

"""Run the specified .jac, .jir, or .py file.

Executes a Jac program file or Python file, loading it into the Jac runtime environment
and running its code. Python files are converted to Jac AST for execution.

Args:
filename: Path to the .jac, .jir, or .py file to run
session: Optional session identifier for persistent state
main: Treat the module as __main__ (default: True)
cache: Use cached compilation if available (default: True)

Examples:
jac run myprogram.jac
jac run myscript.py
jac run myprogram.jac --session mysession
jac run myprogram.jac --no-main
"""
impl run(
    filename: str, session: str = '', main: bool = True, cache: bool = True
) -> None {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    (base, mod, mach) = proc_file_sess(filename, session);
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
        <>exit(1);
    }
    mach.close();
}

"""Create JacRuntime and return the base path, module name, and runtime state."""
impl proc_file_sess(filename: str, session: str, <>root: (str | None) = None) -> tuple {
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    import from jaclang.pycore.runtime { JacUtils }
    if (session == '') {
        session = cmd_registry?.args?.session or '';
    }
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

"""Format .jac files with improved code style.

Applies consistent formatting to Jac code files to improve readability and
maintain a standardized code style across your project. Optionally applies
automatic linting corrections (e.g., converting with entry blocks to glob
declarations where appropriate) when --fix flag is provided.

Args:
paths: One or more paths to .jac files or directories containing .jac files
to_screen: Print formatted code to stdout instead of writing to file
fix: Apply auto-linting corrections before formatting (default: False)

Examples:
jac format myfile.jac
jac format file1.jac file2.jac file3.jac
jac format myproject/
jac format myfile.jac --to_screen
jac format myfile.jac --fix
"""
impl format(paths: list, to_screen: bool = False, fix: bool = False) -> None {
    import from jaclang.pycore.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    def write_formatted_code(code: str, target_path: str) -> None {
        if to_screen {
            print(code);
        } else {
            with open(target_path, 'w') as f {
                f.write(code);
            }
        }
    }
    def format_single_file(file_path: str) -> tuple[bool, bool] {
        path_obj = Path(file_path);
        if not path_obj.exists() {
            print(f"Error: File '{file_path}' does not exist.", file=sys.stderr);
            return (False, False);
        }
        try {
            prog = JacProgram.jac_file_formatter(str(path_obj), auto_lint=fix);
            if prog.errors_had {
                for error in prog.errors_had {
                    print(f"{error}", file=sys.stderr);
                }
                return (False, False);
            }
            # Write main module
            formatted_code = prog.mod.main.gen.jac;
            original_code = prog.mod.main.source.code;
            changed = formatted_code != original_code;
            write_formatted_code(formatted_code, str(path_obj));

            # Write impl modules (.impl.jac, .cl.jac files)
            # The format passes already processed them, just need to write
            for impl_mod in prog.mod.main.impl_mod {
                impl_path = impl_mod.loc.mod_path;
                impl_formatted = impl_mod.gen.jac;
                impl_original = impl_mod.source.code;
                if (impl_formatted != impl_original) {
                    write_formatted_code(impl_formatted, impl_path);
                    changed = True;
                }
            }
            return (True, changed);
        } except Exception as e {
            print(f"Error formatting '{file_path}': {e}", file=sys.stderr);
            return (False, False);
        }
    }
    total_files = 0;
    failed_files = 0;
    changed_files = 0;
    for path in paths {
        path_obj = Path(path);
        if path.endswith('.jac') {
            total_files += 1;
            (success, changed) = format_single_file(path);
            if not success {
                failed_files += 1;
            } elif changed {
                changed_files += 1;
            }
        } elif path_obj.is_dir() {
            for jac_file in path_obj.glob('**/*.jac') {
                total_files += 1;
                (success, changed) = format_single_file(str(jac_file));
                if not success {
                    failed_files += 1;
                } elif changed {
                    changed_files += 1;
                }
            }
        } else {
            print(f"Error: '{path}' is not a .jac file or directory.", file=sys.stderr);
            failed_files += 1;
        }
    }
    if (((len(paths) == 1) and Path(paths[0]).is_dir()) or (failed_files > 0)) {
        print(
            f"Formatted {(total_files - failed_files)}/{total_files} '.jac' files ({changed_files} changed).",
            file=sys.stderr
        );
    }
    if (changed_files > 0) {
        <>exit(1);
    }
}

"""Generate static parser."""
impl gen_parser -> str {
    import from jaclang.compiler { gen_all_parsers }
    gen_all_parsers();
    return 'Parser generated.';
}

"""Initialize Jac runtime once on first use."""
impl _ensure_jac_runtime -> None {
    global _runtime_initialized;
    if not _runtime_initialized {
        import from jaclang.pycore.runtime { JacRuntime as Jac }
        Jac.setup();
        _runtime_initialized = True;
    }
}

#===============================================================================
# PROJECT MANAGEMENT COMMAND IMPLEMENTATIONS
#===============================================================================
"""Initialize a new Jac project.

Creates a jac.toml configuration file and basic project structure in the
current directory or a new directory with the specified name.

Args:
    name: Optional project name. If not provided, uses current directory name.
    force: Overwrite existing jac.toml if present.

Examples:
    jac create
    jac create --name my-project
    jac create --force
"""
impl create(name: str = '', force: bool = False) -> None {
    import from jaclang.project.config { JacConfig, find_project_root }
    cwd = Path.cwd();
    # Check if already in a project
    existing = find_project_root(cwd);
    if existing and not force {
        (project_root, toml_path) = existing;
        print(f"Already in a Jac project: {toml_path}", file=sys.stderr);
        print("Use --force to reinitialize.", file=sys.stderr);
        <>exit(1);
    }
    # Determine project name
    project_name = name or cwd.name;
    # Create jac.toml
    toml_path = cwd / "jac.toml";
    if toml_path.exists() and not force {
        print(f"jac.toml already exists. Use --force to overwrite.", file=sys.stderr);
        <>exit(1);
    }
    toml_content = JacConfig.create_default_toml(project_name);
    with open(toml_path, "w") as f {
        f.write(toml_content);
    }
    print(f"Created {toml_path}");
    # Create main.jac in project root if it doesn't exist
    main_jac = cwd / f"{name}.jac";
    if not main_jac.exists() {
        with open(main_jac, "w") as f {
            f.write(
                f'''"""Main entry point for {project_name}."""

with entry {{
    print("Hello from {project_name}!");
}}
'''
            );
        }
        print(f"Created {main_jac}");
    }
    # Create or update .gitignore
    gitignore_path = cwd / ".gitignore";
    gitignore_entries = [
        "# Jac build artifacts",
        ".jac/",
        "",
        "# Python",
        "__pycache__/",
        "*.py[cod]",
        ".venv/",
        "venv/",
        "",
        "# IDE",
        ".idea/",
        ".vscode/",
        "*.swp",
        ""
    ];
    if gitignore_path.exists() {
        with open(gitignore_path, "r") as f {
            existing_content = f.read();
        }
        # Add entries that don't exist
        new_entries = [];
        for entry in gitignore_entries {
            if entry and entry not in existing_content {
                new_entries.append(entry);
            }
        }
        if new_entries {
            with open(gitignore_path, "a") as f {
                f.write("\n" + "\n".join(new_entries));
            }
            print(f"Updated {gitignore_path}");
        }
    } else {
        with open(gitignore_path, "w") as f {
            f.write("\n".join(gitignore_entries));
        }
        print(f"Created {gitignore_path}");
    }
    print(f"\nProject '{project_name}' initialized successfully!");
    print("\nNext steps:");
    print("  jac run main.jac    # Run the main entry point");
    print("  jac add <package>   # Add dependencies");
    print("  jac install         # Install all dependencies");
}

"""Install all dependencies from jac.toml.

Reads the jac.toml configuration and installs all declared dependencies
into the local packages/ directory.

Args:
    dev: Include dev dependencies in installation.
    verbose: Show detailed installation progress.

Examples:
    jac install
    jac install --dev
    jac install --verbose
"""
impl install(dev: bool = False, verbose: bool = False) -> None {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller }
    config = get_config();
    if config is None {
        print(
            "No jac.toml found. Run 'jac init' to create a project.", file=sys.stderr
        );
        <>exit(1);
    }
    print(f"Installing dependencies for '{config.project.name}'...");
    print(f"Packages directory: {config.get_packages_dir()}");
    print();
    installer = DependencyInstaller(config=config, verbose=verbose);
    success = installer.install_all(include_dev=dev);
    if success {
        print("\nAll dependencies installed successfully!");
    } else {
        print("\nSome dependencies failed to install.", file=sys.stderr);
        <>exit(1);
    }
}

"""Add dependencies to the project.

Adds one or more packages to jac.toml and installs them to the packages/
directory. Supports Python/Jac packages and git repositories.

Args:
    packages: List of package specifications (e.g., "requests>=2.28.0")
    dev: Add as development dependency.
    git: Git repository URL (for git-based dependencies).
    cl: Add as client-side dependency (requires jac-client plugin).
    verbose: Show detailed installation progress.

Examples:
    jac add requests
    jac add "numpy>=1.24" pandas
    jac add pytest --dev
    jac add --git https://github.com/user/plugin.git
    jac add --cl lodash
"""
impl add(
    packages: list = [],
    dev: bool = False,
    git: str = '',
    cl: bool = False,
    verbose: bool = False
) -> None {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller, DependencyResolver }
    config = get_config();
    if config is None {
        print(
            "No jac.toml found. Run 'jac init' to create a project.", file=sys.stderr
        );
        <>exit(1);
    }
    # Handle client-side packages via plugin-registered dependency type
    if cl {
        import from jaclang.project.dep_registry { get_dependency_registry }
        registry = get_dependency_registry();
        dep_type = registry.get_by_flag("--cl");
        if dep_type is None {
            print(
                "Error: --cl flag requires jac-client plugin to be installed.",
                file=sys.stderr
            );
            print("Install with: pip install jac-client", file=sys.stderr);
            <>exit(1);
        }
        # If no packages specified, install all using the install_all_handler
        if not packages {
            if dep_type.install_all_handler is None {
                print(
                    f"Error: No install_all handler registered for {dep_type.name}.",
                    file=sys.stderr
                );
                <>exit(1);
            }
            try {
                print(f"Installing all {dep_type.name} packages from jac.toml...");
                dep_type.install_all_handler(config);
                print(f"\nInstalled all {dep_type.name} packages successfully.");
            } except Exception as e {
                print(f"Error installing packages: {e}", file=sys.stderr);
                <>exit(1);
            }
            return;
        }
        # Install specific packages using the registered install handler
        try {
            resolver = DependencyResolver(config=config);
            for pkg_spec in packages {
                (name, version) = resolver.parse_spec(pkg_spec);
                print(f"Adding {name} ({dep_type.name})...");
                dep_type.install_handler(config, name, version, dev);
            }
            print(
                f"\nAdded {len(packages)} package(s) to [{(
                    'dependencies.' + dep_type.dev_name
                )
                if dev
                else ('dependencies.' + dep_type.name)}]"
            );
        } except Exception as e {
            print(f"Error installing packages: {e}", file=sys.stderr);
            <>exit(1);
        }
        return;
    }
    if not packages and not git {
        print("No packages specified.", file=sys.stderr);
        <>exit(1);
    }
    installer = DependencyInstaller(config=config, verbose=verbose);
    resolver = DependencyResolver(config=config);
    # Handle git dependency
    if git {
        # Use first package name or derive from URL
        if packages {
            pkg_name = packages[0];
        } else {
            # Extract name from git URL
            pkg_name = git.rstrip("/").split("/")[-1];
            if pkg_name.endswith(".git") {
                pkg_name = pkg_name[:-4];
            }
        }
        print(f"Adding {pkg_name} from git: {git}");
        config.add_dependency(pkg_name, git, dev=dev, dep_type="git");
        if installer.install_git_package(pkg_name, git) {
            config.save();
            print(f"Added {pkg_name} from git");
        } else {
            <>exit(1);
        }
        return;
    }
    # Handle Python/Jac dependencies
    for pkg_spec in packages {
        (name, version) = resolver.parse_spec(pkg_spec);
        version_str = version or ">=0.0.0";

        print(f"Adding {name}{version_str}...");

        if installer.install_package(name, version) {
            config.add_dependency(name, version_str, dev=dev, dep_type="python");
        } else {
            print(f"Failed to install {name}", file=sys.stderr);
            <>exit(1);
        }
    }
    # Save updated config
    try {
        config.save();
        print("\nUpdated jac.toml");
    } except Exception as e {
        print(f"Warning: Could not save jac.toml: {e}", file=sys.stderr);
    }
}

"""Remove dependencies from the project.

Removes one or more packages from jac.toml and uninstalls them from the
packages/ directory.

Args:
    packages: List of package names to remove.
    dev: Remove from development dependencies.
    cl: Remove client-side dependency (requires jac-client plugin).

Examples:
    jac remove requests
    jac remove pytest --dev
    jac remove --cl lodash
"""
impl remove(packages: list = [], dev: bool = False, cl: bool = False) -> None {
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies { DependencyInstaller }
    config = get_config();
    if config is None {
        print(
            "No jac.toml found. Run 'jac init' to create a project.", file=sys.stderr
        );
        <>exit(1);
    }
    if not packages {
        print("No packages specified.", file=sys.stderr);
        <>exit(1);
    }
    # Handle client-side packages via plugin-registered dependency type
    if cl {
        import from jaclang.project.dep_registry { get_dependency_registry }
        registry = get_dependency_registry();
        dep_type = registry.get_by_flag("--cl");
        if dep_type is None {
            print(
                "Error: --cl flag requires jac-client plugin to be installed.",
                file=sys.stderr
            );
            print("Install with: pip install jac-client", file=sys.stderr);
            <>exit(1);
        }
        # Use the registered remove handler
        try {
            for name in packages {
                print(f"Removing {name} ({dep_type.name})...");
                dep_type.remove_handler(config, name, dev);
            }
            print(f"\nRemoved {len(packages)} package(s)");
        } except Exception as e {
            print(f"Error removing packages: {e}", file=sys.stderr);
            <>exit(1);
        }
        return;
    }
    installer = DependencyInstaller(config=config);
    # Handle Python/Jac dependencies
    for name in packages {
        dep_type = "python";

        # Check if it's a git dependency
        if name in config.git_dependencies {
            dep_type = "git";
        }

        if config.remove_dependency(name, dev=dev, dep_type=dep_type) {
            print(f"Removed {name} from jac.toml");
            installer.uninstall_package(name);
        } else {
            print(f"Package {name} not found in dependencies", file=sys.stderr);
        }
    }
    # Save updated config
    try {
        config.save();
        print("\nUpdated jac.toml");
    } except Exception as e {
        print(f"Warning: Could not save jac.toml: {e}", file=sys.stderr);
    }
}

"""Run custom scripts defined in jac.toml.

Executes a named script from the [scripts] section of jac.toml, or lists
all available scripts.

Args:
    name: Name of the script to run.
    list_scripts: List all available scripts without running any.

Examples:
    jac script dev
    jac script build
    jac script --list_scripts
"""
impl script(name: str = '', list_scripts: bool = False) -> None {
    import subprocess;
    import shlex;
    import from jaclang.project.config { get_config }
    config = get_config();
    if config is None {
        print(
            "No jac.toml found. Run 'jac init' to create a project.", file=sys.stderr
        );
        <>exit(1);
    }
    if list_scripts or not name {
        if not config.scripts {
            print("No scripts defined in jac.toml.");
            print("\nTo add scripts, add a [scripts] section to your jac.toml:");
            print('  [scripts]');
            print('  dev = "jac run main.jac"');
            print('  test = "jac test"');
            return;
        }
        print("Available scripts:");
        for (script_name, script_cmd) in sorted(config.scripts.items()) {
            print(f"  {script_name}: {script_cmd}");
        }
        return;
    }
    if name not in config.scripts {
        print(f"Script '{name}' not found in jac.toml.", file=sys.stderr);
        print("\nAvailable scripts:");
        for script_name in sorted(config.scripts.keys()) {
            print(f"  {script_name}");
        }
        <>exit(1);
    }
    script_cmd = config.scripts[name];
    print(f"Running: {script_cmd}");
    print();
    # Run the script in a shell
    try {
        result = subprocess.run(
            script_cmd,
            shell=True,
            cwd=str(config.project_root) if config.project_root else None
        );
        <>exit(result.returncode);
    } except Exception as e {
        print(f"Error running script: {e}", file=sys.stderr);
        <>exit(1);
    }
}

"""List all installed Jac plugins.

Shows all plugins registered with the Jac runtime, including those loaded via
setuptools entry points in the 'jac' group. Plugins can extend CLI commands,
add dependency types, and provide runtime hooks.

Args:
    verbose: Show detailed plugin information including module path and hooks

Examples:
    jac plugins
    jac plugins --verbose
"""
impl plugins(verbose: bool = False) -> None {
    import from jaclang.pycore.runtime { plugin_manager }
    import from jaclang.cli.cmdreg { cmd_registry }
    # Get all registered plugins
    plugin_list = plugin_manager.list_name_plugin();
    if not plugin_list {
        print("No Jac plugins installed.");
        return;
    }
    print(f"Installed Jac plugins ({len(plugin_list)}):\n");
    for (name, plugin) in plugin_list {
        plugin_type = type(plugin);
        plugin_name = plugin_type?.__name__ or str(plugin_type);
        print(f"  {name}");

        if verbose {
            # Show module info
            module = getattr(plugin_type, '__module__', 'unknown');
            print(f"    Class: {plugin_name}");
            print(f"    Module: {module}");
            # Show implemented hooks
            hooks = [];
            for attr_name in dir(plugin) {
                if not attr_name.startswith('_') {
                    attr = getattr(plugin, attr_name, None);
                    if callable(attr)
                    and attr?.__wrapped__
                    or (hasattr(plugin_manager.hook, attr_name)) {
                        # Check if plugin implements this hook
                        try {
                            hook = getattr(plugin_manager.hook, attr_name, None);
                            if hook is not None {
                                impls = hook.get_hookimpls();
                                for impl in impls {
                                    if impl.plugin is plugin {
                                        hooks.append(attr_name);
                                        break;
                                    }
                                }
                            }
                        } except Exception {
                            pass;
                        }
                    }
                }
            }
            if hooks {
                print(f"    Hooks: {', '.join(sorted(hooks))}");
            }
            print();
        }
    }
    # Show commands registered by plugins
    plugin_commands = [];
    for (cmd_name, command) in cmd_registry.registry.items() {
        if command?.source and command?.source and command?.source != 'core' {
            plugin_commands.append((cmd_name, command.source));
        }
    }
    if plugin_commands {
        print("\nPlugin-provided commands:");
        for (cmd_name, source) in sorted(plugin_commands) {
            print(f"  {cmd_name} (from {source})");
        }
    }
}
