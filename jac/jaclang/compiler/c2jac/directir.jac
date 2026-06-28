"""Direct-IR slot protocol — the single owner of the placeholder round-trip.

A few C forms (`For`, `Enum`, `Enumerator`, `EnumeratorList`) have no faithful
CPython-`ast` shape, so the mapper cannot lower them on the Python-AST path. At
each such site it emits a *placeholder* expression, records the originating C node
in `CMapper.slot_map` under a slot id, and the driver later splices the real `uni`
nodes (built by `CUniBuilder`) in place of the placeholder.

The round-trip through PyastBuildPass is safe because the placeholder survives
exactly one pass — a pure structural py-ast → uni build that never renames
identifiers — and the splice (driver step 5) runs before the only tree-rewriting
passes (NormalizePass/JacFormatPass, step 6). No rewriting pass ever sees it.

The real hazard is a *silent* leak of `__c2jac_directir__(N)` into emitted Jac.
This module owns what a placeholder looks like (`is_slot_placeholder` /
`slot_id_of`), and the driver hard-errors on every break (malformed placeholder,
unregistered slot, surviving placeholder). The `directir_no_leak` compat-matrix
test locks the invariant (a `for`/`enum` input emits zero sentinels) so a broken
round-trip fails CI instead of corrupting output.

`SLOT_SENTINEL` is a deliberately ugly, namespaced identifier so it can never
collide with a real C symbol surviving preprocessing.
"""

import jaclang.jac0core.unitree as uni;

glob SLOT_SENTINEL: str = "__c2jac_directir__";

def is_slot_placeholder(nd: uni.UniNode) -> bool {
    # True iff `nd` is a spliceable direct-IR placeholder: an ExprStmt whose sole
    # content is a call to the SLOT_SENTINEL name. The mapper is the only emitter
    # of this shape (CMapper._directir_placeholder), so a match is unambiguous.
    if not isinstance(nd, uni.ExprStmt) {
        return False;
    }
    expr = nd.expr;
    if not isinstance(expr, uni.FuncCall) {
        return False;
    }
    target = expr.target;
    if not isinstance(target, uni.Name) {
        return False;
    }
    return target.value == SLOT_SENTINEL;
}

def slot_id_of(placeholder: uni.ExprStmt) -> int | None {
    # The slot id a placeholder carries as its single int argument, or None if the
    # call shape is malformed. Callers that already vetted `placeholder` via
    # is_slot_placeholder treat a None here as a hard protocol break.
    params = placeholder.expr.params;
    if params and len(params) == 1 and isinstance(params[0], uni.Int) {
        try {
            return int(params[0].value);
        } except ValueError {
        # malformed slot literal — caller raises
        }
    }
    return None;
}
