impl PyastBuildPass.aug_op_map(tok_dict: dict, op: Token) -> str {
    op.value += '=';
    for (_key, value) in tok_dict.items() {
        if (value == op.value) {
            break;
        }
    }
    return _key;
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
        return ExprAsItem(
            expr=context_expr,
            alias=optional_vars or None,
            kid=[context_expr, optional_vars] if optional_vars else [context_expr]
        );
    } else {
        raise RuntimeError(self.ice());
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
        return MatchCase(
            pattern=pattern,
            guard=guard,
            body=valid,
            kid=[pattern, guard, *valid] if guard else [pattern, *valid]
        );
    } else {
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_keyword(nd: py_ast.keyword) -> KWPair {
    arg = None;
    if nd.arg {
        arg = self.name_node(nd, nd.arg, is_kwesc=(nd.arg in _reserved_keywords));
    }
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return KWPair(key=arg, value=value, kid=[arg, value] if arg else [value]);
    } else {
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_comprehension(nd: py_ast.comprehension) -> InnerCompr {
    target = self.convert(nd.target);
    iter = self.convert(nd.iter);
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
        return InnerCompr(
            is_async=is_async,
            target=target,
            collection=iter,
            conditional=valid,
            kid=[target, iter, *valid] if valid else [target, iter]
        );
    } else {
        raise RuntimeError(self.ice());
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
    def _apply_kind(params: list, kind: ParamKind) -> list {
        for param in params {
            cast(ParamVar, param).param_kind = kind;
        }
        return params;
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
        vararg.unpack = Token(
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
        vararg.add_kids_left([vararg.unpack]);
    }
    kwonlyargs = _apply_kind(
        [self.convert(arg) for arg in nd.kwonlyargs], ParamKind.KWONLY
    );
    for i in range(len(kwonlyargs)) {
        kwa = kwonlyargs[i];
        kwd = nd.kw_defaults[i];
        kwdefault = self.convert(kwd) if kwd else None;

        if (kwdefault and isinstance(kwa, ParamVar) and isinstance(kwdefault, Expr)) {
            kwa.value = kwdefault;
            kwa.add_kids_right([kwa.value]);
        }
    }
    kwarg_node = self.convert(nd.kwarg) if nd.kwarg else None;
    kwarg: (ParamVar | None) = None;
    if (kwarg_node and isinstance(kwarg_node, ParamVar)) {
        kwarg = kwarg_node;
        kwarg.param_kind = ParamKind.KWARG;
        kwarg.unpack = Token(
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
        kwarg.add_kids_left([kwarg.unpack]);
    }
    defaults = [self.convert(expr) for expr in nd.defaults];
    for para in [*posonlyargs, *args][::-1] {
        if not defaults {
            break;
        }
        `default = defaults.pop();

        if (`default and isinstance(para, ParamVar) and isinstance(`default, Expr)) {
            para.value = `default;
            para.add_kids_right([para.value]);
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
        raise RuntimeError(self.ice('Expected annotation to be an expression'));
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
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
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
            raise RuntimeError(self.ice('Length mismatch in tuple elts'));
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
        raise RuntimeError(self.ice('Length mismatch in try body'));
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
            raise RuntimeError(self.ice('Length mismatch in try handlers'));
        }
        excepts = valid_handlers;
        kid.extend(valid_handlers);
    } else {
        excepts = [];
    }
    if (len(nd.orelse) != 0) {
        orelse = [self.convert(i) for i in nd.orelse];
        valid_orelse = [
            i
            for i in orelse
            if isinstance(i, CodeBlockStmt)
        ];
        if (len(orelse) != len(valid_orelse)) {
            raise RuntimeError(self.ice('Length mismatch in try orelse'));
        }
        else_body = valid_orelse;
        elsestmt = ElseStmt(body=else_body, kid=else_body);
        kid.extend(else_body);
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
            raise RuntimeError(self.ice('Length mismatch in try finalbody'));
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
                raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_starred(nd: py_ast.Starred) -> UnaryExpr {
    star_tok = self.operator(Tok.STAR_MUL, '*');
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return UnaryExpr(operand=value, op=star_tok, kid=[value, star_tok]);
    } else {
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass._proc_compr(nd: py_ast.AST, compr_cls: type) -> UniNode {
    elt = self.convert(nd.elt);
    generators = [self.convert(gen) for gen in nd.generators];
    valid = [
        gen
        for gen in generators
        if isinstance(gen, InnerCompr)
    ];
    if (len(generators) != len(valid)) {
        raise RuntimeError(self.ice('Length mismatch in list comp generators'));
    }
    if isinstance(elt, Expr) {
        return compr_cls(out_expr=elt, compr=valid, kid=[elt, *valid]);
    } else {
        raise RuntimeError(self.ice());
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
            raise RuntimeError(self.ice('Length mismatch in set body'));
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

impl PyastBuildPass.proc_pass(nd: py_ast.Pass) -> Semi {
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
    return self.proc_pass(cast(py_ast.Pass, nd));
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
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_match_star(nd: py_ast.MatchStar) -> MatchStar {
    name = self.name_node(nd, nd.name or '_');
    return MatchStar(name=name, is_list=True, kid=[name]);
}

impl PyastBuildPass.proc_match_singleton(nd: py_ast.MatchSingleton) -> MatchSingleton {
    type = Tok.NULL if (nd.value is None) else Tok.BOOL;
    ret_type = Null if (nd.value is None) else Bool;
    value = ret_type(
        orig_src=self.orig_src,
        name=type,
        value=str(nd.value),
        line=nd.lineno,
        end_line=nd.end_lineno or nd.lineno,
        col_start=nd.col_offset,
        col_end=(nd.col_offset + len(str(nd.value))),
        pos_start=0,
        pos_end=0
    );
    if isinstance(value, (Bool, Null)) {
        return MatchSingleton(value=value, kid=[value]);
    } else {
        raise RuntimeError(self.ice());
    }
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
        raise RuntimeError(self.ice());
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
            raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice('Length mismatch in list elements'));
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
        raise RuntimeError(self.ice());
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
        if (isinstance(i, py_ast.Constant) and isinstance(i.value, str)) {
            escaped_value = self._get_source_segment(i);
            if escaped_value is None {
                raw_repr = repr(i.value);
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
                    col_end=(i.col_offset + len(i.value)),
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
            raise RuntimeError(self.ice('Invalid node in joined str'));
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
    moddots = [self.operator(Tok.DOT, '.') for _ in range(nd.level)];
    modparts = moddots + modpaths;
    path = ModulePath(path=modpaths or None, level=nd.level, alias=None, kid=modparts);
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
                    name=name.expr,
                    alias=name.alias or None,
                    kid=[
                        i
                        for i in name.kid
                        if i
                    ]
                )
            );
        } else {
            raise RuntimeError(self.ice());
        }
    }
    items = valid_names;
    if not items {
        raise RuntimeError(self.ice('No valid names in import from'));
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
        self.emit(E5041);
    }
    paths = [];
    for name in valid_names {
        if (
            isinstance(name.expr, Name)
            and (isinstance(name.alias, Name) or (name.alias is None))
        ) {
            paths.append(
                ModulePath(
                    path=[name.expr],
                    level=0,
                    alias=name.alias,
                    kid=[
                        i
                        for i in name.kid
                        if i
                    ]
                )
            );
        } else {
            raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_global(nd: py_ast.Global) -> Semi {
    return self.proc_pass(cast(py_ast.Pass, nd));
}

impl PyastBuildPass.proc_generator_exp(nd: py_ast.GeneratorExp) -> GenCompr {
    return self._proc_compr(nd, GenCompr);
}

impl PyastBuildPass.proc_formatted_value(nd: py_ast.FormattedValue) -> FormattedValue {
    prev_in_fstring = self.in_fstring_expr;
    self.in_fstring_expr = True;
    value = self.convert(nd.value);
    self.in_fstring_expr = prev_in_fstring;

    fmt_spec = None;
    if nd.format_spec {
        if isinstance(nd.format_spec, py_ast.JoinedStr) {
            fmt_parts: list[str] = [];
            for part in nd.format_spec.values {
                if isinstance(part, py_ast.Constant) and isinstance(part.value, str) {
                    fmt_parts.append(part.value);
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
        ret = FormattedValue(
            format_part=value,
            conversion=nd.conversion,
            format_spec=fmt_spec,
            kid=[value, fmt_spec] if fmt_spec else [value]
        );
    } else {
        raise RuntimeError(self.ice());
    }
    return ret;
}

impl PyastBuildPass.proc_expr(nd: py_ast.Expr) -> ExprStmt {
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return ExprStmt(expr=value, in_fstring=False, kid=[value]);
    } else {
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice('Length mismatch in except handler body'));
    }
    kid = [
        item
        for item in [type, name, *valid]
        if item
    ];
    if (isinstance(type, Expr) and (isinstance(name, Name) or not name)) {
        return Except(ex_type=type, name=name, body=valid, kid=kid);
    } else {
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_dict_comp(nd: py_ast.DictComp) -> DictCompr {
    key = self.convert(nd.key);
    value = self.convert(nd.value);
    if (isinstance(key, Expr) and isinstance(value, Expr)) {
        kv_pair = KVPair(key=key, value=value, kid=[key, value]);
    } else {
        raise RuntimeError(self.ice());
    }
    generators = [self.convert(i) for i in nd.generators];
    valid = [
        i
        for i in generators
        if isinstance(i, InnerCompr)
    ];
    if (len(valid) != len(generators)) {
        raise RuntimeError(self.ice('Length mismatch in dict compr generators'));
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
    (ln, col) = self.ctrl_loc(nd);
    continue_tok = Token(
        orig_src=self.orig_src,
        name=Tok.KW_CONTINUE,
        value='continue',
        line=ln,
        end_line=ln,
        col_start=col,
        col_end=col + 8,
        pos_start=0,
        pos_end=8
    );
    return CtrlStmt(ctrl=continue_tok, kid=[continue_tok]);
}

impl PyastBuildPass.ctrl_loc(nd: object) -> tuple[int, int] {
    ln = getattr(nd, "lineno", 0) or 0;
    col = getattr(nd, "col_offset", 0) or 0;
    return (ln, col);
}

impl PyastBuildPass.proc_constant(nd: py_ast.Constant) -> Literal {
    type_mapping = {
        int: Int,
        float: Float,
        str: String,
        bytes: String,
        bool: Bool,
        type(None): Null
    };
    value_type = type(nd.value);
    if (value_type in type_mapping) {
        if (value_type is None) {
            token_type = 'NULL';
        } elif (value_type is str) {
            token_type = 'STRING';
        } else {
            token_type = f"{value_type.__name__.upper()}";
        }
        if (value_type is str) {
            value = self._get_source_segment(nd);
            if value is None {
                raw_repr = repr(nd.value);
                quote = "'" if raw_repr.startswith("'") else '"';
                value = f"{quote}{raw_repr[1:-1]}{quote}";
            } else {
                value = self._strip_string_continuations(value);
            }
        } else {
            value = str(nd.value);
        }
        return type_mapping[value_type](
            orig_src=self.orig_src,
            name=token_type,
            value=value,
            line=nd.lineno,
            end_line=nd.end_lineno or nd.lineno,
            col_start=nd.col_offset,
            col_end=(nd.col_offset + len(str(nd.value))),
            pos_start=0,
            pos_end=0
        );
    } elif (nd.value == Ellipsis) {
        return UniEllipsis(
            orig_src=self.orig_src,
            name=Tok.ELLIPSIS,
            value='...',
            line=nd.lineno,
            end_line=nd.end_lineno or nd.lineno,
            col_start=nd.col_offset,
            col_end=(nd.col_offset + 3),
            pos_start=0,
            pos_end=0
        );
    } else {
        raise RuntimeError(self.ice('Invalid type for constant'));
    }
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
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_break(nd: py_ast.Break) -> CtrlStmt {
    (ln, col) = self.ctrl_loc(nd);
    break_tok = Token(
        orig_src=self.orig_src,
        name=Tok.KW_BREAK,
        value='break',
        line=ln,
        end_line=ln,
        col_start=col,
        col_end=col + 5,
        pos_start=0,
        pos_end=5
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
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_unary_op(nd: py_ast.UnaryOp) -> UnaryExpr {
    op = self.convert(nd.op);
    operand = self.convert(nd.operand);
    if (isinstance(op, Token) and isinstance(operand, Expr)) {
        return UnaryExpr(op=op, operand=operand, kid=[op, operand]);
    } else {
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_await(nd: py_ast.Await) -> AwaitExpr {
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return AwaitExpr(target=value, kid=[value]);
    } else {
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_assert(nd: py_ast.Assert) -> AssertStmt {
    `test = self.convert(nd.`test);
    msg = self.convert(nd.msg) if nd.msg else None;
    if (isinstance(`test, Expr) and (isinstance(msg, Expr) or (msg is None))) {
        return AssertStmt(
            condition=`test, error_msg=msg, kid=[`test, msg] if msg else [`test]
        );
    } else {
        raise RuntimeError(self.ice());
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
        if (exc and not nd.cause) {
            return RaiseStmt(
                cause=exc,
                from_target=None,
                kid=[self.operator(Tok.KW_RAISE, 'raise'), exc]
            );
        } else {
            return RaiseStmt(cause=cause, from_target=exc, kid=kid);
        }
    } else {
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice('Length mismatch in with items'));
    }
    body = [self.convert(stmt) for stmt in nd.body];
    valid_body = [
        stmt
        for stmt in body
        if isinstance(stmt, CodeBlockStmt)
    ];
    if (len(valid_body) != len(body)) {
        raise RuntimeError(self.ice('Length mismatch in async for body'));
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
        raise RuntimeError(self.ice('Length mismatch in with items'));
    }
    body = [self.convert(stmt) for stmt in nd.body];
    valid_body = [
        stmt
        for stmt in body
        if isinstance(stmt, CodeBlockStmt)
    ];
    if (len(valid_body) != len(body)) {
        raise RuntimeError(self.ice('Length mismatch in async for body'));
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
        self.emit(E5042);
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
                kid=first_elm.kid
            );
        } else {
            else_body = ElseStmt(body=valid_orelse, kid=valid_orelse);
        }
    } else {
        else_body = None;
    }
    if isinstance(`test, Expr) {
        ret = IfStmt(
            condition=`test,
            body=body2,
            else_body=else_body,
            kid=[`test, *body2, else_body] if else_body else [`test, *body2]
        );
    } else {
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice('Length mismatch in while body'));
    }
    orelse = [self.convert(i) for i in nd.orelse];
    val_orelse = [
        i
        for i in orelse
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_orelse) != len(orelse)) {
        raise RuntimeError(self.ice('Length mismatch in for orelse'));
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
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice('Length mismatch in for body'));
    }
    valid_body = val_body;
    orelse = [self.convert(i) for i in nd.orelse];
    val_orelse = [
        i
        for i in orelse
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_orelse) != len(orelse)) {
        raise RuntimeError(self.ice('Length mismatch in for orelse'));
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
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice('Length mismatch in for body'));
    }
    valid_body = val_body;
    orelse = [self.convert(i) for i in nd.orelse];
    val_orelse = [
        i
        for i in orelse
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_orelse) != len(orelse)) {
        raise RuntimeError(self.ice('Length mismatch in for orelse'));
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
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice());
    }
    value = self.convert(nd.value) if nd.value else None;
    if (
        (isinstance(value, (Expr, YieldExpr)) or not value)
        and isinstance(annotation, Expr)
        and isinstance(target, Expr)
    ) {
        return Assignment(
            target=[target],
            value=value if isinstance(value, (Expr, YieldExpr)) else None,
            type_tag=annotation_subtag,
            mutable=False,
            kid=[target, annotation_subtag, value]
                if value
                else [target, annotation_subtag]
        );
    } else {
        raise RuntimeError(self.ice());
    }
}

impl PyastBuildPass.proc_aug_assign(nd: py_ast.AugAssign) -> Assignment {
    import from jaclang.jac0core.constant { TOKEN_MAP }
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
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice('Length mismatch in assignment targets'));
    }
    if isinstance(value, Expr) {
        return Assignment(
            target=valid, value=value, type_tag=None, mutable=False, kid=[*valid, value]
        );
    } else {
        raise RuntimeError(self.ice());
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
        raise RuntimeError(self.ice('Length mismatch in delete targets'));
    }
    target_1 = valid_exprs[0]
        if (len(valid_exprs) > 1)
        else TupleVal(values=valid_exprs, kid=[*valid_exprs]);
    return DeleteStmt(target=target_1, kid=[*valid_exprs]);
}

impl PyastBuildPass.proc_return(nd: py_ast.Return) -> (ReturnStmt | None) {
    value = self.convert(nd.value) if nd.value else None;
    if not value {
        return ReturnStmt(expr=None, kid=[self.operator(Tok.KW_RETURN, 'return')]);
    } elif (value and isinstance(value, Expr)) {
        return ReturnStmt(expr=value, kid=[value]);
    } else {
        raise RuntimeError(self.ice('Invalid return value'));
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
            body_stmt.name_ref = SpecialVarRef(var=tok);
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
        raise RuntimeError(self.ice('Length mismatch in decorators on class'));
    }
    valid_decorators = decorators or None;
    kid: list = [];
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
        raise RuntimeError(self.ice('Length mismatch in function body'));
    }
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
        raise RuntimeError(self.ice('Length mismatch in decorators on function'));
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
            sig.return_type = ret_sig;
            sig.add_kids_right([sig.return_type]);
        }
    }
    if not sig {
        raise RuntimeError(self.ice('Function signature not found'));
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

impl PyastBuildPass.proc_template_str(nd: py_ast.AST) -> UniNode {
    raise RuntimeError(
        self.ice("Python 3.14 t-strings (PEP 750) are not supported in Jac")
    );
}

impl PyastBuildPass.proc_interpolation(nd: py_ast.AST) -> UniNode {
    raise RuntimeError(
        self.ice("Python 3.14 t-string interpolations are not supported in Jac")
    );
}

impl PyastBuildPass.proc_module(nd: py_ast.Module) -> Module {
    if not nd.body {
        return Module.make_stub(inject_src=self.ir_in.orig_src);
    }
    elements: list[UniNode] = [self.convert(i) for i in nd.body];
    elements[0] = elements[0].expr
        if (isinstance(elements[0], ExprStmt) and isinstance(elements[0].expr, String))
        else elements[0];
    doc_str_list = [elements[0]] if isinstance(elements[0], String) else [];
    valid = (
        doc_str_list + self.extract_with_entry(elements[1:], (ElementStmt, EmptyToken))
    )
        if doc_str_list
        else self.extract_with_entry(elements[:], (ElementStmt, EmptyToken));
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
        if isinstance(i, exclude_types) {
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

impl PyastBuildPass.transform(ir_in: PythonModuleAst) -> Module {
    self.ir_out: Module = self.proc_module(ir_in.ast);
    return self.ir_out;
}

impl PyastBuildPass.is_canceled -> bool {
    if self.cancel_requested {
        return True;
    }
    return (self.cancel_token is not None) and self.cancel_token.is_set();
}

impl PyastBuildPass.convert(nd: py_ast.AST) -> UniNode {
    import from jaclang.jac0core.helpers { pascal_to_snake }
    if self.is_canceled() {
        raise StopIteration;
    }
    if hasattr(self, f"proc_{pascal_to_snake(type(nd).__name__)}") {
        ret = getattr(self, f"proc_{pascal_to_snake(type(nd).__name__)}")(nd);
    } else {
        raise RuntimeError(self.ice(f"Unknown node type {type(nd).__name__}"));
    }
    return ret;
}

impl PyastBuildPass.nu(nd: T) -> T {
    self.cur_node = nd;
    return nd;
}

impl PyastBuildPass.name_node(
    nd: py_ast.AST,
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
    self.mod_path = self.ir_in.loc.mod_path;
    self.orig_src = self.ir_in.loc.orig_src;

    self._source_lines = self.orig_src.code.splitlines(keepends=True);
    self.in_type_annotation = False;
    self.in_match_pattern = False;
    self.in_fstring_expr = False;
    super.postinit();
}

impl PyastBuildPass._get_source_segment(nd: py_ast.AST) -> (str | None) {
    try {
        if (nd.end_lineno is None or nd.end_col_offset is None) {
            return None;
        }
        lineno = nd.lineno - 1;
        end_lineno = nd.end_lineno - 1;
        col_offset = nd.col_offset;
        end_col_offset = nd.end_col_offset;
    } except AttributeError {
        return None;
    }
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
