impl MirLowering.bound_args(
    nd: uni.FuncCall, ab: uni.Ability, method: bool
) -> list[uni.Expr] {
    sig = ab.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return self.call_args(nd);
    }
    posonly = [pv for pv in sig.posonly_params if not (method and pv.name.value == "self")];
    params = posonly
        + [pv for pv in list(sig.params or []) if not (method and pv.name.value == "self")];
    keyword_ok = {id(pv) for pv in params} - {id(pv) for pv in posonly};
    positional: list[uni.Expr] = [];
    named: dict[str, uni.Expr] = {};
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) {
            if arg.key is None {
                raise MirRefused(mir_refusal("call argument", "keyword unpacking", arg));
            }
            named[arg.key.sym_name] = arg.value;
        } elif isinstance(arg, uni.UnaryExpr) and arg.op.name in (Tok.STAR_MUL, Tok.STAR_POW) {
            raise MirRefused(mir_refusal("call argument", "argument unpacking", arg));
        } else {
            positional.append(arg);
        }
    }
    if len(positional) > len(params) {
        raise MirRefused(
            mir_refusal("call", f"{self.name_of(ab)} with {len(positional)} arguments", nd)
        );
    }
    bound: list[uni.Expr] = [];
    for (index, pv) in enumerate(params) {
        name = pv.name.value;
        if index < len(positional) {
            if name in named and id(pv) in keyword_ok {
                raise MirRefused(
                    mir_refusal("call", f"{self.name_of(ab)} got {name} twice", nd)
                );
            }
            bound.append(positional[index]);
        } elif name in named and id(pv) in keyword_ok {
            bound.append(named.pop(name));
        } elif self.constant_default(pv.value) {
            bound.append(pv.value);
        } else {
            raise MirRefused(
                mir_refusal(
                    "call",
                    f"{self.name_of(ab)} missing {name}",
                    nd,
                    "Native calls fill omitted arguments only from constant defaults."
                )
            );
        }
    }
    if named {
        raise MirRefused(
            mir_refusal("call", f"{self.name_of(ab)} has no parameter {sorted(named)[0]}", nd)
        );
    }
    return bound;
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

impl MirLowering.param_nodes(sig: uni.FuncSignature, skip_self: bool) -> list[uni.ParamVar] {
    if sig.varargs is not None or sig.kwargs is not None or sig.kwonlyargs {
        raise MirRefused(
            mir_refusal("function", "variadic or keyword-only parameters", sig)
        );
    }
    return [
        pv
        for pv in list(sig.posonly_params) + list(sig.params or [])
        if not skip_self or pv.name.value != "self"
    ];
}
