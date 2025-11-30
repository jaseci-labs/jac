"""Command line interface tool for the Jac language."""

import ast as ast3
import marshal
import os
import pickle
import sys
import types
from importlib.metadata import version as pkg_version
from pathlib import Path

import jaclang.compiler.unitree as uni
from jaclang.cli.cmdreg import cmd_registry
from jaclang.compiler.passes.main import PyastBuildPass
from jaclang.compiler.program import JacProgram
from jaclang.runtimelib.builtin import printgraph
from jaclang.runtimelib.constructs import WalkerArchetype
from jaclang.runtimelib.runtime import ExecutionContext, JacUtils
from jaclang.runtimelib.runtime import JacRuntime as Jac
from jaclang.runtimelib.utils import read_file_with_encoding
from jaclang.settings import settings
from jaclang.utils.helpers import debugger as db
from jaclang.utils.lang_tools import AstTool


@cmd_registry.register
def format(paths: list, outfile: str = "", to_screen: bool = False) -> None:
    """Format .jac files with improved code style.

    Applies consistent formatting to Jac code files to improve readability and
    maintain a standardized code style across your project.

    Args:
        paths: One or more paths to .jac files or directories containing .jac files
        outfile: Optional output file path (only valid when formatting a single file)
        to_screen: Print formatted code to stdout instead of writing to file

    Examples:
        jac format myfile.jac
        jac format file1.jac file2.jac file3.jac
        jac format myproject/
        jac format myfile.jac --outfile formatted.jac
        jac format myfile.jac --to_screen
    """
    # Handle single string argument for backwards compatibility
    if isinstance(paths, str):
        paths = [paths]

    if outfile and len(paths) > 1:
        print("Error: --outfile can only be used with a single file.", file=sys.stderr)
        exit(1)

    def write_formatted_code(code: str, target_path: str) -> None:
        """Write formatted code to the appropriate destination."""
        if to_screen:
            print(code)
        elif outfile:
            with open(outfile, "w") as f:
                f.write(code)
        else:
            with open(target_path, "w") as f:
                f.write(code)

    def format_single_file(file_path: str) -> bool:
        """Format a single .jac file. Returns True on success."""
        path_obj = Path(file_path)
        if not path_obj.exists():
            print(f"Error: File '{file_path}' does not exist.", file=sys.stderr)
            return False
        try:
            formatted_code = JacProgram.jac_file_formatter(str(path_obj))
            write_formatted_code(formatted_code, str(path_obj))
            return True
        except Exception as e:
            print(f"Error formatting '{file_path}': {e}", file=sys.stderr)
            return False

    total_files = 0
    failed_files = 0

    for path in paths:
        path_obj = Path(path)

        # Case 1: Single .jac file
        if path.endswith(".jac"):
            total_files += 1
            if not format_single_file(path):
                failed_files += 1
            continue

        # Case 2: Directory with .jac files
        if path_obj.is_dir():
            jac_files = list(path_obj.glob("**/*.jac"))
            for jac_file in jac_files:
                total_files += 1
                if not format_single_file(str(jac_file)):
                    failed_files += 1
            continue

        # Case 3: Invalid path
        print(f"Error: '{path}' is not a .jac file or directory.", file=sys.stderr)
        failed_files += 1

    # Only print summary for directory processing or when there are failures
    if (len(paths) == 1 and Path(paths[0]).is_dir()) or failed_files > 0:
        print(
            f"Formatted {total_files - failed_files}/{total_files} '.jac' files.",
            file=sys.stderr,
        )

    if failed_files > 0:
        exit(1)


def proc_file_sess(
    filename: str, session: str, root: str | None = None
) -> tuple[str, str, ExecutionContext]:
    """Create JacRuntime and return the base path, module name, and runtime state."""
    if session == "":
        session = (
            cmd_registry.args.session
            if hasattr(cmd_registry, "args")
            and hasattr(cmd_registry.args, "session")
            and cmd_registry.args.session
            else ""
        )
    base, mod = os.path.split(filename)
    base = base if base else "./"
    if filename.endswith(".jac") or filename.endswith(".jir"):
        mod = mod[:-4]
    elif filename.endswith(".py"):
        mod = mod[:-3]
    else:
        print(
            "Not a valid file!\nOnly supports `.jac`, `.jir`, and `.py`",
            file=sys.stderr,
        )
        exit(1)
    mach = JacUtils.create_j_context(session=session, root=root)
    Jac.set_context(mach)
    return base, mod, mach


@cmd_registry.register
def run(
    filename: str,
    session: str = "",
    main: bool = True,
    cache: bool = True,
) -> None:
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
    # if no session specified, check if it was defined via global CLI args
    # otherwise default to jaclang.session
    base, mod, mach = proc_file_sess(filename, session)
    lng = filename.split(".")[-1]
    Jac.set_base_path(base)

    if filename.endswith((".jac", ".py")):
        try:
            Jac.jac_import(
                target=mod,
                base_path=base,
                override_name="__main__" if main else None,
                lng=lng,
            )
        except Exception as e:
            from jaclang.utils.helpers import dump_traceback

            print(dump_traceback(e), file=sys.stderr)
            mach.close()
            exit(1)
    elif filename.endswith(".jir"):
        try:
            with open(filename, "rb") as f:
                Jac.attach_program(pickle.load(f))
                Jac.jac_import(
                    target=mod,
                    base_path=base,
                    override_name="__main__" if main else None,
                    lng=lng,
                )
        except Exception as e:
            from jaclang.utils.helpers import dump_traceback

            print(dump_traceback(e), file=sys.stderr)
            mach.close()
            exit(1)

    mach.close()


@cmd_registry.register
def get_object(filename: str, id: str, session: str = "", main: bool = True) -> dict:
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
    base, mod, mach = proc_file_sess(filename, session)

    if filename.endswith(".jac"):
        Jac.jac_import(
            target=mod,
            base_path=base,
            override_name="__main__" if main else None,
        )
    elif filename.endswith(".jir"):
        with open(filename, "rb") as f:
            Jac.attach_program(pickle.load(f))
            Jac.jac_import(
                target=mod,
                base_path=base,
                override_name="__main__" if main else None,
            )
    else:
        mach.close()
        raise ValueError("Not a valid file!\nOnly supports `.jac` and `.jir`")

    data = {}
    obj = Jac.get_object(id)
    if obj:
        data = obj.__jac__.__getstate__()
    else:
        print(f"Object with id {id} not found.", file=sys.stderr)
        mach.close()
        exit(1)
    mach.close()
    return data


@cmd_registry.register
def build(filename: str, typecheck: bool = False) -> None:
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
    if not filename.endswith(".jac"):
        print("Not a .jac file.", file=sys.stderr)
        exit(1)
    (out := JacProgram()).compile(file_path=filename, type_check=typecheck)
    errs = len(out.errors_had)
    warnings = len(out.warnings_had)
    print(f"Errors: {errs}, Warnings: {warnings}")

    for alrt in out.errors_had + out.warnings_had:
        print(alrt.pretty_print(), file=sys.stderr)

    if errs > 0:
        exit(1)

    with open(filename[:-4] + ".jir", "wb") as f:
        pickle.dump(out, f)


@cmd_registry.register
def check(paths: list, print_errs: bool = True) -> None:
    """Run type checker for specified .jac files.

    Performs static type analysis on Jac programs to identify potential type errors
    without executing the code. Useful for catching errors early in development.

    Args:
        paths: One or more paths to .jac files to check
        print_errs: Print detailed error messages (default: True)

    Examples:
        jac check myprogram.jac
        jac check file1.jac file2.jac file3.jac
        jac check myprogram.jac --no-print_errs
    """
    # Handle single string argument for backwards compatibility
    if isinstance(paths, str):
        paths = [paths]

    total_errors = 0
    total_warnings = 0
    failed_files = 0

    for path in paths:
        if not path.endswith(".jac"):
            print(f"Error: '{path}' is not a .jac file.", file=sys.stderr)
            failed_files += 1
            continue

        if not Path(path).exists():
            print(f"Error: File '{path}' does not exist.", file=sys.stderr)
            failed_files += 1
            continue

        try:
            (prog := JacProgram()).compile(file_path=path)

            errs = len(prog.errors_had)
            warnings = len(prog.warnings_had)
            total_errors += errs
            total_warnings += warnings

            if print_errs and prog.errors_had:
                for e in prog.errors_had:
                    print("Error:", e, file=sys.stderr)

            if errs > 0:
                failed_files += 1
        except Exception as e:
            print(f"Error checking '{path}': {e}", file=sys.stderr)
            failed_files += 1

    # Only print summary when there are issues or for single file
    if len(paths) == 1:
        if failed_files == 0:
            print(f"Errors: {total_errors}, Warnings: {total_warnings}")
    elif total_errors > 0 or total_warnings > 0:
        print(f"Total - Errors: {total_errors}, Warnings: {total_warnings}")

    if failed_files > 0 or total_errors > 0:
        exit(1)


@cmd_registry.register
def lsp() -> None:
    """Run Jac Language Server Protocol.

    Starts the Jac Language Server that provides IDE features like code completion,
    error checking, and navigation for Jac files. Used by editor extensions.

    Args:
        This command takes no parameters.

    Examples:
        jac lsp
    """
    from jaclang.langserve.server import run_lang_server  # type: ignore

    run_lang_server()


@cmd_registry.register
def enter(
    filename: str,
    entrypoint: str,
    args: list,
    session: str = "",
    main: bool = True,
    root: str = "",
    node: str = "",
) -> None:
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
    base, mod, mach = proc_file_sess(filename, session, root)

    if filename.endswith(".jac"):
        ret_module = Jac.jac_import(
            target=mod,
            base_path=base,
            override_name="__main__" if main else None,
        )
    elif filename.endswith(".jir"):
        with open(filename, "rb") as f:
            Jac.attach_program(pickle.load(f))
            ret_module = Jac.jac_import(
                target=mod,
                base_path=base,
                override_name="__main__" if main else None,
            )
    else:
        mach.close()
        raise ValueError("Not a valid file!\nOnly supports `.jac` and `.jir`")

    if ret_module:
        (loaded_mod,) = ret_module
        if not loaded_mod:
            print("Errors occurred while importing the module.", file=sys.stderr)
            mach.close()
            exit(1)
        else:
            archetype = getattr(loaded_mod, entrypoint)(*args)

            mach.set_entry_node(node)
            if isinstance(archetype, WalkerArchetype) and Jac.check_read_access(
                mach.entry_node
            ):
                Jac.spawn(mach.entry_node.archetype, archetype)
    mach.close()


@cmd_registry.register
def test(
    filepath: str,
    test_name: str = "",
    filter: str = "",
    xit: bool = False,
    maxfail: int = None,  # type:ignore
    directory: str = "",
    verbose: bool = False,
) -> None:
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
    failcount = Jac.run_test(
        filepath=filepath,
        func_name=("test_" + test_name) if test_name else None,
        filter=filter,
        xit=xit,
        maxfail=maxfail,
        directory=directory,
        verbose=verbose,
    )

    if failcount:
        raise SystemExit(f"Tests failed: {failcount}")


@cmd_registry.register
def tool(tool: str, args: list | None = None) -> None:
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
    if hasattr(AstTool, tool):
        try:
            if args and len(args):
                print(getattr(AstTool(), tool)(args))
            else:
                print(getattr(AstTool(), tool)())
        except Exception as e:
            print(
                f"Error while running ast tool {tool}, check args: {e}", file=sys.stderr
            )
            raise e
    else:
        print(f"Ast tool {tool} not found.", file=sys.stderr)
        exit(1)


@cmd_registry.register
def debug(filename: str, main: bool = True, cache: bool = False) -> None:
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
    base, mod = os.path.split(filename)
    base = base if base else "./"
    mod = mod[:-4]
    if filename.endswith(".jac"):
        bytecode = JacProgram().compile(filename).gen.py_bytecode
        if bytecode:
            code = marshal.loads(bytecode)
            if db.has_breakpoint(bytecode):
                run(filename, main, cache)
            else:
                func = types.FunctionType(code, globals())

                print("Debugging with Jac debugger.\n")
                db.runcall(func)
                print("Done debugging.")
        else:
            print(f"Error while generating bytecode in {filename}.", file=sys.stderr)
            exit(1)
    else:
        print("Not a .jac file.", file=sys.stderr)
        exit(1)


@cmd_registry.register
def dot(
    filename: str,
    session: str = "",
    initial: str = "",
    depth: int = -1,
    traverse: bool = False,
    connection: list[str] = [],  # noqa: B006
    bfs: bool = False,
    edge_limit: int = 512,
    node_limit: int = 512,
    saveto: str = "",
    to_screen: bool = False,
) -> None:
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
    base, mod, jac_machine = proc_file_sess(filename, session)

    if filename.endswith(".jac"):
        Jac.jac_import(target=mod, base_path=base, override_name="__main__")
        module = Jac.loaded_modules.get("__main__")
        mod_ns = vars(module) if module else {}
        try:
            node = mod_ns.get(initial, eval(initial, mod_ns)) if initial else None
            graph = printgraph(
                node=node,
                depth=depth,
                traverse=traverse,
                edge_type=connection,
                bfs=bfs,
                edge_limit=edge_limit,
                node_limit=node_limit,
            )
        except Exception as e:
            print(f"Error while generating graph: {e}")
            import traceback

            traceback.print_exc()
            jac_machine.close()
            return
        if to_screen:
            print(graph)
        else:
            file_name = saveto if saveto else f"{mod}.dot"
            with open(file_name, "w") as file:
                file.write(graph)
            print(f">>> Graph content saved to {os.path.join(os.getcwd(), file_name)}")
        jac_machine.close()
    else:
        print("Not a .jac file.", file=sys.stderr)
        exit(1)


@cmd_registry.register
def py2jac(filename: str) -> None:
    """Convert a Python file to Jac code.

    Translates Python source code to equivalent Jac code, helping with migration
    from Python to Jac. The conversion handles basic syntax and structures but
    may require manual adjustments for complex code.

    Args:
        filename: Path to the .py file to convert

    Examples:
        jac py2jac myscript.py > converted.jac
    """
    if filename.endswith(".py"):
        file_source = read_file_with_encoding(filename)
        code = PyastBuildPass(
            ir_in=uni.PythonModuleAst(
                ast3.parse(file_source),
                orig_src=uni.Source(file_source, filename),
            ),
            prog=JacProgram(),
        ).ir_out.unparse(requires_format=False)
        formatted_code = JacProgram().jac_str_formatter(
            source_str=code, file_path=filename
        )
        if formatted_code:
            print(formatted_code)
        else:
            print("Error converting Python code to Jac.", file=sys.stderr)
            exit(1)
    else:
        print("Not a .py file.")
        exit(1)


@cmd_registry.register
def jac2py(filename: str) -> None:
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
    if filename.endswith(".jac"):
        code = JacProgram().compile(file_path=filename).gen.py
        if code:
            print(code)
        else:
            exit(1)
    else:
        print("Not a .jac file.", file=sys.stderr)
        exit(1)


@cmd_registry.register
def js(filename: str) -> None:
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
    if filename.endswith(".jac"):
        try:
            prog = JacProgram()
            ir = prog.compile(file_path=filename)

            if prog.errors_had:
                for error in prog.errors_had:
                    print(f"Error: {error}", file=sys.stderr)
                exit(1)
            js_output = ir.gen.js or ""
            if not js_output.strip():
                print(
                    "ECMAScript code generation produced no output.",
                    file=sys.stderr,
                )
                exit(1)
            print(js_output)
        except Exception as e:
            print(f"Error generating JavaScript: {e}", file=sys.stderr)
            import traceback

            traceback.print_exc()
            exit(1)
    else:
        print("Not a .jac file.", file=sys.stderr)
        exit(1)


# Register core commands first (before plugins load)
# These can be overridden by plugins with higher priority


@cmd_registry.register
def serve(
    filename: str,
    session: str = "",
    port: int = 8000,
    main: bool = True,
    faux: bool = False,
) -> None:
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
    from jaclang.runtimelib.server import JacAPIServer

    # Process file and session
    base, mod, mach = proc_file_sess(filename, session)
    lng = filename.split(".")[-1]
    Jac.set_base_path(base)

    # Import the module
    if filename.endswith((".jac", ".py")):
        try:
            Jac.jac_import(
                target=mod,
                base_path=base,
                lng=lng,
            )
        except Exception as e:
            print(f"Error loading {filename}: {e}", file=sys.stderr)
            mach.close()
            exit(1)
    elif filename.endswith(".jir"):
        try:
            with open(filename, "rb") as f:
                Jac.attach_program(pickle.load(f))
                Jac.jac_import(
                    target=mod,
                    base_path=base,
                    lng=lng,
                )
        except Exception as e:
            print(f"Error loading {filename}: {e}", file=sys.stderr)
            mach.close()
            exit(1)

    # Create and start the API server
    # Use session path for persistent storage across user sessions
    session_path = session if session else os.path.join(base, f"{mod}.session")

    server = JacAPIServer(
        module_name=mod,
        session_path=session_path,
        port=port,
        base_path=base,
    )

    # If faux mode, print endpoint documentation and exit
    if faux:
        try:
            server.print_endpoint_docs()
            mach.close()
            return
        except Exception as e:
            print(f"Error generating endpoint documentation: {e}", file=sys.stderr)
            mach.close()
            exit(1)

    # Don't close the context - keep the module loaded for the server
    # mach.close()

    try:
        server.start()
    except KeyboardInterrupt:
        print("\nServer stopped.")
        mach.close()  # Close on shutdown
    except Exception as e:
        print(f"Server error: {e}", file=sys.stderr)
        mach.close()
        exit(1)


Jac.create_cmd()
Jac.setup()

cmd_registry.finalize()


def start_cli() -> None:
    """
    Start the command line interface.

    Returns:
    - None
    """
    parser = cmd_registry.parser
    # Default to `run` when a file is provided without a subcommand
    raw_argv = sys.argv[1:]
    if (
        raw_argv
        and not raw_argv[0].startswith("-")
        and raw_argv[0].lower().endswith((".jac", ".jir", ".py"))
    ):
        sys.argv = [sys.argv[0], "run"] + raw_argv
    args = parser.parse_args()
    cmd_registry.args = args

    # Apply global settings overrides from CLI flags before running commands
    settings.load_command_line_arguments(args)

    if args.version:
        version = pkg_version("jaclang")
        print(f"Jac version {version}")
        print("Jac path:", __file__)
        return

    if args.command is None:
        parser.print_help()
        return

    command = cmd_registry.get(args.command)
    if not command:
        print(f"Unknown command: {args.command}", file=sys.stderr)
        parser.print_help()
        return

    args_dict = vars(args)
    args_dict.pop("command")
    args_dict.pop("version", None)

    # Only pass parameters that the target command accepts
    allowed_params = set(command.sig.parameters.keys())
    filtered_args = {k: v for k, v in args_dict.items() if k in allowed_params}

    ret = command.call(**filtered_args)
    if ret:
        print(ret)


if __name__ == "__main__":
    start_cli()
