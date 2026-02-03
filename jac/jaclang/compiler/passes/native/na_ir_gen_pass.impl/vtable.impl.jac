"""Virtual table (vtable) support for inheritance."""
"""Build vtable layout for a class (parent layout + own methods)."""
impl NaIRGenPass._build_vtable(arch_name: str) -> None {
    parent_name = self.class_hierarchy.get(arch_name);
    layout: list[str] = [];
    # Start with parent's layout
    if parent_name is not None and parent_name in self.vtable_layouts {
        layout = list(self.vtable_layouts[parent_name]);
    }
    # Find own methods (those forward-declared with this class name)
    prefix = f"{arch_name}.";
    for full_name in self.method_funcs {
        if full_name.startswith(prefix) {
            method_name = full_name[len(prefix):];
            if method_name not in layout {
                layout.append(method_name);
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
    if layout is None or not layout {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    vtable_type = ir.ArrayType(i8_ptr, len(layout));
    entries: list[ir.Constant] = [];
    for method_name in layout {
        # Resolve: check this class then walk up hierarchy
        func = None;
        check_name = arch_name;
        while check_name is not None {
            full_name = f"{check_name}.{method_name}";
            if full_name in self.method_funcs {
                func = self.method_funcs[full_name];
                break;
            }
            check_name = self.class_hierarchy.get(check_name);
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

"""Generate a virtual method call via vtable lookup."""
impl NaIRGenPass._codegen_virtual_call(
    obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
) -> (ir.Value | None) {
    indices = self.vtable_method_indices.get(obj_type_name);
    if indices is None or method_name not in indices {
        return None;
    }
    method_idx = indices[method_name];
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
    # Find function type to cast to (walk hierarchy)
    func = None;
    check_name = obj_type_name;
    while check_name is not None {
        full_name = f"{check_name}.{method_name}";
        if full_name in self.method_funcs {
            func = self.method_funcs[full_name];
            break;
        }
        check_name = self.class_hierarchy.get(check_name);
    }
    if func is None {
        return None;
    }
    # Bitcast to expected function type and call
    fn_type = func.function_type;
    typed_fn = self.builder.bitcast(
        method_i8, fn_type.as_pointer(), name=f"fn.{method_name}"
    );
    # Coerce args to expected types
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(fn_type.args) {
            coerced.append(self._coerce_type(arg, fn_type.args[i]));
        } else {
            coerced.append(arg);
        }
    }
    return self.builder.call(typed_fn, coerced, name=f"vcall.{method_name}");
}

"""Generate wrapper functions for inherited methods so they can be called by name."""
impl NaIRGenPass._generate_inherited_method_wrappers -> None {
    # For each child class in the hierarchy
    for (child_name, parent_name) in self.class_hierarchy.items() {
        # Get parent's vtable layout to know which methods exist
        parent_layout = self.vtable_layouts.get(parent_name);
        if parent_layout is None {
            continue;
        }
        child_struct = self.struct_types.get(child_name);
        if child_struct is None {
            continue;
        }
        # For each method in parent's layout
        for method_name in parent_layout {
            child_full = f"{child_name}.{method_name}";
            # Skip if child already has its own implementation
            if child_full in self.method_funcs {
                continue;
            }
            # Find the actual implementation by walking up hierarchy
            impl_func = None;
            check_name = parent_name;
            while check_name is not None {
                parent_full = f"{check_name}.{method_name}";
                if parent_full in self.method_funcs {
                    impl_func = self.method_funcs[parent_full];
                    break;
                }
                check_name = self.class_hierarchy.get(check_name);
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
            # Generate wrapper body that calls the parent implementation
            entry_block = wrapper_fn.append_basic_block(name="entry");
            builder = ir.IRBuilder(entry_block);
            # Bitcast self from child* to parent* (they're compatible due to inheritance)
            parent_struct = self.struct_types.get(parent_name);
            if parent_struct is None {
                # Fall back to direct call without cast
                args: list[ir.Value] = list(wrapper_fn.args);
            } else {
                parent_self = builder.bitcast(
                    wrapper_fn.args[0], parent_struct.as_pointer(), name="parent.self"
                );
                args: list[ir.Value] = [parent_self];
                for i in range(1, len(wrapper_fn.args)) {
                    args.append(wrapper_fn.args[i]);
                }
            }
            # Call the parent implementation
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
# ─── Phase 6: Type Inference Helpers ──────────────────────────
