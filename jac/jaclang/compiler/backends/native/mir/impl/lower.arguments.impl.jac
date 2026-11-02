impl MirLowering.bound_args(
    nd: uni.FuncCall, ab: uni.Ability, method: bool
) -> list[(uni.Expr | MirPacked)] {
    sig = ab.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return self.call_args(nd);
    }
    posonly = [
        pv
        for pv in sig.posonly_params
        if not (method and pv.name.value == "self")
    ];
    params = posonly
        + [
            pv
            for pv in list(sig.params or [])
            if not (method and pv.name.value == "self")
        ];
    keyword_ok = {id(pv) for pv in params} - {id(pv) for pv in posonly};
    positional: list[uni.Expr] = [];
    named: dict[str, uni.Expr] = {};
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) {
            if arg.key is None {
                raise MirRefused(
                    mir_refusal("call argument", "keyword unpacking", arg)
                );
            }
            named[arg.key.sym_name] = arg.value;
        } elif isinstance(arg, uni.UnaryExpr)
            and arg.op.name in (Tok.STAR_MUL, Tok.STAR_POW) {
            raise MirRefused(mir_refusal("call argument", "argument unpacking", arg));
        } else {
            positional.append(arg);
        }
    }
    if len(positional) > len(params) and sig.varargs is None {
        raise MirRefused(
            mir_refusal(
                "call", f"{self.name_of(ab)} with {len(positional)} arguments", nd
            )
        );
    }
    bound: list[(uni.Expr | MirPacked)] = [];
    for (index, pv) in enumerate(params) {
        name = pv.name.value;
        if index < len(positional) {
            if name in named and id(pv) in keyword_ok {
                raise MirRefused(
                    mir_refusal("call", f"{self.name_of(ab)} got {name} twice", nd)
                );
            }
            bound.append(positional[index]);
        } else {
            bound.append(self.bind_by_name(ab, pv, named, id(pv) in keyword_ok, nd));
        }
    }
    if sig.varargs is not None {
        bound.append(MirPacked(items=positional[len(params):], site=nd));
    }
    for pv in list(sig.kwonlyargs or []) {
        bound.append(self.bind_by_name(ab, pv, named, True, nd));
    }
    if sig.kwargs is not None {
        names = sorted(named);
        bound.append(
            MirPacked(
                keyword=True,
                items=[named.pop(key) for key in names],
                names=names,
                site=nd
            )
        );
    }
    if named {
        raise MirRefused(
            mir_refusal(
                "call", f"{self.name_of(ab)} has no parameter {sorted(named)[0]}", nd
            )
        );
    }
    return bound;
}

impl MirLowering.bind_by_name(
    ab: uni.Ability,
    pv: uni.ParamVar,
    named: dict[str, uni.Expr],
    keyword_ok: bool,
    nd: uni.FuncCall
) -> uni.Expr {
    name = pv.name.value;
    if name in named and keyword_ok {
        return named.pop(name);
    }
    if pv.value is not None and self.constant_default(pv.value) {
        return pv.value;
    }
    raise MirRefused(
        mir_refusal(
            "call",
            f"{self.name_of(ab)} missing {name}",
            nd,
            "Native calls fill omitted arguments only from constant defaults."
        )
    );
}

impl MirLowering.bound_value(arg: (uni.Expr | MirPacked), ptype: MirType) -> MirValue {
    if not isinstance(arg, MirPacked) {
        return self.coerce(self.lower_expr(arg), ptype, arg);
    }
    b = self.builder();
    if not arg.keyword {
        if ptype.kind != MirKind.LIST {
            raise MirRefused(
                mir_refusal("call argument", f"*args as {ptype.render()}", arg.site)
            );
        }
        elem = ptype.payload();
        made = self.spill(self.new_list(elem, max(len(arg.items), 4)));
        kind = b.const_int(self.elem_kind(elem, arg.site), mir_int());
        for item in arg.items {
            self.runtime(
                "__jac_rt_list_push",
                [made, self.to_bits(self.lower_expr(item), elem, item), kind]
            );
        }
        return made;
    }
    if ptype.kind != MirKind.DICT {
        raise MirRefused(
            mir_refusal("call argument", f"**kwargs as {ptype.render()}", arg.site)
        );
    }
    (key, value) = (ptype.args[0], ptype.args[1]);
    made = self.spill(self.new_dict(key, value, ptype));
    key_kind = b.const_int(self.elem_kind(key, arg.site), mir_int());
    value_kind = b.const_int(self.elem_kind(value, arg.site), mir_int());
    for (name, item) in zip(arg.names, arg.items) {
        key_bits = self.to_bits(b.const_str(name, mir_str()), key, arg.site);
        self.runtime(
            "__jac_rt_dict_set",
            [
                made,
                key_bits,
                self.to_bits(self.lower_expr(item), value, item),
                key_kind,
                value_kind
            ]
        );
    }
    return made;
}

impl MirLowering.constant_default(value: (uni.Expr | None)) -> bool {
    if value is None {
        return False;
    }
    if isinstance(value, (uni.Int, uni.Float, uni.Bool, uni.Null)) {
        return True;
    }
    if isinstance(value, uni.String) and isinstance(value.lit_value, str) {
        return True;
    }
    if isinstance(value, uni.UnaryExpr) and value.op.name == Tok.MINUS {
        return isinstance(value.operand, (uni.Int, uni.Float));
    }
    return isinstance(value.ct_value, (CtInt, CtBool, CtFloat));
}

impl MirLowering.param_nodes(
    sig: uni.FuncSignature, skip_self: bool
) -> list[uni.ParamVar] {
    found = [
        pv
        for pv in list(sig.posonly_params) + list(sig.params or [])
        if not skip_self or pv.name.value != "self"
    ];
    if sig.varargs is not None {
        found.append(sig.varargs);
    }
    found.extend(list(sig.kwonlyargs or []));
    if sig.kwargs is not None {
        found.append(sig.kwargs);
    }
    return found;
}
