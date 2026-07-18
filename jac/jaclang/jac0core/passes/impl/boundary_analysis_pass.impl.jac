impl BoundaryAnalysisPass.before_pass(self: BoundaryAnalysisPass) -> None {
    self._func_defs: dict[(str, tuple[(InteropContext, uni.Ability)])] = {};
    self._imported_native_funcs: dict[(str, tuple[(str, InteropContext)])] = {};

    self._imported_native_modules: dict[(str, tuple[(str, InteropContext)])] = {};

    self._is_writer: bool = False;
    self._touches: set[str] = set();
    self._visited: set[int] = set();
}

impl BoundaryAnalysisPass._resolved_native_decl(
    self: BoundaryAnalysisPass, name_node: (uni.UniNode | None)
) -> (uni.Ability | None) {
    if name_node is None or not isinstance(name_node, uni.AstSymbolNode) {
        return None;
    }
    import from jaclang.compiler.symbol_utils { ability_of_symbol }
    decl = ability_of_symbol(name_node.sym);
    if decl is not None and isinstance(decl.signature, uni.FuncSignature) {
        return decl;
    }
    return None;
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
    self: BoundaryAnalysisPass, module_name: str
) -> (str | None) {
    import os;
    import from jaclang.jac0core.codeinfo { resolve_native_module }
    base_dir = '.';
    if (self.ir_in and self.ir_in.loc) {
        base_dir = os.path.dirname(self.ir_in.loc.mod_path);
    }
    (src_mod_str, _full_path) = resolve_native_module(module_name, base_dir);
    return src_mod_str;
}

impl BoundaryAnalysisPass._in_native_module(self: BoundaryAnalysisPass) -> bool {
    import os;
    import from jaclang.jac0core.ext_registry { is_native_module }
    if not (self.ir_in and self.ir_in.loc) {
        return False;
    }
    mod_path = self.ir_in.loc.mod_path;
    if mod_path and is_native_module(mod_path) {
        return True;
    }
    if (
        self.prog
        and self.prog._auto_promote_native
        and self.prog._auto_promote_target
        and mod_path
    ) {
        return os.path.realpath(mod_path) == os.path.realpath(
            self.prog._auto_promote_target
        );
    }
    return False;
}

impl BoundaryAnalysisPass.enter_import(
    self: BoundaryAnalysisPass, nd: uni.Import
) -> None {
    import from jaclang.jac0core.ext_registry { is_server_module, is_client_module }
    import_context = self._get_context(nd);
    if (nd.from_loc and isinstance(nd.from_loc, uni.ModulePath)) {
        module_name = nd.from_loc?.dot_path_str;
        if (not module_name and nd.from_loc?.path and nd.from_loc.path) {
            module_name = '.'.join(
                getattr(p, 'value', str(p)) for p in nd.from_loc.path
            );
        }
        if module_name {
            native_path = self._resolve_native_module(module_name);

            mod_path_str = self.ir_in.loc.mod_path
                if (self.ir_in and self.ir_in.loc)
                else '';
            in_server_module = is_server_module(mod_path_str);

            in_client_module = (
                is_client_module(mod_path_str)
                or (nd?.in_client_context and nd.in_client_context())
            );
            sv_token = nd._source_context_token()
                if nd?._source_context_token
                else None;
            has_sv_prefix = sv_token is not None and sv_token.name == Tok.KW_SERVER;
            if (has_sv_prefix and not native_path and nd.items) {
                sv_module_name = nd.from_loc.base_module_name;
                if in_server_module {
                    self._register_sv_import(nd, sv_module_name, InteropContext.SERVER);
                } elif in_client_module {
                    self._register_sv_import(nd, sv_module_name, InteropContext.CLIENT);
                }
            }
            if (native_path and nd.items) {
                manifest = self.ir_in.gen.interop_manifest;
                for item in nd.items {
                    if isinstance(item, uni.ModuleItem) {
                        func_name = getattr(item.name, 'value', str(item.name));
                        self._imported_native_funcs[func_name] = (
                            native_path,
                            import_context
                        );

                        is_native_ctx = (
                            import_context == InteropContext.NATIVE
                            or self._in_native_module()
                        );
                        if (is_native_ctx and func_name not in manifest.bindings) {
                            _decl = self._resolved_native_decl(item.name);
                            binding = InteropBinding(
                                name=func_name,
                                source_context=InteropContext.NATIVE,
                                callers={InteropContext.NATIVE},
                                ret_type='int',
                                param_types=[],
                                param_names=[],
                                ast_node=_decl,
                                route=[InteropContext.NATIVE, InteropContext.NATIVE],
                                source_module=native_path
                            );
                            manifest.bindings[func_name] = binding;
                        }
                    }
                }
            }
        }
    }

    if (not nd.from_loc) and nd.items and (not nd.clib_decls) {
        import from jaclang.jac0core.codeinfo { is_bundled_native_module }
        for item in nd.items {
            if isinstance(item, uni.ModulePath) and item.path {
                whole_name = '.'.join(getattr(p, 'value', str(p)) for p in item.path);
                if whole_name and is_bundled_native_module(whole_name) {
                    native_path = self._resolve_native_module(whole_name);
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
                route=[caller_ctx, InteropContext.SERVER],
                source_module=module_name,
                kind='walker'
            );
            manifest.bindings[local_name] = binding;
            continue;
        }
        param_names: list = [];
        param_types: list = [];
        ret_type: str = 'Any';
        ability_node: (uni.Ability | None) = source_abilities.get(sym_name);
        if (ability_node and isinstance(ability_node.signature, uni.FuncSignature)) {
            sig = ability_node.signature;
            if sig.params {
                for p in sig.params {
                    param_names.append(p.sym_name);
                    if p.type_tag {
                        param_types.append(self._extract_type_name(p.type_tag.tag));
                    } else {
                        param_types.append('Any');
                    }
                }
            }
            if sig.return_type {
                ret_type = self._extract_type_name(sig.return_type);
            }
        }
        binding = InteropBinding(
            name=sym_name,
            source_context=InteropContext.SERVER,
            callers={caller_ctx},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=ability_node,
            route=[caller_ctx, InteropContext.SERVER],
            source_module=module_name,
            kind='function'
        );
        manifest.bindings[local_name] = binding;
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
    if (nd.sym_name and isinstance(nd.signature, uni.FuncSignature)) {
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

    if (
        not nd.is_method
        and not nd.in_client_context()
        and nd.access is not None
        and nd.access.tag.name == Tok.KW_PUB
        and isinstance(nd.name_ref, uni.Name)
    ) {
        self.ir_in.gen.interop_manifest.endpoint_effects[
            f"func:{nd.name_ref.sym_name}"
        ] = self._classify(self._resolved_body(nd));
    }
}

impl BoundaryAnalysisPass.enter_func_call(
    self: BoundaryAnalysisPass, nd: uni.FuncCall
) -> None {
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
                    _mfst.bindings[right_name] = InteropBinding(
                        name=right_name,
                        source_context=InteropContext.NATIVE,
                        callers={InteropContext.NATIVE},
                        ret_type='int',
                        param_types=[],
                        param_names=[],
                        ast_node=self._resolved_native_decl(nd.target.right),
                        route=[InteropContext.NATIVE, InteropContext.NATIVE],
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
                binding = InteropBinding(
                    name=func_name,
                    source_context=InteropContext.NATIVE,
                    callers={InteropContext.NATIVE},
                    ret_type='int',
                    param_types=[],
                    param_names=[],
                    ast_node=self._resolved_native_decl(nd.target),
                    route=[InteropContext.NATIVE, InteropContext.NATIVE],
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
        sig = callee_node.signature;
        assert isinstance(sig, uni.FuncSignature);
        ret_type = self._extract_type_name(sig.return_type);
        param_types: list = [];
        param_names: list = [];
        for p in sig.params {
            param_names.append(p.sym_name);
            if p.type_tag {
                param_types.append(self._extract_type_name(p.type_tag.tag));
            } else {
                param_types.append('int');
            }
        }
        binding = InteropBinding(
            name=func_name,
            source_context=callee_ctx,
            callers={caller_ctx},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=callee_node,
            route=[caller_ctx, callee_ctx]
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
                }
            }
        }
        info = BoundaryTypeInfo(
            name=type_name, kind=kind, fields=fields, nested_types=nested
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

impl BoundaryAnalysisPass.after_pass(self: BoundaryAnalysisPass) -> None {
    manifest = self.ir_in.gen.interop_manifest;

    for binding in manifest.server_exports_to_client {
        if binding.ast_node and isinstance(binding.ast_node, uni.Ability) {
            sig = binding.ast_node.signature;
            if isinstance(sig, uni.FuncSignature) {
                if sig.return_type {
                    for tn in self._extract_all_type_names(sig.return_type) {
                        self._collect_boundary_type(tn, None);
                    }
                }
                for p in sig.params {
                    if p.type_tag {
                        for tn in self._extract_all_type_names(p.type_tag.tag) {
                            self._collect_boundary_type(tn, None);
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
            if isinstance(item, uni.ClientBlock) {
                has_client = True;
                break;
            }
        }
    }
    if has_client and self.ir_in and self.ir_in.body {
        for item in self.ir_in.body {
            if isinstance(item, uni.Archetype) and not item.in_client_context() {
                self._collect_boundary_type(item.sym_name, None);
            } elif isinstance(item, uni.Enum) and not item.in_client_context() {
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

impl BoundaryAnalysisPass.enter_archetype(
    self: BoundaryAnalysisPass, nd: uni.Archetype
) -> None {
    if nd.arch_kind != "walker" {
        return;
    }
    if not isinstance(nd.name, uni.Name) {
        return;
    }
    self.ir_in.gen.interop_manifest.endpoint_effects[f"walker:{nd.name.sym_name}"] = (
        self._classify(self._resolved_body(nd))
    );
}

impl BoundaryAnalysisPass._classify(
    self: BoundaryAnalysisPass, body_nodes: list
) -> dict {
    self._is_writer = False;
    self._touches = set();
    self._visited = set();
    for nd in body_nodes {
        self._scan(nd);
    }
    touches_list = sorted(self._touches) if self._touches else ["*"];
    return {"is_writer": self._is_writer, "touches": touches_list};
}

impl BoundaryAnalysisPass._scan(
    self: BoundaryAnalysisPass, nd: (uni.UniNode | None)
) -> None {
    if nd is None {
        return;
    }

    if isinstance(nd, uni.BinaryExpr) {
        if isinstance(nd.op, uni.ConnectOp) {
            self._is_writer = True;

            if nd.op.conn_type and isinstance(nd.op.conn_type, uni.Name) {
                self._touches.add(nd.op.conn_type.sym_name);
            }
        } elif isinstance(nd.op, uni.DisconnectOp) {
            self._is_writer = True;
        } elif isinstance(nd.op, uni.Token) and nd.op.name == Tok.KW_SPAWN {
            self._is_writer = True;
        }
    }

    if isinstance(nd, uni.DeleteStmt) {
        self._is_writer = True;
    }

    if isinstance(nd, uni.Assignment) and nd.target {
        for tgt in nd.target {
            if isinstance(tgt, uni.AtomTrailer) and tgt.is_attr {
                root_expr = tgt.target;
                while isinstance(root_expr, uni.AtomTrailer) {
                    root_expr = root_expr.target;
                }
                is_self = (
                    isinstance(root_expr, uni.SpecialVarRef)
                    and root_expr.sym_name == 'self'
                );
                if not is_self {
                    self._is_writer = True;
                }
            }
        }
    }

    if isinstance(nd, uni.FuncCall) {
        arch_sym = self._call_target_symbol(nd);
        if arch_sym
        and arch_sym.sym_type in [SymbolType.NODE_ARCH, SymbolType.EDGE_ARCH] {
            self._is_writer = True;
            self._touches.add(arch_sym.sym_name);
        }

        if id(nd) not in self._visited {
            self._visited.add(id(nd));
            for stmt in self._callee_body(nd) {
                self._scan(stmt);
            }
        }
    }

    if isinstance(nd, uni.EventSignature) and nd.arch_tag_info {
        if isinstance(nd.arch_tag_info, uni.Name) {
            self._touches.add(nd.arch_tag_info.sym_name);
        } elif isinstance(nd.arch_tag_info, uni.BoolExpr) {
            for val in nd.arch_tag_info.values {
                if isinstance(val, uni.Name) {
                    self._touches.add(val.sym_name);
                }
            }
        }
    }

    for child in nd.kid {
        if child {
            self._scan(child);
        }
    }
}

impl BoundaryAnalysisPass._call_target_symbol(
    self: BoundaryAnalysisPass, call: uni.FuncCall
) -> (uni.Symbol | None) {
    if isinstance(call.target, uni.Name) {
        sym = call.target.sym;
        if not sym and call.target.sym_tab {
            sym = call.target.sym_tab.lookup(call.target.sym_name, deep=True);
        }
        return sym;
    }

    if isinstance(call.target, uni.AtomTrailer) {
        attrs = call.target.as_attr_list;
        if attrs {
            last = attrs[-1];
            if isinstance(last, uni.AstSymbolNode) and last.sym {
                return last.sym;
            }
        }
    }
    return None;
}

impl BoundaryAnalysisPass._callee_body(
    self: BoundaryAnalysisPass, call: uni.FuncCall
) -> list {
    sym = self._call_target_symbol(call);
    if not sym or not sym.defn {
        return [];
    }
    defn_node = sym.defn[0];
    ability = None;
    if isinstance(defn_node, uni.Ability) {
        ability = defn_node;
    } elif defn_node.parent and isinstance(defn_node.parent, uni.Ability) {
        ability = defn_node.parent;
    }
    if ability {
        return self._resolved_body(ability);
    }
    return [];
}

impl BoundaryAnalysisPass._resolved_body(
    self: BoundaryAnalysisPass, owner: uni.UniNode
) -> list {
    if hasattr(owner, "_get_impl_resolved_body") {
        try {
            resolved = owner._get_impl_resolved_body();
            if isinstance(resolved, list) {
                return resolved;
            }
        } except Exception { }
    }
    body = owner?.body;
    if isinstance(body, list) {
        return body;
    }
    if isinstance(body, uni.ImplDef) and isinstance(body.body, Sequence) {
        return [stmt for stmt in body.body];
    }
    return [];
}
