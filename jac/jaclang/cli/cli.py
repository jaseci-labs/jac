"""Command line interface tool for the Jac language."""

import ast as ast3
import importlib
import marshal
import os
import pickle
import sys
import types
from pathlib import Path
from typing import Optional

import jaclang.compiler.unitree as uni
from jaclang.cli.cmdreg import CommandShell, cmd_registry
from jaclang.compiler.passes.main import PyastBuildPass
from jaclang.compiler.program import JacProgram
from jaclang.runtimelib.builtin import printgraph
from jaclang.runtimelib.constructs import WalkerArchetype
from jaclang.runtimelib.machine import ExecutionContext, JacMachine as Jac
from jaclang.runtimelib.utils import read_file_with_encoding
from jaclang.utils.helpers import debugger as db
from jaclang.utils.lang_tools import AstTool

Jac.create_cmd()
Jac.setup()


@cmd_registry.register
def format(path: str, outfile: str = "", to_screen: bool = False) -> None:
    """Format .jac files with improved code style.

    Applies consistent formatting to Jac code files to improve readability and
    maintain a standardized code style across your project.

    Args:
        path: Path to a .jac file or directory containing .jac files
        outfile: Optional output file path (when formatting a single file)
        to_screen: Print formatted code to stdout instead of writing to file

    Examples:
        jac format myfile.jac
        jac format myproject/
        jac format myfile.jac --outfile formatted.jac
        jac format myfile.jac --to_screen
    """

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

    path_obj = Path(path)

    # Case 1: Single .jac file
    if path.endswith(".jac"):
        if not path_obj.exists():
            print(f"Error: File '{path}' does not exist.", file=sys.stderr)
            return
        formatted_code = JacProgram.jac_file_formatter(str(path_obj))
        write_formatted_code(formatted_code, str(path_obj))
        return

    # Case 2: Directory with .jac files
    if path_obj.is_dir():
        jac_files = list(path_obj.glob("**/*.jac"))
        for jac_file in jac_files:
            formatted_code = JacProgram.jac_file_formatter(str(jac_file))
            write_formatted_code(formatted_code, str(jac_file))

        print(f"Formatted {len(jac_files)} '.jac' files.", file=sys.stderr)
        return

    # Case 3: Invalid path
    print(f"Error: '{path}' is not a .jac file or directory.", file=sys.stderr)


def proc_file_sess(
    filename: str, session: str, root: Optional[str] = None
) -> tuple[str, str, ExecutionContext]:
    """Create JacMachine and return the base path, module name, and machine state."""
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
    mach = ExecutionContext(session=session, root=root)
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
    # if no session specified, check if it was defined when starting the command shell
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
            print(f"Error running {filename}: {e}", file=sys.stderr)
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
            print(f"Error running {filename}: {e}", file=sys.stderr)
    else:
        print(
            "Not a valid file!\nOnly supports `.jac`, `.jir`, and `.py`",
            file=sys.stderr,
        )

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

    with open(filename[:-4] + ".jir", "wb") as f:
        pickle.dump(out, f)


@cmd_registry.register
def bind(filename: str, typecheck: bool = False) -> None:
    """Bind the specified .jac file.

    Parses and binds a Jac source file, resolving symbols and preparing it for execution.
    This step is necessary before running the program, as it ensures all references
    are correctly linked and the program structure is validated.
    TODO: performs type checking.

    Args:
        filename: Path to the .jac file to bind
        typecheck: Print the symbol table after binding (default: False)

    Examples:
        jac bind myprogram.jac
        jac bind myprogram.jac -t
    """
    if filename.endswith((".jac", ".py")):
        (out := JacProgram()).bind(file_path=filename)
        errs = len(out.errors_had)
        warnings = len(out.warnings_had)
        if typecheck:
            for mods in out.mod.hub.values():
                if mods.name == "builtins":
                    continue
                header = (
                    f"{'=' * 6} SymTable({mods.name}) {'=' * (22 - len(mods.name))}"
                )
                divider = "=" * 40
                print(f"{divider}\n{header}\n{divider}\n{mods.sym_tab.sym_pp()}")
        print(f"Errors: {errs}, Warnings: {warnings}")
    else:
        print("Not a .jac/.py file.", file=sys.stderr)


@cmd_registry.register
def check(filename: str, print_errs: bool = True) -> None:
    """Run type checker for a specified .jac file.

    Performs static type analysis on a Jac program to identify potential type errors
    without executing the code. Useful for catching errors early in development.

    Args:
        filename: Path to the .jac file to check
        print_errs: Print detailed error messages (default: True)

    Examples:
        jac check myprogram.jac
        jac check myprogram.jac --no-print_errs
    """
    if filename.endswith(".jac"):
        (prog := JacProgram()).compile(file_path=filename)

        errs = len(prog.errors_had)
        warnings = len(prog.warnings_had)
        if print_errs:
            for e in prog.errors_had:
                print("Error:", e, file=sys.stderr)
        print(f"Errors: {errs}, Warnings: {warnings}")
    else:
        print("Not a .jac file.", file=sys.stderr)


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
    from jaclang.langserve.server import run_lang_server

    run_lang_server()


@cmd_registry.register
def lsp_dev() -> None:
    """Run Jac Language Server Protocol in Developer Mode.

    Starts the experimental Jac Language Server with enhanced features
    for development and testing. Used by editor extensions in developer mode.

    Args:
        This command takes no parameters.

    Examples:
        jac lsp_dev
    """
    from jaclang.langserve.dev_server import run_lang_server

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
def tool(tool: str, args: Optional[list] = None) -> None:
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
    else:
        print("Not a .jac file.", file=sys.stderr)


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

    Examples:
        jac dot myprogram.jac
        jac dot myprogram.jac --initial root_node --depth 3
        jac dot myprogram.jac --traverse --connection edge_type1 edge_type2
        jac dot myprogram.jac --saveto graph.dot
    """
    base, mod, jac_machine = proc_file_sess(filename, session)

    if filename.endswith(".jac"):
        Jac.jac_import(target=mod, base_path=base, override_name="__main__")
        module = Jac.loaded_modules.get("__main__")
        globals().update(vars(module))
        try:
            node = globals().get(initial, eval(initial)) if initial else None
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
        file_name = saveto if saveto else f"{mod}.dot"
        with open(file_name, "w") as file:
            file.write(graph)
        print(f">>> Graph content saved to {os.path.join(os.getcwd(), file_name)}")
        jac_machine.close()
    else:
        print("Not a .jac file.", file=sys.stderr)


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
    else:
        print("Not a .py file.")


@cmd_registry.register
def jac2py(filename: str) -> None:
    """Convert a Jac file to Python code.

    Translates Jac source code to equivalent Python code. This is useful for
    understanding how Jac code is executed or for integrating Jac components
    with Python projects.

    Args:
        filename: Path to the .jac file to convert

    Examples:
        jac jac2py myprogram.jac > converted.py
    """
    if filename.endswith(".jac"):
        code = JacProgram().compile(file_path=filename).gen.py
        print(code)
    else:
        print("Not a .jac file.", file=sys.stderr)


def start_cli() -> None:
    """
    Start the command line interface.

    Returns:
    - None
    """
    parser = cmd_registry.parser
    args = parser.parse_args()
    cmd_registry.args = args

    if args.version:
        version = importlib.metadata.version("jaclang")
        print(f"Jac version {version}")
        print("Jac path:", __file__)
        return

    command = cmd_registry.get(args.command)
    if command:
        args_dict = vars(args)
        args_dict.pop("command")
        args_dict.pop("version", None)
        ret = command.call(**args_dict)
        if ret:
            print(ret)
    else:
        CommandShell(cmd_registry).cmdloop()


if __name__ == "__main__":
    start_cli()
