"""A module-level type-parameter glob is a declaration, not a runtime value.

`TypeVar` and its PEP 612 / 646 siblings read as an assignment whose value is
a call, so codegen would give the name a layout and then try to lower the
constructor call that fills it. Both are wrong: the object only ever appears
in annotations, which the backend erases, so nothing is left to lower.
"""

import from typing { ParamSpec, TypeVarTuple }


obj Item {
    has n: int = 0;
}


glob T = TypeVar('T', bound=Item),
     P = ParamSpec('P'),
     Ts = TypeVarTuple('Ts');


def first(items: list[Item]) -> int {
    return items[0].n if items else -1;
}


def run -> int {
    return first([Item(n=41)]) + 1;
}
