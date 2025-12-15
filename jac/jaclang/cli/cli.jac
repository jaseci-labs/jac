"""Command line interface tool for the Jac language."""
import ast as ast3;
import marshal;
import os;
import pickle;
import sys;
import types;
import from importlib.metadata { version as pkg_version }
import from pathlib { Path }
import from jaclang.cli.cmdreg { cmd_registry }
with entry {
    _runtime_initialized = False;
}

"""Initialize Jac runtime once on first use."""
def _ensure_jac_runtime()  -> None {
    global _runtime_initialized;
    if not _runtime_initialized {
        import from jaclang.pycore.runtime { JacRuntime as Jac }
        Jac.setup();
        _runtime_initialized = True;
    }
}

"""Generate static parser."""
@cmd_registry.register
def gen_parser()  -> str {
    import from jaclang.compiler { gen_all_parsers }
    gen_all_parsers();
    return 'Parser generated.';
}

"""Format .jac files with improved code style.\n\n    Applies consistent formatting to Jac code files to improve readability and\n    maintain a standardized code style across your project.\n\n    Args:\n        paths: One or more paths to .jac files or directories containing .jac files\n        outfile: Optional output file path (only valid when formatting a single file)\n        to_screen: Print formatted code to stdout instead of writing to file\n\n    Examples:\n        jac format myfile.jac\n        jac format file1.jac file2.jac file3.jac\n        jac format myproject/\n        jac format myfile.jac --outfile formatted.jac\n        jac format myfile.jac --to_screen\n    """
@cmd_registry.register
def format(paths: list, outfile: str = '', to_screen: bool = False) -> None {
    import from jaclang.pycore.program { JacProgram }
    if isinstance(paths, str) {
        paths = [paths];
    }
    if (outfile and (len(paths) > 1)) {
        print('Error: --outfile can only be used with a single file.', file=sys.stderr);
        <>exit(1);
    }
    def write_formatted_code(code: str, target_path: str) -> None {
        if to_screen {
            print(code);
        } elif outfile {
            with open(outfile, 'w') as f {
                f.write(code);
            }
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
            prog = JacProgram.jac_file_formatter(str(path_obj));
            if prog.errors_had {
                for error in prog.errors_had {
                    print(f"{error}", file=sys.stderr);
                }
                return (False, False);
            }
            formatted_code = prog.mod.main.gen.jac;
            original_code = prog.mod.main.source.code;
            changed = formatted_code != original_code;
            write_formatted_code(formatted_code, str(path_obj));
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

"""Create JacRuntime and return the base path, module name, and runtime state."""
def proc_file_sess(filename: str, session: str, <>root: (str | None) = None) -> tuple {
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    import from jaclang.pycore.runtime { JacUtils }
    if (session == '') {
        session = cmd_registry.args.session
        if (
            hasattr(cmd_registry, 'args')
            and hasattr(cmd_registry.args, 'session')
            and cmd_registry.args.session
        )
        else '';
    }
    (base, mod) = os.path.split(filename);
    base = base if base else './';
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
    mach = JacUtils.create_j_context(session=session, <>root=<>root);
    Jac.set_context(mach);
    return (base, mod, mach);
}

"""Run the specified .jac, .jir, or .py file.\n\n    Executes a Jac program file or Python file, loading it into the Jac runtime environment\n    and running its code. Python files are converted to Jac AST for execution.\n\n    Args:\n        filename: Path to the .jac, .jir, or .py file to run\n        session: Optional session identifier for persistent state\n        main: Treat the module as __main__ (default: True)\n        cache: Use cached compilation if available (default: True)\n\n    Examples:\n        jac run myprogram.jac\n        jac run myscript.py\n        jac run myprogram.jac --session mysession\n        jac run myprogram.jac --no-main\n    """
@cmd_registry.register
def run(
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

"""Get the object with the specified id.\n\n    Retrieves a specific object from a Jac program by its unique identifier.\n    Returns the object's state as a dictionary.\n\n    Args:\n        filename: Path to the .jac or .jir file containing the object\n        id: Unique identifier of the object to retrieve\n        session: Optional session identifier for persistent state\n        main: Treat the module as __main__ (default: True)\n\n    Examples:\n        jac get_object myprogram.jac obj123\n        jac get_object myprogram.jac obj123 --session mysession\n    """
@cmd_registry.register
def get_object(filename: str, id: str, session: str = '', main: bool = True) -> dict {
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

"""Build the specified .jac file.\n\n    Compiles a Jac source file into a Jac Intermediate Representation (.jir) file,\n    which can be executed more efficiently. Optionally performs type checking.\n\n    Args:\n        filename: Path to the .jac file to build\n        typecheck: Perform type checking during build (default: False)\n\n    Examples:\n        jac build myprogram.jac\n        jac build myprogram.jac --typecheck\n    """
@cmd_registry.register
def build(filename: str, typecheck: bool = False) -> None {
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

"""Run type checker for specified .jac files.\n\n    Performs static type analysis on Jac programs to identify potential type errors\n    without executing the code. Useful for catching errors early in development.\n\n    Args:\n        paths: One or more paths to .jac files or directories containing .jac files\n        print_errs: Print detailed error messages (default: True)\n\n    Examples:\n        jac check myprogram.jac\n        jac check file1.jac file2.jac file3.jac\n        jac check myproject/\n        jac check myprogram.jac --no-print_errs\n    """
@cmd_registry.register
def check(paths: list, print_errs: bool = True) -> None {
    import from jaclang.pycore.program { JacProgram }
    import from jaclang.pycore.settings { settings }
    allwarn = settings.all_warnings;
    if isinstance(paths, str) {
        paths = [paths];
    }
    def check_single_file(prog: JacProgram, file_path: str) -> tuple[bool, int, int] {
        path_obj = Path(file_path);
        if not path_obj.exists() {
            print(f"Error: File '{file_path}' does not exist.", file=sys.stderr);
            return (False, 0 if allwarn else 1, 0);
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
            return (False, 0 if allwarn else 1, 0);
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
            total_errors += 0 if allwarn else 1;
        }
    }
    print(
        f"Checked {total_files} '.jac' files: {(total_files - failed_files)} passed, {failed_files} with errors ({total_errors} errors, {total_warnings} warnings).",
        file=sys.stderr if total_errors else sys.stdout
    );
    if (total_errors > 0) {
        <>exit(1);
    }
}

"""Run Jac Language Server Protocol.\n\n    Starts the Jac Language Server that provides IDE features like code completion,\n    error checking, and navigation for Jac files. Used by editor extensions.\n\n    Args:\n        This command takes no parameters.\n\n    Examples:\n        jac lsp\n    """
@cmd_registry.register
def lsp()  -> None {
    import from jaclang.langserve.server { run_lang_server }
    run_lang_server();
}

"""Run the specified entrypoint function in the given .jac file.\n\n    Executes a specific function within a Jac program, allowing you to target\n    particular functionality without running the entire program. Useful for\n    testing specific components or running specific tasks.\n\n    Args:\n        filename: Path to the .jac or .jir file\n        entrypoint: Name of the function to execute\n        args: Arguments to pass to the entrypoint function\n        session: Optional session identifier for persistent state\n        main: Treat the module as __main__ (default: True)\n        root: Root executor identifier\n        node: Starting node identifier\n\n    Examples:\n        jac enter myprogram.jac main_function arg1 arg2\n        jac enter myprogram.jac process_data --node data_node data.json\n    """
@cmd_registry.register
def enter(
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
    import from jaclang.runtimelib.constructs { WalkerArchetype }
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

"""Run the test suite in the specified .jac file or directory.\n\n    Executes test functions in Jac files to verify code correctness. Tests are\n    identified by functions with names starting with \'test_\'. Provides various\n    options to control test execution and reporting.\n\n    Args:\n        filepath: Path to the .jac file or directory containing tests\n        test_name: Run a specific test (without the \'test_\' prefix)\n        filter: Filter test files using Unix shell style patterns\n        xit: Stop running tests as soon as an error is found\n        maxfail: Stop running tests after specified number of failures\n        directory: Run tests from the specified directory\n        verbose: Show detailed test information and results\n\n    Examples:\n        jac test                     # Run all tests in current directory\n        jac test mytest.jac          # Run all tests in mytest.jac\n        jac test --test_name my_test # Run only test_my_test\n        jac test --directory tests/  # Run all tests in tests/ directory\n        jac test --filter "*_unit_*" # Run tests matching the pattern\n        jac test --xit               # Stop on first failure\n        jac test --verbose           # Show detailed output\n    """
@cmd_registry.register
def <>test(
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

"""Run the specified AST tool with optional arguments.\n\n    Executes specialized tools for working with Jac's Abstract Syntax Tree (AST).\n    These tools help with code analysis, transformation, and debugging.\n\n    Args:\n        tool: Name of the AST tool to run\n        args: Optional arguments to pass to the tool\n\n    Available Tools:\n        list_tools: List all available AST tools\n\n    Examples:\n        jac tool list_tools\n        jac tool <tool_name> [args...]\n    """
@cmd_registry.register
def tool(tool: str, args: (list | None) = None) -> None {
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

"""Debug the specified .jac file using the Python debugger.\n\n    Runs a Jac program in debug mode, allowing you to set breakpoints, step through\n    code execution, inspect variables, and troubleshoot issues interactively.\n\n    Args:\n        filename: Path to the .jac file to debug\n        main: Treat the module as __main__ (default: True)\n        cache: Use cached compilation if available (default: False)\n\n    Examples:\n        jac debug myprogram.jac\n\n    Note:\n        Add breakpoints in your code using the 'breakpoint()' function.\n    """
@cmd_registry.register
def debug(filename: str, main: bool = True, cache: bool = False) -> None {
    import from jaclang.pycore.program { JacProgram }
    import from jaclang.pycore.helpers { debugger as db }
    (base, mod) = os.path.split(filename);
    base = base if base else './';
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

"""Generate a DOT graph visualization from a Jac program.\n\n    Creates a visual representation of the node graph in a Jac program using the\n    DOT graph description language. The generated file can be visualized with\n    tools like Graphviz.\n\n    Args:\n        filename: Path to the .jac file to visualize\n        session: Optional session identifier for persistent state\n        initial: Starting node for graph traversal (default: root node)\n        depth: Maximum traversal depth (-1 for unlimited)\n        traverse: Whether to traverse the graph structure (default: False)\n        connection: List of edge types to include in the visualization\n        bfs: Use breadth-first search for traversal (default: False)\n        edge_limit: Maximum number of edges to include (default: 512)\n        node_limit: Maximum number of nodes to include (default: 512)\n        saveto: Output file path for the DOT file (default: <module_name>.dot)\n        to_screen: Print DOT output to stdout instead of saving to file (default: False)\n\n    Examples:\n        jac dot myprogram.jac\n        jac dot myprogram.jac --initial root_node --depth 3\n        jac dot myprogram.jac --traverse --connection edge_type1 edge_type2\n        jac dot myprogram.jac --saveto graph.dot\n        jac dot myprogram.jac --to_screen\n    """
@cmd_registry.register
def dot(
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
    to_screen: bool = False
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
                node_limit=node_limit
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
            file_name = saveto if saveto else f"{mod}.dot";
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

"""Convert a Python file to Jac code.\n\n    Translates Python source code to equivalent Jac code, helping with migration\n    from Python to Jac. The conversion handles basic syntax and structures but\n    may require manual adjustments for complex code.\n\n    Args:\n        filename: Path to the .py file to convert\n\n    Examples:\n        jac py2jac myscript.py > converted.jac\n    """
@cmd_registry.register
def py2jac(filename: str) -> None {
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
        prog = JacProgram.jac_str_formatter(source_str=code, file_path=filename);
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

"""Convert a Jac file to Python code.\n\n    Translates Jac source code to equivalent Python code. The generated Python\n    uses direct imports from jaclang.lib, making the output clean and suitable\n    for use as a standalone library or for integrating Jac components with\n    Python projects.\n\n    Args:\n        filename: Path to the .jac file to convert\n\n    Examples:\n        jac jac2py myprogram.jac > converted.py\n    """
@cmd_registry.register
def jac2py(filename: str) -> None {
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

"""Convert a Jac file to JavaScript code.\n\n    Translates Jac source code to equivalent JavaScript/ECMAScript code using\n    the ESTree AST specification. This allows Jac programs to run in JavaScript\n    environments like Node.js or web browsers.\n\n    Args:\n        filename: Path to the .jac file to convert\n\n    Examples:\n        jac js myprogram.jac > myprogram.js\n        jac js myprogram.jac\n    """
@cmd_registry.register
def js(filename: str) -> None {
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

"""Start a REST API server for the specified .jac file.\n\n    Executes the target module and turns all functions into authenticated REST API\n    endpoints. Function signatures are introspected to create the API interface.\n    Walkers are converted to REST APIs where their fields become the interface,\n    with an additional target_node field for spawning location.\n\n    Each user gets their own persistent root node that persists across runs.\n    Users must create an account and authenticate to access the API.\n\n    Args:\n        filename: Path to the .jac file to serve\n        session: Session identifier for persistent state (default: auto-generated)\n        port: Port to run the server on (default: 8000)\n        main: Treat the module as __main__ (default: True)\n        faux: Perform introspection and print endpoint docs without starting server (default: False)\n\n    Examples:\n        jac serve myprogram.jac\n        jac serve myprogram.jac --port 8080\n        jac serve myprogram.jac --session myapp.session\n        jac serve myprogram.jac --faux\n    """
@cmd_registry.register
def serve(
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
    } except Exception as e {
        print(f"Error loading {filename}: {e}", file=sys.stderr);
        mach.close();
        <>exit(1);
    }
    session_path = session if session else os.path.join(base, f"{mod}.session");
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

"""Start the command line interface."""
def start_cli()  -> None {
    import from jaclang.pycore.runtime { JacRuntime as Jac }
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
    import from jaclang.pycore.settings { settings }
    settings.load_command_line_arguments(args);
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

with entry {
    if (__name__ == '__main__') {
        start_cli();
    }
}
