"""Context manager codegen: with statement (__enter__/__exit__ protocol).

Generates the control flow for:
  with expr as var { body }

Control flow:
  entry:     cm = codegen(expr), result = cm.__enter__(), bind to var
  body:      execute body statements
  exit:      call cm.__exit__(null, null, null)
  merge:     continue

Multiple context managers (with a as x, b as y) are handled by
recursive nesting — outer __enter__ first, inner __exit__ first (LIFO).
"""

# ─── With Statement Codegen ──────────────────────────────────
"""Generate IR for with statement: with expr as var { body }."""
impl NaIRGenPass._codegen_with(nd: uni.WithStmt) -> None {
    if not nd.exprs {
        # Empty with statement — just generate body
        if isinstance(nd.body, (list, tuple)) {
            self._codegen_body(nd.body);
        }
        return;
    }
    # For multiple context managers, process recursively (nest them)
    # with a as x, b as y { body } → with a as x { with b as y { body } }
    self._codegen_with_recursive(nd.exprs, 0, nd.body);
}

"""Recursively generate nested with blocks for multiple context managers."""
impl NaIRGenPass._codegen_with_recursive(exprs: object, idx: int, body: object) -> None {
    if idx >= len(exprs) {
        # Base case: generate the actual body
        if isinstance(body, (list, tuple)) {
            self._codegen_body(body);
        }
        return;
    }
    expr_item = exprs[idx];
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    func = self.builder.function;
    # Evaluate the context manager expression
    cm_val = self._codegen_expr(expr_item.expr);
    if cm_val is None {
        # Skip this context manager, proceed with rest
        self._codegen_with_recursive(exprs, idx + 1, body);
        return;
    }
    # Determine the type of the context manager
    type_name: (str | None) = None;
    cm_target_name = self._get_name(expr_item.expr);
    # Check if the cm is a File type or a known struct type
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
        # Cannot determine type — skip context manager protocol, just run body
        self._codegen_with_recursive(exprs, idx + 1, body);
        return;
    }
    # Look up __enter__ and __exit__ methods
    enter_fn: (ir.Function | None) = None;
    exit_fn: (ir.Function | None) = None;
    check_name = type_name;
    while check_name is not None {
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
        check_name = self.class_hierarchy.get(check_name);
    }
    if enter_fn is None or exit_fn is None {
        # Type doesn't support context manager protocol — just run body
        self._codegen_with_recursive(exprs, idx + 1, body);
        return;
    }
    # Call __enter__ with self as argument
    enter_args: list[ir.Value] = [cm_val];
    # Coerce self to expected type
    if len(enter_fn.args) > 0 {
        enter_args[0] = self._coerce_type(cm_val, enter_fn.args[0].type);
    }
    enter_result = self.builder.call(enter_fn, enter_args, name="cm.enter");
    # Bind the result to the alias variable if present
    if expr_item.alias is not None {
        alias_name = self._get_name(expr_item.alias);
        if alias_name is not None {
            alloca = self._entry_alloca(enter_result.type, alias_name);
            self.builder.store(enter_result, alloca);
            self.local_vars[alias_name] = alloca;
            # Track type info for the alias variable
            if isinstance(enter_result.type, ir.PointerType) {
                for (sname, stype) in self.struct_types.items() {
                    if enter_result.type == stype.as_pointer() {
                        self.type_var_map[alias_name] = sname;
                        break;
                    }
                }
            }
        }
    }
    # Create basic blocks for body and exit
    body_bb = func.append_basic_block(name=f"with.body.{idx}");
    exit_bb = func.append_basic_block(name=f"with.exit.{idx}");
    merge_bb = func.append_basic_block(name=f"with.merge.{idx}");
    self.builder.branch(body_bb);
    # ── Body block: generate inner with's or actual body ──
    self.builder.position_at_end(body_bb);
    self._codegen_with_recursive(exprs, idx + 1, body);
    if not self.builder.block.is_terminated {
        self.builder.branch(exit_bb);
    }
    # ── Exit block: call __exit__ ──
    self.builder.position_at_end(exit_bb);
    # Build __exit__ arguments: self, exc_type, exc_val, traceback
    # For now, pass null for all exception args (no exception)
    null_ptr = ir.Constant(i8p, None);
    exit_args: list[ir.Value] = [cm_val];
    # Coerce self
    if len(exit_fn.args) > 0 {
        exit_args[0] = self._coerce_type(cm_val, exit_fn.args[0].type);
    }
    # Add null exception args (exc_type, exc_val, traceback)
    for i in range(1, len(exit_fn.args)) {
        exit_args.append(null_ptr);
    }
    self.builder.call(exit_fn, exit_args, name="cm.exit");
    self.builder.branch(merge_bb);
    # ── Merge: continue after with ──
    self.builder.position_at_end(merge_bb);
}
