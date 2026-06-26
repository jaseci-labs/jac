"""Core dispatch + emission machinery for the CMapper.

The construct-family handlers (control_flow / declarations / expressions
impl annexes) call into these to dispatch, allocate direct-IR slots, stamp
CPython-AST coordinates, emit §8.2 fallback surrogates, and record the Tier
verdict. Pure node-building lives here; pure *analysis* lives in the
c_types / c_idioms / c_dataflow sibling modules."""

impl CMapper._loc(c_node: object) -> tuple[int, int] {
    # Resolve coords via the shared helper, threading the running last-seen
    # line as the fallback so coord-less synthesized nodes stay near source.
    (line, col) = coord_of(c_node, self._lineno);
    self._lineno = line;
    return (line, col);
}

impl CMapper._stamp(py_node: object, c_node: object, *, text: str = "") -> object {
    (line, col) = self._loc(c_node);
    py_node.lineno = line;
    py_node.col_offset = col;
    py_node.end_lineno = line;
    py_node.end_col_offset = col + max(len(text), 1);
    return py_node;
}

impl CMapper._stamp_manual(
    py_node: object, line: int, col: int, *, text: str = ""
) -> object {
    py_node.lineno = line;
    py_node.col_offset = col;
    py_node.end_lineno = line;
    py_node.end_col_offset = col + max(len(text), 1);
    return py_node;
}

impl CMapper._alloc_slot(c_node: object) -> int {
    sid = self._next_slot;
    self._next_slot += 1;
    self.slot_map[sid] = c_node;
    return sid;
}

impl CMapper._surrogate_stmt(c_node: object) -> object {
    (line, col) = self._loc(c_node);
    reason = f"{type(c_node).__name__} @ L{line}";
    self.tags.tag(
        c_node,
        NodeTag(
            tier=Tier.TIER_B,
            mechanism=Mechanism.PY_AST,
            idiom=Idiom.TIER_B,
            reason=reason,
            c_line=line,
            snippet=reason
        )
    );
    name_n = self._stamp_manual(
        ast3.Name(id=_UNSUPPORTED_STMT, ctx=ast3.Load()),
        line,
        col,
        text=_UNSUPPORTED_STMT
    );
    # Anchor arg is the C-source line as an INT, not the reason string. A
    # string Constant here would be re-sliced from orig_src (the C source) by
    # PyastBuildPass._get_source_segment — the manual coords point into the C
    # text — emitting invalid Jac (e.g. `__c2jac_unsupported__(U { int i; )`).
    # An int uses str(value) verbatim, so the call stays valid Jac, and the
    # line doubles as the key the post-format comment injector matches on (§7).
    line_c = self._stamp_manual(ast3.Constant(value=line), line, col, text=str(line));
    call_n = self._stamp_manual(
        ast3.Call(func=name_n, args=[line_c], keywords=[]), line, col
    );
    return self._stamp_manual(ast3.Expr(value=call_n), line, col);
}

impl CMapper._surrogate_expr(c_node: object) -> object {
    (line, col) = self._loc(c_node);
    reason = f"{type(c_node).__name__} @ L{line}";
    self.tags.tag(
        c_node,
        NodeTag(
            tier=Tier.TIER_B,
            mechanism=Mechanism.PY_AST,
            idiom=Idiom.TIER_B,
            reason=reason,
            c_line=line,
            snippet=reason
        )
    );
    name_n = self._stamp_manual(
        ast3.Name(id=_UNSUPPORTED_EXPR, ctx=ast3.Load()),
        line,
        col,
        text=_UNSUPPORTED_EXPR
    );
    # Int line anchor, not the reason string — see _surrogate_stmt for why a
    # string Constant would re-slice the C source into invalid Jac.
    line_c = self._stamp_manual(ast3.Constant(value=line), line, col, text=str(line));
    return self._stamp_manual(
        ast3.Call(func=name_n, args=[line_c], keywords=[]), line, col
    );
}

impl CMapper._mark_tier_b(c_node: object, reason: str) {
    # Retag a node Tier-B for a lossy-but-best-effort emission. Unlike the
    # surrogate helpers this does NOT replace the emitted Jac — the handler
    # still emits its best-effort form — it only records the loss so the
    # node is flagged in the Tier-B comments (§3 honest-report invariant). Used by
    # representation-changing casts and side-effect-dropping comma/designated
    # initializers, which would otherwise silently stay at the default
    # Tier-A from _populate_default_tags.
    (line, _) = self._loc(c_node);
    self.tags.tag(
        c_node,
        NodeTag(
            tier=Tier.TIER_B,
            mechanism=Mechanism.PY_AST,
            idiom=Idiom.TIER_B,
            reason=reason,
            c_line=line,
            snippet=reason
        )
    );
}

impl CMapper._mark_tier_a(c_node: object, idiom: Idiom, reason: str = "") {
    # Record a recognized Tier-A pointer idiom (§7). The handler still emits
    # the faithful Jac form; this only stamps the verdict so the idiom is
    # queryable (TagTable.by_idiom) for metrics/tests. Tier-A is never
    # flagged in the Tier-B comments (which surface Tier-B only).
    (line, _) = self._loc(c_node);
    self.tags.tag(
        c_node,
        NodeTag(
            tier=Tier.TIER_A,
            mechanism=Mechanism.PY_AST,
            idiom=idiom,
            reason=reason,
            c_line=line,
            snippet=reason
        )
    );
}

impl CMapper._mark_tier_b_idiom(c_node: object, idiom: Idiom, reason: str) {
    # Tier-B emission carrying a *specific* idiom verdict (e.g. a realloc we
    # elided but could not prove list-bound). Like _mark_tier_b but preserves
    # the idiom so the report names what was attempted, not a bare "tier_b".
    (line, _) = self._loc(c_node);
    self.tags.tag(
        c_node,
        NodeTag(
            tier=Tier.TIER_B,
            mechanism=Mechanism.PY_AST,
            idiom=idiom,
            reason=reason,
            c_line=line,
            snippet=reason
        )
    );
}

impl CMapper._directir_placeholder(c_node: object) -> object {
    (line, col) = self._loc(c_node);
    sid = self._alloc_slot(c_node);
    name_n = self._stamp_manual(
        ast3.Name(id=SLOT_SENTINEL, ctx=ast3.Load()), line, col, text=SLOT_SENTINEL
    );
    sid_c = self._stamp_manual(ast3.Constant(value=sid), line, col, text=str(sid));
    call_n = self._stamp_manual(
        ast3.Call(func=name_n, args=[sid_c], keywords=[]), line, col
    );
    return self._stamp_manual(ast3.Expr(value=call_n), line, col);
}

impl CMapper.conv(c_node: object, *, stmt: bool = True) -> object {
    # Statement-context increment/decrement (`i++;`) → AugAssign (`i += 1`).
    # Done before dispatch because c_UnaryOp can't know its context and an
    # AugAssign is a statement, not an expression.
    if stmt
    and isinstance(c_node, c_ast.UnaryOp)
    and c_node.op in ("p++", "++", "p--", "--") {
        inc = self._inc_dec_stmt(c_node);
        if inc is not None {
            return inc;
        }
    }
    meth = getattr(self, "c_" + type(c_node).__name__, None);
    if meth is None {
        if stmt {
            return self._surrogate_stmt(c_node);
        } else {
            return self._surrogate_expr(c_node);
        }
    }
    result = meth(c_node);
    # A handler may return a bare expression (e.g. c_FuncCall → ast.Call,
    # or an expr surrogate for `i++` in expr position). In statement
    # context PyastBuildPass needs a statement node, so wrap it in an Expr;
    # otherwise the expression is dropped and the function body length
    # mismatches ("Length mismatch in function body").
    if stmt and isinstance(result, ast3.expr) {
        line = getattr(result, "lineno", self._lineno);
        col = getattr(result, "col_offset", 0);
        return self._stamp_manual(ast3.Expr(value=result), line, col);
    }
    return result;
}

impl CMapper._inc_dec_stmt(nd: object) -> object | None {
    # `i++` / `++i` / `i--` / `--i` as a statement → `i += 1` / `i -= 1`.
    target = self.conv_expr(nd.expr);
    if not (
        isinstance(target, ast3.Name)
        or isinstance(target, ast3.Attribute)
        or isinstance(target, ast3.Subscript)
    ) {
        return None;
    }
    self._to_store(target);
    op = ast3.Add() if nd.op in ("p++", "++") else ast3.Sub();
    (line, col) = self._loc(nd);
    one = self._stamp_manual(ast3.Constant(value=1), line, col, text="1");
    aug = ast3.AugAssign(target=target, op=op, value=one);
    return self._stamp_manual(aug, line, col, text=nd.op);
}

impl CMapper.conv_stmt(c_node: object) -> object {
    return self.conv(c_node, stmt=True);
}

impl CMapper.conv_expr(c_node: object) -> object {
    return self.conv(c_node, stmt=False);
}

impl CMapper._to_store(py_node: object) -> object {
    if isinstance(py_node, ast3.Name) {
        py_node.ctx = ast3.Store();
    } elif isinstance(py_node, ast3.Attribute) {
        py_node.ctx = ast3.Store();
    } elif isinstance(py_node, ast3.Subscript) {
        py_node.ctx = ast3.Store();
    }
    return py_node;
}
