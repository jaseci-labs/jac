impl BoundaryAnalysisPass.before_pass(self: BoundaryAnalysisPass) -> None {
    self._func_defs: dict[(str, tuple[(InteropContext, uni.Ability)])] = {};
    self._imported_native_funcs: dict[(str, tuple[(str, InteropContext)])] = {};

    self._imported_native_modules: dict[(str, tuple[(str, InteropContext)])] = {};
}

impl BoundaryAnalysisPass._resolved_native_decl(
    self: BoundaryAnalysisPass, name_node: (uni.UniNode | None)
) -> (uni.Ability | None) {
    if name_node is None or not isinstance(name_node, uni.AstSymbolNode) {
        return None;
    }
    import from jaclang.jac0core.compiler { ability_of_symbol }
    decl = ability_of_symbol(name_node.sym);
    if decl is not None and isinstance(decl.signature, uni.FuncSignature) {
        return decl;
    }
    return None;
}

impl BoundaryAnalysisPass._signature_of_decl(
    self: BoundaryAnalysisPass, decl: (uni.Ability | None)
) -> tuple[(str, list[str], list[str])] {
    ret_type: str = 'int';
    param_types: list[str] = [];
    param_names: list[str] = [];
    if decl is not None and isinstance(decl.signature, uni.FuncSignature) {
        sig = decl.signature;
        for plist in [sig.posonly_params, sig.params or [], sig.kwonlyargs] {
            for p in plist {
                param_names.append(p.sym_name);
                if p.type_tag {
                    param_types.append(self._extract_type_name(p.type_tag.tag));
                } else {
                    param_types.append('int');
                }
            }
        }
        if sig.return_type {
            ret_type = self._extract_type_name(sig.return_type);
        }
    }
    return (ret_type, param_types, param_names);
}

impl BoundaryAnalysisPass._get_context(
    self: BoundaryAnalysisPass, nd: uni.UniNode
) -> InteropContext {
    import from jaclang.jac0core.constant { CodeContext }
    cs = nd.codespace();
    if cs == CodeContext.NATIVE {
        return InteropContext.NATIVE;
    }
    if cs == CodeContext.CLIENT {
        return InteropContext.CLIENT;
    }
    return InteropContext.SERVER;
}

impl BoundaryAnalysisPass._extract_type_name(
    self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
) -> str {
    if (expr is None) {
        return 'int';
    }
    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.Token) {
        return expr.value;
    }

    if isinstance(expr, uni.BuiltinType) {
        return expr?.sym_name or str(getattr(expr, 'value', 'int'));
    }

    if isinstance(expr, uni.AtomTrailer) {
        target_name = self._extract_type_name(expr.target);
        if expr.right {
            inner = self._extract_subscript_inner(expr.right);
            if inner {
                return f"{target_name}[{inner}]";
            }
        }
        return target_name;
    }

    if isinstance(expr, uni.BinaryExpr) {
        left = self._extract_type_name(expr.left);
        right = self._extract_type_name(expr.right);
        return f"{left} | {right}";
    }
    return 'int';
}

impl BoundaryAnalysisPass._resolve_native_module(
    self: BoundaryAnalysisPass, module_name: str, inferred_ok: bool = True
) -> (str | None) {
    import os;
    import from jaclang.jac0core.codeinfo { resolve_native_module }
    base_dir = '.';
    if (self.ir_in and self.ir_in.loc) {
        base_dir = os.path.dirname(self.ir_in.loc.mod_path);
    }
    (src_mod_str, _full_path) = resolve_native_module(
        module_name, base_dir, allow_inferred=inferred_ok
    );
    return src_mod_str;
}

impl BoundaryAnalysisPass._in_native_module(self: BoundaryAnalysisPass) -> bool {
    if not (self.ir_in and self.ir_in.loc) {
        return False;
    }
    return self.ir_in.decided_codespace == 'native';
}

impl BoundaryAnalysisPass._native_source_module_of(
    self: BoundaryAnalysisPass, mod: (uni.Module | None)
) -> (str | None) {
    import os;
    if mod is None or mod is self.ir_in or mod.loc is None or not mod.loc.mod_path {
        return None;
    }
    if not (self.ir_in and self.ir_in.loc and self.ir_in.loc.mod_path) {
        return None;
    }
    try {
        rel = os.path.relpath(
            os.path.abspath(mod.loc.mod_path),
            os.path.dirname(os.path.abspath(self.ir_in.loc.mod_path))
        );
    } except ValueError {
        return None;
    }
    if rel.startswith('..') {
        return None;
    }
    if rel.endswith('.jac') {
        return rel;
    }
    return None;
}

impl BoundaryAnalysisPass._absorbed_module(
    self: BoundaryAnalysisPass, item: uni.ModulePath
) -> (uni.Module | None) {
    import os;
    try {
        path = item.resolve_relative_path();
    } except Exception {
        return None;
    }
    if not path {
        return None;
    }
    mod: (uni.Module | None) = None;
    if (self.prog and self.prog.mod and self.prog.mod.hub) {
        mod = self.prog.mod.hub.get(path);
        if mod is None {
            mod = self.prog.mod.hub.get(os.path.abspath(path));
        }
    }
    if mod is None and os.path.isfile(path) {
        try {
            mod = self.prog.compile(path, no_cgen=True, type_check=False);
        } except Exception {
            mod = None;
        }
    }
    return mod;
}

impl BoundaryAnalysisPass._register_native_absorb(
    self: BoundaryAnalysisPass, nd: uni.Import
) -> None {
    import from jaclang.jac0core.compiler { import_declares_native_target }
    import from jaclang.jac0core.constant { SymbolAccess }
    item = nd.items[0];
    if not (isinstance(item, uni.ModulePath) and item.path) {
        return;
    }
    module_name = '.'.join(getattr(p, 'value', str(p)) for p in item.path);
    if not module_name {
        return;
    }
    _ctx = self._get_context(nd);
    _na_intent = (
        _ctx == InteropContext.NATIVE
        or self._in_native_module()
        or import_declares_native_target(nd)
    );
    native_path = self._resolve_native_module(module_name, inferred_ok=_na_intent);
    if not native_path {
        return;
    }
    inc_mod = self._absorbed_module(item);
    if inc_mod is None {
        return;
    }
    import_context = self._get_context(nd);
    is_native_ctx = import_context == InteropContext.NATIVE or self._in_native_module();
    manifest = self.ir_in.gen.interop_manifest;
    for (name, sym) in inc_mod.names_in_scope.items() {
        if sym.access == SymbolAccess.PRIVATE or not sym.defn {
            continue;
        }
        defn0 = sym.defn[0];
        if defn0.find_parent_of_type(uni.Import) is not None {
            continue;
        }
        src = self._native_source_module_of(defn0.find_parent_of_type(uni.Module))
            or native_path;
        self._imported_native_funcs[name] = (src, import_context);
        if (is_native_ctx and name not in manifest.bindings) {
            decl = self._resolved_native_decl(defn0);
            (ret_type, param_types, param_names) = self._signature_of_decl(decl);
            manifest.bindings[name] = InteropBinding(
                name=name,
                source_context=InteropContext.NATIVE,
                callers={InteropContext.NATIVE},
                ret_type=ret_type,
                param_types=param_types,
                param_names=param_names,
                ast_node=decl,
                source_module=src
            );
        }
    }
}

impl BoundaryAnalysisPass.enter_import(
    self: BoundaryAnalysisPass, nd: uni.Import
) -> None {
    import from jaclang.jac0core.compiler { import_declares_native_target }
    import from jaclang.jac0core.ext_registry { is_server_module }
    import_context = self._get_context(nd);
    if (nd.from_loc and isinstance(nd.from_loc, uni.ModulePath)) {
        module_name = nd.from_loc?.dot_path_str;
        if (not module_name and nd.from_loc?.path and nd.from_loc.path) {
            module_name = '.'.join(
                getattr(p, 'value', str(p)) for p in nd.from_loc.path
            );
        }
        if module_name {
            import from jaclang.jac0core.compiler {
                is_client_native_edge_import as _is_cl_na_edge
            }
            _na_intent = (
                import_context == InteropContext.NATIVE
                or self._in_native_module()
                or import_declares_native_target(nd)
                or _is_cl_na_edge(nd, self.prog)
            );
            native_path = self._resolve_native_module(
                module_name, inferred_ok=_na_intent
            );

            mod_path_str = self.ir_in.loc.mod_path
                if (self.ir_in and self.ir_in.loc)
                else '';
            if (nd.is_service_import and not native_path) {
                sv_module_name = nd.from_loc.base_module_name;
                caller_ctx = InteropContext.CLIENT
                    if nd.in_client_context()
                    else InteropContext.SERVER;
                self._register_sv_import(nd, sv_module_name, caller_ctx);
            }
            if nd.items and not nd.is_service_import {
                import from jaclang.jac0core.compiler { is_client_native_edge_import }
                pinned_server_target = False;
                if nd.in_client_context() and nd.from_loc {
                    try {
                        resolved_target = nd.from_loc.resolve_relative_path();
                        if isinstance(resolved_target, str)
                            and resolved_target.endswith('.jac') {
                            import from jaclang.jac0core.placement_pins {
                                config_module_pin
                            }
                            pinned_server_target = config_module_pin(resolved_target)
                                == 'server';
                        }
                    } except Exception {
                        pinned_server_target = False;
                    }
                }
                if pinned_server_target {
                    self._register_sv_import(
                        nd, nd.from_loc.base_module_name, InteropContext.CLIENT
                    );
                } elif is_client_native_edge_import(nd, self.prog) {
                    self._register_na_client_import(nd);
                } else {
                    self._register_client_bridged_import(nd);
                }
            }
            if (native_path and nd.items) {
                manifest = self.ir_in.gen.interop_manifest;
                for item in nd.items {
                    if isinstance(item, uni.ModuleItem) {
                        func_name = getattr(item.name, 'value', str(item.name));
                        _item_sym = item.name.sym
                            if isinstance(item.name, uni.AstSymbolNode)
                            else None;
                        _src = self._native_source_module_of(
                            _item_sym.defn[0].find_parent_of_type(uni.Module)
                        )
                            if (_item_sym and _item_sym.defn)
                            else None;
                        _src = _src or native_path;
                        self._imported_native_funcs[func_name] = (_src, import_context);

                        is_native_ctx = (
                            import_context == InteropContext.NATIVE
                            or self._in_native_module()
                        );
                        if (is_native_ctx and func_name not in manifest.bindings) {
                            _decl = self._resolved_native_decl(item.name);
                            (_rt, _pts, _pns) = self._signature_of_decl(_decl);
                            binding = InteropBinding(
                                name=func_name,
                                source_context=InteropContext.NATIVE,
                                callers={InteropContext.NATIVE},
                                ret_type=_rt,
                                param_types=_pts,
                                param_names=_pns,
                                ast_node=_decl,
                                source_module=_src
                            );
                            manifest.bindings[func_name] = binding;
                        }
                    }
                }
            }
        }
    }

    if (not nd.from_loc) and nd.is_absorb and nd.items and (not nd.clib_decls) {
        self._register_native_absorb(nd);
        return;
    }

    if (not nd.from_loc) and nd.items and (not nd.clib_decls) {
        import from jaclang.jac0core.codeinfo { is_bundled_native_module }
        for item in nd.items {
            if isinstance(item, uni.ModulePath) and item.path {
                whole_name = '.'.join(getattr(p, 'value', str(p)) for p in item.path);
                _eligible = is_bundled_native_module(whole_name)
                    or (item.alias is None and len(item.path) == 1);
                if whole_name and _eligible {
                    _na_intent = (
                        import_context == InteropContext.NATIVE
                        or self._in_native_module()
                        or import_declares_native_target(nd)
                    );
                    native_path = self._resolve_native_module(
                        whole_name, inferred_ok=_na_intent
                    );
                    if native_path {
                        self._imported_native_modules[whole_name] = (
                            native_path,
                            import_context
                        );
                    }
                }
            }
        }
    }
}

impl BoundaryAnalysisPass._register_sv_import(
    self: BoundaryAnalysisPass,
    nd: uni.Import,
    module_name: str,
    caller_ctx: InteropContext
) -> None {
    source_mod: (uni.Module | None) = None;
    if nd.from_loc {
        try {
            resolved_path = nd.from_loc.resolve_relative_path();
            if (self.prog and self.prog.mod and self.prog.mod.hub) {
                source_mod = self.prog.mod.hub.get(resolved_path);
            }
        } except Exception {
            source_mod = None;
        }
        if (source_mod is None) {
            try {
                resolved_path = nd.from_loc.resolve_relative_path();
                import os;
                if resolved_path and os.path.isfile(resolved_path) {
                    source_mod = self._parse_only_source_module(resolved_path);
                }
            } except Exception {
                source_mod = None;
            }
        }
    }

    source_abilities: dict[str, any] = {};
    source_walkers: dict[str, any] = {};
    if source_mod {
        try {
            self._collect_abilities(source_mod, source_abilities);
        } except Exception { }
        try {
            self._collect_pub_walkers(source_mod, source_walkers);
        } except Exception { }
    }
    manifest = self.ir_in.gen.interop_manifest;
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem) {
            continue;
        }
        sym_name = getattr(item.name, 'value', str(item.name));
        local_name = item.alias.sym_name if item.alias else sym_name;
        walker_node: any = source_walkers.get(sym_name);
        if walker_node is not None {
            (param_names, param_types) = self._extract_walker_has_fields(walker_node);
            binding = InteropBinding(
                name=sym_name,
                source_context=InteropContext.SERVER,
                callers={caller_ctx},
                ret_type=sym_name,
                param_types=param_types,
                param_names=param_names,
                ast_node=walker_node,
                source_module=module_name,
                kind='walker'
            );
            manifest.bindings[local_name] = binding;
            continue;
        }
        ability_node: (uni.Ability | None) = source_abilities.get(sym_name);
        (ret_type, param_types, param_names) = self._signature_of_decl(ability_node);
        binding = InteropBinding(
            name=sym_name,
            source_context=InteropContext.SERVER,
            callers={caller_ctx},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=ability_node,
            source_module=module_name,
            kind='function'
        );
        manifest.bindings[local_name] = binding;
    }
}

impl BoundaryAnalysisPass._register_na_client_import(
    self: BoundaryAnalysisPass, nd: uni.Import
) -> None {
    import from jaclang.jac0core.codeinfo { native_wasm_stem }
    import from jaclang.jac0core.diagnostics { E5083 }
    if not nd.from_loc or not nd.items {
        return;
    }
    try {
        resolved_path = nd.from_loc.resolve_relative_path();
    } except Exception {
        return;
    }
    if not isinstance(resolved_path, str) or not resolved_path {
        return;
    }
    manifest = self.ir_in.gen.interop_manifest;
    stem = native_wasm_stem(resolved_path);
    for existing in manifest.client_native_imports {
        other = existing.source_module or '';
        if other and other != resolved_path and native_wasm_stem(other) == stem {
            self.emit(
                E5083, node_override=nd, stem=stem, path=resolved_path, other=other
            );
            break;
        }
    }
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem) {
            continue;
        }
        sym_name = getattr(item.name, 'value', str(item.name));
        local_name = item.alias.sym_name if item.alias else sym_name;
        decl = self._resolved_native_decl(item.name);
        (ret_type, param_types, param_names) = self._signature_of_decl(decl);
        manifest.bindings[local_name] = InteropBinding(
            name=sym_name,
            source_context=InteropContext.NATIVE,
            callers={InteropContext.CLIENT},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=decl,
            source_module=resolved_path
        );
    }
}

impl BoundaryAnalysisPass._register_client_bridged_import(
    self: BoundaryAnalysisPass, nd: uni.Import
) -> None {
    import from jaclang.jac0core.compiler {
        ClientImportVerdict,
        classify_client_import_item,
        is_client_boundary_import,
        symbol_linked_source_module,
        ability_of_symbol
    }
    if not is_client_boundary_import(nd) {
        return;
    }
    source_mod = symbol_linked_source_module(nd);
    if source_mod is None {
        return;
    }
    manifest = self.ir_in.gen.interop_manifest;
    module_name = nd.from_loc.base_module_name if nd.from_loc else '';
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem) {
            continue;
        }
        verdict = classify_client_import_item(source_mod, item);
        if verdict != ClientImportVerdict.BRIDGED {
            continue;
        }
        sym_name = getattr(item.name, 'value', str(item.name));
        local_name = item.alias.sym_name if item.alias else sym_name;
        ability = ability_of_symbol(source_mod.lookup(sym_name));
        if ability is None {
            continue;
        }
        (ret_type, param_types, param_names) = self._signature_of_decl(ability);
        manifest.bindings[local_name] = InteropBinding(
            name=sym_name,
            source_context=InteropContext.SERVER,
            callers={InteropContext.CLIENT},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=ability,
            source_module=module_name,
            kind='function'
        );
    }
}

impl BoundaryAnalysisPass._collect_abilities(
    self: BoundaryAnalysisPass, nd: any, out: dict[str, any]
) -> None {
    if isinstance(nd, uni.Ability) and nd.sym_name {
        out[nd.sym_name] = nd;
    }
    if nd?.kid and nd.kid {
        for k in nd.kid {
            self._collect_abilities(k, out);
        }
    }
}

impl BoundaryAnalysisPass._collect_pub_walkers(
    self: BoundaryAnalysisPass, nd: any, out: dict[str, any]
) -> None {
    if isinstance(nd, uni.Archetype) and nd.sym_name {
        is_walker = nd.arch_kind == "walker";
        is_pub = False;
        try {
            is_pub = bool(getattr(nd, 'public_access', False));
        } except Exception {
            try {
                is_pub = nd.access is not None and nd.access.tag?.name == Tok.KW_PUB;
            } except Exception {
                is_pub = False;
            }
        }
        if is_walker and is_pub {
            out[nd.sym_name] = nd;
        }
    }
    if nd?.kid and nd.kid {
        for k in nd.kid {
            self._collect_pub_walkers(k, out);
        }
    }
}

impl BoundaryAnalysisPass._extract_walker_has_fields(
    self: BoundaryAnalysisPass, walker_nd: any
) -> tuple[list[str], list[str]] {
    names: list[str] = [];
    types: list[str] = [];
    if (not walker_nd) or (not walker_nd.body) {
        return (names, types);
    }
    body_items = walker_nd.body
        if isinstance(walker_nd.body, list)
        else [walker_nd.body];
    for item in body_items {
        has_vars: list = [];
        if isinstance(item, uni.HasVar) {
            has_vars = [item];
        } elif isinstance(item, uni.ArchHas) {
            has_vars = [
                k
                for k in item.kid
                if isinstance(k, uni.HasVar)
            ];
        }
        for hv in has_vars {
            try {
                fname = getattr(hv.name, 'value', str(hv.name));
            } except Exception {
                continue;
            }
            ftype: str = 'Any';
            try {
                if hv?.type_tag and hv.type_tag.tag {
                    ftype = self._extract_type_name(hv.type_tag.tag);
                }
            } except Exception {
                ftype = 'Any';
            }
            names.append(fname);
            types.append(ftype);
        }
    }
    return (names, types);
}

impl BoundaryAnalysisPass._parse_only_source_module(
    self: BoundaryAnalysisPass, file_path: str
) -> any {
    import from jaclang.jac0core.compiler { JacCompiler }
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.helpers { read_file_with_encoding }
    try {
        src_text = read_file_with_encoding(file_path);
        compiler_obj = JacCompiler();
        return compiler_obj.parse_str(
            source_str=src_text, file_path=file_path, target_program=JacProgram()
        );
    } except Exception {
        return None;
    }
}

impl BoundaryAnalysisPass._find_archetype(
    self: BoundaryAnalysisPass, nd: any, target: str
) -> any {
    if (isinstance(nd, (uni.Archetype, uni.Enum)) and nd?.sym_name == target) {
        return nd;
    }
    if nd?.kid and nd.kid {
        for k in nd.kid {
            found = self._find_archetype(k, target);
            if found is not None {
                return found;
            }
        }
    }
    return None;
}

impl BoundaryAnalysisPass.enter_ability(
    self: BoundaryAnalysisPass, nd: uni.Ability
) -> None {
    if (
        nd.sym_name
        and isinstance(nd.signature, uni.FuncSignature)
        and nd.find_parent_of_type(uni.Ability) is None
        and nd.find_parent_of_type(uni.LambdaExpr) is None
    ) {
        nd_cc = nd.code_context;
        if nd_cc == uni.CodeContext.NATIVE {
            ctx = InteropContext.NATIVE;
        } elif nd_cc == uni.CodeContext.CLIENT {
            ctx = InteropContext.CLIENT;
        } else {
            ctx = self._get_context(nd);
        }
        self._func_defs[nd.sym_name] = (ctx, nd);
    }
}

impl BoundaryAnalysisPass.enter_func_call(
    self: BoundaryAnalysisPass, nd: uni.FuncCall
) -> None {
    if (
        isinstance(nd.target, uni.Name)
        and nd.target.sym is not None
        and nd.target.sym.decl is not None
    ) {
        _decl_ab = nd.target.sym.decl.find_parent_of_type(uni.Ability);
        if (
            _decl_ab is not None
            and _decl_ab.find_parent_of_type(uni.Ability) is not None
        ) {
            return;
        }
    }
    func_name = None;
    if isinstance(nd.target, uni.Name) {
        func_name = nd.target.value;
    } elif isinstance(nd.target, uni.NameAtom) {
        func_name = nd.target.sym_name;
    } elif isinstance(nd.target, uni.AtomTrailer) and nd.target.is_attr {
        base = nd.target.target;
        base_name = None;
        if isinstance(base, uni.Name) {
            base_name = base.value;
        } elif isinstance(base, uni.NameAtom) {
            base_name = base.sym_name;
        }
        if base_name is not None and base_name in self._imported_native_modules {
            right_name = nd.target.right?.sym_name;
            if not right_name {
                right_name = nd.target.right?.value;
            }

            _is_native_ctx = (
                self._get_context(nd) == InteropContext.NATIVE
                or self._in_native_module()
            );
            if right_name and _is_native_ctx {
                (mod_path, _ctx) = self._imported_native_modules[base_name];
                _mfst = self.ir_in.gen.interop_manifest;
                if right_name not in _mfst.bindings {
                    _decl = self._resolved_native_decl(nd.target.right);
                    (_rt, _pts, _pns) = self._signature_of_decl(_decl);
                    _mfst.bindings[right_name] = InteropBinding(
                        name=right_name,
                        source_context=InteropContext.NATIVE,
                        callers={InteropContext.NATIVE},
                        ret_type=_rt,
                        param_types=_pts,
                        param_names=_pns,
                        ast_node=_decl,
                        source_module=mod_path
                    );
                } else {
                    _mfst.bindings[right_name].callers.add(InteropContext.NATIVE);
                }
            }
            return;
        }
        func_name = base_name;
    }
    if not func_name {
        return;
    }
    caller_ctx = self._get_context(nd);
    manifest = self.ir_in.gen.interop_manifest;
    if (func_name in self._imported_native_funcs) {
        (source_module, import_ctx) = self._imported_native_funcs[func_name];
        if (caller_ctx == InteropContext.NATIVE or self._in_native_module()) {
            if (func_name not in manifest.bindings) {
                _decl = self._resolved_native_decl(nd.target);
                (_rt, _pts, _pns) = self._signature_of_decl(_decl);
                binding = InteropBinding(
                    name=func_name,
                    source_context=InteropContext.NATIVE,
                    callers={InteropContext.NATIVE},
                    ret_type=_rt,
                    param_types=_pts,
                    param_names=_pns,
                    ast_node=_decl,
                    source_module=source_module
                );
                manifest.bindings[func_name] = binding;
            } else {
                manifest.bindings[func_name].callers.add(InteropContext.NATIVE);
            }
        }
        return;
    }
    if (func_name not in self._func_defs) {
        return;
    }
    (callee_ctx, callee_node) = self._func_defs[func_name];
    if (caller_ctx == callee_ctx) {
        return;
    }
    if (func_name in manifest.bindings) {
        manifest.bindings[func_name].callers.add(caller_ctx);
    } else {
        (ret_type, param_types, param_names) = self._signature_of_decl(callee_node);
        binding = InteropBinding(
            name=func_name,
            source_context=callee_ctx,
            callers={caller_ctx},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=callee_node
        );
        manifest.bindings[func_name] = binding;
    }
}

impl BoundaryAnalysisPass._extract_subscript_inner(
    self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
) -> str {
    if expr is None {
        return '';
    }

    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.Token) {
        return expr.value;
    }

    if isinstance(expr, uni.IndexSlice) {
        for k in expr.kid {
            result = self._extract_subscript_inner(k);
            if result {
                return result;
            }
        }
    }

    if isinstance(expr, uni.Slice) {
        for k in expr.kid {
            result = self._extract_subscript_inner(k);
            if result {
                return result;
            }
        }
    }

    if isinstance(expr, (uni.ListVal, uni.TupleVal)) {
        if expr.values {
            parts = [self._extract_type_name(v) for v in expr.values];
            return ', '.join(
                p
                for p in parts
                if p
            );
        }
    }
    return '';
}

impl BoundaryAnalysisPass._extract_all_subscript_types(
    self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
) -> list[str] {
    if expr is None {
        return [];
    }
    result: list[str] = [];
    if isinstance(expr, (uni.Name, uni.Token)) {
        result.extend(self._extract_all_type_names(expr));
        return result;
    }
    if isinstance(expr, (uni.ListVal, uni.TupleVal)) {
        for v in expr.values {
            result.extend(self._extract_all_type_names(v));
        }
        return result;
    }

    if hasattr(expr, 'kid') {
        for k in expr.kid {
            result.extend(self._extract_all_subscript_types(k));
        }
    }
    return result;
}

impl BoundaryAnalysisPass._extract_all_type_names(
    self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
) -> list[str] {
    prims = {
        'str',
        'int',
        'float',
        'bool',
        'None',
        'Any',
        'list',
        'dict',
        'tuple',
        'set',
        'frozenset',
        'bytes',
        'object',
        'type',
        'JsxElement'
    };
    if expr is None {
        return [];
    }
    if isinstance(expr, uni.Name) {
        if expr.value not in prims {
            return [expr.value];
        }
        return [];
    }
    if isinstance(expr, uni.Token) {
        if expr.value not in prims {
            return [expr.value];
        }
        return [];
    }

    if isinstance(expr, uni.BuiltinType) {
        return [];
    }

    if isinstance(expr, uni.AtomTrailer) {
        result: list[str] = [];
        result.extend(self._extract_all_type_names(expr.target));
        if expr.right {
            result.extend(self._extract_all_subscript_types(expr.right));
        }
        return result;
    }

    if isinstance(expr, uni.BinaryExpr) {
        result: list[str] = [];
        result.extend(self._extract_all_type_names(expr.left));
        result.extend(self._extract_all_type_names(expr.right));
        return result;
    }
    return [];
}

impl BoundaryAnalysisPass._collect_boundary_type(
    self: BoundaryAnalysisPass, type_name: str, source_mod: (uni.Module | None)
) -> None {
    prims = {
        'str',
        'int',
        'float',
        'bool',
        'None',
        'Any',
        'list',
        'dict',
        'tuple',
        'set',
        'frozenset',
        'bytes',
        'object',
        'type',
        'JsxElement'
    };
    if type_name in prims {
        return;
    }
    manifest = self.ir_in.gen.interop_manifest;
    if type_name in manifest.boundary_types {
        return;
    }

    search_mods = [];
    if source_mod {
        search_mods.append(source_mod);
    }
    search_mods.append(self.ir_in);
    arch_node = None;
    for mod in search_mods {
        sym = mod.sym_tab.lookup(type_name, deep=True) if mod.sym_tab else None;
        if sym and sym.defn {
            candidate = sym.defn[0];
            if isinstance(candidate, uni.NameAtom) and candidate.parent {
                candidate = candidate.parent;
            }

            if isinstance(candidate, (uni.Archetype, uni.Enum)) {
                arch_node = candidate;
                break;
            }
        }
    }

    if arch_node is None {
        for mod in search_mods {
            try {
                arch_node = self._find_archetype(mod, type_name);
            } except Exception {
                arch_node = None;
            }
            if arch_node is not None {
                break;
            }
        }
    }
    if arch_node is None {
        return;
    }

    if isinstance(arch_node, uni.Archetype) {
        _ak = arch_node.arch_kind;
        kind = _ak if _ak in ("node", "walker") else "obj";
        fields: list[tuple[(str, str)]] = [];
        fdefaults: dict[(str, Any)] = {};
        nested: list[str] = [];

        if arch_node.body {
            body_items = arch_node.body
                if isinstance(arch_node.body, list)
                else [arch_node.body];
            for item in body_items {
                has_vars: list = [];
                if isinstance(item, uni.HasVar) {
                    has_vars = [item];
                } elif isinstance(item, uni.ArchHas) {
                    has_vars = [
                        k
                        for k in item.kid
                        if isinstance(k, uni.HasVar)
                    ];
                }
                for hv in has_vars {
                    field_name = hv.sym_name;
                    field_type = "Any";
                    if hv.type_tag {
                        field_type = self._extract_type_name(hv.type_tag.tag);
                        for nested_type in self._extract_all_type_names(
                            hv.type_tag.tag
                        ) {
                            if nested_type != type_name {
                                nested.append(nested_type);
                            }
                        }
                    }
                    fields.append((field_name, field_type));
                    if hv.value is not None {
                        (rep, val) = self._literal_default(hv.value);
                        if rep {
                            fdefaults[field_name] = val;
                        }
                    }
                }
            }
        }
        info = BoundaryTypeInfo(
            name=type_name,
            kind=kind,
            fields=fields,
            field_defaults=fdefaults,
            nested_types=nested
        );
        manifest.boundary_types[type_name] = info;

        for nt in nested {
            self._collect_boundary_type(nt, source_mod);
        }
        return;
    }

    if isinstance(arch_node, uni.Enum) {
        members: list[tuple[(str, Any)]] = [];
        if arch_node.body {
            body_items = arch_node.body
                if isinstance(arch_node.body, list)
                else [arch_node.body];
            for item in body_items {
                if isinstance(item, uni.Assignment) {
                    member_name = '';
                    member_val = None;
                    if isinstance(item.target, uni.Name) {
                        member_name = item.target.value;
                    }
                    if item.value {
                        if isinstance(item.value, uni.MultiString) {
                            if item.value.strings {
                                s = item.value.strings[0];
                                raw = getattr(s, 'value', str(s));
                                if isinstance(raw, str) {
                                    member_val = raw.strip('"').strip("'");
                                } else {
                                    member_val = raw;
                                }
                            }
                        } elif isinstance(item.value, uni.Token) {
                            member_val = item.value.value;
                        }
                    }
                    if member_name {
                        members.append((member_name, member_val));
                    }
                }
            }
        }
        info = BoundaryTypeInfo(name=type_name, kind="enum", enum_members=members);
        manifest.boundary_types[type_name] = info;
        return;
    }
}

impl BoundaryAnalysisPass._literal_default(
    self: BoundaryAnalysisPass, expr: any
) -> tuple[(bool, any)] {
    if isinstance(expr, uni.Null) {
        return (True, None);
    }
    if isinstance(expr, (uni.Bool, uni.Int, uni.Float)) {
        return (True, expr.lit_value);
    }
    if isinstance(expr, uni.MultiString) {
        for part in expr.strings {
            if not isinstance(part, uni.String) {
                return (False, None);
            }
        }
    }
    if isinstance(expr, (uni.String, uni.MultiString)) {
        val = expr.lit_value;
        return (True, val) if isinstance(val, str) else (False, None);
    }
    if (
        isinstance(expr, uni.UnaryExpr)
        and expr.op.value == '-'
        and isinstance(expr.operand, (uni.Int, uni.Float))
    ) {
        return (True, -expr.operand.lit_value);
    }
    if isinstance(expr, (uni.ListVal, uni.TupleVal)) {
        items = [];
        for v in (expr.values or []) {
            (rep, val) = self._literal_default(v);
            if not rep {
                return (False, None);
            }
            items.append(val);
        }
        return (True, items);
    }
    if isinstance(expr, uni.DictVal) {
        entries = {};
        for kv in expr.kv_pairs {
            if not isinstance(kv, uni.KVPair) or kv.key is None {
                return (False, None);
            }
            if isinstance(kv.key, uni.Name) {
                (krep, kval) = (True, kv.key.value);
            } else {
                (krep, kval) = self._literal_default(kv.key);
            }
            (vrep, vval) = self._literal_default(kv.value);
            if (not krep or not vrep or not isinstance(kval, str)) {
                return (False, None);
            }
            entries[kval] = vval;
        }
        return (True, entries);
    }
    return (False, None);
}

impl BoundaryAnalysisPass.after_pass(self: BoundaryAnalysisPass) -> None {
    import from jaclang.jac0core.diagnostics { E5093 }
    manifest = self.ir_in.gen.interop_manifest;

    ctypes_wire: set = {
        'int',
        'float',
        'bool',
        'str',
        'i8',
        'i16',
        'i32',
        'i64',
        'u8',
        'u16',
        'u32',
        'u64'
    };
    for binding in manifest.bindings.values() {
        crosses_ctypes = (
            binding.source_context == InteropContext.SERVER
            and InteropContext.NATIVE in binding.callers
        );
        if not crosses_ctypes {
            continue;
        }
        err_node = binding.ast_node
            if isinstance(binding.ast_node, uni.UniNode)
            else self.ir_in;
        for (i, pt) in enumerate(binding.param_types) {
            if pt not in ctypes_wire {
                pname = binding.param_names[i]
                    if i < len(binding.param_names)
                    else str(i);
                self.emit(
                    E5093,
                    node_override=err_node,
                    type=pt,
                    what=f"parameter '{pname}'",
                    name=binding.name
                );
            }
        }
        if binding.ret_type not in ctypes_wire and binding.ret_type != 'None' {
            self.emit(
                E5093,
                node_override=err_node,
                type=binding.ret_type,
                what="the return",
                name=binding.name
            );
        }
    }

    for binding in manifest.server_exports_to_client {
        if binding.ast_node and isinstance(binding.ast_node, uni.Ability) {
            cl_src_mod: (uni.Module | None) = None;
            walk_node: (uni.UniNode | None) = binding.ast_node;
            while walk_node {
                if isinstance(walk_node, uni.Module) {
                    cl_src_mod = walk_node;
                    break;
                }
                walk_node = walk_node.parent;
            }
            sig = binding.ast_node.signature;
            if isinstance(sig, uni.FuncSignature) {
                if sig.return_type {
                    for tn in self._extract_all_type_names(sig.return_type) {
                        self._collect_boundary_type(tn, cl_src_mod);
                    }
                }
                for p in sig.params {
                    if p.type_tag {
                        for tn in self._extract_all_type_names(p.type_tag.tag) {
                            self._collect_boundary_type(tn, cl_src_mod);
                        }
                    }
                }
            }
        }
    }

    for binding in manifest.server_exports_to_server {
        source_mod_obj: (uni.Module | None) = None;
        if (binding.ast_node and isinstance(binding.ast_node, uni.Ability)) {
            walker_node: (uni.UniNode | None) = binding.ast_node;
            while walker_node {
                if isinstance(walker_node, uni.Module) {
                    source_mod_obj = walker_node;
                    break;
                }
                walker_node = walker_node.parent;
            }
            sig = binding.ast_node.signature;
            if isinstance(sig, uni.FuncSignature) {
                if sig.return_type {
                    for tn in self._extract_all_type_names(sig.return_type) {
                        self._collect_boundary_type(tn, source_mod_obj);
                    }
                }
                for p in sig.params {
                    if p.type_tag {
                        for tn in self._extract_all_type_names(p.type_tag.tag) {
                            self._collect_boundary_type(tn, source_mod_obj);
                        }
                    }
                }
            }
        }
    }

    has_client = False;
    if self.ir_in and self.ir_in.body {
        for item in self.ir_in.body {
            if item.in_client_context() {
                has_client = True;
                break;
            }
        }
    }
    if has_client and self.ir_in and self.ir_in.body {
        for item in self.ir_in.body {
            if (
                isinstance(item, (uni.Archetype, uni.Enum))
                and not item.in_client_context()
                and not item.in_native_context()
            ) {
                self._collect_boundary_type(item.sym_name, None);
            }
        }
    }
    self._record_access_levels(manifest);
}

impl BoundaryAnalysisPass._record_access_levels(
    self: BoundaryAnalysisPass, manifest: any
) -> None {
    if not (self.ir_in and self.ir_in.body) {
        return;
    }
    for item in self.ir_in.body {
        if isinstance(item, uni.Ability) and item?.sym_name {
            is_pub = item.access is not None and item.access.tag.name == Tok.KW_PUB;
            manifest.func_access[item.sym_name] = not is_pub;
        } elif isinstance(item, uni.Archetype) and item?.sym_name {
            is_walker = bool(item?.arch_type) and item.arch_type?.name == Tok.KW_WALKER;
            if is_walker {
                is_pub = item.access is not None and item.access.tag.name == Tok.KW_PUB;
                manifest.walker_access[item.sym_name] = not is_pub;
            }
        }
    }
}
