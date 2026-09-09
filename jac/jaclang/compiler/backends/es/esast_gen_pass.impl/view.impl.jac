import from jaclang.compiler.backends.es.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
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
    inner = ModuleFacts.unwrap_body(nd);
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
