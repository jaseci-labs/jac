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
        ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, ab);
    }
    key = id(ab);
    self.decls[key] = MirDecl(
        ability=ab, symbol=self.symbol_of(ab), params=params, ret=ret
    );
    self.order.append(key);
}

impl MirLowering.symbol_of(ab: uni.Ability) -> str {
    return self.unit_symbol(self.name_of(ab), ab.access);
}

impl MirLowering.unit_symbol(name: str, access: (uni.SubTag[uni.Token] | None)) -> str {
    path = self.module.loc.mod_path;
    spelled = native_unit_spelling(name, path);
    is_pub = bool(access and access.tag.name == Tok.KW_PUB);
    bundled = native_unit_identity(path).startswith("jaclang/runtime/na_stdlib/");
    if is_pub and not bundled {
        return native_def_symbol(spelled);
    }
    return native_symbol_name(native_unit_prefix(path), spelled);
}

impl MirLowering.lower_function(decl: MirDecl) -> (MirFunction | None) {
    ab = decl.ability;
    fn = MirFunction(name=self.name_of(ab), symbol=decl.symbol, ret=decl.ret);
    first = fn.new_block("entry");
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        sig = ab.signature;
        body = ab.body;
        if isinstance(body, uni.ImplDef) {
            spec = body.spec;
            if not isinstance(spec, uni.FuncSignature) {
                raise MirRefused(mir_refusal("function", "impl signature", ab));
            }
            sig = spec;
            body = body.body;
        }
        if not isinstance(sig, uni.FuncSignature) {
            raise MirRefused(mir_refusal("function", "event ability", ab));
        }
        if not isinstance(body, (list, tuple)) {
            raise MirRefused(mir_refusal("function", "expression body", ab));
        }
        nodes = list(sig.posonly_params) + list(sig.params or []);
        if len(nodes) != len(decl.params) {
            raise MirRefused(mir_refusal("function", "impl parameters differ", ab));
        }
        declared = ab.signature;
        twins = list(declared.posonly_params) + list(declared.params or [])
            if isinstance(declared, uni.FuncSignature) and declared is not sig
            else [];
        for (index, (pv, ptype)) in enumerate(zip(nodes, decl.params)) {
            value = fn.new_value(ptype, pv.name.value);
            fn.params.append(MirParam(name=pv.name.value, value=value));
            slot = self.local_slot(pv.name.sym, pv);
            self.builder().store(slot, value);
            if index < len(twins) and twins[index].name.sym is not None {
                self.st().locals[id(twins[index].name.sym)] = slot;
            }
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
    return self.type_of(found, MirPosition.VALUE, site);
}

impl MirLowering.expr_type(nd: uni.Expr) -> MirType {
    return self.type_of(nd.type, MirPosition.VALUE, nd);
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
    if isinstance(target, uni.AtomTrailer)
        and nd.aug_op is None
        and nd.value is not None {
        place = self.lower_place(target);
        value = self.lower_expr(nd.value);
        self.builder().store(place, self.coerce(value, self.place_elem(place), nd));
        return;
    }
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
    made.is_slot = True;
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
    } elif isinstance(nd, uni.AtomTrailer) {
        value = self.lower_trailer(nd);
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
        folded = nd.ct_value;
        if isinstance(folded, CtInt) and not folded.mag {
            return self.builder().const_int(folded.small, self.expr_type(nd));
        }
        if isinstance(folded, CtBool) {
            return self.builder().const_bool(folded.value);
        }
        if isinstance(folded, CtFloat) {
            return self.builder().const_float(folded.value, self.expr_type(nd));
        }
        place = self.global_place(nd);
        if place is not None {
            return self.builder().load(place, self.place_elem(place));
        }
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
    if left.type.kind == MirKind.C_PTR and nd.op.name in (Tok.PLUS, Tok.MINUS) {
        if right.type.kind != MirKind.INT {
            raise MirRefused(
                mir_refusal("pointer arithmetic", right.type.render(), nd)
            );
        }
        offset = right
            if nd.op.name == Tok.PLUS
            else self.builder().binary(
                "sub", self.builder().const_int(0, right.type), right
            );
        return self.emit_value(MirOp.PTR_OFFSET, left.type, [left, offset]);
    }
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
    if op in (Tok.LSHIFT, Tok.RSHIFT) {
        shifted = b.convert(left, mir_int()) if left.type.kind == MirKind.BOOL else left;
        count = b.convert(right, mir_int()) if right.type.kind == MirKind.BOOL else right;
        return self.shift(op, shifted, count);
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

impl MirLowering.shift(op: str, left: MirValue, right: MirValue) -> MirValue {
    b = self.builder();
    t = left.type;
    name = "shl" if op == Tok.LSHIFT else "shr";
    if t.is_sized() or right.type.is_sized() {
        unsigned_count = b.convert(right, mir_int(right.type.width, False));
        self.raise_if(
            b.compare(
                "ge", unsigned_count, b.const_int(t.width, unsigned_count.type)
            ),
            "OverflowError",
            SHIFT_MESSAGE
        );
        count = b.convert(right, t);
        result = b.binary(name, left, count);
        if name == "shl" {
            self.raise_if(
                b.compare("ne", b.binary("shr", result, count), left),
                "OverflowError",
                OVERFLOW_MESSAGE
            );
        }
        return result;
    }
    self.raise_if(
        b.compare("lt", right, b.const_int(0, right.type)),
        "ValueError",
        NEGATIVE_SHIFT_MESSAGE
    );
    count = b.convert(right, t);
    unsigned_count = b.convert(count, mir_int(64, False));
    wide = b.compare("ge", unsigned_count, b.const_int(64, unsigned_count.type));
    safe = b.binary("and", count, b.const_int(63, t));
    result = b.binary(name, left, safe);
    if name == "shr" {
        return b.select(wide, b.binary("shr", left, b.const_int(63, t)), result);
    }
    self.raise_if(
        b.binary("and", wide, b.compare("ne", left, b.const_int(0, t))),
        "OverflowError",
        OVERFLOW_MESSAGE
    );
    lost = b.compare("ne", b.binary("shr", result, safe), left);
    self.raise_if(
        b.binary("and", b.logical_not(wide), lost), "OverflowError", OVERFLOW_MESSAGE
    );
    return b.select(wide, b.const_int(0, t), result);
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
    if left.type.kind == MirKind.C_PTR and right.type.kind == MirKind.C_PTR {
        li = self.emit_value(MirOp.PTR_INT, mir_int(64, False), [left]);
        ri = self.emit_value(MirOp.PTR_INT, mir_int(64, False), [right]);
        return self.builder().compare(name, li, ri);
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
    if decl is not None {
        args: list[MirValue] = [];
        params = self.call_args(nd);
        if len(params) != len(decl.params) {
            raise MirRefused(
                mir_refusal(
                    "call",
                    f"{self.name_of(decl.ability)} with {len(params)} arguments",
                    nd
                )
            );
        }
        for (arg_nd, ptype) in zip(params, decl.params) {
            args.append(self.coerce(self.lower_expr(arg_nd), ptype, arg_nd));
        }
        result = self.builder().call(decl.symbol, args, decl.ret);
        if result is None {
            return self.builder().const_bool(False);
        }
        return result;
    }
    if isinstance(callee, uni.Ability) and clib_import_of(callee) is not None {
        return self.c_call(nd, callee);
    }
    name = self.call_name(nd);
    if isinstance(nd.target, uni.Name) and INTRINSIC_REGISTRY.is_intrinsic(name) {
        return self.intrinsic_call(nd, name);
    }
    target = nd.target;
    if isinstance(target, uni.AtomTrailer) and target.is_attr {
        via_method = self.method_call(nd, target);
        if via_method is not None {
            return via_method;
        }
    }
    via_type = self.type_call(nd);
    if via_type is not None {
        return via_type;
    }
    raise MirRefused(mir_refusal("call", name or type(target).__name__, nd));
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
    if value.type.kind == MirKind.C_PTR {
        address = self.emit_value(MirOp.PTR_INT, mir_int(64, False), [value]);
        return b.compare("ne", address, b.const_int(0, address.type));
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

impl MirLowering.type_of(
    t: (TypeBase | None), position: MirPosition, site: uni.UniNode
) -> MirType {
    self.ensure_c_types(t);
    return mir_type_of(t, position, site);
}

impl MirLowering.ensure_c_types(t: (TypeBase | None)) {
    if t is None {
        return;
    }
    if isinstance(t, FunctionType) {
        for param in t.parameters {
            self.ensure_c_types(param.param_type);
        }
        self.ensure_c_types(t.return_type);
        return;
    }
    kind = c_builtin_kind(t);
    if kind in ("ptr", "PtrView") {
        self.ensure_c_types(c_type_arg(t));
        return;
    }
    arch = foreign_struct_of_type(t);
    if arch is None {
        return;
    }
    name = arch.name.value;
    if name in self.mir.structs {
        return;
    }
    made = MirStructDef(name=name);
    self.mir.structs[name] = made;
    evaluator = self.prog.get_type_evaluator();
    for hv in self.arch_fields(arch) {
        sym = hv.name.sym;
        if sym is None {
            raise MirRefused(mir_refusal("C struct field", hv.name.value, hv));
        }
        field_type = evaluator.get_type_of_symbol(sym);
        self.ensure_c_types(field_type);
        made.fields.append(
            MirStructField(
                name=hv.name.value,
                type=mir_type_of(field_type, MirPosition.C_FIELD, hv)
            )
        );
    }
}

impl MirLowering.arch_fields(arch: uni.Archetype) -> list[uni.HasVar] {
    found: list[uni.HasVar] = [];
    body = arch.body;
    if not isinstance(body, (list, tuple)) {
        return found;
    }
    for stmt in body {
        if isinstance(stmt, uni.ArchHas) and not stmt.is_static {
            for hv in stmt.vars {
                found.append(hv);
            }
        }
    }
    return found;
}

impl MirLowering.emit_value(
    op: MirOp,
    type: MirType,
    operands: list[MirValue],
    sub: str = "",
    callee: str = "",
    int_value: int = 0,
    str_value: str = ""
) -> MirValue {
    result = self.st().fn.new_value(type);
    self.builder().emit(
        MirInstr(
            op=op,
            result=result,
            operands=operands,
            sub=sub,
            callee=callee,
            int_value=int_value,
            str_value=str_value,
            type_arg=type
        )
    );
    return result;
}

impl MirLowering.place_elem(place: MirValue) -> MirType {
    if place.is_slot {
        return place.type;
    }
    if place.type.kind != MirKind.C_PTR {
        raise RuntimeError(f"MIR place {place.render()} is not addressable");
    }
    return place.type.payload();
}

impl MirLowering.lower_place(nd: uni.UniNode) -> MirValue {
    if isinstance(nd, uni.Name) {
        if nd.sym is None or id(nd.sym) not in self.st().locals {
            raise MirRefused(mir_refusal("place", nd.value, nd));
        }
        return self.st().locals[id(nd.sym)];
    }
    if isinstance(nd, uni.AtomUnit) {
        return self.lower_place(nd.value);
    }
    if not isinstance(nd, uni.AtomTrailer) {
        raise MirRefused(mir_refusal("place", type(nd).__name__, nd));
    }
    if nd.is_attr {
        right = nd.right;
        if not isinstance(right, uni.Name) {
            raise MirRefused(mir_refusal("attribute", type(right).__name__, nd));
        }
        base = self.lower_place(nd.target);
        holder = self.place_elem(base);
        if holder.kind != MirKind.C_STRUCT {
            raise MirRefused(mir_refusal("attribute access", holder.render(), nd));
        }
        layout = self.mir.structs[holder.name];
        index = layout.index_of(right.value);
        return self.emit_value(
            MirOp.FIELD_ADDR,
            mir_c_ptr(layout.fields[index].type),
            [self.coerce_place(base)],
            int_value=index
        );
    }
    right = nd.right;
    if not isinstance(right, uni.IndexSlice)
        or right.is_range
        or len(right.slices) != 1 {
        raise MirRefused(mir_refusal("subscript", type(right).__name__, nd));
    }
    view = self.lower_expr(nd.target);
    if view.type.kind != MirKind.C_VIEW {
        raise MirRefused(mir_refusal("subscript", view.type.render(), nd));
    }
    start = right.slices[0].start;
    if start is None {
        raise MirRefused(mir_refusal("subscript", "missing index", nd));
    }
    position = self.lower_expr(start);
    if position.type.kind != MirKind.INT {
        raise MirRefused(mir_refusal("subscript index", position.type.render(), nd));
    }
    b = self.builder();
    length = self.emit_value(MirOp.VIEW_LEN, mir_int(), [view]);
    below = b.compare("lt", position, b.const_int(0, position.type));
    beyond = b.compare("ge", position, length);
    self.raise_if(below, "IndexError", "view index out of range");
    self.raise_if(beyond, "IndexError", "view index out of range");
    return self.emit_value(
        MirOp.ELEM_ADDR, mir_c_ptr(view.type.payload()), [view, position]
    );
}

impl MirLowering.lower_trailer(nd: uni.AtomTrailer) -> MirValue {
    place = self.lower_place(nd);
    return self.builder().load(place, self.place_elem(place));
}

impl MirLowering.call_name(nd: uni.FuncCall) -> str {
    target = nd.target;
    if isinstance(target, uni.Name) {
        return target.value;
    }
    if isinstance(target, uni.AtomTrailer) and isinstance(target.right, uni.Name) {
        return target.right.value;
    }
    return "";
}

impl MirLowering.call_args(nd: uni.FuncCall) -> list[uni.Expr] {
    args: list[uni.Expr] = [];
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) {
            raise MirRefused(mir_refusal("call argument", "keyword", arg));
        }
        args.append(arg);
    }
    return args;
}

impl MirLowering.c_call(nd: uni.FuncCall, callee: uni.Ability) -> MirValue {
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(
        self.ability_sym(callee)
    );
    if not isinstance(fn_type, FunctionType) {
        raise MirRefused(mir_refusal("C call", self.name_of(callee), nd));
    }
    self.ensure_c_types(fn_type);
    params = [
        mir_type_of(p.param_type, MirPosition.C_FIELD, nd) for p in fn_type.parameters
    ];
    ret = mir_type_of(fn_type.return_type, MirPosition.C_FIELD, nd);
    symbol = self.name_of(callee);
    self.mir.externs[symbol] = MirExtern(symbol=symbol, ret=ret, params=params);
    args = self.call_args(nd);
    if len(args) != len(params) {
        raise MirRefused(
            mir_refusal("C call", f"{symbol} with {len(args)} arguments", nd)
        );
    }
    values = [
        self.coerce(self.lower_expr(arg), ptype, arg)
        for (arg, ptype) in zip(args, params)
    ];
    result_type = mir_none() if ret.kind in (MirKind.NONE, MirKind.VOID) else ret;
    return self.emit_value(MirOp.CALL_C, result_type, values, callee=symbol);
}

impl MirLowering.intrinsic_call(nd: uni.FuncCall, name: str) -> MirValue {
    args = self.call_args(nd);
    if name == "__thread_local_block" {
        label = c_string_literal(args[0]) if args else None;
        (ok, size) = c_scalar_constant(args[1]) if len(args) == 2 else (False, None);
        if not label or not ok or not isinstance(size, int) or size <= 0 {
            raise MirRefused(
                mir_refusal(
                    "intrinsic",
                    name,
                    nd,
                    "The block is named by a string literal and sized by a positive constant.",
                    "E5095"
                )
            );
        }
        self.mir.tls_blocks[label] = max(self.mir.tls_blocks.get(label, 0), size);
        return self.emit_value(
            MirOp.TLS_BLOCK, mir_int(64), [], str_value=label, int_value=size
        );
    }
    found = INTRINSIC_REGISTRY.get(name);
    if found is None or len(args) != found.arity() {
        raise MirRefused(mir_refusal("intrinsic", name, nd, code="E5095"));
    }
    dispatch = found.dispatch;
    result_type = mir_spec_type(found.result_spec);
    if dispatch == IntrinsicDispatch.MEM_LOAD {
        address = self.intrinsic_operand(args[0], "i64");
        return self.emit_value(MirOp.MEM_LOAD, result_type, [address]);
    }
    if dispatch == IntrinsicDispatch.MEM_STORE {
        address = self.intrinsic_operand(args[0], "i64");
        value = self.intrinsic_operand(args[1], found.param_specs[1]);
        return self.emit_value(MirOp.MEM_STORE, mir_none(), [address, value]);
    }
    if dispatch in (IntrinsicDispatch.FLOAT_BITS, IntrinsicDispatch.BITS_FLOAT) {
        value = self.intrinsic_operand(args[0], found.param_specs[0]);
        return self.emit_value(MirOp.BITCAST, result_type, [value]);
    }
    if dispatch == IntrinsicDispatch.ATOMIC_FENCE {
        order = self.memory_order(nd, args[0], "fence");
        return self.emit_value(MirOp.FENCE, mir_none(), [], str_value=order);
    }
    if dispatch == IntrinsicDispatch.ATOMIC_XCHG {
        address = self.intrinsic_operand(args[0], "i64");
        value = self.intrinsic_operand(args[1], "i64");
        return self.emit_value(
            MirOp.ATOMIC_RMW,
            result_type,
            [address, value],
            sub="xchg",
            str_value="seq_cst"
        );
    }
    if dispatch == IntrinsicDispatch.ATOMIC_LOAD {
        address = self.intrinsic_operand(args[0], "i64");
        order = self.memory_order(nd, args[1], "load");
        return self.emit_value(
            MirOp.ATOMIC_LOAD, result_type, [address], str_value=order
        );
    }
    if dispatch == IntrinsicDispatch.ATOMIC_STORE {
        address = self.intrinsic_operand(args[0], "i64");
        value = self.intrinsic_operand(args[1], found.param_specs[1]);
        order = self.memory_order(nd, args[2], "store");
        return self.emit_value(
            MirOp.ATOMIC_STORE, mir_none(), [address, value], str_value=order
        );
    }
    if dispatch == IntrinsicDispatch.ATOMIC_CAS {
        address = self.intrinsic_operand(args[0], "i64");
        expected = self.intrinsic_operand(args[1], found.param_specs[1]);
        desired = self.intrinsic_operand(args[2], found.param_specs[2]);
        order = self.memory_order(nd, args[3], "rmw");
        return self.emit_value(
            MirOp.ATOMIC_CAS,
            result_type,
            [address, expected, desired],
            str_value=order
        );
    }
    if dispatch == IntrinsicDispatch.ATOMIC_RMW {
        address = self.intrinsic_operand(args[0], "i64");
        value = self.intrinsic_operand(args[1], found.param_specs[1]);
        order = self.memory_order(nd, args[2], "rmw");
        operation = name[len("__atomic_"):].rsplit("_i", 1)[0];
        return self.emit_value(
            MirOp.ATOMIC_RMW,
            result_type,
            [address, value],
            sub="xchg" if operation == "swap" else operation,
            str_value=order
        );
    }
    raise MirRefused(mir_refusal("intrinsic", name, nd));
}

impl MirLowering.intrinsic_operand(arg: uni.Expr, spec: str) -> MirValue {
    value = self.lower_expr(arg);
    if value.type.kind == MirKind.C_PTR and spec == "i64" {
        return self.emit_value(MirOp.PTR_INT, mir_int(64, True, True), [value]);
    }
    return self.coerce(value, mir_spec_type(spec), arg);
}

impl MirLowering.memory_order(nd: uni.FuncCall, arg: uni.Expr, kind: str) -> str {
    (ok, value) = c_scalar_constant(arg);
    if not ok
        or not isinstance(value, int)
        or value < 0
        or value >= len(MEMORY_ORDERS) {
        raise MirRefused(
            mir_refusal(
                "intrinsic",
                self.call_name(nd),
                arg,
                "The memory order is a constant from 0 (relaxed) to 5 (seq_cst).",
                "E5095"
            )
        );
    }
    order = MEMORY_ORDERS[value];
    if (kind == "load" and order in ("release", "acq_rel"))
        or (kind == "store" and order in ("acquire", "acq_rel")) {
        raise MirRefused(
            mir_refusal(
                "intrinsic",
                self.call_name(nd),
                arg,
                f"A {kind} cannot use memory order {value}.",
                "E5095"
            )
        );
    }
    return order;
}

impl MirLowering.type_call(nd: uni.FuncCall) -> (MirValue | None) {
    result_type = self.expr_type(nd);
    args = self.call_args(nd);
    if result_type.kind == MirKind.C_PTR {
        if not args {
            return self.emit_value(MirOp.PTR_NULL, result_type, []);
        }
        source = args[0];
        if isinstance(source, (uni.String, uni.MultiString)) {
            text = c_string_literal(source);
            if text is None {
                raise MirRefused(mir_refusal("C string", "not a literal", source));
            }
            return self.emit_value(MirOp.CSTR, result_type, [], str_value=text);
        }
        value = self.lower_expr(source);
        if value.type.kind in (MirKind.INT, MirKind.C_PTR) {
            return self.emit_value(MirOp.PTR_CAST, result_type, [value]);
        }
        raise MirRefused(mir_refusal("pointer cast", value.type.render(), nd));
    }
    if result_type.is_numeric() and len(args) == 1 {
        value = self.lower_expr(args[0]);
        if value.type.kind == MirKind.C_PTR and result_type.kind == MirKind.INT {
            return self.emit_value(MirOp.PTR_INT, result_type, [value]);
        }
        if value.type.is_numeric() {
            return self.builder().convert(value, result_type);
        }
    }
    return None;
}

impl MirLowering.method_call(
    nd: uni.FuncCall, target: uni.AtomTrailer
) -> (MirValue | None) {
    right = target.right;
    if not isinstance(right, uni.Name) {
        return None;
    }
    receiver_type = self.expr_type(target.target)
        if isinstance(target.target, uni.Expr)
        else mir_void();
    if receiver_type.kind == MirKind.C_PTR {
        receiver = self.lower_expr(target.target);
        args = self.call_args(nd);
        if right.value == "view" and len(args) == 1 {
            count = self.lower_expr(args[0]);
            return self.emit_value(
                MirOp.VIEW, mir_c_view(receiver.type.payload()), [receiver, count]
            );
        }
        if right.value == "is_null" and not args {
            address = self.emit_value(MirOp.PTR_INT, mir_int(64, False), [receiver]);
            return self.builder().compare(
                "eq", address, self.builder().const_int(0, address.type)
            );
        }
        return None;
    }
    if receiver_type.kind == MirKind.C_STRUCT {
        place = self.lower_place(target);
        field_type = self.place_elem(place);
        if field_type.kind != MirKind.C_FN {
            return None;
        }
        fnptr = self.builder().load(place, field_type);
        params = field_type.args[1:];
        args = self.call_args(nd);
        if len(args) != len(params) {
            raise MirRefused(
                mir_refusal("call", f"{right.value} with {len(args)} arguments", nd)
            );
        }
        values = [
            self.coerce(self.lower_expr(arg), ptype, arg)
            for (arg, ptype) in zip(args, params)
        ];
        ret = field_type.args[0];
        result_type = mir_none() if ret.kind in (MirKind.NONE, MirKind.VOID) else ret;
        return self.emit_value(MirOp.CALL_FNPTR, result_type, [fnptr] + values);
    }
    return None;
}

impl MirLowering.coerce_place(place: MirValue) -> MirValue {
    if not place.is_slot {
        return place;
    }
    return self.emit_value(MirOp.PTR_CAST, mir_c_ptr(place.type), [place]);
}

impl MirLowering.global_declaration(sym: uni.Symbol) -> (uni.Assignment | None) {
    cursor: (uni.UniNode | None) = sym.decl;
    while cursor is not None and not isinstance(cursor, uni.Assignment) {
        cursor = cursor.parent;
    }
    if isinstance(cursor, uni.Assignment)
        and isinstance(cursor.parent, uni.GlobalVars) {
        return cursor;
    }
    return None;
}

impl MirLowering.global_place(nd: uni.Name) -> (MirValue | None) {
    sym = nd.sym;
    if sym is None {
        return None;
    }
    declaration = self.global_declaration(sym);
    if declaration is None {
        return None;
    }
    found = self.mir.globals.get(sym.sym_name);
    if found is None {
        value_type = self.symbol_type(sym, nd);
        group = declaration.parent;
        access = group.access if isinstance(group, uni.GlobalVars) else None;
        is_priv = bool(access and access.tag.name == Tok.KW_PRIV);
        made = MirGlobal(
            name=sym.sym_name,
            symbol=self.unit_symbol(sym.sym_name, access),
            type=value_type,
            linkage="internal" if is_priv else ""
        );
        initial = declaration.value;
        if isinstance(initial, uni.Int) and value_type.kind == MirKind.INT {
            bits = uni.int_literal_i64(initial.value);
            if bits is None {
                raise MirRefused(
                    mir_refusal("integer literal", initial.value, initial)
                );
            }
            made.int_value = bits;
        } elif isinstance(initial, uni.Float) and value_type.kind == MirKind.FLOAT {
            made.float_value = float(initial.value);
        } elif isinstance(initial, uni.Bool) and value_type.kind == MirKind.BOOL {
            made.int_value = 1 if initial.value.lower() in ("true", "1") else 0;
        } else {
            raise MirRefused(
                mir_refusal(
                    "global initializer",
                    sym.sym_name,
                    declaration,
                    "Only literal global initializers lower so far."
                )
            );
        }
        self.mir.globals[sym.sym_name] = made;
        found = made;
    }
    return self.emit_value(
        MirOp.GLOBAL_ADDR, mir_c_ptr(found.type), [], str_value=found.symbol
    );
}
