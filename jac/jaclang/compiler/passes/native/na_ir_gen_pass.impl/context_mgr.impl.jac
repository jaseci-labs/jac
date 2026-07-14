impl NaIRGenPass._codegen_with(nd: uni.WithStmt) -> None {
    if not nd.exprs {
        if isinstance(nd.body, (list, tuple)) {
            self._codegen_body(nd.body);
        }
        return;
    }

    self._codegen_with_recursive(nd.exprs, 0, nd.body);
}

impl NaIRGenPass._codegen_with_recursive(
    exprs: object, idx: int, body: object
) -> None {
    if idx >= len(exprs) {
        if isinstance(body, (list, tuple)) {
            self._codegen_body(body);
        }
        return;
    }
    expr_item = exprs[idx];
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    func = self.builder.function;

    cm_val = self._codegen_expr(expr_item.expr);
    if cm_val is None {
        self._codegen_with_recursive(exprs, idx + 1, body);
        return;
    }

    type_name: (str | None) = None;
    cm_target_name = self._get_name(expr_item.expr);

    if isinstance(cm_val.type, ir.PointerType) {
        for (sname, stype) in self.struct_types.items() {
            if cm_val.type == stype.as_pointer() {
                type_name = sname;
                break;
            }
        }
    }
    if type_name is None {
        type_name = self._infer_type_name(cm_val);
    }
    if type_name is None {
        self._codegen_with_recursive(exprs, idx + 1, body);
        return;
    }

    enter_fn: (ir.Function | None) = None;
    exit_fn: (ir.Function | None) = None;
    for check_name in self._mro_of(type_name) {
        enter_key = f"{check_name}.__enter__";
        exit_key = f"{check_name}.__exit__";
        if enter_fn is None and enter_key in self.method_funcs {
            enter_fn = self.method_funcs[enter_key];
        }
        if exit_fn is None and exit_key in self.method_funcs {
            exit_fn = self.method_funcs[exit_key];
        }
        if enter_fn is not None and exit_fn is not None {
            break;
        }
    }
    if enter_fn is None or exit_fn is None {
        self._codegen_with_recursive(exprs, idx + 1, body);
        return;
    }

    enter_args: list[ir.Value] = [cm_val];

    if len(enter_fn.args) > 0 {
        enter_args[0] = self._coerce_type(cm_val, enter_fn.args[0].type);
    }
    enter_result = self.builder.call(enter_fn, enter_args, name="cm.enter");

    if expr_item.alias is not None {
        alias_name = self._get_name(expr_item.alias);
        if alias_name is not None {
            alloca = self._entry_alloca(enter_result.type, alias_name);

            if isinstance(enter_result.type, ir.PointerType) {
                self.builder.store(ir.Constant(enter_result.type, None), alloca);
                self._emit_rc_retain(
                    enter_result,
                    op="ctx_enter",
                    loc=getattr(enter_result, 'jac_loc', '')
                );
            }
            self.builder.store(enter_result, alloca);
            self.local_vars[alias_name] = alloca;
        }
    }

    body_bb = func.append_basic_block(name=f"with.body.{idx}");
    exit_bb = func.append_basic_block(name=f"with.exit.{idx}");
    merge_bb = func.append_basic_block(name=f"with.merge.{idx}");
    self.builder.branch(body_bb);

    self.builder.position_at_end(body_bb);
    self._codegen_with_recursive(exprs, idx + 1, body);
    if not self.builder.block.is_terminated {
        self.builder.branch(exit_bb);
    }

    self.builder.position_at_end(exit_bb);

    null_ptr = ir.Constant(i8p, None);
    exit_args: list[ir.Value] = [cm_val];

    if len(exit_fn.args) > 0 {
        exit_args[0] = self._coerce_type(cm_val, exit_fn.args[0].type);
    }

    for i in range(1, len(exit_fn.args)) {
        exit_args.append(null_ptr);
    }
    self.builder.call(exit_fn, exit_args, name="cm.exit");
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
}
