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

glob _runtime_initialized = False;

def _ensure_jac_runtime -> None;

@cmd_registry.register
def gen_parser -> str;

@cmd_registry.register
def format(
    paths: list, outfile: str = '', to_screen: bool = False, fix: bool = False
) -> None;

def proc_file_sess(filename: str, session: str, <>root: (str | None) = None) -> tuple;

@cmd_registry.register
def run(
    filename: str, session: str = '', main: bool = True, cache: bool = True
) -> None;

@cmd_registry.register
def get_object(filename: str, id: str, session: str = '', main: bool = True) -> dict;

@cmd_registry.register
def build(filename: str, typecheck: bool = False) -> None;

@cmd_registry.register
def check(paths: list, print_errs: bool = True, warnonly: bool = False) -> None;

@cmd_registry.register
def lsp -> None;

@cmd_registry.register
def enter(
    filename: str,
    entrypoint: str,
    args: list,
    session: str = '',
    main: bool = True,
    <>root: str = '',
    <>node: str = ''
) -> None;

@cmd_registry.register
def <>test(
    filepath: str,
    test_name: str = '',
    filter: str = '',
    xit: bool = False,
    maxfail: int = None,
    directory: str = '',
    verbose: bool = False
) -> None;

@cmd_registry.register
def tool(tool: str, args: (list | None) = None) -> None;

@cmd_registry.register
def debug(filename: str, main: bool = True, cache: bool = False) -> None;

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
    to_screen: bool = False,
    format: str = 'dot'
) -> None;

@cmd_registry.register
def py2jac(filename: str) -> None;

@cmd_registry.register
def jac2py(filename: str) -> None;

@cmd_registry.register
def js(filename: str) -> None;

@cmd_registry.register
def serve(
    filename: str,
    session: str = '',
    port: int = 8000,
    main: bool = True,
    faux: bool = False
) -> None;

#===============================================================================
# PROJECT MANAGEMENT COMMANDS
#===============================================================================
@cmd_registry.register
def create(name: str = 'main', force: bool = False) -> None;

@cmd_registry.register
def install(dev: bool = False, verbose: bool = False) -> None;

@cmd_registry.register
def add(
    packages: list = [],
    dev: bool = False,
    git: str = '',
    cl: bool = False,
    verbose: bool = False
) -> None;

@cmd_registry.register
def remove(packages: list = [], dev: bool = False, cl: bool = False) -> None;

@cmd_registry.register
def script(name: str = '', list_scripts: bool = False) -> None;

def start_cli -> None;

with entry:__main__ {
    start_cli();
}
