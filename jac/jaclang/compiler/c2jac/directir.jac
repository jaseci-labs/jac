"""Direct-IR slot protocol — the single owner of the placeholder round-trip.

A few C forms (`For`, `Enum`, `Enumerator`, `EnumeratorList`) have no faithful
CPython-`ast` shape, so the mapper cannot lower them on the Python-AST path. At
each such site it emits a *placeholder* expression, records the originating C node
in `CMapper.slot_map` under a slot id, and the driver later splices the real `uni`
nodes (built by `CUniBuilder`) in place of the placeholder.

Why a round-trip through PyastBuildPass is *safe*, not just convenient:
  - The placeholder only has to survive ONE pass — PyastBuildPass, the py-ast →
    uni bridge — so the driver can find WHERE in the tree to splice.
  - PyastBuildPass is a pure *structural* build: it maps `Call(Name(...), ...)` to
    `FuncCall(Name(...), ...)` verbatim and never renames identifiers.
  - The splice runs at driver step 5, BEFORE NormalizePass/JacFormatPass at step 6
    — the only passes that rewrite the tree. So the placeholder is observed by
    exactly one pass that is contractually guaranteed not to touch it.
That is the answer to "a stringly round-trip through a pass that may rewrite
things": in THIS pipeline no rewriting pass ever sees the placeholder.

What would actually be dangerous is a *silent* failure — a leaked
`__c2jac_directir__(N)` call reaching emitted Jac. This module is the one place
that knows what a placeholder looks like (`is_slot_placeholder` / `slot_id_of`),
and the driver turns every way the protocol could break into a hard error:
malformed placeholder → raise, unregistered slot → raise, any placeholder
surviving the splice → raise. The `directir_no_leak` compat-matrix test locks the
end-to-end invariant (a `for`/`enum` input emits zero sentinels), so a future
change that broke the round-trip would fail CI loudly instead of corrupting
output. The protocol survives on an enforced, tested invariant — not convention.

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
