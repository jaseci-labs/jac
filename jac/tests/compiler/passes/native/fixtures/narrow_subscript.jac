"""N3: narrowing a subscript expression in place.

`LambdaExpr.tail_return_expr` wants

    if isinstance(stmts[0], ExprStmt) { return stmts[0].expr; }

which asks the narrow to key on the *expression* `stmts[0]` rather than on a
symbol. The workaround binds `only = stmts[0]` first, turning the question
into the ordinary local-narrow the backend already answers, so this fixture
keeps both spellings and reads the narrowed field back either way.

The `and`-chained variant matters separately: `isinstance(stmts[0], RetStmt)
and stmts[0].is_implicit` needs the narrow to reach the *right* operand of
the same condition, not just the guarded block.
"""

obj Stmt {
    has n: int = 0;
}


obj ExprStmt(Stmt) {
    has v: int = 0;
}


obj RetStmt(Stmt) {
    has v: int = 0,
        is_implicit: bool = False;
}


obj Semi(Stmt) {}


"""One statement of each shape, plus a trailing `Semi` the filter drops."""
def mk_stmts(pick: int) -> list[Stmt] {
    if pick == 1 {
        return [ExprStmt(v=17), Semi()];
    }
    if pick == 2 {
        return [RetStmt(v=23, is_implicit=True), Semi()];
    }
    if pick == 3 {
        return [RetStmt(v=29, is_implicit=False)];
    }
    if pick == 4 {
        return [ExprStmt(v=1), ExprStmt(v=2)];
    }
    return [];
}


"""`tail_return_expr` as it wants to be written: narrow `stmts[0]` in place."""
def tail_value_inplace(pick: int) -> int {
    body = mk_stmts(pick);
    stmts = [
        s
        for s in body
        if not isinstance(s, Semi)
    ];
    if len(stmts) != 1 {
        return -1;
    }
    if isinstance(stmts[0], ExprStmt) {
        return stmts[0].v;
    }
    if isinstance(stmts[0], RetStmt) and stmts[0].is_implicit {
        return stmts[0].v;
    }
    return -2;
}


"""The same answer with the element bound to a local first (the workaround)."""
def tail_value_bound(pick: int) -> int {
    body = mk_stmts(pick);
    stmts = [
        s
        for s in body
        if not isinstance(s, Semi)
    ];
    if len(stmts) != 1 {
        return -1;
    }
    only = stmts[0];
    if isinstance(only, ExprStmt) {
        return only.v;
    }
    if isinstance(only, RetStmt) and only.is_implicit {
        return only.v;
    }
    return -2;
}


"""A subscript narrow with a literal index straight off a declared list."""
def first_elem_narrow(pick: int) -> int {
    stmts = mk_stmts(pick);
    if not stmts {
        return -1;
    }
    if isinstance(stmts[0], ExprStmt) {
        return stmts[0].v;
    }
    return stmts[0].n;
}


"""The same narrow keyed on a computed index rather than a constant."""
def last_elem_narrow(pick: int) -> int {
    stmts = mk_stmts(pick);
    if not stmts {
        return -1;
    }
    idx = len(stmts) - 1;
    if isinstance(stmts[idx], RetStmt) {
        return stmts[idx].v;
    }
    return stmts[idx].n;
}
