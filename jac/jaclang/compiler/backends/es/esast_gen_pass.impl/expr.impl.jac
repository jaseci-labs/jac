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
    if isinstance(here.right, uni.FilterCompr) {
        here.gen.es_ast = self._build_osp_filter(here, `obj, here.right);
        return;
    }
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
