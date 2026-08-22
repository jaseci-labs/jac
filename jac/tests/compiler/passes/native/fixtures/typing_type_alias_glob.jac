"""A `TypeAlias` glob is a declaration a type checker reads, not a value.

Native glob lowering already skips the assignment
(`ModuleCodegenPass.is_erased_type_decl`); the import in front of it was
what still demoted the module.
"""

import from typing { TypeAlias }


glob Count: TypeAlias = int;


def pick(a: int, b: int) -> int {
    return a if a > b else b;
}


def run -> int {
    return pick(3, 8);
}
