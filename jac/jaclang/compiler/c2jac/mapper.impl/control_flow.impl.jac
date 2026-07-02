impl CMapper.c_If(nd: object) -> object {
    test = self.conv_expr(nd.cond);

    base: set = set(self._list_bound);
    self._list_bound = set(base);
    true_stmts = self._stmts_from(nd.iftrue);
    s_true: set = self._list_bound;
    false_stmts: list[object] = [];
    if nd.iffalse is not None {
        self._list_bound = set(base);
        false_stmts = self._stmts_from(nd.iffalse);
        s_false: set = self._list_bound;
    } else {
        s_false = base;
    }

    self._list_bound = lb_merge([s_true, s_false]);
    ifs = ast3.If(test=test, body=true_stmts, orelse=false_stmts);
    return self._stamp(ifs, nd, text="if");
}

impl CMapper.c_While(nd: object) -> object {
    test = self.conv_expr(nd.cond);
    base: set = set(self._list_bound);

    killed: set = set();
    collect_lb_kills(nd.stmt, killed);
    self._list_bound = base - killed;
    body = self._stmts_from(nd.stmt);
    s_end: set = self._list_bound;

    self._list_bound = lb_merge([base, s_end]);
    w = ast3.While(test=test, body=body, orelse=[]);
    return self._stamp(w, nd, text="while");
}

impl CMapper.c_DoWhile(nd: object) -> object {
    (line, col) = self._loc(nd);

    killed: set = set();
    collect_lb_kills(nd.stmt, killed);
    self._list_bound -= killed;
    body = self._stmts_from(nd.stmt);
    cond = self.conv_expr(nd.cond);
    not_cond = self._stamp_manual(
        ast3.UnaryOp(op=ast3.Not(), operand=cond), line, col, text="not"
    );
    brk = self._stamp_manual(ast3.Break(), line, col, text="break");
    guard = self._stamp_manual(
        ast3.If(test=not_cond, body=[brk], orelse=[]), line, col, text="if"
    );
    full_body: list[object] = [*body, guard];
    true_c = self._stamp_manual(ast3.Constant(value=True), line, col, text="True");
    w = ast3.While(test=true_c, body=full_body, orelse=[]);

    if has_loop_continue(nd.stmt) {
        self._mark_tier_b(
            nd,
            "do-while desugared to `while True`/break; a loop-level `continue` "
            "skips the post-body condition test (C runs it) — verify",
        );
    } else {
        self._mark_tier_a(
            nd,
            Idiom.DO_WHILE,
            "do-while desugared to `while True { body; if not cond break }` — "
            "faithful: body runs once before the test and no loop-level `continue` "
            "skips the post-body condition check",
        );
    }
    return self._stamp(w, nd, text="do");
}

impl CMapper.c_Switch(nd: object) -> object {
    (line, col) = self._loc(nd);
    groups: list[tuple] = [];
    pending: list[object] = [];
    default_stmts: list | None = None;
    items: list = [];
    if isinstance(nd.stmt, c_ast.Compound) and nd.stmt.block_items {
        items = nd.stmt.block_items;
    }
    for it in items {
        if isinstance(it, c_ast.Case) {
            pending.append(it.expr);
            if it.stmts {
                groups.append((pending, it.stmts));
                pending = [];
            }
        } elif isinstance(it, c_ast.Default) {
            pending = [];
            default_stmts = it.stmts or [];
        }
    }

    if switch_is_safe(items, nd.cond) {
        self._mark_tier_a(
            nd,
            Idiom.SWITCH_CLEAN,
            "clean switch (no fall-through, pure selector) → exact if/elif chain",
        );
    } else {
        self._mark_tier_b(
            nd,
            "switch lowered to an if/elif chain: case fall-through is not modelled "
            "and/or the selector has side effects but is re-evaluated per branch "
            "— verify (faithful when every case ends in break and the selector is pure)",
        );
    }

    base: set = set(self._list_bound);
    branch_states: list = [];
    if default_stmts is not None {
        self._list_bound = set(base);
        orelse: list[object] = self._switch_branch_body(default_stmts);
        branch_states.append(self._list_bound);
    } else {
        orelse = [];
        branch_states.append(base);
    }
    for grp in reversed(groups) {
        (vals, stmts) = grp;
        self._list_bound = set(base);
        body = self._switch_branch_body(stmts);
        branch_states.append(self._list_bound);
        test = self._switch_test(nd.cond, vals, line, col);
        ifs = self._stamp_manual(
            ast3.If(test=test, body=body, orelse=orelse), line, col, text="case"
        );
        orelse = [ifs];
    }
    self._list_bound = lb_merge(branch_states);
    if orelse {
        if len(orelse) == 1 and isinstance(orelse[0], ast3.If) {
            return orelse[0];
        }
        return orelse;
    }
    return self._stamp_manual(ast3.Pass(), line, col);
}

impl CMapper._switch_test(
    cond_cnode: object, vals: list, line: int, col: int
) -> object {
    cmps: list[object] = [];
    for v in vals {
        sel = self.conv_expr(cond_cnode);
        val = self.conv_expr(v);
        cmp_n = self._stamp_manual(
            ast3.Compare(left=sel, ops=[ast3.Eq()], comparators=[val]),
            line,
            col,
            text="=="
        );
        cmps.append(cmp_n);
    }
    if len(cmps) == 1 {
        return cmps[0];
    }
    return self._stamp_manual(
        ast3.BoolOp(op=ast3.Or(), values=cmps), line, col, text="or"
    );
}

impl CMapper._switch_branch_body(stmts: list | None) -> list[object] {
    items: list = stmts or [];
    if len(items) == 1 and isinstance(items[0], c_ast.Compound) {
        items = items[0].block_items or [];
    }
    kept = [
        s
        for s in items
        if not isinstance(s, c_ast.Break)
    ];
    out: list[object] = self._conv_stmts(kept);
    if not out {
        out = [self._stamp_manual(ast3.Pass(), 1, 0)];
    }
    return out;
}

impl CMapper.c_TernaryOp(nd: object) -> object {
    test = self.conv_expr(nd.cond);
    body = self.conv_expr(nd.iftrue);
    orelse = self.conv_expr(nd.iffalse);
    ie = ast3.IfExp(test=test, body=body, orelse=orelse);
    return self._stamp(ie, nd, text="?:");
}

impl CMapper._stmts_from(nd: object) -> list[object] {
    if isinstance(nd, c_ast.Compound) {
        return self.c_Compound(nd);
    }
    n = self.conv_stmt(nd);
    if isinstance(n, list) {
        return n or [self._stamp_manual(ast3.Pass(), 1, 0)];
    }
    return [n];
}

impl CMapper.c_Return(nd: object) -> object {
    if nd.expr is not None and self._ret_is_ptr and is_null_ptr_constant(nd.expr) {
        none_v = self._stamp(ast3.Constant(value=None), nd.expr, text="None");
        r = ast3.Return(value=none_v);
        return self._stamp(r, nd, text="return");
    }
    val = self.conv_expr(nd.expr) if nd.expr is not None else None;
    r = ast3.Return(value=val);
    return self._stamp(r, nd, text="return");
}

impl CMapper.c_Break(nd: object) -> object {
    b = ast3.Break();
    return self._stamp(b, nd, text="break");
}

impl CMapper.c_Continue(nd: object) -> object {
    c = ast3.Continue();
    return self._stamp(c, nd, text="continue");
}

impl CMapper.c_EmptyStatement(nd: object) -> object {
    p = ast3.Pass();
    return self._stamp(p, nd, text="pass");
}

impl CMapper.c_For(nd: object) -> object {
    (line, col) = self._loc(nd);
    init_node = getattr(nd, "init");
    cond_node = nd.cond;
    step_node = getattr(nd, "next");
    body_node = nd.stmt;

    before_ids: set = {id(nt) for nt in self.tags.tier_b_entries()};

    promotable = self._for_promotable(nd);

    init_stmts = self._for_init_stmts(init_node);

    base: set = set(self._list_bound);
    killed: set = set();
    if body_node is not None {
        collect_lb_kills(body_node, killed);
    }
    if step_node is not None {
        collect_lb_kills(step_node, killed);
    }
    self._list_bound = base - killed;

    cond_lossy = False;
    if cond_node is None {
        cond_ast = self._stamp_manual(
            ast3.Constant(value=True), line, col, text="True"
        );
    } else {
        cond_ast = self.conv_expr(cond_node);
        if self._is_surrogate_expr(cond_ast) {
            self._mark_tier_a(cond_node, Idiom.NONE, "");
            cond_lossy = True;
            cond_ast = self._stamp_manual(
                ast3.Constant(value=True), line, col, text="True"
            );
        }
    }

    body_stmts = self._stmts_from(body_node) if body_node is not None else [];
    step_stmts = self._for_step_stmts(step_node);

    self._list_bound = lb_merge([base, self._list_bound]);

    body_losses = [
        nt.reason
        for nt in self.tags.tier_b_entries()
        if id(nt) not in before_ids
    ];

    continue_unfaithful = (
        (not promotable) and step_node is not None and has_loop_continue(body_node)
    );
    faithful = (not body_losses) and (not cond_lossy) and (not continue_unfaithful);

    while_body: list[object] = [*body_stmts, *step_stmts];
    if promotable {
        while_body = [self._directir_placeholder(nd), *while_body];
    }
    if not while_body {
        while_body = [self._stamp_manual(ast3.Pass(), line, col)];
    }
    while_ast = ast3.While(test=cond_ast, body=while_body, orelse=[]);
    self._stamp_manual(while_ast, line, col, text="for");

    if faithful {
        if promotable {
            self._mark_tier_a(
                nd,
                Idiom.C_FOR,
                "C-for promotable to IterForStmt (`for i = … to cond by step`) — "
                "faithful: single valued init, a `<`/`<=`/`!=` condition, an "
                "increment/decrement (or augmented) step, and every body construct "
                "lowered exactly",
            );
        } else {
            self._mark_tier_a(
                nd,
                Idiom.C_FOR,
                "C-for not expressible as IterForStmt (e.g. descending step, "
                "compound/comma clause, `for(;;)`); desugared to `init; while cond "
                "{ body; step }` — faithful: every clause lowered exactly and no "
                "loop-level `continue` skips a step",
            );
        }
    } else {
        body_clause = "; ".join(body_losses);
        if promotable {
            self._mark_tier_b(
                nd, "C-for body constructs not faithfully lowered: " + body_clause,
            );
        } else {
            reason = "C-for loop not expressible as IterForStmt; desugared to while";
            if continue_unfaithful {
                reason += (
                    " (C `continue` runs the step, the desugared `continue` skips "
                    "it — verify)"
                );
            }
            if cond_lossy {
                reason += (
                    " | loop condition not faithfully lowered: real "
                    "`for (...; cond; ...)` test replaced by `while True` (the loop "
                    "no longer terminates on the original condition — verify)"
                );
            }
            if body_losses {
                reason += " | body constructs not faithfully lowered: " + body_clause;
            }
            self._mark_tier_b(nd, reason);
        }
    }
    return [*init_stmts, while_ast];
}

impl CMapper._for_promotable(nd: object) -> bool {
    init_node = getattr(nd, "init");
    cond_node = nd.cond;
    step_node = getattr(nd, "next");
    ok_init = False;
    if isinstance(init_node, c_ast.DeclList) {
        if len(init_node.decls) == 1
        and getattr(init_node.decls[0], "init") is not None {
            ok_init = True;
        }
    } elif isinstance(init_node, c_ast.Decl) {
        if getattr(init_node, "init") is not None {
            ok_init = True;
        }
    } elif isinstance(init_node, c_ast.Assignment) {
        if init_node.op == "=" {
            ok_init = True;
        }
    }
    if not ok_init {
        return False;
    }
    if not (
        isinstance(cond_node, c_ast.BinaryOp) and cond_node.op in ("<", "<=", "!=")
    ) {
        return False;
    }
    if isinstance(step_node, c_ast.UnaryOp)
    and step_node.op in ("p++", "++", "p--", "--") {
        return True;
    }
    if isinstance(step_node, c_ast.Assignment) and step_node.op != "=" {
        return True;
    }
    return False;
}

impl CMapper._for_init_stmts(init_node: object) -> list[object] {
    if init_node is None {
        return [];
    }
    clauses: list = [];
    if isinstance(init_node, c_ast.DeclList) {
        clauses = init_node.decls;
    } elif isinstance(init_node, c_ast.ExprList) {
        clauses = init_node.exprs;
    } else {
        clauses = [init_node];
    }
    return self._conv_stmts(clauses);
}

impl CMapper._for_step_stmts(step_node: object) -> list[object] {
    if step_node is None {
        return [];
    }
    clauses: list = [];
    if isinstance(step_node, c_ast.ExprList) {
        clauses = step_node.exprs;
    } else {
        clauses = [step_node];
    }
    return self._conv_stmts(clauses);
}

impl CMapper._is_surrogate_expr(n: object) -> bool {
    return (
        isinstance(n, ast3.Call)
        and isinstance(n.func, ast3.Name)
        and n.func.id == UNSUPPORTED_EXPR
    );
}
