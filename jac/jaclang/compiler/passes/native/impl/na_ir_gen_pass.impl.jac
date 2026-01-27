"""Initialize the native IR generation pass."""
impl NaIRGenPass.init(
    ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
) -> None {
    self.llvm_module = ir.Module(name="jac_native");
    self.builder: (ir.IRBuilder | None) = None;
    self.func_symtab: dict[(str, ir.Function)] = {};
    self.local_vars: dict[(str, ir.AllocaInstr)] = {};
    self.has_native_code = False;
    self.type_map: dict[(str, ir.Type)] = {
        "int": ir.IntType(64),
        "float": ir.DoubleType(),
        "bool": ir.IntType(1),
        "str": ir.IntType(8).as_pointer()
    };
    self._printf_func: (ir.Function | None) = None;
    self._fmt_strings: dict[(str, ir.GlobalVariable)] = {};
    super.init(ir_in=ir_in, prog=prog, cancel_token=cancel_token);
}

# ─── Pass Entry / Context Pruning ────────────────────────────
"""Enter node — prune non-native contexts, manually codegen abilities."""
impl NaIRGenPass.enter_node(<>node: uni.UniNode) -> None {
    # Prune client and server blocks entirely
    if isinstance(<>node, (uni.ClientBlock, uni.ServerBlock)) {
        self.prune();
        return;
    }
    # Prune context-aware nodes that are not NATIVE (top-level only)
    if (
        isinstance(<>node, uni.ContextAwareNode)
        and (<>node).code_context != CodeContext.NATIVE
        and ((<>node).parent is None or isinstance((<>node).parent, uni.Module))
    ) {
        self.prune();
        return;
    }
    # For Ability nodes in native context, do manual codegen and prune
    if isinstance(<>node, uni.Ability) {
        if (
            isinstance(<>node, uni.ContextAwareNode)
            and (<>node).code_context == CodeContext.NATIVE
            and (<>node).signature is not None
            and isinstance((<>node).signature, uni.FuncSignature)
        ) {
            self._codegen_ability(<>node);
        }
        self.prune();
        return;
    }
    super.enter_node(<>node);
}

"""Exit node."""
impl NaIRGenPass.exit_node(<>node: uni.UniNode) -> None {
    if isinstance(<>node, (uni.ClientBlock, uni.ServerBlock)) {
        return;
    }
    if isinstance(<>node, uni.Ability) {
        return;
    }
    if (
        isinstance(<>node, uni.ContextAwareNode)
        and (<>node).code_context != CodeContext.NATIVE
        and ((<>node).parent is None or isinstance((<>node).parent, uni.Module))
    ) {
        return;
    }
    super.exit_node(<>node);
}

# ─── Module ──────────────────────────────────────────────────
"""Store the LLVM module on the AST node's gen attribute."""
impl NaIRGenPass.exit_module(<>node: uni.Module) -> None {
    if self.has_native_code {
        (<>node).gen.llvm_ir = self.llvm_module;
    }
}

"""Handle NativeBlock — children already processed via visitor."""
impl NaIRGenPass.exit_native_block(<>node: uni.NativeBlock) -> None {
    ;
}

# ─── Forward Declaration ─────────────────────────────────────
"""Forward-declare all native functions before generating bodies."""
impl NaIRGenPass.before_pass -> None {
    self._forward_declare_functions(self.ir_in);
}

"""Walk the module and declare all native functions."""
impl NaIRGenPass._forward_declare_functions(module: uni.Module) -> None {
    for stmt in module.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                self._maybe_declare_ability(inner);
            }
        } elif isinstance(stmt, uni.Ability) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                self._maybe_declare_ability(stmt);
            }
        }
    }
}

"""Forward-declare a single ability if it's a function."""
impl NaIRGenPass._maybe_declare_ability(node: uni.ElementStmt) -> None {
    if not isinstance(node, uni.Ability) {
        return;
    }
    if node.signature is None or not isinstance(node.signature, uni.FuncSignature) {
        return;
    }
    name = node.name_ref.sym_name if node.name_ref else "unnamed";
    sig = node.signature;
    # Build parameter types
    param_types: list[ir.Type] = [];
    for p in sig.get_parameters() {
        if p.type_tag and p.type_tag.tag {
            param_types.append(self._resolve_jac_type(p.type_tag.tag));
        } else {
            param_types.append(ir.IntType(64));
        }
    }
    # Return type
    ret_type = self._resolve_jac_type(sig.return_type);
    # Create function
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=name);
    # Name the parameters
    for (i, p) in enumerate(sig.get_parameters()) {
        func.args[i].name = p.name.value if p.name else f"arg{i}";
    }
    self.func_symtab[name] = func;
    self.has_native_code = True;
}

# ─── Ability (Function Definition) — Manual Codegen ──────────
"""Generate LLVM IR for a complete function definition."""
impl NaIRGenPass._codegen_ability(<>node: uni.Ability) -> None {
    name = (<>node).name_ref.sym_name if (<>node).name_ref else "unnamed";
    func = self.func_symtab.get(name);
    if func is None {
        return;
    }
    # Create entry block
    block = func.append_basic_block(name="entry");
    self.builder = ir.IRBuilder(block);
    self.local_vars = {};
    # Store parameters as local variables (alloca + store pattern)
    sig = (<>node).signature;
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        alloca = self.builder.alloca(func.args[i].type, name=param_name);
        self.builder.store(func.args[i], alloca);
        self.local_vars[param_name] = alloca;
    }
    # Generate body via manual tree-walking
    if isinstance((<>node).body, (<>list, <>tuple)) {
        self._codegen_body((<>node).body);
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
        ret_type = func.return_value.type;
        if isinstance(ret_type, ir.VoidType) {
            self.builder.ret_void();
        } else {
            self.builder.ret(ir.Constant(ret_type, 0));
        }
    }
    (<>node).gen.llvm_ir = func;
    self.builder = None;
}

# ─── Body / Statement Codegen ─────────────────────────────────
"""Generate IR for a sequence of statements."""
impl NaIRGenPass._codegen_body(stmts: (list | tuple)) -> None {
    for stmt in stmts {
        if self.builder.block.is_terminated {
            break;
        }
        self._codegen_stmt(stmt);
    }
}

"""Generate IR for a single statement."""
impl NaIRGenPass._codegen_stmt(node: uni.UniNode) -> None {
    if self.builder is None or self.builder.block.is_terminated {
        return;
    }
    if isinstance(node, uni.ReturnStmt) {
        self._codegen_return(node);
    } elif isinstance(node, uni.IfStmt) {
        self._codegen_if(node);
    } elif isinstance(node, uni.WhileStmt) {
        self._codegen_while(node);
    } elif isinstance(node, uni.Assignment) {
        self._codegen_assignment(node);
    } elif isinstance(node, uni.ExprStmt) {
        self._codegen_expr(node.expr);
    }
}

"""Generate return statement."""
impl NaIRGenPass._codegen_return(node: uni.ReturnStmt) -> None {
    if node.expr is not None {
        val = self._codegen_expr(node.expr);
        if val is not None {
            func_ret_type = self.builder.function.return_value.type;
            val = self._coerce_type(val, func_ret_type);
            self.builder.ret(val);
        } else {
            self.builder.ret_void();
        }
    } else {
        self.builder.ret_void();
    }
}

"""Generate if/else/elif statement with proper basic blocks."""
impl NaIRGenPass._codegen_if(node: uni.IfStmt) -> None {
    cond = self._codegen_expr(node.condition);
    if cond is None {
        return;
    }
    # Ensure condition is i1 (bool)
    cond = self._to_bool(cond);
    func = self.builder.function;
    then_bb = func.append_basic_block(name="if.then");
    else_bb = func.append_basic_block(name="if.else");
    merge_bb = func.append_basic_block(name="if.end");
    self.builder.cbranch(cond, then_bb, else_bb);
    # Then block
    self.builder.position_at_end(then_bb);
    if isinstance(node.body, (<>list, <>tuple)) {
        self._codegen_body(node.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    # Else block
    self.builder.position_at_end(else_bb);
    if node.else_body is not None {
        if isinstance(node.else_body, uni.ElseIf) {
            self._codegen_if(node.else_body);
        } elif isinstance(node.else_body, uni.ElseStmt) {
            if isinstance(node.else_body.body, (<>list, <>tuple)) {
                self._codegen_body(node.else_body.body);
            }
        }
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    self.builder.position_at_end(merge_bb);
}

"""Generate while loop with proper basic blocks."""
impl NaIRGenPass._codegen_while(node: uni.WhileStmt) -> None {
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="while.cond");
    body_bb = func.append_basic_block(name="while.body");
    end_bb = func.append_basic_block(name="while.end");
    # Jump to condition check
    self.builder.branch(cond_bb);
    # Condition block
    self.builder.position_at_end(cond_bb);
    cond = self._codegen_expr(node.condition);
    if cond is not None {
        cond = self._to_bool(cond);
        self.builder.cbranch(cond, body_bb, end_bb);
    } else {
        self.builder.branch(end_bb);
    }
    # Body block
    self.builder.position_at_end(body_bb);
    if isinstance(node.body, (<>list, <>tuple)) {
        self._codegen_body(node.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(cond_bb);
    }
    # Continue after loop
    self.builder.position_at_end(end_bb);
}

"""Generate assignment statement."""
impl NaIRGenPass._codegen_assignment(node: uni.Assignment) -> None {
    value = self._codegen_expr(node.value) if node.value else None;
    if value is None {
        return;
    }
    targets = node.target
    if isinstance(node.target, (<>list, <>tuple))
    else [(node.target)];
    for target_expr in targets {
        var_name = self._get_name(target_expr);
        if var_name is None {
            continue;
        }

        if var_name in self.local_vars {
            # Update existing variable
            alloca = self.local_vars[var_name];
            coerced = self._coerce_type(value, alloca.type.pointee);
            self.builder.store(coerced, alloca);
        } else {
            # New variable — allocate and store
            var_type = value.type;
            if node.type_tag and node.type_tag.tag {
                var_type = self._resolve_jac_type(node.type_tag.tag);
                value = self._coerce_type(value, var_type);
            }
            alloca = self.builder.alloca(var_type, name=var_name);
            self.builder.store(value, alloca);
            self.local_vars[var_name] = alloca;
        }
    }
}

# ─── Expression Codegen ──────────────────────────────────────
"""Generate IR for an expression, returning the resulting value."""
impl NaIRGenPass._codegen_expr(node: (uni.UniNode | None)) -> (ir.Value | None) {
    if node is None {
        return None;
    }
    if isinstance(node, uni.Int) {
        return ir.Constant(ir.IntType(64), int(node.value));
    }
    if isinstance(node, uni.Float) {
        return ir.Constant(ir.DoubleType(), float(node.value));
    }
    if isinstance(node, uni.Bool) {
        val = 1 if node.value.lower() in ("true", "1") else 0;
        return ir.Constant(ir.IntType(1), val);
    }
    if isinstance(node, uni.Name) {
        return self._codegen_name(node);
    }
    if isinstance(node, uni.BinaryExpr) {
        return self._codegen_binary(node);
    }
    if isinstance(node, uni.CompareExpr) {
        return self._codegen_compare(node);
    }
    if isinstance(node, uni.UnaryExpr) {
        return self._codegen_unary(node);
    }
    if isinstance(node, uni.FuncCall) {
        return self._codegen_call(node);
    }
    return None;
}

"""Load a variable or return a function reference."""
impl NaIRGenPass._codegen_name(node: uni.Name) -> (ir.Value | None) {
    var_name = node.value;
    if var_name in self.local_vars {
        alloca = self.local_vars[var_name];
        return self.builder.load(alloca, name=var_name);
    }
    if var_name in self.func_symtab {
        return self.func_symtab[var_name];
    }
    return None;
}

"""Generate binary expression."""
impl NaIRGenPass._codegen_binary(node: uni.BinaryExpr) -> (ir.Value | None) {
    left = self._codegen_expr(node.left);
    right = self._codegen_expr(node.right);
    if left is None or right is None {
        return None;
    }
    op = node.op.name if isinstance(node.op, uni.Token) else str(node.op);
    return self._emit_binary_op(op, left, right);
}

"""Generate comparison expression."""
impl NaIRGenPass._codegen_compare(node: uni.CompareExpr) -> (ir.Value | None) {
    left = self._codegen_expr(node.left);
    if left is None or not node.rights or not node.ops {
        return None;
    }
    right = self._codegen_expr(node.rights[0]);
    if right is None {
        return None;
    }
    op = node.ops[0].name if isinstance(node.ops[0], uni.Token) else str(node.ops[0]);
    is_float = isinstance(left.type, ir.DoubleType)
    or isinstance(right.type, ir.DoubleType);
    if is_float {
        (left, right) = self._promote_to_float(left, right);
    }
    return self._emit_comparison(op, left, right, is_float);
}

"""Generate unary expression."""
impl NaIRGenPass._codegen_unary(node: uni.UnaryExpr) -> (ir.Value | None) {
    operand = self._codegen_expr(node.operand);
    if operand is None {
        return None;
    }
    op = node.op.name if isinstance(node.op, uni.Token) else str(node.op);
    if op == Tok.MINUS {
        if isinstance(operand.type, ir.DoubleType) {
            return self.builder.fneg(operand, name="fneg");
        } elif isinstance(operand.type, ir.IntType) {
            return self.builder.neg(operand, name="neg");
        }
    } elif op == Tok.NOT {
        if isinstance(operand.type, ir.IntType) and operand.type.width == 1 {
            return self.builder.not_(operand, name="not");
        } elif isinstance(operand.type, ir.IntType) {
            zero = ir.Constant(operand.type, 0);
            return self.builder.icmp_signed("==", operand, zero, name="not");
        }
    }
    return None;
}

"""Generate function call."""
impl NaIRGenPass._codegen_call(node: uni.FuncCall) -> (ir.Value | None) {
    func_name = self._get_name(node.target);
    if func_name is None {
        return None;
    }
    # Handle print() specially
    if func_name == "print" {
        return self._emit_print(node);
    }
    func = self.func_symtab.get(func_name);
    if func is None {
        return None;
    }
    # Build arguments
    args: list[ir.Value] = [];
    params = node.params or [];
    for param in params {
        val = self._codegen_expr(param);
        if val is not None {
            args.append(val);
        }
    }
    # Type coerce arguments
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(func.args) {
            coerced.append(self._coerce_type(arg, func.args[i].type));
        } else {
            coerced.append(arg);
        }
    }
    return self.builder.call(func, coerced, name=f"call.{func_name}");
}

# ─── Print Support ───────────────────────────────────────────
"""Get or create the printf external function declaration."""
impl NaIRGenPass._get_printf -> ir.Function {
    if self._printf_func is None {
        printf_ty = ir.FunctionType(
            ir.IntType(32), [ir.IntType(8).as_pointer()], var_arg=True
        );
        self._printf_func = ir.Function(self.llvm_module, printf_ty, name="printf");
    }
    return self._printf_func;
}

"""Emit printf call for print()."""
impl NaIRGenPass._emit_print(node: uni.FuncCall) -> (ir.Value | None) {
    printf = self._get_printf();
    params = node.params or [];
    if not params {
        fmt = self._get_fmt_string("");
        fmt_ptr = self.builder.bitcast(fmt, ir.IntType(8).as_pointer());
        self.builder.call(printf, [fmt_ptr]);
        return ir.Constant(ir.IntType(64), 0);
    }
    val = self._codegen_expr(params[0]);
    if val is None {
        return ir.Constant(ir.IntType(64), 0);
    }
    if isinstance(val.type, ir.IntType) and val.type.width == 64 {
        fmt = self._get_fmt_string("%lld");
    } elif isinstance(val.type, ir.DoubleType) {
        fmt = self._get_fmt_string("%f");
    } elif isinstance(val.type, ir.IntType) and val.type.width == 1 {
        val = self.builder.zext(val, ir.IntType(64));
        fmt = self._get_fmt_string("%lld");
    } else {
        return ir.Constant(ir.IntType(64), 0);
    }
    fmt_ptr = self.builder.bitcast(fmt, ir.IntType(8).as_pointer());
    self.builder.call(printf, [fmt_ptr, val]);
    return ir.Constant(ir.IntType(64), 0);
}

"""Get or create a global format string for printf."""
impl NaIRGenPass._get_fmt_string(fmt: str) -> ir.GlobalVariable {
    if fmt in self._fmt_strings {
        return self._fmt_strings[fmt];
    }
    fmt_bytes = bytearray((fmt + "\n\0").encode("utf8"));
    c_fmt = ir.Constant(ir.ArrayType(ir.IntType(8), len(fmt_bytes)), fmt_bytes);
    global_fmt = ir.GlobalVariable(
        self.llvm_module, c_fmt.type, name=f".fmt.{len(self._fmt_strings)}"
    );
    global_fmt.linkage = "private";
    global_fmt.global_constant = True;
    global_fmt.initializer = c_fmt;
    self._fmt_strings[fmt] = global_fmt;
    return global_fmt;
}

# ─── Helper Methods ──────────────────────────────────────────
"""Resolve a Jac type expression to an LLVM type."""
impl NaIRGenPass._resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    if type_expr is None {
        return ir.IntType(64);
    }
    # Handle Name nodes (type references like `int`, `float`)
    if isinstance(type_expr, uni.Name) {
        type_name = type_expr.value;
        if type_name in self.type_map {
            return self.type_map[type_name];
        }
    }
    # Handle BuiltinType nodes
    if uni?.BuiltinType and isinstance(type_expr, uni.BuiltinType) {
        type_name = type_expr.value;
        if type_name in self.type_map {
            return self.type_map[type_name];
        }
    }
    # Try expr_type string
    if type_expr?.expr_type and type_expr.expr_type in self.type_map {
        return self.type_map[type_expr.expr_type];
    }
    return ir.IntType(64);
}

"""Extract name string from a Name or similar node."""
impl NaIRGenPass._get_name(node: (uni.UniNode | None)) -> (str | None) {
    if node is None {
        return None;
    }
    if isinstance(node, uni.Name) {
        return node.value;
    }
    if node?.sym_name {
        return node.sym_name;
    }
    if node?.value and isinstance(getattr(node, "value"), str) {
        return node.value;
    }
    return None;
}

"""Convert a value to i1 (boolean)."""
impl NaIRGenPass._to_bool(val: ir.Value) -> ir.Value {
    if isinstance(val.type, ir.IntType) and val.type.width == 1 {
        return val;
    }
    if isinstance(val.type, ir.IntType) {
        return self.builder.icmp_unsigned(
            "!=", val, ir.Constant(val.type, 0), name="tobool"
        );
    }
    if isinstance(val.type, ir.DoubleType) {
        return self.builder.fcmp_ordered(
            "!=", val, ir.Constant(val.type, 0.0), name="tobool"
        );
    }
    return val;
}

"""Coerce a value to the target type if needed."""
impl NaIRGenPass._coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value {
    if val.type == target_type {
        return val;
    }
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.sitofp(val, target_type, name="cast");
    }
    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast");
    }
    return val;
}

"""Promote both operands to float if either is float."""
impl NaIRGenPass._promote_to_float(
    left: ir.Value, right: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    if isinstance(left.type, ir.IntType) {
        left = self.builder.sitofp(left, ir.DoubleType(), name="cast");
    }
    if isinstance(right.type, ir.IntType) {
        right = self.builder.sitofp(right, ir.DoubleType(), name="cast");
    }
    return (left, right);
}

"""Emit a binary operation."""
impl NaIRGenPass._emit_binary_op(
    op: str, left: ir.Value, right: ir.Value
) -> (ir.Value | None) {
    is_float = isinstance(left.type, ir.DoubleType)
    or isinstance(right.type, ir.DoubleType);
    if is_float {
        (left, right) = self._promote_to_float(left, right);
    }
    if is_float {
        if op == Tok.PLUS {
            return self.builder.fadd(left, right, name="fadd");
        } elif op == Tok.MINUS {
            return self.builder.fsub(left, right, name="fsub");
        } elif op == Tok.STAR_MUL {
            return self.builder.fmul(left, right, name="fmul");
        } elif op == Tok.DIV {
            return self.builder.fdiv(left, right, name="fdiv");
        } elif op == Tok.MOD {
            return self.builder.frem(left, right, name="fmod");
        }
    } else {
        if op == Tok.PLUS {
            return self.builder.add(left, right, name="add");
        } elif op == Tok.MINUS {
            return self.builder.sub(left, right, name="sub");
        } elif op == Tok.STAR_MUL {
            return self.builder.mul(left, right, name="mul");
        } elif op == Tok.DIV {
            return self.builder.sdiv(left, right, name="div");
        } elif op == Tok.FLOOR_DIV {
            return self.builder.sdiv(left, right, name="floordiv");
        } elif op == Tok.MOD {
            return self.builder.srem(left, right, name="mod");
        }
    }
    # Logical operators
    if op == Tok.KW_AND {
        return self.builder.and_(left, right, name="and");
    }
    if op == Tok.KW_OR {
        return self.builder.or_(left, right, name="or");
    }
    return None;
}

"""Emit a comparison operation."""
impl NaIRGenPass._emit_comparison(
    op: str, left: ir.Value, right: ir.Value, is_float: bool
) -> (ir.Value | None) {
    if is_float {
        fcmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.NE: "!=",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in fcmp_map {
            return self.builder.fcmp_ordered(fcmp_map[op], left, right, name="fcmp");
        }
    } else {
        icmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.NE: "!=",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in icmp_map {
            return self.builder.icmp_signed(icmp_map[op], left, right, name="icmp");
        }
    }
    return None;
}
