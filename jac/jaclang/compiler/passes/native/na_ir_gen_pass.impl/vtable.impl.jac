"""Virtual table (vtable) support for inheritance with C3 MRO."""
"""Compute C3 linearization (MRO) for a class."""
impl NaIRGenPass._compute_c3_mro(class_name: str) -> list[str] {
    # Base case: no parents
    parents = self.class_parents.get(class_name);
    if parents is None or not parents {
        return [class_name];
    }
    # Compute MRO for each parent first (recursive, with memoization)
    parent_mros: list[list[str]] = [];
    for p in parents {
        if p not in self.mro_order {
            self.mro_order[p] = self._compute_c3_mro(p);
        }
        parent_mros.append(list(self.mro_order[p]));
    }
    # Add the parents list itself as a constraint
    parent_mros.append(list(parents));
    # C3 merge
    result: list[str] = [class_name];
    while True {
        # Check if all lists are empty
        any_remaining = False;
        for mro_list in parent_mros {
            if len(mro_list) > 0 {
                any_remaining = True;
                break;
            }
        }
        if not any_remaining {
            break;
        }
        # Find a candidate: head of some list not in tail of any other
        candidate: (str | None) = None;
        for mro_list in parent_mros {
            if len(mro_list) == 0 {
                continue;
            }
            head = mro_list[0];
            # Check if head appears in tail of any non-empty list
            in_tail = False;
            for other_list in parent_mros {
                if len(other_list) > 1 and head in other_list[1:] {
                    in_tail = True;
                    break;
                }
            }
            if not in_tail {
                candidate = head;
                break;
            }
        }
        if candidate is None {
            self.log_error(
                f"Cannot compute C3 MRO for {class_name}: inconsistent hierarchy"
            );
            return result;
        }
        result.append(candidate);
        # Remove candidate from heads of all lists
        new_parent_mros: list[list[str]] = [];
        for mro_list in parent_mros {
            if len(mro_list) > 0 and mro_list[0] == candidate {
                mro_list.pop(0);
            }
            new_parent_mros.append(mro_list);
        }
        parent_mros = new_parent_mros;
    }
    return result;
}

"""Check if ancestor is reachable via primary parent chain from child."""
impl NaIRGenPass._is_primary_ancestor(child_name: str, ancestor_name: str) -> bool {
    current = child_name;
    while current is not None {
        parents = self.class_parents.get(current);
        if parents is None or not parents {
            return False;
        }
        primary = parents[0];
        if primary == ancestor_name {
            return True;
        }
        current = primary;
    }
    return False;
}

"""Build vtable layout for a class (merge from all MRO ancestors + own methods)."""
impl NaIRGenPass._build_vtable(arch_name: str) -> None {
    layout: list[str] = [];
    seen_methods: set[str] = set();
    # Merge method slots from all ancestors in MRO order
    mro = self.mro_order.get(arch_name, [arch_name]);
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
    if layout is None or not layout {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    vtable_type = ir.ArrayType(i8_ptr, len(layout));
    entries: list[ir.Constant] = [];
    mro = self.mro_order.get(arch_name, [arch_name]);
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
    # Find function type to cast to (walk MRO)
    func = None;
    mro = self.mro_order.get(obj_type_name, [obj_type_name]);
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
    # For each class with parents, generate wrappers for inherited methods
    for (child_name, mro) in self.mro_order.items() {
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
                        wrapper_fn.args[0],
                        impl_struct.as_pointer(),
                        name="parent.self"
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
