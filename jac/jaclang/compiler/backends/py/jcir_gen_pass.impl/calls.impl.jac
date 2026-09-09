impl JcirGenPass.exit_atom_trailer with AtomTrailer exit {
    if here.is_genai {
        self.set_out(here, []);
    }
    trailer_cv = here.ct_value;
    if (
        here.is_attr
        and trailer_cv is not None
        and self._ct_concrete(here)
        and self._ct_kind(trailer_cv.v) in ("scalar", "CtEnumMember")
        and self._trailer_reaches_ct_class(here)
    ) {
        folded = self._materialize(trailer_cv.v, here);
        if folded is not None {
            self.set_out(here, [folded]);
            return;
        }
    }
    ct_slots = self._ct_ctor_slots(here);
    if ct_slots is not None {
        kws: list = [];
        for pair in ct_slots {
            pname: str = pair[0];
            pexpr: UniNode = pair[1];
            kws.append(self.nod('keyword', ['arg', 'value'], [pname, self.val(pexpr)]));
        }
        self.set_out(
            here,
            [
                self.call_node(
                    self._import_ref("jaclang.comptime", "specialize", here),
                    [self.val(here.target)],
                    kws,
                    jac_node=here
                )
            ]
        );
        return;
    }
    if here.is_attr {
        if isinstance(here.right, AstSymbolNode) {
            self.set_out(
                here,
                [
                    self.nod(
                        'Attribute',
                        ['value', 'attr', 'ctx'],
                        [
                            self.val(here.target),
                            self._py_name(here.right),
                            self.py_ctx(here.right)
                        ]
                    )
                ]
            );
        } else {
            self.emit(E5008);
        }
    } elif isinstance(here.right, FilterCompr) {
        if self._is_edge_ref_target(here.target) {
            target_py = self.val(here.target);
            narrow_kws = self._query_filter_kws(here.right, 'nd', 'preds');
            target_py.get('args')[0] = self.call_node(
                self.nod(
                    'Attribute',
                    ['value', 'attr', 'ctx'],
                    [target_py.get('args')[0], 'narrow', self.nod('Load', [], [])]
                ),
                [],
                narrow_kws
            );
            self.set_out(here, [target_py]);
        } else {
            self.set_out(
                here,
                [
                    self.call_node(
                        self.jaclib_obj('filter_on'),
                        [],
                        [
                            self.nod(
                                'keyword',
                                ['arg', 'value'],
                                ['items', self.val(here.target)]
                            ),
                            self.nod(
                                'keyword',
                                ['arg', 'value'],
                                ['func', self.val(here.right)]
                            )
                        ]
                    )
                ]
            );
        }
    } elif isinstance(here.right, AssignCompr) {
        self.set_out(
            here,
            [
                self.call_node(
                    self.jaclib_obj('assign_all'),
                    [self.val(here.target), self.val(here.right)],
                    []
                )
            ]
        );
    } elif (
        isinstance(here.right, IndexSlice)
        and here.right.is_range
        and len(here.right.slices) == 1
        and self._is_edge_ref_target(here.target)
    ) {
        target_py = self.val(here.target);
        slc = here.right.slices[0];
        start_ast = self.val(slc.start) if slc.start else self.const_of(None);
        stop_ast = self.val(slc.stop) if slc.stop else self.const_of(None);
        step_ast = self.val(slc.step) if slc.step else self.const_of(None);
        slice_call = self.call_node(
            self.name_load('slice'), [start_ast, stop_ast, step_ast], []
        );
        target_py.get('keywords').append(
            self.nod('keyword', ['arg', 'value'], ['slc', slice_call])
        );
        self.set_out(here, [target_py]);
    } else {
        self.set_out(
            here,
            [
                self.nod(
                    'Subscript',
                    ['value', 'slice', 'ctx'],
                    [
                        self.val(here.target),
                        self.val(here.right),
                        self.py_ctx(here.right)
                            if isinstance(here.right, AstSymbolNode)
                            else self.nod('Load', [], [])
                    ]
                )
            ]
        );
        if self.val(here.right).hasf('ctx') {
            self.val(here.right).setf('ctx', self.nod('Load', [], []));
        }
    }
    if here.is_null_ok {
        walrus_assign = self.nod(
            'NamedExpr',
            ['target', 'value'],
            [
                self.nod(
                    'Name', ['id', 'ctx'], ['__jac_tmp', self.nod('Store', [], [])]
                ),
                self.val(here.target)
            ]
        );
        tmp_ref = self.name_load('__jac_tmp');
        none_const = self.const_of(None);
        cur = self.val(here);
        body_expr: CgNode;
        if cur.cls == 'Attribute' {
            body_expr = self.call_node(
                self.name_load('getattr'),
                [tmp_ref, self.const_of(cur.get('attr')), none_const],
                []
            );
        } elif cur.cls == 'Call' {
            cfunc = cur.get('func');
            if (
                isinstance(cfunc, CgNode)
                and (
                    cfunc.cls == 'Attribute'
                    or (cfunc.cls == 'Name' and cfunc.get('id') == 'filter_on')
                )
            ) {
                for kw in cur.get('keywords') {
                    if (isinstance(kw, CgNode) and kw.get('arg') == 'items') {
                        kw.setf('value', tmp_ref);
                    }
                }
            }
            if (
                isinstance(cfunc, CgNode)
                and (
                    cfunc.cls == 'Attribute'
                    or (cfunc.cls == 'Name' and cfunc.get('id') == 'assign_all')
                )
                and cur.get('args')
            ) {
                cur.get('args')[0] = tmp_ref;
            }
            body_expr = cur;
        } elif cur.cls == 'Subscript' {
            body_expr = self.call_node(
                self.jaclib_obj('safe_subscript'), [tmp_ref, cur.get('slice')], []
            );
        } else {
            cur.setf('value', tmp_ref);
            body_expr = cur;
        }
        self.set_out(
            here,
            [
                self.nod(
                    'IfExp',
                    ['test', 'body', 'orelse'],
                    [
                        self.nod(
                            'Compare',
                            ['left', 'ops', 'comparators'],
                            [walrus_assign, [self.nod('IsNot', [], [])], [none_const]]
                        ),
                        body_expr,
                        none_const
                    ]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_atom_unit with AtomUnit exit {
    if (
        isinstance(here.value, Ability)
        and self.outs(here.value)
        and self.val(here.value).cls in ('FunctionDef', 'AsyncFunctionDef')
    ) {
        self.set_out(here, [self._function_expr_from_def(self.val(here.value), here)]);
        return;
    }
    self.set_out(here, self.outs(here.value));
}

impl JcirGenPass.gen_call_args(nd: FuncCall) -> tuple[(list, list)] {
    args: list[CgNode] = [];
    keywords: list[CgNode] = [];
    if nd.params {
        for x in nd.params {
            if (isinstance(x, UnaryExpr) and (x.op.name == Tok.STAR_POW)) {
                keywords.append(
                    self.nod('keyword', ['value'], [self.val(x.operand)], jac_node=x)
                );
            } elif isinstance(x, Expr) {
                args.append(self.val(x));
            } elif (isinstance(x, KWPair) and self.val(x).cls == 'keyword') {
                keywords.append(self.val(x));
            } else {
                raise RuntimeError(self.ice('Invalid Parameter'));
            }
        }
    }
    return (args, keywords);
}

impl JcirGenPass.exit_func_call with FuncCall exit {
    self._exit_func_call_impl(here);
}

impl JcirGenPass._place_parts(arg: UniNode) -> (tuple | None) {
    place = arg;
    if isinstance(arg, UnaryExpr) and is_borrow_kind(arg.ownership) {
        place = arg.operand;
    }
    cg = self.val(place);
    if cg.cls == 'Attribute' {
        return ('attr', cg.get('value'), self.const_of(cg.get('attr')));
    }
    if cg.cls == 'Subscript' {
        return ('item', cg.get('value'), cg.get('slice'));
    }
    if cg.cls == 'Name' {
        return ('name', cg.get('id'), None);
    }
    return None;
}

impl JcirGenPass._name_swap_expr(store_id: str, value: CgNode) -> CgNode {
    return self.nod(
        'NamedExpr',
        ['target', 'value'],
        [self.nod('Name', ['id', 'ctx'], [store_id, self.nod('Store', [], [])]), value]
    );
}

impl JcirGenPass._name_take_expr(owner: str) -> CgNode {
    moved = self.nod(
        'Tuple',
        ['elts', 'ctx'],
        [
            [self.name_load(owner), self._name_swap_expr(owner, self.const_of(None))],
            self.nod('Load', [], [])
        ]
    );
    return self.nod(
        'Subscript',
        ['value', 'slice', 'ctx'],
        [moved, self.const_of(0), self.nod('Load', [], [])]
    );
}

impl JcirGenPass._lower_take(nd: FuncCall) -> (CgNode | None) {
    params = list(nd.params or []);
    if len(params) != 1 or isinstance(params[0], KWPair) {
        return None;
    }
    parts = self._place_parts(params[0]);
    if parts is None {
        return None;
    }
    (kind, owner, key) = parts;
    if kind == 'name' {
        return self._name_take_expr(owner);
    }
    helper = '_jac_take_attr' if kind == 'attr' else '_jac_take_item';
    return self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [self.builtin_name(helper), [owner, key], []]
    );
}

impl JcirGenPass._lower_swap(nd: FuncCall) -> (CgNode | None) {
    params = list(nd.params or []);
    if len(params) != 2 or any([isinstance(p, KWPair) for p in params]) {
        return None;
    }
    pa = self._place_parts(params[0]);
    pb = self._place_parts(params[1]);
    if pa is None or pb is None {
        return None;
    }
    (ka, oa, keya) = pa;
    (kb, ob, keyb) = pb;
    if ka == 'name' and kb == 'name' {
        inner = self.nod(
            'Tuple',
            ['elts', 'ctx'],
            [
                [self.name_load(ob), self._name_swap_expr(ob, self.name_load(oa))],
                self.nod('Load', [], [])
            ]
        );
        old_b = self.nod(
            'Subscript',
            ['value', 'slice', 'ctx'],
            [inner, self.const_of(0), self.nod('Load', [], [])]
        );
        return self.nod(
            'Subscript',
            ['value', 'slice', 'ctx'],
            [
                self.nod(
                    'Tuple',
                    ['elts', 'ctx'],
                    [
                        [self._name_swap_expr(oa, old_b), self.const_of(None)],
                        self.nod('Load', [], [])
                    ]
                ),
                self.const_of(1),
                self.nod('Load', [], [])
            ]
        );
    }
    if ka == 'name' or kb == 'name' {
        (name_id, pk, pobj, pkey) = (oa, kb, ob, keyb)
            if ka == 'name'
            else (ob, ka, oa, keya);
        helper = '_jac_replace_attr' if pk == 'attr' else '_jac_replace_item';
        replaced = self.nod(
            'Call',
            ['func', 'args', 'keywords'],
            [self.builtin_name(helper), [pobj, pkey, self.name_load(name_id)], []]
        );
        return self.nod(
            'Subscript',
            ['value', 'slice', 'ctx'],
            [
                self.nod(
                    'Tuple',
                    ['elts', 'ctx'],
                    [
                        [self._name_swap_expr(name_id, replaced), self.const_of(None)],
                        self.nod('Load', [], [])
                    ]
                ),
                self.const_of(1),
                self.nod('Load', [], [])
            ]
        );
    }
    return self.nod(
        'Call',
        ['func', 'args', 'keywords'],
        [
            self.builtin_name('_jac_swap_places'),
            [
                oa,
                keya,
                self.const_of(ka == 'attr'),
                ob,
                keyb,
                self.const_of(kb == 'attr')
            ],
            []
        ]
    );
}

impl JcirGenPass._exit_func_call_impl(nd: FuncCall) -> None {
    if isinstance(nd.target, Name) and nd.target.sym_name in ('take', 'swap') {
        import from jaclang.compiler.symbol_utils { CallKind, classify_call }
        lowered = (
            (
                self._lower_take(nd)
                    if nd.target.sym_name == 'take'
                    else self._lower_swap(nd)
            )
                if classify_call(nd) == CallKind.BUILTIN
                else None
        );
        if lowered is not None {
            self.set_out(nd, [lowered]);
            return;
        }
    }
    call_cv = nd.ct_value;
    if (
        nd.callee_decl is not None
        and nd.callee_decl.is_comptime
        and call_cv is not None
        and self._ct_concrete(nd)
    ) {
        folded = self._materialize(call_cv.v, nd);
        if folded is not None {
            self.set_out(nd, [folded]);
            return;
        }
    }
    if self._fold_sorted_traversal(nd) {
        return;
    }
    self._warn_inplace_sort(nd);
    if nd.genai_call {
        self._refuse(nd, 'genai call expression');
    }
    if (
        isinstance(nd.target, SpecialVarRef)
        and nd.target.name == Tok.KW_ROOT
        and (nd.params is None or len(nd.params) == 0)
    ) {
        self.set_out(nd, self.outs(nd.target));
        return;
    }
    if (
        isinstance(nd.target, AtomTrailer)
        and nd.target.is_attr
        and isinstance(nd.target.right, Name)
        and nd.target.right.sym_name == "chunks"
        and nd.params is not None
        and len(nd.params) == 1
    ) {
        _ck_m = nd.chunks_recv_type if nd.chunks_recv_type is not None else "";
        if (
            _ck_m == "list"
            or _ck_m.startswith("list[")
            or (_ck_m in ("", "Unknown", "None") and nd.target.right.sym is None)
        ) {
            self.set_out(
                nd,
                [
                    self.call_node(
                        self.builtin_name('_jac_chunks'),
                        [self.val(nd.target.target), self.val(nd.params[0])],
                        []
                    )
                ]
            );
            return;
        }
    }
    func = self.val(nd.target);
    (args, keywords) = self.gen_call_args(nd);
    self.set_out(nd, [self.call_node(func, args, keywords)]);
}

impl JcirGenPass.exit_index_slice with IndexSlice exit {
    if here.is_range {
        if (len(here.slices) > 1) {
            self.set_out(
                here,
                [
                    self.nod(
                        'Tuple',
                        ['elts', 'ctx'],
                        [
                            [
                                self.nod(
                                    'Slice',
                                    ['lower', 'upper', 'step'],
                                    [
                                        self.val(slc.start) if slc.start else None,
                                        self.val(slc.stop) if slc.stop else None,
                                        self.val(slc.step) if slc.step else None
                                    ]
                                ) for slc in here.slices
                            ],
                            self.nod('Load', [], [])
                        ]
                    )
                ]
            );
        } elif (len(here.slices) == 1) {
            slc = here.slices[0];
            self.set_out(
                here,
                [
                    self.nod(
                        'Slice',
                        ['lower', 'upper', 'step'],
                        [
                            self.val(slc.start) if slc.start else None,
                            self.val(slc.stop) if slc.stop else None,
                            self.val(slc.step) if slc.step else None
                        ]
                    )
                ]
            );
        }
    } elif ((len(here.slices) > 0) and (here.slices[0].start is not None)) {
        self.set_out(here, self.outs(here.slices[0].start));
    } else {
        self.set_out(here, []);
    }
}

impl JcirGenPass.exit_special_var_ref with SpecialVarRef exit {
    if (here.name == Tok.KW_SUPER) {
        self.set_out(
            here,
            [
                self.call_node(
                    self.nod('Name', ['id', 'ctx'], ['super', self.py_ctx(here)]),
                    [],
                    []
                )
            ]
        );
    } elif (here.name == Tok.KW_ROOT) {
        self.set_out(here, [self.call_node(self.jaclib_obj('root'), [], [])]);
    } else {
        self.set_out(
            here,
            [self.nod('Name', ['id', 'ctx'], [self._py_name(here), self.py_ctx(here)])]
        );
    }
}
