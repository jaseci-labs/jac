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
            return <>tuple(values);
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
impl EsastGenPass.exit_semi(<>node: uni.Semi) -> None {
    ;
}

"""Process token."""
impl EsastGenPass.exit_token(<>node: uni.Token) -> None {
    ;
}

"""Process test as a function."""
impl EsastGenPass.exit_test(<>node: uni.Test) -> None {
    params: list[es.Pattern] = [];
    body_stmts: list[es.Statement] = [];
    if <>node.body {
        for stmt in <>node.body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, <>list) {
                    body_stmts.extend(cast(es.Statement, s) for s in stmt.gen.es_ast);
                } else {
                    body_stmts.append(cast(es.Statement, stmt.gen.es_ast));
                }
            }
        }
    }
    body_stmts = self._prepend_hoisted(<>node, body_stmts);
    block = self.sync_loc(es.BlockStatement(body=body_stmts), jac_node=<>node);
    func_id = self.sync_loc(
        es.Identifier(name=<>node.name.sym_name), jac_node=<>node.name
    );
    func_decl = self.sync_loc(
        es.FunctionDeclaration(id=func_id, params=params, body=block), jac_node=<>node
    );
    <>node.gen.es_ast = func_decl;
}

"""Process client block (cl { ... })."""
impl EsastGenPass.exit_client_block(<>node: uni.ClientBlock) -> None {
    body_stmts: list[es.Statement] = [];
    if <>node.body {
        for stmt in <>node.body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, <>list) {
                    body_stmts.extend(cast(es.Statement, s) for s in stmt.gen.es_ast);
                } else {
                    body_stmts.append(cast(es.Statement, stmt.gen.es_ast));
                }
            }
        }
    }
    <>node.gen.es_ast = body_stmts;
}

"""Process module code (with entry block)."""
impl EsastGenPass.exit_module_code(<>node: uni.ModuleCode) -> None {
    body_stmts: list[es.Statement] = [];
    if <>node.body {
        for stmt in <>node.body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, <>list) {
                    body_stmts.extend(cast(es.Statement, s) for s in stmt.gen.es_ast);
                } else {
                    body_stmts.append(cast(es.Statement, stmt.gen.es_ast));
                }
            }
        }
    }
    <>node.gen.es_ast = body_stmts;
}

"""Process non-local statement."""
impl EsastGenPass.exit_non_local_stmt(<>node: uni.NonLocalStmt) -> None {
    <>node.gen.es_ast = [];
}

"""Process global variables."""
impl EsastGenPass.exit_global_vars(<>node: uni.GlobalVars) -> None {
    if <>node.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        for assignment in <>node.assignments {
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
    statements: list[(es.Statement | es.ModuleDeclaration)] = [];
    is_pub = <>node.access and (<>node.access.tag.name == Tok.KW_PUB);
    for assignment in <>node.assignments {
        if assignment.gen.es_ast {
            stmt = assignment.gen.es_ast;
            if (
                isinstance(stmt, es.VariableDeclaration)
                and <>node.is_frozen
                and (stmt.kind != 'const')
            ) {
                stmt.kind = 'const';
            }
            if (is_pub and isinstance(stmt, es.VariableDeclaration)) {
                export_decl = self.sync_loc(
                    es.ExportNamedDeclaration(declaration=stmt), jac_node=<>node
                );
                statements.append(export_decl);
            } else {
                statements.append(cast(es.Statement, stmt));
            }
        }
    }
    <>node.gen.es_ast = statements;
}

"""Process name/identifier."""
impl EsastGenPass.exit_name(<>node: uni.Name) -> None {
    name_map = {'None': 'null', 'True': 'true', 'False': 'false', 'self': 'this'};
    name = name_map.get(<>node.sym_name, <>node.sym_name);
    identifier = self.sync_loc(es.Identifier(name=name), jac_node=<>node);
    <>node.gen.es_ast = identifier;
}

"""Process null/None literal."""
impl EsastGenPass.exit_null(<>node: uni.Null) -> None {
    null_lit = self.sync_loc(es.Literal(value=None, raw='null'), jac_node=<>node);
    <>node.gen.es_ast = null_lit;
}

"""Process await expression."""
impl EsastGenPass.exit_await_expr(<>node: uni.AwaitExpr) -> None {
    argument = cast(
        es.Expression,
        <>node.target.gen.es_ast
        or self.sync_loc(es.Identifier(name='undefined'), jac_node=<>node.target)
    );
    await_expr = self.sync_loc(es.AwaitExpression(argument=argument), jac_node=<>node);
    <>node.gen.es_ast = await_expr;
}

"""Process ternary expression."""
impl EsastGenPass.exit_if_else_expr(<>node: uni.IfElseExpr) -> None {
    <>test = cast(
        es.Expression,
        <>node.condition.gen.es_ast
        or self.sync_loc(es.Identifier(name='condition'), jac_node=<>node.condition)
    );
    consequent = cast(
        es.Expression,
        <>node.value.gen.es_ast
        or self.sync_loc(es.Identifier(name='value'), jac_node=<>node.value)
    );
    alternate = cast(
        es.Expression,
        <>node.else_value.gen.es_ast
        or self.sync_loc(es.Identifier(name='alternate'), jac_node=<>node.else_value)
    );
    cond_expr = self.sync_loc(
        es.ConditionalExpression(
            <>test=<>test, consequent=consequent, alternate=alternate
        ),
        jac_node=<>node
    );
    <>node.gen.es_ast = cond_expr;
}

"""Process f-string literal as template literal."""
impl EsastGenPass.exit_f_string(<>node: uni.FString) -> None {
    quasis: list[es.TemplateElement] = [];
    expressions: list[es.Expression] = [];
    for (i, part) in enumerate(<>node.parts) {
        is_last = i == (len(<>node.parts) - 1);
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
            if ((i == 0) or not isinstance(<>node.parts[(i - 1)], uni.String)) {
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
                jac_node=<>node
            )
        );
    }
    while (len(quasis) < (len(expressions) + 1)) {
        quasis.append(
            self.sync_loc(
                es.TemplateElement(tail=True, value={'cooked': '', 'raw': ''}),
                jac_node=<>node
            )
        );
    }
    template_lit = self.sync_loc(
        es.TemplateLiteral(quasis=quasis, expressions=expressions), jac_node=<>node
    );
    <>node.gen.es_ast = template_lit;
}

"""Process formatted value in f-string."""
impl EsastGenPass.exit_formatted_value(<>node: uni.FormattedValue) -> None {
    expr = <>node.format_part.gen.es_ast
    or self.sync_loc(es.Literal(value=''), jac_node=<>node.format_part);
    <>node.gen.es_ast = expr;
}

"""Process string literal."""
impl EsastGenPass.exit_string(<>node: uni.String) -> None {
    value = <>node.value;
    if value.startswith(('"""', "'''")) {
        value = value[3:-3];
    } elif value.startswith(('"', "'")) {
        value = value[1:-1];
    }
    raw_value = <>node.value;
    if isinstance(value, str) {
        raw_value = json.dumps(value);
    }
    str_lit = self.sync_loc(es.Literal(value=value, raw=raw_value), jac_node=<>node);
    <>node.gen.es_ast = str_lit;
}

"""Process multi-string literal."""
impl EsastGenPass.exit_multi_string(<>node: uni.MultiString) -> None {
    if not <>node.strings {
        null_lit = self.sync_loc(es.Literal(value='', raw='""'), jac_node=<>node);
        <>node.gen.es_ast = null_lit;
        return;
    }
    if (len(<>node.strings) == 1) {
        string_node = <>node.strings[0];
        if string_node.gen.es_ast {
            <>node.gen.es_ast = string_node.gen.es_ast;
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
            <>node.gen.es_ast = str_lit;
        } else {
            <>node.gen.es_ast = self.sync_loc(es.Literal(value=''), jac_node=<>node);
        }
        return;
    }
    parts = [];
    for string_node in <>node.strings {
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
        <>node.gen.es_ast = self.sync_loc(es.Literal(value=''), jac_node=<>node);
        return;
    }
    result: es.Expression = cast(es.Expression, parts[0]);
    for part in parts[1:] {
        result = self.sync_loc(
            es.BinaryExpression(
                operator='+', left=result, right=cast(es.Expression, part)
            ),
            jac_node=<>node
        );
    }
    <>node.gen.es_ast = result;
}

"""Process float literal."""
impl EsastGenPass.exit_float(<>node: uni.Float) -> None {
    float_lit = self.sync_loc(
        es.Literal(value=float(<>node.value), raw=<>node.value), jac_node=<>node
    );
    <>node.gen.es_ast = float_lit;
}

"""Process integer literal."""
impl EsastGenPass.exit_int(<>node: uni.Int) -> None {
    int_lit = self.sync_loc(
        es.Literal(value=int(<>node.value, 0), raw=<>node.value), jac_node=<>node
    );
    <>node.gen.es_ast = int_lit;
}

"""Process boolean literal."""
impl EsastGenPass.exit_bool(<>node: uni.Bool) -> None {
    value = <>node.value.lower() == 'true';
    raw_value = 'true' if value else 'false';
    bool_lit = self.sync_loc(es.Literal(value=value, raw=raw_value), jac_node=<>node);
    <>node.gen.es_ast = bool_lit;
}

"""Process list comprehension."""
impl EsastGenPass.exit_inner_compr(<>node: uni.InnerCompr) -> None {
    <>node.gen.es_ast = self.sync_loc(es.ArrayExpression(elements=[]), jac_node=<>node);
}

"""Process key-value pair."""
impl EsastGenPass.exit_k_v_pair(<>node: uni.KVPair) -> None {
    ;
}

"""Process dictionary literal."""
impl EsastGenPass.exit_dict_val(<>node: uni.DictVal) -> None {
    properties: list[(es.Property | es.SpreadElement)] = [];
    for kv_pair in <>node.kv_pairs {
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
    obj_expr = self.sync_loc(
        es.ObjectExpression(properties=properties), jac_node=<>node
    );
    <>node.gen.es_ast = obj_expr;
}

"""Process tuple as array."""
impl EsastGenPass.exit_tuple_val(<>node: uni.TupleVal) -> None {
    elements: list[es.Expression | es.SpreadElement | None] = [];
    for item in <>node.values {
        if item.gen.es_ast {
            elements.append(cast(es.Expression, item.gen.es_ast));
        }
    }
    array_expr = self.sync_loc(es.ArrayExpression(elements=elements), jac_node=<>node);
    <>node.gen.es_ast = array_expr;
}

"""Process set literal as new Set()."""
impl EsastGenPass.exit_set_val(<>node: uni.SetVal) -> None {
    elements: list[es.Expression | es.SpreadElement | None] = [];
    for item in <>node.values {
        if item.gen.es_ast {
            elements.append(cast(es.Expression, item.gen.es_ast));
        }
    }
    set_expr = self.sync_loc(
        es.NewExpression(
            callee=self.sync_loc(es.Identifier(name='Set'), jac_node=<>node),
            arguments=[
                self.sync_loc(es.ArrayExpression(elements=elements), jac_node=<>node)
            ]
        ),
        jac_node=<>node
    );
    <>node.gen.es_ast = set_expr;
}

"""Process list literal."""
impl EsastGenPass.exit_list_val(<>node: uni.ListVal) -> None {
    elements: list[es.Expression | es.SpreadElement | None] = [];
    for item in <>node.values {
        if item.gen.es_ast {
            elements.append(cast(es.Expression, item.gen.es_ast));
        }
    }
    array_expr = self.sync_loc(es.ArrayExpression(elements=elements), jac_node=<>node);
    <>node.gen.es_ast = array_expr;
}

"""Process parenthesized atom."""
impl EsastGenPass.exit_atom_unit(<>node: uni.AtomUnit) -> None {
    if (isinstance(<>node.value, uni.Ability) and <>node.value.gen.es_ast) {
        func_decl = <>node.value.gen.es_ast;
        if isinstance(func_decl, es.FunctionDeclaration) {
            func_expr = self.sync_loc(
                es.FunctionExpression(
                    id=func_decl.id,
                    params=func_decl.params,
                    body=func_decl.body,
                    async_=func_decl.async_
                ),
                jac_node=<>node.value
            );
            <>node.gen.es_ast = func_expr;
        } else {
            <>node.gen.es_ast = <>node.value.gen.es_ast;
        }
    } elif (<>node.value and <>node.value.gen.es_ast) {
        <>node.gen.es_ast = <>node.value.gen.es_ast;
    } else {
        <>node.gen.es_ast = self.sync_loc(es.Literal(value=None), jac_node=<>node);
    }
}

"""Process lambda expression as arrow function."""
impl EsastGenPass.exit_lambda_expr(<>node: uni.LambdaExpr) -> None {
    params: list[es.Pattern] = [];
    if isinstance(<>node.signature, uni.FuncSignature) {
        for param in <>node.signature.params {
            if param.gen.es_ast {
                params.append(cast(es.Pattern, param.gen.es_ast));
            }
        }
    }
    if isinstance(<>node.body, <>list) {
        body_stmts: list[es.Statement] = [];
        for stmt in <>node.body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, <>list) {
                    body_stmts.extend(stmt.gen.es_ast);
                } else {
                    body_stmts.append(stmt.gen.es_ast);
                }
            }
        }
        body_stmts = self._prepend_hoisted(<>node, body_stmts);
        block_stmt = self.sync_loc(es.BlockStatement(body=body_stmts), jac_node=<>node);
        arrow_func = self.sync_loc(
            es.ArrowFunctionExpression(params=params, body=block_stmt, async_=False),
            jac_node=<>node
        );
        <>node.gen.es_ast = arrow_func;
    } elif isinstance(<>node.body, uni.Expr) {
        body_expr = cast(
            es.Expression,
            <>node.body.gen.es_ast
            or self.sync_loc(es.Literal(value=None), jac_node=<>node.body)
        );
        arrow_func = self.sync_loc(
            es.ArrowFunctionExpression(params=params, body=body_expr, async_=False),
            jac_node=<>node
        );
        <>node.gen.es_ast = arrow_func;
    }
}

"""Process attribute access."""
impl EsastGenPass.exit_atom_trailer(<>node: uni.AtomTrailer) -> None {
    <>obj = cast(
        es.Expression,
        <>node.target.gen.es_ast
        or self.sync_loc(es.Identifier(name='obj'), jac_node=<>node.target)
    );
    if (<>node.right and <>node.right.gen.es_ast) {
        if isinstance(<>node.right, uni.Name) {
            prop = self.sync_loc(
                es.Identifier(name=<>node.right.sym_name), jac_node=<>node.right
            );
            member_expr = self.sync_loc(
                es.MemberExpression(object=<>obj, property=prop, computed=False),
                jac_node=<>node
            );
            <>node.gen.es_ast = member_expr;
        } elif isinstance(<>node.right, uni.IndexSlice) {
            slice_info = <>node.right.gen.es_ast;
            if isinstance(slice_info, es.SliceInfo) {
                start = cast(
                    es.Expression,
                    (
                        slice_info.start
                        or self.sync_loc(es.Literal(value=0), jac_node=<>node)
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
                                object=<>obj,
                                property=self.sync_loc(
                                    es.Identifier(name='slice'), jac_node=<>node
                                ),
                                computed=False
                            ),
                            jac_node=<>node
                        ),
                        arguments=slice_args
                    ),
                    jac_node=<>node
                );
                <>node.gen.es_ast = slice_call;
            } elif isinstance(slice_info, es.IndexInfo) {
                idx = cast(
                    es.Expression,
                    (
                        slice_info.value
                        or self.sync_loc(es.Literal(value=0), jac_node=<>node)
                    )
                );
                member_expr = self.sync_loc(
                    es.MemberExpression(object=<>obj, property=idx, computed=True),
                    jac_node=<>node
                );
                <>node.gen.es_ast = member_expr;
            } else {
                <>node.gen.es_ast = <>obj;
            }
        } else {
            <>node.gen.es_ast = <>node.right.gen.es_ast;
        }
    }
}

"""Process special variable reference."""
impl EsastGenPass.exit_special_var_ref(<>node: uni.SpecialVarRef) -> None {
    self.exit_name(<>node);
}

"""Process index/slice - just store the slice info, actual member access is handled by AtomTrailer."""
impl EsastGenPass.exit_index_slice(<>node: uni.IndexSlice) -> None {
    if (<>node.slices and (len(<>node.slices) > 0)) {
        first_slice = <>node.slices[0];
        if <>node.is_range {
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
            <>node.gen.es_ast = es.SliceInfo(start=start_ast, stop=stop_ast);
        } else {
            value_ast = first_slice.start.gen.es_ast
            if (
                first_slice.start
                and first_slice.start.gen.es_ast
                and isinstance(first_slice.start.gen.es_ast, es.Node)
            )
            else self.sync_loc(es.Literal(value=0), jac_node=<>node);
            <>node.gen.es_ast = es.IndexInfo(value=value_ast);
        }
    } else {
        <>node.gen.es_ast = None;
    }
}

"""Process function call."""
impl EsastGenPass.exit_func_call(<>node: uni.FuncCall) -> None {
    import from jaclang.compiler.type_system { types as jtypes }
    target_is_type = False;
    if isinstance(<>node.target, (uni.Name, uni.BuiltinType)) {
        target_name = getattr(<>node.target, 'sym_name', None);
        if (target_name == 'type') {
            target_is_type = True;
        }
    }
    args: list[(es.Expression | es.SpreadElement)] = [];
    props: list[(es.Property | es.SpreadElement)] = [];
    for param in <>node.params {
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
    if (target_is_type and (len(args) == 1) and isinstance(args[0], es.Expression)) {
        typeof_expr = self.sync_loc(
            es.UnaryExpression(operator='typeof', prefix=True, argument=args[0]),
            jac_node=<>node
        );
        <>node.gen.es_ast = typeof_expr;
        return;
    }
    if (<>node.in_client_context() and isinstance(<>node.target, uni.Name)) {
        target_sym = getattr(<>node.target, 'sym', None);
        if (target_sym and target_sym.defn) {
            defn_node = target_sym.defn[0];
            if isinstance(defn_node.parent, uni.Ability) {
                ability_node = defn_node.parent;
                is_server_func = ability_node.code_context != CodeContext.CLIENT;
                if is_server_func {
                    func_name = <>node.target.sym_name;
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
                                es.Literal(value=param_names[i]), jac_node=<>node
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
                                    jac_node=<>node
                                )
                            );
                        }
                    }
                    args_obj = self.sync_loc(
                        es.ObjectExpression(properties=props), jac_node=<>node
                    );
                    call_expr = self.sync_loc(
                        es.AwaitExpression(
                            argument=self.sync_loc(
                                es.CallExpression(
                                    callee=self.sync_loc(
                                        es.Identifier(name='__jacCallFunction'),
                                        jac_node=<>node
                                    ),
                                    arguments=[
                                        self.sync_loc(
                                            es.Literal(value=func_name),
                                            jac_node=<>node
                                        ),
                                        args_obj
                                    ]
                                ),
                                jac_node=<>node
                            )
                        ),
                        jac_node=<>node
                    );
                    <>node.gen.es_ast = call_expr;
                    return;
                }
            }
        }
    }
    callee = <>node.target.gen.es_ast
    or self.sync_loc(es.Identifier(name='func'), jac_node=<>node.target);
    if (
        isinstance(callee, es.MemberExpression)
        and isinstance(callee.property, es.Identifier)
    ) {
        method_map = {
            'lower': 'toLowerCase',
            'upper': 'toUpperCase',
            'startswith': 'startsWith',
            'endswith': 'endsWith'
        };
        replacement = method_map.get(callee.property.name);
        if replacement {
            callee = self.sync_loc(
                es.MemberExpression(
                    object=callee.object,
                    property=self.sync_loc(
                        es.Identifier(name=replacement), jac_node=<>node
                    ),
                    computed=callee.computed
                ),
                jac_node=<>node
            );
        }
    }
    if isinstance(<>node.target, uni.Name) {
        callee_type = self.prog.get_type_evaluator().get_type_of_expression(
            <>node.target
        );
    } else {
        callee_type = None;
    }
    args_obj = self.sync_loc(es.ObjectExpression(properties=props), jac_node=<>node);
    callee_expr = cast(es.Expression, callee);
    call_args: list[(es.Expression | es.SpreadElement)] = [args_obj] if props else args;
    if (
        isinstance(callee_type, jtypes.ClassType) and isinstance(callee, es.Expression)
    ) {
        <>node.gen.es_ast = self.sync_loc(
            es.NewExpression(callee=callee_expr, arguments=call_args), jac_node=<>node
        );
    } else {
        <>node.gen.es_ast = self.sync_loc(
            es.CallExpression(callee=callee_expr, arguments=call_args), jac_node=<>node
        );
    }
}

"""Process assignment expression."""
impl EsastGenPass.exit_assignment(<>node: uni.Assignment) -> None {
    if not <>node.target {
        <>node.gen.es_ast = None;
        return;
    }
    value_expr = <>node.value.gen.es_ast
    if (<>node.value and <>node.value.gen.es_ast)
    else None;
    # Check for reactive variable assignment (transforms count = X to setCount(X))
    if len(<>node.target) == 1 and isinstance(<>node.target[0], uni.Name) {
        target_name = <>node.target[0].sym_name;
        if target_name in self.reactive_vars {
            setter_name = self.reactive_vars[target_name];
            # Get the value to pass to setter
            setter_arg: es.Expression;
            if <>node.aug_op {
                # For augmented assignment: count += 1 -> setCount(count + 1)
                aug_tok = Tok(<>node.aug_op.name)
                if (<>node.aug_op.name in Tok.__members__)
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
                    jac_node=<>node
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
                jac_node=<>node
            );
            expr_stmt = self.sync_loc(
                es.ExpressionStatement(expression=setter_call), jac_node=<>node
            );
            <>node.gen.es_ast = expr_stmt;
            return;
        }
    }
    if <>node.aug_op {
        (left, _, _) = self._convert_assignment_target(<>node.target[0]);
        aug_tok = Tok(<>node.aug_op.name)
        if (<>node.aug_op.name in Tok.__members__)
        else None;
        operator = ES_AUG_ASSIGN_OPS.get(aug_tok) if aug_tok else None;
        operator = operator or '=';
        right = cast(
            es.Expression,
            (
                value_expr
                or self._get_ast_or_default(
                    <>node.value,
                    default_factory=lambda _src: Any : es.Identifier(name='undefined')
                )
            )
        );
        assign_expr = self.sync_loc(
            es.AssignmentExpression(operator=operator, left=left, right=right),
            jac_node=<>node
        );
        expr_stmt = self.sync_loc(
            es.ExpressionStatement(expression=assign_expr), jac_node=<>node
        );
        <>node.gen.es_ast = expr_stmt;
        return;
    }
    targets_info: list[AssignmentTargetInfo] = [];
    for target_node in <>node.target {
        (left, reference, decl_name) = self._convert_assignment_target(target_node);
        pattern_names = self._collect_pattern_names(target_node);
        first_def = False;
        if isinstance(target_node, uni.Name) {
            first_def = self._is_name_first_definition(target_node);
        } elif pattern_names {
            first_def = <>any(
                self._is_name_first_definition(name_node)
                for (_, name_node) in pattern_names
            );
        }
        targets_info.append(
            AssignmentTargetInfo(
                <>node=target_node,
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
                <>node.value,
                default_factory=lambda _src: Any : es.Identifier(name='undefined')
            )
        )
    );
    for info in reversed(targets_info) {
        target_node = info.node;
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
            should_declare = <>any(
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
                    <>init=current_value if (value_expr is not None) else None
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
        <>node.gen.es_ast = statements[0];
    } else {
        <>node.gen.es_ast = statements;
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

"""Process unary expression."""
impl EsastGenPass.exit_unary_expr(<>node: uni.UnaryExpr) -> None {
    operand = cast(
        es.Expression,
        self._get_ast_or_default(
            <>node.operand, default_factory=lambda _src: Any : es.Literal(value=0)
        )
    );
    op_tok = Tok(<>node.op.name) if (<>node.op.name in Tok.__members__) else None;
    operator = ES_UNARY_OPS.get(op_tok) if op_tok else None;
    operator = operator or '!';
    unary_expr = self.sync_loc(
        es.UnaryExpression(operator=operator, prefix=True, argument=operand),
        jac_node=<>node
    );
    <>node.gen.es_ast = unary_expr;
}

"""Process compare expression."""
impl EsastGenPass.exit_compare_expr(<>node: uni.CompareExpr) -> None {
    if (not <>node.rights or not <>node.ops) {
        <>node.gen.es_ast = self.sync_loc(es.Literal(value=True), jac_node=<>node);
        return;
    }
    comparisons: list[es.Expression] = [];
    left: es.Expression = cast(
        es.Expression,
        self._get_ast_or_default(
            <>node.left,
            default_factory=lambda src: Any :
                es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Identifier(name='left')
        )
    );
    for (op_token, right_node) in zip(<>node.ops, <>node.rights, strict=False) {
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
        operator = ES_COMPARISON_OPS.get(op_tok) if op_tok else None;
        operator = operator or '===';
        comparison: (es.UnaryExpression | es.BinaryExpression);
        if (op_tok == Tok.KW_NIN) {
            in_expr = self.sync_loc(
                es.BinaryExpression(operator='in', left=left, right=right),
                jac_node=<>node
            );
            comparison = self.sync_loc(
                es.UnaryExpression(operator='!', prefix=True, argument=in_expr),
                jac_node=<>node
            );
        } else {
            comparison = self.sync_loc(
                es.BinaryExpression(operator=operator, left=left, right=right),
                jac_node=<>node
            );
        }
        comparisons.append(comparison);
        left = right;
    }
    if (len(comparisons) == 1) {
        <>node.gen.es_ast = comparisons[0];
    } else {
        result = comparisons[0];
        for comp in comparisons[1:] {
            result = self.sync_loc(
                es.LogicalExpression(operator='&&', left=result, right=comp),
                jac_node=<>node
            );
        }
        <>node.gen.es_ast = result;
    }
}

"""Process boolean expression (and/or)."""
impl EsastGenPass.exit_bool_expr(<>node: uni.BoolExpr) -> None {
    if (not <>node.values or (len(<>node.values) < 2)) {
        <>node.gen.es_ast = self.sync_loc(es.Literal(value=None), jac_node=<>node);
        return;
    }
    op_tok = Tok(<>node.op.name) if (<>node.op.name in Tok.__members__) else None;
    logical_op = ES_LOGICAL_OPS.get(op_tok) if op_tok else None;
    logical_op = logical_op or '&&';
    result: es.Expression = cast(
        es.Expression,
        self._get_ast_or_default(
            <>node.values[0], default_factory=lambda _src: Any : es.Literal(value=None)
        )
    );
    for val in <>node.values[1:] {
        right = cast(
            es.Expression,
            self._get_ast_or_default(
                val, default_factory=lambda _src: Any : es.Literal(value=None)
            )
        );
        result = self.sync_loc(
            es.LogicalExpression(operator=logical_op, left=result, right=right),
            jac_node=<>node
        );
    }
    <>node.gen.es_ast = result;
}

"""Process binary expression."""
impl EsastGenPass.exit_binary_expr(<>node: uni.BinaryExpr) -> None {
    left = cast(
        es.Expression,
        self._get_ast_or_default(
            <>node.left,
            default_factory=lambda src: Any :
                es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Literal(value=0)
        )
    );
    right = cast(
        es.Expression,
        self._get_ast_or_default(
            <>node.right,
            default_factory=lambda src: Any :
                es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Literal(value=0)
        )
    );
    op_name_str = getattr(<>node.op, 'name', None);
    op_name = Tok(op_name_str) if (op_name_str in Tok.__members__) else None;
    if (op_name == Tok.KW_SPAWN) {
        spawn_parts = self._prepare_spawn_call(<>node, left, right);
        if spawn_parts {
            <>node.gen.es_ast = self._build_spawn_runtime_call(<>node, spawn_parts);
        }
        return;
    }
    if ((op_name == Tok.WALRUS_EQ) and isinstance(left, es.Identifier)) {
        self._ensure_identifier_declared(left.name, <>node.left);
        assign_expr = self.sync_loc(
            es.AssignmentExpression(operator='=', left=left, right=right),
            jac_node=<>node
        );
        <>node.gen.es_ast = assign_expr;
        return;
    }
    logical_op = ES_LOGICAL_OPS.get(op_name) if op_name else None;
    bin_expr: (es.LogicalExpression | es.BinaryExpression);
    if logical_op {
        bin_expr = self.sync_loc(
            es.LogicalExpression(operator=logical_op, left=left, right=right),
            jac_node=<>node
        );
    } else {
        operator = ES_BINARY_OPS.get(op_name) if op_name else '+';
        operator = operator or '+';
        bin_expr = self.sync_loc(
            es.BinaryExpression(operator=operator, left=left, right=right),
            jac_node=<>node
        );
    }
    <>node.gen.es_ast = bin_expr;
}

"""Process switch case."""
impl EsastGenPass.exit_switch_case(<>node: uni.SwitchCase) -> None {
    case_test: (es.Expression | None) = None;
    if (<>node.pattern and isinstance(<>node.pattern, uni.MatchValue)) {
        case_test = self._get_ast_or_default(
            <>node.pattern.value,
            default_factory=lambda _src: Any : es.Literal(value=None)
        );
    }
    body_stmts = self._collect_stmt_body(<>node.body);
    <>node.gen.es_ast = self.sync_loc(
        es.SwitchCase(<>test=case_test, consequent=body_stmts), jac_node=<>node
    );
}

"""Process switch statement."""
impl EsastGenPass.exit_switch_stmt(<>node: uni.SwitchStmt) -> None {
    <>test = self._get_ast_or_default(
        <>node.target, default_factory=lambda _src: Any : es.Literal(value=None)
    );
    cases: list[es.SwitchCase] = [];
    for stmt in <>node.cases {
        if (stmt.gen.es_ast and isinstance(stmt.gen.es_ast, es.SwitchCase)) {
            switch_case = cast(es.SwitchCase, stmt.gen.es_ast);
            cases.append(switch_case);
        }
    }
    <>node.gen.es_ast = self.sync_loc(
        es.SwitchStatement(discriminant=<>test, cases=cases), jac_node=<>node
    );
}

"""Process expression statement."""
impl EsastGenPass.exit_expr_stmt(<>node: uni.ExprStmt) -> None {
    expr = cast(
        es.Expression,
        self._get_ast_or_default(
            <>node.expr, default_factory=lambda _src: Any : es.Literal(value=None)
        )
    );
    expr_stmt = self.sync_loc(es.ExpressionStatement(expression=expr), jac_node=<>node);
    <>node.gen.es_ast = expr_stmt;
}

"""Process control statement (break/continue)."""
impl EsastGenPass.exit_ctrl_stmt(<>node: uni.CtrlStmt) -> None {
    stmt: (es.BreakStatement | es.ContinueStatement);
    if (<>node.ctrl.name == Tok.KW_BREAK) {
        stmt = self.sync_loc(es.BreakStatement(), jac_node=<>node);
    } else {
        stmt = self.sync_loc(es.ContinueStatement(), jac_node=<>node);
    }
    <>node.gen.es_ast = stmt;
}

"""Process return statement."""
impl EsastGenPass.exit_return_stmt(<>node: uni.ReturnStmt) -> None {
    argument: (es.Expression | None) = None;
    if (<>node.expr and <>node.expr.gen.es_ast) {
        argument = cast(es.Expression, <>node.expr.gen.es_ast);
    }
    ret_stmt = self.sync_loc(es.ReturnStatement(argument=argument), jac_node=<>node);
    <>node.gen.es_ast = ret_stmt;
}

"""Process assert statement as if-throw."""
impl EsastGenPass.exit_assert_stmt(<>node: uni.AssertStmt) -> None {
    <>test: es.Expression = cast(es.Expression, <>node.condition.gen.es_ast)
    if <>node.condition.gen.es_ast
    else self.sync_loc(es.Literal(value=True), jac_node=<>node.condition);
    negated_test = self.sync_loc(
        es.UnaryExpression(operator='!', prefix=True, argument=<>test), jac_node=<>node
    );
    error_msg = 'Assertion failed';
    if (
        <>node.error_msg
        and <>node.error_msg.gen.es_ast
        and isinstance(<>node.error_msg.gen.es_ast, es.Literal)
    ) {
        error_msg = str(<>node.error_msg.gen.es_ast.value);
    }
    throw_stmt = self.sync_loc(
        es.ThrowStatement(
            argument=self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(es.Identifier(name='Error'), jac_node=<>node),
                    arguments=[
                        self.sync_loc(es.Literal(value=error_msg), jac_node=<>node)
                    ]
                ),
                jac_node=<>node
            )
        ),
        jac_node=<>node
    );
    if_stmt = self.sync_loc(
        es.IfStatement(
            <>test=negated_test,
            consequent=self.sync_loc(
                es.BlockStatement(body=[throw_stmt]), jac_node=<>node
            )
        ),
        jac_node=<>node
    );
    <>node.gen.es_ast = if_stmt;
}

"""Process raise statement."""
impl EsastGenPass.exit_raise_stmt(<>node: uni.RaiseStmt) -> None {
    argument: es.Expression = cast(es.Expression, <>node.cause.gen.es_ast)
    if (<>node.cause and <>node.cause.gen.es_ast)
    else self.sync_loc(es.Identifier(name='Error'), jac_node=<>node);
    if isinstance(argument, es.CallExpression) {
        callee = argument.callee;
        if (
            isinstance(callee, es.Identifier)
            and (callee.name in {'Exception','Error'})
        ) {
            new_expr = self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(es.Identifier(name='Error'), jac_node=<>node),
                    arguments=argument.arguments
                ),
                jac_node=<>node
            );
            argument = new_expr;
        }
    }
    throw_stmt = self.sync_loc(es.ThrowStatement(argument=argument), jac_node=<>node);
    <>node.gen.es_ast = throw_stmt;
}

"""Process finally clause."""
impl EsastGenPass.exit_finally_stmt(<>node: uni.FinallyStmt) -> None {
    <>node.gen.es_ast = self._build_block_statement(<>node, <>node.body);
}

"""Process except clause."""
impl EsastGenPass.exit_except(<>node: uni.Except) -> None {
    param: (es.Pattern | None) = None;
    if <>node.name {
        param = self.sync_loc(
            es.Identifier(name=<>node.name.sym_name), jac_node=<>node.name
        );
    }
    body = self._build_block_statement(<>node, <>node.body);
    catch_clause = self.sync_loc(
        es.CatchClause(param=param, body=body), jac_node=<>node
    );
    <>node.gen.es_ast = catch_clause;
}

"""Process try statement."""
impl EsastGenPass.exit_try_stmt(<>node: uni.TryStmt) -> None {
    block = self._build_block_statement(<>node, <>node.body);
    handler: (es.CatchClause | None) = None;
    if <>node.excepts {
        except_node = <>node.excepts[0];
        if except_node.gen.es_ast {
            handler = cast(es.CatchClause, except_node.gen.es_ast);
        }
    }
    finalizer: (es.BlockStatement | None) = None;
    if (
        <>node.finally_body
        and <>node.finally_body.gen.es_ast
        and isinstance(<>node.finally_body.gen.es_ast, es.BlockStatement)
    ) {
        finalizer = <>node.finally_body.gen.es_ast;
    }
    try_stmt = self.sync_loc(
        es.TryStatement(block=block, handler=handler, finalizer=finalizer),
        jac_node=<>node
    );
    <>node.gen.es_ast = try_stmt;
}

"""Process for-in statement."""
impl EsastGenPass.exit_in_for_stmt(<>node: uni.InForStmt) -> None {
    target_ast = <>node.target.gen.es_ast;
    left: es.Node = target_ast
    if isinstance(target_ast, es.Node)
    else self.sync_loc(es.Identifier(name='item'), jac_node=<>node.target);
    right: es.Expression = cast(es.Expression, <>node.collection.gen.es_ast)
    if <>node.collection.gen.es_ast
    else self.sync_loc(es.Identifier(name='collection'), jac_node=<>node.collection);
    body = self._build_block_statement(<>node, <>node.body);
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
            pattern = self.sync_loc(
                es.Identifier(name='_item'), jac_node=<>node.target
            );
        }
        declarator = self.sync_loc(
            es.VariableDeclarator(id=pattern, <>init=None), jac_node=<>node.target
        );
        decl = self.sync_loc(
            es.VariableDeclaration(declarations=[declarator], kind='const'),
            jac_node=<>node.target
        );
    }
    for_stmt = self.sync_loc(
        es.ForOfStatement(left=decl, right=right, body=body, await_=<>node.is_async),
        jac_node=<>node
    );
    <>node.gen.es_ast = for_stmt;
}

"""Process traditional for statement."""
impl EsastGenPass.exit_iter_for_stmt(<>node: uni.IterForStmt) -> None {
    <>init: es.VariableDeclaration | es.Expression | None = None;
    if (<>node.iter and <>node.iter.gen.es_ast) {
        <>init = cast('es.VariableDeclaration | es.Expression', <>node.iter.gen.es_ast);
    }
    <>test: (es.Expression | None) = None;
    if (<>node.condition and <>node.condition.gen.es_ast) {
        <>test = cast(es.Expression, <>node.condition.gen.es_ast);
    }
    update: (es.AssignmentExpression | None) = None;
    if (
        <>node.count_by
        and <>node.count_by.gen.es_ast
        and isinstance(<>node.count_by.gen.es_ast, es.ExpressionStatement)
    ) {
        update = cast(es.AssignmentExpression, <>node.count_by.gen.es_ast.expression);
    }
    body = self._build_block_statement(<>node, <>node.body);
    <>node.gen.es_ast = self.sync_loc(
        es.ForStatement(<>init=<>init, <>test=<>test, update=update, body=body),
        jac_node=<>node
    );
}

"""Process while statement."""
impl EsastGenPass.exit_while_stmt(<>node: uni.WhileStmt) -> None {
    <>test = self._get_ast_or_default(
        <>node.condition, default_factory=lambda _src: Any : es.Literal(value=True)
    );
    body = self._build_block_statement(<>node, <>node.body);
    while_stmt = self.sync_loc(
        es.WhileStatement(<>test=<>test, body=body), jac_node=<>node
    );
    <>node.gen.es_ast = while_stmt;
}

"""Process else clause."""
impl EsastGenPass.exit_else_stmt(<>node: uni.ElseStmt) -> None {
    stmts = self._collect_stmt_body(<>node.body);
    stmts = self._prepend_hoisted(<>node, stmts);
    block = self.sync_loc(es.BlockStatement(body=stmts), jac_node=<>node);
    <>node.gen.es_ast = block;
}

"""Process else-if clause."""
impl EsastGenPass.exit_else_if(<>node: uni.ElseIf) -> None {
    <>test = self._get_ast_or_default(
        <>node.condition, default_factory=lambda _src: Any : es.Literal(value=True)
    );
    consequent = self._build_block_statement(<>node, <>node.body);
    alternate: (es.Statement | None) = None;
    if (<>node.else_body and <>node.else_body.gen.es_ast) {
        alternate = cast(es.Statement, <>node.else_body.gen.es_ast);
    }
    if_stmt = self.sync_loc(
        es.IfStatement(<>test=<>test, consequent=consequent, alternate=alternate),
        jac_node=<>node
    );
    <>node.gen.es_ast = if_stmt;
}

"""Process if statement."""
impl EsastGenPass.exit_if_stmt(<>node: uni.IfStmt) -> None {
    <>test = self._get_ast_or_default(
        <>node.condition, default_factory=lambda _src: Any : es.Literal(value=True)
    );
    consequent = self._build_block_statement(<>node, <>node.body);
    alternate: (es.Statement | None) = None;
    if (<>node.else_body and <>node.else_body.gen.es_ast) {
        alternate = cast(es.Statement, <>node.else_body.gen.es_ast);
    }
    if_stmt = self.sync_loc(
        es.IfStatement(<>test=<>test, consequent=consequent, alternate=alternate),
        jac_node=<>node
    );
    <>node.gen.es_ast = if_stmt;
}

"""Process JSX expression child."""
impl EsastGenPass.exit_jsx_expression(<>node: uni.JsxExpression) -> None {
    self.jsx_processor.expression(<>node);
}

"""Process JSX text node."""
impl EsastGenPass.exit_jsx_text(<>node: uni.JsxText) -> None {
    self.jsx_processor.text(<>node);
}

"""Process JSX normal attribute."""
impl EsastGenPass.exit_jsx_normal_attribute(<>node: uni.JsxNormalAttribute) -> None {
    self.jsx_processor.normal_attribute(<>node);
}

"""Process JSX spread attribute."""
impl EsastGenPass.exit_jsx_spread_attribute(<>node: uni.JsxSpreadAttribute) -> None {
    self.jsx_processor.spread_attribute(<>node);
}

"""Process JSX element name."""
impl EsastGenPass.exit_jsx_element_name(<>node: uni.JsxElementName) -> None {
    self.jsx_processor.element_name(<>node);
}

"""Process JSX element."""
impl EsastGenPass.exit_jsx_element(<>node: uni.JsxElement) -> None {
    <>node.gen.es_ast = self.jsx_processor.element(<>node);
}

"""Process has variable."""
impl EsastGenPass.exit_has_var(<>node: uni.HasVar) -> None {
    <>node.gen.es_ast = None;
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

"""Auto-inject useState import from @jac-client/utils when reactive has variables are used."""
impl EsastGenPass._inject_usestate_import(<>node: uni.UniNode) -> None {
    # Create: import { useState } from "@jac-client/utils";
    # This import goes through jac-client's client_runtime which re-exports useState from React
    specifier = self.sync_loc(
        es.ImportSpecifier(
            imported=es.Identifier(name='useState'),
            local=es.Identifier(name='useState')
        ),
        jac_node=<>node
    );
    source = self.sync_loc(
        es.Literal(value='@jac-client/utils', raw='"@jac-client/utils"'),
        jac_node=<>node
    );
    import_decl = self.sync_loc(
        es.ImportDeclaration(specifiers=[specifier], source=source), jac_node=<>node
    );
    self.imports.append(import_decl);
}

"""Process class field declarations - generates useState for client-side reactive state."""
impl EsastGenPass.exit_arch_has(<>node: uni.ArchHas) -> None {
    # Check if this is client-side reactive state (works for both cl {} and .cl.jac)
    if not <>node.in_client_context() {
        <>node.gen.es_ast = None;
        return;
    }
    # Auto-inject useState import if not already done and user hasn't imported it
    if not self.has_injected_usestate and not self._has_usestate_import() {
        self._inject_usestate_import(<>node);
        self.has_injected_usestate = True;
    }
    # Generate useState destructuring for each variable
    # has count: int = 0; -> const [count, setCount] = useState(0);
    statements: list[es.Statement] = [];
    for has_var in <>node.vars {
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
            es.VariableDeclarator(id=array_pattern, <>init=use_state_call),
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
        <>node.gen.es_ast = statements[0];
    } elif len(statements) > 1 {
        # Return as a list for multiple declarations
        <>node.gen.es_ast = statements;
    } else {
        <>node.gen.es_ast = None;
    }
}

"""Process parameter variable."""
impl EsastGenPass.exit_param_var(<>node: uni.ParamVar) -> None {
    param_id = self.sync_loc(
        es.Identifier(name=<>node.name.sym_name), jac_node=<>node.name
    );
    self._register_declaration(param_id.name);
    <>node.gen.es_ast = param_id;
}

"""Process function signature."""
impl EsastGenPass.exit_func_signature(<>node: uni.FuncSignature) -> None {
    <>node.gen.es_ast = None;
}

"""Process ability (function/method) declaration."""
impl EsastGenPass.exit_ability(<>node: uni.Ability) -> None {
    if (<>node.code_context == CodeContext.CLIENT and not <>node.is_method) {
        self.client_manifest.has_client = True;
        name = <>node.name_ref.sym_name;
        self.client_manifest.exports.append(name);
        self.client_manifest.params[name] = [
            p.name.sym_name for p in <>node.signature.params
        ]
        if isinstance(<>node.signature, uni.FuncSignature)
        else [];
    }
    is_jsx_in_return = False;
    if isinstance(<>node.body, list) {
        for stmt in <>node.body {
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
    if isinstance(<>node.signature, uni.FuncSignature) and <>node.signature.params {
        if is_jsx_in_return
        and not (
            len(<>node.signature.params) == 1
            and <>node.signature.params[0].name.sym_name == 'props'
        ) {
            params.append(es.Identifier(name="props"));
            for param in <>node.signature.params {
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
                                        jac_node=<>node,
                                    ),
                                    <>init=self.sync_loc(
                                        es.Identifier(name="props"), jac_node=<>node
                                    ),
                                ),
                                jac_node=<>node,
                            )
                        ],
                        kind="const",
                    ),
                    jac_node=<>node,
                )
            ];
        } else {
            for param in <>node.signature.params {
                if param.gen.es_ast {
                    params.append(cast(es.Pattern, param.gen.es_ast));
                }
            }
        }
    }
    inner = (
        <>node.body.body
        if isinstance(<>node.body, uni.ImplDef)
        else self._get_body_inner(<>node)
    );
    body_stmts = self._collect_stmt_body(inner);
    body_stmts = self._prepend_hoisted(<>node, body_stmts);
    block = self.sync_loc(
        es.BlockStatement(body=destructure_stmts + body_stmts), jac_node=<>node
    );
    func_id = self.sync_loc(
        es.Identifier(name=<>node.name_ref.sym_name), jac_node=<>node.name_ref
    );
    if <>node.is_method {
        func_expr = self.sync_loc(
            es.FunctionExpression(
                id=None, params=params, body=block, async_=<>node.is_async
            ),
            jac_node=<>node
        );
        method_def = self.sync_loc(
            es.MethodDefinition(
                key=func_id, value=func_expr, kind='method', <>static=<>node.is_static
            ),
            jac_node=<>node
        );
        <>node.gen.es_ast = method_def;
    } else {
        func_decl = self.sync_loc(
            es.FunctionDeclaration(
                id=func_id, params=params, body=block, async_=<>node.is_async
            ),
            jac_node=<>node
        );
        if (<>node.access and (<>node.access.tag.name == Tok.KW_PUB)) {
            export_decl = self.sync_loc(
                es.ExportNamedDeclaration(declaration=func_decl), jac_node=<>node
            );
            <>node.gen.es_ast = export_decl;
        } else {
            <>node.gen.es_ast = func_decl;
        }
    }
}

"""Ensure ImplDef body is properly parented for traversal."""
impl EsastGenPass.enter_ability(<>node: uni.Ability) -> None {
    if isinstance(<>node.body, uni.ImplDef) and (<>node.body not in <>node.kid) {
        <>node.body.parent = <>node;
        <>node.kid.append(<>node.body);
    }
}

"""Process enum declaration as an object."""
impl EsastGenPass.exit_enum(<>node: uni.Enum) -> None {
    properties: list[(es.Property | es.SpreadElement)] = [];
    inner = (
        <>node.body.body
        if isinstance(<>node.body, uni.ImplDef)
        else self._get_body_inner(<>node)
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
    obj_expr = self.sync_loc(
        es.ObjectExpression(properties=properties), jac_node=<>node
    );
    var_id = self.sync_loc(
        es.Identifier(name=<>node.name.sym_name), jac_node=<>node.name
    );
    var_decl = self.sync_loc(
        es.VariableDeclaration(
            declarations=[
                self.sync_loc(
                    es.VariableDeclarator(id=var_id, <>init=obj_expr), jac_node=<>node
                )
            ],
            kind='const'
        ),
        jac_node=<>node
    );
    if (<>node.access and (<>node.access.tag.name == Tok.KW_PUB)) {
        export_decl = self.sync_loc(
            es.ExportNamedDeclaration(declaration=var_decl), jac_node=<>node
        );
        <>node.gen.es_ast = export_decl;
    } else {
        <>node.gen.es_ast = var_decl;
    }
}

"""Process archetype (class) declaration."""
impl EsastGenPass.exit_archetype(<>node: uni.Archetype) -> None {
    if <>node.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        self.client_manifest.exports.append(<>node.name.sym_name);
    }
    body_stmts: list[es.MethodDefinition | es.PropertyDefinition | es.StaticBlock] = [];
    has_members: list[uni.ArchHas] = [];
    inner = (
        <>node.body.body
        if isinstance(<>node.body, uni.ImplDef)
        else self._get_body_inner(<>node)
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
    if ((<>node.arch_type.name == Tok.KW_OBJECT) and has_members) {
        constructor_stmts: list[es.Statement] = [];
        props_param = self.sync_loc(
            es.AssignmentPattern(
                left=self.sync_loc(es.Identifier(name='props'), jac_node=<>node),
                right=self.sync_loc(
                    es.ObjectExpression(properties=[]), jac_node=<>node
                )
            ),
            jac_node=<>node
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
                            <>static=True
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
                        <>test=has_call, consequent=props_access, alternate=default_val
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
                    key=self.sync_loc(
                        es.Identifier(name='constructor'), jac_node=<>node
                    ),
                    value=self.sync_loc(
                        es.FunctionExpression(
                            id=None,
                            params=[props_param],
                            body=self.sync_loc(
                                es.BlockStatement(body=constructor_stmts),
                                jac_node=<>node
                            )
                        ),
                        jac_node=<>node
                    ),
                    kind='constructor',
                    <>static=False
                ),
                jac_node=<>node
            );
            body_stmts.insert(0, constructor_method);
        }
    }
    class_body = self.sync_loc(es.ClassBody(body=body_stmts), jac_node=<>node);
    super_class: (es.Expression | None) = None;
    if <>node.base_classes {
        base = <>node.base_classes[0];
        if base.gen.es_ast {
            super_class = cast(es.Expression, base.gen.es_ast);
        }
    }
    class_id = self.sync_loc(
        es.Identifier(name=<>node.name.sym_name), jac_node=<>node.name
    );
    class_decl = self.sync_loc(
        es.ClassDeclaration(id=class_id, superClass=super_class, body=class_body),
        jac_node=<>node
    );
    if (<>node.access and (<>node.access.tag.name == Tok.KW_PUB)) {
        export_decl = self.sync_loc(
            es.ExportNamedDeclaration(declaration=class_decl), jac_node=<>node
        );
        <>node.gen.es_ast = export_decl;
    } else {
        <>node.gen.es_ast = class_decl;
    }
}

"""Process import statement."""
impl EsastGenPass.exit_import(<>node: uni.Import) -> None {
    # Only process client-side imports for JavaScript generation
    if <>node.code_context != CodeContext.CLIENT {
        # Server-side import (sv keyword or default) - skip JS generation
        return;
    }
    if (<>node.from_loc and <>node.items) {
        resolved_path = <>node.from_loc.resolve_relative_path();
        import_key = <>node.from_loc.dot_path_str;
        self.client_manifest.imports[import_key] = resolved_path;
        self.client_manifest.has_client = True;
        # Prepend dot for local Jac modules to make them relative imports in JS
        # Skip for jac: prefixed imports (built-in runtime modules)
        import_path = <>node.from_loc.dot_path_str;
        has_jac_prefix = <>node.from_loc.prefix
        and <>node.from_loc.prefix.value == 'jac';
        if resolved_path.endswith('.jac')
        and not import_path.startswith('.')
        and not has_jac_prefix {
            import_path = '.' + import_path;
        }
        js_import_path = convert_to_js_import_path(import_path);
    } elif (not <>node.from_loc and <>node.items) {
        self.client_manifest.has_client = True;
        first_item = <>node.items[0];
        if (isinstance(first_item, uni.ModulePath) and first_item.path) {
            path_elem = first_item.path[0];
            import_key = path_elem.lit_value
            if isinstance(path_elem, uni.String)
            else path_elem.value;
        } else {
            import_key = '';
        }
        resolved_path = resolve_relative_path(import_key, <>node.loc.mod_path);
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
    source = self.sync_loc(es.Literal(value=js_import_path), jac_node=<>node.from_loc);
    specifiers:
        list[
            es.ImportSpecifier | es.ImportDefaultSpecifier | es.ImportNamespaceSpecifier
        ] = [];
    for item in <>node.items {
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
        es.ImportDeclaration(specifiers=specifiers, source=source), jac_node=<>node
    );
    self.imports.append(import_decl);
    <>node.gen.es_ast = None;
}

"""Process SubTag node."""
impl EsastGenPass.exit_sub_tag(<>node: uni.SubTag[uni.T]) -> None {
    if <>node.tag.gen.es_ast {
        <>node.gen.es_ast = <>node.tag.gen.es_ast;
    }
}

"""Recursively populate client manifest from module declarations."""
impl EsastGenPass._populate_client_manifest(<>node: uni.Module) -> None {
    for item in <>node.gen.client_manifest.exports {
        self.client_manifest.exports.append(item);
    }
    for item in <>node.gen.client_manifest.globals {
        self.client_manifest.globals.append(item);
    }
    for (import_key, resolved_path) in <>node.gen.client_manifest.imports.items() {
        self.client_manifest.imports[import_key] = resolved_path;
    }
    for sub_mod in <>node.gen.client_manifest.params {
        self.client_manifest.params[sub_mod] = <>node.gen.client_manifest.params[
            sub_mod
        ];
    }
}

"""Populate client manifest from module declarations."""
impl EsastGenPass.populate_client_manifest(<>node: uni.Module) -> None {
    for mod in <>node.impl_mod {
        self._populate_client_manifest(mod);
    }
}

"""Process module node."""
impl EsastGenPass.exit_module(<>node: uni.Module) -> None {
    body: list[(es.Statement | es.ModuleDeclaration)] = [];
    body.extend(self.imports);
    for mod in <>node.impl_mod {
        if (mod.gen.es_ast and isinstance(mod.gen.es_ast, es.Program)) {
            for import_decl in mod.gen.es_ast.body {
                if isinstance(import_decl, es.ImportDeclaration) {
                    body.append(import_decl);
                }
            }
        }
    }
    scope = self.scope_map.get(<>node);
    if (scope and scope.hoisted) {
        hoisted = <>list(scope.hoisted);
        scope.hoisted.clear();
        body.extend(hoisted);
    }
    merged_body = self._merge_module_bodies(<>node);
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
    program = self.sync_loc(
        es.Program(body=body, sourceType='module'), jac_node=<>node
    );
    <>node.gen.es_ast = program;
    <>node.gen.js = es_to_js(<>node.gen.es_ast);
    self.populate_client_manifest(<>node);
    self.client_manifest.exports.sort();
    self.client_manifest.globals.sort();
    <>node.gen.client_manifest = self.client_manifest;
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
    <>node: (uni.UniNode | None),
    default_factory: Callable[([(uni.UniNode | None)], _T)]
) -> _T {
    if (<>node and getattr(<>node.gen, 'es_ast', None)) {
        generated = <>node.gen.es_ast;
        if isinstance(generated, es.Node) {
            return cast(_T, generated);
        }
    }
    fallback = default_factory(<>node);
    jac_ref = <>node if (<>node is not None) else self.cur_node;
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
        if isinstance(generated, <>list) {
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
    <>node: uni.BinaryExpr, parts: SpawnCallParts
) -> es.AwaitExpression {
    walker_literal = self.sync_loc(
        es.Literal(value=parts.walker.walker_name), jac_node=parts.walker.call_node
    );
    spawn_call = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__jacSpawn'), jac_node=<>node),
            arguments=[
                walker_literal,
                parts.target.expression,
                parts.walker.fields_object
            ]
        ),
        jac_node=<>node
    );
    return self.sync_loc(es.AwaitExpression(argument=spawn_call), jac_node=<>node);
}

"""Split a spawn expression into walker and target parts."""
impl EsastGenPass._prepare_spawn_call(
    <>node: uni.BinaryExpr, left_expr: es.Expression, right_expr: es.Expression
) -> (SpawnCallParts | None) {
    left_walker = self._resolve_spawn_walker(<>node.left, left_expr);
    right_walker = self._resolve_spawn_walker(<>node.right, right_expr);
    if (left_walker and right_walker) {
        self.log_warning(
            'Both sides of spawn look like walker instantiations; defaulting to the right-hand expression.',
            node_override=<>node
        );
        target = self._resolve_spawn_target(<>node.left, left_expr);
        return SpawnCallParts(<>walker=right_walker, target=target);
    }
    if left_walker {
        target = self._resolve_spawn_target(<>node.right, right_expr);
        return SpawnCallParts(<>walker=left_walker, target=target);
    }
    if right_walker {
        target = self._resolve_spawn_target(<>node.left, left_expr);
        return SpawnCallParts(<>walker=right_walker, target=target);
    }
    self.log_error(
        'Spawn expressions must include a walker constructor on one side.',
        node_override=<>node
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
        return SpawnTargetInfo(<>node=stripped_node, expression=literal);
    }
    return SpawnTargetInfo(<>node=stripped_node, expression=stripped_es);
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
    <>node: (uni.UniNode | None), <>default: LiteralValue = None
) -> es.Expression {
    generated = self._get_ast_or_default(
        <>node, default_factory=lambda src: Any : es.Literal(value=<>default)
    );
    if isinstance(generated, es.Expression) {
        return generated;
    }
    self.log_error('Expected expression in spawn argument.', node_override=<>node);
    return self.sync_loc(
        es.Literal(value=<>default), jac_node=(<>node or self.cur_node)
    );
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
    <>node: uni.UniScopeNode, statements: list[es.Statement]
) -> list[es.Statement] {
    scope = self.scope_map.get(<>node);
    if (scope and scope.hoisted) {
        hoisted = <>list(scope.hoisted);
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
        es.VariableDeclarator(id=ident, <>init=None), jac_node=jac_node
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
    return <>any((name in scope.declared) for scope in reversed(self.scope_stack));
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
impl EsastGenPass._pop_scope(<>node: uni.UniScopeNode) -> None {
    if (self.scope_stack and (self.scope_stack[-1].node is <>node)) {
        self.scope_stack.pop();
    }
    self.scope_map.pop(<>node, None);
}

"""Enter a new lexical scope."""
impl EsastGenPass._push_scope(<>node: uni.UniScopeNode) -> None {
    info = ScopeInfo(<>node=<>node);
    self.scope_stack.append(info);
    self.scope_map[<>node] = info;
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
impl EsastGenPass.exit_node(<>node: uni.UniNode) -> None {
    if (
        isinstance(<>node, uni.ElementStmt)
        and isinstance(<>node, uni.ContextAwareNode)
        and <>node.code_context != CodeContext.CLIENT
        and ((<>node.parent is None) or isinstance(<>node.parent, uni.Module))
    ) {
        return;
    }
    super.exit_node(<>node);
    if isinstance(<>node, uni.UniScopeNode) {
        self._pop_scope(<>node);
    }
}

"""Enter node."""
impl EsastGenPass.enter_node(<>node: uni.UniNode) -> None {
    if (
        isinstance(<>node, uni.ElementStmt)
        and isinstance(<>node, uni.ContextAwareNode)
        and <>node.code_context != CodeContext.CLIENT
        and ((<>node.parent is None) or isinstance(<>node.parent, uni.Module))
    ) {
        self.prune();
        return;
    }
    if isinstance(<>node, uni.UniScopeNode) {
        self._push_scope(<>node);
    }
    if <>node.gen.es_ast {
        self.prune();
        return;
    }
    super.enter_node(<>node);
}

"""Initialize the pass."""
impl EsastGenPass.before_pass -> None {
    import from jaclang.pycore.codeinfo { ClientManifest }
    self.child_passes: list[EsastGenPass] = self._init_child_passes(EsastGenPass);
    self.imports: list[es.ImportDeclaration] = [];
    self.exports: list[es.ExportNamedDeclaration] = [];
    self.scope_stack: list[ScopeInfo] = [];
    self.scope_map: dict[(uni.UniScopeNode, ScopeInfo)] = {};
    self.client_manifest = ClientManifest();
    self.jsx_processor = EsJsxProcessor(self);
    # Track reactive state variables: maps var_name -> setter_name (e.g., "count" -> "setCount")
    self.reactive_vars: dict[str, str] = {};
    # Track if useState import has been auto-injected to avoid duplicates
    self.has_injected_usestate: bool = False;
}
