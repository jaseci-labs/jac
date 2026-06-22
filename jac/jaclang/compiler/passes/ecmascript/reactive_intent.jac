"""Framework-neutral reactive-intent vocabulary.

These records hold structural facts about reactive constructs found in Jac
client code. They carry no framework-specific lowering (no `setCount`, `useState`,
`<JacAwaiting>`) — that is the responsibility of the active FrameworkBackend.
"""

import jaclang.compiler.passes.ecmascript.estree as es;

"""A reactive state field declaration."""
obj StateField {
    has name: str,
        init_expr: es.Expression;
}

"""A ref field declaration (non-reactive mutable reference)."""
obj RefField {
    has name: str,
        init_expr: es.Expression;
}

"""A reactive state update (assignment to a reactive variable)."""
obj StateUpdate {
    has name: str,
        value: es.Expression,
        aug_op: (str | None) = None;
}

"""An effect (event ability lowered to a lifecycle effect)."""
obj Effect {
    has body: list[es.Statement],
        deps: list[es.Expression],
        is_entry: bool = True,
        is_async: bool = False;
}

"""An async boundary wrapper (try/awaiting/except in a JSX slot).

The pass builds the clause IIFEs; the backend only assembles the JSX wrapper.
"""
obj AsyncBoundary {
    has try_expr: es.Expression,
        awaiting_expr: (es.Expression | None),
        except_exprs: list[es.Expression];
}
