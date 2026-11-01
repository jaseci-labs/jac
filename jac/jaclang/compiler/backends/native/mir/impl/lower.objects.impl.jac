impl MirLowering.module_archetypes -> list[uni.Archetype] {
    found: list[uni.Archetype] = [];
    for elem in self.module.body {
        if isinstance(elem, uni.Archetype) {
            found.append(elem);
        }
    }
    return found;
}

impl MirLowering.arch_of_type(t: (TypeBase | None)) -> (uni.Archetype | None) {
    if isinstance(t, ClassType) and isinstance(t.shared.symbol_table, uni.Archetype) {
        return t.shared.symbol_table;
    }
    return None;
}

impl MirLowering.object_type(arch: uni.Archetype) -> MirType {
    return mir_obj(self.object_def(arch).name);
}

impl MirLowering.object_def(arch: uni.Archetype) -> MirObjectDef {
    name = archetype_native_name(arch);
    found = self.mir.objects.get(name);
    if found is not None {
        return found;
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    layout = get_layout_registry(owner, self.prog).get_layout(name);
    if layout is None {
        raise MirRefused(mir_refusal("archetype", name, arch, "The archetype has no native layout."));
    }
    python_base = self.python_base_of(arch);
    if python_base is not None {
        raise MirRefused(
            mir_refusal(
                "archetype",
                f"{name} (Python base {python_base})",
                arch,
                "An archetype with a Python base class keeps its instance state in Python; native code does not hold such objects."
            )
        );
    }
    local = owner is self.module;
    prefix = native_unit_prefix(owner.loc.mod_path);
    made = MirObjectDef(
        name=name,
        slot_count=layout_slot_count(layout),
        vtable_slot=layout.vtable_ptr_slot if layout.vtable_ptr_slot is not None else -1,
        tag_slot=layout.type_tag_slot if layout.type_tag_slot is not None else -1,
        reports_slot=layout.reports_slot if layout.reports_slot is not None else -1,
        is_acyclic=layout.is_acyclic,
        local=local,
        drop_symbol=native_symbol_name(prefix, f"{name}.__drop"),
        trace_symbol=native_symbol_name(prefix, f"{name}.__trace")
    );
    self.mir.objects[name] = made;
    self.archetypes[name] = arch;
    for member in layout.fields {
        made.fields.append(
            MirObjectField(
                name=member.name,
                type=mir_type_of(member.semantic_type, MirPosition.FIELD, member.decl_node or arch),
                index=member.index
            )
        );
    }
    self.osp_header_fields(made, layout);
    if layout.has_vtable {
        made.vtable_symbol = native_symbol_name(
            prefix, native_unit_spelling(f"{name}.__vtable", owner.loc.mod_path)
        );
        for slot in layout.methods {
            owner_arch = self.archetypes.get(slot.owner);
            made.vtable_methods.append(
                self.method_symbol(owner_arch, slot.name)
                    if owner_arch is not None
                    else native_symbol_name(prefix, f"{slot.owner}.{slot.name}")
            );
        }
        for ancestor in layout.mro {
            ancestor_layout = get_layout_registry(owner, self.prog).get_layout(ancestor);
            if ancestor_layout is not None and ancestor_layout.has_vtable {
                made.ancestry.append(
                    native_symbol_name(
                        native_unit_prefix(ancestor_layout.decl_mod or owner.loc.mod_path),
                        f"{ancestor}.__vtable"
                    )
                );
            }
        }
    }
    if not local {
        self.mir.externs[made.drop_symbol] = MirExtern(
            symbol=made.drop_symbol, ret=mir_none(), params=[mir_c_ptr(mir_int(8, False))]
        );
    }
    return made;
}

impl MirLowering.arch_methods(arch: uni.Archetype) -> list[uni.Ability] {
    found: list[uni.Ability] = [];
    for member in list(ModuleFacts.unwrap_body(arch) or []) {
        if isinstance(member, uni.Ability) and isinstance(member.signature, uni.FuncSignature) {
            found.append(member);
        }
    }
    return found;
}

impl MirLowering.find_method(arch: uni.Archetype, name: str) -> (uni.Ability | None) {
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    layout = get_layout_registry(owner, self.prog).get_layout(archetype_native_name(arch));
    lineage = list(layout.mro) if layout is not None else [archetype_native_name(arch)];
    for ancestor in lineage {
        holder = self.archetypes.get(ancestor) if ancestor != archetype_native_name(arch) else arch;
        if holder is None {
            continue;
        }
        for method in self.arch_methods(holder) {
            if self.name_of(method) == name {
                return method;
            }
        }
    }
    return None;
}

impl MirLowering.method_symbol(arch: uni.Archetype, name: str) -> str {
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    return native_symbol_name(
        native_unit_prefix(owner.loc.mod_path),
        native_unit_spelling(f"{archetype_native_name(arch)}.{name}", owner.loc.mod_path)
    );
}

impl MirLowering.declare_archetype(arch: uni.Archetype) {
    self_type = self.object_type(arch);
    obj_def = self.object_def(arch);
    for method in self.arch_methods(arch) {
        sig = method.signature;
        if not isinstance(sig, uni.FuncSignature) {
            continue;
        }
        if method.is_static {
            raise MirRefused(mir_refusal("method", self.name_of(method), method));
        }
        if self.is_template(method) {
            self.templates[id(method)] = method;
            continue;
        }
        params: list[MirType] = [];
        for pv in self.param_nodes(sig, True) {
            params.append(self.symbol_type(pv.name.sym, pv));
        }
        fn_type = self.prog.get_type_evaluator().get_type_of_symbol(self.ability_sym(method));
        ret = mir_none();
        if isinstance(fn_type, FunctionType) {
            ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, method);
        }
        key = id(method);
        self.decl_syms[id(self.ability_sym(method))] = key;
        self.decls[key] = MirDecl(
            ability=method,
            symbol=self.method_symbol(arch, self.name_of(method)),
            params=params,
            ret=ret,
            self_type=self_type,
            owner=arch
        );
        self.order.append(key);
    }
    self.declare_osp_abilities(arch);
    if obj_def.local {
        self.trace_pairs.append((obj_def.drop_symbol, obj_def.trace_symbol));
    }
}

impl MirLowering.constructor_params(
    arch: uni.Archetype
) -> list[tuple[str, MirType, (uni.Expr | None)]] {
    init = self.find_method(arch, "init") or self.find_method(arch, "__init__");
    found: list[tuple[str, MirType, (uni.Expr | None)]] = [];
    if init is not None and isinstance(init.signature, uni.FuncSignature) {
        for pv in list(init.signature.posonly_params) + list(init.signature.params or []) {
            if pv.name.value == "self" {
                continue;
            }
            found.append((pv.name.value, self.symbol_type(pv.name.sym, pv), pv.value));
        }
        return found;
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    layout = get_layout_registry(owner, self.prog).get_layout(archetype_native_name(arch));
    if layout is None {
        return found;
    }
    obj_def = self.object_def(arch);
    for member in layout.fields {
        decl = member.decl_node;
        if isinstance(decl, uni.HasVar) and decl.defer {
            continue;
        }
        default_value = member.default_expr if isinstance(member.default_expr, uni.Expr) else None;
        held = obj_def.field(member.name);
        if held is not None {
            found.append((member.name, held.type, default_value));
        }
    }
    return found;
}

impl MirLowering.lower_constructor(arch: uni.Archetype) -> (MirFunction | None) {
    obj_def = self.object_def(arch);
    self_type = mir_obj(obj_def.name);
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    symbol = native_symbol_name(native_unit_prefix(owner.loc.mod_path), f"{obj_def.name}.__ctor");
    fn = MirFunction(name=f"{obj_def.name}.__ctor", symbol=symbol, ret=self_type);
    first = fn.new_block("entry");
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        b = self.builder();
        params = self.constructor_params(arch);
        values: list[MirValue] = [];
        for (pname, ptype, _) in params {
            value = fn.new_value(ptype, pname);
            fn.params.append(MirParam(name=pname, value=value));
            values.append(value);
        }
        size = fn.new_value(mir_int());
        b.emit(MirInstr(op=MirOp.SIZEOF, result=size, type_arg=self_type));
        raw = self.runtime("__jac_rt_alloc_zeroed", [size]);
        if raw is None {
            raise MirRefused(mir_refusal("constructor", obj_def.name, arch));
        }
        made = b.ref_cast(raw, self_type, True);
        held = self.temp_slot(self_type);
        b.store(held, made);
        this = b.load(held, self_type);
        self.runtime("__jac_rt_set_type", [this, self.emit_value(MirOp.CSTR, mir_c_ptr(mir_int(8, False)), [], str_value=obj_def.name)]);
        address = self.address_of(this);
        drop_address = self.emit_value(
            MirOp.PTR_INT,
            mir_int(),
            [self.emit_value(MirOp.FN_ADDR, mir_c_fn([mir_c_ptr(mir_int(8, False))], mir_none()), [], callee=obj_def.drop_symbol)]
        );
        self.emit_value(
            MirOp.MEM_STORE, mir_none(), [b.binary("sub", address, b.const_int(8, mir_int())), drop_address]
        );
        if obj_def.vtable_slot >= 0 {
            slot = self.emit_value(
                MirOp.FIELD_ADDR,
                mir_c_ptr(mir_c_ptr(mir_c_ptr(mir_int(8, False)))),
                [this],
                int_value=obj_def.vtable_slot
            );
            b.store(slot, self.emit_value(MirOp.VTABLE_ADDR, mir_c_ptr(mir_c_ptr(mir_int(8, False))), [], str_value=obj_def.name));
        }
        self.osp_header(this, obj_def);
        init = self.find_method(arch, "init") or self.find_method(arch, "__init__");
        if init is None {
            for ((pname, ptype, _), value) in zip(params, values) {
                b.store(self.field_place(this, arch, pname, arch), value);
            }
        }
        layout = get_layout_registry(owner, self.prog).get_layout(obj_def.name);
        named = {pname for (pname, _, _) in params} if init is None else set();
        for member in (layout.fields if layout is not None else []) {
            if member.name in named or not isinstance(member.default_expr, uni.Expr) {
                continue;
            }
            place = self.field_place(this, arch, member.name, arch);
            b.store(place, self.coerce(self.lower_expr(member.default_expr), self.place_elem(place), member.default_expr));
        }
        if init is not None {
            decl = self.decls.get(id(init));
            if decl is None {
                raise MirRefused(mir_refusal("constructor", f"{obj_def.name}.init", init));
            }
            b.call(decl.symbol, [this] + values, decl.ret);
        }
        post = self.find_method(arch, "postinit") or self.find_method(arch, "__post_init__");
        if post is not None {
            decl = self.decls.get(id(post));
            if decl is not None {
                b.call(decl.symbol, [this], decl.ret);
            }
        }
        b.ret(this);
    } except MirRefused as err {
        self.refusals.setdefault(fn.name, []).append(refusal_of(err));
        self.state = saved;
        return None;
    }
    self.state = saved;
    return fn;
}

impl MirLowering.lower_drop(obj_def: MirObjectDef) -> MirFunction {
    i8p = mir_c_ptr(mir_int(8, False));
    fn = MirFunction(name=f"{obj_def.name}.__drop", symbol=obj_def.drop_symbol, ret=mir_none(), manual_rc=True);
    first = fn.new_block("entry");
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    b = self.builder();
    raw = fn.new_value(i8p, "o");
    fn.params.append(MirParam(name="o", value=raw));
    this = b.ref_cast(raw, mir_obj(obj_def.name), False);
    collecting = self.emit_value(
        MirOp.MEM_LOAD, mir_int(8, True, True), [self.emit_value(MirOp.GLOBAL_BLOCK, mir_int(), [], str_value="__rc_collecting", int_value=1)]
    );
    self.mir.global_blocks["__rc_collecting"] = max(self.mir.global_blocks.get("__rc_collecting", 0), 1);
    release_bb = fn.new_block("drop.fields");
    free_bb = fn.new_block("drop.free");
    b.cond_branch(b.compare("eq", collecting, b.const_int(0, collecting.type)), release_bb, free_bb);
    b.position(release_bb);
    for member in obj_def.fields {
        if not mir_holds_ref(member.type) {
            continue;
        }
        place = self.emit_value(MirOp.FIELD_ADDR, mir_c_ptr(member.type), [this], int_value=member.index);
        b.emit(MirInstr(op=MirOp.RELEASE, operands=[b.load(place, member.type)]));
    }
    b.branch(free_bb);
    b.position(free_bb);
    self.osp_drop(obj_def, raw);
    address = self.address_of(raw);
    self.runtime("__jac_rt_free_block", [b.binary("sub", address, b.const_int(32, mir_int()))]);
    b.ret(None);
    self.state = saved;
    return fn;
}

impl MirLowering.lower_trace(obj_def: MirObjectDef) -> MirFunction {
    i8p = mir_c_ptr(mir_int(8, False));
    visitor_type = mir_c_fn([i8p], mir_none());
    fn = MirFunction(name=f"{obj_def.name}.__trace", symbol=obj_def.trace_symbol, ret=mir_none(), manual_rc=True);
    first = fn.new_block("entry");
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    b = self.builder();
    raw = fn.new_value(i8p, "o");
    visit_fn = fn.new_value(visitor_type, "visitor");
    fn.params.append(MirParam(name="o", value=raw));
    fn.params.append(MirParam(name="visitor", value=visit_fn));
    this = b.ref_cast(raw, mir_obj(obj_def.name), False);
    for member in obj_def.fields {
        if not mir_holds_ref(member.type)
            or member.type.kind in (MirKind.STR, MirKind.STR_REF, MirKind.ANY) {
            continue;
        }
        place = self.emit_value(MirOp.FIELD_ADDR, mir_c_ptr(member.type), [this], int_value=member.index);
        child = b.load(place, member.type);
        self.emit_value(MirOp.CALL_FNPTR, mir_none(), [visit_fn, self.emit_value(MirOp.PTR_CAST, i8p, [child])]);
    }
    b.ret(None);
    self.state = saved;
    return fn;
}

impl MirLowering.field_place(
    holder: MirValue, arch: uni.Archetype, name: str, site: uni.UniNode
) -> MirValue {
    obj_def = self.object_def(arch);
    member = obj_def.field(name);
    if member is None {
        raise MirRefused(mir_refusal("attribute", f"{obj_def.name}.{name}", site));
    }
    return self.emit_value(MirOp.FIELD_ADDR, mir_c_ptr(member.type), [holder], int_value=member.index);
}

impl MirLowering.object_call(nd: uni.FuncCall, arch: uni.Archetype) -> MirValue {
    obj_def = self.object_def(arch);
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    symbol = native_symbol_name(native_unit_prefix(owner.loc.mod_path), f"{obj_def.name}.__ctor");
    params = self.constructor_params(arch);
    positional: list[uni.Expr] = [];
    named: dict[str, uni.Expr] = {};
    for arg in list(nd.params or []) {
        if isinstance(arg, uni.KWPair) {
            if arg.key is None {
                raise MirRefused(mir_refusal("call argument", "keyword unpacking", arg));
            }
            named[arg.key.sym_name] = arg.value;
        } else {
            positional.append(arg);
        }
    }
    if len(positional) > len(params) {
        raise MirRefused(mir_refusal("call", f"{obj_def.name} with {len(positional)} arguments", nd));
    }
    values: list[MirValue] = [];
    for (index, (pname, ptype, fallback)) in enumerate(params) {
        source = positional[index] if index < len(positional) else named.get(pname, fallback);
        if source is None {
            raise MirRefused(mir_refusal("call", f"{obj_def.name} missing {pname}", nd));
        }
        values.append(self.coerce(self.lower_expr(source), ptype, source));
    }
    if not obj_def.local {
        self.mir.externs[symbol] = MirExtern(symbol=symbol, ret=mir_obj(obj_def.name), params=[p[1] for p in params]);
        unit = os.path.realpath(owner.loc.mod_path);
        if unit not in self.mir.deps {
            self.mir.deps.append(unit);
        }
    }
    result = self.builder().call(symbol, values, mir_obj(obj_def.name));
    if result is None {
        raise MirRefused(mir_refusal("call", obj_def.name, nd));
    }
    return result;
}

impl MirLowering.object_method(
    nd: uni.FuncCall, receiver: MirValue, arch: uni.Archetype, name: str
) -> (MirValue | None) {
    method = self.find_method(arch, name);
    if method is None {
        return None;
    }
    if id(method) in self.templates {
        return self.generic_call(nd, method, receiver, arch);
    }
    decl = self.decls.get(id(method));
    if decl is None {
        raise MirRefused(mir_refusal("method", f"{archetype_native_name(arch)}.{name}", nd));
    }
    args = self.bound_args(nd, method, True);
    if len(args) != len(decl.params) {
        raise MirRefused(mir_refusal("call", f"{name} with {len(args)} arguments", nd));
    }
    values = [receiver] + [
        self.coerce(self.lower_expr(arg), ptype, arg) for (arg, ptype) in zip(args, decl.params)
    ];
    obj_def = self.object_def(arch);
    if obj_def.vtable_symbol and decl.symbol in obj_def.vtable_methods and name not in NON_DISPATCHED_METHODS {
        b = self.builder();
        i8p = mir_c_ptr(mir_int(8, False));
        slot_place = self.emit_value(MirOp.FIELD_ADDR, mir_c_ptr(mir_c_ptr(i8p)), [receiver], int_value=obj_def.vtable_slot);
        table = b.load(slot_place, mir_c_ptr(i8p));
        index = obj_def.vtable_methods.index(decl.symbol) + VTABLE_HEADER_SLOTS;
        entry_place = self.emit_value(MirOp.PTR_OFFSET, mir_c_ptr(i8p), [table, b.const_int(index, mir_int())]);
        target = b.load(entry_place, i8p);
        signature = mir_c_fn([receiver.type] + decl.params, decl.ret);
        callee = self.emit_value(MirOp.PTR_CAST, signature, [target]);
        result_type = mir_none() if decl.ret.kind in (MirKind.NONE, MirKind.VOID) else decl.ret;
        result = self.emit_value(MirOp.CALL_FNPTR, result_type, [callee] + values);
        result.owned = mir_holds_ref(result_type);
        return result;
    }
    direct = self.builder().call(decl.symbol, values, decl.ret);
    return direct if direct is not None else self.builder().const_bool(False);
}

impl MirLowering.isinstance_check(value: MirValue, arch: uni.Archetype) -> MirValue {
    b = self.builder();
    obj_def = self.object_def(arch);
    if not obj_def.vtable_symbol or value.type.kind != MirKind.OBJ {
        return b.const_bool(value.type is mir_obj(obj_def.name));
    }
    i8p = mir_c_ptr(mir_int(8, False));
    source_name = value.type.name;
    source_def = self.mir.objects.get(source_name);
    if source_def is None or source_def.vtable_slot < 0 {
        return b.const_bool(source_name == obj_def.name);
    }
    slot_place = self.emit_value(MirOp.FIELD_ADDR, mir_c_ptr(mir_c_ptr(i8p)), [value], int_value=source_def.vtable_slot);
    table = b.load(slot_place, mir_c_ptr(i8p));
    lineage = b.load(self.emit_value(MirOp.PTR_OFFSET, mir_c_ptr(i8p), [table, b.const_int(1, mir_int())]), i8p);
    wanted = self.emit_value(MirOp.PTR_INT, mir_int(), [self.emit_value(MirOp.VTABLE_ADDR, mir_c_ptr(i8p), [], str_value=obj_def.name)]);
    walk = self.temp_slot(mir_int());
    verdict = self.temp_slot(mir_bool());
    b.store(walk, self.emit_value(MirOp.PTR_INT, mir_int(), [lineage]));
    b.store(verdict, b.const_bool(False));
    fn = self.st().fn;
    head = fn.new_block("isa.head");
    body = fn.new_block("isa.body");
    done = fn.new_block("isa.done");
    b.branch(head);
    b.position(head);
    entry_value = self.emit_value(MirOp.MEM_LOAD, mir_int(), [b.load(walk, mir_int())]);
    b.cond_branch(b.compare("ne", entry_value, b.const_int(0, mir_int())), body, done);
    b.position(body);
    found = b.compare("eq", entry_value, wanted);
    b.store(verdict, found);
    b.store(walk, b.binary("add", b.load(walk, mir_int()), b.const_int(8, mir_int())));
    b.cond_branch(found, done, head);
    b.position(done);
    return b.load(verdict, mir_bool());
}

impl MirLowering.lower_module_init -> (MirFunction | None) {
    if not self.trace_pairs and not self.deferred_globals and not self.osp_setup {
        return None;
    }
    path = self.module.loc.mod_path;
    fn = MirFunction(name="__glob_init", symbol=native_glob_init_name(path), ret=mir_none());
    first = fn.new_block("entry");
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        b = self.builder();
        for (drop_symbol, trace_symbol) in self.trace_pairs {
            i8p = mir_c_ptr(mir_int(8, False));
            drop_fn = self.emit_value(MirOp.FN_ADDR, mir_c_fn([i8p], mir_none()), [], callee=drop_symbol);
            trace_fn = self.emit_value(
                MirOp.FN_ADDR, mir_c_fn([i8p, mir_c_fn([i8p], mir_none())], mir_none()), [], callee=trace_symbol
            );
            self.runtime(
                "__jac_rt_trace_register",
                [self.emit_value(MirOp.PTR_INT, mir_int(), [drop_fn]), self.emit_value(MirOp.PTR_INT, mir_int(), [trace_fn])]
            );
        }
        if self.osp_setup {
            b.call(self.osp_setup, [], mir_none());
        }
        for (glob_def, initial) in self.deferred_globals {
            place = self.emit_value(MirOp.GLOBAL_ADDR, mir_c_ptr(glob_def.type), [], str_value=glob_def.symbol);
            b.store(place, self.coerce(self.lower_expr(initial), glob_def.type, initial));
        }
        b.ret(None);
    } except MirRefused as err {
        self.refusals.setdefault("global initializers", []).append(refusal_of(err));
        self.state = None;
        return None;
    }
    self.state = None;
    return fn;
}

impl MirLowering.lower_module_entry -> (MirFunction | None) {
    blocks: list[uni.ModuleCode] = [];
    for elem in self.module.body {
        if isinstance(elem, uni.ModuleCode) and elem.name is None {
            blocks.append(elem);
        }
    }
    if not blocks {
        return None;
    }
    fn = MirFunction(name="__entry", symbol=native_entry_name(self.module.loc.mod_path), ret=mir_none());
    first = fn.new_block("entry");
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        for block in blocks {
            self.lower_body(list(block.body or []));
        }
        if not self.builder().block.terminated() {
            self.builder().ret(None);
        }
        for blk in fn.blocks {
            if not blk.terminated() {
                self.builder().position(blk);
                self.builder().unreachable();
            }
        }
    } except MirRefused as err {
        self.refusals.setdefault("with entry", []).append(refusal_of(err));
        self.state = None;
        return None;
    }
    self.state = None;
    return fn;
}
