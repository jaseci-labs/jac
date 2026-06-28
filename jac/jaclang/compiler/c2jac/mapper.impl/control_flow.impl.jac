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
    # Prove the one semantic hazard (a loop-level `continue` that skips the
    # post-body condition test) absent, else stay Tier-B — the same gate
    # for-fallback (C_FOR) and switch (SWITCH_CLEAN) use. DoWhile is NOT on the
    # boundary Tier-A allowlist, so a continue-free do-while would otherwise keep
    # its default Tier-B tag (idiom NONE, no reason) and be undercounted as
    # unfaithful; stamp it Tier-A explicitly so the faithful verdict is queryable
    # (TagTable.by_idiom) and the reason records *why* the desugar is exact.
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
    # C `switch` → nested if/elif/else. pycparser nests each Case/Default as a
    # block_item carrying its own statement list; empty-statement cases
    # (`case 1: case 2: ...`) fold their labels onto the next case that has a
    # body, modelling `1 || 2`. The clean, common shape (every body-bearing
    # case ends in break/return/continue and the selector is pure) lowers
    # *exactly* and is promoted to Tier-A by `_switch_is_safe`; only the lossy
    # shapes — case fall-through between body-bearing sections (if/elif has no
    # fall-through) or a side-effecting selector re-evaluated per branch — stay
    # Tier-B. A direct `break` always binds to the switch, so dropping it as the
    # terminator is never itself a hazard.
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
            # Any empty `case` labels accumulated just before this `default`
            # fall INTO it (an empty case has no break), so they belong to the
            # default/else catch-all, not to the next body-bearing case. Drop
            # them from `pending` — leaving them would leak their selector
            # values onto a later case's `==` test (a wrong match set).
            pending = [];
            default_stmts = it.stmts or [];
        }
    }
    # The if/elif lowering is *exact* for the clean, common shape (every
    # non-final case ends in break, pure selector). Only the lossy shapes —
    # fall-through between non-empty cases, or a side-effecting selector that
    # would run more than once — are flagged Tier-B (§5.3). A direct `break`
    # always binds to the switch (never an enclosing loop), so dropping it as
    # the terminator is never itself a hazard.
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
    # loop's converted body, not here). A braced case body `case N: { ... }`
    # arrives as a single Compound; unwrap it so its terminating break is
    # dropped exactly like an unbraced one (Python has no block scope, so
    # flattening the braces changes nothing else). Empty bodies get a Pass.
    items: list = stmts or [];
    if len(items) == 1 and isinstance(items[0], c_ast.Compound) {
        items = items[0].block_items or [];
    }
    out: list[object] = [];
    for s in items {
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
    # A null-pointer constant returned from a pointer-typed function is C's
    # NULL — lower it to Jac `None` rather than the integer literal 0, which
    # would otherwise leak through (the return annotation is str/object/etc.,
    # so `return 0` is a type-mismatched value). Mirrors _zero_default's NULL
    # handling for uninitialized pointers; plain expression lowering has no
    # pointer context, so the function's return type supplies it here.
    if nd.expr is not None
    and self._ret_is_ptr
    and is_null_ptr_constant(nd.expr) {
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
    # A bare `;` is a no-op. Lower it to a Jac `pass` rather than the
    # dispatch-miss surrogate (which would emit a __c2jac_unsupported__ marker
    # and flag a do-nothing statement Tier-B). Faithful — `pass` runs nothing,
    # exactly like the empty statement. (In a direct-IR for-body the uni builder
    # drops it outright; this covers a top-level `;` on the py-ast path.)
    p = ast3.Pass();
    return self._stamp(p, nd, text="pass");
}

impl CMapper.c_For(nd: object) -> object {
    # Single-source loop-body lowering: a C-for is desugared to ordinary `ast`
    # statements (`init; while cond { body; step }`) using the SAME handlers
    # every other statement goes through — no parallel direct-IR mirror. The one
    # form with no `ast` analog, Jac's native `IterForStmt` (`for i = 0 to i < n
    # by i += 1`), can't be built from `ast`, so a *promotable* loop drops an
    # in-body direct-IR sentinel and the driver rewrites the spliced WhileStmt
    # into an IterForStmt (see driver._promote_for). Everything else — clause
    # lowering, idiom rewrites (free/malloc/realloc), casts, comma, nested
    # do-while/switch — is the mapper's existing behavior, so a for-body now
    # lowers identically to the same C at function top-level.
    (line, col) = self._loc(nd);
    init_node = getattr(nd, "init");
    cond_node = nd.cond;
    step_node = getattr(nd, "next");
    body_node = nd.stmt;

    # §3 honest-report: snapshot the Tier-B set so ANY construct the mapper has
    # to surrogate/flag while lowering this loop's clauses or body forces the
    # loop's own verdict to Tier-B. This one generic gate replaces the
    # per-construct loss bookkeeping the old direct-IR for-builder hand-rolled.
    before_ids: set = {id(nt) for nt in self.tags.tier_b_entries()};

    promotable = self._for_promotable(nd);

    # --- init: zero or more pre-loop statements (runs once) ---
    init_stmts = self._for_init_stmts(init_node);

    # --- list-bound discipline around the loop body (mirror c_While §9.5): drop
    # names the body/step may rebind to a non-list before walking, so a realloc
    # in the body is judged against every back-edge, not just the first. ---
    base: set = set(self._list_bound);
    killed: set = set();
    if body_node is not None {
        collect_lb_kills(body_node, killed);
    }
    if step_node is not None {
        collect_lb_kills(step_node, killed);
    }
    self._list_bound = base - killed;

    # --- condition ---
    cond_lossy = False;
    if cond_node is None {
        cond_ast = self._stamp_manual(
            ast3.Constant(value=True), line, col, text="True"
        );
    } else {
        cond_ast = self.conv_expr(cond_node);
        if self._is_surrogate_expr(cond_ast) {
            # The whole condition is unmappable: fall back to faithful `while
            # True` semantics plus an explicit loss flag (like for(;;)). The
            # surrogate would otherwise emit an orphan __c2jac_unsupported_expr__
            # marker with no anchor in the output, so neutralize its Tier-B tag —
            # the loop carries the condition-loss reason itself.
            self._mark_tier_a(cond_node, Idiom.NONE, "");
            cond_lossy = True;
            cond_ast = self._stamp_manual(
                ast3.Constant(value=True), line, col, text="True"
            );
        }
    }

    # --- body + step (the step runs after the body, where C runs it) ---
    body_stmts = self._stmts_from(body_node) if body_node is not None else [];
    step_stmts = self._for_step_stmts(step_node);

    # The loop may run zero times: keep only names list-bound on both the skip
    # path (base) and the body-exit path.
    self._list_bound = lb_merge([base, self._list_bound]);

    # --- faithfulness verdict (BEFORE stamping the loop's own tag, so the loop
    # verdict is not mistaken for one of its own body losses) ---
    body_losses = [
        nt.reason
        for nt in self.tags.tier_b_entries()
        if id(nt) not in before_ids
    ];
    # A loop-level `continue` diverges from C only in the while-desugar: C jumps
    # to the step then retests, but `body; step` runs `continue` BEFORE the
    # appended step. With no step there is nothing to skip. An IterForStmt runs
    # its count_by after `continue` exactly like C, so a promotable loop is never
    # at risk (§5.3).
    continue_unfaithful = (
        (not promotable) and step_node is not None and has_loop_continue(body_node)
    );
    faithful = (not body_losses) and (not cond_lossy) and (not continue_unfaithful);

    # --- assemble the desugared while (the splice rewrites a promotable one into
    # an IterForStmt) ---
    while_body: list[object] = [*body_stmts, *step_stmts];
    if promotable {
        # An in-body sentinel whose parent IS this while, so the splice can find
        # the loop to promote; it carries the For c_node's slot id.
        while_body = [self._directir_placeholder(nd), *while_body];
    }
    if not while_body {
        while_body = [self._stamp_manual(ast3.Pass(), line, col)];
    }
    while_ast = ast3.While(test=cond_ast, body=while_body, orelse=[]);
    self._stamp_manual(while_ast, line, col, text="for");

    # --- stamp the loop verdict ---
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
            # The shape still promotes to IterForStmt (the driver rewrites it);
            # the only loss is in the body, so the verdict names that — not the
            # while-desugar (which this loop is not).
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
    # A C-for is promotable to Jac's native IterForStmt only in the canonical
    # ascending shape: a single init clause that yields one valued assignment, a
    # `<` / `<=` / `!=` comparison condition, and an increment/decrement or
    # augmented-assignment step (IterForStmt's `by` clause must be an augmented
    # assignment). Every other shape — descending, multi-clause, compound or
    # call condition, plain `i = i + 1` step, for(;;) — stays a while-desugar.
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
    # The C-for initializer as zero or more pre-loop statements. A multi-clause
    # init — `for (int i = 0, j = 0; ...)` (DeclList) or `for (i = 0, seed();
    # ...)` (ExprList comma) — emits one statement per clause; each clause goes
    # through the ordinary statement handlers (c_Decl / c_Assignment / call /
    # i++), so it lowers exactly as the same statement would anywhere else.
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
    out: list[object] = [];
    for cl in clauses {
        n = self.conv_stmt(cl);
        if isinstance(n, list) {
            out += n;
        } else {
            out.append(n);
        }
    }
    return out;
}

impl CMapper._for_step_stmts(step_node: object) -> list[object] {
    # The C-for step as zero or more statements appended after the body, where C
    # runs it. A comma step `for (...; ...; i++, j++)` (ExprList) appends one
    # statement per operand; each lowers through conv_stmt (i++ → `i += 1`, a
    # bare call → an expression statement), matching where C evaluates them.
    if step_node is None {
        return [];
    }
    clauses: list = [];
    if isinstance(step_node, c_ast.ExprList) {
        clauses = step_node.exprs;
    } else {
        clauses = [step_node];
    }
    out: list[object] = [];
    for cl in clauses {
        n = self.conv_stmt(cl);
        if isinstance(n, list) {
            out += n;
        } else {
            out.append(n);
        }
    }
    return out;
}

impl CMapper._is_surrogate_expr(n: object) -> bool {
    # True when `n` is a top-level dispatch-miss expression surrogate
    # (`__c2jac_unsupported_expr__(line)`), i.e. the whole expression had no Jac
    # analog. Used to detect an entirely-unmappable for-condition.
    return (
        isinstance(n, ast3.Call)
        and isinstance(n.func, ast3.Name)
        and n.func.id == UNSUPPORTED_EXPR
    );
}
