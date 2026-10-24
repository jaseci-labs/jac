impl LayoutPass.postinit -> None {
    self.registry = LayoutRegistry();
    self.isinstance_targets = set();
}

impl LayoutPass._run_impl(ir_in: Module) -> Module {
    module = self.module;

    self._type_declaration_surface(module);
    self._build_enum_layouts(module);

    arch_map = self._collect_archetypes(module);
    if not arch_map {
        module.gen.layout_registry = self.registry;
        return ir_in;
    }

    self._build_hierarchy(arch_map);
    self._collect_isinstance_targets(module);

    topo_order = self._topo_sort(arch_map);
    self.registry.topo_order = topo_order;

    for name in topo_order {
        if name in arch_map {
            layout = self._build_layout(arch_map[name]);
            self.registry.layouts[name] = layout;
            self.registry.local_names.append(name);
        }
    }

    for name in topo_order {
        if name in arch_map {
            self._build_vtable_layout(name, arch_map);
        }
    }

    self._compute_acyclicity();

    for name in topo_order {
        if name in arch_map {
            self._validate_obj_fields(arch_map[name], arch_map);
        }
    }

    module.gen.layout_registry = self.registry;
    return ir_in;
}

impl LayoutPass._type_declaration_surface(module: Module) -> None {
    annotations: list[Expr] = [];
    for typed in module.get_all_sub_nodes(HasVar)
        + module.get_all_sub_nodes(ParamVar) {
        if typed.type_tag is not None {
            annotations.append(typed.type_tag.tag);
        }
    }
    for sig in module.get_all_sub_nodes(FuncSignature) {
        if sig.return_type is not None {
            annotations.append(sig.return_type);
        }
    }
    for decl in module.get_all_sub_nodes(GlobalVars) {
        for assign in decl.assignments {
            if assign.type_tag is not None {
                annotations.append(assign.type_tag.tag);
            }
        }
    }
    evaluator = self.prog.get_type_evaluator();
    for annotation in annotations {
        for nd in reversed(annotation.flatten()) {
            if isinstance(nd, Expr) and nd.type is None {
                try {
                    evaluator.get_type_of_expression(nd);
                } except Exception {}
            }
        }
    }
}

impl LayoutPass._collect_archetypes(module: Module) -> dict[str, Archetype] {
    arch_map: dict[str, Archetype] = {};
    for nd in module.get_all_sub_nodes(Archetype) {
        if nd.name is None {
            continue;
        }
        aname = archetype_native_name(nd);

        if aname not in arch_map or nd.body is not None {
            arch_map[aname] = nd;
        }
    }
    return arch_map;
}

impl LayoutPass._collect_isinstance_targets(module: Module) -> None {
    for call in module.get_all_sub_nodes(FuncCall) {
        tgt = call.target;
        if not (isinstance(tgt, Name) and tgt.value == "isinstance") {
            continue;
        }
        params: list[Expr | KWPair] = list(call.params or []);
        if len(params) < 2 {
            continue;
        }
        type_arg = params[1];
        cands: list[Expr | KWPair] = [];
        if isinstance(type_arg, TupleVal) {
            for v in (type_arg.values or []) {
                cands.append(v);
            }
        } else {
            cands.append(type_arg);
        }
        for c in cands {
            if isinstance(c, Name) {
                self.isinstance_targets.add(referenced_native_name(c) or c.value);
            }
        }
    }
}

impl LayoutPass._build_hierarchy(archetypes: dict[str, Archetype]) -> None {
    reg = self.registry;

    for (aname, arch) in archetypes.items() {
        if arch.base_classes {
            parents: list[str] = [];
            parent_mods: list[str] = [];
            for base_expr in arch.base_classes {
                pname: (str | None) = None;
                if isinstance(base_expr, Name) {
                    pname = base_expr.value;
                } elif isinstance(base_expr, AstSymbolNode) {
                    pname = base_expr.sym_name;
                }
                parent = referenced_native_name(base_expr);
                if parent is None {
                    if pname is None or is_erased_base_name(pname, archetypes) {
                        continue;
                    }
                    parent = pname;
                }
                parents.append(parent);
                parent_mods.append(declaring_module_path(base_expr));
            }
            if parents {
                reg.class_parents[aname] = parents;
                reg.parent_mods[aname] = parent_mods;
            }
        }
    }

    for aname in archetypes {
        if aname not in reg.mro_order {
            reg.set_mro(aname, self._compute_c3_mro(aname));
        }
    }
}

impl LayoutPass._compute_c3_mro(class_name: str) -> list[str] {
    reg = self.registry;

    parents = reg.class_parents.get(class_name);
    if parents is None or not parents {
        return [class_name];
    }

    parent_mros: list[list[str]] = [];
    for p in parents {
        if p not in reg.mro_order {
            reg.set_mro(p, self._compute_c3_mro(p));
        }
        parent_mros.append(list(reg.mro_order[p]));
    }

    parent_mros.append(list(parents));

    result: list[str] = [class_name];
    while True {
        any_remaining = False;
        for mro_list in parent_mros {
            if len(mro_list) > 0 {
                any_remaining = True;
                break;
            }
        }
        if not any_remaining {
            break;
        }

        candidate: (str | None) = None;
        for mro_list in parent_mros {
            if len(mro_list) == 0 {
                continue;
            }
            head = mro_list[0];

            in_tail = False;
            for other_list in parent_mros {
                if len(other_list) > 1 and head in other_list[1:] {
                    in_tail = True;
                    break;
                }
            }
            if not in_tail {
                candidate = head;
                break;
            }
        }
        if candidate is None {
            self.ctx.emit(E5030, name=class_name);
            return result;
        }
        result.append(candidate);

        new_parent_mros: list[list[str]] = [];
        for mro_list in parent_mros {
            if len(mro_list) > 0 and mro_list[0] == candidate {
                mro_list.pop(0);
            }
            new_parent_mros.append(mro_list);
        }
        parent_mros = new_parent_mros;
    }
    return result;
}

impl LayoutPass._topo_sort(arch_map: dict[str, Archetype]) -> list[str] {
    return self.registry.dependency_order(list(arch_map));
}

impl LayoutRegistry.dependency_order(names: list[str]) -> list[str] {
    """Order layouts after their ancestors, including incomplete imported MROs.""";
    visited: set[str] = set();
    order: list[str] = [];

    for aname in names {
        if aname in visited {
            continue;
        }
        stack: list[tuple[str, bool]] = [(aname, False)];
        while stack {
            (name, processed) = stack.pop();
            if name in visited {
                continue;
            }
            if processed {
                visited.add(name);
                order.append(name);
                continue;
            }
            stack.append((name, True));
            mro = self.mro_order.get(name, [name]);
            for ancestor in reversed(mro[1:]) {
                if ancestor not in visited {
                    stack.append((ancestor, False));
                }
            }
        }
    }
    return order;
}

impl LayoutPass._build_layout(arch: Archetype) -> ArchetypeLayout {
    """Assign header and field slots with stable dispatch requirements.

    Abstract interfaces reserve a vtable even when their implementations live
    in other modules, and so does every class other modules can subclass
    whose own methods they could override (`open_dispatch`). Local parents,
    isinstance targets, and OSP archetypes likewise require dispatch. A concrete class may initially acquire a slot
    merely because it declares a base; imported-base adoption can remove that
    provisional slot when neither the class nor its ancestors need dispatch,
    or when an isinstance test is its only use and the build's allocation
    header carries the class identity instead.
    """;
    reg = self.registry;
    aname = archetype_native_name(arch);
    mro = reg.mro_order.get(aname, [aname]);
    parents = reg.class_parents.get(aname, []);

    arch_type_str = arch.arch_kind or "object";
    is_osp = arch.arch_kind is not None;

    parents_set: set[str] = set();
    for (_, plist) in reg.class_parents.items() {
        for p in plist {
            parents_set.add(p);
        }
    }

    by_hierarchy = (
        is_osp or arch.is_abstract or aname in parents_set or open_dispatch(arch)
    );
    vtable_by_dispatch = by_hierarchy or aname in self.isinstance_targets;
    needs_vtable = bool(parents) or vtable_by_dispatch;
    vtable_by_isinstance_only = aname in self.isinstance_targets and not by_hierarchy;

    fields: list[FieldLayout] = [];
    field_index: dict[str, int] = {};
    parent_field_start: dict[str, int] = {};
    seen_fields: set[str] = set();
    current_idx = 0;

    vtable_ptr_slot: (int | None) = None;
    type_tag_slot: (int | None) = None;
    reports_slot: (int | None) = None;
    if needs_vtable or is_osp {
        vtable_ptr_slot = current_idx;
        current_idx += 1;
    }
    if is_osp {
        type_tag_slot = current_idx;
        current_idx += 1;
    }
    if arch_type_str == "walker" {
        reports_slot = current_idx;
        field_index["reports"] = current_idx;
        seen_fields.add("reports");
        current_idx += 1;
    }

    for ancestor_name in mro[1:] {
        ancestor_layout = reg.layouts.get(ancestor_name);
        if ancestor_layout is None {
            continue;
        }
        parent_field_start[ancestor_name] = current_idx;

        for finfo in ancestor_layout.fields {
            if finfo.name in seen_fields {
                continue;
            }
            seen_fields.add(finfo.name);
            new_field = FieldLayout(
                name=finfo.name,
                index=current_idx,
                type_tag=finfo.type_tag,
                type_node=finfo.type_node,
                default_expr=finfo.default_expr,
                owner=finfo.owner,
                is_func_ptr=finfo.is_func_ptr,
                decl_node=finfo.decl_node
            );
            fields.append(new_field);
            field_index[finfo.name] = current_idx;
            current_idx += 1;
        }
    }

    if EXC_MESSAGE_FIELD not in seen_fields
        and any(JAC_TYPE_REGISTRY.is_exception(p) for p in parents) {
        seen_fields.add(EXC_MESSAGE_FIELD);
        fields.append(
            FieldLayout(
                name=EXC_MESSAGE_FIELD, index=current_idx, type_tag="str", owner=aname
            )
        );
        field_index[EXC_MESSAGE_FIELD] = current_idx;
        current_idx += 1;
    }

    for var in arch.get_has_vars() {
        fname = var.name.value if var.name else "field";
        if fname in seen_fields {
            continue;
        }

        if var.accessors {
            continue;
        }

        _archhas = var.find_parent_of_type(ArchHas);
        if _archhas is not None and _archhas.is_static {
            continue;
        }
        seen_fields.add(fname);
        type_tag = "";
        type_node: (UniNode | None) = None;
        if var.type_tag and var.type_tag.tag {
            type_node = var.type_tag.tag;
            type_tag = unparse_node(type_node) or str(type_node);
        }
        is_fn_ptr = type_node is not None and isinstance(type_node, FuncSignature);
        new_field = FieldLayout(
            name=fname,
            index=current_idx,
            type_tag=type_tag,
            type_node=type_node,
            default_expr=var.value,
            owner=aname,
            is_func_ptr=is_fn_ptr,
            decl_node=var
        );
        fields.append(new_field);
        field_index[fname] = current_idx;
        current_idx += 1;
    }

    for tp in (arch.type_params or []) {
        if not tp.is_comptime {
            continue;
        }
        pname = tp.name.value;
        if pname in seen_fields {
            continue;
        }
        seen_fields.add(pname);
        tnode = tp.bound;
        ptag = (unparse_node(tnode) or str(tnode)) if tnode is not None else "int";
        fields.append(
            FieldLayout(
                name=pname,
                index=current_idx,
                type_tag=ptag,
                type_node=tnode,
                default_expr=None,
                owner=aname,
                is_func_ptr=False,
                decl_node=tp
            )
        );
        field_index[pname] = current_idx;
        current_idx += 1;
    }

    import os as _lay_os;
    _decl_mod = arch.find_parent_of_type(Module);
    _decl_path = _decl_mod.loc.mod_path if _decl_mod is not None else None;
    return ArchetypeLayout(
        name=aname,
        arch_type=arch_type_str,
        decl_mod=(_lay_os.path.realpath(_decl_path) if _decl_path else ""),
        parent_mods=list(reg.parent_mods.get(aname, [])),
        parents=parents,
        mro=mro,
        fields=fields,
        field_index=field_index,
        has_vtable=needs_vtable,
        vtable_by_dispatch=vtable_by_dispatch,
        vtable_by_isinstance_only=vtable_by_isinstance_only,
        parent_field_start=parent_field_start,
        is_osp=is_osp,
        vtable_ptr_slot=vtable_ptr_slot,
        type_tag_slot=type_tag_slot,
        reports_slot=reports_slot
    );
}

impl LayoutPass._build_enum_layouts(module: Module) -> None {
    for nd in module.get_all_sub_nodes(Enum) {
        ename = nd.name.value if nd.name else None;
        body = ModuleFacts.unwrap_body(nd);
        if ename is None or ename in self.registry.enums or body is None {
            continue;
        }
        raw_members: list[tuple[(str, (UniNode | None))]] = [];
        for stmt in body {
            if isinstance(stmt, Assignment) {
                targets = stmt.target
                    if isinstance(stmt.target, (list, tuple))
                    else [stmt.target];
                for target_expr in targets {
                    if isinstance(target_expr, Name) {
                        raw_members.append((target_expr.value, stmt.value));
                    }
                }
            }
        }

        member_values: list[(str | int | None)] = resolve_enum_member_values(
            raw_members
        );
        is_string_enum = False;
        for mval in member_values {
            if isinstance(mval, str) {
                is_string_enum = True;
                break;
            }
        }
        members: list[EnumMemberLayout] = [];
        for (ordinal, member) in enumerate(raw_members) {
            mname: str = member[0];
            str_value: (str | None) = None;
            int_value = 0;
            mval = member_values[ordinal];
            if is_string_enum {
                str_value = mval if isinstance(mval, str) else "";
            } else {
                int_value = mval if isinstance(mval, int) else 0;
            }
            members.append(
                EnumMemberLayout(
                    name=mname,
                    ordinal=ordinal,
                    int_value=int_value,
                    str_value=str_value
                )
            );
        }
        self.registry.enums[ename] = EnumLayout(
            name=ename,
            is_string_enum=is_string_enum,
            all_values_known=all(mval is not None for mval in member_values),
            members=members
        );
    }
    for nd in class_form_enum_decls(module) {
        ename = nd.name.value;
        if ename in self.registry.enums {
            continue;
        }
        _scalar = class_form_enum_scalar(nd.name.type);
        _cf_raw = class_form_enum_members(nd);
        _cf_values = resolve_enum_member_values(_cf_raw);
        _cf_members: list[EnumMemberLayout] = [];
        _cf_declared = len(_cf_raw);
        _cf_typed = True;
        for (_cf_idx, _cf_member) in enumerate(_cf_raw) {
            _lit = _cf_values[_cf_idx];
            if _lit is None {
                continue;
            }
            if (_scalar == "str") != isinstance(_lit, str) {
                _cf_typed = False;
            }
            _cf_members.append(
                EnumMemberLayout(
                    name=_cf_member[0],
                    ordinal=len(_cf_members),
                    int_value=(_lit if isinstance(_lit, int) else 0),
                    str_value=(_lit if isinstance(_lit, str) else None)
                )
            );
        }
        self.registry.enums[ename] = EnumLayout(
            name=ename,
            underlying=("str" if _scalar == "str" else "i64"),
            is_string_enum=(_scalar == "str"),
            is_class_form=True,
            all_values_known=(_cf_declared == len(_cf_members) and _cf_typed),
            members=_cf_members
        );
    }
}

impl LayoutPass._build_vtable_layout(
    arch_name: str, arch_map: dict[str, Archetype]
) -> None {
    reg = self.registry;
    layout_obj = reg.layouts.get(arch_name);
    if layout_obj is None {
        return;
    }
    method_list: list[str] = [];
    seen_methods: set[str] = set();
    mro = reg.mro_order.get(arch_name, [arch_name]);

    for ancestor_name in mro[1:] {
        ancestor_layout = reg.layouts.get(ancestor_name);
        if ancestor_layout is None {
            continue;
        }
        for mslot in ancestor_layout.methods {
            if mslot.name not in seen_methods {
                method_list.append(mslot.name);
                seen_methods.add(mslot.name);
            }
        }
    }

    arch = arch_map.get(arch_name);
    if arch is not None {
        for method in arch.get_methods() {
            method_name = method.name_ref.sym_name if method.name_ref else None;
            if method_name is not None and method_name not in seen_methods {
                method_list.append(method_name);
                seen_methods.add(method_name);
            }
        }

        for (slot_name, _var, _acc) in archetype_accessors(arch) {
            if slot_name not in seen_methods {
                method_list.append(slot_name);
                seen_methods.add(slot_name);
            }
        }
    }

    methods: list[MethodSlot] = [];
    method_index: dict[str, int] = {};
    for (i, mname) in enumerate(method_list) {
        sig_node: (UniNode | None) = None;
        owner = arch_name;
        for check_name in mro {
            check_arch = arch_map.get(check_name);
            if check_arch is None {
                continue;
            }
            found = False;
            for method in check_arch.get_methods() {
                mn = method.name_ref.sym_name if method.name_ref else None;
                if mn == mname {
                    sig_node = method.signature;
                    owner = check_name;
                    found = True;
                    break;
                }
            }
            if not found {
                for (slot_name, _var, acc) in archetype_accessors(check_arch) {
                    if slot_name == mname {
                        sig_node = acc.signature;
                        owner = check_name;
                        found = True;
                        break;
                    }
                }
            }
            if found {
                break;
            }
        }
        slot = MethodSlot(name=mname, index=i, owner=owner, signature=sig_node);
        methods.append(slot);
        method_index[mname] = i;
    }

    layout_obj.methods = methods;
    layout_obj.method_index = method_index;
}

impl LayoutPass._compute_acyclicity -> None {
    state: dict[str, int] = {};
    for name in list(self.registry.layouts.keys()) {
        self._acyclic_walk(name, state);
    }
    for (name, lay) in self.registry.layouts.items() {
        lay.is_acyclic = state.get(name) == 1;
    }
}

impl LayoutPass._acyclic_walk(name: str, state: dict[str, int]) -> int {
    if name in state {
        cur = state[name];
        if cur == 0 {
            return 2;
        }
        return cur;
    }
    lay = self.registry.layouts.get(name);
    if lay is None or lay.has_vtable or lay.is_osp {
        state[name] = 2;
        return 2;
    }
    state[name] = 0;
    result = 1;
    for finfo in lay.fields {
        var = finfo.decl_node;
        tb = var.type if isinstance(var, HasVar) else None;
        if tb is None {
            result = 2;
            break;
        }
        key: (str | None) = None;
        try {
            key = native_type_key(tb);
        } except Exception {
            key = None;
        }
        if key is None {
            result = 2;
            break;
        }
        parts = self._expand_type_keys(key);
        if parts is None {
            result = 2;
            break;
        }
        for part in parts {
            if self._acyclic_walk(part, state) == 2 {
                result = 2;
                break;
            }
        }
        if result == 2 {
            break;
        }
    }
    state[name] = result;
    return result;
}

impl LayoutPass._expand_type_keys(key: str) -> (list[str] | None) {
    import from jaclang.compiler.passes.layout_pass { LAYOUT_COMPATIBLE_SCALARS }
    out: list[str] = [];
    for raw in self._split_top_level(key, "|") {
        p = raw.strip();
        if not p {
            return None;
        }
        if p in LAYOUT_COMPATIBLE_SCALARS or p in ("None", "NoneType") {
            continue;
        }

        if p.startswith("type[") and p.endswith("]") {
            continue;
        }
        inner: (str | None) = None;
        if p.startswith("list[") and p.endswith("]") {
            inner = p[5:-1];
        } elif p.startswith("set[") and p.endswith("]") {
            inner = p[4:-1];
        } elif p.startswith("frozenset[") and p.endswith("]") {
            inner = p[10:-1];
        } elif p.startswith("tuple[") and p.endswith("]") {
            inner = p[6:-1];
        } elif p.startswith("dict[") and p.endswith("]") {
            inner = p[5:-1];
        }
        if inner is not None {
            for elem in self._split_top_level(inner, ",") {
                sub = self._expand_type_keys(elem.strip());
                if sub is None {
                    return None;
                }
                out.extend(sub);
            }
            continue;
        }
        if ("[" in p) or ("(" in p) or (" " in p) {
            return None;
        }
        out.append(p);
    }
    return out;
}

impl LayoutPass._split_top_level(s: str, sep: str) -> list[str] {
    parts: list[str] = [];
    depth = 0;
    cur = "";
    for ch in s {
        if ch in "[(" {
            depth += 1;
        } elif ch in "])" {
            depth -= 1;
        }
        if ch == sep and depth == 0 {
            parts.append(cur);
            cur = "";
        } else {
            cur = cur + ch;
        }
    }
    parts.append(cur);
    return parts;
}

impl LayoutRegistry.get_layout(name: str) -> (ArchetypeLayout | None) {
    return self.layouts.get(name);
}

impl LayoutRegistry.get_enum_layout(name: str) -> (EnumLayout | None) {
    return self.enums.get(name);
}

impl LayoutRegistry.resolve_method_owner(
    arch_name: str, method_name: str
) -> (str | None) {
    lay = self.layouts.get(arch_name);
    if lay is None {
        return None;
    }
    for mslot in lay.methods {
        if mslot.name == method_name {
            return mslot.owner;
        }
    }
    return None;
}

impl LayoutRegistry.set_mro(name: str, mro: list[str]) -> None {
    self.mro_order[name] = mro;
    self._descendants = None;
}

impl LayoutRegistry.descendants_of(names: list[str]) -> list[str] {
    """Every class whose method resolution order holds one of `names`, the
    named classes included, in registry order. The index is built once per
    set of resolution orders.""";
    index = self._descendants;
    if index is None {
        index = {};
        for cls in self.mro_order {
            for anc in self.get_mro(cls) {
                index.setdefault(anc, []).append(cls);
            }
        }
        self._descendants = index;
    }
    if len(names) == 1 {
        return index.get(names[0], []);
    }
    found: set[str] = set();
    for name in names {
        found.update(index.get(name, []));
    }
    return [
        cls
        for cls in self.mro_order
        if cls in found
    ];
}

impl LayoutRegistry.get_mro(name: str) -> list[str] {
    return self.mro_order.get(name, [name]);
}

impl LayoutRegistry.get_topo_order -> list[str] {
    return self.topo_order;
}

impl LayoutRegistry.is_primary_ancestor(child: str, ancestor: str) -> bool {
    current = child;
    while current is not None {
        parents = self.class_parents.get(current);
        if parents is None or not parents {
            return False;
        }
        primary = parents[0];
        if primary == ancestor {
            return True;
        }
        current = primary;
    }
    return False;
}

impl LayoutPass._validate_obj_fields(
    arch: Archetype, arch_map: dict[str, Archetype]
) -> None {
    if arch.arch_type {
        tok_name = arch.arch_type.name;
        if tok_name != Tok.KW_OBJECT.value {
            return;
        }
    }
    aname = arch.name.value if arch.name else "unknown";
    for var in arch.get_has_vars() {
        fname = var.name.value if var.name else "field";

        if var.accessors {
            continue;
        }

        _archhas = var.find_parent_of_type(ArchHas);
        if _archhas is not None and _archhas.is_static {
            continue;
        }

        if not var.type_tag or not var.type_tag.tag {
            self.ctx.emit(W5031, node_override=var, arch=aname, field=fname);
            continue;
        }
        type_node = var.type_tag.tag;
        if not self._is_layout_compatible_semantic_type(var.type)
            and not self._is_layout_compatible_type(type_node, arch_map) {
            type_str = unparse_node(type_node) or str(type_node);
            self.ctx.emit(
                W5032, node_override=var, arch=aname, field=fname, type=type_str
            );
        }
    }
}

impl LayoutPass._is_layout_compatible_semantic_type(typ: TypeBase | None) -> bool {
    if isinstance(typ, UnionType) {
        return bool(typ.types)
            and all(
                self._is_layout_compatible_semantic_type(member) for member in typ.types
            );
    }
    if isinstance(typ, FunctionType) {
        return True;
    }
    if not isinstance(typ, ClassType) or typ._shared is None {
        return False;
    }
    declaration = typ.shared.symbol_table;
    if isinstance(declaration, Archetype)
        and declaration.loc.mod_path.endswith(".jac") {
        return True;
    }
    if typ.is_builtin(
        list(LAYOUT_COMPATIBLE_SCALARS)
            + ["None", "NoneType", "ptr", "PtrView", "Pinned"]
    ) {
        return True;
    }
    if typ.is_builtin(["list", "dict", "set", "frozenset", "tuple"]) {
        args = typ.private.type_args;
        return bool(args)
            and all(self._is_layout_compatible_semantic_type(arg) for arg in args);
    }
    return False;
}

impl LayoutPass._is_layout_compatible_type(
    type_node: (UniNode | None), arch_map: dict[str, Archetype]
) -> bool {
    import from jaclang.compiler.passes.layout_pass { LAYOUT_COMPATIBLE_SCALARS }
    if type_node is None {
        return False;
    }
    if isinstance(type_node, (FuncSignature, Null)) {
        return True;
    }

    if isinstance(type_node, UnaryExpr) and type_node.ownership != OwnershipKind.NONE {
        return self._is_layout_compatible_type(type_node.operand, arch_map);
    }

    if isinstance(type_node, Expr)
        and self._is_layout_compatible_semantic_type(type_node.type) {
        return True;
    }

    if isinstance(type_node, Name) {
        tname = type_node.value;
        if tname in LAYOUT_COMPATIBLE_SCALARS {
            return True;
        }
        if tname == "None" {
            return True;
        }

        _tnative = referenced_native_name(type_node) or tname;
        if _tnative in arch_map {
            return True;
        }

        if _tnative in self.registry.layouts {
            return True;
        }

        return False;
    }

    if BuiltinType and isinstance(type_node, BuiltinType) {
        tname = type_node.value;
        return tname in LAYOUT_COMPATIBLE_SCALARS;
    }

    if isinstance(type_node, BinaryExpr) {
        op_val = type_node.op.value if isinstance(type_node.op, Token) else '';
        if op_val == "|" {
            return (
                self._is_layout_compatible_type(type_node.left, arch_map)
                and self._is_layout_compatible_type(type_node.right, arch_map)
            );
        }
    }

    if isinstance(type_node, AtomTrailer) and not type_node.is_attr {
        target_name: (str | None) = None;
        if isinstance(type_node.target, Name) {
            target_name = type_node.target.value;
        }

        if target_name in ("type", "Callable") {
            return True;
        }
        if target_name in {"list", "dict", "set", "frozenset", "tuple"} {
            index = type_node.right;
            if isinstance(index, IndexSlice) {
                for sl in index.slices {
                    elem: UniNode = sl.start if sl.start is not None else sl;
                    if isinstance(elem, TupleVal) and elem.values {
                        for tv in elem.values {
                            if not self._is_layout_compatible_type(tv, arch_map) {
                                return False;
                            }
                        }
                    } else {
                        if not self._is_layout_compatible_type(elem, arch_map) {
                            return False;
                        }
                    }
                }
            }
            return True;
        }
    }

    return False;
}

impl LayoutPass.run_walk with Module entry {
    self.module = self._run_impl(here);
}

impl FieldLayout.semantic_type.getter -> TypeBase | None {
    declaration = self.decl_node;
    if isinstance(declaration, AstTypedVarNode) {
        return declaration.type;
    }
    if isinstance(declaration, TypeParam) {
        return declaration.name.type;
    }
    return None;
}

impl accessor_slot_name(field_name: str, acc: Ability) -> (str | None) {
    suffix = ACCESSOR_SLOT_SUFFIX.get(acc.accessor_kind);
    return None if suffix is None else f"{field_name}.{suffix}";
}

impl archetype_accessors(arch: Archetype) -> list[tuple[(str, HasVar, Ability)]] {
    out: list[tuple[(str, HasVar, Ability)]] = [];
    for var in arch.get_has_vars() {
        if not var.accessors {
            continue;
        }
        fname = var.name.value if var.name else "field";
        for acc in var.accessors {
            slot = accessor_slot_name(fname, acc);
            if slot is not None {
                out.append((slot, var, acc, ));
            }
        }
    }
    return out;
}

impl open_dispatch(arch: Archetype) -> bool {
    """Can a module this one never sees override a method dispatched through it?

    Layout is decided per module, and a subclass in an importing module is
    invisible here. A class other modules can name, whose own body declares a
    method or accessor a subclass may override, must carry a vtable so a call
    through a reference typed as this class reaches the override wherever it
    was declared; without one the call binds to this class's body. A private
    class cannot be named, so cannot be subclassed, outside its module, whose
    registry is therefore complete for it. A foreign (C-layout) struct is
    plain data, and constructors, static and class methods never dispatch
    through an instance. A `drop` hook alone does not open a class either: it
    runs only when the owner lets go, and a class whose only behavior is its
    hook stays flat so a headerless build can embed it inline in an own field.
    """;

    if arch.access_type == SymbolAccess.PRIVATE or is_clib_archetype(arch) {
        return False;
    }
    for method in arch.get_methods() {
        mname = method.name_ref.sym_name if method.name_ref else None;
        if mname is not None
            and mname not in NON_DISPATCHED_METHODS
            and not method.is_static
            and not method.is_classmethod {
            return True;
        }
    }
    return bool(archetype_accessors(arch));
}

impl get_layout_registry(module: Module, prog: JacProgram) -> LayoutRegistry {
    reg = module.gen.layout_registry;
    if reg is not None {
        return reg;
    }

    if not require(prog, module, CompilationProduct.LAYOUT) {
        raise RuntimeError(f"Layout preparation failed: {module.loc.mod_path}");
    }
    return module.gen.layout_registry or LayoutRegistry();
}

impl layout_slot_count(lay: ArchetypeLayout) -> int {
    top = 0;
    for slot in [lay.vtable_ptr_slot, lay.type_tag_slot, lay.reports_slot] {
        if slot is not None and (slot + 1) > top {
            top = slot + 1;
        }
    }
    for finfo in lay.fields {
        if (finfo.index + 1) > top {
            top = finfo.index + 1;
        }
    }
    return top;
}

impl archetype_native_name(arch: Archetype) -> str {
    name = arch.name.value if arch.name else "unknown";
    if arch.loc is not None and arch.loc.mod_path.endswith(".pyi") {
        import os;
        import from jaclang.compiler.frontend.codeinfo { bundled_stdlib_module_of }
        twin = _NATIVE_NAME_BY_DECL.get(
            (
                real_path(arch.loc.mod_path),
                arch.loc.first_line,
                arch.loc.col_start,
                name
            )
        );
        stdlib_module = bundled_stdlib_module_of(arch.loc.mod_path);
        if twin is None and stdlib_module is not None {
            twin = _NATIVE_NAME_BY_STDLIB.get((stdlib_module, name));
        }
        return twin if twin is not None else _archetype_native_name(arch, name);
    }
    native = _archetype_native_name(arch, name);
    if arch.loc is not None and arch.loc.mod_path {
        import os;
        key = (
            real_path(arch.loc.mod_path),
            arch.loc.first_line,
            arch.loc.col_start,
            name
        );
        if key not in _NATIVE_NAME_BY_DECL {
            _NATIVE_NAME_BY_DECL[key] = native;
            _NATIVE_NAMED_CLASSES.add(name);
            import from jaclang.compiler.frontend.codeinfo { bundled_stdlib_module_of }
            stdlib_module = bundled_stdlib_module_of(arch.loc.mod_path);
            if stdlib_module is not None
                and (stdlib_module, name) not in _NATIVE_NAME_BY_STDLIB {
                _NATIVE_NAME_BY_STDLIB[(stdlib_module, name)] = native;
            }
        }
    }
    return native;
}

impl record_interface_twins(native_mod: Module, prog: JacProgram) {
    import os;

    if native_mod.loc is None or not native_mod.loc.mod_path.endswith(".jac") {
        return;
    }
    stdlib_module = bundled_stdlib_module_of(native_mod.loc.mod_path);
    stub_path = typeshed_stub_path(stdlib_module)
        if stdlib_module is not None
        else None;
    if stub_path is None {
        return;
    }
    stub_mod: (Module | None) = None;
    for stmt in native_mod.body {
        if not isinstance(stmt, Archetype)
            or stmt.name is None
            or stmt.name.value.startswith("_") {
            continue;
        }
        if stub_mod is None {
            try {
                stub_mod = prog.load_dependency_module(stub_path);
            } except Exception {
                return;
            }
        }
        typ = interface_type(stub_mod, stmt.name.value, prog);
        if not isinstance(typ, ClassType) or typ._shared is None or typ.is_instance() {
            continue;
        }
        key = typ.shared.canonical_key();
        if key is None or not key[0].endswith(".pyi") {
            continue;
        }
        _NATIVE_NAME_BY_DECL[(real_path(key[0]), key[1], key[2], key[3])] = (
            archetype_native_name(stmt)
        );
        _NATIVE_NAMED_CLASSES.add(key[3]);
    }
}

impl _archetype_native_name(arch: Archetype, name: str) -> str {
    if arch.name is not None and is_enum_class_type(arch.name.type) {
        return name;
    }
    if arch.find_parent_of_type(Import) is not None {
        return name;
    }
    return native_arch_name(arch.loc.mod_path if arch.loc else "", name);
}

impl _recorded_native_name(shared: ClassDetailsShared) -> (str | None) {
    if shared.class_name not in _NATIVE_NAMED_CLASSES {
        return None;
    }
    key = shared.canonical_key();
    if key is None or not key[0] {
        return None;
    }
    import os;
    found = _NATIVE_NAME_BY_DECL.get((real_path(key[0]), key[1], key[2], key[3]));
    if found is None {
        import from jaclang.compiler.frontend.codeinfo { bundled_stdlib_module_of }
        stdlib_module = bundled_stdlib_module_of(key[0]);
        if stdlib_module is not None {
            found = _NATIVE_NAME_BY_STDLIB.get((stdlib_module, key[3]));
        }
    }
    return found;
}

impl _declared_native_name(shared: ClassDetailsShared) -> str {
    return _recorded_native_name(shared) or interface_class_native_name(shared);
}

impl referenced_archetype(expr: (UniNode | None)) -> (Archetype | None) {
    if expr is None {
        return None;
    }
    if isinstance(expr, Archetype) {
        return expr;
    }
    typ = expr.type if isinstance(expr, Expr) else None;
    if isinstance(typ, ClassType) and typ._shared is not None {
        if typ.is_instance() {
            return None;
        }
        scope = typ.shared.symbol_table;
        if isinstance(scope, Archetype) {
            return scope;
        }
    }
    if isinstance(expr, AtomTrailer) and expr.is_attr {
        return referenced_archetype(expr.right);
    }
    if not isinstance(expr, AstSymbolNode) or expr.sym is None {
        return None;
    }
    decl = expr.sym.decl;
    owner = decl.name_of if decl is not None else None;
    return owner if isinstance(owner, Archetype) else None;
}

impl referenced_native_name(expr: (UniNode | None)) -> (str | None) {
    arch = referenced_archetype(expr);
    if arch is not None {
        return archetype_native_name(arch);
    }
    typ = expr.type if isinstance(expr, Expr) else None;
    if isinstance(typ, ClassType)
        and typ._shared is not None
        and not typ.is_instance()
        and not isinstance(typ.shared.symbol_table, Archetype) {
        return _recorded_native_name(typ.shared);
    }
    return None;
}

impl class_type_native_name(typ: (TypeBase | None)) -> (str | None) {
    if not isinstance(typ, ClassType) or typ._shared is None {
        return None;
    }
    shared = typ.shared;
    scope = shared.symbol_table;
    if shared.is_enum_class or shared.is_extern_struct {
        return shared.class_name;
    }
    if not isinstance(scope, Archetype) {
        return _declared_native_name(shared);
    }
    memo = shared._native_name;
    if memo is not None and memo[0] is scope {
        return memo[1];
    }
    name = archetype_native_name(scope);
    shared._native_name = (scope, name);
    return name;
}

impl interface_class_native_name(shared: ClassDetailsShared) -> str {
    key = shared.canonical_key();
    if key is None or not key[0].endswith(".jac") {
        return shared.class_name;
    }

    return native_arch_name(key[0], shared.class_name);
}

impl native_type_key(typ: TypeBase) -> str {
    if isinstance(typ, ClassType) {
        if typ._shared is None {
            return typ.mangle();
        }
        base = class_type_native_name(typ) or typ.shared.class_name;
        if typ.private.type_args {
            args = ",".join(native_type_key(arg) for arg in typ.private.type_args);
            base = f"{base}[{args}]";
        }
        if typ.is_instantiable() and not typ.is_instance() {
            return f"type[{base}]";
        }
        return base;
    }
    if isinstance(typ, UnionType) {
        members = sorted(set(native_type_key(ty) for ty in (typ.types or [])));
        return "|".join(members) if members else "<union>";
    }
    if isinstance(typ, FunctionType) {
        params = ",".join(
            (native_type_key(p.param_type) if p.param_type is not None else "any")
            for p in (typ.parameters or [])
        );
        ret = native_type_key(typ.return_type)
            if typ.return_type is not None
            else "any";
        return f"fn({params})->{ret}";
    }
    if isinstance(typ, OverloadedType) {
        return "&".join(native_type_key(ov) for ov in (typ.overloads or []));
    }
    return typ.mangle();
}

impl declaring_module_path(base_expr: Expr) -> str {
    import os;

    base_type = base_expr.type;
    if isinstance(base_type, ClassType) and base_type._shared is not None {
        scope = base_type.shared.symbol_table;
        if isinstance(scope, Archetype) and scope.loc.mod_path {
            return real_path(scope.loc.mod_path);
        }
    }
    if not isinstance(base_expr, AstSymbolNode) {
        return "";
    }
    sym = base_expr.sym;
    if sym is None {
        return "";
    }
    decl = sym.decl;
    base_arch = decl.enclosing_decl(Archetype);
    if base_arch is None {
        return "";
    }
    decl_mod = decl.find_parent_of_type(Module);
    if decl_mod is None {
        return "";
    }
    path = decl_mod.loc.mod_path;
    return real_path(path) if path else "";
}

impl headers_agree(child: ArchetypeLayout, base: ArchetypeLayout) -> bool {
    return child.vtable_ptr_slot == base.vtable_ptr_slot
        and child.type_tag_slot == base.type_tag_slot
        and child.reports_slot == base.reports_slot;
}

impl relax_vtable_header(
    lay: ArchetypeLayout, ancestors: list[ArchetypeLayout], header_identity: bool = True
) -> bool {
    """Drop a vtable header a class carries only for having had a base.

    `needs_vtable` is decided per module, where a base's subclasses in other
    modules are not visible. A base that is nobody's parent in its own
    registry comes out flat; its subclass, merely for having a base, comes
    out with a vtable pointer in header slot 0 -- so every field the base
    declared sits one slot further along in the child, `headers_agree`
    refuses the pair, and the inherited access stays demoted.

    Here both layouts are in hand, so the question can be asked properly: is
    anything actually dispatched through this class? `vtable_by_dispatch`
    records the answer the defining module gave -- it is someone's parent, an
    isinstance target, or an OSP archetype. When nothing is, and no ancestor
    carries a header either, the child's vtable slot is a habit rather than a
    requirement and dropping it makes the two units agree.

    An `isinstance` target is not dispatched through: it needs a runtime
    identity, and a build whose allocations carry a header already stamps the
    class name there, which answers `isinstance` for a flat class as well as
    the vtable pointer would. `header_identity` says the build has that
    header; only then does an `isinstance`-only header count as a habit. A
    headerless build keeps the vtable, the one identity it has.

    Every ancestor is checked, not just the primary: relaxing a child whose
    grandparent carries a header would trade one disagreement for another.
    A class that IS dispatched through keeps its header and its refusal --
    that pair genuinely has no assignment satisfying both.
    """;
    identity_only = lay.vtable_by_isinstance_only and header_identity;
    if lay.is_osp
        or (lay.vtable_by_dispatch and not identity_only)
        or not lay.has_vtable {
        return False;
    }
    for anc_lay in ancestors {
        if anc_lay.has_vtable {
            return False;
        }
    }
    lay.has_vtable = False;
    lay.vtable_ptr_slot = None;
    return headers_agree(lay, ancestors[0]);
}

impl extended_mro(reg: LayoutRegistry, lay: ArchetypeLayout) -> list[str] {
    out: list[str] = list(lay.mro or [lay.name]);
    trusted: set[str] = set();
    for (i, pname) in enumerate(lay.parents or []) {
        anc_lay = reg.layouts.get(pname);
        if anc_lay is None {
            continue;
        }
        want = (lay.parent_mods or [])[i] if i < len(lay.parent_mods or []) else "";
        if want and anc_lay.decl_mod and want == anc_lay.decl_mod {
            trusted.add(pname);
        }
    }
    idx = 1;
    while idx < len(out) {
        anc = out[idx];
        anc_lay = reg.layouts.get(anc);
        if anc_lay is not None
            and (anc in trusted or anc not in (lay.parents or []))
            and headers_agree(lay, anc_lay) {
            for nxt in (reg.mro_order.get(anc) or [])[1:] {
                if nxt not in out {
                    out.append(nxt);
                    trusted.add(nxt);
                }
            }
        }
        idx += 1;
    }
    return out;
}

impl adopt_imported_bases(module: Module, header_identity: bool = True) -> list[str] {
    reg: (LayoutRegistry | None) = module.gen.layout_registry;
    if reg is None {
        return [];
    }
    for (name, lay) in reg.layouts.items() {
        full = extended_mro(reg, lay);
        if len(full) > len(lay.mro or []) {
            lay.mro = full;
        }
        if len(full) > len(reg.mro_order.get(name) or []) {
            reg.set_mro(name, list(full));
        }
    }
    layouts = reg.layouts;
    order = reg.dependency_order(list(layouts));
    adopted: list[str] = [];
    for name in order {
        lay = reg.layouts.get(name);
        if lay is None {
            continue;
        }
        ancestors: list[ArchetypeLayout] = [];
        for anc in (lay.mro or [])[1:] {
            anc_lay = reg.layouts.get(anc);
            if anc_lay is not None {
                ancestors.append(anc_lay);
            }
        }
        if not ancestors {
            continue;
        }
        absent = False;
        for anc_lay in ancestors {
            for finfo in anc_lay.fields {
                if finfo.name not in lay.field_index {
                    absent = True;
                }
            }
            for mslot in anc_lay.methods {
                if mslot.name not in lay.method_index {
                    absent = True;
                }
            }
        }

        inherited_methods: set[str] = set();
        inherited_index = 0;
        for anc_lay in ancestors {
            for mslot in anc_lay.methods {
                if mslot.name in inherited_methods {
                    continue;
                }
                inherited_methods.add(mslot.name);
                if lay.method_index.get(mslot.name, -1) != inherited_index {
                    absent = True;
                }
                inherited_index += 1;
            }
        }
        if not absent {
            continue;
        }
        if not headers_agree(lay, ancestors[0])
            and not relax_vtable_header(lay, ancestors, header_identity) {
            continue;
        }
        adopt_ancestor_slots(lay, ancestors);
        adopted.append(name);
    }
    return adopted;
}

impl adopt_ancestor_slots(lay: ArchetypeLayout, ancestors: list[ArchetypeLayout]) {
    primary = ancestors[0];
    fields: list[FieldLayout] = [];
    field_index: dict[str, int] = {};
    parent_field_start: dict[str, int] = {};
    seen: set[str] = set();
    if lay.reports_slot is not None {
        field_index["reports"] = lay.reports_slot;
        seen.add("reports");
    }
    for finfo in primary.fields {
        if finfo.name in seen {
            continue;
        }
        seen.add(finfo.name);
        fields.append(clone_field(finfo, finfo.index));
        field_index[finfo.name] = finfo.index;
    }
    parent_field_start[primary.name] = layout_slot_count(primary) - len(primary.fields);
    next_idx = layout_slot_count(primary);
    for anc_lay in ancestors[1:] {
        parent_field_start[anc_lay.name] = next_idx;
        for finfo in anc_lay.fields {
            if finfo.name in seen {
                continue;
            }
            seen.add(finfo.name);
            fields.append(clone_field(finfo, next_idx));
            field_index[finfo.name] = next_idx;
            next_idx += 1;
        }
    }
    for finfo in lay.fields {
        if finfo.name in seen {
            continue;
        }
        seen.add(finfo.name);
        fields.append(clone_field(finfo, next_idx));
        field_index[finfo.name] = next_idx;
        next_idx += 1;
    }
    lay.fields = sorted(fields, key=lambda (f: FieldLayout) { f.index; });
    lay.field_index = field_index;
    lay.parent_field_start = parent_field_start;
    adopt_ancestor_methods(lay, ancestors);
    for anc_lay in ancestors {
        lay.is_acyclic = lay.is_acyclic and anc_lay.is_acyclic;
    }
}

impl clone_field(finfo: FieldLayout, index: int) -> FieldLayout {
    return FieldLayout(
        name=finfo.name,
        index=index,
        type_tag=finfo.type_tag,
        type_node=finfo.type_node,
        default_expr=finfo.default_expr,
        owner=finfo.owner,
        is_func_ptr=finfo.is_func_ptr,
        decl_node=finfo.decl_node
    );
}

impl adopt_ancestor_methods(lay: ArchetypeLayout, ancestors: list[ArchetypeLayout]) {
    order: list[str] = [];
    source: dict[str, MethodSlot] = {};
    for anc_lay in ancestors {
        for mslot in anc_lay.methods {
            if mslot.name not in source {
                source[mslot.name] = mslot;
                order.append(mslot.name);
            }
        }
    }
    for mslot in lay.methods {
        if mslot.name not in source {
            order.append(mslot.name);
        }
        source[mslot.name] = mslot;
    }
    methods: list[MethodSlot] = [];
    method_index: dict[str, int] = {};
    for (i, mname) in enumerate(order) {
        held = source[mname];
        methods.append(
            MethodSlot(name=mname, index=i, owner=held.owner, signature=held.signature)
        );
        method_index[mname] = i;
    }
    lay.methods = methods;
    lay.method_index = method_index;
}

impl is_erased_base_name(name: str, archetypes: dict[str, Archetype]) -> bool {
    return name in NATIVE_ERASED_BASES and name not in archetypes;
}

impl enum_class_of(t: (TypeBase | None)) -> (ClassType | None) {
    if isinstance(t, ClassType) and t._shared is not None and t.shared.is_enum_class {
        return t;
    }
    return None;
}

impl is_enum_class_type(t: (TypeBase | None)) -> bool {
    return enum_class_of(t) is not None;
}

impl enum_decl_of(t: (TypeBase | None)) -> (Enum | Archetype | None) {
    cls = enum_class_of(t);
    if cls is None {
        return None;
    }
    scope = cls.shared.symbol_table;
    if isinstance(scope, Enum) {
        return scope;
    }
    if isinstance(scope, Archetype) and class_form_enum_scalar(cls) is not None {
        return scope;
    }
    return None;
}

impl enum_value_type_of(t: (TypeBase | None)) -> (TypeBase | None) {
    cls = enum_class_of(t);
    return cls.shared.enum_value_type if cls is not None else None;
}

impl class_form_enum_scalar(t: (TypeBase | None)) -> (str | None) {
    cls = enum_class_of(t);
    if cls is None or not isinstance(cls.shared.symbol_table, Archetype) {
        return None;
    }
    value_type = cls.shared.enum_value_type;
    if not isinstance(value_type, ClassType) or value_type._shared is None {
        return None;
    }
    value_name = value_type.shared.class_name;
    return value_name if value_name in ("str", "int") else None;
}

impl class_form_enum_decls(module: Module) -> list[Archetype] {
    out: list[Archetype] = [];
    for nd in module.get_all_sub_nodes(Archetype) {
        if nd.name is None {
            continue;
        }
        if class_form_enum_scalar(nd.name.type) is not None {
            out.append(nd);
        }
    }
    return out;
}

impl enum_member_literal(value_expr: (UniNode | None)) -> (str | int | None) {
    (folded, val) = fold_const(value_expr);
    if not folded or isinstance(val, bool) or not isinstance(val, (str, int)) {
        return None;
    }
    return val;
}

impl is_enum_auto(value_expr: (UniNode | None)) -> bool {
    if not isinstance(value_expr, FuncCall) or value_expr.params {
        return False;
    }
    _target = value_expr.target;
    if not isinstance(_target, Name) {
        return False;
    }
    _sym = _target.sym;
    if _sym is None {
        return False;
    }
    _decl = _sym.decl;
    _item = _decl.find_parent_of_type(ModuleItem);
    if _item is not None and _item.name is not None {
        _from = _item.from_parent.from_loc;
        return (
            _from is not None
            and _from.dot_path_str == "enum"
            and _item.name.value == "auto"
        );
    }
    _mod = _decl.find_parent_of_type(Module);
    return _mod is not None and _mod.name == "enum" and _sym.sym_name == "auto";
}

impl resolve_enum_member_values(
    raw_members: list[tuple[(str, (UniNode | None))]]
) -> list[(str | int | None)] {
    out: list[(str | int | None)] = [];
    _max: (int | None) = None;
    _blocked = False;
    for member in raw_members {
        _vnode = member[1];
        if _vnode is None or is_enum_auto(_vnode) {
            if _blocked {
                out.append(None);
                continue;
            }
            _next = 1 if _max is None else _max + 1;
            _max = _next;
            out.append(_next);
            continue;
        }
        _lit = enum_member_literal(_vnode);
        if isinstance(_lit, int) {
            _max = _lit if (_max is None or _lit > _max) else _max;
        } else {
            _blocked = True;
        }
        out.append(_lit);
    }
    return out;
}

impl class_form_enum_members(
    scope: (UniScopeNode | None)
) -> list[tuple[(str, (UniNode | None))]] {
    out: list[tuple[(str, (UniNode | None))]] = [];
    if scope is None or not scope.names_in_scope {
        return out;
    }
    _placed: list[tuple[(int, int, str)]] = [];
    _values: dict[str, UniNode] = {};
    for mname in scope.names_in_scope {
        _sym = scope.names_in_scope.get(mname);
        _decl = _sym.decl if _sym is not None else None;
        _asn = _decl.parent if (_decl is not None) else None;
        if not isinstance(_asn, Assignment) or _asn.value is None {
            continue;
        }
        _placed.append((_asn.loc.first_line, _asn.loc.col_start, mname));
        _values[mname] = _asn.value;
    }
    _placed.sort();
    for `entry in _placed {
        out.append((`entry[2], _values[`entry[2]]));
    }
    return out;
}

impl class_form_enum_literal(t: ClassType, member: str) -> (str | int | None) {
    _members = class_form_enum_members(t.shared.symbol_table);
    _values = resolve_enum_member_values(_members);
    for (_idx, _member) in enumerate(_members) {
        if _member[0] == member {
            return _values[_idx];
        }
    }
    return None;
}

impl class_form_enum_member(
    t: (TypeBase | None)
) -> (tuple[(str, (str | int), str)] | None) {
    if not isinstance(t, EnumMemberType) {
        return None;
    }
    enum_class = t.enum_class;
    member_info = t.member_info;
    if enum_class is None or member_info is None {
        return None;
    }
    _scalar = class_form_enum_scalar(enum_class);
    if _scalar is None {
        return None;
    }
    _name = member_info.member_name;
    _lit = class_form_enum_literal(enum_class, _name);
    if _scalar == "str" and isinstance(_lit, str) {
        return (_scalar, _lit, _name);
    }
    if _scalar == "int" and isinstance(_lit, int) and not isinstance(_lit, bool) {
        return (_scalar, _lit, _name);
    }
    return None;
}
