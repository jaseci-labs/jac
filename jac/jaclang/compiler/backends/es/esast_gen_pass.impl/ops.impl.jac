impl EsastGenPass._ensure_emitters -> None {
    if self._primitive_emitters is not None {
        return;
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    import jaclang.compiler.backends.es.primitives_es as _pes;
    self._primitives_es_mod = _pes;
    self._primitive_emitters = {};
    for (_tn, _suffix) in JAC_TYPE_REGISTRY.emitter_items() {
        _ecls = getattr(_pes, "ES" + _suffix, None);
        if _ecls is not None {
            self._primitive_emitters[_tn] = _ecls();
        }
    }
    self._builtin_emitter = _pes.ESBuiltinEmitter();

    _poly: set[str] = set();
    for _emitter in self._primitive_emitters.values() {
        for _attr in dir(_emitter) {
            if _attr.startswith("emit_") and not _attr.startswith("emit_op_") {
                _poly.add(_attr[len("emit_"):]);
            }
        }
    }
    self._poly_methods = _poly;
}

impl EsastGenPass._resolve_primitive_type_name(_obj_type: object) -> str {
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    self._ensure_emitters();
    return primitive_type_name_of(_obj_type) or "";
}

impl EsastGenPass._try_primitive_op(
    expr_node: uni.UniNode,
    emit_method: str,
    left_es: es.Expression,
    right_es: (es.Expression | None),
    jac_node: uni.UniNode
) -> (es.Expression | None) {
    import from jaclang.compiler.backends.es.es_unparse { JSCodeGenerator }

    import from jaclang.compiler.types.type_utils { expr_primitive_name }
    _type_name = expr_primitive_name(expr_node);
    if not _type_name {
        return None;
    }
    self._ensure_emitters();
    _emitter = self._primitive_emitters.get(_type_name);
    _emit_fn = getattr(_emitter, emit_method, None) if _emitter else None;
    if not _emit_fn {
        return None;
    }
    _unparser = JSCodeGenerator();
    _ctx = self._primitives_es_mod.ESEmitCtx(unparser=_unparser);

    _target_str = self._operand_str(_unparser, left_es);
    _args_strs: list[str] = [];
    if right_es is not None {
        _args_strs.append(self._operand_str(_unparser, right_es));
    }
    _result = _emit_fn(_ctx, _target_str, _args_strs);
    if _result is None {
        return None;
    }
    if "_jac." in str(_result) {
        self.needs_jac_runtime = True;
    }
    return self.sync_loc(es.RawCode(code=_result), jac_node=jac_node);
}

impl EsastGenPass._operand_str(unparser: object, es_node: es.Expression) -> str {
    rendered = unparser.generate(es_node);
    if isinstance(
        es_node,
        (es.AssignmentExpression, es.ConditionalExpression, es.ArrowFunctionExpression)
    ) {
        return "(" + rendered + ")";
    }
    return rendered;
}

impl EsastGenPass._expr_type_name(expr_node: uni.UniNode) -> str {
    import from jaclang.compiler.types.type_utils { expr_primitive_name }
    return expr_primitive_name(expr_node);
}

impl EsastGenPass._is_collection_expr(expr_node: uni.UniNode) -> bool {
    if isinstance(expr_node, uni.BoolExpr) {
        for val in expr_node.values {
            if self._is_collection_expr(val) {
                return True;
            }
        }
        return False;
    }
    return self._expr_type_name(expr_node)
        in {"list", "dict", "set", "tuple", "frozenset", "bytes"};
}

impl EsastGenPass._is_native_iterable_builtin_call(expr_node: uni.UniNode) -> bool {
    return isinstance(expr_node, uni.FuncCall)
        and expr_node.call_kind == "builtin"
        and isinstance(expr_node.target, uni.Name)
        and expr_node.target.sym_name
            in {"iter", "enumerate", "zip", "map", "filter", "sorted", "range"};
}

impl EsastGenPass._build_jac_ref(
    path: list[str], jac_node: (uni.UniNode | None)
) -> es.Expression {
    ref: es.Expression = self.sync_loc(es.Identifier(name=path[0]), jac_node=jac_node);
    for name in path[1:] {
        ref = self.sync_loc(
            es.MemberExpression(
                object=ref,
                property=self.sync_loc(es.Identifier(name=name), jac_node=jac_node),
                computed=False
            ),
            jac_node=jac_node
        );
    }
    return ref;
}

impl EsastGenPass._build_jac_call(
    path: list[str], args: list[es.Expression], jac_node: uni.UniNode
) -> es.Expression {
    self.needs_jac_runtime = True;
    return self.sync_loc(
        es.CallExpression(
            callee=self._build_jac_ref(path, jac_node),
            arguments=cast(list[(es.Expression | es.SpreadElement)], args)
        ),
        jac_node=jac_node
    );
}

impl EsastGenPass._coerce_truthy(
    expr_node: (uni.UniNode | None), es_expr: es.Expression, jac_node: uni.UniNode
) -> es.Expression {
    if (expr_node is not None) and self._is_collection_expr(expr_node) {
        return self._build_jac_call(["_jac", "builtin", "bool"], [es_expr], jac_node);
    }
    return es_expr;
}

impl EsastGenPass._is_literal_index(idx_es: es.Expression) -> bool {
    if not isinstance(idx_es, es.Literal) {
        return False;
    }
    return not (
        isinstance(idx_es.value, (int, float))
        and (not isinstance(idx_es.value, bool))
        and (idx_es.value < 0)
    );
}

impl EsastGenPass._lower_subscript(
    target_node: uni.UniNode,
    obj_es: es.Expression,
    idx_es: es.Expression,
    jac_node: uni.UniNode
) -> es.Expression {
    if self._is_literal_index(idx_es) {
        return self.sync_loc(
            es.MemberExpression(object=obj_es, property=idx_es, computed=True),
            jac_node=jac_node
        );
    }
    _tname = self._expr_type_name(target_node);
    if _tname in {"list", "tuple", "str", "bytes"} {
        return self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(
                    es.MemberExpression(
                        object=obj_es,
                        property=self.sync_loc(
                            es.Identifier(name='at'), jac_node=jac_node
                        ),
                        computed=False
                    ),
                    jac_node=jac_node
                ),
                arguments=[cast((es.Expression | es.SpreadElement), idx_es)]
            ),
            jac_node=jac_node
        );
    }
    if _tname == "dict" {
        return self.sync_loc(
            es.MemberExpression(object=obj_es, property=idx_es, computed=True),
            jac_node=jac_node
        );
    }
    return self._build_jac_call(
        ["_jac", "poly", "getitem"], [obj_es, idx_es], jac_node
    );
}

impl EsastGenPass._try_subscript_setitem(
    target: uni.UniNode, value_es: (es.Expression | None), jac_node: uni.UniNode
) -> (es.Statement | None) {
    if (
        not isinstance(target, uni.AtomTrailer)
        or not isinstance(target.right, uni.IndexSlice)
        or target.right.is_range
    ) {
        return None;
    }
    _si = target.right.gen.es_ast;
    if not isinstance(_si, es.IndexInfo) {
        return None;
    }
    _idx = cast(
        es.Expression,
        _si.value or self.sync_loc(es.Literal(value=0), jac_node=jac_node)
    );

    if self._is_literal_index(_idx) {
        return None;
    }

    if self._expr_type_name(target.target) != "list" {
        return None;
    }
    _obj = cast(
        es.Expression,
        target.target.gen.es_ast
            or self.sync_loc(es.Identifier(name='obj'), jac_node=jac_node)
    );
    _val = cast(
        es.Expression,
        value_es or self.sync_loc(es.Identifier(name='undefined'), jac_node=jac_node)
    );
    _call = self._build_jac_call(
        ["_jac", "poly", "setitem"], [_obj, _idx, _val], jac_node
    );
    return self.sync_loc(es.ExpressionStatement(expression=_call), jac_node=jac_node);
}

impl EsastGenPass.exit_unary_expr with uni.UnaryExpr exit {
    operand = cast(
        es.Expression,
        self._get_ast_or_default(
            here.operand, default_factory=lambda (_src: any) { es.Literal(value=0); }
        )
    );
    op_tok = Tok(here.op.name) if (here.op.name in Tok.__members__) else None;

    if op_tok in (Tok.MINUS, Tok.BW_NOT) {
        _fw_name = here.fw;
        if _fw_name is not None {
            if op_tok == Tok.MINUS and here.fw_safe {
                here.gen.es_ast = self.sync_loc(
                    es.UnaryExpression(operator='-', argument=operand, prefix=True),
                    jac_node=here
                );
                return;
            }
            here.gen.es_ast = self._fw_call(
                f"{'neg' if op_tok == Tok.MINUS else 'inv'}_{_fw_name}", [operand], here
            );
            return;
        }
    }

    _unary_emit_name = UNARY_EMIT_MAP.get(op_tok) if op_tok else None;
    if _unary_emit_name {
        _prim_result = self._try_primitive_op(
            here.operand, _unary_emit_name, operand, None, here
        );
        if _prim_result is not None {
            here.gen.es_ast = _prim_result;
            return;
        }
    }
    operator = ES_UNARY_OPS.get(op_tok) if op_tok else None;
    operator = operator or '!';

    if (op_tok == Tok.NOT) {
        operand = self._coerce_truthy(here.operand, operand, here);
    }
    unary_expr = self.sync_loc(
        es.UnaryExpression(operator=operator, prefix=True, argument=operand),
        jac_node=here
    );
    here.gen.es_ast = unary_expr;
}

impl EsastGenPass.exit_compare_expr with uni.CompareExpr exit {
    if (not here.rights or not here.ops) {
        here.gen.es_ast = self.sync_loc(es.Literal(value=True), jac_node=here);
        return;
    }
    comparisons: list[es.Expression] = [];
    left: es.Expression = cast(
        es.Expression,
        self._get_ast_or_default(
            here.left,
            default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Identifier(name='left'); }
        )
    );
    left_uni: uni.UniNode = here.left;
    for (op_token, right_node) in zip(here.ops, here.rights, strict=False) {
        right: es.Expression = cast(
            es.Expression,
            self._get_ast_or_default(
                right_node,
                default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                    if isinstance(src, uni.Name)
                    else es.Identifier(name='right'); }
            )
        );
        op_tok = Tok(op_token.name) if (op_token.name in Tok.__members__) else None;

        if (
            op_tok in (Tok.KW_IS, Tok.KW_ISN, Tok.EE, Tok.NE)
            and (self._is_null_literal(left_uni) or self._is_null_literal(right_node))
        ) {
            loose_op = '==' if (op_tok in (Tok.KW_IS, Tok.EE)) else '!=';
            comparisons.append(
                self.sync_loc(
                    es.BinaryExpression(operator=loose_op, left=left, right=right),
                    jac_node=here
                )
            );
            left = right;
            left_uni = right_node;
            continue;
        }

        _cmp_emit_name = CMP_EMIT_MAP.get(op_tok) if op_tok else None;
        if _cmp_emit_name {
            if op_tok in (Tok.KW_IN, Tok.KW_NIN) {
                _prim_result = self._try_primitive_op(
                    right_node, _cmp_emit_name, right, left, here
                );
            } else {
                _prim_result = self._try_primitive_op(
                    here.left, _cmp_emit_name, left, right, here
                );
            }
            if _prim_result is not None {
                if op_tok == Tok.KW_NIN {
                    comparison = self.sync_loc(
                        es.UnaryExpression(
                            operator='!', prefix=True, argument=_prim_result
                        ),
                        jac_node=here
                    );
                } else {
                    comparison = _prim_result;
                }
                comparisons.append(comparison);
                left = right;
                left_uni = right_node;
                continue;
            }
        }
        comparison: es.Expression;
        if (op_tok in (Tok.KW_IN, Tok.KW_NIN)) {
            contains_callee = self.sync_loc(
                es.MemberExpression(
                    object=self.sync_loc(
                        es.MemberExpression(
                            object=self.sync_loc(
                                es.Identifier(name='_jac'), jac_node=here
                            ),
                            property=self.sync_loc(
                                es.Identifier(name='poly'), jac_node=here
                            ),
                            computed=False
                        ),
                        jac_node=here
                    ),
                    property=self.sync_loc(
                        es.Identifier(name='contains'), jac_node=here
                    ),
                    computed=False
                ),
                jac_node=here
            );
            self.needs_jac_runtime = True;
            contains_call = self.sync_loc(
                es.CallExpression(
                    callee=cast(es.Expression, contains_callee),
                    arguments=[cast(es.Expression, right), cast(es.Expression, left)]
                ),
                jac_node=here
            );
            if (op_tok == Tok.KW_NIN) {
                comparison = self.sync_loc(
                    es.UnaryExpression(
                        operator='!',
                        prefix=True,
                        argument=cast(es.Expression, contains_call)
                    ),
                    jac_node=here
                );
            } else {
                comparison = cast(es.Expression, contains_call);
            }
        } else {
            operator = ES_COMPARISON_OPS.get(op_tok) if op_tok else None;
            operator = operator or '===';
            comparison = self.sync_loc(
                es.BinaryExpression(operator=operator, left=left, right=right),
                jac_node=here
            );
        }
        comparisons.append(comparison);
        left = right;
        left_uni = right_node;
    }
    if (len(comparisons) == 1) {
        here.gen.es_ast = comparisons[0];
    } else {
        result = comparisons[0];
        for comp in comparisons[1:] {
            result = self.sync_loc(
                es.LogicalExpression(operator='&&', left=result, right=comp),
                jac_node=here
            );
        }
        here.gen.es_ast = result;
    }
}

impl EsastGenPass._is_null_literal(nd: (uni.UniNode | None)) -> bool {
    if nd is None {
        return False;
    }
    return isinstance(nd, uni.Null)
        or (isinstance(nd, uni.Name) and nd.sym_name == 'None');
}

impl EsastGenPass.exit_cfg_expr with uni.CfgExpr exit {
    here.gen.es_ast = here.expr.gen.es_ast;
}

impl EsastGenPass.exit_bool_expr with uni.BoolExpr exit {
    if (not here.values or (len(here.values) < 2)) {
        here.gen.es_ast = self.sync_loc(es.Literal(value=None), jac_node=here);
        return;
    }
    op_tok = Tok(here.op.name) if (here.op.name in Tok.__members__) else None;
    logical_op = ES_LOGICAL_OPS.get(op_tok) if op_tok else None;
    logical_op = logical_op or '&&';

    _helper = "and_" if (op_tok == Tok.KW_AND) else "or_";
    result: es.Expression = cast(
        es.Expression,
        self._get_ast_or_default(
            here.values[0],
            default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );

    left_maybe_collection = self._is_collection_expr(here.values[0]);
    for val in here.values[1:] {
        right = cast(
            es.Expression,
            self._get_ast_or_default(
                val, default_factory=lambda (_src: any) { es.Literal(value=None); }
            )
        );
        if left_maybe_collection {
            right_thunk = self.sync_loc(
                es.ArrowFunctionExpression(params=[], body=right, expression=True),
                jac_node=here
            );
            result = self._build_jac_call(
                ["_jac", "poly", _helper],
                [result, cast(es.Expression, right_thunk)],
                here
            );
        } else {
            result = self.sync_loc(
                es.LogicalExpression(operator=logical_op, left=result, right=right),
                jac_node=here
            );
        }
        left_maybe_collection = left_maybe_collection or self._is_collection_expr(val);
    }
    here.gen.es_ast = result;
}

impl EsastGenPass.exit_binary_expr with uni.BinaryExpr exit {
    left = cast(
        es.Expression,
        self._get_ast_or_default(
            here.left,
            default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Literal(value=0); }
        )
    );
    right = cast(
        es.Expression,
        self._get_ast_or_default(
            here.right,
            default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Literal(value=0); }
        )
    );

    connect_call = self._build_osp_graph_call(here, left, right);
    if connect_call is not None {
        here.gen.es_ast = connect_call;
        return;
    }
    if isinstance(here.op, uni.DisconnectOp) {
        here.gen.es_ast = self._build_osp_disconnect_call(here, left, right);
        return;
    }
    op_name_str = here.op?.name;
    op_name = Tok(op_name_str) if (op_name_str in Tok.__members__) else None;
    if (op_name == Tok.KW_SPAWN) {
        local_spawn = self._build_local_osp_spawn(here, left, right);
        if local_spawn is not None {
            here.gen.es_ast = local_spawn;
            return;
        }
        spawn_parts = self._prepare_spawn_call(here, left, right);
        if spawn_parts {
            here.gen.es_ast = self._build_spawn_runtime_call(here, spawn_parts);
        }
        return;
    }
    if ((op_name == Tok.WALRUS_EQ) and isinstance(left, es.Identifier)) {
        self._ensure_identifier_declared(left.name, here.left);
        assign_expr = self.sync_loc(
            es.AssignmentExpression(operator='=', left=left, right=right), jac_node=here
        );
        here.gen.es_ast = assign_expr;
        return;
    }

    if op_name and op_name in FW_BINARY_OPS {
        _fw_result = self._fw_binary(here, FW_BINARY_OPS[op_name], left, right);
        if _fw_result is not None {
            here.gen.es_ast = _fw_result;
            return;
        }
    }
    if op_name {
        _op_emit_name = OP_EMIT_MAP.get(op_name);
        if _op_emit_name {
            _prim_result = self._try_primitive_op(
                here.left, _op_emit_name, left, right, here
            );
            if _prim_result is not None {
                here.gen.es_ast = _prim_result;
                return;
            }
        }
    }
    logical_op = ES_LOGICAL_OPS.get(op_name) if op_name else None;
    bin_expr: (es.LogicalExpression | es.BinaryExpression);
    if logical_op {
        bin_expr = self.sync_loc(
            es.LogicalExpression(operator=logical_op, left=left, right=right),
            jac_node=here
        );
    } else {
        operator = ES_BINARY_OPS.get(op_name) if op_name else '+';
        operator = operator or '+';
        if operator == '+'
            and (
                isinstance(left, es.ArrayExpression)
                or isinstance(right, es.ArrayExpression)
            ) {
            left_spread = es.SpreadElement(argument=left);
            right_spread = es.SpreadElement(argument=right);
            bin_expr = self.sync_loc(
                es.ArrayExpression(elements=[left_spread, right_spread]), jac_node=here
            );
        } else {
            bin_expr = self.sync_loc(
                es.BinaryExpression(operator=operator, left=left, right=right),
                jac_node=here
            );
        }
    }
    here.gen.es_ast = bin_expr;
}

impl EsastGenPass._fw_call(
    name: str, args: list[es.Expression], jac_node: uni.UniNode
) -> es.Expression {
    self.needs_jac_runtime = True;
    return self.sync_loc(
        es.CallExpression(
            callee=self._build_jac_ref(["_jac", "fw", name], jac_node), arguments=args
        ),
        jac_node=jac_node
    );
}

impl EsastGenPass._fw_js_binop(
    op: str, left: es.Expression, right: es.Expression, jac_node: uni.UniNode
) -> es.Expression {
    return self.sync_loc(
        es.BinaryExpression(operator=op, left=left, right=right), jac_node=jac_node
    );
}

impl EsastGenPass._fw_to_number(
    expr: es.Expression, jac_node: uni.UniNode
) -> es.Expression {
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name="Number"), jac_node=jac_node),
            arguments=[expr]
        ),
        jac_node=jac_node
    );
}

impl EsastGenPass._apply_fw_coercion(nd: uni.Expr) -> None {
    import from jaclang.runtime.scalars { shape_of }
    dst = nd.coerce_to;
    cur = nd.gen.es_ast;
    if dst is None or not isinstance(cur, es.Expression) {
        return;
    }
    dst_shape = shape_of(dst);
    if dst_shape is None {
        return;
    }
    if (
        dst_shape.sized
        and not dst_shape.is_float
        and dst_shape.width == 64
        and isinstance(cur, es.Literal)
        and isinstance(cur.value, int)
        and not isinstance(cur.value, bool)
    ) {
        nd.gen.es_ast = self.sync_loc(
            es.Literal(value=cur.value, raw=f"{cur.value}n"), jac_node=nd
        );
        return;
    }
    parent = nd.parent;
    if (
        isinstance(parent, uni.FuncCall)
        and isinstance(parent.target, uni.Name)
        and parent.target.sym_name == dst
        and parent.params is not None
        and len(parent.params) == 1
    ) {
        return;
    }
    src = nd.fw;
    src_shape = shape_of(src) if src is not None else None;
    src_big = (
        src_shape is not None
        and src_shape.sized
        and not src_shape.is_float
        and src_shape.width == 64
    );
    if dst == "f32" {
        nd.gen.es_ast = self._fw_call("r_f32", [cur], nd);
        return;
    }
    dst_big = dst_shape.sized and not dst_shape.is_float and dst_shape.width == 64;
    if dst_big {
        if not src_big {
            nd.gen.es_ast = self._fw_call(f"big_{dst}", [cur], nd);
        }
        return;
    }
    if src_big {
        nd.gen.es_ast = self._fw_to_number(cur, nd);
        return;
    }
    if src_shape is None
        and not (isinstance(cur, es.Literal) and isinstance(cur.value, (int, float))) {
        nd.gen.es_ast = self._fw_to_number(cur, nd);
    }
}

impl EsastGenPass._fw_binary(
    nd: uni.Expr, op: str, left: es.Expression, right: es.Expression
) -> (es.Expression | None) {
    import from jaclang.runtime.scalars { shape_of }
    name = nd.fw;
    if name is None {
        return None;
    }
    row = shape_of(name);
    if row is None or not row.sized {
        return None;
    }
    if row.is_float {
        helper = FW_JS_FLOAT_HELPERS.get(op, None);
        if helper is not None {
            return self._fw_call(f"{helper}_{name}", [left, right], nd);
        }
        raw = self._fw_js_binop(op, left, right, nd);
        if row.width == 32 {
            return self._fw_call("r_f32", [raw], nd);
        }
        return raw;
    }
    if op in FW_JS_PLAIN_OPS {
        raw = self._fw_js_binop(op, left, right, nd);
        if row.width == 32 and not row.signed {
            zero = self.sync_loc(es.Literal(value=0, raw="0"), jac_node=nd);
            return self._fw_js_binop(">>>", raw, zero, nd);
        }
        return raw;
    }
    if op in FW_JS_CHECKED_OPS {
        return self._fw_call(f"c_{name}", [self._fw_js_binop(op, left, right, nd)], nd);
    }
    helper = FW_JS_HELPER_OPS.get(op, None);
    if helper is None {
        return None;
    }
    return self._fw_call(f"{helper}_{name}", [left, right], nd);
}
