"""Control-flow construct handlers (if / while / do-while / switch /
ternary / return / break / continue / for).

These own the §9.5 list-bound MUST-dataflow joins across branches and loop
back-edges (via c_dataflow.lb_merge / collect_lb_kills); `for` defers to the
direct-IR placeholder protocol spliced by the driver."""

impl CMapper.c_If(nd: object) -> object {
    test = self.conv_expr(nd.cond);
    # Snapshot AFTER the condition — a cond like `if ((arr = malloc(...)))`
    # mutates list-bound state, and that effect is on every path. Each branch
    # then walks from its own copy so neither leaks into the other (§9.5).
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
        # No else → the fall-through path keeps `base` unchanged.
        s_false = base;
    }
    # Join: list-bound after the if only if list-bound on BOTH paths.
    self._list_bound = lb_merge([s_true, s_false]);
    ifs = ast3.If(test=test, body=true_stmts, orelse=false_stmts);
    return self._stamp(ifs, nd, text="if");
}

impl CMapper.c_While(nd: object) -> object {
    test = self.conv_expr(nd.cond);
    base: set = set(self._list_bound);
    # Drop names the body may rebind to a non-list before walking it, so a
    # realloc in the body is judged against what holds on every iteration's
    # back-edge, not just the first (§9.5). Re-gens in the body re-add them.
    killed: set = set();
    collect_lb_kills(nd.stmt, killed);
    self._list_bound = base - killed;
    body = self._stmts_from(nd.stmt);
    s_end: set = self._list_bound;
    # The loop may run zero times: keep only names list-bound on both the
    # skip path (base) and the body-exit path.
    self._list_bound = lb_merge([base, s_end]);
    w = ast3.While(test=test, body=body, orelse=[]);
    return self._stamp(w, nd, text="while");
}

impl CMapper.c_DoWhile(nd: object) -> object {
    # `do { body } while (cond);` has no Python/Jac analog. Desugar to the
    # faithful `while True { body; if not cond { break } }` — body runs once
    # before the test, exactly like do-while. The one semantic gap is `continue`:
    # in C it jumps to the post-body condition test, but here it re-enters the
    # loop top and skips the `if not cond` guard, so a loop-level continue would
    # spin without ever re-checking cond. Flag that case Tier-B; the common
    # continue-free do-while stays faithful (Tier-A).
    (line, col) = self._loc(nd);
    # Body runs at least once, but still loops: drop names it may rebind to a
    # non-list before walking, so a realloc in the body holds on every
    # back-edge, not just the first iteration (§9.5).
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
    if self._has_loop_continue(nd.stmt) {
        self._mark_tier_b(
            nd,
            "do-while desugared to `while True`/break; a loop-level `continue` "
            "skips the post-body condition test (C runs it) — verify",
        );
    }
    return self._stamp(w, nd, text="do");
}

impl CMapper._has_loop_continue(nd: object) -> bool {
    # True if a `continue` belonging to THIS loop appears in nd. Nested loops
    # and switch bodies own their own continue/break, so descent stops at them.
    if nd is None {
        return False;
    }
    if (
        isinstance(nd, c_ast.For)
        or isinstance(nd, c_ast.While)
        or isinstance(nd, c_ast.DoWhile)
        or isinstance(nd, c_ast.Switch)
    ) {
        return False;
    }
    if isinstance(nd, c_ast.Continue) {
        return True;
    }
    for (_, child) in nd.children() {
        if self._has_loop_continue(child) {
            return True;
        }
    }
    return False;
}

impl CMapper.c_Switch(nd: object) -> object {
    # C `switch` → nested if/elif/else. pycparser nests each Case/Default as a
    # block_item carrying its own statement list; empty-statement cases
    # (`case 1: case 2: ...`) fold their labels onto the next case that has a
    # body, modelling `1 || 2`. This is always Tier-B: case fall-through between
    # non-empty cases is NOT modelled (if/elif has no fall-through), `break` is
    # dropped as the switch terminator (so a `break` meant for an enclosing loop
    # would be mis-handled), and the selector is re-evaluated per branch rather
    # than once. The clean, common shape (every case ends in `break`) is exact.
    (line, col) = self._loc(nd);
    groups: list[tuple] = [];  # (list[c_value_node], list[c_stmt_node])
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
            default_stmts = it.stmts or [];
        }
    }
    self._mark_tier_b(
        nd,
        "switch lowered to an if/elif chain: case fall-through is not modelled, "
        "`break` is dropped as the switch terminator, and the selector is "
        "re-evaluated per branch — verify (faithful when every case ends in break)",
    );
    # Each case body is a distinct path; walk it from a copy of the pre-switch
    # state and merge at the end so list-bound status leaving the switch is
    # what holds on every path, not whatever the last-walked case left (§9.5).
    base: set = set(self._list_bound);
    branch_states: list = [];
    if default_stmts is not None {
        self._list_bound = set(base);
        orelse: list[object] = self._switch_branch_body(default_stmts);
        branch_states.append(self._list_bound);
    } else {
        orelse = [];
        # No default → the no-match path falls through with `base` unchanged.
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
    # `selector == v1 [or selector == v2 ...]`. The selector is re-converted
    # per comparison so no ast node object is shared across the tree.
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
    # Convert one case's direct statements, dropping the switch-terminating
    # `break` (direct break only — a break inside a nested loop lives in that
    # loop's converted body, not here). Empty bodies get a Pass.
    out: list[object] = [];
    for s in (stmts or []) {
        if isinstance(s, c_ast.Break) {
            continue;
        }
        n = self.conv_stmt(s);
        if isinstance(n, list) {
            out += n;
        } else {
            out.append(n);
        }
    }
    if not out {
        out = [self._stamp_manual(ast3.Pass(), 1, 0)];
    }
    return out;
}

impl CMapper.c_TernaryOp(nd: object) -> object {
    # `cond ? a : b` → Python conditional expression `a if cond else b`
    # (PyastBuildPass.proc_if_exp → uni.IfElseExpr). Faithful (Tier-A).
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

impl CMapper.c_For(nd: object) -> object {
    return self._directir_placeholder(nd);
}
