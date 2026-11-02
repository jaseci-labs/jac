impl MirLowering.bound_args(
    nd: uni.FuncCall, ab: uni.Ability, method: bool, leading: int = 0
) -> list[(uni.Expr | MirPacked | MirBound)] {
    sig = ab.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return self.call_args(nd);
    }
    if self.has_spread(nd) {
        return self.spread_args(nd, ab, sig, method);
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
    positional = positional[leading:];
    if len(positional) > len(params) and sig.varargs is None {
        raise MirRefused(
            mir_refusal(
                "call", f"{self.name_of(ab)} with {len(positional)} arguments", nd
            )
        );
    }
    bound: list[(uni.Expr | MirPacked | MirBound)] = [];
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

impl MirLowering.has_spread(nd: uni.FuncCall) -> bool {
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) and arg.key is None {
            return True;
        }
        if isinstance(arg, uni.UnaryExpr)
            and arg.op.name in (Tok.STAR_MUL, Tok.STAR_POW) {
            return True;
        }
    }
    return False;
}

impl MirLowering.spread_args(
    nd: uni.FuncCall, ab: uni.Ability, sig: uni.FuncSignature, method: bool
) -> list[(uni.Expr | MirPacked | MirBound)] {
    b = self.builder();
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
    kwonly = list(sig.kwonlyargs or []);
    keyword_ok = {id(pv) for pv in params + kwonly} - {id(pv) for pv in posonly};
    positional: list[MirBound] = [];
    named: dict[str, MirBound] = {};
    spreads: list[MirBound] = [];
    sink_names: list[str] = [];
    sink_items: list[(uni.Expr | MirBound)] = [];
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) and arg.key is not None {
            held = MirBound(
                value=self.spill(self.lower_expr(arg.value)), site=arg.value
            );
            named[arg.key.sym_name] = held;
            sink_names.append(arg.key.sym_name);
            sink_items.append(held);
            continue;
        }
        source: (uni.Expr | None) = None;
        if isinstance(arg, uni.KWPair) {
            source = arg.value;
        } elif isinstance(arg, uni.UnaryExpr) and arg.op.name == Tok.STAR_POW {
            source = arg.operand;
        }
        if source is not None {
            spread = MirBound(value=self.spill(self.lower_expr(source)), site=source);
            keys = spread.value.type;
            if keys.kind != MirKind.DICT
                or keys.args[0].kind not in (MirKind.STR, MirKind.STR_REF) {
                raise MirRefused(
                    mir_refusal("call argument", f"** of {keys.render()}", arg)
                );
            }
            spreads.append(spread);
            sink_names.append("");
            sink_items.append(spread);
            continue;
        }
        if isinstance(arg, uni.UnaryExpr) and arg.op.name == Tok.STAR_MUL {
            spread_value = self.spill(self.lower_expr(arg.operand));
            if spread_value.type.kind == MirKind.TUPLE {
                for index in range(len(spread_value.type.args)) {
                    positional.append(
                        MirBound(
                            value=self.tuple_get(spread_value, index), site=arg.operand
                        )
                    );
                }
                continue;
            }
            if len(positional) < len(params) or sig.varargs is None {
                raise MirRefused(
                    mir_refusal("call argument", "argument unpacking", arg)
                );
            }
            positional.append(
                MirBound(value=spread_value, site=arg.operand, star=True)
            );
            continue;
        }
        positional.append(MirBound(value=self.spill(self.lower_expr(arg)), site=arg));
    }
    if len(positional) > len(params) and sig.varargs is None {
        raise MirRefused(
            mir_refusal(
                "call", f"{self.name_of(ab)} with {len(positional)} arguments", nd
            )
        );
    }
    matched = self.temp_slot(mir_int());
    b.store(matched, b.const_int(0, mir_int()));
    bindable: list[str] = [];
    bound: list[(uni.Expr | MirPacked | MirBound)] = [];
    for (index, pv) in enumerate(params + kwonly) {
        name = pv.name.value;
        can_name = id(pv) in keyword_ok;
        if can_name {
            bindable.append(name);
        }
        given: (MirBound | None) = None;
        if index < len(params) and index < len(positional) {
            if name in named and can_name {
                raise MirRefused(
                    mir_refusal("call", f"{self.name_of(ab)} got {name} twice", nd)
                );
            }
            given = positional[index];
        } elif name in named and can_name {
            given = named[name];
        }
        if can_name {
            bound.append(self.bind_from_spreads(pv, given, spreads, matched, ab, nd));
        } elif given is not None {
            bound.append(given);
        } else {
            bound.append(self.bind_by_name(ab, pv, {}, False, nd));
        }
        if index + 1 == len(params) and sig.varargs is not None {
            bound.append(MirPacked(items=positional[len(params):], site=nd));
        }
    }
    if not params and sig.varargs is not None {
        bound.insert(0, MirPacked(items=list(positional), site=nd));
    }
    if sig.kwargs is not None {
        names: list[str] = [];
        items: list[(uni.Expr | MirBound)] = [];
        for (name, item) in zip(sink_names, sink_items) {
            if name and name in bindable {
                continue;
            }
            names.append(name);
            items.append(item);
        }
        bound.append(
            MirPacked(
                keyword=True,
                items=items,
                names=names,
                bindable=bindable,
                unique=True,
                site=nd
            )
        );
        return bound;
    }
    unknown = [
        name
        for name in named
        if name not in bindable
    ];
    if unknown {
        raise MirRefused(
            mir_refusal("call", f"{self.name_of(ab)} has no parameter {unknown[0]}", nd)
        );
    }
    total = b.const_int(0, mir_int());
    for spread in spreads {
        total = b.binary("add", total, self.container_len(spread.value));
    }
    self.raise_if(
        b.compare("ne", total, b.load(matched, mir_int())),
        "TypeError",
        f"{self.name_of(ab)}() got an unexpected keyword argument"
    );
    return bound;
}

impl MirLowering.bind_from_spreads(
    pv: uni.ParamVar,
    given: (MirBound | None),
    spreads: list[MirBound],
    matched: MirValue,
    ab: uni.Ability,
    nd: uni.FuncCall
) -> MirBound {
    b = self.builder();
    fn = self.st().fn;
    name = pv.name.value;
    if not spreads and given is not None {
        return given;
    }
    ptype = self.symbol_type(pv.name.sym, pv);
    held = self.temp_slot(ptype);
    bound_flag = self.temp_slot(mir_bool());
    b.store(bound_flag, b.const_bool(given is not None));
    if given is not None {
        b.store(held, self.coerce(given.value, ptype, given.site));
    }
    for spread in spreads {
        source = spread.value;
        key = source.type.args[0];
        found = self.runtime_value(
            "__jac_rt_dict_find",
            [
                source,
                self.to_bits(b.const_str(name, mir_str()), key, spread.site),
                b.const_int(self.elem_kind(key, spread.site), mir_int())
            ]
        );
        hit = fn.new_block("kwsp.bind");
        miss = fn.new_block("kwsp.next");
        b.cond_branch(b.compare("ge", found, b.const_int(0, mir_int())), hit, miss);
        b.position(hit);
        self.raise_if(
            b.load(bound_flag, mir_bool()),
            "TypeError",
            f"{self.name_of(ab)}() got multiple values for argument '{name}'"
        );
        b.store(
            held,
            self.coerce(
                self.dict_entry_value(source, found, spread.site), ptype, spread.site
            )
        );
        b.store(bound_flag, b.const_bool(True));
        b.store(
            matched,
            b.binary("add", b.load(matched, mir_int()), b.const_int(1, mir_int()))
        );
        b.branch(miss);
        b.position(miss);
    }
    if given is None {
        fallback = fn.new_block("kwsp.default");
        done = fn.new_block("kwsp.bound");
        b.cond_branch(b.load(bound_flag, mir_bool()), done, fallback);
        b.position(fallback);
        if pv.value is not None and self.constant_default(pv.value) {
            b.store(held, self.coerce(self.lower_expr(pv.value), ptype, pv.value));
        } else {
            b.raise_builtin(
                "TypeError",
                f"{self.name_of(ab)}() missing 1 required argument: '{name}'"
            );
            b.position(fn.new_block("kwsp.dead"));
        }
        b.branch(done);
        b.position(done);
    }
    return MirBound(value=b.load(held, ptype), site=pv);
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

impl MirLowering.bound_value(
    arg: (uni.Expr | MirPacked | MirBound), ptype: MirType
) -> MirValue {
    if isinstance(arg, MirBound) {
        return self.coerce(arg.value, ptype, arg.site);
    }
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
        for item in arg.items {
            if isinstance(item, MirBound) and item.star {
                self.extend_from(made, item.value, item.site);
            } elif isinstance(item, MirBound) {
                self.container_add(made, item.value, item.site);
            } else {
                self.container_add(made, self.lower_expr(item), item);
            }
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
        given = item.value if isinstance(item, MirBound) else self.lower_expr(item);
        site = item.site if isinstance(item, MirBound) else item;
        if not name {
            self.merge_dict(made, given, site, arg.unique);
            continue;
        }
        key_bits = self.to_bits(b.const_str(name, mir_str()), key, arg.site);
        if arg.unique {
            seen = self.runtime_value("__jac_rt_dict_find", [made, key_bits, key_kind]);
            self.raise_if(
                b.compare("ge", seen, b.const_int(0, mir_int())),
                "TypeError",
                f"got multiple values for keyword argument '{name}'"
            );
        }
        self.runtime(
            "__jac_rt_dict_set",
            [made, key_bits, self.to_bits(given, value, site), key_kind, value_kind]
        );
    }
    for name in arg.bindable {
        if not arg.unique {
            break;
        }
        self.runtime(
            "__jac_rt_dict_del",
            [
                made,
                self.to_bits(b.const_str(name, mir_str()), key, arg.site),
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
