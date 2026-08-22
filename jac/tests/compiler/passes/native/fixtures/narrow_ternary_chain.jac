"""N2: narrowing that has to survive a ternary chain.

Two sites in `unitree` want a nested ternary and got a flat if/elif instead.

`UniScopeNode.insert` resolves its `AstAccessNode | None | SymbolAccess`
parameter with

    access_spec if isinstance(access_spec, SymbolAccess)
        else access_spec.access_type if access_spec else SymbolAccess.PUBLIC

so the middle arm's `.access_type` read is only well-typed because the outer
`else` removed the enum member and the inner condition removed `None`. The
flat form in `isinstance_enum_union.jac` proves the *narrow* is computable;
what this fixture asks is whether it survives when the consumer is a select
arm instead of an assignment target.

`Archetype._get_impl_resolved_body` wants the same shape one level deeper --
a nested ternary over `list` and a node that holds a list -- and its answer
is a container, so the result's element type has to survive the select too.
"""

enum Access { PRIVATE = 'private', PUBLIC = 'public', PROTECTED = 'protected' }

obj AccessNode {
    has access_type: Access = Access.PROTECTED;
}


obj Item {
    has n: int = 0;
}


obj ImplDef {
    has body: list[Item] | Item;
}


"""Total order on the members so a wrong arm is a wrong number."""
def _rank(resolved: Access) -> int {
    if resolved == Access.PRIVATE {
        return 0;
    }
    if resolved == Access.PUBLIC {
        return 1;
    }
    return 2;
}


"""The union in `insert`'s declared order: node, absent, already-resolved."""
def _mk_spec(pick: int) -> AccessNode | None | Access {
    if pick == 1 {
        return Access.PRIVATE;
    }
    if pick == 2 {
        return AccessNode(access_type=Access.PROTECTED);
    }
    return None;
}


"""`UniScopeNode.insert`'s access resolution, as a nested ternary."""
def _resolve_ternary(spec: AccessNode | None | Access) -> int {
    resolved: Access = spec
        if isinstance(spec, Access)
        else spec.access_type if spec else Access.PUBLIC;
    return _rank(resolved);
}


def resolve_ternary(pick: int) -> int {
    return _resolve_ternary(_mk_spec(pick));
}


"""The same resolution written flat, which lowers today (the workaround)."""
def _resolve_flat(spec: AccessNode | None | Access) -> int {
    resolved: Access = Access.PUBLIC;
    if isinstance(spec, Access) {
        resolved = spec;
    } elif isinstance(spec, AccessNode) {
        resolved = spec.access_type;
    }
    return _rank(resolved);
}


def resolve_flat(pick: int) -> int {
    return _resolve_flat(_mk_spec(pick));
}


"""The `Archetype.body` union: a statement list, or an impl holding one."""
def _mk_src(pick: int) -> list[Item] | ImplDef {
    if pick == 1 {
        return [Item(n=3), Item(n=4)];
    }
    if pick == 2 {
        return ImplDef(body=[Item(n=5), Item(n=6), Item(n=7)]);
    }
    if pick == 3 {
        return ImplDef(body=Item(n=9));
    }
    return ImplDef(body=Item(n=1));
}


"""`Archetype._get_impl_resolved_body`: a nested ternary yielding a container.

The narrow that makes `src.body` legal in the middle arm is the outer
`else`'s removal of `list`, and the element type of the answer has to reach
the `isinstance` filter the callers run over it.
"""
def _resolved_body(src: list[Item] | ImplDef) -> list[Item] {
    return `list(src)
        if isinstance(src, list)
        else `list(src.body)
            if (isinstance(src, ImplDef) and isinstance(src.body, list))
            else [];
}


def resolved_body_sum(pick: int) -> int {
    total = 0;
    for i in _resolved_body(_mk_src(pick)) {
        total += i.n;
    }
    return total;
}


"""The flat resolve-then-collect the workaround uses for the same answer."""
def _resolved_body_flat(src: list[Item] | ImplDef) -> list[Item] {
    inner = src.body if isinstance(src, ImplDef) else src;
    out: list[Item] = [];
    if isinstance(inner, list) {
        out.extend(inner);
    }
    return out;
}


def resolved_body_flat_sum(pick: int) -> int {
    total = 0;
    for i in _resolved_body_flat(_mk_src(pick)) {
        total += i.n;
    }
    return total;
}
