impl JcirGenPass.exit_report_stmt with ReportStmt exit {
    self.set_out(
        here,
        [
            self.nod(
                'Expr',
                ['value'],
                [
                    self.call_node(
                        self.jaclib_obj('log_report'), self.outs(here.expr), []
                    )
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_visit_stmt with VisitStmt exit {
    loc = self.name_load('self' if here.from_walker else Con.VISITOR.value);
    visit_call = self.call_node(
        self.jaclib_obj('visit'), [loc, self.val(here.target)], []
    );
    if (here.insert_loc is not None) {
        visit_call.get('keywords').append(
            self.nod(
                'keyword', ['arg', 'value'], ['insert_loc', self.val(here.insert_loc)]
            )
        );
    }
    self.set_out(
        here,
        [
            self.nod(
                'If',
                ['test', 'body', 'orelse'],
                [
                    self.nod(
                        'UnaryOp',
                        ['op', 'operand'],
                        [self.nod('Not', [], []), visit_call]
                    ),
                    self.outs(here.else_body),
                    []
                ]
            )
        ]
            if here.else_body
            else [self.nod('Expr', ['value'], [visit_call])]
    );
}

impl JcirGenPass.exit_disengage_stmt with DisengageStmt exit {
    loc = self.name_load('self' if here.from_walker else Con.VISITOR.value);
    self.set_out(
        here,
        [
            self.nod(
                'Expr',
                ['value'],
                [self.call_node(self.jaclib_obj('disengage'), [loc], [])]
            ),
            self.nod('Return', [], [])
        ]
    );
}

impl JcirGenPass._fold_sorted_traversal(nd: FuncCall) -> bool {
    if (not isinstance(nd.target, Name)) or nd.target.sym_name != 'sorted' {
        return False;
    }
    params = nd.params;
    if params is None or len(params) < 1 {
        return False;
    }
    trav = params[0];
    if not isinstance(trav, EdgeRefTrailer) {
        return False;
    }
    key_expr: (Expr | None) = None;
    reverse = False;
    for extra in params[1:] {
        if not isinstance(extra, KWPair) or extra.key is None {
            return False;
        }
        kname = extra.key.sym_name;
        if kname == 'key' {
            key_expr = extra.value;
        } elif kname == 'reverse' {
            rv = extra.value;
            if isinstance(rv, Bool) and rv.lit_value {
                reverse = True;
            } elif isinstance(rv, Bool) {
                reverse = False;
            } else {
                return False;
            }
        } else {
            return False;
        }
    }
    if key_expr is None {
        return False;
    }
    (node_ty, edge_ty) = self._final_hop_types(trav);
    specs = self._sort_order_specs(key_expr, node_ty, edge_ty);
    if specs is None {
        self.emit(
            W5096,
            node_override=key_expr,
            reason='sort key is not a field access, so it has no ORDER BY form'
        );
        return False;
    }
    outs = self.outs(trav);
    if len(outs) != 1 {
        return False;
    }
    call = outs[0];
    if (not isinstance(call, CgNode)) or call.cls != 'Call' {
        return False;
    }
    gq = call.get('args')[0] if call.get('args') else None;
    if (not isinstance(gq, CgNode)) or gq.cls != 'Call' {
        return False;
    }
    terms: list[CgNode] = [];
    for (fname, desc, on_edge) in specs {
        flip = (not desc) if reverse else desc;
        terms.append(
            self.call_node(
                self.jaclib_obj('QOrder'),
                [],
                [
                    self.nod(
                        'keyword', ['arg', 'value'], ['field', self.const_of(fname)]
                    ),
                    self.nod(
                        'keyword', ['arg', 'value'], ['desc', self.const_of(flip)]
                    ),
                    self.nod(
                        'keyword', ['arg', 'value'], ['on_edge', self.const_of(on_edge)]
                    )
                ]
            )
        );
    }
    gq.get('keywords').append(
        self.nod(
            'keyword',
            ['arg', 'value'],
            [
                'order',
                self.nod('List', ['elts', 'ctx'], [terms, self.nod('Load', [], [])])
            ]
        )
    );
    self.set_out(nd, [call]);
    return True;
}

impl JcirGenPass._order_term(
    expr: Expr, param: str, node_ty: str, edge_ty: str
) -> (tuple[str, bool, bool] | None) {
    desc = False;
    inner = expr;
    if isinstance(inner, UnaryExpr) and inner.op.name == Tok.MINUS {
        desc = True;
        inner = inner.operand;
    }
    if not isinstance(inner, AtomTrailer) or not inner.is_attr {
        return None;
    }
    base = inner.target;
    right = inner.right;
    if (not isinstance(base, Name))
        or base.sym_name != param
        or not isinstance(right, Name) {
        return None;
    }
    return (right.sym_name, desc, False);
}

impl JcirGenPass._sort_order_specs(
    key: Expr, node_ty: str, edge_ty: str
) -> (list[tuple[str, bool, bool]] | None) {
    if not isinstance(key, LambdaExpr) {
        return None;
    }
    sig = key.signature;
    if sig is None or sig.params is None or len(sig.params) != 1 {
        return None;
    }
    pv = sig.params[0];
    pname = pv.name.sym_name;
    ann = '';
    if pv.type_tag is not None and isinstance(pv.type_tag.tag, Name) {
        ann = pv.type_tag.tag.sym_name;
    }
    if ann and node_ty and ann != node_ty {
        return None;
    }
    body = key.tail_return_expr();
    if body is None {
        return None;
    }
    parts: list = list(body.values) if isinstance(body, TupleVal) else [body];
    out: list[tuple[str, bool, bool]] = [];
    for part in parts {
        if not isinstance(part, Expr) {
            return None;
        }
        term = self._order_term(part, pname, node_ty, edge_ty);
        if term is None {
            return None;
        }
        out.append((term[0], term[1], False));
    }
    return out;
}

impl JcirGenPass._final_hop_types(nd: EdgeRefTrailer) -> tuple[str, str] {
    node_ty = '';
    edge_ty = '';
    for item in nd.chain {
        if isinstance(item, FilterCompr) and isinstance(item.f_type, Name) {
            node_ty = item.f_type.sym_name;
        } elif isinstance(item, EdgeOpRef) {
            fc = item.filter_cond;
            if fc is not None and isinstance(fc.f_type, Name) {
                edge_ty = fc.f_type.sym_name;
            }
        }
    }
    return (node_ty, edge_ty);
}

impl JcirGenPass._is_edge_ref_target(target: UniNode) -> bool {
    if isinstance(target, EdgeRefTrailer) {
        return not target.edges_only and not target.is_async;
    }
    if (isinstance(target, AtomTrailer) and isinstance(target.right, FilterCompr)) {
        return self._is_edge_ref_target(target.target);
    }
    if isinstance(target, FuncCall)
        and isinstance(target.target, Name)
        and target.target.sym_name == 'sorted'
        and target.params is not None
        and len(target.params) >= 1 {
        return self._is_edge_ref_target(target.params[0]);
    }
    return False;
}

impl JcirGenPass._cmp_op_str(op: CgNode) -> (str | None) {
    if op.cls == 'Eq' {
        return '==';
    }
    if op.cls == 'NotEq' {
        return '!=';
    }
    if op.cls == 'Lt' {
        return '<';
    }
    if op.cls == 'LtE' {
        return '<=';
    }
    if op.cls == 'Gt' {
        return '>';
    }
    if op.cls == 'GtE' {
        return '>=';
    }
    if op.cls == 'In' {
        return 'in';
    }
    return None;
}

impl JcirGenPass._query_filter_kws(
    fc: FilterCompr, type_arg: str, preds_arg: str
) -> list {
    return self._query_filter_kws_ord(fc, type_arg, preds_arg, False, [])[0];
}

impl JcirGenPass._order_name_of(x: Expr) -> (tuple[str, bool] | None) {
    inner = x;
    desc = False;
    if isinstance(inner, UnaryExpr) {
        if inner.op.name != Tok.MINUS {
            return None;
        }
        desc = True;
        inner = inner.operand;
    }
    if not isinstance(inner, Name) {
        return None;
    }
    return (inner.sym_name, desc);
}

impl JcirGenPass._query_filter_kws_ord(
    fc: FilterCompr,
    type_arg: str,
    preds_arg: str,
    on_edge: bool,
    order_out: list[CgNode]
) -> tuple[list[CgNode], bool] {
    kws: list[CgNode] = [];
    if fc.f_type {
        kws.append(
            self.nod('keyword', ['arg', 'value'], [type_arg, self.val(fc.f_type)])
        );
    }
    preds: list[CgNode] = [];
    saw_order = False;
    for x in fc.compares {
        term = self._order_name_of(x);
        if term is not None {
            saw_order = True;
            order_out.append(
                self.call_node(
                    self.jaclib_obj('QOrder'),
                    [],
                    [
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            ['field', self.const_of(term[0])]
                        ),
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            ['desc', self.const_of(term[1])]
                        ),
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            ['on_edge', self.const_of(on_edge)]
                        )
                    ]
                )
            );
            continue;
        }
        if saw_order {
            self.emit(
                E5094,
                node_override=x,
                reason='ordering terms must come after every predicate'
            );
            continue;
        }
        cmp_ast = self.val(x);
        reason: str = '';
        field_name: str = '';
        op_str: str = '';
        composite_names: list[str] = [];
        if cmp_ast.cls != 'Compare' {
            reason = 'not a comparison';
        } else {
            ops = cmp_ast.get('ops');
            left = cmp_ast.get('left');
            if len(ops) != 1 {
                reason = 'chained comparisons are not admitted';
            } elif isinstance(left, CgNode) and left.cls == 'Tuple' {
                op_node = ops[0];
                resolved = self._cmp_op_str(op_node)
                    if isinstance(op_node, CgNode)
                    else None;
                names: list[str] = [];
                for elt in left.get('elts') {
                    if isinstance(elt, CgNode) and elt.cls == 'Name' {
                        eid = elt.get('id');
                        if isinstance(eid, str) {
                            names.append(eid);
                        }
                    }
                }
                right = cmp_ast.get('comparators')[0];
                if resolved is None or resolved == 'in' {
                    reason = 'a composite key has no ordering for this operator';
                } elif (not names) or len(names) != len(left.get('elts')) {
                    reason = 'a composite key must be a tuple of declared field names';
                } elif (
                    (not isinstance(right, CgNode))
                    or right.cls != 'Tuple'
                    or len(right.get('elts')) != len(names)
                ) {
                    reason = f"a composite key of arity {len(
                        names
                    )} needs a tuple value of the same arity";
                } else {
                    composite_names = names;
                    op_str = resolved;
                }
            } elif (not isinstance(left, CgNode)) or (left.cls != 'Name') {
                reason = 'left side must be a declared field name';
            } else {
                op_node = ops[0];
                op_label = '?';
                if isinstance(op_node, CgNode) {
                    op_label = op_node.cls;
                    resolved = self._cmp_op_str(op_node);
                    if resolved is not None {
                        op_str = resolved;
                    }
                }
                if not op_str {
                    reason = f"operator '{op_label}' is not admitted";
                } else {
                    field_id = left.get('id');
                    if isinstance(field_id, str) {
                        field_name = field_id;
                    }
                }
            }
        }
        if reason {
            self.emit(E5094, node_override=x, reason=reason);
        } else {
            preds.append(
                self.call_node(
                    self.jaclib_obj('QPred'),
                    [],
                    [
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            [
                                'field',
                                self.nod(
                                    'Tuple',
                                    ['elts', 'ctx'],
                                    [
                                        [self.const_of(nm) for nm in composite_names],
                                        self.nod('Load', [], [])
                                    ]
                                )
                                    if composite_names
                                    else self.const_of(field_name)
                            ]
                        ),
                        self.nod(
                            'keyword', ['arg', 'value'], ['op', self.const_of(op_str)]
                        ),
                        self.nod(
                            'keyword',
                            ['arg', 'value'],
                            ['value', cmp_ast.get('comparators')[0]]
                        )
                    ]
                )
            );
        }
    }
    if preds {
        kws.append(
            self.nod(
                'keyword',
                ['arg', 'value'],
                [
                    preds_arg,
                    self.nod('List', ['elts', 'ctx'], [preds, self.nod('Load', [], [])])
                ]
            )
        );
    }
    return (kws, saw_order);
}

impl JcirGenPass._warn_inplace_sort(nd: FuncCall) -> None {
    tgt = nd.target;
    if (not isinstance(tgt, AtomTrailer))
        or not tgt.is_attr
        or not isinstance(tgt.right, Name)
        or tgt.right.sym_name != 'sort' {
        return;
    }
    base = tgt.target;
    if not isinstance(base, Name) {
        return;
    }
    sym = base.sym;
    if sym is None {
        return;
    }
    for defn in sym.defn {
        assign = defn.parent;
        if isinstance(assign, Assignment)
            and assign.value is not None
            and isinstance(assign.value, EdgeRefTrailer) {
            self.emit(
                W5096,
                node_override=nd,
                reason=(
                    f"'{base.sym_name}' holds a traversal and .sort() cannot "
                    f"fold; use sorted(), or order inside the reference"
                )
            );
            return;
        }
    }
}

impl JcirGenPass._traversal_consumed_now(nd: EdgeRefTrailer) -> bool {
    parent = nd.parent;
    if parent is None {
        return False;
    }
    if isinstance(parent, (IfStmt, WhileStmt, AssertStmt)) {
        return parent.condition is nd;
    }
    if isinstance(parent, BoolExpr) {
        return True;
    }
    if isinstance(parent, UnaryExpr) {
        return parent.op.name == Tok.NOT and parent.operand is nd;
    }
    if isinstance(parent, FuncCall) {
        tgt = parent.target;
        return isinstance(tgt, Name)
            and tgt.sym_name == 'len'
            and parent.params is not None
            and len(parent.params) == 1
            and parent.params[0] is nd;
    }
    return False;
}

impl JcirGenPass._simple_hop(nd: EdgeRefTrailer) -> (list[CgNode] | None) {
    if nd.is_async {
        return None;
    }
    parent = nd.parent;
    if isinstance(parent, VisitStmt) {
        return None;
    }
    if isinstance(parent, AtomTrailer)
        and parent.target is nd
        and isinstance(parent.right, (FilterCompr, IndexSlice)) {
        return None;
    }
    if isinstance(parent, FuncCall)
        and isinstance(parent.target, Name)
        and parent.target.sym_name == 'sorted'
        and parent.params is not None
        and len(parent.params) >= 1
        and parent.params[0] is nd {
        return None;
    }
    chain = nd.chain;
    if len(chain) == 2
        and not isinstance(chain[0], EdgeOpRef)
        and isinstance(chain[1], EdgeOpRef) {
        origin_ast = self.val(chain[0]);
        hop = chain[1];
    } elif len(chain) == 1 and isinstance(chain[0], EdgeOpRef) {
        hop = chain[0];
        origin_ast = self.val(hop);
    } else {
        return None;
    }
    type_ast = self.const_of(None);
    fc = hop.filter_cond;
    if fc is not None {
        if fc.compares or fc.f_type is None {
            return None;
        }
        type_ast = self.val(fc.f_type);
    }
    return [origin_ast, self.const_of(hop.edge_dir.value), type_ast];
}

impl JcirGenPass.exit_edge_ref_trailer with EdgeRefTrailer exit {
    simple = self._simple_hop(here);
    if simple is not None {
        self.set_out(
            here,
            [
                self.call_node(
                    self.jaclib_obj('hop'),
                    [*simple, self.const_of(here.edges_only)],
                    []
                )
            ]
        );
        return;
    }
    origin: (CgNode | None) = None;
    cur = here.chain[0];
    chomp = [*here.chain[1:]];
    from_visit = bool(isinstance(here.parent, VisitStmt));
    if not isinstance(cur, EdgeOpRef) {
        origin = self.val(cur);
        cur = chomp.pop(0);
    }
    origin_ast = origin if origin is not None else self.val(cur);
    hops: list[CgNode] = [];
    order_terms: list[CgNode] = [];
    while True {
        if not isinstance(cur, EdgeOpRef) {
            raise RuntimeError(self.ice('edge ref chain hop is not an EdgeOpRef'));
        }
        keywords = [
            self.nod(
                'keyword', ['arg', 'value'], ['dir', self.const_of(cur.edge_dir.value)]
            )
        ];
        hop_order: list[CgNode] = [];
        if cur.filter_cond {
            (ekws, _eord) = self._query_filter_kws_ord(
                cur.filter_cond, 'edge', 'epreds', True, hop_order
            );
            keywords.extend(ekws);
        }
        if (chomp and not isinstance(chomp[0], EdgeOpRef)) {
            filt = chomp.pop(0);
            if isinstance(filt, FilterCompr) {
                (nkws, _nord) = self._query_filter_kws_ord(
                    filt, 'nd', 'preds', False, hop_order
                );
                keywords.extend(nkws);
            } else {
                keywords.append(
                    self.nod('keyword', ['arg', 'value'], ['only', self.val(filt)])
                );
            }
        }
        hops.append(self.call_node(self.jaclib_obj('QHop'), [], keywords));
        if hop_order and chomp {
            self.emit(
                E5094,
                node_override=here,
                reason='ordering applies to the final hop of a traversal'
            );
            hop_order = [];
        }
        order_terms = hop_order;
        if chomp {
            cur = chomp.pop(0);
        } else {
            break;
        }
    }
    gq_kws = [
        self.nod(
            'keyword',
            ['arg', 'value'],
            [
                'hops',
                self.nod('List', ['elts', 'ctx'], [hops, self.nod('Load', [], [])])
            ]
        )
    ];
    if order_terms {
        gq_kws.append(
            self.nod(
                'keyword',
                ['arg', 'value'],
                [
                    'order',
                    self.nod(
                        'List', ['elts', 'ctx'], [order_terms, self.nod('Load', [], [])]
                    )
                ]
            )
        );
    }
    if here.edges_only {
        gq_kws.append(
            self.nod('keyword', ['arg', 'value'], ['edges_only', self.const_of(True)])
        );
    }
    pynode = self.call_node(self.jaclib_obj('GraphQuery'), [origin_ast], gq_kws);
    if from_visit {
        pynode = self.call_node(
            self.nod(
                'Attribute',
                ['value', 'attr', 'ctx'],
                [pynode, 'visit', self.nod('Load', [], [])]
            ),
            [],
            []
        );
    }
    if here.is_async {
        pynode = self.call_node(self.jaclib_obj('arefs'), [pynode], []);
    } else {
        ref_kws: list[CgNode] = [];
        if self._traversal_consumed_now(here) {
            ref_kws.append(
                self.nod('keyword', ['arg', 'value'], ['lazy', self.const_of(True)])
            );
        }
        pynode = self.call_node(self.jaclib_obj('refs'), [pynode], ref_kws);
    }
    self.set_out(here, [pynode]);
}

impl JcirGenPass.exit_edge_op_ref with EdgeOpRef exit {
    self.set_out(
        here, [self.name_load(Con.HERE.value if here.from_walker else 'self')]
    );
}

impl JcirGenPass.exit_disconnect_op with DisconnectOp exit {
    self.set_out(here, self.outs(here.edge_spec));
}

impl JcirGenPass.exit_connect_op with ConnectOp exit {
    self.set_out(
        here,
        [
            self.call_node(
                self.jaclib_obj('build_edge'),
                [],
                [
                    self.nod(
                        'keyword',
                        ['arg', 'value'],
                        ['is_undirected', self.const_of(here.edge_dir == EdgeDir.ANY)]
                    ),
                    self.nod(
                        'keyword',
                        ['arg', 'value'],
                        [
                            'conn_type',
                            self.val(here.conn_type)
                                if here.conn_type
                                else self.const_of(None)
                        ]
                    ),
                    self.nod(
                        'keyword',
                        ['arg', 'value'],
                        [
                            'conn_assign',
                            self.val(here.conn_assign)
                                if here.conn_assign
                                else self.const_of(None)
                        ]
                    )
                ]
            )
        ]
    );
}

impl JcirGenPass.exit_filter_compr with FilterCompr exit {
    iter_name = 'i';
    comprs: list[CgNode] = [];
    if here.f_type {
        f_type_recipe = self.val(here.f_type);
        cur_loc = self.nod('Pass', [], []);
        f_type_recipe.l1 = cur_loc.l1;
        f_type_recipe.c1 = cur_loc.c1;
        f_type_recipe.l2 = cur_loc.l2;
        f_type_recipe.c2 = cur_loc.c2;
        comprs.append(
            self.call_node(
                self.name_load('isinstance'),
                [self.name_load(iter_name), f_type_recipe],
                []
            )
        );
    }
    for x in here.compares {
        x_recipe = self.val(x);
        if x_recipe.cls != 'Compare' {
            continue;
        }
        left = x_recipe.get('left');
        if (not isinstance(left, CgNode)) or (left.cls != 'Name') {
            continue;
        }
        comprs.append(
            self.nod(
                'Compare',
                ['left', 'ops', 'comparators'],
                [
                    self.nod(
                        'Attribute',
                        ['value', 'attr', 'ctx'],
                        [
                            self.name_load(iter_name, jac_node=x),
                            left.get('id'),
                            self.nod('Load', [], [], jac_node=x)
                        ],
                        jac_node=x
                    ),
                    x_recipe.get('ops'),
                    x_recipe.get('comparators')
                ],
                jac_node=x
            )
        );
    }
    body: (CgNode | None) = None;
    if (len(comprs) > 1) {
        body = self.nod('BoolOp', ['op', 'values'], [self.nod('And', [], []), comprs]);
    } elif comprs {
        body = comprs[0];
    }
    if body {
        self.set_out(
            here,
            [
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
                            [[], [self.nod('arg', ['arg'], [iter_name])], [], [], []]
                        ),
                        body
                    ]
                )
            ]
        );
    }
}

impl JcirGenPass.exit_assign_compr with AssignCompr exit {
    keys: list[CgNode] = [];
    values: list[CgNode] = [];
    for i in here.assigns {
        if i.key {
            keys.append(self.const_of(i.key.sym_name));
            values.append(self.val(i.value));
        }
    }
    key_tup = self.nod('Tuple', ['elts', 'ctx'], [keys, self.nod('Load', [], [])]);
    val_tup = self.nod('Tuple', ['elts', 'ctx'], [values, self.nod('Load', [], [])]);
    self.set_out(
        here,
        [
            self.nod(
                'Tuple', ['elts', 'ctx'], [[key_tup, val_tup], self.nod('Load', [], [])]
            )
        ]
    );
}
