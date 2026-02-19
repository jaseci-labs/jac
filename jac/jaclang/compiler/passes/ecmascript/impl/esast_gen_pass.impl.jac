"""Initialize EsastGenPass."""

impl EsastGenPass.init(
    ir_in: uni.Module, prog: Any, cancel_token: (Any | None) = None
) -> None {
    super.init(ir_in, prog, cancel_token);
}

"""Extract literal value from an expression."""
impl EsastGenPass._literal_value(expr: (uni.UniNode | None)) -> (object | None) {
    if (expr is None) {
        return None;
    }
    if isinstance(expr, (uni.String, uni.Int, uni.Float, uni.Bool)) {
        return expr.lit_value;
    }
    if isinstance(expr, uni.MultiString) {
        parts: list[str] = [];
        for segment in expr.strings {
            if isinstance(segment, uni.String) {
                parts.append(segment.lit_value);
            } else {
                return None;
            }
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

"""Process semicolon."""
impl EsastGenPass.exit_semi(nd: uni.Semi) -> None {
    ;
}

"""Process token."""
impl EsastGenPass.exit_token(nd: uni.Token) -> None {
    ;
}

"""Process test as a function."""
impl EsastGenPass.exit_test(nd: uni.Test) -> None {
    params: list[es.Pattern] = [];
    body_stmts: list[es.Statement] = [];
    if nd.body {
        for stmt in nd.body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, list) {
                    body_stmts.extend(cast(es.Statement, s) for s in stmt.gen.es_ast);
                } else {
                    body_stmts.append(cast(es.Statement, stmt.gen.es_ast));
                }
            }
        }
    }
    body_stmts = self._prepend_hoisted(nd, body_stmts);
    block = self.sync_loc(es.BlockStatement(body=body_stmts), jac_node=nd);
    func_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);
    func_decl = self.sync_loc(
        es.FunctionDeclaration(id=func_id, params=params, body=block), jac_node=nd
    );
    nd.gen.es_ast = func_decl;
}

"""Process client block (cl { ... })."""
impl EsastGenPass.exit_client_block(nd: uni.ClientBlock) -> None {
    body_stmts: list[es.Statement] = [];
    if nd.body {
        for stmt in nd.body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, list) {
                    body_stmts.extend(cast(es.Statement, s) for s in stmt.gen.es_ast);
                } else {
                    body_stmts.append(cast(es.Statement, stmt.gen.es_ast));
                }
            }
        }
    }
    nd.gen.es_ast = body_stmts;
}

"""Process native block (na { ... }) - pruned from ECMAScript generation."""
impl EsastGenPass.exit_native_block(nd: uni.NativeBlock) -> None {
    ;
}

"""Process module code (with entry block)."""
impl EsastGenPass.exit_module_code(nd: uni.ModuleCode) -> None {
    body_stmts: list[es.Statement] = [];
    if nd.body {
        for stmt in nd.body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, list) {
                    body_stmts.extend(cast(es.Statement, s) for s in stmt.gen.es_ast);
                } else {
                    body_stmts.append(cast(es.Statement, stmt.gen.es_ast));
                }
            }
        }
    }
    nd.gen.es_ast = body_stmts;
}

"""Process non-local statement."""
impl EsastGenPass.exit_non_local_stmt(nd: uni.NonLocalStmt) -> None {
    nd.gen.es_ast = [];
}

"""Process global variables."""
impl EsastGenPass.exit_global_vars(nd: uni.GlobalVars) -> None {
    if nd.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub {
            for assignment in nd.assignments {
                for target in assignment.target {
                    if (sym_name := getattr(target, 'sym_name', None)) {
                        self.client_manifest.globals.append(sym_name);
                        if (
                            assignment.value
                            and (
                                (lit_val := self._literal_value(assignment.value)) is not None
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

"""Process name/identifier."""
impl EsastGenPass.exit_name(nd: uni.Name) -> None {
    name_map = {'None': 'null', 'True': 'true', 'False': 'false', 'self': 'this'};
    name = name_map.get(nd.sym_name, nd.sym_name);
    identifier = self.sync_loc(es.Identifier(name=name), jac_node=nd);
    nd.gen.es_ast = identifier;
}

"""Process null/None literal."""
impl EsastGenPass.exit_null(nd: uni.Null) -> None {
    null_lit = self.sync_loc(es.Literal(value=None, raw='null'), jac_node=nd);
    nd.gen.es_ast = null_lit;
}

"""Process await expression."""
impl EsastGenPass.exit_await_expr(nd: uni.AwaitExpr) -> None {
    argument = cast(
        es.Expression,
        nd.target.gen.es_ast
        or self.sync_loc(es.Identifier(name='undefined'), jac_node=nd.target)
    );
    await_expr = self.sync_loc(es.AwaitExpression(argument=argument), jac_node=nd);
    nd.gen.es_ast = await_expr;
}

"""Process ternary expression."""
impl EsastGenPass.exit_if_else_expr(nd: uni.IfElseExpr) -> None {
    `test = cast(
        es.Expression,
        nd.condition.gen.es_ast
        or self.sync_loc(es.Identifier(name='condition'), jac_node=nd.condition)
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

"""Process f-string literal as template literal."""
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

"""Process formatted value in f-string."""
impl EsastGenPass.exit_formatted_value(nd: uni.FormattedValue) -> None {
    expr = nd.format_part.gen.es_ast
    or self.sync_loc(es.Literal(value=''), jac_node=nd.format_part);
    nd.gen.es_ast = expr;
}

"""Process string literal."""
impl EsastGenPass.exit_string(nd: uni.String) -> None {
    value = nd.value;
    if value.startswith(('"""', "'''")) {
        value = value[3:-3];
    } elif value.startswith(('"', "'")) {
        value = value[1:-1];
    }
    raw_value = nd.value;
    if isinstance(value, str) {
        raw_value = json.dumps(value);
    }
    str_lit = self.sync_loc(es.Literal(value=value, raw=raw_value), jac_node=nd);
    nd.gen.es_ast = str_lit;
}

"""Process multi-string literal."""
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
            value = string_node.value;
            if value.startswith(('"""', "'''")) {
                value = value[3:-3];
            } elif value.startswith(('"', "'")) {
                value = value[1:-1];
            }
            str_lit = self.sync_loc(
                es.Literal(value=value, raw=string_node.value), jac_node=string_node
            );
            nd.gen.es_ast = str_lit;
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
            value = string_node.value;
            if value.startswith(('"""', "'''")) {
                value = value[3:-3];
            } elif value.startswith(('"', "'")) {
                value = value[1:-1];
            }
            raw_val = json.dumps(value)
            if isinstance(value, str)
            else string_node.value;
            str_lit = self.sync_loc(
                es.Literal(value=value, raw=raw_val), jac_node=string_node
            );
            parts.append(str_lit);
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

"""Process float literal."""
impl EsastGenPass.exit_float(nd: uni.Float) -> None {
    float_lit = self.sync_loc(
        es.Literal(value=float(nd.value), raw=nd.value), jac_node=nd
    );
    nd.gen.es_ast = float_lit;
}

"""Process integer literal."""
impl EsastGenPass.exit_int(nd: uni.Int) -> None {
    int_lit = self.sync_loc(
        es.Literal(value=int(nd.value, 0), raw=nd.value), jac_node=nd
    );
    nd.gen.es_ast = int_lit;
}

"""Process boolean literal."""
impl EsastGenPass.exit_bool(nd: uni.Bool) -> None {
    value = nd.value.lower() == 'true';
    raw_value = 'true' if value else 'false';
    bool_lit = self.sync_loc(es.Literal(value=value, raw=raw_value), jac_node=nd);
    nd.gen.es_ast = bool_lit;
}

"""Process inner comprehension (for x in items if cond) - handled by parent comprehension."""
impl EsastGenPass.exit_inner_compr(nd: uni.InnerCompr) -> None {
    # InnerCompr is handled by the parent ListCompr/SetCompr/GenCompr
    ;
}

"""Process list comprehension: [expr for x in items if cond] -> items.filter(x => cond).map(x => expr)."""
impl EsastGenPass.exit_list_compr(nd: uni.ListCompr) -> None {
    self._build_compr_chain(nd);
}

"""Process set comprehension: {expr for x in items if cond} -> items.filter(x => cond).map(x => expr)."""
impl EsastGenPass.exit_set_compr(nd: uni.SetCompr) -> None {
    self._build_compr_chain(nd);
}

"""Process generator comprehension: (expr for x in items if cond) -> items.filter(x => cond).map(x => expr)."""
impl EsastGenPass.exit_gen_compr(nd: uni.GenCompr) -> None {
    self._build_compr_chain(nd);
}

"""Build filter().map() chain for comprehensions."""
impl EsastGenPass._build_compr_chain(nd: uni.ListCompr) -> None {
    # Start with the output expression
    out_expr = cast(es.Expression, nd.out_expr.gen.es_ast);
    if not out_expr {
        nd.gen.es_ast = self.sync_loc(es.ArrayExpression(elements=[]), jac_node=nd);
        return;
    }
    # Process comprehensions (currently only support single compr, nested would be more complex)
    if not nd.compr or len(nd.compr) == 0 {
        nd.gen.es_ast = self.sync_loc(
            es.ArrayExpression(elements=[out_expr]), jac_node=nd
        );
        return;
    }
    compr = nd.compr[0];
    collection = cast(es.Expression, compr.collection.gen.es_ast);
    target = cast(es.Expression, compr.target.gen.es_ast);
    if not collection or not target {
        nd.gen.es_ast = self.sync_loc(es.ArrayExpression(elements=[]), jac_node=nd);
        return;
    }
    # Build params for arrow function (the iteration variable)
    param = self.sync_loc(
        es.Identifier(name=target.name if isinstance(target, es.Identifier) else 'x'),
        jac_node=compr.target
    );
    result = collection;
    # Add filter() calls for each conditional
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
                filter_call = self.sync_loc(
                    es.CallExpression(
                        callee=self.sync_loc(
                            es.MemberExpression(
                                object=result,
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
                result = filter_call;
            }
        }
    }
    # Add map() call for the output expression
    map_arrow = self.sync_loc(
        es.ArrowFunctionExpression(params=[param], body=out_expr, expression=True),
        jac_node=nd.out_expr
    );
    map_call = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.MemberExpression(
                    object=result,
                    property=self.sync_loc(es.Identifier(name='map'), jac_node=nd),
                    computed=False
                ),
                jac_node=nd
            ),
            arguments=[map_arrow]
        ),
        jac_node=nd
    );
    nd.gen.es_ast = map_call;
}

"""Process key-value pair."""
impl EsastGenPass.exit_k_v_pair(nd: uni.KVPair) -> None {
    ;
}

"""Process dictionary literal."""
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

"""Process tuple as array."""
impl EsastGenPass.exit_tuple_val(nd: uni.TupleVal) -> None {
    elements: list[es.Expression | es.SpreadElement | None] = [];
    for item in nd.values {
        if item.gen.es_ast {
            elements.append(cast(es.Expression, item.gen.es_ast));
        }
    }
    array_expr = self.sync_loc(es.ArrayExpression(elements=elements), jac_node=nd);
    nd.gen.es_ast = array_expr;
}

"""Process set literal as new Set()."""
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

"""Process list literal."""
impl EsastGenPass.exit_list_val(nd: uni.ListVal) -> None {
    elements: list[es.Expression | es.SpreadElement | None] = [];
    for item in nd.values {
        if item.gen.es_ast {
            elements.append(cast(es.Expression, item.gen.es_ast));
        }
    }
    array_expr = self.sync_loc(es.ArrayExpression(elements=elements), jac_node=nd);
    nd.gen.es_ast = array_expr;
}

"""Process parenthesized atom."""
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

"""Process lambda expression as arrow function."""
impl EsastGenPass.exit_lambda_expr(nd: uni.LambdaExpr) -> None {
    params: list[es.Pattern] = [];
    if isinstance(nd.signature, uni.FuncSignature) {
        for param in nd.signature.params {
            if param.gen.es_ast {
                params.append(cast(es.Pattern, param.gen.es_ast));
            }
        }
    }
    if isinstance(nd.body, list) {
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

"""Process attribute access."""
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
                member_expr = self.sync_loc(
                    es.MemberExpression(object=`obj, property=idx, computed=True),
                    jac_node=nd
                );
                nd.gen.es_ast = member_expr;
            } else {
                nd.gen.es_ast = `obj;
            }
        } else {
            nd.gen.es_ast = nd.right.gen.es_ast;
        }
    }
}

"""Process special variable reference."""
impl EsastGenPass.exit_special_var_ref(nd: uni.SpecialVarRef) -> None {
    self.exit_name(nd);
}

"""Process index/slice - just store the slice info, actual member access is handled by AtomTrailer."""
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

"""Process function call."""
impl EsastGenPass.exit_func_call(nd: uni.FuncCall) -> None {
    import from jaclang.compiler.type_system { types as jtypes }
    args: list[(es.Expression | es.SpreadElement)] = [];
    props: list[(es.Property | es.SpreadElement)] = [];
    for param in nd.params {
        if isinstance(param, uni.KWPair) {
            key_expr = cast(
                es.Expression,
                param.key.gen.es_ast
                if (param.key and param.key.gen.es_ast)
                else self.sync_loc(es.Identifier(name='key'), jac_node=param)
            );
            value_expr = cast(
                es.Expression,
                param.value.gen.es_ast
                if (param.value and param.value.gen.es_ast)
                else self.sync_loc(es.Literal(value=None), jac_node=param)
            );
            prop = self.sync_loc(
                es.Property(
                    key=key_expr,
                    value=value_expr,
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=param
            );
            props.append(prop);
            continue;
        }
        if param.gen.es_ast {
            args.append(cast(es.Expression, param.gen.es_ast));
        }
    }
    # Check for server function call from client context - transform to __jacCallFunction
    if (nd.in_client_context() and isinstance(nd.target, uni.Name)) {
        # Symbol may not be linked yet, so look it up directly from the symbol table
        target_sym = getattr(nd.target, 'sym', None);
        if not target_sym and nd.target.sym_tab {
            target_sym = nd.target.sym_tab.lookup(nd.target.sym_name, deep=True);
        }
        if (target_sym and target_sym.defn) {
            defn_node = target_sym.defn[0];
            if isinstance(defn_node.parent, uni.Ability) {
                ability_node = defn_node.parent;
                # A function is a server function if:
                # 1. It has code_context = SERVER (or default), AND
                # 2. It is NOT inside a client context (not nested in cl{}), AND
                # 3. It is a PUBLIC function (def:pub) - this excludes builtins like print
                is_server_func = (
                    ability_node.code_context != CodeContext.CLIENT
                    and not ability_node.in_client_context()
                    and ability_node.access is not None
                    and ability_node.access.tag.name == Tok.KW_PUB
                );
                if is_server_func {
                    func_name = nd.target.sym_name;
                    param_names: list[str] = [];
                    if isinstance(ability_node.signature, uni.FuncSignature) {
                        param_names = [
                            p.name.sym_name for p in ability_node.signature.params
                        ];
                    }
                    props = [];
                    for (i, arg) in enumerate(args) {
                        if isinstance(arg, es.SpreadElement) {
                            props.append(arg);
                        } elif (i < len(param_names)) {
                            key = self.sync_loc(
                                es.Literal(value=param_names[i]), jac_node=nd
                            );
                            props.append(
                                self.sync_loc(
                                    es.Property(
                                        key=key,
                                        value=arg,
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
                    args_obj = self.sync_loc(
                        es.ObjectExpression(properties=props), jac_node=nd
                    );
                    # Generate CallExpression without await - the outer AwaitExpr handles that
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
                    # Auto-inject __jacCallFunction import if not already done
                    if not self.has_injected_jac_call_function {
                        # Inline: import { __jacCallFunction } from "@jac/runtime";
                        specifier = self.sync_loc(
                            es.ImportSpecifier(
                                imported=es.Identifier(name='__jacCallFunction'),
                                local=es.Identifier(name='__jacCallFunction')
                            ),
                            jac_node=nd
                        );
                        source = self.sync_loc(
                            es.Literal(value='@jac/runtime', raw='"@jac/runtime"'),
                            jac_node=nd
                        );
                        import_decl = self.sync_loc(
                            es.ImportDeclaration(specifiers=[specifier], source=source),
                            jac_node=nd
                        );
                        self.imports.append(import_decl);
                        self.has_injected_jac_call_function = True;
                    }
                    nd.gen.es_ast = call_expr;
                    return;
                }
            }
        }
    }
    callee = nd.target.gen.es_ast
    or self.sync_loc(es.Identifier(name='func'), jac_node=nd.target);
    # --- Primitive emitter dispatch for method calls ---
    if (
        isinstance(callee, es.MemberExpression)
        and isinstance(callee.property, es.Identifier)
        and isinstance(nd.target, uni.AtomTrailer)
    ) {
        import from jaclang.compiler.passes.ecmascript.es_unparse { JSCodeGenerator }
        _obj_type = None;
        try {
            _te = self.prog.get_type_evaluator();
            if _te {
                _obj_type = _te.get_type_of_expression(nd.target.target);
            }
        } except Exception {
            _obj_type = None;
        }
        if (
            isinstance(_obj_type, jtypes.ClassType)
            and _obj_type.shared
            and _obj_type.shared.class_name in self._primitive_type_names
        ) {
            # Lazily initialize emitter singletons on first use
            if self._primitive_emitters is None {
                _pes = __import__(
                    "jaclang.compiler.passes.ecmascript.primitives_es",
                    fromlist=["ESIntEmitter"]
                );
                self._primitive_emitters = {
                    "int": _pes.ESIntEmitter(),
                    "float": _pes.ESFloatEmitter(),
                    "complex": _pes.ESComplexEmitter(),
                    "str": _pes.ESStrEmitter(),
                    "bytes": _pes.ESBytesEmitter(),
                    "list": _pes.ESListEmitter(),
                    "dict": _pes.ESDictEmitter(),
                    "set": _pes.ESSetEmitter(),
                    "frozenset": _pes.ESFrozensetEmitter(),
                    "tuple": _pes.ESTupleEmitter(),
                    "range": _pes.ESRangeEmitter(),
                    "bool": _pes.ESBoolEmitter()
                };
                self._es_emit_ctx_class = _pes.ESEmitCtx;
            }
            _type_name = _obj_type.shared.class_name;
            _emitter = self._primitive_emitters.get(_type_name);
            _method_name = callee.property.name;
            _emit_fn_name = "emit_" + _method_name;
            _emit_fn = getattr(_emitter, _emit_fn_name, None) if _emitter else None;
            if _emit_fn {
                _unparser = JSCodeGenerator();
                _ctx = self._es_emit_ctx_class(unparser=_unparser);
                _target_str = _unparser.generate(callee.object);
                _args_strs: list[str] = [];
                for _a in args {
                    _args_strs.append(_unparser.generate(_a));
                }
                # Include keyword argument values (e.g., key=lambda in sort)
                for _p in props {
                    if isinstance(_p, es.Property) and _p.value {
                        _args_strs.append(_unparser.generate(_p.value));
                    }
                }
                _result = _emit_fn(_ctx, _target_str, _args_strs);
                if _result is not None and "_jac." in str(_result) {
                    self.needs_jac_runtime = True;
                }
                nd.gen.es_ast = self.sync_loc(es.Identifier(name=_result), jac_node=nd);
                return;
            }
        }
    }
    # --- Primitive emitter dispatch for builtin function calls ---
    if (
        isinstance(nd.target, uni.Name)
        and nd.target.sym_name in self._emitter_builtins
    ) {
        import from jaclang.compiler.passes.ecmascript.es_unparse { JSCodeGenerator }
        # Lazily initialize builtin emitter singleton on first use
        if self._builtin_emitter is None {
            _pes = __import__(
                "jaclang.compiler.passes.ecmascript.primitives_es",
                fromlist=["ESBuiltinEmitter"]
            );
            self._builtin_emitter = _pes.ESBuiltinEmitter();
            if not hasattr(self, '_es_emit_ctx_class') {
                self._es_emit_ctx_class = _pes.ESEmitCtx;
            }
        }
        _builtin_name = nd.target.sym_name;
        _emit_fn_name = "emit_" + _builtin_name;
        _emit_fn = getattr(self._builtin_emitter, _emit_fn_name, None);
        if _emit_fn {
            _unparser = JSCodeGenerator();
            _ctx = self._es_emit_ctx_class(unparser=_unparser);
            _args_strs: list[str] = [];
            for _a in args {
                _args_strs.append(_unparser.generate(_a));
            }
            # Include keyword argument values (e.g., key=lambda, reverse=True)
            for _p in props {
                if isinstance(_p, es.Property) and _p.value {
                    _args_strs.append(_unparser.generate(_p.value));
                }
            }
            _result = _emit_fn(_ctx, _args_strs);
            if _result is not None and "_jac." in str(_result) {
                self.needs_jac_runtime = True;
            }
            nd.gen.es_ast = self.sync_loc(es.Identifier(name=_result), jac_node=nd);
            return;
        }
    }
    # --- Default codegen (non-primitive or fallback) ---
    if isinstance(nd.target, uni.Name) {
        callee_type = self.prog.get_type_evaluator().get_type_of_expression(nd.target);
    } else {
        callee_type = None;
    }
    args_obj = self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);
    callee_expr = cast(es.Expression, callee);
    call_args: list[(es.Expression | es.SpreadElement)] = [args_obj] if props else args;
    if (
        isinstance(callee_type, jtypes.ClassType) and isinstance(callee, es.Expression)
    ) {
        nd.gen.es_ast = self.sync_loc(
            es.NewExpression(callee=callee_expr, arguments=call_args), jac_node=nd
        );
    } else {
        nd.gen.es_ast = self.sync_loc(
            es.CallExpression(callee=callee_expr, arguments=call_args), jac_node=nd
        );
    }
}

"""Process assignment expression."""
impl EsastGenPass.exit_assignment(nd: uni.Assignment) -> None {
    if not nd.target {
        nd.gen.es_ast = None;
        return;
    }
    value_expr = nd.value.gen.es_ast if (nd.value and nd.value.gen.es_ast) else None;
    # Check for reactive variable assignment (transforms count = X to setCount(X))
    if len(nd.target) == 1 and isinstance(nd.target[0], uni.Name) {
        target_name = nd.target[0].sym_name;
        if target_name in self.reactive_vars {
            setter_name = self.reactive_vars[target_name];
            # Get the value to pass to setter
            setter_arg: es.Expression;
            if nd.aug_op {
                # For augmented assignment: count += 1 -> setCount(count + 1)
                aug_tok = Tok(nd.aug_op.name)
                if (nd.aug_op.name in Tok.__members__)
                else None;
                # Map augmented op to binary op
                aug_to_binary: dict[Tok, str] = {
                    Tok.ADD_EQ: '+',
                    Tok.SUB_EQ: '-',
                    Tok.MUL_EQ: '*',
                    Tok.DIV_EQ: '/',
                    Tok.MOD_EQ: '%'
                };
                binary_op = aug_to_binary.get(aug_tok, '+') if aug_tok else '+';
                right_expr = cast(es.Expression, value_expr or es.Literal(value=0));
                setter_arg = self.sync_loc(
                    es.BinaryExpression(
                        operator=binary_op,
                        left=es.Identifier(name=target_name),
                        right=right_expr
                    ),
                    jac_node=nd
                );
            } else {
                # Regular assignment: count = X -> setCount(X)
                setter_arg = cast(
                    es.Expression, value_expr or es.Identifier(name='undefined')
                );
            }
            # Generate: setCount(value)
            setter_call = self.sync_loc(
                es.CallExpression(
                    callee=es.Identifier(name=setter_name), arguments=[setter_arg]
                ),
                jac_node=nd
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
                    default_factory=lambda _src: Any : es.Identifier(name='undefined')
                )
            )
        );
        # Type-aware augmented assignment primitive dispatch
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
    targets_info: list[AssignmentTargetInfo] = [];
    for target_node in nd.target {
        (left, reference, decl_name) = self._convert_assignment_target(target_node);
        pattern_names = self._collect_pattern_names(target_node);
        first_def = False;
        if isinstance(target_node, uni.Name) {
            first_def = self._is_name_first_definition(target_node);
        } elif pattern_names {
            first_def = any(
                self._is_name_first_definition(name_node)
                for (_, name_node) in pattern_names
            );
        }
        targets_info.append(
            AssignmentTargetInfo(
                nd=target_node,
                left=left,
                reference=reference,
                decl_name=decl_name,
                pattern_names=pattern_names,
                is_first=first_def
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
                default_factory=lambda _src: Any : es.Identifier(name='undefined')
            )
        )
    );
    for info in reversed(targets_info) {
        target_node = info.nd;
        left = info.left;
        decl_name = info.decl_name;
        pattern_names = info.pattern_names;
        is_first = info.is_first;
        should_declare = False;
        if decl_name {
            should_declare = (
                is_first and not self._is_declared_in_any_scope(decl_name)
            );
        } elif pattern_names {
            should_declare = any(
                (
                    self._is_name_first_definition(name_node)
                    and not self._is_declared_in_any_scope(name)
                ) for (name, name_node) in pattern_names
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

"""Determine whether a name node corresponds to the first definition in its scope."""
impl EsastGenPass._is_name_first_definition(name_node: uni.Name) -> bool {
    sym = getattr(name_node, 'sym', None);
    if (sym and (name_node.name_spec in sym.defn)) {
        return (sym.defn.index(name_node.name_spec) == 0);
    }
    return True;
}

"""Collect identifier names from a (possibly nested) destructuring target."""
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

"""Convert a Jac assignment target into an ESTree pattern/expression."""
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
                    key=key_expr,
                    value=cast(es.Pattern, value_pattern),
                    shorthand=False
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
    left = cast(
        (es.Pattern | es.Expression),
        target.gen.es_ast or self.sync_loc(es.Identifier(name='temp'), jac_node=target)
    );
    reference = cast(es.Expression, left) if isinstance(left, es.Node) else None;
    return (left, reference, None);
}

"""Try to dispatch an operator through the primitive emitter system.

Returns an es.Expression (raw Identifier wrapping emitted JS) on success, or None
if the type evaluator doesn't know the type or the emitter doesn't handle this op.
"""
impl EsastGenPass._try_primitive_op(
    expr_node: uni.UniNode,
    emit_method: str,
    left_es: es.Expression,
    right_es: (es.Expression | None),
    jac_node: uni.UniNode
) -> (es.Expression | None) {
    import from jaclang.compiler.type_system { types as jtypes }
    import from jaclang.compiler.passes.ecmascript.es_unparse { JSCodeGenerator }
    _obj_type = None;
    try {
        _te = self.prog.get_type_evaluator();
        if _te {
            _obj_type = _te.get_type_of_expression(expr_node);
        }
    } except Exception {
        _obj_type = None;
    }
    if not (
        isinstance(_obj_type, jtypes.ClassType)
        and _obj_type.shared
        and _obj_type.shared.class_name in self._primitive_type_names
    ) {
        return None;
    }
    # Lazily initialize emitter singletons on first use
    if self._primitive_emitters is None {
        _pes = __import__(
            "jaclang.compiler.passes.ecmascript.primitives_es",
            fromlist=["ESIntEmitter"]
        );
        self._primitive_emitters = {
            "int": _pes.ESIntEmitter(),
            "float": _pes.ESFloatEmitter(),
            "complex": _pes.ESComplexEmitter(),
            "str": _pes.ESStrEmitter(),
            "bytes": _pes.ESBytesEmitter(),
            "list": _pes.ESListEmitter(),
            "dict": _pes.ESDictEmitter(),
            "set": _pes.ESSetEmitter(),
            "frozenset": _pes.ESFrozensetEmitter(),
            "tuple": _pes.ESTupleEmitter(),
            "range": _pes.ESRangeEmitter(),
            "bool": _pes.ESBoolEmitter()
        };
        self._es_emit_ctx_class = _pes.ESEmitCtx;
    }
    _type_name = _obj_type.shared.class_name;
    _emitter = self._primitive_emitters.get(_type_name);
    _emit_fn = getattr(_emitter, emit_method, None) if _emitter else None;
    if not _emit_fn {
        return None;
    }
    _unparser = JSCodeGenerator();
    _ctx = self._es_emit_ctx_class(unparser=_unparser);
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

"""Process unary expression."""
impl EsastGenPass.exit_unary_expr(nd: uni.UnaryExpr) -> None {
    operand = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.operand, default_factory=lambda _src: Any : es.Literal(value=0)
        )
    );
    op_tok = Tok(nd.op.name) if (nd.op.name in Tok.__members__) else None;
    # Type-aware unary primitive dispatch
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
    unary_expr = self.sync_loc(
        es.UnaryExpression(operator=operator, prefix=True, argument=operand),
        jac_node=nd
    );
    nd.gen.es_ast = unary_expr;
}

"""Process compare expression."""
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
            default_factory=lambda src: Any :
                es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Identifier(name='left')
        )
    );
    for (op_token, right_node) in zip(nd.ops, nd.rights, strict=False) {
        right: es.Expression = cast(
            es.Expression,
            self._get_ast_or_default(
                right_node,
                default_factory=lambda src: Any :
                    es.Identifier(name=src.sym_name)
                    if isinstance(src, uni.Name)
                    else es.Identifier(name='right')
            )
        );
        op_tok = Tok(op_token.name) if (op_token.name in Tok.__members__) else None;
        # Type-aware comparison primitive dispatch
        _cmp_emit_name = CMP_EMIT_MAP.get(op_tok) if op_tok else None;
        if _cmp_emit_name {
            # For in/not in: type-check the container (right), swap target/arg
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
        operator = ES_COMPARISON_OPS.get(op_tok) if op_tok else None;
        operator = operator or '===';
        comparison: (es.UnaryExpression | es.BinaryExpression);
        if (op_tok == Tok.KW_NIN) {
            in_expr = self.sync_loc(
                es.BinaryExpression(operator='in', left=left, right=right), jac_node=nd
            );
            comparison = self.sync_loc(
                es.UnaryExpression(operator='!', prefix=True, argument=in_expr),
                jac_node=nd
            );
        } else {
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

"""Process boolean expression (and/or)."""
impl EsastGenPass.exit_bool_expr(nd: uni.BoolExpr) -> None {
    if (not nd.values or (len(nd.values) < 2)) {
        nd.gen.es_ast = self.sync_loc(es.Literal(value=None), jac_node=nd);
        return;
    }
    op_tok = Tok(nd.op.name) if (nd.op.name in Tok.__members__) else None;
    logical_op = ES_LOGICAL_OPS.get(op_tok) if op_tok else None;
    logical_op = logical_op or '&&';
    result: es.Expression = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.values[0], default_factory=lambda _src: Any : es.Literal(value=None)
        )
    );
    for val in nd.values[1:] {
        right = cast(
            es.Expression,
            self._get_ast_or_default(
                val, default_factory=lambda _src: Any : es.Literal(value=None)
            )
        );
        result = self.sync_loc(
            es.LogicalExpression(operator=logical_op, left=result, right=right),
            jac_node=nd
        );
    }
    nd.gen.es_ast = result;
}

"""Process binary expression."""
impl EsastGenPass.exit_binary_expr(nd: uni.BinaryExpr) -> None {
    left = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.left,
            default_factory=lambda src: Any :
                es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Literal(value=0)
        )
    );
    right = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.right,
            default_factory=lambda src: Any :
                es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Literal(value=0)
        )
    );
    op_name_str = getattr(nd.op, 'name', None);
    op_name = Tok(op_name_str) if (op_name_str in Tok.__members__) else None;
    if (op_name == Tok.KW_SPAWN) {
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
    # Type-aware operator primitive dispatch
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
        bin_expr = self.sync_loc(
            es.BinaryExpression(operator=operator, left=left, right=right), jac_node=nd
        );
    }
    nd.gen.es_ast = bin_expr;
}

"""Process switch case."""
impl EsastGenPass.exit_switch_case(nd: uni.SwitchCase) -> None {
    case_test: (es.Expression | None) = None;
    if (nd.pattern and isinstance(nd.pattern, uni.MatchValue)) {
        case_test = self._get_ast_or_default(
            nd.pattern.value, default_factory=lambda _src: Any : es.Literal(value=None)
        );
    }
    body_stmts = self._collect_stmt_body(nd.body);
    nd.gen.es_ast = self.sync_loc(
        es.SwitchCase(`test=case_test, consequent=body_stmts), jac_node=nd
    );
}

"""Process switch statement."""
impl EsastGenPass.exit_switch_stmt(nd: uni.SwitchStmt) -> None {
    `test = self._get_ast_or_default(
        nd.target, default_factory=lambda _src: Any : es.Literal(value=None)
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

"""Process expression statement."""
impl EsastGenPass.exit_expr_stmt(nd: uni.ExprStmt) -> None {
    expr = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.expr, default_factory=lambda _src: Any : es.Literal(value=None)
        )
    );
    expr_stmt = self.sync_loc(es.ExpressionStatement(expression=expr), jac_node=nd);
    nd.gen.es_ast = expr_stmt;
}

"""Process control statement (break/continue)."""
impl EsastGenPass.exit_ctrl_stmt(nd: uni.CtrlStmt) -> None {
    stmt: (es.BreakStatement | es.ContinueStatement);
    if (nd.ctrl.name == Tok.KW_BREAK) {
        stmt = self.sync_loc(es.BreakStatement(), jac_node=nd);
    } else {
        stmt = self.sync_loc(es.ContinueStatement(), jac_node=nd);
    }
    nd.gen.es_ast = stmt;
}

"""Process return statement."""
impl EsastGenPass.exit_return_stmt(nd: uni.ReturnStmt) -> None {
    argument: (es.Expression | None) = None;
    if (nd.expr and nd.expr.gen.es_ast) {
        argument = cast(es.Expression, nd.expr.gen.es_ast);
    }
    ret_stmt = self.sync_loc(es.ReturnStatement(argument=argument), jac_node=nd);
    nd.gen.es_ast = ret_stmt;
}

"""Process assert statement as if-throw."""
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

"""Process raise statement."""
impl EsastGenPass.exit_raise_stmt(nd: uni.RaiseStmt) -> None {
    argument: es.Expression = cast(es.Expression, nd.cause.gen.es_ast)
    if (nd.cause and nd.cause.gen.es_ast)
    else self.sync_loc(es.Identifier(name='Error'), jac_node=nd);
    if isinstance(argument, es.CallExpression) {
        callee = argument.callee;
        if (
            isinstance(callee, es.Identifier)
            and (callee.name in {'Exception','Error'})
        ) {
            new_expr = self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(es.Identifier(name='Error'), jac_node=nd),
                    arguments=argument.arguments
                ),
                jac_node=nd
            );
            argument = new_expr;
        }
    }
    throw_stmt = self.sync_loc(es.ThrowStatement(argument=argument), jac_node=nd);
    nd.gen.es_ast = throw_stmt;
}

"""Process finally clause."""
impl EsastGenPass.exit_finally_stmt(nd: uni.FinallyStmt) -> None {
    nd.gen.es_ast = self._build_block_statement(nd, nd.body);
}

"""Process except clause."""
impl EsastGenPass.exit_except(nd: uni.Except) -> None {
    param: (es.Pattern | None) = None;
    if nd.name {
        param = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);
    }
    body = self._build_block_statement(nd, nd.body);
    catch_clause = self.sync_loc(es.CatchClause(param=param, body=body), jac_node=nd);
    nd.gen.es_ast = catch_clause;
}

"""Process try statement."""
impl EsastGenPass.exit_try_stmt(nd: uni.TryStmt) -> None {
    block = self._build_block_statement(nd, nd.body);
    handler: (es.CatchClause | None) = None;
    if nd.excepts {
        except_node = nd.excepts[0];
        if except_node.gen.es_ast {
            handler = cast(es.CatchClause, except_node.gen.es_ast);
        }
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

"""Process for-in statement."""
impl EsastGenPass.exit_in_for_stmt(nd: uni.InForStmt) -> None {
    target_ast = nd.target.gen.es_ast;
    left: es.Node = target_ast
    if isinstance(target_ast, es.Node)
    else self.sync_loc(es.Identifier(name='item'), jac_node=nd.target);
    right: es.Expression = cast(es.Expression, nd.collection.gen.es_ast)
    if nd.collection.gen.es_ast
    else self.sync_loc(es.Identifier(name='collection'), jac_node=nd.collection);
    body = self._build_block_statement(nd, nd.body);
    pattern_nodes = (
        es.Identifier,
        es.ArrayPattern,
        es.ObjectPattern,
        es.AssignmentPattern,
        es.RestElement
    );
    if isinstance(left, es.VariableDeclaration) {
        decl = left;
    } else {
        if isinstance(left, pattern_nodes) {
            pattern = left;
        } else {
            pattern = self.sync_loc(es.Identifier(name='_item'), jac_node=nd.target);
        }
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

"""Process traditional for statement."""
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
        es.ForStatement(`init=`init, `test=`test, update=update, body=body),
        jac_node=nd
    );
}

"""Process while statement."""
impl EsastGenPass.exit_while_stmt(nd: uni.WhileStmt) -> None {
    `test = self._get_ast_or_default(
        nd.condition, default_factory=lambda _src: Any : es.Literal(value=True)
    );
    body = self._build_block_statement(nd, nd.body);
    while_stmt = self.sync_loc(es.WhileStatement(`test=`test, body=body), jac_node=nd);
    nd.gen.es_ast = while_stmt;
}

"""Process else clause."""
impl EsastGenPass.exit_else_stmt(nd: uni.ElseStmt) -> None {
    stmts = self._collect_stmt_body(nd.body);
    stmts = self._prepend_hoisted(nd, stmts);
    block = self.sync_loc(es.BlockStatement(body=stmts), jac_node=nd);
    nd.gen.es_ast = block;
}

"""Process else-if clause."""
impl EsastGenPass.exit_else_if(nd: uni.ElseIf) -> None {
    `test = self._get_ast_or_default(
        nd.condition, default_factory=lambda _src: Any : es.Literal(value=True)
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

"""Process if statement."""
impl EsastGenPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    `test = self._get_ast_or_default(
        nd.condition, default_factory=lambda _src: Any : es.Literal(value=True)
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

"""Process JSX expression child."""
impl EsastGenPass.exit_jsx_expression(nd: uni.JsxExpression) -> None {
    self.jsx_processor.expression(nd);
}

"""Process JSX text node."""
impl EsastGenPass.exit_jsx_text(nd: uni.JsxText) -> None {
    self.jsx_processor.text(nd);
}

"""Process JSX normal attribute."""
impl EsastGenPass.exit_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None {
    self.jsx_processor.normal_attribute(nd);
}

"""Process JSX spread attribute."""
impl EsastGenPass.exit_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None {
    self.jsx_processor.spread_attribute(nd);
}

"""Process JSX element name."""
impl EsastGenPass.exit_jsx_element_name(nd: uni.JsxElementName) -> None {
    self.jsx_processor.element_name(nd);
}

"""Process JSX element."""
impl EsastGenPass.exit_jsx_element(nd: uni.JsxElement) -> None {
    nd.gen.es_ast = self.jsx_processor.element(nd);
}

"""Process has variable."""
impl EsastGenPass.exit_has_var(nd: uni.HasVar) -> None {
    nd.gen.es_ast = None;
}

"""Generate setter name for reactive variable (count -> setCount)."""
impl EsastGenPass._get_setter_name(var_name: str) -> str {
    if not var_name {
        return "";
    }
    return f"set{var_name[0].upper()}{var_name[1:]}";
}

"""Check if useState is already imported (either by user or auto-injection)."""
impl EsastGenPass._has_usestate_import -> bool {
    for import_decl in self.imports {
        for spec in import_decl.specifiers {
            if isinstance(spec, es.ImportSpecifier) {
                if spec.local and spec.local.name == 'useState' {
                    return True;
                }
            }
        }
    }
    return False;
}

"""Register @jac/runtime in the client manifest so bundler can inline it."""
impl EsastGenPass._register_jac_runtime_import -> None {
    import from pathlib { Path }
    import jaclang.runtimelib;
    # Only register once
    if '@jac/runtime' not in self.client_manifest.imports {
        runtime_dir = Path(jaclang.runtimelib.__file__).parent;
        runtime_path = runtime_dir / 'client_runtime.cl.jac';
        self.client_manifest.imports['@jac/runtime'] = str(runtime_path);
    }
}

"""Auto-inject useState import from @jac/runtime when reactive has variables are used."""
impl EsastGenPass._inject_usestate_import(nd: uni.UniNode) -> None {
    # Create: import { useState } from "@jac/runtime";
    specifier = self.sync_loc(
        es.ImportSpecifier(
            imported=es.Identifier(name='useState'),
            local=es.Identifier(name='useState')
        ),
        jac_node=nd
    );
    source = self.sync_loc(
        es.Literal(value='@jac/runtime', raw='"@jac/runtime"'), jac_node=nd
    );
    import_decl = self.sync_loc(
        es.ImportDeclaration(specifiers=[specifier], source=source), jac_node=nd
    );
    self.imports.append(import_decl);
    # Register in client manifest so bundler knows to inline the runtime
    self._register_jac_runtime_import();
}

"""Auto-inject __jacCallFunction import from @jac/runtime when server functions are called from client."""
impl EsastGenPass._inject_jac_call_function_import(nd: uni.UniNode) -> None {
    # Create: import { __jacCallFunction } from "@jac/runtime";
    specifier = self.sync_loc(
        es.ImportSpecifier(
            imported=es.Identifier(name='__jacCallFunction'),
            local=es.Identifier(name='__jacCallFunction')
        ),
        jac_node=nd
    );
    source = self.sync_loc(
        es.Literal(value='@jac/runtime', raw='"@jac/runtime"'), jac_node=nd
    );
    import_decl = self.sync_loc(
        es.ImportDeclaration(specifiers=[specifier], source=source), jac_node=nd
    );
    self.imports.append(import_decl);
    # Register in client manifest so bundler knows to inline the runtime
    self._register_jac_runtime_import();
}

"""Check if useEffect is already imported (either by user or auto-injection)."""
impl EsastGenPass._has_useeffect_import -> bool {
    for import_decl in self.imports {
        for spec in import_decl.specifiers {
            if isinstance(spec, es.ImportSpecifier) {
                if spec.local and spec.local.name == 'useEffect' {
                    return True;
                }
            }
        }
    }
    return False;
}

"""Auto-inject useEffect import from @jac/runtime when can with entry/exit is used."""
impl EsastGenPass._inject_useeffect_import(nd: uni.UniNode) -> None {
    # Create: import { useEffect } from "@jac/runtime";
    specifier = self.sync_loc(
        es.ImportSpecifier(
            imported=es.Identifier(name='useEffect'),
            local=es.Identifier(name='useEffect')
        ),
        jac_node=nd
    );
    source = self.sync_loc(
        es.Literal(value='@jac/runtime', raw='"@jac/runtime"'), jac_node=nd
    );
    import_decl = self.sync_loc(
        es.ImportDeclaration(specifiers=[specifier], source=source), jac_node=nd
    );
    self.imports.append(import_decl);
    # Register in client manifest so bundler knows to inline the runtime
    self._register_jac_runtime_import();
}

"""Transform an EventSignature ability (can with entry/exit) to useEffect call."""
impl EsastGenPass._transform_to_useeffect(nd: uni.Ability) -> None {
    # Get the body statements
    inner = (
        nd.body.body if isinstance(nd.body, uni.ImplDef) else self._get_body_inner(nd)
    );
    body_stmts = self._collect_stmt_body(inner);
    # Determine if this is entry or exit
    is_entry = nd.signature.event.name == Tok.KW_ENTRY;
    is_async = nd.is_async;
    effect_body: list[es.Statement] = [];
    if is_entry {
        if is_async {
            # Wrap in IIFE: (async () => { ... })();
            async_arrow = self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[],
                    body=es.BlockStatement(body=body_stmts),
                    async_=True,
                    expression=False
                ),
                jac_node=nd
            );
            iife_call = self.sync_loc(
                es.CallExpression(callee=async_arrow, arguments=[]), jac_node=nd
            );
            effect_body.append(
                self.sync_loc(
                    es.ExpressionStatement(expression=iife_call), jac_node=nd
                )
            );
        } else {
            effect_body = body_stmts;
        }
    } else {
        # Exit: wrap body in cleanup return
        # return () => { ... };
        cleanup_arrow = self.sync_loc(
            es.ArrowFunctionExpression(
                params=[],
                body=es.BlockStatement(body=body_stmts),
                async_=False,
                expression=False
            ),
            jac_node=nd
        );
        effect_body.append(
            self.sync_loc(es.ReturnStatement(argument=cleanup_arrow), jac_node=nd)
        );
    }
    # Create effect callback: () => { ... }
    effect_callback = self.sync_loc(
        es.ArrowFunctionExpression(
            params=[],
            body=es.BlockStatement(body=effect_body),
            async_=False,
            expression=False
        ),
        jac_node=nd
    );
    # Build dependency array from arch_tag_info (if provided)
    # can with entry { ... }           -> []
    # can with [a, b] entry { ... }    -> [a, b]
    # can with (a, b) entry { ... }    -> [a, b]
    deps_elements: list[es.Expression | es.SpreadElement | None] = [];
    arch_tag = nd.signature.arch_tag_info;
    if arch_tag {
        # Check if it's a list or tuple
        if isinstance(arch_tag, (uni.ListVal, uni.TupleVal)) {
            for item in arch_tag.values {
                if item.gen.es_ast {
                    deps_elements.append(cast(es.Expression, item.gen.es_ast));
                }
            }
        } else {
            # Single expression as dependency
            if arch_tag.gen.es_ast {
                deps_elements.append(cast(es.Expression, arch_tag.gen.es_ast));
            }
        }
    }
    deps_array = self.sync_loc(es.ArrayExpression(elements=deps_elements), jac_node=nd);
    # Create useEffect call: useEffect(() => { ... }, [deps]);
    use_effect_call = self.sync_loc(
        es.CallExpression(
            callee=es.Identifier(name='useEffect'),
            arguments=[effect_callback, deps_array]
        ),
        jac_node=nd
    );
    nd.gen.es_ast = self.sync_loc(
        es.ExpressionStatement(expression=use_effect_call), jac_node=nd
    );
}

"""Process class field declarations - generates useState for client-side reactive state."""
impl EsastGenPass.exit_arch_has(nd: uni.ArchHas) -> None {
    # Check if this is client-side reactive state (works for both cl {} and .cl.jac)
    if not nd.in_client_context() {
        nd.gen.es_ast = None;
        return;
    }
    # Auto-inject useState import if not already done and user hasn't imported it
    if not self.has_injected_usestate and not self._has_usestate_import() {
        self._inject_usestate_import(nd);
        self.has_injected_usestate = True;
    }
    # Generate useState destructuring for each variable
    # has count: int = 0; -> const [count, setCount] = useState(0);
    statements: list[es.Statement] = [];
    for has_var in nd.vars {
        var_name = has_var.name.sym_name;
        setter_name = self._get_setter_name(var_name);

        # Track this as a reactive variable for assignment transformation
        self.reactive_vars[var_name] = setter_name;

        # Get the initial value expression
        init_value: es.Expression;
        if has_var.value and has_var.value.gen.es_ast {
            init_value = cast(es.Expression, has_var.value.gen.es_ast);
        } else {
            init_value = es.Identifier(name='undefined');
        }

        # Build: const [count, setCount] = useState(initialValue);
        array_pattern = self.sync_loc(
            es.ArrayPattern(
                elements=[
                    es.Identifier(name=var_name),
                    es.Identifier(name=setter_name)
                ]
            ),
            jac_node=has_var.name
        );

        use_state_call = self.sync_loc(
            es.CallExpression(
                callee=es.Identifier(name='useState'), arguments=[init_value]
            ),
            jac_node=has_var
        );

        declarator = self.sync_loc(
            es.VariableDeclarator(id=array_pattern, `init=use_state_call),
            jac_node=has_var
        );

        decl_stmt = self.sync_loc(
            es.VariableDeclaration(declarations=[declarator], kind='const'),
            jac_node=has_var
        );

        statements.append(decl_stmt);

        # Register both the variable and setter as declared
        self._register_declaration(var_name);
        self._register_declaration(setter_name);
    }
    if len(statements) == 1 {
        nd.gen.es_ast = statements[0];
    } elif len(statements) > 1 {
        # Return as a list for multiple declarations
        nd.gen.es_ast = statements;
    } else {
        nd.gen.es_ast = None;
    }
}

"""Process parameter variable."""
impl EsastGenPass.exit_param_var(nd: uni.ParamVar) -> None {
    param_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);
    self._register_declaration(param_id.name);
    nd.gen.es_ast = param_id;
}

"""Process function signature."""
impl EsastGenPass.exit_func_signature(nd: uni.FuncSignature) -> None {
    nd.gen.es_ast = None;
}

"""Process ability (function/method) declaration."""
impl EsastGenPass.exit_ability(nd: uni.Ability) -> None {
    # Restore reactive_vars to parent scope
    if self.reactive_vars_stack {
        self.reactive_vars = self.reactive_vars_stack.pop();
    }
    # CHECK: Is this an event-based ability (can with entry/exit) in client context?
    if (isinstance(nd.signature, uni.EventSignature) and nd.in_client_context()) {
        # Auto-inject useEffect import if needed
        if not self.has_injected_useeffect and not self._has_useeffect_import() {
            self._inject_useeffect_import(nd);
            self.has_injected_useeffect = True;
        }
        # Transform to useEffect
        self._transform_to_useeffect(nd);
        return;
    }
    if (nd.code_context == CodeContext.CLIENT and not nd.is_method) {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub {
            name = nd.name_ref.sym_name;
            self.client_manifest.exports.append(name);
            self.client_manifest.params[name] = [
                p.name.sym_name for p in nd.signature.params
            ]
            if isinstance(nd.signature, uni.FuncSignature)
            else [];
        }
    }
    is_jsx_in_return = False;
    if isinstance(nd.body, list) {
        for stmt in nd.body {
            if isinstance(stmt, uni.ReturnStmt) {
                for i in stmt.kid {
                    if isinstance(i, uni.JsxElement) {
                        is_jsx_in_return = True;
                        break;
                    }
                }
            }
        }
    }
    params: list[es.Pattern] = [];
    destructure_stmts: list[es.Statement] = [];
    destructure_props: list[es.AssignmentProperty | es.RestElement] = [];
    if isinstance(nd.signature, uni.FuncSignature) and nd.signature.params {
        if is_jsx_in_return
        and not (
            len(nd.signature.params) == 1
            and nd.signature.params[0].name.sym_name == 'props'
        ) {
            params.append(es.Identifier(name="props"));
            for param in nd.signature.params {
                destructure_props.append(
                    self.sync_loc(
                        es.AssignmentProperty(
                            key=cast(es.Expression, param.gen.es_ast),
                            value=cast(es.Pattern, param.gen.es_ast),
                            shorthand=True,
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
            for param in nd.signature.params {
                if param.gen.es_ast {
                    params.append(cast(es.Pattern, param.gen.es_ast));
                }
            }
        }
    }
    inner = (
        nd.body.body if isinstance(nd.body, uni.ImplDef) else self._get_body_inner(nd)
    );
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

"""Ensure ImplDef body is properly parented for traversal."""
impl EsastGenPass.enter_ability(nd: uni.Ability) -> None {
    if isinstance(nd.body, uni.ImplDef) and (nd.body not in nd.kid) {
        nd.body.parent = nd;
        nd.kid.append(nd.body);
    }
    self.reactive_vars_stack.append(self.reactive_vars);
    self.reactive_vars = dict(self.reactive_vars);
}

"""Process enum declaration as an object."""
impl EsastGenPass.exit_enum(nd: uni.Enum) -> None {
    if nd.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub {
            self.client_manifest.exports.append(nd.name.sym_name);
        }
    }
    properties: list[(es.Property | es.SpreadElement)] = [];
    inner = (
        nd.body.body if isinstance(nd.body, uni.ImplDef) else self._get_body_inner(nd)
    );
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

"""Process type alias - no runtime JS code needed."""
impl EsastGenPass.exit_type_alias(nd: uni.TypeAlias) -> None {
    nd.gen.es_ast = [];
}

"""Process type param - no runtime JS code needed."""
impl EsastGenPass.exit_type_param(nd: uni.TypeParam) -> None {
    nd.gen.es_ast = [];
}

"""Process archetype (class) declaration."""
impl EsastGenPass.exit_archetype(nd: uni.Archetype) -> None {
    if nd.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub {
            self.client_manifest.exports.append(nd.name.sym_name);
        }
    }
    body_stmts: list[es.MethodDefinition | es.PropertyDefinition | es.StaticBlock] = [];
    has_members: list[uni.ArchHas] = [];
    inner = (
        nd.body.body if isinstance(nd.body, uni.ImplDef) else self._get_body_inner(nd)
    );
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
                    stmt.gen.es_ast,
                    (es.MethodDefinition, es.PropertyDefinition, es.StaticBlock)
                )
            ) {
                body_stmts.append(stmt.gen.es_ast);
            }
        }
    }
    if ((nd.arch_type.name == Tok.KW_OBJECT) and has_members) {
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
                                es.Identifier(name=var.name.sym_name),
                                jac_node=var.name
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
    if nd.base_classes {
        base = nd.base_classes[0];
        if base.gen.es_ast {
            super_class = cast(es.Expression, base.gen.es_ast);
        }
    }
    class_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);
    class_decl = self.sync_loc(
        es.ClassDeclaration(id=class_id, superClass=super_class, body=class_body),
        jac_node=nd
    );
    nd.gen.es_ast = class_decl;
}

"""Process import statement."""
impl EsastGenPass.exit_import(nd: uni.Import) -> None {
    # Only process client-side imports for JavaScript generation
    if nd.code_context != CodeContext.CLIENT {
        # Server-side import (sv keyword or default) - skip JS generation
        return;
    }
    if (nd.from_loc and nd.items) {
        resolved_path = nd.from_loc.resolve_relative_path();
        import_key = nd.from_loc.dot_path_str;
        self.client_manifest.imports[import_key] = resolved_path;
        self.client_manifest.has_client = True;
        # Prepend dot for local Jac modules to make them relative imports in JS
        # Skip for @jac/ prefixed imports (built-in runtime modules)
        import_path = nd.from_loc.dot_path_str;
        is_jac_runtime = import_path.startswith('@jac/');
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
        # Prepend dot for local Jac modules to make them relative imports in JS
        import_path = import_key;
        if resolved_path.endswith('.jac') and not import_path.startswith('.') {
            import_path = '.' + import_path;
        }
        js_import_path = convert_to_js_import_path(import_path);
    } else {
        # No valid import to process
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

"""Process SubTag node."""
impl EsastGenPass.exit_sub_tag(nd: uni.SubTag[uni.T]) -> None {
    if nd.tag.gen.es_ast {
        nd.gen.es_ast = nd.tag.gen.es_ast;
    }
}

"""Recursively populate client manifest from module declarations."""
impl EsastGenPass._populate_client_manifest(nd: uni.Module) -> None {
    for item in nd.gen.client_manifest.exports {
        self.client_manifest.exports.append(item);
    }
    for item in nd.gen.client_manifest.globals {
        self.client_manifest.globals.append(item);
    }
    for (import_key, resolved_path) in nd.gen.client_manifest.imports.items() {
        self.client_manifest.imports[import_key] = resolved_path;
    }
    for sub_mod in nd.gen.client_manifest.params {
        self.client_manifest.params[sub_mod] = nd.gen.client_manifest.params[sub_mod];
    }
}

"""Populate client manifest from module declarations."""
impl EsastGenPass.populate_client_manifest(nd: uni.Module) -> None {
    for mod in nd.impl_mod {
        self._populate_client_manifest(mod);
    }
}

"""Process module node."""
impl EsastGenPass.exit_module(nd: uni.Module) -> None {
    body: list[(es.Statement | es.ModuleDeclaration)] = [];
    body.extend(self.imports);
    for mod in nd.impl_mod {
        if (mod.gen.es_ast and isinstance(mod.gen.es_ast, es.Program)) {
            for import_decl in mod.gen.es_ast.body {
                if isinstance(import_decl, es.ImportDeclaration) {
                    body.append(import_decl);
                }
            }
        }
    }
    scope = self.scope_map.get(nd);
    if (scope and scope.hoisted) {
        hoisted = list(scope.hoisted);
        scope.hoisted.clear();
        body.extend(hoisted);
    }
    # Inject _jac runtime object if any primitive emitter produced _jac.* calls
    if self.needs_jac_runtime {
        _jac_rt_mod = __import__(
            "jaclang.compiler.passes.ecmascript.jac_runtime_js",
            fromlist=["JAC_RUNTIME_JS_OBJECT"]
        );
        jac_rt_decl = es.VariableDeclaration(
            declarations=[
                es.VariableDeclarator(
                    id=es.Identifier(name='_jac'),
                    init=es.Identifier(name=_jac_rt_mod.JAC_RUNTIME_JS_OBJECT)
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
            if getattr(stmt, 'code_context', CodeContext.CLIENT) == CodeContext.CLIENT {
                client_items.append(cast(es.Statement, stmt.gen.es_ast));
            } else {
                ;
            }
        }
    }
    target_body = client_items or fallback_items;
    body.extend(self._flatten_ast_list(target_body));
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
        comprehensive_export = es.ExportNamedDeclaration(
            declaration=None, specifiers=export_specifiers, source=None
        );
        body.append(comprehensive_export);
    }
    program = self.sync_loc(es.Program(body=body, sourceType='module'), jac_node=nd);
    nd.gen.es_ast = program;
    nd.gen.js = es_to_js(nd.gen.es_ast);
    nd.gen.client_manifest = self.client_manifest;
}

"""Construct a block statement from a Jac scope node."""
impl EsastGenPass._build_block_statement(
    scope_node: uni.UniScopeNode, body_nodes: (Sequence[uni.UniNode] | None)
) -> es.BlockStatement {
    statements = self._collect_stmt_body(body_nodes);
    statements = self._prepend_hoisted(scope_node, statements);
    return self.sync_loc(es.BlockStatement(body=statements), jac_node=scope_node);
}

"""
Return an existing ESTree node or synthesize a fallback.

        The return type matches the default_factory's return type. This assumes
        that if node.gen.es_ast exists, it will be compatible with the expected type.
"""
impl EsastGenPass._get_ast_or_default(
    nd: (uni.UniNode | None), default_factory: Callable[([(uni.UniNode | None)], _T)]
) -> _T {
    if (nd and getattr(nd.gen, 'es_ast', None)) {
        generated = nd.gen.es_ast;
        if isinstance(generated, es.Node) {
            return cast(_T, generated);
        }
    }
    fallback = default_factory(nd);
    jac_ref = nd if (nd is not None) else self.cur_node;
    return self.sync_loc(fallback, jac_node=jac_ref);
}

"""Convert a sequence of Jac statements into ESTree statements."""
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
        generated = getattr(stmt.gen, 'es_ast', None);
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

"""Emit the await __jacSpawn(...) expression for a spawn call."""
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

"""Split a spawn expression into walker and target parts."""
impl EsastGenPass._prepare_spawn_call(
    nd: uni.BinaryExpr, left_expr: es.Expression, right_expr: es.Expression
) -> (SpawnCallParts | None) {
    left_walker = self._resolve_spawn_walker(nd.left, left_expr);
    right_walker = self._resolve_spawn_walker(nd.right, right_expr);
    if (left_walker and right_walker) {
        self.log_warning(
            'Both sides of spawn look like walker instantiations; defaulting to the right-hand expression.',
            node_override=nd
        );
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
    self.log_error(
        'Spawn expressions must include a walker constructor on one side.',
        node_override=nd
    );
    return None;
}

"""Convert a spawn target expression into a runtime-ready reference."""
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

"""Check if an expression refers to the root node."""
impl EsastGenPass._is_root_reference(expr: uni.Expr) -> bool {
    if (isinstance(expr, uni.Name) and (expr.sym_name == 'root')) {
        return True;
    }
    return bool((isinstance(expr, uni.SpecialVarRef) and (expr.sym_name == 'root')));
}

"""Return walker call info if the expression instantiates a walker."""
impl EsastGenPass._resolve_spawn_walker(
    expr: uni.Expr, es_expr: es.Expression
) -> (SpawnWalkerInfo | None) {
    (stripped_node, _) = self._strip_spawn_await(expr, es_expr);
    if not isinstance(stripped_node, uni.FuncCall) {
        return None;
    }
    target_symbol = self._resolve_expr_symbol(stripped_node.target);
    # If symbol is found and is a walker, use it
    if target_symbol and (target_symbol.sym_type == SymbolType.WALKER_ARCH) {
        walker_name = target_symbol.sym_name;
        fields_obj = self._build_spawn_arg_object(stripped_node, target_symbol);
        return SpawnWalkerInfo(
            call_node=stripped_node, walker_name=walker_name, fields_object=fields_obj
        );
    }
    # Allow function calls that look like walker constructors (server walkers from sv imports)
    # These are validated at runtime via API calls
    if isinstance(stripped_node.target, uni.Name) {
        walker_name = stripped_node.target.sym_name;
        fields_obj = self._build_spawn_arg_object(stripped_node, None);
        return SpawnWalkerInfo(
            call_node=stripped_node, walker_name=walker_name, fields_object=fields_obj
        );
    }
    return None;
}

"""Convert walker constructor arguments into a JSON payload."""
impl EsastGenPass._build_spawn_arg_object(
    call_node: uni.FuncCall, walker_symbol: (uni.Symbol | None)
) -> es.ObjectExpression {
    ordered_fields = self._collect_walker_field_names(walker_symbol);
    properties: list[(es.Property | es.SpreadElement)] = [];
    positional_index = 0;
    for param in call_node.params {
        if isinstance(param, uni.KWPair) {
            if param.key {
                key_expr = self.sync_loc(
                    es.Literal(value=param.key.sym_name), jac_node=param.key
                );
                value_expr = self._expr_from_node(param.value);
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
                    self.sync_loc(
                        es.SpreadElement(argument=spread_arg), jac_node=param
                    )
                );
            }
            continue;
        }
        key_name = ordered_fields[positional_index]
        if (positional_index < len(ordered_fields))
        else f"arg{positional_index}";
        if (positional_index >= len(ordered_fields)) {
            self.log_warning(
                'Walker spawn has more positional arguments than fields.',
                node_override=param
            );
        }
        positional_index += 1;
        key_expr = self.sync_loc(es.Literal(value=key_name), jac_node=param);
        value_expr = self._expr_from_node(param);
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

"""Return an expression ESTree node, synthesizing a literal if needed."""
impl EsastGenPass._expr_from_node(
    nd: (uni.UniNode | None), `default: LiteralValue = None
) -> es.Expression {
    generated = self._get_ast_or_default(
        nd, default_factory=lambda src: Any : es.Literal(value=`default)
    );
    if isinstance(generated, es.Expression) {
        return generated;
    }
    self.log_error('Expected expression in spawn argument.', node_override=nd);
    return self.sync_loc(es.Literal(value=`default), jac_node=(nd or self.cur_node));
}

"""Collect walker has-var field names for positional argument mapping."""
impl EsastGenPass._collect_walker_field_names(
    walker_symbol: (uni.Symbol | None)
) -> list[str] {
    if not walker_symbol {
        return [];
    }
    decl_owner = walker_symbol.decl.name_of;
    if (
        isinstance(decl_owner, uni.Archetype)
        and (decl_owner.arch_type.name == Tok.KW_WALKER)
    ) {
        return [field.sym_name for field in decl_owner.get_has_vars()];
    }
    return [];
}

"""Get the main module of the program."""
impl EsastGenPass.get_main_mod -> uni.Module {
    main_mod_path = self.ir_in.annexable_by or self.ir_in.loc.mod_path;
    mod = self.prog.mod.hub.get(main_mod_path);
    if not isinstance(mod, uni.Module) {
        self.log_error('Expected main module to be a Module node.');
    }
    return mod;
}

"""Search for a symbol in the main module."""
impl EsastGenPass.search_sym_in_main_mod(expr: uni.Expr) -> (uni.Symbol | None) {
    if not isinstance(expr, uni.Name) {
        return None;
    }
    main_mod = self.get_main_mod();
    return main_mod and main_mod.lookup(expr.sym_name);
}

"""Resolve a symbol from an expression (handles dotted access)."""
impl EsastGenPass._resolve_expr_symbol(expr: uni.Expr) -> (uni.Symbol | None) {
    if (isinstance(expr, uni.AstSymbolNode) and expr.sym) {
        return expr.sym;
    }
    if isinstance(expr, uni.AtomTrailer) {
        attrs = expr.as_attr_list;
        if attrs {
            return attrs[-1].sym;
        }
    }
    if (sym := self.search_sym_in_main_mod(expr)) {
        return sym;
    }
    return None;
}

"""Remove Jac/ES await wrappers for spawn analysis."""
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

"""Insert hoisted declarations, if any, ahead of the given statements."""
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

"""Hoist a declaration for identifiers introduced mid-expression (e.g., walrus)."""
impl EsastGenPass._ensure_identifier_declared(name: str, jac_node: uni.UniNode) -> None {
    scope = self._current_scope();
    if (not scope or (name in scope.declared)) {
        return;
    }
    ident = self.sync_loc(es.Identifier(name=name), jac_node=jac_node);
    declarator = self.sync_loc(
        es.VariableDeclarator(id=ident, `init=None), jac_node=jac_node
    );
    decl = self.sync_loc(
        es.VariableDeclaration(declarations=[declarator], kind='let'),
        jac_node=jac_node
    );
    scope.hoisted.append(decl);
    scope.declared.add(name);
}

"""Mark a name as declared within the current scope."""
impl EsastGenPass._register_declaration(name: str) -> None {
    scope = self._current_scope();
    if scope {
        scope.declared.add(name);
    }
}

"""
Check if a name is declared in the current scope or any parent scope.

        This is essential for proper closure support - we need to avoid re-declaring
        variables that exist in parent scopes when generating nested functions.
"""
impl EsastGenPass._is_declared_in_any_scope(name: str) -> bool {
    return any((name in scope.declared) for scope in reversed(self.scope_stack));
}

"""Check if a name is already declared in the active scope."""
impl EsastGenPass._is_declared_in_current_scope(name: str) -> bool {
    scope = self._current_scope();
    return (name in scope.declared) if scope else False;
}

"""Get the scope currently being populated."""
impl EsastGenPass._current_scope -> (ScopeInfo | None) {
    return self.scope_stack[-1] if self.scope_stack else None;
}

"""Exit a lexical scope."""
impl EsastGenPass._pop_scope(nd: uni.UniScopeNode) -> None {
    if (self.scope_stack and (self.scope_stack[-1].nd is nd)) {
        self.scope_stack.pop();
    }
    self.scope_map.pop(nd, None);
}

"""Enter a new lexical scope."""
impl EsastGenPass._push_scope(nd: uni.UniScopeNode) -> None {
    info = ScopeInfo(nd=nd);
    self.scope_stack.append(info);
    self.scope_map[nd] = info;
}

"""Sync source locations from Jac node to ES node."""
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

"""Exit node."""
impl EsastGenPass.exit_node(nd: uni.UniNode) -> None {
    if (
        isinstance(nd, uni.ElementStmt)
        and isinstance(nd, uni.ContextAwareNode)
        and nd.code_context != CodeContext.CLIENT
        and ((nd.parent is None) or isinstance(nd.parent, uni.Module))
    ) {
        return;
    }
    super.exit_node(nd);
    if isinstance(nd, uni.UniScopeNode) {
        self._pop_scope(nd);
    }
}

"""Enter node."""
impl EsastGenPass.enter_node(nd: uni.UniNode) -> None {
    # Prune NativeBlocks from ECMAScript generation
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
        self.prune();
        return;
    }
    if isinstance(nd, uni.UniScopeNode) {
        self._push_scope(nd);
    }
    if nd.gen.es_ast {
        self.prune();
        return;
    }
    super.enter_node(nd);
}

"""Initialize the pass."""
impl EsastGenPass.before_pass -> None {
    import from jaclang.jac0core.codeinfo { ClientManifest }
    self.child_passes: list[EsastGenPass] = self._init_child_passes(EsastGenPass);
    self.imports: list[es.ImportDeclaration] = [];
    self.exports: list[es.ExportNamedDeclaration] = [];
    self.scope_stack: list[ScopeInfo] = [];
    self.scope_map: dict[(uni.UniScopeNode, ScopeInfo)] = {};
    self.client_manifest = ClientManifest();
    self.jsx_processor = EsJsxProcessor(self);
    # Track reactive state variables: maps var_name -> setter_name (e.g., "count" -> "setCount")
    self.reactive_vars: dict[str, str] = {};
    # Stack to save/restore reactive_vars per function boundary
    self.reactive_vars_stack: list[dict[str, str]] = [];
    # Track if useState import has been auto-injected to avoid duplicates
    self.has_injected_usestate: bool = False;
    # Track if __jacCallFunction import has been auto-injected to avoid duplicates
    self.has_injected_jac_call_function: bool = False;
    # Track if useEffect import has been auto-injected to avoid duplicates
    self.has_injected_useeffect: bool = False;
    # Track whether generated code uses _jac runtime (primitive emitter produced _jac.* calls)
    self.needs_jac_runtime: bool = False;
    # Primitive emitter instances for codegen dispatch (lazily initialized to avoid circular imports)
    self._primitive_emitters: dict[str, object] | None = None;
    self._builtin_emitter: object | None = None;
    self._primitive_type_names: set[str] = {"int","float","complex","str","bytes","list","dict","set","frozenset","tuple","range","bool"};
    self._emitter_builtins: set[str] = {"print","input","len","abs","round","min","max","sum","sorted","reversed","enumerate","zip","map","filter","any","all","isinstance","issubclass","type","id","hash","repr","chr","ord","hex","oct","bin","pow","divmod","iter","next","callable","getattr","setattr","hasattr","delattr","vars","dir","open","format","ascii","str","int","float","bool","list","dict","set","tuple","frozenset","bytes","complex","range","slice","bytearray"};
}
