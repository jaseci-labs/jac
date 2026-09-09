impl JcirGenPass.exit_yield_expr with YieldExpr exit {
    if not here.with_from {
        self.set_out(
            here,
            [self.nod('Yield', ['value'], [self.val(here.expr) if here.expr else None])]
        );
    } else {
        self.set_out(
            here,
            [
                self.nod(
                    'YieldFrom',
                    ['value'],
                    [self.val(here.expr) if here.expr else self.const_of(None)]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_await_expr with AwaitExpr exit {
    self.set_out(here, [self.nod('Await', ['value'], [self.val(here.target)])]);
}

impl JcirGenPass.exit_cast_expr with CastExpr exit {
    self.set_out(here, self.outs(here.value));
}

impl JcirGenPass.exit_assignment with Assignment exit {
    value: (CgNode | None) = None;
    init_cv = here.value.ct_value if here.value else None;
    if here.value
        and here.is_comptime
        and init_cv is not None
        and self._ct_concrete(here.value) {
        value = self._materialize(init_cv.v, here.value);
        if value is None {
            value = self.val(here.value);
        }
    } elif here.value {
        value = self.val(here.value);
    } elif here.is_enum_stmt {
        value = self.call_node(self.name_load('auto'), [], []);
    } elif not here.type_tag {
        raise RuntimeError(
            self.ice('assignment has no value, no enum default and no type tag')
        );
    }
    targets_ast = [self.val(t) for t in here.target];
    class_body_ct = (
        here.is_comptime
        and isinstance(here.parent, GlobalVars)
        and isinstance(here.parent.parent, Archetype)
    );
    ct_val0 = here.value;
    if class_body_ct and ct_val0 is not None and not self._ct_concrete(ct_val0) {
        tgt0 = here.target[0] if here.target else None;
        if isinstance(tgt0, Name) {
            self.set_out(
                here,
                [
                    self.nod(
                        'FunctionDef',
                        ['name', 'args', 'body', 'decorator_list', 'returns'],
                        [
                            tgt0.sym_name,
                            self.nod(
                                'arguments',
                                [
                                    'posonlyargs',
                                    'args',
                                    'kwonlyargs',
                                    'kw_defaults',
                                    'defaults'
                                ],
                                [
                                    [],
                                    [
                                        self.nod(
                                            'arg', ['arg', 'annotation'], ['self', None]
                                        )
                                    ],
                                    [],
                                    [],
                                    []
                                ]
                            ),
                            [
                                self.nod(
                                    'Return',
                                    ['value'],
                                    [self.val(ct_val0)],
                                    jac_node=here
                                )
                            ],
                            [self.name_load('property', here)],
                            None
                        ],
                        jac_node=here
                    )
                ]
            );
            return;
        }
    }
    if here.type_tag and not class_body_ct {
        assignment_stmt = self.nod(
            'AnnAssign',
            ['target', 'annotation', 'value', 'simple'],
            [
                targets_ast[0],
                self.val(here.type_tag),
                value if here.value else None,
                int(isinstance(targets_ast[0], CgNode) and targets_ast[0].cls == 'Name')
            ]
        );
    } elif here.aug_op {
        _fw_aug = self._fw_aug_assign(
            here, targets_ast[0], value if isinstance(value, CgNode) else None
        );
        assignment_stmt = _fw_aug
            if _fw_aug is not None
            else self.nod(
                'AugAssign',
                ['target', 'op', 'value'],
                [
                    targets_ast[0],
                    self.val(here.aug_op),
                    value if isinstance(value, CgNode) else self.const_of(None)
                ]
            );
    } else {
        assignment_stmt = self.nod(
            'Assign',
            ['targets', 'value'],
            [targets_ast, value if isinstance(value, CgNode) else self.const_of(None)]
        );
    }
    self.set_out(here, [assignment_stmt]);
}

impl JcirGenPass.exit_binary_expr with BinaryExpr exit {
    if isinstance(here.op, ConnectOp) {
        left = self.val(here.right)
            if (here.op.edge_dir == EdgeDir.IN)
            else self.val(here.left);
        right = self.val(here.left)
            if (here.op.edge_dir == EdgeDir.IN)
            else self.val(here.right);
        keywords = [
            self.nod('keyword', ['arg', 'value'], ['left', left]),
            self.nod('keyword', ['arg', 'value'], ['right', right])
        ];
        if here.op.capture_edges {
            keywords.append(
                self.nod(
                    'keyword', ['arg', 'value'], ['edges_only', self.const_of(True)]
                )
            );
        }
        if here.op.conn_type {
            keywords.append(
                self.nod(
                    'keyword', ['arg', 'value'], ['edge', self.val(here.op.conn_type)]
                )
            );
        }
        if (here.op.edge_dir == EdgeDir.ANY) {
            keywords.append(
                self.nod('keyword', ['arg', 'value'], ['undir', self.const_of(True)])
            );
        }
        if here.op.conn_assign {
            keywords.append(
                self.nod(
                    'keyword',
                    ['arg', 'value'],
                    ['conn_assign', self.val(here.op.conn_assign)]
                )
            );
        }
        self.set_out(here, [self.call_node(self.jaclib_obj('connect'), [], keywords)]);
    } elif isinstance(here.op, DisconnectOp) {
        keywords = [
            self.nod('keyword', ['arg', 'value'], ['left', self.val(here.left)]),
            self.nod('keyword', ['arg', 'value'], ['right', self.val(here.right)])
        ];
        if (here.op.edge_spec.edge_dir != EdgeDir.OUT) {
            keywords.append(
                self.nod(
                    'keyword',
                    ['arg', 'value'],
                    [
                        'dir',
                        self.nod(
                            'Attribute',
                            ['value', 'attr', 'ctx'],
                            [
                                self.jaclib_obj('EdgeDir'),
                                EDGE_DIR_NAMES[int(here.op.edge_spec.edge_dir)],
                                self.nod('Load', [], [])
                            ]
                        )
                    ]
                )
            );
        }
        if here.op.edge_spec.filter_cond {
            keywords.append(
                self.nod(
                    'keyword',
                    ['arg', 'value'],
                    ['filter', self.val(here.op.edge_spec.filter_cond)]
                )
            );
        }
        self.set_out(
            here, [self.call_node(self.jaclib_obj('disconnect'), [], keywords)]
        );
    } elif (here.op.name in [Tok.KW_AND.value, Tok.KW_OR.value]) {
        self.set_out(
            here,
            [
                self.nod(
                    'BoolOp',
                    ['op', 'values'],
                    [self.val(here.op), [self.val(here.left), self.val(here.right)]]
                )
            ]
        );
    } elif ((here.op.name in [Tok.WALRUS_EQ]) and self.val(here.left).cls == 'Name') {
        self.val(here.left).setf('ctx', self.nod('Store', [], []));
        self.set_out(
            here,
            [
                self.nod(
                    'NamedExpr',
                    ['target', 'value'],
                    [self.val(here.left), self.val(here.right)]
                )
            ]
        );
    } elif ((here.op.name in [Tok.WALRUS_EQ]) and not isinstance(here.left, Name)) {
        self.set_out(here, [self.val(here.right)]);
    } elif self.outs(here.op) {
        self.set_out(
            here,
            [
                self.nod(
                    'BinOp',
                    ['left', 'op', 'right'],
                    [self.val(here.left), self.val(here.op), self.val(here.right)]
                )
            ]
        );
    } else {
        self.set_out(here, self.translate_jac_bin_op(here));
    }
}

impl JcirGenPass.translate_jac_bin_op(nd: BinaryExpr) -> list {
    if not isinstance(nd.op, Token) {
        raise RuntimeError(
            self.ice('translate_jac_bin_op reached a non-token operator')
        );
    }
    if (nd.op.name in [Tok.PIPE_FWD, Tok.A_PIPE_FWD]) {
        func_node = FuncCall(
            target=nd.right,
            params=list(nd.left.values)
                if (isinstance(nd.left, TupleVal) and nd.left.values)
                else [nd.left],
            genai_call=None,
            kid=nd.kid
        );
        if nd.parent is not None {
            func_node.set_parent(nd.parent);
        }
        self._exit_func_call_impl(func_node);
        return self.outs(func_node);
    } elif (nd.op.name in [Tok.KW_SPAWN]) {
        for side in (nd.right, nd.left) {
            if self._sv_bridge_walker_call(side) is not None {
                return [self.val(side)];
            }
        }
        return [
            self.call_node(
                self.jaclib_obj('spawn'), [self.val(nd.left), self.val(nd.right)], []
            )
        ];
    } elif (nd.op.name in [Tok.PIPE_BKWD, Tok.A_PIPE_BKWD]) {
        func_node = FuncCall(
            target=nd.left,
            params=list(nd.right.values)
                if (isinstance(nd.right, TupleVal) and nd.right.values)
                else [nd.right],
            genai_call=None,
            kid=nd.kid
        );
        if nd.parent is not None {
            func_node.set_parent(nd.parent);
        }
        self._exit_func_call_impl(func_node);
        return self.outs(func_node);
    } elif (nd.op.name in [Tok.KW_BY]) {
        return [
            self.call_node(
                self.jaclib_obj('by_operator'),
                [self.val(nd.left), self.val(nd.right)],
                []
            )
        ];
    } elif ((nd.op.name == Tok.PIPE_FWD) and isinstance(nd.right, TupleVal)) {
        self.emit(E5006);
    } else {
        self.emit(E5007, op=str(nd.op.value));
    }
    return [];
}

impl JcirGenPass.exit_compare_expr with CompareExpr exit {
    self.set_out(
        here,
        [
            self.nod(
                'Compare',
                ['left', 'ops', 'comparators'],
                [
                    self.val(here.left),
                    [self.val(i) for i in here.ops],
                    [self.val(i) for i in here.rights]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_cfg_expr with CfgExpr exit {
    self.set_out(here, self.outs(here.expr));
}

impl JcirGenPass.exit_bool_expr with BoolExpr exit {
    self.set_out(
        here,
        [
            self.nod(
                'BoolOp',
                ['op', 'values'],
                [self.val(here.op), [self.val(i) for i in here.values]]
            )
        ]
    );
}

impl JcirGenPass.enter_lambda_expr with LambdaExpr entry {
    self._push_hoist_frame();
}

impl JcirGenPass.exit_lambda_expr with LambdaExpr exit {
    frame = self._hoist_frames.pop();
    signature_roots: list[UniNode] = [here.signature] if here.signature else [];
    (body_hoists, enclosing_hoists) = self._split_scope_hoists(frame, signature_roots);
    self._hoist_frames[-1].extend(enclosing_hoists);
    tail = here.body if isinstance(here.body, Expr) else here.tail_return_expr();
    if tail is not None and not body_hoists {
        self._emit_lambda_expr_body(here, tail);
        return;
    }
    if isinstance(here.body, list) or tail is not None {
        if (here.signature and self.outs(here.signature)) {
            arguments = self.val(here.signature);
        } else {
            arguments = self.nod(
                'arguments',
                ['posonlyargs', 'args', 'kwonlyargs', 'kw_defaults', 'defaults'],
                [[], [], [], [], []],
                jac_node=here
            );
        }
        body_stmts: list[CgItem];
        if tail is not None {
            body_stmts = [
                self.nod('Return', ['value'], [self.val(tail)], jac_node=here)
            ];
        } else {
            assert not isinstance(here.body, Expr);
            body_stmts = self.resolve_stmt_block(here.body, doc=None);
        }
        body_stmts = [*body_hoists, *body_stmts];
        directive_stmts = self.scope_directive_stmts([here]);
        if directive_stmts {
            body_stmts = [*directive_stmts, *body_stmts];
        }
        if not body_stmts {
            body_stmts = [self.nod('Pass', [], [], jac_node=here)];
        }
        func_name = self._next_lambda_name();
        returns = self.val(here.signature.return_type)
            if (
                here.signature
                and here.signature.return_type
                and self.outs(here.signature.return_type)
            )
            else None;
        func_def = self.nod(
            'FunctionDef',
            ['name', 'args', 'body', 'decorator_list', 'returns', 'type_params'],
            [func_name, arguments, body_stmts, [], returns, []],
            jac_node=here
        );
        self.set_out(here, [self._function_expr_from_def(func_def, here)]);
        return;
    }
    if not isinstance(here.body, Expr) {
        raise RuntimeError(
            self.ice('lambda statement body fell past the FunctionDef path')
        );
    }
    self._emit_lambda_expr_body(here, here.body);
}

impl JcirGenPass._emit_lambda_expr_body(nd: LambdaExpr, body_node: Expr) -> None {
    if nd.signature {
        self._remove_lambda_param_annotations(nd.signature);
    }
    if (nd.signature and self.outs(nd.signature)) {
        arguments = self.val(nd.signature);
    } else {
        arguments = self.nod(
            'arguments',
            ['posonlyargs', 'args', 'kwonlyargs', 'kw_defaults', 'defaults'],
            [[], [], [], [], []],
            jac_node=nd
        );
    }
    self.set_out(
        nd,
        [
            self.nod(
                'Lambda',
                ['args', 'body'],
                [arguments, self.val(body_node)],
                jac_node=nd
            )
        ]
    );
}

impl JcirGenPass._remove_lambda_param_annotations(signature: FuncSignature) -> None {
    for param in signature.params {
        if (self.outs(param) and self.val(param).cls == 'arg') {
            self.val(param).setf('annotation', None);
        }
    }
}

impl JcirGenPass._emit_jobj_ref(nd: UnaryExpr) -> None {
    self.set_out(
        nd,
        [
            self.call_node(
                self.builtin_name('jobj'),
                [],
                [self.nod('keyword', ['arg', 'value'], ['id', self.val(nd.operand)])]
            )
        ]
    );
}

impl JcirGenPass.exit_unary_expr with UnaryExpr exit {
    if here.ownership in (OwnershipKind.OWN, OwnershipKind.IMM) {
        self.set_out(here, [self.val(here.operand)]);
        return;
    }
    if here.op.name == Tok.BW_AND {
        if is_borrow_kind(here.ownership) {
            self.set_out(here, [self.val(here.operand)]);
        } else {
            self._emit_jobj_ref(here);
        }
        return;
    }
    op_name = here.op.name;
    op_cls = UNARY_CLS_BY_NAME[op_name] if op_name in UNARY_CLS_BY_NAME else '';
    if op_cls {
        self.set_out(
            here,
            [
                self.nod(
                    'UnaryOp',
                    ['op', 'operand'],
                    [self.nod(op_cls, [], []), self.val(here.operand)]
                )
            ]
        );
        return;
    } elif (here.op.name in [Tok.PIPE_FWD, Tok.KW_SPAWN, Tok.A_PIPE_FWD]) {
        self.set_out(here, [self.call_node(self.val(here.operand), [], [])]);
    } elif (here.op.name in [Tok.STAR_MUL]) {
        ctx_val = self.py_ctx(here.operand)
            if isinstance(here.operand, AstSymbolNode)
            else self.nod('Load', [], []);
        self.set_out(
            here,
            [self.nod('Starred', ['value', 'ctx'], [self.val(here.operand), ctx_val])]
        );
    } elif (here.op.name in [Tok.STAR_POW]) {
        self.set_out(here, self.outs(here.operand));
    } else {
        raise RuntimeError(self.ice("Unknown Unary operator " + here.op.value));
    }
}

impl JcirGenPass.exit_if_else_expr with IfElseExpr exit {
    self.set_out(
        here,
        [
            self.nod(
                'IfExp',
                ['test', 'body', 'orelse'],
                [
                    self.val(here.condition),
                    self.val(here.value),
                    self.val(here.else_value)
                ]
            )
        ]
    );
}

impl JcirGenPass._multi_string_pieces(str_seq: Sequence[UniNode]) -> list {
    pieces: list[any] = [];
    for i in str_seq {
        if isinstance(i, String) {
            pieces.append(i.lit_value);
        } elif isinstance(i, (FString, ExprStmt)) {
            py_val = self.val(i);
            if py_val.cls == 'JoinedStr' {
                for v in py_val.get('values') {
                    pieces.append(v);
                }
            } else {
                pieces.append(py_val);
            }
        } elif (isinstance(i, Token) and (i.name in [Tok.LBRACE, Tok.RBRACE])) {
            continue;
        } else {
            raise RuntimeError(self.ice('Multi string made of something weird.'));
        }
    }
    return pieces;
}

impl JcirGenPass.exit_multi_string with MultiString exit {
    lone = here.strings[0] if (len(here.strings) == 1) else None;
    if (isinstance(lone, FString) and self.outs(lone)) {
        self.set_out(here, self.outs(lone));
        return;
    }
    combined_multi: list = [];
    for item in self._multi_string_pieces(here.strings) {
        if (
            combined_multi
            and isinstance(item, str)
            and isinstance((tail_str := combined_multi[-1]), str)
        ) {
            combined_multi[-1] = tail_str + item;
        } elif (
            combined_multi
            and isinstance(item, bytes)
            and isinstance((tail_bytes := combined_multi[-1]), bytes)
        ) {
            combined_multi[-1] = tail_bytes + item;
        } else {
            combined_multi.append(item);
        }
    }
    for (i, v) in enumerate(combined_multi) {
        if isinstance(v, (str, bytes)) {
            combined_multi[i] = self.const_of(v);
        }
    }
    merged: list[CgNode] = [];
    for v in combined_multi {
        prev: (CgNode | None) = merged[-1] if merged else None;
        folded = False;
        if (prev is not None and isinstance(v, CgNode) and v.cls == 'Constant') {
            next_const = v.get('value');
            prev_const = prev.get('value') if prev.cls == 'Constant' else None;
            if (isinstance(next_const, str) and isinstance(prev_const, str)) {
                merged[-1] = self.const_of(prev_const + next_const);
                folded = True;
            }
        }
        if not folded {
            merged.append(v);
        }
    }
    if not merged {
        self.set_out(here, [self.const_of('')]);
    } elif (len(merged) == 1 and merged[0].cls == 'Constant') {
        self.set_out(here, [merged[0]]);
    } else {
        self.set_out(here, [self.nod('JoinedStr', ['values'], [merged])]);
    }
}

impl JcirGenPass.exit_f_string with FString exit {
    self.set_out(
        here,
        [
            self.nod(
                'JoinedStr',
                ['values'],
                [
                    [
                        self.val(part)
                        for part in here.parts
                        if self.outs(part)
                    ]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_formatted_value with FormattedValue exit {
    self.set_out(
        here,
        [
            self.nod(
                'FormattedValue',
                ['value', 'conversion', 'format_spec'],
                [
                    self.val(here.format_part),
                    here.conversion,
                    self.val(here.format_spec) if here.format_spec else None
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_list_val with ListVal exit {
    self.set_out(
        here,
        [
            self.nod(
                'List',
                ['elts', 'ctx'],
                [[self.val(v) for v in here.values], self.py_ctx(here)]
            )
        ]
    );
}

impl JcirGenPass.exit_set_val with SetVal exit {
    self.set_out(
        here, [self.nod('Set', ['elts'], [[self.val(i) for i in here.values]])]
    );
}

impl JcirGenPass.exit_tuple_val with TupleVal exit {
    self.set_out(
        here,
        [
            self.nod(
                'Tuple',
                ['elts', 'ctx'],
                [[self.val(i) for i in here.values], self.py_ctx(here)]
            )
        ]
    );
}

impl JcirGenPass.exit_dict_val with DictVal exit {
    self.set_out(
        here,
        [
            self.nod(
                'Dict',
                ['keys', 'values'],
                [
                    [self.val(x.key) if x.key else None for x in here.kv_pairs],
                    [self.val(x.value) for x in here.kv_pairs]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_k_v_pair with KVPair exit {}

impl JcirGenPass.exit_k_w_pair with KWPair exit {
    self.set_out(
        here,
        [
            self.nod(
                'keyword',
                ['arg', 'value'],
                [
                    here.key.sym_name
                        if (here.key and self.val(here.key).cls == 'Name')
                        else None,
                    self.val(here.value)
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_inner_compr with InnerCompr exit {
    self.set_out(
        here,
        [
            self.nod(
                'comprehension',
                ['target', 'iter', 'ifs', 'is_async'],
                [
                    self.val(here.target),
                    self.val(here.collection),
                    [self.val(x) for x in here.conditional] if here.conditional else [],
                    0
                ]
            )
        ]
    );
}

impl JcirGenPass.enter_list_compr with ListCompr entry {
    if here.__class__ is ListCompr {
        self._push_hoist_frame();
    }
}

impl JcirGenPass.exit_list_compr with ListCompr exit {
    if here.__class__ is not ListCompr {
        return;
    }
    frame = self._hoist_frames.pop();
    (hoists, enclosing_hoists) = self._split_scope_hoists(
        frame, [here.compr[0].collection]
    );
    self._hoist_frames[-1].extend(enclosing_hoists);
    if hoists {
        self.set_out(here, [self._statement_list_comprehension(here, hoists)]);
        return;
    }
    self.set_out(
        here,
        [
            self.nod(
                'ListComp',
                ['elt', 'generators'],
                [self.val(here.out_expr), [self.val(i) for i in here.compr]]
            )
        ]
    );
}

impl JcirGenPass._statement_list_comprehension(
    nd: ListCompr, hoists: list[CgNode]
) -> CgNode {
    func_name = self._next_lambda_name();
    result_name = self._reserve_name(func_name + '_result');
    iterable_name = self._reserve_name(func_name + '_iterable');
    result = self.name_load(result_name, jac_node=nd);
    append = self.nod(
        'Attribute',
        ['value', 'attr', 'ctx'],
        [result, 'append', self.nod('Load', [], [])]
    );
    call = self.nod(
        'Call', ['func', 'args', 'keywords'], [append, [self.val(nd.out_expr)], []]
    );
    statements: list[CgNode] = [self.nod('Expr', ['value'], [call])];
    for index in range(len(nd.compr) - 1, -1, -1) {
        generator = self.val(nd.compr[index]);
        conditions = generator.get('ifs');
        for condition in reversed(conditions) {
            statements = [
                self.nod('If', ['test', 'body', 'orelse'], [condition, statements, []])
            ];
        }
        iterable = self.name_load(iterable_name, jac_node=nd)
            if index == 0
            else generator.get('iter');
        statements = [
            self.nod(
                'For',
                ['target', 'iter', 'body', 'orelse', 'type_comment'],
                [generator.get('target'), iterable, statements, [], None]
            )
        ];
    }
    target = self.nod('Name', ['id', 'ctx'], [result_name, self.nod('Store', [], [])]);
    empty = self.nod('List', ['elts', 'ctx'], [[], self.nod('Load', [], [])]);
    initialize = self.nod('Assign', ['targets', 'value'], [[target], empty]);
    body: list[CgItem] = [
        *hoists,
        initialize,
        *statements,
        self.nod('Return', ['value'], [result])
    ];
    argument = self.nod('arg', ['arg', 'annotation'], [iterable_name, None]);
    arguments = self.nod(
        'arguments',
        ['posonlyargs', 'args', 'kwonlyargs', 'kw_defaults', 'defaults'],
        [[], [argument], [], [], []]
    );
    function = self.nod(
        'FunctionDef',
        ['name', 'args', 'body', 'decorator_list', 'returns', 'type_params'],
        [func_name, arguments, body, [], None, []],
        jac_node=nd
    );
    reference = self._function_expr_from_def(function, nd);
    return self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [reference, [self.val(nd.compr[0]).get('iter')], []],
        jac_node=nd
    );
}

impl JcirGenPass.exit_gen_compr with GenCompr exit {
    self.set_out(
        here,
        [
            self.nod(
                'GeneratorExp',
                ['elt', 'generators'],
                [self.val(here.out_expr), [self.val(i) for i in here.compr]]
            )
        ]
    );
}

impl JcirGenPass.exit_set_compr with SetCompr exit {
    self.set_out(
        here,
        [
            self.nod(
                'SetComp',
                ['elt', 'generators'],
                [self.val(here.out_expr), [self.val(i) for i in here.compr]]
            )
        ]
    );
}

impl JcirGenPass.exit_dict_compr with DictCompr exit {
    self.set_out(
        here,
        [
            self.nod(
                'DictComp',
                ['key', 'value', 'generators'],
                [
                    self.val(here.kv_pair.key)
                        if here.kv_pair.key
                        else self.const_of(None),
                    self.val(here.kv_pair.value),
                    [self.val(i) for i in here.compr]
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_name with Name exit {
    if here.__class__ is not Name {
        return;
    }
    if here.expr_ctx == ExprCtx.LOAD
        and id(here) in self.ir_in.own_move_sites
        and here.sym is not None
        and here.sym.storage in (SymbolStorage.LOCAL, SymbolStorage.PARAM) {
        self.set_out(here, [self._name_take_expr(self._py_name(here))]);
        return;
    }
    name = here.sym_name;
    if self._is_ct_type_param(here) and here.expr_ctx == ExprCtx.LOAD {
        self.set_out(
            here,
            [
                self.nod(
                    'Attribute',
                    ['value', 'attr', 'ctx'],
                    [self.name_load('self', here), name, self.nod('Load', [], [])],
                    jac_node=here
                )
            ]
        );
        return;
    }
    if name == "Self" {
        resolved = self._resolve_self_type(here);
        if resolved is not None {
            self.set_out(here, [resolved]);
            return;
        }
    }
    name_cv = here.ct_value;
    if name_cv is not None
        and self._ct_concrete(here)
        and here.expr_ctx == ExprCtx.LOAD {
        cv = name_cv.v;
        if self._is_comptime_only_name(here)
            or self._ct_kind(cv) in ("scalar", "CtEnumMember") {
            folded = self._materialize(cv, here);
            if folded is not None {
                self.set_out(here, [folded]);
                return;
            }
        }
    }
    if not is_identifier_slot(here) {
        if (name in self._get_builtin_names()) {
            self.builtin_imports.add(name);
        }
        if (name in self._get_ambient_typing_names()) {
            self.typing_imports.add(name);
        }
    }
    self.set_out(here, [self.nod('Name', ['id', 'ctx'], [name, self.py_ctx(here)])]);
}

impl JcirGenPass._resolve_self_type(nd: Name) -> (CgNode | None) {
    arch = nd.find_parent_of_type(Archetype);
    enum_parent = nd.find_parent_of_type(Enum) if not arch else None;
    enclosing = arch or enum_parent;
    enclosing_name: str | None = None;
    if enclosing {
        enclosing_name = enclosing.name.sym_name if enclosing.name else None;
    }
    if not enclosing_name {
        impl_def = nd.find_parent_of_type(ImplDef);
        if (impl_def and impl_def.target and len(impl_def.target) > 0) {
            enclosing_name = impl_def.target[0].sym_name
                if isinstance(impl_def.target[0], NameAtom)
                else None;
        }
    }
    if not enclosing_name {
        return None;
    }
    if self._is_in_type_annotation(nd) {
        return self.name_load(enclosing_name);
    }
    ability = nd.find_parent_of_type(Ability);
    impl_def = nd.find_parent_of_type(ImplDef);
    is_in_classmethod = False;
    is_in_method = False;
    if ability {
        is_in_classmethod = ability.is_cls_method;
        is_in_method = ability.is_method
            and not ability.is_static
            and not ability.is_cls_method;
    } elif (
        impl_def and impl_def.decl_link and isinstance(impl_def.decl_link, Ability)
    ) {
        is_in_classmethod = impl_def.decl_link.is_cls_method;
        is_in_method = (
            impl_def.decl_link.is_method
            and not impl_def.decl_link.is_static
            and not impl_def.decl_link.is_cls_method
        );
    }
    if is_in_classmethod {
        return self.nod('Name', ['id', 'ctx'], ['cls', self.py_ctx(nd)]);
    }
    if is_in_method {
        return self.call_node(self.name_load('type'), [self.name_load('self')], []);
    }
    return self.nod('Name', ['id', 'ctx'], [enclosing_name, self.py_ctx(nd)]);
}

impl JcirGenPass._is_in_type_annotation(nd: UniNode) -> bool {
    parent = nd.parent;
    while parent {
        if isinstance(parent, FuncSignature) {
            if parent.return_type {
                return self._is_descendant_of(nd, parent.return_type);
            }
        }
        if isinstance(parent, ParamVar) {
            if parent.type_tag {
                return True;
            }
        }
        if isinstance(parent, HasVar) {
            if parent.type_tag {
                return True;
            }
        }
        if isinstance(parent, SubTag) {
            return True;
        }
        parent = parent.parent;
    }
    return False;
}

impl JcirGenPass._is_descendant_of(nd: UniNode, ancestor: UniNode) -> bool {
    if nd is ancestor {
        return True;
    }
    current = nd.parent;
    while current {
        if current is ancestor {
            return True;
        }
        current = current.parent;
    }
    return False;
}

impl JcirGenPass.exit_float with Float exit {
    self.set_out(here, [self.const_of(float(here.value))]);
}

impl JcirGenPass.exit_int with Int exit {
    self.set_out(here, [self.const_of(int(here.value, 0))]);
}

impl JcirGenPass.exit_string with String exit {
    self.set_out(here, [self.const_of(here.lit_value)]);
}

impl JcirGenPass.exit_bool with Bool exit {
    self.set_out(here, [self.const_of(here.value == 'True')]);
}

impl JcirGenPass.exit_builtin_type with BuiltinType exit {
    if here.sym_name in self._get_builtin_names() {
        self.builtin_imports.add(here.sym_name);
    }
    if here.sym_name == "any" {
        parent = here.parent;
        is_call_func = (
            parent is not None
            and isinstance(parent, FuncCall)
            and parent.target is here
        );
        if not is_call_func {
            self.typing_imports.add("Any");
            self.set_out(
                here, [self.nod('Name', ['id', 'ctx'], ["Any", self.py_ctx(here)])]
            );
            return;
        }
    }
    self.set_out(
        here, [self.nod('Name', ['id', 'ctx'], [here.sym_name, self.py_ctx(here)])]
    );
}

impl JcirGenPass.exit_null with Null exit {
    self.set_out(here, [self.const_of(None)]);
}

impl JcirGenPass.exit_ellipsis with Ellipsis exit {
    self.set_out(here, [self.const_of(CgEllipsis())]);
}
