impl MirLowering.lower -> MirModule {
    for ab in self.module_abilities() {
        try {
            self.declare(ab);
        } except MirRefused as err {
            name = self.name_of(ab);
            self.refusals.setdefault(name, []).append(refusal_of(err));
        }
    }
    for key in self.order {
        made = self.lower_function(self.decls[key]);
        if made is not None {
            self.mir.functions.append(made);
        }
    }
    return self.mir;
}

impl MirLowering.module_abilities -> list[uni.Ability] {
    found: list[uni.Ability] = [];
    for elem in self.module.body {
        if isinstance(elem, uni.Ability)
            and isinstance(elem.signature, uni.FuncSignature) {
            found.append(elem);
        }
    }
    return found;
}

impl MirLowering.declare(ab: uni.Ability) {
    sig = ab.signature;
    if not isinstance(sig, uni.FuncSignature) {
        raise MirRefused(mir_refusal("function", "event ability", ab));
    }
    if sig.varargs is not None or sig.kwargs is not None or sig.kwonlyargs {
        raise MirRefused(
            mir_refusal("function", "variadic or keyword-only parameters", ab)
        );
    }
    params: list[MirType] = [];
    for pv in list(sig.posonly_params) + list(sig.params or []) {
        params.append(self.symbol_type(pv.name.sym, pv));
    }
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(self.ability_sym(ab));
    ret = mir_none();
    if isinstance(fn_type, FunctionType) {
        ret = mir_type_of(fn_type.return_type, MirPosition.SIGNATURE, ab);
    }
    key = id(ab);
    self.decls[key] = MirDecl(
        ability=ab, symbol=self.symbol_of(ab), params=params, ret=ret
    );
    self.order.append(key);
}

impl MirLowering.symbol_of(ab: uni.Ability) -> str {
    path = self.module.loc.mod_path;
    name = native_unit_spelling(self.name_of(ab), path);
    is_pub = bool(ab.access and ab.access.tag.name == Tok.KW_PUB);
    bundled = native_unit_identity(path).startswith("jaclang/runtime/na_stdlib/");
    if is_pub and not bundled {
        return native_def_symbol(name);
    }
    return native_symbol_name(native_unit_prefix(path), name);
}

impl MirLowering.lower_function(decl: MirDecl) -> (MirFunction | None) {
    ab = decl.ability;
    fn = MirFunction(name=self.name_of(ab), symbol=decl.symbol, ret=decl.ret);
    first = fn.new_block("entry");
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        sig = ab.signature;
        if not isinstance(sig, uni.FuncSignature) {
            raise MirRefused(mir_refusal("function", "event ability", ab));
        }
        nodes = list(sig.posonly_params) + list(sig.params or []);
        for (pv, ptype) in zip(nodes, decl.params) {
            value = fn.new_value(ptype, pv.name.value);
            fn.params.append(MirParam(name=pv.name.value, value=value));
            self.builder().store(self.local_slot(pv.name.sym, pv), value);
        }
        body = ab.body;
        if not isinstance(body, (list, tuple)) {
            raise MirRefused(
                mir_refusal("function", "body defined outside its declaration", ab)
            );
        }
        self.lower_body(body);
        if not self.builder().block.terminated() {
            if decl.ret.kind == MirKind.NONE {
                self.builder().ret(None);
            } else {
                self.builder().unreachable();
            }
        }
        for blk in fn.blocks {
            if not blk.terminated() {
                self.builder().position(blk);
                self.builder().unreachable();
            }
        }
    } except MirRefused as err {
        self.refusals.setdefault(fn.name, []).append(refusal_of(err));
        self.state = None;
        return None;
    }
    self.state = None;
    return fn;
}

impl MirLowering.st -> MirFnState {
    if self.state is None {
        raise RuntimeError("MIR lowering has no function in progress");
    }
    return self.state;
}

impl MirLowering.builder -> MirBuilder {
    return self.st().b;
}

impl MirLowering.symbol_type(sym: (uni.Symbol | None), site: uni.UniNode) -> MirType {
    if sym is None {
        raise MirRefused(mir_refusal("name", "unresolved", site));
    }
    found = self.prog.get_type_evaluator().get_type_of_symbol(sym);
    return mir_type_of(found, MirPosition.VALUE, site);
}

impl MirLowering.expr_type(nd: uni.Expr) -> MirType {
    return mir_type_of(nd.type, MirPosition.VALUE, nd);
}

impl MirLowering.lower_body(stmts: Sequence[uni.UniNode]) {
    for stmt in stmts {
        if self.builder().block.terminated() {
            self.builder().position(self.st().fn.new_block("dead"));
        }
        self.lower_stmt(stmt);
    }
}

impl MirLowering.lower_stmt(nd: uni.UniNode) {
    if isinstance(nd, uni.ExprStmt) {
        self.lower_expr(nd.expr);
    } elif isinstance(nd, uni.Assignment) {
        self.lower_assignment(nd);
    } elif isinstance(nd, uni.ReturnStmt) {
        self.lower_return(nd);
    } elif isinstance(nd, uni.IfStmt) {
        self.lower_if(nd);
    } elif isinstance(nd, uni.WhileStmt) {
        self.lower_while(nd);
    } elif isinstance(nd, uni.CtrlStmt) {
        self.lower_ctrl(nd);
    } else {
        raise MirRefused(mir_refusal("statement", type(nd).__name__, nd));
    }
}

impl MirLowering.lower_assignment(nd: uni.Assignment) {
    targets = list(nd.target);
    if len(targets) != 1 {
        raise MirRefused(mir_refusal("assignment", "several targets", nd));
    }
    target = targets[0];
    if not isinstance(target, uni.Name) {
        raise MirRefused(mir_refusal("assignment", type(target).__name__, nd));
    }
    if nd.value is None {
        self.local_slot(target.sym, target);
        return;
    }
    value = self.lower_expr(nd.value);
    if nd.aug_op is not None {
        op = AUG_OPERATORS.get(nd.aug_op.name);
        if op is None {
            raise MirRefused(mir_refusal("augmented assignment", nd.aug_op.value, nd));
        }
        slot = self.local_slot(target.sym, target);
        current = self.builder().load(slot, slot.type);
        value = self.arith(op, current, value, nd);
    }
    self.store_name(target, value);
}

impl MirLowering.store_name(target: uni.Name, value: MirValue) {
    slot = self.local_slot(target.sym, target);
    self.builder().store(slot, self.coerce(value, slot.type, target));
}

impl MirLowering.local_slot(sym: (uni.Symbol | None), site: uni.UniNode) -> MirValue {
    if sym is None {
        raise MirRefused(mir_refusal("name", "unresolved", site));
    }
    key = id(sym);
    found = self.st().locals.get(key);
    if found is not None {
        return found;
    }
    slot_type = self.symbol_type(sym, site);
    fn = self.st().fn;
    first = fn.blocks[0];
    made = fn.new_value(slot_type, sym.sym_name);
    first.instrs.insert(0, MirInstr(op=MirOp.SLOT, result=made, type_arg=slot_type));
    self.st().locals[key] = made;
    return made;
}

impl MirLowering.lower_return(nd: uni.ReturnStmt) {
    ret = self.st().fn.ret;
    if nd.expr is None {
        if ret.kind != MirKind.NONE {
            raise MirRefused(mir_refusal("return", "missing value", nd));
        }
        self.builder().ret(None);
        return;
    }
    value = self.lower_expr(nd.expr);
    if ret.kind == MirKind.NONE {
        self.builder().ret(None);
        return;
    }
    self.builder().ret(self.coerce(value, ret, nd));
}

impl MirLowering.lower_if(nd: (uni.IfStmt | uni.ElseIf)) {
    if nd.is_comptime {
        raise MirRefused(mir_refusal("statement", "comptime if", nd));
    }
    cond = self.truthy(self.lower_expr(nd.condition), nd.condition);
    fn = self.st().fn;
    then_bb = fn.new_block("then");
    else_bb = fn.new_block("else");
    done_bb = fn.new_block("endif");
    self.builder().cond_branch(cond, then_bb, else_bb);
    self.builder().position(then_bb);
    self.lower_body(nd.body);
    if not self.builder().block.terminated() {
        self.builder().branch(done_bb);
    }
    self.builder().position(else_bb);
    self.lower_else(nd.else_body, done_bb);
    self.builder().position(done_bb);
}

impl MirLowering.lower_else(nd: (uni.ElseStmt | uni.ElseIf | None), done: MirBlock) {
    if isinstance(nd, uni.ElseIf) {
        self.lower_if(nd);
    } elif isinstance(nd, uni.ElseStmt) {
        self.lower_body(nd.body);
    }
    if not self.builder().block.terminated() {
        self.builder().branch(done);
    }
}

impl MirLowering.lower_while(nd: uni.WhileStmt) {
    fn = self.st().fn;
    head = fn.new_block("while.head");
    body = fn.new_block("while.body");
    otherwise = fn.new_block("while.else");
    after = fn.new_block("while.exit");
    self.builder().branch(head);
    self.builder().position(head);
    cond = self.truthy(self.lower_expr(nd.condition), nd.condition);
    self.builder().cond_branch(cond, body, otherwise);
    self.builder().position(body);
    self.st().loops.append(MirLoopTarget(head=head, after=after));
    self.lower_body(nd.body);
    self.st().loops.pop();
    if not self.builder().block.terminated() {
        self.builder().branch(head);
    }
    self.builder().position(otherwise);
    self.lower_else(nd.else_body, after);
    self.builder().position(after);
}

impl MirLowering.lower_ctrl(nd: uni.CtrlStmt) {
    if not self.st().loops {
        raise MirRefused(mir_refusal("statement", nd.ctrl.value, nd));
    }
    target = self.st().loops[-1];
    if nd.ctrl.name == Tok.KW_BREAK {
        self.builder().branch(target.after);
    } elif nd.ctrl.name == Tok.KW_CONTINUE {
        self.builder().branch(target.head);
    } else {
        raise MirRefused(mir_refusal("statement", nd.ctrl.value, nd));
    }
}

impl MirLowering.lower_expr(nd: uni.UniNode) -> MirValue {
    value: (MirValue | None) = None;
    if isinstance(nd, uni.Int) {
        bits = uni.int_literal_i64(nd.value);
        if bits is None {
            raise MirRefused(
                mir_refusal(
                    "integer literal",
                    nd.value,
                    nd,
                    "A native int is 64 bits and this literal does not fit one."
                )
            );
        }
        value = self.builder().const_int(bits, self.expr_type(nd));
    } elif isinstance(nd, uni.Float) {
        value = self.builder().const_float(float(nd.value), self.expr_type(nd));
    } elif isinstance(nd, uni.Bool) {
        value = self.builder().const_bool(nd.value.lower() in ("true", "1"));
    } elif isinstance(nd, uni.Name) {
        value = self.lower_name(nd);
    } elif isinstance(nd, uni.AtomUnit) {
        value = self.lower_expr(nd.value);
    } elif isinstance(nd, uni.CfgExpr) {
        value = self.lower_expr(nd.expr);
    } elif isinstance(nd, uni.BinaryExpr) {
        value = self.lower_binary(nd);
    } elif isinstance(nd, uni.CompareExpr) {
        value = self.lower_compare(nd);
    } elif isinstance(nd, uni.UnaryExpr) {
        value = self.lower_unary(nd);
    } elif isinstance(nd, uni.BoolExpr) {
        value = self.lower_bool(nd);
    } elif isinstance(nd, uni.FuncCall) {
        value = self.lower_call(nd);
    } else {
        raise MirRefused(mir_refusal("expression", type(nd).__name__, nd));
    }
    if value is None {
        raise MirRefused(mir_refusal("expression", type(nd).__name__, nd));
    }
    if isinstance(nd, uni.Expr) and nd.coerce_to is not None {
        value = self.coerce(value, mir_class_type_named(nd.coerce_to, nd), nd);
    }
    return value;
}

impl MirLowering.lower_name(nd: uni.Name) -> MirValue {
    if nd.sym is None or id(nd.sym) not in self.st().locals {
        raise MirRefused(mir_refusal("name", nd.value, nd));
    }
    slot = self.st().locals[id(nd.sym)];
    return self.builder().load(slot, slot.type);
}

impl MirLowering.lower_binary(nd: uni.BinaryExpr) -> MirValue {
    if not isinstance(nd.op, uni.Token) {
        raise MirRefused(mir_refusal("binary operator", type(nd.op).__name__, nd));
    }
    left = self.lower_expr(nd.left);
    right = self.lower_expr(nd.right);
    return self.arith(nd.op.name, left, right, nd);
}

impl MirLowering.arith(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if not left.type.is_numeric() or not right.type.is_numeric() {
        raise MirRefused(
            mir_refusal("binary operator", f"{op} on {left.type.render()}", site)
        );
    }
    if op == Tok.DIV
        or left.type.kind == MirKind.FLOAT
        or right.type.kind == MirKind.FLOAT {
        wide = mir_float(
            max(
                left.type.width if left.type.kind == MirKind.FLOAT else 64,
                right.type.width if right.type.kind == MirKind.FLOAT else 64
            )
        );
        fl = b.convert(left, wide);
        fr = b.convert(right, wide);
        if op == Tok.PLUS {
            return b.binary("add", fl, fr);
        }
        if op == Tok.MINUS {
            return b.binary("sub", fl, fr);
        }
        if op == Tok.STAR_MUL {
            return b.binary("mul", fl, fr);
        }
        if op in (Tok.DIV, Tok.MOD, Tok.FLOOR_DIV) {
            message = FLOAT_ZERO_DIVISION_MESSAGE;
            if op == Tok.MOD {
                message = FLOAT_ZERO_MODULO_MESSAGE;
            } elif op == Tok.FLOOR_DIV {
                message = FLOAT_ZERO_FLOOR_MESSAGE;
            }
            zero = b.const_float(0.0, wide);
            self.raise_if(b.compare("eq", fr, zero), "ZeroDivisionError", message);
            if op == Tok.DIV {
                return b.binary("div", fl, fr);
            }
            return b.binary("mod" if op == Tok.MOD else "floordiv", fl, fr);
        }
        raise MirRefused(mir_refusal("binary operator", f"{op} on float", site));
    }
    (li, ri) = self.unify_numeric(left, right, site);
    if op in (Tok.PLUS, Tok.MINUS, Tok.STAR_MUL) {
        name = "add" if op == Tok.PLUS else ("sub" if op == Tok.MINUS else "mul");
        self.raise_if(b.overflows(name, li, ri), "OverflowError", OVERFLOW_MESSAGE);
        return b.binary(name, li, ri);
    }
    if op in (Tok.FLOOR_DIV, Tok.MOD) {
        zero = b.const_int(0, ri.type);
        self.raise_if(
            b.compare("eq", ri, zero), "ZeroDivisionError", ZERO_DIVISION_MESSAGE
        );
        if op == Tok.FLOOR_DIV {
            self.raise_if(
                b.overflows("floordiv", li, ri), "OverflowError", OVERFLOW_MESSAGE
            );
            return b.binary("floordiv", li, ri);
        }
        return b.binary("mod", li, ri);
    }
    if op == Tok.BW_AND {
        return b.binary("and", li, ri);
    }
    if op == Tok.BW_OR {
        return b.binary("or", li, ri);
    }
    if op == Tok.BW_XOR {
        return b.binary("xor", li, ri);
    }
    raise MirRefused(mir_refusal("binary operator", op, site));
}

impl MirLowering.lower_compare(nd: uni.CompareExpr) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    result = fn.new_value(mir_bool(), "cmp.chain");
    fn.blocks[0].instrs.insert(
        0, MirInstr(op=MirOp.SLOT, result=result, type_arg=mir_bool())
    );
    done = fn.new_block("cmp.done");
    left = self.lower_expr(nd.left);
    count = len(nd.ops);
    for (index, (op, right_nd)) in enumerate(zip(nd.ops, nd.rights)) {
        right = self.lower_expr(right_nd);
        verdict = self.compare_values(op.name, left, right, nd);
        b.store(result, verdict);
        if index + 1 < count {
            more = fn.new_block("cmp.next");
            b.cond_branch(verdict, more, done);
            b.position(more);
        } else {
            b.branch(done);
        }
        left = right;
    }
    b.position(done);
    return b.load(result, mir_bool());
}

impl MirLowering.compare_values(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    name = COMPARE_OPERATORS.get(op);
    if name is None {
        raise MirRefused(mir_refusal("comparison", op, site));
    }
    if not left.type.is_numeric() or not right.type.is_numeric() {
        raise MirRefused(
            mir_refusal(
                "comparison", f"{left.type.render()} {op} {right.type.render()}", site
            )
        );
    }
    (l, r) = self.unify_numeric(left, right, site);
    return self.builder().compare(name, l, r);
}

impl MirLowering.lower_unary(nd: uni.UnaryExpr) -> MirValue {
    b = self.builder();
    op = nd.op.name;
    if op == Tok.NOT {
        return b.logical_not(self.truthy(self.lower_expr(nd.operand), nd.operand));
    }
    value = self.lower_expr(nd.operand);
    if not value.type.is_numeric() {
        raise MirRefused(
            mir_refusal("unary operator", f"{op} on {value.type.render()}", nd)
        );
    }
    if op == Tok.PLUS {
        return value;
    }
    if op == Tok.MINUS {
        if value.type.kind == MirKind.FLOAT {
            return b.negate(value);
        }
        operand = b.convert(value, mir_int())
            if value.type.kind == MirKind.BOOL
            else value;
        zero = b.const_int(0, operand.type);
        self.raise_if(
            b.overflows("sub", zero, operand), "OverflowError", OVERFLOW_MESSAGE
        );
        return b.binary("sub", zero, operand);
    }
    if op == Tok.BW_NOT and value.type.kind != MirKind.FLOAT {
        operand = b.convert(value, mir_int())
            if value.type.kind == MirKind.BOOL
            else value;
        return b.binary("xor", operand, b.const_int(-1, operand.type));
    }
    raise MirRefused(mir_refusal("unary operator", op, nd));
}

impl MirLowering.lower_bool(nd: uni.BoolExpr) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    result_type = self.expr_type(nd);
    result = fn.new_value(result_type, "bool.result");
    fn.blocks[0].instrs.insert(
        0, MirInstr(op=MirOp.SLOT, result=result, type_arg=result_type)
    );
    done = fn.new_block("bool.done");
    is_and = nd.op.name == Tok.KW_AND;
    values = list(nd.values);
    for (index, operand_nd) in enumerate(values) {
        operand = self.lower_expr(operand_nd);
        b.store(result, self.coerce(operand, result_type, operand_nd));
        if index + 1 < len(values) {
            more = fn.new_block("bool.next");
            verdict = self.truthy(operand, operand_nd);
            if is_and {
                b.cond_branch(verdict, more, done);
            } else {
                b.cond_branch(verdict, done, more);
            }
            b.position(more);
        } else {
            b.branch(done);
        }
    }
    b.position(done);
    return b.load(result, result_type);
}

impl MirLowering.lower_call(nd: uni.FuncCall) -> MirValue {
    callee = nd.callee_decl;
    decl = self.decls.get(id(callee)) if callee is not None else None;
    if decl is None {
        name = nd.target.value
            if isinstance(nd.target, uni.Name)
            else type(nd.target).__name__;
        raise MirRefused(mir_refusal("call", name, nd));
    }
    args: list[MirValue] = [];
    params = list(nd.params or []);
    if len(params) != len(decl.params) {
        raise MirRefused(
            mir_refusal(
                "call", f"{self.name_of(decl.ability)} with {len(params)} arguments", nd
            )
        );
    }
    for (arg_nd, ptype) in zip(params, decl.params) {
        if isinstance(arg_nd, uni.KWPair) {
            raise MirRefused(mir_refusal("call argument", "keyword", arg_nd));
        }
        args.append(self.coerce(self.lower_expr(arg_nd), ptype, arg_nd));
    }
    result = self.builder().call(decl.symbol, args, decl.ret);
    if result is None {
        return self.builder().const_bool(False);
    }
    return result;
}

impl MirLowering.truthy(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    if value.type.kind == MirKind.BOOL {
        return value;
    }
    if value.type.kind == MirKind.INT {
        return b.compare("ne", value, b.const_int(0, value.type));
    }
    if value.type.kind == MirKind.FLOAT {
        return b.compare("ne", value, b.const_float(0.0, value.type));
    }
    raise MirRefused(mir_refusal("truth test", value.type.render(), site));
}

impl MirLowering.coerce(value: MirValue, to: MirType, site: uni.UniNode) -> MirValue {
    if value.type is to {
        return value;
    }
    if value.type.is_numeric() and to.is_numeric() {
        return self.builder().convert(value, to);
    }
    raise MirRefused(
        mir_refusal("conversion", f"{value.type.render()} to {to.render()}", site)
    );
}

impl MirLowering.unify_numeric(
    left: MirValue, right: MirValue, site: uni.UniNode
) -> tuple[MirValue, MirValue] {
    b = self.builder();
    l = b.convert(left, mir_int()) if left.type.kind == MirKind.BOOL else left;
    r = b.convert(right, mir_int()) if right.type.kind == MirKind.BOOL else right;
    if l.type.kind == MirKind.FLOAT or r.type.kind == MirKind.FLOAT {
        wide = mir_float(64);
        return (b.convert(l, wide), b.convert(r, wide));
    }
    if l.type is not r.type {
        raise MirRefused(
            mir_refusal(
                "integer operator layout",
                f"{l.type.render()} vs {r.type.render()}",
                site
            )
        );
    }
    return (l, r);
}

impl MirLowering.raise_if(cond: MirValue, exception: str, message: str) {
    b = self.builder();
    fn = self.st().fn;
    raise_bb = fn.new_block(f"raise.{exception}");
    ok_bb = fn.new_block("ok");
    b.cond_branch(cond, raise_bb, ok_bb);
    b.position(raise_bb);
    b.raise_builtin(exception, message);
    b.position(ok_bb);
}

impl MirLowering.name_of(ab: uni.Ability) -> str {
    name_ref = ab.name_ref;
    if name_ref is None {
        raise MirRefused(mir_refusal("function", "anonymous", ab));
    }
    return name_ref.sym_name;
}

impl MirLowering.ability_sym(ab: uni.Ability) -> uni.Symbol {
    name_ref = ab.name_ref;
    if name_ref is None or name_ref.sym is None {
        raise MirRefused(mir_refusal("function", "unresolved", ab));
    }
    return name_ref.sym;
}
