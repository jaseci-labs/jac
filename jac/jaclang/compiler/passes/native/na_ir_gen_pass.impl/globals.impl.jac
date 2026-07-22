impl NaIRGenPass._register_globals(module: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.GlobalVars) {
            self._codegen_global_vars(stmt);
        }
    }
}

impl NaIRGenPass._register_entry_globals(module: uni.Module) -> None {
    candidates: dict = {};
    dropped: set = set();
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if not isinstance(stmt, uni.ModuleCode) {
            continue;
        }
        for assign in stmt.get_all_sub_nodes(typ=uni.Assignment) {
            if assign.aug_op is not None {
                continue;
            }
            targets = assign.target
                if isinstance(assign.target, (list, tuple))
                else [(assign.target)];
            for target in targets {
                if (
                    not isinstance(target, uni.NameAtom)
                    or target.sym is None
                    or target.sym.storage != uni.SymbolStorage.MODULE_GLOBAL
                ) {
                    continue;
                }
                var_name = self._get_name(target);
                if (
                    var_name is None
                    or var_name in self.global_vars
                    or var_name in dropped
                ) {
                    continue;
                }
                var_type: (ir.Type | None) = None;
                if isinstance(target, uni.Expr) {
                    try {
                        var_type = self._lower_type(target.type);
                    } except Exception {
                        var_type = None;
                    }
                }
                if var_type is None and assign.value is not None {
                    var_type = self._infer_global_init_type(assign.value);
                }
                if var_type is None or isinstance(var_type, ir.VoidType) {
                    dropped.add(var_name);
                    candidates.pop(var_name, None);
                    continue;
                }
                prev = candidates.get(var_name);
                if prev is not None and prev != var_type {
                    dropped.add(var_name);
                    candidates.pop(var_name, None);
                    continue;
                }
                candidates[var_name] = var_type;
            }
        }
    }
    for (var_name, var_type) in candidates.items() {
        try {
            global_var = ir.GlobalVariable(self.llvm_module, var_type, name=var_name);
        } except Exception as _dup_err {
            continue;
        }
        global_var.linkage = "internal";
        global_var.initializer = ir.Constant(var_type, None);
        self.global_vars[var_name] = global_var;
        self.global_var_types[var_name] = var_type;
        self._global_origins[var_name] = module.loc.mod_path
            if module?.loc
            else "(current module)";
        self.has_native_code = True;
    }
}

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

            var_type: ir.Type = ir.IntType(64);
            if assign.type_tag is not None {
                var_type = self._resolve_jac_type(assign.type_tag);
            } elif assign.value is not None {
                inferred = self._infer_global_init_type(assign.value);
                if inferred is not None {
                    var_type = inferred;
                }
            }

            try {
                global_var = ir.GlobalVariable(
                    self.llvm_module, var_type, name=var_name
                );
            } except Exception as _dup_err {
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

            _is_priv = nd.access and nd.access.tag.name == Tok.KW_PRIV;
            if _is_priv {
                global_var.linkage = "internal";
            } else {
                global_var.linkage = "";
            }

            _is_pub = nd.access and nd.access.tag.name == Tok.KW_PUB;
            if _is_pub and self.ir_in?.gen and var_name.isidentifier() {
                if var_name not in self.ir_in.gen._exported_symbols {
                    self.ir_in.gen._exported_symbols.append(var_name);
                }
            }

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

            self._global_origins[var_name] = self.ir_in.loc.mod_path
                if self.ir_in?.loc
                else "(current module)";
            self.has_native_code = True;

            if assign.value is not None and const_init is None {
                if not self?._global_init_nodes {
                    self._global_init_nodes: list = [];
                }
                self._global_init_nodes.append((var_name, assign.value, var_type));
            }
        }
    }
}

impl NaIRGenPass._infer_global_init_type(value_node: uni.UniNode) -> (ir.Type | None) {
    if isinstance(value_node, uni.Expr) and value_node?.type is not None {
        lowered = self._lower_type(value_node.type);
        if lowered is not None {
            return lowered;
        }
    }

    if isinstance(value_node, uni.FuncCall) {
        call_name = self._get_name(value_node.target);
        if call_name is not None and call_name in self.struct_types {
            return self.struct_types[call_name].as_pointer();
        }
    }

    if isinstance(value_node, uni.AtomTrailer) {
        target_name = self._get_name(value_node.target);
        if target_name is not None and target_name in self.struct_types {
            return self.struct_types[target_name].as_pointer();
        }

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

impl NaIRGenPass._codegen_const_expr(
    nd: uni.UniNode, target_type: ir.Type
) -> (ir.Constant | None) {
    import from jaclang.jac0core.const_fold { fold_const }
    (ok, v) = fold_const(nd);
    if not ok {
        return None;
    }
    if isinstance(v, bool) {
        return ir.Constant(target_type, 1 if v else 0);
    }
    if isinstance(v, (int, float)) {
        return ir.Constant(target_type, v);
    }
    return None;
}

impl NaIRGenPass._register_enums(module: uni.Module) -> None {
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Enum) {
            self._codegen_enum(stmt);
        }
    }
}
