import from jaclang.compiler.tools.unparse_pass { unparse_node }
import from jaclang.compiler.backends.es.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

impl EsastGenPass._ensure_backend -> None {
    if self.backend is None {
        import from jaclang.compiler.backends.es.backends.registry {
            resolve_active_backend
        }
        try {
            self.backend = resolve_active_backend();
        } except ValueError {
            import from jaclang.project.config { get_config }
            import from jaclang.compiler.frontend.diagnostics { E5081 }
            import from jaclang.compiler.backends.es.backends.react { ReactBackend }
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
        items: dict[(str, any)] = {};
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

impl EsastGenPass.exit_semi with uni.Semi exit {}

impl EsastGenPass.exit_token with uni.Token exit {
    if here.__class__ is not uni.Token {
        return;
    }
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

impl EsastGenPass.exit_test with uni.Test exit {
    params: list[es.Pattern] = [];
    body_stmts = self._collect_body_stmts(here.body);
    body_stmts = self._prepend_hoisted(here, body_stmts);
    block = self.sync_loc(es.BlockStatement(body=body_stmts), jac_node=here);
    func_id = self.sync_loc(es.Identifier(name=here.name.sym_name), jac_node=here.name);

    func_decl = self.sync_loc(
        es.FunctionDeclaration(id=func_id, params=params, body=block, async_=True),
        jac_node=here
    );
    here.gen.es_ast = func_decl;

    self.client_manifest.has_client = True;
    self.client_manifest.tests.append(
        {
            'name': here.name.sym_name,
            'description': here.description.lit_value
                if here.description
                else here.name.sym_name
        }
    );
}

impl EsastGenPass.exit_module_code with uni.ModuleCode exit {
    here.gen.es_ast = self._collect_body_stmts(here.body);
}

impl EsastGenPass.exit_global_vars with uni.GlobalVars exit {
    if here.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = here.access and (here.access.tag.name == Tok.KW_PUB);
        if is_pub or here.codespace_dual {
            for assignment in here.assignments {
                for target in assignment.target {
                    if (sym_name := target?.sym_name) {
                        self.client_manifest.globals.append(sym_name);
                        if (
                            assignment.value
                            and (
                                (lit_val := self._literal_value(assignment.value))
                                is not None
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
    for assignment in here.assignments {
        if assignment.gen.es_ast {
            stmt = assignment.gen.es_ast;
            if (
                isinstance(stmt, es.VariableDeclaration)
                and here.is_frozen
                and (stmt.kind != 'const')
            ) {
                stmt.kind = 'const';
            }
            statements.append(cast(es.Statement, stmt));
        }
    }
    here.gen.es_ast = statements;
}

impl EsastGenPass.exit_name with uni.Name exit {
    if here.__class__ is not uni.Name {
        return;
    }
    self._exit_name_impl(here);
}

impl EsastGenPass._exit_name_impl(nd: uni.Name) -> None {
    if self._is_ct_type_param(nd) and not self._in_identifier_slot(nd) {
        nd.gen.es_ast = self.sync_loc(
            es.MemberExpression(
                object=self.sync_loc(es.ThisExpression(), jac_node=nd),
                property=es.Identifier(name=nd.sym_name),
                computed=False
            ),
            jac_node=nd
        );
        return;
    }
    if self._ct_only_name(nd) {
        folded = self._ct_es_expr(nd.ct_value, nd);
        if folded is not None {
            nd.gen.es_ast = folded;
            return;
        }
    }
    if (nd.sym_name in self.reactive_vars) and not self._in_identifier_slot(nd) {
        self._ensure_backend();
        nd.gen.es_ast = self.sync_loc(
            self.backend.lower_state_read(nd.sym_name), jac_node=nd
        );
        return;
    }
    import from jaclang.runtime.scalars { is_sized }
    import from jaclang.compiler.types.types { ClassType as _ClassType }
    if (
        is_sized(nd.sym_name)
        and isinstance(nd.type, _ClassType)
        and not nd.type.is_instance()
        and not self._in_identifier_slot(nd)
        and not self._in_type_slot(nd)
    ) {
        nd.gen.es_ast = self._build_jac_ref(["_jac", "types", nd.sym_name], nd);
        if not self._is_call_target(nd) {
            self.needs_jac_runtime = True;
        }
        return;
    }
    name_map = {'None': 'null', 'True': 'true', 'False': 'false', 'self': 'this'};
    name = name_map.get(nd.sym_name, nd.sym_name);
    identifier = self.sync_loc(es.Identifier(name=name), jac_node=nd);
    nd.gen.es_ast = identifier;
}

impl EsastGenPass._in_identifier_slot(nd: uni.UniNode) -> bool {
    parent = nd.parent;
    if parent is None {
        return False;
    }
    if isinstance(parent, uni.KWPair) {
        return parent.key is nd;
    }
    if isinstance(parent, uni.AtomTrailer) {
        return parent.is_attr and (parent.right is nd);
    }
    if isinstance(parent, (uni.ParamVar, uni.HasVar, uni.Archetype, uni.Enum)) {
        return parent.name is nd;
    }
    if isinstance(parent, uni.Ability) {
        return parent.name_ref is nd;
    }
    if isinstance(parent, uni.ModuleItem) {
        return (parent.name is nd) or (parent.alias is nd);
    }
    if isinstance(parent, uni.ModulePath) {
        return (parent.alias is nd) or any(part is nd for part in (parent.path or []));
    }
    if isinstance(parent, uni.JsxNormalAttribute) {
        return (parent.name is nd) and (parent.value is not nd);
    }
    if isinstance(parent, uni.JsxElementName) {
        return any(part is nd for part in (parent.parts or []));
    }
    if isinstance(parent, uni.CompareExpr) {
        return (parent.left is nd) and isinstance(parent.parent, uni.FilterCompr);
    }
    return False;
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

impl EsastGenPass.exit_builtin_type with uni.BuiltinType exit {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    type_name = here.sym_name;
    self._ensure_emitters();
    if (
        not self._in_type_slot(here)
        and (
            getattr(self._builtin_emitter, "emit_" + type_name, None) is not None
            or JAC_TYPE_REGISTRY.is_sized(type_name)
        )
    ) {
        here.gen.es_ast = self.sync_loc(
            es.MemberExpression(
                object=es.MemberExpression(
                    object=es.Identifier(name='_jac'),
                    property=es.Identifier(name='types'),
                    computed=False
                ),
                property=es.Identifier(name=type_name),
                computed=False
            ),
            jac_node=here
        );
        if not self._is_call_target(here) {
            self.needs_jac_runtime = True;
        }
        return;
    }
    tag = self.sync_loc(
        es.Literal(value=type_name, raw=json.dumps(type_name)), jac_node=here
    );
    here.gen.es_ast = tag;
}

impl EsastGenPass.exit_null with uni.Null exit {
    null_lit = self.sync_loc(es.Literal(value=None, raw='null'), jac_node=here);
    here.gen.es_ast = null_lit;
}

impl EsastGenPass.exit_await_expr with uni.AwaitExpr exit {
    argument = cast(
        es.Expression,
        here.target.gen.es_ast
            or self.sync_loc(es.Identifier(name='undefined'), jac_node=here.target)
    );
    await_expr = self.sync_loc(es.AwaitExpression(argument=argument), jac_node=here);
    here.gen.es_ast = await_expr;
}

impl EsastGenPass.exit_yield_expr with uni.YieldExpr exit {
    argument: (es.Expression | None) = None;
    if here.expr and here.expr.gen.es_ast {
        argument = cast(es.Expression, here.expr.gen.es_ast);
    }
    here.gen.es_ast = self.sync_loc(
        es.YieldExpression(argument=argument, delegate=here.with_from), jac_node=here
    );
}

impl EsastGenPass._ability_is_generator(nd: uni.Ability) -> bool {
    for y in nd.get_all_sub_nodes(uni.YieldExpr) {
        if y.find_parent_of_type(uni.Ability) is nd {
            return True;
        }
    }
    return False;
}

impl EsastGenPass.exit_cast_expr with uni.CastExpr exit {
    here.gen.es_ast = here.value.gen.es_ast;
}

impl EsastGenPass.exit_if_else_expr with uni.IfElseExpr exit {
    `test = self._coerce_truthy(
        here.condition,
        cast(
            es.Expression,
            here.condition.gen.es_ast
                or self.sync_loc(
                    es.Identifier(name='condition'), jac_node=here.condition
                )
        ),
        here
    );
    consequent = cast(
        es.Expression,
        here.value.gen.es_ast
            or self.sync_loc(es.Identifier(name='value'), jac_node=here.value)
    );
    alternate = cast(
        es.Expression,
        here.else_value.gen.es_ast
            or self.sync_loc(es.Identifier(name='alternate'), jac_node=here.else_value)
    );
    cond_expr = self.sync_loc(
        es.ConditionalExpression(
            `test=`test, consequent=consequent, alternate=alternate
        ),
        jac_node=here
    );
    here.gen.es_ast = cond_expr;
}

impl EsastGenPass._template_element(
    text: str, tail: bool, jac_node: uni.UniNode
) -> es.TemplateElement {
    return self.sync_loc(
        es.TemplateElement(tail=tail, value={'cooked': text}), jac_node=jac_node
    );
}

impl EsastGenPass.exit_f_string with uni.FString exit {
    quasis: list[es.TemplateElement] = [];
    expressions: list[es.Expression] = [];
    for (i, part) in enumerate(here.parts) {
        is_last = i == (len(here.parts) - 1);
        if isinstance(part, uni.String) {
            quasis.append(self._template_element(str(part.lit_value), is_last, part));
        } elif isinstance(part, uni.FormattedValue) {
            if ((i == 0) or not isinstance(here.parts[(i - 1)], uni.String)) {
                quasis.append(self._template_element('', False, part));
            }
            expr = cast(
                es.Expression,
                part.gen.es_ast or self.sync_loc(es.Literal(value=''), jac_node=part)
            );
            expressions.append(expr);
            if is_last {
                quasis.append(self._template_element('', True, part));
            }
        }
    }
    if not quasis {
        quasis.append(self._template_element('', True, here));
    }
    while (len(quasis) < (len(expressions) + 1)) {
        quasis.append(self._template_element('', True, here));
    }
    template_lit = self.sync_loc(
        es.TemplateLiteral(quasis=quasis, expressions=expressions), jac_node=here
    );
    here.gen.es_ast = template_lit;
}

impl EsastGenPass.exit_formatted_value with uni.FormattedValue exit {
    expr = here.format_part.gen.es_ast
        or self.sync_loc(es.Literal(value=''), jac_node=here.format_part);
    if here.format_spec is not None {
        spec_es = here.format_spec.gen.es_ast
            or self.sync_loc(es.Literal(value=''), jac_node=here.format_spec);
        format_callee = self.sync_loc(
            es.MemberExpression(
                object=self.sync_loc(
                    es.MemberExpression(
                        object=self.sync_loc(es.Identifier(name='_jac'), jac_node=here),
                        property=self.sync_loc(
                            es.Identifier(name='builtin'), jac_node=here
                        ),
                        computed=False
                    ),
                    jac_node=here
                ),
                property=self.sync_loc(es.Identifier(name='format'), jac_node=here),
                computed=False
            ),
            jac_node=here
        );
        self.needs_jac_runtime = True;
        here.gen.es_ast = self.sync_loc(
            es.CallExpression(
                callee=cast(es.Expression, format_callee),
                arguments=[cast(es.Expression, expr), cast(es.Expression, spec_es)]
            ),
            jac_node=here
        );
        return;
    }
    here.gen.es_ast = expr;
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

impl EsastGenPass.exit_string with uni.String exit {
    here.gen.es_ast = self._str_literal(here);
}

impl EsastGenPass.exit_multi_string with uni.MultiString exit {
    if not here.strings {
        null_lit = self.sync_loc(es.Literal(value='', raw='""'), jac_node=here);
        here.gen.es_ast = null_lit;
        return;
    }
    if (len(here.strings) == 1) {
        string_node = here.strings[0];
        if string_node.gen.es_ast {
            here.gen.es_ast = string_node.gen.es_ast;
        } elif isinstance(string_node, uni.String) {
            here.gen.es_ast = self._str_literal(string_node);
        } else {
            here.gen.es_ast = self.sync_loc(es.Literal(value=''), jac_node=here);
        }
        return;
    }
    parts = [];
    for string_node in here.strings {
        if string_node.gen.es_ast {
            parts.append(string_node.gen.es_ast);
        } elif isinstance(string_node, uni.String) {
            parts.append(self._str_literal(string_node));
        }
    }
    if not parts {
        here.gen.es_ast = self.sync_loc(es.Literal(value=''), jac_node=here);
        return;
    }
    result: es.Expression = cast(es.Expression, parts[0]);
    for part in parts[1:] {
        result = self.sync_loc(
            es.BinaryExpression(
                operator='+', left=result, right=cast(es.Expression, part)
            ),
            jac_node=here
        );
    }
    here.gen.es_ast = result;
}

impl EsastGenPass.exit_float with uni.Float exit {
    float_lit = self.sync_loc(
        es.Literal(value=float(here.value), raw=here.value), jac_node=here
    );
    here.gen.es_ast = float_lit;
}

impl EsastGenPass.exit_int with uni.Int exit {
    int_lit = self.sync_loc(
        es.Literal(value=int(here.value, 0), raw=here.value), jac_node=here
    );
    here.gen.es_ast = int_lit;
}

impl EsastGenPass.exit_bool with uni.Bool exit {
    value = here.value.lower() == 'true';
    raw_value = 'true' if value else 'false';
    bool_lit = self.sync_loc(es.Literal(value=value, raw=raw_value), jac_node=here);
    here.gen.es_ast = bool_lit;
}

impl EsastGenPass.exit_inner_compr with uni.InnerCompr exit {}

impl EsastGenPass.exit_list_compr with uni.ListCompr exit {
    if here.__class__ is not uni.ListCompr {
        return;
    }
    self._build_compr_chain(here);
}

impl EsastGenPass.exit_set_compr with uni.SetCompr exit {
    self._build_compr_chain(here);
    if here.gen.es_ast {
        here.gen.es_ast = self.sync_loc(
            es.NewExpression(
                callee=self.sync_loc(es.Identifier(name='Set'), jac_node=here),
                arguments=[cast(es.Expression, here.gen.es_ast)]
            ),
            jac_node=here
        );
    }
}

impl EsastGenPass.exit_gen_compr with uni.GenCompr exit {
    self._build_compr_chain(here);
}

impl EsastGenPass.exit_dict_compr with uni.DictCompr exit {
    key_expr = cast(es.Expression, here.kv_pair.key.gen.es_ast)
        if here.kv_pair.key
        else None;
    val_expr = cast(es.Expression, here.kv_pair.value.gen.es_ast);
    if not key_expr or not val_expr {
        here.gen.es_ast = self.sync_loc(
            es.ObjectExpression(properties=[]), jac_node=here
        );
        return;
    }

    out_expr = self.sync_loc(
        es.ArrayExpression(elements=[key_expr, val_expr]), jac_node=here.kv_pair
    );

    chain = self._build_compr_expr(here.compr, out_expr, here);
    if not chain {
        here.gen.es_ast = self.sync_loc(
            es.ObjectExpression(properties=[]), jac_node=here
        );
        return;
    }

    here.gen.es_ast = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.MemberExpression(
                    object=self.sync_loc(es.Identifier(name='Object'), jac_node=here),
                    property=self.sync_loc(
                        es.Identifier(name='fromEntries'), jac_node=here
                    ),
                    computed=False
                ),
                jac_node=here
            ),
            arguments=[chain]
        ),
        jac_node=here
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

impl EsastGenPass.exit_k_v_pair with uni.KVPair exit {}

impl EsastGenPass.exit_dict_val with uni.DictVal exit {
    properties: list[(es.Property | es.SpreadElement)] = [];
    for kv_pair in here.kv_pairs {
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
    obj_expr = self.sync_loc(es.ObjectExpression(properties=properties), jac_node=here);
    here.gen.es_ast = obj_expr;
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

impl EsastGenPass.exit_tuple_val with uni.TupleVal exit {
    self._gen_seq_array(here);
}

impl EsastGenPass.exit_set_val with uni.SetVal exit {
    elements: list[es.Expression | es.SpreadElement | None] = [];
    for item in here.values {
        if item.gen.es_ast {
            elements.append(cast(es.Expression, item.gen.es_ast));
        }
    }
    set_expr = self.sync_loc(
        es.NewExpression(
            callee=self.sync_loc(es.Identifier(name='Set'), jac_node=here),
            arguments=[
                self.sync_loc(es.ArrayExpression(elements=elements), jac_node=here)
            ]
        ),
        jac_node=here
    );
    here.gen.es_ast = set_expr;
}

impl EsastGenPass.exit_list_val with uni.ListVal exit {
    self._gen_seq_array(here);
}

impl EsastGenPass.exit_atom_unit with uni.AtomUnit exit {
    if (isinstance(here.value, uni.Ability) and here.value.gen.es_ast) {
        func_decl = here.value.gen.es_ast;
        if isinstance(func_decl, es.FunctionDeclaration) {
            func_expr = self.sync_loc(
                es.FunctionExpression(
                    id=func_decl.id,
                    params=func_decl.params,
                    body=func_decl.body,
                    generator=func_decl.generator,
                    async_=func_decl.async_
                ),
                jac_node=here.value
            );
            here.gen.es_ast = func_expr;
        } else {
            here.gen.es_ast = here.value.gen.es_ast;
        }
    } elif (here.value and here.value.gen.es_ast) {
        here.gen.es_ast = here.value.gen.es_ast;
    } else {
        here.gen.es_ast = self.sync_loc(es.Literal(value=None), jac_node=here);
    }
}

impl EsastGenPass.exit_lambda_expr with uni.LambdaExpr exit {
    params: list[es.Pattern] = [];
    if isinstance(here.signature, uni.FuncSignature) {
        for param in here.signature.get_parameters() {
            if param.gen.es_ast {
                params.append(cast(es.Pattern, param.gen.es_ast));
            }
        }
    }
    tail = here.tail_return_expr();
    if (tail is not None and isinstance(here.body, list)) {
        body_expr = cast(
            es.Expression,
            tail.gen.es_ast or self.sync_loc(es.Literal(value=None), jac_node=tail)
        );
        here.gen.es_ast = self.sync_loc(
            es.ArrowFunctionExpression(
                params=params, body=body_expr, expression=True, async_=False
            ),
            jac_node=here
        );
    } elif isinstance(here.body, list) {
        body_stmts: list[es.Statement] = [];
        for stmt in here.body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, list) {
                    body_stmts.extend(stmt.gen.es_ast);
                } else {
                    body_stmts.append(stmt.gen.es_ast);
                }
            }
        }
        body_stmts = self._prepend_hoisted(here, body_stmts);
        block_stmt = self.sync_loc(es.BlockStatement(body=body_stmts), jac_node=here);
        arrow_func = self.sync_loc(
            es.ArrowFunctionExpression(params=params, body=block_stmt, async_=False),
            jac_node=here
        );
        here.gen.es_ast = arrow_func;
    } elif isinstance(here.body, uni.Expr) {
        body_expr = cast(
            es.Expression,
            here.body.gen.es_ast
                or self.sync_loc(es.Literal(value=None), jac_node=here.body)
        );
        arrow_func = self.sync_loc(
            es.ArrowFunctionExpression(
                params=params, body=body_expr, expression=True, async_=False
            ),
            jac_node=here
        );
        here.gen.es_ast = arrow_func;
    }
}

impl EsastGenPass.exit_atom_trailer with uni.AtomTrailer exit {
    if here.is_attr and self._trailer_reaches_ct_class(here) {
        folded = self._ct_es_expr(here.ct_value, here);
        if folded is not None {
            here.gen.es_ast = folded;
            return;
        }
    }
    if self._ct_ctor_slots(here) is not None and here.target.gen.es_ast {
        here.gen.es_ast = here.target.gen.es_ast;
        return;
    }
    `obj = cast(
        es.Expression,
        here.target.gen.es_ast
            or self.sync_loc(es.Identifier(name='obj'), jac_node=here.target)
    );
    if (here.right and here.right.gen.es_ast) {
        if isinstance(here.right, uni.Name) {
            prop = self.sync_loc(
                es.Identifier(name=here.right.sym_name), jac_node=here.right
            );
            member_expr = self.sync_loc(
                es.MemberExpression(object=`obj, property=prop, computed=False),
                jac_node=here
            );
            here.gen.es_ast = member_expr;
        } elif isinstance(here.right, uni.IndexSlice) {
            slice_info = here.right.gen.es_ast;
            if isinstance(slice_info, es.SliceInfo) {
                start = cast(
                    es.Expression,
                    (
                        slice_info.start
                        or self.sync_loc(es.Literal(value=0), jac_node=here)
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
                                    es.Identifier(name='slice'), jac_node=here
                                ),
                                computed=False
                            ),
                            jac_node=here
                        ),
                        arguments=slice_args
                    ),
                    jac_node=here
                );
                here.gen.es_ast = slice_call;
            } elif isinstance(slice_info, es.IndexInfo) {
                idx = cast(
                    es.Expression,
                    (
                        slice_info.value
                        or self.sync_loc(es.Literal(value=0), jac_node=here)
                    )
                );
                here.gen.es_ast = self._lower_subscript(here.target, `obj, idx, here);
            } else {
                here.gen.es_ast = `obj;
            }
        } else {
            here.gen.es_ast = here.right.gen.es_ast;
        }
    }
}

impl EsastGenPass.exit_special_var_ref with uni.SpecialVarRef exit {
    self._exit_name_impl(here);
}

impl EsastGenPass.exit_index_slice with uni.IndexSlice exit {
    if (here.slices and (len(here.slices) > 0)) {
        first_slice = here.slices[0];
        if here.is_range {
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
            here.gen.es_ast = es.SliceInfo(start=start_ast, stop=stop_ast);
        } else {
            value_ast = first_slice.start.gen.es_ast
                if (
                    first_slice.start
                    and first_slice.start.gen.es_ast
                    and isinstance(first_slice.start.gen.es_ast, es.Node)
                )
                else self.sync_loc(es.Literal(value=0), jac_node=here);
            here.gen.es_ast = es.IndexInfo(value=value_ast);
        }
    } else {
        here.gen.es_ast = None;
    }
}

impl EsastGenPass._resolve_source_module(nd: uni.Import) -> (uni.Module | None) {
    import from jaclang.compiler.symbol_utils { resolve_import_source_module }
    return resolve_import_source_module(self.prog, nd);
}

impl EsastGenPass._record_sv_backend(nd: uni.Import) -> None {
    import from pathlib { Path }
    import from jaclang.compiler.driver.boundary_classify {
        import_crosses_apps,
        import_provider_app,
        import_provider_route
    }
    if not nd.from_loc {
        return;
    }
    resolved_path = nd.from_loc.resolve_relative_path();
    if not resolved_path {
        return;
    }
    abs_path = str(Path(resolved_path).resolve());
    if abs_path.endswith(".jac") and Path(abs_path).exists() {
        if abs_path not in self.client_manifest.server_imports {
            self.client_manifest.server_imports.append(abs_path);
        }
        if import_crosses_apps(nd) {
            self.client_manifest.server_import_routes[abs_path] = {
                "app": import_provider_app(nd) or '',
                "route": import_provider_route(nd)
            };
        }
    }
}

impl EsastGenPass._is_service_bridge_import(nd: uni.Import) -> bool {
    import from jaclang.compiler.driver.boundary_classify {
        CrossAppKind,
        classify_cross_app_import
    }
    return (
        classify_cross_app_import(nd, self.ir_in.gen.interop_manifest)
        == CrossAppKind.SERVICE_BRIDGE
    );
}

impl EsastGenPass._sv_provider_options(nd: uni.Import) -> (es.Expression | None) {
    import from jaclang.compiler.driver.boundary_classify {
        import_crosses_apps,
        import_provider_app,
        import_provider_route
    }
    if not import_crosses_apps(nd) {
        return None;
    }
    provider_app = import_provider_app(nd) or '';
    provider_route = import_provider_route(nd);
    if not provider_app {
        return None;
    }
    props: list[es.Property | es.SpreadElement] = [];
    for (key, value) in [("app", provider_app), ("route", provider_route)] {
        props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Literal(value=key), jac_node=nd),
                    value=self.sync_loc(es.Literal(value=value), jac_node=nd),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=nd
            )
        );
    }
    return self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);
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
    return isinstance(rt, uni.Name)
        and rt.value in ('JsxElement', 'JsxPage', 'JsxLayout');
}

impl EsastGenPass._return_type_route_role(rt: uni.Expr) -> (str | None) {
    if (
        isinstance(rt, uni.BinaryExpr)
        and isinstance(rt.op, uni.Token)
        and rt.op.name == Tok.BW_OR
    ) {
        left_role = self._return_type_route_role(rt.left);
        return left_role or self._return_type_route_role(rt.right);
    }
    if isinstance(rt, uni.Name) {
        if rt.value == 'JsxPage' {
            return 'page';
        }
        if rt.value == 'JsxLayout' {
            return 'layout';
        }
    }
    return None;
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
    boundary_types: dict[(str, any)],
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
    boundary_types: dict[(str, any)],
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
        kw_key = kw.key;
        kw_name = '';
        if isinstance(kw_key, es.Identifier) {
            kw_name = kw_key.name;
        } elif isinstance(kw_key, es.Literal) {
            kw_name = str(kw_key.value);
        }
        if not kw_name {
            self.emit(
                E5099, node_override=nd, func=func_name, shape=type(kw_key).__name__
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
        and ability_node.code_context != CodeContext.NATIVE
        and not ability_node.in_client_context()
        and ability_node.access is not None
        and ability_node.access.tag.name == Tok.KW_PUB
    );
    if not is_server_func {
        return None;
    }
    func_name = nd.target.sym_name;
    self._warn_rpc_callable_params(ability_node, func_name, nd);

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

impl EsastGenPass._warn_rpc_callable_params(
    ability_node: uni.Ability, func_name: str, at: uni.UniNode
) -> None {
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return;
    }
    import re;
    import from jaclang.compiler.frontend.diagnostics { W6005 }
    _sig = ability_node.signature;
    for _plist in [_sig.posonly_params, _sig.params or [], _sig.kwonlyargs] {
        for _p in _plist {
            if (
                _p.type_tag is not None
                and _p.type_tag.tag is not None
                and re.search(r"\bCallable\b", unparse_node(_p.type_tag.tag))
            ) {
                self.emit(
                    W6005, node_override=at, func=func_name, param=_p.name.sym_name
                );
            }
        }
    }
}

impl EsastGenPass._forwarder_ret_label(ability_node: uni.Ability) -> str {
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return '';
    }
    rt = ability_node.signature.return_type;
    if rt is None {
        return '';
    }
    label = unparse_node(rt).strip();
    return '' if label in ('', 'None') else label;
}

impl EsastGenPass._build_server_forwarder(
    ability_node: uni.Ability, func_name: str, jac_node: uni.UniNode
) -> es.FunctionDeclaration {
    self._warn_rpc_callable_params(ability_node, func_name, jac_node);
    boundary = self.ir_in.gen.interop_manifest.boundary_types
        if self.ir_in.gen.interop_manifest
        else {};
    param_types = self._param_type_map_from_ability(ability_node);
    ret_type = self._extract_return_type(
        ability_node, func_name, self.ir_in.gen.interop_manifest
    );
    params: list[es.Pattern] = [];
    props: list[(es.Property | es.SpreadElement)] = [];
    for pname in self._param_names_from_ability(ability_node) {
        params.append(self.sync_loc(es.Identifier(name=pname), jac_node=jac_node));
        props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Literal(value=pname), jac_node=jac_node),
                    value=self._wrap_to_wire_if_boundary(
                        self.sync_loc(es.Identifier(name=pname), jac_node=jac_node),
                        param_types.get(pname, ''),
                        boundary,
                        jac_node
                    ),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=jac_node
            )
        );
    }
    call_expr: es.Expression = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.Identifier(name='__jacCallFunction'), jac_node=jac_node
            ),
            arguments=[
                self.sync_loc(es.Literal(value=func_name), jac_node=jac_node),
                self.sync_loc(es.ObjectExpression(properties=props), jac_node=jac_node)
            ]
        ),
        jac_node=jac_node
    );
    call_expr = self._wrap_return_with_boundary(
        call_expr, ret_type, boundary, jac_node, pre_awaited=False
    );
    self._inject_runtime_import('__jacCallFunction', jac_node);
    ret_label = self._forwarder_ret_label(ability_node);
    if ret_label {
        import from jaclang.compiler.frontend.diagnostics { W6009 }
        self.emit(W6009, node_override=jac_node, name=func_name, ret=ret_label);
    }
    return self.sync_loc(
        es.FunctionDeclaration(
            id=self.sync_loc(es.Identifier(name=func_name), jac_node=jac_node),
            params=params,
            body=self.sync_loc(
                es.BlockStatement(
                    body=[
                        self.sync_loc(
                            es.ReturnStatement(argument=call_expr), jac_node=jac_node
                        )
                    ]
                ),
                jac_node=jac_node
            ),
            async_=True
        ),
        jac_node=jac_node
    );
}

impl EsastGenPass._bind_client_value_refs(nd: uni.Module) -> list[es.Statement] {
    import from jaclang.compiler.symbol_utils {
        client_bridged_endpoint,
        client_value_ref_targets,
        element_display_name
    }
    forwarders: list[es.Statement] = [];
    bound: set[str] = set();
    for (ref_name, top) in client_value_ref_targets(nd, self.shared_arch_names) {
        if (isinstance(top, uni.Ability) and client_bridged_endpoint(nd, top)) {
            func_name = element_display_name(top);
            if func_name in bound {
                continue;
            }
            bound.add(func_name);
            forwarders.append(self._build_server_forwarder(top, func_name, ref_name));
            continue;
        }
        self._unbound_reported.add(ref_name.sym_name);
        self.emit(E5086, node_override=ref_name, name=ref_name.sym_name);
    }
    return forwarders;
}

impl EsastGenPass.exit_func_call with uni.FuncCall exit {
    if (
        (here.callee_decl is not None and here.callee_decl.is_comptime)
        or (isinstance(here.target, uni.Name) and self._ct_only_name(here.target))
    ) {
        folded = self._ct_es_expr(here.ct_value, here);
        if folded is not None {
            here.gen.es_ast = folded;
            return;
        }
    }
    args: list[(es.Expression | es.SpreadElement)] = [];
    props: list[(es.Property | es.SpreadElement)] = [];
    for param in here.params {
        if isinstance(param, uni.KWPair) {
            value_expr = cast(
                es.Expression,
                param.value.gen.es_ast
                    if (param.value and param.value.gen.es_ast)
                    else self.sync_loc(es.Literal(value=None), jac_node=param)
            );

            if not param.key {
                props.append(
                    self.sync_loc(es.SpreadElement(argument=value_expr), jac_node=param)
                );
                continue;
            }
            key_expr = cast(
                es.Expression,
                self.sync_loc(
                    es.Identifier(name=param.key.sym_name), jac_node=param.key
                )
            );
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

    for (ct_name, ct_expr) in (self._ct_ctor_slots(here.target) or []) {
        if ct_expr.gen.es_ast {
            props.append(
                self.sync_loc(
                    es.Property(
                        key=es.Identifier(name=ct_name),
                        value=cast(es.Expression, ct_expr.gen.es_ast),
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    ),
                    jac_node=ct_expr
                )
            );
        }
    }
    server_call = self._try_lower_server_rpc_call(here, args, props);
    if server_call is not None {
        here.gen.es_ast = server_call;
        return;
    }
    callee = here.target.gen.es_ast
        or self.sync_loc(es.Identifier(name='func'), jac_node=here.target);

    if (
        isinstance(callee, es.MemberExpression)
        and isinstance(callee.property, es.Identifier)
        and isinstance(here.target, uni.AtomTrailer)
    ) {
        import from jaclang.compiler.backends.es.es_unparse { JSCodeGenerator }

        _obj_type = here.target.target?.type;
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
                here.gen.es_ast = self.sync_loc(
                    es.Identifier(name=_result), jac_node=here
                );
                return;
            }
        }

        if self._poly_methods is not None and (_method_name in self._poly_methods) {
            _poly_args: list[(es.Expression | es.SpreadElement)] = [
                cast(es.Expression, callee.object),
                self.sync_loc(es.Literal(value=_method_name), jac_node=here)
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
            here.gen.es_ast = self.sync_loc(
                es.CallExpression(
                    callee=cast(es.Expression, _poly_callee), arguments=_poly_args
                ),
                jac_node=here
            );
            return;
        }
    }

    self._ensure_emitters();

    _call_kind = here.call_kind;
    if _call_kind == "builtin" and isinstance(here.target, uni.Name) {
        import from jaclang.compiler.backends.es.es_unparse { JSCodeGenerator }
        import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
        _builtin_name = here.target.sym_name;
        _emit_fn_name = "emit_" + _builtin_name;
        _emit_fn = getattr(self._builtin_emitter, _emit_fn_name, None);
        _sized_cast = _emit_fn is None and JAC_TYPE_REGISTRY.is_sized(_builtin_name);
        if _emit_fn or _sized_cast {
            _unparser = JSCodeGenerator();
            _arg_type_names: list[str] = [
                self._expr_type_name(_p)
                for _p in here.params
                if not isinstance(_p, uni.KWPair)
            ];
            _ctx = self._primitives_es_mod.ESEmitCtx(
                unparser=_unparser, arg_type_names=_arg_type_names
            );
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
                if _sized_cast {
                    _result = self._builtin_emitter.emit_sized_cast(
                        _builtin_name, _args_strs
                    );
                } else {
                    _result = _emit_fn(_ctx, _args_strs);
                }
            } except Exception as _emit_err {
                self.emit(
                    E5016, node_override=here, name=_builtin_name, error=str(_emit_err)
                );
                return;
            }

            if _result is not None {
                if "_jac." in str(_result) {
                    self.needs_jac_runtime = True;
                }
                here.gen.es_ast = self.sync_loc(
                    es.Identifier(name=_result), jac_node=here
                );
                return;
            }
        }
    }

    if isinstance(here.target, uni.BuiltinType)
        and isinstance(callee, es.MemberExpression) {
        self.needs_jac_runtime = True;
    }

    args_obj = self.sync_loc(es.ObjectExpression(properties=props), jac_node=here);
    callee_expr = cast(es.Expression, callee);
    call_args: list[(es.Expression | es.SpreadElement)] = args;
    (spread_arg, spread_read_source) = self._make_kwargs_spread_context(props, here);
    use_kwargs_temp = spread_read_source is not None;
    ability_node_resolved = self._resolve_call_ability(here);
    if props {
        if ability_node_resolved {
            ordered_args = self._call_args_from_slots(
                self._resolve_call_arg_slots(
                    here,
                    args,
                    props,
                    self._param_names_from_ability(ability_node_resolved),
                    here.target.sym_name
                        if isinstance(here.target, uni.Name)
                        else "func",
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
                here, callee_expr, ability_node_resolved, args, props
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
                                    es.Identifier(name=param_names[i]), jac_node=here
                                ),
                                value=cast(es.Expression, arg),
                                kind='init',
                                method=False,
                                shorthand=False,
                                computed=False
                            ),
                            jac_node=here
                        )
                    );
                }
            }
            result_expr = self.sync_loc(
                es.CallExpression(
                    callee=callee_expr,
                    arguments=[
                        self.sync_loc(
                            es.ObjectExpression(properties=wrap_props), jac_node=here
                        )
                    ]
                ),
                jac_node=here
            );
            if use_kwargs_temp and spread_arg is not None {
                result_expr = self._wrap_with_kwargs_temp(
                    result_expr, spread_arg, here
                );
            }
        }
        here.gen.es_ast = result_expr;
        return;
    }

    _target_type = here.target?.type;
    if _target_type is not None {
        _emit_new = _target_type.is_instantiable_class()
            and not _target_type.shared.is_builtin_class;
    } else {
        _emit_new = _call_kind == "instantiation";
    }
    if _emit_new and isinstance(callee, es.Expression) {
        result_expr: es.Expression = self.sync_loc(
            es.NewExpression(callee=callee_expr, arguments=call_args), jac_node=here
        );
    } else {
        result_expr = self.sync_loc(
            es.CallExpression(callee=callee_expr, arguments=call_args), jac_node=here
        );
    }
    if use_kwargs_temp and spread_arg is not None {
        result_expr = self._wrap_with_kwargs_temp(result_expr, spread_arg, here);
    }
    here.gen.es_ast = result_expr;
}

impl EsastGenPass.exit_assignment with uni.Assignment exit {
    if not here.target {
        here.gen.es_ast = None;
        return;
    }
    if here.is_comptime and here.value is not None {
        folded = self._ct_es_expr(here.value.ct_value, here.value);
        if folded is not None {
            here.value.gen.es_ast = folded;
        }
    }
    value_expr = here.value.gen.es_ast
        if (here.value and here.value.gen.es_ast)
        else None;

    if (
        len(here.target) == 1
        and isinstance(here.target[0], uni.Name)
        and here.target[0].sym_name == '_'
        and not here.aug_op
        and '_' not in self.reactive_vars
    ) {
        discard_value = cast(
            es.Expression, value_expr or es.Identifier(name='undefined')
        );
        void_expr = self.sync_loc(
            es.UnaryExpression(operator='void', prefix=True, argument=discard_value),
            jac_node=here
        );
        here.gen.es_ast = self.sync_loc(
            es.ExpressionStatement(expression=void_expr), jac_node=here
        );
        return;
    }

    if len(here.target) == 1 and isinstance(here.target[0], uni.Name) {
        target_name = here.target[0].sym_name;
        if target_name in self.reactive_vars {
            setter_arg: es.Expression;
            aug_op: (str | None) = None;
            if here.aug_op {
                aug_tok = Tok(here.aug_op.name)
                    if (here.aug_op.name in Tok.__members__)
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
                self.backend.lower_state_update(state_update), jac_node=here
            );
            expr_stmt = self.sync_loc(
                es.ExpressionStatement(expression=setter_call), jac_node=here
            );
            here.gen.es_ast = expr_stmt;
            return;
        }
    }
    if here.aug_op {
        (left, _, _) = self._convert_assignment_target(here.target[0]);
        aug_tok = Tok(here.aug_op.name)
            if (here.aug_op.name in Tok.__members__)
            else None;
        right = cast(
            es.Expression,
            (
                value_expr
                or self._get_ast_or_default(
                    here.value,
                    default_factory=lambda (_src: any) { es.Identifier(
                        name='undefined'
                    ); }
                )
            )
        );

        _aug_base = AUG_TO_BINARY_TOK.get(aug_tok) if aug_tok else None;
        if _aug_base is not None and _aug_base in FW_BINARY_OPS {
            _fw_aug = self._fw_binary(
                here.target[0],
                FW_BINARY_OPS[_aug_base],
                cast(es.Expression, left),
                right
            );
            if _fw_aug is not None {
                here.gen.es_ast = self.sync_loc(
                    es.ExpressionStatement(
                        expression=self.sync_loc(
                            es.AssignmentExpression(
                                operator='=', left=left, right=_fw_aug
                            ),
                            jac_node=here
                        )
                    ),
                    jac_node=here
                );
                return;
            }
        }
        _aug_emit_name = AUG_EMIT_MAP.get(aug_tok) if aug_tok else None;
        if _aug_emit_name {
            _prim_result = self._try_primitive_op(
                here.target[0], _aug_emit_name, cast(es.Expression, left), right, here
            );
            if _prim_result is not None {
                expr_stmt = self.sync_loc(
                    es.ExpressionStatement(expression=_prim_result), jac_node=here
                );
                here.gen.es_ast = expr_stmt;
                return;
            }
        }
        operator = ES_AUG_ASSIGN_OPS.get(aug_tok) if aug_tok else None;
        operator = operator or '=';
        assign_expr = self.sync_loc(
            es.AssignmentExpression(operator=operator, left=left, right=right),
            jac_node=here
        );
        expr_stmt = self.sync_loc(
            es.ExpressionStatement(expression=assign_expr), jac_node=here
        );
        here.gen.es_ast = expr_stmt;
        return;
    }

    if len(here.target) == 1 {
        _setitem = self._try_subscript_setitem(here.target[0], value_expr, here);
        if _setitem is not None {
            here.gen.es_ast = _setitem;
            return;
        }
    }
    targets_info: list[AssignmentTargetInfo] = [];
    for target_node in here.target {
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
                here.value,
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
        cur_scope = self._current_scope();

        if decl_name {
            owning = self._declaring_scope_for(target_node);
            if owning is None {
                should_declare = not self._is_declared_in_any_scope(decl_name);
            } elif owning is cur_scope {
                should_declare = decl_name not in owning.declared;
            } elif decl_name not in owning.declared {
                self._hoist_into(owning, decl_name, target_node);
            }
        } elif pattern_names {
            inline_ok = True;
            for (name, name_node) in pattern_names {
                p_owning = self._declaring_scope_for(name_node);
                if p_owning is None {
                    if self._is_declared_in_any_scope(name) {
                        inline_ok = False;
                    }
                } elif (p_owning is not cur_scope) or (name in p_owning.declared) {
                    inline_ok = False;
                }
            }
            should_declare = inline_ok;
            if not inline_ok {
                for (name, name_node) in pattern_names {
                    p_owning = self._declaring_scope_for(name_node) or cur_scope;
                    if (
                        p_owning
                        and (name not in p_owning.declared)
                        and not self._is_declared_in_any_scope(name)
                    ) {
                        self._hoist_into(p_owning, name, name_node);
                    }
                }
            }
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
        here.gen.es_ast = statements[0];
    } else {
        here.gen.es_ast = statements;
    }
}

impl EsastGenPass._collect_pattern_names(
    target: uni.UniNode
) -> list[tuple[(str, uni.Name)]] {
    names: list[tuple[(str, uni.Name)]] = [];
    if isinstance(target, uni.Name) {
        names.append((target.sym_name, target));
    } elif (
        isinstance(target, uni.UnaryExpr)
        and isinstance(target.op, uni.Token)
        and target.op.name == Tok.STAR_MUL.value
    ) {
        names.extend(self._collect_pattern_names(target.operand));
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
    if (
        isinstance(target, uni.UnaryExpr)
        and isinstance(target.op, uni.Token)
        and target.op.name == Tok.STAR_MUL.value
    ) {
        (argument, _, _) = self._convert_assignment_target(target.operand);
        pattern = self.sync_loc(
            es.RestElement(argument=cast(es.Pattern, argument)),
            jac_node=target
        );
        return (pattern, None, None);
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
    return self.sync_loc(es.Identifier(name=_result), jac_node=jac_node);
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

impl EsastGenPass.exit_delete_stmt with uni.DeleteStmt exit {
    stmts: list[es.Statement] = [];
    ordinal = 0;
    for target in here.leaf_targets() {
        if not uni.DeleteStmt.is_location(target) {
            _st = self._es_destroy_stmt(target, here);
            if _st is not None {
                stmts.append(_st);
            }
        } elif isinstance(target, uni.AtomTrailer) {
            stmts.extend(self._es_delete_location(target, here, ordinal));
        } elif isinstance(target, uni.Name) {
            _name_es = target.gen.es_ast;
            if isinstance(_name_es, es.Node) {
                stmts.append(
                    self._es_poly_destroy_stmt(cast(es.Expression, _name_es), here)
                );
            }
            _st = self._es_release_name_stmt(target, here);
            if _st is not None {
                stmts.append(_st);
            }
        }
        ordinal += 1;
    }
    here.gen.es_ast = stmts[0]
        if len(stmts) == 1
        else self.sync_loc(es.BlockStatement(body=stmts), jac_node=here);
}

impl EsastGenPass._es_release_name_stmt(
    target: uni.Name, nd: uni.DeleteStmt
) -> (es.Statement | None) {
    _name_es = target.gen.es_ast;
    if not isinstance(_name_es, es.Identifier)
        or not self._is_declared_in_any_scope(_name_es.name) {
        return None;
    }
    return self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.AssignmentExpression(
                    operator='=',
                    left=self.sync_loc(es.Identifier(name=_name_es.name), jac_node=nd),
                    right=self.sync_loc(es.Identifier(name='undefined'), jac_node=nd)
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
}

impl EsastGenPass._es_destroy_stmt(
    target: uni.Expr, nd: uni.DeleteStmt
) -> (es.Statement | None) {
    _target_es = target.gen.es_ast;
    if not isinstance(_target_es, es.Node) {
        return None;
    }
    self.needs_osp_graph = True;
    return self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.Identifier(name='__ospDestroyW'), jac_node=nd
                    ),
                    arguments=[
                        cast(es.Expression, _target_es),
                        self.sync_loc(es.Literal(value=True), jac_node=nd)
                    ]
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
}

impl EsastGenPass._es_poly_destroy_stmt(
    value: es.Expression, nd: uni.DeleteStmt
) -> es.Statement {
    return self.sync_loc(
        es.ExpressionStatement(
            expression=self._build_jac_call(["_jac", "poly", "destroy"], [value], nd)
        ),
        jac_node=nd
    );
}

impl EsastGenPass._es_del_trivial(expr: es.Expression) -> bool {
    return isinstance(expr, (es.Identifier, es.Literal));
}

impl EsastGenPass._es_del_bind(
    expr: es.Expression, name: str, stmts: list[es.Statement], nd: uni.DeleteStmt
) -> es.Expression {
    stmts.append(
        self.sync_loc(
            es.VariableDeclaration(
                declarations=[
                    self.sync_loc(
                        es.VariableDeclarator(
                            id=self.sync_loc(es.Identifier(name=name), jac_node=nd),
                            `init=expr
                        ),
                        jac_node=nd
                    )
                ],
                kind='const'
            ),
            jac_node=nd
        )
    );
    return self.sync_loc(es.Identifier(name=name), jac_node=nd);
}

impl EsastGenPass._es_delete_location(
    target: uni.AtomTrailer, nd: uni.DeleteStmt, ordinal: int
) -> list[es.Statement] {
    stmts: list[es.Statement] = [];
    _obj_es = target.target.gen.es_ast;
    if not isinstance(_obj_es, es.Node) {
        return stmts;
    }
    prefix = f"_jac_del_{nd.loc.first_line}_{nd.loc.col_start}_{ordinal}";
    container = cast(es.Expression, _obj_es);
    if not self._es_del_trivial(container) {
        container = self._es_del_bind(container, prefix + "_c", stmts, nd);
    }
    if target.is_attr {
        _prop = target.right.gen.es_ast;
        if not isinstance(_prop, es.Node) {
            return stmts;
        }
        stmts.append(
            self._es_poly_destroy_stmt(
                self.sync_loc(
                    es.MemberExpression(
                        object=container,
                        property=cast(es.Expression, _prop),
                        computed=False
                    ),
                    jac_node=nd
                ),
                nd
            )
        );
        stmts.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=self.sync_loc(
                        es.UnaryExpression(
                            operator='delete',
                            prefix=True,
                            argument=self.sync_loc(
                                es.MemberExpression(
                                    object=container,
                                    property=cast(es.Expression, _prop),
                                    computed=False
                                ),
                                jac_node=nd
                            )
                        ),
                        jac_node=nd
                    )
                ),
                jac_node=nd
            )
        );
        return stmts;
    }
    _islice = target.right;
    if not isinstance(_islice, uni.IndexSlice) or not _islice.slices {
        return stmts;
    }
    _slice = _islice.slices[0];
    if _islice.is_range {
        parts: list[es.Expression] = [];
        for (_pname, _part) in [
            ("_s", _slice.start),
            ("_e", _slice.stop),
            ("_p", _slice.step)
        ] {
            _pe = self._es_slice_part(_part, nd);
            if not self._es_del_trivial(_pe) {
                _pe = self._es_del_bind(_pe, prefix + _pname, stmts, nd);
            }
            parts.append(_pe);
        }
        stmts.append(
            self._es_poly_destroy_stmt(
                self._build_jac_call(
                    ["_jac", "poly", "getslice"], [container] + parts, nd
                ),
                nd
            )
        );
        stmts.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=self._build_jac_call(
                        ["_jac", "poly", "delslice"], [container] + parts, nd
                    )
                ),
                jac_node=nd
            )
        );
        return stmts;
    }
    _idx = self._es_slice_part(_slice.start, nd);
    if not self._es_del_trivial(_idx) {
        _idx = self._es_del_bind(_idx, prefix + "_k", stmts, nd);
    }
    stmts.append(
        self._es_poly_destroy_stmt(
            self._build_jac_call(["_jac", "poly", "getitem"], [container, _idx], nd), nd
        )
    );
    stmts.append(
        self.sync_loc(
            es.ExpressionStatement(
                expression=self._build_jac_call(
                    ["_jac", "poly", "delitem"], [container, _idx], nd
                )
            ),
            jac_node=nd
        )
    );
    return stmts;
}

impl EsastGenPass._es_slice_part(
    part: (uni.Expr | None), nd: uni.DeleteStmt
) -> es.Expression {
    _part_es = part.gen.es_ast if part is not None else None;
    if isinstance(_part_es, es.Node) {
        return cast(es.Expression, _part_es);
    }
    return self.sync_loc(es.Literal(value=None), jac_node=nd);
}

impl EsastGenPass.exit_switch_case with uni.SwitchCase exit {
    case_test: (es.Expression | None) = None;
    if (here.pattern and isinstance(here.pattern, uni.MatchValue)) {
        case_test = self._get_ast_or_default(
            here.pattern.value,
            default_factory=lambda (_src: any) { es.Literal(value=None); }
        );
    }
    body_stmts = self._collect_stmt_body(here.body);
    here.gen.es_ast = self.sync_loc(
        es.SwitchCase(`test=case_test, consequent=body_stmts), jac_node=here
    );
}

impl EsastGenPass.exit_switch_stmt with uni.SwitchStmt exit {
    `test = self._get_ast_or_default(
        here.target, default_factory=lambda (_src: any) { es.Literal(value=None); }
    );
    cases: list[es.SwitchCase] = [];
    for stmt in here.cases {
        if (stmt.gen.es_ast and isinstance(stmt.gen.es_ast, es.SwitchCase)) {
            switch_case = cast(es.SwitchCase, stmt.gen.es_ast);
            cases.append(switch_case);
        }
    }
    here.gen.es_ast = self.sync_loc(
        es.SwitchStatement(discriminant=`test, cases=cases), jac_node=here
    );
}

impl EsastGenPass.exit_match_stmt with uni.MatchStmt exit {
    subj_expr = cast(
        es.Expression,
        self._get_ast_or_default(
            here.target, default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );
    self.match_seq += 1;
    subj_name = f"__jac_match_subj_{self.match_seq}";
    flag_name = f"__jac_matched_{self.match_seq}";
    stmts: list[es.Statement] = [];
    stmts.append(
        self.sync_loc(
            es.VariableDeclaration(
                declarations=[
                    self.sync_loc(
                        es.VariableDeclarator(
                            id=es.Identifier(name=subj_name), `init=subj_expr
                        ),
                        jac_node=here
                    )
                ],
                kind='let'
            ),
            jac_node=here
        )
    );
    stmts.append(
        self.sync_loc(
            es.VariableDeclaration(
                declarations=[
                    self.sync_loc(
                        es.VariableDeclarator(
                            id=es.Identifier(name=flag_name),
                            `init=es.Literal(value=False)
                        ),
                        jac_node=here
                    )
                ],
                kind='let'
            ),
            jac_node=here
        )
    );
    for mcase in here.cases {
        (cond, binds, ok) = self._lower_match_pattern(
            mcase.pattern, self.sync_loc(es.Identifier(name=subj_name), jac_node=mcase)
        );
        if not ok {
            here.gen.es_ast = self.sync_loc(es.BlockStatement(body=[]), jac_node=here);
            return;
        }
        body_stmts = self._collect_stmt_body(mcase.body);
        set_flag = self.sync_loc(
            es.ExpressionStatement(
                expression=self.sync_loc(
                    es.AssignmentExpression(
                        operator='=',
                        left=es.Identifier(name=flag_name),
                        right=es.Literal(value=True)
                    ),
                    jac_node=mcase
                )
            ),
            jac_node=mcase
        );
        inner: list[es.Statement] = list(binds);
        if mcase.guard is not None {
            guard_expr = self._coerce_truthy(
                mcase.guard,
                cast(
                    es.Expression,
                    self._get_ast_or_default(
                        mcase.guard,
                        default_factory=lambda (_src: any) { es.Literal(value=True); }
                    )
                ),
                mcase
            );
            inner.append(
                self.sync_loc(
                    es.IfStatement(
                        `test=guard_expr,
                        consequent=self.sync_loc(
                            es.BlockStatement(body=[set_flag] + body_stmts),
                            jac_node=mcase
                        )
                    ),
                    jac_node=mcase
                )
            );
        } else {
            inner.append(set_flag);
            inner.extend(body_stmts);
        }
        test_expr: es.Expression = self.sync_loc(
            es.UnaryExpression(
                operator='!', prefix=True, argument=es.Identifier(name=flag_name)
            ),
            jac_node=mcase
        );
        if cond is not None {
            test_expr = self.sync_loc(
                es.LogicalExpression(operator='&&', left=test_expr, right=cond),
                jac_node=mcase
            );
        }
        stmts.append(
            self.sync_loc(
                es.IfStatement(
                    `test=test_expr,
                    consequent=self.sync_loc(
                        es.BlockStatement(body=inner), jac_node=mcase
                    )
                ),
                jac_node=mcase
            )
        );
    }
    here.gen.es_ast = stmts;
}

impl EsastGenPass._match_subj_member(subj: es.Expression, field: str) -> es.Expression {
    return es.MemberExpression(
        object=subj, property=es.Identifier(name=field), computed=False
    );
}

impl EsastGenPass._match_bind_name(
    name_node: uni.UniNode, value: es.Expression
) -> es.Statement {
    bind_name = name_node.sym_name
        if isinstance(name_node, uni.AstSymbolNode)
        else str(name_node);
    self._ensure_identifier_declared(bind_name, name_node);
    return self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.AssignmentExpression(
                    operator='=', left=es.Identifier(name=bind_name), right=value
                ),
                jac_node=name_node
            )
        ),
        jac_node=name_node
    );
}

impl EsastGenPass._match_arch_field_order(pat: uni.MatchArch) -> (list[str] | None) {
    nm = pat.name;
    sym = nm.sym if isinstance(nm, uni.AstSymbolNode) else None;
    if sym is None {
        return None;
    }
    arch_node: (uni.UniNode | None) = sym.decl;
    while arch_node is not None and not isinstance(arch_node, uni.Archetype) {
        arch_node = arch_node.parent;
    }
    if arch_node is None {
        return None;
    }
    inner = self.unwrap_body(arch_node);
    if inner is None {
        return None;
    }
    order: list[str] = [];
    for stmt in inner {
        if isinstance(stmt, uni.ArchHas) {
            for hv in stmt.vars {
                order.append(hv.name.value);
            }
        }
    }
    return order or None;
}

impl EsastGenPass._lower_match_pattern(
    pat: uni.MatchPattern, subj: es.Expression
) -> tuple[(es.Expression | None), list[es.Statement], bool] {
    no_binds: list[es.Statement] = [];
    if isinstance(pat, uni.MatchWild) {
        return (None, no_binds, True);
    }
    if isinstance(pat, uni.MatchAs) {
        cond: (es.Expression | None) = None;
        binds: list[es.Statement] = [];
        if pat.pattern is not None {
            (cond, binds, ok) = self._lower_match_pattern(pat.pattern, subj);
            if not ok {
                return (None, no_binds, False);
            }
        }
        binds.append(self._match_bind_name(pat.name, subj));
        return (cond, binds, True);
    }
    if isinstance(pat, (uni.MatchValue, uni.MatchSingleton)) {
        val_node = pat.value;
        val_expr = cast(
            es.Expression,
            self._get_ast_or_default(
                val_node, default_factory=lambda (_src: any) { es.Literal(value=None); }
            )
        );

        op = '==' if self._is_null_literal(val_node) else '===';
        return (
            self.sync_loc(
                es.BinaryExpression(operator=op, left=subj, right=val_expr),
                jac_node=pat
            ),
            no_binds,
            True
        );
    }
    if isinstance(pat, uni.MatchOr) {
        or_cond: (es.Expression | None) = None;
        for sub in pat.patterns {
            (c, b, ok) = self._lower_match_pattern(sub, subj);
            if not ok {
                return (None, no_binds, False);
            }
            if b {
                self.emit(
                    E5018,
                    node_override=sub,
                    construct='binding in an or-pattern',
                    fix="Give each '|' alternative its own 'case', so the binding "
                    "appears once per branch."
                );
                return (None, no_binds, False);
            }
            if c is None {
                return (None, no_binds, True);
            }
            or_cond = c
                if or_cond is None
                else self.sync_loc(
                    es.LogicalExpression(operator='||', left=or_cond, right=c),
                    jac_node=pat
                );
        }
        return (or_cond, no_binds, True);
    }
    if isinstance(pat, uni.MatchSequence) {
        values = list(pat.values);
        star_idx = -1;
        for i in range(len(values)) {
            if isinstance(values[i], uni.MatchStar) {
                star_idx = i;
                break;
            }
        }
        conds: list[es.Expression] = [
            self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=es.Identifier(name='Array'),
                        property=es.Identifier(name='isArray'),
                        computed=False
                    ),
                    arguments=[subj]
                ),
                jac_node=pat
            )
        ];
        seq_binds: list[es.Statement] = [];
        subj_len = self._match_subj_member(subj, 'length');
        if star_idx < 0 {
            conds.append(
                self.sync_loc(
                    es.BinaryExpression(
                        operator='===',
                        left=subj_len,
                        right=es.Literal(value=len(values))
                    ),
                    jac_node=pat
                )
            );
        } else {
            conds.append(
                self.sync_loc(
                    es.BinaryExpression(
                        operator='>=',
                        left=subj_len,
                        right=es.Literal(value=len(values) - 1)
                    ),
                    jac_node=pat
                )
            );
        }
        for i in range(len(values)) {
            sub = values[i];
            if isinstance(sub, uni.MatchStar) {
                after = len(values) - 1 - i;
                slice_args: list[es.Expression] = [es.Literal(value=i)];
                if after > 0 {
                    slice_args.append(
                        self.sync_loc(
                            es.BinaryExpression(
                                operator='-',
                                left=self._match_subj_member(subj, 'length'),
                                right=es.Literal(value=after)
                            ),
                            jac_node=sub
                        )
                    );
                }
                seq_binds.append(
                    self._match_bind_name(
                        sub.name,
                        self.sync_loc(
                            es.CallExpression(
                                callee=self._match_subj_member(subj, 'slice'),
                                arguments=slice_args
                            ),
                            jac_node=sub
                        )
                    )
                );
                continue;
            }
            if star_idx >= 0 and i > star_idx {
                elem_idx: es.Expression = self.sync_loc(
                    es.BinaryExpression(
                        operator='-',
                        left=self._match_subj_member(subj, 'length'),
                        right=es.Literal(value=len(values) - i)
                    ),
                    jac_node=sub
                );
            } else {
                elem_idx = es.Literal(value=i);
            }
            elem = self.sync_loc(
                es.MemberExpression(object=subj, property=elem_idx, computed=True),
                jac_node=sub
            );
            (c, b, ok) = self._lower_match_pattern(sub, elem);
            if not ok {
                return (None, no_binds, False);
            }
            if c is not None {
                conds.append(c);
            }
            seq_binds.extend(b);
        }
        seq_cond: es.Expression = conds[0];
        for c in conds[1:] {
            seq_cond = self.sync_loc(
                es.LogicalExpression(operator='&&', left=seq_cond, right=c),
                jac_node=pat
            );
        }
        return (seq_cond, seq_binds, True);
    }
    if isinstance(pat, uni.MatchMapping) {
        map_conds: list[es.Expression] = [];
        map_binds: list[es.Statement] = [];
        rest_star: (uni.MatchStar | None) = None;
        matched_keys: list[es.Expression] = [];
        for `entry in pat.values {
            if isinstance(`entry, uni.MatchStar) {
                rest_star = `entry;
                continue;
            }
            key_node = `entry.key;
            if isinstance(key_node, uni.MatchValue) {
                key_node = key_node.value;
            }
            key_expr = cast(
                es.Expression,
                self._get_ast_or_default(
                    key_node,
                    default_factory=lambda (_src: any) { es.Literal(value=None); }
                )
            );
            map_conds.append(
                self.sync_loc(
                    es.CallExpression(
                        callee=es.MemberExpression(
                            object=es.MemberExpression(
                                object=es.MemberExpression(
                                    object=es.Identifier(name='Object'),
                                    property=es.Identifier(name='prototype'),
                                    computed=False
                                ),
                                property=es.Identifier(name='hasOwnProperty'),
                                computed=False
                            ),
                            property=es.Identifier(name='call'),
                            computed=False
                        ),
                        arguments=[subj, key_expr]
                    ),
                    jac_node=`entry
                )
            );
            val_at_key = self.sync_loc(
                es.MemberExpression(object=subj, property=key_expr, computed=True),
                jac_node=`entry
            );
            matched_keys.append(key_expr);
            (c, b, ok) = self._lower_match_pattern(`entry.value, val_at_key);
            if not ok {
                return (None, no_binds, False);
            }
            if c is not None {
                map_conds.append(c);
            }
            map_binds.extend(b);
        }
        if rest_star is not None {
            filter_arrow = self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[es.ArrayPattern(elements=[es.Identifier(name='__jac_k')])],
                    body=self.sync_loc(
                        es.UnaryExpression(
                            operator='!',
                            prefix=True,
                            argument=self.sync_loc(
                                es.CallExpression(
                                    callee=es.MemberExpression(
                                        object=es.ArrayExpression(
                                            elements=list(matched_keys)
                                        ),
                                        property=es.Identifier(name='includes'),
                                        computed=False
                                    ),
                                    arguments=[es.Identifier(name='__jac_k')]
                                ),
                                jac_node=rest_star
                            )
                        ),
                        jac_node=rest_star
                    ),
                    expression=True
                ),
                jac_node=rest_star
            );
            rest_value = self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=es.Identifier(name='Object'),
                        property=es.Identifier(name='fromEntries'),
                        computed=False
                    ),
                    arguments=[
                        self.sync_loc(
                            es.CallExpression(
                                callee=es.MemberExpression(
                                    object=self.sync_loc(
                                        es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.Identifier(name='Object'),
                                                property=es.Identifier(name='entries'),
                                                computed=False
                                            ),
                                            arguments=[subj]
                                        ),
                                        jac_node=rest_star
                                    ),
                                    property=es.Identifier(name='filter'),
                                    computed=False
                                ),
                                arguments=[filter_arrow]
                            ),
                            jac_node=rest_star
                        )
                    ]
                ),
                jac_node=rest_star
            );
            map_binds.append(self._match_bind_name(rest_star.name, rest_value));
        }
        if not map_conds {
            return (None, map_binds, True);
        }
        map_cond: es.Expression = map_conds[0];
        for c in map_conds[1:] {
            map_cond = self.sync_loc(
                es.LogicalExpression(operator='&&', left=map_cond, right=c),
                jac_node=pat
            );
        }
        return (map_cond, map_binds, True);
    }
    if isinstance(pat, uni.MatchArch) {
        cls_name = pat.name.sym_name
            if isinstance(pat.name, uni.AstSymbolNode)
            else None;
        if cls_name is None {
            self.emit(
                E5018,
                node_override=pat,
                construct='dotted class pattern',
                fix="Import the archetype directly and match on its bare name."
            );
            return (None, no_binds, False);
        }
        arch_conds: list[es.Expression] = [
            self.sync_loc(
                es.BinaryExpression(
                    operator='instanceof', left=subj, right=es.Identifier(name=cls_name)
                ),
                jac_node=pat
            )
        ];
        arch_binds: list[es.Statement] = [];
        pairs: list = [];
        arg_pats = list(pat.arg_patterns) if pat.arg_patterns else [];
        if arg_pats {
            order = self._match_arch_field_order(pat);
            if order is None or len(arg_pats) > len(order) {
                self.emit(
                    E5018,
                    node_override=pat,
                    construct='positional class pattern with unresolvable field order',
                    fix="Match the fields by keyword, 'Cls(field=pattern)', instead "
                    "of by position."
                );
                return (None, no_binds, False);
            }
            for i in range(len(arg_pats)) {
                pairs.append((order[i], arg_pats[i]));
            }
        }
        for kv in (list(pat.kw_patterns) if pat.kw_patterns else []) {
            fname = kv.key.sym_name if isinstance(kv.key, uni.AstSymbolNode) else None;
            if fname is None {
                self.emit(
                    E5018,
                    node_override=kv,
                    construct='computed class-pattern field',
                    fix="Name the field with a plain identifier instead of a "
                    "computed key."
                );
                return (None, no_binds, False);
            }
            pairs.append((fname, kv.value));
        }
        for (fname, sub_pat) in pairs {
            field_expr = self.sync_loc(
                self._match_subj_member(subj, fname), jac_node=pat
            );
            (c, b, ok) = self._lower_match_pattern(sub_pat, field_expr);
            if not ok {
                return (None, no_binds, False);
            }
            if c is not None {
                arch_conds.append(c);
            }
            arch_binds.extend(b);
        }
        arch_cond: es.Expression = arch_conds[0];
        for c in arch_conds[1:] {
            arch_cond = self.sync_loc(
                es.LogicalExpression(operator='&&', left=arch_cond, right=c),
                jac_node=pat
            );
        }
        return (arch_cond, arch_binds, True);
    }
    self.emit(
        E5018,
        node_override=pat,
        construct=pat.__class__.__name__,
        fix="Rewrite it with literal, capture, sequence, mapping, or class patterns."
    );
    return (None, no_binds, False);
}

impl EsastGenPass.exit_expr_stmt with uni.ExprStmt exit {
    expr = cast(
        es.Expression,
        self._get_ast_or_default(
            here.expr, default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );

    acc = self._cur_view_acc();
    if acc is not None {
        here.gen.es_ast = self._view_emit_child(acc, expr, here);
        return;
    }
    expr_stmt = self.sync_loc(es.ExpressionStatement(expression=expr), jac_node=here);
    here.gen.es_ast = expr_stmt;
}

impl EsastGenPass.exit_ctrl_stmt with uni.CtrlStmt exit {
    acc = self._cur_view_acc();
    if acc is not None and here.ctrl.value == "skip" {
        here.gen.es_ast = self._view_fragment_return(acc, here);
        return;
    }
    stmt: (es.BreakStatement | es.ContinueStatement | es.ReturnStatement);
    if (here.ctrl.name == Tok.KW_BREAK) {
        stmt = self.sync_loc(es.BreakStatement(), jac_node=here);
    } elif (here.ctrl.name == Tok.KW_SKIP) {
        stmt = self.sync_loc(es.ReturnStatement(argument=None), jac_node=here);
    } else {
        stmt = self.sync_loc(es.ContinueStatement(), jac_node=here);
    }
    here.gen.es_ast = stmt;
}

impl EsastGenPass.exit_return_stmt with uni.ReturnStmt exit {
    acc = self._cur_view_acc();
    if acc is not None {
        here.gen.es_ast = self._view_fragment_return(acc, here);
        return;
    }
    argument: (es.Expression | None) = None;
    if (here.expr and here.expr.gen.es_ast) {
        argument = cast(es.Expression, here.expr.gen.es_ast);
    }
    ret_stmt = self.sync_loc(es.ReturnStatement(argument=argument), jac_node=here);
    here.gen.es_ast = ret_stmt;
}

impl EsastGenPass.exit_assert_stmt with uni.AssertStmt exit {
    if here.is_comptime {
        here.gen.es_ast = None;
        return;
    }
    `test: es.Expression = cast(es.Expression, here.condition.gen.es_ast)
        if here.condition.gen.es_ast
        else self.sync_loc(es.Literal(value=True), jac_node=here.condition);
    negated_test = self.sync_loc(
        es.UnaryExpression(operator='!', prefix=True, argument=`test), jac_node=here
    );
    error_msg = 'Assertion failed';
    if (
        here.error_msg
        and here.error_msg.gen.es_ast
        and isinstance(here.error_msg.gen.es_ast, es.Literal)
    ) {
        error_msg = str(here.error_msg.gen.es_ast.value);
    }
    throw_stmt = self.sync_loc(
        es.ThrowStatement(
            argument=self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(es.Identifier(name='Error'), jac_node=here),
                    arguments=[
                        self.sync_loc(es.Literal(value=error_msg), jac_node=here)
                    ]
                ),
                jac_node=here
            )
        ),
        jac_node=here
    );
    if_stmt = self.sync_loc(
        es.IfStatement(
            `test=negated_test,
            consequent=self.sync_loc(
                es.BlockStatement(body=[throw_stmt]), jac_node=here
            )
        ),
        jac_node=here
    );
    here.gen.es_ast = if_stmt;
}

impl EsastGenPass._jac_exc_ref(
    member: str, jac_node: (uni.UniNode | None)
) -> es.MemberExpression {
    self.needs_jac_runtime = True;
    return cast(
        es.MemberExpression, self._build_jac_ref(['_jac', 'exc', member], jac_node)
    );
}

def _raised_exc_identity(cause: (uni.Expr | None)) -> tuple[bool, (str | None)] {
    if cause is None {
        return (False, None);
    }
    target = cause.target if isinstance(cause, uni.FuncCall) else cause;
    ty = target?.type;
    if ty is None {
        return (False, None);
    }
    shared = ty?.shared;
    if shared is None or not shared.is_builtin_class {
        return (True, None);
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    name = shared.class_name;
    return (True, name if JAC_TYPE_REGISTRY.is_exception(name) else None);
}

impl EsastGenPass.exit_raise_stmt with uni.RaiseStmt exit {
    argument: es.Expression = cast(es.Expression, here.cause.gen.es_ast)
        if (here.cause and here.cause.gen.es_ast)
        else self.sync_loc(es.Identifier(name='Error'), jac_node=here);

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
        (ty_known, exc_name) = _raised_exc_identity(here.cause);
        if not ty_known and JAC_TYPE_REGISTRY.is_exception(callee.name) {
            exc_name = callee.name;
        }
        if exc_name is not None {
            exc_ref = self._jac_exc_ref(exc_name, here);
            argument = self.sync_loc(
                es.NewExpression(callee=exc_ref, arguments=call_args or []),
                jac_node=here
            );
        } elif callee.name == 'Error' {
            argument = self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(es.Identifier(name='Error'), jac_node=here),
                    arguments=call_args or []
                ),
                jac_node=here
            );
        }
    }
    throw_stmt = self.sync_loc(es.ThrowStatement(argument=argument), jac_node=here);
    here.gen.es_ast = throw_stmt;
}

impl EsastGenPass.exit_finally_stmt with uni.FinallyStmt exit {
    here.gen.es_ast = self._build_block_statement(here, here.body);
}

impl EsastGenPass.exit_except with uni.Except exit {
    parent_try = here.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
        here.gen.es_ast = self._build_view_iife(
            here.body, acc if isinstance(acc, str) else VIEW_ACC, here
        );
        return;
    }

    body = self._build_block_statement(here, here.body);
    here.gen.es_ast = body;
}

impl EsastGenPass.enter_try_stmt with uni.TryStmt entry {
    if self._cur_view_acc() is not None and here.awaiting_body is not None {
        self._view_awaiting_tries.add(id(here));
        self._push_view_acc();
    }
}

impl EsastGenPass.enter_awaiting_clause with uni.AwaitingClause entry {
    parent_try = here.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        self._push_view_acc();
    }
}

impl EsastGenPass.exit_awaiting_clause with uni.AwaitingClause exit {
    parent_try = here.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
        here.gen.es_ast = self._build_view_iife(
            here.body, acc if isinstance(acc, str) else VIEW_ACC, here
        );
    }
}

impl EsastGenPass.enter_except with uni.Except entry {
    parent_try = here.find_parent_of_type(uni.TryStmt);
    if parent_try is not None and id(parent_try) in self._view_awaiting_tries {
        self._push_view_acc();
    }
}


impl EsastGenPass.exit_try_stmt with uni.TryStmt exit {
    if id(here) in self._view_awaiting_tries {
        self._view_awaiting_tries.discard(id(here));
        try_acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
        try_iife = self._build_view_iife(
            here.body, try_acc if isinstance(try_acc, str) else VIEW_ACC, here
        );
        awaiting_iife: es.Expression = (
            cast(es.Expression, here.awaiting_body.gen.es_ast)
                if (here.awaiting_body is not None and here.awaiting_body.gen.es_ast)
                else self._build_view_iife([], VIEW_ACC, here)
        );
        except_iifes: list[es.Expression] = [];
        if here.excepts {
            except_iifes = [
                cast(es.Expression, ex.gen.es_ast)
                for ex in here.excepts
                if ex.gen.es_ast is not None
            ];
        }
        async_boundary = AsyncBoundary(
            try_expr=try_iife, awaiting_expr=awaiting_iife, except_exprs=except_iifes
        );
        self._ensure_backend();
        for sym in self.backend.async_boundary_symbols(async_boundary) {
            self._inject_runtime_import(sym, here);
        }
        wrapper = self.sync_loc(
            self.backend.lower_async_boundary(async_boundary), jac_node=here
        );
        outer = self._cur_view_acc();
        if outer is not None {
            here.gen.es_ast = self._view_emit_child(outer, wrapper, here);
        } else {
            here.gen.es_ast = self.sync_loc(
                es.ExpressionStatement(expression=wrapper), jac_node=here
            );
        }
        return;
    }
    block = self._build_block_statement(here, here.body);
    handler: (es.CatchClause | None) = None;
    if here.excepts and len(here.excepts) > 0 {
        catch_param_name = "__jac_e";
        catch_param = self.sync_loc(
            es.Identifier(name=catch_param_name), jac_node=here
        );

        catch_body_stmts: list[es.Statement] = [];

        if_chain: (es.IfStatement | None) = None;
        for i in range(len(here.excepts) - 1, -1, -1) {
            except_node = here.excepts[i];

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

            (ex_ty_known, ex_builtin) = _raised_exc_identity(except_node.ex_type);
            if ex_ty_known {
                exc_type_name = ex_builtin;
            }
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
                        `test=test_expr, consequent=handler_body, alternate=if_chain
                    ),
                    jac_node=except_node
                );
            } else {
                if_chain = self.sync_loc(
                    es.IfStatement(
                        `test=self.sync_loc(
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
                                        jac_node=here
                                    )
                                ),
                                jac_node=here
                            )
                        ]
                    ),
                    jac_node=here
                );
            }
            catch_body_stmts.append(if_chain);
        }
        catch_body = self.sync_loc(
            es.BlockStatement(body=catch_body_stmts), jac_node=here
        );
        handler = self.sync_loc(
            es.CatchClause(param=catch_param, body=catch_body), jac_node=here
        );
    }
    finalizer: (es.BlockStatement | None) = None;
    if (
        here.finally_body
        and here.finally_body.gen.es_ast
        and isinstance(here.finally_body.gen.es_ast, es.BlockStatement)
    ) {
        finalizer = here.finally_body.gen.es_ast;
    }
    try_stmt = self.sync_loc(
        es.TryStatement(block=block, handler=handler, finalizer=finalizer),
        jac_node=here
    );
    here.gen.es_ast = try_stmt;
}

impl EsastGenPass._view_open_loop_acc(nd: uni.UniNode) -> None {
    acc = self._cur_view_acc();
    if (acc is None) or (acc in self._view_dynamic_accs) {
        return;
    }
    self._view_dynamic_accs.add(self._push_view_acc());
    self._view_slot_loops.add(id(nd));
}

impl EsastGenPass._view_loop_stmt(
    nd: uni.UniNode, loop_stmt: es.Statement
) -> es.Statement {
    if id(nd) not in self._view_slot_loops {
        return loop_stmt;
    }
    self._view_slot_loops.discard(id(nd));
    acc = self._view_stack.pop() if self._view_stack else None;
    if not isinstance(acc, str) {
        return loop_stmt;
    }
    iife = self._view_iife_from_stmts([loop_stmt], acc, nd);
    outer = self._cur_view_acc();
    if outer is not None {
        return self._view_emit_child(outer, iife, nd);
    }
    return self.sync_loc(es.ExpressionStatement(expression=iife), jac_node=nd);
}

impl EsastGenPass._view_chain_open(nd: uni.UniNode) -> None {
    acc = self._cur_view_acc();
    if (acc is None) or (acc in self._view_dynamic_accs) {
        return;
    }
    self._view_branch_base[id(nd)] = self._view_acc_next.get(acc, 0);
}

impl EsastGenPass._view_chain_arm(nd: uni.UniNode) -> None {
    acc = self._cur_view_acc();
    if (acc is None) or (acc in self._view_dynamic_accs) or (nd.parent is None) {
        return;
    }
    base = self._view_branch_base.get(id(nd.parent));
    if base is None {
        return;
    }
    self._view_branch_base[id(nd)] = base;
    self._view_acc_next[acc] = base;
}

impl EsastGenPass._view_chain_close(nd: uni.UniNode) -> None {
    if id(nd) not in self._view_branch_base {
        return;
    }
    self._view_branch_base.pop(id(nd), None);
    acc = self._cur_view_acc();
    if (acc is not None) and (acc not in self._view_dynamic_accs) {
        self._view_acc_next[acc] = self._view_acc_high.get(acc, 0);
    }
}

impl EsastGenPass.enter_if_stmt with uni.IfStmt entry {
    if here.__class__ is not uni.IfStmt {
        return;
    }
    self._view_chain_open(here);
}

impl EsastGenPass.enter_else_if with uni.ElseIf entry {
    self._view_chain_arm(here);
}

impl EsastGenPass.enter_else_stmt with uni.ElseStmt entry {
    self._view_chain_arm(here);
}

impl EsastGenPass.enter_in_for_stmt with uni.InForStmt entry {
    self._view_open_loop_acc(here);
}

impl EsastGenPass.enter_iter_for_stmt with uni.IterForStmt entry {
    self._view_open_loop_acc(here);
}

impl EsastGenPass.enter_while_stmt with uni.WhileStmt entry {
    self._view_open_loop_acc(here);
}

impl EsastGenPass.enter_forever_stmt with uni.ForeverStmt entry {
    self._view_open_loop_acc(here);
}

impl EsastGenPass.exit_in_for_stmt with uni.InForStmt exit {
    if here.is_comptime {
        folded = self._ct_es_expr(here.collection.ct_value, here.collection);
        if folded is not None {
            here.collection.gen.es_ast = folded;
        }
    }
    target_ast = here.target.gen.es_ast;
    left: es.Node = target_ast
        if isinstance(target_ast, es.Node)
        else self.sync_loc(es.Identifier(name='item'), jac_node=here.target);
    right: es.Expression = cast(es.Expression, here.collection.gen.es_ast)
        if here.collection.gen.es_ast
        else self.sync_loc(es.Identifier(name='collection'), jac_node=here.collection);

    ctype = self._expr_type_name(here.collection);
    if ctype == "dict" {
        right = self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(
                    es.MemberExpression(
                        object=self.sync_loc(
                            es.Identifier(name='Object'), jac_node=here.collection
                        ),
                        property=self.sync_loc(
                            es.Identifier(name='keys'), jac_node=here.collection
                        ),
                        computed=False
                    ),
                    jac_node=here.collection
                ),
                arguments=[right]
            ),
            jac_node=here.collection
        );
    } elif ctype
        not in [
            "list",
            "str",
            "tuple",
            "set",
            "bytes",
            "bytearray",
            "range",
            "generator",
            "frozenset"
        ]
        and not self._is_native_iterable_builtin_call(here.collection) {
        right = self._build_jac_call(
            ["_jac", "builtin", "iter"], [right], here.collection
        );
    }
    body = self._build_block_statement(here, here.body);
    if isinstance(left, es.VariableDeclaration) {
        decl = left;
    } else {
        pattern = self._target_to_pattern(left, here.target);
        declarator = self.sync_loc(
            es.VariableDeclarator(id=pattern, `init=None), jac_node=here.target
        );
        decl = self.sync_loc(
            es.VariableDeclaration(declarations=[declarator], kind='const'),
            jac_node=here.target
        );
    }
    for_stmt = self.sync_loc(
        es.ForOfStatement(left=decl, right=right, body=body, await_=here.is_async),
        jac_node=here
    );
    here.gen.es_ast = self._view_loop_stmt(here, for_stmt);
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

impl EsastGenPass.exit_iter_for_stmt with uni.IterForStmt exit {
    `init: es.VariableDeclaration | es.Expression | None = None;
    if (here.iter and here.iter.gen.es_ast) {
        iter_gen = here.iter.gen.es_ast;
        if isinstance(iter_gen, es.ExpressionStatement) {
            `init = cast(es.Expression, iter_gen.expression);
        } else {
            `init = cast('es.VariableDeclaration | es.Expression', iter_gen);
        }
    }
    `test: (es.Expression | None) = None;
    if (here.condition and here.condition.gen.es_ast) {
        `test = cast(es.Expression, here.condition.gen.es_ast);
    }
    update: (es.AssignmentExpression | None) = None;
    if (
        here.count_by
        and here.count_by.gen.es_ast
        and isinstance(here.count_by.gen.es_ast, es.ExpressionStatement)
    ) {
        update = cast(es.AssignmentExpression, here.count_by.gen.es_ast.expression);
    }
    body = self._build_block_statement(here, here.body);
    here.gen.es_ast = self._view_loop_stmt(
        here,
        self.sync_loc(
            es.ForStatement(`init=`init, `test=`test, update=update, body=body),
            jac_node=here
        )
    );
}

impl EsastGenPass.exit_while_stmt with uni.WhileStmt exit {
    `test = self._coerce_truthy(
        here.condition,
        cast(
            es.Expression,
            self._get_ast_or_default(
                here.condition,
                default_factory=lambda (_src: any) { es.Literal(value=True); }
            )
        ),
        here
    );
    body = self._build_block_statement(here, here.body);
    while_stmt = self.sync_loc(
        es.WhileStatement(`test=`test, body=body), jac_node=here
    );
    here.gen.es_ast = self._view_loop_stmt(here, while_stmt);
}

impl EsastGenPass.exit_forever_stmt with uni.ForeverStmt exit {
    body = self._build_block_statement(here, here.body);
    forever_stmt = self.sync_loc(
        es.WhileStatement(`test=es.Literal(value=True), body=body), jac_node=here
    );
    here.gen.es_ast = self._view_loop_stmt(here, forever_stmt);
}

impl EsastGenPass.exit_else_stmt with uni.ElseStmt exit {
    self._view_chain_close(here);
    stmts = self._collect_stmt_body(here.body);
    stmts = self._prepend_hoisted(here, stmts);
    block = self.sync_loc(es.BlockStatement(body=stmts), jac_node=here);
    here.gen.es_ast = block;
}

impl EsastGenPass.exit_else_if with uni.ElseIf exit {
    self._view_chain_close(here);
    if here.is_comptime and here.ct_taken is not None {
        if here.ct_taken {
            here.gen.es_ast = self._build_block_statement(here, here.body);
        } elif here.else_body and here.else_body.gen.es_ast {
            here.gen.es_ast = cast(es.Statement, here.else_body.gen.es_ast);
        } else {
            here.gen.es_ast = None;
        }
        return;
    }
    `test = self._coerce_truthy(
        here.condition,
        cast(
            es.Expression,
            self._get_ast_or_default(
                here.condition,
                default_factory=lambda (_src: any) { es.Literal(value=True); }
            )
        ),
        here
    );
    consequent = self._build_block_statement(here, here.body);
    alternate: (es.Statement | None) = None;
    if (here.else_body and here.else_body.gen.es_ast) {
        alternate = cast(es.Statement, here.else_body.gen.es_ast);
    }
    if_stmt = self.sync_loc(
        es.IfStatement(`test=`test, consequent=consequent, alternate=alternate),
        jac_node=here
    );
    here.gen.es_ast = if_stmt;
}

impl EsastGenPass.exit_if_stmt with uni.IfStmt exit {
    if here.__class__ is not uni.IfStmt {
        return;
    }
    self._view_chain_close(here);
    if here.is_comptime and here.ct_taken is not None {
        if here.ct_taken {
            here.gen.es_ast = self._build_block_statement(here, here.body);
        } elif here.else_body and here.else_body.gen.es_ast {
            here.gen.es_ast = cast(es.Statement, here.else_body.gen.es_ast);
        } else {
            here.gen.es_ast = None;
        }
        return;
    }
    `test = self._coerce_truthy(
        here.condition,
        cast(
            es.Expression,
            self._get_ast_or_default(
                here.condition,
                default_factory=lambda (_src: any) { es.Literal(value=True); }
            )
        ),
        here
    );
    consequent = self._build_block_statement(here, here.body);
    alternate: (es.Statement | None) = None;
    if (here.else_body and here.else_body.gen.es_ast) {
        alternate = cast(es.Statement, here.else_body.gen.es_ast);
    }
    if_stmt = self.sync_loc(
        es.IfStatement(`test=`test, consequent=consequent, alternate=alternate),
        jac_node=here
    );
    here.gen.es_ast = if_stmt;
}

impl EsastGenPass.exit_jsx_expression with uni.JsxExpression exit {
    self.jsx_processor.expression(here);
}

impl EsastGenPass.enter_jsx_slot with uni.JsxSlot entry {
    self._push_view_acc();
}

impl EsastGenPass.exit_jsx_slot with uni.JsxSlot exit {
    acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
    acc_name = acc if isinstance(acc, str) else VIEW_ACC;
    here.gen.es_ast = self._build_view_iife(here.body, acc_name, here);
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
    self._view_acc_next[name] = 0;
    self._view_acc_high[name] = 0;
    self._view_stack.append(name);
    return name;
}

impl EsastGenPass._view_alloc_index(acc_name: str) -> int {
    index = self._view_acc_next.get(acc_name, 0);
    self._view_acc_next[acc_name] = index + 1;
    if (index + 1) > self._view_acc_high.get(acc_name, 0) {
        self._view_acc_high[acc_name] = index + 1;
    }
    return index;
}

impl EsastGenPass._view_assign_stmt(
    acc_name: str, index: int, value: es.Expression, anchor: uni.UniNode
) -> es.ExpressionStatement {
    slot = self.sync_loc(
        es.MemberExpression(
            object=self.sync_loc(es.Identifier(name=acc_name), jac_node=anchor),
            property=self.sync_loc(es.Literal(value=index), jac_node=anchor),
            computed=True,
            optional=False
        ),
        jac_node=anchor
    );
    assign = self.sync_loc(
        es.AssignmentExpression(operator='=', left=slot, right=value), jac_node=anchor
    );
    return self.sync_loc(es.ExpressionStatement(expression=assign), jac_node=anchor);
}

impl EsastGenPass._view_emit_child(
    acc_name: str, value: es.Expression, anchor: uni.UniNode
) -> es.ExpressionStatement {
    if acc_name in self._view_dynamic_accs {
        return self._view_push_stmt(acc_name, value, anchor);
    }
    return self._view_assign_stmt(
        acc_name, self._view_alloc_index(acc_name), value, anchor
    );
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
    children: es.Expression, anchor: uni.UniNode
) -> es.CallExpression {
    import from jaclang.client.client_surface { backend_jsx_factory_name }
    self._ensure_backend();
    factory_name = backend_jsx_factory_name(self.backend);
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name=factory_name), jac_node=anchor),
            arguments=[
                self.sync_loc(es.Literal(value=None), jac_node=anchor),
                self.sync_loc(es.ObjectExpression(properties=[]), jac_node=anchor),
                children
            ]
        ),
        jac_node=anchor
    );
}

impl EsastGenPass._view_fragment_return(
    acc_name: str, anchor: uni.UniNode
) -> es.ReturnStatement {
    acc_id = self.sync_loc(es.Identifier(name=acc_name), jac_node=anchor);
    argument: es.Expression = acc_id
        if acc_name in self._view_dynamic_accs
        else self._jsx_fragment(acc_id, anchor);
    return self.sync_loc(es.ReturnStatement(argument=argument), jac_node=anchor);
}

impl EsastGenPass._build_view_iife(
    body_nodes: (Sequence[uni.UniNode] | None), acc_name: str, anchor: uni.UniNode
) -> es.CallExpression {
    return self._view_iife_from_stmts(
        self._collect_stmt_body(body_nodes), acc_name, anchor
    );
}

impl EsastGenPass._view_iife_from_stmts(
    stmts: list[es.Statement], acc_name: str, anchor: uni.UniNode
) -> es.CallExpression {
    init = self.sync_loc(
        es.VariableDeclaration(
            declarations=[
                self.sync_loc(
                    es.VariableDeclarator(
                        id=self.sync_loc(es.Identifier(name=acc_name), jac_node=anchor),
                        `init=self.sync_loc(
                            es.ArrayExpression(
                                elements=[
                                    self.sync_loc(
                                        es.Literal(value=False), jac_node=anchor
                                    )
                                    for _ in range(
                                        0
                                            if acc_name in self._view_dynamic_accs
                                            else self._view_acc_high.get(acc_name, 0)
                                    )
                                ]
                            ),
                            jac_node=anchor
                        )
                    ),
                    jac_node=anchor
                )
            ],
            kind='let'
        ),
        jac_node=anchor
    );
    body: list[es.Statement] = [init];
    body.extend(stmts);
    body.append(self._view_fragment_return(acc_name, anchor));
    block = self.sync_loc(es.BlockStatement(body=body), jac_node=anchor);
    arrow = self.sync_loc(
        es.ArrowFunctionExpression(params=[], body=block, async_=False), jac_node=anchor
    );
    return self.sync_loc(
        es.CallExpression(callee=arrow, arguments=[]), jac_node=anchor
    );
}

impl EsastGenPass.exit_jsx_text with uni.JsxText exit {
    self.jsx_processor.text(here);
}

impl EsastGenPass.exit_jsx_comment with uni.JsxComment exit {
    here.gen.es_ast = None;
}

impl EsastGenPass.exit_jsx_normal_attribute with uni.JsxNormalAttribute exit {}

impl EsastGenPass.exit_jsx_spread_attribute with uni.JsxSpreadAttribute exit {
    self.jsx_processor.spread_attribute(here);
}

impl EsastGenPass.exit_jsx_element_name with uni.JsxElementName exit {
    self.jsx_processor.element_name(here);
}

impl EsastGenPass.exit_jsx_element with uni.JsxElement exit {
    if (
        here.name is not None
        and here.name.parts
        and isinstance(here.name.parts[0], uni.Name)
        and here.name.parts[0].value in ("JacAwaiting", "JacClientErrorBoundary")
    ) {
        self._inject_runtime_import(here.name.parts[0].value, here);
    }

    if here.dynamic_tag is not None {
        self._ensure_backend();
        if self.backend.import_source("Dynamic") != self.backend.runtime_module() {
            self._inject_runtime_import("Dynamic", here);
        }
    }
    here.gen.es_ast = self.jsx_processor.element(here);

    self._ensure_backend();
    view = self.jsx_processor._view_by_node.get(id(here));
    if view is not None {
        for sym in self.backend.view_runtime_symbols(view) {
            self._inject_runtime_import(sym, here);
        }
    }
}

impl EsastGenPass.exit_has_var with uni.HasVar exit {
    here.gen.es_ast = None;
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

impl EsastGenPass._register_jac_virtual_import(module_id: str) -> None {
    import from jaclang.compiler.driver.modresolver { resolve_jac_virtual_module_path }
    if not self.client_manifest or module_id in self.client_manifest.imports {
        return;
    }
    source_path = resolve_jac_virtual_module_path(module_id);
    if source_path {
        self.client_manifest.imports[module_id] = source_path;
    }
}

impl EsastGenPass._register_jac_runtime_import -> None {
    self._ensure_backend();
    self._register_jac_virtual_import(self.backend.runtime_module());
}

impl EsastGenPass._inject_runtime_import(name: str, nd: uni.UniNode) -> None {
    import from jaclang.client.client_surface { runtime_import_source }
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
    body_stmts = self._prepend_hoisted(nd, body_stmts);

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

impl EsastGenPass.exit_arch_has with uni.ArchHas exit {
    owner: (uni.UniNode | None) = here.parent;
    while (owner is not None and not isinstance(owner, (uni.Ability, uni.Archetype))) {
        owner = owner.parent;
    }
    if isinstance(owner, uni.Archetype) or not here.in_client_context() {
        here.gen.es_ast = None;
        return;
    }

    statements: list[es.Statement] = [];
    for has_var in here.vars {
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
                self._inject_runtime_import(sym, here);
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

        self._ensure_backend();
        setter_name = self.backend._get_setter_name(var_name);
        state_field = StateField(
            name=var_name,
            init_expr=init_value,
            bind_setter=not self._setter_name_taken(has_var, setter_name)
        );
        for sym in self.backend.state_field_symbols(state_field) {
            self._inject_runtime_import(sym, here);
        }
        for stmt in self.backend.lower_state_field(state_field) {
            statements.append(self.sync_loc(stmt, jac_node=has_var));
        }

        self.reactive_vars.add(var_name);
        self._register_declaration(var_name);
        if state_field.bind_setter and setter_name {
            self._register_declaration(setter_name);
        }
    }
    if len(statements) == 1 {
        here.gen.es_ast = statements[0];
    } elif len(statements) > 1 {
        here.gen.es_ast = statements;
    } else {
        here.gen.es_ast = None;
    }
}

impl EsastGenPass._setter_name_taken(has_var: uni.HasVar, setter_name: str) -> bool {
    if not setter_name {
        return True;
    }
    scope = has_var.sym_tab;
    if scope is None {
        return False;
    }
    existing = scope.names_in_scope.get(setter_name);
    if existing is None {
        return False;
    }

    return existing.decl.parent is not has_var;
}

impl EsastGenPass.exit_param_var with uni.ParamVar exit {
    param_id = self.sync_loc(
        es.Identifier(name=here.name.sym_name), jac_node=here.name
    );
    self._register_declaration(param_id.name);
    if here.is_vararg or here.is_kwargs {
        here.gen.es_ast = self.sync_loc(
            es.RestElement(argument=param_id), jac_node=here
        );
    } elif here.value and here.value.gen.es_ast {
        here.gen.es_ast = self.sync_loc(
            es.AssignmentPattern(
                left=param_id, right=cast(es.Expression, here.value.gen.es_ast)
            ),
            jac_node=here
        );
    } else {
        here.gen.es_ast = param_id;
    }
}

impl EsastGenPass.exit_func_signature with uni.FuncSignature exit {
    here.gen.es_ast = None;
}

impl EsastGenPass.exit_ability with uni.Ability exit {
    if self._view_stack {
        self._view_stack.pop();
    }

    if self.reactive_vars_stack {
        self.reactive_vars = self.reactive_vars_stack.pop();
    }

    if here.is_comptime {
        here.gen.es_ast = None;
        return;
    }

    osp_info = self._osp_ability_info(here);
    if osp_info is not None {
        self._emit_osp_slot_method(here, osp_info);
        return;
    }

    if (isinstance(here.signature, uni.EventSignature) and here.in_client_context()) {
        self._transform_to_useeffect(here);
        return;
    }

    ref_param: (uni.ParamVar | None) = None;
    if (
        here.code_context == CodeContext.CLIENT
        and not here.is_method
        and self._component_call_abi(here) in ('props_destructure', 'props_passthrough')
    ) {
        ref_param = self._ref_forward_param(here);
    }
    if (here.code_context == CodeContext.CLIENT and not here.is_method) {
        self.client_manifest.has_client = True;
        is_pub = here.access and (here.access.tag.name == Tok.KW_PUB);
        route_role: (str | None) = None;
        if (
            isinstance(here.signature, uni.FuncSignature)
            and here.signature.return_type is not None
        ) {
            route_role = self._return_type_route_role(here.signature.return_type);
        }

        if is_pub or route_role or here.codespace_dual {
            name = here.name_ref.sym_name;
            self.client_manifest.exports.append(name);
            if (
                isinstance(here.signature, uni.FuncSignature)
                and here.signature.return_type is not None
                and self._return_type_includes_jsx_element(here.signature.return_type)
            ) {
                self.component_export_names.add(name);
            }

            self.client_manifest.params[name] = [
                p.name.sym_name
                for p in here.signature.params
                if p is not ref_param
            ]
                if isinstance(here.signature, uni.FuncSignature)
                else [];
            if route_role == 'page' and self.client_manifest.page_export is None {
                self.client_manifest.page_export = name;
            } elif route_role == 'layout'
                and self.client_manifest.layout_export is None {
                self.client_manifest.layout_export = name;
            }
        }
    }
    component_call_abi = self._component_call_abi(here);
    params: list[es.Pattern] = [];
    destructure_stmts: list[es.Statement] = [];
    destructure_props: list[es.AssignmentProperty | es.RestElement] = [];

    sig_params = (
        [
            p
            for p in here.signature.params
            if p is not ref_param
        ]
            if isinstance(here.signature, uni.FuncSignature)
            else []
    );
    value_params = (
        [
            p
            for p in here.signature.get_parameters()
            if p is not ref_param
        ]
            if isinstance(here.signature, uni.FuncSignature)
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
                                        jac_node=here,
                                    ),
                                    `init=self.sync_loc(
                                        es.Identifier(name="props"), jac_node=here
                                    ),
                                ),
                                jac_node=here,
                            )
                        ],
                        kind="const",
                    ),
                    jac_node=here,
                )
            ];
        } else {
            if component_call_abi == 'props_passthrough' {
                self.emit(
                    W5015,
                    node_override=value_params[0],
                    component=here.name_ref.sym_name
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
            params.append(self.sync_loc(es.Identifier(name="props"), jac_node=here));
        }
        params.append(
            cast(es.Pattern, ref_param.gen.es_ast)
                if ref_param.gen.es_ast
                else self.sync_loc(
                    es.Identifier(name=ref_param.name.sym_name), jac_node=ref_param.name
                )
        );
    }
    inner = self.unwrap_body(here);
    body_stmts = self._collect_stmt_body(inner);
    body_stmts = self._prepend_hoisted(here, body_stmts);
    block = self.sync_loc(
        es.BlockStatement(body=destructure_stmts + body_stmts), jac_node=here
    );
    func_id = self.sync_loc(
        es.Identifier(name=here.name_ref.sym_name), jac_node=here.name_ref
    );
    is_gen = self._ability_is_generator(here);
    if here.is_method {
        func_expr = self.sync_loc(
            es.FunctionExpression(
                id=None,
                params=params,
                body=block,
                generator=is_gen,
                async_=here.is_async
            ),
            jac_node=here
        );
        method_def = self.sync_loc(
            es.MethodDefinition(
                key=func_id, value=func_expr, kind='method', `static=here.is_static
            ),
            jac_node=here
        );
        here.gen.es_ast = method_def;
    } elif ref_param is not None {
        self._inject_runtime_import('forwardRef', here);
        func_expr = self.sync_loc(
            es.FunctionExpression(
                id=func_id,
                params=params,
                body=block,
                generator=is_gen,
                async_=here.is_async
            ),
            jac_node=here
        );
        forward_call = self.sync_loc(
            es.CallExpression(
                callee=es.Identifier(name='forwardRef'), arguments=[func_expr]
            ),
            jac_node=here
        );
        declarator = self.sync_loc(
            es.VariableDeclarator(
                id=self.sync_loc(
                    es.Identifier(name=here.name_ref.sym_name), jac_node=here.name_ref
                ),
                `init=forward_call,
            ),
            jac_node=here
        );
        here.gen.es_ast = self.sync_loc(
            es.VariableDeclaration(declarations=[declarator], kind='const'),
            jac_node=here
        );
    } else {
        pascal = self._component_pascal_name(here);
        if pascal is not None {
            func_decl = self.sync_loc(
                es.FunctionDeclaration(
                    id=self.sync_loc(
                        es.Identifier(name=pascal), jac_node=here.name_ref
                    ),
                    params=params,
                    body=block,
                    generator=is_gen,
                    async_=here.is_async
                ),
                jac_node=here
            );
            alias_decl = self.sync_loc(
                es.VariableDeclaration(
                    declarations=[
                        self.sync_loc(
                            es.VariableDeclarator(
                                id=self.sync_loc(
                                    es.Identifier(name=here.name_ref.sym_name),
                                    jac_node=here.name_ref
                                ),
                                `init=self.sync_loc(
                                    es.Identifier(name=pascal), jac_node=here.name_ref
                                ),
                            ),
                            jac_node=here
                        )
                    ],
                    kind='const'
                ),
                jac_node=here
            );
            here.gen.es_ast = [func_decl, alias_decl];
        } else {
            func_decl = self.sync_loc(
                es.FunctionDeclaration(
                    id=func_id,
                    params=params,
                    body=block,
                    generator=is_gen,
                    async_=here.is_async
                ),
                jac_node=here
            );
            here.gen.es_ast = func_decl;
        }
    }
}

impl EsastGenPass._osp_model -> OspModel {
    import from jaclang.runtime.osp_model { get_osp_model }
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

impl EsastGenPass._osp_expr_arch_name(expr: (uni.UniNode | None)) -> (str | None) {
    import from jaclang.compiler.types.types { ClassType }
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    _ty = expr.type;
    if isinstance(_ty, ClassType) {
        _nm = _ty.shared.class_name;
        if self._arch_kind_of_type(_ty) is not None
            or self._arch_kind_by_name(_nm) is not None {
            return _nm;
        }
    }
    return None;
}

impl EsastGenPass._arch_kind_of_type(ty: object) -> (str | None) {
    import from jaclang.compiler.types.types { ClassType }
    if not isinstance(ty, ClassType) {
        return None;
    }
    _st = ty.shared.symbol_table;
    if isinstance(_st, uni.Archetype) {
        return {
            "KW_NODE": "node",
            "KW_EDGE": "edge",
            "KW_WALKER": "walker",
            "KW_OBJECT": "object"
        }.get(
            _st.arch_type.name
        );
    }
    return None;
}

impl EsastGenPass._expr_class_type(expr: (uni.UniNode | None)) -> (object | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    _ty = expr.type;
    return _ty;
}

impl EsastGenPass._osp_expr_arch_kind(expr: (uni.UniNode | None)) -> (str | None) {
    _kind = self._arch_kind_of_type(self._expr_class_type(expr));
    if _kind is not None {
        return _kind;
    }
    _nm = self._osp_expr_arch_name(expr);
    if _nm is None {
        return None;
    }
    return self._arch_kind_by_name(_nm);
}

impl EsastGenPass._arch_kind_by_name(name: str) -> (str | None) {
    _local = self._osp_model().arch_kind.get(name);
    if _local is not None {
        return _local;
    }
    _mod = self.ir_in if isinstance(self.ir_in, uni.Module) else self.get_main_mod();
    _sym = _mod.lookup(name);
    if _sym is None {
        return None;
    }
    if _sym.sym_type.value in ("node", "edge", "walker") {
        return _sym.sym_type.value;
    }
    return self._arch_kind_of_type(self._expr_class_type(_sym.decl));
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
    typed = self._osp_expr_arch_name(expr);
    if (typed is not None) and (self._arch_kind_by_name(typed) == "walker") {
        return typed;
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
    if self._osp_expr_arch_kind(expr) in ("node", "edge") {
        return True;
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
        es.CallExpression(
            callee=self.sync_loc(
                es.Identifier(name="__ospC.osp_node_desc"), jac_node=nd
            ),
            arguments=[
                self.sync_loc(
                    es.MemberExpression(
                        object=walker_es,
                        property=self.sync_loc(
                            es.Identifier(name="__tag"), jac_node=nd
                        ),
                        computed=False
                    ),
                    jac_node=nd
                )
            ]
        ),
        jac_node=nd
    );
    starts = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name="__ospLiveStarts"), jac_node=nd),
            arguments=[
                self.sync_loc(es.ArrayExpression(elements=[target_es]), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name="__ospC.osp_spawn"), jac_node=nd),
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

impl EsastGenPass._build_osp_tags_js -> str {
    _model = self._osp_model();
    tags = _model.tags;
    lines: list[str] = [];
    for name in _model.arch_kind.keys() {
        tag = tags.get(name);
        if tag is None {
            continue;
        }
        lines.append(
            f'if (typeof {name} !== "undefined") {name}.prototype.__tag = {tag};'
        );
        isa_members = ", ".join(
            [
                str(tags[a])
                for a in _model.isa.get(name, [])
                if a in tags
            ]
        );
        lines.append(f"__ospC.osp_register_type({tag}, [{isa_members}]);");
    }
    import from jaclang.runtime.osp_model { stable_osp_tag }
    ge_tag = stable_osp_tag("GenericEdge");
    lines.append(f"__ospGenericEdge.prototype.__tag = {ge_tag};");
    lines.append(f"__ospC.osp_register_type({ge_tag}, []);");
    return "\n".join(lines);
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
    for name in arch_kinds.keys() {
        tag = tags.get(name);
        if tag is None {
            continue;
        }
        desc_cls = "__ospC.WalkerDesc"
            if (arch_kinds[name] == "walker")
            else "__ospC.NodeDesc";
        entry_js = self._osp_slots_js(entry_by_owner.get(name, []), tags);
        exit_js = self._osp_slots_js(exit_by_owner.get(name, []), tags);
        lines.append(
            f"__ospC.osp_register_desc({tag}, new {desc_cls}"
                + f"({{type_tag: {tag}, entry: {entry_js}, exit: {exit_js}}}));"
        );
    }
    lines.append(
        "var __ospRT = globalThis.__jacOspRT ??= new __ospC.OspRuntime({"
            + "tag_of: (h) => h.__tag, "
            + "is_a: (t, b) => __ospC.osp_is_a(t, b), "
            + "node_desc: (t) => __ospC.osp_node_desc(t), "
            + "on_complete: (s, ok) => { if (s.wlk && !s.nested) s.wlk.reports = s.reports; }"
            + "});"
    );
    return "\n".join(lines);
}

impl EsastGenPass._osp_slots_js(slots: list, tags: dict) -> str {
    parts: list[str] = [];
    for slot in slots {
        fn = "(o, x) => o." + slot.ability + "(x)";
        if not slot.trigger_names {
            parts.append("new __ospC.Slot({trig_tag: -1, fn: " + fn + "})");
        } else {
            for trig in slot.trigger_names {
                ttag = tags[trig] if (trig in tags) else -1;
                if ttag < 0 {
                    if self._arch_kind_by_name(trig) in ("node", "edge", "walker") {
                        import from jaclang.runtime.osp_model { stable_osp_tag }
                        ttag = stable_osp_tag(trig);
                    }
                }
                parts.append(f"new __ospC.Slot({{trig_tag: {ttag}, fn: {fn}}})");
            }
        }
    }
    return "[" + ", ".join(parts) + "]";
}

impl EsastGenPass.exit_visit_stmt with uni.VisitStmt exit {
    self.needs_osp_kernel = True;
    self.needs_jac_runtime = True;
    target = cast(
        es.Expression,
        self._get_ast_or_default(
            here.target,
            default_factory=lambda (_src: any) { es.ArrayExpression(elements=[]); }
        )
    );

    if not isinstance(here.target, (uni.EdgeRefTrailer, uni.ListVal)) {
        target = self.sync_loc(es.ArrayExpression(elements=[target]), jac_node=here);
    }
    insert: es.Expression = self.sync_loc(
        es.UnaryExpression(operator='-', argument=es.Literal(value=1), prefix=True),
        jac_node=here
    );
    if here.insert_loc and here.insert_loc.gen.es_ast {
        insert = cast(es.Expression, here.insert_loc.gen.es_ast);
    }
    visit_call = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__ospC.osp_visit'), jac_node=here),
            arguments=[target, insert]
        ),
        jac_node=here
    );
    if here.else_body and here.else_body.gen.es_ast {
        here.gen.es_ast = self.sync_loc(
            es.IfStatement(
                `test=self.sync_loc(
                    es.UnaryExpression(operator='!', argument=visit_call, prefix=True),
                    jac_node=here
                ),
                consequent=cast(es.Statement, here.else_body.gen.es_ast),
                alternate=None
            ),
            jac_node=here
        );
        return;
    }
    here.gen.es_ast = self.sync_loc(
        es.ExpressionStatement(expression=visit_call), jac_node=here
    );
}

impl EsastGenPass.exit_disengage_stmt with uni.DisengageStmt exit {
    self.needs_osp_kernel = True;
    here.gen.es_ast = self.sync_loc(
        es.BlockStatement(
            body=[
                self.sync_loc(
                    es.ExpressionStatement(
                        expression=self.sync_loc(
                            es.CallExpression(
                                callee=self.sync_loc(
                                    es.Identifier(name='__ospC.osp_disengage'),
                                    jac_node=here
                                ),
                                arguments=[]
                            ),
                            jac_node=here
                        )
                    ),
                    jac_node=here
                ),
                self.sync_loc(es.ReturnStatement(argument=None), jac_node=here)
            ]
        ),
        jac_node=here
    );
}

impl EsastGenPass.exit_report_stmt with uni.ReportStmt exit {
    self.needs_osp_kernel = True;
    expr = cast(
        es.Expression,
        self._get_ast_or_default(
            here.expr, default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );
    here.gen.es_ast = self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.Identifier(name='__ospC.osp_report'), jac_node=here
                    ),
                    arguments=[expr]
                ),
                jac_node=here
            )
        ),
        jac_node=here
    );
}

impl EsastGenPass.exit_edge_ref_trailer with uni.EdgeRefTrailer exit {
    here.gen.es_ast = self._build_edge_ref(here);
}

impl EsastGenPass._edge_tag_literal(
    nd: uni.UniNode, type_expr: (uni.UniNode | None), hard: bool
) -> int {
    if type_expr is None {
        return -1;
    }
    _etname = OspAnalysis.head_name(type_expr);
    if _etname is None {
        return -1;
    }
    _tag = self._osp_model().tags.get(_etname, -1);
    if _tag < 0 {
        _xkind = self._arch_kind_by_name(_etname);
        if _xkind is None {
            _xkind = self._arch_kind_of_type(self._expr_class_type(type_expr));
        }
        if _xkind in ("node", "edge") {
            import from jaclang.runtime.osp_model { stable_osp_tag }
            _tag = stable_osp_tag(_etname);
        }
    }
    if (_tag < 0) and hard {
        import from jaclang.compiler.frontend.diagnostics { E5097 }
        self.emit(
            E5097,
            node_override=nd,
            kind=f"a graph reference with unresolved archetype '{_etname}'"
        );
    }
    return _tag;
}

impl EsastGenPass._build_edge_ref(nd: uni.EdgeRefTrailer) -> es.Expression {
    import from jaclang.compiler.frontend.diagnostics { E5097 }
    fail = self.sync_loc(es.ArrayExpression(elements=[]), jac_node=nd);
    chain = nd.chain;
    if not chain {
        self.emit(E5097, node_override=nd, kind="an empty edge reference");
        return fail;
    }
    self.needs_osp_graph = True;
    _idx = 0;
    origin: es.Expression;
    if isinstance(chain[0], uni.EdgeOpRef) {
        origin = self.sync_loc(es.Identifier(name='here'), jac_node=nd);
    } else {
        origin = cast(
            es.Expression,
            self._get_ast_or_default(
                chain[0],
                default_factory=lambda (_src: any) { es.ArrayExpression(elements=[]); }
            )
        );
        _idx = 1;
    }
    if (_idx >= len(chain)) or (not isinstance(chain[_idx], uni.EdgeOpRef)) {
        self.emit(E5097, node_override=nd, kind="this edge reference shape");
        return fail;
    }
    cur: (es.Expression | None) = None;
    while (_idx < len(chain)) and isinstance(chain[_idx], uni.EdgeOpRef) {
        step = chain[_idx];
        _idx += 1;
        _step_filter: (uni.FilterCompr | None) = None;
        if (_idx < len(chain)) and isinstance(chain[_idx], uni.FilterCompr) {
            _step_filter = chain[_idx];
            _idx += 1;
        }
        _is_last_hop = (_idx >= len(chain))
            or (not isinstance(chain[_idx], uni.EdgeOpRef));
        _fcond = step.filter_cond;
        _edge_tag = self._edge_tag_literal(
            nd, _fcond.f_type if (_fcond is not None) else None, True
        );
        _edges_only = 1 if (nd.edges_only and _is_last_hop) else 0;
        hop_args: list[es.Expression] = [
            origin if (cur is None) else cur,
            self.sync_loc(es.Literal(value=int(step.edge_dir.value)), jac_node=nd),
            self.sync_loc(es.Literal(value=_edge_tag), jac_node=nd),
            self.sync_loc(es.Literal(value=_edges_only), jac_node=nd)
        ];
        if (_fcond is not None) and _fcond.compares {
            _epred = self._build_osp_filter_pred(nd, _fcond);
            if _epred is None {
                return fail;
            }
            hop_args.append(
                self.sync_loc(
                    es.ArrowFunctionExpression(
                        params=[self.sync_loc(es.Identifier(name='x'), jac_node=nd)],
                        body=_epred,
                        expression=True
                    ),
                    jac_node=nd
                )
            );
        }
        hop_fn = '__ospRefsW' if (cur is None) else '__ospRefsManyW';
        result: es.Expression = self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(es.Identifier(name=hop_fn), jac_node=nd),
                arguments=hop_args
            ),
            jac_node=nd
        );
        if _step_filter is not None {
            pred = self._build_osp_filter_pred(nd, _step_filter);
            if pred is None {
                return fail;
            }
            result = self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.MemberExpression(
                            object=result,
                            property=self.sync_loc(
                                es.Identifier(name='filter'), jac_node=nd
                            ),
                            computed=False
                        ),
                        jac_node=nd
                    ),
                    arguments=[
                        self.sync_loc(
                            es.ArrowFunctionExpression(
                                params=[
                                    self.sync_loc(es.Identifier(name='x'), jac_node=nd)
                                ],
                                body=pred,
                                expression=True
                            ),
                            jac_node=nd
                        )
                    ]
                ),
                jac_node=nd
            );
        }
        cur = result;
    }
    if (cur is None) or (_idx != len(chain)) {
        self.emit(E5097, node_override=nd, kind="this edge reference shape");
        return fail;
    }
    return cur;
}

impl EsastGenPass._build_osp_filter_pred(
    nd: uni.UniNode, filt: uni.FilterCompr
) -> (es.Expression | None) {
    import from jaclang.compiler.frontend.diagnostics { E5097 }
    parts: list[es.Expression] = [];
    if filt.f_type is not None {
        _ntag = self._edge_tag_literal(nd, filt.f_type, True);
        if _ntag < 0 {
            return None;
        }
        parts.append(
            self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.Identifier(name='__ospC.osp_is_a'), jac_node=nd
                    ),
                    arguments=[
                        self.sync_loc(
                            es.LogicalExpression(
                                operator='??',
                                left=self.sync_loc(
                                    es.MemberExpression(
                                        object=self.sync_loc(
                                            es.Identifier(name='x'), jac_node=nd
                                        ),
                                        property=self.sync_loc(
                                            es.Identifier(name='__tag'), jac_node=nd
                                        ),
                                        computed=False
                                    ),
                                    jac_node=nd
                                ),
                                right=self.sync_loc(es.Literal(value=-1), jac_node=nd)
                            ),
                            jac_node=nd
                        ),
                        self.sync_loc(es.Literal(value=_ntag), jac_node=nd)
                    ]
                ),
                jac_node=nd
            )
        );
    }
    for cmp in filt.compares {
        _lhs = cmp.left;
        _js_op: (str | None) = None;
        if isinstance(_lhs, uni.Name)
            and (len(cmp.ops) == 1)
            and (len(cmp.rights) == 1) {
            _op_name = cmp.ops[0].name;
            _op_tok = Tok(_op_name) if (_op_name in Tok.__members__) else None;
            if _op_tok in (Tok.EE, Tok.NE, Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
                _js_op = ES_COMPARISON_OPS.get(_op_tok);
            }
        }
        if (_js_op is None) or (not isinstance(_lhs, uni.Name)) {
            self.emit(
                E5097,
                node_override=nd,
                kind="a graph filter outside 'name <op> value' form"
            );
            return None;
        }
        rhs = cast(
            es.Expression,
            self._get_ast_or_default(
                cmp.rights[0],
                default_factory=lambda (_src: any) { es.Literal(value=None); }
            )
        );
        parts.append(
            self.sync_loc(
                es.BinaryExpression(
                    operator=_js_op,
                    left=self.sync_loc(
                        es.MemberExpression(
                            object=self.sync_loc(es.Identifier(name='x'), jac_node=nd),
                            property=self.sync_loc(
                                es.Identifier(name=_lhs.sym_name), jac_node=nd
                            ),
                            computed=False
                        ),
                        jac_node=nd
                    ),
                    right=rhs
                ),
                jac_node=nd
            )
        );
    }
    if not parts {
        return self.sync_loc(es.Literal(value=True), jac_node=nd);
    }
    pred = parts[0];
    for part in parts[1:] {
        pred = self.sync_loc(
            es.LogicalExpression(operator='&&', left=pred, right=part), jac_node=nd
        );
    }
    return pred;
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
    edge_tag = -1;
    edge_body: es.Expression;
    if co.conn_type is None {
        edge_body = self.sync_loc(
            es.NewExpression(
                callee=self.sync_loc(
                    es.Identifier(name='__ospGenericEdge'), jac_node=nd
                ),
                arguments=[]
            ),
            jac_node=nd
        );
    } else {
        edge_tag = self._edge_tag_literal(nd, co.conn_type, False);
        if isinstance(co.conn_type, uni.Name) {
            edge_body = self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(
                        es.Identifier(name=co.conn_type.sym_name), jac_node=co.conn_type
                    ),
                    arguments=[]
                ),
                jac_node=nd
            );
        } else {
            edge_body = cast(
                es.Expression,
                self._get_ast_or_default(
                    co.conn_type,
                    default_factory=lambda (_src: any) { es.ObjectExpression(
                        properties=[]
                    ); }
                )
            );
        }
    }
    if co.conn_assign is not None {
        props: list = [];
        for kw in co.conn_assign.assigns {
            if kw.key is None {
                continue;
            }
            props.append(
                self.sync_loc(
                    es.Property(
                        key=self.sync_loc(
                            es.Identifier(name=kw.key.sym_name), jac_node=kw
                        ),
                        value=cast(
                            es.Expression,
                            self._get_ast_or_default(
                                kw.value,
                                default_factory=lambda (_src: any) { es.Literal(
                                    value=None
                                ); }
                            )
                        ),
                        kind='init'
                    ),
                    jac_node=kw
                )
            );
        }
        if props {
            edge_body = self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.Identifier(name='Object.assign'), jac_node=nd
                    ),
                    arguments=[
                        edge_body,
                        self.sync_loc(
                            es.ObjectExpression(properties=props), jac_node=nd
                        )
                    ]
                ),
                jac_node=nd
            );
        }
    }
    make_edge = self.sync_loc(
        es.ArrowFunctionExpression(params=[], body=edge_body, expression=True),
        jac_node=nd
    );
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__ospConnW'), jac_node=nd),
            arguments=[
                src,
                tgt,
                make_edge,
                self.sync_loc(es.Literal(value=undirected), jac_node=nd),
                self.sync_loc(es.Literal(value=edge_tag), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._build_osp_disconnect_call(
    nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
) -> es.Expression {
    self.needs_osp_graph = True;
    spec = cast(uni.DisconnectOp, nd.op).edge_spec;
    _fcond = spec.filter_cond;
    _edge_tag = self._edge_tag_literal(
        nd, _fcond.f_type if (_fcond is not None) else None, True
    );
    if (_fcond is not None) and _fcond.compares {
        _pred = self._build_osp_filter_pred(nd, _fcond);
        if _pred is not None {
            _arrow = self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[self.sync_loc(es.Identifier(name='x'), jac_node=nd)],
                    body=_pred,
                    expression=True
                ),
                jac_node=nd
            );
            return self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.Identifier(name='__ospDiscBetweenPredW'), jac_node=nd
                    ),
                    arguments=[
                        left,
                        right,
                        self.sync_loc(
                            es.Literal(value=int(spec.edge_dir.value)), jac_node=nd
                        ),
                        self.sync_loc(es.Literal(value=_edge_tag), jac_node=nd),
                        _arrow
                    ]
                ),
                jac_node=nd
            );
        }
    }
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__ospDiscBetweenW'), jac_node=nd),
            arguments=[
                left,
                right,
                self.sync_loc(es.Literal(value=int(spec.edge_dir.value)), jac_node=nd),
                self.sync_loc(es.Literal(value=_edge_tag), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass.enter_ability with uni.Ability entry {
    if isinstance(here.body, uni.ImplDef) and (here.body not in here.kid) {
        here.add_kids_right([here.body], pos_update=False, parent_update=True);
    }

    self._view_stack.append(None);
    self.reactive_vars_stack.append(self.reactive_vars);
    self.reactive_vars = set(self.reactive_vars);
}

impl EsastGenPass.exit_enum with uni.Enum exit {
    if here.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = here.access and (here.access.tag.name == Tok.KW_PUB);
        if is_pub or here.codespace_dual {
            self.client_manifest.exports.append(here.name.sym_name);
        }
    }
    properties: list[(es.Property | es.SpreadElement)] = [];
    inner = self.unwrap_body(here);
    next_auto = 1;
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
                            if (
                                isinstance(enum_value, es.Literal)
                                and isinstance(enum_value.value, int)
                                and not isinstance(enum_value.value, bool)
                            ) {
                                next_auto = enum_value.value + 1;
                            }
                        } else {
                            enum_value = self.sync_loc(
                                es.Literal(value=next_auto), jac_node=stmt
                            );
                            next_auto += 1;
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
    obj_expr = self.sync_loc(es.ObjectExpression(properties=properties), jac_node=here);
    var_id = self.sync_loc(es.Identifier(name=here.name.sym_name), jac_node=here.name);
    var_decl = self.sync_loc(
        es.VariableDeclaration(
            declarations=[
                self.sync_loc(
                    es.VariableDeclarator(id=var_id, `init=obj_expr), jac_node=here
                )
            ],
            kind='const'
        ),
        jac_node=here
    );
    here.gen.es_ast = var_decl;
}

impl EsastGenPass.exit_type_alias with uni.TypeAlias exit {
    here.gen.es_ast = [];
}

impl EsastGenPass.exit_type_param with uni.TypeParam exit {
    here.gen.es_ast = [];
}

impl EsastGenPass.exit_archetype with uni.Archetype exit {
    if here.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = here.access and (here.access.tag.name == Tok.KW_PUB);
        if is_pub or here.codespace_dual {
            self.client_manifest.exports.append(here.name.sym_name);
        }
    }
    body_stmts: list[es.MethodDefinition | es.PropertyDefinition] = [];
    has_members: list[uni.ArchHas] = [];
    inner = self.unwrap_body(here);
    if inner {
        for stmt in inner {
            if isinstance(stmt, uni.ArchHas) {
                has_members.append(stmt);
                continue;
            }
            if isinstance(stmt, uni.GlobalVars) and stmt.is_frozen {
                for asn in stmt.assignments {
                    tgt = asn.target[0] if asn.target else None;
                    folded = (
                        self._ct_es_expr(asn.value.ct_value, asn.value)
                            if asn.value is not None
                            else None
                    );
                    if isinstance(tgt, uni.Name) and folded is not None {
                        body_stmts.append(
                            self.sync_loc(
                                es.PropertyDefinition(
                                    key=es.Identifier(name=tgt.sym_name),
                                    value=folded,
                                    `static=True
                                ),
                                jac_node=asn
                            )
                        );
                    } elif (
                        isinstance(tgt, uni.Name)
                        and asn.value is not None
                        and isinstance(asn.value.gen.es_ast, es.Expression)
                    ) {
                        body_stmts.append(
                            self.sync_loc(
                                es.MethodDefinition(
                                    key=es.Identifier(name=tgt.sym_name),
                                    kind='get',
                                    value=self.sync_loc(
                                        es.FunctionExpression(
                                            params=[],
                                            body=self.sync_loc(
                                                es.BlockStatement(
                                                    body=[
                                                        self.sync_loc(
                                                            es.ReturnStatement(
                                                                argument=cast(
                                                                    es.Expression,
                                                                    asn.value.gen.es_ast
                                                                )
                                                            ),
                                                            jac_node=asn
                                                        )
                                                    ]
                                                ),
                                                jac_node=asn
                                            )
                                        ),
                                        jac_node=asn
                                    )
                                ),
                                jac_node=asn
                            )
                        );
                    }
                }
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
        (here.name is not None)
        and (here.name.sym_name in self._osp_arch_set())
        and (here.arch_kind is not None)
    );
    is_shared_boundary_arch = (
        (here.name is not None) and (here.name.sym_name in self.shared_arch_names)
    );
    has_postinit = False;
    for _stmt in (self.unwrap_body(here) or []) {
        if (
            isinstance(_stmt, uni.Ability)
            and getattr(_stmt, 'sym_name', '') == '__post_init__'
        ) {
            has_postinit = True;
        }
    }
    if (
        (
            (here.arch_type.name == Tok.KW_OBJECT)
            or is_local_osp_arch
            or is_shared_boundary_arch
        )
        and (has_members or has_postinit)
    ) {
        constructor_stmts: list[es.Statement] = [];
        props_param = self.sync_loc(
            es.AssignmentPattern(
                left=self.sync_loc(es.Identifier(name='props'), jac_node=here),
                right=self.sync_loc(es.ObjectExpression(properties=[]), jac_node=here)
            ),
            jac_node=here
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
        for tp in (here.type_params or []) {
            if not tp.is_comptime {
                continue;
            }
            constructor_stmts.append(
                self.sync_loc(
                    es.ExpressionStatement(
                        expression=self.sync_loc(
                            es.AssignmentExpression(
                                operator='=',
                                left=self.sync_loc(
                                    es.MemberExpression(
                                        object=self.sync_loc(
                                            es.ThisExpression(), jac_node=tp
                                        ),
                                        property=es.Identifier(name=tp.name.value),
                                        computed=False
                                    ),
                                    jac_node=tp
                                ),
                                right=self.sync_loc(
                                    es.MemberExpression(
                                        object=self.sync_loc(
                                            es.Identifier(name='props'), jac_node=tp
                                        ),
                                        property=es.Identifier(name=tp.name.value),
                                        computed=False
                                    ),
                                    jac_node=tp
                                )
                            ),
                            jac_node=tp
                        )
                    ),
                    jac_node=tp
                )
            );
        }
        if has_postinit {
            constructor_stmts.append(
                self.sync_loc(
                    es.ExpressionStatement(
                        expression=self.sync_loc(
                            es.CallExpression(
                                callee=self.sync_loc(
                                    es.MemberExpression(
                                        object=self.sync_loc(
                                            es.ThisExpression(), jac_node=here
                                        ),
                                        property=self.sync_loc(
                                            es.Identifier(name='__post_init__'),
                                            jac_node=here
                                        ),
                                        computed=False
                                    ),
                                    jac_node=here
                                ),
                                arguments=[]
                            ),
                            jac_node=here
                        )
                    ),
                    jac_node=here
                )
            );
        }
        if constructor_stmts {
            if here.base_classes {
                constructor_stmts.insert(
                    0,
                    self.sync_loc(
                        es.ExpressionStatement(
                            expression=self.sync_loc(
                                es.CallExpression(
                                    callee=es.Identifier(name='super'),
                                    arguments=[es.Identifier(name='props')]
                                ),
                                jac_node=here
                            )
                        ),
                        jac_node=here
                    )
                );
            }
            constructor_method = self.sync_loc(
                es.MethodDefinition(
                    key=self.sync_loc(es.Identifier(name='constructor'), jac_node=here),
                    value=self.sync_loc(
                        es.FunctionExpression(
                            id=None,
                            params=[props_param],
                            body=self.sync_loc(
                                es.BlockStatement(body=constructor_stmts), jac_node=here
                            )
                        ),
                        jac_node=here
                    ),
                    kind='constructor',
                    `static=False
                ),
                jac_node=here
            );
            body_stmts.insert(0, constructor_method);
        }
    }
    class_body = self.sync_loc(es.ClassBody(body=body_stmts), jac_node=here);
    super_class: (es.Expression | None) = None;
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if here.base_classes {
        base = here.base_classes[0];
        if base.gen.es_ast {
            super_class = cast(es.Expression, base.gen.es_ast);
            (base_ty_known, base_builtin) = _raised_exc_identity(base);
            if isinstance(super_class, es.Identifier) {
                if base_builtin is not None {
                    super_class = self._jac_exc_ref(base_builtin, base);
                } elif (
                    not base_ty_known
                    and JAC_TYPE_REGISTRY.is_exception(super_class.name)
                ) {
                    super_class = self._jac_exc_ref(super_class.name, base);
                }
            }
        }
    }
    class_id = self.sync_loc(
        es.Identifier(name=here.name.sym_name), jac_node=here.name
    );
    class_decl = self.sync_loc(
        es.ClassDeclaration(id=class_id, superClass=super_class, body=class_body),
        jac_node=here
    );
    here.gen.es_ast = class_decl;
}

impl EsastGenPass.exit_import with uni.Import exit {
    if here.is_typed or here.is_comptime {
        here.gen.es_ast = None;
        return;
    }

    if self._is_service_bridge_import(here) {
        if (here.from_loc and here.items) {
            self._generate_sv_import_stubs(here);
            self._record_sv_backend(here);
        }
        return;
    }

    if self._is_client_native_import(here) {
        if (here.from_loc and here.items) {
            self._generate_na_import_binding(here);
        }
        here.gen.es_ast = None;
        return;
    }
    emit_items: list = list(here.items);
    if (here.from_loc and here.items) {
        resolved_path = here.from_loc.resolve_relative_path();
        partition = self._partition_client_import_items(here);
        if partition is not None {
            (emit_items, bridged_items) = partition;
            if bridged_items {
                self._generate_sv_import_stubs(here, bridged_items);
                self._record_sv_backend(here);
            }
            if not emit_items {
                here.gen.es_ast = None;
                return;
            }
        }
        import_key = here.from_loc.dot_path_str;
        self.client_manifest.imports[import_key] = resolved_path;
        self.client_manifest.has_client = True;

        import_path = here.from_loc.dot_path_str;
        is_jac_runtime = here.is_virtual_jac;
        if resolved_path.endswith('.jac')
            and not import_path.startswith('.')
            and not is_jac_runtime {
            js_import_path = relative_js_specifier(
                resolved_path, self.ir_in.loc.mod_path or here.loc.mod_path
            );
        } else {
            js_import_path = convert_to_js_import_path(import_path);
        }
    } elif (not here.from_loc and here.items) {
        self.client_manifest.has_client = True;
        first_item = here.items[0];
        if (isinstance(first_item, uni.ModulePath) and first_item.path) {
            path_elem = first_item.path[0];
            import_key = path_elem.lit_value
                if isinstance(path_elem, uni.String)
                else path_elem.value;
        } else {
            import_key = '';
        }
        resolved_path = resolve_relative_path(
            import_key,
            here.loc.mod_path,
            string_spec=isinstance(first_item, uni.ModulePath)
                and first_item.string_path_value is not None
        );
        self.client_manifest.imports[import_key] = resolved_path;
        import_path = import_key;
        if resolved_path.endswith('.jac') and not import_path.startswith('.') {
            js_import_path = relative_js_specifier(
                resolved_path, self.ir_in.loc.mod_path or here.loc.mod_path
            );
        } else {
            js_import_path = convert_to_js_import_path(import_path);
        }
    } else {
        return;
    }
    source = self.sync_loc(es.Literal(value=js_import_path), jac_node=here.from_loc);
    specifiers:
        list[
            es.ImportSpecifier | es.ImportDefaultSpecifier | es.ImportNamespaceSpecifier
        ] = [];
    for item in emit_items {
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
        es.ImportDeclaration(specifiers=specifiers, source=source), jac_node=here
    );
    self.imports.append(import_decl);
    here.gen.es_ast = None;
}


impl EsastGenPass._partition_client_import_items(
    nd: uni.Import
) -> (tuple[list, list] | None) {
    import from jaclang.compiler.symbol_utils {
        ClientImportVerdict,
        classify_client_import_item,
        decl_has_access,
        import_target_pinned_server,
        is_client_boundary_import,
        report_dead_client_import
    }
    if not is_client_boundary_import(nd) {
        return None;
    }
    import from jaclang.compiler.driver.boundary_classify { import_crosses_apps }
    pinned_server = import_target_pinned_server(nd);
    cross_app = import_crosses_apps(nd);
    source_mod = self._resolve_source_module(nd);
    if source_mod is None {
        return ([], list(nd.items)) if pinned_server else None;
    }
    kept: list = [];
    bridged: list = [];
    for item in nd.items {
        verdict = classify_client_import_item(source_mod, item);
        if pinned_server and verdict != ClientImportVerdict.DEAD {
            bridged.append(item);
            continue;
        }
        if pinned_server
            and verdict == ClientImportVerdict.DEAD
            and decl_has_access(source_mod, item) {
            bridged.append(item);
            continue;
        }
        if verdict == ClientImportVerdict.BRIDGED {
            bridged.append(item);
        } elif verdict == ClientImportVerdict.DEAD {
            if not cross_app {
                report_dead_client_import(self, nd, item);
            }
        } else {
            kept.append(item);
        }
    }
    return (kept, bridged);
}

impl EsastGenPass._generate_sv_import_stubs(
    nd: uni.Import, items: (Sequence[uni.ModuleItem] | None) = None
) -> None {
    manifest = self.ir_in.gen.interop_manifest;
    boundary_types = manifest.boundary_types;
    stubs: list[es.Statement] = [];
    for item in (items if items is not None else nd.items) {
        if not isinstance(item, uni.ModuleItem)
            or not isinstance(item.name, uni.Name) {
            continue;
        }

        if self._sv_import_item_is_type(nd, item) {
            continue;
        }
        func_name = item.name.sym_name;
        local_name = item.alias.sym_name if item.alias else func_name;

        binding = manifest.bindings.get(local_name);
        if binding is not None and binding.kind != 'function' {
            continue;
        }
        param_names: list[str] = [];
        param_type_map: dict[str, str] = {};
        ret_type_name: str = '';
        if binding is not None {
            param_names = list(binding.param_names);
            for i in range(len(param_names)) {
                if i < len(binding.param_types) {
                    param_type_map[param_names[i]] = binding.param_types[i];
                }
            }
            ret_type_name = binding.ret_type;
            _src_mod = binding.ast_node.find_parent_of_type(uni.Module)
                if binding.ast_node is not None
                else None;
            if _src_mod is not None {
                src_effect = _src_mod.gen.interop_manifest.endpoint_effects.get(
                    f"func:{func_name}"
                );
                if src_effect is not None {
                    self.client_manifest.endpoint_effects[f"func:{func_name}"] = (
                        src_effect
                    );
                }
            }
        }

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

        call_args: list[es.Expression] = [
            self.sync_loc(es.Literal(value=func_name), jac_node=nd),
            args_obj
        ];
        provider_opts = self._sv_provider_options(nd);
        if provider_opts is not None {
            call_args.append(provider_opts);
        }
        call_expr = self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(
                    es.Identifier(name='__jacCallFunction'), jac_node=nd
                ),
                arguments=call_args
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

impl EsastGenPass._is_client_native_import(nd: uni.Import) -> bool {
    import from jaclang.compiler.driver.boundary_classify { import_binds_client_native }
    return import_binds_client_native(nd, self.ir_in.gen.interop_manifest);
}

impl EsastGenPass._generate_na_import_binding(nd: uni.Import) -> None {
    import from jaclang.compiler.frontend.codeinfo { native_wasm_stem }
    resolved_path = nd.from_loc.resolve_relative_path();
    stem = native_wasm_stem(resolved_path);

    if self.client_manifest {
        self.client_manifest.has_client = True;
    }

    bind_local = '__jac_na_bind';
    if bind_local not in self.injected_imports {
        host_module = '@jac/wasm_host';
        specifier = self.sync_loc(
            es.ImportSpecifier(
                imported=es.Identifier(name='__na_bind'),
                local=es.Identifier(name=bind_local)
            ),
            jac_node=nd
        );
        source = self.sync_loc(
            es.Literal(value=host_module, raw=f'"{host_module}"'), jac_node=nd
        );
        self.imports.append(
            self.sync_loc(
                es.ImportDeclaration(specifiers=[specifier], source=source), jac_node=nd
            )
        );
        self.injected_imports.add(bind_local);
        self._register_jac_virtual_import(host_module);
    }

    props: list[(es.AssignmentProperty | es.RestElement)] = [];
    export_names: list[(es.Expression | es.SpreadElement | None)] = [];
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem)
            or not isinstance(item.name, uni.Name) {
            continue;
        }
        export_name = item.name.sym_name;
        local_name = item.alias.sym_name if item.alias else export_name;
        export_names.append(
            self.sync_loc(
                es.Literal(value=export_name, raw=f'"{export_name}"'), jac_node=item
            )
        );
        props.append(
            self.sync_loc(
                es.AssignmentProperty(
                    key=es.Identifier(name=export_name),
                    value=es.Identifier(name=local_name),
                    shorthand=(export_name == local_name)
                ),
                jac_node=item
            )
        );
    }
    if not props {
        return;
    }

    bind_call = self.sync_loc(
        es.CallExpression(
            callee=es.Identifier(name=bind_local),
            arguments=[
                self.sync_loc(es.Literal(value=stem, raw=f'"{stem}"'), jac_node=nd),
                self.sync_loc(es.ArrayExpression(elements=export_names), jac_node=nd),

            ]
        ),
        jac_node=nd
    );
    self.na_import_stubs.append(
        self.sync_loc(
            es.VariableDeclaration(
                kind='const',
                declarations=[
                    self.sync_loc(
                        es.VariableDeclarator(
                            id=self.sync_loc(
                                es.ObjectPattern(properties=props), jac_node=nd
                            ),
                            init=bind_call
                        ),
                        jac_node=nd
                    )
                ]
            ),
            jac_node=nd
        )
    );
}

impl EsastGenPass._sv_import_item_is_type(
    nd: uni.Import, item: uni.ModuleItem
) -> bool {
    sym = item.name.sym;
    if sym and sym.binding_kind.denotes_type() {
        return True;
    }
    return item.name.sym_name in self.ir_in.gen.interop_manifest.boundary_types;
}

impl EsastGenPass.exit_sub_tag with uni.SubTag exit {
    if here.tag.gen.es_ast {
        here.gen.es_ast = here.tag.gen.es_ast;
    }
}

impl EsastGenPass.populate_client_manifest(nd: uni.Module) -> None {
    for (ename, eeffect) in nd.gen.interop_manifest.endpoint_effects.items() {
        self.client_manifest.endpoint_effects[ename] = eeffect;
    }
}

impl EsastGenPass._es_json_literal(value: any) -> any {
    if isinstance(value, list) {
        return es.ArrayExpression(elements=[self._es_json_literal(v) for v in value]);
    }
    if isinstance(value, dict) {
        return es.ObjectExpression(
            properties=[
                es.Property(
                    key=es.Literal(value=k), value=self._es_json_literal(v), kind='init'
                ) for (k, v) in value.items()
            ]
        );
    }
    return es.Literal(value=value);
}

impl EsastGenPass._emit_boundary_type_stubs(nd: uni.Module) -> list[es.Statement] {
    manifest = nd.gen.interop_manifest;
    if not manifest.boundary_types {
        return [];
    }
    stubs: list[es.Statement] = [];

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
                fallback = self._es_json_literal(info.field_defaults[fname])
                    if fname in info.field_defaults
                    else es.Literal(value=None);
                assign = es.ExpressionStatement(
                    expression=es.AssignmentExpression(
                        operator='=',
                        left=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name=fname),
                            computed=False
                        ),
                        right=es.ConditionalExpression(
                            `test=es.CallExpression(
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
                            alternate=fallback
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
                            `test=es.CallExpression(
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
                `static=False,
                computed=False
            );
            from_wire_stmts: list[es.Statement] = [];
            from_wire_stmts.append(
                es.IfStatement(
                    `test=es.LogicalExpression(
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
            nested_set = {
                t
                for t in info.nested_types
                if t in manifest.boundary_types
                    and manifest.boundary_types[t].kind != "enum"
            };
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
                                `test=es.MemberExpression(
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
                                `test=es.MemberExpression(
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
                                `test=es.MemberExpression(
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
                `static=True,
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
                        `test=es.MemberExpression(
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
                            `test=es.MemberExpression(
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
                                `test=es.MemberExpression(
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
                `static=False,
                computed=False
            );
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
                                    `test=es.CallExpression(
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
                                                property=es.Identifier(name='_jac_id'),
                                                computed=False
                                            ),
                                            right=es.MemberExpression(
                                                object=es.Identifier(name='props'),
                                                property=es.Identifier(name='_jac_id'),
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

impl EsastGenPass.exit_module with uni.Module exit {
    import from jaclang.compiler.symbol_utils { report_client_bare_import_uses }
    report_client_bare_import_uses(self, here);
    server_forwarders = self._bind_client_value_refs(here);
    if (self.scoped_styles is not None and self.scoped_styles.class_map) {
        import os;
        here.gen.css = self.scoped_styles.scoped_css;
        base = os.path.basename(self.scoped_styles.css_path);
        if base.endswith('.style.css') {
            base = base[:-len('.style.css')];
        }
        css_import = f"./{base}.css";
        css_source = self.sync_loc(
            es.Literal(value=css_import, raw=f'"{css_import}"'), jac_node=here
        );
        self.imports.insert(
            0,
            self.sync_loc(
                es.ImportDeclaration(specifiers=[], source=css_source), jac_node=here
            )
        );
    }
    body: list[(es.Statement | es.ModuleDeclaration)] = [];
    body.extend(self.imports);

    body.extend(self.sv_import_stubs);
    body.extend(self.na_import_stubs);

    body.extend(self._emit_boundary_type_stubs(here));
    body.extend(server_forwarders);
    scope = self.scope_map.get(here);
    if (scope and scope.hoisted) {
        hoisted = list(scope.hoisted);
        scope.hoisted.clear();
        body.extend(hoisted);
    }

    if self.needs_osp_graph or self.needs_osp_kernel {
        self.needs_jac_runtime = True;
    }
    if self.needs_jac_runtime {
        import from jaclang.compiler.backends.es.jac_runtime_js { build_jac_runtime_js }
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
    merged_body = self._merge_module_bodies(here);
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
            } else {}
        }
    }
    target_body = client_items or fallback_items;
    body.extend(self._flatten_ast_list(target_body));

    if self.needs_osp_graph or self.needs_osp_kernel {
        import from jaclang.compiler.backends.es.jac_runtime_js {
            build_osp_core_js,
            build_osp_driver_js
        }
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=build_osp_core_js())
                ),
                jac_node=here
            )
        );
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=build_osp_driver_js())
                ),
                jac_node=here
            )
        );
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=self._build_osp_tags_js())
                ),
                jac_node=here
            )
        );
    }
    if self.needs_osp_kernel {
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=self._build_osp_setup_js())
                ),
                jac_node=here
            )
        );
    }
    body.extend(self.exports);
    self.populate_client_manifest(here);
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
                    jac_node=here
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
    program = self.sync_loc(es.Program(body=body), jac_node=here);
    here.gen.es_ast = program;
    here.gen.js = es_to_js(here.gen.es_ast);
    here.gen.client_manifest = self.client_manifest;
    self._audit_free_identifiers(here, program);
}

impl EsastGenPass._audit_free_identifiers(nd: uni.Module, program: es.Program) -> None {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    allowed = client_ambient_globals() | RUNTIME_PRELUDE_GLOBALS;
    frees = free_identifiers(program, allowed);
    if not frees {
        return;
    }
    names = nd.get_all_sub_nodes(typ=uni.Name);
    reported: set[str] = set();
    for free in frees {
        if free.name in reported or not JAC_TYPE_REGISTRY.is_builtin(free.name) {
            continue;
        }
        reported.add(free.name);
        self.emit(
            E5103,
            node_override=self._free_ident_site(names, free) or nd,
            name=free.name
        );
    }
    if not self.client_manifest.has_client {
        return;
    }
    for free in frees {
        if (free.name in reported) or (free.name in self._unbound_reported) {
            continue;
        }
        origin: (uni.Name | None) = None;
        imported = False;
        for cand in names {
            if (cand.value != free.name) or (cand.sym is None) {
                continue;
            }
            if cand.sym.decl.find_parent_of_type(uni.Import) is not None {
                imported = True;
                break;
            }
            origin = cand;
            if cand.loc.first_line == free.line {
                break;
            }
        }
        if imported or (origin is None) {
            continue;
        }
        reported.add(free.name);
        self.emit(E5101, node_override=origin, name=free.name);
    }
}

impl EsastGenPass._free_ident_site(
    names: list[uni.Name], free: FreeIdentifier
) -> (uni.Name | None) {
    fallback: (uni.Name | None) = None;
    for cand in names {
        if cand.value != free.name {
            continue;
        }
        if cand.loc.first_line == free.line {
            return cand;
        }
        if fallback is None {
            fallback = cand;
        }
    }
    return fallback;
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
    if (
        isinstance(nd, uni.Expr)
        and (nd.gen.es_ast is None)
        and (nd not in self._unlowered_reported)
        and self._is_client_destined(nd)
    ) {
        import from jaclang.compiler.frontend.diagnostics { E5097 }
        self._unlowered_reported.add(nd);
        self.emit(E5097, node_override=nd, kind=nd.__class__.__name__);
    }
    fallback = default_factory(nd);
    jac_ref = nd if (nd is not None) else self.cur_node;
    return self.sync_loc(fallback, jac_node=jac_ref);
}

impl EsastGenPass._is_client_destined(nd: uni.UniNode) -> bool {
    return uni.is_client_destined(nd);
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
        } elif (
            generated is None
            and isinstance(stmt, uni.CodeBlockStmt)
            and not isinstance(stmt, uni.Import)
            and not getattr(stmt, "is_comptime", False)
        ) {
            cls_name = stmt.__class__.__name__;
            self.emit(
                E5017,
                node_override=stmt,
                construct=ES_STMT_DISPLAY.get(cls_name, cls_name)
            );
        }
    }
    return statements;
}

impl EsastGenPass._import_item_named(name: str) -> (uni.ModuleItem | None) {
    for imp in self.ir_in.get_all_sub_nodes(uni.Import) {
        if imp.from_loc is None {
            continue;
        }
        for item in imp.items {
            if not isinstance(item, uni.ModuleItem) {
                continue;
            }
            local = item.alias.value if item.alias is not None else item.name.value;
            if local == name {
                return item;
            }
        }
    }
    return None;
}

impl EsastGenPass._build_spawn_runtime_call(
    nd: uni.BinaryExpr, parts: SpawnCallParts
) -> es.AwaitExpression {
    walker_literal = self.sync_loc(
        es.Literal(value=parts.`walker.walker_name), jac_node=parts.`walker.call_node
    );
    spawn_args: list[es.Expression | es.SpreadElement] = [
        walker_literal,
        parts.target.expression,
        parts.`walker.fields_object
    ];
    call_target = parts.`walker.call_node.target;
    walker_sym = call_target.sym if isinstance(call_target, uni.AtomExpr) else None;
    item: (uni.ModuleItem | None) = None;
    if walker_sym is not None and walker_sym.defn {
        candidate = walker_sym.defn[0].parent;
        if isinstance(candidate, uni.ModuleItem) {
            item = candidate;
        }
    }
    if item is None {
        item = self._import_item_named(parts.`walker.walker_name);
    }
    if item is not None {
        provider_opts = self._sv_provider_options(item.from_parent);
        if provider_opts is not None {
            spawn_args.append(provider_opts);
        }
    }
    spawn_call = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__jacSpawn'), jac_node=nd),
            arguments=spawn_args
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

impl EsastGenPass._declaring_scope_for(name_node: uni.UniNode) -> (ScopeInfo | None) {
    if not isinstance(name_node, uni.AstSymbolNode) {
        return None;
    }
    sym = name_node.sym;
    if (sym is None) or (sym.parent_tab is None) {
        return None;
    }
    owner = sym.parent_tab;
    if not isinstance(
        owner, (uni.Module, uni.Ability, uni.ImplDef, uni.Test, uni.LambdaExpr)
    ) {
        return None;
    }
    if isinstance(owner, uni.ImplDef) {
        if not isinstance(owner.decl_link, uni.Ability) {
            return None;
        }
        owner = owner.decl_link;
    }
    for scope in reversed(self.scope_stack) {
        if scope.nd is owner {
            return scope;
        }
    }
    return None;
}

impl EsastGenPass._hoist_into(
    scope: ScopeInfo, name: str, jac_node: uni.UniNode
) -> None {
    if name in scope.declared {
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

impl EsastGenPass._ensure_identifier_declared(
    name: str, jac_node: uni.UniNode
) -> None {
    if self._is_declared_in_any_scope(name) {
        return;
    }
    scope = self._declaring_scope_for(jac_node) or self._current_scope();
    if not scope {
        return;
    }
    self._hoist_into(scope, name, jac_node);
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
        info = self.scope_stack.pop();
        if info.hoisted {
            names: list[str] = [];
            for decl in info.hoisted {
                if not isinstance(decl, es.VariableDeclaration) {
                    continue;
                }
                for declarator in decl.declarations {
                    ident = declarator.id;
                    if isinstance(ident, es.Identifier) {
                        names.append(f"'{ident.name}'");
                    }
                }
            }
            self.emit(
                E5085,
                node_override=nd,
                names=", ".join(names) or "<unknown>",
                scope=type(nd).__name__
            );
        }
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

impl EsastGenPass.exit_walk with uni.UniNode exit {
    if here.ct_pruned {
        osp_skip_rest();
        return;
    }
    self.cur_node = here;
    if self.is_canceled() {
        osp_skip_rest();
        return;
    }
    if (
        isinstance(here, uni.ElementStmt)
        and isinstance(here, uni.ContextAwareNode)
        and here.code_context != CodeContext.CLIENT
        and ((here.parent is None) or isinstance(here.parent, uni.Module))
    ) {
        is_sv_import = isinstance(here, uni.Import)
            and self._is_service_bridge_import(here);

        is_native_edge = isinstance(here, uni.Import)
            and self._is_client_native_import(here);
        is_shared_arch = (
            isinstance(here, uni.Archetype)
            and (here.name is not None)
            and (here.name.value in self.shared_arch_names)
        );
        if (not is_sv_import and not is_native_edge and not is_shared_arch) {
            osp_skip_rest();
            return;
        }
    }
}

impl EsastGenPass.finish_expr with uni.Expr exit {
    if here.coerce_to is not None {
        self._apply_fw_coercion(here);
    }
}

impl EsastGenPass.finish_scope with uni.UniScopeNode exit {
    self._pop_scope(here);
    self.scope_map.pop(here, None);
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

impl EsastGenPass.enter_walk with uni.UniNode entry {
    if self.is_canceled() or here.ct_pruned {
        osp_skip_rest();
        return;
    }
    self.cur_node = here;
    if (
        isinstance(here, uni.ElementStmt)
        and isinstance(here, uni.ContextAwareNode)
        and here.code_context != CodeContext.CLIENT
        and ((here.parent is None) or isinstance(here.parent, uni.Module))
    ) {
        is_sv_import = isinstance(here, uni.Import)
            and self._is_service_bridge_import(here);

        is_shared_arch = (
            isinstance(here, uni.Archetype)
            and (here.name is not None)
            and (here.name.value in self.shared_arch_names)
        );
        is_native_edge = isinstance(here, uni.Import)
            and self._is_client_native_import(here);
        if (not is_sv_import and not is_native_edge and not is_shared_arch) {
            osp_skip_rest();
            return;
        }
    }
    if isinstance(here, uni.UniScopeNode) {
        scope_to_finalize = self._alt_branch_scope_to_finalize(here);
        if scope_to_finalize is not None {
            self._pop_scope(scope_to_finalize);
        }
        self._push_scope(here);
    }
    if here.gen.es_ast {
        if not (
            isinstance(here, uni.Import) and here.code_context != CodeContext.CLIENT
        ) {
            osp_skip_rest();
            return;
        }
    }
}

impl EsastGenPass.before_pass -> None {
    import from jaclang.compiler.frontend.codeinfo { ClientManifest }

    import from jaclang.compiler.backends.py.module_codegen_pass {
        client_capability_violations
    }
    import from jaclang.compiler.frontend.diagnostics { E5096 }
    if not self.ir_in.client_viols_reported {
        for (_vnode, _vkind) in client_capability_violations(self.ir_in) {
            self.emit(E5096, node_override=_vnode, kind=_vkind);
        }
        self.ir_in.client_viols_reported = True;
    }
    self.child_passes = self._init_child_passes(EsastGenPass);
    self.client_manifest = ClientManifest();
    self.component_export_names = set();

    self.client_manifest.endpoint_effects = dict(
        self.ir_in.gen.interop_manifest.endpoint_effects
    );

    import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
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

impl EsastGenPass._ct_es_expr(
    cv: any, jac_node: uni.UniNode
) -> (es.Expression | None) {
    if cv is None or getattr(cv, "is_deferred", False) {
        return None;
    }
    built = self._ct_es_value(cv.v);
    if built is None {
        return None;
    }
    return self.sync_loc(built, jac_node=jac_node);
}

impl EsastGenPass._ct_es_value(v: any) -> (es.Expression | None) {
    if v is None or isinstance(v, (bool, int, float, str)) {
        return es.Literal(value=v);
    }
    if isinstance(v, (list, tuple, set, frozenset)) {
        elements: list[(es.Expression | es.SpreadElement | None)] = [];
        for item in v {
            built = self._ct_es_value(item);
            if built is None {
                return None;
            }
            elements.append(built);
        }
        return es.ArrayExpression(elements=elements);
    }
    if isinstance(v, dict) {
        props: list[(es.Property | es.SpreadElement)] = [];
        for (k, item) in v.items() {
            if not isinstance(k, str) {
                return None;
            }
            built = self._ct_es_value(item);
            if built is None {
                return None;
            }
            props.append(es.Property(key=es.Literal(value=k), value=built));
        }
        return es.ObjectExpression(properties=props);
    }
    return None;
}

impl EsastGenPass._comptime_only_names -> set[str] {
    cached = self._ct_only_names;
    if cached is not None {
        return cached;
    }
    names: set[str] = set();
    for imp in self.ir_in.get_all_sub_nodes(uni.Import) {
        if not imp.is_comptime {
            continue;
        }
        for item in imp.items {
            bound: (uni.Name | None) = item.alias;
            if (
                bound is None
                and isinstance(item, uni.ModuleItem)
                and isinstance(item.name, uni.Name)
            ) {
                bound = item.name;
            }
            if bound is None and isinstance(item, uni.ModulePath) and item.path {
                last = item.path[-1];
                bound = last if isinstance(last, uni.Name) else None;
            }
            if bound is not None {
                names.add(bound.sym_name);
            }
        }
    }
    for ab in self.ir_in.get_all_sub_nodes(uni.Ability) {
        if ab.is_comptime and ab.name_ref is not None {
            names.add(ab.name_ref.sym_name);
        }
    }
    self._ct_only_names = names;
    return names;
}

impl EsastGenPass._ct_only_name(nd: uni.Name) -> bool {
    if nd.sym_name in self._comptime_only_names() {
        return True;
    }
    sym = nd.sym;
    if sym is None {
        return False;
    }
    decl = sym.decl;
    imp = decl.find_parent_of_type(uni.Import) if isinstance(decl, uni.Name) else None;
    if imp is not None and imp.is_comptime {
        return True;
    }
    owner = decl.name_of;
    return isinstance(owner, uni.Ability) and owner.is_comptime;
}

impl EsastGenPass._is_ct_type_param(nd: uni.Name) -> bool {
    sym = nd.sym;
    if sym is None {
        return False;
    }
    owner = sym.decl.name_of;
    return isinstance(owner, uni.TypeParam) and owner.is_comptime;
}

impl EsastGenPass._ct_ctor_slots(nd: uni.UniNode) -> (list[tuple] | None) {
    if not isinstance(nd, uni.AtomTrailer) or nd.is_attr {
        return None;
    }
    if not isinstance(nd.right, uni.IndexSlice) or nd.right.is_range {
        return None;
    }
    t = nd.target.type;
    shared = t?.shared;
    if shared is None or not shared.ct_params {
        return None;
    }
    arch = shared.symbol_table;
    if not isinstance(arch, uni.Archetype) {
        return None;
    }
    s0 = nd.right.slices[0] if nd.right.slices else None;
    head = s0.start if s0 is not None else None;
    vals: list = `list(head.values)
        if isinstance(head, uni.TupleVal)
        else ([head] if head else []);
    out: list[tuple] = [];
    for (i, tp) in enumerate(arch.type_params or []) {
        if tp.is_comptime and i < len(vals) {
            out.append((tp.name.value, vals[i], ));
        }
    }
    return out;
}

impl EsastGenPass._trailer_reaches_ct_class(nd: uni.AtomTrailer) -> bool {
    cur: any = nd.target;
    while isinstance(cur, uni.AtomTrailer) {
        if self._ct_ctor_slots(cur) is not None {
            return True;
        }
        cur = cur.target;
    }
    return False;
}
