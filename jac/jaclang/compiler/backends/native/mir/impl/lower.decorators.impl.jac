impl MirLowering.runtime_decorators(ab: uni.Ability) -> list[uni.Expr] {
    if contextmanager_ability(ab) {
        return [];
    }
    return [
        dec
        for dec in list(ab.decorators or [])
        if not (isinstance(dec, uni.Name) and dec.value in C_CALLING_CONVENTIONS)
    ];
}

impl MirLowering.decorator_target(dec: uni.Name) -> (MirDecl | None) {
    sym = dec.sym;
    target = sym.decl.parent if sym is not None and sym.decl is not None else None;
    if not isinstance(target, uni.Ability)
        or not isinstance(target.parent, uni.Module) {
        return None;
    }
    local = self.decls.get(self.decl_syms.get(id(sym), -1));
    if local is None {
        local = self.decls.get(id(target));
    }
    if local is not None {
        if local.owner is not None
            or local.self_type is not None
            or local.event
            or local.c_symbol
            or local.c_variadic {
            return None;
        }
        return local;
    }
    if target.parent is self.module
        or not target.loc.mod_path.endswith(".jac")
        or self.template_of(target) {
        return None;
    }
    return self.foreign_function_decl(self.variant_ability(target), dec);
}

impl MirLowering.decorator_refusal(decl: MirDecl) -> (NativeRefusal | None) {
    ab = decl.ability;
    decorators = self.runtime_decorators(ab);
    if not decorators {
        return None;
    }
    label = self.decl_label(decl);
    if decl.owner is not None or decl.self_type is not None {
        return mir_refusal(
            "decorator",
            f"on method {label}",
            decorators[0],
            "A decorated method is applied by its Python implementation; native code lowers decorators only on module-level functions."
        );
    }
    if not isinstance(ab.parent, uni.Module)
        or self.is_generator(ab)
        or decl.c_symbol
        or decl.cc
        or decl.c_variadic {
        return mir_refusal(
            "decorator",
            f"on {label}",
            decorators[0],
            "Native code lowers decorators only on module-level, non-generator Jac functions."
        );
    }
    for dec in decorators {
        if not isinstance(dec, uni.Name) {
            return mir_refusal(
                "decorator",
                f"computed decorator on {label}",
                dec,
                "A decorator expression that is not a plain function name is applied by the Python implementation."
            );
        }
        target = self.decorator_target(dec);
        if target is None {
            return mir_refusal(
                "decorator",
                f"{dec.value} on {label}",
                dec,
                "A native decorator must name a module-level native function."
            );
        }
        sig = self.ability_sig(target.ability);
        required = len(
            [
                pv
                for pv in self.param_nodes(sig, False)
                if pv.value is None and pv.unpack is None
            ]
        )
            if sig is not None
            else len(target.params);
        if required > 1 or not target.params {
            refusal = mir_refusal(
                "decorator",
                dec.value,
                dec,
                "A native decorator must resolve to a module-level native function taking exactly one argument."
            );
            self.hard_refusals.append(refusal);
            return refusal;
        }
        if len(target.params) != 1 {
            return mir_refusal(
                "decorator",
                f"{dec.value} on {label}",
                dec,
                "A native decorator takes exactly one parameter; one with optional extras is applied by the Python implementation."
            );
        }
    }
    return None;
}

impl MirLowering.decorate(decl: MirDecl, raw: MirFunction) -> MirFunction {
    ab = decl.ability;
    decorators = self.runtime_decorators(ab);
    fn_type = mir_fn(list(decl.params), decl.ret);
    public_linkage = raw.linkage;
    raw.symbol = f"{decl.symbol}.__undecorated";
    raw.linkage = "internal";
    slot = MirGlobal(
        name=f"{raw.name}.__slot",
        symbol=f"{decl.symbol}.__slot",
        type=fn_type,
        linkage="internal"
    );
    self.mir.globals[slot.symbol] = slot;
    apply = MirFunction(
        name=f"{raw.name}.__decorate",
        symbol=f"{decl.symbol}.__decorate",
        ret=mir_none(),
        linkage="internal"
    );
    self.state = MirFnState(
        fn=apply, b=MirBuilder(fn=apply, block=apply.new_block("entry"))
    );
    try {
        b = self.builder();
        current = self.function_value(
            MirDecl(
                ability=ab, symbol=raw.symbol, params=list(decl.params), ret=decl.ret
            ),
            fn_type
        );
        for dec in reversed(decorators) {
            target = self.decorator_target(dec) if isinstance(dec, uni.Name) else None;
            if target is None or len(target.params) != 1 {
                raise MirRefused(mir_refusal("decorator", self.decl_label(decl), dec));
            }
            handed = self.coerce(current, target.params[0], dec);
            if target.ret.kind in (MirKind.NONE, MirKind.VOID) {
                b.call(target.symbol, [handed], mir_none());
                current = self.none_value();
                continue;
            }
            returned = b.call(target.symbol, [handed], target.ret);
            if returned is None {
                raise MirRefused(mir_refusal("decorator", self.decl_label(decl), dec));
            }
            current = returned;
        }
        place = self.emit_value(
            MirOp.GLOBAL_ADDR, mir_c_ptr(fn_type), [], str_value=slot.symbol
        );
        b.store(place, self.coerce(current, fn_type, decorators[0]));
        b.ret(None);
    } finally {
        self.state = None;
    }
    forward = MirFunction(name=raw.name, symbol=decl.symbol, ret=decl.ret);
    forward.linkage = public_linkage;
    first = forward.new_block("entry");
    self.state = MirFnState(fn=forward, b=MirBuilder(fn=forward, block=first));
    try {
        b = self.builder();
        given: list[MirValue] = [];
        for (param, ptype) in zip(raw.params, decl.params) {
            value = forward.new_value(ptype, param.name);
            forward.params.append(MirParam(name=param.name, value=value));
            given.append(value);
        }
        place = self.emit_value(
            MirOp.GLOBAL_ADDR, mir_c_ptr(fn_type), [], str_value=slot.symbol
        );
        loaded = b.load(place, fn_type);
        self.raise_if(
            b.compare(
                "eq",
                self.emit_value(MirOp.PTR_INT, mir_int(), [loaded]),
                b.const_int(0, mir_int())
            ),
            "NameError",
            f"name '{raw.name}' is not defined"
        );
        result = self.call_closure(loaded, given, ab);
        if decl.ret.kind in (MirKind.NONE, MirKind.VOID) {
            b.ret(None);
        } else {
            b.ret(result);
        }
    } finally {
        self.state = None;
    }
    self.nested.append(raw);
    self.nested.append(apply);
    self.fn_deps[forward.symbol] = [apply.symbol, raw.symbol];
    self.decorations.append((ab.loc.pos_start, apply.symbol));
    return forward;
}
