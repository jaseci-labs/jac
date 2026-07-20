import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

impl EsastGenPass._ensure_backend -> None {
    if self.backend is None {
        import from jaclang.compiler.passes.ecmascript.backends.registry {
            resolve_active_backend
        }
        try {
            self.backend = resolve_active_backend();
        } except ValueError {
            import from jaclang.project.config { get_config }
            import from jaclang.jac0core.diagnostics { E5081 }
            import from jaclang.compiler.passes.ecmascript.backends.react {
                ReactBackend
            }
            cfg = get_config();
            fw = cfg.client.framework if (cfg and cfg.client) else "unknown";
            self.emit(E5081, framework=fw);
            self.backend = ReactBackend();
        }
    }
}

impl EsastGenPass._literal_value(expr: (uni.UniNode | None)) -> (object | None) {
    if (expr is None) {
        return None;
    }
    if isinstance(expr, (uni.String, uni.Int, uni.Float, uni.Bool)) {
        return expr.lit_value;
    }
    if isinstance(expr, uni.MultiString) {
        parts: list[str | bytes] = [];
        for segment in expr.strings {
            if isinstance(segment, uni.String) {
                parts.append(segment.lit_value);
            } else {
                return None;
            }
        }
        if parts and isinstance(parts[0], `bytes) {
            return b''.join(parts);
        }
        return ''.join(parts);
    }
    if isinstance(expr, uni.ListVal) {
        values = [self._literal_value(item) for item in expr.values];
        if all((val is not None) for val in values) {
            return values;
        }
    }
    if isinstance(expr, uni.TupleVal) {
        values = [self._literal_value(item) for item in expr.values];
        if all((val is not None) for val in values) {
            return tuple(values);
        }
    }
    if isinstance(expr, uni.DictVal) {
        items: dict[(str, Any)] = {};
        for pair in expr.kv_pairs {
            if (isinstance(pair, uni.KVPair) and pair.key) {
                key_val = self._literal_value(pair.key);
                val_val = self._literal_value(pair.value);
                if (isinstance(key_val, str) and (val_val is not None)) {
                    items[key_val] = val_val;
                }
            }
        }
        if items {
            return items;
        }
    }
    return None;
}

impl EsastGenPass.exit_semi(nd: uni.Semi) -> None {
    ;
}

impl EsastGenPass.exit_token(nd: uni.Token) -> None {
    ;
}

impl EsastGenPass._collect_body_stmts(
    body: Sequence[uni.UniNode]
) -> list[es.Statement] {
    body_stmts: list[es.Statement] = [];
    if body {
        for stmt in body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, list) {
                    body_stmts.extend(cast(es.Statement, s) for s in stmt.gen.es_ast);
                } else {
                    body_stmts.append(cast(es.Statement, stmt.gen.es_ast));
                }
            }
        }
    }
    return body_stmts;
}

impl EsastGenPass.exit_test(nd: uni.Test) -> None {
    params: list[es.Pattern] = [];
    body_stmts = self._collect_body_stmts(nd.body);
    body_stmts = self._prepend_hoisted(nd, body_stmts);
    block = self.sync_loc(es.BlockStatement(body=body_stmts), jac_node=nd);
    func_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);

    func_decl = self.sync_loc(
        es.FunctionDeclaration(id=func_id, params=params, body=block, async_=True),
        jac_node=nd
    );
    nd.gen.es_ast = func_decl;

    self.client_manifest.has_client = True;
    self.client_manifest.tests.append(
        {
            'name': nd.name.sym_name,
            'description': nd.description.lit_value
                if nd.description
                else nd.name.sym_name
        }
    );
}

impl EsastGenPass.exit_client_block(nd: uni.ClientBlock) -> None {
    nd.gen.es_ast = self._collect_body_stmts(nd.body);
}

impl EsastGenPass.exit_native_block(nd: uni.NativeBlock) -> None {
    ;
}

impl EsastGenPass.exit_module_code(nd: uni.ModuleCode) -> None {
    nd.gen.es_ast = self._collect_body_stmts(nd.body);
}

impl EsastGenPass.exit_global_vars(nd: uni.GlobalVars) -> None {
    if nd.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub {
            for assignment in nd.assignments {
                for target in assignment.target {
                    if (sym_name := target?.sym_name) {
                        self.client_manifest.globals.append(sym_name);
                        if (
                            assignment.value
                            and (
                                (
                                    lit_val := self._literal_value(assignment.value)
                                ) is not None
                            )
                        ) {
                            self.client_manifest.globals_values[sym_name] = lit_val;
                        }
                    }
                }
            }
        }
    }
    statements: list[(es.Statement | es.ModuleDeclaration)] = [];
    for assignment in nd.assignments {
        if assignment.gen.es_ast {
            stmt = assignment.gen.es_ast;
            if (
                isinstance(stmt, es.VariableDeclaration)
                and nd.is_frozen
                and (stmt.kind != 'const')
            ) {
                stmt.kind = 'const';
            }
            statements.append(cast(es.Statement, stmt));
        }
    }
    nd.gen.es_ast = statements;
}

impl EsastGenPass.exit_name(nd: uni.Name) -> None {
    if nd.sym_name in self.reactive_vars {
        self._ensure_backend();
        nd.gen.es_ast = self.sync_loc(
            self.backend.lower_state_read(nd.sym_name), jac_node=nd
        );
        return;
    }
    name_map = {'None': 'null', 'True': 'true', 'False': 'false', 'self': 'this'};
    name = name_map.get(nd.sym_name, nd.sym_name);
    identifier = self.sync_loc(es.Identifier(name=name), jac_node=nd);
    nd.gen.es_ast = identifier;
}

impl EsastGenPass._in_type_slot(nd: uni.UniNode) -> bool {
    child = nd;
    parent = nd.parent;
    while parent is not None {
        if (
            isinstance(parent, uni.SubTag)
            or (isinstance(parent, uni.FuncSignature) and parent.return_type is child)
            or (isinstance(parent, uni.CastExpr) and parent.cast_type is child)
            or (isinstance(parent, uni.TypedCtxBlock) and parent.type_ctx is child)
            or (isinstance(parent, uni.Except) and parent.ex_type is child)
        ) {
            return True;
        }
        child = parent;
        parent = parent.parent;
    }
    return False;
}

impl EsastGenPass._is_call_target(nd: uni.UniNode) -> bool {
    return isinstance(nd.parent, uni.FuncCall) and nd.parent.target is nd;
}

impl EsastGenPass.exit_builtin_type(nd: uni.BuiltinType) -> None {
    type_name = nd.sym_name;
    self._ensure_emitters();
    if (
        not self._in_type_slot(nd)
        and getattr(self._builtin_emitter, "emit_" + type_name, None) is not None
    ) {
        nd.gen.es_ast = self.sync_loc(
            es.MemberExpression(
                object=es.MemberExpression(
                    object=es.Identifier(name='_jac'),
                    property=es.Identifier(name='types'),
                    computed=False
                ),
                property=es.Identifier(name=type_name),
                computed=False
            ),
            jac_node=nd
        );
        if not self._is_call_target(nd) {
            self.needs_jac_runtime = True;
        }
        return;
    }
    tag = self.sync_loc(
        es.Literal(value=type_name, raw=json.dumps(type_name)), jac_node=nd
    );
    nd.gen.es_ast = tag;
}

impl EsastGenPass.exit_null(nd: uni.Null) -> None {
    null_lit = self.sync_loc(es.Literal(value=None, raw='null'), jac_node=nd);
    nd.gen.es_ast = null_lit;
}

impl EsastGenPass.exit_await_expr(nd: uni.AwaitExpr) -> None {
    argument = cast(
        es.Expression,
        nd.target.gen.es_ast
        or self.sync_loc(es.Identifier(name='undefined'), jac_node=nd.target)
    );
    await_expr = self.sync_loc(es.AwaitExpression(argument=argument), jac_node=nd);
    nd.gen.es_ast = await_expr;
}

impl EsastGenPass.exit_cast_expr(nd: uni.CastExpr) -> None {
    nd.gen.es_ast = nd.value.gen.es_ast;
}

impl EsastGenPass.exit_if_else_expr(nd: uni.IfElseExpr) -> None {
    `test = self._coerce_truthy(
        nd.condition,
        cast(
            es.Expression,
            nd.condition.gen.es_ast
            or self.sync_loc(es.Identifier(name='condition'), jac_node=nd.condition)
        ),
        nd
    );
    consequent = cast(
        es.Expression,
        nd.value.gen.es_ast
        or self.sync_loc(es.Identifier(name='value'), jac_node=nd.value)
    );
    alternate = cast(
        es.Expression,
        nd.else_value.gen.es_ast
        or self.sync_loc(es.Identifier(name='alternate'), jac_node=nd.else_value)
    );
    cond_expr = self.sync_loc(
        es.ConditionalExpression(
            `test=`test, consequent=consequent, alternate=alternate
        ),
        jac_node=nd
    );
    nd.gen.es_ast = cond_expr;
}

impl EsastGenPass.exit_f_string(nd: uni.FString) -> None {
    quasis: list[es.TemplateElement] = [];
    expressions: list[es.Expression] = [];
    for (i, part) in enumerate(nd.parts) {
        is_last = i == (len(nd.parts) - 1);
        if isinstance(part, uni.String) {
            value = part.value;
            if value.startswith(('"""', "'''")) {
                value = value[3:-3];
            } elif value.startswith(('"', "'")) {
                value = value[1:-1];
            }
            elem = self.sync_loc(
                es.TemplateElement(tail=is_last, value={'cooked': value, 'raw': value}),
                jac_node=part
            );
            quasis.append(elem);
        } elif isinstance(part, uni.FormattedValue) {
            if ((i == 0) or not isinstance(nd.parts[(i - 1)], uni.String)) {
                empty_elem = self.sync_loc(
                    es.TemplateElement(tail=False, value={'cooked': '', 'raw': ''}),
                    jac_node=part
                );
                quasis.append(empty_elem);
            }
            expr = cast(
                es.Expression,
                part.gen.es_ast or self.sync_loc(es.Literal(value=''), jac_node=part)
            );
            expressions.append(expr);
            if is_last {
                empty_elem = self.sync_loc(
                    es.TemplateElement(tail=True, value={'cooked': '', 'raw': ''}),
                    jac_node=part
                );
                quasis.append(empty_elem);
            }
        }
    }
    if not quasis {
        quasis.append(
            self.sync_loc(
                es.TemplateElement(tail=True, value={'cooked': '', 'raw': ''}),
                jac_node=nd
            )
        );
    }
    while (len(quasis) < (len(expressions) + 1)) {
        quasis.append(
            self.sync_loc(
                es.TemplateElement(tail=True, value={'cooked': '', 'raw': ''}),
                jac_node=nd
            )
        );
    }
    template_lit = self.sync_loc(
        es.TemplateLiteral(quasis=quasis, expressions=expressions), jac_node=nd
    );
    nd.gen.es_ast = template_lit;
}

impl EsastGenPass.exit_formatted_value(nd: uni.FormattedValue) -> None {
    expr = nd.format_part.gen.es_ast
    or self.sync_loc(es.Literal(value=''), jac_node=nd.format_part);
    if nd.format_spec is not None {
        spec_es = nd.format_spec.gen.es_ast
        or self.sync_loc(es.Literal(value=''), jac_node=nd.format_spec);
        format_callee = self.sync_loc(
            es.MemberExpression(
                object=self.sync_loc(
                    es.MemberExpression(
                        object=self.sync_loc(es.Identifier(name='_jac'), jac_node=nd),
                        property=self.sync_loc(
                            es.Identifier(name='builtin'), jac_node=nd
                        ),
                        computed=False
                    ),
                    jac_node=nd
                ),
                property=self.sync_loc(es.Identifier(name='format'), jac_node=nd),
                computed=False
            ),
            jac_node=nd
        );
        self.needs_jac_runtime = True;
        nd.gen.es_ast = self.sync_loc(
            es.CallExpression(
                callee=cast(es.Expression, format_callee),
                arguments=[cast(es.Expression, expr), cast(es.Expression, spec_es)]
            ),
            jac_node=nd
        );
        return;
    }
    nd.gen.es_ast = expr;
}

impl EsastGenPass._str_literal(nd: uni.String) -> es.Literal {
    decoded = nd.lit_value;
    if isinstance(decoded, str) {
        return self.sync_loc(
            es.Literal(value=decoded, raw=json.dumps(decoded)), jac_node=nd
        );
    }

    raw_token = nd.value;
    fallback_raw = json.dumps(raw_token) if isinstance(raw_token, str) else None;
    return self.sync_loc(es.Literal(value=raw_token, raw=fallback_raw), jac_node=nd);
}

impl EsastGenPass.exit_string(nd: uni.String) -> None {
    nd.gen.es_ast = self._str_literal(nd);
}

impl EsastGenPass.exit_multi_string(nd: uni.MultiString) -> None {
    if not nd.strings {
        null_lit = self.sync_loc(es.Literal(value='', raw='""'), jac_node=nd);
        nd.gen.es_ast = null_lit;
        return;
    }
    if (len(nd.strings) == 1) {
        string_node = nd.strings[0];
        if string_node.gen.es_ast {
            nd.gen.es_ast = string_node.gen.es_ast;
        } elif isinstance(string_node, uni.String) {
            nd.gen.es_ast = self._str_literal(string_node);
        } else {
            nd.gen.es_ast = self.sync_loc(es.Literal(value=''), jac_node=nd);
        }
        return;
    }
    parts = [];
    for string_node in nd.strings {
        if string_node.gen.es_ast {
            parts.append(string_node.gen.es_ast);
        } elif isinstance(string_node, uni.String) {
            parts.append(self._str_literal(string_node));
        }
    }
    if not parts {
        nd.gen.es_ast = self.sync_loc(es.Literal(value=''), jac_node=nd);
        return;
    }
    result: es.Expression = cast(es.Expression, parts[0]);
    for part in parts[1:] {
        result = self.sync_loc(
            es.BinaryExpression(
                operator='+', left=result, right=cast(es.Expression, part)
            ),
            jac_node=nd
        );
    }
    nd.gen.es_ast = result;
}

impl EsastGenPass.exit_float(nd: uni.Float) -> None {
    float_lit = self.sync_loc(
        es.Literal(value=float(nd.value), raw=nd.value), jac_node=nd
    );
    nd.gen.es_ast = float_lit;
}

impl EsastGenPass.exit_int(nd: uni.Int) -> None {
    int_lit = self.sync_loc(
        es.Literal(value=int(nd.value, 0), raw=nd.value), jac_node=nd
    );
    nd.gen.es_ast = int_lit;
}

impl EsastGenPass.exit_bool(nd: uni.Bool) -> None {
    value = nd.value.lower() == 'true';
    raw_value = 'true' if value else 'false';
    bool_lit = self.sync_loc(es.Literal(value=value, raw=raw_value), jac_node=nd);
    nd.gen.es_ast = bool_lit;
}

impl EsastGenPass.exit_inner_compr(nd: uni.InnerCompr) -> None {
    ;
}

impl EsastGenPass.exit_list_compr(nd: uni.ListCompr) -> None {
    self._build_compr_chain(nd);
}

impl EsastGenPass.exit_set_compr(nd: uni.SetCompr) -> None {
    self._build_compr_chain(nd);
    if nd.gen.es_ast {
        nd.gen.es_ast = self.sync_loc(
            es.NewExpression(
                callee=self.sync_loc(es.Identifier(name='Set'), jac_node=nd),
                arguments=[cast(es.Expression, nd.gen.es_ast)]
            ),
            jac_node=nd
        );
    }
}

impl EsastGenPass.exit_gen_compr(nd: uni.GenCompr) -> None {
    self._build_compr_chain(nd);
}

impl EsastGenPass.exit_dict_compr(nd: uni.DictCompr) -> None {
    key_expr = cast(es.Expression, nd.kv_pair.key.gen.es_ast)
        if nd.kv_pair.key
        else None;
    val_expr = cast(es.Expression, nd.kv_pair.value.gen.es_ast);
    if not key_expr or not val_expr {
        nd.gen.es_ast = self.sync_loc(es.ObjectExpression(properties=[]), jac_node=nd);
        return;
    }

    out_expr = self.sync_loc(
        es.ArrayExpression(elements=[key_expr, val_expr]), jac_node=nd.kv_pair
    );

    chain = self._build_compr_expr(nd.compr, out_expr, nd);
    if not chain {
        nd.gen.es_ast = self.sync_loc(es.ObjectExpression(properties=[]), jac_node=nd);
        return;
    }

    nd.gen.es_ast = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.MemberExpression(
                    object=self.sync_loc(es.Identifier(name='Object'), jac_node=nd),
                    property=self.sync_loc(
                        es.Identifier(name='fromEntries'), jac_node=nd
                    ),
                    computed=False
                ),
                jac_node=nd
            ),
            arguments=[chain]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._build_compr_chain(nd: uni.ListCompr) -> None {
    out_expr = cast(es.Expression, nd.out_expr.gen.es_ast);
    if not out_expr {
        nd.gen.es_ast = self.sync_loc(es.ArrayExpression(elements=[]), jac_node=nd);
        return;
    }
    if not nd.compr or len(nd.compr) == 0 {
        nd.gen.es_ast = self.sync_loc(
            es.ArrayExpression(elements=[out_expr]), jac_node=nd
        );
        return;
    }
    result = self._build_compr_expr(nd.compr, out_expr, nd);
    if result {
        nd.gen.es_ast = result;
    } else {
        nd.gen.es_ast = self.sync_loc(es.ArrayExpression(elements=[]), jac_node=nd);
    }
}

impl EsastGenPass._build_compr_expr(
    comprs: list[uni.InnerCompr], out_expr: es.Expression, nd: uni.UniNode
) -> (es.Expression | None) {
    if not comprs or len(comprs) == 0 {
        return None;
    }

    result: (es.Expression | None) = None;
    i = len(comprs) - 1;
    while i >= 0 {
        compr = comprs[i];
        collection = cast(es.Expression, compr.collection.gen.es_ast);
        target = cast(es.Expression, compr.target.gen.es_ast);
        if not collection or not target {
            return None;
        }
        param = self._compr_param(target, compr.target);

        chain = collection;

        if compr.conditional {
            for cond in compr.conditional {
                cond_expr = cast(es.Expression, cond.gen.es_ast);
                if cond_expr {
                    filter_arrow = self.sync_loc(
                        es.ArrowFunctionExpression(
                            params=[param], body=cond_expr, expression=True
                        ),
                        jac_node=cond
                    );
                    chain = self.sync_loc(
                        es.CallExpression(
                            callee=self.sync_loc(
                                es.MemberExpression(
                                    object=chain,
                                    property=self.sync_loc(
                                        es.Identifier(name='filter'), jac_node=cond
                                    ),
                                    computed=False
                                ),
                                jac_node=cond
                            ),
                            arguments=[filter_arrow]
                        ),
                        jac_node=cond
                    );
                }
            }
        }
        if i == len(comprs) - 1 {
            map_arrow = self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[param], body=out_expr, expression=True
                ),
                jac_node=nd
            );
            result = self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.MemberExpression(
                            object=chain,
                            property=self.sync_loc(
                                es.Identifier(name='map'), jac_node=nd
                            ),
                            computed=False
                        ),
                        jac_node=nd
                    ),
                    arguments=[map_arrow]
                ),
                jac_node=nd
            );
        } else {
            flat_arrow = self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[param], body=cast(es.Expression, result), expression=True
                ),
                jac_node=nd
            );
            result = self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.MemberExpression(
                            object=chain,
                            property=self.sync_loc(
                                es.Identifier(name='flatMap'), jac_node=nd
                            ),
                            computed=False
                        ),
                        jac_node=nd
                    ),
                    arguments=[flat_arrow]
                ),
                jac_node=nd
            );
        }
        i -= 1;
    }
    return cast(es.Expression, result);
}

impl EsastGenPass._compr_param(
    target: es.Expression, jac_node: uni.UniNode
) -> es.Node {
    if isinstance(target, es.Identifier) {
        return self.sync_loc(es.Identifier(name=target.name), jac_node=jac_node);
    }
    if isinstance(target, es.ArrayExpression) {
        elements: list[(es.Node | None)] = [];
        for elem in target.elements {
            if isinstance(elem, es.Identifier) {
                elements.append(
                    self.sync_loc(es.Identifier(name=elem.name), jac_node=jac_node)
                );
            }
        }
        return self.sync_loc(es.ArrayPattern(elements=elements), jac_node=jac_node);
    }

    return self.sync_loc(es.Identifier(name='x'), jac_node=jac_node);
}

impl EsastGenPass.exit_k_v_pair(nd: uni.KVPair) -> None {
    ;
}

impl EsastGenPass.exit_dict_val(nd: uni.DictVal) -> None {
    properties: list[(es.Property | es.SpreadElement)] = [];
    for kv_pair in nd.kv_pairs {
        if (not isinstance(kv_pair, uni.KVPair) or (kv_pair.value is None)) {
            continue;
        }
        if (kv_pair.key is None) {
            if kv_pair.value.gen.es_ast {
                properties.append(
                    self.sync_loc(
                        es.SpreadElement(
                            argument=cast(es.Expression, kv_pair.value.gen.es_ast)
                        ),
                        jac_node=kv_pair.value
                    )
                );
            }
            continue;
        }
        key = cast(
            es.Expression,
            kv_pair.key.gen.es_ast
            or self.sync_loc(es.Literal(value='key'), jac_node=kv_pair.key)
        );
        value = cast(
            es.Expression,
            kv_pair.value.gen.es_ast
            or self.sync_loc(es.Literal(value=None), jac_node=kv_pair.value)
        );
        prop = self.sync_loc(
            es.Property(key=key, value=value, kind='init'), jac_node=kv_pair
        );
        properties.append(prop);
    }
    obj_expr = self.sync_loc(es.ObjectExpression(properties=properties), jac_node=nd);
    nd.gen.es_ast = obj_expr;
}

impl EsastGenPass._gen_seq_array(nd: uni.UniNode) -> None {
    elements: list[es.Expression | es.SpreadElement | None] = [];
    for item in nd.values {
        if (
            isinstance(item, uni.UnaryExpr)
            and item.op.name == Tok.STAR_MUL.value
            and item.operand.gen.es_ast
        ) {
            elements.append(
                self.sync_loc(
                    es.SpreadElement(
                        argument=cast(es.Expression, item.operand.gen.es_ast)
                    ),
                    jac_node=item
                )
            );
        } elif item.gen.es_ast {
            elements.append(cast(es.Expression, item.gen.es_ast));
        }
    }
    array_expr = self.sync_loc(es.ArrayExpression(elements=elements), jac_node=nd);
    nd.gen.es_ast = array_expr;
}

impl EsastGenPass.exit_tuple_val(nd: uni.TupleVal) -> None {
    self._gen_seq_array(nd);
}

impl EsastGenPass.exit_set_val(nd: uni.SetVal) -> None {
    elements: list[es.Expression | es.SpreadElement | None] = [];
    for item in nd.values {
        if item.gen.es_ast {
            elements.append(cast(es.Expression, item.gen.es_ast));
        }
    }
    set_expr = self.sync_loc(
        es.NewExpression(
            callee=self.sync_loc(es.Identifier(name='Set'), jac_node=nd),
            arguments=[
                self.sync_loc(es.ArrayExpression(elements=elements), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
    nd.gen.es_ast = set_expr;
}

impl EsastGenPass.exit_list_val(nd: uni.ListVal) -> None {
    self._gen_seq_array(nd);
}

impl EsastGenPass.exit_atom_unit(nd: uni.AtomUnit) -> None {
    if (isinstance(nd.value, uni.Ability) and nd.value.gen.es_ast) {
        func_decl = nd.value.gen.es_ast;
        if isinstance(func_decl, es.FunctionDeclaration) {
            func_expr = self.sync_loc(
                es.FunctionExpression(
                    id=func_decl.id,
                    params=func_decl.params,
                    body=func_decl.body,
                    async_=func_decl.async_
                ),
                jac_node=nd.value
            );
            nd.gen.es_ast = func_expr;
        } else {
            nd.gen.es_ast = nd.value.gen.es_ast;
        }
    } elif (nd.value and nd.value.gen.es_ast) {
        nd.gen.es_ast = nd.value.gen.es_ast;
    } else {
        nd.gen.es_ast = self.sync_loc(es.Literal(value=None), jac_node=nd);
    }
}

impl EsastGenPass.exit_lambda_expr(nd: uni.LambdaExpr) -> None {
    params: list[es.Pattern] = [];
    if isinstance(nd.signature, uni.FuncSignature) {
        for param in nd.signature.get_parameters() {
            if param.gen.es_ast {
                params.append(cast(es.Pattern, param.gen.es_ast));
            }
        }
    }
    tail = nd.tail_return_expr();
    if (tail is not None and isinstance(nd.body, list)) {
        body_expr = cast(
            es.Expression,
            tail.gen.es_ast or self.sync_loc(es.Literal(value=None), jac_node=tail)
        );
        nd.gen.es_ast = self.sync_loc(
            es.ArrowFunctionExpression(params=params, body=body_expr, async_=False),
            jac_node=nd
        );
    } elif isinstance(nd.body, list) {
        body_stmts: list[es.Statement] = [];
        for stmt in nd.body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, list) {
                    body_stmts.extend(stmt.gen.es_ast);
                } else {
                    body_stmts.append(stmt.gen.es_ast);
                }
            }
        }
        body_stmts = self._prepend_hoisted(nd, body_stmts);
        block_stmt = self.sync_loc(es.BlockStatement(body=body_stmts), jac_node=nd);
        arrow_func = self.sync_loc(
            es.ArrowFunctionExpression(params=params, body=block_stmt, async_=False),
            jac_node=nd
        );
        nd.gen.es_ast = arrow_func;
    } elif isinstance(nd.body, uni.Expr) {
        body_expr = cast(
            es.Expression,
            nd.body.gen.es_ast
            or self.sync_loc(es.Literal(value=None), jac_node=nd.body)
        );
        arrow_func = self.sync_loc(
            es.ArrowFunctionExpression(params=params, body=body_expr, async_=False),
            jac_node=nd
        );
        nd.gen.es_ast = arrow_func;
    }
}

impl EsastGenPass.exit_atom_trailer(nd: uni.AtomTrailer) -> None {
    `obj = cast(
        es.Expression,
        nd.target.gen.es_ast
        or self.sync_loc(es.Identifier(name='obj'), jac_node=nd.target)
    );
    if (nd.right and nd.right.gen.es_ast) {
        if isinstance(nd.right, uni.Name) {
            prop = self.sync_loc(
                es.Identifier(name=nd.right.sym_name), jac_node=nd.right
            );
            member_expr = self.sync_loc(
                es.MemberExpression(object=`obj, property=prop, computed=False),
                jac_node=nd
            );
            nd.gen.es_ast = member_expr;
        } elif isinstance(nd.right, uni.IndexSlice) {
            slice_info = nd.right.gen.es_ast;
            if isinstance(slice_info, es.SliceInfo) {
                start = cast(
                    es.Expression,
                    (
                        slice_info.start
                        or self.sync_loc(es.Literal(value=0), jac_node=nd)
                    )
                );
                stop = slice_info.stop;
                slice_args: list[(es.Expression | es.SpreadElement)] = [start];
                if (stop is not None) {
                    slice_args.append(cast(es.Expression, stop));
                }
                slice_call = self.sync_loc(
                    es.CallExpression(
                        callee=self.sync_loc(
                            es.MemberExpression(
                                object=`obj,
                                property=self.sync_loc(
                                    es.Identifier(name='slice'), jac_node=nd
                                ),
                                computed=False
                            ),
                            jac_node=nd
                        ),
                        arguments=slice_args
                    ),
                    jac_node=nd
                );
                nd.gen.es_ast = slice_call;
            } elif isinstance(slice_info, es.IndexInfo) {
                idx = cast(
                    es.Expression,
                    (
                        slice_info.value
                        or self.sync_loc(es.Literal(value=0), jac_node=nd)
                    )
                );
                nd.gen.es_ast = self._lower_subscript(nd.target, `obj, idx, nd);
            } else {
                nd.gen.es_ast = `obj;
            }
        } else {
            nd.gen.es_ast = nd.right.gen.es_ast;
        }
    }
}

impl EsastGenPass.exit_special_var_ref(nd: uni.SpecialVarRef) -> None {
    self.exit_name(nd);
}

impl EsastGenPass.exit_index_slice(nd: uni.IndexSlice) -> None {
    if (nd.slices and (len(nd.slices) > 0)) {
        first_slice = nd.slices[0];
        if nd.is_range {
            start_ast = first_slice.start.gen.es_ast
                if (
                    first_slice.start
                    and first_slice.start.gen.es_ast
                    and isinstance(first_slice.start.gen.es_ast, es.Node)
                )
                else None;
            stop_ast = first_slice.stop.gen.es_ast
                if (
                    first_slice.stop
                    and first_slice.stop.gen.es_ast
                    and isinstance(first_slice.stop.gen.es_ast, es.Node)
                )
                else None;
            nd.gen.es_ast = es.SliceInfo(start=start_ast, stop=stop_ast);
        } else {
            value_ast = first_slice.start.gen.es_ast
                if (
                    first_slice.start
                    and first_slice.start.gen.es_ast
                    and isinstance(first_slice.start.gen.es_ast, es.Node)
                )
                else self.sync_loc(es.Literal(value=0), jac_node=nd);
            nd.gen.es_ast = es.IndexInfo(value=value_ast);
        }
    } else {
        nd.gen.es_ast = None;
    }
}

impl EsastGenPass._resolve_source_module(nd: uni.Import) -> (uni.Module | None) {
    if not nd.from_loc {
        return None;
    }
    import from pathlib { Path }
    resolved_path = nd.from_loc.resolve_relative_path();
    abs_path = str(Path(resolved_path).resolve());
    source_mod = self.prog.mod.hub.get(resolved_path)
    or self.prog.mod.hub.get(abs_path);
    if source_mod {
        return source_mod;
    }
    if Path(resolved_path).exists() {
        source_mod = self.prog.compile(
            resolved_path, no_cgen=True, type_check=False, symtab_ir_only=True
        );
        self.prog.mod.hub[abs_path] = source_mod;
        return source_mod;
    }
    return None;
}

impl EsastGenPass._record_sv_backend(nd: uni.Import) -> None {
    import from pathlib { Path }
    if not nd.from_loc {
        return;
    }
    resolved_path = nd.from_loc.resolve_relative_path();
    if not resolved_path {
        return;
    }
    abs_path = str(Path(resolved_path).resolve());
    if abs_path.endswith(".jac")
    and Path(abs_path).exists()
    and (abs_path not in self.client_manifest.server_imports) {
        self.client_manifest.server_imports.append(abs_path);
    }
}

impl EsastGenPass._resolve_call_ability(nd: uni.FuncCall) -> (uni.Ability | None) {
    import from jaclang.compiler.symbol_utils { ability_of_symbol }

    if nd.callee_decl is not None {
        return nd.callee_decl;
    }
    if isinstance(nd.target, uni.Name) {
        ability_node = ability_of_symbol(nd.target.sym);
        if ability_node {
            return ability_node;
        }

        manifest = self.ir_in.gen.interop_manifest;
        binding = manifest.bindings.get(nd.target.sym_name) if manifest else None;
        if binding and isinstance(binding.ast_node, uni.Ability) {
            return binding.ast_node;
        }
        return None;
    }
    if isinstance(nd.target, uni.AtomTrailer)
    and isinstance(nd.target.right, uni.Name) {
        return ability_of_symbol(nd.target.right.sym);
    }
    return None;
}

impl EsastGenPass._return_type_includes_jsx_element(rt: uni.Expr) -> bool {
    if (
        isinstance(rt, uni.BinaryExpr)
        and isinstance(rt.op, uni.Token)
        and rt.op.name == Tok.BW_OR
    ) {
        return (
            self._return_type_includes_jsx_element(rt.left)
            or self._return_type_includes_jsx_element(rt.right)
        );
    }
    return isinstance(rt, uni.Name) and rt.value == 'JsxElement';
}

impl EsastGenPass._component_pascal_name(nd: uni.Ability) -> (str | None) {
    if nd.code_context != CodeContext.CLIENT or nd.is_method {
        return None;
    }
    if not isinstance(nd.signature, uni.FuncSignature) {
        return None;
    }
    rt = nd.signature.return_type;
    if rt is None or not self._return_type_includes_jsx_element(rt) {
        return None;
    }
    name = nd.name_ref.sym_name;
    if not name or not ('a' <= name[0] and name[0] <= 'z') {
        return None;
    }
    pascal = name[0].upper() + name[1:];
    mod = nd.find_parent_of_type(uni.Module);
    if mod is not None and mod.lookup(pascal, deep=False) is not None {
        return None;
    }
    return pascal;
}

impl EsastGenPass._component_call_abi(ability_node: uni.Ability) -> str {
    cached_abi = ability_node.gen?.component_call_abi;
    if isinstance(cached_abi, str) and cached_abi {
        return cached_abi;
    }
    abi = 'direct';
    if isinstance(ability_node.signature, uni.FuncSignature) {
        sig = ability_node.signature;
        if sig.get_parameters() {
            rt = sig.return_type;

            if rt is not None and self._return_type_includes_jsx_element(rt) {
                if (
                    ability_node.name_ref
                    and ability_node.name_ref.sym_name
                    and ability_node.name_ref.sym_name.startswith('__jac')
                ) {
                    abi = 'direct';
                } else {
                    all_pos_params = self._pos_params_from_ability(ability_node);
                    if (
                        len(all_pos_params) == 1
                        and all_pos_params[0].name.sym_name == 'props'
                    ) {
                        abi = 'props_passthrough';
                    } else {
                        abi = 'props_destructure';
                    }
                }
            }
        }
    }
    ability_node.gen.component_call_abi = abi;
    return abi;
}

impl EsastGenPass._build_props_spread_component_call(
    nd: uni.FuncCall,
    callee_expr: es.Expression,
    ability_node: uni.Ability,
    args: list[(es.Expression | es.SpreadElement)],
    props: list[(es.Property | es.SpreadElement)]
) -> es.Expression {
    param_names = self._param_names_from_ability(ability_node);
    packed_args = self.sync_loc(es.ArrayExpression(elements=args), jac_node=nd);
    packed_kwargs = self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);
    args_id = self.sync_loc(es.Identifier(name='__jac_args'), jac_node=nd);
    kwargs_id = self.sync_loc(es.Identifier(name='__jac_kwargs'), jac_node=nd);
    wrap_props: list[es.Property] = [];
    for (i, pname) in enumerate(param_names) {
        len_expr = self.sync_loc(
            es.MemberExpression(
                object=args_id, property=es.Identifier(name='length'), computed=False
            ),
            jac_node=nd
        );
        pos_exists = self.sync_loc(
            es.BinaryExpression(
                operator='>',
                left=len_expr,
                right=self.sync_loc(es.Literal(value=i), jac_node=nd)
            ),
            jac_node=nd
        );
        pos_value = self.sync_loc(
            es.MemberExpression(
                object=args_id,
                property=self.sync_loc(es.Literal(value=i), jac_node=nd),
                computed=True
            ),
            jac_node=nd
        );
        kw_value = self.sync_loc(
            es.MemberExpression(
                object=kwargs_id,
                property=self.sync_loc(es.Literal(value=pname), jac_node=nd),
                computed=True
            ),
            jac_node=nd
        );
        wrap_props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Identifier(name=pname), jac_node=nd),
                    value=self.sync_loc(
                        es.ConditionalExpression(
                            `test=pos_exists, consequent=pos_value, alternate=kw_value
                        ),
                        jac_node=nd
                    ),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=nd
            )
        );
    }
    inner_call = self.sync_loc(
        es.CallExpression(
            callee=callee_expr,
            arguments=[
                self.sync_loc(es.ObjectExpression(properties=wrap_props), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[args_id, kwargs_id],
                    body=inner_call,
                    expression=True,
                    async_=False
                ),
                jac_node=nd
            ),
            arguments=[packed_args, packed_kwargs]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._pos_params_from_ability(
    ability_node: uni.Ability
) -> list[uni.ParamVar] {
    sig = ability_node.signature;
    return (sig.posonly_params or []) + (sig.params or []);
}

impl EsastGenPass._param_names_from_ability(ability_node: uni.Ability) -> list[str] {
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return [];
    }
    sig = ability_node.signature;
    names: list[str] = [];
    for p in self._pos_params_from_ability(ability_node) {
        names.append(p.name.sym_name);
    }
    for p in sig.kwonlyargs {
        names.append(p.name.sym_name);
    }
    return names;
}

impl EsastGenPass._param_type_map_from_ability(
    ability_node: uni.Ability
) -> dict[(str, str)] {
    type_map: dict[(str, str)] = {};
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return type_map;
    }
    sig = ability_node.signature;
    param_lists = [sig.posonly_params, sig.params or [], sig.kwonlyargs];
    for params in param_lists {
        for p in params {
            if (
                p.type_tag and p.type_tag.tag and isinstance(p.type_tag.tag, uni.Name)
            ) {
                type_map[p.name.sym_name] = p.type_tag.tag.value;
            }
        }
    }
    return type_map;
}

impl EsastGenPass._extract_return_type(
    ability_node: uni.Ability, func_name: str, manifest: any
) -> str {
    if manifest {
        for b in manifest.server_exports_to_client {
            if b.name == func_name {
                return b.ret_type;
            }
        }
    }
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return '';
    }
    rt = ability_node.signature.return_type;
    if rt is None {
        return '';
    }
    if isinstance(rt, uni.Name) {
        return rt.value;
    }
    if isinstance(rt, uni.AtomTrailer) and isinstance(rt.target, uni.Name) {
        base = rt.target.value;
        if rt.right and isinstance(rt.right, uni.Name) {
            return f"{base}[{rt.right.value}]";
        }
        return base;
    }
    return '';
}

impl EsastGenPass._wrap_return_with_boundary(
    call_expr: es.Expression,
    ret_type: str,
    boundary_types: dict[(str, Any)],
    jac_node: uni.UniNode,
    pre_awaited: bool
) -> es.Expression {
    awaited_call = call_expr
        if pre_awaited
        else self.sync_loc(es.AwaitExpression(argument=call_expr), jac_node=jac_node);

    if (ret_type in boundary_types and boundary_types[ret_type].kind != "enum") {
        return self.sync_loc(
            es.CallExpression(
                callee=es.MemberExpression(
                    object=es.Identifier(name=ret_type),
                    property=es.Identifier(name='__from_wire'),
                    computed=False
                ),
                arguments=[awaited_call]
            ),
            jac_node=jac_node
        );
    }

    if ret_type.startswith("list[") and ret_type.endswith("]") {
        inner = ret_type[5:-1];
        if inner in boundary_types and boundary_types[inner].kind != "enum" {
            return self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=awaited_call,
                        property=es.Identifier(name='map'),
                        computed=False
                    ),
                    arguments=[
                        es.ArrowFunctionExpression(
                            params=[es.Identifier(name='x')],
                            body=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name=inner),
                                    property=es.Identifier(name='__from_wire'),
                                    computed=False
                                ),
                                arguments=[es.Identifier(name='x')]
                            ),
                            expression=True,
                            async_=False
                        )
                    ]
                ),
                jac_node=jac_node
            );
        }
    }

    if ret_type.startswith("dict[") and ret_type.endswith("]") {
        dict_params = ret_type[5:-1];
        comma_pos = dict_params.find(', ');
        if comma_pos >= 0 {
            val_type = dict_params[comma_pos + 2:].strip();
            if (
                val_type in boundary_types and boundary_types[val_type].kind != "enum"
            ) {
                entries_call = es.CallExpression(
                    callee=es.MemberExpression(
                        object=es.Identifier(name='Object'),
                        property=es.Identifier(name='entries'),
                        computed=False
                    ),
                    arguments=[awaited_call]
                );
                map_call = es.CallExpression(
                    callee=es.MemberExpression(
                        object=entries_call,
                        property=es.Identifier(name='map'),
                        computed=False
                    ),
                    arguments=[
                        es.ArrowFunctionExpression(
                            params=[
                                es.ArrayPattern(
                                    elements=[
                                        es.Identifier(name='k'),
                                        es.Identifier(name='v')
                                    ]
                                )
                            ],
                            body=es.ArrayExpression(
                                elements=[
                                    es.Identifier(name='k'),
                                    es.CallExpression(
                                        callee=es.MemberExpression(
                                            object=es.Identifier(name=val_type),
                                            property=es.Identifier(name='__from_wire'),
                                            computed=False
                                        ),
                                        arguments=[es.Identifier(name='v')]
                                    )
                                ]
                            ),
                            expression=True,
                            async_=False
                        )
                    ]
                );
                return self.sync_loc(
                    es.CallExpression(
                        callee=es.MemberExpression(
                            object=es.Identifier(name='Object'),
                            property=es.Identifier(name='fromEntries'),
                            computed=False
                        ),
                        arguments=[map_call]
                    ),
                    jac_node=jac_node
                );
            }
        }
    }

    return call_expr;
}

impl EsastGenPass._wrap_to_wire_if_boundary(
    expr: es.Expression,
    type_name: str,
    boundary_types: dict[(str, Any)],
    jac_node: uni.UniNode
) -> es.Expression {
    if (type_name in boundary_types and boundary_types[type_name].kind != "enum") {
        return self.sync_loc(
            es.CallExpression(
                callee=es.MemberExpression(
                    object=expr,
                    property=es.Identifier(name='__to_wire'),
                    computed=False
                ),
                arguments=[]
            ),
            jac_node=jac_node
        );
    }
    return expr;
}

impl EsastGenPass._resolve_call_arg_slots(
    nd: uni.FuncCall,
    args: list[(es.Expression | es.SpreadElement)],
    props: list[(es.Property | es.SpreadElement)],
    param_names: list[str],
    func_name: str,
    spread_read_source: (es.Expression | None)
) -> list[CallArgSlot] {
    by_name: dict[str, (es.Expression | es.SpreadElement)] = {};
    extras: list[CallArgSlot] = [];
    spread_sources: list[es.Expression] = [];
    seen_names: set[str] = set();
    for (i, arg) in enumerate(args) {
        if isinstance(arg, es.SpreadElement) {
            extras.append(CallArgSlot(name=None, value=arg));
            continue;
        }
        if i < len(param_names) {
            pname = param_names[i];
            seen_names.add(pname);
            by_name[pname] = arg;
        } else {
            extras.append(CallArgSlot(name=None, value=arg));
        }
    }
    for kw in props {
        if isinstance(kw, es.SpreadElement) {
            spread_sources.append(kw.argument);
            continue;
        }
        kw_name = '';
        if isinstance(kw.key, es.Identifier) {
            kw_name = kw.key.name;
        } elif isinstance(kw.key, es.Literal) {
            kw_name = str(kw.key.value);
        }
        if not kw_name {
            extras.append(
                CallArgSlot(
                    name=None,
                    value=self.sync_loc(
                        es.SpreadElement(argument=kw.value), jac_node=nd
                    )
                )
            );
            continue;
        }
        if kw_name in seen_names {
            self.emit(E5080, node_override=nd, name=kw_name, func=func_name);
        }
        seen_names.add(kw_name);
        by_name[kw_name] = kw.value;
    }
    resolved: list[CallArgSlot] = [];
    for pname in param_names {
        if pname in by_name {
            resolved.append(CallArgSlot(name=pname, value=by_name[pname]));
        } elif spread_sources {
            spread_source = spread_read_source;
            if spread_source is None {
                spread_source = spread_sources[0]
                    if len(spread_sources) == 1
                    else self.sync_loc(
                        es.ObjectExpression(
                            properties=[
                                self.sync_loc(
                                    es.SpreadElement(argument=src), jac_node=nd
                                ) for src in spread_sources
                            ]
                        ),
                        jac_node=nd
                    );
            }
            resolved.append(
                CallArgSlot(
                    name=pname,
                    value=self.sync_loc(
                        es.MemberExpression(
                            object=spread_source,
                            property=self.sync_loc(
                                es.Literal(value=pname), jac_node=nd
                            ),
                            computed=True
                        ),
                        jac_node=nd
                    )
                )
            );
        } else {
            resolved.append(CallArgSlot(name=pname, value=None));
        }
    }
    resolved.extend(extras);
    return resolved;
}

impl EsastGenPass._call_args_from_slots(
    slots: list[CallArgSlot]
) -> (list[(es.Expression | es.SpreadElement)] | None) {
    call_args: list[(es.Expression | es.SpreadElement)] = [];
    last_value_idx = -1;
    for (i, slot) in enumerate(slots) {
        if slot.value is not None {
            last_value_idx = i;
        }
    }
    if last_value_idx < 0 {
        return [];
    }
    for (i, slot) in enumerate(slots) {
        if i > last_value_idx {
            break;
        }
        if slot.value is None {
            call_args.append(es.Identifier(name='undefined'));
            continue;
        }
        if slot.name is None {
            call_args.append(slot.value);
            continue;
        }
        call_args.append(slot.value);
    }
    return call_args;
}

impl EsastGenPass._kwargs_spread_arg(
    props: list[(es.Property | es.SpreadElement)], nd: uni.FuncCall
) -> (es.Expression | None) {
    sources: list[es.Expression] = [];
    for prop in props {
        if isinstance(prop, es.SpreadElement) {
            sources.append(prop.argument);
        }
    }
    if not sources {
        return None;
    }
    if len(sources) == 1 {
        return sources[0];
    }
    return self.sync_loc(
        es.ObjectExpression(
            properties=[
                self.sync_loc(es.SpreadElement(argument=src), jac_node=nd)
                for src in sources
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._kwargs_spread_needs_temp(
    props: list[(es.Property | es.SpreadElement)]
) -> bool {
    sources: list[es.Expression] = [];
    for prop in props {
        if isinstance(prop, es.SpreadElement) {
            sources.append(prop.argument);
        }
    }
    if len(sources) > 1 {
        return True;
    }
    if len(sources) == 1 and not isinstance(sources[0], es.Identifier) {
        return True;
    }
    return False;
}

impl EsastGenPass._make_kwargs_spread_context(
    props: list[(es.Property | es.SpreadElement)], nd: uni.FuncCall
) -> tuple[((es.Expression | None), (es.Expression | None))] {
    spread_arg = self._kwargs_spread_arg(props, nd);
    if spread_arg is None {
        return (None, None);
    }
    if self._kwargs_spread_needs_temp(props) {
        return (
            spread_arg,
            self.sync_loc(es.Identifier(name='__jac_kwargs'), jac_node=nd)
        );
    }
    return (spread_arg, None);
}

impl EsastGenPass._wrap_with_kwargs_temp(
    expr: es.Expression, spread_arg: es.Expression, nd: uni.FuncCall
) -> es.Expression {
    temp_id = self.sync_loc(es.Identifier(name='__jac_kwargs'), jac_node=nd);
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[temp_id], body=expr, expression=True, async_=False
                ),
                jac_node=nd
            ),
            arguments=[spread_arg]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._try_lower_server_rpc_call(
    nd: uni.FuncCall,
    args: list[(es.Expression | es.SpreadElement)],
    props: list[(es.Property | es.SpreadElement)]
) -> (es.Expression | None) {
    if not (nd.in_client_context() and isinstance(nd.target, uni.Name)) {
        return None;
    }
    ability_node = self._resolve_call_ability(nd);
    if not ability_node {
        return None;
    }
    is_server_func = (
        ability_node.code_context != CodeContext.CLIENT
        and not ability_node.in_client_context()
        and ability_node.access is not None
        and ability_node.access.tag.name == Tok.KW_PUB
    );
    if not is_server_func {
        return None;
    }
    func_name = nd.target.sym_name;

    param_names: list[str] = self._param_names_from_ability(ability_node);
    inline_param_type_map: dict[str, str] = self._param_type_map_from_ability(
        ability_node
    );
    inline_ret_type: str = self._extract_return_type(
        ability_node, func_name, self.ir_in.gen.interop_manifest
    );
    inline_boundary = self.ir_in.gen.interop_manifest.boundary_types
        if self.ir_in.gen.interop_manifest
        else {};
    (spread_arg, spread_read_source) = self._make_kwargs_spread_context(props, nd);
    use_kwargs_temp = spread_read_source is not None;
    slots = self._resolve_call_arg_slots(
        nd, args, props, param_names, func_name, spread_read_source
    );
    rpc_props: list[(es.Property | es.SpreadElement)] = [];
    for slot in slots {
        if slot.value is None {
            continue;
        }
        if slot.name is None {
            rpc_props.append(slot.value);
            continue;
        }
        named_value = self._wrap_to_wire_if_boundary(
            cast(es.Expression, slot.value),
            inline_param_type_map.get(slot.name, ''),
            inline_boundary,
            nd
        );
        rpc_props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Literal(value=slot.name), jac_node=nd),
                    value=named_value,
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=nd
            )
        );
    }
    args_obj: es.Expression = self.sync_loc(
        es.ObjectExpression(properties=rpc_props), jac_node=nd
    );
    if use_kwargs_temp and spread_arg is not None {
        args_obj = self._wrap_with_kwargs_temp(args_obj, spread_arg, nd);
    }

    result_expr: es.Expression = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__jacCallFunction'), jac_node=nd),
            arguments=[
                self.sync_loc(es.Literal(value=func_name), jac_node=nd),
                args_obj
            ]
        ),
        jac_node=nd
    );
    result_expr = self._wrap_return_with_boundary(
        result_expr, inline_ret_type, inline_boundary, nd, pre_awaited=False
    );
    self._inject_runtime_import('__jacCallFunction', nd);
    return result_expr;
}

impl EsastGenPass.exit_func_call(nd: uni.FuncCall) -> None {
    args: list[(es.Expression | es.SpreadElement)] = [];
    props: list[(es.Property | es.SpreadElement)] = [];
    for param in nd.params {
        if isinstance(param, uni.KWPair) {
            value_expr = cast(
                es.Expression,
                param.value.gen.es_ast
                    if (param.value and param.value.gen.es_ast)
                    else self.sync_loc(es.Literal(value=None), jac_node=param)
            );

            if (not param.key) or (not param.key.gen.es_ast) {
                props.append(
                    self.sync_loc(es.SpreadElement(argument=value_expr), jac_node=param)
                );
                continue;
            }
            key_expr = cast(es.Expression, param.key.gen.es_ast);
            props.append(
                self.sync_loc(
                    es.Property(
                        key=key_expr,
                        value=value_expr,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    ),
                    jac_node=param
                )
            );
            continue;
        }
        if (isinstance(param, uni.UnaryExpr) and param.op.name == Tok.STAR_MUL.value) {
            spread_arg = cast(
                es.Expression,
                param.operand.gen.es_ast
                    if (param.operand and param.operand.gen.es_ast)
                    else self.sync_loc(es.Identifier(name='undefined'), jac_node=param)
            );
            args.append(
                self.sync_loc(es.SpreadElement(argument=spread_arg), jac_node=param)
            );
            continue;
        }
        if param.gen.es_ast {
            args.append(cast(es.Expression, param.gen.es_ast));
        }
    }

    server_call = self._try_lower_server_rpc_call(nd, args, props);
    if server_call is not None {
        nd.gen.es_ast = server_call;
        return;
    }
    callee = nd.target.gen.es_ast
    or self.sync_loc(es.Identifier(name='func'), jac_node=nd.target);

    if (
        isinstance(callee, es.MemberExpression)
        and isinstance(callee.property, es.Identifier)
        and isinstance(nd.target, uni.AtomTrailer)
    ) {
        import from jaclang.compiler.passes.ecmascript.es_unparse { JSCodeGenerator }

        _obj_type = nd.target.target?.type;
        _type_name = self._resolve_primitive_type_name(_obj_type);
        _method_name = callee.property.name;
        if _type_name {
            _emitter = self._primitive_emitters.get(_type_name);
            _emit_fn_name = "emit_" + _method_name;
            _emit_fn = getattr(_emitter, _emit_fn_name, None) if _emitter else None;
            if _emit_fn {
                _unparser = JSCodeGenerator();
                _ctx = self._primitives_es_mod.ESEmitCtx(unparser=_unparser);
                _target_str = _unparser.generate(callee.object);
                _args_strs: list[str] = [];
                for _a in args {
                    _args_strs.append(_unparser.generate(_a));
                }

                for _p in props {
                    if isinstance(_p, es.Property) and _p.value {
                        _args_strs.append(_unparser.generate(_p.value));
                    }
                }

                import inspect;
                _n_params = len(inspect.signature(_emit_fn).parameters);
                if _n_params == 2 {
                    _result = _emit_fn(_ctx, _args_strs);
                } else {
                    _result = _emit_fn(_ctx, _target_str, _args_strs);
                }
                if _result is not None and "_jac." in str(_result) {
                    self.needs_jac_runtime = True;
                }
                nd.gen.es_ast = self.sync_loc(es.Identifier(name=_result), jac_node=nd);
                return;
            }
        }

        if self._poly_methods is not None and (_method_name in self._poly_methods) {
            _poly_args: list[(es.Expression | es.SpreadElement)] = [
                cast(es.Expression, callee.object),
                self.sync_loc(es.Literal(value=_method_name), jac_node=nd)
            ];
            for _a in args {
                _poly_args.append(_a);
            }

            for _p in props {
                if isinstance(_p, es.Property) and _p.value {
                    _poly_args.append(cast(es.Expression, _p.value));
                }
            }
            _poly_callee = es.MemberExpression(
                object=es.MemberExpression(
                    object=es.Identifier(name='_jac'),
                    property=es.Identifier(name='poly'),
                    computed=False
                ),
                property=es.Identifier(name='call'),
                computed=False
            );
            self.needs_jac_runtime = True;
            nd.gen.es_ast = self.sync_loc(
                es.CallExpression(
                    callee=cast(es.Expression, _poly_callee), arguments=_poly_args
                ),
                jac_node=nd
            );
            return;
        }
    }

    self._ensure_emitters();

    _call_kind = nd.call_kind;
    if _call_kind == "builtin" and isinstance(nd.target, uni.Name) {
        import from jaclang.compiler.passes.ecmascript.es_unparse { JSCodeGenerator }
        _builtin_name = nd.target.sym_name;
        _emit_fn_name = "emit_" + _builtin_name;
        _emit_fn = getattr(self._builtin_emitter, _emit_fn_name, None);
        if _emit_fn {
            _unparser = JSCodeGenerator();
            _ctx = self._primitives_es_mod.ESEmitCtx(unparser=_unparser);
            _args_strs: list[str] = [];
            for _a in args {
                _args_strs.append(_unparser.generate(_a));
            }

            for _p in props {
                if isinstance(_p, es.Property) and _p.value {
                    _args_strs.append(_unparser.generate(_p.value));
                }
            }

            _result = None;
            try {
                _result = _emit_fn(_ctx, _args_strs);
            } except Exception as _emit_err {
                self.emit(
                    E5016, node_override=nd, name=_builtin_name, error=str(_emit_err)
                );
                return;
            }

            if _result is not None {
                if "_jac." in str(_result) {
                    self.needs_jac_runtime = True;
                }
                nd.gen.es_ast = self.sync_loc(es.Identifier(name=_result), jac_node=nd);
                return;
            }
        }
    }

    if isinstance(nd.target, uni.BuiltinType)
    and isinstance(callee, es.MemberExpression) {
        self.needs_jac_runtime = True;
    }

    args_obj = self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);
    callee_expr = cast(es.Expression, callee);
    call_args: list[(es.Expression | es.SpreadElement)] = args;
    (spread_arg, spread_read_source) = self._make_kwargs_spread_context(props, nd);
    use_kwargs_temp = spread_read_source is not None;
    ability_node_resolved = self._resolve_call_ability(nd);
    if props {
        if ability_node_resolved {
            ordered_args = self._call_args_from_slots(
                self._resolve_call_arg_slots(
                    nd,
                    args,
                    props,
                    self._param_names_from_ability(ability_node_resolved),
                    nd.target.sym_name if isinstance(nd.target, uni.Name) else "func",
                    spread_read_source
                )
            );
            call_args = ordered_args if ordered_args is not None else [args_obj];
        } else {
            call_args = [args_obj];
        }
    }

    if (
        ability_node_resolved
        and self._component_call_abi(ability_node_resolved) == 'props_destructure'
    ) {
        result_expr: es.Expression;

        if any(isinstance(arg, es.SpreadElement) for arg in args) {
            result_expr = self._build_props_spread_component_call(
                nd, callee_expr, ability_node_resolved, args, props
            );
        } else {
            wrap_props: list[es.Property] = [];
            param_names = self._param_names_from_ability(ability_node_resolved);
            for (i, arg) in enumerate(call_args) {
                if i < len(param_names) {
                    wrap_props.append(
                        self.sync_loc(
                            es.Property(
                                key=self.sync_loc(
                                    es.Identifier(name=param_names[i]), jac_node=nd
                                ),
                                value=cast(es.Expression, arg),
                                kind='init',
                                method=False,
                                shorthand=False,
                                computed=False
                            ),
                            jac_node=nd
                        )
                    );
                }
            }
            result_expr = self.sync_loc(
                es.CallExpression(
                    callee=callee_expr,
                    arguments=[
                        self.sync_loc(
                            es.ObjectExpression(properties=wrap_props), jac_node=nd
                        )
                    ]
                ),
                jac_node=nd
            );
            if use_kwargs_temp and spread_arg is not None {
                result_expr = self._wrap_with_kwargs_temp(result_expr, spread_arg, nd);
            }
        }
        nd.gen.es_ast = result_expr;
        return;
    }
    if _call_kind == "instantiation" and isinstance(callee, es.Expression) {
        result_expr: es.Expression = self.sync_loc(
            es.NewExpression(callee=callee_expr, arguments=call_args), jac_node=nd
        );
    } else {
        result_expr = self.sync_loc(
            es.CallExpression(callee=callee_expr, arguments=call_args), jac_node=nd
        );
    }
    if use_kwargs_temp and spread_arg is not None {
        result_expr = self._wrap_with_kwargs_temp(result_expr, spread_arg, nd);
    }
    nd.gen.es_ast = result_expr;
}

impl EsastGenPass.exit_assignment(nd: uni.Assignment) -> None {
    if not nd.target {
        nd.gen.es_ast = None;
        return;
    }
    value_expr = nd.value.gen.es_ast if (nd.value and nd.value.gen.es_ast) else None;

    if len(nd.target) == 1 and isinstance(nd.target[0], uni.Name) {
        target_name = nd.target[0].sym_name;
        if target_name in self.reactive_vars {
            setter_arg: es.Expression;
            aug_op: (str | None) = None;
            if nd.aug_op {
                aug_tok = Tok(nd.aug_op.name)
                    if (nd.aug_op.name in Tok.__members__)
                    else None;
                aug_to_binary: dict[Tok, str] = {
                    Tok.ADD_EQ: '+',
                    Tok.SUB_EQ: '-',
                    Tok.MUL_EQ: '*',
                    Tok.DIV_EQ: '/',
                    Tok.MOD_EQ: '%'
                };
                binary_op = aug_to_binary.get(aug_tok, '+') if aug_tok else '+';
                aug_op = binary_op;

                setter_arg = cast(es.Expression, value_expr or es.Literal(value=0));
            } else {
                setter_arg = cast(
                    es.Expression, value_expr or es.Identifier(name='undefined')
                );
            }
            state_update = StateUpdate(
                name=target_name, value=setter_arg, aug_op=aug_op
            );
            self._ensure_backend();
            setter_call = self.sync_loc(
                self.backend.lower_state_update(state_update), jac_node=nd
            );
            expr_stmt = self.sync_loc(
                es.ExpressionStatement(expression=setter_call), jac_node=nd
            );
            nd.gen.es_ast = expr_stmt;
            return;
        }
    }
    if nd.aug_op {
        (left, _, _) = self._convert_assignment_target(nd.target[0]);
        aug_tok = Tok(nd.aug_op.name) if (nd.aug_op.name in Tok.__members__) else None;
        right = cast(
            es.Expression,
            (
                value_expr
                or self._get_ast_or_default(
                    nd.value,
                    default_factory=lambda (_src: any) { es.Identifier(
                        name='undefined'
                    ); }
                )
            )
        );

        _aug_emit_name = AUG_EMIT_MAP.get(aug_tok) if aug_tok else None;
        if _aug_emit_name {
            _prim_result = self._try_primitive_op(
                nd.target[0], _aug_emit_name, cast(es.Expression, left), right, nd
            );
            if _prim_result is not None {
                expr_stmt = self.sync_loc(
                    es.ExpressionStatement(expression=_prim_result), jac_node=nd
                );
                nd.gen.es_ast = expr_stmt;
                return;
            }
        }
        operator = ES_AUG_ASSIGN_OPS.get(aug_tok) if aug_tok else None;
        operator = operator or '=';
        assign_expr = self.sync_loc(
            es.AssignmentExpression(operator=operator, left=left, right=right),
            jac_node=nd
        );
        expr_stmt = self.sync_loc(
            es.ExpressionStatement(expression=assign_expr), jac_node=nd
        );
        nd.gen.es_ast = expr_stmt;
        return;
    }

    if len(nd.target) == 1 {
        _setitem = self._try_subscript_setitem(nd.target[0], value_expr, nd);
        if _setitem is not None {
            nd.gen.es_ast = _setitem;
            return;
        }
    }
    targets_info: list[AssignmentTargetInfo] = [];
    for target_node in nd.target {
        (left, reference, decl_name) = self._convert_assignment_target(target_node);
        pattern_names = self._collect_pattern_names(target_node);
        targets_info.append(
            AssignmentTargetInfo(
                nd=target_node,
                left=left,
                reference=reference,
                decl_name=decl_name,
                pattern_names=pattern_names
            )
        );
    }
    statements: list[es.Statement] = [];
    current_value: es.Expression = cast(
        es.Expression,
        (
            value_expr
            or self._get_ast_or_default(
                nd.value,
                default_factory=lambda (_src: any) { es.Identifier(name='undefined'); }
            )
        )
    );
    for info in reversed(targets_info) {
        target_node = info.nd;
        left = info.left;
        decl_name = info.decl_name;
        pattern_names = info.pattern_names;
        should_declare = False;

        if decl_name {
            should_declare = not self._is_declared_in_any_scope(decl_name);
        } elif pattern_names {
            should_declare = any(
                (not self._is_declared_in_any_scope(name))
                for (name, _) in pattern_names
            );
        }
        if should_declare {
            declarator = self.sync_loc(
                es.VariableDeclarator(
                    id=cast(es.Pattern, left),
                    `init=current_value if (value_expr is not None) else None
                ),
                jac_node=target_node
            );
            decl_stmt = self.sync_loc(
                es.VariableDeclaration(declarations=[declarator], kind='let'),
                jac_node=target_node
            );
            statements.append(decl_stmt);
            if decl_name {
                self._register_declaration(decl_name);
            } else {
                for (name, _) in pattern_names {
                    self._register_declaration(name);
                }
            }
        } else {
            assign_expr = self.sync_loc(
                es.AssignmentExpression(operator='=', left=left, right=current_value),
                jac_node=target_node
            );
            expr_stmt = self.sync_loc(
                es.ExpressionStatement(expression=assign_expr), jac_node=target_node
            );
            statements.append(expr_stmt);
        }
        if isinstance(left, es.Identifier) {
            current_value = self.sync_loc(
                es.Identifier(name=left.name), jac_node=target_node
            );
        } elif isinstance(info.reference, es.Identifier) {
            ref_ident = info.reference;
            current_value = self.sync_loc(
                es.Identifier(name=ref_ident.name), jac_node=target_node
            );
        } else {
            current_value = info.reference or current_value;
        }
    }
    if (len(statements) == 1) {
        nd.gen.es_ast = statements[0];
    } else {
        nd.gen.es_ast = statements;
    }
}

impl EsastGenPass._collect_pattern_names(
    target: uni.UniNode
) -> list[tuple[(str, uni.Name)]] {
    names: list[tuple[(str, uni.Name)]] = [];
    if isinstance(target, uni.Name) {
        names.append((target.sym_name, target));
    } elif isinstance(target, (uni.TupleVal, uni.ListVal)) {
        for value in target.values {
            names.extend(self._collect_pattern_names(value));
        }
    } elif isinstance(target, uni.DictVal) {
        for kv in target.kv_pairs {
            if isinstance(kv, uni.KVPair) {
                names.extend(self._collect_pattern_names(kv.value));
            }
        }
    } elif isinstance(target, uni.SubTag) {
        names.extend(self._collect_pattern_names(target.tag));
    }
    return names;
}

impl EsastGenPass._convert_assignment_target(
    target: uni.UniNode
) -> tuple[(es.Pattern | es.Expression), (es.Expression | None), (str | None)] {
    if isinstance(target, uni.Name) {
        identifier = self.sync_loc(
            es.Identifier(name=target.sym_name), jac_node=target
        );
        return (identifier, identifier, target.sym_name);
    }
    if isinstance(target, (uni.TupleVal, uni.ListVal)) {
        elements: list[(es.Pattern | None)] = [];
        for value in target.values {
            if (value is None) {
                elements.append(None);
                continue;
            }
            (pattern, _, _) = self._convert_assignment_target(value);
            elements.append(cast(es.Pattern, pattern));
        }
        pattern = self.sync_loc(es.ArrayPattern(elements=elements), jac_node=target);
        return (pattern, None, None);
    }
    if isinstance(target, uni.DictVal) {
        properties: list[(es.AssignmentProperty | es.RestElement)] = [];
        for kv in target.kv_pairs {
            if (not isinstance(kv, uni.KVPair) or (kv.key is None)) {
                continue;
            }
            key_expr = cast(
                es.Expression,
                kv.key.gen.es_ast
                or self.sync_loc(es.Identifier(name='key'), jac_node=kv.key)
            );
            (value_pattern, _, _) = self._convert_assignment_target(kv.value);
            assignment = self.sync_loc(
                es.AssignmentProperty(
                    key=key_expr, value=cast(es.Pattern, value_pattern), shorthand=False
                ),
                jac_node=kv
            );
            properties.append(assignment);
        }
        pattern = self.sync_loc(
            es.ObjectPattern(properties=properties), jac_node=target
        );
        return (pattern, None, None);
    }
    if isinstance(target, uni.SubTag) {
        return self._convert_assignment_target(target.tag);
    }

    if (
        isinstance(target, uni.AtomTrailer)
        and isinstance(target.right, uni.IndexSlice)
        and (not target.right.is_range)
    ) {
        _si = target.right.gen.es_ast;
        if isinstance(_si, es.IndexInfo) {
            _obj = cast(
                es.Expression,
                target.target.gen.es_ast
                or self.sync_loc(es.Identifier(name='obj'), jac_node=target)
            );
            _idx = cast(
                es.Expression,
                _si.value or self.sync_loc(es.Literal(value=0), jac_node=target)
            );
            _member = self.sync_loc(
                es.MemberExpression(object=_obj, property=_idx, computed=True),
                jac_node=target
            );
            return (_member, _member, None);
        }
    }
    left = cast(
        (es.Pattern | es.Expression),
        target.gen.es_ast or self.sync_loc(es.Identifier(name='temp'), jac_node=target)
    );
    reference = cast(es.Expression, left) if isinstance(left, es.Node) else None;
    return (left, reference, None);
}

impl EsastGenPass._ensure_emitters -> None {
    if self._primitive_emitters is not None {
        return;
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    import jaclang.compiler.passes.ecmascript.primitives_es as _pes;
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
    import from jaclang.compiler.type_system.type_utils { primitive_type_name_of }
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
    import from jaclang.compiler.passes.ecmascript.es_unparse { JSCodeGenerator }

    import from jaclang.compiler.type_system.type_utils { expr_primitive_name }
    _type_name = expr_primitive_name(self.prog, expr_node);
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
    _target_str = _unparser.generate(left_es);
    _args_strs: list[str] = [];
    if right_es is not None {
        _args_strs.append(_unparser.generate(right_es));
    }
    _result = _emit_fn(_ctx, _target_str, _args_strs);
    if _result is None {
        return None;
    }
    if "_jac." in str(_result) {
        self.needs_jac_runtime = True;
    }
    return self.sync_loc(es.Identifier(name=_result), jac_node=jac_node);
}

impl EsastGenPass._expr_type_name(expr_node: uni.UniNode) -> str {
    import from jaclang.compiler.type_system.type_utils { expr_primitive_name }
    return expr_primitive_name(self.prog, expr_node);
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
    return self._expr_type_name(expr_node) in {
        "list",
        "dict",
        "set",
        "tuple",
        "frozenset",
        "bytes"
    };
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

impl EsastGenPass.exit_unary_expr(nd: uni.UnaryExpr) -> None {
    operand = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.operand, default_factory=lambda (_src: any) { es.Literal(value=0); }
        )
    );
    op_tok = Tok(nd.op.name) if (nd.op.name in Tok.__members__) else None;

    _unary_emit_name = UNARY_EMIT_MAP.get(op_tok) if op_tok else None;
    if _unary_emit_name {
        _prim_result = self._try_primitive_op(
            nd.operand, _unary_emit_name, operand, None, nd
        );
        if _prim_result is not None {
            nd.gen.es_ast = _prim_result;
            return;
        }
    }
    operator = ES_UNARY_OPS.get(op_tok) if op_tok else None;
    operator = operator or '!';

    if (op_tok == Tok.NOT) {
        operand = self._coerce_truthy(nd.operand, operand, nd);
    }
    unary_expr = self.sync_loc(
        es.UnaryExpression(operator=operator, prefix=True, argument=operand),
        jac_node=nd
    );
    nd.gen.es_ast = unary_expr;
}

impl EsastGenPass.exit_compare_expr(nd: uni.CompareExpr) -> None {
    if (not nd.rights or not nd.ops) {
        nd.gen.es_ast = self.sync_loc(es.Literal(value=True), jac_node=nd);
        return;
    }
    comparisons: list[es.Expression] = [];
    left: es.Expression = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.left,
            default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Identifier(name='left'); }
        )
    );
    for (op_token, right_node) in zip(nd.ops, nd.rights, strict=False) {
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

        _cmp_emit_name = CMP_EMIT_MAP.get(op_tok) if op_tok else None;
        if _cmp_emit_name {
            if op_tok in (Tok.KW_IN, Tok.KW_NIN) {
                _prim_result = self._try_primitive_op(
                    right_node, _cmp_emit_name, right, left, nd
                );
            } else {
                _prim_result = self._try_primitive_op(
                    nd.left, _cmp_emit_name, left, right, nd
                );
            }
            if _prim_result is not None {
                if op_tok == Tok.KW_NIN {
                    comparison = self.sync_loc(
                        es.UnaryExpression(
                            operator='!', prefix=True, argument=_prim_result
                        ),
                        jac_node=nd
                    );
                } else {
                    comparison = _prim_result;
                }
                comparisons.append(comparison);
                left = right;
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
                                es.Identifier(name='_jac'), jac_node=nd
                            ),
                            property=self.sync_loc(
                                es.Identifier(name='poly'), jac_node=nd
                            ),
                            computed=False
                        ),
                        jac_node=nd
                    ),
                    property=self.sync_loc(es.Identifier(name='contains'), jac_node=nd),
                    computed=False
                ),
                jac_node=nd
            );
            self.needs_jac_runtime = True;
            contains_call = self.sync_loc(
                es.CallExpression(
                    callee=cast(es.Expression, contains_callee),
                    arguments=[cast(es.Expression, right), cast(es.Expression, left)]
                ),
                jac_node=nd
            );
            if (op_tok == Tok.KW_NIN) {
                comparison = self.sync_loc(
                    es.UnaryExpression(
                        operator='!',
                        prefix=True,
                        argument=cast(es.Expression, contains_call)
                    ),
                    jac_node=nd
                );
            } else {
                comparison = cast(es.Expression, contains_call);
            }
        } else {
            operator = ES_COMPARISON_OPS.get(op_tok) if op_tok else None;
            operator = operator or '===';
            comparison = self.sync_loc(
                es.BinaryExpression(operator=operator, left=left, right=right),
                jac_node=nd
            );
        }
        comparisons.append(comparison);
        left = right;
    }
    if (len(comparisons) == 1) {
        nd.gen.es_ast = comparisons[0];
    } else {
        result = comparisons[0];
        for comp in comparisons[1:] {
            result = self.sync_loc(
                es.LogicalExpression(operator='&&', left=result, right=comp),
                jac_node=nd
            );
        }
        nd.gen.es_ast = result;
    }
}

impl EsastGenPass.exit_cfg_expr(nd: uni.CfgExpr) -> None {
    nd.gen.es_ast = nd.expr.gen.es_ast;
}

impl EsastGenPass.exit_bool_expr(nd: uni.BoolExpr) -> None {
    if (not nd.values or (len(nd.values) < 2)) {
        nd.gen.es_ast = self.sync_loc(es.Literal(value=None), jac_node=nd);
        return;
    }
    op_tok = Tok(nd.op.name) if (nd.op.name in Tok.__members__) else None;
    logical_op = ES_LOGICAL_OPS.get(op_tok) if op_tok else None;
    logical_op = logical_op or '&&';

    _helper = "and_" if (op_tok == Tok.KW_AND) else "or_";
    result: es.Expression = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.values[0], default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );

    left_maybe_collection = self._is_collection_expr(nd.values[0]);
    for val in nd.values[1:] {
        right = cast(
            es.Expression,
            self._get_ast_or_default(
                val, default_factory=lambda (_src: any) { es.Literal(value=None); }
            )
        );
        if left_maybe_collection {
            right_thunk = self.sync_loc(
                es.ArrowFunctionExpression(params=[], body=right, expression=True),
                jac_node=nd
            );
            result = self._build_jac_call(
                ["_jac", "poly", _helper],
                [result, cast(es.Expression, right_thunk)],
                nd
            );
        } else {
            result = self.sync_loc(
                es.LogicalExpression(operator=logical_op, left=result, right=right),
                jac_node=nd
            );
        }
        left_maybe_collection = left_maybe_collection or self._is_collection_expr(val);
    }
    nd.gen.es_ast = result;
}

impl EsastGenPass.exit_binary_expr(nd: uni.BinaryExpr) -> None {
    left = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.left,
            default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Literal(value=0); }
        )
    );
    right = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.right,
            default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Literal(value=0); }
        )
    );

    connect_call = self._build_osp_graph_call(nd, left, right);
    if connect_call is not None {
        nd.gen.es_ast = connect_call;
        return;
    }
    op_name_str = nd.op?.name;
    op_name = Tok(op_name_str) if (op_name_str in Tok.__members__) else None;
    if (op_name == Tok.KW_SPAWN) {
        local_spawn = self._build_local_osp_spawn(nd, left, right);
        if local_spawn is not None {
            nd.gen.es_ast = local_spawn;
            return;
        }
        spawn_parts = self._prepare_spawn_call(nd, left, right);
        if spawn_parts {
            nd.gen.es_ast = self._build_spawn_runtime_call(nd, spawn_parts);
        }
        return;
    }
    if ((op_name == Tok.WALRUS_EQ) and isinstance(left, es.Identifier)) {
        self._ensure_identifier_declared(left.name, nd.left);
        assign_expr = self.sync_loc(
            es.AssignmentExpression(operator='=', left=left, right=right), jac_node=nd
        );
        nd.gen.es_ast = assign_expr;
        return;
    }

    if op_name {
        _op_emit_name = OP_EMIT_MAP.get(op_name);
        if _op_emit_name {
            _prim_result = self._try_primitive_op(
                nd.left, _op_emit_name, left, right, nd
            );
            if _prim_result is not None {
                nd.gen.es_ast = _prim_result;
                return;
            }
        }
    }
    logical_op = ES_LOGICAL_OPS.get(op_name) if op_name else None;
    bin_expr: (es.LogicalExpression | es.BinaryExpression);
    if logical_op {
        bin_expr = self.sync_loc(
            es.LogicalExpression(operator=logical_op, left=left, right=right),
            jac_node=nd
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
                es.ArrayExpression(elements=[left_spread, right_spread]), jac_node=nd
            );
        } else {
            bin_expr = self.sync_loc(
                es.BinaryExpression(operator=operator, left=left, right=right),
                jac_node=nd
            );
        }
    }
    nd.gen.es_ast = bin_expr;
}

impl EsastGenPass.exit_switch_case(nd: uni.SwitchCase) -> None {
    case_test: (es.Expression | None) = None;
    if (nd.pattern and isinstance(nd.pattern, uni.MatchValue)) {
        case_test = self._get_ast_or_default(
            nd.pattern.value,
            default_factory=lambda (_src: any) { es.Literal(value=None); }
        );
    }
    body_stmts = self._collect_stmt_body(nd.body);
    nd.gen.es_ast = self.sync_loc(
        es.SwitchCase(`test=case_test, consequent=body_stmts), jac_node=nd
    );
}

impl EsastGenPass.exit_switch_stmt(nd: uni.SwitchStmt) -> None {
    `test = self._get_ast_or_default(
        nd.target, default_factory=lambda (_src: any) { es.Literal(value=None); }
    );
    cases: list[es.SwitchCase] = [];
    for stmt in nd.cases {
        if (stmt.gen.es_ast and isinstance(stmt.gen.es_ast, es.SwitchCase)) {
            switch_case = cast(es.SwitchCase, stmt.gen.es_ast);
            cases.append(switch_case);
        }
    }
    nd.gen.es_ast = self.sync_loc(
        es.SwitchStatement(discriminant=`test, cases=cases), jac_node=nd
    );
}

impl EsastGenPass.exit_expr_stmt(nd: uni.ExprStmt) -> None {
    expr = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.expr, default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );

    acc = self._cur_view_acc();
    if acc is not None {
        nd.gen.es_ast = self._view_push_stmt(acc, expr, nd);
        return;
    }
    expr_stmt = self.sync_loc(es.ExpressionStatement(expression=expr), jac_node=nd);
    nd.gen.es_ast = expr_stmt;
}

impl EsastGenPass.exit_ctrl_stmt(nd: uni.CtrlStmt) -> None {
    acc = self._cur_view_acc();
    if acc is not None and nd.ctrl.value == "skip" {
        nd.gen.es_ast = self._view_fragment_return(acc, nd);
        return;
    }
    stmt: (es.BreakStatement | es.ContinueStatement | es.ReturnStatement);
    if (nd.ctrl.name == Tok.KW_BREAK) {
        stmt = self.sync_loc(es.BreakStatement(), jac_node=nd);
    } elif (nd.ctrl.name == Tok.KW_SKIP) {
        stmt = self.sync_loc(es.ReturnStatement(argument=None), jac_node=nd);
    } else {
        stmt = self.sync_loc(es.ContinueStatement(), jac_node=nd);
    }
    nd.gen.es_ast = stmt;
}

impl EsastGenPass.exit_return_stmt(nd: uni.ReturnStmt) -> None {
    acc = self._cur_view_acc();
    if acc is not None {
        nd.gen.es_ast = self._view_fragment_return(acc, nd);
        return;
    }
    argument: (es.Expression | None) = None;
    if (nd.expr and nd.expr.gen.es_ast) {
        argument = cast(es.Expression, nd.expr.gen.es_ast);
    }
    ret_stmt = self.sync_loc(es.ReturnStatement(argument=argument), jac_node=nd);
    nd.gen.es_ast = ret_stmt;
}

impl EsastGenPass.exit_assert_stmt(nd: uni.AssertStmt) -> None {
    `test: es.Expression = cast(es.Expression, nd.condition.gen.es_ast)
        if nd.condition.gen.es_ast
        else self.sync_loc(es.Literal(value=True), jac_node=nd.condition);
    negated_test = self.sync_loc(
        es.UnaryExpression(operator='!', prefix=True, argument=`test), jac_node=nd
    );
    error_msg = 'Assertion failed';
    if (
        nd.error_msg
        and nd.error_msg.gen.es_ast
        and isinstance(nd.error_msg.gen.es_ast, es.Literal)
    ) {
        error_msg = str(nd.error_msg.gen.es_ast.value);
    }
    throw_stmt = self.sync_loc(
        es.ThrowStatement(
            argument=self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(es.Identifier(name='Error'), jac_node=nd),
                    arguments=[self.sync_loc(es.Literal(value=error_msg), jac_node=nd)]
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
    if_stmt = self.sync_loc(
        es.IfStatement(
            `test=negated_test,
            consequent=self.sync_loc(es.BlockStatement(body=[throw_stmt]), jac_node=nd)
        ),
        jac_node=nd
    );
    nd.gen.es_ast = if_stmt;
}

impl EsastGenPass._jac_exc_ref(
    member: str, jac_node: (uni.UniNode | None)
) -> es.MemberExpression {
    self.needs_jac_runtime = True;
    return cast(
        es.MemberExpression, self._build_jac_ref(['_jac', 'exc', member], jac_node)
    );
}

impl EsastGenPass.exit_raise_stmt(nd: uni.RaiseStmt) -> None {
    argument: es.Expression = cast(es.Expression, nd.cause.gen.es_ast)
        if (nd.cause and nd.cause.gen.es_ast)
        else self.sync_loc(es.Identifier(name='Error'), jac_node=nd);

    callee: (es.Expression | None) = None;
    call_args: (list | None) = None;
    if isinstance(argument, es.CallExpression) {
        callee = argument.callee;
        call_args = argument.arguments;
    } elif isinstance(argument, es.NewExpression) {
        callee = argument.callee;
        call_args = argument.arguments;
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if callee is not None and isinstance(callee, es.Identifier) {
        if JAC_TYPE_REGISTRY.is_exception(callee.name) {
            exc_ref = self._jac_exc_ref(callee.name, nd);
            argument = self.sync_loc(
                es.NewExpression(callee=exc_ref, arguments=call_args or []), jac_node=nd
            );
        } elif callee.name == 'Error' {
            argument = self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(es.Identifier(name='Error'), jac_node=nd),
                    arguments=call_args or []
                ),
                jac_node=nd
            );
        }
    }
    throw_stmt = self.sync_loc(es.ThrowStatement(argument=argument), jac_node=nd);
    nd.gen.es_ast = throw_stmt;
}

impl EsastGenPass.exit_finally_stmt(nd: uni.FinallyStmt) -> None {
    nd.gen.es_ast = self._build_block_statement(nd, nd.body);
}

impl EsastGenPass.exit_except(nd: uni.Except) -> None {
    parent_try = nd.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
        nd.gen.es_ast = self._build_view_iife(
            nd.body, acc if isinstance(acc, str) else VIEW_ACC, nd
        );
        return;
    }

    body = self._build_block_statement(nd, nd.body);
    nd.gen.es_ast = body;
}

impl EsastGenPass.enter_try_stmt(nd: uni.TryStmt) -> None {
    if self._cur_view_acc() is not None and nd.awaiting_body is not None {
        self._view_awaiting_tries.add(id(nd));
        self._push_view_acc();
    }
}

impl EsastGenPass.enter_awaiting_clause(nd: uni.AwaitingClause) -> None {
    parent_try = nd.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        self._push_view_acc();
    }
}

impl EsastGenPass.exit_awaiting_clause(nd: uni.AwaitingClause) -> None {
    parent_try = nd.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
        nd.gen.es_ast = self._build_view_iife(
            nd.body, acc if isinstance(acc, str) else VIEW_ACC, nd
        );
    }
}

impl EsastGenPass.enter_except(nd: uni.Except) -> None {
    parent_try = nd.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        self._push_view_acc();
    }
}


impl EsastGenPass.exit_try_stmt(nd: uni.TryStmt) -> None {
    if id(nd) in self._view_awaiting_tries {
        self._view_awaiting_tries.discard(id(nd));
        try_acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
        try_iife = self._build_view_iife(
            nd.body, try_acc if isinstance(try_acc, str) else VIEW_ACC, nd
        );
        awaiting_iife: es.Expression = (
            cast(es.Expression, nd.awaiting_body.gen.es_ast)
                if (nd.awaiting_body is not None and nd.awaiting_body.gen.es_ast)
                else self._build_view_iife([], VIEW_ACC, nd)
        );
        except_iifes: list[es.Expression] = [];
        if nd.excepts {
            except_iifes = [
                cast(es.Expression, ex.gen.es_ast)
                for ex in nd.excepts
                if ex.gen.es_ast is not None
            ];
        }
        async_boundary = AsyncBoundary(
            try_expr=try_iife, awaiting_expr=awaiting_iife, except_exprs=except_iifes
        );
        self._ensure_backend();
        for sym in self.backend.async_boundary_symbols(async_boundary) {
            self._inject_runtime_import(sym, nd);
        }
        wrapper = self.sync_loc(
            self.backend.lower_async_boundary(async_boundary), jac_node=nd
        );
        outer = self._cur_view_acc();
        if outer is not None {
            nd.gen.es_ast = self._view_push_stmt(outer, wrapper, nd);
        } else {
            nd.gen.es_ast = self.sync_loc(
                es.ExpressionStatement(expression=wrapper), jac_node=nd
            );
        }
        return;
    }
    block = self._build_block_statement(nd, nd.body);
    handler: (es.CatchClause | None) = None;
    if nd.excepts and len(nd.excepts) > 0 {
        catch_param_name = "__jac_e";
        catch_param = self.sync_loc(es.Identifier(name=catch_param_name), jac_node=nd);

        catch_body_stmts: list[es.Statement] = [];

        if_chain: (es.IfStatement | None) = None;
        for i in range(len(nd.excepts) - 1, -1, -1) {
            except_node = nd.excepts[i];

            handler_body: (es.BlockStatement | None) = None;
            if except_node.gen.es_ast
            and isinstance(except_node.gen.es_ast, es.BlockStatement) {
                handler_body = except_node.gen.es_ast;
            } else {
                handler_body = self.sync_loc(
                    es.BlockStatement(body=[]), jac_node=except_node
                );
            }

            if except_node.name {
                var_name = except_node.name?.sym_name or str(except_node.name);
                binding = self.sync_loc(
                    es.VariableDeclaration(
                        declarations=[
                            self.sync_loc(
                                es.VariableDeclarator(
                                    id=self.sync_loc(
                                        es.Identifier(name=var_name),
                                        jac_node=except_node.name
                                    ),
                                    init=self.sync_loc(
                                        es.Identifier(name=catch_param_name),
                                        jac_node=except_node
                                    )
                                ),
                                jac_node=except_node
                            )
                        ],
                        kind='let'
                    ),
                    jac_node=except_node
                );
                handler_body = self.sync_loc(
                    es.BlockStatement(body=[binding] + (handler_body.body or [])),
                    jac_node=except_node
                );
            }

            exc_type_name: (str | None) = None;
            if except_node.ex_type {
                if hasattr(except_node.ex_type, 'sym_name') {
                    exc_type_name = except_node.ex_type.sym_name;
                } elif hasattr(except_node.ex_type, 'value') {
                    exc_type_name = except_node.ex_type.value;
                }
            }
            import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }

            test_expr: (es.Expression | None) = None;
            if exc_type_name and JAC_TYPE_REGISTRY.is_exception(exc_type_name) {
                test_expr = self.sync_loc(
                    es.CallExpression(
                        callee=self._jac_exc_ref('matches', except_node),
                        arguments=[
                            self.sync_loc(
                                es.Identifier(name=catch_param_name),
                                jac_node=except_node
                            ),
                            self.sync_loc(
                                es.Literal(
                                    value=exc_type_name, raw=json.dumps(exc_type_name)
                                ),
                                jac_node=except_node
                            )
                        ]
                    ),
                    jac_node=except_node
                );
            } elif exc_type_name {
                test_expr = self.sync_loc(
                    es.BinaryExpression(
                        operator='instanceof',
                        left=self.sync_loc(
                            es.Identifier(name=catch_param_name), jac_node=except_node
                        ),
                        right=self.sync_loc(
                            es.Identifier(name=exc_type_name), jac_node=except_node
                        )
                    ),
                    jac_node=except_node
                );
            }
            if test_expr is not None {
                if_chain = self.sync_loc(
                    es.IfStatement(
                        test=test_expr, consequent=handler_body, alternate=if_chain
                    ),
                    jac_node=except_node
                );
            } else {
                if_chain = self.sync_loc(
                    es.IfStatement(
                        test=self.sync_loc(
                            es.Literal(value=True, raw='true'), jac_node=except_node
                        ),
                        consequent=handler_body,
                        alternate=None
                    ),
                    jac_node=except_node
                );
            }
        }

        if if_chain is not None {
            tail = if_chain;
            while isinstance(tail.alternate, es.IfStatement) {
                tail = tail.alternate;
            }
            if tail.alternate is None {
                tail.alternate = self.sync_loc(
                    es.BlockStatement(
                        body=[
                            self.sync_loc(
                                es.ThrowStatement(
                                    argument=self.sync_loc(
                                        es.Identifier(name=catch_param_name),
                                        jac_node=nd
                                    )
                                ),
                                jac_node=nd
                            )
                        ]
                    ),
                    jac_node=nd
                );
            }
            catch_body_stmts.append(if_chain);
        }
        catch_body = self.sync_loc(
            es.BlockStatement(body=catch_body_stmts), jac_node=nd
        );
        handler = self.sync_loc(
            es.CatchClause(param=catch_param, body=catch_body), jac_node=nd
        );
    }
    finalizer: (es.BlockStatement | None) = None;
    if (
        nd.finally_body
        and nd.finally_body.gen.es_ast
        and isinstance(nd.finally_body.gen.es_ast, es.BlockStatement)
    ) {
        finalizer = nd.finally_body.gen.es_ast;
    }
    try_stmt = self.sync_loc(
        es.TryStatement(block=block, handler=handler, finalizer=finalizer), jac_node=nd
    );
    nd.gen.es_ast = try_stmt;
}

impl EsastGenPass.exit_in_for_stmt(nd: uni.InForStmt) -> None {
    target_ast = nd.target.gen.es_ast;
    left: es.Node = target_ast
        if isinstance(target_ast, es.Node)
        else self.sync_loc(es.Identifier(name='item'), jac_node=nd.target);
    right: es.Expression = cast(es.Expression, nd.collection.gen.es_ast)
        if nd.collection.gen.es_ast
        else self.sync_loc(es.Identifier(name='collection'), jac_node=nd.collection);
    body = self._build_block_statement(nd, nd.body);
    if isinstance(left, es.VariableDeclaration) {
        decl = left;
    } else {
        pattern = self._target_to_pattern(left, nd.target);
        declarator = self.sync_loc(
            es.VariableDeclarator(id=pattern, `init=None), jac_node=nd.target
        );
        decl = self.sync_loc(
            es.VariableDeclaration(declarations=[declarator], kind='const'),
            jac_node=nd.target
        );
    }
    for_stmt = self.sync_loc(
        es.ForOfStatement(left=decl, right=right, body=body, await_=nd.is_async),
        jac_node=nd
    );
    nd.gen.es_ast = for_stmt;
}

impl EsastGenPass._target_to_pattern(target: es.Node, loc: uni.UniNode) -> es.Node {
    if isinstance(target, es.SpreadElement) {
        inner = self._target_to_pattern(target.argument, loc)
            if target.argument
            else self.sync_loc(es.Identifier(name='_item'), jac_node=loc);
        return self.sync_loc(es.RestElement(argument=inner), jac_node=loc);
    }
    if isinstance(target, es.ArrayExpression) {
        elements: list[(es.Node | None)] = [];
        for elem in target.elements {
            elements.append(
                self._target_to_pattern(elem, loc) if elem is not None else None
            );
        }
        return self.sync_loc(es.ArrayPattern(elements=elements), jac_node=loc);
    }
    pattern_nodes = (
        es.Identifier,
        es.ArrayPattern,
        es.ObjectPattern,
        es.AssignmentPattern,
        es.RestElement
    );
    if isinstance(target, pattern_nodes) {
        return target;
    }
    return self.sync_loc(es.Identifier(name='_item'), jac_node=loc);
}

impl EsastGenPass.exit_iter_for_stmt(nd: uni.IterForStmt) -> None {
    `init: es.VariableDeclaration | es.Expression | None = None;
    if (nd.iter and nd.iter.gen.es_ast) {
        `init = cast('es.VariableDeclaration | es.Expression', nd.iter.gen.es_ast);
    }
    `test: (es.Expression | None) = None;
    if (nd.condition and nd.condition.gen.es_ast) {
        `test = cast(es.Expression, nd.condition.gen.es_ast);
    }
    update: (es.AssignmentExpression | None) = None;
    if (
        nd.count_by
        and nd.count_by.gen.es_ast
        and isinstance(nd.count_by.gen.es_ast, es.ExpressionStatement)
    ) {
        update = cast(es.AssignmentExpression, nd.count_by.gen.es_ast.expression);
    }
    body = self._build_block_statement(nd, nd.body);
    nd.gen.es_ast = self.sync_loc(
        es.ForStatement(`init=`init, `test=`test, update=update, body=body), jac_node=nd
    );
}

impl EsastGenPass.exit_while_stmt(nd: uni.WhileStmt) -> None {
    `test = self._coerce_truthy(
        nd.condition,
        cast(
            es.Expression,
            self._get_ast_or_default(
                nd.condition,
                default_factory=lambda (_src: any) { es.Literal(value=True); }
            )
        ),
        nd
    );
    body = self._build_block_statement(nd, nd.body);
    while_stmt = self.sync_loc(es.WhileStatement(`test=`test, body=body), jac_node=nd);
    nd.gen.es_ast = while_stmt;
}

impl EsastGenPass.exit_forever_stmt(nd: uni.ForeverStmt) -> None {
    body = self._build_block_statement(nd, nd.body);
    forever_stmt = self.sync_loc(
        es.WhileStatement(`test=es.Literal(value=True), body=body), jac_node=nd
    );
    nd.gen.es_ast = forever_stmt;
}

impl EsastGenPass.exit_else_stmt(nd: uni.ElseStmt) -> None {
    stmts = self._collect_stmt_body(nd.body);
    stmts = self._prepend_hoisted(nd, stmts);
    block = self.sync_loc(es.BlockStatement(body=stmts), jac_node=nd);
    nd.gen.es_ast = block;
}

impl EsastGenPass.exit_else_if(nd: uni.ElseIf) -> None {
    `test = self._coerce_truthy(
        nd.condition,
        cast(
            es.Expression,
            self._get_ast_or_default(
                nd.condition,
                default_factory=lambda (_src: any) { es.Literal(value=True); }
            )
        ),
        nd
    );
    consequent = self._build_block_statement(nd, nd.body);
    alternate: (es.Statement | None) = None;
    if (nd.else_body and nd.else_body.gen.es_ast) {
        alternate = cast(es.Statement, nd.else_body.gen.es_ast);
    }
    if_stmt = self.sync_loc(
        es.IfStatement(`test=`test, consequent=consequent, alternate=alternate),
        jac_node=nd
    );
    nd.gen.es_ast = if_stmt;
}

impl EsastGenPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    `test = self._coerce_truthy(
        nd.condition,
        cast(
            es.Expression,
            self._get_ast_or_default(
                nd.condition,
                default_factory=lambda (_src: any) { es.Literal(value=True); }
            )
        ),
        nd
    );
    consequent = self._build_block_statement(nd, nd.body);
    alternate: (es.Statement | None) = None;
    if (nd.else_body and nd.else_body.gen.es_ast) {
        alternate = cast(es.Statement, nd.else_body.gen.es_ast);
    }
    if_stmt = self.sync_loc(
        es.IfStatement(`test=`test, consequent=consequent, alternate=alternate),
        jac_node=nd
    );
    nd.gen.es_ast = if_stmt;
}

impl EsastGenPass.exit_jsx_expression(nd: uni.JsxExpression) -> None {
    self.jsx_processor.expression(nd);
}

impl EsastGenPass.enter_jsx_slot(nd: uni.JsxSlot) -> None {
    self._push_view_acc();
}

impl EsastGenPass.exit_jsx_slot(nd: uni.JsxSlot) -> None {
    acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
    acc_name = acc if isinstance(acc, str) else VIEW_ACC;
    nd.gen.es_ast = self._build_view_iife(nd.body, acc_name, nd);
}

impl EsastGenPass._cur_view_acc -> (str | None) {
    if self._view_stack and isinstance(self._view_stack[-1], str) {
        return self._view_stack[-1];
    }
    return None;
}

impl EsastGenPass._push_view_acc -> str {
    if not self._view_used_base {
        self._view_used_base = True;
        name = VIEW_ACC;
    } else {
        self._view_acc_counter += 1;
        name = f"{VIEW_ACC}_{self._view_acc_counter}";
    }
    self._view_stack.append(name);
    return name;
}

impl EsastGenPass._view_push_stmt(
    acc_name: str, value: es.Expression, anchor: uni.UniNode
) -> es.ExpressionStatement {
    member = self.sync_loc(
        es.MemberExpression(
            object=self.sync_loc(es.Identifier(name=acc_name), jac_node=anchor),
            property=self.sync_loc(es.Identifier(name='push'), jac_node=anchor),
            computed=False,
            optional=False
        ),
        jac_node=anchor
    );
    call = self.sync_loc(
        es.CallExpression(callee=member, arguments=[value]), jac_node=anchor
    );
    return self.sync_loc(es.ExpressionStatement(expression=call), jac_node=anchor);
}

impl EsastGenPass._jsx_fragment(
    children: list[es.Expression], anchor: uni.UniNode
) -> es.CallExpression {
    import from jaclang.runtimelib.client_surface { backend_jsx_factory_name }
    self._ensure_backend();
    factory_name = backend_jsx_factory_name(self.backend);
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name=factory_name), jac_node=anchor),
            arguments=[
                self.sync_loc(es.Literal(value=None), jac_node=anchor),
                self.sync_loc(es.ObjectExpression(properties=[]), jac_node=anchor),
                self.sync_loc(es.ArrayExpression(elements=children), jac_node=anchor)
            ]
        ),
        jac_node=anchor
    );
}

impl EsastGenPass._view_fragment_return(
    acc_name: str, anchor: uni.UniNode
) -> es.ReturnStatement {
    frag = self._jsx_fragment(
        [self.sync_loc(es.Identifier(name=acc_name), jac_node=anchor)], anchor
    );
    return self.sync_loc(es.ReturnStatement(argument=frag), jac_node=anchor);
}

impl EsastGenPass._build_view_iife(
    body_nodes: (Sequence[uni.UniNode] | None), acc_name: str, anchor: uni.UniNode
) -> es.CallExpression {
    init = self.sync_loc(
        es.VariableDeclaration(
            declarations=[
                self.sync_loc(
                    es.VariableDeclarator(
                        id=self.sync_loc(es.Identifier(name=acc_name), jac_node=anchor),
                        `init=self.sync_loc(
                            es.ArrayExpression(elements=[]), jac_node=anchor
                        )
                    ),
                    jac_node=anchor
                )
            ],
            kind='let'
        ),
        jac_node=anchor
    );
    stmts: list[es.Statement] = [init];
    stmts.extend(self._collect_stmt_body(body_nodes));
    stmts.append(self._view_fragment_return(acc_name, anchor));
    block = self.sync_loc(es.BlockStatement(body=stmts), jac_node=anchor);
    arrow = self.sync_loc(
        es.ArrowFunctionExpression(params=[], body=block, async_=False), jac_node=anchor
    );
    return self.sync_loc(
        es.CallExpression(callee=arrow, arguments=[]), jac_node=anchor
    );
}

impl EsastGenPass.exit_jsx_text(nd: uni.JsxText) -> None {
    self.jsx_processor.text(nd);
}

impl EsastGenPass.exit_jsx_comment(nd: uni.JsxComment) -> None {
    nd.gen.es_ast = None;
}

impl EsastGenPass.exit_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None { }

impl EsastGenPass.exit_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None {
    self.jsx_processor.spread_attribute(nd);
}

impl EsastGenPass.exit_jsx_element_name(nd: uni.JsxElementName) -> None {
    self.jsx_processor.element_name(nd);
}

impl EsastGenPass.exit_jsx_element(nd: uni.JsxElement) -> None {
    if (
        nd.name is not None
        and nd.name.parts
        and isinstance(nd.name.parts[0], uni.Name)
        and nd.name.parts[0].value in ("JacAwaiting", "JacClientErrorBoundary")
    ) {
        self._inject_runtime_import(nd.name.parts[0].value, nd);
    }

    if nd.dynamic_tag is not None {
        self._ensure_backend();
        if self.backend.import_source("Dynamic") != self.backend.runtime_module() {
            self._inject_runtime_import("Dynamic", nd);
        }
    }
    nd.gen.es_ast = self.jsx_processor.element(nd);

    self._ensure_backend();
    view = self.jsx_processor._view_by_node.get(id(nd));
    if view is not None {
        for sym in self.backend.view_runtime_symbols(view) {
            self._inject_runtime_import(sym, nd);
        }
    }
}

impl EsastGenPass.exit_has_var(nd: uni.HasVar) -> None {
    nd.gen.es_ast = None;
}

impl EsastGenPass._has_import(name: str) -> bool {
    for import_decl in self.imports {
        for spec in import_decl.specifiers {
            if isinstance(spec, es.ImportSpecifier) {
                if spec.local and spec.local.name == name {
                    return True;
                }
            }
        }
    }
    return False;
}

impl EsastGenPass._register_jac_runtime_import -> None {
    import from jaclang.jac0core.modresolver { resolve_jac_virtual_module_path }
    self._ensure_backend();
    module_id = self.backend.runtime_module();
    if module_id not in self.client_manifest.imports {
        runtime_path = resolve_jac_virtual_module_path(module_id);
        if runtime_path {
            self.client_manifest.imports[module_id] = runtime_path;
        }
    }
}

impl EsastGenPass._inject_runtime_import(name: str, nd: uni.UniNode) -> None {
    import from jaclang.runtimelib.client_surface { runtime_import_source }
    self._ensure_backend();
    if name in self.injected_imports or self._has_import(name) {
        return;
    }
    src = runtime_import_source(name, self.backend);
    specifier = self.sync_loc(
        es.ImportSpecifier(
            imported=es.Identifier(name=name), local=es.Identifier(name=name)
        ),
        jac_node=nd
    );
    source = self.sync_loc(es.Literal(value=src, raw='"' + src + '"'), jac_node=nd);
    import_decl = self.sync_loc(
        es.ImportDeclaration(specifiers=[specifier], source=source), jac_node=nd
    );
    self.imports.append(import_decl);
    self.injected_imports.add(name);
    if src.startswith('@jac/') {
        self._register_jac_runtime_import();
    }
}

impl EsastGenPass._ref_head_name(expr: (uni.UniNode | None)) -> (str | None) {
    cur = expr;
    while True {
        if isinstance(cur, uni.FuncCall) {
            cur = cur.target;
        } elif isinstance(cur, uni.AtomTrailer) {
            cur = cur.target;
        } else {
            break;
        }
    }
    return cur.value if isinstance(cur, uni.Name) else None;
}

impl EsastGenPass._ref_forward_param(nd: uni.Ability) -> (uni.ParamVar | None) {
    if not isinstance(nd.signature, uni.FuncSignature) {
        return None;
    }
    params = nd.signature.params;
    if not params {
        return None;
    }
    last = params[-1];
    if (
        last.type_tag is not None and self._ref_head_name(last.type_tag.tag) == 'Ref'
    ) {
        return last;
    }
    return None;
}

impl EsastGenPass._transform_to_useeffect(nd: uni.Ability) -> None {
    inner = self.unwrap_body(nd);
    body_stmts = self._collect_stmt_body(inner);

    is_entry = nd.signature.event.name == Tok.KW_ENTRY;
    is_async = nd.is_async;

    deps_elements: list[es.Expression | es.SpreadElement | None] = [];
    arch_tag = nd.signature.arch_tag_info;
    if arch_tag {
        if isinstance(arch_tag, (uni.ListVal, uni.TupleVal)) {
            for item in arch_tag.values {
                if item.gen.es_ast {
                    deps_elements.append(cast(es.Expression, item.gen.es_ast));
                }
            }
        } elif arch_tag.gen.es_ast {
            deps_elements.append(cast(es.Expression, arch_tag.gen.es_ast));
        }
    }
    effect = Effect(
        body=body_stmts, deps=deps_elements, is_entry=is_entry, is_async=is_async
    );
    self._ensure_backend();
    for sym in self.backend.effect_symbols(effect) {
        self._inject_runtime_import(sym, nd);
    }
    lowered = self.backend.lower_effect(effect);
    if lowered {
        nd.gen.es_ast = self.sync_loc(lowered[0], jac_node=nd);
    }
}

impl EsastGenPass.exit_arch_has(nd: uni.ArchHas) -> None {
    owner: (uni.UniNode | None) = nd.parent;
    while (owner is not None and not isinstance(owner, (uni.Ability, uni.Archetype))) {
        owner = owner.parent;
    }
    if isinstance(owner, uni.Archetype) or not nd.in_client_context() {
        nd.gen.es_ast = None;
        return;
    }

    statements: list[es.Statement] = [];
    for has_var in nd.vars {
        var_name = has_var.name.sym_name;

        ref_ctor = (
            isinstance(has_var.value, uni.FuncCall)
            and self._ref_head_name(has_var.value) == 'Ref'
        );
        ref_typed = (
            has_var.type_tag is not None
            and self._ref_head_name(has_var.type_tag.tag) == 'Ref'
        );
        if ref_ctor or ref_typed {
            if ref_typed and not ref_ctor {
                self.emit(E2025, node_override=has_var);
            }
            ref_init: es.Expression = self.sync_loc(
                es.Literal(value=None, raw='null'), jac_node=has_var
            );
            if isinstance(has_var.value, uni.FuncCall) and has_var.value.params {
                seed = has_var.value.params[0];
                seed_expr = seed.value if isinstance(seed, uni.KWPair) else seed;
                if seed_expr.gen.es_ast {
                    ref_init = cast(es.Expression, seed_expr.gen.es_ast);
                }
            }
            ref_field = RefField(name=var_name, init_expr=ref_init);
            self._ensure_backend();
            for sym in self.backend.ref_field_symbols(ref_field) {
                self._inject_runtime_import(sym, nd);
            }
            for stmt in self.backend.lower_ref_field(ref_field) {
                statements.append(self.sync_loc(stmt, jac_node=has_var));
            }
            self._register_declaration(var_name);
            continue;
        }

        init_value: es.Expression;
        if has_var.value and has_var.value.gen.es_ast {
            init_value = cast(es.Expression, has_var.value.gen.es_ast);
        } else {
            init_value = es.Identifier(name='undefined');
        }

        state_field = StateField(name=var_name, init_expr=init_value);
        self._ensure_backend();
        for sym in self.backend.state_field_symbols(state_field) {
            self._inject_runtime_import(sym, nd);
        }
        for stmt in self.backend.lower_state_field(state_field) {
            statements.append(self.sync_loc(stmt, jac_node=has_var));
        }

        self.reactive_vars.add(var_name);
        self._register_declaration(var_name);
    }
    if len(statements) == 1 {
        nd.gen.es_ast = statements[0];
    } elif len(statements) > 1 {
        nd.gen.es_ast = statements;
    } else {
        nd.gen.es_ast = None;
    }
}

impl EsastGenPass.exit_param_var(nd: uni.ParamVar) -> None {
    param_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);
    self._register_declaration(param_id.name);
    if nd.is_vararg or nd.is_kwargs {
        nd.gen.es_ast = self.sync_loc(es.RestElement(argument=param_id), jac_node=nd);
    } elif nd.value and nd.value.gen.es_ast {
        nd.gen.es_ast = self.sync_loc(
            es.AssignmentPattern(
                left=param_id, right=cast(es.Expression, nd.value.gen.es_ast)
            ),
            jac_node=nd
        );
    } else {
        nd.gen.es_ast = param_id;
    }
}

impl EsastGenPass.exit_func_signature(nd: uni.FuncSignature) -> None {
    nd.gen.es_ast = None;
}

impl EsastGenPass.exit_ability(nd: uni.Ability) -> None {
    if self._view_stack {
        self._view_stack.pop();
    }

    if self.reactive_vars_stack {
        self.reactive_vars = self.reactive_vars_stack.pop();
    }

    osp_info = self._osp_ability_info(nd);
    if osp_info is not None {
        self._emit_osp_slot_method(nd, osp_info);
        return;
    }

    if (isinstance(nd.signature, uni.EventSignature) and nd.in_client_context()) {
        self._transform_to_useeffect(nd);
        return;
    }

    ref_param: (uni.ParamVar | None) = None;
    if (
        nd.code_context == CodeContext.CLIENT
        and not nd.is_method
        and self._component_call_abi(nd) in ('props_destructure', 'props_passthrough')
    ) {
        ref_param = self._ref_forward_param(nd);
    }
    if (nd.code_context == CodeContext.CLIENT and not nd.is_method) {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub {
            name = nd.name_ref.sym_name;
            self.client_manifest.exports.append(name);
            if (
                isinstance(nd.signature, uni.FuncSignature)
                and nd.signature.return_type is not None
                and self._return_type_includes_jsx_element(nd.signature.return_type)
            ) {
                self.component_export_names.add(name);
            }

            self.client_manifest.params[name] = [
                p.name.sym_name
                for p in nd.signature.params
                if p is not ref_param
            ]
                if isinstance(nd.signature, uni.FuncSignature)
                else [];
        }
    }
    component_call_abi = self._component_call_abi(nd);
    params: list[es.Pattern] = [];
    destructure_stmts: list[es.Statement] = [];
    destructure_props: list[es.AssignmentProperty | es.RestElement] = [];

    sig_params = (
        [
            p
            for p in nd.signature.params
            if p is not ref_param
        ]
            if isinstance(nd.signature, uni.FuncSignature)
            else []
    );
    value_params = (
        [
            p
            for p in nd.signature.get_parameters()
            if p is not ref_param
        ]
            if isinstance(nd.signature, uni.FuncSignature)
            else []
    );
    if value_params {
        if component_call_abi == 'props_destructure' {
            params.append(es.Identifier(name="props"));
            for param in sig_params {
                param_key = self.sync_loc(
                    es.Identifier(name=param.name.sym_name), jac_node=param.name
                );
                destructure_props.append(
                    self.sync_loc(
                        es.AssignmentProperty(
                            key=param_key,
                            value=cast(es.Pattern, param.gen.es_ast),
                            shorthand=not isinstance(
                                param.gen.es_ast, es.AssignmentPattern
                            ),
                        ),
                        jac_node=param,
                    )
                );
            }
            destructure_stmts = [
                self.sync_loc(
                    es.VariableDeclaration(
                        declarations=[
                            self.sync_loc(
                                es.VariableDeclarator(
                                    id=self.sync_loc(
                                        es.ObjectPattern(properties=destructure_props),
                                        jac_node=nd,
                                    ),
                                    `init=self.sync_loc(
                                        es.Identifier(name="props"), jac_node=nd
                                    ),
                                ),
                                jac_node=nd,
                            )
                        ],
                        kind="const",
                    ),
                    jac_node=nd,
                )
            ];
        } else {
            if component_call_abi == 'props_passthrough' {
                self.emit(
                    W5015, node_override=value_params[0], component=nd.name_ref.sym_name
                );
            }
            for param in value_params {
                if param.gen.es_ast {
                    params.append(cast(es.Pattern, param.gen.es_ast));
                }
            }
        }
    }
    if ref_param is not None {
        if not params {
            params.append(self.sync_loc(es.Identifier(name="props"), jac_node=nd));
        }
        params.append(
            cast(es.Pattern, ref_param.gen.es_ast)
                if ref_param.gen.es_ast
                else self.sync_loc(
                    es.Identifier(name=ref_param.name.sym_name), jac_node=ref_param.name
                )
        );
    }
    inner = self.unwrap_body(nd);
    body_stmts = self._collect_stmt_body(inner);
    body_stmts = self._prepend_hoisted(nd, body_stmts);
    block = self.sync_loc(
        es.BlockStatement(body=destructure_stmts + body_stmts), jac_node=nd
    );
    func_id = self.sync_loc(
        es.Identifier(name=nd.name_ref.sym_name), jac_node=nd.name_ref
    );
    if nd.is_method {
        func_expr = self.sync_loc(
            es.FunctionExpression(
                id=None, params=params, body=block, async_=nd.is_async
            ),
            jac_node=nd
        );
        method_def = self.sync_loc(
            es.MethodDefinition(
                key=func_id, value=func_expr, kind='method', `static=nd.is_static
            ),
            jac_node=nd
        );
        nd.gen.es_ast = method_def;
    } elif ref_param is not None {
        self._inject_runtime_import('forwardRef', nd);
        func_expr = self.sync_loc(
            es.FunctionExpression(
                id=func_id, params=params, body=block, async_=nd.is_async
            ),
            jac_node=nd
        );
        forward_call = self.sync_loc(
            es.CallExpression(
                callee=es.Identifier(name='forwardRef'), arguments=[func_expr]
            ),
            jac_node=nd
        );
        declarator = self.sync_loc(
            es.VariableDeclarator(
                id=self.sync_loc(
                    es.Identifier(name=nd.name_ref.sym_name), jac_node=nd.name_ref
                ),
                `init=forward_call,
            ),
            jac_node=nd
        );
        nd.gen.es_ast = self.sync_loc(
            es.VariableDeclaration(declarations=[declarator], kind='const'), jac_node=nd
        );
    } else {
        pascal = self._component_pascal_name(nd);
        if pascal is not None {
            func_decl = self.sync_loc(
                es.FunctionDeclaration(
                    id=self.sync_loc(es.Identifier(name=pascal), jac_node=nd.name_ref),
                    params=params,
                    body=block,
                    async_=nd.is_async
                ),
                jac_node=nd
            );
            alias_decl = self.sync_loc(
                es.VariableDeclaration(
                    declarations=[
                        self.sync_loc(
                            es.VariableDeclarator(
                                id=self.sync_loc(
                                    es.Identifier(name=nd.name_ref.sym_name),
                                    jac_node=nd.name_ref
                                ),
                                `init=self.sync_loc(
                                    es.Identifier(name=pascal), jac_node=nd.name_ref
                                ),
                            ),
                            jac_node=nd
                        )
                    ],
                    kind='const'
                ),
                jac_node=nd
            );
            nd.gen.es_ast = [func_decl, alias_decl];
        } else {
            func_decl = self.sync_loc(
                es.FunctionDeclaration(
                    id=func_id, params=params, body=block, async_=nd.is_async
                ),
                jac_node=nd
            );
            nd.gen.es_ast = func_decl;
        }
    }
}

impl EsastGenPass._osp_model -> OspModel {
    import from jaclang.jac0core.osp_model { get_osp_model }
    _root = self.ir_in if isinstance(self.ir_in, uni.Module) else self.get_main_mod();
    return get_osp_model(_root);
}

impl EsastGenPass._osp_ability_info(nd: uni.Ability) -> (dict | None) {
    if not isinstance(nd.signature, uni.EventSignature) {
        return None;
    }
    if nd.body is None {
        return None;
    }
    owner = nd.method_owner;
    if not isinstance(owner, uni.Archetype) {
        return None;
    }
    kind = owner.arch_kind;
    if kind is None {
        return None;
    }
    if (nd.name_ref is None) or (owner.name is None) {
        return None;
    }
    return {
        "owner": owner.name.sym_name,
        "kind": kind,
        "is_entry": nd.signature.event.name == Tok.KW_ENTRY,
        "name": nd.name_ref.sym_name
    };
}

impl EsastGenPass._osp_const_decl(
    name: str, `init: es.Expression, nd: uni.UniNode
) -> es.VariableDeclaration {
    return self.sync_loc(
        es.VariableDeclaration(
            kind='const',
            declarations=[
                es.VariableDeclarator(id=es.Identifier(name=name), `init=`init)
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._emit_osp_slot_method(nd: uni.Ability, osp: dict) -> None {
    self.needs_jac_runtime = True;
    is_walker = osp["kind"] == "walker";
    other_ref = self.sync_loc(es.Identifier(name="__other"), jac_node=nd);
    this_ref = self.sync_loc(es.ThisExpression(), jac_node=nd);
    here_init = other_ref if is_walker else this_ref;
    visitor_init = this_ref if is_walker else other_ref;
    binds: list[es.Statement] = [
        self._osp_const_decl("here", here_init, nd),
        self._osp_const_decl("visitor", visitor_init, nd)
    ];
    inner = self.unwrap_body(nd);
    body_stmts = self._collect_stmt_body(inner);
    body_stmts = self._prepend_hoisted(nd, body_stmts);
    block = self.sync_loc(es.BlockStatement(body=binds + body_stmts), jac_node=nd);
    func_expr = self.sync_loc(
        es.FunctionExpression(
            id=None,
            params=[self.sync_loc(es.Identifier(name="__other"), jac_node=nd)],
            body=block,
            async_=nd.is_async
        ),
        jac_node=nd
    );
    nd.gen.es_ast = self.sync_loc(
        es.MethodDefinition(
            key=self.sync_loc(
                es.Identifier(name=nd.name_ref.sym_name), jac_node=nd.name_ref
            ),
            value=func_expr,
            kind='method',
            `static=False
        ),
        jac_node=nd
    );
}

impl EsastGenPass._osp_arch_kinds -> dict[str, str] {
    _model = self._osp_model();
    if not _model.has_local_ability() {
        return {};
    }
    return _model.arch_kind;
}

impl EsastGenPass._osp_arch_set -> set[str] {
    return set(self._osp_arch_kinds().keys());
}

impl EsastGenPass._osp_var_arch -> dict[str, str] {
    if self._osp_var_arch_cache is not None {
        return self._osp_var_arch_cache;
    }
    bindings: dict[str, str] = {};
    kinds = self._osp_arch_kinds();
    if kinds {
        scan_root = self.ir_in
            if isinstance(self.ir_in, uni.Module)
            else self.get_main_mod();
        for asn in scan_root.get_all_sub_nodes(uni.Assignment) {
            if isinstance(asn.value, uni.FuncCall) {
                head = self._ref_head_name(asn.value);
                if (head is not None) and (head in kinds) {
                    for tgt in asn.target {
                        if isinstance(tgt, uni.Name) {
                            bindings[tgt.sym_name] = head;
                        }
                    }
                }
            }
        }
    }
    self._osp_var_arch_cache = bindings;
    return bindings;
}

impl EsastGenPass._spawn_walker_arch(expr: uni.Expr) -> (str | None) {
    kinds = self._osp_arch_kinds();
    head = self._ref_head_name(expr);
    if (head is not None) and (kinds.get(head) == "walker") {
        return head;
    }
    if isinstance(expr, uni.Name) {
        bound = self._osp_var_arch().get(expr.sym_name);
        if (bound is not None) and (kinds.get(bound) == "walker") {
            return bound;
        }
    }
    return None;
}

impl EsastGenPass._spawn_target_is_local_node(expr: uni.Expr) -> bool {
    kinds = self._osp_arch_kinds();
    head = self._ref_head_name(expr);
    if (head is not None) and (kinds.get(head) in ("node", "edge")) {
        return True;
    }
    if isinstance(expr, uni.Name) {
        bound = self._osp_var_arch().get(expr.sym_name);
        if (bound is not None) and (kinds.get(bound) in ("node", "edge")) {
            return True;
        }
    }
    return False;
}

impl EsastGenPass._build_local_osp_spawn(
    nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
) -> (es.Expression | None) {
    walker_es: (es.Expression | None) = None;
    target_es: (es.Expression | None) = None;
    target_expr: (uni.Expr | None) = None;
    if self._spawn_walker_arch(nd.left) is not None {
        walker_es = left;
        target_es = right;
        target_expr = nd.right;
    } elif self._spawn_walker_arch(nd.right) is not None {
        walker_es = right;
        target_es = left;
        target_expr = nd.left;
    } else {
        return None;
    }

    if not self._spawn_target_is_local_node(target_expr) {
        return None;
    }
    self.needs_osp_kernel = True;
    self.needs_jac_runtime = True;
    tag_lookup = self.sync_loc(
        es.MemberExpression(
            object=self.sync_loc(es.Identifier(name="__ospDESC"), jac_node=nd),
            property=self.sync_loc(
                es.MemberExpression(
                    object=walker_es,
                    property=self.sync_loc(es.Identifier(name="__tag"), jac_node=nd),
                    computed=False
                ),
                jac_node=nd
            ),
            computed=True
        ),
        jac_node=nd
    );
    starts = self.sync_loc(es.ArrayExpression(elements=[target_es]), jac_node=nd);
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name="osp_spawn"), jac_node=nd),
            arguments=[
                self.sync_loc(es.Identifier(name="__ospRT"), jac_node=nd),
                walker_es,
                tag_lookup,
                starts
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._build_osp_setup_js -> str {
    _model = self._osp_model();

    arch_kinds = self._osp_arch_kinds();
    tags = _model.tags;

    entry_by_owner: dict[str, list] = {};
    exit_by_owner: dict[str, list] = {};
    for slot in _model.local_slots() {
        bucket = entry_by_owner if slot.is_entry else exit_by_owner;
        if slot.owner not in bucket {
            bucket[slot.owner] = [];
        }
        bucket[slot.owner].append(slot);
    }

    lines: list[str] = [];
    isa_parts: list[str] = [];
    for name in arch_kinds.keys() {
        tag = tags[name];
        lines.append(f"{name}.prototype.__tag = {tag};");
        isa_members = ", ".join(
            [
                str(tags[a])
                for a in _model.isa.get(name, [])
                if a in tags
            ]
        );
        isa_parts.append(f"{tag}: new Set([{isa_members}])");
    }
    lines.append("const __ospISA = {" + ", ".join(isa_parts) + "};");
    desc_parts: list[str] = [];
    for name in arch_kinds.keys() {
        tag = tags[name];
        desc_cls = "WalkerDesc" if (arch_kinds[name] == "walker") else "NodeDesc";
        entry_js = self._osp_slots_js(entry_by_owner.get(name, []), tags);
        exit_js = self._osp_slots_js(exit_by_owner.get(name, []), tags);
        desc_parts.append(
            f"{tag}: new {desc_cls}({{type_tag: {tag}, entry: {entry_js}, exit: {exit_js}}})"
        );
    }
    lines.append("const __ospDESC = {" + ", ".join(desc_parts) + "};");
    lines.append(
        "const __ospRT = new OspRuntime({" + "tag_of: (h) => h.__tag, " + "is_a: (t, b) => __ospISA[t] ? __ospISA[t].has(b) : (t === b), " + "node_desc: (t) => __ospDESC[t], " + "on_complete: (s, ok) => { if (s.wlk) s.wlk.reports = s.reports; }" + "});"
    );
    return "\n".join(lines);
}

impl EsastGenPass._osp_slots_js(slots: list, tags: dict) -> str {
    parts: list[str] = [];
    for slot in slots {
        fn = "(o, x) => o." + slot.ability + "(x)";
        if not slot.trigger_names {
            parts.append("new Slot({trig_tag: -1, fn: " + fn + "})");
        } else {
            for trig in slot.trigger_names {
                ttag = tags[trig] if (trig in tags) else -1;
                parts.append(f"new Slot({{trig_tag: {ttag}, fn: {fn}}})");
            }
        }
    }
    return "[" + ", ".join(parts) + "]";
}

impl EsastGenPass.exit_visit_stmt(nd: uni.VisitStmt) -> None {
    self.needs_osp_kernel = True;
    self.needs_jac_runtime = True;
    target = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.target,
            default_factory=lambda (_src: any) { es.ArrayExpression(elements=[]); }
        )
    );

    if not isinstance(nd.target, (uni.EdgeRefTrailer, uni.ListVal)) {
        target = self.sync_loc(es.ArrayExpression(elements=[target]), jac_node=nd);
    }
    insert: es.Expression = self.sync_loc(
        es.UnaryExpression(operator='-', argument=es.Literal(value=1), prefix=True),
        jac_node=nd
    );
    if nd.insert_loc and nd.insert_loc.gen.es_ast {
        insert = cast(es.Expression, nd.insert_loc.gen.es_ast);
    }
    nd.gen.es_ast = self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(es.Identifier(name='osp_visit'), jac_node=nd),
                    arguments=[target, insert]
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
}

impl EsastGenPass.exit_disengage_stmt(nd: uni.DisengageStmt) -> None {
    self.needs_osp_kernel = True;
    nd.gen.es_ast = self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.Identifier(name='osp_disengage'), jac_node=nd
                    ),
                    arguments=[]
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
}

impl EsastGenPass.exit_report_stmt(nd: uni.ReportStmt) -> None {
    self.needs_osp_kernel = True;
    expr = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.expr, default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );
    nd.gen.es_ast = self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(es.Identifier(name='osp_report'), jac_node=nd),
                    arguments=[expr]
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
}

impl EsastGenPass.exit_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> None {
    result = self._build_edge_ref(nd);
    if result is not None {
        nd.gen.es_ast = result;
    }
}

impl EsastGenPass._build_edge_ref(nd: uni.EdgeRefTrailer) -> (es.Expression | None) {
    if not nd.chain {
        return None;
    }
    step = nd.chain[0];
    if not isinstance(step, uni.EdgeOpRef) {
        return None;
    }
    self.needs_osp_graph = True;

    origin: es.Expression = self.sync_loc(es.Identifier(name='here'), jac_node=nd);
    direction = self.sync_loc(es.Literal(value=int(step.edge_dir.value)), jac_node=nd);
    edge_tag: es.Expression = self.sync_loc(es.Literal(value=None), jac_node=nd);
    fcond = step.filter_cond;
    if (fcond is not None) and (fcond.f_type is not None) {
        edge_tag = self.sync_loc(
            es.MemberExpression(
                object=self.sync_loc(
                    es.MemberExpression(
                        object=self.sync_loc(
                            es.Identifier(name=fcond.f_type.value), jac_node=nd
                        ),
                        property=self.sync_loc(
                            es.Identifier(name='prototype'), jac_node=nd
                        ),
                        computed=False
                    ),
                    jac_node=nd
                ),
                property=self.sync_loc(es.Identifier(name='__tag'), jac_node=nd),
                computed=False
            ),
            jac_node=nd
        );
    }
    edges_only = self.sync_loc(es.Literal(value=bool(nd.edges_only)), jac_node=nd);
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__ospRefs'), jac_node=nd),
            arguments=[origin, direction, edge_tag, edges_only]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._build_osp_graph_call(
    nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
) -> (es.Expression | None) {
    co = nd.op;
    if not isinstance(co, uni.ConnectOp) {
        return None;
    }
    self.needs_osp_graph = True;
    dir_val = int(co.edge_dir.value);

    undirected = dir_val == 3;
    if dir_val == 1 {
        (src, tgt) = (right, left);
    } else {
        (src, tgt) = (left, right);
    }
    make_edge: es.Expression = self.sync_loc(es.Literal(value=None), jac_node=nd);
    if (co.conn_type is not None) and co.conn_type.gen.es_ast {
        make_edge = self.sync_loc(
            es.ArrowFunctionExpression(
                params=[],
                body=cast(es.Expression, co.conn_type.gen.es_ast),
                expression=True
            ),
            jac_node=nd
        );
    }
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__ospConn'), jac_node=nd),
            arguments=[
                src,
                tgt,
                make_edge,
                self.sync_loc(es.Literal(value=undirected), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass.enter_ability(nd: uni.Ability) -> None {
    if isinstance(nd.body, uni.ImplDef) and (nd.body not in nd.kid) {
        nd.add_kids_right([nd.body], pos_update=False, parent_update=True);
    }

    self._view_stack.append(None);
    self.reactive_vars_stack.append(self.reactive_vars);
    self.reactive_vars = set(self.reactive_vars);
}

impl EsastGenPass.exit_enum(nd: uni.Enum) -> None {
    if nd.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub {
            self.client_manifest.exports.append(nd.name.sym_name);
        }
    }
    properties: list[(es.Property | es.SpreadElement)] = [];
    inner = self.unwrap_body(nd);
    if inner {
        for stmt in inner {
            if isinstance(stmt, uni.Assignment) {
                for target in stmt.target {
                    if isinstance(target, uni.AstSymbolNode) {
                        key = self.sync_loc(
                            es.Identifier(name=target.sym_name), jac_node=target
                        );
                        enum_value: es.Expression;
                        if (stmt.value and stmt.value.gen.es_ast) {
                            enum_value = cast(es.Expression, stmt.value.gen.es_ast);
                        } else {
                            enum_value = self.sync_loc(
                                es.Literal(value=None), jac_node=stmt
                            );
                        }
                        prop = self.sync_loc(
                            es.Property(key=key, value=enum_value, kind='init'),
                            jac_node=stmt
                        );
                        properties.append(prop);
                    }
                }
            }
        }
    }
    obj_expr = self.sync_loc(es.ObjectExpression(properties=properties), jac_node=nd);
    var_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);
    var_decl = self.sync_loc(
        es.VariableDeclaration(
            declarations=[
                self.sync_loc(
                    es.VariableDeclarator(id=var_id, `init=obj_expr), jac_node=nd
                )
            ],
            kind='const'
        ),
        jac_node=nd
    );
    nd.gen.es_ast = var_decl;
}

impl EsastGenPass.exit_type_alias(nd: uni.TypeAlias) -> None {
    nd.gen.es_ast = [];
}

impl EsastGenPass.exit_type_param(nd: uni.TypeParam) -> None {
    nd.gen.es_ast = [];
}

impl EsastGenPass.exit_archetype(nd: uni.Archetype) -> None {
    if nd.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub {
            self.client_manifest.exports.append(nd.name.sym_name);
        }
    }
    body_stmts: list[es.MethodDefinition | es.PropertyDefinition] = [];
    has_members: list[uni.ArchHas] = [];
    inner = self.unwrap_body(nd);
    if inner {
        for stmt in inner {
            if isinstance(stmt, uni.ArchHas) {
                has_members.append(stmt);
                continue;
            }
            if (
                stmt.gen.es_ast
                and stmt.gen.es_ast
                and isinstance(
                    stmt.gen.es_ast, (es.MethodDefinition, es.PropertyDefinition)
                )
            ) {
                body_stmts.append(stmt.gen.es_ast);
            }
        }
    }

    is_local_osp_arch = (
        (nd.name is not None)
        and (nd.name.sym_name in self._osp_arch_set())
        and (nd.arch_kind is not None)
    );
    if (((nd.arch_type.name == Tok.KW_OBJECT) or is_local_osp_arch) and has_members) {
        constructor_stmts: list[es.Statement] = [];
        props_param = self.sync_loc(
            es.AssignmentPattern(
                left=self.sync_loc(es.Identifier(name='props'), jac_node=nd),
                right=self.sync_loc(es.ObjectExpression(properties=[]), jac_node=nd)
            ),
            jac_node=nd
        );
        for arch_has in has_members {
            if arch_has.is_static {
                for var in arch_has.vars {
                    default_expr: es.Expression = cast(
                        es.Expression, var.value.gen.es_ast
                    )
                        if (var.value and var.value.gen.es_ast and var.value.gen.es_ast)
                        else self.sync_loc(es.Literal(value=None), jac_node=var);
                    static_prop = self.sync_loc(
                        es.PropertyDefinition(
                            key=self.sync_loc(
                                es.Identifier(name=var.name.sym_name), jac_node=var.name
                            ),
                            value=default_expr,
                            `static=True
                        ),
                        jac_node=var
                    );
                    body_stmts.append(static_prop);
                }
                continue;
            }
            for var in arch_has.vars {
                props_ident = self.sync_loc(es.Identifier(name='props'), jac_node=var);
                prop_ident = self.sync_loc(
                    es.Identifier(name=var.name.sym_name), jac_node=var.name
                );
                this_member = self.sync_loc(
                    es.MemberExpression(
                        object=self.sync_loc(es.ThisExpression(), jac_node=var),
                        property=prop_ident,
                        computed=False
                    ),
                    jac_node=var
                );
                props_access = self.sync_loc(
                    es.MemberExpression(
                        object=props_ident,
                        property=self.sync_loc(
                            es.Identifier(name=var.name.sym_name), jac_node=var.name
                        ),
                        computed=False
                    ),
                    jac_node=var
                );
                has_call = self.sync_loc(
                    es.CallExpression(
                        callee=self.sync_loc(
                            es.MemberExpression(
                                object=props_ident,
                                property=self.sync_loc(
                                    es.Identifier(name='hasOwnProperty'), jac_node=var
                                ),
                                computed=False
                            ),
                            jac_node=var
                        ),
                        arguments=[
                            self.sync_loc(
                                es.Literal(value=var.name.sym_name), jac_node=var.name
                            )
                        ]
                    ),
                    jac_node=var
                );
                default_val: es.Expression = cast(es.Expression, var.value.gen.es_ast)
                    if (var.value and var.value.gen.es_ast and var.value.gen.es_ast)
                    else self.sync_loc(es.Literal(value=None), jac_node=var);
                conditional = self.sync_loc(
                    es.ConditionalExpression(
                        `test=has_call, consequent=props_access, alternate=default_val
                    ),
                    jac_node=var
                );
                assignment = self.sync_loc(
                    es.AssignmentExpression(
                        operator='=', left=this_member, right=conditional
                    ),
                    jac_node=var
                );
                constructor_stmts.append(
                    self.sync_loc(
                        es.ExpressionStatement(expression=assignment), jac_node=var
                    )
                );
            }
        }
        if constructor_stmts {
            constructor_method = self.sync_loc(
                es.MethodDefinition(
                    key=self.sync_loc(es.Identifier(name='constructor'), jac_node=nd),
                    value=self.sync_loc(
                        es.FunctionExpression(
                            id=None,
                            params=[props_param],
                            body=self.sync_loc(
                                es.BlockStatement(body=constructor_stmts), jac_node=nd
                            )
                        ),
                        jac_node=nd
                    ),
                    kind='constructor',
                    `static=False
                ),
                jac_node=nd
            );
            body_stmts.insert(0, constructor_method);
        }
    }
    class_body = self.sync_loc(es.ClassBody(body=body_stmts), jac_node=nd);
    super_class: (es.Expression | None) = None;
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if nd.base_classes {
        base = nd.base_classes[0];
        if base.gen.es_ast {
            super_class = cast(es.Expression, base.gen.es_ast);
            if (
                isinstance(super_class, es.Identifier)
                and JAC_TYPE_REGISTRY.is_exception(super_class.name)
            ) {
                super_class = self._jac_exc_ref(super_class.name, base);
            }
        }
    }
    class_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);
    class_decl = self.sync_loc(
        es.ClassDeclaration(id=class_id, superClass=super_class, body=class_body),
        jac_node=nd
    );
    nd.gen.es_ast = class_decl;
}

impl EsastGenPass.exit_import(nd: uni.Import) -> None {
    if nd.is_typed {
        nd.gen.es_ast = None;
        return;
    }

    if nd.is_sv_marked {
        if (nd.from_loc and nd.items) {
            self._generate_sv_import_stubs(nd);
            self._record_sv_backend(nd);
        }
        return;
    }
    if (nd.from_loc and nd.items) {
        resolved_path = nd.from_loc.resolve_relative_path();
        import_key = nd.from_loc.dot_path_str;
        self.client_manifest.imports[import_key] = resolved_path;
        self.client_manifest.has_client = True;

        import_path = nd.from_loc.dot_path_str;
        is_jac_runtime = nd.is_virtual_jac;
        if resolved_path.endswith('.jac')
        and not import_path.startswith('.')
        and not is_jac_runtime {
            import_path = '.' + import_path;
        }
        js_import_path = convert_to_js_import_path(import_path);
    } elif (not nd.from_loc and nd.items) {
        self.client_manifest.has_client = True;
        first_item = nd.items[0];
        if (isinstance(first_item, uni.ModulePath) and first_item.path) {
            path_elem = first_item.path[0];
            import_key = path_elem.lit_value
                if isinstance(path_elem, uni.String)
                else path_elem.value;
        } else {
            import_key = '';
        }
        resolved_path = resolve_relative_path(import_key, nd.loc.mod_path);
        self.client_manifest.imports[import_key] = resolved_path;
        import_path = import_key;
        if resolved_path.endswith('.jac') and not import_path.startswith('.') {
            import_path = '.' + import_path;
        }
        js_import_path = convert_to_js_import_path(import_path);
    } else {
        return;
    }
    source = self.sync_loc(es.Literal(value=js_import_path), jac_node=nd.from_loc);
    specifiers:
        list[
            es.ImportSpecifier | es.ImportDefaultSpecifier | es.ImportNamespaceSpecifier
        ] = [];
    for item in nd.items {
        if isinstance(item, uni.ModuleItem) {
            if isinstance(item.name, uni.Name) {
                imported = self.sync_loc(
                    es.Identifier(name=item.name.sym_name), jac_node=item.name
                );
                local = self.sync_loc(
                    es.Identifier(
                        name=item.alias.sym_name if item.alias else item.name.sym_name
                    ),
                    jac_node=item.alias or item.name
                );
                specifiers.append(
                    self.sync_loc(
                        es.ImportSpecifier(imported=imported, local=local),
                        jac_node=item
                    )
                );
            } elif isinstance(item.name, uni.Token) {
                if (item.name.value == 'default') {
                    if not item.alias {
                        continue;
                    }
                    local = self.sync_loc(
                        es.Identifier(name=item.alias.sym_name), jac_node=item.alias
                    );
                    specifiers.append(
                        self.sync_loc(
                            es.ImportDefaultSpecifier(local=local), jac_node=item
                        )
                    );
                } elif (item.name.value == '*') {
                    if not item.alias {
                        continue;
                    }
                    local = self.sync_loc(
                        es.Identifier(name=item.alias.sym_name), jac_node=item.alias
                    );
                    specifiers.append(
                        self.sync_loc(
                            es.ImportNamespaceSpecifier(local=local), jac_node=item
                        )
                    );
                }
            }
        }
    }
    import_decl = self.sync_loc(
        es.ImportDeclaration(specifiers=specifiers, source=source), jac_node=nd
    );
    self.imports.append(import_decl);
    nd.gen.es_ast = None;
}

impl EsastGenPass._generate_sv_import_stubs(nd: uni.Import) -> None {
    import from jaclang.compiler.symbol_utils { ability_of_symbol }

    source_mod: uni.Module | None = self._resolve_source_module(nd);
    stubs: list[es.Statement] = [];
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem)
        or not isinstance(item.name, uni.Name) {
            continue;
        }

        if self._sv_import_item_is_type(nd, item) {
            continue;
        }
        func_name = item.name.sym_name;
        local_name = item.alias.sym_name if item.alias else func_name;

        param_names: list[str] = [];
        param_type_map: dict[str, str] = {};
        ret_type_name: str = '';
        ability_node: uni.Ability | None = None;
        if source_mod {
            ability_node = ability_of_symbol(source_mod.lookup(func_name));
            if ability_node {
                param_names = self._param_names_from_ability(ability_node);
                param_type_map = self._param_type_map_from_ability(ability_node);
                ret_type_name = self._extract_return_type(
                    ability_node, func_name, nd.gen.interop_manifest
                );

                src_effect = source_mod.gen.interop_manifest.endpoint_effects.get(
                    f"func:{func_name}"
                );
                if src_effect is not None {
                    self.client_manifest.endpoint_effects[f"func:{func_name}"] = (
                        src_effect
                    );
                }
            }
        }
        boundary_types = nd.gen.interop_manifest.boundary_types
            if nd.gen.interop_manifest
            else {};

        js_params: list[es.Pattern] = [];
        for pname in param_names {
            js_params.append(self.sync_loc(es.Identifier(name=pname), jac_node=nd));
        }

        props: list[es.Property | es.SpreadElement] = [];
        for pname in param_names {
            key = self.sync_loc(es.Literal(value=pname), jac_node=nd);
            value: es.Expression = self._wrap_to_wire_if_boundary(
                self.sync_loc(es.Identifier(name=pname), jac_node=nd),
                param_type_map.get(pname, ''),
                boundary_types,
                nd
            );
            props.append(
                self.sync_loc(
                    es.Property(
                        key=key,
                        value=value,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    ),
                    jac_node=nd
                )
            );
        }
        args_obj = self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);

        call_expr = self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(
                    es.Identifier(name='__jacCallFunction'), jac_node=nd
                ),
                arguments=[
                    self.sync_loc(es.Literal(value=func_name), jac_node=nd),
                    args_obj
                ]
            ),
            jac_node=nd
        );
        await_expr: es.Expression = self.sync_loc(
            es.AwaitExpression(argument=call_expr), jac_node=nd
        );
        await_expr = self._wrap_return_with_boundary(
            await_expr, ret_type_name, boundary_types, nd, pre_awaited=True
        );
        return_stmt = self.sync_loc(
            es.ReturnStatement(argument=await_expr), jac_node=nd
        );
        body = self.sync_loc(es.BlockStatement(body=[return_stmt]), jac_node=nd);
        func_id = self.sync_loc(es.Identifier(name=local_name), jac_node=nd);
        func_decl = self.sync_loc(
            es.FunctionDeclaration(
                id=func_id, params=js_params, body=body, generator=False, async_=True
            ),
            jac_node=nd
        );
        stubs.append(func_decl);
    }
    if stubs {
        self._inject_runtime_import('__jacCallFunction', nd);

        self.sv_import_stubs.extend(stubs);
    }
}

impl EsastGenPass._sv_import_item_is_type(
    nd: uni.Import, item: uni.ModuleItem
) -> bool {
    type_kinds = {
        SymbolType.OBJECT_ARCH,
        SymbolType.NODE_ARCH,
        SymbolType.EDGE_ARCH,
        SymbolType.WALKER_ARCH,
        SymbolType.ENUM_ARCH
    };
    sym = item.name.sym;
    if sym and (sym.sym_type in type_kinds) {
        return True;
    }
    boundary_types = nd.gen.interop_manifest.boundary_types
        if nd.gen.interop_manifest
        else {};
    return item.name.sym_name in boundary_types;
}

impl EsastGenPass.exit_sub_tag(nd: uni.SubTag[uni.T]) -> None {
    if nd.tag.gen.es_ast {
        nd.gen.es_ast = nd.tag.gen.es_ast;
    }
}

impl EsastGenPass.populate_client_manifest(nd: uni.Module) -> None {
    for (ename, eeffect) in nd.gen.interop_manifest.endpoint_effects.items() {
        self.client_manifest.endpoint_effects[ename] = eeffect;
    }
}

impl EsastGenPass._emit_boundary_type_stubs(nd: uni.Module) -> list[es.Statement] {
    manifest = nd.gen.interop_manifest;
    if not manifest.boundary_types {
        return [];
    }
    stubs: list[es.Statement] = [];
    osp_archs = self._osp_arch_set();

    osp_class_map: dict[str, es.ClassDeclaration] = {};
    for item in self._merge_module_bodies(nd) {
        if (
            isinstance(item, uni.Archetype)
            and (item.name is not None)
            and isinstance(item.gen.es_ast, es.ClassDeclaration)
        ) {
            osp_class_map[item.name.sym_name] = item.gen.es_ast;
        }
    }
    for (type_name, info) in manifest.boundary_types.items() {
        is_osp = type_name in osp_archs;
        if info.kind == "enum" {
            enum_props: list[es.Property] = [];
            for (member_name, member_val) in info.enum_members {
                key = es.Identifier(name=member_name);
                val = es.Literal(
                    value=member_val if member_val is not None else member_name
                );
                enum_props.append(
                    es.Property(
                        key=key,
                        value=val,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    )
                );
            }
            obj_expr = es.CallExpression(
                callee=es.MemberExpression(
                    object=es.Identifier(name='Object'),
                    property=es.Identifier(name='freeze'),
                    computed=False
                ),
                arguments=[es.ObjectExpression(properties=enum_props)]
            );
            decl = es.VariableDeclaration(
                declarations=[
                    es.VariableDeclarator(
                        id=es.Identifier(name=type_name), init=obj_expr
                    )
                ],
                kind='const'
            );
            stubs.append(decl);
        } else {
            field_names = [f[0] for f in info.fields];
            field_types = {f[0]: f[1] for f in info.fields};
            ctor_stmts: list[es.Statement] = [];
            for fname in field_names {
                assign = es.ExpressionStatement(
                    expression=es.AssignmentExpression(
                        operator='=',
                        left=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name=fname),
                            computed=False
                        ),
                        right=es.ConditionalExpression(
                            test=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name='props'),
                                    property=es.Identifier(name='hasOwnProperty'),
                                    computed=False
                                ),
                                arguments=[es.Literal(value=fname)]
                            ),
                            consequent=es.MemberExpression(
                                object=es.Identifier(name='props'),
                                property=es.Identifier(name=fname),
                                computed=False
                            ),
                            alternate=es.Literal(value=None)
                        )
                    )
                );
                ctor_stmts.append(assign);
            }
            if info.kind == "node" {
                jac_id_assign = es.ExpressionStatement(
                    expression=es.AssignmentExpression(
                        operator='=',
                        left=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name='_jac_id'),
                            computed=False
                        ),
                        right=es.ConditionalExpression(
                            test=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name='props'),
                                    property=es.Identifier(name='hasOwnProperty'),
                                    computed=False
                                ),
                                arguments=[es.Literal(value='_jac_id')]
                            ),
                            consequent=es.MemberExpression(
                                object=es.Identifier(name='props'),
                                property=es.Identifier(name='_jac_id'),
                                computed=False
                            ),
                            alternate=es.Literal(value=None)
                        )
                    )
                );
                ctor_stmts.append(jac_id_assign);
            }
            ctor = es.FunctionExpression(
                id=None,
                params=[
                    es.AssignmentPattern(
                        left=es.Identifier(name='props'),
                        right=es.ObjectExpression(properties=[])
                    )
                ],
                body=es.BlockStatement(body=ctor_stmts),
                generator=False,
                async_=False
            );
            ctor_def = es.MethodDefinition(
                key=es.Identifier(name='constructor'),
                value=ctor,
                kind='constructor',
                static=False,
                computed=False
            );
            from_wire_stmts: list[es.Statement] = [];
            from_wire_stmts.append(
                es.IfStatement(
                    test=es.LogicalExpression(
                        operator='||',
                        left=es.BinaryExpression(
                            operator='===',
                            left=es.Identifier(name='d'),
                            right=es.Literal(value=None)
                        ),
                        right=es.BinaryExpression(
                            operator='===',
                            left=es.Identifier(name='d'),
                            right=es.Identifier(name='undefined')
                        )
                    ),
                    consequent=es.ReturnStatement(argument=es.Identifier(name='d')),
                    alternate=None
                )
            );
            nested_set = set(info.nested_types);
            for fname in field_names {
                ftype = field_types[fname];

                inner_type = None;
                is_list = False;
                is_dict = False;
                if ftype in nested_set {
                    inner_type = ftype;
                } elif ftype.startswith("list[") and ftype.endswith("]") {
                    inner = ftype[5:-1];
                    if inner in nested_set {
                        inner_type = inner;
                        is_list = True;
                    }
                } elif ftype.startswith("dict[") and ftype.endswith("]") {
                    dict_params = ftype[5:-1];
                    comma_pos = dict_params.find(', ');
                    if comma_pos >= 0 {
                        val_type = dict_params[comma_pos + 2:].strip();
                        if val_type in nested_set {
                            inner_type = val_type;
                            is_dict = True;
                        }
                    }
                }
                if inner_type {
                    if is_dict {
                        entries_call = es.CallExpression(
                            callee=es.MemberExpression(
                                object=es.Identifier(name='Object'),
                                property=es.Identifier(name='entries'),
                                computed=False
                            ),
                            arguments=[
                                es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                )
                            ]
                        );
                        map_call = es.CallExpression(
                            callee=es.MemberExpression(
                                object=entries_call,
                                property=es.Identifier(name='map'),
                                computed=False
                            ),
                            arguments=[
                                es.ArrowFunctionExpression(
                                    params=[
                                        es.ArrayPattern(
                                            elements=[
                                                es.Identifier(name='k'),
                                                es.Identifier(name='v')
                                            ]
                                        )
                                    ],
                                    body=es.ArrayExpression(
                                        elements=[
                                            es.Identifier(name='k'),
                                            es.CallExpression(
                                                callee=es.MemberExpression(
                                                    object=es.Identifier(
                                                        name=inner_type
                                                    ),
                                                    property=es.Identifier(
                                                        name='__from_wire'
                                                    ),
                                                    computed=False
                                                ),
                                                arguments=[es.Identifier(name='v')]
                                            )
                                        ]
                                    ),
                                    expression=True,
                                    async_=False
                                )
                            ]
                        );
                        from_entries_call = es.CallExpression(
                            callee=es.MemberExpression(
                                object=es.Identifier(name='Object'),
                                property=es.Identifier(name='fromEntries'),
                                computed=False
                            ),
                            arguments=[map_call]
                        );
                        from_wire_stmts.append(
                            es.IfStatement(
                                test=es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.ExpressionStatement(
                                    expression=es.AssignmentExpression(
                                        operator='=',
                                        left=es.MemberExpression(
                                            object=es.Identifier(name='d'),
                                            property=es.Identifier(name=fname),
                                            computed=False
                                        ),
                                        right=from_entries_call
                                    )
                                ),
                                alternate=None
                            )
                        );
                    } elif is_list {
                        from_wire_stmts.append(
                            es.IfStatement(
                                test=es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.ExpressionStatement(
                                    expression=es.AssignmentExpression(
                                        operator='=',
                                        left=es.MemberExpression(
                                            object=es.Identifier(name='d'),
                                            property=es.Identifier(name=fname),
                                            computed=False
                                        ),
                                        right=es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.MemberExpression(
                                                    object=es.Identifier(name='d'),
                                                    property=es.Identifier(name=fname),
                                                    computed=False
                                                ),
                                                property=es.Identifier(name='map'),
                                                computed=False
                                            ),
                                            arguments=[
                                                es.ArrowFunctionExpression(
                                                    params=[es.Identifier(name='x')],
                                                    body=es.CallExpression(
                                                        callee=es.MemberExpression(
                                                            object=es.Identifier(
                                                                name=inner_type
                                                            ),
                                                            property=es.Identifier(
                                                                name='__from_wire'
                                                            ),
                                                            computed=False
                                                        ),
                                                        arguments=[
                                                            es.Identifier(name='x')
                                                        ]
                                                    ),
                                                    expression=True,
                                                    async_=False
                                                )
                                            ]
                                        )
                                    )
                                ),
                                alternate=None
                            )
                        );
                    } else {
                        from_wire_stmts.append(
                            es.IfStatement(
                                test=es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.ExpressionStatement(
                                    expression=es.AssignmentExpression(
                                        operator='=',
                                        left=es.MemberExpression(
                                            object=es.Identifier(name='d'),
                                            property=es.Identifier(name=fname),
                                            computed=False
                                        ),
                                        right=es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.Identifier(name=inner_type),
                                                property=es.Identifier(
                                                    name='__from_wire'
                                                ),
                                                computed=False
                                            ),
                                            arguments=[
                                                es.MemberExpression(
                                                    object=es.Identifier(name='d'),
                                                    property=es.Identifier(name=fname),
                                                    computed=False
                                                )
                                            ]
                                        )
                                    )
                                ),
                                alternate=None
                            )
                        );
                    }
                }
            }
            from_wire_stmts.append(
                es.ReturnStatement(
                    argument=es.NewExpression(
                        callee=es.Identifier(name=type_name),
                        arguments=[es.Identifier(name='d')]
                    )
                )
            );
            from_wire_fn = es.FunctionExpression(
                id=None,
                params=[es.Identifier(name='d')],
                body=es.BlockStatement(body=from_wire_stmts),
                generator=False,
                async_=False
            );
            from_wire_def = es.MethodDefinition(
                key=es.Identifier(name='__from_wire'),
                value=from_wire_fn,
                kind='method',
                static=True,
                computed=False
            );
            to_wire_props: list[es.Property] = [];
            to_wire_props.append(
                es.Property(
                    key=es.Literal(value='__type__'),
                    value=es.Literal(value=type_name),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                )
            );
            for fname in field_names {
                ftype = field_types[fname];
                value_expr: es.Expression = es.MemberExpression(
                    object=es.ThisExpression(),
                    property=es.Identifier(name=fname),
                    computed=False
                );

                if ftype in nested_set {
                    value_expr = es.ConditionalExpression(
                        test=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name=fname),
                            computed=False
                        ),
                        consequent=es.CallExpression(
                            callee=es.MemberExpression(
                                object=value_expr,
                                property=es.Identifier(name='__to_wire'),
                                computed=False
                            ),
                            arguments=[]
                        ),
                        alternate=es.Literal(value=None)
                    );
                } elif ftype.startswith("list[") and ftype.endswith("]") {
                    inner = ftype[5:-1];
                    if inner in nested_set {
                        value_expr = es.ConditionalExpression(
                            test=es.MemberExpression(
                                object=es.ThisExpression(),
                                property=es.Identifier(name=fname),
                                computed=False
                            ),
                            consequent=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.MemberExpression(
                                        object=es.ThisExpression(),
                                        property=es.Identifier(name=fname),
                                        computed=False
                                    ),
                                    property=es.Identifier(name='map'),
                                    computed=False
                                ),
                                arguments=[
                                    es.ArrowFunctionExpression(
                                        params=[es.Identifier(name='x')],
                                        body=es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.Identifier(name='x'),
                                                property=es.Identifier(
                                                    name='__to_wire'
                                                ),
                                                computed=False
                                            ),
                                            arguments=[]
                                        ),
                                        expression=True,
                                        async_=False
                                    )
                                ]
                            ),
                            alternate=es.ArrayExpression(elements=[])
                        );
                    }
                } elif ftype.startswith("dict[") and ftype.endswith("]") {
                    dict_params = ftype[5:-1];
                    comma_pos = dict_params.find(', ');
                    if comma_pos >= 0 {
                        val_type = dict_params[comma_pos + 2:].strip();
                        if val_type in nested_set {
                            this_field = es.MemberExpression(
                                object=es.ThisExpression(),
                                property=es.Identifier(name=fname),
                                computed=False
                            );
                            entries_call = es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name='Object'),
                                    property=es.Identifier(name='entries'),
                                    computed=False
                                ),
                                arguments=[this_field]
                            );
                            map_call = es.CallExpression(
                                callee=es.MemberExpression(
                                    object=entries_call,
                                    property=es.Identifier(name='map'),
                                    computed=False
                                ),
                                arguments=[
                                    es.ArrowFunctionExpression(
                                        params=[
                                            es.ArrayPattern(
                                                elements=[
                                                    es.Identifier(name='k'),
                                                    es.Identifier(name='v')
                                                ]
                                            )
                                        ],
                                        body=es.ArrayExpression(
                                            elements=[
                                                es.Identifier(name='k'),
                                                es.CallExpression(
                                                    callee=es.MemberExpression(
                                                        object=es.Identifier(name='v'),
                                                        property=es.Identifier(
                                                            name='__to_wire'
                                                        ),
                                                        computed=False
                                                    ),
                                                    arguments=[]
                                                )
                                            ]
                                        ),
                                        expression=True,
                                        async_=False
                                    )
                                ]
                            );
                            value_expr = es.ConditionalExpression(
                                test=es.MemberExpression(
                                    object=es.ThisExpression(),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.CallExpression(
                                    callee=es.MemberExpression(
                                        object=es.Identifier(name='Object'),
                                        property=es.Identifier(name='fromEntries'),
                                        computed=False
                                    ),
                                    arguments=[map_call]
                                ),
                                alternate=es.ObjectExpression(properties=[])
                            );
                        }
                    }
                }
                to_wire_props.append(
                    es.Property(
                        key=es.Literal(value=fname),
                        value=value_expr,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    )
                );
            }
            if info.kind == "node" {
                to_wire_props.append(
                    es.Property(
                        key=es.Literal(value='_jac_id'),
                        value=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name='_jac_id'),
                            computed=False
                        ),
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    )
                );
            }
            to_wire_fn = es.FunctionExpression(
                id=None,
                params=[],
                body=es.BlockStatement(
                    body=[
                        es.ReturnStatement(
                            argument=es.ObjectExpression(properties=to_wire_props)
                        )
                    ]
                ),
                generator=False,
                async_=False
            );
            to_wire_def = es.MethodDefinition(
                key=es.Identifier(name='__to_wire'),
                value=to_wire_fn,
                kind='method',
                static=False,
                computed=False
            );
            if is_osp {
                osp_class = osp_class_map.get(type_name);
                if osp_class is not None {
                    if info.kind == "node" {
                        for member in osp_class.body.body {
                            if (
                                isinstance(member, es.MethodDefinition)
                                and (member.kind == "constructor")
                            ) {
                                member.value.body.body.append(
                                    es.IfStatement(
                                        test=es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.Identifier(name='props'),
                                                property=es.Identifier(
                                                    name='hasOwnProperty'
                                                ),
                                                computed=False
                                            ),
                                            arguments=[es.Literal(value='_jac_id')]
                                        ),
                                        consequent=es.ExpressionStatement(
                                            expression=es.AssignmentExpression(
                                                operator='=',
                                                left=es.MemberExpression(
                                                    object=es.ThisExpression(),
                                                    property=es.Identifier(
                                                        name='_jac_id'
                                                    ),
                                                    computed=False
                                                ),
                                                right=es.MemberExpression(
                                                    object=es.Identifier(name='props'),
                                                    property=es.Identifier(
                                                        name='_jac_id'
                                                    ),
                                                    computed=False
                                                )
                                            )
                                        ),
                                        alternate=None
                                    )
                                );
                            }
                        }
                    }
                    osp_class.body.body.append(from_wire_def);
                    osp_class.body.body.append(to_wire_def);
                }
            } else {
                class_body = es.ClassBody(body=[ctor_def, from_wire_def, to_wire_def]);
                class_decl = es.ClassDeclaration(
                    id=es.Identifier(name=type_name), superClass=None, body=class_body
                );
                stubs.append(class_decl);
            }
        }
    }
    return stubs;
}

impl EsastGenPass.exit_module(nd: uni.Module) -> None {
    if (self.scoped_styles is not None and self.scoped_styles.class_map) {
        import os;
        nd.gen.css = self.scoped_styles.scoped_css;
        base = os.path.basename(self.scoped_styles.css_path);
        if base.endswith('.style.css') {
            base = base[:-len('.style.css')];
        }
        css_import = f"./{base}.css";
        css_source = self.sync_loc(
            es.Literal(value=css_import, raw=f'"{css_import}"'), jac_node=nd
        );
        self.imports.insert(
            0,
            self.sync_loc(
                es.ImportDeclaration(specifiers=[], source=css_source), jac_node=nd
            )
        );
    }
    body: list[(es.Statement | es.ModuleDeclaration)] = [];
    body.extend(self.imports);

    body.extend(self.sv_import_stubs);

    body.extend(self._emit_boundary_type_stubs(nd));
    scope = self.scope_map.get(nd);
    if (scope and scope.hoisted) {
        hoisted = list(scope.hoisted);
        scope.hoisted.clear();
        body.extend(hoisted);
    }

    if self.needs_jac_runtime {
        import from jaclang.compiler.passes.ecmascript.jac_runtime_js {
            build_jac_runtime_js
        }
        jac_rt_decl = es.VariableDeclaration(
            declarations=[
                es.VariableDeclarator(
                    id=es.Identifier(name='_jac'),
                    init=es.Identifier(name=build_jac_runtime_js())
                )
            ],
            kind='const'
        );
        body.append(jac_rt_decl);
    }
    merged_body = self._merge_module_bodies(nd);
    client_items: list[es.Statement | list[es.Statement] | None] = [];
    fallback_items: list[es.Statement | list[es.Statement] | None] = [];
    for stmt in merged_body {
        if stmt.gen.es_ast {
            is_shared_arch = (
                isinstance(stmt, uni.Archetype)
                and (stmt.name is not None)
                and (stmt.name.value in self.shared_arch_names)
            );
            if (getattr(stmt, 'code_context', CodeContext.CLIENT) == CodeContext.CLIENT)
            or is_shared_arch {
                client_items.append(cast(es.Statement, stmt.gen.es_ast));
            } else {
                ;
            }
        }
    }
    target_body = client_items or fallback_items;
    body.extend(self._flatten_ast_list(target_body));

    if self.needs_osp_graph {
        import from jaclang.compiler.passes.ecmascript.jac_runtime_js {
            build_osp_graph_js
        }
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=build_osp_graph_js())
                ),
                jac_node=nd
            )
        );
    }
    if self.needs_osp_kernel {
        import from jaclang.compiler.passes.ecmascript.jac_runtime_js {
            build_osp_kernel_js
        }
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=build_osp_kernel_js())
                ),
                jac_node=nd
            )
        );
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=self._build_osp_setup_js())
                ),
                jac_node=nd
            )
        );
    }
    body.extend(self.exports);
    self.populate_client_manifest(nd);
    self.client_manifest.exports.sort();
    self.client_manifest.globals.sort();
    module_export_names = sorted(
        set(self.client_manifest.exports + self.client_manifest.globals)
    );
    if module_export_names {
        export_specifiers: list[es.ExportSpecifier] = [];
        for name in module_export_names {
            export_specifiers.append(
                es.ExportSpecifier(
                    exported=es.Identifier(name=name), local=es.Identifier(name=name)
                )
            );
        }

        if (
            not self.client_manifest.globals
            and all(name in self.component_export_names for name in module_export_names)
        ) {
            body.append(
                self.sync_loc(
                    es.ExpressionStatement(
                        expression=es.Identifier(name='/*jac:refresh-boundary*/')
                    ),
                    jac_node=nd
                )
            );
        }
        comprehensive_export = es.ExportNamedDeclaration(
            declaration=None, specifiers=export_specifiers, source=None
        );
        body.append(comprehensive_export);
    }

    if self.client_manifest.endpoint_effects {
        import json as _json;
        effects_json = _json.dumps(self.client_manifest.endpoint_effects);
        register_code = (
            'if (typeof globalThis !== "undefined") {'
            ' if (!globalThis.__jacEndpointEffects__) globalThis.__jacEndpointEffects__ = {};'
            f' Object.assign(globalThis.__jacEndpointEffects__, {effects_json});'
            ' }'
        );
        body.append(
            es.ExpressionStatement(expression=es.Identifier(name=register_code))
        );
    }
    program = self.sync_loc(es.Program(body=body), jac_node=nd);
    nd.gen.es_ast = program;
    nd.gen.js = es_to_js(nd.gen.es_ast);
    nd.gen.client_manifest = self.client_manifest;
}

impl EsastGenPass._build_block_statement(
    scope_node: uni.UniScopeNode, body_nodes: (Sequence[uni.UniNode] | None)
) -> es.BlockStatement {
    statements = self._collect_stmt_body(body_nodes);
    statements = self._prepend_hoisted(scope_node, statements);
    return self.sync_loc(es.BlockStatement(body=statements), jac_node=scope_node);
}

impl EsastGenPass._get_ast_or_default(
    nd: (uni.UniNode | None), default_factory: Callable[([(uni.UniNode | None)], _T)]
) -> _T {
    if (nd and nd.gen.es_ast) {
        generated = nd.gen.es_ast;
        if isinstance(generated, es.Node) {
            return cast(_T, generated);
        }
    }
    fallback = default_factory(nd);
    jac_ref = nd if (nd is not None) else self.cur_node;
    return self.sync_loc(fallback, jac_node=jac_ref);
}

impl EsastGenPass._collect_stmt_body(
    body: (Sequence[uni.UniNode] | None)
) -> list[es.Statement] {
    if not body {
        return [];
    }
    statements: list[es.Statement] = [];
    for stmt in body {
        if isinstance(stmt, uni.Semi) {
            continue;
        }
        generated = stmt.gen.es_ast;
        if isinstance(generated, list) {
            statements.extend(
                item
                for item in generated
                if isinstance(item, es.Statement)
            );
        } elif isinstance(generated, es.Statement) {
            statements.append(generated);
        }
    }
    return statements;
}

impl EsastGenPass._build_spawn_runtime_call(
    nd: uni.BinaryExpr, parts: SpawnCallParts
) -> es.AwaitExpression {
    walker_literal = self.sync_loc(
        es.Literal(value=parts.walker.walker_name), jac_node=parts.walker.call_node
    );
    spawn_call = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__jacSpawn'), jac_node=nd),
            arguments=[
                walker_literal,
                parts.target.expression,
                parts.walker.fields_object
            ]
        ),
        jac_node=nd
    );
    return self.sync_loc(es.AwaitExpression(argument=spawn_call), jac_node=nd);
}

impl EsastGenPass._prepare_spawn_call(
    nd: uni.BinaryExpr, left_expr: es.Expression, right_expr: es.Expression
) -> (SpawnCallParts | None) {
    left_walker = self._resolve_spawn_walker(nd.left, left_expr);
    right_walker = self._resolve_spawn_walker(nd.right, right_expr);
    if (left_walker and right_walker) {
        self.emit(W5013, node_override=nd);
        target = self._resolve_spawn_target(nd.left, left_expr);
        return SpawnCallParts(`walker=right_walker, target=target);
    }
    if left_walker {
        target = self._resolve_spawn_target(nd.right, right_expr);
        return SpawnCallParts(`walker=left_walker, target=target);
    }
    if right_walker {
        target = self._resolve_spawn_target(nd.left, left_expr);
        return SpawnCallParts(`walker=right_walker, target=target);
    }
    self.emit(E5010, node_override=nd);
    return None;
}

impl EsastGenPass._resolve_spawn_target(
    expr: uni.Expr, es_expr: es.Expression
) -> SpawnTargetInfo {
    (stripped_node, stripped_es) = self._strip_spawn_await(expr, es_expr);
    if self._is_root_reference(stripped_node) {
        literal = self.sync_loc(es.Literal(value=''), jac_node=stripped_node);
        return SpawnTargetInfo(nd=stripped_node, expression=literal);
    }
    return SpawnTargetInfo(nd=stripped_node, expression=stripped_es);
}

impl EsastGenPass._is_root_reference(expr: uni.Expr) -> bool {
    if (isinstance(expr, uni.Name) and (expr.sym_name == 'root')) {
        return True;
    }
    return bool((isinstance(expr, uni.SpecialVarRef) and (expr.sym_name == 'root')));
}

impl EsastGenPass._resolve_spawn_walker(
    expr: uni.Expr, es_expr: es.Expression
) -> (SpawnWalkerInfo | None) {
    (stripped_node, _) = self._strip_spawn_await(expr, es_expr);
    if not isinstance(stripped_node, uni.FuncCall) {
        return None;
    }

    target_symbol = stripped_node.target.sym
        if isinstance(stripped_node.target, uni.AtomExpr)
        else None;

    if target_symbol and (target_symbol.sym_type == SymbolType.WALKER_ARCH) {
        walker_name = target_symbol.sym_name;
        fields_obj = self._build_spawn_arg_object(stripped_node, target_symbol);
        return SpawnWalkerInfo(
            call_node=stripped_node, walker_name=walker_name, fields_object=fields_obj
        );
    }

    if isinstance(stripped_node.target, uni.Name) {
        walker_name = stripped_node.target.sym_name;
        fields_obj = self._build_spawn_arg_object(stripped_node, None);
        return SpawnWalkerInfo(
            call_node=stripped_node, walker_name=walker_name, fields_object=fields_obj
        );
    }
    return None;
}

impl EsastGenPass._build_spawn_arg_object(
    call_node: uni.FuncCall, walker_symbol: (uni.Symbol | None)
) -> es.ObjectExpression {
    import from jaclang.compiler.symbol_utils {
        collect_field_names,
        symbol_owner_archetype
    }
    ordered_fields = collect_field_names(walker_symbol, Tok.KW_WALKER.value);

    field_type_map: dict[str, str] = {};
    if walker_symbol {
        arch = symbol_owner_archetype(walker_symbol);
        if arch {
            for field in arch.get_has_vars() {
                if field.type_tag and field.type_tag.tag {
                    if isinstance(field.type_tag.tag, uni.Name) {
                        field_type_map[field.sym_name] = field.type_tag.tag.value;
                    }
                }
            }
        }
    }
    boundary_types = self.ir_in.gen.interop_manifest.boundary_types
        if self.ir_in.gen.interop_manifest
        else {};
    properties: list[(es.Property | es.SpreadElement)] = [];
    positional_index = 0;
    for param in call_node.params {
        if isinstance(param, uni.KWPair) {
            if param.key {
                field_name = param.key.sym_name;
                key_expr = self.sync_loc(
                    es.Literal(value=field_name), jac_node=param.key
                );
                value_expr = self._expr_from_node(param.value);

                ftype = field_type_map.get(field_name, '');
                if ftype in boundary_types and boundary_types[ftype].kind != "enum" {
                    value_expr = self.sync_loc(
                        es.CallExpression(
                            callee=es.MemberExpression(
                                object=value_expr,
                                property=es.Identifier(name='__to_wire'),
                                computed=False
                            ),
                            arguments=[]
                        ),
                        jac_node=param
                    );
                }
                properties.append(
                    self.sync_loc(
                        es.Property(
                            key=key_expr,
                            value=value_expr,
                            kind='init',
                            method=False,
                            shorthand=False,
                            computed=False
                        ),
                        jac_node=param
                    )
                );
            } else {
                spread_arg = self._expr_from_node(param.value);
                properties.append(
                    self.sync_loc(es.SpreadElement(argument=spread_arg), jac_node=param)
                );
            }
            continue;
        }
        key_name = ordered_fields[positional_index]
            if (positional_index < len(ordered_fields))
            else f"arg{positional_index}";
        if (positional_index >= len(ordered_fields)) {
            self.emit(W5014, node_override=param);
        }
        positional_index += 1;
        key_expr = self.sync_loc(es.Literal(value=key_name), jac_node=param);
        value_expr = self._expr_from_node(param);

        ftype = field_type_map.get(key_name, '');
        if ftype in boundary_types and boundary_types[ftype].kind != "enum" {
            value_expr = self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=value_expr,
                        property=es.Identifier(name='__to_wire'),
                        computed=False
                    ),
                    arguments=[]
                ),
                jac_node=param
            );
        }
        properties.append(
            self.sync_loc(
                es.Property(
                    key=key_expr,
                    value=value_expr,
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=param
            )
        );
    }
    return self.sync_loc(
        es.ObjectExpression(properties=properties), jac_node=call_node
    );
}

impl EsastGenPass._expr_from_node(
    nd: (uni.UniNode | None), `default: LiteralValue = None
) -> es.Expression {
    generated = self._get_ast_or_default(
        nd, default_factory=lambda (src: any) { es.Literal(value=`default); }
    );
    if isinstance(generated, es.Expression) {
        return generated;
    }
    self.emit(E5011, node_override=nd);
    return self.sync_loc(es.Literal(value=`default), jac_node=(nd or self.cur_node));
}

impl EsastGenPass.get_main_mod -> uni.Module {
    main_mod_path = self.ir_in.annexable_by or self.ir_in.loc.mod_path;
    mod = self.prog.mod.hub.get(main_mod_path);
    if not isinstance(mod, uni.Module) {
        self.emit(E5012);
    }
    return mod;
}

impl EsastGenPass._strip_spawn_await(
    node_expr: uni.Expr, es_expr: es.Expression
) -> tuple[uni.Expr, es.Expression] {
    cur_node = node_expr;
    cur_es = es_expr;
    while (isinstance(cur_node, uni.AwaitExpr) and cur_node.target) {
        cur_node = cur_node.target;
        if (isinstance(cur_es, es.AwaitExpression) and (cur_es.argument is not None)) {
            cur_es = cur_es.argument;
        } else {
            break;
        }
    }
    return (cur_node, cur_es);
}

impl EsastGenPass._prepend_hoisted(
    nd: uni.UniScopeNode, statements: list[es.Statement]
) -> list[es.Statement] {
    scope = self.scope_map.get(nd);
    if (scope and scope.hoisted) {
        hoisted = list(scope.hoisted);
        scope.hoisted.clear();
        return (hoisted + statements);
    }
    return statements;
}

impl EsastGenPass._ensure_identifier_declared(
    name: str, jac_node: uni.UniNode
) -> None {
    scope = self._current_scope();
    if (not scope or (name in scope.declared)) {
        return;
    }
    ident = self.sync_loc(es.Identifier(name=name), jac_node=jac_node);
    declarator = self.sync_loc(
        es.VariableDeclarator(id=ident, `init=None), jac_node=jac_node
    );
    decl = self.sync_loc(
        es.VariableDeclaration(declarations=[declarator], kind='let'), jac_node=jac_node
    );
    scope.hoisted.append(decl);
    scope.declared.add(name);
}

impl EsastGenPass._register_declaration(name: str) -> None {
    scope = self._current_scope();
    if scope {
        scope.declared.add(name);
    }
}

impl EsastGenPass._is_declared_in_any_scope(name: str) -> bool {
    return any((name in scope.declared) for scope in reversed(self.scope_stack));
}

impl EsastGenPass._current_scope -> (ScopeInfo | None) {
    return self.scope_stack[-1] if self.scope_stack else None;
}

impl EsastGenPass._pop_scope(nd: uni.UniScopeNode) -> None {
    if (self.scope_stack and (self.scope_stack[-1].nd is nd)) {
        self.scope_stack.pop();
    }
}

impl EsastGenPass._push_scope(nd: uni.UniScopeNode) -> None {
    info = ScopeInfo(nd=nd);
    self.scope_stack.append(info);
    self.scope_map[nd] = info;
}

impl EsastGenPass._alt_branch_scope_to_finalize(
    nd: uni.UniNode
) -> (uni.UniScopeNode | None) {
    parent = nd.parent;
    if parent is None {
        return None;
    }

    if (
        (isinstance(nd, uni.ElseStmt) or isinstance(nd, uni.ElseIf))
        and isinstance(parent, uni.IfStmt)
        and (parent.else_body is nd)
    ) {
        return parent;
    }

    if isinstance(parent, uni.TryStmt) {
        if isinstance(nd, uni.Except) and (nd in parent.excepts) {
            return parent;
        }
        if isinstance(nd, uni.FinallyStmt) and (parent.finally_body is nd) {
            return parent;
        }
        if isinstance(nd, uni.ElseStmt) and (parent.else_body is nd) {
            return parent;
        }
    }

    if (
        isinstance(nd, uni.ElseStmt)
        and isinstance(parent, (uni.WhileStmt, uni.IterForStmt, uni.InForStmt))
        and (parent.else_body is nd)
    ) {
        return parent;
    }
    return None;
}

impl EsastGenPass.sync_loc(es_node: _T, jac_node: (uni.UniNode | None) = None) -> _T {
    if not jac_node {
        jac_node = self.cur_node;
    }
    es_node.loc = es.SourceLocation(
        start=es.Position(line=jac_node.loc.first_line, column=jac_node.loc.col_start),
        end=es.Position(line=jac_node.loc.last_line, column=jac_node.loc.col_end)
    );
    return es_node;
}

impl EsastGenPass.exit_node(nd: uni.UniNode) -> None {
    if (
        isinstance(nd, uni.ElementStmt)
        and isinstance(nd, uni.ContextAwareNode)
        and nd.code_context != CodeContext.CLIENT
        and ((nd.parent is None) or isinstance(nd.parent, uni.Module))
    ) {
        is_sv_import = isinstance(nd, uni.Import) and nd.is_sv_marked;

        is_shared_arch = (
            isinstance(nd, uni.Archetype)
            and (nd.name is not None)
            and (nd.name.value in self.shared_arch_names)
        );
        if (
            not is_sv_import
            and not isinstance(nd, uni.ServerBlock)
            and not is_shared_arch
        ) {
            return;
        }
    }
    super.exit_node(nd);
    if isinstance(nd, uni.UniScopeNode) {
        self._pop_scope(nd);

        self.scope_map.pop(nd, None);
    }
}

impl EsastGenPass.enter_node(nd: uni.UniNode) -> None {
    if isinstance(nd, uni.NativeBlock) {
        self.prune();
        return;
    }
    if (
        isinstance(nd, uni.ElementStmt)
        and isinstance(nd, uni.ContextAwareNode)
        and nd.code_context != CodeContext.CLIENT
        and ((nd.parent is None) or isinstance(nd.parent, uni.Module))
    ) {
        is_sv_import = isinstance(nd, uni.Import) and nd.is_sv_marked;

        is_shared_arch = (
            isinstance(nd, uni.Archetype)
            and (nd.name is not None)
            and (nd.name.value in self.shared_arch_names)
        );
        if (
            not is_sv_import
            and not isinstance(nd, uni.ServerBlock)
            and not is_shared_arch
        ) {
            self.prune();
            return;
        }
    }
    if isinstance(nd, uni.UniScopeNode) {
        scope_to_finalize = self._alt_branch_scope_to_finalize(nd);
        if scope_to_finalize is not None {
            self._pop_scope(scope_to_finalize);
        }
        self._push_scope(nd);
    }
    if nd.gen.es_ast {
        if not (isinstance(nd, uni.Import) and nd.code_context != CodeContext.CLIENT) {
            self.prune();
            return;
        }
    }
    super.enter_node(nd);
}

impl EsastGenPass.before_pass -> None {
    import from jaclang.jac0core.codeinfo { ClientManifest }
    self.child_passes = self._init_child_passes(EsastGenPass);
    self.client_manifest = ClientManifest();
    self.component_export_names = set();

    self.client_manifest.endpoint_effects = dict(
        self.ir_in.gen.interop_manifest.endpoint_effects
    );

    import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
    self.shared_arch_names: set[str] = {
        a.name.value
        for a in ModuleCodegenPass.shared_archetypes_for_context(
            self.ir_in, CodeContext.CLIENT
        )
        if a.name is not None
    };
    self.jsx_processor = EsJsxProcessor(self);

    self.scoped_styles = load_style_annex(
        self.ir_in.annexable_by or self.ir_in.loc.mod_path
    );
}
