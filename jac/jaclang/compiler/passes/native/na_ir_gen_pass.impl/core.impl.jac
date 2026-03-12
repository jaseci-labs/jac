"""Core initialization and transform logic for native IR generation."""
"""Initialize the native IR generation pass."""
impl NaIRGenPass.init(
    ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
) -> None {
    self.llvm_module = ir.Module(name="jac_native", context=ir.Context());
    # Set data layout to match native target so optimizer and MCJIT agree
    # on struct sizes. Without this, the optimizer uses default layout
    # (4-byte i64 alignment, sizeof({i8,i64})=12) while MCJIT uses native
    # x86-64 layout (8-byte alignment, sizeof=16), causing buffer overflows.
    import llvmlite.binding as _llvm_bind;
    _llvm_bind.initialize_native_target();
    _target = _llvm_bind.Target.from_default_triple();
    _tm = _target.create_target_machine();
    self.llvm_module.data_layout = str(_tm.target_data);
    self.llvm_module.triple = _tm.triple;
    self.builder: (ir.IRBuilder | None) = None;
    self.func_symtab: dict[(str, ir.Function)] = {};
    self.local_vars: dict[(str, ir.AllocaInstr)] = {};
    self.has_native_code = False;
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
    self.type_map: dict[(str, ir.Type)] = {};
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
    self._fmt_strings: dict[(str, ir.GlobalVariable)] = {};
    # External function cache (Phase 0)
    self.extern_funcs: dict[(str, ir.Function)] = {};
    # C library extern function names (from import from "lib" { def ...; })
    self.clib_extern_names: set[str] = set();
    # C library struct names (value-type structs declared in clib import blocks)
    self.clib_struct_names: set[str] = set();
    # ABI-coerced integer types for small clib structs (struct_name → ir.IntType)
    self.clib_struct_abi_types: dict[str, ir.Type] = {};
    # Enum support (Phase 1)
    self.enum_values: dict[(str, ir.Constant)] = {};
    self.enum_types: dict[(str, ir.IntType)] = {};
    # String-valued enum lookup tables
    self.enum_string_values: dict[str, list] = {};  # enum_name → [(member_name, string_value, ordinal), ...]
    self.enum_value_arrays: dict[str, object] = {};  # enum_name → global [N x i8*] array (.value strings)
    self.enum_name_arrays: dict[str, object] = {};  # enum_name → global [N x i8*] array (.name strings)
    self.var_enum_type: dict[str, str] = {};  # var_name → enum_name (tracks enum-typed vars)
    self.struct_field_enum_type: dict[str, dict] = {};  # struct_name → {field_name → enum_name}
    # Loop stack for break/continue (Phase 1)
    self.loop_stack: list[tuple] = [];
    # String counter for unique global names (Phase 2)
    self._str_count: int = 0;
    # Object/struct support (Phase 3)
    self.struct_types: dict[(str, object)] = {};
    self.struct_field_indices: dict[(str, dict)] = {};
    self.struct_field_types: dict[(str, dict)] = {};
    self.struct_field_defaults: dict[(str, object)] = {};
    self.method_funcs: dict[(str, ir.Function)] = {};
    self.method_ast_sigs: dict[(str, object)] = {};  # "Arch.method" → FuncSignature AST node
    self.type_var_map: dict[(str, str)] = {};
    # List support (Phase 4)
    self.list_types: dict[(str, object)] = {};  # elem_type_name → list struct type
    self.list_helpers: dict[(str, dict)] = {};  # elem_type_name → {new, append, get, set, len}
    self.var_list_elem_type: dict[(str, str)] = {};  # var_name → elem_type_name
    # Jac-level type tracking for nested lists and ptr list element resolution
    self.field_type_node: dict[(str, dict)] = {};  # struct_name → {field → type AST node}
    self.var_type_node: dict[(str, object)] = {};  # var_name → type AST node
    self._list_type_hint: (str | None) = None;  # hint for empty list creation
    self._last_type_node_hint: (object | None) = None;  # Jac type AST of last evaluated expr
    # Inheritance / vtable support (Phase 5)
    self.class_hierarchy: dict[(str, str)] = {};  # child → primary parent (backward compat)
    self.class_parents: dict[str, list[str]] = {};  # child → [parent1, parent2, ...]
    self.mro_order: dict[str, list[str]] = {};  # class → C3 MRO [self, parent1, ...]
    self.parent_field_start: dict[str, dict[str, int]] = {};  # child → {ancestor → first_field_idx}
    self.arch_ast_map: dict[str, object] = {};  # class_name → Archetype AST node
    self.has_vtable: dict[(str, bool)] = {};
    self.vtable_layouts: dict[(str, list[str])] = {};
    self.vtable_method_indices: dict[(str, dict)] = {};
    self.vtable_globals: dict[(str, ir.GlobalVariable)] = {};
    self._non_overridden_methods: dict[str, set[str]] = {};  # class → methods never overridden by children
    # Tuple support (Phase 9)
    self.tuple_types: dict[(str, object)] = {};  # type_key → LiteralStructType
    self.var_tuple_type: dict[(str, str)] = {};  # var_name → tuple_key
    # Complex number support
    self.complex_struct_type = self.llvm_module.context.get_identified_type(
        "JacComplex"
    );
    self.complex_struct_type.set_body(
        ir.DoubleType(), ir.DoubleType()
    );  # {f64 real, f64 imag}
    self.var_complex: set[str] = set();  # variable names known to be complex
    # Range object support
    self.range_struct_type = self.llvm_module.context.get_identified_type("JacRange");
    self.range_struct_type.set_body(
        ir.IntType(64), ir.IntType(64), ir.IntType(64)
    );  # {i64 start, i64 stop, i64 step}
    self.var_range: set[str] = set();  # variable names known to be range
    # Slice object support (same layout as JacRange)
    self.slice_struct_type = self.llvm_module.context.get_identified_type("JacSlice");
    self.slice_struct_type.set_body(
        ir.IntType(64), ir.IntType(64), ir.IntType(64)
    );  # {i64 start, i64 stop, i64 step}
    self.var_slice: set[str] = set();  # variable names known to be slice
    # Global variable support (Phase 11)
    self.global_vars: dict[(str, ir.GlobalVariable)] = {};  # name → global variable
    self.global_var_types: dict[(str, ir.Type)] = {};  # name → LLVM type
    # Dictionary support (Phase 12)
    self.dict_types: dict[(str, object)] = {};  # "key_type:val_type" → dict struct type
    self.dict_helpers: dict[(str, dict)] = {};  # "key_type:val_type" → {new, set, get, contains, len}
    self.var_dict_type: dict[(str, str)] = {};  # var_name → "key_type:val_type"
    # JacVal tagged union for dict[str, any] support
    self.jacval_type = self.llvm_module.context.get_identified_type("JacVal");
    self.jacval_type.set_body(ir.IntType(8), ir.IntType(64));  # {i8 tag, i64 payload}
    self._dict_val_type_hint: (str | None) = None;  # "jacval" when dict[str, any]
    # Set support (Phase 13)
    self.set_types: dict[(str, object)] = {};  # elem_type_name → set struct type
    self.set_helpers: dict[(str, dict)] = {};  # elem_type_name → {new, add, contains, len}
    self.var_set_elem_type: dict[(str, str)] = {};  # var_name → elem_type_name
    # Exception handling support (Phase 14)
    self._exc_state_type: (object | None) = None;  # JacExceptionState struct type
    self._exc_handler_global: (object | None) = None;  # @__jac_current_handler global
    self._exc_push_fn: (object | None) = None;  # __jac_exc_push function
    self._exc_pop_fn: (object | None) = None;  # __jac_exc_pop function
    self._exc_raise_fn: (object | None) = None;  # __jac_exc_raise function
    self._exc_type_registry: dict[(str, int)] = {"Exception": 0};  # exc_name → type_id
    self._exc_type_counter: int = 1;  # Next type ID to assign
    self._rt_error_msgs: dict[(str, object)] = {};  # msg → ir.GlobalVariable (dedup cache)
    # File I/O support (Phase 15)
    self._file_struct_type: (object | None) = None;  # File struct type
    self._file_helpers_emitted: bool = False;
    # Primitive emitter singletons (lazily initialized)
    self._native_emitters: (dict[str, object] | None) = None;
    self._native_builtin_emitter: (object | None) = None;
    # Reference counting support (Phase RC)
    self.rc_alloc_fn: (ir.Function | None) = None;
    self.rc_retain_fn: (ir.Function | None) = None;
    self.rc_release_simple_fn: (ir.Function | None) = None;
    self.malloc_fn: (ir.Function | None) = None;
    self.free_fn: (ir.Function | None) = None;
    self.struct_release_fns: dict[(str, ir.Function)] = {};
    self.list_release_fns: dict[(str, ir.Function)] = {};
    self.dict_release_fns: dict[(str, ir.Function)] = {};
    self.set_release_fns: dict[(str, ir.Function)] = {};
    super.init(ir_in=ir_in, prog=prog, cancel_token=cancel_token);
}

# ─── Main Pass Logic ─────────────────────────────────────────
"""Forward-declare, codegen native abilities/entries, and store the LLVM module."""
impl NaIRGenPass.transform(ir_in: uni.Module) -> uni.Module {
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
    # Track already-processed modules to avoid duplicates
    processed_modules: set[str] = set();
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
        if resolved_path in processed_modules {
            continue;
        }
        processed_modules.add(resolved_path);
        # Look up the imported module in the hub (try both relative and absolute)
        imported_mod = self.prog.mod.hub.get(resolved_path);
        if imported_mod is None {
            abs_path = os.path.abspath(resolved_path);
            imported_mod = self.prog.mod.hub.get(abs_path);
        }
        # If not in hub, parse the imported .jac file to get its AST for type
        # extraction. Use rd_parse directly (not parse_str) to avoid adding a
        # parse-only module to the hub, which would prevent TypeCheckPass from
        # properly compiling it with SymTabBuildPass later.
        # Only parse .jac files — .py/.pyi stubs must use the Python parser.
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
        # Walk the imported module for archetypes, enums, globals, functions
        self._walk_imported_module(imported_mod);
        # Track path so _codegen_entry can emit __jac_glob_init_<safe_name>() calls
        if not self?._imported_na_paths {
            self._imported_na_paths: list = [];
        }
        if resolved_path not in self._imported_na_paths {
            self._imported_na_paths.append(resolved_path);
        }
    }
}

"""Walk an imported module's AST and register all type declarations."""
impl NaIRGenPass._walk_imported_module(imported_mod: uni.Module) -> None {
    # Flatten all blocks; skip only CLIENT-context statements.
    # Imported modules may be plain .jac (SERVER) or .na.jac (NATIVE);
    # both need their types/enums registered for native compilation.
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
        } elif isinstance(stmt, uni.Ability) {
            self._forward_declare_imported_ability(stmt);
        }
    }
}

"""Register a single imported archetype: create struct type and define field layout."""
impl NaIRGenPass._register_imported_archetype(arch: uni.Archetype) -> None {
    aname = arch.name.value if arch.name else None;
    if aname is None or aname in self.struct_types {
        return;
    }
    # Create identified struct type
    struct_type = self.llvm_module.context.get_identified_type(aname);
    self.struct_types[aname] = struct_type;
    # Define struct body with full field layout
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
                        if not self?._native_stdlib_modules {
                            self._native_stdlib_modules: set[str] = set();
                        }
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
                    if not self?._clib_paths {
                        self._clib_paths: list[str] = [];
                    }
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
