"""Bug: cast() with a union target type returns class types instead of instances.

Root cause: The cast() special-form handler in parameter_type_check.impl.jac
returned the union type as-is. When the target is (A | B), each member was
a ClassType (not an instance), so is_class_instance() returned False and
subsequent attribute accesses on the cast result were rejected with E1099.

Fix: When the cast target is a UnionType, apply clone_as_instance() to each
member that is an instantiable ClassType before returning, so the result is
a proper instance union.

All functions below should produce 0 errors after the fix.
"""

import from typing { cast }

obj FuncDef {
    has name: str = "",
        lineno: int = 0;
}

obj AsyncFuncDef {
    has name: str = "",
        lineno: int = 0;
}

obj ClassDef {
    has name: str = "",
        lineno: int = 0;
}

# cast to a two-member union, then access a shared attribute.
def get_func_name(nd: object) -> str {
    func = cast((FuncDef | AsyncFuncDef), nd);
    return func.name;  # name exists on both members
}

# cast to a two-member union, then access another shared attribute.
def get_line(nd: object) -> int {
    func = cast((FuncDef | AsyncFuncDef), nd);
    return func.lineno;  # lineno exists on both members
}

# cast to a three-member union.
def get_def_name(nd: object) -> str {
    defn = cast((FuncDef | AsyncFuncDef | ClassDef), nd);
    return defn.name;  # name exists on all three members
}
