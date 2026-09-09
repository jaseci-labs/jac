impl JcirGenPass.resolve_switch_pattern(pattern: MatchPattern, target: Expr) -> CgNode {
    if isinstance(pattern, MatchValue) {
        return self.nod(
            'Compare',
            ['left', 'ops', 'comparators'],
            [self.val(target), [self.nod('Eq', [], [])], [self.val(pattern.value)]]
        );
    } elif isinstance(pattern, MatchOr) {
        return self.nod(
            'BoolOp',
            ['op', 'values'],
            [
                self.nod('Or', [], []),
                [self.resolve_switch_pattern(pat, target) for pat in pattern.patterns]
            ]
        );
    } elif isinstance(pattern, MatchSingleton) {
        return self.nod(
            'Compare',
            ['left', 'ops', 'comparators'],
            [self.val(target), [self.nod('Is', [], [])], [self.val(pattern.value)]]
        );
    } else {
        raise RuntimeError(self.ice('Unsupported switch pattern type'));
    }
}

impl JcirGenPass.resolve_switch_stmt(nd: SwitchStmt) -> list[CgItem] {
    var_executed = self.nod(
        'Name', ['id', 'ctx'], ['__executed', self.nod('Store', [], [])]
    );
    assign_var = self.nod(
        'Assign', ['targets', 'value'], [[var_executed], self.const_of(False)]
    );
    ast_nodes: list[CgItem] = [];
    executed_assign = self.nod(
        'Assign', ['targets', 'value'], [[var_executed], self.const_of(True)]
    );
    for cs in nd.cases {
        if (cs.pattern is None) {
            ast_nodes.extend((self.resolve_stmt_block(cs.body) + [executed_assign]));
        } else {
            test_expr = self.nod(
                'BoolOp',
                ['op', 'values'],
                [
                    self.nod('Or', [], []),
                    [
                        self.resolve_switch_pattern(cs.pattern, nd.target),
                        self.name_load('__executed')
                    ]
                ]
            );
            if_stmt = self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [test_expr, (self.resolve_stmt_block(cs.body) + [executed_assign]), []]
            );
            ast_nodes.append(if_stmt);
        }
    }
    while_cond = self.nod(
        'UnaryOp',
        ['op', 'operand'],
        [self.nod('Not', [], []), self.name_load('__executed')]
    );
    return [
        assign_var,
        self.nod('While', ['test', 'body', 'orelse'], [while_cond, ast_nodes, []])
    ];
}

impl JcirGenPass.resolve_stmt_block(
    nd: Sequence[CodeBlockStmt] | Sequence[EnumBlockStmt] | None,
    doc: (String | None) = None
) -> list[CgItem] {
    items = list(nd) if nd else [];
    valid_stmts = [
        i
        for i in items
        if not isinstance(i, Semi)
    ];
    ret: list[CgItem] = [self.nod('Pass', [], [])]
        if (isinstance(nd, Sequence) and not valid_stmts)
        else self._stmts_with_releases(valid_stmts)
            if (nd is not None)
            else [self.nod('Pass', [], [])];
    if doc {
        ret = [self.nod('Expr', ['value'], [self.val(doc)], jac_node=doc), *ret];
    }
    return ret;
}

impl JcirGenPass._stmts_with_releases(stmts: list) -> list[CgItem] {
    out: list[CgItem] = [];
    for x in stmts {
        if isinstance(x, ImplDef) {
            continue;
        }
        out.extend(
            self.outs(x)
                if not isinstance(x, SwitchStmt)
                else self.resolve_switch_stmt(x)
        );
        out.extend(self._move_release_stmts(x));
    }
    return out;
}

impl JcirGenPass._move_release_stmts(stmt: CodeBlockStmt) -> list[CgNode] {
    if isinstance(stmt, (ReturnStmt, RaiseStmt)) {
        return [];
    }
    sites = self.ir_in.own_move_sites;
    last_uses = self.ir_in.rc_last_use.get(id(stmt)) or [];
    if not sites and not last_uses {
        return [];
    }
    targets: list[str] = [];
    if isinstance(stmt, Assignment) {
        targets = [
            t.sym_name
            for t in stmt.target
            if isinstance(t, Name)
        ];
    }
    names: list[str] = [];
    for nm in stmt.get_all_sub_nodes(Name) {
        if id(nm) not in sites
            or nm.sym is None
            or nm.find_parent_of_type(CodeBlockStmt) is not stmt
            or nm.find_parent_of_type(LambdaExpr) is not None
            or nm.sym.storage not in (SymbolStorage.LOCAL, SymbolStorage.PARAM)
            or nm.sym_name in targets
            or nm.sym_name in names {
            continue;
        }
        names.append(nm.sym_name);
    }
    for ln in last_uses {
        if ln in names {
            continue;
        }
        sym = stmt.sym_tab.lookup(ln) if stmt.sym_tab is not None else None;
        if sym is None
            or sym.ownership != OwnershipKind.OWN
            or sym.storage != SymbolStorage.LOCAL {
            continue;
        }
        names.append(ln);
    }
    return [self._release_name_stmt(n, stmt) for n in names];
}

impl JcirGenPass.scope_directive_stmts(
    scopes: list[UniScopeNode | None]
) -> list[CgNode] {
    global_names: list[str] = [];
    nonlocal_names: list[str] = [];
    seen: set[str] = set();
    for scope in scopes {
        if scope is None {
            continue;
        }
        for name in scope.implicit_rebinds {
            if name in seen {
                continue;
            }
            seen.add(name);
            sym = scope.implicit_rebinds[name];
            if isinstance(sym.parent_tab, Module) {
                global_names.append(name);
            } else {
                nonlocal_names.append(name);
            }
        }
    }
    stmts: list[CgNode] = [];
    if global_names {
        stmts.append(self.nod('Global', ['names'], [sorted(global_names)]));
    }
    if nonlocal_names {
        stmts.append(self.nod('Nonlocal', ['names'], [sorted(nonlocal_names)]));
    }
    return stmts;
}

impl JcirGenPass.exit_typed_ctx_block with TypedCtxBlock exit {
    loc = self.name_load(Con.HERE.value if here.from_walker else Con.VISITOR.value);
    self.set_out(
        here,
        [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.call_node(
                        self.name_load('isinstance'), [loc, self.val(here.type_ctx)], []
                    ),
                    self.resolve_stmt_block(here.body),
                    []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_open_stmt with OpenStmt exit {
    self.builtin_imports.add("_jac_region_open");
    self.builtin_imports.add("_jac_region_close");
    _tmp = f"_jac_region_{here.loc.first_line}_{here.loc.col_start}";
    assign_stmt = self.nod(
        'Assign',
        ['targets', 'value'],
        [
            [
                self.nod(
                    'Name',
                    ['id', 'ctx'],
                    [_tmp, self.nod('Store', [], [], jac_node=here)],
                    jac_node=here
                )
            ],
            self.val(here.target)
        ],
        jac_node=here.target
    );
    open_stmt = self.nod(
        'Expr',
        ['value'],
        [
            self.call_node(
                self.name_load('_jac_region_open', jac_node=here),
                [self.name_load(_tmp, jac_node=here)],
                [],
                jac_node=here
            )
        ],
        jac_node=here
    );
    close_stmt = self.nod(
        'Expr',
        ['value'],
        [
            self.call_node(
                self.name_load('_jac_region_close', jac_node=here),
                [self.name_load(_tmp, jac_node=here)],
                [],
                jac_node=here
            )
        ],
        jac_node=here
    );
    clear_stmt = self.nod(
        'Assign',
        ['targets', 'value'],
        [
            [
                self.nod(
                    'Name',
                    ['id', 'ctx'],
                    [_tmp, self.nod('Store', [], [], jac_node=here)],
                    jac_node=here
                )
            ],
            self.const_of(None, jac_node=here)
        ],
        jac_node=here
    );
    body_stmts: list = self._flatten_ast_list([self.outs(item) for item in here.body]);
    if not body_stmts {
        body_stmts = [self.nod('Pass', [], [], jac_node=here)];
    }
    try_stmt = self.nod(
        'Try',
        ['body', 'handlers', 'orelse', 'finalbody'],
        [body_stmts, [], [], [close_stmt, clear_stmt]],
        jac_node=here
    );
    self.set_out(here, [assign_stmt, open_stmt, try_stmt]);
}

impl JcirGenPass._comptime_if_out(nd: IfStmt) -> bool {
    if nd.ct_taken is None {
        return False;
    }
    if nd.ct_taken {
        self.set_out(nd, self.resolve_stmt_block(nd.body));
    } else {
        self.set_out(nd, self.outs(nd.else_body) if nd.else_body else []);
    }
    return True;
}

impl JcirGenPass._if_out(nd: IfStmt) -> None {
    if self._comptime_if_out(nd) {
        return;
    }
    self.set_out(
        nd,
        [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.val(nd.condition),
                    self.resolve_stmt_block(nd.body),
                    self.outs(nd.else_body) if nd.else_body else []
                ],
                jac_node=nd
            )
        ]
    );
}

impl JcirGenPass.exit_if_stmt with IfStmt exit {
    if here.__class__ is not IfStmt {
        return;
    }
    self._if_out(here);
}

impl JcirGenPass.exit_else_if with ElseIf exit {
    self._if_out(here);
}

impl JcirGenPass.exit_else_stmt with ElseStmt exit {
    self.set_out(here, self.resolve_stmt_block(here.body));
}

impl JcirGenPass.exit_expr_stmt with ExprStmt exit {
    if not here.in_fstring {
        stub_call = self._sv_bridge_walker_call(here.expr);
        if stub_call is not None {
            stub_name = (
                stub_call.target.sym_name if isinstance(stub_call.target, Name) else ''
            );
            (args, keywords) = self.gen_call_args(stub_call);
            deferred = self.call_node(
                self.nod(
                    'Attribute',
                    ['value', 'attr', 'ctx'],
                    [
                        self.nod(
                            'Name', ['id', 'ctx'], [stub_name, self.nod('Load', [], [])]
                        ),
                        '_deferred',
                        self.nod('Load', [], [])
                    ]
                ),
                args,
                keywords,
                jac_node=here.expr
            );
            self.set_out(here, [self.nod('Expr', ['value'], [deferred])]);
            return;
        }
    }
    expr_stmt = self.nod('Expr', ['value'], [self.val(here.expr)])
        if not here.in_fstring
        else self.nod(
            'FormattedValue',
            ['value', 'conversion', 'format_spec'],
            [self.val(here.expr), -1, None]
        );
    self.set_out(here, [expr_stmt]);
}

impl JcirGenPass.exit_concurrent_expr with ConcurrentExpr exit {
    func = '';
    if here.tok {
        if here.tok.value == 'flow' {
            func = 'thread_run';
        } elif here.tok.value == 'wait' {
            func = 'thread_wait';
        }
    }
    if func {
        lambda_ex = [
            self.nod(
                'Lambda',
                ['args', 'body'],
                [
                    self.nod(
                        'arguments',
                        [
                            'posonlyargs',
                            'args',
                            'kwonlyargs',
                            'kw_defaults',
                            'defaults'
                        ],
                        [[], [], [], [], []]
                    ),
                    self.val(here.target)
                ]
            )
        ];
        self.set_out(
            here,
            [
                self.call_node(
                    self.jaclib_obj(func),
                    lambda_ex if (func == 'thread_run') else [self.val(here.target)],
                    []
                )
            ]
        );
    }
}

impl JcirGenPass.exit_try_stmt with TryStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'Try',
                ['body', 'handlers', 'orelse', 'finalbody'],
                [
                    self.resolve_stmt_block(here.body),
                    [self.val(i) for i in here.excepts],
                    self.outs(here.else_body) if here.else_body else [],
                    self.outs(here.finally_body) if here.finally_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_except with Except exit {
    self.set_out(
        here,
        [
            self.nod(
                'ExceptHandler',
                ['type', 'name', 'body'],
                [
                    self.val(here.ex_type) if here.ex_type else None,
                    here.name.sym_name if here.name else None,
                    self.resolve_stmt_block(here.body)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_finally_stmt with FinallyStmt exit {
    self.set_out(here, self.resolve_stmt_block(here.body));
}

impl JcirGenPass.exit_iter_for_stmt with IterForStmt exit {
    py_nodes: list[CgNode] = [];
    body = self.resolve_stmt_block(here.body);
    body = body + [self.val(here.count_by)];
    py_nodes.append(self.val(here.iter));
    py_nodes.append(
        self.nod(
            'While',
            ['test', 'body', 'orelse'],
            [
                self.val(here.condition),
                body,
                self.outs(here.else_body) if here.else_body else []
            ]
        )
    );
    self.set_out(here, py_nodes);
}

impl JcirGenPass.exit_in_for_stmt with InForStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'AsyncFor' if here.is_async else 'For',
                ['target', 'iter', 'body', 'orelse'],
                [
                    self.val(here.target),
                    self.val(here.collection),
                    self.resolve_stmt_block(here.body),
                    self.outs(here.else_body) if here.else_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_while_stmt with WhileStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'While',
                ['test', 'body', 'orelse'],
                [
                    self.val(here.condition),
                    self.resolve_stmt_block(here.body),
                    self.outs(here.else_body) if here.else_body else []
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_forever_stmt with ForeverStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'While',
                ['test', 'body', 'orelse'],
                [self.const_of(True), self.resolve_stmt_block(here.body), []]
            )
        ]
    );
}

impl JcirGenPass.exit_with_stmt with WithStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'AsyncWith' if here.is_async else 'With',
                ['items', 'body'],
                [
                    [self.val(item) for item in here.exprs],
                    self.resolve_stmt_block(here.body)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_expr_as_item with ExprAsItem exit {
    self.set_out(
        here,
        [
            self.nod(
                'withitem',
                ['context_expr', 'optional_vars'],
                [self.val(here.expr), self.val(here.alias) if here.alias else None]
            )
        ]
    );
}

impl JcirGenPass.exit_raise_stmt with RaiseStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'Raise',
                ['exc', 'cause'],
                [
                    self.val(here.cause) if here.cause else None,
                    self.val(here.from_target) if here.from_target else None
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_assert_stmt with AssertStmt exit {
    if here.is_comptime {
        self.set_out(here, []);
        return;
    }
    self.set_out(
        here,
        [
            self.nod(
                'Assert',
                ['test', 'msg'],
                [
                    self.val(here.condition),
                    self.val(here.error_msg) if here.error_msg else None
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_ctrl_stmt with CtrlStmt exit {
    if (here.ctrl.name == Tok.KW_BREAK) {
        self.set_out(here, [self.nod('Break', [], [])]);
    } elif (here.ctrl.name == Tok.KW_CONTINUE) {
        if (iter_for_parent := here.find_parent_of_type(IterForStmt)) {
            count_by = iter_for_parent.count_by;
            self.set_out(here, [self.val(count_by), self.nod('Continue', [], [])]);
        } else {
            self.set_out(here, [self.nod('Continue', [], [])]);
        }
    } elif (here.ctrl.name == Tok.KW_SKIP) {
        self.set_out(here, [self.nod('Return', ['value'], [None])]);
    }
}

impl JcirGenPass._del_ctx_target(target: Expr, ctx_cls: str) -> CgNode {
    cgn = self.val(target);
    return self._with_ctx(cgn, ctx_cls) if cgn.hasf('ctx') else cgn;
}

impl JcirGenPass._destroy_call(value: CgNode, strict: bool) -> CgNode {
    keywords: list[CgNode] = [];
    if strict {
        keywords.append(
            self.nod('keyword', ['arg', 'value'], ['strict', self.const_of(True)])
        );
    }
    return self.nod(
        'Expr',
        ['value'],
        [self.call_node(self.jaclib_obj('destroy'), [value], keywords)]
    );
}

impl JcirGenPass._del_is_trivial(cgn: CgNode) -> bool {
    if cgn.cls in ('Name', 'Constant') {
        return True;
    }
    if cgn.cls == 'Slice' {
        return all(
            (part is None) or (isinstance(part, CgNode) and self._del_is_trivial(part))
            for part in (cgn.get('lower'), cgn.get('upper'), cgn.get('step'))
        );
    }
    return False;
}

impl JcirGenPass._del_slice_value(value: CgNode, nd: DeleteStmt) -> CgNode {
    if value.cls != 'Slice' {
        return value;
    }
    return self.call_node(
        self.name_load('slice', jac_node=nd),
        [
            part if isinstance(part, CgNode) else self.const_of(None)
            for part in (value.get('lower'), value.get('upper'), value.get('step'))
        ],
        []
    );
}

impl JcirGenPass._del_bind_temp(
    value: CgNode, name: str, stmts: list[CgItem], nd: DeleteStmt
) -> CgNode {
    bound = self._del_slice_value(value, nd);
    stmts.append(
        self.nod(
            'Assign',
            ['targets', 'value'],
            [
                [self.nod('Name', ['id', 'ctx'], [name, self.nod('Store', [], [])])],
                bound
            ],
            jac_node=nd
        )
    );
    return self.name_load(name, jac_node=nd);
}

impl JcirGenPass._del_location(
    target: Expr, nd: DeleteStmt, ordinal: int
) -> list[CgItem] {
    stmts: list[CgItem] = [];
    if isinstance(target, Name) {
        stmts.append(self._destroy_call(self._del_ctx_target(target, 'Load'), False));
        stmts.append(
            self.nod('Delete', ['targets'], [[self._del_ctx_target(target, 'Del')]])
        );
        return stmts;
    }
    loaded = self._del_ctx_target(target, 'Load');
    prefix = f"_jac_del_{nd.loc.first_line}_{nd.loc.col_start}_{ordinal}";
    container = loaded.get('value');
    if not self._del_is_trivial(container) {
        container = self._del_bind_temp(container, prefix + "_c", stmts, nd);
    }
    del_ctx = self.nod('Del', [], []);
    if loaded.cls == 'Attribute' {
        attr = loaded.get('attr');
        peek_call = self.call_node(
            self.jaclib_obj('peek_attr'), [container, self.const_of(attr)], []
        );
        del_target = self.nod(
            'Attribute', ['value', 'attr', 'ctx'], [container, attr, del_ctx]
        );
    } else {
        key = loaded.get('slice');
        if not self._del_is_trivial(key) {
            key = self._del_bind_temp(key, prefix + "_k", stmts, nd);
        }
        peek_call = self.call_node(
            self.jaclib_obj('peek_item'),
            [container, self._del_slice_value(key, nd)],
            []
        );
        del_target = self.nod(
            'Subscript', ['value', 'slice', 'ctx'], [container, key, del_ctx]
        );
    }
    stmts.append(self._destroy_call(peek_call, False));
    stmts.append(self.nod('Delete', ['targets'], [[del_target]]));
    return stmts;
}

impl JcirGenPass.exit_delete_stmt with DeleteStmt exit {
    stmts: list[CgItem] = [];
    ordinal = 0;
    for target in here.leaf_targets() {
        if DeleteStmt.is_location(target) {
            stmts.extend(self._del_location(target, here, ordinal));
        } else {
            simple = None;
            if isinstance(target, EdgeRefTrailer) and target.edges_only {
                simple = self._simple_hop(target);
            }
            if simple is not None {
                stmts.append(
                    self.nod(
                        'Expr',
                        ['value'],
                        [self.call_node(self.jaclib_obj('clear_edges'), simple, [])]
                    )
                );
            } else {
                stmts.append(
                    self._destroy_call(self._del_ctx_target(target, 'Load'), True)
                );
            }
        }
        ordinal += 1;
    }
    self.set_out(here, stmts);
}

impl JcirGenPass.exit_return_stmt with ReturnStmt exit {
    self.set_out(
        here,
        [self.nod('Return', ['value'], [self.val(here.expr) if here.expr else None])]
    );
}

impl JcirGenPass._scope_cleanup_body(
    scope: UniNode, body: list[CgNode]
) -> list[CgNode] {
    names = self.ir_in.rc_scope_cleanup.get(id(scope), []);
    if not names {
        return body;
    }
    cleanup = [self._release_name_stmt(name, scope) for name in names];
    offset = self._docstring_offset(body);
    return [
        *body[:offset],
        self.nod(
            'Try',
            ['body', 'handlers', 'orelse', 'finalbody'],
            [body[offset:] or [self.nod('Pass', [], [])], [], [], cleanup]
        )
    ];
}

impl JcirGenPass._release_name_stmt(name: str, source: UniNode) -> CgNode {
    return self.nod(
        'Try',
        ['body', 'handlers', 'orelse', 'finalbody'],
        [
            [
                self.nod(
                    'Delete',
                    ['targets'],
                    [[self.nod('Name', ['id', 'ctx'], [name, self.nod('Del', [], [])])]]
                )
            ],
            [
                self.nod(
                    'ExceptHandler',
                    ['type', 'name', 'body'],
                    [
                        self._import_ref('builtins', 'UnboundLocalError', source),
                        None,
                        [self.nod('Pass', [], [])]
                    ]
                )
            ],
            [],
            []
        ],
        jac_node=source
    );
}
