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
    if c_builtin_kind(t)
        or foreign_struct_of_type(t) is not None
        or self.erased_class(t) {
        return None;
    }
    if stub_scope(scope) {
        return self.stdlib_counterpart(scope, t.shared.class_name);
    }
    return scope if isinstance(scope, uni.Archetype) else None;
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
    refused = self.refused_objects.get(name);
    if refused is not None {
        raise refused;
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    if owner is not self.module and owner.loc.mod_path.endswith(".jac") {
        self.adopt_imported_layouts(owner);
    }
    layout = get_layout_registry(owner, self.prog).get_layout(name);
    home = arch.loc.mod_path if arch.loc is not None else "";
    if layout is None
        and home.endswith(".jac")
        and os.path.realpath(home) != os.path.realpath(self.module.loc.mod_path) {
        current = self.live_unit(home);
        if current is not None and current is not owner {
            for elem in current.body {
                if isinstance(elem, uni.Archetype)
                    and archetype_native_name(elem) == name {
                    layout = get_layout_registry(current, self.prog).get_layout(name);
                    if layout is not None {
                        arch = elem;
                        owner = current;
                    }
                    break;
                }
            }
        }
    }
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
        glue_symbol=native_symbol_name(prefix, f"{name}.__drop_glue"),
        trace_symbol=native_symbol_name(prefix, f"{name}.__trace"),
        class_symbol=native_symbol_name(
            prefix, native_unit_spelling(f"{name}.__class", owner.loc.mod_path)
        )
    );
    self.mir.objects[name] = made;
    self.archetypes[name] = arch;
    try {
        for member in layout.fields {
            if member.name == EXC_MESSAGE_FIELD {
                made.fields.append(
                    MirObjectField(
                        name=member.name, type=mir_str_ref(), index=member.index
                    )
                );
                continue;
            }
            field_type = member.semantic_type
                or self.declared_field_type(member.decl_node);
            self.ensure_c_types(field_type);
            self.note_erasures(field_type);
            slot_type = mir_any()
                if self.erased_slot(field_type)
                    or self.host_only_type(field_type)
                    or self.foreign_field(field_type)
                else mir_type_of(
                    field_type, MirPosition.FIELD, member.decl_node or arch
                );
            if slot_type.kind != MirKind.ANY {
                self.ensure_objects(field_type);
            }
            self.record_enum_type(slot_type, field_type);
            tag = member.decl_node.type_tag
                if isinstance(member.decl_node, uni.HasVar)
                else None;
            made.fields.append(
                MirObjectField(
                    name=member.name,
                    type=slot_type,
                    index=member.index,
                    borrowed=self.tag_borrows(tag)
                )
            );
        }
        self.osp_header_fields(made, layout);
        if layout.has_vtable {
            made.vtable_symbol = native_symbol_name(
                prefix, native_unit_spelling(f"{name}.__vtable", owner.loc.mod_path)
            );
            specials = self.special_methods(arch);
            for slot in layout.methods {
                made.vtable_names.append(slot.name);
                if slot.owner != name and slot.name in specials {
                    made.vtable_methods.append(self.method_symbol(arch, slot.name));
                    continue;
                }
                owner_arch = self.archetypes.get(slot.owner);
                if owner_arch is not None {
                    made.vtable_methods.append(
                        self.method_symbol(owner_arch, slot.name)
                    );
                    continue;
                }
                owner_layout = get_layout_registry(owner, self.prog).get_layout(
                    slot.owner
                );
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
            if local {
                for slot in layout.methods {
                    inherited = self.find_method(arch, slot.name);
                    defining = inherited.find_parent_of_type(uni.Module)
                        if inherited is not None
                        else None;
                    if inherited is not None
                        and defining is not None
                        and defining is not self.module {
                        try {
                            self.foreign_method_decl(inherited);
                        } except MirRefused {
                            continue;
                        }
                    }
                }
            }
            for ancestor in layout.mro {
                ancestor_layout = get_layout_registry(owner, self.prog).get_layout(
                    ancestor
                );
                if ancestor_layout is not None and ancestor_layout.has_vtable {
                    ancestor_path = ancestor_layout.decl_mod or owner.loc.mod_path;
                    ancestor_symbol = native_symbol_name(
                        native_unit_prefix(ancestor_path),
                        native_unit_spelling(f"{ancestor}.__vtable", ancestor_path)
                    );
                    made.ancestry.append(ancestor_symbol);
                    moved = field_remap(layout, ancestor_layout);
                    if moved {
                        made.field_remaps[ancestor_symbol] = moved;
                    }
                }
            }
        }
        if not local {
            self.mir.externs[made.drop_symbol] = MirExtern(
                symbol=made.drop_symbol,
                ret=mir_none(),
                params=[mir_c_ptr(mir_int(8, False))]
            );
            self.add_dep(owner.loc.mod_path, name, arch);
        }
    } except MirRefused as err {
        self.mir.objects.pop(name, None);
        self.archetypes.pop(name, None);
        self.refused_objects[name] = err;
        raise err;
    }
    return made;
}

impl MirLowering.settle_slots {
    for (name, made) in list(self.mir.objects.items()) {
        arch = self.archetypes.get(name);
        if not made.local or not made.vtable_symbol or arch is None {
            continue;
        }
        wanted = set(made.vtable_methods);
        for holder in self.lineage(arch) {
            unit = holder.find_parent_of_type(uni.Module);
            if unit is None or unit is self.module {
                continue;
            }
            for method in self.arch_methods(holder) {
                symbol = self.method_symbol(holder, self.name_of(method));
                if symbol not in wanted or symbol in self.mir.externs {
                    continue;
                }
                try {
                    self.foreign_method_decl(method);
                } except MirRefused {}
            }
            for (slot_name, var, acc) in archetype_accessors(holder) {
                symbol = self.method_symbol(holder, slot_name);
                if symbol not in wanted or symbol in self.mir.externs {
                    continue;
                }
                try {
                    self.foreign_accessor_decl(var, acc);
                } except MirRefused {}
            }
        }
        for (index, slot_name) in enumerate(made.vtable_names) {
            if slot_name in NON_DISPATCHED_METHODS {
                continue;
            }
            method = self.find_method(arch, slot_name);
            if method is None {
                continue;
            }
            try {
                decl = self.method_decl_of(method);
            } except MirRefused {
                continue;
            }
            if decl is None or decl.symbol != made.vtable_methods[index] {
                continue;
            }
            base = self.slot_root(arch, slot_name);
            if base is None or mir_same_signature(base, decl) {
                continue;
            }
            adapter = self.slot_adapters.get(f"{decl.symbol}.__slot");
            if adapter is None {
                adapter = self.slot_adapter(decl, base);
                if adapter is not None {
                    self.mir.functions.append(adapter);
                    self.slot_adapters[adapter.symbol] = adapter;
                }
            }
            if adapter is not None {
                made.vtable_entries[index] = adapter.symbol;
            }
        }
    }
}

impl MirLowering.slot_root(arch: uni.Archetype, name: str) -> (MirDecl | None) {
    for holder in reversed(self.lineage(arch)) {
        for method in self.arch_methods(holder) {
            if self.name_of(method) != name {
                continue;
            }
            try {
                return self.method_decl_of(method);
            } except MirRefused {
                return None;
            }
        }
    }
    return None;
}

impl mir_same_signature(left: MirDecl, right: MirDecl) -> bool {
    return len(left.params) == len(right.params)
        and left.ret.render() == right.ret.render()
        and all(
            mine.render() == theirs.render()
            for (mine, theirs) in zip(left.params, right.params)
        );
}

impl MirLowering.slot_adapter(decl: MirDecl, base: MirDecl) -> (MirFunction | None) {
    if decl.self_type is None or len(decl.params) != len(base.params) {
        return None;
    }
    site = decl.ability;
    fn = MirFunction(
        name=f"{self.name_of(decl.ability)}.__slot",
        symbol=f"{decl.symbol}.__slot",
        ret=base.ret,
        linkage="internal"
    );
    first = fn.new_block("entry");
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        b = self.builder();
        receiver = fn.new_value(base.self_type or decl.self_type, "self");
        fn.params.append(MirParam(name="self", value=receiver));
        args: list[MirValue] = [
            receiver
                if receiver.type is decl.self_type
                else b.ref_cast(receiver, decl.self_type, False)
        ];
        for (index, (given, wanted)) in enumerate(zip(base.params, decl.params)) {
            value = fn.new_value(given, f"a{index}");
            fn.params.append(MirParam(name=f"a{index}", value=value));
            args.append(self.coerce(value, wanted, site));
        }
        if decl.ret.kind in (MirKind.NONE, MirKind.VOID) {
            b.call(decl.symbol, args, decl.ret);
            if base.ret.kind in (MirKind.NONE, MirKind.VOID) {
                b.ret(None);
            } else {
                b.ret(self.coerce(self.none_value(), base.ret, site));
            }
        } else {
            made = b.call(decl.symbol, args, decl.ret);
            if made is None {
                raise MirRefused(mir_refusal("method", decl.symbol, site));
            }
            if base.ret.kind in (MirKind.NONE, MirKind.VOID) {
                b.ret(None);
            } else {
                b.ret(self.coerce(made, base.ret, site));
            }
        }
    } except MirRefused {
        self.state = saved;
        return None;
    }
    self.state = saved;
    return fn;
}

impl MirLowering.note_lineage(arch: uni.Archetype, obj_def: MirObjectDef) {
    for ancestor in self.lineage(arch)[1:] {
        try {
            held = self.object_def(ancestor);
        } except MirRefused {
            continue;
        }
        if held.name != obj_def.name {
            self.class_lineages.append((obj_def.name, held.name));
        }
    }
    layout = self.osp_layout(arch);
    if layout is not None and layout.arch_type == "edge" {
        self.class_lineages.append((obj_def.name, ""));
    }
}

impl MirLowering.live_unit(path: str) -> (uni.Module | None) {
    return self.prog.mod.hub.get(path)
        or self.prog.mod.hub.get(os.path.realpath(path))
        or self.prog.load_dependency_module(
            os.path.realpath(path),
            importer_path=self.module.loc.mod_path,
            need_tree=True
        );
}

impl MirLowering.live_member(nd: uni.Ability) -> uni.Ability {
    if nd.parent is not None
        or nd.loc is None
        or not nd.loc.mod_path.endswith(".jac") {
        return nd;
    }
    unit = self.live_unit(nd.loc.mod_path);
    found = self.module_member(unit, self.name_of(nd)) if unit is not None else None;
    return found if isinstance(found, uni.Ability) else nd;
}

impl MirLowering.owner_archetype(nd: uni.UniNode) -> (uni.Archetype | None) {
    cursor = nd.parent;
    while cursor is not None {
        if isinstance(cursor, uni.Archetype) {
            return cursor;
        }
        if isinstance(cursor, uni.ImplDef) {
            linked = cursor.decl_link;
            if isinstance(linked, uni.Archetype) {
                return linked;
            }
            if isinstance(linked, uni.Ability) {
                return self.owner_archetype(linked);
            }
            return None;
        }
        if isinstance(cursor, uni.Module) {
            return None;
        }
        cursor = cursor.parent;
    }
    return None;
}

impl MirLowering.declared_field_type(decl: (uni.UniNode | None)) -> (TypeBase | None) {
    if not isinstance(decl, uni.HasVar) or decl.name.sym is None {
        return None;
    }
    return self.declared_type(decl.name.sym);
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

impl MirLowering.hasattr_value(
    target: uni.Expr, attr: uni.Expr, site: uni.UniNode
) -> MirValue {
    name = uni.literal_string_value(attr);
    if not isinstance(name, str) {
        raise MirRefused(
            mir_refusal(
                "call",
                "hasattr with a computed name",
                site,
                "Native code answers hasattr from the value's declared members, so the attribute name must be a string literal."
            )
        );
    }
    value = self.lower_expr(target);
    found = self.static_hasattr(value, target, name);
    if found is None {
        raise MirRefused(
            mir_refusal(
                "call",
                f"hasattr({value.type.render()}, {name!r})",
                site,
                "Native code answers hasattr from the value's declared members; this value's attributes are only known at run time."
            )
        );
    }
    return self.builder().const_bool(found);
}

impl MirLowering.static_hasattr(
    value: MirValue, target: uni.Expr, name: str
) -> (bool | None) {
    t = value.type;
    if t.kind == MirKind.OPT {
        return None;
    }
    if t.kind in (MirKind.OBJ, MirKind.CLASS, MirKind.OSP) {
        arch = self.archetypes.get(t.name);
        declared = target.type;
        if arch is None
            and isinstance(declared, ClassType)
            and declared._shared is not None
            and isinstance(declared.shared.symbol_table, uni.Archetype)
            and not stub_archetype(declared.shared.symbol_table) {
            arch = declared.shared.symbol_table;
        }
        if arch is None {
            return None;
        }
        for hook in ("__getattr__", "__getattribute__") {
            if self.find_method(arch, hook) is not None {
                return None;
            }
        }
        if not name.isidentifier() {
            return False;
        }
        if t.kind == MirKind.OBJ
            and (
                self.object_def(arch).field(name) is not None
                or self.find_method(arch, name) is not None
            ) {
            return True;
        }
        return None;
    }
    builtin: (type | None) = None;
    if t.kind in (MirKind.STR, MirKind.STR_REF) {
        builtin = str;
    } elif t.kind == MirKind.INT {
        builtin = int;
    } elif t.kind == MirKind.FLOAT {
        builtin = float;
    } elif t.kind == MirKind.BOOL {
        builtin = bool;
    } elif t.kind == MirKind.NONE {
        builtin = type(None);
    } elif mir_is_var_tuple(t) {
        builtin = tuple;
    } elif t.kind == MirKind.LIST {
        builtin = list;
    } elif t.kind == MirKind.DICT {
        builtin = dict;
    } elif t.kind == MirKind.SET {
        builtin = set;
    } elif t.kind == MirKind.BYTES {
        builtin = bytes;
    } elif t.kind == MirKind.BYTEARRAY {
        builtin = bytearray;
    } elif t.kind == MirKind.TUPLE {
        builtin = tuple;
    }
    if builtin is None {
        return None;
    }
    return hasattr(builtin, name);
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
    made = self.declared_type(sym) if sym is not None else None;
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
    owner = self.owner_archetype(method);
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
    params = [self.param_type(pv) for pv in self.param_nodes(sig, True)];
    fn_type = self.declared_type(self.ability_sym(method));
    ret = mir_none();
    if isinstance(fn_type, FunctionType) {
        ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, method);
    }
    symbol = self.method_symbol(owner, self.name_of(method));
    self.require_dep_native(unit.loc.mod_path, symbol, method);
    self.mir.externs[symbol] = MirExtern(
        symbol=symbol, ret=ret, params=[self_type] + params
    );
    self.add_dep(unit.loc.mod_path, symbol, method);
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

impl MirLowering.foreign_static_decl(method: uni.Ability) -> (MirDecl | None) {
    owner = self.owner_archetype(method);
    unit = method.find_parent_of_type(uni.Module);
    sig = method.signature;
    if owner is None
        or unit is None
        or unit is self.module
        or not unit.loc.mod_path.endswith(".jac")
        or not isinstance(sig, uni.FuncSignature)
        or not method.is_static
        or self.is_template(method) {
        return None;
    }
    params = [self.param_type(pv) for pv in self.param_nodes(sig, False)];
    fn_type = self.declared_type(self.ability_sym(method));
    ret = mir_none();
    if isinstance(fn_type, FunctionType) {
        ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, method);
    }
    symbol = self.method_symbol(owner, self.name_of(method));
    self.require_dep_native(unit.loc.mod_path, symbol, method);
    self.mir.externs[symbol] = MirExtern(symbol=symbol, ret=ret, params=params);
    self.add_dep(unit.loc.mod_path, symbol, method);
    made = MirDecl(ability=method, symbol=symbol, params=params, ret=ret, owner=owner);
    self.decls[id(method)] = made;
    return made;
}

impl MirLowering.foreign_accessor_decl(
    var: uni.HasVar, acc: uni.Ability
) -> (MirDecl | None) {
    owner = self.owner_archetype(var);
    unit = owner.find_parent_of_type(uni.Module) if owner is not None else None;
    if owner is None
        or unit is None
        or unit is self.module
        or not unit.loc.mod_path.endswith(".jac")
        or acc.accessor_kind not in ("property", "setter") {
        return None;
    }
    slot: (str | None) = None;
    for (name, _, held) in archetype_accessors(owner) {
        if held is acc {
            slot = name;
        }
    }
    if slot is None {
        return None;
    }
    self_type = self.object_type(owner);
    params: list[MirType] = [];
    ret = mir_none();
    if acc.accessor_kind == "property" {
        ret = self.type_of(self.declared_field_type(var), MirPosition.SIGNATURE, var);
    } else {
        sig = self.accessor_sig(acc);
        nodes = self.param_nodes(sig, True) if sig is not None else [];
        if len(nodes) != 1 {
            return None;
        }
        params.append(self.symbol_type(nodes[0].name.sym, nodes[0]));
    }
    symbol = self.method_symbol(owner, slot);
    self.require_dep_native(unit.loc.mod_path, symbol, acc);
    self.mir.externs[symbol] = MirExtern(
        symbol=symbol, ret=ret, params=[self_type] + params
    );
    self.add_dep(unit.loc.mod_path, symbol, acc);
    made = MirDecl(
        ability=acc,
        symbol=symbol,
        params=params,
        ret=ret,
        self_type=self_type,
        owner=owner
    );
    self.decls[id(acc)] = made;
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
        if self.is_template(method) {
            self.templates[id(method)] = method;
            continue;
        }
        params: list[MirType] = [];
        for pv in self.param_nodes(sig, not method.is_static) {
            params.append(self.param_type(pv));
        }
        fn_type = self.declared_type(self.ability_sym(method));
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
            self_type=None
                if method.is_static
                else (mir_class("*") if method.is_classmethod else self_type),
            owner=arch
        );
        self.order.append(key);
    }
    self.declare_specials(arch, self_type);
    self.declare_accessors(arch, self_type);
    self.declare_osp_abilities(arch);
    if obj_def.local and not obj_def.is_acyclic {
        self.trace_pairs.append((obj_def.drop_symbol, obj_def.trace_symbol));
    }
}

impl MirLowering.special_methods(arch: uni.Archetype) -> dict[str, uni.Ability] {
    found: dict[str, uni.Ability] = {};
    name = archetype_native_name(arch);
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    registry = get_layout_registry(owner, self.prog);
    for holder in self.lineage(arch)[1:] {
        if registry.is_primary_ancestor(name, archetype_native_name(holder))
            or (holder.find_parent_of_type(uni.Module) or self.module) is not owner {
            continue;
        }
        for method in self.arch_methods(holder) {
            label = self.name_of(method);
            if label not in found
                and not method.is_static
                and not self.is_template(method)
                and self.find_method(arch, label) is method {
                found[label] = method;
            }
        }
    }
    return found;
}

impl MirLowering.declare_specials(arch: uni.Archetype, self_type: MirType) {
    for (label, method) in self.special_methods(arch).items() {
        sig = method.signature;
        if not isinstance(sig, uni.FuncSignature) {
            continue;
        }
        params: list[MirType] = [];
        for pv in self.param_nodes(sig, True) {
            params.append(self.param_type(pv));
        }
        fn_type = self.declared_type(self.ability_sym(method));
        ret = mir_none();
        if isinstance(fn_type, FunctionType) {
            ret = self.type_of(fn_type.return_type, MirPosition.SIGNATURE, method);
        }
        made = MirDecl(
            ability=method,
            symbol=self.method_symbol(arch, label),
            params=params,
            ret=ret,
            self_type=self_type,
            owner=arch
        );
        key = id(made);
        self.decls[key] = made;
        self.specials[f"{archetype_native_name(arch)}.{label}"] = key;
        self.order.append(key);
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
    keyword_only: set[str] = set();
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
        var = nearest if nearest is not None else decl;
        if isinstance(var, uni.HasVar) {
            initialization = field_initialization(var);
            if not initialization.participates_in_init {
                continue;
            }
            if initialization.keyword_only {
                keyword_only.add(member.name);
            }
            if self.field_default_of(var) is not var.value {
                default_value = self.field_default_of(var);
            }
        }
        held = obj_def.field(member.name);
        if held is not None {
            found.append((member.name, held.type, default_value));
        }
    }
    self.ctor_keyword_only[obj_def.name] = keyword_only;
    return found;
}

impl MirLowering.object_alloc(
    arch: uni.Archetype, obj_def: MirObjectDef, self_type: MirType
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    size = fn.new_value(mir_int());
    b.emit(MirInstr(op=MirOp.SIZEOF, result=size, type_arg=self_type));
    eligible = arch.arch_type.name != Tok.KW_WALKER
        and not is_kernel_unit_path(self.module.loc.mod_path);
    (word, arena) = self.region_alloc(
        size, obj_def.drop_symbol, obj_def.local, eligible
    );
    raw = self.emit_value(MirOp.PTR_CAST, mir_ref(), [word]);
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
        [
            b.binary("sub", address, b.const_int(8, mir_int())),
            b.select(
                b.compare("ne", arena, b.const_int(0, mir_int())), arena, drop_address
            )
        ]
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
    return this;
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
        consumed: list[int] = [];
        for (index, (pname, ptype, _)) in enumerate(params) {
            value = fn.new_value(ptype, pname);
            fn.params.append(MirParam(name=pname, value=value));
            if self.owned_world
                and mir_holds_ref(ptype)
                and self.field_consumes(arch, pname) {
                value.owned = True;
                consumed.append(index);
            }
            values.append(value);
        }
        if consumed {
            self.ctor_consumes[symbol] = consumed;
        }
        words = self.ctor_mask_words(params);
        if words {
            given: list[MirValue] = [];
            for word in range(words) {
                held = fn.new_value(mir_int(), f"__given{word}");
                fn.params.append(MirParam(name=f"__given{word}", value=held));
                given.append(held);
            }
            for (index, (pname, ptype, fallback)) in enumerate(params) {
                if fallback is None {
                    continue;
                }
                values[index] = self.ctor_default(
                    values[index], given, index, fallback
                );
            }
        }
        this = self.object_alloc(arch, obj_def, self_type);
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
            initial = self.field_default_of(nearest)
                if nearest is not None
                else member.default_expr;
            if member.name in named or not isinstance(initial, uni.Expr) {
                continue;
            }
            place = self.field_place(this, arch, member.name, arch);
            made = self.default_value(initial, self.place_elem(place));
            if isinstance(member.decl_node, uni.HasVar) {
                self.lend_fresh(made, member.decl_node.type_tag, initial);
            }
            b.store(place, made);
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
        post = (
            self.find_method(arch, "postinit")
            or self.find_method(arch, "__post_init__")
        )
            if init is None
            else None;
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
        self.refusals.setdefault(fn.symbol, []).append(refusal_of(err));
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
    release_bb = fn.new_block("drop.fields");
    free_bb = fn.new_block("drop.free");
    if (self.prog.options.na_gc_mode or "cycles") == "cycles" {
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
        b.cond_branch(
            b.compare("eq", collecting, b.const_int(0, collecting.type)),
            release_bb,
            free_bb
        );
    } else {
        b.branch(release_bb);
    }
    b.position(release_bb);
    for member in obj_def.fields {
        if not mir_holds_ref(member.type) or (self.owned_world and member.borrowed) {
            continue;
        }
        place = self.emit_value(
            MirOp.FIELD_ADDR, mir_c_ptr(member.type), [this], int_value=member.index
        );
        held = b.load(place, member.type);
        if not self.owned_world or not self.drop_through_glue(held) {
            b.emit(MirInstr(op=MirOp.RELEASE, operands=[held]));
        }
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

impl MirLowering.drop_through_glue(held: MirValue) -> bool {
    b = self.builder();
    i8p = mir_c_ptr(mir_int(8, False));
    target = held.type.payload() if held.type.kind == MirKind.OPT else held.type;
    if target.kind != MirKind.OBJ {
        return False;
    }
    obj_def = self.mir.objects.get(target.name);
    if obj_def is None or not obj_def.local or not obj_def.glue_symbol {
        return False;
    }
    subject = held;
    if held.type.kind == MirKind.OPT {
        subject = b.select(
            self.opt_present(held), self.opt_get(held), b.const_null(target)
        );
    }
    b.call(
        obj_def.glue_symbol,
        [self.emit_value(MirOp.PTR_CAST, i8p, [subject])],
        mir_none()
    );
    return True;
}

impl MirLowering.lower_drop_glue(obj_def: MirObjectDef) -> MirFunction {
    i8p = mir_c_ptr(mir_int(8, False));
    fn = MirFunction(
        name=f"{obj_def.name}.__drop_glue",
        symbol=obj_def.glue_symbol,
        ret=mir_none(),
        manual_rc=True,
        linkage="internal"
    );
    first = fn.new_block("entry");
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    b = self.builder();
    raw = fn.new_value(i8p, "o");
    fn.params.append(MirParam(name="o", value=raw));
    address = self.address_of(raw);
    live = fn.new_block("glue.live");
    owned = fn.new_block("glue.owned");
    done = fn.new_block("glue.done");
    b.cond_branch(b.compare("ne", address, b.const_int(0, mir_int())), live, done);
    b.position(live);
    arena = self.region_call("__jac_region_of", [address]);
    b.cond_branch(b.compare("eq", arena, b.const_int(0, mir_int())), owned, done);
    b.position(owned);
    if obj_def.vtable_slot >= 0 {
        this = b.ref_cast(raw, mir_obj(obj_def.name), False);
        slot_place = self.emit_value(
            MirOp.FIELD_ADDR,
            mir_c_ptr(mir_c_ptr(i8p)),
            [this],
            int_value=obj_def.vtable_slot
        );
        table = b.load(slot_place, mir_c_ptr(i8p));
        entry_place = self.emit_value(
            MirOp.PTR_OFFSET,
            mir_c_ptr(i8p),
            [table, b.const_int(VTABLE_DROP_SLOT, mir_int())]
        );
        target = b.load(entry_place, i8p);
        exact = fn.new_block("glue.exact");
        shared = fn.new_block("glue.shared");
        b.cond_branch(
            b.compare("ne", self.address_of(target), b.const_int(0, mir_int())),
            exact,
            shared
        );
        b.position(exact);
        body = self.emit_value(MirOp.PTR_CAST, mir_c_fn([i8p], mir_none()), [target]);
        self.emit_value(MirOp.CALL_FNPTR, mir_none(), [body, raw]);
        b.branch(done);
        b.position(shared);
        b.emit(MirInstr(op=MirOp.RELEASE, operands=[this]));
    } else {
        b.call(obj_def.drop_symbol, [raw], mir_none());
    }
    b.branch(done);
    b.position(done);
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

impl MirLowering.lower_text_thunk(
    obj_def: MirObjectDef, arch: uni.Archetype
) -> (MirFunction | None) {
    i8p = mir_c_ptr(mir_int(8, False));
    fn = MirFunction(
        name=f"{obj_def.name}.__text",
        symbol=native_symbol_name(
            native_unit_prefix(self.module.loc.mod_path), f"{obj_def.name}.__text"
        ),
        ret=mir_none(),
        linkage="internal"
    );
    first = fn.new_block("entry");
    frame = fn.new_value(i8p, "frame");
    fn.params.append(MirParam(name="frame", value=frame));
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        b = self.builder();
        base = self.address_of(frame);
        word = self.emit_value(MirOp.MEM_LOAD, mir_int(), [base]);
        mode = self.emit_value(
            MirOp.MEM_LOAD,
            mir_int(),
            [b.binary("add", base, b.const_int(TEXT_THUNK_MODE, mir_int()))]
        );
        this = b.ref_cast(
            self.emit_value(MirOp.PTR_CAST, i8p, [word]), mir_obj(obj_def.name), False
        );
        repr_bb = fn.new_block("text.repr");
        str_bb = fn.new_block("text.str");
        done = fn.new_block("text.done");
        b.cond_branch(
            b.compare("ne", mode, b.const_int(0, mir_int())), repr_bb, str_bb
        );
        for (block, method) in ((repr_bb, "__repr__"), (str_bb, "__str__")) {
            b.position(block);
            self.store_text_result(base, self.object_text(this, method, arch));
            b.branch(done);
        }
        b.position(done);
        b.ret(None);
    } except MirRefused as err {
        self.state = saved;
        return None;
    }
    self.state = saved;
    return fn;
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
        if member.type.kind == MirKind.ANY {
            place = self.emit_value(
                MirOp.FIELD_ADDR, mir_c_ptr(member.type), [this], int_value=member.index
            );
            tagged = b.load(place, member.type);
            tag = self.emit_value(MirOp.ANY_TAG, mir_int(), [tagged]);
            word = self.emit_value(MirOp.ANY_PAYLOAD, mir_int(), [tagged]);
            traced = b.binary(
                "and",
                b.binary(
                    "and",
                    b.compare("ge", tag, b.const_int(ANY_LIST_TAG, mir_int())),
                    b.compare("le", tag, b.const_int(ANY_OBJ_TAG, mir_int()))
                ),
                b.compare("ne", word, b.const_int(0, mir_int()))
            );
            present = fn.new_block("trace.tagged");
            after = fn.new_block("trace.next");
            b.cond_branch(traced, present, after);
            b.position(present);
            self.emit_value(
                MirOp.CALL_FNPTR,
                mir_none(),
                [
                    visit_fn,
                    self.emit_value(
                        MirOp.PTR_CAST, i8p, [b.ref_cast(tagged, mir_ref(), False)]
                    )
                ]
            );
            b.branch(after);
            b.position(after);
            continue;
        }
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
    if holder.type.kind == MirKind.OPT
        and holder.type.payload().kind in (MirKind.OBJ, MirKind.OSP) {
        holder = self.opt_unwrap_checked(
            holder, f"'NoneType' object has no attribute '{name}'", "AttributeError"
        );
    }
    if holder.type.kind == MirKind.ANY {
        holder = self.coerce(holder, self.object_type(arch), site);
    }
    if holder.type.kind == MirKind.OBJ and holder.type.name != obj_def.name {
        holder = self.builder().ref_cast(holder, mir_obj(obj_def.name), False);
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
    place = self.emit_value(
        MirOp.FIELD_ADDR, mir_c_ptr(member.type), [holder], int_value=member.index
    );
    if obj_def.vtable_slot < 0 {
        return place;
    }
    return self.remapped_field(holder, obj_def, member.index, place);
}

impl MirLowering.remapped_field(
    holder: MirValue, obj_def: MirObjectDef, index: int, place: MirValue
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    i8p = mir_c_ptr(mir_int(8, False));
    table = b.load(
        self.emit_value(
            MirOp.FIELD_ADDR,
            mir_c_ptr(mir_c_ptr(i8p)),
            [holder],
            int_value=obj_def.vtable_slot
        ),
        mir_c_ptr(i8p)
    );
    remap = self.address_of(
        b.load(
            self.emit_value(
                MirOp.PTR_OFFSET,
                mir_c_ptr(i8p),
                [table, b.const_int(VTABLE_FIELDS_SLOT, mir_int())]
            ),
            i8p
        )
    );
    held = self.temp_slot(place.type);
    b.store(held, place);
    moved = fn.new_block("field.moved");
    done = fn.new_block("field.done");
    b.cond_branch(b.compare("ne", remap, b.const_int(0, mir_int())), moved, done);
    b.position(moved);
    found = self.runtime_value(
        "__jac_rt_field_at",
        [
            remap,
            self.address_of(
                self.emit_value(
                    MirOp.VTABLE_ADDR, mir_c_ptr(i8p), [], str_value=obj_def.name
                )
            ),
            b.const_int(index, mir_int()),
            self.address_of(place),
            self.address_of(holder)
        ]
    );
    b.store(held, self.emit_value(MirOp.PTR_CAST, place.type, [found]));
    b.branch(done);
    b.position(done);
    return b.load(held, place.type);
}

impl MirLowering.checked_cross_cast(
    value: MirValue, to: MirType, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    target = self.arch_named(to.name, site);
    held = self.spill(value);
    self.raise_if(
        b.logical_not(self.isinstance_check(held, target)),
        "TypeError",
        f"expected {target.name.value}, got another archetype"
    );
    return b.ref_cast(held, to, False);
}

impl MirLowering.member_test(
    held: MirValue, view: MirValue, arch: uni.Archetype, site: uni.UniNode
) -> MirValue {
    if held.type.kind != MirKind.ANY {
        return self.isinstance_check(held, arch);
    }
    name = self.object_def(arch).name;
    named = self.address_of(self.runtime_value("__jac_rt_type_name", [view]));
    return self.exact_class_test(named, self.runtime_classes(name, name), site);
}

impl MirLowering.exact_class_test(
    named: MirValue, classes: list[str], site: uni.UniNode
) -> MirValue {
    b = self.builder();
    i8p = mir_c_ptr(mir_int(8, False));
    verdict = b.const_bool(False);
    for cls in classes {
        cls_def = self.object_def(self.arch_named(cls, site));
        verdict = b.binary(
            "or",
            verdict,
            b.compare(
                "eq",
                named,
                self.address_of(
                    self.emit_value(MirOp.CLASS_ADDR, i8p, [], str_value=cls_def.name)
                )
            )
        );
    }
    return verdict;
}

impl MirLowering.layout_registries(name: str) -> list[LayoutRegistry] {
    found = [get_layout_registry(self.module, self.prog)];
    arch = self.archetypes.get(name);
    owner = arch.find_parent_of_type(uni.Module) if arch is not None else None;
    if owner is not None and owner is not self.module {
        found.append(get_layout_registry(owner, self.prog));
    }
    return found;
}

impl MirLowering.runtime_classes(target: str, seen_from: str) -> list[str] {
    found: set[str] = set();
    for registry in self.layout_registries(target) {
        below = set(registry.descendants_of([target]));
        if seen_from != target {
            below = below & set(registry.descendants_of([seen_from]));
        }
        found = found | below;
    }
    return sorted(found);
}

impl MirLowering.arch_named(name: str, site: uni.UniNode) -> uni.Archetype {
    found = self.archetypes.get(name) or self.named_archs.get(name);
    if found is not None {
        return found;
    }
    units: list[uni.Module] = [self.module];
    for registry in self.layout_registries(name) {
        layout = registry.get_layout(name);
        if layout is not None and layout.decl_mod {
            unit = self.prog.mod.hub.get(layout.decl_mod)
                or self.prog.mod.hub.get(os.path.realpath(layout.decl_mod));
            if unit is not None {
                units.insert(0, unit);
            }
        }
    }
    for known in list(self.archetypes.values()) {
        owner = known.find_parent_of_type(uni.Module);
        if owner is not None and not any(owner is unit for unit in units) {
            units.append(owner);
        }
    }
    for unit in units {
        if id(unit) in self.indexed_units {
            continue;
        }
        self.indexed_units.add(id(unit));
        for arch in unit.get_all_sub_nodes(uni.Archetype) {
            self.named_archs.setdefault(archetype_native_name(arch), arch);
        }
        if name in self.named_archs {
            return self.named_archs[name];
        }
    }
    raise MirRefused(
        mir_refusal(
            "archetype",
            name,
            site,
            "An archetype that inherits this member is not visible to this unit."
        )
    );
}

impl MirLowering.object_call(
    nd: uni.FuncCall, arch: uni.Archetype, leading: int = 0
) -> MirValue {
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
    if init is None
        and list(nd.params or [])[leading:]
        and all(
            holder.arch_type.name == Tok.KW_CLASS for holder in self.lineage(arch)
        ) {
        raise MirRefused(
            mir_refusal(
                "constructor call",
                arch.name.value,
                nd,
                f"'{arch.name.value}' is a `class` archetype with no initializer, so like a Python class it takes no constructor arguments; its `has` fields do not become constructor parameters. Declare `def init(...)` or make it an `obj`."
            )
        );
    }
    if init is not None
        and isinstance(init.signature, uni.FuncSignature)
        and (
            init.signature.varargs is not None
            or init.signature.kwargs is not None
            or init.signature.kwonlyargs
            or self.has_spread(nd)
        ) {
        bound = self.bound_args(nd, init, True, leading);
        if len(bound) != len(params) {
            raise MirRefused(
                mir_refusal("call", f"{obj_def.name} with {len(bound)} arguments", nd)
            );
        }
        values = self.bound_values(list(bound), [param[1] for param in params]);
        given: list[int] = [];
        for (index, param) in enumerate(params) {
            if param[2] is not None {
                self.ctor_mask_set(given, index);
            }
        }
        values.extend(self.ctor_mask(given, params));
        return self.construct(symbol, obj_def, owner, params, values, nd);
    }
    values = self.ctor_arguments(nd, obj_def.name, params, leading);
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
            params=[p[1] for p in params] + [mir_int()] * self.ctor_mask_words(params)
        );
        self.add_dep(owner.loc.mod_path, obj_def.name, nd);
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
    derived = self.archetypes.get(receiver.type.name)
        if receiver.type.kind == MirKind.OBJ
        else None;
    if derived is not None
        and derived is not arch
        and self.obj_extends(receiver.type.name, archetype_native_name(arch)) {
        arch = derived;
    }
    method = self.find_method(arch, name);
    if method is None {
        return None;
    }
    if self.template_of(method) {
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

impl MirLowering.super_call(nd: uni.FuncCall, name: str) -> MirValue {
    receiver = self.st().self_value;
    held = self.super_self(nd) if receiver is None else None;
    cell = self.cell_of(id(held)) if held is not None else None;
    if held is not None and cell is not None {
        receiver = self.cell_read(cell, self.st().cell_types[id(held)]);
    }
    arch = self.archetypes.get(receiver.type.name)
        if receiver is not None and receiver.type.kind == MirKind.OBJ
        else None;
    if receiver is None or arch is None {
        raise MirRefused(mir_refusal("name", "super", nd));
    }
    lineage = self.lineage(arch);
    names = ["init", "__init__"] if name in ("init", "__init__") else [name];
    for holder in lineage[1:] {
        for method in self.arch_methods(holder) {
            if self.name_of(method) in names and not method.is_static {
                return self.direct_method_call(nd, holder, method, receiver, 0);
            }
        }
    }
    if len(lineage) < 2 or name not in ("init", "__init__") {
        raise MirRefused(
            mir_refusal(
                "method",
                f"super.{name}",
                nd,
                "No ancestor declares this method, so there is no body for `super` to call."
            )
        );
    }
    b = self.builder();
    params = self.constructor_params(lineage[1]);
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
        } elif isinstance(arg, uni.Expr) {
            positional.append(arg);
        }
    }
    if len(positional) > len(params) {
        raise MirRefused(
            mir_refusal("call", f"super.{name} with {len(positional)} arguments", nd)
        );
    }
    assigned: list[tuple[str, MirValue]] = [];
    for (index, (pname, ptype, fallback)) in enumerate(params) {
        source = positional[index] if index < len(positional) else named.get(pname);
        if source is not None {
            assigned.append(
                (pname, self.spill(self.coerce(self.lower_expr(source), ptype, source)))
            );
        } elif fallback is not None {
            assigned.append((pname, self.spill(self.default_value(fallback, ptype))));
        } else {
            raise MirRefused(mir_refusal("call", f"super.{name} missing {pname}", nd));
        }
    }
    for (pname, value) in assigned {
        b.store(self.field_place(receiver, arch, pname, nd), value);
    }
    return b.const_bool(False);
}

impl MirLowering.direct_method_call(
    nd: uni.FuncCall,
    holder: uni.Archetype,
    method: uni.Ability,
    receiver: MirValue,
    leading: int
) -> MirValue {
    name = self.name_of(method);
    decl = self.method_decl(holder, method, name, nd);
    receiver = self.method_receiver(decl, holder, receiver, nd);
    args = self.bound_args(nd, method, True, leading);
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

impl MirLowering.unbound_method(
    nd: uni.FuncCall, arch: uni.Archetype, name: str
) -> (MirValue | None) {
    method = self.find_method(arch, name);
    passed = list(nd.params or []);
    if method is None
        or method.is_static
        or method.is_classmethod
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

impl MirLowering.object_operator(
    op: str, left: MirValue, right: MirValue, site: uni.UniNode, inplace: bool = False
) -> (MirValue | None) {
    stem = OPERATOR_DUNDERS.get(op);
    if stem is None {
        return None;
    }
    tries: list[tuple[MirValue, MirValue, str]] = [];
    if inplace {
        tries.append((left, right, f"__i{stem}__"));
    }
    tries.extend([(left, right, f"__{stem}__"), (right, left, f"__r{stem}__")]);
    for (receiver, other, name) in tries {
        if receiver.type.kind != MirKind.OBJ {
            continue;
        }
        arch = self.archetypes.get(receiver.type.name);
        if arch is None {
            continue;
        }
        method = self.find_method(arch, name);
        if method is None or method.is_static {
            continue;
        }
        decl = self.method_decl(arch, method, name, site);
        if len(decl.params) != 1 {
            raise MirRefused(
                mir_refusal(
                    "binary operator", f"{name} with a signature of its own", site
                )
            );
        }
        held = self.method_receiver(decl, arch, receiver, site);
        return self.invoke_method(
            decl, arch, name, [held, self.coerce(other, decl.params[0], site)]
        );
    }
    return None;
}

impl MirLowering.object_eq(
    left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    arch = self.archetypes.get(left.type.name)
        if left.type.kind == MirKind.OBJ
        else None;
    method = self.find_method(arch, "__eq__") if arch is not None else None;
    if arch is None or method is None or method.is_static {
        return self.identity(left, right, site);
    }
    decl = self.method_decl(arch, method, "__eq__", site);
    if len(decl.params) != 1 {
        raise MirRefused(
            mir_refusal("comparison", "__eq__ with a signature of its own", site)
        );
    }
    receiver = self.method_receiver(decl, arch, left, site);
    verdict = self.invoke_method(
        decl, arch, "__eq__", [receiver, self.coerce(right, decl.params[0], site)]
    );
    return self.truthy(verdict, site);
}

impl MirLowering.object_compare(
    name: str, left: MirValue, right: MirValue, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    dunder = "__eq__" if name == "eq" else "__ne__";
    first = left;
    second = right;
    left_arch = self.archetypes.get(left.type.name)
        if left.type.kind == MirKind.OBJ
        else None;
    right_arch = self.archetypes.get(right.type.name)
        if right.type.kind == MirKind.OBJ
        else None;
    if left_arch is not None
        and right_arch is not None
        and right_arch is not left_arch
        and self.obj_extends(right.type.name, left.type.name)
        and any(
            self.name_of(method) in ("__eq__", dunder)
            for method in self.arch_methods(right_arch)
        ) {
        first = right;
        second = left;
    }
    holder = self.archetypes.get(first.type.name)
        if first.type.kind == MirKind.OBJ
        else None;
    if name == "ne" and holder is not None {
        method = self.find_method(holder, "__ne__");
        if method is not None and not method.is_static {
            decl = self.method_decl(holder, method, "__ne__", site);
            if len(decl.params) == 1 {
                verdict = self.invoke_method(
                    decl,
                    holder,
                    "__ne__",
                    [
                        self.method_receiver(decl, holder, first, site),
                        self.coerce(second, decl.params[0], site)
                    ]
                );
                return self.truthy(verdict, site);
            }
        }
    }
    same = self.object_eq(first, second, site);
    return same if name == "eq" else b.logical_not(same);
}

impl MirLowering.holder_arch(expr: uni.Expr) -> (uni.Archetype | None) {
    if isinstance(expr, uni.Name)
        and expr.sym is not None
        and self.state is not None
        and id(expr.sym) in self.st().retyped {
        retyped = self.st().retyped[id(expr.sym)];
        if retyped.kind == MirKind.OBJ and retyped.name in self.archetypes {
            return self.archetypes[retyped.name];
        }
    }
    seen = expr.narrowed_type if expr.narrowed_type is not None else expr.type;
    found = self.arch_of_type(seen);
    if found is not None or not isinstance(seen, UnionType) {
        return found;
    }
    members = [
        member
        for member in seen.types
        if not (
            isinstance(member, ClassType)
            and member.shared.class_name in ("NoneType", "None")
        )
    ];
    return self.arch_of_type(members[0]) if len(members) == 1 else None;
}

impl MirLowering.method_decl_of(method: uni.Ability) -> (MirDecl | None) {
    return self.decls.get(id(method))
        or self.foreign_method_decl(method)
        or self.foreign_static_decl(method);
}

impl MirLowering.method_decl(
    arch: uni.Archetype, method: uni.Ability, name: str, site: uni.UniNode
) -> MirDecl {
    special = self.specials.get(f"{archetype_native_name(arch)}.{name}");
    if special is not None and self.decls[special].ability is method {
        return self.decls[special];
    }
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
    if decl.self_type.kind == MirKind.CLASS {
        if receiver.type.kind == MirKind.CLASS {
            return receiver;
        }
        return self.class_of(receiver, site);
    }
    if receiver.type.kind == MirKind.OBJ
        and self.obj_extends(archetype_native_name(arch), decl.self_type.name) {
        return self.builder().ref_cast(receiver, decl.self_type, False);
    }
    return self.coerce(receiver, decl.self_type, site);
}

impl MirLowering.vtable_target(
    receiver: MirValue, obj_def: MirObjectDef, slot: int
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    i8p = mir_c_ptr(mir_int(8, False));
    slot_place = self.emit_value(
        MirOp.FIELD_ADDR,
        mir_c_ptr(mir_c_ptr(i8p)),
        [receiver],
        int_value=obj_def.vtable_slot
    );
    table = b.load(slot_place, mir_c_ptr(i8p));
    selector = mir_selector_global(obj_def.vtable_names[slot]);
    if selector.symbol not in self.mir.globals {
        self.mir.globals[selector.symbol] = selector;
    }
    wanted = self.address_of(
        self.emit_value(
            MirOp.GLOBAL_ADDR, mir_c_ptr(selector.type), [], str_value=selector.symbol
        )
    );
    selectors = self.emit_value(
        MirOp.PTR_CAST,
        mir_c_ptr(i8p),
        [
            b.load(
                self.emit_value(
                    MirOp.PTR_OFFSET,
                    mir_c_ptr(i8p),
                    [table, b.const_int(VTABLE_SELECTOR_SLOT, mir_int())]
                ),
                i8p
            )
        ]
    );
    seen = self.address_of(
        b.load(
            self.emit_value(
                MirOp.PTR_OFFSET,
                mir_c_ptr(i8p),
                [selectors, b.const_int(slot, mir_int())]
            ),
            i8p
        )
    );
    held = self.temp_slot(i8p);
    fixed = fn.new_block("vtable.fixed");
    moved = fn.new_block("vtable.moved");
    done = fn.new_block("vtable.done");
    b.cond_branch(b.compare("eq", seen, wanted), fixed, moved);
    b.position(fixed);
    b.store(
        held,
        b.load(
            self.emit_value(
                MirOp.PTR_OFFSET,
                mir_c_ptr(i8p),
                [table, b.const_int(slot + VTABLE_HEADER_SLOTS, mir_int())]
            ),
            i8p
        )
    );
    b.branch(done);
    b.position(moved);
    found = self.runtime_value(
        "__jac_rt_vtable_find", [self.address_of(table), wanted]
    );
    b.store(held, self.emit_value(MirOp.PTR_CAST, i8p, [found]));
    b.branch(done);
    b.position(done);
    return b.load(held, i8p);
}

impl MirLowering.invoke_method(
    decl: MirDecl, arch: uni.Archetype, name: str, values: list[MirValue]
) -> MirValue {
    receiver = values[0];
    obj_def = self.object_def(arch);
    if obj_def.vtable_symbol
        and receiver.type.kind != MirKind.CLASS
        and decl.symbol in obj_def.vtable_methods
        and (
            name not in NON_DISPATCHED_METHODS or name in ("postinit", "__post_init__")
        ) {
        target = self.vtable_target(
            receiver, obj_def, obj_def.vtable_methods.index(decl.symbol)
        );
        base = self.slot_root(arch, name);
        if base is None
            or mir_same_signature(base, decl)
            or len(base.params) != len(values) - 1 {
            base = decl;
        }
        site = decl.ability;
        passed = [receiver]
            + [
                self.coerce(value, wanted, site) if value.type is not wanted else value
                for (value, wanted) in zip(values[1:], base.params)
            ];
        signature = mir_c_fn([receiver.type] + base.params, base.ret);
        callee = self.emit_value(MirOp.PTR_CAST, signature, [target]);
        result_type = mir_none()
            if base.ret.kind in (MirKind.NONE, MirKind.VOID)
            else base.ret;
        result = self.emit_value(
            MirOp.CALL_FNPTR, result_type, [callee] + passed, str_value=decl.symbol
        );
        result.owned = mir_holds_ref(result_type);
        if base is decl or decl.ret.kind in (MirKind.NONE, MirKind.VOID) {
            return result;
        }
        return self.coerce(result, decl.ret, site);
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
    if value.type.kind == MirKind.OBJ
        and value.type.name != "*"
        and self.obj_extends(value.type.name, obj_def.name) {
        return b.const_bool(True);
    }
    if not obj_def.vtable_symbol or value.type.kind != MirKind.OBJ {
        if value.type.kind != MirKind.OBJ {
            return b.const_bool(False);
        }
        return self.runtime_value(
            "__jac_rt_class_isa",
            [
                self.address_of(self.runtime_value("__jac_rt_type_name", [value])),
                self.address_of(
                    self.emit_value(
                        MirOp.CLASS_ADDR,
                        mir_c_ptr(mir_int(8, False)),
                        [],
                        str_value=obj_def.name
                    )
                )
            ]
        );
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
        and not self.class_inits
        and not self.osp_setup
        and not self.class_entries
        and not self.class_lineages
        and not self.default_entries
        and not self.text_pairs
        and not self.decorations
        and not any(isinstance(nd, uni.GlobalVars) for nd in self.module.body) {
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
        for (drop_symbol, thunk_symbol) in self.text_pairs {
            i8p = mir_c_ptr(mir_int(8, False));
            block = b.block;
            start = len(block.instrs);
            words = [
                self.emit_value(
                    MirOp.PTR_INT,
                    mir_int(),
                    [
                        self.emit_value(
                            MirOp.FN_ADDR,
                            mir_c_fn([i8p], mir_none()),
                            [],
                            callee=symbol
                        )
                    ]
                ) for symbol in (drop_symbol, thunk_symbol)
            ];
            self.runtime("__jac_rt_text_register", words);
            self.text_regs[thunk_symbol] = (block, list(block.instrs[start:]));
        }
        for (made_name, adapter_symbol) in self.default_entries {
            i8p = mir_c_ptr(mir_int(8, False));
            self.runtime(
                "__jac_rt_class_ctor_register",
                [
                    self.address_of(
                        self.emit_value(MirOp.CLASS_ADDR, i8p, [], str_value=made_name)
                    ),
                    b.const_int(0, mir_int()),
                    self.emit_value(
                        MirOp.PTR_INT,
                        mir_int(),
                        [
                            self.emit_value(
                                MirOp.FN_ADDR,
                                mir_c_fn([], mir_none()),
                                [],
                                callee=adapter_symbol
                            )
                        ]
                    )
                ]
            );
        }
        for (made_name, base_name) in self.class_lineages {
            i8p = mir_c_ptr(mir_int(8, False));
            self.runtime(
                "__jac_rt_class_isa_add",
                [
                    self.address_of(
                        self.emit_value(MirOp.CLASS_ADDR, i8p, [], str_value=made_name)
                    ),
                    self.address_of(
                        self.emit_value(MirOp.CLASS_ADDR, i8p, [], str_value=base_name)
                    )
                        if base_name
                        else b.const_int(EDGE_CLASS_MARK, mir_int())
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
        steps: list[tuple[int, int, int]] = [
            (initial.loc.pos_start, 0, at)
            for (at, (_, initial)) in enumerate(self.deferred_globals)
        ];
        steps.extend(
            [(start, 1, at) for (at, (start, _)) in enumerate(self.class_inits)]
        );
        steps.extend(
            [(start, 2, at) for (at, (start, _)) in enumerate(self.decorations)]
        );
        for (_, step, at) in sorted(steps) {
            if step == 1 {
                b.call(self.class_inits[at][1], [], mir_none());
                continue;
            }
            if step == 2 {
                b.call(self.decorations[at][1], [], mir_none());
                continue;
            }
            (glob_def, initial) = self.deferred_globals[at];
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
        if isinstance(elem, uni.ModuleCode)
            and (elem.name is None or elem.name.sym_name == "__main__") {
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
            self.drop_regions();
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

impl MirLowering.host_only_type(t: (TypeBase | None)) -> bool {
    if not self.prog.options.native_unit {
        return False;
    }
    members = t.types if isinstance(t, UnionType) else [t];
    for member in members {
        if isinstance(member, ClassType) and self.erased_class(member) {
            return True;
        }
    }
    return False;
}

impl MirLowering.foreign_field(t: (TypeBase | None)) -> bool {
    if not self.prog.options.native_unit {
        return False;
    }
    members = t.types if isinstance(t, UnionType) else [t];
    for member in members {
        if not isinstance(member, ClassType)
            or member._shared is None
            or not stub_scope(member.shared.symbol_table) {
            continue;
        }
        try {
            mir_type_of(member, MirPosition.FIELD);
        } except MirRefused {
            return True;
        }
    }
    return False;
}

impl MirLowering.erased_class(t: ClassType) -> bool {
    if not self.prog.options.native_unit or t._shared is None {
        return False;
    }
    scope = t.shared.symbol_table;
    if not isinstance(scope, uni.Archetype) or stub_archetype(scope) {
        return False;
    }
    known = self.erased_archs.get(id(scope));
    if known is not None {
        return known;
    }
    owner = scope.find_parent_of_type(uni.Module);
    erased = False;
    if owner is not None
        and owner is not self.module
        and owner.loc.mod_path.endswith(".jac")
        and self.dep_verdict(owner.loc.mod_path) is False {
        self.erased_units.add(owner.loc.mod_path);
        erased = True;
    }
    self.erased_archs[id(scope)] = erased;
    return erased;
}

impl MirLowering.note_erasures(t: (TypeBase | None)) {
    if not self.prog.options.native_unit {
        return;
    }
    if isinstance(t, TypeVarType) {
        bound = self.type_env.get(t.name);
        if bound is not None and bound is not t {
            self.note_erasures(bound);
        }
        return;
    }
    if isinstance(t, UnionType) {
        for member in t.types {
            self.note_erasures(member);
        }
        return;
    }
    if isinstance(t, FunctionType) {
        for param in t.parameters {
            self.note_erasures(param.param_type);
        }
        self.note_erasures(t.return_type);
        return;
    }
    if not isinstance(t, ClassType) or t._shared is None {
        return;
    }
    self.erased_class(t);
    if t.private and t.private.type_args {
        for arg in t.private.type_args {
            self.note_erasures(arg);
        }
    }
}

impl MirLowering.erased_slot(t: (TypeBase | None)) -> bool {
    if isinstance(t, TypeVarType) {
        return not t.is_self;
    }
    if isinstance(t, UnknownType) {
        return True;
    }
    if not isinstance(t, UnionType) {
        return False;
    }
    erased = False;
    for member in t.types {
        if (isinstance(member, TypeVarType) and not member.is_self)
            or isinstance(member, UnknownType) {
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

impl MirLowering.class_list_isinstance(value: MirValue, kinds: MirValue) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    held = self.spill(kinds);
    probe = self.spill(value);
    cursor = self.temp_slot(mir_int());
    found = self.temp_slot(mir_bool());
    b.store(cursor, b.const_int(0, mir_int()));
    b.store(found, b.const_bool(False));
    head = fn.new_block("isa.head");
    body = fn.new_block("isa.body");
    hit = fn.new_block("isa.hit");
    step = fn.new_block("isa.step");
    done = fn.new_block("isa.done");
    b.branch(head);
    b.position(head);
    at = b.load(cursor, mir_int());
    b.cond_branch(b.compare("lt", at, self.container_len(held)), body, done);
    b.position(body);
    kind = self.spill(self.list_read(held, b.load(cursor, mir_int())));
    b.cond_branch(self.class_isinstance(probe, kind), hit, step);
    b.position(hit);
    b.store(found, b.const_bool(True));
    b.branch(done);
    b.position(step);
    b.store(
        cursor, b.binary("add", b.load(cursor, mir_int()), b.const_int(1, mir_int()))
    );
    b.branch(head);
    b.position(done);
    return b.load(found, mir_bool());
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
    if value.type.kind == MirKind.OPT {
        (held, payload, absent, done) = self.opt_begin(value, mir_class("*"));
        self.opt_switch(held, self.class_of(payload, site), absent, done);
        return self.opt_end(
            held,
            self.emit_value(MirOp.CSTR, mir_class("*"), [], str_value="NoneType"),
            done
        );
    }
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

impl MirLowering.ctor_mask_words(
    params: list[tuple[str, MirType, (uni.Expr | None)]]
) -> int {
    defaulted = [
        index
        for (index, param) in enumerate(params)
        if param[2] is not None
    ];
    if not defaulted {
        return 0;
    }
    return max(defaulted) // CTOR_MASK_BITS + 1;
}

impl MirLowering.ctor_mask(
    mask: list[int], params: list[tuple[str, MirType, (uni.Expr | None)]]
) -> list[MirValue] {
    b = self.builder();
    return [
        b.const_int(mask[word] if word < len(mask) else 0, mir_int())
        for word in range(self.ctor_mask_words(params))
    ];
}

impl MirLowering.ctor_mask_set(mask: list[int], index: int) {
    word = index // CTOR_MASK_BITS;
    while len(mask) <= word {
        mask.append(0);
    }
    mask[word] = mask[word] | (1 << (index % CTOR_MASK_BITS));
}

impl MirLowering.ctor_given_bit(given: list[MirValue], index: int) -> MirValue {
    b = self.builder();
    return b.binary(
        "and",
        b.binary(
            "shr",
            given[index // CTOR_MASK_BITS],
            b.const_int(index % CTOR_MASK_BITS, mir_int())
        ),
        b.const_int(1, mir_int())
    );
}

impl MirLowering.ctor_default(
    value: MirValue, given: list[MirValue], index: int, fallback: uni.Expr
) -> MirValue {
    b = self.builder();
    fn = self.st().fn;
    held = self.temp_slot(value.type);
    bit = self.ctor_given_bit(given, index);
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
    nd: uni.FuncCall,
    label: str,
    params: list[tuple[str, MirType, (uni.Expr | None)]],
    leading: int = 0
) -> list[MirValue] {
    b = self.builder();
    fn = self.st().fn;
    positional: list[uni.Expr] = [];
    named: dict[str, uni.Expr] = {};
    spreads: list[MirValue] = [];
    for arg in list(nd.params or [])[leading:] {
        if isinstance(arg, uni.KWPair) {
            if arg.key is None {
                spread = self.spill(self.lower_expr(arg.value));
                if spread.type.kind != MirKind.DICT
                    or spread.type.args[0].kind not in (MirKind.STR, MirKind.STR_REF) {
                    raise MirRefused(
                        mir_refusal("call argument", "keyword unpacking", arg)
                    );
                }
                spreads.append(spread);
                continue;
            }
            named[arg.key.sym_name] = arg.value;
        } else {
            positional.append(arg);
        }
    }
    keyword_only = self.ctor_keyword_only.get(label, set());
    slots = [
        index
        for (index, param) in enumerate(params)
        if param[0] not in keyword_only
    ];
    if len(positional) > len(slots) {
        raise MirRefused(
            mir_refusal("call", f"{label} with {len(positional)} arguments", nd)
        );
    }
    shown = label.split("$")[0];
    values: list[MirValue] = [];
    mask: list[int] = [];
    dynamic_mask: dict[int, MirValue] = {};
    matched: (MirValue | None) = None;
    if spreads {
        matched = self.temp_slot(mir_int());
        b.store(matched, b.const_int(0, mir_int()));
    }
    for (index, (pname, ptype, fallback)) in enumerate(params) {
        at = slots.index(index) if pname not in keyword_only else len(positional);
        source = positional[at] if at < len(positional) else named.get(pname);
        if source is None and spreads and matched is not None {
            held = self.temp_slot(ptype);
            flag = self.temp_slot(mir_bool());
            b.store(flag, b.const_bool(False));
            for spread in spreads {
                key = spread.type.args[0];
                found = self.runtime_value(
                    "__jac_rt_dict_find",
                    [
                        spread,
                        self.to_bits(b.const_str(pname, mir_str()), key, nd),
                        b.const_int(self.elem_kind(key, nd), mir_int())
                    ]
                );
                hit = fn.new_block("ctor.kw.hit");
                miss = fn.new_block("ctor.kw.miss");
                b.cond_branch(
                    b.compare("ge", found, b.const_int(0, mir_int())), hit, miss
                );
                b.position(hit);
                self.raise_if(
                    b.load(flag, mir_bool()),
                    "TypeError",
                    f"{shown}() got multiple values for argument '{pname}'"
                );
                b.store(
                    held,
                    self.coerce(self.dict_entry_value(spread, found, nd), ptype, nd)
                );
                b.store(flag, b.const_bool(True));
                b.store(
                    matched,
                    b.binary(
                        "add", b.load(matched, mir_int()), b.const_int(1, mir_int())
                    )
                );
                b.branch(miss);
                b.position(miss);
            }
            given = b.load(flag, mir_bool());
            if fallback is None {
                self.raise_if(
                    b.logical_not(given),
                    "TypeError",
                    f"{shown}() missing required argument: '{pname}'"
                );
            } else {
                absent = fn.new_block("ctor.kw.default");
                done = fn.new_block("ctor.kw.done");
                b.cond_branch(given, done, absent);
                b.position(absent);
                b.store(held, self.placeholder(ptype));
                b.branch(done);
                b.position(done);
                word = index // CTOR_MASK_BITS;
                bit = b.select(
                    b.load(flag, mir_bool()),
                    b.const_int(1 << (index % CTOR_MASK_BITS), mir_int()),
                    b.const_int(0, mir_int())
                );
                dynamic_mask[word] = bit
                    if word not in dynamic_mask
                    else b.binary("or", dynamic_mask[word], bit);
            }
            values.append(b.load(held, ptype));
            continue;
        }
        if source is None and fallback is not None {
            values.append(self.placeholder(ptype));
            continue;
        }
        if fallback is not None {
            self.ctor_mask_set(mask, index);
        }
        if source is None {
            raise MirRefused(mir_refusal("call", f"{label} missing {pname}", nd));
        }
        values.append(self.coerce(self.lower_expr(source), ptype, source));
    }
    if spreads and matched is not None {
        total = b.const_int(0, mir_int());
        for spread in spreads {
            total = b.binary("add", total, self.container_len(spread));
        }
        self.raise_if(
            b.compare("ne", total, b.load(matched, mir_int())),
            "TypeError",
            f"{shown}() got an unexpected keyword argument"
        );
    }
    for (word, made) in enumerate(self.ctor_mask(mask, params)) {
        if word in dynamic_mask {
            made = b.binary("or", made, dynamic_mask[word]);
        }
        values.append(made);
    }
    return values;
}

impl MirLowering.class_value_call(
    nd: uni.FuncCall,
    bound: uni.Archetype,
    source: (uni.Expr | None) = None,
    leading: int = 0
) -> MirValue {
    b = self.builder();
    obj_def = self.object_def(bound);
    kind = self.lower_expr(source if source is not None else nd.target);
    params = self.constructor_params(bound);
    values = self.ctor_arguments(nd, obj_def.name, params, leading);
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
    if self.owned_world {
        b.block.instrs[-1].consumes = [
            index + 1
            for (index, (pname, ptype, _)) in enumerate(params)
            if mir_holds_ref(ptype) and self.field_consumes(bound, pname)
        ];
    }
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
            if self.owned_world
                and mir_holds_ref(ptype)
                and self.field_consumes(bound, pname) {
                value.owned = True;
            }
            given.append(value);
        }
        supplied: list[MirValue] = [];
        for word in range(self.ctor_mask_words(taken)) {
            held = fn.new_value(mir_int(), f"__given{word}");
            fn.params.append(MirParam(name=f"__given{word}", value=held));
            supplied.append(held);
        }
        args: list[MirValue] = [];
        mask = self.ctor_mask([], accepts);
        for (index, (pname, ptype, fallback)) in enumerate(accepts) {
            if pname not in names {
                args.append(self.placeholder(ptype));
                continue;
            }
            at = names.index(pname);
            args.append(self.coerce(given[at], ptype, arch));
            word = index // CTOR_MASK_BITS;
            if taken[at][2] is None {
                if fallback is not None {
                    mask[word] = b.binary(
                        "or",
                        mask[word],
                        b.const_int(1 << (index % CTOR_MASK_BITS), mir_int())
                    );
                }
                continue;
            }
            bit = self.ctor_given_bit(supplied, at);
            if fallback is None {
                self.raise_if(
                    b.compare("eq", bit, b.const_int(0, mir_int())),
                    "TypeError",
                    f"{obj_def.name.split('$')[0]}() missing required argument: '{pname}'"
                );
            } else {
                mask[word] = b.binary(
                    "or",
                    mask[word],
                    b.binary("shl", bit, b.const_int(index % CTOR_MASK_BITS, mir_int()))
                );
            }
        }
        args.extend(mask);
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

impl MirLowering.default_entry(arch: uni.Archetype) -> (MirFunction | None) {
    obj_def = self.object_def(arch);
    params = self.constructor_params(arch);
    if any(fallback is None for (_, _, fallback) in params) {
        return None;
    }
    owner = arch.find_parent_of_type(uni.Module) or self.module;
    prefix = native_unit_prefix(owner.loc.mod_path);
    symbol = native_symbol_name(prefix, f"{obj_def.name}.__new_default");
    fn = MirFunction(
        name=f"{obj_def.name}.__new_default",
        symbol=symbol,
        ret=mir_obj(obj_def.name),
        linkage="internal"
    );
    first = fn.new_block("entry");
    saved = self.state;
    self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
    try {
        b = self.builder();
        args = [self.placeholder(ptype) for (_, ptype, _) in params];
        args.extend(self.ctor_mask([], params));
        made = b.call(
            native_symbol_name(prefix, f"{obj_def.name}.__ctor"),
            args,
            mir_obj(obj_def.name)
        );
        if made is None {
            raise MirRefused(mir_refusal("constructor", obj_def.name, arch));
        }
        b.ret(made);
    } except MirRefused as err {
        self.state = saved;
        return None;
    }
    self.state = saved;
    self.default_entries.append((obj_def.name, symbol));
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

impl MirLowering.default_thunk(expr: uni.Expr) -> (tuple[str, str, MirType] | None) {
    holder = self.default_holder(expr);
    if isinstance(holder, uni.HasVar) and holder.name is not None {
        arch = self.owner_archetype(holder);
        if arch is None {
            return None;
        }
        member = self.object_def(arch).field(holder.name.value);
        if member is None {
            return None;
        }
        return (
            f"{self.object_def(arch).name}.",
            f"__default.{holder.name.value}",
            member.type
        );
    }
    if isinstance(holder, uni.ParamVar) {
        ability = holder.enclosing_decl(uni.Ability);
        arch = self.owner_archetype(ability) if ability is not None else None;
        if ability is None {
            return None;
        }
        owner = f"{self.object_def(arch).name}." if arch is not None else "";
        return (
            owner,
            f"__default.{self.name_of(ability)}.{holder.name.value}",
            self.symbol_type(holder.name.sym, holder)
        );
    }
    return None;
}

impl MirLowering.default_value(expr: uni.Expr, to: MirType) -> MirValue {
    origin = expr.find_parent_of_type(uni.Module);
    if origin is None or origin is self.module {
        return self.field_expr_value(expr, to);
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
    (owner, label, made_type) = found;
    symbol = native_symbol_name(
        native_unit_prefix(origin.loc.mod_path), f"{owner}{label}"
    );
    self.mir.externs[symbol] = MirExtern(symbol=symbol, ret=made_type, params=[]);
    made = self.builder().call(symbol, [], made_type);
    if made is None {
        raise MirRefused(mir_refusal("default", label, expr));
    }
    return self.coerce(made, to, expr);
}

impl MirLowering.field_default_of(var: uni.HasVar) -> (uni.Expr | None) {
    initialization = field_initialization(var);
    if initialization.factory_expr is not None {
        return initialization.factory_expr;
    }
    return initialization.default_expr;
}

impl MirLowering.default_holder(expr: uni.Expr) -> (uni.UniNode | None) {
    holder = expr.parent;
    if isinstance(holder, uni.KWPair)
        and isinstance(holder.parent, uni.FuncCall)
        and isinstance(holder.parent.parent, uni.HasVar)
        and self.field_default_of(holder.parent.parent) is expr {
        return holder.parent.parent;
    }
    return holder;
}

impl MirLowering.is_field_factory(expr: uni.Expr) -> bool {
    holder = self.default_holder(expr);
    return isinstance(holder, uni.HasVar)
        and holder is not expr.parent
        and field_initialization(holder).factory_expr is expr;
}

impl MirLowering.field_expr_value(expr: uni.Expr, to: MirType) -> MirValue {
    if self.is_field_factory(expr) {
        return self.field_factory_value(expr, to);
    }
    return self.coerce(self.lower_expr(expr), to, expr);
}

impl MirLowering.field_factory_value(factory: uni.Expr, to: MirType) -> MirValue {
    made = factory.type;
    if isinstance(made, ClassType) and not made.is_instance() {
        kind = made.shared.class_name;
        if kind == "list" and to.kind == MirKind.LIST {
            return self.new_list(to.payload(), 0);
        }
        if kind == "dict" and to.kind == MirKind.DICT {
            return self.new_dict(to.args[0], to.args[1], to);
        }
        if kind == "set" and to.kind == MirKind.SET {
            return self.new_dict(to.payload(), None, to);
        }
    }
    target = named_function_of(factory);
    marker = factory.parent.parent if factory.parent is not None else None;
    if isinstance(target, uni.Ability)
        and isinstance(target.signature, uni.FuncSignature)
        and target.signature.varargs is None
        and target.signature.kwargs is None
        and isinstance(marker, uni.FuncCall) {
        decl = self.decls.get(id(target));
        if decl is None
            and isinstance(target.parent, uni.Module)
            and target.loc.mod_path.endswith(".jac") {
            decl = self.foreign_function_decl(target, factory);
        }
        if decl is not None and decl.self_type is None {
            sig = target.signature;
            bound: list[any] = [
                self.bind_by_name(target, pv, {}, True, marker)
                for pv in list(sig.posonly_params)
                    + list(sig.params or [])
                    + list(sig.kwonlyargs or [])
            ];
            if len(bound) == len(decl.params) {
                result = self.builder().call(
                    decl.symbol, self.bound_values(bound, decl.params), decl.ret
                );
                if result is not None {
                    return self.coerce(result, to, factory);
                }
            }
        }
    }
    raise MirRefused(
        mir_refusal(
            "field",
            "default_factory",
            factory,
            "A native field factory is list, dict, set or a function called with no arguments."
        )
    );
}

impl MirLowering.default_thunks(arch: uni.Archetype) -> list[MirFunction] {
    defaults: list[uni.Expr] = [];
    for var in arch.get_has_vars() {
        initial = self.field_default_of(var);
        if isinstance(initial, uni.Expr) {
            defaults.append(initial);
        }
    }
    for method in self.arch_methods(arch) {
        if not isinstance(method.signature, uni.FuncSignature) {
            continue;
        }
        is_init = self.name_of(method) in ("init", "__init__");
        for pv in list(method.signature.posonly_params)
            + list(method.signature.params or [])
            + list(method.signature.kwonlyargs or []) {
            if isinstance(pv.value, uni.Expr)
                and (is_init or not self.literal_default(pv.value)) {
                defaults.append(pv.value);
            }
        }
    }
    return self.make_default_thunks(defaults);
}

impl MirLowering.function_default_thunks -> list[MirFunction] {
    defaults: list[uni.Expr] = [];
    owners: list[uni.Ability] = list(self.module_abilities());
    for elem in self.module.body {
        if isinstance(elem, uni.Import) and elem.clib_decls {
            for decl in elem.clib_decls {
                if isinstance(decl, uni.Ability) and decl not in owners {
                    owners.append(decl);
                }
            }
        }
    }
    for ab in owners {
        sig = ab.signature;
        if not isinstance(sig, uni.FuncSignature) or id(ab) in self.templates {
            continue;
        }
        for pv in list(sig.posonly_params)
            + list(sig.params or [])
            + list(sig.kwonlyargs or []) {
            if isinstance(pv.value, uni.Expr) and not self.literal_default(pv.value) {
                defaults.append(pv.value);
            }
        }
    }
    return self.make_default_thunks(defaults);
}

impl MirLowering.make_default_thunks(defaults: list[uni.Expr]) -> list[MirFunction] {
    made: list[MirFunction] = [];
    prefix = native_unit_prefix(self.module.loc.mod_path);
    for expr in defaults {
        saved = self.state;
        try {
            found = self.default_thunk(expr);
            if found is None {
                continue;
            }
            (owner, label, made_type) = found;
            fn = MirFunction(
                name=f"{owner}{label}",
                symbol=native_symbol_name(prefix, f"{owner}{label}"),
                ret=made_type
            );
            first = fn.new_block("entry");
            self.state = MirFnState(fn=fn, b=MirBuilder(fn=fn, block=first));
            self.builder().ret(self.field_expr_value(expr, made_type));
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

impl MirLowering.refusal_key(decl: MirDecl) -> str {
    return decl.symbol;
}

impl MirLowering.member_owner(member: uni.Name) -> (uni.Archetype | None) {
    sym = member.sym;
    if sym is None or sym.decl is None {
        return None;
    }
    return self.owner_archetype(sym.decl);
}

impl MirLowering.union_method_owner(
    nd: uni.FuncCall, receiver: uni.Expr
) -> (uni.Archetype | None) {
    callee = nd.callee_decl;
    if not isinstance(callee, uni.Ability) or callee.is_static {
        return None;
    }
    owner = self.owner_archetype(callee);
    seen = receiver.narrowed_type
        if receiver.narrowed_type is not None
        else receiver.type;
    members = self.union_archetypes(seen);
    if owner is None or not members {
        return None;
    }
    base = archetype_native_name(owner);
    for member in members {
        name = archetype_native_name(member);
        if name != base and not self.obj_extends(name, base) {
            return None;
        }
    }
    return owner;
}

impl MirLowering.is_class_operand(nd: (uni.UniNode | None)) -> bool {
    return isinstance(nd, uni.Expr)
        and isinstance(nd.type, ClassType)
        and not nd.type.is_instance();
}

impl MirLowering.union_archetypes(t: (TypeBase | None)) -> list[uni.Archetype] {
    t = self.resolved(t);
    if not isinstance(t, UnionType) {
        return [];
    }
    found: list[uni.Archetype] = [];
    for member in t.types {
        arch = self.arch_of_type(member);
        if arch is None {
            return [];
        }
        found.append(arch);
    }
    return found;
}

impl MirLowering.union_field_place(
    holder: MirValue, members: list[uni.Archetype], name: str, site: uni.UniNode
) -> MirValue {
    b = self.builder();
    if holder.type.kind == MirKind.OPT {
        holder = self.opt_unwrap_checked(
            holder, f"'NoneType' object has no attribute '{name}'", "AttributeError"
        );
    }
    held = self.spill(holder);
    places: list[tuple[MirValue, MirValue]] = [];
    for arch in members {
        wanted = self.object_type(arch);
        view = held;
        if held.type is not wanted {
            if held.type.kind != MirKind.ANY
                and (
                    held.type.kind != MirKind.OBJ
                    or not self.obj_extends(wanted.name, held.type.name)
                ) {
                raise MirRefused(
                    mir_refusal(
                        "attribute access", f"{name} on {held.type.render()}", site
                    )
                );
            }
            view = b.ref_cast(held, wanted, False);
        }
        verdict = self.member_test(held, view, arch, site);
        places.append((verdict, self.field_place(view, arch, name, site)));
    }
    chosen = places[-1][1];
    for (verdict, place) in reversed(places[:-1]) {
        if place.type is not chosen.type {
            raise MirRefused(
                mir_refusal("attribute access", f"{name} of differing types", site)
            );
        }
        chosen = b.select(verdict, place, chosen);
    }
    return chosen;
}

impl MirLowering.union_field_read(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not nd.is_attr
        or not isinstance(nd.right, uni.Name)
        or not isinstance(nd.target, uni.Expr) {
        return None;
    }
    members = self.union_archetypes(nd.target.narrowed_type or nd.target.type);
    if not members {
        return None;
    }
    name = nd.right.value;
    kinds: list[MirType] = [];
    for arch in members {
        member = self.object_def(arch).field(name);
        if member is None {
            return None;
        }
        kinds.append(member.type);
    }
    if all(kind is kinds[0] for kind in kinds) {
        return None;
    }
    wanted = self.expr_type(nd);
    b = self.builder();
    fn = self.st().fn;
    holder = self.lower_expr(nd.target);
    if holder.type.kind == MirKind.OPT {
        holder = self.opt_unwrap_checked(
            holder, f"'NoneType' object has no attribute '{name}'", "AttributeError"
        );
    }
    held = self.spill(holder);
    result = self.temp_slot(wanted);
    done = fn.new_block("ufield.done");
    for arch in members {
        target = self.object_type(arch);
        view = held if held.type is target else b.ref_cast(held, target, False);
        here = fn.new_block("ufield.here");
        next_bb = fn.new_block("ufield.next");
        b.cond_branch(self.member_test(held, view, arch, nd), here, next_bb);
        b.position(here);
        place = self.field_place(view, arch, name, nd);
        b.store(result, self.coerce(b.load(place, self.place_elem(place)), wanted, nd));
        b.branch(done);
        b.position(next_bb);
    }
    b.raise_builtin("AttributeError", f"object has no attribute '{name}'");
    b.position(done);
    return b.load(result, wanted);
}

impl MirLowering.accessor_of(
    nd: uni.AtomTrailer, kind: str
) -> (tuple[uni.Archetype, MirDecl] | None) {
    if not nd.is_attr
        or not isinstance(nd.right, uni.Name)
        or not isinstance(nd.target, uni.Expr) {
        return None;
    }
    arch = self.holder_arch(nd.target);
    if arch is None {
        return None;
    }
    return self.accessor_on(arch, nd.right.value, kind, nd);
}

impl MirLowering.accessor_on(
    arch: uni.Archetype, name: str, kind: str, nd: uni.UniNode
) -> (tuple[uni.Archetype, MirDecl] | None) {
    var = self.nearest_has_var(arch, name);
    if var is None or not var.accessors {
        return None;
    }
    label = f"{archetype_native_name(arch)}.{name}";
    for acc in var.accessors {
        if acc.accessor_kind == kind {
            decl = self.decls.get(id(acc)) or self.foreign_accessor_decl(var, acc);
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

impl MirLowering.union_accessor_get(nd: uni.AtomTrailer) -> (MirValue | None) {
    if not nd.is_attr
        or not isinstance(nd.right, uni.Name)
        or not isinstance(nd.target, uni.Expr) {
        return None;
    }
    seen = nd.target.narrowed_type
        if nd.target.narrowed_type is not None
        else nd.target.type;
    members = self.union_archetypes(seen);
    if not members {
        return None;
    }
    found = [
        self.accessor_on(arch, nd.right.value, "property", nd) for arch in members
    ];
    fielded = [
        self.object_def(arch).field(nd.right.value) is not None for arch in members
    ];
    if all(one is None for one in found) and all(fielded) {
        return None;
    }
    b = self.builder();
    fn = self.st().fn;
    held = self.spill(self.lower_expr(nd.target));
    wanted = self.expr_type(nd);
    result = self.temp_slot(wanted);
    done = fn.new_block("uacc.done");
    for (index, arch) in enumerate(members) {
        bound = found[index];
        view = held
            if held.type is self.object_type(arch)
            else b.ref_cast(held, self.object_type(arch), False);
        miss: (MirBlock | None) = None;
        if index < len(members) - 1 {
            hit = fn.new_block("uacc.hit");
            miss = fn.new_block("uacc.miss");
            b.cond_branch(self.member_test(held, view, arch, nd), hit, miss);
            b.position(hit);
        }
        made: MirValue = view;
        if bound is None and not fielded[index] {
            b.raise_builtin(
                "AttributeError",
                f"'{archetype_native_name(arch).split('$')[
                    0
                ]}' object has no attribute '{nd.right.value}'"
            );
            if miss is not None {
                b.position(miss);
            }
            continue;
        }
        if bound is None {
            place = self.field_place(view, arch, nd.right.value, nd);
            made = b.load(place, self.place_elem(place));
        } else {
            (owner, decl) = bound;
            made = self.invoke_method(
                decl,
                owner,
                self.decl_label(decl),
                [self.method_receiver(decl, owner, view, nd)]
            );
        }
        b.store(result, self.coerce(made, wanted, nd));
        b.branch(done);
        if miss is not None {
            b.position(miss);
        }
    }
    b.position(done);
    return b.load(result, wanted);
}

impl MirLowering.accessor_get(nd: uni.AtomTrailer) -> (MirValue | None) {
    found = self.accessor_of(nd, "property");
    if found is None {
        return self.union_accessor_get(nd);
    }
    (arch, decl) = found;
    receiver = self.method_receiver(decl, arch, self.lower_expr(nd.target), nd);
    return self.invoke_method(decl, arch, self.decl_label(decl), [receiver]);
}

impl MirLowering.union_accessor_set(
    target: uni.AtomTrailer, nd: uni.Assignment
) -> bool {
    if not target.is_attr
        or nd.aug_op is not None
        or nd.value is None
        or not isinstance(target.right, uni.Name)
        or not isinstance(target.target, uni.Expr) {
        return False;
    }
    name = target.right.value;
    seen = target.target.narrowed_type
        if target.target.narrowed_type is not None
        else target.target.type;
    members = self.union_archetypes(seen);
    if not members {
        return False;
    }
    found = [self.accessor_on(arch, name, "setter", target) for arch in members];
    fielded = [self.object_def(arch).field(name) is not None for arch in members];
    if all(one is None for one in found) and all(fielded) {
        return False;
    }
    b = self.builder();
    fn = self.st().fn;
    held = self.spill(self.lower_expr(target.target));
    value = self.spill(self.lower_expr(nd.value));
    done = fn.new_block("uset.done");
    for (index, arch) in enumerate(members) {
        bound = found[index];
        view = held
            if held.type is self.object_type(arch)
            else b.ref_cast(held, self.object_type(arch), False);
        miss: (MirBlock | None) = None;
        if index < len(members) - 1 {
            hit = fn.new_block("uset.hit");
            miss = fn.new_block("uset.miss");
            b.cond_branch(self.member_test(held, view, arch, target), hit, miss);
            b.position(hit);
        }
        if bound is not None {
            (owner, decl) = bound;
            self.invoke_method(
                decl,
                owner,
                self.decl_label(decl),
                [
                    self.method_receiver(decl, owner, view, target),
                    self.coerce(value, decl.params[0], nd)
                ]
            );
            b.branch(done);
        } elif fielded[index] {
            place = self.field_place(view, arch, name, target);
            b.store(place, self.coerce(value, self.place_elem(place), nd));
            b.branch(done);
        } else {
            b.raise_builtin(
                "AttributeError",
                f"'{archetype_native_name(arch).split('$')[
                    0
                ]}' object has no attribute '{name}'"
            );
        }
        if miss is not None {
            b.position(miss);
        }
    }
    b.position(done);
    return True;
}

impl MirLowering.accessor_store(target: uni.AtomTrailer, value: MirValue) -> bool {
    found = self.accessor_of(target, "setter");
    if found is None {
        return False;
    }
    (arch, decl) = found;
    holder = self.spill(self.lower_expr(target.target));
    self.invoke_method(
        decl,
        arch,
        self.decl_label(decl),
        [
            self.method_receiver(decl, arch, holder, target),
            self.coerce(value, decl.params[0], target)
        ]
    );
    return True;
}

impl MirLowering.accessor_set(target: uni.AtomTrailer, nd: uni.Assignment) -> bool {
    if nd.value is None {
        return False;
    }
    found = self.accessor_of(target, "setter");
    if found is None {
        return self.union_accessor_set(target, nd);
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
            else self.aug_arith(op, current, value, nd);
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
