"""Core initialization and transform logic for native IR generation."""
"""Initialize the native IR generation pass."""
impl NaIRGenPass.postinit -> None {
    # Initialize LLVM module with native target data layout
    self.llvm_module = ir.Module(name="jac_native", context=ir.Context());
    import llvmlite.binding as _llvm_bind;
    _llvm_bind.initialize_native_target();
    _target = _llvm_bind.Target.from_default_triple();
    _tm = _target.create_target_machine();
    self.llvm_module.data_layout = str(_tm.target_data);
    self.llvm_module.triple = _tm.triple;

    # Build type_map from the centralized type registry
    _spec_map: dict[str, ir.Type] = {
        "i8": ir.IntType(8),
        "i16": ir.IntType(16),
        "i32": ir.IntType(32),
        "i64": ir.IntType(64),
        "f32": ir.FloatType(),
        "f64": ir.DoubleType(),
        "i1": ir.IntType(1),
        "i8*": ir.IntType(8).as_pointer()
    };
    self.type_map = {};
    try {
        import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
        for (_name, _spec) in JAC_TYPE_REGISTRY.na_type_entries() {
            self.type_map[_name] = _spec_map[_spec];
        }
    } except ImportError {
        # Bootstrap: type_registry not yet compiled; use inline defaults
        self.type_map["int"] = _spec_map["i64"];
        self.type_map["float"] = _spec_map["f64"];
        self.type_map["bool"] = _spec_map["i1"];
        self.type_map["str"] = _spec_map["i8*"];
    }

    # Initialize LLVM struct types that depend on llvm_module.context
    self.complex_struct_type = self.llvm_module.context.get_identified_type(
        "JacComplex"
    );
    self.complex_struct_type.set_body(ir.DoubleType(), ir.DoubleType());

    self.range_struct_type = self.llvm_module.context.get_identified_type("JacRange");
    self.range_struct_type.set_body(ir.IntType(64), ir.IntType(64), ir.IntType(64));

    self.slice_struct_type = self.llvm_module.context.get_identified_type("JacSlice");
    self.slice_struct_type.set_body(ir.IntType(64), ir.IntType(64), ir.IntType(64));

    self.jacval_type = self.llvm_module.context.get_identified_type("JacVal");
    self.jacval_type.set_body(ir.IntType(8), ir.IntType(64));

    super.postinit();
}

# ─── Main Pass Logic ─────────────────────────────────────────
"""Forward-declare, codegen native abilities/entries, and store the LLVM module."""
impl NaIRGenPass.transform(ir_in: uni.Module) -> uni.Module {
    # Auto-promote a compatible .jac module to native context when requested
    if (
        getattr(self.prog, '_auto_promote_native', False)
        and self.ir_in.gen.native_compat
    ) {
        mod_path = self.ir_in.loc.mod_path if self.ir_in.loc else "";
        main_target = getattr(self.prog, '_auto_promote_target', "");
        if (
            mod_path == main_target
            and not mod_path.endswith('.na.jac')
            and not mod_path.endswith('.impl.jac')
            and not mod_path.endswith('.test.jac')
        ) {
            import from jaclang.jac0core.compiler { _coerce_native_module }
            _coerce_native_module(self.ir_in);
        }
    }
    # Emit reference counting helper functions (must be first)
    self._emit_rc_helpers();
    # Process C library imports: import from "libname" { def ...; }
    self._process_clib_imports(self.ir_in);
    # Phase 0: Forward declarations (enums, archetypes, free functions, globals)
    self._register_enums(self.ir_in);
    # Pre-register archetype names as opaque struct types so globals can reference them
    self._forward_declare_archetype_names(self.ir_in);
    # Register struct types from imported .na.jac modules (must be after local forward-declares)
    self._register_imported_struct_types();
    self._register_globals(self.ir_in);
    self._register_archetypes(self.ir_in);
    # Phase 1: Codegen native abilities and entry blocks
    for stmt in ModuleCodegenPass.iter_context_stmts(self.ir_in, CodeContext.NATIVE) {
        if (
            isinstance(stmt, uni.Ability)
            and stmt.signature is not None
            and isinstance(stmt.signature, uni.FuncSignature)
        ) {
            self._codegen_ability(stmt);
        } elif isinstance(stmt, uni.ModuleCode) {
            self._codegen_entry(stmt);
        }
    }
    # Store LLVM module on AST
    if self.has_native_code {
        # Ensure __jac_glob_init is always defined, even for modules that have
        # no `with entry` block.
        if "__jac_glob_init" not in self.func_symtab {
            self._emit_glob_init_func();
        }
        self.ir_in.gen.llvm_ir = self.llvm_module;
        # Debug: dump IR to file
        import os;
        _ir_dump_path = os.environ.get("JAC_DUMP_IR", "");
        if _ir_dump_path {
            with open(_ir_dump_path, "w") as _f {
                _f.write(str(self.llvm_module));
            }
        }
        # Export native layout metadata for auto-marshalling
        self._export_native_layout();
    }
    return self.ir_in;
}

"""Convert an LLVM IR type to a string descriptor for ctypes marshalling."""
impl NaIRGenPass._llvm_type_str(ty: ir.Type) -> str {
    if isinstance(ty, ir.IntType) {
        if ty.width == 64 {
            return "i64";
        }
        if ty.width == 32 {
            return "i32";
        }
        if ty.width == 8 {
            return "i8";
        }
        if ty.width == 1 {
            return "i1";
        }
        return f"i{ty.width}";
    }
    if isinstance(ty, ir.DoubleType) {
        return "f64";
    }
    if isinstance(ty, ir.FloatType) {
        return "f32";
    }
    if isinstance(ty, ir.VoidType) {
        return "void";
    }
    if isinstance(ty, ir.PointerType) {
        if ty?.pointee {
            # Check for i8* (string)
            if isinstance(ty.pointee, ir.IntType) and ty.pointee.width == 8 {
                return "i8*";
            }
            # Check for known struct type
            for (sname, stype) in self.struct_types.items() {
                if ty.pointee == stype {
                    return f"{sname}*";
                }
            }
            # Check for list type
            for (ename, ltype) in self.list_types.items() {
                if ty.pointee == ltype {
                    return f"List.{ename}*";
                }
            }
            # Check for tuple type
            for (tkey, ttype) in self.tuple_types.items() {
                if ty.pointee == ttype {
                    return f"Tuple*";
                }
            }
        }
        return "ptr";
    }
    return "i64";
}

"""Export struct/enum/function layout metadata to CodeGenTarget."""
impl NaIRGenPass._export_native_layout -> None {
    import from jaclang.jac0core.codeinfo {
        NativeModuleLayout,
        NativeStructLayout,
        NativeFieldInfo,
        NativeEnumLayout,
        NativeFuncLayout,
        NativeTupleLayout
    }
    layout = NativeModuleLayout();
    # Structs
    for (arch_name, field_indices) in self.struct_field_indices.items() {
        field_types = self.struct_field_types.get(arch_name, {});
        fields: list[NativeFieldInfo] = [];
        enum_types = self.struct_field_enum_type.get(arch_name, {});
        for (fname, idx) in sorted(field_indices.items(), key=lambda x : x[1]) {
            ftype = field_types.get(fname);
            llvm_t = self._llvm_type_str(ftype) if ftype is not None else "i64";
            # Detect function pointer fields
            is_fn_ptr = False;
            fn_param_types: (list[str] | None) = None;
            fn_ret_type: (str | None) = None;
            if (
                ftype is not None
                and isinstance(ftype, ir.PointerType)
                and isinstance(ftype.pointee, ir.FunctionType)
            ) {
                is_fn_ptr = True;
                fn_param_types = [self._llvm_type_str(a) for a in ftype.pointee.args];
                fn_ret_type = self._llvm_type_str(ftype.pointee.return_type);
            }
            fields.append(
                NativeFieldInfo(
                    name=fname,
                    llvm_type=llvm_t,
                    index=idx,
                    enum_type=enum_types.get(fname),
                    is_func_ptr=is_fn_ptr,
                    func_param_types=fn_param_types,
                    func_ret_type=fn_ret_type
                )
            );
        }
        layout.structs[arch_name] = NativeStructLayout(
            name=arch_name,
            fields=fields,
            has_vtable=self.has_vtable.get(arch_name, False)
        );
    }
    # Enums
    for (enum_name, entries) in self.enum_string_values.items() {
        layout.enums[enum_name] = NativeEnumLayout(
            name=enum_name, is_string_valued=True, members=list(entries)
        );
    }
    # Tuples
    for (tkey, ttype) in self.tuple_types.items() {
        elem_types = [self._llvm_type_str(e) for e in ttype.elements];
        layout.tuples[tkey] = NativeTupleLayout(
            key=tkey,
            element_types=elem_types,
            element_struct_hints=[None] * len(elem_types)
        );
    }
    # Free functions (exclude methods which are also in func_symtab)
    method_names = set(self.method_funcs.keys());
    for (fname, func) in self.func_symtab.items() {
        if fname.startswith("__") or fname == "jac_entry" or fname in method_names {
            continue;
        }
        param_types = [self._llvm_type_str(a) for a in func.function_type.args];
        param_names: list[str] = [a.name for a in func.args];
        ret_type = self._llvm_type_str(func.function_type.return_type);
        ret_struct: (str | None) = None;
        ret_tuple: (NativeTupleLayout | None) = None;
        if isinstance(func.function_type.return_type, ir.PointerType) {
            for (sn, st) in self.struct_types.items() {
                if func.function_type.return_type.pointee == st {
                    ret_struct = sn;
                    break;
                }
            }
            # Match tuple return type and extract struct hints from AST
            if ret_type.startswith("Tuple") {
                for (tkey, ttype) in self.tuple_types.items() {
                    if func.function_type.return_type.pointee == ttype {
                        ret_tuple = layout.tuples.get(tkey);
                        if ret_tuple is not None {
                            sig = self.method_ast_sigs.get(fname);
                            if sig and sig.return_type {
                                hints = self._extract_tuple_struct_hints(
                                    sig.return_type
                                );
                                if hints
                                and len(hints) == len(ret_tuple.element_types) {
                                    ret_tuple = NativeTupleLayout(
                                        key=ret_tuple.key,
                                        element_types=ret_tuple.element_types,
                                        element_struct_hints=hints
                                    );
                                    layout.tuples[tkey] = ret_tuple;
                                }
                            }
                        }
                        break;
                    }
                }
            }
        }
        layout.functions[fname] = NativeFuncLayout(
            name=fname,
            param_types=param_types,
            param_names=param_names,
            ret_type=ret_type,
            ret_struct_name=ret_struct,
            ret_tuple_layout=ret_tuple
        );
    }
    # Methods
    for (mname, func) in self.method_funcs.items() {
        param_types = [self._llvm_type_str(a) for a in func.function_type.args];
        param_names = [a.name for a in func.args];
        ret_type = self._llvm_type_str(func.function_type.return_type);
        ret_struct: (str | None) = None;
        if isinstance(func.function_type.return_type, ir.PointerType) {
            for (sn, st) in self.struct_types.items() {
                if func.function_type.return_type.pointee == st {
                    ret_struct = sn;
                    break;
                }
            }
        }
        layout.methods[mname] = NativeFuncLayout(
            name=mname,
            param_types=param_types,
            param_names=param_names,
            ret_type=ret_type,
            ret_struct_name=ret_struct
        );
    }
    # List element types
    for (ename, ltype) in self.list_types.items() {
        layout.list_elem_types[f"List.{ename}"] = ename;
    }
    self.ir_in.gen.native_layout = layout;
}

"""Extract struct hints from a tuple return type AST node.

Walks the return type annotation (e.g. tuple[list[Token], list[LexerError]])
to extract struct names for each tuple element that contains struct pointers.
Returns a list of (struct_name | None) for each element.
"""
impl NaIRGenPass._extract_tuple_struct_hints(type_node: object) -> list {
    hints: list = [];
    if not isinstance(type_node, uni.Expr) {
        return hints;
    }
    # Walk slices of tuple[...] annotation
    if type_node?.right and type_node.right?.slices {
        slices = type_node.right.slices or [];
        for s in slices {
            inner = s.start if s?.start else s;
            # Handle TupleVal wrapping: tuple[(T1, T2)] parses as TupleVal
            if isinstance(inner, uni.TupleVal) {
                for tv in inner.values {
                    hints.append(self._extract_elem_struct_hint(tv));
                }
            } else {
                hints.append(self._extract_elem_struct_hint(inner));
            }
        }
    }
    return hints;
}

"""Extract a struct hint from a single type element (e.g. list[Token] -> 'Token')."""
impl NaIRGenPass._extract_elem_struct_hint(type_node: object) -> (str | None) {
    if not isinstance(type_node, uni.Expr) {
        return None;
    }
    # For AtomTrailer nodes (e.g. list[Token]), get the base name from kid[0]
    name = self._get_name(type_node);
    if name is None and isinstance(type_node, uni.AtomTrailer) {
        # AtomTrailer has kid[0] = Name("list"), kid[1] = IndexSlice
        if type_node.kid {
            name = self._get_name(type_node.kid[0]);
        }
    }
    # Check if this is list[StructName] or similar container
    if name == "list" and type_node?.right and type_node.right?.slices {
        inner_slices = type_node.right.slices or [];
        for is_ in inner_slices {
            inner_type = is_.start if is_?.start else is_;
            inner_name = self._get_name(inner_type);
            if inner_name is not None and inner_name in self.struct_types {
                return inner_name;
            }
        }
    }
    # Direct struct name
    if name is not None and name in self.struct_types {
        return name;
    }
    return None;
}

# ─── Imported Struct Type Registration ────────────────────────
"""Register struct types from imported .na.jac modules.

Walks the current module's import statements, resolves each imported
.na.jac module via the module hub, and registers any archetypes found
in the imported module. This enables the importing module to use
imported struct types in function signatures, instantiate them,
and access their fields.
"""
impl NaIRGenPass._register_imported_struct_types -> None {
    import os;
    # Collect imports from top-level and inside na {} blocks
    imports = [
        s
        for s in ModuleCodegenPass.iter_context_stmts(self.ir_in)
        if isinstance(s, uni.Import)
    ];
    # Resolve all imported modules, deduplicating by absolute path.
    processed_modules: set[str] = set();
    imported_mods: list = [];
    for imp in imports {
        if not imp.from_loc or not isinstance(imp.from_loc, uni.ModulePath) {
            continue;
        }
        # Skip clib imports (from "libname")
        if imp.from_loc.path and isinstance(imp.from_loc.path[0], uni.String) {
            continue;
        }
        try {
            resolved_path = imp.from_loc.resolve_relative_path();
        } except Exception {
            continue;
        }
        abs_key = os.path.abspath(resolved_path);
        if abs_key in processed_modules {
            continue;
        }
        # Look up the imported module in the hub (try both relative and absolute)
        imported_mod = self.prog.mod.hub.get(resolved_path);
        if imported_mod is None {
            imported_mod = self.prog.mod.hub.get(abs_key);
        }
        # If not in hub, parse the imported .jac file for type extraction.
        if (
            imported_mod is None
            and resolved_path.endswith('.jac')
            and os.path.isfile(resolved_path)
        ) {
            try {
                import from jaclang.jac0core.parser { parse as rd_parse }
                source = open(resolved_path).read();
                (imported_mod, _) = rd_parse(source, resolved_path, prog=self.prog);
            } except Exception {
                continue;
            }
        }
        if imported_mod is None {
            continue;
        }
        processed_modules.add(abs_key);
        imported_mods.append((resolved_path, imported_mod));
    }
    # ── Phase 1a: register ALL struct names (empty identified types) ─────────
    # All struct names must exist in struct_types before any body is filled
    # so that cross-module field/parameter type references (e.g.
    # JSClosure.func: CompiledFunction) resolve correctly even when the
    # defining module is walked after the referencing module.
    for (_, imported_mod) in imported_mods {
        self._walk_imported_module_type_names(imported_mod);
    }
    # ── Phase 1b: fill ALL struct bodies, enums, globals ─────────────────────
    for (_, imported_mod) in imported_mods {
        self._walk_imported_module_types(imported_mod);
    }
    # ── Phase 2: forward-declare ALL abilities from ALL modules ──────────────
    for (resolved_path, imported_mod) in imported_mods {
        self._walk_imported_module_abilities(imported_mod);
        # Track path so _codegen_entry can emit __jac_glob_init_<safe_name>() calls
        if resolved_path not in self._imported_na_paths {
            self._imported_na_paths.append(resolved_path);
        }
    }
}

"""Walk an imported module's AST and register all type declarations."""
impl NaIRGenPass._walk_imported_module(imported_mod: uni.Module) -> None {
    # Full walk (types + abilities) — kept for any direct callers.
    self._walk_imported_module_type_names(imported_mod);
    self._walk_imported_module_types(imported_mod);
    self._walk_imported_module_abilities(imported_mod);
}

"""Phase-1a walk: register struct names only (empty identified types, no bodies)."""
impl NaIRGenPass._walk_imported_module_type_names(imported_mod: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            aname = stmt.name.value if stmt.name else None;
            if aname is not None and aname not in self.struct_types {
                struct_type = self.llvm_module.context.get_identified_type(aname);
                self.struct_types[aname] = struct_type;
            }
        }
    }
}

"""Phase-1b walk: fill struct bodies, register enums and globals."""
impl NaIRGenPass._walk_imported_module_types(imported_mod: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            self._register_imported_archetype(stmt);
        } elif isinstance(stmt, uni.Enum) {
            self._codegen_enum(stmt);
        } elif isinstance(stmt, uni.GlobalVars) {
            self._register_imported_globals(stmt);
        }
    }
}

"""Phase-2 walk: forward-declare imported abilities (all struct types already registered)."""
impl NaIRGenPass._walk_imported_module_abilities(imported_mod: uni.Module) -> None {
    # First: forward-declare methods on all imported archetypes.
    # Must happen before module-level abilities so that method-call resolution
    # finds every struct method in self.method_funcs.
    for stmt in ModuleCodegenPass.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) {
            self._forward_declare_archetype_methods(stmt);
        }
    }
    # Second: forward-declare module-level functions.
    for stmt in ModuleCodegenPass.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            continue;
        }
        if isinstance(stmt, uni.Ability) {
            self._forward_declare_imported_ability(stmt);
        }
    }
}

"""Forward-declare all methods of a single imported archetype.
Called during Phase 2 so all struct types from all modules are already registered.
"""
impl NaIRGenPass._forward_declare_archetype_methods(arch: uni.Archetype) -> None {
    aname = arch.name.value if arch.name else None;
    if aname is None or arch.body is None {
        return;
    }
    for stmt in arch.body {
        if isinstance(stmt, uni.Ability) {
            if stmt.signature is not None
            and isinstance(stmt.signature, uni.FuncSignature) {
                self._forward_declare_method(aname, stmt);
            }
        }
    }
}

"""Register a single imported archetype: create struct type and define field layout only.
Method forward-declarations are deferred to Phase 2 (_forward_declare_archetype_methods)
so that param types from other imported modules are already in self.struct_types.
"""
impl NaIRGenPass._register_imported_archetype(arch: uni.Archetype) -> None {
    aname = arch.name.value if arch.name else None;
    if aname is None {
        return;
    }
    # Ensure the identified struct type exists (Phase 1a may have pre-created it).
    if aname not in self.struct_types {
        struct_type = self.llvm_module.context.get_identified_type(aname);
        self.struct_types[aname] = struct_type;
    }
    # Guard: skip body fill if already done (e.g., called twice due to multiple
    # import paths, or after Phase 1a + Phase 1b sequencing).
    if aname in self._struct_bodies_done {
        return;
    }
    self._struct_bodies_done.add(aname);
    # Fill struct body with full field layout.
    self._codegen_archetype(arch);
}

"""Register imported global variables with external linkage (resolved at link time)."""
impl NaIRGenPass._register_imported_globals(nd: uni.GlobalVars) -> None {
    for assign in nd.assignments {
        targets = assign.target
            if isinstance(assign.target, (list, tuple))
            else [(assign.target)];
        for target in targets {
            var_name = self._get_name(target);
            if var_name is None or var_name in self.global_vars {
                continue;
            }
            var_type: ir.Type = ir.IntType(64);
            if assign.type_tag and assign.type_tag.tag {
                var_type = self._resolve_jac_type(assign.type_tag.tag);
                # Track type annotation node for chained subscript+field access
                # e.g. ITEMS[i].field chains need the list[Outer] node to bitcast
                self.var_type_node[var_name] = assign.type_tag.tag;
            }
            global_var = ir.GlobalVariable(self.llvm_module, var_type, name=var_name);
            global_var.linkage = "external";
            self.global_vars[var_name] = global_var;
            self.global_var_types[var_name] = var_type;
            # Track list element types for imported list globals
            if isinstance(var_type, ir.PointerType) {
                for (ename, ltype) in self.list_types.items() {
                    if var_type == ltype.as_pointer() {
                        self.var_list_elem_type[var_name] = ename;
                        break;
                    }
                }
            }
            # Track dict types for imported dict globals
            if isinstance(var_type, ir.PointerType) {
                for (dict_key, dtype) in self.dict_types.items() {
                    if var_type == dtype.as_pointer() {
                        self.var_dict_type[var_name] = dict_key;
                        break;
                    }
                }
            }
            self.has_native_code = True;
        }
    }
}

"""Forward-declare an imported function (resolved at link time).

Delegates to _maybe_declare_ability which handles all type resolution correctly.
"""
impl NaIRGenPass._forward_declare_imported_ability(nd: uni.Ability) -> None {
    name = nd.name_ref.sym_name if nd.name_ref else None;
    if name is None or name in self.func_symtab {
        return;
    }
    # Only forward-declare concrete function definitions (with body + signature)
    if nd.body is None {
        return;
    }
    self._maybe_declare_ability(nd);
}

# ─── C Library Import Processing ──────────────────────────────
"""Process import from "libname" { def ...; } statements.

Extracts library paths for loading and forward-declares
extern symbols from the clib declarations.
"""
impl NaIRGenPass._process_clib_imports(module: uni.Module) -> None {
    # Collect imports from top-level and inside na {} blocks
    imports = [
        s
        for s in ModuleCodegenPass.iter_context_stmts(module)
        if isinstance(s, uni.Import)
    ];
    for stmt in imports {
        # Recognize `import sys;` for native sys module support
        if not stmt.clib_decls {
            if stmt.items {
                for item in stmt.items {
                    mod_name = None;
                    if isinstance(item, uni.ModulePath) and item.path {
                        parts = [];
                        for p in item.path {
                            parts.append(
                                p.value if isinstance(p, uni.Name) else str(p)
                            );
                        }
                        mod_name = ".".join(parts);
                    }
                    if mod_name == "sys" {
                        self._native_stdlib_modules.add("sys");
                    }
                }
            }
            continue;
        }
        # Extract library path from from_loc
        if stmt.from_loc is not None and stmt.from_loc.path {
            for path_part in stmt.from_loc.path {
                if isinstance(path_part, uni.String) {
                    raw = path_part.value;
                    # Strip quotes
                    if (len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'") {
                        raw = raw[1:-1];
                    }
                    # Store library path for NativeCompilePass to load
                    self._clib_paths.append(raw);
                }
            }
        }
        # Three-pass processing of clib declarations:
        # Pass 1: Register struct types (opaque, for forward refs)
        for decl in stmt.clib_decls {
            if isinstance(decl, uni.Archetype) {
                arch_name = decl.name.value if decl.name else None;
                if arch_name is not None {
                    struct_type = self.llvm_module.context.get_identified_type(
                        arch_name
                    );
                    self.struct_types[arch_name] = struct_type;
                    self.clib_struct_names.add(arch_name);
                    self.has_native_code = True;
                }
            }
        }
        # Pass 1.5: Define struct bodies (field layout)
        for decl in stmt.clib_decls {
            if isinstance(decl, uni.Archetype) {
                arch_name = decl.name.value if decl.name else None;
                if arch_name is not None and arch_name in self.struct_types {
                    self._codegen_archetype(decl);
                    # Compute ABI integer type for small structs (C ABI coercion)
                    stype = self.struct_types[arch_name];
                    if stype?.elements and stype.elements {
                        total_bits = 0;
                        all_int = True;
                        for elem in stype.elements {
                            if isinstance(elem, ir.IntType) {
                                total_bits += elem.width;
                            } else {
                                all_int = False;
                                break;
                            }
                        }
                        if all_int and 0 < total_bits <= 64 {
                            # Round up to nearest power-of-2 byte size
                            abi_bits = 8;
                            while abi_bits < total_bits {
                                abi_bits *= 2;
                            }
                            self.clib_struct_abi_types[arch_name] = ir.IntType(
                                abi_bits
                            );
                        }
                    }
                }
            }
        }
        # Pass 2: Forward-declare extern functions (with value types for clib structs)
        for decl in stmt.clib_decls {
            if isinstance(decl, uni.Ability) {
                fn_name = decl.name_ref.sym_name if decl.name_ref else None;
                if decl.body is not None {
                    self.emit(E5060, name=fn_name);
                    continue;
                }
                self._declare_clib_ability(decl);
                if fn_name {
                    self.clib_extern_names.add(fn_name);
                }
            }
        }
        # Store clib paths on module gen for compile pass
        if self?._clib_paths and self._clib_paths {
            module.gen._clib_paths = self._clib_paths;
            self.has_native_code = True;
        }
    }
}

# ─── Primitive Emitter Dispatch ────────────────────────────────
"""Lazily initialize primitive emitter singletons."""
impl NaIRGenPass._ensure_emitters -> None {
    if self._native_emitters is not None {
        return;
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    import jaclang.compiler.passes.native.primitives_native as _pn;
    self._native_emitters = {};
    for (_tn, _suffix) in JAC_TYPE_REGISTRY.emitter_items() {
        _ecls = getattr(_pn, "Native" + _suffix, None);
        if _ecls is not None {
            self._native_emitters[_tn] = _ecls();
        }
    }
    self._native_builtin_emitter = _pn.NativeBuiltinEmitter();
    self._native_emit_ctx_class = _pn.NativeEmitCtx;
}

"""Dispatch a primitive type method call through the emitter layer."""
impl NaIRGenPass._dispatch_primitive_method(
    type_name: str,
    method_name: str,
    target: ir.Value,
    args: list[ir.Value],
    type_key: str
) -> (ir.Value | None) {
    self._ensure_emitters();
    _emitter = self._native_emitters.get(type_name);
    if _emitter is None {
        return None;
    }
    _emit_fn = getattr(_emitter, "emit_" + method_name, None);
    if _emit_fn is None {
        return None;
    }
    _ctx = self._native_emit_ctx_class(pass_ref=self, type_key=type_key);
    return _emit_fn(_ctx, target, args);
}

"""Dispatch a builtin function call through the emitter layer."""
impl NaIRGenPass._dispatch_builtin(
    func_name: str, args: list[ir.Value]
) -> (ir.Value | None) {
    self._ensure_emitters();
    _emit_fn = getattr(self._native_builtin_emitter, "emit_" + func_name, None);
    if _emit_fn is None {
        return None;
    }
    _ctx = self._native_emit_ctx_class(pass_ref=self, type_key="");
    return _emit_fn(_ctx, args);
}
