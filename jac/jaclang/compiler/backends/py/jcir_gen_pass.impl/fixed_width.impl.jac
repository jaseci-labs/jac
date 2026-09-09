impl JcirGenPass._apply_coercion(nd: Expr) -> None {
    target = nd.coerce_to;
    got = self.outs(nd);
    if target is None or len(got) != 1 or not isinstance(got[0], CgNode) {
        return;
    }
    parent = nd.parent;
    if (
        isinstance(parent, FuncCall)
        and isinstance(parent.target, Name)
        and parent.target.sym_name == target
        and parent.params is not None
        and len(parent.params) == 1
    ) {
        return;
    }
    row = shape_of(target);
    if row is None or not row.is_float {
        return;
    }
    if target == "f32" {
        self._fw_wrap_call(nd, "_fw_r_f32", [got[0]]);
        return;
    }
    src = shape_of(nd.fw) if nd.fw is not None else None;
    if src is not None and src.is_float {
        return;
    }
    self.set_out(
        nd, [self.call_node(self.name_load('float'), [got[0]], [], jac_node=nd)]
    );
}

impl JcirGenPass._fw_helper(name: str) -> CgNode {
    self.sized_imports.add(name);
    return self.name_load(name);
}

impl JcirGenPass._fw_call_node(helper: str, args: list, jac_node: UniNode) -> CgNode {
    return self.call_node(self._fw_helper(helper), args, [], jac_node=jac_node);
}

impl JcirGenPass._fw_wrap_call(nd: Expr, helper: str, args: list) -> None {
    self.set_out(nd, [self._fw_call_node(helper, args, nd)]);
}

impl JcirGenPass._apply_fw(nd: Expr) -> None {
    if isinstance(nd, FuncCall) {
        self._fw_call(nd);
        return;
    }
    name = nd.fw;
    if name is None {
        return;
    }
    if isinstance(nd, BinaryExpr) {
        self._fw_binary(nd, name);
    } elif isinstance(nd, UnaryExpr) {
        self._fw_unary(nd, name);
    }
}

impl JcirGenPass._fw_binary(nd: BinaryExpr, name: str) -> None {
    if not isinstance(nd.op, Token) {
        return;
    }
    got = self.outs(nd);
    if len(got) != 1 or not isinstance(got[0], CgNode) or got[0].cls != 'BinOp' {
        return;
    }
    row = shape_of(name);
    if row is None {
        return;
    }
    out = self._fw_checked(
        name, nd.op.name, self.val(nd.left), self.val(nd.right), got[0], nd
    );
    if out is not None {
        self.set_out(nd, [out]);
    }
}

impl JcirGenPass._fw_checked(
    name: str, op: str, left: CgNode, right: CgNode, op_node: any, jac_node: UniNode
) -> (CgNode | None) {
    row = shape_of(name);
    if row is None or not row.sized {
        return None;
    }
    if isinstance(jac_node, Expr) and jac_node.fw_safe and op in FW_ELIDABLE_OPS {
        return None;
    }
    if row.is_float {
        if row.width != 32 {
            return None;
        }
        return self._fw_call_node("_fw_r_f32", [op_node], jac_node);
    }
    if op in (Tok.PLUS, Tok.MINUS, Tok.STAR_MUL, Tok.FLOOR_DIV) {
        return self._fw_call_node(f"_fw_ck_{name}", [op_node], jac_node);
    }
    if op == Tok.STAR_POW {
        return self._fw_call_node(f"_fw_pow_{name}", [left, right], jac_node);
    }
    if op == Tok.LSHIFT {
        return self._fw_call_node(f"_fw_shl_{name}", [left, right], jac_node);
    }
    if op == Tok.RSHIFT {
        return self._fw_call_node(f"_fw_shr_{name}", [left, right], jac_node);
    }
    return None;
}

impl JcirGenPass._fw_as_load(item: any) -> any {
    if isinstance(item, list) {
        return [self._fw_as_load(x) for x in item];
    }
    if not isinstance(item, CgNode) {
        return item;
    }
    copy = self.nod(item.cls, list(item.keys), [], jac_node=item.jac_src);
    copy.vals = [
        self.nod('Load', [], [], jac_node=item.jac_src)
            if (item.keys[i] == 'ctx')
            else self._fw_as_load(item.vals[i]) for i in range(len(item.keys))
    ];
    return copy;
}

impl JcirGenPass._fw_aug_assign(
    nd: Assignment, target: any, value: any
) -> (CgNode | None) {
    tgt = nd.target[0] if nd.target else None;
    if (
        not isinstance(tgt, Expr)
        or tgt.fw is None
        or nd.aug_op is None
        or not isinstance(target, CgNode)
        or not isinstance(value, CgNode)
    ) {
        return None;
    }
    base = FW_AUG_TO_BIN.get(nd.aug_op.name, None);
    if base is None {
        return None;
    }
    load = self._fw_as_load(target);
    binop = self.nod(
        'BinOp',
        ['left', 'op', 'right'],
        [load, self.val(nd.aug_op), value],
        jac_node=nd
    );
    checked = self._fw_checked(tgt.fw, base, load, value, binop, nd);
    if checked is None {
        return None;
    }
    return self.nod('Assign', ['targets', 'value'], [[target], checked], jac_node=nd);
}

impl JcirGenPass._fw_unary(nd: UnaryExpr, name: str) -> None {
    if not isinstance(nd.op, Token) {
        return;
    }
    got = self.outs(nd);
    if len(got) != 1 or not isinstance(got[0], CgNode) {
        return;
    }
    row = shape_of(name);
    if row is None or not row.sized {
        return;
    }
    op = nd.op.name;
    if row.is_float {
        if row.width == 32 and op == Tok.MINUS {
            self._fw_wrap_call(nd, "_fw_r_f32", [got[0]]);
        }
        return;
    }
    if op == Tok.MINUS {
        if not nd.fw_safe {
            self._fw_wrap_call(nd, f"_fw_ck_{name}", [got[0]]);
        }
    } elif op == Tok.BW_NOT and not row.signed {
        self._fw_wrap_call(nd, f"_fw_inv_{name}", [self.val(nd.operand)]);
    }
}

impl JcirGenPass._fw_call(nd: FuncCall) -> None {
    callee = nd.target;
    if not isinstance(callee, Name) {
        return;
    }
    args = [
        a
        for a in (nd.params or [])
        if isinstance(a, Expr)
    ];
    if len(args) != len(nd.params or []) {
        return;
    }
    if callee.sym_name == "abs" and len(args) == 1 {
        name = nd.fw or args[0].fw;
        row = shape_of(name) if name is not None else None;
        if row is None or not row.sized or row.is_float or name is None {
            return;
        }
        got = self.outs(nd);
        if len(got) == 1 and isinstance(got[0], CgNode) {
            self._fw_wrap_call(nd, f"_fw_ck_{name}", [got[0]]);
        }
        return;
    }
    op = FW_WRAPPING_OPS.get(callee.sym_name, None);
    if op is None {
        return;
    }
    name = nd.fw or (args[0].fw if args else None);
    row = shape_of(name) if name is not None else None;
    if row is None or not row.sized or row.is_float or name is None {
        return;
    }
    call_args: list = [
        self.const_of(name, jac_node=nd),
        self.const_of(op, jac_node=nd)
    ];
    for a in args {
        call_args.append(self.val(a));
    }
    self._fw_wrap_call(nd, "_fw_wrapping", call_args);
}
