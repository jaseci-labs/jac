import from jaclang.compiler.backends.es.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
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
