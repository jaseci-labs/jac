impl StaticAnalysisPass._run_impl(ir_in: Module) -> Module {
    if self.module.is_raised_from_py {
        return ir_in;
    }

    self.module spawn UnusedSymbolWalker(analysis=self);
    self._check_undefined_names(self.module);
    self._check_unreachable_code(self.module);
    self._check_semantic_patterns(self.module);
    self._check_typing_import_refusals(self.module);
    self._check_redundant_imports(self.module);
    self._check_client_imports(self.module);
    self._check_placement_warnings(self.module);
    self._check_loop_closure_captures(self.module);
    return ir_in;
}

impl StaticAnalysisPass._check_placement_warnings(mod: Module) -> None {
    import from jaclang.compiler.symbol_utils {
        report_placement_warnings,
        report_serverless_kind_errors
    }
    report_placement_warnings(self, mod);
    report_serverless_kind_errors(self, mod);
}

impl StaticAnalysisPass._check_unused_symbols(scope: UniScopeNode) -> None {
    for (name, sym) in scope.names_in_scope.items() {
        if sym.imported {
            continue;
        }

        if name.startswith("_") {
            continue;
        }

        if sym.sym_type
            in (
                SymbolType.MODULE,
                SymbolType.MOD_VAR,
                SymbolType.IMPL,
                SymbolType.SEM,
                SymbolType.TEST,
                SymbolType.HAS_VAR,
                SymbolType.CONSTRUCTOR,
                SymbolType.ENUM_MEMBER,
                SymbolType.ABILITY,
                SymbolType.METHOD
            ) {
            continue;
        }

        if sym.sym_type
            in (
                SymbolType.OBJECT_ARCH,
                SymbolType.NODE_ARCH,
                SymbolType.EDGE_ARCH,
                SymbolType.WALKER_ARCH,
                SymbolType.ENUM_ARCH
            ) {
            continue;
        }

        if name in ("self", "super", "init", "postinit") {
            continue;
        }

        if sym.sym_type == SymbolType.VAR and isinstance(scope, Ability) {
            if scope.needs_impl or scope.is_genai_ability {
                continue;
            }
        }

        if sym.sym_type == SymbolType.VAR and isinstance(scope, Archetype) {
            continue;
        }

        if len(sym.uses) == 0 {
            self.ctx.emit(W2003, node_override=sym.decl, name=name);
        }
    }
}

impl StaticAnalysisPass._check_undefined_names(mod: Module) -> None {
    all_names = mod.get_all_sub_nodes(typ=Name);
    for name_nd in all_names {
        if name_nd.sym {
            continue;
        }

        if name_nd.expr_ctx != ExprCtx.LOAD {
            continue;
        }

        if name_nd.value in BUILTIN_NAMES or name_nd.value in ("self", "super") {
            continue;
        }

        if mod.parent_scope and name_nd.value in mod.parent_scope.names_in_scope {
            continue;
        }

        if name_nd.value.startswith("__") and name_nd.value.endswith("__") {
            continue;
        }

        parent = name_nd.parent;
        if isinstance(parent, AtomTrailer) and parent.is_attr {
            continue;
        }

        if isinstance(parent, KWPair) and parent.key is name_nd {
            continue;
        }

        if not name_nd.is_kwesc {
            native_position = self._native_type_position(name_nd);
            if native_position is not None {
                self.ctx.emit(
                    E2018,
                    node_override=name_nd,
                    name=name_nd.value,
                    position=native_position
                );
                continue;
            }
        }

        if name_nd.find_parent_of_type(Import) is not None {
            continue;
        }

        if (
            name_nd.value == '_'
            and name_nd.find_parent_of_type(MatchPattern) is not None
        ) {
            continue;
        }

        if name_nd.find_parent_of_type(ModulePath) is not None {
            continue;
        }

        if name_nd.find_parent_of_type(ImplImport) is not None {
            continue;
        }

        if not name_nd.is_kwesc {
            position = self._osp_shape_position(name_nd);
            if position is not None {
                self.ctx.emit(
                    E2018, node_override=name_nd, name=name_nd.value, position=position
                );
                continue;
            }
        }

        hint = None;
        suggestion = self._literal_case_suggestion(name_nd.value);
        if suggestion is not None {
            hint = f"Jac uses Python-style literals -- did you mean `{suggestion}`?";
        } else {
            hint = self._enclosing_class_member(name_nd);
        }
        self.ctx.emit(W2001, node_override=name_nd, name=name_nd.value, help_text=hint);
    }
}

impl StaticAnalysisPass._enclosing_class_member(name_nd: Name) -> (str | None) {
    method: (Ability | None) = None;
    cur = name_nd.parent;
    while cur is not None {
        owner: (UniNode | None) = cur;
        if isinstance(cur, Ability) and method is None {
            method = cur;
        }
        if isinstance(cur, ImplDef) and cur.decl_link is not None {
            if method is None and isinstance(cur.decl_link, Ability) {
                method = cur.decl_link;
            }
            owner = cur.decl_link.find_parent_of_type(Archetype);
        }
        if isinstance(owner, Archetype) and name_nd.value in owner.names_in_scope {
            receiver = "self";
            if method is not None
                and (
                    method.is_classmethod
                    or any(
                        isinstance(dec, Name) and dec.value == "classmethod"
                        for dec in (method.decorators or [])
                    )
                ) {
                receiver = "cls";
            } elif method is not None and method.is_static {
                receiver = owner.sym_name;
            }
            return f"`{name_nd.value}` is a member of `{owner.sym_name}`, and a method body does not see its class's names; refer to it as `{receiver}.{name_nd.value}`.";
        }
        cur = cur.parent;
    }
    return None;
}

impl StaticAnalysisPass._literal_case_suggestion(name: str) -> (str | None) {
    return {
        "true": "True",
        "false": "False",
        "none": "None",
        "null": "None",
        "nil": "None"
    }.get(
        name
    );
}

impl StaticAnalysisPass._osp_shape_position(name_nd: Name) -> (str | None) {
    cur: UniNode = name_nd;
    parent = cur.parent;

    for _ in range(8) {
        if parent is None {
            return None;
        }
        if isinstance(parent, ConnectOp) and parent.conn_type is cur {
            return "connect typed-edge position";
        }
        if isinstance(parent, EventSignature) and parent.arch_tag_info is cur {
            return "ability trigger position";
        }
        if isinstance(parent, FilterCompr) and parent.f_type is cur {
            edge_ref = parent.parent;
            if (
                isinstance(edge_ref, EdgeOpRef)
                and isinstance(edge_ref.parent, DisconnectOp)
            ) {
                return "disconnect typed-edge position";
            }
            return None;
        }
        cur = parent;
        parent = cur.parent;
    }
    return None;
}

impl StaticAnalysisPass._native_type_position(name_nd: Name) -> (str | None) {
    if not in_type_position(name_nd, include_subscripts=False) {
        return None;
    }
    imp = name_nd.find_parent_of_type(Import);
    if imp is not None and imp.clib_decls {
        return "C library declaration type position";
    }
    if name_nd.in_native_context() {
        return "native type position";
    }
    return None;
}

impl StaticAnalysisPass._check_unreachable_code(mod: Module) -> None {
    container_types: list[type[UniNode]] = [
        Ability,
        ImplDef,
        IfStmt,
        ElseStmt,
        ElseIf,
        WhileStmt,
        ForeverStmt,
        InForStmt,
        IterForStmt
    ];
    containers: list[UniNode] = [];
    for typ in container_types {
        containers.extend(mod.get_all_sub_nodes(typ=typ));
    }

    for container in containers {
        body: list[UniNode] = [container->:BodyRole:->];
        if not body {
            continue;
        }
        found_terminator = False;
        for stmt in body {
            if found_terminator {
                if isinstance(stmt, Semi) {
                    continue;
                }
                self.ctx.emit(W2002, node_override=stmt);
                break;
            }
            if isinstance(stmt, (ReturnStmt, RaiseStmt)) {
                found_terminator = True;
            }
            if isinstance(stmt, CtrlStmt) {
                found_terminator = True;
            }
        }
    }
}

impl StaticAnalysisPass._check_semantic_patterns(mod: Module) -> None {
    for nd in mod.get_all_sub_nodes(typ=BinaryExpr) {
        if nd.op is not None and isinstance(nd.op, Token) {
            if nd.op.value in ("/", "//", "%") {
                if isinstance(nd.right, Int) and nd.right.value == "0" {
                    self.ctx.emit(W2070, node_override=nd);
                } elif isinstance(nd.right, Float) and nd.right.value == "0.0" {
                    self.ctx.emit(W2070, node_override=nd);
                }
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=CompareExpr) {
        for (i, op) in enumerate(nd.ops) {
            if op.value in ("==", "!=") {
                right = nd.rights[i] if i < len(nd.rights) else None;
                left = nd.left if i == 0 else (nd.rights[i - 1] if i > 0 else None);
                if isinstance(right, Null) or isinstance(left, Null) {
                    self.ctx.emit(W2058, node_override=nd);
                }
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=Assignment) {
        if nd.aug_op is not None or nd.value is None {
            continue;
        }
        if len(nd.target) == 1 {
            target = nd.target[0];
            if isinstance(target, Name) and isinstance(nd.value, Name) {
                if target.value == nd.value.value {
                    self.ctx.emit(W2063, node_override=nd, name=target.value);
                }
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=FString) {
        has_expr = False;
        for part in nd.parts {
            if isinstance(part, FormattedValue) {
                has_expr = True;
                break;
            }
        }
        if not has_expr {
            self.ctx.emit(W2074, node_override=nd);
        }
    }

    for nd in mod.get_all_sub_nodes(typ=CompareExpr) {
        for (i, op) in enumerate(nd.ops) {
            if op.value in ("==", "!=", "is", "is not") {
                right = nd.rights[i] if i < len(nd.rights) else None;
                if isinstance(right, Bool) {
                    import from jaclang.compiler.types.type_utils {
                        expr_primitive_name
                    }
                    left = nd.left if i == 0 else nd.rights[i - 1];
                    if expr_primitive_name(left) == "bool" {
                        self.ctx.emit(W2075, node_override=nd);
                    }
                }
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=FinallyStmt) {
        for stmt in nd.body {
            if isinstance(stmt, ReturnStmt) {
                self.ctx.emit(E2055, node_override=stmt);
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=DisengageStmt) {
        in_walker = False;
        parent = nd.parent;
        while parent is not None {
            if isinstance(parent, Ability)
                and isinstance(parent.signature, EventSignature) {
                in_walker = True;
                break;
            }
            if isinstance(parent, Archetype) {
                if parent.arch_kind == "walker" {
                    in_walker = True;
                }
                break;
            }
            if isinstance(parent, ImplDef) {
                _dl = parent.decl_link;
                if isinstance(_dl, Ability) {
                    if isinstance(_dl.signature, EventSignature) {
                        in_walker = True;
                    } else {
                        _owner = _dl.method_owner;
                        if isinstance(_owner, Archetype)
                            and _owner.arch_kind == "walker" {
                            in_walker = True;
                        }
                    }
                }
                break;
            }
            parent = parent.parent;
        }
        if not in_walker {
            self.ctx.emit(E2083, node_override=nd);
        }
    }

    for nd in mod.get_all_sub_nodes(typ=AwaitExpr) {
        in_async = False;
        parent = nd.parent;
        while parent is not None {
            if isinstance(parent, LambdaExpr) {
                break;
            }
            if isinstance(parent, Test) {
                in_async = parent.in_client_context();
                break;
            }
            if isinstance(parent, Ability) {
                in_async = parent.is_async;
                break;
            }
            if isinstance(parent, ImplDef) {
                _dl = parent.decl_link;
                if isinstance(_dl, Ability) {
                    in_async = _dl.is_async;
                }
                break;
            }
            if isinstance(parent, Archetype) {
                break;
            }
            parent = parent.parent;
        }
        if not in_async {
            self.ctx.emit(E2085, node_override=nd);
        }
    }

    for nd in mod.get_all_sub_nodes(typ=Archetype) {
        if nd.arch_kind != "edge" {
            if nd.src_endpoint is not None {
                self.ctx.emit(
                    E2027,
                    node_override=nd.src_endpoint,
                    arch_type=(nd.arch_kind or nd.arch_type.value),
                    name=nd.name.value
                );
            }
        } elif not nd.declares_endpoints() {
            self.ctx.emit(E2086, node_override=nd.name, name=nd.name.value);
        }
    }
}

impl StaticAnalysisPass._check_client_imports(mod: Module) -> None {
    import from jaclang.compiler.driver.boundary_classify {
        is_client_native_edge_import
    }
    import from jaclang.compiler.frontend.constant { CodeContext }
    import from jaclang.compiler.symbol_utils {
        ClientImportVerdict,
        classify_client_import_item,
        is_client_boundary_import,
        report_dead_client_import,
        resolve_import_source_module
    }
    client_tops: dict[str, bool] = {};
    for nd in mod.get_all_sub_nodes(typ=Import) {
        if is_client_native_edge_import(nd, self.prog, client_tops) {
            continue;
        }
        if nd.code_context != CodeContext.CLIENT {
            continue;
        }
        if (
            nd.from_loc is not None
            and nd.from_loc.string_path_value is None
            and not nd.is_virtual_jac
        ) {
            resolved = None;
            try {
                resolved = nd.from_loc.resolve_relative_path();
            } except Exception {
                resolved = None;
            }
            if isinstance(resolved, str) and resolved.endswith('.jac') {
                import from jaclang.compiler.frontend.diagnostics { W1105 }
                import from jaclang.compiler.placement.placement_pins {
                    in_client_npm_world
                }
                spec = nd.from_loc.dot_path_str;
                if in_client_npm_world(spec, nd.loc.mod_path or '') {
                    self.ctx.emit(W1105, node_override=nd.from_loc, name=spec);
                }
            }
        }
        string_specs: list[tuple[str, ModulePath]] = [];
        if (nd.from_loc is not None and nd.from_loc.string_path_value is not None) {
            string_specs.append((nd.from_loc.string_path_value, nd.from_loc));
        } elif nd.from_loc is None {
            for item in nd.items {
                if (
                    isinstance(item, ModulePath) and item.string_path_value is not None
                ) {
                    string_specs.append((item.string_path_value, item));
                }
            }
        }
        for (spv, spv_node) in string_specs {
            if (spv.startswith('.') or nd.is_virtual_jac) {
                continue;
            }
            import os;
            import from jaclang.compiler.frontend.diagnostics { W1106 }
            import from jaclang.compiler.frontend.host { active_host }
            import from jaclang.compiler.placement.placement_pins {
                in_client_npm_world
            }
            mod_path = nd.loc.mod_path or '';
            sibling_file = os.path.join(os.path.dirname(mod_path), spv);
            if (
                not in_client_npm_world(spv, mod_path)
                and not active_host().is_path_alias(spv, mod_path)
                and not os.path.isfile(sibling_file)
            ) {
                self.ctx.emit(W1106, node_override=spv_node, name=spv);
            }
        }
        if not is_client_boundary_import(nd) {
            continue;
        }
        source_mod = resolve_import_source_module(self.prog, nd);
        if source_mod is None {
            continue;
        }
        for item in nd.items {
            if not isinstance(item, ModuleItem) {
                continue;
            }
            verdict = classify_client_import_item(source_mod, item);
            if verdict == ClientImportVerdict.DEAD {
                report_dead_client_import(self, nd, item);
            }
        }
    }
}

impl StaticAnalysisPass._check_typing_import_refusals(mod: Module) -> None {
    for nd in mod.get_all_sub_nodes(typ=Import) {
        if (nd.loc.mod_path or "").endswith(".pyi") {
            continue;
        }
        if nd.from_loc is None or nd.from_loc.dot_path_str != "typing" {
            continue;
        }
        for item in nd.items {
            if not isinstance(item, ModuleItem) {
                continue;
            }
            if not isinstance(item.name, Name) {
                continue;
            }
            nm = item.name.value;
            if nm == "Any" {
                self.ctx.emit(E1122, node_override=item.name);
                continue;
            }
            remedy = DEPRECATED_TYPING_ALIASES.get(nm);
            if remedy is not None {
                self.ctx.emit(E1123, node_override=item.name, name=nm, remedy=remedy);
            }
        }
    }
}

impl StaticAnalysisPass._check_redundant_imports(mod: Module) -> None {
    import from jaclang.compiler.passes.static_analysis_pass {
        is_ambient_provider_module,
        is_bootstrap_compiled_module
    }
    if not self.prog.type_evaluator {
        return;
    }
    registry = self.prog.type_evaluator.ambient_typing_names_by_module;
    if not registry {
        return;
    }
    mod_path = mod.loc.mod_path or "";
    advisory_only = is_bootstrap_compiled_module(mod_path)
        or is_ambient_provider_module(mod_path);
    for nd in mod.get_all_sub_nodes(typ=Import) {
        if (nd.loc.mod_path or "").endswith(".pyi") {
            continue;
        }
        if nd.from_loc is None {
            continue;
        }
        from_mod_name = nd.from_loc.dot_path_str;
        ambient = registry.get(from_mod_name);
        if ambient is None {
            continue;
        }
        for item in nd.items {
            if not isinstance(item, ModuleItem) {
                continue;
            }
            if not isinstance(item.name, Name) {
                continue;
            }
            if item.alias is not None {
                continue;
            }
            nm = item.name.value;
            if nm in ambient {
                if advisory_only {
                    self.ctx.emit(
                        W1103, node_override=item.name, name=nm, module=from_mod_name
                    );
                } else {
                    self.ctx.emit(
                        E1125, node_override=item.name, name=nm, module=from_mod_name
                    );
                }
            }
        }
    }
}

impl StaticAnalysisPass.run_walk with Module entry {
    self.module = self._run_impl(here);
}

impl StaticAnalysisPass._check_loop_closure_captures(mod: Module) -> None {
    closures: list[Closure] = [];
    for lam in mod.get_all_sub_nodes(typ=LambdaExpr) {
        closures.append(lam);
    }
    for nd in mod.get_all_sub_nodes(typ=Ability) {
        if is_nested_function(nd) {
            closures.append(nd);
        }
    }
    for closure in closures {
        if self._runs_in_place(closure) {
            continue;
        }
        loops = self._loops_outlived_by(closure);
        if not loops {
            continue;
        }
        reported: set[int] = set();
        for name_nd in closure.get_all_sub_nodes(typ=Name) {
            sym = name_nd.sym;
            if sym is None
                or sym.sym_type != SymbolType.VAR
                or name_nd.expr_ctx != ExprCtx.LOAD
                or id(sym) in reported
                or is_identifier_slot(name_nd) {
                continue;
            }
            owner = sym.parent_tab;
            if owner is None or self._read_when_created(name_nd, closure) {
                continue;
            }
            for loop in loops {
                if not scope_encloses(owner, loop) {
                    continue;
                }
                rebind = self._rebound_each_iteration(sym, loop, False);
                if rebind is None {
                    continue;
                }
                fate = self._closure_fate(closure, loop, []);
                if fate != ClosureFate.HELD and fate != ClosureFate.OPAQUE {
                    continue;
                }
                reported.add(id(sym));
                self.ctx.emit(
                    E2097 if fate == ClosureFate.HELD else W2084,
                    node_override=name_nd,
                    related=[
                        (
                            f"'{sym.sym_name}' is assigned here on every iteration",
                            rebind
                        )
                    ],
                    name=sym.sym_name
                );
                break;
            }
        }
    }
}

impl StaticAnalysisPass._runs_in_place(closure: Closure) -> bool {
    if isinstance(closure, Ability) and not is_nested_function(closure) {
        return False;
    }
    key = id(closure);
    known = self._in_place.get(key);
    if known is not None {
        return known;
    }
    self._in_place[key] = True;
    verdict = self._closure_fate(closure, None, []) == ClosureFate.IN_PLACE;
    self._in_place[key] = verdict;
    return verdict;
}

impl StaticAnalysisPass._closure_fate(
    closure: Closure, loop: (LoopStmt | None), seen: list[int]
) -> ClosureFate {
    if id(closure) in seen {
        return ClosureFate.IN_PLACE;
    }
    seen.append(id(closure));
    fate: ClosureFate = ClosureFate.OPAQUE;
    if isinstance(closure, LambdaExpr) {
        fate = self._value_fate(closure, True, loop, seen);
    } elif not closure.decorators {
        name_ref = closure.name_ref;
        if name_ref is not None and name_ref.sym is not None {
            fate = self._binding_fate(
                name_ref.sym, closure, self._frame_of(closure), True, loop, seen
            );
        }
    }
    seen.pop();
    return fate;
}

impl StaticAnalysisPass._binding_fate(
    binding: Symbol,
    origin: (Closure | None),
    home: (UniScopeNode | None),
    direct: bool,
    loop: (LoopStmt | None),
    seen: list[int]
) -> ClosureFate {
    if id(binding) in seen {
        return ClosureFate.IN_PLACE;
    }
    seen.append(id(binding));
    fate: ClosureFate = ClosureFate.IN_PLACE;
    deferred = origin is not None and runs_later(origin);
    for use in binding.uses {
        if use.expr_ctx != ExprCtx.LOAD
            or (origin is not None and is_within(use, origin)) {
            continue;
        }
        call = use.parent;
        if deferred and isinstance(call, FuncCall) and call.target is use {
            fate = worse_fate(fate, self._use_fate(call, home, False, loop, seen));
        } else {
            fate = worse_fate(fate, self._use_fate(use, home, direct, loop, seen));
        }
        if fate == ClosureFate.HELD {
            break;
        }
    }
    seen.pop();
    return fate;
}

impl StaticAnalysisPass._use_fate(
    use: UniNode,
    home: (UniScopeNode | None),
    direct: bool,
    loop: (LoopStmt | None),
    seen: list[int]
) -> ClosureFate {
    frame = self._frame_of(use);
    if not same_lexical_scope(frame, home) {
        while frame is not None
            and not same_lexical_scope(self._frame_of(frame), home) {
            frame = self._frame_of(frame);
        }
        if not isinstance(frame, LambdaExpr)
            and not (isinstance(frame, Ability) and is_nested_function(frame)) {
            return ClosureFate.OPAQUE;
        }
        if loop is not None and not self._outlives(frame, loop) {
            return ClosureFate.IN_PLACE;
        }
        return self._closure_fate(frame, loop, seen);
    }
    if loop is not None and not self._outlives(use, loop) {
        return ClosureFate.IN_PLACE;
    }
    return self._value_fate(use, direct, loop, seen);
}

impl StaticAnalysisPass._value_fate(
    value: UniNode, direct: bool, loop: (LoopStmt | None), seen: list[int]
) -> ClosureFate {
    cur = value;
    holder = cur.parent;
    while holder is not None {
        if isinstance(holder, IfElseExpr) and holder.condition is cur {
            return ClosureFate.IN_PLACE;
        }
        if isinstance(
            holder,
            (
                ListVal,
                TupleVal,
                SetVal,
                DictVal,
                KVPair,
                IfElseExpr,
                BoolExpr,
                BinaryExpr,
                UnaryExpr,
                ListCompr,
                DictCompr
            )
        ) {
            direct = False;
        } elif not isinstance(holder, AtomUnit)
            and not (
                isinstance(holder, AtomTrailer) and holder.target is cur and not direct
            ) {
            break;
        }
        cur = holder;
        holder = holder.parent;
    }
    if isinstance(holder, FuncCall) {
        if holder.target is cur {
            return ClosureFate.IN_PLACE;
        }
        if direct and callee_name(holder) in ITERATION_COMBINATORS {
            return ClosureFate.IN_PLACE;
        }
        receiver = keeping_receiver(holder);
        if receiver is not None {
            return self._stored_fate(receiver, loop, seen);
        }
        return ClosureFate.OPAQUE;
    }
    if isinstance(holder, KWPair) {
        if direct and holder.key is not None and holder.key.sym_name == 'key' {
            return ClosureFate.IN_PLACE;
        }
        return ClosureFate.OPAQUE;
    }
    if isinstance(
        holder, (JsxNormalAttribute, JsxSpreadAttribute, JsxExpression, YieldExpr)
    ) {
        return ClosureFate.HELD;
    }
    if isinstance(holder, ReturnStmt) {
        return self._returned_fate(holder, loop, seen);
    }
    if isinstance(holder, LambdaExpr) {
        return self._returned_fate(holder, loop, seen)
            if holder.body is cur
            else ClosureFate.OPAQUE;
    }
    if isinstance(holder, ExprStmt) {
        owner = holder.parent;
        if isinstance(owner, LambdaExpr) and owner.tail_return_expr() is cur {
            return self._returned_fate(owner, loop, seen);
        }
        return ClosureFate.IN_PLACE;
    }
    if isinstance(holder, Assignment) {
        if holder.value is not cur {
            return ClosureFate.IN_PLACE;
        }
        fate: ClosureFate = ClosureFate.IN_PLACE;
        for target in holder.target {
            if not isinstance(target, Name) or holder.aug_op is not None {
                fate = worse_fate(fate, self._stored_fate(target, loop, seen));
            } elif target.sym is None {
                fate = worse_fate(fate, ClosureFate.OPAQUE);
            } elif id(target.sym) in seen {
                fate = worse_fate(fate, self._carried_fate(target.sym, holder, loop));
            } else {
                fate = worse_fate(
                    fate,
                    self._binding_fate(
                        target.sym, None, self._frame_of(holder), direct, loop, seen
                    )
                );
            }
        }
        return fate;
    }
    if isinstance(
        holder,
        (
            AtomTrailer,
            AwaitExpr,
            CompareExpr,
            InnerCompr,
            IfStmt,
            WhileStmt,
            AssertStmt,
            FormattedValue,
            InForStmt
        )
    ) {
        return ClosureFate.IN_PLACE;
    }
    return ClosureFate.OPAQUE;
}

impl StaticAnalysisPass._stored_fate(
    target: UniNode, loop: (LoopStmt | None), seen: list[int]
) -> ClosureFate {
    base = store_root(target);
    if not isinstance(base, Name) {
        return ClosureFate.OPAQUE;
    }
    sym = base.sym;
    if sym is None {
        return ClosureFate.HELD;
    }
    return worse_fate(
        self._carried_fate(sym, base, loop),
        self._binding_fate(sym, None, self._frame_of(base), False, loop, seen)
    );
}

impl StaticAnalysisPass._carried_fate(
    sym: Symbol, site: UniNode, loop: (LoopStmt | None)
) -> ClosureFate {
    if loop is None or self._rebound_each_iteration(sym, loop, True) is None {
        return ClosureFate.HELD;
    }
    for name_nd in (list(sym.defn) + list(sym.uses)) {
        store = name_nd.parent;
        if name_nd.expr_ctx == ExprCtx.STORE
            and isinstance(store, Assignment)
            and store.parent is not None
            and not carries_over(sym, store)
            and comes_before(store, site)
            and is_within(site, store.parent)
            and self._outlives(store, loop) {
            return ClosureFate.IN_PLACE;
        }
    }
    return ClosureFate.OPAQUE;
}

impl StaticAnalysisPass._returned_fate(
    leave: (ReturnStmt | LambdaExpr), loop: (LoopStmt | None), seen: list[int]
) -> ClosureFate {
    owner: (UniNode | None) = leave;
    while owner is not None and not UniScopeNode.is_python_scoping(owner) {
        owner = owner.parent;
    }
    if not isinstance(owner, (Ability, LambdaExpr))
        or not self._runs_in_place(owner)
        or id(owner) in seen {
        return ClosureFate.ENDS_LOOP;
    }
    seen.append(id(owner));
    fate: ClosureFate = ClosureFate.IN_PLACE;
    for call in self._calls_of(owner) {
        if loop is None or self._outlives(call, loop) {
            fate = worse_fate(fate, self._value_fate(call, False, loop, seen));
        }
    }
    seen.pop();
    return fate;
}

impl StaticAnalysisPass._calls_of(closure: Closure) -> list[FuncCall] {
    binding: (Symbol | None) = None;
    if isinstance(closure, LambdaExpr) {
        site: UniNode = closure;
        while isinstance(site.parent, AtomUnit) {
            site = site.parent;
        }
        holder = site.parent;
        if isinstance(holder, KWPair) {
            holder = holder.parent;
        }
        if isinstance(holder, FuncCall) {
            return [holder];
        }
        if isinstance(holder, Assignment) and len(holder.target) == 1 {
            target = holder.target[0];
            if isinstance(target, Name) {
                binding = target.sym;
            }
        }
    } elif closure.name_ref is not None {
        binding = closure.name_ref.sym;
    }
    calls: list[FuncCall] = [];
    if binding is not None {
        for use in binding.uses {
            call = use.parent;
            if isinstance(call, FuncCall)
                and call.target is use
                and not is_within(use, closure) {
                calls.append(call);
            }
        }
    }
    return calls;
}

impl StaticAnalysisPass._is_frame(nd: UniNode) -> bool {
    return UniScopeNode.is_python_scoping(nd)
        and not (isinstance(nd, (Ability, LambdaExpr)) and self._runs_in_place(nd));
}

impl StaticAnalysisPass._frame_of(nd: UniNode) -> (UniScopeNode | None) {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, UniScopeNode) and self._is_frame(cur) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl StaticAnalysisPass._outlives(nd: UniNode, loop: LoopStmt) -> bool {
    for outlived in self._loops_outlived_by(nd) {
        if outlived is loop {
            return True;
        }
    }
    return False;
}

impl StaticAnalysisPass._loops_outlived_by(nd: UniNode) -> list[LoopStmt] {
    loops: list[LoopStmt] = [];
    part: UniNode = nd;
    cur = nd.parent;
    returning = False;
    while cur is not None {
        if isinstance(cur, ReturnStmt) {
            returning = True;
        } elif isinstance(cur, (InForStmt, IterForStmt, WhileStmt, ForeverStmt)) {
            if not returning and loop_repeats(cur, part) {
                loops.append(cur);
            }
        } elif UniScopeNode.is_python_scoping(cur) {
            if self._is_frame(cur) {
                break;
            }
            returning = False;
        }
        part = cur;
        cur = cur.parent;
    }
    return loops;
}

impl StaticAnalysisPass._rebound_each_iteration(
    sym: Symbol, loop: LoopStmt, afresh: bool
) -> (NameAtom | None) {
    for name_nd in (list(sym.defn) + list(sym.uses)) {
        if name_nd.expr_ctx != ExprCtx.STORE {
            continue;
        }
        part: UniNode = name_nd;
        cur = name_nd.parent;
        if afresh and isinstance(cur, Assignment) and carries_over(sym, cur) {
            continue;
        }
        while cur is not None and cur is not loop and not self._is_frame(cur) {
            part = cur;
            cur = cur.parent;
        }
        if cur is loop and loop_repeats(loop, part) {
            return name_nd;
        }
    }
    return None;
}

impl StaticAnalysisPass._read_when_created(name_nd: Name, closure: Closure) -> bool {
    part: UniNode = name_nd;
    cur = name_nd.parent;
    while cur is not None and cur is not closure {
        if isinstance(cur, ParamVar) and cur.value is part {
            owner: (UniNode | None) = cur.parent;
            while owner is not None and not UniScopeNode.is_python_scoping(owner) {
                owner = owner.parent;
            }
            return owner is closure;
        }
        part = cur;
        cur = cur.parent;
    }
    return False;
}
