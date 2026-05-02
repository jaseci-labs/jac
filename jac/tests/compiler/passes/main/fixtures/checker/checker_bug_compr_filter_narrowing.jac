"""Bug: isinstance filter in a list comprehension does not narrow the output expression.

Root cause: TypeCheckPass visits nodes bottom-up via exit_* hooks. exit_atom_trailer
fires for the output expression (e.g. x.sym_name) before any comprehension context
exists, because there was no enter_list_compr hook to set up narrowing ahead of time.
ListCompr nodes have no CFG nodes, so the normal CFG-based narrowing from the
`if isinstance(x, T)` filter never applied either.

Fix: Added enter_list_compr (top-down, fires BEFORE children are visited) in
type_checker_pass.impl.jac. It extracts isinstance predicates from the filter
conditions and stores them in _comprehension_narrowing on the TypeEvaluator.
When exit_atom_trailer then fires for the output expression, get_narrowed_type_for_expr
finds the key in _comprehension_narrowing and returns the narrowed type.
Added exit_list_compr to clean up using _comprehension_key_stack.

All functions below should produce 0 errors after the fix.
"""

obj NameAtom {
    has sym_name: str = "";
}

obj OtherPattern {
    has code: int = 0;
}

obj KeyValPair {
    has key: NameAtom | OtherPattern = NameAtom(),
        val: int = 0;
}

# Basic: isinstance filter on comprehension variable directly.
def collect_names(items: list[NameAtom | OtherPattern]) -> list[str] {
    return [x.sym_name for x in items if isinstance(x, NameAtom)];
}

# Attribute of comprehension variable: isinstance on x.key narrows x.key.
def collect_key_names(pairs: list[KeyValPair]) -> list[str] {
    return [
        x.key.sym_name
        for x in pairs
        if isinstance(x.key, NameAtom)
    ];
}

# Nested: two separate comprehensions each with their own narrowing.
def collect_both(
    items: list[NameAtom | OtherPattern],
    pairs: list[KeyValPair]
) -> list[str] {
    direct = [x.sym_name for x in items if isinstance(x, NameAtom)];
    from_pairs = [p.key.sym_name for p in pairs if isinstance(p.key, NameAtom)];
    result: list[str] = [];
    result.extend(direct);
    result.extend(from_pairs);
    return result;
}
