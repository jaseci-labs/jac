"""Global variable and enum registration for native compilation."""
"""Walk the module and register all native global variables."""
impl NaIRGenPass._register_globals(module: uni.Module) -> None {
    for stmt in module.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                if isinstance(inner, uni.GlobalVars) {
                    self._codegen_global_vars(inner);
                }
            }
        } elif isinstance(stmt, uni.GlobalVars) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                self._codegen_global_vars(stmt);
            }
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
            }
            # Create LLVM global variable
            global_var = ir.GlobalVariable(self.llvm_module, var_type, name=var_name);
            global_var.linkage = "internal";
            # Initialize with null - complex values will be set at runtime in entry
            global_var.initializer = ir.Constant(var_type, None);
            self.global_vars[var_name] = global_var;
            self.global_var_types[var_name] = var_type;
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
            if assign.value is not None {
                if not self?._global_init_nodes {
                    self._global_init_nodes: list = [];
                }
                self._global_init_nodes.append((var_name, assign.value, var_type));
            }
        }
    }
}

"""Evaluate a constant expression for global variable initialization."""
impl NaIRGenPass._codegen_const_expr(
    nd: uni.UniNode, target_type: ir.Type
) -> (ir.Constant | None) {
    if isinstance(nd, uni.Int) {
        tok_name = nd?.name;
        if tok_name == Tok.HEX {
            return ir.Constant(target_type, int(nd.value, 16));
        } elif tok_name == Tok.OCT {
            return ir.Constant(target_type, int(nd.value, 8));
        } elif tok_name == Tok.BIN {
            return ir.Constant(target_type, int(nd.value, 2));
        } else {
            return ir.Constant(target_type, int(nd.value));
        }
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
    for stmt in module.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                if isinstance(inner, uni.Enum) {
                    self._codegen_enum(inner);
                }
            }
        } elif isinstance(stmt, uni.Enum) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                self._codegen_enum(stmt);
            }
        }
    }
}
