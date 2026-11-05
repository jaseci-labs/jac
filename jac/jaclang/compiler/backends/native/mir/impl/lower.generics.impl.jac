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

impl MirLowering.template_of(ab: uni.Ability) -> bool {
    if id(ab) in self.templates {
        return True;
    }
    unit = ab.find_parent_of_type(uni.Module);
    if unit is None
        or unit is self.module
        or not unit.loc.mod_path.endswith(".jac")
        or not self.is_template(ab) {
        return False;
    }
    self.templates[id(ab)] = ab;
    return True;
}

impl MirLowering.is_template(ab: uni.Ability) -> bool {
    if ab.type_params {
        return True;
    }
    fn_type = self.declared_type(self.ability_sym(ab));
    return isinstance(fn_type, FunctionType) and self.mentions_typevar(fn_type);
}

impl MirLowering.mentions_typevar(t: (TypeBase | None)) -> bool {
    if t is None {
        return False;
    }
    if isinstance(t, TypeVarType) {
        return not t.is_self and not t.is_class_type_param;
    }
    if isinstance(t, FunctionType) {
        return any(self.mentions_typevar(p.param_type) for p in t.parameters)
            or self.mentions_typevar(t.return_type);
    }
    if isinstance(t, UnionType) {
        return any(self.mentions_typevar(member) for member in t.types);
    }
    if isinstance(t, ClassType) and t.private {
        return any(
            self.mentions_typevar(arg) for arg in list(t.private.type_args or [])
        );
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
        declared_args = list(declared.private.type_args or [])
            if declared.private
            else [];
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
    if isinstance(declared, FunctionType) and isinstance(actual, FunctionType) {
        for (want, got) in zip(declared.parameters, actual.parameters) {
            self.unify(want.param_type, got.param_type, solution);
        }
        self.unify(declared.return_type, actual.return_type, solution);
        return;
    }
    if isinstance(declared, UnionType) {
        if isinstance(actual, UnionType) {
            fixed = [
                member
                for member in declared.types
                if not isinstance(member, TypeVarType)
            ];
            rest = [
                member
                for member in actual.types
                if not any(str(member) == str(known) for known in fixed)
            ];
            for member in declared.types {
                if isinstance(member, TypeVarType) and len(rest) == 1 {
                    self.unify(member, rest[0], solution);
                    return;
                }
            }
        }
        for member in declared.types {
            if isinstance(member, TypeVarType) {
                self.unify(member, actual, solution);
                return;
            }
        }
        for member in declared.types {
            if self.mentions_typevar(member) {
                self.unify(member, actual, solution);
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
    fn_type = self.declared_type(self.ability_sym(ab));
    if isinstance(fn_type, FunctionType) {
        pending.extend(
            [
                p.param_type
                for p in fn_type.parameters
                if p.param_type is not None
            ]
        );
        if fn_type.return_type is not None {
            pending.append(fn_type.return_type);
        }
    }
    while pending {
        current = pending.pop();
        if isinstance(current, TypeVarType) {
            if not current.is_self
                and current.name not in names
                and current.name not in self.type_env {
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
    method_owner = self.owner_archetype(ab);
    if receiver is None
        and method_owner is not None
        and not ab.is_static
        and isinstance(nd.target, uni.AtomTrailer)
        and nd.target.is_attr
        and isinstance(nd.target.target, uni.Expr) {
        held_type = nd.target.target.type;
        if not (isinstance(held_type, ClassType) and not held_type.is_instance()) {
            owner = self.holder_arch(nd.target.target) or method_owner;
            receiver = self.lower_expr(nd.target.target);
        }
    }
    if receiver is None and method_owner is not None and not ab.is_static {
        raise MirRefused(
            mir_refusal(
                "method",
                f"{archetype_native_name(method_owner)}.{self.name_of(
                    ab
                )} without a receiver",
                nd
            )
        );
    }
    name = self.name_of(ab);
    sig = self.ability_sig(ab);
    if sig is None {
        raise MirRefused(mir_refusal("function", name, nd));
    }
    label = f"{archetype_native_name(owner)}.{name}" if owner is not None else name;
    if self.has_spread(nd) {
        raise MirRefused(mir_refusal("call argument", f"unpacking into {label}", nd));
    }
    nodes = self.param_nodes(sig, receiver is not None);
    solution: dict[str, TypeBase] = {};
    for (pv, chosen) in zip(nodes, self.bound_args(nd, ab, receiver is not None)) {
        if pv.name.sym is None {
            continue;
        }
        given = chosen
            if isinstance(chosen, uni.Expr)
            else (pv.value if isinstance(pv.value, uni.Expr) else None);
        if given is not None {
            self.unify(self.declared_type(pv.name.sym), given.type, solution);
        }
    }
    if nd.type is not None {
        fn_type = self.declared_type(self.ability_sym(ab));
        if isinstance(fn_type, FunctionType) {
            self.unify(fn_type.return_type, nd.type, solution);
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
    decl = self.stamp_instance(ab, owner, solution, nd);
    bound = self.bound_args(nd, ab, receiver is not None);
    if len(bound) != len(decl.params) {
        raise MirRefused(
            mir_refusal("call", f"{label} with {len(bound)} arguments", nd)
        );
    }
    values = self.bound_values(list(bound), decl.params);
    if receiver is not None {
        values.insert(
            0,
            self.coerce(receiver, decl.self_type, nd)
                if decl.self_type is not None
                else receiver
        );
    }
    result = self.builder().call(decl.symbol, values, decl.ret);
    if result is None {
        return self.builder().const_bool(False);
    }
    return result;
}

impl MirLowering.stamp_instance(
    ab: uni.Ability,
    owner: (uni.Archetype | None),
    solution: dict[str, TypeBase],
    site: uni.UniNode
) -> MirDecl {
    name = self.name_of(ab);
    label = f"{archetype_native_name(owner)}.{name}" if owner is not None else name;
    env: dict[str, TypeBase] = dict(self.type_env);
    env.update(solution);
    key = f"{label}|"
        + ",".join(
            sorted(
                f"{param}={mir_type_of(bound, MirPosition.VALUE, site, env).render()}"
                for (param, bound) in solution.items()
            )
        );
    decl = self.instances.get(key);
    if decl is None {
        parts = sorted(
            f"{param}={native_type_key(bound)}" for (param, bound) in solution.items()
        );
        memo = f"{label}|" + ",".join(parts);
        digest = hashlib.sha256(memo.encode()).hexdigest()[:8];
        stem = f"{archetype_native_name(owner)}_{name}" if owner is not None else name;
        symbol = f"__jac_mono_{stem}_{mono_symbol_text('_'.join(parts))}_{digest}";
        decl = self.declare_instance(ab, env, symbol, owner);
        self.instances[key] = decl;
        self.pending.append(decl);
    }
    return decl;
}

impl MirLowering.template_value(nd: uni.Name, ab: uni.Ability) -> (MirValue | None) {
    asn = nd.parent;
    if not isinstance(asn, uni.Assignment)
        or asn.value is not nd
        or asn.type_tag is None
        or not isinstance(asn.type_tag.tag, uni.Expr)
        or self.owner_archetype(ab) is not None {
        return None;
    }
    wanted = asn.type_tag.tag.type;
    fn_type = self.declared_type(self.ability_sym(ab));
    if not isinstance(wanted, FunctionType)
        or not isinstance(fn_type, FunctionType)
        or self.mentions_typevar(wanted) {
        return None;
    }
    solution: dict[str, TypeBase] = {};
    self.unify(fn_type, wanted, solution);
    for param in self.type_param_names(ab) {
        if param not in solution {
            return None;
        }
    }
    decl = self.stamp_instance(ab, None, solution, nd);
    address = self.emit_value(
        MirOp.FN_ADDR,
        mir_c_fn(decl.params, decl.ret),
        [],
        callee=self.c_entry(decl.symbol, decl.params, decl.ret, decl.ability)
    );
    self.fn_values[address.id] = decl;
    return address;
}

impl MirLowering.declare_instance(
    ab: uni.Ability,
    env: dict[str, TypeBase],
    symbol: str,
    owner: (uni.Archetype | None)
) -> MirDecl {
    self.body_types(ab);
    saved = self.type_env;
    self.type_env = env;
    try {
        sig = self.ability_sig(ab);
        if sig is None {
            raise MirRefused(mir_refusal("function", self.name_of(ab), ab));
        }
        params = [
            self.param_type(pv) for pv in self.param_nodes(sig, owner is not None)
        ];
        fn_type = self.declared_type(self.ability_sym(ab));
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
            reasons = self.refusals.get(self.refusal_key(decl), []);
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

impl MirLowering.body_types(ab: uni.Ability) {
    owner = ab.find_parent_of_type(uni.Module);
    import from jaclang.compiler.driver.pipeline { require }
    import from jaclang.compiler.driver.pipeline_types {
        AnalysisFact,
        CompilationProduct
    }
    if owner is None or owner is self.module {
        return;
    }
    qualname = uni.definition_qualname(ab);
    if qualname {
        self.module.record_comptime_definition(owner.loc.mod_path, qualname);
    } else {
        self.module.record_comptime_dependency(owner.loc.mod_path, body=True);
    }
    if self.prog.analysis.provides(owner, AnalysisFact.TYPE_OF) {
        return;
    }
    if not require(self.prog, owner, CompilationProduct.ANALYSIS) {
        raise MirRefused(
            mir_refusal(
                "function",
                self.name_of(ab),
                ab,
                f"Its module {owner.loc.mod_path} could not be analysed, and this unit lowers its body."
            )
        );
    }
}
