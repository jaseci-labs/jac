impl StaticAnalysisPass.postinit -> None {
    super.postinit();
}

impl StaticAnalysisPass.transform(ir_in: Module) -> Module {
    _fresh: set[int] = set();
    self._checked_scopes = _fresh;

    self._check_unused_symbols(self.ir_in);
    self._check_undefined_names(self.ir_in);
    self._check_unreachable_code(self.ir_in);
    self._check_semantic_patterns(self.ir_in);
    self._check_typing_import_refusals(self.ir_in);
    self._check_redundant_imports(self.ir_in);
    self._check_client_imports(self.ir_in);
    self._check_placement_warnings(self.ir_in);
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
    if id(scope) in self._checked_scopes {
        return;
    }
    self._checked_scopes.add(id(scope));

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

        if len(sym.uses) == 0 {
            self.emit(W2003, node_override=sym.decl, name=name);
        }
    }

    for kid in scope.kid_scope {
        self._check_unused_symbols(kid);
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
                self.emit(
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

        if not name_nd.is_kwesc {
            position = self._osp_shape_position(name_nd);
            if position is not None {
                self.emit(
                    E2018, node_override=name_nd, name=name_nd.value, position=position
                );
                continue;
            }
        }

        hint = None;
        suggestion = self._literal_case_suggestion(name_nd.value);
        if suggestion is not None {
            hint = f"Jac uses Python-style literals -- did you mean `{suggestion}`?";
        }
        self.emit(W2001, node_override=name_nd, name=name_nd.value, help_text=hint);
    }
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
    cur = name_nd;
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
    cur: UniNode = name_nd;
    parent = cur.parent;
    in_type_pos = False;

    for _ in range(8) {
        if parent is None {
            break;
        }
        if isinstance(parent, SubTag)
            or (isinstance(parent, FuncSignature) and parent.return_type is cur) {
            in_type_pos = True;
            break;
        }
        cur = parent;
        parent = cur.parent;
    }
    if not in_type_pos {
        return None;
    }
    imp = name_nd.find_parent_of_type(Import);
    if imp is not None and imp.clib_decls {
        return "C library declaration type position";
    }
    if name_nd.in_native_context() {
        return "native type annotation position";
    }
    return None;
}

impl StaticAnalysisPass._check_unreachable_code(mod: Module) -> None {
    container_types = [
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
    containers: list = [];
    for typ in container_types {
        containers.extend(mod.get_all_sub_nodes(typ=typ));
    }

    for container in containers {
        body = container?.body;
        if not body or not isinstance(body, Sequence) {
            continue;
        }
        found_terminator = False;
        for stmt in body {
            if found_terminator {
                if isinstance(stmt, Semi) {
                    continue;
                }
                self.emit(W2002, node_override=stmt);
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
                    self.emit(W2070, node_override=nd);
                } elif isinstance(nd.right, Float) and nd.right.value == "0.0" {
                    self.emit(W2070, node_override=nd);
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
                    self.emit(W2058, node_override=nd);
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
                    self.emit(W2063, node_override=nd, name=target.value);
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
            self.emit(W2074, node_override=nd);
        }
    }

    for nd in mod.get_all_sub_nodes(typ=CompareExpr) {
        for (i, op) in enumerate(nd.ops) {
            if op.value in ("==", "!=", "is", "is not") {
                right = nd.rights[i] if i < len(nd.rights) else None;
                if isinstance(right, Bool) {
                    import from jaclang.compiler.type_system.type_utils {
                        expr_primitive_name
                    }
                    left = nd.left if i == 0 else nd.rights[i - 1];
                    if expr_primitive_name(self.prog, left) == "bool" {
                        self.emit(W2075, node_override=nd);
                    }
                }
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=FinallyStmt) {
        for stmt in nd.body {
            if isinstance(stmt, ReturnStmt) {
                self.emit(E2055, node_override=stmt);
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=DisengageStmt) {
        in_walker = False;
        parent = nd.parent;
        while parent is not None {
            if isinstance(parent, Archetype) {
                if parent.arch_kind == "walker" {
                    in_walker = True;
                }
                break;
            }
            parent = parent.parent;
        }
        if not in_walker {
            self.emit(E2083, node_override=nd);
        }
    }

    for nd in mod.get_all_sub_nodes(typ=Archetype) {
        if nd.src_endpoint is not None and nd.arch_kind != "edge" {
            self.emit(
                E2027,
                node_override=nd.src_endpoint,
                arch_type=(nd.arch_kind or nd.arch_type.value),
                name=nd.name.value
            );
        }
    }
}

impl StaticAnalysisPass._check_client_imports(mod: Module) -> None {
    import from jaclang.jac0core.compiler { is_client_native_edge_import }
    import from jaclang.jac0core.constant { CodeContext }
    import from jaclang.compiler.symbol_utils {
        ClientImportVerdict,
        classify_client_import_item,
        decl_has_access,
        import_target_pinned_server,
        is_client_boundary_import,
        report_dead_client_import,
        resolve_import_source_module
    }
    for nd in mod.get_all_sub_nodes(typ=Import) {
        if is_client_native_edge_import(nd, self.prog) {
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
                import from jaclang.jac0core.diagnostics { W1105 }
                import from jaclang.jac0core.modresolver { is_client_npm_import }
                spec = nd.from_loc.dot_path_str;
                if is_client_npm_import(spec, nd.loc.mod_path or '') {
                    self.emit(W1105, node_override=nd.from_loc, name=spec);
                }
            }
        }
        string_specs: list = [];
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
            import from jaclang.jac0core.diagnostics { W1106 }
            import from jaclang.jac0core.modresolver {
                is_client_npm_import,
                is_path_alias_import
            }
            mod_path = nd.loc.mod_path or '';
            sibling_file = os.path.join(os.path.dirname(mod_path), spv);
            if (
                not is_client_npm_import(spv, mod_path)
                and not is_path_alias_import(spv, mod_path)
                and not os.path.isfile(sibling_file)
            ) {
                self.emit(W1106, node_override=spv_node, name=spv);
            }
        }
        if not is_client_boundary_import(nd) {
            continue;
        }
        source_mod = resolve_import_source_module(self.prog, nd);
        if source_mod is None {
            continue;
        }
        pinned_server = import_target_pinned_server(nd);
        for item in nd.items {
            verdict = classify_client_import_item(source_mod, item);
            if verdict == ClientImportVerdict.DEAD
                and not (pinned_server and decl_has_access(source_mod, item)) {
                report_dead_client_import(self, nd, item);
            }
        }
    }
}

impl StaticAnalysisPass._check_typing_import_refusals(mod: Module) -> None {
    for nd in mod.get_all_sub_nodes(typ=Import) {
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
                self.emit(E1122, node_override=item.name);
                continue;
            }
            remedy = DEPRECATED_TYPING_ALIASES.get(nm);
            if remedy is not None {
                self.emit(E1123, node_override=item.name, name=nm, remedy=remedy);
            }
        }
    }
}

impl StaticAnalysisPass._check_redundant_imports(mod: Module) -> None {
    import from jaclang.compiler.passes.main.static_analysis_pass {
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
                    self.emit(
                        W1103, node_override=item.name, name=nm, module=from_mod_name
                    );
                } else {
                    self.emit(
                        E1125, node_override=item.name, name=nm, module=from_mod_name
                    );
                }
            }
        }
    }
}
