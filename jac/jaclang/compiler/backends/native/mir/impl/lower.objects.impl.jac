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
    if not isinstance(t, ClassType) or t._shared is None {
        return None;
    }
    scope = t.shared.symbol_table;
    if not isinstance(scope, uni.Archetype)
        or c_builtin_kind(t)
        or foreign_struct_of_type(t) is not None {
        return None;
    }
    return None if stub_archetype(scope) else scope;
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
        raise MirRefused(
            mir_refusal("archetype", name, arch, "The archetype has no native layout.")
        );
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
        vtable_slot=layout.vtable_ptr_slot
            if layout.vtable_ptr_slot is not None
            else -1,
        tag_slot=layout.type_tag_slot if layout.type_tag_slot is not None else -1,
        reports_slot=layout.reports_slot if layout.reports_slot is not None else -1,
        is_acyclic=layout.is_acyclic,
        local=local,
        drop_symbol=native_symbol_name(prefix, f"{name}.__drop"),
        trace_symbol=native_symbol_name(prefix, f"{name}.__trace"),
        class_symbol=native_symbol_name(
            prefix, native_unit_spelling(f"{name}.__class", owner.loc.mod_path)
        )
    );
    self.mir.objects[name] = made;
    self.archetypes[name] = arch;
    for member in layout.fields {
        if member.name == EXC_MESSAGE_FIELD {
            made.fields.append(
                MirObjectField(name=member.name, type=mir_str_ref(), index=member.index)
            );
            continue;
        }
        field_type = member.semantic_type or self.declared_field_type(member.decl_node);
        self.ensure_objects(field_type);
        made.fields.append(
            MirObjectField(
                name=member.name,
                type=mir_any()
                    if self.erased_slot(field_type)
                    else mir_type_of(
                        field_type, MirPosition.FIELD, member.decl_node or arch
                    ),
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
            if owner_arch is not None {
                made.vtable_methods.append(self.method_symbol(owner_arch, slot.name));
                continue;
            }
            owner_layout = get_layout_registry(owner, self.prog).get_layout(slot.owner);
            owner_path = owner_layout.decl_mod
                if owner_layout is not None and owner_layout.decl_mod
                else owner.loc.mod_path;
            made.vtable_methods.append(
                native_symbol_name(
                    native_unit_prefix(owner_path),
                    native_unit_spelling(f"{slot.owner}.{slot.name}", owner_path)
                )
            );
        }
        for ancestor in layout.mro {
            ancestor_layout = get_layout_registry(owner, self.prog).get_layout(
                ancestor
            );
            if ancestor_layout is not None and ancestor_layout.has_vtable {
                ancestor_path = ancestor_layout.decl_mod or owner.loc.mod_path;
                made.ancestry.append(
                    native_symbol_name(
                        native_unit_prefix(ancestor_path),
                        native_unit_spelling(f"{ancestor}.__vtable", ancestor_path)
                    )
                );
            }
        }
    }
    if not local {
        self.mir.externs[made.drop_symbol] = MirExtern(
            symbol=made.drop_symbol,
            ret=mir_none(),
            params=[mir_c_ptr(mir_int(8, False))]
        );
        unit = os.path.realpath(owner.loc.mod_path);
        if unit not in self.mir.deps {
            self.mir.deps.append(unit);
        }
    }
    return made;
}

impl MirLowering.declared_field_type(decl: (uni.UniNode | None)) -> (TypeBase | None) {
    if not isinstance(decl, uni.HasVar) or decl.name.sym is None {
        return None;
    }
    return self.prog.get_type_evaluator().get_type_of_symbol(decl.name.sym);
}

impl MirLowering.arch_methods(arch: uni.Archetype) -> list[uni.Ability] {
    found: list[uni.Ability] = [];
    for member in list(ModuleFacts.unwrap_body(arch) or []) {
        if isinstance(member, uni.Ability)
            and isinstance(member.signature, uni.FuncSignature) {
            found.append(member);
        }
    }
    return found;
}

impl MirLowering.find_method(arch: uni.Archetype, name: str) -> (uni.Ability | None) {
    for holder in self.lineage(arch) {
        for method in self.arch_methods(holder) {
            if self.name_of(method) == name {
                return method;
            }
        }
    }
    return None;
}

impl MirLowering.lineage(arch: uni.Archetype) -> list[uni.Archetype] {
    sym = arch.name.sym if arch.name is not None else None;
    made = self.prog.get_type_evaluator().get_type_of_symbol(sym)
        if sym is not None
        else None;
    if isinstance(made, ClassType) and made._shared is not None {
        found: list[uni.Archetype] = [];
        for ancestor in made.shared.mro {
            scope = ancestor.shared.symbol_table
                if ancestor._shared is not None
                else None;
            if isinstance(scope, uni.Archetype)
                and not stub_archetype(scope)
                and scope not in found {
                found.append(scope);
            }
        }
        if found {
            return found;
        }
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    layout = get_layout_registry(owner, self.prog).get_layout(
        archetype_native_name(arch)
    );
    found = [arch];
    for ancestor in list(layout.mro)[1:] if layout is not None else [] {
        holder = self.archetypes.get(ancestor);
        if holder is not None {
            found.append(holder);
        }
    }
    return found;
}

impl MirLowering.method_symbol(arch: uni.Archetype, name: str) -> str {
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    return native_symbol_name(
        native_unit_prefix(owner.loc.mod_path),
        native_unit_spelling(
            f"{archetype_native_name(arch)}.{name}", owner.loc.mod_path
        )
    );
}

impl MirLowering.foreign_method_decl(method: uni.Ability) -> (MirDecl | None) {
    owner = method.parent
        if isinstance(method.parent, uni.Archetype)
        else method.find_parent_of_type(uni.Archetype);
    unit = method.find_parent_of_type(uni.Module);
    sig = method.signature;
    if owner is None
        or unit is None
        or unit is self.module
        or not unit.loc.mod_path.endswith(".jac")
        or not isinstance(sig, uni.FuncSignature)
        or method.is_static
        or self.is_template(method) {
        return None;
    }
    self_type = self.object_type(owner);
    params = [self.symbol_type(pv.name.sym, pv) for pv in self.param_nodes(sig, True)];
    fn_type = self.prog.get_type_evaluator().get_type_of_symbol(
        self.ability_sym(method)
    );
    ret = mir_none();
    if isinstance(fn_type, FunctionType) {
        ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, method);
    }
    symbol = self.method_symbol(owner, self.name_of(method));
    self.mir.externs[symbol] = MirExtern(
        symbol=symbol, ret=ret, params=[self_type] + params
    );
    path = os.path.realpath(unit.loc.mod_path);
    if path not in self.mir.deps {
        self.mir.deps.append(path);
    }
    made = MirDecl(
        ability=method,
        symbol=symbol,
        params=params,
        ret=ret,
        self_type=self_type,
        owner=owner
    );
    self.decls[id(method)] = made;
    return made;
}

impl MirLowering.declare_archetype(arch: uni.Archetype) {
    enum_type = self.enum_self_type(arch);
    if enum_type is not None {
        self.declare_enum_methods(arch, enum_type);
        return;
    }
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
        fn_type = self.prog.get_type_evaluator().get_type_of_symbol(
            self.ability_sym(method)
        );
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
    self.declare_accessors(arch, self_type);
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
        for pv in self.param_nodes(init.signature, True) {
            found.append((pv.name.value, self.symbol_type(pv.name.sym, pv), pv.value));
        }
        return found;
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    layout = get_layout_registry(owner, self.prog).get_layout(
        archetype_native_name(arch)
    );
    if layout is None {
        return found;
    }
    obj_def = self.object_def(arch);
    for member in layout.fields {
        decl = member.decl_node;
        if (isinstance(decl, uni.HasVar) and decl.defer)
            or member.name == EXC_MESSAGE_FIELD {
            continue;
        }
        default_value = member.default_expr
            if isinstance(member.default_expr, uni.Expr)
            else None;
        nearest = self.nearest_has_var(arch, member.name);
        if nearest is not None and nearest is not decl {
            default_value = nearest.value
                if isinstance(nearest.value, uni.Expr)
                else None;
        }
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
    symbol = native_symbol_name(
        native_unit_prefix(owner.loc.mod_path), f"{obj_def.name}.__ctor"
    );
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
        if self.ctor_takes_mask(params) {
            given = fn.new_value(mir_int(), "__given");
            fn.params.append(MirParam(name="__given", value=given));
            for (index, (pname, ptype, fallback)) in enumerate(params) {
                if fallback is None {
                    continue;
                }
                values[index] = self.ctor_default(
                    values[index], given, index, fallback
                );
            }
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
        self.runtime(
            "__jac_rt_set_type",
            [
                this,
                self.emit_value(
                    MirOp.CLASS_ADDR,
                    mir_c_ptr(mir_int(8, False)),
                    [],
                    str_value=obj_def.name
                )
            ]
        );
        address = self.address_of(this);
        drop_address = self.emit_value(
            MirOp.PTR_INT,
            mir_int(),
            [
                self.emit_value(
                    MirOp.FN_ADDR,
                    mir_c_fn([mir_c_ptr(mir_int(8, False))], mir_none()),
                    [],
                    callee=obj_def.drop_symbol
                )
            ]
        );
        self.emit_value(
            MirOp.MEM_STORE,
            mir_none(),
            [b.binary("sub", address, b.const_int(8, mir_int())), drop_address]
        );
        if obj_def.vtable_slot >= 0 {
            slot = self.emit_value(
                MirOp.FIELD_ADDR,
                mir_c_ptr(mir_c_ptr(mir_c_ptr(mir_int(8, False)))),
                [this],
                int_value=obj_def.vtable_slot
            );
            b.store(
                slot,
                self.emit_value(
                    MirOp.VTABLE_ADDR,
                    mir_c_ptr(mir_c_ptr(mir_int(8, False))),
                    [],
                    str_value=obj_def.name
                )
            );
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
            nearest = self.nearest_has_var(arch, member.name);
            initial = nearest.value if nearest is not None else member.default_expr;
            if member.name in named or not isinstance(initial, uni.Expr) {
                continue;
            }
            place = self.field_place(this, arch, member.name, arch);
            b.store(place, self.default_value(initial, self.place_elem(place)));
        }
        if init is not None {
            decl = self.decls.get(id(init)) or self.foreign_method_decl(init);
            if decl is None {
                raise MirRefused(
                    mir_refusal("constructor", f"{obj_def.name}.init", init)
                );
            }
            receiver = this
                if decl.self_type is None or decl.self_type is this.type
                else b.ref_cast(this, decl.self_type, False);
            b.call(decl.symbol, [receiver] + values, decl.ret);
        }
        post = self.find_method(arch, "postinit")
            or self.find_method(arch, "__post_init__");
        if post is not None {
            decl = self.decls.get(id(post)) or self.foreign_method_decl(post);
            if decl is not None {
                receiver = this
                    if decl.self_type is None or decl.self_type is this.type
                    else b.ref_cast(this, decl.self_type, False);
                b.call(decl.symbol, [receiver], decl.ret);
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

impl MirLowering.lower_drop(obj_def: MirObjectDef, arch: uni.Archetype) -> MirFunction {
    i8p = mir_c_ptr(mir_int(8, False));
    fn = MirFunction(
        name=f"{obj_def.name}.__drop",
        symbol=obj_def.drop_symbol,
        ret=mir_none(),
        manual_rc=True
    );
    first = fn.new_block("entry");
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    b = self.builder();
    raw = fn.new_value(i8p, "o");
    fn.params.append(MirParam(name="o", value=raw));
    this = b.ref_cast(raw, mir_obj(obj_def.name), False);
    try {
        self.drop_hook(arch, raw);
    } except MirRefused as err {
        self.refusals.setdefault(fn.symbol, []).append(refusal_of(err));
    }
    collecting = self.emit_value(
        MirOp.MEM_LOAD,
        mir_int(8, True, True),
        [
            self.emit_value(
                MirOp.GLOBAL_BLOCK,
                mir_int(),
                [],
                str_value="__rc_collecting",
                int_value=1
            )
        ]
    );
    self.mir.global_blocks["__rc_collecting"] = max(
        self.mir.global_blocks.get("__rc_collecting", 0), 1
    );
    release_bb = fn.new_block("drop.fields");
    free_bb = fn.new_block("drop.free");
    b.cond_branch(
        b.compare("eq", collecting, b.const_int(0, collecting.type)),
        release_bb,
        free_bb
    );
    b.position(release_bb);
    for member in obj_def.fields {
        if not mir_holds_ref(member.type) {
            continue;
        }
        place = self.emit_value(
            MirOp.FIELD_ADDR, mir_c_ptr(member.type), [this], int_value=member.index
        );
        b.emit(MirInstr(op=MirOp.RELEASE, operands=[b.load(place, member.type)]));
    }
    b.branch(free_bb);
    b.position(free_bb);
    self.osp_drop(obj_def, raw);
    address = self.address_of(raw);
    self.runtime(
        "__jac_rt_free_block", [b.binary("sub", address, b.const_int(32, mir_int()))]
    );
    b.ret(None);
    self.state = saved;
    return fn;
}

impl MirLowering.drop_hook(arch: uni.Archetype, raw: MirValue) {
    hook = self.find_method(arch, "drop");
    if hook is None
        or hook.is_static
        or not isinstance(hook.signature, uni.FuncSignature)
        or self.param_nodes(hook.signature, True) {
        return;
    }
    decl = self.method_decl(arch, hook, "drop", hook);
    if decl.self_type is None {
        return;
    }
    b = self.builder();
    fn = self.st().fn;
    self.emit_value(
        MirOp.MEM_STORE,
        mir_none(),
        [
            b.binary("sub", self.address_of(raw), b.const_int(16, mir_int())),
            b.const_int(DROP_RC_SENTINEL, mir_int())
        ]
    );
    frame = fn.new_value(mir_c_ptr(mir_int(8, False)), "exc.frame");
    fn.blocks[0].instrs.insert(0, MirInstr(op=MirOp.EXC_FRAME, result=frame));
    self.runtime("__jac_rt_exc_push", [frame]);
    buffer = self.runtime("__jac_rt_exc_jmp_buf", [frame]);
    if buffer is None {
        raise MirRefused(mir_refusal("method", "drop", hook));
    }
    armed = self.emit_value(MirOp.SETJMP, mir_int(32, True, True), [buffer]);
    call_bb = fn.new_block("drop.hook");
    raised_bb = fn.new_block("drop.raised");
    done_bb = fn.new_block("drop.hooked");
    b.cond_branch(
        b.compare("eq", armed, b.const_int(0, armed.type)), call_bb, raised_bb
    );
    b.position(call_bb);
    b.call(decl.symbol, [b.ref_cast(raw, decl.self_type, False)], mir_none());
    self.runtime("__jac_rt_exc_pop", [frame]);
    b.branch(done_bb);
    b.position(raised_bb);
    self.runtime("__jac_rt_exc_pop", [frame]);
    address = self.address_of(frame);
    message = self.emit_value(
        MirOp.MEM_LOAD,
        mir_int(),
        [b.binary("add", address, b.const_int(EXC_MESSAGE_OFFSET, mir_int()))]
    );
    shown = archetype_native_name(arch).split("$")[0];
    self.write_value(
        b.const_str(f"Exception ignored in: {shown}.drop: ", mir_str()), 2, hook
    );
    has_message_bb = fn.new_block("drop.message");
    newline_bb = fn.new_block("drop.newline");
    b.cond_branch(
        b.compare("ne", message, b.const_int(0, mir_int())), has_message_bb, newline_bb
    );
    b.position(has_message_bb);
    text = self.emit_value(MirOp.PTR_CAST, mir_str_ref(), [message]);
    size = self.runtime("__jac_rt_str_size", [text]);
    if size is not None {
        self.write_value(b.str_make(text, text, size), 2, hook);
    }
    b.branch(newline_bb);
    b.position(newline_bb);
    self.write_value(b.const_str("\n", mir_str()), 2, hook);
    b.branch(done_bb);
    b.position(done_bb);
}

impl MirLowering.lower_trace(obj_def: MirObjectDef) -> MirFunction {
    i8p = mir_c_ptr(mir_int(8, False));
    visitor_type = mir_c_fn([i8p], mir_none());
    fn = MirFunction(
        name=f"{obj_def.name}.__trace",
        symbol=obj_def.trace_symbol,
        ret=mir_none(),
        manual_rc=True
    );
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
        held = member.type.payload()
            if member.type.kind == MirKind.OPT
            else member.type;
        if not mir_holds_ref(held)
            or held.kind in (MirKind.STR, MirKind.STR_REF, MirKind.ANY) {
            continue;
        }
        place = self.emit_value(
            MirOp.FIELD_ADDR, mir_c_ptr(member.type), [this], int_value=member.index
        );
        loaded = b.load(place, member.type);
        children: list[MirValue] = [loaded];
        if member.type.kind == MirKind.TUPLE {
            children = [
                self.tuple_get(loaded, index) for index in range(len(member.type.args))
            ];
        }
        for child in children {
            if child.type.kind
                in (MirKind.STR, MirKind.STR_REF, MirKind.ANY, MirKind.TUPLE)
                or not mir_holds_ref(child.type) {
                continue;
            }
            if child.type.kind == MirKind.OPT {
                if child.type.payload().kind
                    in (MirKind.STR, MirKind.STR_REF, MirKind.ANY, MirKind.TUPLE) {
                    continue;
                }
                present = fn.new_block("trace.some");
                after = fn.new_block("trace.next");
                b.cond_branch(self.opt_present(child), present, after);
                b.position(present);
                self.emit_value(
                    MirOp.CALL_FNPTR,
                    mir_none(),
                    [
                        visit_fn,
                        self.emit_value(MirOp.PTR_CAST, i8p, [self.opt_get(child)])
                    ]
                );
                b.branch(after);
                b.position(after);
                continue;
            }
            self.emit_value(
                MirOp.CALL_FNPTR,
                mir_none(),
                [visit_fn, self.emit_value(MirOp.PTR_CAST, i8p, [child])]
            );
        }
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
    if holder.type.kind not in (MirKind.OBJ, MirKind.OSP) {
        raise MirRefused(
            mir_refusal(
                "attribute access",
                f"{obj_def.name}.{name} on {holder.type.render()}",
                site
            )
        );
    }
    return self.emit_value(
        MirOp.FIELD_ADDR, mir_c_ptr(member.type), [holder], int_value=member.index
    );
}

impl MirLowering.object_call(nd: uni.FuncCall, arch: uni.Archetype) -> MirValue {
    obj_def = self.object_def(arch);
    if obj_def.field(EXC_MESSAGE_FIELD) is not None
        and (self.find_method(arch, "init") or self.find_method(arch, "__init__"))
            is None {
        return self.exception_object(nd, arch);
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    symbol = native_symbol_name(
        native_unit_prefix(owner.loc.mod_path), f"{obj_def.name}.__ctor"
    );
    params = self.constructor_params(arch);
    init = self.find_method(arch, "init") or self.find_method(arch, "__init__");
    if init is not None
        and isinstance(init.signature, uni.FuncSignature)
        and (
            init.signature.varargs is not None
            or init.signature.kwargs is not None
            or init.signature.kwonlyargs
            or self.has_spread(nd)
        ) {
        bound = self.bound_args(nd, init, True);
        if len(bound) != len(params) {
            raise MirRefused(
                mir_refusal("call", f"{obj_def.name} with {len(bound)} arguments", nd)
            );
        }
        values = self.bound_values(list(bound), [param[1] for param in params]);
        if self.ctor_takes_mask(params) {
            given = 0;
            for (index, param) in enumerate(params) {
                if param[2] is not None {
                    given = given | (1 << index);
                }
            }
            values.append(self.builder().const_int(given, mir_int()));
        }
        return self.construct(symbol, obj_def, owner, params, values, nd);
    }
    values = self.ctor_arguments(nd, obj_def.name, params);
    return self.construct(symbol, obj_def, owner, params, values, nd);
}

impl MirLowering.construct(
    symbol: str,
    obj_def: MirObjectDef,
    owner: uni.Module,
    params: list[tuple[str, MirType, (uni.Expr | None)]],
    values: list[MirValue],
    nd: uni.FuncCall
) -> MirValue {
    if not obj_def.local {
        self.mir.externs[symbol] = MirExtern(
            symbol=symbol,
            ret=mir_obj(obj_def.name),
            params=[p[1] for p in params]
                + ([mir_int()] if self.ctor_takes_mask(params) else [])
        );
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
    decl = self.method_decl(arch, method, name, nd);
    receiver = self.method_receiver(decl, arch, receiver, nd);
    args = self.bound_args(nd, method, True);
    if len(args) != len(decl.params) {
        raise MirRefused(mir_refusal("call", f"{name} with {len(args)} arguments", nd));
    }
    values = [receiver] + self.bound_values(list(args), decl.params);
    return self.invoke_method(decl, arch, name, values);
}

impl MirLowering.unbound_method(
    nd: uni.FuncCall, arch: uni.Archetype, name: str
) -> (MirValue | None) {
    method = self.find_method(arch, name);
    passed = list(nd.params or []);
    if method is None
        or method.is_static
        or id(method) in self.templates
        or self.has_spread(nd)
        or not passed
        or isinstance(passed[0], uni.KWPair)
        or (
            isinstance(passed[0], uni.UnaryExpr)
            and passed[0].op.name in (Tok.STAR_MUL, Tok.STAR_POW)
        ) {
        return None;
    }
    decl = self.method_decl(arch, method, name, nd);
    if decl.self_type is None {
        return None;
    }
    first = passed[0];
    receiver = self.lower_expr(first);
    holder = self.arch_of_type(first.type) if isinstance(first, uni.Expr) else None;
    receiver = self.method_receiver(decl, holder or arch, receiver, first);
    args = self.bound_args(nd, method, True, 1);
    if len(args) != len(decl.params) {
        raise MirRefused(mir_refusal("call", f"{name} with {len(args)} arguments", nd));
    }
    values = [receiver] + self.bound_values(list(args), decl.params);
    result = self.builder().call(decl.symbol, values, decl.ret);
    if result is None {
        return self.builder().const_bool(False);
    }
    return result;
}

impl MirLowering.method_decl(
    arch: uni.Archetype, method: uni.Ability, name: str, site: uni.UniNode
) -> MirDecl {
    decl = self.decls.get(id(method)) or self.foreign_method_decl(method);
    if decl is None {
        raise MirRefused(
            mir_refusal("method", f"{archetype_native_name(arch)}.{name}", site)
        );
    }
    return decl;
}

impl MirLowering.method_receiver(
    decl: MirDecl, arch: uni.Archetype, receiver: MirValue, site: uni.UniNode
) -> MirValue {
    if decl.self_type is None or receiver.type is decl.self_type {
        return receiver;
    }
    if receiver.type.kind == MirKind.OBJ
        and self.obj_extends(archetype_native_name(arch), decl.self_type.name) {
        return self.builder().ref_cast(receiver, decl.self_type, False);
    }
    return self.coerce(receiver, decl.self_type, site);
}

impl MirLowering.invoke_method(
    decl: MirDecl, arch: uni.Archetype, name: str, values: list[MirValue]
) -> MirValue {
    receiver = values[0];
    obj_def = self.object_def(arch);
    if obj_def.vtable_symbol
        and decl.symbol in obj_def.vtable_methods
        and name not in NON_DISPATCHED_METHODS {
        b = self.builder();
        i8p = mir_c_ptr(mir_int(8, False));
        slot_place = self.emit_value(
            MirOp.FIELD_ADDR,
            mir_c_ptr(mir_c_ptr(i8p)),
            [receiver],
            int_value=obj_def.vtable_slot
        );
        table = b.load(slot_place, mir_c_ptr(i8p));
        index = obj_def.vtable_methods.index(decl.symbol) + VTABLE_HEADER_SLOTS;
        entry_place = self.emit_value(
            MirOp.PTR_OFFSET, mir_c_ptr(i8p), [table, b.const_int(index, mir_int())]
        );
        target = b.load(entry_place, i8p);
        signature = mir_c_fn([receiver.type] + decl.params, decl.ret);
        callee = self.emit_value(MirOp.PTR_CAST, signature, [target]);
        result_type = mir_none()
            if decl.ret.kind in (MirKind.NONE, MirKind.VOID)
            else decl.ret;
        result = self.emit_value(MirOp.CALL_FNPTR, result_type, [callee] + values);
        result.owned = mir_holds_ref(result_type);
        return result;
    }
    direct = self.builder().call(decl.symbol, values, decl.ret);
    return direct if direct is not None else self.builder().const_bool(False);
}

impl MirLowering.isinstance_check(value: MirValue, arch: uni.Archetype) -> MirValue {
    b = self.builder();
    if value.type.kind == MirKind.OPT and value.type.payload().kind == MirKind.OBJ {
        (held, payload, absent, done) = self.opt_begin(value, mir_bool());
        self.opt_switch(held, self.isinstance_check(payload, arch), absent, done);
        return self.opt_end(held, self.builder().const_bool(False), done);
    }
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
    slot_place = self.emit_value(
        MirOp.FIELD_ADDR,
        mir_c_ptr(mir_c_ptr(i8p)),
        [value],
        int_value=source_def.vtable_slot
    );
    table = b.load(slot_place, mir_c_ptr(i8p));
    lineage = b.load(
        self.emit_value(
            MirOp.PTR_OFFSET, mir_c_ptr(i8p), [table, b.const_int(1, mir_int())]
        ),
        i8p
    );
    wanted = self.emit_value(
        MirOp.PTR_INT,
        mir_int(),
        [self.emit_value(MirOp.VTABLE_ADDR, mir_c_ptr(i8p), [], str_value=obj_def.name)]
    );
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
    if not self.trace_pairs
        and not self.deferred_globals
        and not self.osp_setup
        and not self.class_entries {
        return None;
    }
    path = self.module.loc.mod_path;
    fn = MirFunction(
        name="__glob_init", symbol=native_glob_init_name(path), ret=mir_none()
    );
    first = fn.new_block("entry");
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        b = self.builder();
        for (drop_symbol, trace_symbol) in self.trace_pairs {
            i8p = mir_c_ptr(mir_int(8, False));
            drop_fn = self.emit_value(
                MirOp.FN_ADDR, mir_c_fn([i8p], mir_none()), [], callee=drop_symbol
            );
            trace_fn = self.emit_value(
                MirOp.FN_ADDR,
                mir_c_fn([i8p, mir_c_fn([i8p], mir_none())], mir_none()),
                [],
                callee=trace_symbol
            );
            self.runtime(
                "__jac_rt_trace_register",
                [
                    self.emit_value(MirOp.PTR_INT, mir_int(), [drop_fn]),
                    self.emit_value(MirOp.PTR_INT, mir_int(), [trace_fn])
                ]
            );
        }
        for (made_name, bound_name, adapter_symbol) in self.class_entries {
            i8p = mir_c_ptr(mir_int(8, False));
            adapter_fn = self.emit_value(
                MirOp.FN_ADDR, mir_c_fn([], mir_none()), [], callee=adapter_symbol
            );
            self.runtime(
                "__jac_rt_class_ctor_register",
                [
                    self.address_of(
                        self.emit_value(MirOp.CLASS_ADDR, i8p, [], str_value=made_name)
                    ),
                    self.address_of(
                        self.emit_value(MirOp.CLASS_ADDR, i8p, [], str_value=bound_name)
                    ),
                    self.emit_value(MirOp.PTR_INT, mir_int(), [adapter_fn])
                ]
            );
        }
        if self.osp_setup {
            b.call(self.osp_setup, [], mir_none());
        }
        index = 0;
        while index < len(self.deferred_globals) {
            for used in self.deferred_globals[index][1].get_all_sub_nodes(uni.Name) {
                self.declare_global(used);
            }
            index += 1;
        }
        ordered = sorted(
            self.deferred_globals,
            key=lambda (pair: tuple[MirGlobal, uni.Expr]) -> int { pair[
                1
            ].loc.pos_start; }
        );
        for (glob_def, initial) in ordered {
            place = self.emit_value(
                MirOp.GLOBAL_ADDR,
                mir_c_ptr(glob_def.type),
                [],
                str_value=glob_def.symbol
            );
            b.store(
                place, self.coerce(self.lower_expr(initial), glob_def.type, initial)
            );
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
    fn = MirFunction(
        name="__entry",
        symbol=native_entry_name(self.module.loc.mod_path),
        ret=mir_none()
    );
    first = fn.new_block("entry");
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        for block in blocks {
            self.lower_body(list(block.body or []));
        }
        if not self.builder().block.terminated() {
            self.flush_stdio();
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

impl MirLowering.erased_slot(t: (TypeBase | None)) -> bool {
    if isinstance(t, TypeVarType) {
        return not t.is_self;
    }
    if not isinstance(t, UnionType) {
        return False;
    }
    erased = False;
    for member in t.types {
        if isinstance(member, TypeVarType) and not member.is_self {
            erased = True;
        } elif not (
            isinstance(member, ClassType)
            and member.shared.class_name in ("NoneType", "None")
        ) {
            return False;
        }
    }
    return erased;
}

impl MirLowering.class_reference(nd: uni.Expr) -> (uni.Archetype | None) {
    t = nd.type;
    if not isinstance(t, ClassType)
        or t._shared is None
        or not t.is_instantiable()
        or t.is_instance()
        or is_enum_class_type(t) {
        return None;
    }
    return self.arch_of_type(t);
}

impl MirLowering.class_value(arch: uni.Archetype) -> MirValue {
    obj_def = self.object_def(arch);
    return self.emit_value(
        MirOp.CLASS_ADDR, mir_class("*"), [], str_value=obj_def.name
    );
}

impl MirLowering.class_isinstance(value: MirValue, kind: MirValue) -> MirValue {
    b = self.builder();
    i8p = mir_c_ptr(mir_int(8, False));
    wanted = self.address_of(self.emit_value(MirOp.PTR_CAST, i8p, [kind]));
    if value.type.kind != MirKind.OBJ {
        return b.const_bool(False);
    }
    obj_def = self.mir.objects.get(value.type.name);
    if obj_def is None or obj_def.vtable_slot < 0 {
        named = self.runtime_value("__jac_rt_type_name", [value]);
        return b.compare("eq", self.address_of(named), wanted);
    }
    slot_place = self.emit_value(
        MirOp.FIELD_ADDR,
        mir_c_ptr(mir_c_ptr(i8p)),
        [value],
        int_value=obj_def.vtable_slot
    );
    table = b.load(slot_place, mir_c_ptr(i8p));
    lineage = b.load(
        self.emit_value(
            MirOp.PTR_OFFSET, mir_c_ptr(i8p), [table, b.const_int(1, mir_int())]
        ),
        i8p
    );
    walk = self.temp_slot(mir_int());
    verdict = self.temp_slot(mir_bool());
    b.store(walk, self.address_of(lineage));
    b.store(verdict, b.const_bool(False));
    fn = self.st().fn;
    head = fn.new_block("isa.cls.head");
    body = fn.new_block("isa.cls.body");
    done = fn.new_block("isa.cls.done");
    b.branch(head);
    b.position(head);
    entry_value = self.emit_value(MirOp.MEM_LOAD, mir_int(), [b.load(walk, mir_int())]);
    b.cond_branch(b.compare("ne", entry_value, b.const_int(0, mir_int())), body, done);
    b.position(body);
    found = b.compare(
        "eq", self.emit_value(MirOp.MEM_LOAD, mir_int(), [entry_value]), wanted
    );
    b.store(verdict, found);
    b.store(walk, b.binary("add", b.load(walk, mir_int()), b.const_int(8, mir_int())));
    b.cond_branch(found, done, head);
    b.position(done);
    return b.load(verdict, mir_bool());
}

impl MirLowering.class_of(value: MirValue, site: uni.UniNode) -> MirValue {
    b = self.builder();
    if value.type.kind != MirKind.OBJ {
        return self.type_value(value, site);
    }
    obj_def = self.mir.objects.get(value.type.name);
    if obj_def is None {
        return self.type_value(value, site);
    }
    if obj_def.vtable_slot < 0 {
        return self.emit_value(
            MirOp.CLASS_ADDR, mir_class("*"), [], str_value=obj_def.name
        );
    }
    i8p = mir_c_ptr(mir_int(8, False));
    slot_place = self.emit_value(
        MirOp.FIELD_ADDR,
        mir_c_ptr(mir_c_ptr(i8p)),
        [value],
        int_value=obj_def.vtable_slot
    );
    table = b.load(slot_place, mir_c_ptr(i8p));
    return self.emit_value(MirOp.PTR_CAST, mir_class("*"), [b.load(table, i8p)]);
}

impl MirLowering.ctor_takes_mask(
    params: list[tuple[str, MirType, (uni.Expr | None)]]
) -> bool {
    defaulted = [
        index
        for (index, param) in enumerate(params)
        if param[2] is not None
    ];
    if defaulted and max(defaulted) >= CTOR_MASK_BITS {
        raise MirRefused(
            mir_refusal(
                "constructor",
                f"{len(params)} parameters",
                None,
                "A native constructor marks which defaulted parameters were given in one 63-bit word."
            )
        );
    }
    return bool(defaulted);
}

impl MirLowering.ctor_default(
    value: MirValue, given: MirValue, index: int, fallback: uni.Expr
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    held = self.temp_slot(value.type);
    bit = b.binary(
        "and",
        b.binary("shr", given, b.const_int(index, mir_int())),
        b.const_int(1, mir_int())
    );
    supplied = fn.new_block("ctor.given");
    missing = fn.new_block("ctor.default");
    done = fn.new_block("ctor.arg");
    b.cond_branch(b.compare("ne", bit, b.const_int(0, mir_int())), supplied, missing);
    b.position(supplied);
    b.store(held, value);
    b.branch(done);
    b.position(missing);
    b.store(held, self.default_value(fallback, value.type));
    b.branch(done);
    b.position(done);
    return b.load(held, value.type);
}

impl MirLowering.placeholder(t: MirType) -> MirValue {
    if t.kind == MirKind.NONE {
        return self.none_value();
    }
    return self.builder().const_null(t);
}

impl MirLowering.ctor_arguments(
    nd: uni.FuncCall, label: str, params: list[tuple[str, MirType, (uni.Expr | None)]]
) -> list[MirValue] {
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
        } else {
            positional.append(arg);
        }
    }
    if len(positional) > len(params) {
        raise MirRefused(
            mir_refusal("call", f"{label} with {len(positional)} arguments", nd)
        );
    }
    values: list[MirValue] = [];
    mask = 0;
    for (index, (pname, ptype, fallback)) in enumerate(params) {
        source = positional[index] if index < len(positional) else named.get(pname);
        if source is None and fallback is not None {
            values.append(self.placeholder(ptype));
            continue;
        }
        if fallback is not None {
            mask = mask | (1 << index);
        }
        if source is None {
            raise MirRefused(mir_refusal("call", f"{label} missing {pname}", nd));
        }
        values.append(self.coerce(self.lower_expr(source), ptype, source));
    }
    if self.ctor_takes_mask(params) {
        values.append(self.builder().const_int(mask, mir_int()));
    }
    return values;
}

impl MirLowering.class_value_call(nd: uni.FuncCall, bound: uni.Archetype) -> MirValue {
    b = self.builder();
    obj_def = self.object_def(bound);
    kind = self.lower_expr(nd.target);
    params = self.constructor_params(bound);
    values = self.ctor_arguments(nd, obj_def.name, params);
    i8p = mir_c_ptr(mir_int(8, False));
    found = self.runtime_value(
        "__jac_rt_class_ctor_find",
        [
            self.address_of(self.emit_value(MirOp.PTR_CAST, i8p, [kind])),
            self.address_of(
                self.emit_value(MirOp.CLASS_ADDR, i8p, [], str_value=obj_def.name)
            )
        ]
    );
    self.raise_if(
        b.compare("eq", found, b.const_int(0, mir_int())),
        "TypeError",
        f"this class cannot be constructed with the arguments of {obj_def.name.split(
            '$'
        )[0]}"
    );
    made_type = mir_obj(obj_def.name);
    callee = self.emit_value(
        MirOp.PTR_CAST, mir_c_fn([v.type for v in values], made_type), [found]
    );
    result = self.emit_value(MirOp.CALL_FNPTR, made_type, [callee] + values);
    result.owned = True;
    return result;
}

impl MirLowering.class_entry(
    arch: uni.Archetype, bound: uni.Archetype
) -> (MirFunction | None) {
    obj_def = self.object_def(arch);
    bound_def = self.object_def(bound);
    accepts = self.constructor_params(arch);
    taken = self.constructor_params(bound);
    names = [param[0] for param in taken];
    for (pname, _, fallback) in accepts {
        if fallback is None and pname not in names {
            return None;
        }
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    prefix = native_unit_prefix(owner.loc.mod_path);
    ctor = native_symbol_name(prefix, f"{obj_def.name}.__ctor");
    symbol = native_symbol_name(
        prefix, f"{obj_def.name}.__new_as.{mono_symbol_text(bound_def.name)}"
    );
    result_type = mir_obj(bound_def.name);
    fn = MirFunction(
        name=f"{obj_def.name}.__new_as",
        symbol=symbol,
        ret=result_type,
        linkage="internal"
    );
    first = fn.new_block("entry");
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        b = self.builder();
        given: list[MirValue] = [];
        for (pname, ptype, _) in taken {
            value = fn.new_value(ptype, pname);
            fn.params.append(MirParam(name=pname, value=value));
            given.append(value);
        }
        supplied = b.const_int(-1, mir_int());
        if self.ctor_takes_mask(taken) {
            supplied = fn.new_value(mir_int(), "__given");
            fn.params.append(MirParam(name="__given", value=supplied));
        }
        args: list[MirValue] = [];
        mask = b.const_int(0, mir_int());
        for (index, (pname, ptype, fallback)) in enumerate(accepts) {
            if pname not in names {
                args.append(self.placeholder(ptype));
                continue;
            }
            at = names.index(pname);
            args.append(self.coerce(given[at], ptype, arch));
            if taken[at][2] is None {
                if fallback is not None {
                    mask = b.binary("or", mask, b.const_int(1 << index, mir_int()));
                }
                continue;
            }
            bit = b.binary(
                "and",
                b.binary("shr", supplied, b.const_int(at, mir_int())),
                b.const_int(1, mir_int())
            );
            if fallback is None {
                self.raise_if(
                    b.compare("eq", bit, b.const_int(0, mir_int())),
                    "TypeError",
                    f"{obj_def.name.split('$')[0]}() missing required argument: '{pname}'"
                );
            } else {
                mask = b.binary(
                    "or", mask, b.binary("shl", bit, b.const_int(index, mir_int()))
                );
            }
        }
        if self.ctor_takes_mask(accepts) {
            args.append(mask);
        }
        made = b.call(ctor, args, mir_obj(obj_def.name));
        if made is None {
            raise MirRefused(mir_refusal("constructor", obj_def.name, arch));
        }
        b.ret(
            b.ref_cast(made, result_type, True)
                if made.type is not result_type
                else made
        );
    } except MirRefused as err {
        self.state = saved;
        return None;
    }
    self.state = saved;
    self.class_entries.append((obj_def.name, bound_def.name, symbol));
    return fn;
}

impl MirLowering.class_bound(t: (TypeBase | None)) -> (uni.Archetype | None) {
    if not isinstance(t, ClassType) or t._shared is None {
        return None;
    }
    args = t.private.type_args if t.private else None;
    bound = args[0] if args else None;
    if isinstance(bound, TypeVarType) {
        bound = self.type_env.get(bound.name) or bound.bound;
    }
    return self.arch_of_type(bound);
}

impl MirLowering.nearest_has_var(
    arch: uni.Archetype, name: str
) -> (uni.HasVar | None) {
    for holder in self.lineage(arch) {
        for var in holder.get_has_vars() {
            if var.name is not None and var.name.value == name {
                return var;
            }
        }
    }
    return None;
}

impl MirLowering.default_thunk(
    expr: uni.Expr
) -> (tuple[uni.Archetype, str, MirType] | None) {
    holder = expr.parent;
    if isinstance(holder, uni.HasVar) and holder.name is not None {
        arch = holder.find_parent_of_type(uni.Archetype);
        if arch is None {
            return None;
        }
        member = self.object_def(arch).field(holder.name.value);
        if member is None {
            return None;
        }
        return (arch, f"__default.{holder.name.value}", member.type);
    }
    if isinstance(holder, uni.ParamVar) {
        ability = holder.find_parent_of_type(uni.Ability);
        arch = holder.find_parent_of_type(uni.Archetype);
        if ability is None or arch is None {
            return None;
        }
        return (
            arch,
            f"__default.{self.name_of(ability)}.{holder.name.value}",
            self.symbol_type(holder.name.sym, holder)
        );
    }
    return None;
}

impl MirLowering.default_value(expr: uni.Expr, to: MirType) -> MirValue {
    origin = expr.find_parent_of_type(uni.Module);
    if origin is None or origin is self.module {
        return self.coerce(self.lower_expr(expr), to, expr);
    }
    found = self.default_thunk(expr);
    if found is None {
        raise MirRefused(
            mir_refusal(
                "default",
                "imported default",
                expr,
                "A default declared in another unit is evaluated by that unit's default function."
            )
        );
    }
    (arch, label, made_type) = found;
    obj_def = self.object_def(arch);
    symbol = native_symbol_name(
        native_unit_prefix(origin.loc.mod_path), f"{obj_def.name}.{label}"
    );
    self.mir.externs[symbol] = MirExtern(symbol=symbol, ret=made_type, params=[]);
    made = self.builder().call(symbol, [], made_type);
    if made is None {
        raise MirRefused(mir_refusal("default", label, expr));
    }
    return self.coerce(made, to, expr);
}

impl MirLowering.default_thunks(arch: uni.Archetype) -> list[MirFunction] {
    made: list[MirFunction] = [];
    defaults: list[uni.Expr] = [];
    for var in arch.get_has_vars() {
        if isinstance(var.value, uni.Expr) {
            defaults.append(var.value);
        }
    }
    for method in self.arch_methods(arch) {
        if self.name_of(method) not in ("init", "__init__")
            or not isinstance(method.signature, uni.FuncSignature) {
            continue;
        }
        for pv in list(method.signature.posonly_params)
            + list(method.signature.params or []) {
            if isinstance(pv.value, uni.Expr) {
                defaults.append(pv.value);
            }
        }
    }
    prefix = native_unit_prefix(self.module.loc.mod_path);
    obj_def = self.object_def(arch);
    for expr in defaults {
        saved = self.state;
        try {
            found = self.default_thunk(expr);
            if found is None {
                continue;
            }
            (_, label, made_type) = found;
            fn = MirFunction(
                name=f"{obj_def.name}.{label}",
                symbol=native_symbol_name(prefix, f"{obj_def.name}.{label}"),
                ret=made_type
            );
            first = fn.new_block("entry");
            self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
            self.builder().ret(self.coerce(self.lower_expr(expr), made_type, expr));
            made.append(fn);
        } except MirRefused {
            self.state = saved;
            continue;
        }
        self.state = saved;
    }
    return made;
}

impl MirLowering.accessor_sig(acc: uni.Ability) -> (uni.FuncSignature | None) {
    body = acc.body;
    if isinstance(body, uni.ImplDef) and isinstance(body.spec, uni.FuncSignature) {
        return body.spec;
    }
    return acc.signature if isinstance(acc.signature, uni.FuncSignature) else None;
}

impl MirLowering.declare_accessors(arch: uni.Archetype, self_type: MirType) {
    for (slot, var, acc) in archetype_accessors(arch) {
        if acc.accessor_kind not in ("property", "setter") {
            continue;
        }
        params: list[MirType] = [];
        ret = mir_none();
        if acc.accessor_kind == "property" {
            ret = self.type_of(
                self.declared_field_type(var), MirPosition.SIGNATURE, var
            );
        } else {
            sig = self.accessor_sig(acc);
            nodes = self.param_nodes(sig, True) if sig is not None else [];
            if len(nodes) != 1 {
                raise MirRefused(
                    mir_refusal(
                        "accessor", f"{archetype_native_name(arch)}.{slot}", acc
                    )
                );
            }
            params.append(self.symbol_type(nodes[0].name.sym, nodes[0]));
        }
        key = id(acc);
        self.decls[key] = MirDecl(
            ability=acc,
            symbol=self.method_symbol(arch, slot),
            params=params,
            ret=ret,
            self_type=self_type,
            owner=arch
        );
        self.order.append(key);
    }
}

impl MirLowering.decl_label(decl: MirDecl) -> str {
    ab = decl.ability;
    if ab.accessor_kind and decl.owner is not None {
        var = ab.find_parent_of_type(uni.HasVar);
        field = var.name.value if var is not None and var.name is not None else "field";
        return accessor_slot_name(field, ab) or field;
    }
    return self.name_of(ab);
}

impl MirLowering.accessor_of(
    nd: uni.AtomTrailer, kind: str
) -> (tuple[uni.Archetype, MirDecl] | None) {
    if not nd.is_attr
        or not isinstance(nd.right, uni.Name)
        or not isinstance(nd.target, uni.Expr) {
        return None;
    }
    arch = self.arch_of_type(nd.target.type);
    if arch is None {
        return None;
    }
    var = self.nearest_has_var(arch, nd.right.value);
    if var is None or not var.accessors {
        return None;
    }
    label = f"{archetype_native_name(arch)}.{nd.right.value}";
    for acc in var.accessors {
        if acc.accessor_kind == kind {
            decl = self.decls.get(id(acc));
            if decl is None {
                raise MirRefused(
                    mir_refusal(
                        "accessor",
                        label,
                        nd,
                        "The accessor is declared on an archetype of another module, whose accessor bodies native code does not reach yet."
                    )
                );
            }
            return (arch, decl);
        }
    }
    raise MirRefused(
        mir_refusal(
            "accessor",
            f"{label} without a {'getter' if kind == 'property' else kind}",
            nd
        )
    );
}

impl MirLowering.accessor_get(nd: uni.AtomTrailer) -> (MirValue | None) {
    found = self.accessor_of(nd, "property");
    if found is None {
        return None;
    }
    (arch, decl) = found;
    receiver = self.method_receiver(decl, arch, self.lower_expr(nd.target), nd);
    return self.invoke_method(decl, arch, self.decl_label(decl), [receiver]);
}

impl MirLowering.accessor_set(target: uni.AtomTrailer, nd: uni.Assignment) -> bool {
    if nd.value is None {
        return False;
    }
    found = self.accessor_of(target, "setter");
    if found is None {
        return False;
    }
    (arch, decl) = found;
    holder = self.spill(self.lower_expr(target.target));
    value = self.lower_expr(nd.value);
    if nd.aug_op is not None {
        op = AUG_OPERATORS.get(nd.aug_op.name);
        reader = self.accessor_of(target, "property");
        if op is None or reader is None {
            raise MirRefused(mir_refusal("augmented assignment", nd.aug_op.value, nd));
        }
        (get_arch, get_decl) = reader;
        current = self.invoke_method(
            get_decl,
            get_arch,
            self.decl_label(get_decl),
            [self.method_receiver(get_decl, get_arch, holder, target)]
        );
        value = self.str_concat(current, self.coerce(value, mir_str(), nd))
            if current.type.kind == MirKind.STR and op == Tok.PLUS
            else self.arith(op, current, value, nd);
    }
    self.invoke_method(
        decl,
        arch,
        self.decl_label(decl),
        [
            self.method_receiver(decl, arch, holder, target),
            self.coerce(value, decl.params[0], nd)
        ]
    );
    return True;
}
