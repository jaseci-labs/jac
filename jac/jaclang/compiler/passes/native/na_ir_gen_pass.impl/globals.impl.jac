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
            if assign.type_tag is not None {
                # Annotated global: lower the target's checker-stamped type.
                _g_t0 = assign.target[0]
                    if isinstance(assign.target, (list, tuple))
                    else assign.target;
                var_type = self._resolve_jac_type(_g_t0);
            } elif assign.value is not None {
                # Infer type from initializer (e.g., glob game = Game())
                inferred = self._infer_global_init_type(assign.value);
                if inferred is not None {
                    var_type = inferred;
                }
            }
            # Create LLVM global variable
            try {
                global_var = ir.GlobalVariable(
                    self.llvm_module, var_type, name=var_name
                );
            } except Exception as _dup_err {
                # DuplicatedNameError: var_name already declared (e.g. from a
                # transitive import). Report as a symbol collision and skip.
                _cur_path = self.ir_in.loc.mod_path
                    if self.ir_in?.loc
                    else "(current module)";
                _origin = self._global_origins.get(var_name, "(imported module)");
                self.emit(
                    E5026,
                    symbol=var_name,
                    existing_module=_origin,
                    new_module=_cur_path
                );
                continue;
            }
            # Only explicitly :priv globals get internal linkage.
            # Default (no access modifier) is public in Jac, so they must
            # keep external linkage to be shared across modules.
            _is_priv = nd.access and nd.access.tag.name == Tok.KW_PRIV;
            if _is_priv {
                global_var.linkage = "internal";
            } else {
                global_var.linkage = "";
            }
            # Record `:pub` globals as C-ABI shared-library exports, consumed by
            # `jac nacompile --shared` (a C host reads them via dlsym).
            _is_pub = nd.access and nd.access.tag.name == Tok.KW_PUB;
            if _is_pub and self.ir_in?.gen and var_name.isidentifier() {
                if var_name not in self.ir_in.gen._exported_symbols {
                    self.ir_in.gen._exported_symbols.append(var_name);
                }
            }
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
            # Record origin for dup-error diagnostics
            self._global_origins[var_name] = self.ir_in.loc.mod_path
                if self.ir_in?.loc
                else "(current module)";
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

"""Infer the LLVM type of an un-annotated global from its initializer.

Primary path: consume the initializer Expr's `.type` (set by TypeCheckPass)
via _lower_type, the same seam annotated globals use. Falls back to
initializer-shape inference for nodes the checker did not type (e.g. globals
in imported .na.jac modules, until those modules are themselves type-checked).
Returns None when nothing resolves.
"""
impl NaIRGenPass._infer_global_init_type(value_node: uni.UniNode) -> (ir.Type | None) {
    # Unified path: lower the central checker's resolved type.
    if isinstance(value_node, uni.Expr) and value_node?.type is not None {
        lowered = self._lower_type(value_node.type);
        if lowered is not None {
            return lowered;
        }
    }
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
        return ir.Constant(target_type, nd.lit_value);
    }
    if isinstance(nd, uni.Float) {
        return ir.Constant(target_type, nd.lit_value);
    }
    if isinstance(nd, uni.Bool) {
        return ir.Constant(target_type, 1 if nd.lit_value else 0);
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
