import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

def py2jac(filename: str) -> int;

def jac2py(filename: str) -> int;

def jac2js(filename: str) -> int;
