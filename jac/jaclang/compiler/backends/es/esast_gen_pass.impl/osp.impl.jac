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
    inner = ModuleFacts.unwrap_body(nd);
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
            filtered = self._build_osp_filter(nd, result, _step_filter);
            if filtered is None {
                return fail;
            }
            result = filtered;
        }
        cur = result;
    }
    if (cur is None) or (_idx != len(chain)) {
        self.emit(E5097, node_override=nd, kind="this edge reference shape");
        return fail;
    }
    return cur;
}

impl EsastGenPass._build_osp_filter(
    nd: uni.UniNode, target: es.Expression, filt: uni.FilterCompr
) -> (es.Expression | None) {
    pred = self._build_osp_filter_pred(nd, filt);
    if pred is None {
        return None;
    }
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.MemberExpression(
                    object=target,
                    property=self.sync_loc(es.Identifier(name='filter'), jac_node=nd),
                    computed=False
                ),
                jac_node=nd
            ),
            arguments=[
                self.sync_loc(
                    es.ArrowFunctionExpression(
                        params=[self.sync_loc(es.Identifier(name='x'), jac_node=nd)],
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
                self.sync_loc(es.Literal(value=edge_tag), jac_node=nd),
                self.sync_loc(es.Literal(value=co.capture_edges), jac_node=nd)
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
    provider_opts = self._sv_provider_options(item.from_parent)
        if item is not None
        else None;
    if provider_opts is None {
        provider_opts = es.ObjectExpression(properties=[]);
    }
    import from jaclang.compiler.symbol_utils { symbol_owner_archetype }
    import from jaclang.compiler.frontend.codeinfo { endpoint_key }
    owner = symbol_owner_archetype(walker_sym) if walker_sym is not None else None;
    if owner is not None and isinstance(provider_opts, es.ObjectExpression) {
        key = endpoint_key(
            owner.find_parent_of_type(uni.Module), "walker", owner.sym_name
        );
        provider_opts.properties.append(
            es.Property(
                key=es.Literal(value="contract"),
                value=es.Literal(value=key),
                kind="init",
                method=False,
                shorthand=False,
                computed=False
            )
        );
    }
    spawn_args.append(provider_opts);
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
