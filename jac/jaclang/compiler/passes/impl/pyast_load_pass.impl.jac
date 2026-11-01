impl PyastBuildPass.aug_op_map(tok_dict: dict[str, str], op: Token) -> str {
    op.value += '=';
    for (_key, value) in tok_dict.items() {
        if (value == op.value) {
            break;
        }
    }
    return _key;
}

impl PyastBuildPass.is_canceled -> bool {
    return self.ctx.cancel_requested
        or (self.ctx.cancel_token is not None and self.ctx.cancel_token.is_set());
}

impl PyastBuildPass.convert_to_doc(string: String) -> None {
    val = string.value;
    if val.startswith('"""') or val.startswith("'''") {
        return;
    } elif val.startswith('"') or val.startswith("'") {
        content = val[1:-1];
    } else {
        content = val;
    }

    string.value = f'"""{content}"""';
}

impl PyastBuildPass.proc_withitem(nd: py_ast.withitem) -> ExprAsItem {
    context_expr = self.convert(nd.context_expr);
    optional_vars = self.convert(nd.optional_vars) if nd.optional_vars else None;
    if (
        isinstance(context_expr, Expr)
        and (isinstance(optional_vars, Expr) or (optional_vars is None))
    ) {
        kid: list[UniNode] = [context_expr];
        if optional_vars is not None {
            kid.append(optional_vars);
        }
        return ExprAsItem(expr=context_expr, alias=optional_vars or None, kid=kid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_match_case(nd: py_ast.match_case) -> MatchCase {
    pattern = self.convert(nd.pattern);
    guard = self.convert(nd.guard) if nd.guard else None;
    body = [self.convert(i) for i in nd.body];
    valid = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (
        isinstance(pattern, MatchPattern)
        and (isinstance(guard, Expr) or (guard is None))
    ) {
        kid: list[UniNode] = [pattern];
        if guard is not None {
            kid.append(guard);
        }
        kid.extend(valid);
        return MatchCase(pattern=pattern, guard=guard, body=valid, kid=kid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_keyword(nd: py_ast.keyword) -> KWPair {
    arg = None;
    if nd.arg {
        arg = self.name_node(nd, nd.arg, is_kwesc=(nd.arg in _reserved_keywords));
    }
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return KWPair(
            key=arg, value=value, kid=[arg, value] if arg is not None else [value]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_comprehension(nd: py_ast.comprehension) -> InnerCompr {
    target = self.convert(nd.target);
    iter = self.convert(nd.iter);
    valid: (list[Expr] | None) = None;
    if (len(nd.ifs) != 0) {
        ifs_list = [self.convert(ifs) for ifs in nd.ifs];
        valid = [
            ifs
            for ifs in ifs_list
            if isinstance(ifs, Expr)
        ];
    } else {
        valid = None;
    }
    is_async = nd.is_async > 0;
    if (isinstance(target, Expr) and isinstance(iter, Expr)) {
        kid: list[UniNode] = [target, iter];
        conds: list[Expr] = valid or [];
        kid.extend(conds);
        return InnerCompr(
            is_async=is_async,
            target=target,
            collection=iter,
            conditional=valid,
            kid=kid
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_not_in(nd: py_ast.NotIn) -> Token {
    return self.operator(Tok.KW_NIN, 'not in');
}

impl PyastBuildPass.proc_not_eq(nd: py_ast.NotEq) -> Token {
    return self.operator(Tok.NE, '!=');
}

impl PyastBuildPass.proc_lt_e(nd: py_ast.LtE) -> Token {
    return self.operator(Tok.LTE, '<=');
}

impl PyastBuildPass.proc_lt(nd: py_ast.Lt) -> Token {
    return self.operator(Tok.LT, '<');
}

impl PyastBuildPass.proc_is_not(nd: py_ast.IsNot) -> Token {
    return self.operator(Tok.KW_ISN, 'is not');
}

impl PyastBuildPass.proc_is(nd: py_ast.Is) -> Token {
    return self.operator(Tok.KW_IS, 'is');
}

impl PyastBuildPass.proc_in(nd: py_ast.In) -> Token {
    return self.operator(Tok.KW_IN, 'in');
}

impl PyastBuildPass.proc_gt_e(nd: py_ast.GtE) -> Token {
    return self.operator(Tok.GTE, '>=');
}

impl PyastBuildPass.proc_gt(nd: py_ast.Gt) -> Token {
    return self.operator(Tok.GT, '>');
}

impl PyastBuildPass.proc_eq(nd: py_ast.Eq) -> Token {
    return self.operator(Tok.EE, '==');
}

impl PyastBuildPass.proc_u_sub(nd: py_ast.USub) -> Token {
    return self.operator(Tok.MINUS, '-');
}

impl PyastBuildPass.proc_u_add(nd: py_ast.UAdd) -> Token {
    return self.operator(Tok.PLUS, '+');
}

impl PyastBuildPass.proc_not(nd: py_ast.Not) -> Token {
    return self.operator(Tok.NOT, 'not');
}

impl PyastBuildPass.proc_invert(nd: py_ast.Invert) -> Token {
    return self.operator(Tok.BW_NOT, '~');
}

impl PyastBuildPass.proc_sub(nd: py_ast.Sub) -> Token {
    return self.operator(Tok.MINUS, '-');
}

impl PyastBuildPass.proc_r_shift(nd: py_ast.RShift) -> Token {
    return self.operator(Tok.RSHIFT, '>>');
}

impl PyastBuildPass.proc_pow(nd: py_ast.Pow) -> Token {
    return self.operator(Tok.STAR_POW, '**');
}

impl PyastBuildPass.proc_mat_mult(nd: py_ast.MatMult) -> Token {
    return self.operator(Tok.DECOR_OP, '@');
}

impl PyastBuildPass.proc_mult(nd: py_ast.Mult) -> Token {
    return self.operator(Tok.STAR_MUL, '*');
}

impl PyastBuildPass.proc_mod(nd: py_ast.Mod) -> Token {
    return self.operator(Tok.MOD, '%');
}

impl PyastBuildPass.proc_l_shift(nd: py_ast.LShift) -> Token {
    return self.operator(Tok.LSHIFT, '<<');
}

impl PyastBuildPass.proc_floor_div(nd: py_ast.FloorDiv) -> Token {
    return self.operator(Tok.FLOOR_DIV, '//');
}

impl PyastBuildPass.proc_div(nd: py_ast.Div) -> Token {
    return self.operator(Tok.DIV, '/');
}

impl PyastBuildPass.proc_bit_xor(nd: py_ast.BitXor) -> Token {
    return self.operator(Tok.BW_XOR, '^');
}

impl PyastBuildPass.proc_bit_or(nd: py_ast.BitOr) -> Token {
    return self.operator(Tok.BW_OR, '|');
}

impl PyastBuildPass.proc_bit_and(nd: py_ast.BitAnd) -> Token {
    return self.operator(Tok.BW_AND, '&');
}

impl PyastBuildPass.proc_add(nd: py_ast.Add) -> Token {
    return self.operator(Tok.PLUS, '+');
}

impl PyastBuildPass.proc_or(nd: py_ast.Or) -> Token {
    return self.operator(Tok.KW_OR, 'or');
}

impl PyastBuildPass.proc_and(nd: py_ast.And) -> Token {
    return self.operator(Tok.KW_AND, 'and');
}

impl PyastBuildPass.operator(tok: Tok, value: str) -> Token {
    return Token(
        orig_src=self.orig_src,
        name=tok,
        value=value,
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
}

impl PyastBuildPass.proc_arguments(nd: py_ast.arguments) -> FuncSignature {
    def _apply_kind(params: list[UniNode], kind: ParamKind) -> list[ParamVar] {
        typed: list[ParamVar] = [];
        for param in params {
            param_var = cast(ParamVar, param);
            param_var.param_kind = kind;
            typed.append(param_var);
        }
        return typed;
    }
    posonlyargs = _apply_kind(
        [self.convert(arg) for arg in nd.posonlyargs], ParamKind.POSONLY
    );
    args = _apply_kind([self.convert(arg) for arg in nd.args], ParamKind.NORMAL);
    vararg_node = self.convert(nd.vararg) if nd.vararg else None;
    vararg: (ParamVar | None) = None;
    if (vararg_node and isinstance(vararg_node, ParamVar)) {
        vararg = vararg_node;
        vararg.param_kind = ParamKind.VARARG;
        _unpack = Token(
            orig_src=self.orig_src,
            name=Tok.STAR_MUL,
            value='*',
            line=vararg.loc.first_line,
            end_line=vararg.loc.last_line,
            col_start=vararg.loc.col_start,
            col_end=vararg.loc.col_end,
            pos_start=0,
            pos_end=0
        );
        vararg.add_kids_left([_unpack], role=UnpackRole);
    }
    kwonlyargs = _apply_kind(
        [self.convert(arg) for arg in nd.kwonlyargs], ParamKind.KWONLY
    );
    for i in range(len(kwonlyargs)) {
        kwa = kwonlyargs[i];
        kwd = nd.kw_defaults[i];
        kwdefault = self.convert(kwd) if kwd else None;

        if (kwdefault and isinstance(kwa, ParamVar) and isinstance(kwdefault, Expr)) {
            kwa.add_kids_right([kwdefault], role=ValueRole);
        }
    }
    kwarg_node = self.convert(nd.kwarg) if nd.kwarg else None;
    kwarg: (ParamVar | None) = None;
    if (kwarg_node and isinstance(kwarg_node, ParamVar)) {
        kwarg = kwarg_node;
        kwarg.param_kind = ParamKind.KWARG;
        _unpack = Token(
            orig_src=self.orig_src,
            name=Tok.STAR_POW,
            value='**',
            line=kwarg.loc.first_line,
            end_line=kwarg.loc.last_line,
            col_start=kwarg.loc.col_start,
            col_end=kwarg.loc.col_end,
            pos_start=0,
            pos_end=0
        );
        kwarg.add_kids_left([_unpack], role=UnpackRole);
    }
    defaults = [self.convert(expr) for expr in nd.defaults];
    for para in [*posonlyargs, *args][::-1] {
        if not defaults {
            break;
        }
        `default = defaults.pop();

        if (`default and isinstance(para, ParamVar) and isinstance(`default, Expr)) {
            para.add_kids_right([`default], role=ValueRole);
        }
    }
    if (kwonlyargs or args or posonlyargs or vararg or kwarg) {
        kids = [];
        kids.extend(posonlyargs) if posonlyargs else None;
        kids.extend(args) if args else None;
        kids.append(vararg) if vararg else None;
        kids.extend(kwonlyargs) if kwonlyargs else None;
        kids.append(kwarg) if kwarg else None;
        return FuncSignature(
            posonly_params=posonlyargs,
            params=args,
            varargs=vararg,
            kwonlyargs=kwonlyargs,
            kwargs=kwarg,
            return_type=None,
            kid=kids
        );
    } else {
        return FuncSignature(
            posonly_params=posonlyargs,
            params=[],
            varargs=vararg,
            kwonlyargs=kwonlyargs,
            kwargs=kwarg,
            return_type=None,
            kid=[self.operator(Tok.LPAREN, '('), self.operator(Tok.RPAREN, ')')]
        );
    }
}

impl PyastBuildPass.proc_arg(nd: py_ast.arg) -> ParamVar {
    name = self.name_node(nd, nd.arg, is_kwesc=(nd.arg in _reserved_keywords));
    self.in_type_annotation = True;
    ann_expr = self.convert(nd.annotation)
        if nd.annotation
        else self.name_node(nd, 'Any');
    self.in_type_annotation = False;
    if not isinstance(ann_expr, Expr) {
        raise RuntimeError(self.ctx.ice('Expected annotation to be an expression'));
    }
    annot = SubTag[Expr](tag=ann_expr, kid=[ann_expr]);
    paramvar = ParamVar(
        name=name, type_tag=annot, unpack=None, value=None, kid=[name, annot]
    );
    return paramvar;
}

impl PyastBuildPass.proc_alias(nd: py_ast.alias) -> ExprAsItem {
    name = self.name_node(nd, nd.name);
    asname = self.name_node(nd, nd.asname) if nd.asname else None;
    return ExprAsItem(
        expr=name, alias=asname, kid=[name, asname] if asname else [name]
    );
}

impl PyastBuildPass.proc_yield_from(nd: py_ast.YieldFrom) -> YieldExpr {
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return YieldExpr(expr=value, with_from=True, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_yield(nd: py_ast.Yield) -> YieldExpr {
    value = self.convert(nd.value) if nd.value else None;
    if isinstance(value, Expr) {
        return YieldExpr(expr=value, with_from=False, kid=[value]);
    } elif not value {
        return YieldExpr(
            expr=None, with_from=False, kid=[self.operator(Tok.KW_YIELD, 'yield')]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_tuple(nd: py_ast.Tuple) -> TupleVal {
    elts = [self.convert(elt) for elt in nd.elts];
    if (len(nd.elts) != 0) {
        valid_elts = [
            i
            for i in elts
            if isinstance(i, (Expr, KWPair))
        ];
        if (len(elts) != len(valid_elts)) {
            raise RuntimeError(self.ctx.ice('Length mismatch in tuple elts'));
        }
        kid = elts;
    } else {
        l_paren = self.operator(Tok.LPAREN, '(');
        r_paren = self.operator(Tok.RPAREN, ')');
        valid_elts = [];
        kid = [l_paren, r_paren];
    }
    return TupleVal(values=valid_elts, kid=kid);
}

impl PyastBuildPass.proc_try_star(nd: py_ast.TryStar) -> TryStmt {
    return self.proc_try(nd);
}

impl PyastBuildPass.proc_try(nd: (py_ast.Try | py_ast.TryStar)) -> TryStmt {
    body = [self.convert(i) for i in nd.body];
    valid = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(valid) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in try body'));
    }
    valid_body = valid;
    kid: list[UniNode] = [*valid_body];
    if (len(nd.handlers) != 0) {
        handlers = [self.convert(i) for i in nd.handlers];
        valid_handlers = [
            i
            for i in handlers
            if isinstance(i, Except)
        ];
        if (len(handlers) != len(valid_handlers)) {
            raise RuntimeError(self.ctx.ice('Length mismatch in try handlers'));
        }
        excepts = valid_handlers;
        kid.extend(valid_handlers);
    } else {
        excepts = [];
    }
    else_body: (list[CodeBlockStmt] | None) = None;
    elsestmt: (ElseStmt | None) = None;
    if (len(nd.orelse) != 0) {
        orelse = [self.convert(i) for i in nd.orelse];
        valid_orelse = [
            i
            for i in orelse
            if isinstance(i, CodeBlockStmt)
        ];
        if (len(orelse) != len(valid_orelse)) {
            raise RuntimeError(self.ctx.ice('Length mismatch in try orelse'));
        }
        else_body = valid_orelse;
        elsestmt = ElseStmt(body=valid_orelse, kid=valid_orelse);
        kid.extend(valid_orelse);
    } else {
        else_body = None;
    }
    if (len(nd.finalbody) != 0) {
        finalbody = [self.convert(i) for i in nd.finalbody];
        valid_finalbody = [
            i
            for i in finalbody
            if isinstance(i, CodeBlockStmt)
        ];
        if (len(finalbody) != len(valid_finalbody)) {
            raise RuntimeError(self.ctx.ice('Length mismatch in try finalbody'));
        }
        finally_stmt_obj: (FinallyStmt | None) = (
            fin_append := FinallyStmt(body=valid_finalbody, kid=valid_finalbody)
        );
        kid.append(fin_append);
    } else {
        finally_stmt_obj = None;
    }
    ret = TryStmt(
        body=valid_body,
        excepts=excepts,
        else_body=elsestmt if else_body else None,
        awaiting_body=None,
        finally_body=finally_stmt_obj,
        kid=kid
    );
    return ret;
}

impl PyastBuildPass.proc_subscript(nd: py_ast.Subscript) -> AtomTrailer {
    value = self.convert(nd.value);
    slice = self.convert(nd.slice);
    if (not isinstance(slice, IndexSlice) and isinstance(slice, Expr)) {
        slice_node = Slice(start=slice, stop=None, step=None, kid=[slice]);
        slice = IndexSlice(slices=[slice_node], is_range=False, kid=[slice_node]);
    }
    if (
        not isinstance(slice, IndexSlice)
        and isinstance(slice, TupleVal)
        and slice.values
    ) {
        slices: list[Slice] = [];
        for index_slice in slice.values {
            if not isinstance(index_slice, IndexSlice) {
                raise RuntimeError(self.ctx.ice());
            }
            slices.append(index_slice.slices[0]);
        }
        slice = IndexSlice(slices=slices, is_range=True, kid=list(slices));
    }
    if (isinstance(value, Expr) and isinstance(slice, IndexSlice)) {
        return AtomTrailer(
            target=value,
            right=slice,
            is_attr=False,
            is_null_ok=False,
            kid=[value, slice]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_starred(nd: py_ast.Starred) -> UnaryExpr {
    star_tok = self.operator(Tok.STAR_MUL, '*');
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return UnaryExpr(operand=value, op=star_tok, kid=[value, star_tok]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_slice(nd: py_ast.Slice) -> IndexSlice {
    lower = self.convert(nd.lower) if nd.lower else None;
    upper = self.convert(nd.upper) if nd.upper else None;
    step = self.convert(nd.step) if nd.step else None;
    valid_kid = [
        i
        for i in [lower, upper, step]
        if i
    ];
    if not valid_kid {
        valid_kid = [self.operator(Tok.COLON, ':')];
    }
    if (
        (isinstance(lower, Expr) or (lower is None))
        and (isinstance(upper, Expr) or (upper is None))
        and (isinstance(step, Expr) or (step is None))
    ) {
        slice_node = Slice(start=lower, stop=upper, step=step, kid=valid_kid);
        return IndexSlice(slices=[slice_node], is_range=True, kid=[slice_node]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass._proc_compr(
    nd: PyComprehensionNode, compr_cls: type[ComprT]
) -> ComprT {
    elt = self.convert(nd.elt);
    generators = [self.convert(gen) for gen in nd.generators];
    valid = [
        gen
        for gen in generators
        if isinstance(gen, InnerCompr)
    ];
    if (len(generators) != len(valid)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in list comp generators'));
    }
    if isinstance(elt, Expr) {
        return compr_cls(out_expr=elt, compr=valid, kid=[elt, *valid]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_set_comp(nd: py_ast.SetComp) -> ListCompr {
    return self._proc_compr(nd, SetCompr);
}

impl PyastBuildPass.proc_set(nd: py_ast.Set) -> SetVal {
    if (len(nd.elts) != 0) {
        elts = [self.convert(i) for i in nd.elts];
        valid = [
            i
            for i in elts
            if isinstance(i, Expr)
        ];
        if (len(valid) != len(elts)) {
            raise RuntimeError(self.ctx.ice('Length mismatch in set body'));
        }
        kid: list[UniNode] = [*valid];
    } else {
        valid = [];
        l_brace = self.operator(Tok.LBRACE, '{');
        r_brace = self.operator(Tok.RBRACE, '}');
        kid = [l_brace, r_brace];
    }
    return SetVal(values=valid, kid=kid);
}

impl PyastBuildPass.proc_pass(nd: py_ast.stmt) -> Semi {
    return Semi(
        orig_src=self.orig_src,
        name=Tok.SEMI,
        value=';',
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
}

impl PyastBuildPass.proc_nonlocal(nd: py_ast.Nonlocal) -> Semi {
    return self.proc_pass(nd);
}

impl PyastBuildPass.proc_named_expr(nd: py_ast.NamedExpr) -> AtomUnit {
    target = self.convert(nd.target);
    value = self.convert(nd.value);
    if (isinstance(value, Expr) and isinstance(target, Name)) {
        op = self.operator(Tok.WALRUS_EQ, ':=');
        if isinstance(value, IfElseExpr) {
            value = AtomUnit(
                value=value,
                kid=[
                    self.operator(Tok.LPAREN, '('),
                    value,
                    self.operator(Tok.RPAREN, ')')
                ]
            );
        }
        expr = BinaryExpr(left=target, op=op, right=value, kid=[target, op, value]);
        return AtomUnit(
            value=expr,
            kid=[self.operator(Tok.LPAREN, '('), expr, self.operator(Tok.RPAREN, ')')]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_name(nd: py_ast.Name) -> Name {
    should_escape = (
        (nd.id in _reserved_keywords)
        and not self.in_type_annotation
        and not self.in_match_pattern
        and not self.in_fstring_expr
    );
    ret = self.name_node(nd, nd.id, is_kwesc=should_escape);
    return ret;
}

impl PyastBuildPass.proc_match_value(nd: py_ast.MatchValue) -> MatchValue {
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return MatchValue(value=value, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_match_star(nd: py_ast.MatchStar) -> MatchStar {
    name = self.name_node(nd, nd.name or '_');
    return MatchStar(name=name, is_list=True, kid=[name]);
}

impl PyastBuildPass.proc_match_singleton(nd: py_ast.MatchSingleton) -> MatchSingleton {
    singleton = nd.value;
    if isinstance(singleton, PyNoneType) {
        value = Null(
            orig_src=self.orig_src,
            name=Tok.NULL,
            value='None',
            line=nd.lineno,
            end_line=nd.end_lineno or nd.lineno,
            col_start=nd.col_offset,
            col_end=(nd.col_offset + 4),
            pos_start=0,
            pos_end=0
        );
        return MatchSingleton(value=value, kid=[value]);
    }
    if isinstance(singleton, PyBool) {
        text = 'True' if singleton.val else 'False';
        value = Bool(
            orig_src=self.orig_src,
            name=Tok.BOOL,
            value=text,
            line=nd.lineno,
            end_line=nd.end_lineno or nd.lineno,
            col_start=nd.col_offset,
            col_end=(nd.col_offset + len(text)),
            pos_start=0,
            pos_end=0
        );
        return MatchSingleton(value=value, kid=[value]);
    }
    raise RuntimeError(self.ctx.ice('Invalid match singleton'));
}

impl PyastBuildPass.proc_match_sequence(nd: py_ast.MatchSequence) -> MatchSequence {
    patterns = [self.convert(i) for i in nd.patterns];
    valid = [
        i
        for i in patterns
        if isinstance(i, MatchPattern)
    ];
    if (len(patterns) == len(valid)) {
        return MatchSequence(values=valid, kid=valid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_match_or(nd: py_ast.MatchOr) -> MatchOr {
    patterns = [self.convert(i) for i in nd.patterns];
    valid = [
        i
        for i in patterns
        if isinstance(i, MatchPattern)
    ];
    return MatchOr(patterns=valid, kid=valid);
}

impl PyastBuildPass.proc_match_mapping(nd: py_ast.MatchMapping) -> MatchMapping {
    values: list[(MatchKVPair | MatchStar)] = [];
    keys = [self.convert(i) for i in nd.keys];
    valid_keys = [
        i
        for i in keys
        if isinstance(i, (MatchPattern, NameAtom, AtomExpr))
    ];
    patterns = [self.convert(i) for i in nd.patterns];
    valid_patterns = [
        i
        for i in patterns
        if isinstance(i, MatchPattern)
    ];
    for i in range(len(valid_keys)) {
        colon_token = Token(
            orig_src=self.orig_src,
            name=Tok.COLON,
            value=":",
            line=0,
            end_line=0,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0
        );
        kv_pair = MatchKVPair(
            key=valid_keys[i],
            value=valid_patterns[i],
            kid=[valid_keys[i], colon_token, valid_patterns[i]]
        );
        values.append(kv_pair);
    }
    if nd.rest {
        name = self.name_node(nd, nd.rest);
        values.append(MatchStar(name=name, is_list=False, kid=[name]));
    }
    return MatchMapping(values=values, kid=values);
}

impl PyastBuildPass.proc_match_class(nd: py_ast.MatchClass) -> MatchArch {
    self.in_match_pattern = True;
    cls = self.convert(nd.cls);
    self.in_match_pattern = False;
    kid = [cls];
    patterns_list: (list[MatchPattern] | None) = None;
    kw_patterns_list: (list[MatchKVPair] | None) = None;
    if (len(nd.patterns) != 0) {
        patterns = [self.convert(i) for i in nd.patterns];
        valid_patterns = [
            i
            for i in patterns
            if isinstance(i, MatchPattern)
        ];
        if (len(patterns) == len(valid_patterns)) {
            kid.extend(valid_patterns);
            patterns_list = valid_patterns;
        } else {
            raise RuntimeError(self.ctx.ice());
        }
    } else {
        patterns_list = None;
    }
    if len(nd.kwd_patterns) {
        kv_pairs: list[MatchKVPair] = [];
        names: list[Name] = [];
        valid_kwd_patterns: list[MatchPattern] = [];
        kwd_patterns = [self.convert(i) for i in nd.kwd_patterns];
        for i in range(len(nd.kwd_attrs)) {
            kwd_attrs = nd.kwd_attrs[i];
            if isinstance(kwd_patterns[i], MatchPattern) {
                names.append(
                    Name(
                        orig_src=self.orig_src,
                        name=Tok.NAME,
                        value=kwd_attrs,
                        line=nd.lineno,
                        end_line=nd.end_lineno or nd.lineno,
                        col_start=nd.col_offset,
                        col_end=(nd.col_offset + len(kwd_attrs)),
                        pos_start=0,
                        pos_end=0
                    )
                );
                valid_kwd_patterns.append(kwd_patterns[i]);
            }
        }
        for i in range(len(valid_kwd_patterns)) {
            eq_token = Token(
                orig_src=self.orig_src,
                name=Tok.EQ,
                value="=",
                line=0,
                end_line=0,
                col_start=0,
                col_end=0,
                pos_start=0,
                pos_end=0
            );
            kv_pairs.append(
                MatchKVPair(
                    key=names[i],
                    value=valid_kwd_patterns[i],
                    kid=[names[i], eq_token, valid_kwd_patterns[i]]
                )
            );
        }
        kid.extend(kv_pairs);
        kw_patterns_list = kv_pairs;
    } else {
        kw_patterns_list = None;
    }
    if isinstance(cls, (NameAtom, AtomTrailer)) {
        return MatchArch(
            name=cls, arg_patterns=patterns_list, kw_patterns=kw_patterns_list, kid=kid
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_match_as(nd: py_ast.MatchAs) -> (MatchAs | MatchWild) {
    pattern = self.convert(nd.pattern) if nd.pattern else None;
    name = self.name_node(nd, nd.name or '_');
    if (
        (name.value == '_')
        or ((pattern is not None) and not isinstance(pattern, MatchPattern))
    ) {
        return MatchWild(kid=[name]);
    }
    return MatchAs(
        name=name, pattern=pattern, kid=[name] if (pattern is None) else [name, pattern]
    );
}

impl PyastBuildPass.proc_match(nd: py_ast.Match) -> MatchStmt {
    subject = self.convert(nd.subject);
    cases = [self.convert(i) for i in nd.cases];
    valid = [
        `case
        for `case in cases
        if isinstance(`case, MatchCase)
    ];
    if isinstance(subject, Expr) {
        return MatchStmt(target=subject, cases=valid, kid=[subject, *valid]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_list_comp(nd: py_ast.ListComp) -> ListCompr {
    return self._proc_compr(nd, ListCompr);
}

impl PyastBuildPass.proc_list(nd: py_ast.List) -> ListVal {
    elts = [self.convert(elt) for elt in nd.elts];
    valid_elts = [
        elt
        for elt in elts
        if isinstance(elt, Expr)
    ];
    if (len(valid_elts) != len(elts)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in list elements'));
    }
    l_square = self.operator(Tok.LSQUARE, '[');
    r_square = self.operator(Tok.RSQUARE, ']');
    return ListVal(
        values=valid_elts, kid=[*valid_elts] if valid_elts else [l_square, r_square]
    );
}

impl PyastBuildPass.proc_lambda(nd: py_ast.Lambda) -> LambdaExpr {
    args = self.convert(nd.args);
    body = self.convert(nd.body);
    if (isinstance(args, FuncSignature) and isinstance(body, Expr)) {
        body_stmt = ExprStmt(expr=body, in_fstring=False, kid=[body]);
        return LambdaExpr(signature=args, body=[body_stmt], kid=[args, body_stmt]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_joined_str(nd: py_ast.JoinedStr) -> MultiString {
    ast_seg = self._get_source_segment(nd);
    if (ast_seg is None) {
        ast_seg = 'f""';
    }
    fstr_match = re.`match('(?i)(fr|rf|f)(\'{3}|\\"{3}|\'|\\")', ast_seg);

    valid: list[(String | FormattedValue)] = [];
    for i in nd.values {
        if (isinstance(i, py_ast.Constant) and isinstance(i.value, PyStr)) {
            text = i.value.val;
            escaped_value = self._get_source_segment(i);
            if escaped_value is None {
                raw_repr = repr(text);
                escaped_value = raw_repr[1:-1];
            }

            valid.append(
                String(
                    orig_src=self.orig_src,
                    name='STRING',
                    value=escaped_value,
                    line=i.lineno,
                    end_line=i.end_lineno or i.lineno,
                    col_start=i.col_offset,
                    col_end=(i.col_offset + len(text)),
                    pos_start=0,
                    pos_end=0
                )
            );
        } elif isinstance(i, py_ast.FormattedValue) {
            converted = self.convert(i);
            if isinstance(converted, FormattedValue) {
                valid.append(converted);
            }
        } else {
            raise RuntimeError(self.ctx.ice('Invalid node in joined str'));
        }
    }
    if fstr_match {
        (prefix, quote) = fstr_match.groups();
        start = fstr_match.group(0);
        end = quote;
    } else {
        start = "f'";
        end = "'";
    }
    all_content = ''.join(
        part.lit_value
        for part in valid
        if isinstance(part, String)
    );
    has_single = "'" in all_content;
    has_double = '"' in all_content;
    is_triple = len(end) == 3;
    if (has_single and has_double and not is_triple) {
        if ("'" in end) {
            start = 'f"""';
            end = '"""';
        } else {
            start = "f'''";
            end = "'''";
        }
    } elif ((("'" in end) and has_single) or (('"' in end) and has_double)) {
        if ("'" in end) {
            start = start.replace("'", '"');
            end = end.replace("'", '"');
        } else {
            start = start.replace('"', "'");
            end = end.replace('"', "'");
        }
    }
    tok_start = self.operator(Tok.STRING, start);
    tok_end = self.operator(Tok.STRING, end);
    fstr = FString(
        start=tok_start,
        parts=valid,
        end=tok_end,
        kid=[tok_start, *valid, tok_end] if valid else [EmptyToken()]
    );
    return MultiString(strings=[fstr], kid=[fstr]);
}

impl PyastBuildPass.proc_import_from(nd: py_ast.ImportFrom) -> Import {
    lang = self.name_node(nd, 'py', col_end=0);
    modpaths: list[Name] = [];
    if nd.module {
        for i in nd.module.split('.') {
            modpaths.append(self.name_node(nd, i, col_start=0, col_end=0));
        }
    }
    level = nd.level or 0;
    moddots = [self.operator(Tok.DOT, '.') for _ in range(level)];
    modparts = moddots + modpaths;
    path = ModulePath(path=modpaths or None, level=level, alias=None, kid=modparts);
    names = [self.convert(name) for name in nd.names];
    valid_names = [];
    for name in names {
        if (
            isinstance(name, ExprAsItem)
            and isinstance(name.expr, Name)
            and (isinstance(name.alias, Name) or (name.alias is None))
        ) {
            valid_names.append(
                ModuleItem(
                    name=name.expr, alias=name.alias or None, kid=[name->:Kid:->]
                )
            );
        } else {
            raise RuntimeError(self.ctx.ice());
        }
    }
    items = valid_names;
    if not items {
        raise RuntimeError(self.ctx.ice('No valid names in import from'));
    }
    pytag = SubTag[Name](tag=lang, kid=[lang]);
    if ((len(nd.names) == 1) and (nd.names[0].name == '*')) {
        ret = Import(from_loc=None, items=[path], is_absorb=True, kid=[pytag, path]);
        return ret;
    }
    ret = Import(
        from_loc=path, items=items, is_absorb=False, kid=[pytag, path, *items]
    );
    return ret;
}

impl PyastBuildPass.proc_import(nd: py_ast.Import) -> Import {
    names = [self.convert(name) for name in nd.names];
    valid_names = [
        name
        for name in names
        if isinstance(name, ExprAsItem)
    ];
    if (len(valid_names) != len(names)) {
        self.ctx.emit(E5041);
    }
    paths = [];
    for name in valid_names {
        if (
            isinstance(name.expr, Name)
            and (isinstance(name.alias, Name) or (name.alias is None))
        ) {
            segments: list[Name] = [
                self.name_node(nd, part) for part in name.expr.value.split(".")
            ];
            if not segments {
                segments = [name.expr];
            }
            seg_kid: list[UniNode] = list(segments);
            if name.alias {
                seg_kid.append(name.alias);
            }
            paths.append(
                ModulePath(path=segments, level=0, alias=name.alias, kid=seg_kid)
            );
        } else {
            raise RuntimeError(self.ctx.ice());
        }
    }
    ret = Import(from_loc=None, items=paths, is_absorb=False, kid=paths);
    return ret;
}

impl PyastBuildPass.proc_if_exp(nd: py_ast.IfExp) -> IfElseExpr {
    `test = self.convert(nd.`test);
    body = self.convert(nd.body);
    orelse = self.convert(nd.orelse);
    if (
        isinstance(`test, Expr) and isinstance(body, Expr) and isinstance(orelse, Expr)
    ) {
        cond_cfg = CfgExpr(expr=`test, kid=[`test]);
        val_cfg = CfgExpr(expr=body, kid=[body]);
        else_cfg = CfgExpr(expr=orelse, kid=[orelse]);
        return IfElseExpr(
            value=val_cfg,
            condition=cond_cfg,
            else_value=else_cfg,
            kid=[val_cfg, cond_cfg, else_cfg]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_global(nd: py_ast.Global) -> Semi {
    return self.proc_pass(nd);
}

impl PyastBuildPass.proc_generator_exp(nd: py_ast.GeneratorExp) -> GenCompr {
    return self._proc_compr(nd, GenCompr);
}

impl PyastBuildPass.proc_formatted_value(nd: py_ast.FormattedValue) -> FormattedValue {
    prev_in_fstring = self.in_fstring_expr;
    self.in_fstring_expr = True;
    value = self.convert(nd.value);
    self.in_fstring_expr = prev_in_fstring;

    fmt_spec: (Expr | None) = None;
    if nd.format_spec {
        if isinstance(nd.format_spec, py_ast.JoinedStr) {
            fmt_parts: list[str] = [];
            for part in nd.format_spec.values {
                if isinstance(part, py_ast.Constant) and isinstance(part.value, PyStr) {
                    fmt_parts.append(part.value.val);
                } elif isinstance(part, py_ast.FormattedValue) {
                    nested_fmt = self.convert(part);
                    if isinstance(nested_fmt, FormattedValue) {
                        fmt_spec = nested_fmt;
                        break;
                    }
                }
            }
            if (not fmt_spec and fmt_parts) {
                fmt_str = ''.join(fmt_parts);
                fmt_spec = String(
                    orig_src=self.orig_src,
                    name='STRING',
                    value=fmt_str,
                    line=nd.format_spec.lineno,
                    end_line=nd.format_spec.end_lineno or nd.format_spec.lineno,
                    col_start=nd.format_spec.col_offset,
                    col_end=nd.format_spec.end_col_offset or nd.format_spec.col_offset,
                    pos_start=0,
                    pos_end=0
                );
            }
        } else {
            fmt_spec = cast(Expr, self.convert(nd.format_spec));
        }
    }
    if isinstance(value, Expr) {
        kid: list[UniNode] = [value];
        if fmt_spec is not None {
            kid.append(fmt_spec);
        }
        ret = FormattedValue(
            format_part=value, conversion=nd.conversion, format_spec=fmt_spec, kid=kid
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
    return ret;
}

impl PyastBuildPass.proc_expr(nd: py_ast.Expr) -> ExprStmt {
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return ExprStmt(expr=value, in_fstring=False, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_except_handler(nd: py_ast.ExceptHandler) -> Except {
    type = self.convert(nd.type) if nd.type else None;
    name: (Name | None) = None;
    if (not type and not nd.name) {
        type = self.name_node(nd, 'Exception');
        name = self.name_node(nd, 'e');
    } else {
        name = self.name_node(nd, nd.name) if nd.name else None;
    }
    body = [self.convert(i) for i in nd.body];
    valid = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(valid) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in except handler body'));
    }
    kid = [
        item
        for item in [type, name, *valid]
        if item
    ];
    if (isinstance(type, Expr) and (isinstance(name, Name) or not name)) {
        return Except(ex_type=type, name=name, body=valid, kid=kid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_dict_comp(nd: py_ast.DictComp) -> DictCompr {
    key = self.convert(nd.key);
    value = self.convert(nd.value);
    if (isinstance(key, Expr) and isinstance(value, Expr)) {
        kv_pair = KVPair(key=key, value=value, kid=[key, value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
    generators = [self.convert(i) for i in nd.generators];
    valid = [
        i
        for i in generators
        if isinstance(i, InnerCompr)
    ];
    if (len(valid) != len(generators)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in dict compr generators'));
    }
    return DictCompr(kv_pair=kv_pair, compr=valid, kid=[kv_pair, *valid]);
}

impl PyastBuildPass.proc_dict(nd: py_ast.Dict) -> DictVal {
    keys = [self.convert(i) if i else None for i in nd.keys];
    values = [self.convert(i) for i in nd.values];
    valid_keys = [
        i
        for i in keys
        if (isinstance(i, Expr) or (i is None))
    ];
    valid_values = [
        i
        for i in values
        if isinstance(i, Expr)
    ];
    kvpair: list[KVPair] = [];
    for i in range(len(values)) {
        key_pluck = valid_keys[i];
        kvp = KVPair(
            key=key_pluck,
            value=valid_values[i],
            kid=[key_pluck, valid_values[i]] if key_pluck else [valid_values[i]]
        );
        kvpair.append(kvp);
    }
    return DictVal(
        kv_pairs=kvpair,
        kid=[*kvpair]
            if len(kvpair)
            else [self.operator(Tok.LBRACE, '{'), self.operator(Tok.RBRACE, '}')]
    );
}

impl PyastBuildPass.proc_continue(nd: py_ast.Continue) -> CtrlStmt {
    continue_tok = Token(
        orig_src=self.orig_src,
        name=Tok.KW_CONTINUE,
        value='continue',
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
    return CtrlStmt(ctrl=continue_tok, kid=[continue_tok]);
}

impl PyastBuildPass.proc_constant(nd: py_ast.Constant) -> Literal {
    value = nd.value;
    line = nd.lineno;
    end_line = nd.end_lineno or nd.lineno;
    col = nd.col_offset;
    if isinstance(value, PyEllipsis) {
        return UniEllipsis(
            orig_src=self.orig_src,
            name=Tok.ELLIPSIS,
            value='...',
            line=line,
            end_line=end_line,
            col_start=col,
            col_end=(col + 3),
            pos_start=0,
            pos_end=0
        );
    }
    if isinstance(value, PyStr) {
        text = value.val;
        segment = self._get_source_segment(nd);
        if segment is None {
            raw_repr = repr(text);
            quote = "'" if raw_repr.startswith("'") else '"';
            segment = f"{quote}{raw_repr[1:-1]}{quote}";
        } else {
            segment = self._strip_string_continuations(segment);
        }
        return String(
            orig_src=self.orig_src,
            name='STRING',
            value=segment,
            line=line,
            end_line=end_line,
            col_start=col,
            col_end=(col + len(text)),
            pos_start=0,
            pos_end=0
        );
    }
    if isinstance(value, PyBytes) {
        spelled = repr(bytes(value.val));
        return String(
            orig_src=self.orig_src,
            name='BYTES',
            value=spelled,
            line=line,
            end_line=end_line,
            col_start=col,
            col_end=(col + len(spelled)),
            pos_start=0,
            pos_end=0
        );
    }
    if isinstance(value, PyBool) {
        spelled = 'True' if value.val else 'False';
        return Bool(
            orig_src=self.orig_src,
            name='BOOL',
            value=spelled,
            line=line,
            end_line=end_line,
            col_start=col,
            col_end=(col + len(spelled)),
            pos_start=0,
            pos_end=0
        );
    }
    if isinstance(value, PyNoneType) {
        return Null(
            orig_src=self.orig_src,
            name=Tok.NULL,
            value='None',
            line=line,
            end_line=end_line,
            col_start=col,
            col_end=(col + 4),
            pos_start=0,
            pos_end=0
        );
    }
    if isinstance(value, (PyInt, PyBigInt)) {
        spelled = integer_decimal(value)
            if isinstance(value, PyBigInt)
            else str(value.val);
        return Int(
            orig_src=self.orig_src,
            name='INT',
            value=spelled,
            line=line,
            end_line=end_line,
            col_start=col,
            col_end=(col + len(spelled)),
            pos_start=0,
            pos_end=0
        );
    }
    if isinstance(value, PyFloat) {
        spelled = repr(value.val);
        return Float(
            orig_src=self.orig_src,
            name='FLOAT',
            value=spelled,
            line=line,
            end_line=end_line,
            col_start=col,
            col_end=(col + len(spelled)),
            pos_start=0,
            pos_end=0
        );
    }
    raise RuntimeError(self.ctx.ice('Invalid type for constant'));
}

impl PyastBuildPass.proc_compare(nd: py_ast.Compare) -> AtomUnit {
    left = self.convert(nd.left);
    comparators = [self.convert(comparator) for comparator in nd.comparators];
    valid_comparators = [
        comparator
        for comparator in comparators
        if isinstance(comparator, Expr)
    ];
    ops = [self.convert(op) for op in nd.ops];
    valid_ops = [
        op
        for op in ops
        if isinstance(op, Token)
    ];
    kids = [left, *valid_ops, *valid_comparators];
    if (
        isinstance(left, Expr)
        and (len(ops) == len(valid_ops))
        and (len(comparators) == len(valid_comparators))
    ) {
        expr = CompareExpr(
            left=left, rights=valid_comparators, ops=valid_ops, kid=kids
        );
        return AtomUnit(
            value=expr,
            kid=[self.operator(Tok.RPAREN, '('), expr, self.operator(Tok.LPAREN, ')')]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_call(nd: py_ast.Call) -> FuncCall {
    func = self.convert(nd.func);
    params_in: list[(Expr | KWPair)] = [];
    args = [self.convert(arg) for arg in nd.args];
    keywords = [self.convert(keyword) for keyword in nd.keywords];
    for i in args {
        if isinstance(i, Expr) {
            params_in.append(i);
        }
    }
    for i in keywords {
        if isinstance(i, KWPair) {
            params_in.append(i);
        }
    }
    kids = [func, *params_in] if (len(params_in) != 0) else [func];
    if isinstance(func, Expr) {
        return FuncCall(target=func, params=params_in, genai_call=None, kid=kids);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_break(nd: py_ast.Break) -> CtrlStmt {
    break_tok = Token(
        orig_src=self.orig_src,
        name=Tok.KW_BREAK,
        value='break',
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
    return CtrlStmt(ctrl=break_tok, kid=[break_tok]);
}

impl PyastBuildPass.proc_bool_op(nd: py_ast.BoolOp) -> AtomUnit {
    op = self.convert(nd.op);
    values = [self.convert(value) for value in nd.values];
    valid = [
        value
        for value in values
        if isinstance(value, Expr)
    ];
    if (isinstance(op, Token) and (len(valid) == len(values))) {
        cfg_vals = [CfgExpr(expr=v, kid=[v]) for v in valid];
        expr = BoolExpr(op=op, values=cfg_vals, kid=[op, *cfg_vals]);
        return AtomUnit(
            value=expr,
            kid=[self.operator(Tok.RPAREN, '('), expr, self.operator(Tok.LPAREN, ')')]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_unary_op(nd: py_ast.UnaryOp) -> UnaryExpr {
    op = self.convert(nd.op);
    operand = self.convert(nd.operand);
    if (isinstance(op, Token) and isinstance(operand, Expr)) {
        return UnaryExpr(op=op, operand=operand, kid=[op, operand]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_bin_op(nd: py_ast.BinOp) -> (AtomUnit | BinaryExpr) {
    left = self.convert(nd.left);
    op = self.convert(nd.op);
    right = self.convert(nd.right);
    if (isinstance(left, Expr) and isinstance(op, Token) and isinstance(right, Expr)) {
        unwrapped_left = left;
        if (
            isinstance(left, AtomUnit)
            and isinstance(left.value, BinaryExpr)
            and isinstance(left.value.op, Token)
            and (left.value.op.value == op.value)
        ) {
            unwrapped_left = left.value;
        }
        value = BinaryExpr(
            left=unwrapped_left, op=op, right=right, kid=[unwrapped_left, op, right]
        );
        return AtomUnit(
            value=value,
            kid=[self.operator(Tok.RPAREN, '('), value, self.operator(Tok.LPAREN, ')')]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_await(nd: py_ast.Await) -> AwaitExpr {
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return AwaitExpr(target=value, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_attribute(nd: py_ast.Attribute) -> AtomTrailer {
    value = self.convert(nd.value);
    if (
        isinstance(value, FuncCall)
        and isinstance(value.target, Name)
        and (value.target.value == 'super')
    ) {
        tok = self.name_node(nd, 'super', name_tok=Tok.KW_SUPER);
        value = SpecialVarRef(var=tok);
    }
    attribute = self.name_node(
        nd,
        'init' if (nd.attr == '__init__') else nd.attr,
        name_tok=Tok.KW_INIT if (nd.attr == '__init__') else Tok.NAME,
        col_end=(nd.col_offset + len(nd.attr)),
        is_kwesc=(nd.attr == 'init')
    );
    if isinstance(value, Expr) {
        return AtomTrailer(
            target=value,
            right=attribute,
            is_attr=True,
            is_null_ok=False,
            kid=[value, attribute]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_assert(nd: py_ast.Assert) -> AssertStmt {
    `test = self.convert(nd.`test);
    msg = self.convert(nd.msg) if nd.msg else None;
    if (isinstance(`test, Expr) and (isinstance(msg, Expr) or (msg is None))) {
        kid: list[UniNode] = [`test];
        if msg is not None {
            kid.append(msg);
        }
        return AssertStmt(condition=`test, error_msg=msg, kid=kid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_raise(nd: py_ast.Raise) -> RaiseStmt {
    exc = self.convert(nd.exc) if nd.exc else None;
    cause = self.convert(nd.cause) if nd.cause else None;
    kid: list[(Expr | Token)] = [];
    if isinstance(exc, Expr) {
        kid = [exc];
    }
    if isinstance(cause, Expr) {
        kid.append(cause);
    }
    if not (exc and cause) {
        kid.append(self.operator(Tok.KW_RAISE, 'raise'));
    }
    if (
        (isinstance(cause, Expr) or (cause is None))
        and (isinstance(exc, Expr) or (exc is None))
    ) {
        if (isinstance(exc, Expr) and not nd.cause) {
            return RaiseStmt(
                cause=exc,
                from_target=None,
                kid=[self.operator(Tok.KW_RAISE, 'raise'), exc]
            );
        } else {
            return RaiseStmt(cause=cause, from_target=exc, kid=kid);
        }
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_async_with(nd: py_ast.AsyncWith) -> WithStmt {
    items = [self.convert(item) for item in nd.items];
    valid_items = [
        item
        for item in items
        if isinstance(item, ExprAsItem)
    ];
    if (len(valid_items) != len(items)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in with items'));
    }
    body = [self.convert(stmt) for stmt in nd.body];
    valid_body = [
        stmt
        for stmt in body
        if isinstance(stmt, CodeBlockStmt)
    ];
    if (len(valid_body) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in async for body'));
    }
    return WithStmt(
        is_async=True,
        exprs=valid_items,
        body=valid_body,
        kid=[*valid_items, *valid_body]
    );
}

impl PyastBuildPass.proc_with(nd: py_ast.With) -> WithStmt {
    items = [self.convert(item) for item in nd.items];
    valid_items = [
        item
        for item in items
        if isinstance(item, ExprAsItem)
    ];
    if (len(valid_items) != len(items)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in with items'));
    }
    body = [self.convert(stmt) for stmt in nd.body];
    valid_body = [
        stmt
        for stmt in body
        if isinstance(stmt, CodeBlockStmt)
    ];
    if (len(valid_body) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in async for body'));
    }
    return WithStmt(
        is_async=False,
        exprs=valid_items,
        body=valid_body,
        kid=[*valid_items, *valid_body]
    );
}

impl PyastBuildPass.proc_if(nd: py_ast.If) -> IfStmt {
    `test = self.convert(nd.`test);
    body = [self.convert(stmt) for stmt in nd.body];
    valid_body = [
        stmt
        for stmt in body
        if isinstance(stmt, CodeBlockStmt)
    ];
    if (len(valid_body) != len(body)) {
        self.ctx.emit(E5042);
    }
    body2 = valid_body;
    orelse = [self.convert(stmt) for stmt in nd.orelse];
    valid_orelse = [
        stmt
        for stmt in orelse
        if isinstance(stmt, CodeBlockStmt)
    ];
    if valid_orelse {
        first_elm = valid_orelse[0];
        if (isinstance(first_elm, IfStmt) and (len(valid_orelse) == 1)) {
            else_body: ElseIf | ElseStmt | None = ElseIf(
                condition=first_elm.condition,
                body=first_elm.body,
                else_body=first_elm.else_body,
                kid=[first_elm->:Kid:->]
            );
        } else {
            else_body = ElseStmt(body=valid_orelse, kid=valid_orelse);
        }
    } else {
        else_body = None;
    }
    if isinstance(`test, Expr) {
        kid: list[UniNode] = [`test, *body2];
        if else_body is not None {
            kid.append(else_body);
        }
        ret = IfStmt(condition=`test, body=body2, else_body=else_body, kid=kid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
    return ret;
}

impl PyastBuildPass.proc_while(nd: py_ast.While) -> WhileStmt {
    `test = self.convert(nd.`test);
    body = [self.convert(stmt) for stmt in nd.body];
    valid_body = [
        stmt
        for stmt in body
        if isinstance(stmt, CodeBlockStmt)
    ];
    if (len(valid_body) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in while body'));
    }
    orelse = [self.convert(i) for i in nd.orelse];
    val_orelse = [
        i
        for i in orelse
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_orelse) != len(orelse)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in for orelse'));
    }
    fin_orelse = ElseStmt(body=val_orelse, kid=val_orelse) if orelse else None;
    if isinstance(`test, Expr) {
        return WhileStmt(
            condition=`test,
            body=valid_body,
            else_body=fin_orelse,
            kid=[`test, *valid_body]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_async_for(nd: py_ast.AsyncFor) -> InForStmt {
    target = self.convert(nd.target);
    iter = self.convert(nd.iter);
    body = [self.convert(i) for i in nd.body];
    val_body = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_body) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in for body'));
    }
    valid_body = val_body;
    orelse = [self.convert(i) for i in nd.orelse];
    val_orelse = [
        i
        for i in orelse
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_orelse) != len(orelse)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in for orelse'));
    }
    fin_orelse = ElseStmt(body=val_orelse, kid=val_orelse) if orelse else None;
    if (isinstance(target, Expr) and isinstance(iter, Expr)) {
        return InForStmt(
            target=target,
            is_async=True,
            collection=iter,
            body=valid_body,
            else_body=fin_orelse,
            kid=[target, iter, *valid_body, fin_orelse]
                if fin_orelse
                else [target, iter, *valid_body]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_for(nd: py_ast.For) -> InForStmt {
    target = self.convert(nd.target);
    iter = self.convert(nd.iter);
    body = [self.convert(i) for i in nd.body];
    val_body = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_body) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in for body'));
    }
    valid_body = val_body;
    orelse = [self.convert(i) for i in nd.orelse];
    val_orelse = [
        i
        for i in orelse
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_orelse) != len(orelse)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in for orelse'));
    }
    fin_orelse = ElseStmt(body=val_orelse, kid=val_orelse) if orelse else None;
    if (isinstance(target, Expr) and isinstance(iter, Expr)) {
        return InForStmt(
            target=target,
            is_async=False,
            collection=iter,
            body=valid_body,
            else_body=fin_orelse,
            kid=[target, iter, *valid_body, fin_orelse]
                if fin_orelse
                else [target, iter, *valid_body]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_ann_assign(nd: py_ast.AnnAssign) -> Assignment {
    target = self.convert(nd.target);
    self.in_type_annotation = True;
    annotation = self.convert(nd.annotation);
    self.in_type_annotation = False;
    if isinstance(annotation, Expr) {
        annotation_subtag = SubTag[Expr](tag=annotation, kid=[annotation]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
    value = self.convert(nd.value) if nd.value else None;
    if (
        (isinstance(value, (Expr, YieldExpr)) or not value)
        and isinstance(annotation, Expr)
        and isinstance(target, Expr)
    ) {
        assign_value = value if isinstance(value, (Expr, YieldExpr)) else None;
        kid: list[UniNode] = [target, annotation_subtag];
        if assign_value is not None {
            kid.append(assign_value);
        }
        return Assignment(
            target=[target],
            value=assign_value,
            type_tag=annotation_subtag,
            mutable=False,
            kid=kid
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_aug_assign(nd: py_ast.AugAssign) -> Assignment {
    target = self.convert(nd.target);
    op = self.convert(nd.op);
    if isinstance(op, Token) {
        op.name = self.aug_op_map(TOKEN_MAP, op);
    }
    value = self.convert(nd.value);
    if (
        isinstance(value, Expr) and isinstance(target, Expr) and isinstance(op, Token)
    ) {
        return Assignment(
            target=[target],
            type_tag=None,
            mutable=False,
            aug_op=op,
            value=value,
            kid=[target, op, value]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_assign(nd: py_ast.Assign) -> Assignment {
    value = self.convert(nd.value);
    targets = [self.convert(target) for target in nd.targets];
    valid = [
        target
        for target in targets
        if isinstance(target, Expr)
    ];
    if not (len(valid) == len(targets)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in assignment targets'));
    }
    if isinstance(value, Expr) {
        return Assignment(
            target=valid, value=value, type_tag=None, mutable=False, kid=[*valid, value]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_delete(nd: py_ast.Delete) -> DeleteStmt {
    exprs = [self.convert(target) for target in nd.targets];
    valid_exprs = [
        expr
        for expr in exprs
        if isinstance(expr, Expr)
    ];
    if (not len(valid_exprs) or (len(valid_exprs) != len(exprs))) {
        raise RuntimeError(self.ctx.ice('Length mismatch in delete targets'));
    }
    return DeleteStmt(targets=valid_exprs, kid=[*valid_exprs]);
}

impl PyastBuildPass.proc_return(nd: py_ast.Return) -> (ReturnStmt | None) {
    value = self.convert(nd.value) if nd.value else None;
    if not value {
        return ReturnStmt(expr=None, kid=[self.operator(Tok.KW_RETURN, 'return')]);
    } elif (value and isinstance(value, Expr)) {
        return ReturnStmt(expr=value, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice('Invalid return value'));
    }
}

impl PyastBuildPass.proc_class_def(nd: py_ast.ClassDef) -> (Archetype | Enum) {
    name = self.name_node(nd, nd.name);
    arch_type = Token(
        orig_src=self.orig_src,
        name=Tok.KW_CLASS,
        value='class',
        line=nd.lineno,
        end_line=nd.end_lineno or nd.lineno,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
    body = [self.convert(i) for i in nd.body];
    for body_stmt in body {
        if (
            isinstance(body_stmt, Ability)
            and isinstance(body_stmt.name_ref, Name)
            and (body_stmt.name_ref.value == '__init__')
        ) {
            tok = self.name_node(nd, 'init', name_tok=Tok.KW_INIT);
            body_stmt._role_set(NameRefRole, SpecialVarRef(var=tok));
        }

        if (
            isinstance(body_stmt, Ability)
            and body_stmt.signature
            and isinstance(body_stmt.signature, FuncSignature)
            and body_stmt.signature.params
        ) {
            for param in body_stmt.signature.params {
                if (
                    (param.name.value == 'self')
                    and param.type_tag
                    and isinstance(param.type_tag.tag, Name)
                ) {
                    param.type_tag.tag.value = name.value;
                }
            }
        }
    }
    doc = body[0].expr
        if (body and isinstance(body[0], ExprStmt) and isinstance(body[0].expr, String))
        else None;
    self.convert_to_doc(doc) if doc else None;
    body = body[1:] if doc else body;
    valid: list[ArchBlockStmt] = self.extract_with_entry(body, ArchBlockStmt)
        if (body and not (isinstance(body[0], Semi) and (len(body) == 1)))
        else [];
    empty_block: Sequence[UniNode] = [
        self.operator(Tok.LBRACE, '{'),
        self.operator(Tok.RBRACE, '}')
    ];
    valid_body = valid or empty_block;
    converted_base_classes = [self.convert(base) for base in nd.bases];
    base_classes: list[Expr] = [
        base
        for base in converted_base_classes
        if isinstance(base, Expr)
    ];
    converted_keywords = [self.convert(kw) for kw in nd.keywords];
    keywords: list[KWPair] = [
        kw
        for kw in converted_keywords
        if isinstance(kw, KWPair)
    ];
    converted_decorators_list = [self.convert(i) for i in nd.decorator_list];
    decorators = [
        i
        for i in converted_decorators_list
        if isinstance(i, Expr)
    ];
    if (len(decorators) != len(converted_decorators_list)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in decorators on class'));
    }
    valid_decorators = decorators or None;
    kid: list[UniNode] = [];
    if valid_decorators {
        kid.extend(valid_decorators);
    }
    kid.append(arch_type);
    kid.append(name);
    kid.extend(base_classes);
    kid.extend(keywords);
    kid.extend(valid_body);
    if doc {
        kid.append(doc);
    }
    return Archetype(
        arch_type=arch_type,
        name=name,
        access=None,
        base_classes=base_classes,
        keywords=keywords,
        body=valid,
        kid=kid,
        doc=doc,
        decorators=valid_decorators
    );
}

impl PyastBuildPass.proc_async_function_def(nd: py_ast.AsyncFunctionDef) -> Ability {
    ability = self.proc_function_def(nd);
    ability.is_async = True;
    return ability;
}

impl PyastBuildPass.proc_function_def(
    nd: (py_ast.FunctionDef | py_ast.AsyncFunctionDef)
) -> Ability {
    name = self.name_node(nd, nd.name, is_kwesc=(nd.name in _reserved_keywords));
    body = [self.convert(i) for i in nd.body];
    valid = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(valid) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in function body'));
    }
    doc: (String | None) = None;
    if (
        len(valid)
        and isinstance(valid[0], ExprStmt)
        and isinstance(valid[0].expr, String)
    ) {
        self.convert_to_doc(valid[0].expr);
        doc = valid[0].expr;
        valid_body = valid[1:];
    } else {
        doc = None;
        valid_body = valid;
    }
    decorators = [self.convert(i) for i in nd.decorator_list];
    valid_dec = [
        i
        for i in decorators
        if isinstance(i, Expr)
    ];
    if (len(valid_dec) != len(decorators)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in decorators on function'));
    }
    valid_decorators = valid_dec or None;
    res = self.convert(nd.args);
    sig: (FuncSignature | None) = res if isinstance(res, FuncSignature) else None;
    self.in_type_annotation = True;
    ret_sig = self.convert(nd.returns) if nd.returns else None;
    if ret_sig is None {
        ret_sig = self.name_node(
            nd, 'object', col_end=nd.col_offset, end_line=nd.lineno
        );
    }
    self.in_type_annotation = False;
    if isinstance(ret_sig, Expr) {
        if not sig {
            sig = FuncSignature(
                posonly_params=[],
                params=[],
                varargs=None,
                kwonlyargs=[],
                kwargs=None,
                return_type=ret_sig,
                kid=[ret_sig]
            );
        } else {
            sig.add_kids_right([ret_sig], role=ReturnTypeRole);
        }
    }
    if not sig {
        raise RuntimeError(self.ctx.ice('Function signature not found'));
    }
    kid = [];
    if doc {
        kid.append(doc);
    }
    if valid_decorators {
        kid.extend(valid_decorators);
    }
    kid.append(name);
    kid.append(sig);
    kid.extend(valid_body);
    ret = Ability(
        name_ref=name,
        is_async=False,
        is_static=False,
        is_classmethod=False,
        is_abstract=False,
        is_override=False,
        access=None,
        signature=sig,
        body=valid_body,
        decorators=valid_decorators,
        doc=doc,
        kid=kid
    );
    return ret;
}

impl PyastBuildPass.proc_template_str(nd: py_ast.TemplateStr) -> UniNode {
    raise RuntimeError(
        self.ctx.ice("Python 3.14 t-strings (PEP 750) are not supported in Jac")
    );
}

impl PyastBuildPass.proc_interpolation(nd: py_ast.Interpolation) -> UniNode {
    raise RuntimeError(
        self.ctx.ice("Python 3.14 t-string interpolations are not supported in Jac")
    );
}

impl PyastBuildPass.proc_module(nd: py_ast.Module) -> Module {
    if not nd.body {
        stub = Module.make_stub(inject_src=self.orig_src);
        stub.set_kids(nodes=[EmptyToken(orig_src=self.orig_src)]);
        return stub;
    }
    elements: list[UniNode] = [self.convert(i) for i in nd.body];
    elements[0] = elements[0].expr
        if (isinstance(elements[0], ExprStmt) and isinstance(elements[0].expr, String))
        else elements[0];
    doc_str_list = [elements[0]] if isinstance(elements[0], String) else [];
    top_level: tuple[type[ElementStmt], type[EmptyToken]] = (ElementStmt, EmptyToken);
    valid = (doc_str_list + self.extract_with_entry(elements[1:], top_level))
        if doc_str_list
        else self.extract_with_entry(elements[:], top_level);
    doc_str = elements[0] if isinstance(elements[0], String) else None;
    self.convert_to_doc(doc_str) if doc_str else None;
    ret = Module(
        name=self.mod_path.split(os.path.sep)[-1].split('.')[0],
        source=Source('', mod_path=self.mod_path),
        doc=doc_str,
        body=valid[1:] if (valid and isinstance(valid[0], String)) else valid,
        terminals=[],
        kid=valid
    );
    ret.is_raised_from_py = True;
    return self.nu(ret);
}

impl PyastBuildPass.extract_with_entry(
    body: list[UniNode], exclude_types: TypeAlias = T
) -> list[(T | ModuleCode)] {
    def gen_mod_code(with_entry_body: list[CodeBlockStmt]) -> ModuleCode {
        return ModuleCode(
            name=None, body=with_entry_body, kid=with_entry_body, doc=None
        );
    }
    extracted: list[(T | ModuleCode)] = [];
    with_entry_body: list[CodeBlockStmt] = [];
    for i in body {
        if isinstance(i, exclude_types)
            and not (isinstance(i, AssertStmt) and not i.is_comptime) {
            if len(with_entry_body) {
                extracted.append(gen_mod_code(with_entry_body));
                with_entry_body = [];
            }
            extracted.append(i);
        } elif isinstance(i, CodeBlockStmt) {
            if (isinstance(i, ExprStmt) and isinstance(i.expr, String)) {
                self.convert_to_doc(i.expr);
            }
            with_entry_body.append(i);
        } else {
            continue;
        }
    }
    if len(with_entry_body) {
        extracted.append(gen_mod_code(with_entry_body));
    }
    return extracted;
}

impl PyastBuildPass._run_impl(ir_in: PythonModuleAst) -> Module {
    self.module = self.proc_module(ir_in.ast);
    return self.module;
}

impl PyastBuildPass.convert(nd: py_ast.ast_node) -> UniNode {
    if self.is_canceled() {
        raise StopIteration;
    }
    kind = nd.node_kind();
    match kind {
        case py_ast.ast_kind.Module:
            return self.proc_module(nd as py_ast.Module);
        case py_ast.ast_kind.Interactive:
            return self.proc_interactive(nd as py_ast.Interactive);
        case py_ast.ast_kind.FunctionType:
            return self.proc_function_type(nd as py_ast.FunctionType);
        case py_ast.ast_kind.FunctionDef:
            return self.proc_function_def(nd as py_ast.FunctionDef);
        case py_ast.ast_kind.AsyncFunctionDef:
            return self.proc_async_function_def(nd as py_ast.AsyncFunctionDef);
        case py_ast.ast_kind.ClassDef:
            return self.proc_class_def(nd as py_ast.ClassDef);
        case py_ast.ast_kind.Return:
            return self.proc_return(nd as py_ast.Return);
        case py_ast.ast_kind.Delete:
            return self.proc_delete(nd as py_ast.Delete);
        case py_ast.ast_kind.Assign:
            return self.proc_assign(nd as py_ast.Assign);
        case py_ast.ast_kind.TypeAlias:
            return self.proc_type_alias(nd as py_ast.TypeAlias);
        case py_ast.ast_kind.AugAssign:
            return self.proc_aug_assign(nd as py_ast.AugAssign);
        case py_ast.ast_kind.AnnAssign:
            return self.proc_ann_assign(nd as py_ast.AnnAssign);
        case py_ast.ast_kind.For:
            return self.proc_for(nd as py_ast.For);
        case py_ast.ast_kind.AsyncFor:
            return self.proc_async_for(nd as py_ast.AsyncFor);
        case py_ast.ast_kind.While:
            return self.proc_while(nd as py_ast.While);
        case py_ast.ast_kind.If:
            return self.proc_if(nd as py_ast.If);
        case py_ast.ast_kind.With:
            return self.proc_with(nd as py_ast.With);
        case py_ast.ast_kind.AsyncWith:
            return self.proc_async_with(nd as py_ast.AsyncWith);
        case py_ast.ast_kind.Match:
            return self.proc_match(nd as py_ast.Match);
        case py_ast.ast_kind.Raise:
            return self.proc_raise(nd as py_ast.Raise);
        case py_ast.ast_kind.Try:
            return self.proc_try(nd as py_ast.Try);
        case py_ast.ast_kind.TryStar:
            return self.proc_try_star(nd as py_ast.TryStar);
        case py_ast.ast_kind.Assert:
            return self.proc_assert(nd as py_ast.Assert);
        case py_ast.ast_kind.Import:
            return self.proc_import(nd as py_ast.Import);
        case py_ast.ast_kind.ImportFrom:
            return self.proc_import_from(nd as py_ast.ImportFrom);
        case py_ast.ast_kind.Global:
            return self.proc_global(nd as py_ast.Global);
        case py_ast.ast_kind.Nonlocal:
            return self.proc_nonlocal(nd as py_ast.Nonlocal);
        case py_ast.ast_kind.Expr:
            return self.proc_expr(nd as py_ast.Expr);
        case py_ast.ast_kind.Pass:
            return self.proc_pass(nd as py_ast.Pass);
        case py_ast.ast_kind.Break:
            return self.proc_break(nd as py_ast.Break);
        case py_ast.ast_kind.Continue:
            return self.proc_continue(nd as py_ast.Continue);
        case py_ast.ast_kind.BoolOp:
            return self.proc_bool_op(nd as py_ast.BoolOp);
        case py_ast.ast_kind.NamedExpr:
            return self.proc_named_expr(nd as py_ast.NamedExpr);
        case py_ast.ast_kind.BinOp:
            return self.proc_bin_op(nd as py_ast.BinOp);
        case py_ast.ast_kind.UnaryOp:
            return self.proc_unary_op(nd as py_ast.UnaryOp);
        case py_ast.ast_kind.Lambda:
            return self.proc_lambda(nd as py_ast.Lambda);
        case py_ast.ast_kind.IfExp:
            return self.proc_if_exp(nd as py_ast.IfExp);
        case py_ast.ast_kind.Dict:
            return self.proc_dict(nd as py_ast.Dict);
        case py_ast.ast_kind.Set:
            return self.proc_set(nd as py_ast.Set);
        case py_ast.ast_kind.ListComp:
            return self.proc_list_comp(nd as py_ast.ListComp);
        case py_ast.ast_kind.SetComp:
            return self.proc_set_comp(nd as py_ast.SetComp);
        case py_ast.ast_kind.DictComp:
            return self.proc_dict_comp(nd as py_ast.DictComp);
        case py_ast.ast_kind.GeneratorExp:
            return self.proc_generator_exp(nd as py_ast.GeneratorExp);
        case py_ast.ast_kind.Await:
            return self.proc_await(nd as py_ast.Await);
        case py_ast.ast_kind.Yield:
            return self.proc_yield(nd as py_ast.Yield);
        case py_ast.ast_kind.YieldFrom:
            return self.proc_yield_from(nd as py_ast.YieldFrom);
        case py_ast.ast_kind.Compare:
            return self.proc_compare(nd as py_ast.Compare);
        case py_ast.ast_kind.Call:
            return self.proc_call(nd as py_ast.Call);
        case py_ast.ast_kind.FormattedValue:
            return self.proc_formatted_value(nd as py_ast.FormattedValue);
        case py_ast.ast_kind.Interpolation:
            return self.proc_interpolation(nd as py_ast.Interpolation);
        case py_ast.ast_kind.JoinedStr:
            return self.proc_joined_str(nd as py_ast.JoinedStr);
        case py_ast.ast_kind.TemplateStr:
            return self.proc_template_str(nd as py_ast.TemplateStr);
        case py_ast.ast_kind.Constant:
            return self.proc_constant(nd as py_ast.Constant);
        case py_ast.ast_kind.Attribute:
            return self.proc_attribute(nd as py_ast.Attribute);
        case py_ast.ast_kind.Subscript:
            return self.proc_subscript(nd as py_ast.Subscript);
        case py_ast.ast_kind.Starred:
            return self.proc_starred(nd as py_ast.Starred);
        case py_ast.ast_kind.Name:
            return self.proc_name(nd as py_ast.Name);
        case py_ast.ast_kind.List:
            return self.proc_list(nd as py_ast.List);
        case py_ast.ast_kind.Tuple:
            return self.proc_tuple(nd as py_ast.Tuple);
        case py_ast.ast_kind.Slice:
            return self.proc_slice(nd as py_ast.Slice);
        case py_ast.ast_kind.And:
            return self.proc_and(nd as py_ast.And);
        case py_ast.ast_kind.Or:
            return self.proc_or(nd as py_ast.Or);
        case py_ast.ast_kind.Add:
            return self.proc_add(nd as py_ast.Add);
        case py_ast.ast_kind.Sub:
            return self.proc_sub(nd as py_ast.Sub);
        case py_ast.ast_kind.Mult:
            return self.proc_mult(nd as py_ast.Mult);
        case py_ast.ast_kind.MatMult:
            return self.proc_mat_mult(nd as py_ast.MatMult);
        case py_ast.ast_kind.Div:
            return self.proc_div(nd as py_ast.Div);
        case py_ast.ast_kind.Mod:
            return self.proc_mod(nd as py_ast.Mod);
        case py_ast.ast_kind.Pow:
            return self.proc_pow(nd as py_ast.Pow);
        case py_ast.ast_kind.LShift:
            return self.proc_l_shift(nd as py_ast.LShift);
        case py_ast.ast_kind.RShift:
            return self.proc_r_shift(nd as py_ast.RShift);
        case py_ast.ast_kind.BitOr:
            return self.proc_bit_or(nd as py_ast.BitOr);
        case py_ast.ast_kind.BitXor:
            return self.proc_bit_xor(nd as py_ast.BitXor);
        case py_ast.ast_kind.BitAnd:
            return self.proc_bit_and(nd as py_ast.BitAnd);
        case py_ast.ast_kind.FloorDiv:
            return self.proc_floor_div(nd as py_ast.FloorDiv);
        case py_ast.ast_kind.Invert:
            return self.proc_invert(nd as py_ast.Invert);
        case py_ast.ast_kind.Not:
            return self.proc_not(nd as py_ast.Not);
        case py_ast.ast_kind.UAdd:
            return self.proc_u_add(nd as py_ast.UAdd);
        case py_ast.ast_kind.USub:
            return self.proc_u_sub(nd as py_ast.USub);
        case py_ast.ast_kind.Eq:
            return self.proc_eq(nd as py_ast.Eq);
        case py_ast.ast_kind.NotEq:
            return self.proc_not_eq(nd as py_ast.NotEq);
        case py_ast.ast_kind.Lt:
            return self.proc_lt(nd as py_ast.Lt);
        case py_ast.ast_kind.LtE:
            return self.proc_lt_e(nd as py_ast.LtE);
        case py_ast.ast_kind.Gt:
            return self.proc_gt(nd as py_ast.Gt);
        case py_ast.ast_kind.GtE:
            return self.proc_gt_e(nd as py_ast.GtE);
        case py_ast.ast_kind.Is:
            return self.proc_is(nd as py_ast.Is);
        case py_ast.ast_kind.IsNot:
            return self.proc_is_not(nd as py_ast.IsNot);
        case py_ast.ast_kind.In:
            return self.proc_in(nd as py_ast.In);
        case py_ast.ast_kind.NotIn:
            return self.proc_not_in(nd as py_ast.NotIn);
        case py_ast.ast_kind.comprehension:
            return self.proc_comprehension(nd as py_ast.comprehension);
        case py_ast.ast_kind.ExceptHandler:
            return self.proc_except_handler(nd as py_ast.ExceptHandler);
        case py_ast.ast_kind.arguments:
            return self.proc_arguments(nd as py_ast.arguments);
        case py_ast.ast_kind.arg:
            return self.proc_arg(nd as py_ast.arg);
        case py_ast.ast_kind.keyword:
            return self.proc_keyword(nd as py_ast.keyword);
        case py_ast.ast_kind.alias:
            return self.proc_alias(nd as py_ast.alias);
        case py_ast.ast_kind.withitem:
            return self.proc_withitem(nd as py_ast.withitem);
        case py_ast.ast_kind.match_case:
            return self.proc_match_case(nd as py_ast.match_case);
        case py_ast.ast_kind.MatchValue:
            return self.proc_match_value(nd as py_ast.MatchValue);
        case py_ast.ast_kind.MatchSingleton:
            return self.proc_match_singleton(nd as py_ast.MatchSingleton);
        case py_ast.ast_kind.MatchSequence:
            return self.proc_match_sequence(nd as py_ast.MatchSequence);
        case py_ast.ast_kind.MatchMapping:
            return self.proc_match_mapping(nd as py_ast.MatchMapping);
        case py_ast.ast_kind.MatchClass:
            return self.proc_match_class(nd as py_ast.MatchClass);
        case py_ast.ast_kind.MatchStar:
            return self.proc_match_star(nd as py_ast.MatchStar);
        case py_ast.ast_kind.MatchAs:
            return self.proc_match_as(nd as py_ast.MatchAs);
        case py_ast.ast_kind.MatchOr:
            return self.proc_match_or(nd as py_ast.MatchOr);
        case py_ast.ast_kind.TypeVar:
            return self.proc_type_var(nd as py_ast.TypeVar);
        case py_ast.ast_kind.ParamSpec:
            return self.proc_param_spec(nd as py_ast.ParamSpec);
        case py_ast.ast_kind.TypeVarTuple:
            return self.proc_type_var_tuple(nd as py_ast.TypeVarTuple);
        case _:
            raise RuntimeError(self.ctx.ice(f"Unknown node kind {kind.name}"));
    }
}

impl PyastBuildPass.nu(nd: T) -> T {
    self.ctx.current_node = nd;
    return nd;
}

impl PyastBuildPass.name_node(
    nd: PyPositioned,
    value: str,
    name_tok: Tok = Tok.NAME,
    col_end: int = -1,
    col_start: int = -1,
    end_line: int = -1,
    is_kwesc: bool = False
) -> Name {
    return Name(
        orig_src=self.orig_src,
        name=name_tok,
        value=value,
        line=nd.lineno,
        end_line=(nd.end_lineno or nd.lineno) if (end_line == -1) else end_line,
        col_start=nd.col_offset if (col_start == -1) else col_start,
        col_end=(nd.col_offset + len(value)) if (col_end == -1) else col_end,
        pos_start=0,
        pos_end=0,
        is_kwesc=is_kwesc
    );
}

impl PyastBuildPass.postinit -> None {
    self.mod_path = self.module.loc.mod_path;
    self.orig_src = self.module.loc.orig_src;

    self._source_lines = self.orig_src.code.splitlines(keepends=True);
    self.in_type_annotation = False;
    self.in_match_pattern = False;
    self.in_fstring_expr = False;
}

impl PyastBuildPass._get_source_segment(nd: py_ast.expr) -> (str | None) {
    if (nd.end_lineno is None or nd.end_col_offset is None or nd.lineno < 1) {
        return None;
    }
    lineno = nd.lineno - 1;
    end_lineno = nd.end_lineno - 1;
    col_offset = nd.col_offset;
    end_col_offset = nd.end_col_offset;
    lines = self._source_lines;
    if (end_lineno >= len(lines)) {
        return None;
    }
    if (end_lineno == lineno) {
        return lines[lineno].encode()[col_offset:end_col_offset].decode();
    }
    first = lines[lineno].encode()[col_offset:].decode();
    last = lines[end_lineno].encode()[:end_col_offset].decode();
    middle = lines[lineno + 1:end_lineno];
    result_lines = [first] + middle + [last];
    return ''.join(result_lines);
}

impl PyastBuildPass._strip_string_continuations(seg: str) -> str {
    if not ('\\' in seg and '\n' in seg) {
        return seg;
    }
    out: list[str] = [];
    i = 0;
    n = len(seg);
    quote = '';
    triple = False;
    while (i < n) {
        c = seg[i];
        if quote {
            if (c == '\\') {
                out.append(seg[i:i + 2]);
                i += 2;
                continue;
            }
            if (triple and seg[i:i + 3] == (quote * 3)) {
                out.append(quote * 3);
                quote = '';
                i += 3;
                continue;
            }
            if ((not triple) and c == quote) {
                out.append(c);
                quote = '';
                i += 1;
                continue;
            }
            out.append(c);
            i += 1;
            continue;
        }

        if (c == '\\' and (i + 1) < n and seg[i + 1] in '\r\n') {
            i += 1;
            continue;
        }
        if (c == '"' or c == "'") {
            if (seg[i:i + 3] == (c * 3)) {
                triple = True;
                quote = c;
                out.append(c * 3);
                i += 3;
                continue;
            }
            triple = False;
            quote = c;
            out.append(c);
            i += 1;
            continue;
        }
        out.append(c);
        i += 1;
    }
    return ''.join(out);
}

impl PyastBuildPass.run_walk with PythonModuleAst entry {
    self.module = self._run_impl(here);
}

impl PyastBuildPass.proc_function_type(nd: py_ast.FunctionType) {}

impl PyastBuildPass.proc_interactive(nd: py_ast.Interactive) {}

impl PyastBuildPass.proc_param_spec(nd: py_ast.ParamSpec) {}

impl PyastBuildPass.proc_type_alias(nd: py_ast.TypeAlias) {}

impl PyastBuildPass.proc_type_var(nd: py_ast.TypeVar) {}

impl PyastBuildPass.proc_type_var_tuple(nd: py_ast.TypeVarTuple) {}

impl build_python_module(py_mod: PythonModuleAst) -> Module {
    walk = PyastBuildPass(module=py_mod, ctx=new_context(PyastBuildPass, py_mod));
    walk_pass(walk);
    built = walk.module;
    assert isinstance(built, Module);
    return built;
}

impl python_syntax_alert(failure: syntax_failure, orig_src: Source) -> Alert {
    first_line = failure.lineno if failure.lineno > 0 else 1;
    last_line = failure.end_lineno if failure.end_lineno >= first_line else first_line;
    first_col = failure.offset if failure.offset > 0 else 1;
    last_col = failure.end_offset if failure.end_offset > 0 else first_col + 1;
    span = Span.make(
        orig_src.file_path,
        orig_src.code,
        (first_line, last_line),
        (first_col, last_col),
        (0, 0)
    );
    return Alert(
        msg=E0111.format_message(message=failure.msg),
        loc=span,
        from_pass=PyastBuildPass,
        code=E0111
    );
}

impl parse_python_source(
    source_str: str, file_path: str, program: JacProgram
) -> tuple[Module, bool] {
    orig_src = Source(source_str, mod_path=file_path);
    tree: (py_ast.Module | None) = None;
    try {
        tree = parse_file(source_str, file_path);
    } except syntax_failure as failure {
        program.errors_had.append(python_syntax_alert(failure, orig_src));
        stub = Module.make_stub(inject_src=orig_src);
        stub.set_kids(nodes=[EmptyToken(orig_src=orig_src)]);
        return (stub, True);
    }
    if tree is None {
        raise RuntimeError(f"{file_path}: the Python parser returned no module");
    }
    built = run_utility(
        CompilationProduct.PYTHON_AST,
        PythonModuleAst(tree, orig_src=orig_src),
        program,
        cancel_token=program.options.cancel_token if program.options else None
    );
    return (built.module, len(built.ctx.errors_had) > 0);
}

impl python_top_level_names(path: str) -> set[str] {
    with open(path, encoding="utf-8") as handle {
        source = handle.read();
    }
    tree = parse_file(source, path);
    if tree is None {
        raise RuntimeError(f"{path}: the Python parser returned no module");
    }
    out: set[str] = set();
    for stmt_node in tree.body {
        if isinstance(stmt_node, py_ast.ClassDef) {
            out.add(stmt_node.name);
        } elif isinstance(stmt_node, py_ast.FunctionDef) {
            out.add(stmt_node.name);
        } elif isinstance(stmt_node, py_ast.AsyncFunctionDef) {
            out.add(stmt_node.name);
        } elif isinstance(stmt_node, py_ast.AnnAssign) {
            if isinstance(stmt_node.target, py_ast.Name) {
                out.add(stmt_node.target.id);
            }
        } elif isinstance(stmt_node, py_ast.Assign) {
            for target in stmt_node.targets {
                if not isinstance(target, py_ast.Name) {
                    continue;
                }
                out.add(target.id);
                if target.id != "__all__" {
                    continue;
                }
                listed: list[py_ast.expr] = [];
                if isinstance(stmt_node.value, py_ast.List) {
                    listed = stmt_node.value.elts;
                } elif isinstance(stmt_node.value, py_ast.Tuple) {
                    listed = stmt_node.value.elts;
                }
                for elt in listed {
                    if isinstance(elt, py_ast.Constant) and isinstance(elt.value, PyStr) {
                        out.add(elt.value.val);
                    }
                }
            }
        }
    }
    return out;
}
