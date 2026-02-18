"""Archetype (object) codegen: structs, fields, methods, instantiation."""
"""Walk the module and register all native archetypes (obj definitions)."""
impl NaIRGenPass._register_archetypes(module: uni.Module) -> None {
    # Collect all archetype nodes, deduplicating forward declarations
    arch_map: dict[(str, uni.Archetype)] = {};
    for stmt in module.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                if isinstance(inner, uni.Archetype) {
                    aname = inner.name.value if inner.name else "unknown";
                    # Full definition overrides forward declaration
                    if aname not in arch_map or inner.body is not None {
                        arch_map[aname] = inner;
                    }
                }
            }
        } elif isinstance(stmt, uni.Archetype) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                aname = stmt.name.value if stmt.name else "unknown";
                if aname not in arch_map or stmt.body is not None {
                    arch_map[aname] = stmt;
                }
            }
        }
    }
    archetypes: list[uni.Archetype] = list(arch_map.values());
    # Pass 1: Create opaque identified struct types (handles forward refs)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        struct_type = self.llvm_module.context.get_identified_type(arch_name);
        self.struct_types[arch_name] = struct_type;
        self.has_native_code = True;
    }
    # Pass 1.5: Build class hierarchy
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.base_classes {
            for base_expr in arch.base_classes {
                parent_name = self._get_name(base_expr);
                if parent_name is not None and parent_name in self.struct_types {
                    self.class_hierarchy[arch_name] = parent_name;
                    break;
                }
            }
        }
    }
    # Determine which classes need vtables (any class in the hierarchy)
    parents_set: set[str] = set();
    for (child, parent) in self.class_hierarchy.items() {
        parents_set.add(parent);
        self.has_vtable[child] = True;
    }
    for parent in parents_set {
        self.has_vtable[parent] = True;
    }
    # Pass 2: Define struct bodies (parents before children)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch_name not in self.class_hierarchy {
            self._codegen_archetype(arch);
        }
    }
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch_name in self.class_hierarchy {
            self._codegen_archetype(arch);
        }
    }
    # Pass 3: Forward-declare all methods
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                    and isinstance(stmt.signature, uni.FuncSignature) {
                        self._forward_declare_method(arch_name, stmt);
                    }
                }
            }
        }
    }
    # Pass 3.5: Build vtable layouts (parents before children)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch_name in self.has_vtable and arch_name not in self.class_hierarchy {
            self._build_vtable(arch_name);
        }
    }
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch_name in self.has_vtable and arch_name in self.class_hierarchy {
            self._build_vtable(arch_name);
        }
    }
    # Pass 4: Emit vtable globals
    for arch_name in self.has_vtable {
        self._emit_vtable_global(arch_name);
    }
    # Pass 4.5: Forward-declare free functions (must happen before method bodies)
    self._forward_declare_functions(module);
    # Pass 5: Generate method bodies
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                    and isinstance(stmt.signature, uni.FuncSignature) {
                        self._codegen_method(arch_name, stmt);
                    }
                }
            }
        }
    }
    # Pass 6: Generate wrapper functions for inherited methods
    self._generate_inherited_method_wrappers();
}

"""Register a struct type — define its field layout from has declarations."""
impl NaIRGenPass._codegen_archetype(nd: uni.Archetype) -> None {
    arch_name = (nd).name.value if (nd).name else "unknown";
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    needs_vtable = arch_name in self.has_vtable;
    parent_name = self.class_hierarchy.get(arch_name);
    # Collect fields
    field_types: list[ir.Type] = [];
    field_index_map: dict[(str, int)] = {};
    field_type_map: dict[(str, ir.Type)] = {};
    field_default_map: dict[(str, object)] = {};
    # Add vtable pointer as field 0 if needed
    if needs_vtable {
        field_types.append(ir.IntType(8).as_pointer().as_pointer());
    }
    # Inherit parent fields (in order by index)
    if parent_name is not None and parent_name in self.struct_field_indices {
        parent_indices = self.struct_field_indices[parent_name];
        parent_types = self.struct_field_types[parent_name];
        parent_defaults = self.struct_field_defaults.get(parent_name, {});
        # Build reverse map: index → field name, then iterate in order
        idx_to_name: dict[(int, str)] = {};
        for (fname, pidx) in parent_indices.items() {
            idx_to_name[pidx] = fname;
        }
        sorted_idxs = sorted(idx_to_name.keys());
        for pidx in sorted_idxs {
            fname = idx_to_name[pidx];
            ftype = parent_types.get(fname, ir.IntType(64));
            field_types.append(ftype);
            field_index_map[fname] = pidx;
            field_type_map[fname] = ftype;
            if fname in parent_defaults {
                field_default_map[fname] = parent_defaults[fname];
            }
        }
    }
    # Add own fields from ArchHas nodes
    if (nd).body is not None {
        for stmt in (nd).body {
            if isinstance(stmt, uni.ArchHas) {
                for var in stmt.vars {
                    fname = var.name.value if var.name else "field";
                    ftype = ir.IntType(64);
                    if var.type_tag and var.type_tag.tag {
                        ftype = self._resolve_jac_type(var.type_tag.tag);
                        # Track Jac-level type AST for nested type resolution
                        if arch_name not in self.field_type_node {
                            self.field_type_node[arch_name] = {};
                        }
                        self.field_type_node[arch_name][fname] = var.type_tag.tag;
                    }
                    new_idx = len(field_types);
                    field_types.append(ftype);
                    field_index_map[fname] = new_idx;
                    field_type_map[fname] = ftype;
                    if var.value is not None {
                        field_default_map[fname] = var.value;
                    }
                }
            }
        }
    }
    # Define the struct body (always call set_body, even with empty field_types,
    # to make the struct type non-opaque so GEP operations work)
    struct_type.set_body(*field_types);
    self.struct_field_indices[arch_name] = field_index_map;
    self.struct_field_types[arch_name] = field_type_map;
    self.struct_field_defaults[arch_name] = field_default_map;
}

"""Forward-declare a method with self pointer as first parameter."""
impl NaIRGenPass._forward_declare_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    sig = method.signature;
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or sig is None {
        return;
    }
    # Build parameter types: self pointer + declared params
    param_types: list[ir.Type] = [struct_type.as_pointer()];
    for p in sig.get_parameters() {
        if p.type_tag and p.type_tag.tag {
            param_types.append(self._resolve_jac_type(p.type_tag.tag));
        } else {
            param_types.append(ir.IntType(64));
        }
    }
    # Return type
    ret_type = self._resolve_jac_type(sig.return_type);
    if isinstance(ret_type, ir.VoidType) {
        ;  # keep void
    }
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=full_name);
    # Name the parameters
    func.args[0].name = "self";
    for (i, p) in enumerate(sig.get_parameters()) {
        func.args[i + 1].name = p.name.value if p.name else f"arg{i}";
    }
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;
}

"""Generate LLVM IR for a method body."""
impl NaIRGenPass._codegen_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }
    # Create entry block
    block = func.append_basic_block(name="entry");
    saved_builder = self.builder;
    saved_locals = self.local_vars;
    saved_type_map = dict(self.type_var_map);
    saved_type_node = dict(self.var_type_node);
    saved_list_elem = dict(self.var_list_elem_type);
    saved_dict_type = dict(self.var_dict_type);
    saved_set_elem = dict(self.var_set_elem_type);
    self.builder = ir.IRBuilder(block);
    self.local_vars = {};
    self.var_type_node = {};
    self.var_list_elem_type = {};
    self.var_dict_type = {};
    self.var_set_elem_type = {};
    # Store self pointer
    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    self.type_var_map["self"] = arch_name;
    # Store other parameters
    sig = method.signature;
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        arg_val = func.args[i + 1];
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;
        # Track type info for struct pointer parameters
        if isinstance(arg_val.type, ir.PointerType) {
            for (sname, stype) in self.struct_types.items() {
                if arg_val.type == stype.as_pointer() {
                    self.type_var_map[param_name] = sname;
                    break;
                }
            }
        }
        # Track Jac type annotation for parameters (enables nested list resolution)
        if p.type_tag and p.type_tag.tag {
            self.var_type_node[param_name] = p.type_tag.tag;
            # Also track list elem type from annotation
            for (ename, ltype) in self.list_types.items() {
                if arg_val.type == ltype.as_pointer() {
                    self.var_list_elem_type[param_name] = ename;
                    break;
                }
            }
            # Handle union types T | None for struct tracking
            tag_name = self._get_name(p.type_tag.tag);
            tag_node = p.type_tag.tag;
            if tag_name is None and isinstance(tag_node, uni.BinaryExpr) {
                op_val = getattr(tag_node.op, 'value', '');
                if op_val == "|" {
                    tag_name = self._get_name(tag_node.left);
                }
            }
            if tag_name is not None and tag_name in self.struct_types {
                self.type_var_map[param_name] = tag_name;
            }
        }
    }
    # Generate body
    if isinstance(method.body, (list, tuple)) {
        self._codegen_body(method.body);
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
        ret_type = func.return_value.type;
        if isinstance(ret_type, ir.VoidType) {
            self.builder.ret_void();
        } elif isinstance(ret_type, ir.PointerType) {
            self.builder.ret(ir.Constant(ret_type, None));
        } else {
            self.builder.ret(ir.Constant(ret_type, 0));
        }
    }
    method.gen.llvm_ir = func;
    # Restore saved state
    self.builder = saved_builder;
    self.local_vars = saved_locals;
    self.type_var_map = saved_type_map;
    self.var_type_node = saved_type_node;
    self.var_list_elem_type = saved_list_elem;
    self.var_dict_type = saved_dict_type;
    self.var_set_elem_type = saved_set_elem;
}

"""Generate object instantiation: allocate struct, init fields, call postinit."""
impl NaIRGenPass._codegen_instantiation(nd: uni.FuncCall) -> (ir.Value | None) {
    type_name = self._get_name(nd.target);
    if type_name is None or type_name not in self.struct_types {
        return None;
    }
    struct_type = self.struct_types[type_name];
    struct_ptr_type = struct_type.as_pointer();
    # Compute sizeof using GEP-from-null trick
    null_ptr = ir.Constant(struct_ptr_type, None);
    size_gep = self.builder.gep(
        null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
    );
    size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
    # Allocate via GC_malloc
    gc_malloc = self._get_or_declare_extern(
        "GC_malloc", ir.IntType(8).as_pointer(), [ir.IntType(64)]
    );
    raw_ptr = self.builder.call(gc_malloc, [size], name="raw.ptr");
    obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
    # Store vtable pointer if class has vtable
    if type_name in self.vtable_globals {
        vtable_global = self.vtable_globals[type_name];
        vtable_base = self.builder.gep(
            vtable_global,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.base"
        );
        vtable_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.slot"
        );
        self.builder.store(vtable_base, vtable_slot);
    }
    # Initialize fields from keyword arguments
    field_indices = self.struct_field_indices.get(type_name, {});
    field_types = self.struct_field_types.get(type_name, {});
    field_defaults = self.struct_field_defaults.get(type_name, {});
    # Track which fields were explicitly set
    set_fields: set[str] = set();
    params = nd.params or [];
    for param in params {
        if isinstance(param, uni.KWPair) {
            key_name = param.key.sym_name if param.key else None;
            if key_name is None or key_name not in field_indices {
                continue;
            }
            val = self._codegen_expr(param.value);
            if val is None {
                continue;
            }
            idx = field_indices[key_name];
            ftype = field_types[key_name];
            val = self._coerce_type(val, ftype);
            field_ptr = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"field.{key_name}"
            );
            self.builder.store(val, field_ptr);
            set_fields.add(key_name);
        }
    }
    # Initialize unset fields with defaults
    for (fname, default_expr) in field_defaults.items() {
        if fname not in set_fields {
            val = self._codegen_expr(default_expr);
            if val is not None {
                idx = field_indices[fname];
                ftype = field_types[fname];
                val = self._coerce_type(val, ftype);
                field_ptr = self.builder.gep(
                    obj_ptr,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                    name=f"default.{fname}"
                );
                self.builder.store(val, field_ptr);
                set_fields.add(fname);
            }
        }
    }
    # Zero-initialize any remaining unset fields
    for (fname, idx) in field_indices.items() {
        if fname not in set_fields {
            ftype = field_types[fname];
            if isinstance(ftype, ir.PointerType) {
                zero_val = ir.Constant(ftype, None);
            } else {
                zero_val = ir.Constant(ftype, 0);
            }
            field_ptr = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"zero.{fname}"
            );
            self.builder.store(zero_val, field_ptr);
        }
    }
    # Call postinit if it exists (Jac renames postinit → __post_init__)
    for pname in [f"{type_name}.__post_init__", f"{type_name}.postinit"] {
        if pname in self.method_funcs {
            postinit_fn = self.method_funcs[pname];
            self.builder.call(postinit_fn, [obj_ptr]);
            break;
        }
    }
    return obj_ptr;
}

"""Generate method call: obj.method(args).

Primitive type methods are dispatched through the emitter layer
(primitives_native.jac). If the emitter returns a result, it is used
directly; if it returns None, the inline codegen below handles it.
"""
impl NaIRGenPass._codegen_method_call(nd: uni.FuncCall) -> (ir.Value | None) {
    trailer = nd.target;
    if not isinstance(trailer, uni.AtomTrailer) or not trailer.is_attr {
        return None;
    }
    target_name = self._get_name(trailer.target);
    method_name = self._get_name(trailer.right);
    if method_name is None {
        return None;
    }
    # --- Primitive emitter dispatch (list, set, str methods) ---
    # Evaluate target and args, dispatch through emitter layer.
    # List methods (simple name target)
    if target_name is not None and target_name in self.var_list_elem_type {
        elem_type_name = self.var_list_elem_type[target_name];
        list_val = self._codegen_expr(trailer.target);
        if list_val is not None {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            result = self._dispatch_primitive_method(
                "list", method_name, list_val, arg_vals, elem_type_name
            );
            if result is not None {
                return result;
            }
        }
    }
    # Set methods (simple name target)
    if target_name is not None and target_name in self.var_set_elem_type {
        elem_type_name = self.var_set_elem_type[target_name];
        set_val = self._codegen_expr(trailer.target);
        if set_val is not None {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            result = self._dispatch_primitive_method(
                "set", method_name, set_val, arg_vals, elem_type_name
            );
            if result is not None {
                return result;
            }
        }
    }
    # String methods (on any target expression whose type is i8*)
    if method_name in (
        "strip",
        "split",
        "upper",
        "lower",
        "find",
        "startswith",
        "endswith"
    ) {
        str_val = self._codegen_expr(trailer.target);
        if str_val is not None and str_val.type == ir.IntType(8).as_pointer() {
            params = nd.params or [];
            arg_vals: list[ir.Value] = [];
            for param in params {
                v = self._codegen_expr(param);
                if v is not None {
                    arg_vals.append(v);
                }
            }
            result = self._dispatch_primitive_method(
                "str", method_name, str_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }
    # Determine type_name and obj_val (supports chained access)
    type_name: (str | None) = None;
    obj_val: (ir.Value | None) = None;
    if target_name is not None {
        type_name = self.type_var_map.get(target_name);
    }
    if type_name is None {
        # Complex expression target (chained access) — evaluate and infer
        obj_val = self._codegen_expr(trailer.target);
        if obj_val is not None {
            type_name = self._infer_type_name(obj_val);
            # Handle list methods on complex targets (e.g. g.items.append(x))
            if type_name is None {
                elem_type_name = self._infer_list_elem_type(obj_val);
                if elem_type_name is not None and method_name == "append" {
                    helpers = self.list_helpers.get(elem_type_name);
                    if helpers is not None {
                        params = nd.params or [];
                        if params {
                            val = self._codegen_expr(params[0]);
                            if val is not None {
                                elem_type = helpers["elem_type"];
                                val = self._coerce_type(val, elem_type);
                                self.builder.call(helpers["append"], [obj_val, val]);
                            }
                        }
                        return ir.Constant(ir.IntType(64), 0);
                    }
                }
            }
        }
    }
    if type_name is None {
        return None;
    }
    # Find method: check this class and walk up hierarchy
    func = None;
    check_name = type_name;
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
    # Get the object pointer (reuse if already computed in chained path)
    if obj_val is None {
        obj_val = self._codegen_expr(trailer.target);
    }
    if obj_val is None {
        return None;
    }
    # AttributeError: check for null pointer (None) before method call
    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.method.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
    }
    # Build args: [self_ptr, arg1, arg2, ...]
    args: list[ir.Value] = [obj_val];
    params = nd.params or [];
    for param in params {
        val = self._codegen_expr(param);
        if val is not None {
            args.append(val);
        }
    }
    # Virtual dispatch if type has vtable
    if type_name in self.has_vtable {
        result = self._codegen_virtual_call(obj_val, method_name, args, type_name);
        if result is not None {
            if isinstance(func.return_value.type, ir.VoidType) {
                return ir.Constant(ir.IntType(64), 0);
            }
            return result;
        }
    }
    # Direct call (for non-vtable types or fallback)
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(func.args) {
            coerced.append(self._coerce_type(arg, func.args[i].type));
        } else {
            coerced.append(arg);
        }
    }
    result = self.builder.call(func, coerced, name=f"call.{method_name}");
    # Return void calls as None
    if isinstance(func.return_value.type, ir.VoidType) {
        return ir.Constant(ir.IntType(64), 0);
    }
    return result;
}

"""Generate field access: GEP into struct + load (with AttributeError null check)."""
impl NaIRGenPass._codegen_field_access(
    obj_val: ir.Value, field_name: str, type_name: str
) -> (ir.Value | None) {
    field_indices = self.struct_field_indices.get(type_name);
    if field_indices is None or field_name not in field_indices {
        return None;
    }
    # AttributeError: check for null pointer (None) before accessing field
    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.field.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
    }
    idx = field_indices[field_name];
    field_ptr = self.builder.gep(
        obj_val,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
        name=f"field.{field_name}.ptr"
    );
    return self.builder.load(field_ptr, name=f"field.{field_name}");
}

"""Generate field assignment: GEP into struct + store."""
impl NaIRGenPass._codegen_field_assign(
    target: uni.AtomTrailer, value: ir.Value
) -> None {
    target_name = self._get_name(target.target);
    field_name = self._get_name(target.right);
    if field_name is None {
        return;
    }
    # Resolve the type: try simple name first, then infer from expression
    type_name: (str | None) = None;
    if target_name is not None {
        type_name = self.type_var_map.get(target_name);
    }
    obj_val = self._codegen_expr(target.target);
    if obj_val is None {
        return;
    }
    if type_name is None {
        type_name = self._infer_type_name(obj_val);
    }
    if type_name is None {
        return;
    }
    field_indices = self.struct_field_indices.get(type_name);
    field_types = self.struct_field_types.get(type_name);
    if field_indices is None or field_name not in field_indices {
        return;
    }
    idx = field_indices[field_name];
    ftype = field_types[field_name];
    value = self._coerce_type(value, ftype);
    field_ptr = self.builder.gep(
        obj_val,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
        name=f"field.{field_name}.ptr"
    );
    self.builder.store(value, field_ptr);
}
# ─── Phase 4: Lists ──────────────────────────────────────────
