"""Implementation for boundary_analysis_pass constructs."""

"""Initialize function-definition tracking and effect accumulators."""
impl BoundaryAnalysisPass.before_pass(self: BoundaryAnalysisPass) -> None {
    self._func_defs: dict[(str, tuple[(InteropContext, uni.Ability)])] = {};
    self._imported_native_funcs: dict[(str, tuple[(str, InteropContext)])] = {};
    # Per-classification accumulators for endpoint graph effects (reset for
    # each endpoint body by _classify).
    self._is_writer: bool = False;
    self._touches: set[str] = set();
    self._visited: set[int] = set();
}

"""Determine the codespace context of a node."""
impl BoundaryAnalysisPass._get_context(
    self: BoundaryAnalysisPass, nd: uni.UniNode
) -> InteropContext {
    if nd.in_native_context() {
        return InteropContext.NATIVE;
    }
    if nd.in_client_context() {
        return InteropContext.CLIENT;
    }
    return InteropContext.SERVER;
}

"""Extract a type name string from a type annotation expression."""
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
    # Handle BuiltinType (list, dict, set, etc.)
    if isinstance(expr, uni.BuiltinType) {
        return expr?.sym_name or str(getattr(expr, 'value', 'int'));
    }
    # Handle subscript types like list[Todo]
    if isinstance(expr, uni.AtomTrailer) {
        target_name = self._extract_type_name(expr.target);
        if expr.right {
            # Right is typically IndexSlice -> Slice -> ListVal -> [types]
            inner = self._extract_subscript_inner(expr.right);
            if inner {
                return f"{target_name}[{inner}]";
            }
        }
        return target_name;
    }
    # Handle union types like Todo | None -> "Todo | None"
    if isinstance(expr, uni.BinaryExpr) {
        left = self._extract_type_name(expr.left);
        right = self._extract_type_name(expr.right);
        return f"{left} | {right}";
    }
    return 'int';
}

"""Check if a module name refers to a .na.jac file and return the path suffix.

Delegates to the shared resolve_native_module() in codeinfo to ensure
consistent resolution across the compiler.
"""
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

"""Track imports from .na.jac modules and sv-to-sv microservice imports."""
impl BoundaryAnalysisPass.enter_import(
    self: BoundaryAnalysisPass, nd: uni.Import
) -> None {
    import from jaclang.jac0core.ext_registry {
        is_server_module,
        is_client_module,
        is_native_module
    }
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
            # sv-to-sv microservice import detection: triggered when the user
            # explicitly wrote `sv import from ...` (we detect via the sv
            # token, not code_context which defaults to SERVER for all nodes).
            mod_path_str = self.ir_in.loc.mod_path
                if (self.ir_in and self.ir_in.loc)
                else '';
            in_server_module = is_server_module(mod_path_str);
            # A `sv import` inside a client module is the client->server RPC
            # edge (the #6221 case). Because this pass now runs in the shared
            # front-end on .cl.jac modules too, we record that binding here from
            # resolved symbols instead of leaving EsastGen to re-resolve it.
            in_client_module = (
                is_client_module(mod_path_str)
                or (nd?.in_client_context and nd.in_client_context())
            );
            sv_token = nd._source_context_token()
                if nd?._source_context_token
                else None;
            has_sv_prefix = sv_token is not None and sv_token.name == Tok.KW_SERVER;
            if (has_sv_prefix and not native_path and nd.items) {
                # Key the binding on the bare module name (no leading relative
                # dots) so it matches what PyastGen / the runtime use to find
                # the provider; `.analytics` and `analytics` must register
                # identically (#6507).
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
                        # For native-to-native imports, create binding immediately
                        # so NativeCompilePass can link the module. This avoids
                        # relying on enter_func_call which may not visit annex bodies.
                        # Check both explicit na {} context and .na.jac file context.
                        is_native_ctx = (
                            import_context == InteropContext.NATIVE
                            or (
                                self.ir_in
                                and self.ir_in.loc
                                and is_native_module(self.ir_in.loc.mod_path)
                            )
                        );
                        if (is_native_ctx and func_name not in manifest.bindings) {
                            binding = InteropBinding(
                                name=func_name,
                                source_context=InteropContext.NATIVE,
                                callers={InteropContext.NATIVE},
                                ret_type='int',
                                param_types=[],
                                param_names=[],
                                ast_node=None,
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
}

"""Register an sv import edge: create InteropBindings for each item.

`caller_ctx` is the codespace doing the importing — SERVER for an sv->sv
microservice import, CLIENT for a `sv import` inside a .cl.jac (the
client->server RPC edge). The provider is always SERVER. For each item we
look up the source module's symbol table to extract param names, types,
and return type; these bindings drive HTTP client-stub codegen (Python
and JS) and inform boundary type collection.
"""
impl BoundaryAnalysisPass._register_sv_import(
    self: BoundaryAnalysisPass,
    nd: uni.Import,
    module_name: str,
    caller_ctx: InteropContext
) -> None {
    # Resolve the source module. If it's not yet in the program hub, parse
    # it standalone (no semantic analysis) so we can extract function
    # signatures via AST walk. This only triggers for actual sv imports
    # (we use the sv token check), not for every import.
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
    # Build name -> AST-node maps by walking the source module's AST. We
    # keep functions and walkers separate because their wire shapes (and
    # therefore stub-generation paths) differ: functions go through
    # /function/<name> with a signature derived from `def` params,
    # walkers go through /walker/<name> with params derived from `has`
    # fields. The walker map only contains `walker:pub` archetypes since
    # private walkers are not exposed at the HTTP boundary.
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
                # The wire returns a walker instance whose Python-side
                # type is the walker class itself, so the return type
                # name and the symbol name are the same. Stub codegen
                # uses this to rehydrate via `<Walker>._from_wire(...)`.
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

"""Walk a module AST collecting Ability nodes by name."""
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

"""Walk a module AST collecting public walker Archetype nodes by name."""
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

"""Extract `has` field (name, type-name) pairs from a walker archetype.

Walks the walker's body for `ArchHas` containers and bare `HasVar`
declarations, mirroring how `_collect_boundary_type` reads Archetype
field shape. Type annotations are extracted with `_extract_type_name`
so generics, unions, and boundary-typed defaults survive intact.
"""
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

"""Parse a source file standalone (no semantic analysis).

Used by sv import detection to extract function signatures from a provider
module that is not yet in the program hub. We parse into a *throwaway*
JacProgram (never `self.prog`) so a symtab-less parse-only module can never
poison the shared hub — downstream resolvers (EsastGen `_resolve_source_module`)
must still find/compile the real provider themselves. We only walk the
returned AST for `def`/walker signatures, which needs no symbol table.
"""
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

"""Find an Archetype or Enum node by name via AST walk."""
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

"""Record a function's definition context and, for a public server-context
module-level `def`, classify it as an RPC endpoint (graph effects).

Methods (walker/node abilities) are skipped for effects — captured by the
owning archetype. Client functions are never RPC-called; non-public helpers
are followed *into* when a public endpoint calls them, not keyed as endpoints.
"""
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
    # Endpoint graph-effect classification (formerly WalkerEffectsPass).
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

"""Check if a function call crosses context boundaries."""
impl BoundaryAnalysisPass.enter_func_call(
    self: BoundaryAnalysisPass, nd: uni.FuncCall
) -> None {
    func_name = None;
    if isinstance(nd.target, uni.Name) {
        func_name = nd.target.value;
    } elif isinstance(nd.target, uni.NameAtom) {
        func_name = nd.target.sym_name;
    } elif isinstance(nd.target, uni.AtomTrailer) and nd.target.is_attr {
        # Static-method call on an imported class: `Class.method(...)` (#6951).
        # Bind on the base class name so a bundled/cross-module class used only
        # via its statics still pulls its defining module into the native link
        # set (instance calls on locals miss the `_imported_native_funcs` gate
        # below, so this never disturbs ordinary `obj.method()` dispatch).
        base = nd.target.target;
        if isinstance(base, uni.Name) {
            func_name = base.value;
        } elif isinstance(base, uni.NameAtom) {
            func_name = base.sym_name;
        }
    }
    if not func_name {
        return;
    }
    caller_ctx = self._get_context(nd);
    manifest = self.ir_in.gen.interop_manifest;
    if (func_name in self._imported_native_funcs) {
        (source_module, import_ctx) = self._imported_native_funcs[func_name];
        if (caller_ctx == InteropContext.NATIVE) {
            if (func_name not in manifest.bindings) {
                binding = InteropBinding(
                    name=func_name,
                    source_context=InteropContext.NATIVE,
                    callers={InteropContext.NATIVE},
                    ret_type='int',
                    param_types=[],
                    param_names=[],
                    ast_node=None,
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

"""Extract the inner type name from a subscript (IndexSlice/Slice/ListVal)."""
impl BoundaryAnalysisPass._extract_subscript_inner(
    self: BoundaryAnalysisPass, expr: (uni.UniNode | None)
) -> str {
    if expr is None {
        return '';
    }
    # Direct Name or Token
    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.Token) {
        return expr.value;
    }
    # IndexSlice -> walk children to find Slice/ListVal
    if isinstance(expr, uni.IndexSlice) {
        for k in expr.kid {
            result = self._extract_subscript_inner(k);
            if result {
                return result;
            }
        }
    }
    # Slice -> walk children
    if isinstance(expr, uni.Slice) {
        for k in expr.kid {
            result = self._extract_subscript_inner(k);
            if result {
                return result;
            }
        }
    }
    # ListVal/TupleVal -> extract all type params (e.g. dict[str, Metric] -> "str, Metric")
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

"""Extract all user-defined type names from a subscript (IndexSlice tree)."""
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
    # Walk children for IndexSlice, Slice, etc.
    if hasattr(expr, 'kid') {
        for k in expr.kid {
            result.extend(self._extract_all_subscript_types(k));
        }
    }
    return result;
}

"""Extract all user-defined type names from a type annotation expression."""
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
    # BuiltinType (list, dict, etc.) — not user-defined
    if isinstance(expr, uni.BuiltinType) {
        return [];
    }
    # Subscript: list[Todo] -> extract inner types (walk into IndexSlice/Slice/ListVal)
    if isinstance(expr, uni.AtomTrailer) {
        result: list[str] = [];
        result.extend(self._extract_all_type_names(expr.target));
        if expr.right {
            result.extend(self._extract_all_subscript_types(expr.right));
        }
        return result;
    }
    # Union: Todo | None -> extract both sides
    if isinstance(expr, uni.BinaryExpr) {
        result: list[str] = [];
        result.extend(self._extract_all_type_names(expr.left));
        result.extend(self._extract_all_type_names(expr.right));
        return result;
    }
    return [];
}

"""Collect a type that crosses the codespace boundary into the manifest."""
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
    # Look up the type in the source module or current module
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
            # Only accept a symbol that actually resolves to a type
            # definition. An `sv import`ed type name resolves, in the
            # consumer's own symtab, to the import binding (a NameAtom/Token)
            # rather than the Archetype -- accepting that would set arch_node
            # to a non-type node, short-circuit the AST-walk fallback below,
            # and leave the type uncollected. The return value of the sv->sv
            # call then never gets a `_from_wire` stub and arrives as a raw
            # `_jac_type` dict (#6710). Keep looking past such bindings so the
            # fallback can find the real definition in the provider module.
            if isinstance(candidate, (uni.Archetype, uni.Enum)) {
                arch_node = candidate;
                break;
            }
        }
    }
    # AST-walk fallback for modules without a built sym_tab (e.g., a source
    # module that's already in prog.mod.hub but for which boundary type
    # collection runs before symtab build), or whose only matching symbol was
    # a non-type binding rejected above.
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
    # Handle Archetype (obj, node, walker)
    if isinstance(arch_node, uni.Archetype) {
        # Edge archetypes intentionally fall back to "obj" here -- this
        # manifest only distinguishes node/walker shapes.
        _ak = arch_node.arch_kind;
        kind = _ak if _ak in ("node", "walker") else "obj";
        fields: list[tuple[(str, str)]] = [];
        nested: list[str] = [];
        # Extract has declarations (walk through ArchHas -> HasVar)
        if arch_node.body {
            body_items = arch_node.body
                if isinstance(arch_node.body, list)
                else [arch_node.body];
            for item in body_items {
                has_vars: list = [];
                if isinstance(item, uni.HasVar) {
                    has_vars = [item];
                } elif isinstance(item, uni.ArchHas) {
                    # ArchHas contains HasVar nodes as children
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
        # Recursively collect nested types
        for nt in nested {
            self._collect_boundary_type(nt, source_mod);
        }
        return;
    }
    # Handle Enum
    if isinstance(arch_node, uni.Enum) {
        members: list[tuple[(str, Any)]] = [];
        if arch_node.body {
            body_items = arch_node.body
                if isinstance(arch_node.body, list)
                else [arch_node.body];
            for item in body_items {
                if isinstance(item, uni.Assignment) {
                    # Enum member: NAME = value
                    member_name = '';
                    member_val = None;
                    if isinstance(item.target, uni.Name) {
                        member_name = item.target.value;
                    }
                    if item.value {
                        if isinstance(item.value, uni.MultiString) {
                            # String literal — extract from first string token
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

"""After all nodes visited, collect boundary types from SV->CL bindings
and server-side archetypes that may cross the boundary."""
impl BoundaryAnalysisPass.after_pass(self: BoundaryAnalysisPass) -> None {
    manifest = self.ir_in.gen.interop_manifest;
    # Collect types from explicit SV->CL function bindings
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
    # Collect types from SV->SV (microservice) bindings. The source module
    # holds the canonical type definition; walk up from the ast_node to
    # find the containing Module.
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
    # Collect all server-side archetypes (obj, node, walker, enum) as potential
    # boundary types — they may be passed via walker reports/spawn fields.
    # Only collect types defined outside of CL context.
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

"""Record compile-time auth requirement for this module's own top-level
endpoints (def abilities and walker archetypes).

`func_access`/`walker_access` map name -> True when auth is required
(secure-by-default: anything not explicitly `pub` requires auth). Because
this pass runs on every module, each records its own symbols; the serve
runtime aggregates across the program hub instead of re-walking ASTs at
request time (replacing ModuleIntrospector._extract_access_levels)."""
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

"""Classify a walker archetype by the effects in its (impl-resolved) body."""
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

"""Run the effect scan over a flat statement body, returning the manifest entry.
The single definition of the `["*"]`-when-empty conservative default for
`touches` lives here."""
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

"""Recursively classify a node and its descendants for graph effects. The two
context-dependent operations -- recognizing a node/edge constructor and
following a call into its callee -- both go through resolved symbols, so there is
no syntactic fallback."""
impl BoundaryAnalysisPass._scan(
    self: BoundaryAnalysisPass, nd: (uni.UniNode | None)
) -> None {
    if nd is None {
        return;
    }
    # Edge create / delete, or sub-walker spawn.
    if isinstance(nd, uni.BinaryExpr) {
        if isinstance(nd.op, uni.ConnectOp) {
            self._is_writer = True;
            # ++>, <++, <++> may carry an explicit edge type to record.
            if nd.op.conn_type and isinstance(nd.op.conn_type, uni.Name) {
                self._touches.add(nd.op.conn_type.sym_name);
            }
        } elif isinstance(nd.op, uni.DisconnectOp) {
            self._is_writer = True;
        } elif isinstance(nd.op, uni.Token) and nd.op.name == Tok.KW_SPAWN {
            self._is_writer = True;
        }
    }
    # Node / edge deletion.
    if isinstance(nd, uni.DeleteStmt) {
        self._is_writer = True;
    }
    # Field mutation on a non-self target: `n.attr = ...`. `self.x` is
    # walker-local state, not a graph write, so it is excluded.
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
    # FuncCall: arch construction (a write + a touch) and interprocedural follow
    # into the callee body.
    if isinstance(nd, uni.FuncCall) {
        arch_sym = self._call_target_symbol(nd);
        if arch_sym
        and arch_sym.sym_type in [SymbolType.NODE_ARCH, SymbolType.EDGE_ARCH] {
            self._is_writer = True;
            self._touches.add(arch_sym.sym_name);
        }
        # The id()-based visited guard makes mutual / self recursion terminate;
        # `_callee_body` returns [] when the call can't be resolved to an
        # ability.
        if id(nd) not in self._visited {
            self._visited.add(id(nd));
            for stmt in self._callee_body(nd) {
                self._scan(stmt);
            }
        }
    }
    # Node types from an EventSignature: `can foo with NodeType entry`.
    if isinstance(nd, uni.EventSignature) and nd.arch_tag_info {
        if isinstance(nd.arch_tag_info, uni.Name) {
            self._touches.add(nd.arch_tag_info.sym_name);
        } elif isinstance(nd.arch_tag_info, uni.BoolExpr) {
            # Union type: NodeA | NodeB
            for val in nd.arch_tag_info.values {
                if isinstance(val, uni.Name) {
                    self._touches.add(val.sym_name);
                }
            }
        }
    }
    # Recurse into children.
    for child in nd.kid {
        if child {
            self._scan(child);
        }
    }
}

"""Resolve a call's target to its symbol (resolved, with a scope lookup)."""
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
    # Dotted attribute chain (a.b.c): the call targets the last attribute.
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

"""The callee ability's impl-resolved body, or [] if the call can't be
statically resolved to an ability."""
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

"""Flatten an archetype / ability body to a list of statements, resolving a
separate `impl` block when the declaration and body are split."""
impl BoundaryAnalysisPass._resolved_body(
    self: BoundaryAnalysisPass, owner: uni.UniNode
) -> list {
    if hasattr(owner, "_get_impl_resolved_body") {
        try {
            resolved = owner._get_impl_resolved_body();
            if isinstance(resolved, list) {
                return resolved;
            }
        } except Exception {
            pass;
        }
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
