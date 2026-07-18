impl CastBuildPass.postinit -> None {
    self.orig_src = self.ir_in.orig_src;
    self.enum_verdicts = build_enum_map(self.ir_in.ast);
    self._list_bound = set();
    self._enum_member_owner = self._build_member_owner_map();
    self._var_types = {};
    self._func_depth = 0;
    super.postinit();
}

impl CastBuildPass._build_member_owner_map -> dict[str, str] {
    owner: dict[str, str] = {};
    enums: list[object] = [];
    self._collect_enum_nodes(self.ir_in.ast, enums);
    for en in enums {
        if self.enum_verdicts.verdicts.get(id(en)) != EnumShape.ENUM_AS_ENUM {
            continue;
        }
        nm_map = self.enum_verdicts.name_map.get(id(en), {});
        for mem in nm_map {
            owner[mem] = en.name or "_AnonEnum";
        }
    }
    return owner;
}

impl CastBuildPass._collect_enum_nodes(nd: object, out: list) -> None {
    if isinstance(nd, c_ast.Enum) {
        out.append(nd);
    }
    for (_, child) in nd.children() {
        self._collect_enum_nodes(child, out);
    }
}

impl CastBuildPass.transform(ir_in: uni.CModuleAst) -> uni.Module {
    self.ir_out = self.proc_file_ast(ir_in.ast);
    return self.ir_out;
}

impl CastBuildPass.nu(nd: uni.UniNode) -> uni.UniNode {
    self.cur_node = nd;
    return nd;
}

impl CastBuildPass.convert(nd: object, *, stmt: bool = False) -> object {
    if self.is_canceled() {
        raise StopIteration;
    }

    if stmt and isinstance(nd, c_ast.UnaryOp) and nd.op in ("p++", "++", "p--", "--") {
        inc = self._inc_dec_stmt(nd);
        if inc is not None {
            return inc;
        }
    }
    tname = type(nd).__name__;
    mname = _CONVERT_OVERRIDE.get(tname) or ("proc_" + pascal_to_snake(tname));
    meth = getattr(self, mname, None);
    if meth is None {
        return self._surrogate_stmt(nd) if stmt else self._surrogate_expr(nd);
    }
    res = meth(nd);
    if stmt and isinstance(res, uni.Expr) {
        return uni.ExprStmt(expr=res, in_fstring=False, kid=[res]);
    }
    return res;
}

impl CastBuildPass.conv_expr(nd: object) -> object {
    return self.convert(nd, stmt=False);
}

impl CastBuildPass.emit_c_diag(
    c_node: object, num: int, anchor: uni.UniNode | None = None, **kw: object
) -> None {
    loc_node = anchor if anchor is not None else c_tok(c_node, self.orig_src);
    twin = ("W" if self.lenient_c else "E") + str(num);
    diag = DIAGNOSTICS[twin];
    self.cur_node = loc_node;
    self.emit(diag, node_override=loc_node, **kw);
}

impl CastBuildPass.c_diags -> list[tuple[str, str, int]] {
    out: list[tuple[str, str, int]] = [];
    for al in self.warnings_had + self.errors_had {
        code = al.code.code if al.code is not None else "";
        out.append((code, al.msg, al.loc.first_line));
    }
    return out;
}

impl CastBuildPass._coord(c_node: object) -> tuple[int, int] {
    return coord_of(c_node, 1);
}

impl CastBuildPass._name(c_node: object, value: str) -> uni.Name {
    (line, col) = self._coord(c_node);
    return uni.Name(
        orig_src=self.orig_src,
        name=Tok.NAME,
        value=value,
        line=line,
        end_line=line,
        col_start=col,
        col_end=col + max(len(value), 1),
        pos_start=0,
        pos_end=max(len(value), 1)
    );
}

impl CastBuildPass._ident(c_node: object, value: str) -> uni.Name {
    return self._name(c_node, jac_id(value));
}

impl CastBuildPass._op_tok(c_node: object, tok: str, value: str) -> uni.Token {
    (line, col) = self._coord(c_node);
    return uni.Token(
        orig_src=self.orig_src,
        name=tok,
        value=value,
        line=line,
        end_line=line,
        col_start=col,
        col_end=col + len(value),
        pos_start=0,
        pos_end=len(value)
    );
}

impl CastBuildPass._surrogate_expr(c_node: object) -> uni.FuncCall {
    (line, _) = self._coord(c_node);
    target = self._name(c_node, C_UNSUPPORTED);
    line_lit = uni.Int(
        orig_src=self.orig_src,
        name=Tok.INT,
        value=str(line),
        line=line,
        end_line=line,
        col_start=0,
        col_end=len(str(line)),
        pos_start=0,
        pos_end=len(str(line))
    );
    call = uni.FuncCall(
        target=target, params=[line_lit], genai_call=None, kid=[target, line_lit]
    );
    self.emit_c_diag(c_node, 4290, anchor=call, ctype=type(c_node).__name__);
    return call;
}

impl CastBuildPass._surrogate_stmt(c_node: object) -> uni.UniNode {
    call = self._surrogate_expr(c_node);
    stmt = uni.ExprStmt(expr=call, in_fstring=False, kid=[call]);
    if self._func_depth > 0 {
        return stmt;
    }

    return uni.ModuleCode(name=None, body=[stmt], doc=None, kid=[stmt]);
}

impl CastBuildPass._scope_bind(assign: uni.Assignment) -> uni.UniNode {
    if self._func_depth > 0 {
        return assign;
    }
    return uni.GlobalVars(
        access=None, doc=None, assignments=[assign], is_frozen=False, kid=[assign]
    );
}

impl CastBuildPass.proc_file_ast(nd: object) -> uni.Module {
    elements: list[uni.UniNode] = [];
    ext = nd?.ext or [];
    for entry in ext {
        res = self.convert(entry, stmt=True);
        if isinstance(res, list) {
            elements.extend(res);
        } elif res is not None {
            elements.append(res);
        }
    }
    modname = os.path.basename(self.ir_in.file_path).split(".")[0];
    if not elements {
        return uni.Module.make_stub(inject_src=self.orig_src);
    }
    ret = uni.Module(
        name=modname,
        source=self.orig_src,
        doc=None,
        body=elements,
        terminals=[],
        kid=elements
    );
    return self.nu(ret);
}

impl CastBuildPass.proc_compound(nd: object) -> list[uni.UniNode] {
    out: list[uni.UniNode] = [];
    items = nd?.block_items or [];
    for it in items {
        res = self.convert(it, stmt=True);
        if isinstance(res, list) {
            out.extend(res);
        } elif res is not None {
            out.append(res);
        }
    }
    return out;
}

impl CastBuildPass.proc_func_def(nd: object) -> uni.Ability {
    self._list_bound = set();
    self._var_types = {};
    fname = nd.decl.name;
    name = self._ident(nd.decl, fname);
    params: list[uni.ParamVar] = [];
    pl = nd.decl.type.args;
    if pl is not None {
        for p in pl.params {
            if isinstance(p, c_ast.EllipsisParam) {
                self.emit_c_diag(nd.decl, 4207);
                continue;
            }
            if p.name is None {
                continue;
            }
            self._record_scalar_type(p.name, p.type);
            ann = self._name(p, elem_typename(p.type));
            annot = uni.SubTag[uni.Expr](tag=ann, kid=[ann]);
            pname = self._ident(p, p.name);
            params.append(
                uni.ParamVar(
                    name=pname,
                    type_tag=annot,
                    unpack=None,
                    value=None,
                    kid=[pname, annot]
                )
            );
        }
    }
    ret_ann = self._name(nd.decl, elem_typename(nd.decl.type.type));
    sig_kids: list[uni.UniNode] = [*params, ret_ann];
    sig = uni.FuncSignature(
        posonly_params=[],
        params=params,
        varargs=None,
        kwonlyargs=[],
        kwargs=None,
        return_type=ret_ann,
        kid=sig_kids
    );
    self._func_depth += 1;
    body = self.proc_compound(nd.body);
    self._func_depth -= 1;
    kid: list[uni.UniNode] = [name, sig, *body];
    return self.nu(
        uni.Ability(
            name_ref=name,
            is_async=False,
            is_static=False,
            is_classmethod=False,
            is_abstract=False,
            is_override=False,
            access=None,
            signature=sig,
            body=body,
            decorators=None,
            doc=None,
            kid=kid
        )
    );
}

impl CastBuildPass.proc_decl(nd: object) -> object {
    if nd.name is None {
        if isinstance(nd.type, c_ast.Struct) and nd.type.name is not None {
            return self.convert(nd.type);
        }
        if isinstance(nd.type, c_ast.Enum) {
            return self.convert(nd.type);
        }
        return self._surrogate_stmt(nd);
    }
    inner = nd.type;
    storage = nd.storage or [];
    quals = nd.quals or [];
    if "volatile" in quals {
        self.emit_c_diag(nd, 4205, name=nd.name);
    }
    if "static" in storage and self._func_depth > 0 {
        self.emit_c_diag(nd, 4206, name=nd.name);
    }
    if "extern" in storage and c_field(nd, "init") is None {
        return [];
    }
    if isinstance(inner, c_ast.FuncDecl) {
        return [];
    }
    if isinstance(inner, c_ast.ArrayDecl) {
        return self._decl_array(nd);
    }
    if isinstance(inner, c_ast.TypeDecl) and isinstance(inner.type, c_ast.Enum) {
        return self._enum_var_decl(nd, inner.type);
    }

    self._record_scalar_type(nd.name, inner);
    target = self._ident(nd, nd.name);
    nd_init = c_field(nd, "init");

    arr_elem = malloc_array_match(nd_init) if nd_init is not None else None;
    if arr_elem is not None {
        list_ann = self._list_ann(nd, arr_elem);
        annot = uni.SubTag[uni.Expr](tag=list_ann, kid=[list_ann]);
        self._list_bound.add(nd.name);
    } else {
        ann = self._name(nd, elem_typename(nd.type));
        annot = uni.SubTag[uni.Expr](tag=ann, kid=[ann]);
        self._list_bound.discard(nd.name);
    }
    value = self.conv_expr(nd_init) if nd_init is not None else None;
    kid: list[uni.UniNode] = [target, annot];
    if value is not None {
        kid.append(value);
    }
    return self._scope_bind(
        uni.Assignment(
            target=[target],
            value=value if isinstance(value, uni.Expr) else None,
            type_tag=annot,
            mutable=True,
            kid=kid
        )
    );
}

impl CastBuildPass.proc_return(nd: object) -> uni.ReturnStmt {
    val = self.conv_expr(nd.expr) if nd.expr is not None else None;
    if val is None or not isinstance(val, uni.Expr) {
        return uni.ReturnStmt(
            expr=None, kid=[self._op_tok(nd, Tok.KW_RETURN, "return")]
        );
    }
    return uni.ReturnStmt(expr=val, kid=[val]);
}

impl CastBuildPass.proc_binary_op(nd: object) -> object {
    entry = C_OP_TOK.get(nd.op);
    if entry is None {
        return self._surrogate_expr(nd);
    }
    (kind, tok, text) = entry;
    left = self.conv_expr(nd.left);
    right = self.conv_expr(nd.right);
    if not (isinstance(left, uni.Expr) and isinstance(right, uni.Expr)) {
        return self._surrogate_expr(nd);
    }
    op = self._op_tok(nd, tok, text);
    if kind == BinKind.COMPARE {
        inner = uni.CompareExpr(
            left=left, rights=[right], ops=[op], kid=[left, op, right]
        );
    } elif kind == BinKind.BOOL {
        lc = uni.CfgExpr(expr=left, kid=[left]);
        rc = uni.CfgExpr(expr=right, kid=[right]);
        inner = uni.BoolExpr(op=op, values=[lc, rc], kid=[op, lc, rc]);
    } else {
        inner = uni.BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return uni.AtomUnit(
        value=inner,
        kid=[
            self._op_tok(nd, Tok.LPAREN, "("),
            inner,
            self._op_tok(nd, Tok.RPAREN, ")")
        ]
    );
}

impl CastBuildPass.proc_id(nd: object) -> uni.UniNode {
    owner = self._enum_member_owner.get(nd.name);
    if owner is not None {
        base = self._name(nd, owner);
        member = self._name(nd, nd.name);
        return uni.AtomTrailer(
            target=base,
            right=member,
            is_attr=True,
            is_null_ok=False,
            kid=[base, member]
        );
    }
    return self._ident(nd, nd.name);
}

impl CastBuildPass.proc_constant(nd: object) -> uni.Literal {
    family = classify_c_constant(nd.type);
    (line, col) = self._coord(nd);
    if family == CLIT_INT {
        iv = parse_c_int(nd.value);
        if iv is not None {
            return self._lit(uni.Int, Tok.INT, str(iv), line, col);
        }
        self.emit_c_diag(nd, 4210, value=str(nd.value));
        return self._lit(uni.String, Tok.STRING, repr(nd.value), line, col);
    }
    if family == CLIT_FLOAT {
        fv = parse_c_float(nd.value);
        if fv is not None {
            return self._lit(uni.Float, Tok.FLOAT, str(fv), line, col);
        }
        self.emit_c_diag(nd, 4210, value=str(nd.value));
        return self._lit(uni.String, Tok.STRING, repr(nd.value), line, col);
    }
    if family == CLIT_CHAR {
        return self._lit(
            uni.String, Tok.STRING, repr(c_char_text(nd.value)), line, col
        );
    }
    if family == CLIT_STRING {
        inner = c_string_inner(nd.value);
        text = inner if inner is not None else nd.value;
        return self._lit(uni.String, Tok.STRING, f'"{text}"', line, col);
    }
    self.emit_c_diag(nd, 4211);
    return self._lit(uni.String, Tok.STRING, repr(str(nd.value)), line, col);
}

impl CastBuildPass._lit(
    cls: type, tok: str, text: str, line: int, col: int
) -> uni.Literal {
    return cls(
        orig_src=self.orig_src,
        name=tok,
        value=text,
        line=line,
        end_line=line,
        col_start=col,
        col_end=col + len(text),
        pos_start=0,
        pos_end=len(text)
    );
}

impl CastBuildPass.proc_func_call(nd: object) -> object {
    if isinstance(nd.name, c_ast.ID) and nd.name.name == "free" {
        return self._pass_semi(nd);
    }
    if isinstance(nd.name, c_ast.ID) and nd.name.name == "realloc" {
        re = self._realloc_elide(nd);
        if re is not None {
            return re;
        }

        return self._surrogate_expr(nd);
    }
    arr = self._malloc_array(nd);
    if arr is not None {
        return arr;
    }
    struct_name = malloc_struct_type(nd);
    if struct_name is not None {
        ctor = self._name(nd, struct_name);
        return uni.FuncCall(target=ctor, params=[], genai_call=None, kid=[ctor]);
    }
    target = self.conv_expr(nd.name);
    if not isinstance(target, uni.Expr) {
        return self._surrogate_expr(nd);
    }
    params: list[uni.Expr] = [];
    args = nd?.args;
    if args is not None {
        for a in args.exprs {
            pv = self.conv_expr(a);
            if isinstance(pv, uni.Expr) {
                params.append(pv);
            }
        }
    }
    kid: list[uni.UniNode] = [target, *params];
    return uni.FuncCall(target=target, params=params, genai_call=None, kid=kid);
}

impl CastBuildPass._realloc_elide(nd: object) -> uni.Expr | None {
    ptr = realloc_ptr_arg(nd);
    if not (isinstance(ptr, c_ast.ID) and ptr.name in self._list_bound) {
        return None;
    }
    val = self.conv_expr(ptr);
    return val if isinstance(val, uni.Expr) else None;
}

impl CastBuildPass._malloc_array(nd: object) -> object | None {
    tname = malloc_array_match(nd);
    if tname is None {
        return None;
    }
    default = self._elem_default(nd, tname);
    factors: list = [];
    flatten_mult(nd.args.exprs[0], factors);
    others = [
        f
        for f in factors
        if sizeof_type(f) is None
    ];
    count = self._product_expr(nd, others);
    if not isinstance(count, uni.Expr) {
        return None;
    }
    return self._range_compr(nd, default, count);
}

impl CastBuildPass._range_compr(
    c_node: object, elem_default: uni.Expr, count: uni.Expr
) -> uni.ListCompr {
    range_name = self._name(c_node, "range");
    range_call = uni.FuncCall(
        target=range_name, params=[count], genai_call=None, kid=[range_name, count]
    );
    tgt = self._name(c_node, "_");
    inner = uni.InnerCompr(
        is_async=False,
        target=tgt,
        collection=range_call,
        conditional=None,
        kid=[tgt, range_call]
    );
    return uni.ListCompr(
        out_expr=elem_default, compr=[inner], kid=[elem_default, inner]
    );
}

impl CastBuildPass._elem_default(c_node: object, tname: str) -> uni.Expr {
    if tname in C_PRIM_MAP {
        return self._elem_zero_lit(c_node, tname);
    }
    ctor = self._name(c_node, tname);
    return uni.FuncCall(target=ctor, params=[], genai_call=None, kid=[ctor]);
}

impl CastBuildPass._product_expr(c_node: object, factors: list) -> object {
    exprs = [self.conv_expr(f) for f in factors];
    valid = [
        e
        for e in exprs
        if isinstance(e, uni.Expr)
    ];
    if not valid {
        return self._surrogate_expr(c_node);
    }
    acc = valid[0];
    i = 1;
    while i < len(valid) {
        star = self._op_tok(c_node, Tok.STAR_MUL, "*");
        acc = uni.BinaryExpr(
            left=acc, op=star, right=valid[i], kid=[acc, star, valid[i]]
        );
        i += 1;
    }
    return acc;
}

impl CastBuildPass._pass_semi(c_node: object) -> uni.Semi {
    (line, _) = self._coord(c_node);
    return uni.Semi(
        orig_src=self.orig_src,
        name=Tok.SEMI,
        value=";",
        line=line,
        end_line=line,
        col_start=0,
        col_end=1,
        pos_start=0,
        pos_end=1
    );
}

impl CastBuildPass._stmts_from(c_node: object) -> list[uni.UniNode] {
    if c_node is None {
        return [self._pass_semi(c_node)];
    }
    if isinstance(c_node, c_ast.Compound) {
        body = self.proc_compound(c_node);
        return body or [self._pass_semi(c_node)];
    }
    res = self.convert(c_node, stmt=True);
    if isinstance(res, list) {
        return res or [self._pass_semi(c_node)];
    }
    return [res] if res is not None else [self._pass_semi(c_node)];
}

impl CastBuildPass._block(c_node: object) -> list[uni.UniNode] {
    return [
        s
        for s in self._stmts_from(c_node)
        if isinstance(s, uni.CodeBlockStmt)
    ];
}

impl CastBuildPass.proc_if(nd: object) -> object {
    test = self.conv_expr(nd.cond);
    if not isinstance(test, uni.Expr) {
        return self._surrogate_stmt(nd);
    }
    body = self._block(nd.iftrue);
    else_body: uni.ElseIf | uni.ElseStmt | None = None;
    if nd.iffalse is not None {
        orelse = self._block(nd.iffalse);
        if orelse {
            first = orelse[0];
            if isinstance(first, uni.IfStmt) and len(orelse) == 1 {
                else_body = uni.ElseIf(
                    condition=first.condition,
                    body=first.body,
                    else_body=first.else_body,
                    kid=first.kid
                );
            } else {
                else_body = uni.ElseStmt(body=orelse, kid=orelse);
            }
        }
    }
    kid: list[uni.UniNode] = [test, *body, else_body] if else_body else [test, *body];
    return uni.IfStmt(condition=test, body=body, else_body=else_body, kid=kid);
}

impl CastBuildPass.proc_while(nd: object) -> object {
    test = self.conv_expr(nd.cond);
    if not isinstance(test, uni.Expr) {
        return self._surrogate_stmt(nd);
    }
    body = self._block(nd.stmt);
    return uni.WhileStmt(condition=test, body=body, else_body=None, kid=[test, *body]);
}

impl CastBuildPass._inc_dec_stmt(nd: object) -> uni.Assignment | None {
    target = self.conv_expr(nd.expr);
    if not isinstance(target, (uni.Name, uni.AtomTrailer)) {
        return None;
    }
    (tok, text) = (Tok.ADD_EQ, "+=") if nd.op in ("p++", "++") else (Tok.SUB_EQ, "-=");
    op = self._op_tok(nd, tok, text);
    (line, col) = self._coord(nd);
    one = self._lit(uni.Int, Tok.INT, "1", line, col);
    return uni.Assignment(
        target=[target],
        type_tag=None,
        mutable=False,
        aug_op=op,
        value=one,
        kid=[target, op, one]
    );
}

impl CastBuildPass._conv_stmts(items: list) -> list[uni.UniNode] {
    out: list[uni.UniNode] = [];
    for item in items {
        n = self.convert(item, stmt=True);
        if isinstance(n, list) {
            out.extend(n);
        } elif n is not None {
            out.append(n);
        }
    }
    return out;
}

impl CastBuildPass._for_promotable(nd: object) -> bool {
    init_node = c_field(nd, "init");
    cond_node = nd.cond;
    step_node = nd?.next;
    ok_init = False;
    if isinstance(init_node, c_ast.DeclList) {
        ok_init = len(init_node.decls) == 1
        and c_field(init_node.decls[0], "init") is not None;
    } elif isinstance(init_node, c_ast.Decl) {
        ok_init = c_field(init_node, "init") is not None;
    } elif isinstance(init_node, c_ast.Assignment) {
        ok_init = init_node.op == "=";
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
    return isinstance(step_node, c_ast.Assignment) and step_node.op != "=";
}

impl CastBuildPass._for_clause_stmts(clause_node: object) -> list[uni.UniNode] {
    if clause_node is None {
        return [];
    }
    if isinstance(clause_node, c_ast.DeclList) {
        return self._conv_stmts(clause_node.decls);
    }
    if isinstance(clause_node, c_ast.ExprList) {
        return self._conv_stmts(clause_node.exprs);
    }
    return self._conv_stmts([clause_node]);
}

impl CastBuildPass.proc_for(nd: object) -> object {
    promotable = self._for_promotable(nd);
    init_stmts = self._for_clause_stmts(c_field(nd, "init"));
    step_stmts = self._for_clause_stmts(nd?.next);
    body_stmts = self._block(nd.stmt) if nd.stmt is not None else [];
    if promotable and init_stmts and step_stmts {
        iter_old = init_stmts[0];
        count_by = step_stmts[0];
        if isinstance(iter_old, uni.Assignment)
        and isinstance(count_by, uni.Assignment) {
            cond = self.conv_expr(nd.cond);
            if isinstance(cond, uni.AtomUnit) {
                cond = cond.value;
            }
            if isinstance(cond, uni.Expr) {
                tgt = iter_old.target[0];
                val = iter_old.value;
                new_iter = uni.Assignment(
                    target=[tgt],
                    value=val,
                    type_tag=None,
                    mutable=True,
                    aug_op=None,
                    kid=[tgt, val]
                );
                return uni.IterForStmt(
                    iter=new_iter,
                    condition=cond,
                    count_by=count_by,
                    body=body_stmts,
                    else_body=None,
                    is_async=False,
                    kid=[new_iter, cond, count_by, *body_stmts]
                );
            }
        }
    }

    step_node = nd?.next;
    lossy_detail = "";
    if nd.cond is None {
        cond = self._bool_true(nd);
    } else {
        cond = self.conv_expr(nd.cond);
        if not isinstance(cond, uni.Expr) or self._is_surrogate(cond) {
            cond = self._bool_true(nd);
            lossy_detail = (
                "loop condition has no faithful lowering; replaced by `while True`"
            );
        }
    }
    if step_node is not None and nd.stmt is not None and has_loop_continue(nd.stmt) {
        detail = "a loop-level `continue` skips the step that C runs each iteration";
        lossy_detail = detail if not lossy_detail else lossy_detail + " | " + detail;
    }
    if lossy_detail {
        self.emit_c_diag(nd, 4208, detail=lossy_detail);
    }
    while_body: list[uni.UniNode] = [*body_stmts, *step_stmts];
    if not while_body {
        while_body = [self._pass_semi(nd)];
    }
    while_stmt = uni.WhileStmt(
        condition=cond, body=while_body, else_body=None, kid=[cond, *while_body]
    );
    return [*init_stmts, while_stmt];
}

impl CastBuildPass._bool_true(c_node: object) -> uni.Literal {
    (line, col) = self._coord(c_node);
    return self._lit(uni.Bool, Tok.BOOL, "True", line, col);
}

impl CastBuildPass._is_surrogate(expr: object) -> bool {
    return (
        isinstance(expr, uni.FuncCall)
        and isinstance(expr.target, uni.Name)
        and expr.target.value == C_UNSUPPORTED
    );
}

impl CastBuildPass.proc_break(nd: object) -> uni.CtrlStmt {
    tok = self._op_tok(nd, Tok.KW_BREAK, "break");
    return uni.CtrlStmt(ctrl=tok, kid=[tok]);
}

impl CastBuildPass.proc_continue(nd: object) -> uni.CtrlStmt {
    tok = self._op_tok(nd, Tok.KW_CONTINUE, "continue");
    return uni.CtrlStmt(ctrl=tok, kid=[tok]);
}

impl CastBuildPass._break_stmt(c_node: object) -> uni.CtrlStmt {
    tok = self._op_tok(c_node, Tok.KW_BREAK, "break");
    return uni.CtrlStmt(ctrl=tok, kid=[tok]);
}

impl CastBuildPass.proc_do_while(nd: object) -> object {
    cond = self.conv_expr(nd.cond);
    if not isinstance(cond, uni.Expr) {
        return self._surrogate_stmt(nd);
    }
    body = self._block(nd.stmt);
    not_op = self._op_tok(nd, Tok.NOT, "not");
    guard_cond = uni.UnaryExpr(op=not_op, operand=cond, kid=[not_op, cond]);
    brk = self._break_stmt(nd);
    guard = uni.IfStmt(
        condition=guard_cond, body=[brk], else_body=None, kid=[guard_cond, brk]
    );
    full_body: list[uni.UniNode] = [*body, guard];
    if has_loop_continue(nd.stmt) {
        self.emit_c_diag(nd, 4203);
    }
    true_c = self._bool_true(nd);
    return uni.WhileStmt(
        condition=true_c, body=full_body, else_body=None, kid=[true_c, *full_body]
    );
}

impl CastBuildPass.proc_switch(nd: object) -> object {
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
    if not switch_is_safe(items, nd.cond) {
        self.emit_c_diag(
            nd,
            4202,
            detail="case fall-through not modelled and/or an impure selector "
            "is re-evaluated per branch"
        );
    }
    tail_else: uni.ElseIf | uni.ElseStmt | None = None;
    if default_stmts is not None {
        d_body = self._switch_branch_body(nd, default_stmts);
        tail_else = uni.ElseStmt(body=d_body, kid=d_body);
    }
    chain: uni.IfStmt | None = None;
    for grp in reversed(groups) {
        (vals, stmts) = grp;
        test = self._switch_test(nd, nd.cond, vals);
        body = self._switch_branch_body(nd, stmts);
        kid: list[uni.UniNode] = [test, *body, tail_else]
            if tail_else
            else [test, *body];
        ifs = uni.IfStmt(condition=test, body=body, else_body=tail_else, kid=kid);
        chain = ifs;
        tail_else = uni.ElseIf(
            condition=ifs.condition, body=ifs.body, else_body=ifs.else_body, kid=ifs.kid
        );
    }
    return chain if chain is not None else self._pass_semi(nd);
}

impl CastBuildPass._switch_test(
    nd: object, cond_cnode: object, vals: list
) -> uni.Expr {
    cmps: list[uni.Expr] = [];
    for v in vals {
        sel = self.conv_expr(cond_cnode);
        val = self.conv_expr(v);
        if isinstance(sel, uni.Expr) and isinstance(val, uni.Expr) {
            op = self._op_tok(nd, Tok.EE, "==");
            cmp = uni.CompareExpr(left=sel, rights=[val], ops=[op], kid=[sel, op, val]);
            cmps.append(cmp);
        }
    }
    if len(cmps) == 1 {
        return cmps[0];
    }
    or_op = self._op_tok(nd, Tok.KW_OR, "or");
    cfgs = [uni.CfgExpr(expr=c, kid=[c]) for c in cmps];
    return uni.BoolExpr(op=or_op, values=cfgs, kid=[or_op, *cfgs]);
}

impl CastBuildPass._switch_branch_body(
    nd: object, stmts: list | None
) -> list[uni.UniNode] {
    raw: list = stmts or [];
    if len(raw) == 1 and isinstance(raw[0], c_ast.Compound) {
        raw = raw[0].block_items or [];
    }
    kept = [
        s
        for s in raw
        if not isinstance(s, c_ast.Break)
    ];
    out = [
        s
        for s in self._conv_stmts(kept)
        if isinstance(s, uni.CodeBlockStmt)
    ];
    return out or [self._pass_semi(nd)];
}

impl CastBuildPass.proc_empty_statement(nd: object) -> uni.Semi {
    return self._pass_semi(nd);
}

impl CastBuildPass.proc_ternary_op(nd: object) -> object {
    test = self.conv_expr(nd.cond);
    body = self.conv_expr(nd.iftrue);
    orelse = self.conv_expr(nd.iffalse);
    if not (
        isinstance(test, uni.Expr)
        and isinstance(body, uni.Expr)
        and isinstance(orelse, uni.Expr)
    ) {
        return self._surrogate_expr(nd);
    }
    cond_cfg = uni.CfgExpr(expr=test, kid=[test]);
    val_cfg = uni.CfgExpr(expr=body, kid=[body]);
    else_cfg = uni.CfgExpr(expr=orelse, kid=[orelse]);
    return uni.IfElseExpr(
        value=val_cfg,
        condition=cond_cfg,
        else_value=else_cfg,
        kid=[val_cfg, cond_cfg, else_cfg]
    );
}

impl CastBuildPass._scalar_prim(type_node: object) -> JacPrim | None {
    if isinstance(type_node, c_ast.TypeDecl)
    and isinstance(type_node.type, c_ast.IdentifierType) {
        return jac_prim(type_node.type.names);
    }
    return None;
}

impl CastBuildPass._record_scalar_type(name: str, type_node: object) -> None {
    prim = self._scalar_prim(type_node);
    if prim is not None {
        self._var_types[name] = prim;
    } elif name in self._var_types {
        del self._var_types[name];
    }
}

impl CastBuildPass._expr_prim(c_node: object) -> JacPrim | None {
    if isinstance(c_node, c_ast.Constant) {
        fam = classify_c_constant(c_node.type);
        if fam == CLIT_INT {
            return JacPrim.INT;
        }
        if fam == CLIT_FLOAT {
            return JacPrim.FLOAT;
        }
        return JacPrim.STR;
    }
    if isinstance(c_node, c_ast.ID) {
        return self._var_types.get(c_node.name);
    }
    return None;
}

impl CastBuildPass.proc_unary_op(nd: object) -> object {
    entry = C_UNARY_TOK.get(nd.op);
    if entry is not None {
        (tok, text) = entry;
        operand = self.conv_expr(nd.expr);
        if not isinstance(operand, uni.Expr) {
            return self._surrogate_expr(nd);
        }
        op = self._op_tok(nd, tok, text);
        return uni.UnaryExpr(op=op, operand=operand, kid=[op, operand]);
    }
    if nd.op in ("++", "--") {
        walrus = self._pre_incdec_walrus(nd);
        return walrus if walrus is not None else self._surrogate_expr(nd);
    }
    if nd.op in ("*", "&") and is_simple_ref(nd.expr) {
        inner = self.conv_expr(nd.expr);
        return inner if isinstance(inner, uni.Expr) else self._surrogate_expr(nd);
    }

    return self._surrogate_expr(nd);
}

impl CastBuildPass._pre_incdec_walrus(nd: object) -> uni.AtomUnit | None {
    if not isinstance(nd.expr, c_ast.ID) {
        return None;
    }
    if self._expr_prim(nd.expr) not in (JacPrim.INT, JacPrim.FLOAT) {
        return None;
    }
    name = nd.expr.name;
    target = self._name(nd, name);
    load = self._name(nd, name);
    (line, col) = self._coord(nd);
    one = self._lit(uni.Int, Tok.INT, "1", line, col);
    (tok, text) = (Tok.PLUS, "+") if nd.op == "++" else (Tok.MINUS, "-");
    add_op = self._op_tok(nd, tok, text);
    binop = uni.BinaryExpr(left=load, op=add_op, right=one, kid=[load, add_op, one]);
    walrus_op = self._op_tok(nd, Tok.WALRUS_EQ, ":=");
    expr = uni.BinaryExpr(
        left=target, op=walrus_op, right=binop, kid=[target, walrus_op, binop]
    );
    return uni.AtomUnit(
        value=expr,
        kid=[self._op_tok(nd, Tok.LPAREN, "("), expr, self._op_tok(nd, Tok.RPAREN, ")")]
    );
}

impl CastBuildPass.proc_assignment(nd: object) -> object {
    if nd.op == "=" and isinstance(nd.rvalue, c_ast.Assignment) {
        targets_c: list[object] = [];
        cur = nd;
        while isinstance(cur, c_ast.Assignment) and cur.op == "=" {
            targets_c.append(cur.lvalue);
            cur = cur.rvalue;
        }
        tgt_exprs = [self.conv_expr(t) for t in targets_c];
        val = self.conv_expr(cur);
        ok = isinstance(val, uni.Expr)
        and all([isinstance(t, uni.Expr) for t in tgt_exprs]);
        if ok {
            return uni.Assignment(
                target=tgt_exprs,
                value=val,
                type_tag=None,
                mutable=False,
                kid=[*tgt_exprs, val]
            );
        }
        return self._surrogate_stmt(nd);
    }
    lhs = self.conv_expr(nd.lvalue);
    rhs = self.conv_expr(nd.rvalue);
    if not (isinstance(lhs, uni.Expr) and isinstance(rhs, uni.Expr)) {
        return self._surrogate_stmt(nd);
    }
    if nd.op == "=" {
        if isinstance(nd.lvalue, c_ast.ID) {
            self._list_bound.discard(nd.lvalue.name);
        }
        return uni.Assignment(
            target=[lhs], value=rhs, type_tag=None, mutable=False, kid=[lhs, rhs]
        );
    }
    aug_name = C_AUG_TOK.get(nd.op);
    if aug_name is None {
        return self._surrogate_stmt(nd);
    }
    op = self._op_tok(nd, aug_name, nd.op);
    return uni.Assignment(
        target=[lhs],
        type_tag=None,
        mutable=False,
        aug_op=op,
        value=rhs,
        kid=[lhs, op, rhs]
    );
}

impl CastBuildPass.proc_struct_ref(nd: object) -> object {
    target = self.conv_expr(nd.name);
    if not isinstance(target, uni.Expr) {
        return self._surrogate_expr(nd);
    }
    field = self._name(nd.field, nd.field.name);
    return uni.AtomTrailer(
        target=target, right=field, is_attr=True, is_null_ok=False, kid=[target, field]
    );
}

impl CastBuildPass.proc_array_ref(nd: object) -> object {
    target = self.conv_expr(nd.name);
    idx = self.conv_expr(nd.subscript);
    if not (isinstance(target, uni.Expr) and isinstance(idx, uni.Expr)) {
        return self._surrogate_expr(nd);
    }
    slice_node = uni.Slice(start=idx, stop=None, step=None, kid=[idx]);
    index = uni.IndexSlice(slices=[slice_node], is_range=False, kid=[slice_node]);
    return uni.AtomTrailer(
        target=target, right=index, is_attr=False, is_null_ok=False, kid=[target, index]
    );
}

impl CastBuildPass._struct_field(mem: object) -> uni.ArchHas | None {
    if mem.name is None {
        return None;
    }
    name_node = self._name(mem, mem.name);
    ann = self._name(mem, elem_typename(mem.type));
    type_tag = uni.SubTag[uni.Expr](tag=ann, kid=[ann]);
    hv = uni.HasVar(
        name=name_node,
        type_tag=type_tag,
        value=None,
        defer=False,
        kid=[name_node, type_tag]
    );
    has_kw = self._op_tok(mem, Tok.KW_HAS, "has");
    semi = self._op_tok(mem, Tok.SEMI, ";");
    return uni.ArchHas(
        is_static=False,
        vars=[hv],
        is_frozen=False,
        access=None,
        doc=None,
        kid=[has_kw, hv, semi]
    );
}

impl CastBuildPass._struct_archetype(
    snode: object, name: str, origin: object
) -> uni.Archetype {
    fields: list[uni.ArchHas] = [];
    decls = snode?.decls or [];
    for mem in decls {
        ah = self._struct_field(mem);
        if ah is not None {
            fields.append(ah);
        }
    }
    arch_type = self._op_tok(origin, Tok.KW_OBJECT, "obj");
    name_node = self._name(origin, name);
    if fields {
        body_kids: list[uni.UniNode] = [*fields];
    } else {
        body_kids = [
            self._op_tok(origin, Tok.LBRACE, "{"),
            self._op_tok(origin, Tok.RBRACE, "}")
        ];
    }
    return uni.Archetype(
        name=name_node,
        arch_type=arch_type,
        access=None,
        base_classes=[],
        body=fields,
        doc=None,
        decorators=None,
        kid=[arch_type, name_node, *body_kids]
    );
}

impl CastBuildPass.proc_struct(nd: object) -> uni.Archetype {
    return self._struct_archetype(nd, nd.name or "_AnonStruct", nd);
}

impl CastBuildPass.proc_typedef(nd: object) -> object {
    inner = nd.type;
    if isinstance(inner, c_ast.TypeDecl) and isinstance(inner.type, c_ast.Struct) {
        return self._struct_archetype(inner.type, nd.name, nd);
    }

    target = self._ident(nd, nd.name);
    value = self._name(nd, typename(nd.type));
    return self._scope_bind(
        uni.Assignment(
            target=[target],
            value=value,
            type_tag=None,
            mutable=False,
            kid=[target, value]
        )
    );
}

impl CastBuildPass.proc_enum(nd: object) -> object {
    verdict = self.enum_verdicts.verdicts.get(id(nd), EnumShape.NONE);
    name_map = self.enum_verdicts.name_map.get(id(nd), {});
    if verdict == EnumShape.ENUM_AS_ENUM {
        return self._enum_as_enum(nd, name_map);
    }
    if verdict == EnumShape.ENUM_AS_CONSTS {
        return self._enum_as_consts(nd, name_map);
    }
    return self._surrogate_stmt(nd);
}

impl CastBuildPass._enum_var_decl(nd: object, en: object) -> list[uni.UniNode] {
    stmts: list[uni.UniNode] = [];

    if en.values is not None {
        if self._func_depth > 0 {
            ep = eval_enumerators(en.values);
            if not ep.all_simple {
                stmts.append(self._surrogate_stmt(en));
            } else {
                (line, col) = self._coord(en);
                for (nm, val) in ep.pairs {
                    name_n = self._name(en, nm);
                    val_n = self._lit(uni.Int, Tok.INT, str(val), line, col);
                    stmts.append(
                        uni.Assignment(
                            target=[name_n],
                            value=val_n,
                            type_tag=None,
                            mutable=True,
                            aug_op=None,
                            is_enum_stmt=False,
                            kid=[name_n, val_n]
                        )
                    );
                }
            }
        } else {
            res = self.proc_enum(en);
            if isinstance(res, list) {
                stmts.extend(res);
            } elif res is not None {
                stmts.append(res);
            }
        }
    }

    self._record_scalar_type(nd.name, en);
    target = self._ident(nd, nd.name);
    ann = self._name(nd, elem_typename(en));
    annot = uni.SubTag[uni.Expr](tag=ann, kid=[ann]);
    stmts.append(
        self._scope_bind(
            uni.Assignment(
                target=[target],
                value=None,
                type_tag=annot,
                mutable=True,
                kid=[target, annot]
            )
        )
    );
    return stmts;
}

impl CastBuildPass._enum_as_enum(nd: object, name_map: dict[str, int]) -> uni.Enum {
    (line, col) = self._coord(nd);
    enum_name = self._name(nd, nd.name or "_AnonEnum");
    members: list[uni.UniNode] = [];
    for (nm, val) in name_map.items() {
        m_name = self._name(nd, nm);
        m_val = self._lit(uni.Int, Tok.INT, str(val), line, col);
        members.append(
            uni.Assignment(
                target=[m_name],
                value=m_val,
                type_tag=None,
                mutable=False,
                aug_op=None,
                is_enum_stmt=True,
                kid=[m_name, m_val]
            )
        );
    }
    return uni.Enum(
        name=enum_name,
        is_async=False,
        access=None,
        base_classes=None,
        value_type=None,
        body=members,
        decorators=None,
        doc=None,
        kid=[enum_name, *members]
    );
}

impl CastBuildPass._enum_as_consts(
    nd: object, name_map: dict[str, int]
) -> list[uni.GlobalVars] {
    (line, col) = self._coord(nd);
    assigns: list[uni.Assignment] = [];
    for (nm, val) in name_map.items() {
        name_n = self._name(nd, nm);
        val_n = self._lit(uni.Int, Tok.INT, str(val), line, col);
        assigns.append(
            uni.Assignment(
                target=[name_n],
                value=val_n,
                type_tag=None,
                mutable=False,
                aug_op=None,
                is_enum_stmt=False,
                kid=[name_n, val_n]
            )
        );
    }
    return [
        uni.GlobalVars(
            access=None, doc=None, assignments=assigns, is_frozen=True, kid=[*assigns]
        )
    ];
}

impl CastBuildPass._list_ann(c_node: object, elem_name: str) -> uni.AtomTrailer {
    raw = C_PRIM_MAP.get(elem_name);
    jac = raw.value if raw is not None else elem_name;
    elem = self._name(c_node, jac);
    list_name = self._name(c_node, "list");
    slice_node = uni.Slice(start=elem, stop=None, step=None, kid=[elem]);
    idx = uni.IndexSlice(slices=[slice_node], is_range=False, kid=[slice_node]);
    return uni.AtomTrailer(
        target=list_name,
        right=idx,
        is_attr=False,
        is_null_ok=False,
        kid=[list_name, idx]
    );
}

impl CastBuildPass._elem_zero_lit(c_node: object, elem_name: str) -> uni.Literal {
    (line, col) = self._coord(c_node);
    jac = C_PRIM_MAP.get(elem_name, JacPrim.INT);
    pz = jac_prim_zero(jac);
    if jac == JacPrim.FLOAT {
        return self._lit(uni.Float, Tok.FLOAT, pz.text, line, col);
    }
    if jac == JacPrim.BOOL {
        text = "True" if pz.value else "False";
        return self._lit(uni.Bool, Tok.BOOL, text, line, col);
    }
    if jac == JacPrim.STR {
        return self._lit(uni.String, Tok.STRING, '""', line, col);
    }
    return self._lit(uni.Int, Tok.INT, pz.text, line, col);
}

impl CastBuildPass._decl_array(nd: object) -> object {
    arr_decl = nd.type;
    elem_name = elem_typename(arr_decl.type);
    list_ann = self._list_ann(nd, elem_name);
    annot = uni.SubTag[uni.Expr](tag=list_ann, kid=[list_ann]);
    target = self._ident(nd, nd.name);
    value: uni.Expr | None = None;
    nd_init = c_field(nd, "init");
    if nd_init is not None {
        iv = self.conv_expr(nd_init);
        value = iv if isinstance(iv, uni.Expr) else None;
    } elif arr_decl.dim is not None {
        dim_expr = self.conv_expr(arr_decl.dim);
        if elem_name in C_PRIM_MAP and isinstance(dim_expr, uni.Expr) {
            zero = self._elem_zero_lit(nd, elem_name);
            lst = uni.ListVal(values=[zero], kid=[zero]);
            star = self._op_tok(nd, Tok.STAR_MUL, "*");
            value = uni.BinaryExpr(
                left=lst, op=star, right=dim_expr, kid=[lst, star, dim_expr]
            );
        } elif isinstance(dim_expr, uni.Expr) {
            default = self._elem_default(nd, elem_name);
            value = self._range_compr(nd, default, dim_expr);
        }
    }
    kid: list[uni.UniNode] = [target, annot];
    if value is not None {
        kid.append(value);
    }
    return self._scope_bind(
        uni.Assignment(
            target=[target], value=value, type_tag=annot, mutable=True, kid=kid
        )
    );
}

impl CastBuildPass.proc_array_decl(nd: object) -> object {
    return self._surrogate_stmt(nd);
}

impl CastBuildPass.proc_init_list(nd: object) -> object {
    elts: list[uni.Expr] = [];
    for e in nd?.exprs or [] {
        ev = self.conv_expr(e);
        if isinstance(ev, uni.Expr) {
            elts.append(ev);
        }
    }
    if elts {
        return uni.ListVal(values=elts, kid=[*elts]);
    }
    lb = self._op_tok(nd, Tok.LSQUARE, "[");
    rb = self._op_tok(nd, Tok.RSQUARE, "]");
    return uni.ListVal(values=[], kid=[lb, rb]);
}

impl CastBuildPass.proc_named_initializer(nd: object) -> object {
    names = nd.name or [];
    field = ".".join([self._desig_name(d) for d in names]);
    self.emit_c_diag(nd, 4209, field=field);
    return self.conv_expr(nd.expr);
}

impl CastBuildPass._desig_name(d: object) -> str {
    return d.name if isinstance(d, c_ast.ID) else str(getattr(d, "value", "?"));
}

impl CastBuildPass.proc_expr_list(nd: object) -> object {
    exprs = nd?.exprs or [];
    if not exprs {
        return self._surrogate_expr(nd);
    }
    impure = [
        e
        for e in exprs[:-1]
        if not expr_reeval_safe(e)
    ];
    if impure {
        self.emit_c_diag(nd, 4204);
    }
    return self.conv_expr(exprs[-1]);
}

impl CastBuildPass.proc_cast(nd: object) -> object {
    target = cast_scalar_target(nd);
    if target is not None {
        self.emit_c_diag(
            nd,
            4201,
            target=target,
            detail="representation-changing conversion "
            "(truncation/narrowing/discard) not applied"
        );
    }
    return self.conv_expr(nd.expr);
}
