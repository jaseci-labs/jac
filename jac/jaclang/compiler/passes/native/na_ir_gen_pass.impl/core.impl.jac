"""Core initialization and transform logic for native IR generation."""
"""Initialize the native IR generation pass."""
impl NaIRGenPass.init(
    ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
) -> None {
    self.llvm_module = ir.Module(name="jac_native", context=ir.Context());
    self.builder: (ir.IRBuilder | None) = None;
    self.func_symtab: dict[(str, ir.Function)] = {};
    self.local_vars: dict[(str, ir.AllocaInstr)] = {};
    self.has_native_code = False;
    self.type_map: dict[(str, ir.Type)] = {
        "int": ir.IntType(64),
        "float": ir.DoubleType(),
        "bool": ir.IntType(1),
        "str": ir.IntType(8).as_pointer(),
        # Fixed-width C-compatible integer types
        "i8": ir.IntType(8),
        "u8": ir.IntType(8),
        "i16": ir.IntType(16),
        "u16": ir.IntType(16),
        "i32": ir.IntType(32),
        "u32": ir.IntType(32),
        "i64": ir.IntType(64),
        "u64": ir.IntType(64),
        # Fixed-width C-compatible float types
        "f32": ir.FloatType(),
        "f64": ir.DoubleType(),
        # C void pointer (opaque handle)
        "c_void": ir.IntType(8).as_pointer()
    };
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
    self.class_hierarchy: dict[(str, str)] = {};  # child → parent
    self.has_vtable: dict[(str, bool)] = {};
    self.vtable_layouts: dict[(str, list[str])] = {};
    self.vtable_method_indices: dict[(str, dict)] = {};
    self.vtable_globals: dict[(str, ir.GlobalVariable)] = {};
    # Tuple support (Phase 9)
    self.tuple_types: dict[(str, object)] = {};  # type_key → LiteralStructType
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
    super.init(ir_in=ir_in, prog=prog, cancel_token=cancel_token);
}

# ─── Main Pass Logic ─────────────────────────────────────────
"""Forward-declare, codegen native abilities/entries, and store the LLVM module."""
impl NaIRGenPass.transform(ir_in: uni.Module) -> uni.Module {
    # Process C library imports: import from "libname" { def ...; }
    self._process_clib_imports(self.ir_in);
    # Phase 0: Forward declarations (enums, archetypes, free functions, globals)
    self._register_enums(self.ir_in);
    self._register_globals(self.ir_in);
    self._register_archetypes(self.ir_in);
    # Phase 1: Codegen native abilities and entry blocks
    for stmt in self.ir_in.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                if (
                    isinstance(inner, uni.Ability)
                    and isinstance(inner, uni.ContextAwareNode)
                    and inner.code_context == CodeContext.NATIVE
                    and inner.signature is not None
                    and isinstance(inner.signature, uni.FuncSignature)
                ) {
                    self._codegen_ability(inner);
                } elif (
                    isinstance(inner, uni.ModuleCode)
                    and isinstance(inner, uni.ContextAwareNode)
                    and inner.code_context == CodeContext.NATIVE
                ) {
                    self._codegen_entry(inner);
                }
            }
        } elif isinstance(stmt, uni.Ability) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
                and stmt.signature is not None
                and isinstance(stmt.signature, uni.FuncSignature)
            ) {
                self._codegen_ability(stmt);
            }
        } elif isinstance(stmt, uni.ModuleCode) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                self._codegen_entry(stmt);
            }
        }
    }
    # Store LLVM module on AST
    if self.has_native_code {
        self.ir_in.gen.llvm_ir = self.llvm_module;
    }
    return self.ir_in;
}

# ─── C Library Import Processing ──────────────────────────────
"""Process import from "libname" { def ...; } statements.

Extracts library paths for loading and forward-declares
extern symbols from the clib declarations.
"""
impl NaIRGenPass._process_clib_imports(module: uni.Module) -> None {
    # Collect imports from top-level and inside na {} blocks
    imports: list = [];
    for stmt in module.body {
        if isinstance(stmt, uni.Import) {
            imports.append(stmt);
        } elif isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                if isinstance(inner, uni.Import) {
                    imports.append(inner);
                }
            }
        }
    }
    for stmt in imports {
        if not stmt.clib_decls {
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
                    self.log_error(
                        f"C library import declaration '{fn_name}' "
                        "must not have a body"
                    );
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
    _pn = __import__(
        "jaclang.compiler.passes.native.primitives_native",
        fromlist=["NativeListEmitter"]
    );
    self._native_emitters = {
        "int": _pn.NativeIntEmitter(),
        "float": _pn.NativeFloatEmitter(),
        "complex": _pn.NativeComplexEmitter(),
        "str": _pn.NativeStrEmitter(),
        "bytes": _pn.NativeBytesEmitter(),
        "list": _pn.NativeListEmitter(),
        "dict": _pn.NativeDictEmitter(),
        "set": _pn.NativeSetEmitter(),
        "frozenset": _pn.NativeFrozensetEmitter(),
        "tuple": _pn.NativeTupleEmitter(),
        "range": _pn.NativeRangeEmitter()
    };
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
