"""Virtual table (vtable) support for inheritance with C3 MRO."""
"""Build vtable layout for a class (merge from all MRO ancestors + own methods)."""
impl NaIRGenPass._build_vtable(arch_name: str) -> None {
    layout: list[str] = [];
    seen_methods: set[str] = set();
    # Merge method slots from all ancestors in MRO order
    mro = self._mro_of(arch_name);
    for ancestor_name in mro[1:] {
        ancestor_layout = self.vtable_layouts.get(ancestor_name, []);
        for method_name in ancestor_layout {
            if method_name not in seen_methods {
                layout.append(method_name);
                seen_methods.add(method_name);
            }
        }
    }
    # Add own methods (those forward-declared with this class name)
    prefix = f"{arch_name}.";
    for full_name in self.method_funcs {
        if full_name.startswith(prefix) {
            method_name = full_name[len(prefix):];
            if method_name not in seen_methods {
                layout.append(method_name);
                seen_methods.add(method_name);
            }
        }
    }
    self.vtable_layouts[arch_name] = layout;
    self.vtable_method_indices[arch_name] = {};
    for (i, name) in enumerate(layout) {
        self.vtable_method_indices[arch_name][name] = i;
    }
}

"""Emit a vtable global constant for a class."""
impl NaIRGenPass._emit_vtable_global(arch_name: str) -> None {
    layout = self.vtable_layouts.get(arch_name);
    # An empty method layout (a vtable-flagged class with no methods anywhere in
    # its MRO -- a bare base/leaf in a hierarchy) still emits a vtable: the
    # reserved `__name__` header slot must exist so the instance's field-0 slot
    # is written at construction and `self.__class__.__name__` has a valid slot
    # to read (issue #6930 A2). Only a missing layout (never built) is skipped.
    if layout is None {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    # Physical slot 0 is the class `__name__` string (issue #6930 A2); method
    # slots follow at VTABLE_HEADER_SLOTS. `self.__class__.__name__` reads this
    # slot off the instance's vtable, recovering the runtime (subclass) name.
    vtable_type = ir.ArrayType(i8_ptr, len(layout) + VTABLE_HEADER_SLOTS);
    entries: list[ir.Constant] = [self._emit_class_name_const(arch_name)];
    mro = self._mro_of(arch_name);
    for method_name in layout {
        # Resolve: walk MRO to find first implementation
        func = None;
        for check_name in mro {
            full_name = f"{check_name}.{method_name}";
            if full_name in self.method_funcs {
                func = self.method_funcs[full_name];
                break;
            }
        }
        if func is not None {
            entries.append(func.bitcast(i8_ptr));
        } else {
            entries.append(ir.Constant(i8_ptr, None));
        }
    }
    vtable_init = ir.Constant(vtable_type, entries);
    vtable_global = ir.GlobalVariable(
        self.llvm_module, vtable_type, name=f"{arch_name}.__vtable"
    );
    vtable_global.global_constant = True;
    vtable_global.linkage = "private";
    vtable_global.initializer = vtable_init;
    self.vtable_globals[arch_name] = vtable_global;
}

"""Generate a virtual method call via vtable lookup.
Devirtualizes to direct call when the method is never overridden by any subclass."""
impl NaIRGenPass._codegen_virtual_call(
    obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
) -> (ir.Value | None) {
    indices = self.vtable_method_indices.get(obj_type_name);
    if indices is None or method_name not in indices {
        return None;
    }
    # Find the resolved function (walk MRO)
    func = None;
    mro = self._mro_of(obj_type_name);
    for check_name in mro {
        full_name = f"{check_name}.{method_name}";
        if full_name in self.method_funcs {
            func = self.method_funcs[full_name];
            break;
        }
    }
    if func is None {
        return None;
    }
    fn_type = func.function_type;
    # Coerce args to expected types
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(fn_type.args) {
            coerced.append(self._coerce_type(arg, fn_type.args[i]));
        } else {
            coerced.append(arg);
        }
    }
    # Devirtualization: if this method is never overridden, use direct call
    non_overridden = self._non_overridden_methods.get(obj_type_name);
    if non_overridden is not None and method_name in non_overridden {
        _dv_res = self.builder.call(func, coerced, name=f"call.{method_name}");
        # callee borrows args (arg 0 is self) — release owned temporaries we passed
        self._release_owned_args(coerced, op="mcall_arg");
        return _dv_res;
    }
    # Full vtable dispatch for overridden methods. The logical method index is
    # method-only; the physical slot is offset by the reserved header (the class
    # `__name__` pointer occupies physical slot 0 -- issue #6930 A2).
    method_idx = indices[method_name] + VTABLE_HEADER_SLOTS;
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    # Load vtable pointer from field 0
    vtable_ptr_ptr = self.builder.gep(
        obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="vtable.ptr.ptr"
    );
    vtable_ptr = self.builder.load(vtable_ptr_ptr, name="vtable.ptr");
    # GEP to method index
    method_slot = self.builder.gep(
        vtable_ptr, [ir.Constant(i32, method_idx)], name=f"vt.{method_name}"
    );
    method_i8 = self.builder.load(method_slot, name=f"fn.{method_name}.raw");
    # Bitcast to expected function type and call
    typed_fn = self.builder.bitcast(
        method_i8, fn_type.as_pointer(), name=f"fn.{method_name}"
    );
    _vt_res = self.builder.call(typed_fn, coerced, name=f"vcall.{method_name}");
    # callee borrows args (arg 0 is self) — release owned temporaries we passed
    self._release_owned_args(coerced, op="vcall_arg");
    return _vt_res;
}

"""Emit (and cache) the per-class `__name__` string constant for `arch_name`.

Returns a constant `i8*` into a private RC-headed global, byte-identical in
shape to `_make_global_string` so it is a valid native `str` value. The
constant form (vs. `_make_global_string`, which needs an active builder) lets
it sit directly in the vtable global's initializer (issue #6930 A2).
"""
impl NaIRGenPass._emit_class_name_const(arch_name: str) -> ir.Value {
    cached = self._class_name_consts.get(arch_name);
    if cached is not None {
        return cached;
    }
    str_bytes = bytearray((arch_name + "\0").encode("utf8"));
    i64 = ir.IntType(64);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    arr_type = ir.ArrayType(i8, len(str_bytes));
    # { i64 RC_SENTINEL, i64 dtor(=0), [N x i8] data } -- ptr-16 is the sentinel
    # so retain/release skip it (matches _make_global_string).
    struct_type = ir.LiteralStructType([i64, i64, arr_type]);
    struct_val = ir.Constant(
        struct_type,
        [
            ir.Constant(i64, 0x7FFFFFFFFFFFFFFF),
            ir.Constant(i64, 0),
            ir.Constant(arr_type, str_bytes)
        ]
    );
    global_str = ir.GlobalVariable(
        self.llvm_module, struct_type, name=f".clsname.{self._str_count}"
    );
    self._str_count = self._str_count + 1;
    global_str.linkage = "private";
    global_str.global_constant = True;
    global_str.initializer = struct_val;
    # Constant GEP to the data field (offset +16) -> i8*, usable in the vtable
    # initializer and as a plain native `str` value.
    ptr = global_str.gep(
        [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)]
    );
    self._class_name_consts[arch_name] = ptr;
    return ptr;
}

"""Lower `self.__class__.__name__` / `type(self).__name__` to the class name.

Returns None when `nd` is not one of those two shapes (the caller then keeps
walking its other attribute/index forms). When the receiver's static type has a
vtable it may be a subclass at runtime, so the name is loaded from the
instance's vtable header slot (polymorphic); a vtable-less class is its own
runtime type, so the name lowers to a constant load (issue #6930 A2).
"""
impl NaIRGenPass._codegen_class_name(nd: uni.AtomTrailer) -> (ir.Value | None) {
    if not (nd.is_attr and self._get_name(nd.right) == "__name__") {
        return None;
    }
    inner = nd.target;
    receiver: (uni.UniNode | None) = None;
    # `self.__class__.__name__`: target is `<recv>.__class__`.
    if isinstance(inner, uni.AtomTrailer)
    and inner.is_attr
    and self._get_name(inner.right) == "__class__" {
        receiver = inner.target;
    } elif isinstance(inner, uni.FuncCall)
    and self._get_name(inner.target) == "type"
    and inner.params
    and len(inner.params) == 1 {
        # `type(<recv>).__name__`.
        receiver = inner.params[0];
    }
    if receiver is None {
        return None;
    }
    arch_name = self._struct_name_of(receiver);
    if arch_name is None {
        return None;
    }
    # No vtable -> the static type is the exact runtime type: constant load.
    if not self._arch_has_vtable(arch_name) {
        return self._emit_class_name_const(arch_name);
    }
    # Vtable present -> read the runtime name from the instance's vtable header
    # slot 0, so an inherited method reports the concrete subclass name.
    obj_val = self._codegen_expr(receiver);
    if obj_val is None {
        return None;
    }
    i32 = ir.IntType(32);
    vtable_ptr_ptr = self.builder.gep(
        obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="clsname.vt.ptr.ptr"
    );
    vtable_ptr = self.builder.load(vtable_ptr_ptr, name="clsname.vt.ptr");
    name_slot = self.builder.gep(
        vtable_ptr, [ir.Constant(i32, 0)], name="clsname.slot"
    );
    return self.builder.load(name_slot, name="clsname");
}

"""Generate wrapper functions for inherited methods so they can be called by name."""
impl NaIRGenPass._generate_inherited_method_wrappers -> None {
    # For each class with parents, generate wrappers for inherited methods
    for child_name in self.arch_ast_map {
        mro = self._mro_of(child_name);
        child_struct = self.struct_types.get(child_name);
        if child_struct is None or len(mro) < 2 {
            continue;
        }
        # Collect all methods from ancestors via MRO
        seen_methods: set[str] = set();
        for ancestor_name in mro[1:] {
            ancestor_layout = self.vtable_layouts.get(ancestor_name, []);
            for method_name in ancestor_layout {
                if method_name in seen_methods {
                    continue;
                }
                seen_methods.add(method_name);
                child_full = f"{child_name}.{method_name}";
                # Skip if child already has its own implementation
                if child_full in self.method_funcs {
                    continue;
                }
                # Find the actual implementation by walking MRO
                impl_func = None;
                impl_class: (str | None) = None;
                for mro_class in mro[1:] {
                    parent_full = f"{mro_class}.{method_name}";
                    if parent_full in self.method_funcs {
                        impl_func = self.method_funcs[parent_full];
                        impl_class = mro_class;
                        break;
                    }
                }
                if impl_func is None {
                    continue;
                }
                # Create wrapper function with child's struct type as self parameter
                orig_fn_type = impl_func.function_type;
                # Replace first param (self) with child's struct pointer
                new_param_types: list[ir.Type] = [child_struct.as_pointer()];
                for i in range(1, len(orig_fn_type.args)) {
                    new_param_types.append(orig_fn_type.args[i]);
                }
                wrapper_fn_type = ir.FunctionType(
                    orig_fn_type.return_type, new_param_types
                );
                wrapper_fn = ir.Function(
                    self.llvm_module, wrapper_fn_type, name=child_full
                );
                # Copy parameter names
                wrapper_fn.args[0].name = "self";
                for i in range(1, len(impl_func.args)) {
                    wrapper_fn.args[i].name = impl_func.args[i].name;
                }
                # Generate wrapper body
                entry_block = wrapper_fn.append_basic_block(name="entry");
                builder = ir.IRBuilder(entry_block);
                # For primary ancestors, bitcast works (prefix compatible)
                # For non-primary, bitcast also works at wrapper level since we
                # re-compile non-primary methods with the child struct in Pass 5.
                # Here we only generate wrappers for methods from primary ancestors.
                impl_struct = self.struct_types.get(impl_class);
                if impl_struct is None {
                    args: list[ir.Value] = list(wrapper_fn.args);
                } else {
                    parent_self = builder.bitcast(
                        wrapper_fn.args[0], impl_struct.as_pointer(), name="parent.self"
                    );
                    args: list[ir.Value] = [parent_self];
                    for i in range(1, len(wrapper_fn.args)) {
                        args.append(wrapper_fn.args[i]);
                    }
                }
                # Call the implementation
                result = builder.call(impl_func, args, name=f"inherited.{method_name}");
                # Return the result
                if isinstance(orig_fn_type.return_type, ir.VoidType) {
                    builder.ret_void();
                } else {
                    builder.ret(result);
                }
                # Register the wrapper
                self.method_funcs[child_full] = wrapper_fn;
                self.func_symtab[child_full] = wrapper_fn;
            }
        }
    }
}
# ─── Phase 6: Type Inference Helpers ──────────────────────────
