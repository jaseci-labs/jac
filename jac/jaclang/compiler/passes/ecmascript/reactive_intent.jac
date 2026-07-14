import jaclang.compiler.passes.ecmascript.estree as es;

obj StateField {
    has name: str,
        init_expr: es.Expression;
}

obj RefField {
    has name: str,
        init_expr: es.Expression;
}

obj StateUpdate {
    has name: str,
        value: es.Expression,
        aug_op: (str | None) = None;
}

obj Effect {
    has body: list[es.Statement],
        deps: list[es.Expression],
        is_entry: bool = True,
        is_async: bool = False;
}

obj AsyncBoundary {
    has try_expr: es.Expression,
        awaiting_expr: (es.Expression | None),
        except_exprs: list[es.Expression];
}
