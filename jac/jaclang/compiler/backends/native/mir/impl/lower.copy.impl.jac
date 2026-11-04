impl MirLowering.copy_kind(nd: uni.FuncCall) -> str {
    target = nd.target;
    if isinstance(target, uni.AtomTrailer)
        and target.is_attr
        and isinstance(target.right, uni.Name)
        and target.right.value in ("copy", "deepcopy")
        and isinstance(target.target, uni.Name)
        and isinstance(target.target.type, ModuleType)
        and target.target.type.mod_name == "copy" {
        return target.right.value;
    }
    callee = nd.callee_decl;
    if isinstance(target, uni.Name)
        and isinstance(callee, uni.Ability)
        and isinstance(callee.parent, uni.Module)
        and os.path.basename(callee.loc.mod_path) in ("copy.pyi", "copy.py")
        and self.name_of(callee) in ("copy", "deepcopy") {
        return self.name_of(callee);
    }
    return "";
}

impl MirLowering.copy_call(nd: uni.FuncCall, kind: str) -> MirValue {
    deep = kind == "deepcopy";
    params = list(nd.params or []);
    if len(params) != 1 or isinstance(params[0], uni.KWPair) {
        raise MirRefused(
            self.copy_refused(
                nd,
                kind,
                "a call with other than one positional argument (a `memo` dict)"
            )
        );
    }
    if self.owned_world {
        raise MirRefused(
            self.copy_refused(
                nd,
                kind,
                "a module under the nogc memory profile, whose headerless objects carry no runtime class"
            )
        );
    }
    arg = params[0];
    value = self.lower_expr(arg);
    why = self.copy_refusal(value.type, deep, set(), True);
    if why is not None {
        raise MirRefused(self.copy_refused(nd, kind, why));
    }
    if self.copy_atomic(value.type, deep) {
        return value;
    }
    memo: (MirValue | None) = None;
    if deep {
        memo = self.spill(self.new_dict(mir_int(), mir_int(), self.copy_memo_type()));
    }
    return self.copy_value(self.spill(value), deep, memo, nd);
}

impl MirLowering.copy_refused(nd: uni.UniNode, kind: str, why: str) -> NativeRefusal {
    return mir_refusal(
        "copy call",
        f"copy.{kind} of {why}",
        nd,
        f"`copy.{kind}` lowers natively for scalars, strings, bytes, tuples, lists, dicts, sets and obj/class archetypes composed of them. Copy the value explicitly, or call `copy.{kind}` from a @sv/Python context."
    );
}

impl MirLowering.copy_memo_type -> MirType {
    return mir_dict(mir_int(), mir_int());
}

impl MirLowering.copy_label(t: MirType) -> str {
    if t.kind == MirKind.OBJ {
        arch = self.archetypes.get(t.name) or self.named_archs.get(t.name);
        if arch is not None {
            return f"`{arch.name.value}`";
        }
    }
    return f"`{t.render()}`";
}

impl MirLowering.copy_atomic(t: MirType, deep: bool) -> bool {
    if t.kind
        in (
            MirKind.INT,
            MirKind.FLOAT,
            MirKind.BOOL,
            MirKind.STR,
            MirKind.STR_REF,
            MirKind.NONE,
            MirKind.BYTES,
            MirKind.ENUM,
            MirKind.COMPLEX,
            MirKind.RANGE,
            MirKind.FN,
            MirKind.C_FN,
            MirKind.CLASS
        ) {
        return True;
    }
    if t.kind in (MirKind.OPT, MirKind.OPT_REF) {
        return self.copy_atomic(t.payload(), deep);
    }
    if t.kind == MirKind.TUPLE {
        return not deep or all(self.copy_atomic(member, True) for member in t.args);
    }
    return False;
}

impl MirLowering.copy_refusal(
    t: MirType, deep: bool, seen: set[str], top: bool
) -> (str | None) {
    if self.copy_atomic(t, deep) {
        return None;
    }
    label = self.copy_label(t);
    if t.kind == MirKind.TUPLE {
        return f"{label}, a tuple holding mutable values";
    }
    if t.kind in (MirKind.OPT, MirKind.OPT_REF) {
        return self.copy_refusal(t.payload(), deep, seen, top);
    }
    if t.kind == MirKind.OBJ {
        return self.copy_class_refusal(t, deep, seen);
    }
    if t.kind == MirKind.OSP {
        return f"{label}, a graph handle: a copy would share (copy.copy) or recursively duplicate (copy.deepcopy) the graph anchor of the original, which the Python runtime does not handle either";
    }
    if t.kind in (MirKind.LIST, MirKind.DICT, MirKind.SET) {
        if not deep {
            return None;
        }
        if t.kind == MirKind.LIST {
            why = self.copy_refusal(t.payload(), True, seen, False);
            return None if why is None else f"{label}, whose elements are {why}";
        }
        if t.kind == MirKind.SET {
            return None
                if self.copy_atomic(t.payload(), True)
                else f"{label}, a set of mutable objects";
        }
        if not self.copy_atomic(t.args[0], True) {
            return f"{label}, a dict keyed by mutable objects";
        }
        why = self.copy_refusal(t.args[1], True, seen, False);
        return None if why is None else f"{label}, whose values are {why}";
    }
    if t.kind == MirKind.ANY {
        if not deep and not top {
            return None;
        }
        return f"{label}, whose runtime type the native copy cannot dispatch on";
    }
    if not deep and not top {
        return None;
    }
    return label;
}

impl MirLowering.copy_candidates(arch: uni.Archetype) -> list[uni.Archetype] {
    name = self.object_def(arch).name;
    found: list[uni.Archetype] = [arch];
    for cls in self.runtime_classes(name, name) {
        cand = self.arch_named(cls, arch);
        if all(cand is not held for held in found) {
            found.append(cand);
        }
    }
    return found;
}

impl MirLowering.copy_class_refusal(
    t: MirType, deep: bool, seen: set[str]
) -> (str | None) {
    if t.name in seen {
        return None;
    }
    seen.add(t.name);
    base = self.archetypes.get(t.name) or self.named_archs.get(t.name);
    if base is None {
        return f"{self.copy_label(
            t
        )}, whose field layout is not visible to this module";
    }
    dunder = "__deepcopy__" if deep else "__copy__";
    for cand in self.copy_candidates(base) {
        label = f"`{cand.name.value}`"
            if cand is base
            else f"`{cand.name.value}` (a subclass of `{base.name.value}`)";
        layout = self.osp_layout(cand);
        if layout is not None {
            what = layout.arch_type;
            return f"{label}, a {what} archetype: a copy would share (copy.copy) or recursively duplicate (copy.deepcopy) the graph anchor of the original, which the Python runtime does not handle either; construct a new {what} explicitly";
        }
        if self.python_base_of(cand) is not None {
            return f"{label}, which extends a Python-side base";
        }
        if self.find_method(cand, dunder) is not None {
            return f"{label}, which defines its own `{dunder}`";
        }
        obj_def = self.object_def(cand);
        if obj_def.tag_slot >= 0 {
            return f"{label}, a graph archetype";
        }
        if not deep {
            continue;
        }
        for member in obj_def.fields {
            why = self.copy_refusal(member.type, True, seen, False);
            if why is not None {
                return f"{label}, whose field `{member.name}` is {why}";
            }
        }
    }
    return None;
}

impl MirLowering.copy_value(
    value: MirValue, deep: bool, memo: (MirValue | None), site: uni.UniNode
) -> MirValue {
    b = self.builder();
    t = value.type;
    if self.copy_atomic(t, deep) {
        return value;
    }
    if t.kind == MirKind.OPT {
        (held, payload, absent, done) = self.opt_begin(value, t);
        copied = self.copy_value(self.spill(payload), deep, memo, site);
        self.opt_switch(held, self.opt_wrap(copied, t), absent, done);
        return self.opt_end(held, b.const_null(t), done);
    }
    if deep and memo is not None {
        made = b.call(self.copy_deep_fn(t, site), [value, memo], t);
        if made is None {
            raise MirRefused(mir_refusal("copy call", t.render(), site));
        }
        made.owned = True;
        return made;
    }
    if t.kind == MirKind.OBJ {
        made = b.call(self.copy_dispatch(t, False, site), [value], t);
        if made is None {
            raise MirRefused(mir_refusal("copy call", t.render(), site));
        }
        made.owned = True;
        return made;
    }
    if t.kind in (MirKind.LIST, MirKind.SET) {
        made = self.spill(
            self.new_list(t.payload(), 4)
                if t.kind == MirKind.LIST
                else self.new_dict(t.payload(), None, t)
        );
        self.extend_from(made, value, site);
        return made;
    }
    if t.kind == MirKind.DICT {
        made = self.spill(self.new_dict(t.args[0], t.args[1], t));
        self.merge_dict(made, value, site, False);
        return made;
    }
    if t.kind == MirKind.BYTEARRAY {
        return self.to_bytearray(value);
    }
    raise MirRefused(mir_refusal("copy call", f"copy of {t.render()}", site));
}

impl MirLowering.copy_memo_find(
    memo: MirValue, source: MirValue, t: MirType
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    found = self.runtime_value(
        "__jac_rt_dict_find",
        [memo, self.address_of(source), b.const_int(KIND_INT, mir_int())]
    );
    hit = fn.new_block("copy.memo.hit");
    fresh = fn.new_block("copy.memo.fresh");
    b.cond_branch(b.compare("ge", found, b.const_int(0, mir_int())), hit, fresh);
    b.position(hit);
    prior = self.dict_entry_value(memo, found, self.module);
    b.ret(b.ref_cast(prior, t, False));
    b.position(fresh);
    return found;
}

impl MirLowering.copy_memo_record(memo: MirValue, source: MirValue, made: MirValue) {
    b = self.builder();
    kind = b.const_int(KIND_INT, mir_int());
    self.runtime(
        "__jac_rt_dict_set",
        [memo, self.address_of(source), self.address_of(made), kind, kind]
    );
}

impl MirLowering.copy_deep_fn(t: MirType, site: uni.UniNode) -> str {
    key = f"copy|deep|{t.render()}";
    known = self.adapters.get(key);
    if known is not None {
        return known;
    }
    symbol = f"{self.mir.prefix}.__deepcopy_{len(self.adapters)}";
    self.adapters[key] = symbol;
    memo_type = self.copy_memo_type();
    fn = MirFunction(name="__deepcopy", symbol=symbol, ret=t, linkage="internal");
    source = fn.new_value(t, "src");
    memo = fn.new_value(memo_type, "memo");
    fn.params.append(MirParam(name="src", value=source));
    fn.params.append(MirParam(name="memo", value=memo));
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=fn.new_block("entry")));
    try {
        b = self.builder();
        self.copy_memo_find(memo, source, t);
        if t.kind == MirKind.OBJ {
            made = b.call(self.copy_dispatch(t, True, site), [source, memo], t);
            if made is None {
                raise MirRefused(mir_refusal("copy call", t.render(), site));
            }
            made.owned = True;
            b.ret(made);
        } elif t.kind == MirKind.SET {
            made = self.spill(self.new_dict(t.payload(), None, t));
            self.copy_memo_record(memo, source, made);
            self.extend_from(made, source, site);
            b.ret(made);
        } elif t.kind == MirKind.LIST {
            elem = t.payload();
            made = self.spill(self.new_list(elem, 4));
            self.copy_memo_record(memo, source, made);
            (item, _, head, after) = self.each_begin(source, site);
            self.container_add(made, self.copy_value(item, True, memo, site), site);
            self.each_end(head, after);
            b.ret(made);
        } elif t.kind == MirKind.DICT {
            (key_type, value_type) = (t.args[0], t.args[1]);
            made = self.spill(self.new_dict(key_type, value_type, t));
            self.copy_memo_record(memo, source, made);
            key_kind = b.const_int(self.elem_kind(key_type, site), mir_int());
            value_kind = b.const_int(self.elem_kind(value_type, site), mir_int());
            (entry_key, cursor, head, after) = self.each_begin(source, site);
            held = cursor.source;
            at = cursor.position;
            if held is None or at is None {
                raise MirRefused(mir_refusal("copy call", t.render(), site));
            }
            held_value = self.spill(
                self.dict_entry_value(held, b.load(at, mir_int()), site)
            );
            copied = self.copy_value(held_value, True, memo, site);
            self.runtime(
                "__jac_rt_dict_set",
                [
                    made,
                    self.to_bits(entry_key, key_type, site),
                    self.to_bits(copied, value_type, site),
                    key_kind,
                    value_kind
                ]
            );
            self.each_end(head, after);
            b.ret(made);
        } else {
            raise MirRefused(
                mir_refusal("copy call", f"deepcopy of {t.render()}", site)
            );
        }
    } finally {
        self.state = saved;
    }
    self.nested.append(fn);
    return symbol;
}

impl MirLowering.copy_dispatch(t: MirType, deep: bool, site: uni.UniNode) -> str {
    key = f"copy|{'deep' if deep else 'shallow'}|dispatch|{t.name}";
    known = self.adapters.get(key);
    if known is not None {
        return known;
    }
    symbol = f"{self.mir.prefix}.__copy_dispatch_{len(self.adapters)}";
    self.adapters[key] = symbol;
    base = self.arch_named(t.name, site);
    fn = MirFunction(name="__copy_dispatch", symbol=symbol, ret=t, linkage="internal");
    source = fn.new_value(t, "src");
    fn.params.append(MirParam(name="src", value=source));
    memo: (MirValue | None) = None;
    if deep {
        memo = fn.new_value(self.copy_memo_type(), "memo");
        fn.params.append(MirParam(name="memo", value=memo));
    }
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=fn.new_block("entry")));
    try {
        b = self.builder();
        named = self.address_of(self.runtime_value("__jac_rt_type_name", [source]));
        for cand in self.copy_candidates(base) {
            cand_def = self.object_def(cand);
            cand_type = mir_obj(cand_def.name);
            hit = fn.new_block("copy.hit");
            miss = fn.new_block("copy.miss");
            b.cond_branch(
                self.exact_class_test(named, [cand_def.name], site), hit, miss
            );
            b.position(hit);
            args = [b.ref_cast(source, cand_type, False)];
            if memo is not None {
                args.append(memo);
            }
            made = b.call(self.copy_body(cand, deep, site), args, cand_type);
            if made is None {
                raise MirRefused(mir_refusal("copy call", cand_def.name, site));
            }
            made.owned = True;
            b.ret(b.ref_cast(made, t, True));
            b.position(miss);
        }
        b.raise_builtin(
            "TypeError",
            f"copy.{'deepcopy'
                if deep
                else 'copy'}: this native unit has no copy for the runtime class of a '{base.name.value}' value (a subclass defined in a module it does not import)"
        );
    } finally {
        self.state = saved;
    }
    self.nested.append(fn);
    return symbol;
}

impl MirLowering.copy_body(arch: uni.Archetype, deep: bool, site: uni.UniNode) -> str {
    obj_def = self.object_def(arch);
    key = f"copy|{'deep' if deep else 'shallow'}|body|{obj_def.name}";
    known = self.adapters.get(key);
    if known is not None {
        return known;
    }
    symbol = f"{self.mir.prefix}.__copy_body_{len(self.adapters)}";
    self.adapters[key] = symbol;
    self_type = mir_obj(obj_def.name);
    fn = MirFunction(
        name=f"{obj_def.name}.__copy", symbol=symbol, ret=self_type, linkage="internal"
    );
    source = fn.new_value(self_type, "src");
    fn.params.append(MirParam(name="src", value=source));
    memo: (MirValue | None) = None;
    if deep {
        memo = fn.new_value(self.copy_memo_type(), "memo");
        fn.params.append(MirParam(name="memo", value=memo));
    }
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=fn.new_block("entry")));
    try {
        b = self.builder();
        made = self.spill(self.object_alloc(arch, obj_def, self_type));
        if memo is not None {
            self.copy_memo_record(memo, source, made);
        }
        for member in obj_def.fields {
            loaded = b.load(
                self.emit_value(
                    MirOp.FIELD_ADDR,
                    mir_c_ptr(member.type),
                    [source],
                    int_value=member.index
                ),
                member.type
            );
            if deep and not self.copy_atomic(member.type, True) {
                loaded = self.copy_value(self.spill(loaded), True, memo, site);
            }
            b.store(
                self.emit_value(
                    MirOp.FIELD_ADDR,
                    mir_c_ptr(member.type),
                    [made],
                    int_value=member.index
                ),
                loaded
            );
        }
        b.ret(made);
    } finally {
        self.state = saved;
    }
    self.nested.append(fn);
    return symbol;
}
