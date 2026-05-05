"""Global variable and enum registration for native compilation."""
"""Walk the module and register all native global variables."""
impl NaIRGenPass._register_globals(module: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.GlobalVars) {
            self._codegen_global_vars(stmt);
        }
    }
}

"""Codegen global variable declarations."""
impl NaIRGenPass._codegen_global_vars(nd: uni.GlobalVars) -> None {
    for assign in nd.assignments {
        targets = assign.target
            if isinstance(assign.target, (list, tuple))
            else [(assign.target)];
        for target in targets {
            var_name = self._get_name(target);
            if var_name is None {
                continue;
            }
            # Determine the LLVM type
            var_type: ir.Type = ir.IntType(64);  # Default to i64
            if assign.type_tag and assign.type_tag.tag {
                var_type = self._resolve_jac_type(assign.type_tag.tag);
                # Track type annotation node for chained subscript+field access
                # e.g. TABLE[i].field chains need the list[T] node to bitcast
                self.var_type_node[var_name] = assign.type_tag.tag;
            } elif assign.value is not None {
                # Infer type from initializer (e.g., glob game = Game())
                inferred = self._infer_global_init_type(assign.value);
                if inferred is not None {
                    var_type = inferred;
                }
            }
            # Create LLVM global variable
            global_var = ir.GlobalVariable(self.llvm_module, var_type, name=var_name);
            global_var.linkage = "";
            # Try compile-time constant initialization for simple values
            const_init = self._codegen_const_expr(assign.value, var_type)
                if assign.value is not None
                else None;
            if const_init is not None {
                global_var.initializer = const_init;
            } else {
                global_var.initializer = ir.Constant(var_type, None);
            }
            self.global_vars[var_name] = global_var;
            self.global_var_types[var_name] = var_type;
            # Track list element types for global lists
            if isinstance(var_type, ir.PointerType) {
                for (ename, ltype) in self.list_types.items() {
                    if var_type == ltype.as_pointer() {
                        self.var_list_elem_type[var_name] = ename;
                        break;
                    }
                }
            }
            # Track dict types for global dicts
            if isinstance(var_type, ir.PointerType) {
                for (dict_key, dtype) in self.dict_types.items() {
                    if var_type == dtype.as_pointer() {
                        self.var_dict_type[var_name] = dict_key;
                        break;
                    }
                }
            }
            self.has_native_code = True;
            # Save assignment node for runtime initialization
            # (skip if already initialized with a compile-time constant)
            if assign.value is not None and const_init is None {
                if not self?._global_init_nodes {
                    self._global_init_nodes: list = [];
                }
                self._global_init_nodes.append((var_name, assign.value, var_type));
            }
        }
    }
}

"""Infer the LLVM type from an initializer AST node (e.g., Game() → Game*)."""
impl NaIRGenPass._infer_global_init_type(value_node: uni.UniNode) -> (ir.Type | None) {
    # FuncCall whose target is a known archetype name → constructor
    if isinstance(value_node, uni.FuncCall) {
        call_name = self._get_name(value_node.target);
        if call_name is not None and call_name in self.struct_types {
            return self.struct_types[call_name].as_pointer();
        }
    }
    # AtomTrailer that wraps a function call (e.g., Module.Type())
    if isinstance(value_node, uni.AtomTrailer) {
        target_name = self._get_name(value_node.target);
        if target_name is not None and target_name in self.struct_types {
            return self.struct_types[target_name].as_pointer();
        }
        # sys.argv → list[str] (list of pointer-sized elements)
        right_name = self._get_name(value_node.right);
        if target_name == "sys" and right_name == "argv" {
            i8p = ir.IntType(8).as_pointer();
            self._emit_list_helpers("ptr", i8p);
            list_type = self.list_types.get("ptr");
            if list_type is not None {
                return list_type.as_pointer();
            }
        }
    }
    return None;
}

"""Evaluate a constant expression for global variable initialization."""
impl NaIRGenPass._codegen_const_expr(
    nd: uni.UniNode, target_type: ir.Type
) -> (ir.Constant | None) {
    if isinstance(nd, uni.Int) {
        # Use base=0 to auto-detect prefix: 0x=hex, 0o=oct, 0b=bin, else decimal
        return ir.Constant(target_type, int(nd.value, 0));
    }
    if isinstance(nd, uni.Float) {
        return ir.Constant(target_type, float(nd.value));
    }
    if isinstance(nd, uni.Bool) {
        val = 1 if nd.value.lower() in ("true", "1") else 0;
        return ir.Constant(target_type, val);
    }
    if isinstance(nd, uni.String) or isinstance(nd, uni.MultiString) {
        # String constants - create global string
        return None;  # Complex initialization handled at runtime
    }
    return None;
}

"""Walk the module and register all native enum types."""
impl NaIRGenPass._register_enums(module: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Enum) {
            self._codegen_enum(stmt);
        }
    }
}
