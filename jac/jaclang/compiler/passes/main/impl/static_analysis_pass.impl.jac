impl StaticAnalysisPass.postinit -> None {
    super.postinit();
}

impl StaticAnalysisPass.transform(ir_in: uni.Module) -> uni.Module {
    self._checked_scopes: set[int] = set();

    self._check_unused_symbols(self.ir_in);
    self._check_undefined_names(self.ir_in);
    self._check_unreachable_code(self.ir_in);
    self._check_semantic_patterns(self.ir_in);
    self._check_redundant_imports(self.ir_in);
    self._check_client_imports(self.ir_in);
    return ir_in;
}

impl StaticAnalysisPass._check_unused_symbols(scope: uni.UniScopeNode) -> None {
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

        if sym.sym_type in (
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

        if sym.sym_type in (
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

        if sym.sym_type == SymbolType.VAR and isinstance(scope, uni.Ability) {
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

impl StaticAnalysisPass._check_undefined_names(mod: uni.Module) -> None {
    all_names = mod.get_all_sub_nodes(typ=uni.Name);
    for name_nd in all_names {
        if name_nd.sym {
            continue;
        }

        if name_nd._py_ctx_func != ast3.Load {
            continue;
        }

        import builtins;
        if name_nd.value in dir(builtins) or name_nd.value in ("self", "super") {
            continue;
        }

        if mod.parent_scope and name_nd.value in mod.parent_scope.names_in_scope {
            continue;
        }

        if name_nd.value.startswith("__") and name_nd.value.endswith("__") {
            continue;
        }

        parent = name_nd.parent;
        if isinstance(parent, uni.AtomTrailer) and parent.is_attr {
            continue;
        }

        if isinstance(parent, uni.KWPair) and parent.key is name_nd {
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

        if name_nd.find_parent_of_type(uni.Import) is not None {
            continue;
        }

        if name_nd.find_parent_of_type(uni.ModulePath) is not None {
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


impl StaticAnalysisPass._osp_shape_position(name_nd: uni.Name) -> (str | None) {
    cur = name_nd;
    parent = cur.parent;

    for _ in range(8) {
        if parent is None {
            return None;
        }
        if isinstance(parent, uni.ConnectOp) and parent.conn_type is cur {
            return "connect typed-edge position";
        }
        if isinstance(parent, uni.EventSignature) and parent.arch_tag_info is cur {
            return "ability trigger position";
        }
        if isinstance(parent, uni.FilterCompr) and parent.f_type is cur {
            edge_ref = parent.parent;
            if (
                isinstance(edge_ref, uni.EdgeOpRef)
                and isinstance(edge_ref.parent, uni.DisconnectOp)
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

impl StaticAnalysisPass._native_type_position(name_nd: uni.Name) -> (str | None) {
    cur: uni.UniNode = name_nd;
    parent = cur.parent;
    in_type_pos = False;

    for _ in range(8) {
        if parent is None {
            break;
        }
        if isinstance(parent, uni.SubTag)
        or (isinstance(parent, uni.FuncSignature) and parent.return_type is cur) {
            in_type_pos = True;
            break;
        }
        cur = parent;
        parent = cur.parent;
    }
    if not in_type_pos {
        return None;
    }
    imp = name_nd.find_parent_of_type(uni.Import);
    if imp is not None and imp.clib_decls {
        return "C library declaration type position";
    }
    if name_nd.in_native_context() {
        return "native type annotation position";
    }
    return None;
}

impl StaticAnalysisPass._check_unreachable_code(mod: uni.Module) -> None {
    container_types = [
        uni.Ability,
        uni.ImplDef,
        uni.IfStmt,
        uni.ElseStmt,
        uni.ElseIf,
        uni.WhileStmt,
        uni.ForeverStmt,
        uni.InForStmt,
        uni.IterForStmt
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
                if isinstance(stmt, uni.Semi) {
                    continue;
                }
                self.emit(W2002, node_override=stmt);
                break;
            }
            if isinstance(stmt, (uni.ReturnStmt, uni.RaiseStmt)) {
                found_terminator = True;
            }
            if isinstance(stmt, uni.CtrlStmt) {
                found_terminator = True;
            }
        }
    }
}

impl StaticAnalysisPass._check_semantic_patterns(mod: uni.Module) -> None {
    for nd in mod.get_all_sub_nodes(typ=uni.BinaryExpr) {
        if nd.op is not None and isinstance(nd.op, uni.Token) {
            if nd.op.value in ("/", "//", "%") {
                if isinstance(nd.right, uni.Int) and nd.right.value == "0" {
                    self.emit(W2070, node_override=nd);
                } elif isinstance(nd.right, uni.Float) and nd.right.value == "0.0" {
                    self.emit(W2070, node_override=nd);
                }
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=uni.CompareExpr) {
        for (i, op) in enumerate(nd.ops) {
            if op.value in ("==", "!=") {
                right = nd.rights[i] if i < len(nd.rights) else None;
                left = nd.left if i == 0 else (nd.rights[i - 1] if i > 0 else None);
                if isinstance(right, uni.Null) or isinstance(left, uni.Null) {
                    self.emit(W2058, node_override=nd);
                }
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=uni.Assignment) {
        if nd.aug_op is not None or nd.value is None {
            continue;
        }
        if len(nd.target) == 1 {
            target = nd.target[0];
            if isinstance(target, uni.Name) and isinstance(nd.value, uni.Name) {
                if target.value == nd.value.value {
                    self.emit(W2063, node_override=nd, name=target.value);
                }
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=uni.FString) {
        has_expr = False;
        for part in nd.parts {
            if isinstance(part, uni.FormattedValue) {
                has_expr = True;
                break;
            }
        }
        if not has_expr {
            self.emit(W2074, node_override=nd);
        }
    }

    for nd in mod.get_all_sub_nodes(typ=uni.CompareExpr) {
        for (i, op) in enumerate(nd.ops) {
            if op.value in ("==", "!=", "is", "is not") {
                right = nd.rights[i] if i < len(nd.rights) else None;
                if isinstance(right, uni.Bool) {
                    self.emit(W2075, node_override=nd);
                }
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=uni.FinallyStmt) {
        for stmt in nd.body {
            if isinstance(stmt, uni.ReturnStmt) {
                self.emit(E2055, node_override=stmt);
            }
        }
    }

    for nd in mod.get_all_sub_nodes(typ=uni.DisengageStmt) {
        in_walker = False;
        parent = nd.parent;
        while parent is not None {
            if isinstance(parent, uni.Archetype) {
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

    for nd in mod.get_all_sub_nodes(typ=uni.Archetype) {
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

impl StaticAnalysisPass._check_client_imports(mod: uni.Module) -> None {
    import from jaclang.compiler.symbol_utils {
        ClientImportVerdict,
        classify_client_import_item,
        is_client_boundary_import,
        report_dead_client_import,
        resolve_import_source_module
    }
    for nd in mod.get_all_sub_nodes(typ=uni.Import) {
        if not is_client_boundary_import(nd) {
            continue;
        }
        source_mod = resolve_import_source_module(self.prog, nd);
        if source_mod is None {
            continue;
        }
        for item in nd.items {
            verdict = classify_client_import_item(source_mod, item);
            if verdict == ClientImportVerdict.DEAD {
                report_dead_client_import(self, nd, item);
            }
        }
    }
}

impl StaticAnalysisPass._check_redundant_imports(mod: uni.Module) -> None {
    if not self.prog.type_evaluator {
        return;
    }
    registry = self.prog.type_evaluator.ambient_typing_names_by_module;
    if not registry {
        return;
    }
    for nd in mod.get_all_sub_nodes(typ=uni.Import) {
        if nd.from_loc is None {
            continue;
        }
        from_mod_name = nd.from_loc.dot_path_str;
        ambient = registry.get(from_mod_name);
        is_typing = from_mod_name == "typing";
        if ambient is None and not is_typing {
            continue;
        }
        for item in nd.items {
            if not isinstance(item, uni.ModuleItem) {
                continue;
            }
            if not isinstance(item.name, uni.Name) {
                continue;
            }
            if item.alias is not None {
                continue;
            }
            nm = item.name.value;
            if is_typing and nm == "Any" {
                self.emit(W1104, node_override=item.name);
            } elif ambient is not None and nm in ambient {
                self.emit(
                    W1103, node_override=item.name, name=nm, module=from_mod_name
                );
            }
        }
    }
}
