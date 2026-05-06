"""Implementation for interop_analysis_pass constructs."""

"""Initialize function definition tracking."""
impl InteropAnalysisPass.before_pass(self: InteropAnalysisPass) -> None {
    self._func_defs: dict[(str, tuple[(InteropContext, uni.Ability)])] = {};
    self._imported_native_funcs: dict[(str, tuple[(str, InteropContext)])] = {};
}

"""Determine the codespace context of a node."""
impl InteropAnalysisPass._get_context(
    self: InteropAnalysisPass, nd: uni.UniNode
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
impl InteropAnalysisPass._extract_type_name(
    self: InteropAnalysisPass, expr: (uni.UniNode | None)
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
impl InteropAnalysisPass._resolve_native_module(
    self: InteropAnalysisPass, module_name: str
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
impl InteropAnalysisPass.enter_import(
    self: InteropAnalysisPass, nd: uni.Import
) -> None {
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
            in_server_module = (
                mod_path_str.endswith('.jac')
                and not mod_path_str.endswith('.cl.jac')
                and not mod_path_str.endswith('.na.jac')
                and not mod_path_str.endswith('.impl.jac')
            );
            sv_token = nd._source_context_token()
                if nd?._source_context_token
                else None;
            has_sv_prefix = sv_token is not None and sv_token.name == Tok.KW_SERVER;
            if (has_sv_prefix and not native_path and in_server_module and nd.items) {
                self._register_sv_to_sv_import(nd, module_name);
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
                                and self.ir_in.loc.mod_path.endswith('.na.jac')
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

"""Register an sv-to-sv import: create InteropBindings for each item.

For each function imported, look up the source module's symbol table to
extract param names, types, and return type. These bindings drive PyAST
codegen of HTTP client stubs and inform boundary type collection.
"""
impl InteropAnalysisPass._register_sv_to_sv_import(
    self: InteropAnalysisPass, nd: uni.Import, module_name: str
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
    # Build a name -> Ability map by walking the source module's AST.
    # This works whether or not the source has had symtab built.
    source_abilities: dict[str, Any] = {};
    if source_mod {
        try {
            self._collect_abilities(source_mod, source_abilities);
        } except Exception { }
    }
    manifest = self.ir_in.gen.interop_manifest;
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem) {
            continue;
        }
        func_name = getattr(item.name, 'value', str(item.name));
        param_names: list = [];
        param_types: list = [];
        ret_type: str = 'Any';
        ability_node: (uni.Ability | None) = source_abilities.get(func_name);
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
        local_name = item.alias.sym_name if item.alias else func_name;
        binding = InteropBinding(
            name=func_name,
            source_context=InteropContext.SERVER,
            callers={InteropContext.SERVER},
            ret_type=ret_type,
            param_types=param_types,
            param_names=param_names,
            ast_node=ability_node,
            route=[InteropContext.SERVER, InteropContext.SERVER],
            source_module=module_name
        );
        manifest.bindings[local_name] = binding;
    }
}

"""Walk a module AST collecting Ability nodes by name."""
impl InteropAnalysisPass._collect_abilities(
    self: InteropAnalysisPass, nd: Any, out: dict[str, Any]
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

"""Parse a source file standalone (no semantic analysis).

Used by sv-to-sv detection to extract function signatures from a
provider module that hasn't been compiled yet. We avoid running the
full compile pipeline to prevent recursive compilation cascades.
"""
impl InteropAnalysisPass._parse_only_source_module(
    self: InteropAnalysisPass, file_path: str
) -> Any {
    import from jaclang.jac0core.compiler { JacCompiler }
    try {
        f = open(file_path, 'r');
        try {
            src_text = f.read();
        } finally {
            f.close();
        }
        compiler_obj = JacCompiler();
        return compiler_obj.parse_str(
            source_str=src_text, file_path=file_path, target_program=self.prog
        );
    } except Exception {
        return None;
    }
}

"""Find an Archetype or Enum node by name via AST walk."""
impl InteropAnalysisPass._find_archetype(
    self: InteropAnalysisPass, nd: Any, target: str
) -> Any {
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

"""Record function definition and its context."""
impl InteropAnalysisPass.enter_ability(
    self: InteropAnalysisPass, nd: uni.Ability
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
}

"""Check if a function call crosses context boundaries."""
impl InteropAnalysisPass.enter_func_call(
    self: InteropAnalysisPass, nd: uni.FuncCall
) -> None {
    func_name = None;
    if isinstance(nd.target, uni.Name) {
        func_name = nd.target.value;
    } elif isinstance(nd.target, uni.NameAtom) {
        func_name = nd.target.sym_name;
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
impl InteropAnalysisPass._extract_subscript_inner(
    self: InteropAnalysisPass, expr: (uni.UniNode | None)
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
impl InteropAnalysisPass._extract_all_subscript_types(
    self: InteropAnalysisPass, expr: (uni.UniNode | None)
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
impl InteropAnalysisPass._extract_all_type_names(
    self: InteropAnalysisPass, expr: (uni.UniNode | None)
) -> list[str] {
    prims = {'str','int','float','bool','None','Any','list','dict','tuple','set','frozenset','bytes','object','type','JsxElement'};
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
impl InteropAnalysisPass._collect_boundary_type(
    self: InteropAnalysisPass, type_name: str, source_mod: (uni.Module | None)
) -> None {
    prims = {'str','int','float','bool','None','Any','list','dict','tuple','set','frozenset','bytes','object','type','JsxElement'};
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
            arch_node = sym.defn[0];
            if isinstance(arch_node, uni.NameAtom) and arch_node.parent {
                arch_node = arch_node.parent;
            }
            break;
        }
    }
    # AST-walk fallback for modules without a built sym_tab (e.g., a source
    # module that's already in prog.mod.hub but for which boundary type
    # collection runs before symtab build).
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
        arch_type = arch_node.arch_type;
        kind = "obj";
        if hasattr(arch_type, 'name') {
            name_val = arch_type.name;
            if name_val == "KW_NODE" or "node" in str(name_val).lower() {
                kind = "node";
            } elif name_val == "KW_WALKER" or "walker" in str(name_val).lower() {
                kind = "walker";
            }
        }
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
impl InteropAnalysisPass.after_pass(self: InteropAnalysisPass) -> None {
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
}
