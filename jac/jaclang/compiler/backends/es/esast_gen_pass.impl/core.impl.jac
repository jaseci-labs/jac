impl EsastGenPass._ensure_backend -> FrameworkBackend {
    if self.backend is None {
        import from jaclang.compiler.backends.es.backends.registry {
            active_framework,
            resolve_framework_backend
        }
        framework = active_framework();
        try {
            self.backend = resolve_framework_backend(framework);
        } except ValueError {
            import from jaclang.compiler.frontend.diagnostics { E5081 }
            import from jaclang.compiler.backends.es.backends.react { ReactBackend }
            self.ctx.emit(E5081, framework=framework);
            self.backend = ReactBackend();
        }
    }
    assert self.backend is not None;
    return self.backend;
}

impl EsastGenPass._literal_value(expr: (uni.UniNode | None)) -> (object | None) {
    if (expr is None) {
        return None;
    }
    if isinstance(expr, (uni.String, uni.Int, uni.Float, uni.Bool)) {
        return expr.lit_value;
    }
    if isinstance(expr, uni.MultiString) {
        text_parts: list[str] = [];
        byte_parts: list[bytes] = [];
        for segment in expr.strings {
            if not isinstance(segment, uni.String) {
                return None;
            }
            part = segment.lit_value;
            if isinstance(part, `bytes) {
                byte_parts.append(part);
            } elif isinstance(part, str) {
                text_parts.append(part);
            }
        }
        if byte_parts and text_parts {
            return None;
        }
        if byte_parts {
            joined = b'';
            for part in byte_parts {
                joined = joined + part;
            }
            return joined;
        }
        return ''.join(text_parts);
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
            return values;
        }
    }
    if isinstance(expr, uni.DictVal) {
        items: dict[(str, any)] = {};
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

impl EsastGenPass.exit_semi with uni.Semi exit {}

impl EsastGenPass.exit_token with uni.Token exit {
    if here.__class__ is not uni.Token {
        return;
    }
}

impl EsastGenPass._collect_body_stmts(
    body: Sequence[uni.UniNode]
) -> list[es.Statement] {
    body_stmts: list[es.Statement] = [];
    if body {
        for stmt in body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, list) {
                    body_stmts.extend(cast(es.Statement, s) for s in stmt.gen.es_ast);
                } else {
                    body_stmts.append(cast(es.Statement, stmt.gen.es_ast));
                }
            }
        }
    }
    return body_stmts;
}

impl EsastGenPass._audit_free_identifiers(nd: uni.Module, program: es.Program) -> None {
    allowed = client_ambient_globals() | RUNTIME_PRELUDE_GLOBALS;
    frees = free_identifiers(program, allowed);
    if not frees {
        return;
    }
    names = nd.get_all_sub_nodes(typ=uni.Name);
    reported: set[str] = set();
    for free in frees {
        if free.name in reported or not JAC_TYPE_REGISTRY.is_builtin(free.name) {
            continue;
        }
        reported.add(free.name);
        self.ctx.emit(
            E5103,
            node_override=self._free_ident_site(names, free) or nd,
            name=free.name
        );
    }
    if not self.client_manifest.has_client {
        return;
    }
    for free in frees {
        if (free.name in reported) or (free.name in self._unbound_reported) {
            continue;
        }
        origin: (uni.Name | None) = None;
        for cand in names {
            if (cand.value != free.name) or (cand.sym is None) {
                continue;
            }
            origin = cand;
            if cand.loc.first_line == free.line {
                break;
            }
        }
        if origin is None {
            continue;
        }
        reported.add(free.name);
        self.ctx.emit(E5101, node_override=origin, name=free.name);
    }
}

impl EsastGenPass._free_ident_site(
    names: list[uni.Name], free: FreeIdentifier
) -> (uni.Name | None) {
    fallback: (uni.Name | None) = None;
    for cand in names {
        if cand.value != free.name {
            continue;
        }
        if cand.loc.first_line == free.line {
            return cand;
        }
        if fallback is None {
            fallback = cand;
        }
    }
    return fallback;
}

impl EsastGenPass._build_block_statement(
    scope_node: uni.UniScopeNode, body_nodes: (Sequence[uni.UniNode] | None)
) -> es.BlockStatement {
    statements = self._collect_stmt_body(body_nodes);
    statements = self._prepend_hoisted(scope_node, statements);
    return self.sync_loc(es.BlockStatement(body=statements), jac_node=scope_node);
}

impl EsastGenPass._pass_link_name(link: PassLink) -> str {
    return f"_jac_pass_{link.sym.sym_name}_{link.index}";
}

impl EsastGenPass._pass_link_ref(link: PassLink, nd: uni.UniNode) -> es.Expression {
    return self.sync_loc(
        es.MemberExpression(
            object=self.sync_loc(
                es.Identifier(name=self._pass_link_name(link)), jac_node=nd
            ),
            property=self.sync_loc(es.Identifier(name='v'), jac_node=nd),
            computed=False
        ),
        jac_node=nd
    );
}

impl EsastGenPass._build_pass_block(loop: LoopStmt) -> es.BlockStatement {
    block = self._build_block_statement(loop, loop.body);
    links = [
        link
        for link in self.loop_links.of_loop(loop)
        if not self._pass_link_native(link)
    ];
    if not links {
        return block;
    }
    opens: list[es.Statement] = [];
    for link in links {
        name = link.sym.sym_name;
        read_fn = es.ArrowFunctionExpression(
            params=[], body=es.Identifier(name=name), expression=True
        );
        write_fn = es.ArrowFunctionExpression(
            params=[es.Identifier(name='value')],
            body=es.BlockStatement(
                body=[
                    es.ExpressionStatement(
                        expression=es.AssignmentExpression(
                            operator='=',
                            left=es.Identifier(name=name),
                            right=es.Identifier(name='value')
                        )
                    )
                ]
            ),
            expression=False
        );
        made = self._build_jac_call(
            ["_jac", "passLink"],
            [
                self.sync_loc(read_fn, jac_node=loop),
                self.sync_loc(write_fn, jac_node=loop)
            ],
            loop
        );
        declarator = es.VariableDeclarator(
            id=es.Identifier(name=self._pass_link_name(link)), `init=made
        );
        opens.append(
            self.sync_loc(
                es.VariableDeclaration(declarations=[declarator], kind='const'),
                jac_node=loop
            )
        );
    }
    block.body = [*opens, *block.body, *self._pass_link_detaches(loop)];
    return block;
}

impl EsastGenPass._pass_link_native(link: PassLink) -> bool {
    known = self._native_links.get(link.index);
    if known is None {
        known = confined_to(link.sym, link.loop)
            and (
                binds_target(link.sym, link.loop)
                or assigned_on_entry(link.sym, link.loop)
            );
        self._native_links[link.index] = known;
    }
    return known;
}

impl EsastGenPass._target_confined(loop: uni.InForStmt) -> bool {
    for nm in loop.target.get_all_sub_nodes(uni.Name) {
        if nm.sym is not None and not confined_to(nm.sym, loop) {
            return False;
        }
    }
    return True;
}

impl EsastGenPass._target_rebound(loop: uni.InForStmt) -> bool {
    for nm in loop.target.get_all_sub_nodes(uni.Name) {
        if nm.sym is None {
            continue;
        }
        for site in binding_sites(nm.sym) {
            if not site.is_within(loop.target) {
                return True;
            }
        }
    }
    return False;
}

impl EsastGenPass._frame_scope_of(nd: uni.UniNode) -> (ScopeInfo | None) {
    cur = nd.decl_parent;
    while cur is not None {
        if isinstance(cur, (uni.Module, uni.Ability, uni.Test, uni.LambdaExpr)) {
            return self.scope_map.get(cur);
        }
        cur = cur.decl_parent;
    }
    return None;
}

impl EsastGenPass._pass_link_detaches(loop: (LoopStmt | None)) -> list[es.Statement] {
    detaches: list[es.Statement] = [];
    if loop is None {
        return detaches;
    }
    for link in self.loop_links.of_loop(loop) {
        if self._pass_link_native(link) {
            continue;
        }
        detach = es.CallExpression(
            callee=es.MemberExpression(
                object=es.Identifier(name=self._pass_link_name(link)),
                property=es.Identifier(name='detach'),
                computed=False
            ),
            arguments=[]
        );
        detaches.append(
            self.sync_loc(es.ExpressionStatement(expression=detach), jac_node=loop)
        );
    }
    return detaches;
}

impl EsastGenPass._get_ast_or_default(
    nd: (uni.UniNode | None), default_factory: Callable[([(uni.UniNode | None)], _T)]
) -> _T {
    if (nd and nd.gen.es_ast) {
        generated = nd.gen.es_ast;
        if isinstance(generated, es.Node) {
            return cast(_T, generated);
        }
    }
    if (
        isinstance(nd, uni.Expr)
        and (nd.gen.es_ast is None)
        and (id(nd) not in self._unlowered_reported)
        and self._is_client_destined(nd)
    ) {
        import from jaclang.compiler.frontend.diagnostics { E5097 }
        self._unlowered_reported.add(id(nd));
        self.ctx.emit(E5097, node_override=nd, kind=nd.__class__.__name__);
    }
    fallback = default_factory(nd);
    jac_ref = nd if (nd is not None) else self.ctx.current_node;
    return self.sync_loc(fallback, jac_node=jac_ref);
}

impl EsastGenPass._is_client_destined(nd: uni.UniNode) -> bool {
    return uni.is_client_destined(nd);
}

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
        generated = stmt.gen.es_ast;
        if isinstance(generated, list) {
            statements.extend(
                item
                for item in generated
                if isinstance(item, es.Statement)
            );
        } elif isinstance(generated, es.Statement) {
            statements.append(generated);
        } elif (
            generated is None
            and isinstance(stmt, uni.CodeBlockStmt)
            and not isinstance(stmt, uni.Import)
            and not uni.is_comptime_stmt(stmt)
        ) {
            cls_name = stmt.__class__.__name__;
            self.ctx.emit(
                E5017,
                node_override=stmt,
                construct=ES_STMT_DISPLAY.get(cls_name, cls_name)
            );
        }
    }
    return statements;
}

impl EsastGenPass._expr_from_node(
    nd: (uni.UniNode | None), `default: LiteralValue = None
) -> es.Expression {
    generated = self._get_ast_or_default(
        nd, default_factory=lambda (src: any) { es.Literal(value=`default); }
    );
    if isinstance(generated, es.Expression) {
        return generated;
    }
    self.ctx.emit(E5011, node_override=nd);
    return self.sync_loc(
        es.Literal(value=`default), jac_node=(nd or self.ctx.current_node)
    );
}

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

impl EsastGenPass._declaring_scope_for(name_node: uni.UniNode) -> (ScopeInfo | None) {
    if not isinstance(name_node, uni.AstSymbolNode) {
        return None;
    }
    sym = name_node.sym;
    if (sym is None) or (sym.parent_tab is None) {
        return None;
    }
    for link in self.loop_links.of_symbol(sym) {
        if self._pass_link_native(link) and not binds_target(sym, link.loop) {
            return self.scope_map.get(link.loop);
        }
    }
    owner = sym.parent_tab;
    if isinstance(owner, uni.InForStmt) {
        if not self._target_confined(owner) {
            return self._frame_scope_of(owner);
        }
        loop_scope = self.scope_map.get(owner);
        if loop_scope is not None {
            loop_scope.declared.add(sym.sym_name);
        }
        return loop_scope;
    }
    if not isinstance(owner, (uni.Module, uni.Ability, uni.Test, uni.LambdaExpr)) {
        return None;
    }
    for scope in reversed(self.scope_stack) {
        if scope.nd is owner {
            return scope;
        }
    }
    return None;
}

impl EsastGenPass._hoist_into(
    scope: ScopeInfo, name: str, jac_node: uni.UniNode
) -> None {
    if name in scope.declared {
        return;
    }
    ident = self.sync_loc(es.Identifier(name=name), jac_node=jac_node);
    declarator = self.sync_loc(
        es.VariableDeclarator(id=ident, `init=None), jac_node=jac_node
    );
    decl = self.sync_loc(
        es.VariableDeclaration(declarations=[declarator], kind='let'), jac_node=jac_node
    );
    scope.hoisted.append(decl);
    scope.declared.add(name);
}

impl EsastGenPass._ensure_identifier_declared(
    name: str, jac_node: uni.UniNode
) -> None {
    if self._is_declared_in_any_scope(name) {
        return;
    }
    scope = self._declaring_scope_for(jac_node) or self._current_scope();
    if not scope {
        return;
    }
    self._hoist_into(scope, name, jac_node);
}

impl EsastGenPass._register_declaration(name: str) -> None {
    scope = self._current_scope();
    if scope {
        scope.declared.add(name);
    }
}

impl EsastGenPass._is_declared_in_any_scope(name: str) -> bool {
    return any((name in scope.declared) for scope in reversed(self.scope_stack));
}

impl EsastGenPass._current_scope -> (ScopeInfo | None) {
    return self.scope_stack[-1] if self.scope_stack else None;
}

impl EsastGenPass._pop_scope(nd: uni.UniScopeNode) -> None {
    if (self.scope_stack and (self.scope_stack[-1].nd is nd)) {
        info = self.scope_stack.pop();
        if info.hoisted {
            names: list[str] = [];
            for decl in info.hoisted {
                if not isinstance(decl, es.VariableDeclaration) {
                    continue;
                }
                for declarator in decl.declarations {
                    ident = declarator.id;
                    if isinstance(ident, es.Identifier) {
                        names.append(f"'{ident.name}'");
                    }
                }
            }
            self.ctx.emit(
                E5085,
                node_override=nd,
                names=", ".join(names) or "<unknown>",
                scope=type(nd).__name__
            );
        }
    }
}

impl EsastGenPass._push_scope(nd: uni.UniScopeNode) -> None {
    info = ScopeInfo(nd=nd);
    self.scope_stack.append(info);
    self.scope_map[nd] = info;
}

impl EsastGenPass._alt_branch_scope_to_finalize(
    nd: uni.UniNode
) -> (uni.UniScopeNode | None) {
    parent = nd.parent;
    if parent is None {
        return None;
    }

    if (
        (isinstance(nd, uni.ElseStmt) or isinstance(nd, uni.ElseIf))
        and isinstance(parent, uni.IfStmt)
        and (parent.else_body is nd)
    ) {
        return parent;
    }

    if isinstance(parent, uni.TryStmt) {
        if isinstance(nd, uni.Except) and (nd in parent.excepts) {
            return parent;
        }
        if isinstance(nd, uni.FinallyStmt) and (parent.finally_body is nd) {
            return parent;
        }
        if isinstance(nd, uni.ElseStmt) and (parent.else_body is nd) {
            return parent;
        }
    }

    if (
        isinstance(nd, uni.ElseStmt)
        and isinstance(parent, (uni.WhileStmt, uni.IterForStmt, uni.InForStmt))
        and (parent.else_body is nd)
    ) {
        return parent;
    }
    return None;
}

impl EsastGenPass.sync_loc(es_node: _T, jac_node: (uni.UniNode | None) = None) -> _T {
    if not jac_node {
        jac_node = self.ctx.current_node;
    }
    es_node.loc = es.SourceLocation(
        start=es.Position(line=jac_node.loc.first_line, column=jac_node.loc.col_start),
        end=es.Position(line=jac_node.loc.last_line, column=jac_node.loc.col_end)
    );
    return es_node;
}

impl EsastGenPass.exit_walk with uni.UniNode exit {
    if here.ct_pruned or self.reached_by_syntax(here) {
        osp_skip_rest();
        return;
    }
    self.ctx.current_node = here;
    if self.ctx.is_canceled() {
        osp_skip_rest();
        return;
    }
    if (
        isinstance(here, uni.ElementStmt)
        and isinstance(here, uni.ContextAwareNode)
        and here.code_context != CodeContext.CLIENT
        and ((here.decl_parent is None) or isinstance(here.decl_parent, uni.Module))
    ) {
        is_sv_import = isinstance(here, uni.Import)
            and self._is_service_bridge_import(here);

        is_native_edge = isinstance(here, uni.Import)
            and self._is_client_native_import(here);
        is_shared_arch = (
            isinstance(here, uni.Archetype)
            and (here.name is not None)
            and (here.name.value in self.shared_arch_names)
        );
        if (not is_sv_import and not is_native_edge and not is_shared_arch) {
            osp_skip_rest();
            return;
        }
    }
}

impl EsastGenPass.finish_expr with uni.Expr exit {
    if here.coerce_to is not None {
        self._apply_fw_coercion(here);
    }
}

impl EsastGenPass.finish_scope with uni.UniScopeNode exit {
    self._pop_scope(here);
    self.scope_map.pop(here, None);
}

impl EsastGenPass.enter_walk with uni.UniNode entry {
    if self.ctx.is_canceled() or here.ct_pruned or self.reached_by_syntax(here) {
        osp_skip_rest();
        return;
    }
    self.ctx.current_node = here;
    if (
        isinstance(here, uni.ElementStmt)
        and isinstance(here, uni.ContextAwareNode)
        and here.code_context != CodeContext.CLIENT
        and ((here.decl_parent is None) or isinstance(here.decl_parent, uni.Module))
    ) {
        is_sv_import = isinstance(here, uni.Import)
            and self._is_service_bridge_import(here);

        is_shared_arch = (
            isinstance(here, uni.Archetype)
            and (here.name is not None)
            and (here.name.value in self.shared_arch_names)
        );
        is_native_edge = isinstance(here, uni.Import)
            and self._is_client_native_import(here);
        if (not is_sv_import and not is_native_edge and not is_shared_arch) {
            osp_skip_rest();
            return;
        }
    }
    if isinstance(here, uni.UniScopeNode) and not here.folded {
        scope_to_finalize = self._alt_branch_scope_to_finalize(here);
        if scope_to_finalize is not None {
            self._pop_scope(scope_to_finalize);
        }
        self._push_scope(here);
    }
    if here.gen.es_ast {
        if not (
            isinstance(here, uni.Import) and here.code_context != CodeContext.CLIENT
        ) {
            osp_skip_rest();
            return;
        }
    }
}

impl EsastGenPass.prepare with entry {
    if self.ctx.nested_depth {
        return;
    }
    self.loop_links = LoopLinks.of(self.module);
    self._native_links = {};
    for nd in self.module.flatten() {
        nd.gen.es_ast = None;
    }

    if not self.module.client_viols_reported {
        for (_vnode, _vkind) in client_capability_violations(self.module) {
            self.ctx.emit(E5096, node_override=_vnode, kind=_vkind);
        }
        self.module.client_viols_reported = True;
    }
    self.client_manifest = ClientManifest();

    self.client_manifest.endpoint_effects = dict(
        self.module.gen.interop_manifest.endpoint_effects
    );

    self.shared_arch_names = {
        a.name.value
        for a in ModuleFacts.shared_archetypes_for_context(
            self.module, CodeContext.CLIENT
        )
        if a.name is not None
    };
    self._jsx_processor = EsJsxProcessor(self);

    self.scoped_styles = load_style_annex(
        self.module.annexable_by or self.module.loc.mod_path
    );
}
