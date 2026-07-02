impl CMapper._loc(c_node: object) -> tuple[int, int] {
    (line, col) = coord_of(c_node, self._lineno);
    self._lineno = line;
    return (line, col);
}

impl CMapper._stamp(py_node: object, c_node: object, *, text: str = "") -> object {
    (line, col) = self._loc(c_node);
    return self._stamp_manual(py_node, line, col, text=text);
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

impl CMapper._tag(c_node: object, tier: Tier, idiom: Idiom, reason: str) {
    (line, _) = self._loc(c_node);
    self.tags.tag(
        c_node,
        NodeTag(
            tier=tier,
            mechanism=Mechanism.PY_AST,
            idiom=idiom,
            reason=reason,
            c_line=line
        )
    );
}

impl CMapper._surrogate(c_node: object, name: str) -> object {
    (line, col) = self._loc(c_node);
    reason = f"{type(c_node).__name__} @ L{line}";
    self._tag(c_node, Tier.TIER_B, Idiom.TIER_B, reason);
    name_n = self._stamp_manual(
        ast3.Name(id=name, ctx=ast3.Load()), line, col, text=name
    );

    line_c = self._stamp_manual(ast3.Constant(value=line), line, col, text=str(line));
    return self._stamp_manual(
        ast3.Call(func=name_n, args=[line_c], keywords=[]), line, col
    );
}

impl CMapper._surrogate_stmt(c_node: object) -> object {
    (line, col) = self._loc(c_node);
    call_n = self._surrogate(c_node, UNSUPPORTED_STMT);
    return self._stamp_manual(ast3.Expr(value=call_n), line, col);
}

impl CMapper._surrogate_expr(c_node: object) -> object {
    return self._surrogate(c_node, UNSUPPORTED_EXPR);
}

impl CMapper._mark_tier_b(c_node: object, reason: str) {
    self._tag(c_node, Tier.TIER_B, Idiom.TIER_B, reason);
}

impl CMapper._mark_tier_a(c_node: object, idiom: Idiom, reason: str = "") {
    self._tag(c_node, Tier.TIER_A, idiom, reason);
}

impl CMapper._earn_tier_a(c_node: object) {
    tag = self.tags.get(c_node);
    if tag is not None
    and tag.tier == Tier.TIER_B
    and tag.reason == ""
    and tag.idiom == Idiom.NONE {
        self.tags.tag(
            c_node,
            NodeTag(
                tier=Tier.TIER_A,
                mechanism=tag.mechanism,
                idiom=Idiom.NONE,
                reason="",
                c_line=tag.c_line
            )
        );
    }
}

impl CMapper._mark_tier_b_idiom(c_node: object, idiom: Idiom, reason: str) {
    self._tag(c_node, Tier.TIER_B, idiom, reason);
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
    if stmt
    and isinstance(c_node, c_ast.UnaryOp)
    and c_node.op in ("p++", "++", "p--", "--") {
        inc = self._inc_dec_stmt(c_node);
        if inc is not None {
            self._earn_tier_a(c_node);
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

    self._earn_tier_a(c_node);

    if stmt and isinstance(result, ast3.expr) {
        line = getattr(result, "lineno", self._lineno);
        col = getattr(result, "col_offset", 0);
        return self._stamp_manual(ast3.Expr(value=result), line, col);
    }
    return result;
}

impl CMapper._inc_dec_stmt(nd: object) -> object | None {
    target = self.conv_expr(nd.expr);
    if not isinstance(target, (ast3.Name, ast3.Attribute, ast3.Subscript)) {
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
    if isinstance(py_node, (ast3.Name, ast3.Attribute, ast3.Subscript)) {
        py_node.ctx = ast3.Store();
    }
    return py_node;
}
