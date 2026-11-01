impl mono_symbol_text(text: str) -> str {
    out = "";
    for ch in text {
        if (ch >= "a" and ch <= "z")
            or (ch >= "A" and ch <= "Z")
            or (ch >= "0" and ch <= "9")
            or ch == "_" {
            out += ch;
        } else {
            out += "_";
        }
    }
    return out;
}

impl MirLowering.is_template(ab: uni.Ability) -> bool {
    if ab.type_params {
        return True;
    }
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(self.ability_sym(ab));
    return isinstance(fn_type, FunctionType) and self.mentions_typevar(fn_type);
}

impl MirLowering.mentions_typevar(t: (TypeBase | None)) -> bool {
    if t is None {
        return False;
    }
    if isinstance(t, TypeVarType) {
        return not t.is_self;
    }
    if isinstance(t, FunctionType) {
        return any(self.mentions_typevar(p.param_type) for p in t.parameters)
            or self.mentions_typevar(t.return_type);
    }
    if isinstance(t, UnionType) {
        return any(self.mentions_typevar(member) for member in t.types);
    }
    if isinstance(t, ClassType) and t.private {
        return any(self.mentions_typevar(arg) for arg in list(t.private.type_args or []));
    }
    return False;
}

impl MirLowering.resolved(t: (TypeBase | None)) -> (TypeBase | None) {
    if isinstance(t, TypeVarType) and t.name in self.type_env {
        return self.type_env[t.name];
    }
    return t;
}

impl MirLowering.unify(
    declared: (TypeBase | None),
    actual: (TypeBase | None),
    solution: dict[str, TypeBase]
) {
    actual = self.resolved(actual);
    if declared is None or actual is None {
        return;
    }
    if isinstance(declared, TypeVarType) {
        if declared.name not in solution {
            solution[declared.name] = actual;
        }
        return;
    }
    if isinstance(declared, ClassType) and isinstance(actual, ClassType) {
        declared_args = list(declared.private.type_args or []) if declared.private else [];
        actual_args = list(actual.private.type_args or []) if actual.private else [];
        if declared.shared.class_name == "type"
            and declared_args
            and actual.is_instantiable()
            and not actual.is_instance() {
            self.unify(declared_args[0], actual.clone_as_instance(), solution);
            return;
        }
        for (index, part) in enumerate(declared_args) {
            if index < len(actual_args) {
                self.unify(part, actual_args[index], solution);
            }
        }
        return;
    }
    if isinstance(declared, UnionType) {
        for member in declared.types {
            if isinstance(member, TypeVarType) {
                self.unify(member, actual, solution);
                return;
            }
        }
    }
}

impl MirLowering.type_param_names(ab: uni.Ability) -> list[str] {
    names: list[str] = [tp.name.value for tp in list(ab.type_params or [])];
    if names {
        return names;
    }
    pending: list[TypeBase] = [];
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(self.ability_sym(ab));
    if isinstance(fn_type, FunctionType) {
        pending.extend([p.param_type for p in fn_type.parameters if p.param_type is not None]);
        if fn_type.return_type is not None {
            pending.append(fn_type.return_type);
        }
    }
    while pending {
        current = pending.pop();
        if isinstance(current, TypeVarType) {
            if not current.is_self and current.name not in names and current.name not in self.type_env {
                names.append(current.name);
            }
        } elif isinstance(current, UnionType) {
            pending.extend(list(current.types));
        } elif isinstance(current, ClassType) and current.private {
            pending.extend(list(current.private.type_args or []));
        }
    }
    return names;
}

impl MirLowering.generic_call(
    nd: uni.FuncCall,
    ab: uni.Ability,
    receiver: (MirValue | None),
    owner: (uni.Archetype | None)
) -> MirValue {
    name = self.name_of(ab);
    sig = self.ability_sig(ab);
    if sig is None {
        raise MirRefused(mir_refusal("function", name, nd));
    }
    label = f"{archetype_native_name(owner)}.{name}" if owner is not None else name;
    nodes = self.param_nodes(sig, receiver is not None);
    evaluator = self.prog.get_type_evaluator();
    solution: dict[str, TypeBase] = {};
    for (pv, chosen) in zip(nodes, self.bound_args(nd, ab, receiver is not None)) {
        if pv.name.sym is not None {
            self.unify(evaluator.get_type_of_symbol(pv.name.sym), chosen.type, solution);
        }
    }
    for wanted in self.type_param_names(ab) {
        if wanted not in solution {
            raise MirRefused(
                mir_refusal(
                    "function" if owner is None else "method",
                    label,
                    nd,
                    "Could not solve this call's type arguments for monomorphization; annotate the arguments with concrete types."
                )
            );
        }
    }
    env: dict[str, TypeBase] = dict(self.type_env);
    env.update(solution);
    key = f"{label}|" + ",".join(
        sorted(
            f"{param}={mir_type_of(bound, MirPosition.VALUE, nd, env).render()}"
            for (param, bound) in solution.items()
        )
    );
    decl = self.instances.get(key);
    if decl is None {
        parts = sorted(f"{param}={native_type_key(bound)}" for (param, bound) in solution.items());
        memo = f"{label}|" + ",".join(parts);
        digest = hashlib.sha256(memo.encode()).hexdigest()[:8];
        stem = f"{archetype_native_name(owner)}_{name}" if owner is not None else name;
        symbol = f"__jac_mono_{stem}_{mono_symbol_text('_'.join(parts))}_{digest}";
        decl = self.declare_instance(ab, env, symbol, owner);
        self.instances[key] = decl;
        self.pending.append(decl);
    }
    bound = self.bound_args(nd, ab, receiver is not None);
    if len(bound) != len(decl.params) {
        raise MirRefused(mir_refusal("call", f"{label} with {len(bound)} arguments", nd));
    }
    values = [
        self.coerce(self.lower_expr(arg), ptype, arg)
        for (arg, ptype) in zip(bound, decl.params)
    ];
    if receiver is not None {
        values.insert(0, receiver);
    }
    result = self.builder().call(decl.symbol, values, decl.ret);
    if result is None {
        return self.builder().const_bool(False);
    }
    return result;
}

impl MirLowering.declare_instance(
    ab: uni.Ability,
    env: dict[str, TypeBase],
    symbol: str,
    owner: (uni.Archetype | None)
) -> MirDecl {
    saved = self.type_env;
    self.type_env = env;
    try {
        sig = self.ability_sig(ab);
        if sig is None {
            raise MirRefused(mir_refusal("function", self.name_of(ab), ab));
        }
        params = [
            self.symbol_type(pv.name.sym, pv)
            for pv in self.param_nodes(sig, owner is not None)
        ];
        fn_type = self.prog.get_type_evaluator().get_type_of_symbol(self.ability_sym(ab));
        ret = mir_none();
        if isinstance(fn_type, FunctionType) {
            ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, ab);
        }
    } finally {
        self.type_env = saved;
    }
    return MirDecl(
        ability=ab,
        symbol=symbol,
        params=params,
        ret=ret,
        self_type=self.object_type(owner) if owner is not None else None,
        owner=owner,
        env=env
    );
}

impl MirLowering.lower_instances {
    while self.pending {
        decl = self.pending.pop(0);
        saved = self.type_env;
        self.type_env = decl.env;
        made = self.lower_function(decl);
        self.type_env = saved;
        if made is None {
            reasons = self.refusals.get(self.name_of(decl.ability), []);
            self.mir.demoted[decl.symbol] = f"{reasons[-1].kind} '{reasons[-1].name}'"
                if reasons
                else "its instantiation is not native";
            continue;
        }
        made.linkage = "internal";
        self.mir.functions.append(made);
    }
    self.mir.functions.extend(self.nested);
    self.nested = [];
}
