impl MirLowering.osp_call(name: str, args: list[MirValue]) -> MirValue {
    (params, ret) = mir_osp_signature(name);
    self.mir.externs[name] = MirExtern(symbol=name, ret=ret, params=params);
    here = os.path.realpath(self.module.loc.mod_path);
    for rel in (OSP_KERNEL_REL, OSP_GRAPH_REL, OSP_NATIVE_REL) {
        unit = os.path.realpath(kernel_unit_path(rel));
        if unit != here and unit not in self.mir.deps {
            self.mir.deps.append(unit);
        }
    }
    values = [
        self.builder().convert(arg, param)
            if arg.type.is_numeric() and param.is_numeric()
            else arg
        for (arg, param) in zip(args, params)
    ];
    result = self.builder().call_runtime(name, values, ret);
    return result if result is not None else self.builder().const_bool(False);
}

impl MirLowering.osp_hold(value: MirValue) -> MirValue {
    if not mir_holds_ref(value.type) {
        return value;
    }
    held = self.temp_slot(value.type);
    self.builder().store(held, value);
    return self.builder().load(held, value.type);
}

impl MirLowering.osp_layout(arch: (uni.Archetype | None)) -> (ArchetypeLayout | None) {
    if arch is None {
        return None;
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    layout = get_layout_registry(owner, self.prog).get_layout(archetype_native_name(arch));
    return layout if layout is not None and layout.is_osp else None;
}

impl MirLowering.osp_arch_of(nd: (uni.UniNode | None)) -> (uni.Archetype | None) {
    cursor = nd;
    while isinstance(cursor, uni.AtomUnit) {
        cursor = cursor.value;
    }
    if isinstance(cursor, uni.Expr) {
        found = self.arch_of_type(cursor.type);
        if found is not None {
            return found;
        }
    }
    sym: (uni.Symbol | None) = None;
    if isinstance(cursor, uni.Name) {
        sym = cursor.sym;
    } elif isinstance(cursor, uni.AtomTrailer) and isinstance(cursor.right, uni.Name) {
        sym = cursor.right.sym;
    }
    decl = sym.decl if sym is not None else None;
    holder = decl if isinstance(decl, uni.Archetype) else (decl.parent if decl is not None else None);
    return holder if isinstance(holder, uni.Archetype) else None;
}

impl MirLowering.osp_tag(arch: uni.Archetype) -> int {
    return stable_osp_tag(archetype_native_name(arch));
}

impl MirLowering.osp_type_tag(nd: (uni.Expr | None), site: uni.UniNode) -> int {
    if nd is None {
        return UNTYPED_OSP_TAG;
    }
    cursor: uni.UniNode = nd;
    while isinstance(cursor, uni.AtomUnit) {
        cursor = cursor.value;
    }
    name = cursor.value if isinstance(cursor, uni.Name) else "";
    arch = self.osp_arch_of(cursor);
    stub = arch is not None
        and os.path.basename(arch.loc.mod_path) in ("builtins.jac", "builtins.pyi", "jac_builtins.pyi");
    if arch is not None and not stub and self.osp_layout(arch) is not None {
        return self.osp_tag(arch);
    }
    if name in OSP_ANY_TAGS {
        return OSP_ANY_TAGS[name];
    }
    raise MirRefused(
        mir_refusal(
            "graph type",
            name or type(cursor).__name__,
            site,
            "Native graph filters name a node or edge archetype."
        )
    );
}

impl MirLowering.osp_handle(value: MirValue, site: uni.UniNode) -> MirValue {
    if value.type.kind == MirKind.INT {
        return value;
    }
    if value.type.kind == MirKind.ANY {
        return self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [value]);
    }
    if value.type.kind == MirKind.OBJ {
        return self.address_of(value);
    }
    raise MirRefused(mir_refusal("graph operand", value.type.render(), site));
}

impl MirLowering.osp_handles(value: MirValue, site: uni.UniNode) -> MirValue {
    if value.type.kind == MirKind.LIST {
        elem = value.type.payload();
        if elem.kind == MirKind.INT {
            return value;
        }
        if elem.kind == MirKind.OBJ {
            return self.builder().ref_cast(value, mir_list(mir_int()), False);
        }
        raise MirRefused(mir_refusal("graph operand", value.type.render(), site));
    }
    return self.osp_one(self.osp_handle(value, site));
}

impl MirLowering.osp_one(handle: MirValue) -> MirValue {
    b = self.builder();
    made = self.new_list(mir_int(), 1);
    self.runtime("__jac_rt_list_push", [made, handle, b.const_int(KIND_INT, mir_int())]);
    return made;
}

impl MirLowering.osp_typed(handles: MirValue, site: uni.Expr) -> MirValue {
    b = self.builder();
    target = self.expr_type(site);
    if target.kind != MirKind.LIST {
        raise MirRefused(mir_refusal("expression", f"graph result as {target.render()}", site));
    }
    if target is handles.type {
        return handles;
    }
    if target.payload().kind != MirKind.OBJ {
        raise MirRefused(mir_refusal("expression", f"graph result as {target.render()}", site));
    }
    copied = self.runtime("__jac_rt_list_copy", [handles, b.const_int(KIND_REF, mir_int())]);
    if copied is None {
        raise MirRefused(mir_refusal("expression", "graph result", site));
    }
    return b.ref_cast(copied, target, True);
}

impl MirLowering.osp_header_fields(made: MirObjectDef, layout: ArchetypeLayout) {
    if not layout.is_osp {
        return;
    }
    made.osp_kind = layout.arch_type;
    if layout.reports_slot is not None {
        made.fields.append(
            MirObjectField(name="reports", type=mir_list(mir_any()), index=layout.reports_slot)
        );
    }
}

impl MirLowering.osp_header(this: MirValue, obj_def: MirObjectDef) {
    if obj_def.tag_slot < 0 {
        return;
    }
    b = self.builder();
    tag_place = self.emit_value(
        MirOp.FIELD_ADDR, mir_c_ptr(mir_int()), [this], int_value=obj_def.tag_slot
    );
    b.store(tag_place, b.const_int(stable_osp_tag(obj_def.name), mir_int()));
    reports = obj_def.field("reports");
    if reports is None {
        return;
    }
    self.emit_value(
        MirOp.MEM_STORE,
        mir_none(),
        [b.binary("add", self.address_of(this), b.const_int(reports.index * 8, mir_int())), b.const_int(0, mir_int())]
    );
    b.store(
        self.emit_value(MirOp.FIELD_ADDR, mir_c_ptr(reports.type), [this], int_value=reports.index),
        self.new_list(mir_any(), 0)
    );
}

impl MirLowering.osp_drop(obj_def: MirObjectDef, raw: MirValue) {
    if obj_def.osp_kind not in ("node", "edge") {
        return;
    }
    self.osp_call(
        "__jac_osp_reclaimed",
        [self.address_of(raw), self.builder().const_bool(obj_def.osp_kind == "edge")]
    );
}

impl MirLowering.osp_bases(arch: uni.Archetype) -> list[uni.Archetype] {
    found: list[uni.Archetype] = [];
    for base in list(arch.base_classes or []) {
        held = self.osp_arch_of(base);
        if held is not None and self.osp_layout(held) is not None {
            found.append(held);
        }
    }
    return found;
}

impl MirLowering.osp_model_of -> OspModel {
    if self.osp_model is not None {
        return self.osp_model;
    }
    archs: list[uni.Archetype] = [];
    seen: set[int] = set();
    pending: list[uni.Archetype] = [
        arch for arch in self.module_archetypes() if self.osp_layout(arch) is not None
    ];
    while pending {
        arch = pending.pop();
        if id(arch) in seen {
            continue;
        }
        seen.add(id(arch));
        archs.append(arch);
        self.archetypes[archetype_native_name(arch)] = arch;
        pending.extend(self.osp_bases(arch));
        for member in list(ModuleFacts.unwrap_body(arch) or []) {
            if isinstance(member, uni.Ability) and isinstance(member.signature, uni.EventSignature) {
                for head in OspAnalysis.trigger_heads(member.signature.arch_tag_info) {
                    trigger = self.osp_arch_of(head);
                    if trigger is not None and self.osp_layout(trigger) is not None {
                        pending.append(trigger);
                    }
                }
            }
        }
    }
    self.osp_model = OspAnalysis.compute(self.module, archs, None, True);
    return self.osp_model;
}

impl MirLowering.declare_osp_abilities(arch: uni.Archetype) {
    layout = self.osp_layout(arch);
    if layout is None {
        return;
    }
    self_type = self.object_type(arch);
    for member in list(ModuleFacts.unwrap_body(arch) or []) {
        if not isinstance(member, uni.Ability) or not isinstance(member.signature, uni.EventSignature) {
            continue;
        }
        key = id(member);
        self.decl_syms[id(self.ability_sym(member))] = key;
        self.decls[key] = MirDecl(
            ability=member,
            symbol=self.method_symbol(arch, self.name_of(member)),
            params=[mir_any()],
            ret=mir_none(),
            self_type=self_type,
            owner=arch,
            event="here" if layout.arch_type == "walker" else "visitor"
        );
        self.order.append(key);
    }
}

impl MirLowering.lower_ability(decl: MirDecl) -> (MirFunction | None) {
    ab = decl.ability;
    fn = MirFunction(name=self.name_of(ab), symbol=decl.symbol, ret=mir_none());
    first = fn.new_block("entry");
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        body = ab.body;
        if isinstance(body, uni.ImplDef) {
            body = body.body;
        }
        if not isinstance(body, (list, tuple)) {
            raise MirRefused(mir_refusal("ability", "expression body", ab));
        }
        self_type = decl.self_type;
        if self_type is None {
            raise MirRefused(mir_refusal("ability", "without an archetype", ab));
        }
        receiver = fn.new_value(self_type, "self");
        place = fn.new_value(mir_any(), decl.event);
        fn.params.append(MirParam(name="self", value=receiver));
        fn.params.append(MirParam(name=decl.event, value=place));
        self.st().self_value = receiver;
        self.st().specials[decl.event] = place;
        self.prepare_cells(ab, list(body));
        self.lower_body(body);
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
        self.refusals.setdefault(fn.name, []).append(refusal_of(err));
        self.state = None;
        return None;
    }
    self.state = None;
    return fn;
}

impl MirLowering.osp_thunk(owner: uni.Archetype, ability: str) -> str {
    target = self.method_symbol(owner, ability);
    found = self.osp_thunks.get(target);
    if found is not None {
        return found;
    }
    self_type = self.object_type(owner);
    home = owner.find_parent_of_type(uni.Module) or self.module;
    if home is not self.module {
        self.mir.externs[target] = MirExtern(
            symbol=target, ret=mir_none(), params=[self_type, mir_any()]
        );
        unit = os.path.realpath(home.loc.mod_path);
        if unit not in self.mir.deps {
            self.mir.deps.append(unit);
        }
    }
    i8p = mir_c_ptr(mir_int(8, False));
    symbol = f"{target}.__ospthunk";
    fn = MirFunction(
        name=f"{ability}.__ospthunk", symbol=symbol, ret=mir_any(), linkage="internal"
    );
    first = fn.new_block("entry");
    env = fn.new_value(i8p, "env");
    walker_or_node = fn.new_value(mir_any(), "a");
    location = fn.new_value(mir_any(), "b");
    fn.params.append(MirParam(name="env", value=env));
    fn.params.append(MirParam(name="a", value=walker_or_node));
    fn.params.append(MirParam(name="b", value=location));
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        b = self.builder();
        b.call(target, [b.ref_cast(walker_or_node, self_type, False), location], mir_none());
        b.ret(self.any_none());
    } finally {
        self.state = saved;
    }
    self.mir.functions.append(fn);
    self.osp_thunks[target] = symbol;
    return symbol;
}

impl MirLowering.lower_osp_module {
    local: list[uni.Archetype] = [
        arch
        for arch in self.module_archetypes()
        if self.osp_layout(arch) is not None and archetype_native_name(arch) in self.mir.objects
    ];
    if not local {
        return;
    }
    model = self.osp_model_of();
    i8p = mir_c_ptr(mir_int(8, False));
    slot_fn = mir_fn([mir_any(), mir_any()], mir_any());
    code_fn = mir_c_fn([i8p, mir_any(), mir_any()], mir_any());
    fn = MirFunction(
        name="__osp_setup",
        symbol=native_symbol_name(self.mir.prefix, "__osp_setup"),
        ret=mir_none(),
        linkage="internal"
    );
    first = fn.new_block("entry");
    self.osp_setup = fn.symbol;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        b = self.builder();
        for arch in local {
            name = archetype_native_name(arch);
            for (clash, other) in model.collisions {
                if clash == name {
                    raise MirRefused(
                        mir_refusal(
                            "archetype", f"{name} (OSP type-tag hash collides with '{other}')", arch
                        )
                    );
                }
            }
            tag = model.tags[name];
            kind = model.arch_kind.get(name, "");
            bases = self.new_list(mir_int(), 0);
            ancestors = [model.tags[a] for a in model.isa.get(name, []) if a != name and a in model.tags];
            generic = OSP_ANY_TAGS.get(kind.capitalize(), 0);
            if generic != 0 {
                ancestors.append(generic);
            }
            for ancestor in ancestors {
                self.runtime(
                    "__jac_rt_list_push",
                    [bases, b.const_int(ancestor, mir_int()), b.const_int(KIND_INT, mir_int())]
                );
            }
            self.osp_call(
                "__jac_osp_register",
                [b.const_int(tag, mir_int()), bases, b.const_bool(kind == "walker")]
            );
            layout = self.osp_layout(arch);
            lineage = list(layout.mro) if layout is not None else [name];
            for is_entry in (True, False) {
                merged: dict[str, OspSlot] = {};
                for owner in reversed(lineage) {
                    for slot in (model.entry_slots(owner) if is_entry else model.exit_slots(owner)) {
                        merged[slot.ability] = slot;
                    }
                }
                for slot in merged.values() {
                    if not slot.has_body {
                        continue;
                    }
                    holder = self.archetypes.get(slot.owner);
                    if holder is None {
                        raise MirRefused(
                            mir_refusal(
                                "ability",
                                f"{slot.owner}.{slot.ability}",
                                arch,
                                "The archetype that declares this ability is not visible to this native compile."
                            )
                        );
                    }
                    closure = self.osp_closure(self.osp_thunk(holder, slot.ability), code_fn, [], slot_fn);
                    for trigger in model.trigger_tags(slot) {
                        self.osp_call(
                            "__jac_osp_slot",
                            [
                                b.const_int(tag, mir_int()),
                                b.const_bool(is_entry),
                                b.const_int(trigger, mir_int()),
                                closure
                            ]
                        );
                    }
                }
            }
        }
        b.ret(None);
    } except MirRefused as err {
        self.refusals.setdefault(fn.symbol, []).append(refusal_of(err));
        self.state = None;
        return;
    }
    self.state = None;
    self.mir.functions.append(fn);
}

impl MirLowering.osp_special(nd: uni.SpecialVarRef) -> MirValue {
    if nd.value == "root" {
        raise MirRefused(mir_refusal("expression", "root", nd, OSP_ROOT_HELP));
    }
    found = self.st().specials.get(nd.value);
    if found is None {
        raise MirRefused(
            mir_refusal(
                "expression",
                nd.value,
                nd,
                f"`{nd.value}` is bound only inside an event ability of a walker, node or edge."
            )
        );
    }
    arch = self.arch_of_type(nd.type);
    if arch is not None and self.osp_layout(arch) is not None {
        return self.any_unbox(found, self.object_type(arch), nd);
    }
    return found;
}

impl MirLowering.osp_leave {
    if self.st().fn.ret.kind == MirKind.NONE {
        self.builder().ret(None);
    }
}

impl MirLowering.lower_osp_stmt(nd: uni.UniNode) {
    b = self.builder();
    if isinstance(nd, uni.ReportStmt) {
        self.osp_call("__jac_osp_report", [self.any_box(self.lower_expr(nd.expr), nd)]);
        return;
    }
    if isinstance(nd, uni.DisengageStmt) {
        self.osp_call("__jac_osp_disengage", []);
        self.osp_leave();
        return;
    }
    if isinstance(nd, uni.CtrlStmt) {
        if self.st().fn.ret.kind != MirKind.NONE {
            raise MirRefused(mir_refusal("statement", "SkipStmt", nd, OSP_SKIP_HELP));
        }
        self.osp_call("__jac_osp_skip", []);
        b.ret(None);
        return;
    }
    if not isinstance(nd, uni.VisitStmt) {
        raise MirRefused(mir_refusal("statement", type(nd).__name__, nd));
    }
    targets = self.lower_edge_handles(nd.target)
        if isinstance(nd.target, uni.EdgeRefTrailer)
        else self.osp_handles(self.lower_expr(nd.target), nd);
    insert = self.coerce(self.lower_expr(nd.insert_loc), mir_int(), nd.insert_loc)
        if nd.insert_loc is not None
        else b.const_int(-1, mir_int());
    did = self.osp_call("__jac_osp_visit", [targets, insert]);
    if nd.else_body is None {
        return;
    }
    fn = self.st().fn;
    otherwise = fn.new_block("visit.else");
    done = fn.new_block("visit.end");
    b.cond_branch(did, done, otherwise);
    b.position(otherwise);
    self.lower_else(nd.else_body, done);
    b.position(done);
}

impl MirLowering.lower_osp_binary(nd: uni.BinaryExpr) -> MirValue {
    if isinstance(nd.op, uni.ConnectOp) {
        return self.lower_connect(nd, nd.op);
    }
    if isinstance(nd.op, uni.DisconnectOp) {
        return self.lower_disconnect(nd, nd.op);
    }
    return self.lower_spawn(nd);
}

impl MirLowering.lower_spawn(nd: uni.BinaryExpr) -> MirValue {
    left_arch = self.osp_arch_of(nd.left);
    right_arch = self.osp_arch_of(nd.right);
    left_layout = self.osp_layout(left_arch);
    right_layout = self.osp_layout(right_arch);
    walker_nd: uni.Expr = nd.left;
    place_nd: uni.Expr = nd.right;
    walker_arch = left_arch;
    if left_layout is not None and left_layout.arch_type == "walker" {
        walker_nd = nd.left;
        place_nd = nd.right;
    } elif right_layout is not None and right_layout.arch_type == "walker" {
        walker_nd = nd.right;
        place_nd = nd.left;
        walker_arch = right_arch;
    } else {
        raise MirRefused(
            mir_refusal(
                "binary operator",
                "KW_SPAWN",
                nd,
                "A native spawn needs one operand statically typed as a walker archetype."
            )
        );
    }
    if walker_arch is None {
        raise MirRefused(mir_refusal("binary operator", "KW_SPAWN", nd));
    }
    if isinstance(place_nd, uni.SpecialVarRef) and place_nd.value == "root" {
        raise MirRefused(mir_refusal("expression", "root", place_nd, OSP_ROOT_HELP));
    }
    b = self.builder();
    walker = self.osp_hold(self.lower_expr(walker_nd));
    location = self.osp_hold(self.lower_expr(place_nd));
    walker_def = self.object_def(walker_arch);
    tag_place = self.emit_value(
        MirOp.FIELD_ADDR, mir_c_ptr(mir_int()), [walker], int_value=walker_def.tag_slot
    );
    reports = self.osp_hold(
        self.osp_call(
            "__jac_osp_spawn",
            [self.any_box(walker, nd), b.load(tag_place, mir_int()), self.osp_handle(location, place_nd)]
        )
    );
    fn = self.st().fn;
    keep = fn.new_block("spawn.reports");
    done = fn.new_block("spawn.done");
    b.cond_branch(self.opt_present(reports), keep, done);
    b.position(keep);
    b.store(self.field_place(walker, walker_arch, "reports", nd), self.opt_get(reports));
    b.branch(done);
    b.position(done);
    return walker;
}

impl MirLowering.osp_root_anchor(nd: uni.BinaryExpr, co: uni.ConnectOp) -> MirValue {
    root_left = isinstance(nd.left, uni.SpecialVarRef) and nd.left.value == "root";
    root_right = isinstance(nd.right, uni.SpecialVarRef) and nd.right.value == "root";
    looks_back = any(
        int(ref.edge_dir.value) != OSP_DIR_OUT for ref in self.module.get_all_sub_nodes(uni.EdgeOpRef)
    );
    direction = int(co.edge_dir.value);
    away = (root_left and direction == OSP_DIR_OUT) or (root_right and direction == OSP_DIR_IN);
    if (root_left and root_right)
        or co.capture_edges
        or co.conn_type is not None
        or looks_back
        or not away {
        raise MirRefused(mir_refusal("connect operand", "root", nd, OSP_ROOT_CONNECT_HELP));
    }
    return self.lower_expr(nd.right if root_left else nd.left);
}

impl MirLowering.osp_assign_values(
    co: uni.ConnectOp, edge: (uni.Archetype | None), site: uni.UniNode
) -> dict[str, MirValue] {
    values: dict[str, MirValue] = {};
    assign = co.conn_assign;
    if assign is None {
        return values;
    }
    help = "a connect's attribute assignments need an edge type whose fields are known at compile time.";
    if edge is None {
        raise MirRefused(mir_refusal("edge attribute", "<field>", assign, help));
    }
    obj_def = self.object_def(edge);
    accepted = {param[0] for param in self.constructor_params(edge)};
    for kw in assign.assigns {
        key = kw.key.sym_name if kw.key is not None else "";
        if not key or (obj_def.field(key) is None and key not in accepted) {
            raise MirRefused(mir_refusal("edge attribute", key or "<field>", kw, help));
        }
        values[key] = self.osp_hold(self.lower_expr(kw.value));
    }
    return values;
}

impl MirLowering.osp_edge_object(
    co: uni.ConnectOp,
    edge: (uni.Archetype | None),
    values: dict[str, MirValue],
    site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if edge is None {
        return b.ref_cast(self.osp_call("__jac_osp_generic_edge", []), mir_ref(), True);
    }
    obj_def = self.object_def(edge);
    args: list[MirValue] = [];
    taken: set[str] = set();
    params = self.constructor_params(edge);
    for (pname, ptype, fallback) in params {
        if pname in values {
            args.append(self.coerce(values[pname], ptype, site));
            taken.add(pname);
        } elif fallback is not None {
            args.append(self.coerce(self.lower_expr(fallback), ptype, fallback));
        } else {
            raise MirRefused(
                mir_refusal(
                    "edge attribute",
                    f"{obj_def.name} missing {pname}",
                    co,
                    "edge type cannot be constructed without arguments"
                )
            );
        }
    }
    owner = edge.find_parent_of_type(uni.Module) or self.module;
    symbol = native_symbol_name(native_unit_prefix(owner.loc.mod_path), f"{obj_def.name}.__ctor");
    if not obj_def.local {
        self.mir.externs[symbol] = MirExtern(
            symbol=symbol, ret=mir_obj(obj_def.name), params=[param[1] for param in params]
        );
        unit = os.path.realpath(owner.loc.mod_path);
        if unit not in self.mir.deps {
            self.mir.deps.append(unit);
        }
    }
    made = b.call(symbol, args, mir_obj(obj_def.name));
    if made is None {
        raise MirRefused(mir_refusal("edge type", obj_def.name, site));
    }
    for (field, value) in values.items() {
        if field in taken {
            continue;
        }
        place = self.field_place(made, edge, field, site);
        b.store(place, self.coerce(value, self.place_elem(place), site));
    }
    return made;
}

impl MirLowering.lower_connect(nd: uni.BinaryExpr, co: uni.ConnectOp) -> MirValue {
    if (isinstance(nd.left, uni.SpecialVarRef) and nd.left.value == "root")
        or (isinstance(nd.right, uni.SpecialVarRef) and nd.right.value == "root") {
        return self.osp_root_anchor(nd, co);
    }
    edge: (uni.Archetype | None) = None;
    if co.conn_type is not None {
        edge = self.osp_arch_of(co.conn_type);
        layout = self.osp_layout(edge);
        if layout is None or layout.arch_type != "edge" {
            raise MirRefused(
                mir_refusal(
                    "edge type",
                    "an edge value",
                    co.conn_type,
                    "A native connect names its edge archetype; edge types held in variables are not lowered natively."
                )
            );
        }
    }
    b = self.builder();
    left = self.lower_expr(nd.left);
    right = self.lower_expr(nd.right);
    left_many = left.type.kind == MirKind.LIST;
    right_many = right.type.kind == MirKind.LIST;
    if (left_many and right_many) or ((left_many or right_many) and co.capture_edges) {
        raise MirRefused(mir_refusal("connect operand", "list", nd, OSP_FANOUT_HELP));
    }
    direction = int(co.edge_dir.value);
    undirected = b.const_bool(direction == OSP_DIR_ANY);
    tag = b.const_int(self.osp_tag(edge) if edge is not None else UNTYPED_OSP_TAG, mir_int());
    if not left_many and not right_many {
        values = self.osp_assign_values(co, edge, nd);
        made = self.osp_edge_object(co, edge, values, nd);
        (src, tgt) = (right, left) if direction == OSP_DIR_IN else (left, right);
        self.osp_call(
            "__jac_osp_connect",
            [self.osp_handle(src, nd), self.osp_handle(tgt, nd), self.osp_handle(made, nd), undirected, tag]
        );
        if not co.capture_edges {
            return tgt;
        }
        result_type = self.expr_type(nd);
        if result_type.kind != MirKind.LIST {
            raise MirRefused(mir_refusal("connect", f"edges as {result_type.render()}", nd));
        }
        collected = self.new_list(result_type.payload(), 1);
        self.runtime(
            "__jac_rt_list_push",
            [
                collected,
                self.to_bits(made, result_type.payload(), nd),
                b.const_int(self.elem_kind(result_type.payload(), nd), mir_int())
            ]
        );
        return collected;
    }
    many = self.osp_hold(right if right_many else left);
    one = self.osp_hold(left if right_many else right);
    values = self.osp_assign_values(co, edge, nd);
    fn = self.st().fn;
    index = self.temp_slot(mir_int());
    b.store(index, b.const_int(0, mir_int()));
    head = fn.new_block("connect.head");
    body = fn.new_block("connect.body");
    done = fn.new_block("connect.done");
    b.branch(head);
    b.position(head);
    at = b.load(index, mir_int());
    b.cond_branch(b.compare("lt", at, self.container_len(many)), body, done);
    b.position(body);
    each = self.list_read(many, at);
    made = self.osp_edge_object(co, edge, values, nd);
    (src, tgt) = (one, each) if right_many else (each, one);
    if direction == OSP_DIR_IN {
        (src, tgt) = (tgt, src);
    }
    self.osp_call(
        "__jac_osp_connect",
        [self.osp_handle(src, nd), self.osp_handle(tgt, nd), self.osp_handle(made, nd), undirected, tag]
    );
    b.store(index, b.binary("add", at, b.const_int(1, mir_int())));
    b.branch(head);
    b.position(done);
    if direction == OSP_DIR_IN {
        return one if right_many else many;
    }
    return many if right_many else one;
}

impl MirLowering.osp_list_operand(nd: uni.Expr) -> bool {
    if isinstance(nd, uni.EdgeRefTrailer) {
        return True;
    }
    t = nd.type;
    return isinstance(t, ClassType)
        and t.shared.class_name in ("list", "tuple", "set", "frozenset");
}

impl MirLowering.lower_disconnect(nd: uni.BinaryExpr, dop: uni.DisconnectOp) -> MirValue {
    spec = dop.edge_spec;
    condition = spec.filter_cond;
    edge: (uni.Archetype | None) = None;
    if condition is not None and condition.f_type is not None {
        edge = self.osp_arch_of(condition.f_type);
        layout = self.osp_layout(edge);
        if layout is None or layout.arch_type != "edge" {
            raise MirRefused(mir_refusal("edge type", "an edge value", condition.f_type));
        }
    }
    compares = [
        item for item in list(condition.compares if condition is not None else []) if isinstance(item, uni.CompareExpr)
    ];
    many = self.osp_list_operand(nd.left) or self.osp_list_operand(nd.right);
    if compares and many {
        raise MirRefused(mir_refusal("binary operator", "DisconnectOp", nd, OSP_DISCONNECT_LIST_HELP));
    }
    if compares and edge is None {
        raise MirRefused(mir_refusal("binary operator", "DisconnectOp", nd, OSP_PREDICATE_HELP));
    }
    b = self.builder();
    tag = b.const_int(self.osp_tag(edge) if edge is not None else UNTYPED_OSP_TAG, mir_int());
    direction = b.const_int(int(spec.edge_dir.value), mir_int());
    left = self.lower_expr(nd.left);
    right = self.lower_expr(nd.right);
    if compares and edge is not None {
        return self.osp_call(
            "__jac_osp_disconnect_pred",
            [self.osp_handle(left, nd), self.osp_handle(right, nd), direction, tag, self.osp_field_pred(edge, compares, nd)]
        );
    }
    if many {
        return self.osp_call(
            "__jac_osp_disconnect_many",
            [self.osp_handles(left, nd), self.osp_handles(right, nd), direction, tag]
        );
    }
    return self.osp_call(
        "__jac_osp_disconnect",
        [self.osp_handle(left, nd), self.osp_handle(right, nd), direction, tag]
    );
}

impl MirLowering.lower_edge_handles(nd: uni.EdgeRefTrailer) -> MirValue {
    b = self.builder();
    chain = list(nd.chain);
    if not chain {
        raise MirRefused(mir_refusal("expression", "EdgeRefTrailer", nd));
    }
    index = 0;
    origin: MirValue;
    if isinstance(chain[0], uni.EdgeOpRef) {
        here = self.st().specials.get("here");
        if here is None {
            raise MirRefused(
                mir_refusal(
                    "expression",
                    "EdgeRefTrailer",
                    nd,
                    "An edge reference with no origin reads `here`, which is bound only in a walker's event ability."
                )
            );
        }
        origin = here;
    } else {
        origin = self.lower_expr(chain[0]);
        index = 1;
    }
    if index >= len(chain) or not isinstance(chain[index], uni.EdgeOpRef) {
        raise MirRefused(mir_refusal("expression", "EdgeRefTrailer", nd));
    }
    current: (MirValue | None) = None;
    while index < len(chain) {
        step = chain[index];
        if not isinstance(step, uni.EdgeOpRef) {
            break;
        }
        index += 1;
        step_filter: (uni.FilterCompr | None) = None;
        step_only: (uni.Expr | None) = None;
        if index < len(chain) {
            following = chain[index];
            if isinstance(following, uni.FilterCompr) and following.f_type is not None {
                step_filter = following;
                index += 1;
            } elif isinstance(following, uni.Expr)
                and not isinstance(following, (uni.EdgeOpRef, uni.FilterCompr)) {
                step_only = following;
                index += 1;
            }
        }
        last = index >= len(chain) or not isinstance(chain[index], uni.EdgeOpRef);
        condition = step.filter_cond;
        edge: (uni.Archetype | None) = None;
        if condition is not None and condition.f_type is not None {
            edge = self.osp_arch_of(condition.f_type);
            layout = self.osp_layout(edge);
            if layout is None or layout.arch_type != "edge" {
                raise MirRefused(mir_refusal("edge type", "an edge value", condition.f_type));
            }
        }
        compares = list(condition.compares if condition is not None else []);
        if compares and edge is None {
            raise MirRefused(mir_refusal("expression", "EdgeRefTrailer", nd, OSP_PREDICATE_HELP));
        }
        direction = b.const_int(int(step.edge_dir.value), mir_int());
        tag = b.const_int(self.osp_tag(edge) if edge is not None else UNTYPED_OSP_TAG, mir_int());
        edges_only = b.const_bool(nd.edges_only and last);
        origins = current
            if current is not None
            else (self.osp_handles(origin, nd) if compares or step_only is not None or origin.type.kind == MirKind.LIST else None);
        result: MirValue;
        if compares and edge is not None and origins is not None {
            result = self.osp_call(
                "__jac_osp_refs_pred",
                [origins, direction, tag, edges_only, self.osp_field_pred(edge, compares, nd)]
            );
        } elif origins is None {
            result = self.osp_call(
                "__jac_osp_refs", [self.osp_handle(origin, nd), direction, tag, edges_only]
            );
        } else {
            result = self.osp_call("__jac_osp_refs_many", [origins, direction, tag, edges_only]);
        }
        if step_filter is not None {
            result = self.osp_call(
                "__jac_osp_filter",
                [result, self.osp_type_pred(self.osp_type_tag(step_filter.f_type, nd))]
            );
            if step_filter.compares {
                held = self.osp_filter_arch(step_filter, None);
                if held is None {
                    raise MirRefused(mir_refusal("expression", "FilterCompr", nd, OSP_FILTER_HELP));
                }
                result = self.osp_call(
                    "__jac_osp_filter", [result, self.osp_field_pred(held, step_filter.compares, nd)]
                );
            }
        }
        if step_only is not None and origins is not None {
            wanted = self.osp_handles(self.lower_expr(step_only), step_only);
            result = self.osp_call(
                "__jac_osp_keep_toward",
                [result, origins if nd.edges_only and last else wanted, direction, edges_only, wanted]
            );
        }
        current = result;
    }
    if current is None or index != len(chain) {
        raise MirRefused(mir_refusal("expression", "EdgeRefTrailer", nd));
    }
    return current;
}

impl MirLowering.osp_filter_arch(
    f: uni.FilterCompr, holder: (uni.Expr | None)
) -> (uni.Archetype | None) {
    if f.f_type is not None {
        return self.osp_arch_of(f.f_type);
    }
    t = holder.type if holder is not None else None;
    if isinstance(t, ClassType) and t.private and t.private.type_args {
        return self.arch_of_type(t.private.type_args[0]);
    }
    return None;
}

impl MirLowering.lower_osp_filter(nd: uni.AtomTrailer) -> MirValue {
    f = nd.right;
    if not isinstance(f, uni.FilterCompr) or not isinstance(nd.target, uni.Expr) {
        raise MirRefused(mir_refusal("expression", "FilterCompr", nd));
    }
    arch = self.osp_filter_arch(f, nd.target);
    if arch is None and f.compares {
        raise MirRefused(mir_refusal("expression", "FilterCompr", nd, OSP_FILTER_HELP));
    }
    result = self.osp_handles(self.lower_expr(nd.target), nd);
    if f.f_type is not None {
        result = self.osp_call(
            "__jac_osp_filter", [result, self.osp_type_pred(self.osp_type_tag(f.f_type, nd))]
        );
    }
    if f.compares and arch is not None {
        result = self.osp_call("__jac_osp_filter", [result, self.osp_field_pred(arch, f.compares, nd)]);
    }
    return self.osp_typed(result, nd);
}

impl MirLowering.osp_predicate(label: str) -> tuple[MirFunction, MirFnState] {
    outer = self.st();
    i8p = mir_c_ptr(mir_int(8, False));
    fn = MirFunction(
        name=label, symbol=f"{outer.fn.symbol}.{label}", ret=mir_bool(), linkage="internal"
    );
    first = fn.new_block("entry");
    env = fn.new_value(i8p, "env");
    handle = fn.new_value(mir_int(), "h");
    fn.params.append(MirParam(name="env", value=env));
    fn.params.append(MirParam(name="h", value=handle));
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    self.st().env = self.builder().ref_cast(env, mir_ref(), False);
    return (fn, outer);
}

impl MirLowering.osp_closure(
    symbol: str, code: MirType, captures: list[tuple[MirValue, MirType]], to: MirType
) -> MirValue {
    b = self.builder();
    address = self.emit_value(
        MirOp.PTR_INT, mir_int(), [self.emit_value(MirOp.FN_ADDR, code, [], callee=symbol)]
    );
    made = self.runtime("__jac_rt_closure_new", [address, b.const_int(len(captures), mir_int())]);
    if made is None {
        raise MirRefused(mir_refusal("closure", symbol));
    }
    for (index, (value, value_type)) in enumerate(captures) {
        cell = self.runtime(
            "__jac_rt_cell_new", [b.const_int(self.elem_kind(value_type, self.module), mir_int())]
        );
        if cell is None {
            raise MirRefused(mir_refusal("closure", symbol));
        }
        self.cell_write(cell, value, value_type, self.module);
        self.runtime("__jac_rt_closure_set", [made, b.const_int(index, mir_int()), cell]);
    }
    return b.ref_cast(made, to, True);
}

impl MirLowering.osp_type_pred(tag: int) -> MirValue {
    i8p = mir_c_ptr(mir_int(8, False));
    self.osp_preds += 1;
    (fn, outer) = self.osp_predicate(f"osp_type{self.osp_preds}");
    try {
        b = self.builder();
        handle = fn.params[1].value;
        held = self.emit_value(
            MirOp.MEM_LOAD, mir_int(), [b.binary("add", handle, b.const_int(OSP_TAG_OFFSET, mir_int()))]
        );
        b.ret(self.osp_call("__jac_osp_is_a", [held, b.const_int(tag, mir_int())]));
    } finally {
        self.state = outer;
    }
    self.nested.append(fn);
    return self.osp_closure(
        fn.symbol, mir_c_fn([i8p, mir_int()], mir_bool()), [], mir_fn([mir_int()], mir_bool())
    );
}

impl MirLowering.osp_field_pred(
    arch: uni.Archetype, compares: Sequence[uni.Expr], site: uni.UniNode
) -> MirValue {
    i8p = mir_c_ptr(mir_int(8, False));
    obj_def = self.object_def(arch);
    checks: list[uni.CompareExpr] = [];
    captures: list[tuple[MirValue, MirType]] = [];
    for cmp in compares {
        field = cmp.left.value
            if isinstance(cmp, uni.CompareExpr) and isinstance(cmp.left, uni.Name)
            else "<expr>";
        if not isinstance(cmp, uni.CompareExpr)
            or len(cmp.ops) != 1
            or len(cmp.rights) != 1
            or obj_def.field(field) is None {
            raise MirRefused(
                mir_refusal(
                    "expression",
                    "FilterCompr",
                    cmp,
                    f"filter predicate on '{field}' does not resolve to a simple `field <op> value` compare over archetype '{obj_def.name}'"
                )
            );
        }
        checks.append(cmp);
        value = self.spill(self.lower_expr(cmp.rights[0]));
        captures.append((value, value.type));
    }
    self.osp_preds += 1;
    (fn, outer) = self.osp_predicate(f"osp_pred{self.osp_preds}");
    try {
        b = self.builder();
        this = b.ref_cast(fn.params[1].value, self.object_type(arch), False);
        env = self.st().env;
        if env is None {
            raise MirRefused(mir_refusal("closure", fn.symbol, site));
        }
        cells = self.address_of(env);
        verdict = b.const_bool(True);
        for (index, cmp) in enumerate(checks) {
            if not isinstance(cmp.left, uni.Name) {
                raise MirRefused(mir_refusal("expression", "FilterCompr", cmp));
            }
            place = self.field_place(this, arch, cmp.left.value, cmp);
            current = self.spill(b.load(place, self.place_elem(place)));
            cell = b.ref_cast(
                self.emit_value(
                    MirOp.MEM_LOAD,
                    mir_int(),
                    [b.binary("add", cells, b.const_int(CLOSURE_CELLS_OFFSET + index * 8, mir_int()))]
                ),
                mir_ref(),
                False
            );
            wanted = self.spill(self.cell_read(cell, captures[index][1]));
            verdict = b.binary(
                "and", verdict, self.compare_values(cmp.ops[0].name, current, wanted, cmp)
            );
        }
        b.ret(verdict);
    } finally {
        self.state = outer;
    }
    self.nested.append(fn);
    return self.osp_closure(
        fn.symbol, mir_c_fn([i8p, mir_int()], mir_bool()), captures, mir_fn([mir_int()], mir_bool())
    );
}

impl MirLowering.osp_delete(target: uni.Expr) -> bool {
    if isinstance(target, uni.AtomTrailer) {
        return False;
    }
    t = target.type;
    if isinstance(t, ClassType) and t.shared.class_name == "list" {
        args = t.private.type_args if t.private else [];
        elem = self.arch_of_type(args[0]) if args else None;
        layout = self.osp_layout(elem);
        if layout is None or layout.arch_type not in ("node", "edge") {
            return False;
        }
        self.osp_call("__jac_osp_destroy_all", [self.osp_handles(self.lower_expr(target), target)]);
        return True;
    }
    layout = self.osp_layout(self.arch_of_type(t));
    if layout is None or layout.arch_type not in ("node", "edge") {
        return False;
    }
    self.osp_call("__jac_osp_destroy", [self.osp_handle(self.lower_expr(target), target)]);
    return True;
}

impl MirLowering.lower_jid(nd: uni.FuncCall) -> MirValue {
    args = self.call_args(nd);
    arch = self.osp_arch_of(args[0]) if len(args) == 1 else None;
    layout = self.osp_layout(arch);
    if layout is None
        or layout.arch_type not in ("node", "edge")
        or isinstance(args[0].type, UnionType) {
        raise MirRefused(mir_refusal("builtin call", "jid", nd, OSP_JID_HELP));
    }
    return self.osp_call("__jac_osp_jid", [self.osp_handle(self.lower_expr(args[0]), nd)]);
}
