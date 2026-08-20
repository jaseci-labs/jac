import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.compiler.passes.tool.unparse_pass { unparse_node }


impl LayoutPass.postinit -> None {
    self.registry = class_model(self.prog);
    self.isinstance_targets = set();
    self._building = set();
    self._base_aids = set();
    self._closure_archs = {};
    self._registered = [];
    super.postinit();
}

impl LayoutPass.transform(ir_in: Module) -> Module {
    """Contribute this module's archetypes to the program's class model.

    There is no topological sort here and no repair pass afterwards.
    `_ensure_layout` recurses through each archetype's linearization and
    builds ancestors first, which IS the dependency order -- and because the
    linearization comes from the type system, it crosses module boundaries,
    so an imported base is laid out before its subclass rather than being
    patched in later by `adopt_imported_bases`.
    """;
    module = self.ir_in;

    self._build_enum_layouts(module);

    self._mark_module_done(module);

    arch_map = self._collect_archetypes(module);
    if not arch_map {
        module.gen.layout_registry = self.registry;
        return ir_in;
    }

    self._collect_isinstance_targets(module);
    self._discover_closure(arch_map);

    for (_, arch) in arch_map.items() {
        self._ensure_layout(arch);
    }

    for aid in self._registered {
        self._build_vtable_layout(aid);
    }

    self._compute_acyclicity();

    for (_, arch) in arch_map.items() {
        self._validate_obj_fields(arch, arch_map);
    }

    module.gen.layout_registry = self.registry;
    return ir_in;
}

impl LayoutPass._mark_module_done(module: Module) -> None {
    """Record that this module's archetypes are in the model.

    Marked before the work rather than after: laying a class out reaches its
    ancestors, which can re-enter this module, and the model is what makes
    that idempotent.
    """;
    import os;
    path = module.loc.mod_path if module.loc else None;
    if path {
        self.registry.modules_done.add(os.path.realpath(path));
    }
}

impl LayoutPass._class_type_of(arch: Archetype) -> any {
    """This archetype as a ClassType, or None if the type system cannot say.

    The type evaluator answers on demand -- `type_check` gates the checking
    pass, not this -- so the native lane reaches the same linearization the
    checker does without paying for a full type-check.
    """;
    if self.prog is None {
        return None;
    }
    try {
        return self.prog.get_type_evaluator().get_type_of_class(arch);
    } except Exception {
        return None;
    }
}

impl LayoutPass._ancestor_archetypes(arch: Archetype) -> list[Archetype] {
    """`arch`'s ancestors, nearest first, as their own declarations.

    Preferred source is `ClassType.shared.mro`: the C3 linearization
    `compute_mro_linearization` already computed and memoized. That is the
    single linearizer -- this pass does not compute a second one.

    When the type system cannot construct the class (an erased or otherwise
    untypable declaration), fall back to resolving each base expression to
    its declaring archetype through the symbol it already carries. That
    loses C3 ordering but keeps identity exact; it never falls back to
    matching on a bare name.
    """;
    out: list[Archetype] = [];
    cls = self._class_type_of(arch);
    shared = cls.shared if cls is not None else None;
    mro = list(shared.mro) if (shared is not None and shared.mro) else [];
    if mro {
        for anc_cls in mro[1:] {
            anc = class_type_decl(anc_cls);
            if anc is not None and anc is not arch and self._lays_out(anc) {
                out.append(anc);
            }
        }
        if out {
            return out;
        }
    }

    return self._base_archetypes(arch);
}

impl LayoutPass._ensure_layout(arch: Archetype) -> (str | None) {
    """Lay out `arch`, its ancestors first. Returns its aid.

    The recursion is the ordering, and the memo on `layouts` makes it linear
    in the closure rather than quadratic in the chain: each archetype is
    built once, whichever descendant reaches it first.
    """;
    aid = archetype_id(arch);
    if aid in self.registry.layouts {
        return aid;
    }
    if aid in self._building {
        return aid;
    }
    self._building.add(aid);
    try {
        ancestors: list[ArchetypeLayout] = [];
        for anc_arch in self._ancestor_archetypes(arch) {
            anc_aid = self._ensure_layout(anc_arch);
            if anc_aid is None {
                continue;
            }
            anc_lay = self.registry.layouts.get(anc_aid);
            if anc_lay is not None and anc_lay not in ancestors {
                ancestors.append(anc_lay);
            }
        }
        lay = self._build_layout(arch, aid, ancestors);
        self.registry.register(lay);
        self._registered.append(aid);
    } finally {
        self._building.discard(aid);
    }
    return aid;
}

impl LayoutPass._lays_out(arch: Archetype) -> bool {
    """Whether this declaration is one the backend assigns a layout to.

    Two kinds of ancestor are reachable through the linearization but have
    no runtime representation. Typeshed declarations -- `object` and the
    rest -- are real classes to the type system and nothing to the backend.
    Erasure markers (NATIVE_ERASED_BASES: `ABC`, `Protocol` and friends) are
    erased in native context, so a class must not carry one as a native
    parent; a module declaring a class of its own by one of those names
    means that class, which is why the test is on where it is declared
    rather than on the spelling alone.

    The bare-name model excluded both by accident: it only ever knew
    archetypes declared in the module being compiled.
    """;
    import from jaclang.jac0core.codeinfo { NATIVE_ERASED_BASES }
    if arch_decl_module(arch).endswith(".pyi") {
        return False;
    }
    aname = arch.name.value if arch.name else "";
    if aname in NATIVE_ERASED_BASES {
        return arch.find_parent_of_type(Module) is self.ir_in;
    }
    return True;
}


impl LayoutPass._base_archetypes(arch: Archetype) -> list[Archetype] {
    """`arch`'s DIRECT bases as their own declarations.

    Resolved through the symbol each base expression already carries, so an
    imported base resolves to the archetype that actually declares it. The
    old path matched base expressions against a bare-name map of the current
    module, which silently dropped a base declared elsewhere and silently
    accepted an unrelated class of the same name.
    """;
    out: list[Archetype] = [];
    for base_expr in (arch.base_classes or []) {
        anc = base_declaration(base_expr);
        if anc is None {
            bname = base_expr_name(base_expr);
            anc = sibling_archetype(arch, bname) if bname else None;
        }
        if (
            anc is not None
            and anc is not arch
            and anc not in out
            and self._lays_out(anc)
        ) {
            out.append(anc);
        }
    }
    return out;
}

impl LayoutPass._discover_closure(arch_map: dict[str, Archetype]) -> None {
    """Record every archetype that is somebody's base, across the closure.

    `_build_layout` needs to know whether anything dispatches through a
    class BEFORE it assigns that class's header, because a vtable pointer
    occupies slot 0 and moves every field behind it. Answering from the
    current module could not see a subclass declared elsewhere, so a base
    came out flat, its subclass came out with a vtable, their headers
    disagreed, and `adopt_imported_bases` was left to reconcile two layouts
    that had already been assigned. Walking the closure first makes the
    question answerable at the point it is asked.
    """;
    stack: list[Archetype] = list(arch_map.values());
    seen: set[str] = set();
    while stack {
        arch = stack.pop();
        aid = archetype_id(arch);
        if aid in seen {
            continue;
        }
        seen.add(aid);
        self._closure_archs[aid] = arch;
        for anc in self._ancestor_archetypes(arch) {
            anc_aid = archetype_id(anc);
            self._base_aids.add(anc_aid);
            stack.append(anc);
        }
        for base in self._base_archetypes(arch) {
            self._base_aids.add(archetype_id(base));
            stack.append(base);
        }
    }
}

impl LayoutPass._collect_archetypes(module: Module) -> dict[str, Archetype] {
    arch_map: dict[str, Archetype] = {};
    for nd in module.get_all_sub_nodes(Archetype) {
        aname = nd.name.value if nd.name else None;
        if aname is None {
            continue;
        }

        if aname not in arch_map or nd.body is not None {
            arch_map[aname] = nd;
        }
    }
    return arch_map;
}

impl LayoutPass._collect_isinstance_targets(module: Module) -> None {
    import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
    import from jaclang.jac0core.constant { CodeContext }
    calls: list = [];
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, FuncCall) {
            calls.append(stmt);
        }
        calls.extend(stmt.get_all_sub_nodes(typ=FuncCall));
    }
    for call in calls {
        tgt = call.target;
        if not (isinstance(tgt, Name) and tgt.value == "isinstance") {
            continue;
        }
        params = call.params or [];
        if len(params) < 2 {
            continue;
        }
        type_arg = params[1];
        cands: list = [];
        if isinstance(type_arg, TupleVal) {
            for v in (type_arg.values or []) {
                cands.append(v);
            }
        } else {
            cands.append(type_arg);
        }
        for c in cands {
            if isinstance(c, Name) {
                self.isinstance_targets.add(c.value);
            }
        }
    }
}


impl LayoutPass._build_layout(
    arch: Archetype, aid: str, ancestors: list[ArchetypeLayout]
) -> ArchetypeLayout {
    """Assign an archetype's header and field slots.

    `ancestors` is the class's linearization, already laid out -- callers
    reach here through `_ensure_layout`, which builds ancestors first.

    `needs_vtable` asks one question -- is anything dispatched through this
    class -- and asks it of the whole closure. It used to also ask
    `bool(parents)` ("do I have a base"), which is a property of the
    declaration and says nothing about dispatch, while the dispatch half
    could only see the current module. A base whose only subclass lived
    elsewhere was nobody's base in its own registry and came out flat; its
    child, merely for having a base, took a vtable pointer in slot 0, every
    inherited field shifted by one, and `headers_agree` refused the pair.

    The dispatch question is now asked of the whole closure, so a base with
    a subclass anywhere is recognised as one -- exactly as a base with a
    same-module subclass always was. `inherits_vtable` carries the header
    down, so a subclass never has a narrower header than the ancestor whose
    field indices it adopts.
    """;
    aname = arch.name.value if arch.name else "unknown";
    mro: list[str] = [aid];
    for anc_lay in ancestors {
        mro.append(anc_lay.aid);
    }
    parents: list[str] = [];
    for base in self._base_archetypes(arch) {
        parents.append(archetype_id(base));
    }

    arch_type_str = arch.arch_kind or "object";
    is_osp = arch.arch_kind is not None;

    vtable_by_dispatch = (
        is_osp or aid in self._base_aids or aname in self.isinstance_targets
    );
    inherits_vtable = False;
    for anc_lay in ancestors {
        if anc_lay.has_vtable {
            inherits_vtable = True;
            break;
        }
    }
    needs_vtable = bool(parents) or vtable_by_dispatch or inherits_vtable;

    fields: list[FieldInfo] = [];
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

    for ancestor_layout in ancestors {
        parent_field_start[ancestor_layout.aid] = current_idx;

        for finfo in ancestor_layout.fields {
            if finfo.name in seen_fields {
                continue;
            }
            seen_fields.add(finfo.name);
            new_field = FieldInfo(
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
        new_field = FieldInfo(
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

    return ArchetypeLayout(
        name=aname,
        arch_type=arch_type_str,
        decl_mod=arch_decl_module(arch),
        aid=aid,
        parents=parents,
        mro=mro,
        fields=fields,
        field_index=field_index,
        has_vtable=needs_vtable,
        vtable_by_dispatch=vtable_by_dispatch,
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
        if ename is None or ename in self.registry.enums or nd.body is None {
            continue;
        }
        raw_members: list[tuple[(str, (UniNode | None))]] = [];
        for stmt in nd.body {
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

impl LayoutPass._build_vtable_layout(aid: str) -> None {
    """Order this class's vtable slots, ancestors' methods first.

    The MRO walked here is the class's own linearization, held as aids, and
    every ancestor's declaration is available from the closure map -- so a
    method inherited from an imported base gets its slot from the same walk
    as a local one. `owner` stays a bare name because it names a symbol.
    """;
    reg = self.registry;
    layout_obj = reg.layouts.get(aid);
    if layout_obj is None {
        return;
    }
    arch_name = layout_obj.name;
    method_list: list[str] = [];
    seen_methods: set[str] = set();
    mro = list(layout_obj.mro);

    for ancestor_aid in mro[1:] {
        ancestor_layout = reg.layouts.get(ancestor_aid);
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

    arch = self._closure_archs.get(aid) or arch_map.get(arch_name);
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
            check_lay = reg.layouts.get(check_name);
            check_arch = self._closure_archs.get(check_name);
            if check_arch is None {
                continue;
            }
            found = False;
            for method in check_arch.get_methods() {
                mn = method.name_ref.sym_name if method.name_ref else None;
                if mn == mname {
                    sig_node = method.signature;
                    owner = check_lay.name if check_lay is not None else arch_name;
                    found = True;
                    break;
                }
            }
            if not found {
                for (slot_name, _var, acc) in archetype_accessors(check_arch) {
                    if slot_name == mname {
                        sig_node = acc.signature;
                        owner = check_lay.name if check_lay is not None else arch_name;
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

impl LayoutPass._acyclic_walk(aid: str, state: dict[str, int]) -> int {
    resolved = self.registry.resolve_id(aid);
    name = resolved if resolved is not None else aid;
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
            key = tb.mangle();
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
    import from jaclang.compiler.passes.main.layout_pass { LAYOUT_COMPATIBLE_SCALARS }
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


impl LayoutRegistry.resolve_id(name: str) -> (str | None) {
    """An aid for `name`, which may already be one.

    Consumers that only hold a bare name -- a mangled type key, a symbol
    spelling -- resolve through here. When a bare name has more than one
    declaration the first registered wins, and registration order is the
    linearization order, so the answer is at least deterministic; before, it
    followed whichever module compiled first. `collisions` records every such
    name so those call sites can be given real identity.
    """;
    if name in self.layouts {
        return name;
    }
    ids = self.name_index.get(name);
    if not ids {
        return None;
    }
    return ids[0];
}

impl LayoutRegistry.register(lay: ArchetypeLayout) -> None {
    """Add a layout and refresh the derived bare-name views.""";
    if self.frozen {
        raise RuntimeError(f"class model is frozen; cannot register {lay.aid}");
    }
    if lay.aid in self.layouts {
        return;
    }
    self.layouts[lay.aid] = lay;
    ids = self.name_index.get(lay.name);
    if ids is None {
        self.name_index[lay.name] = [lay.aid];
    } else {
        ids.append(lay.aid);
        self.collisions[lay.name] = list(ids);
    }
    self.topo_order.append(lay.aid);
    if lay.name not in self.mro_order {
        names: list[str] = [];
        for anc_aid in lay.mro {
            anc = self.layouts.get(anc_aid);
            names.append(anc.name if anc is not None else anc_aid);
        }
        self.mro_order[lay.name] = names;
    }
    if lay.parents and lay.name not in self.class_parents {
        pnames: list[str] = [];
        for p_aid in lay.parents {
            p = self.layouts.get(p_aid);
            pnames.append(p.name if p is not None else p_aid);
        }
        self.class_parents[lay.name] = pnames;
    }
}

impl LayoutRegistry.freeze -> None {
    """Seal the model. Codegen reads it; nothing rewrites it.

    Layout objects used to be shared across per-module registries and
    mutated in place after assignment, so compiling one module could move a
    field under another. A model that anything can rewrite is not a source
    of truth.
    """;
    self.frozen = True;
}

impl LayoutRegistry.get_layout(name: str) -> (ArchetypeLayout | None) {
    aid = self.resolve_id(name);
    return self.layouts.get(aid) if aid is not None else None;
}

impl LayoutRegistry.get_mro(name: str) -> list[str] {
    lay = self.get_layout(name);
    if lay is None {
        return [name];
    }
    return list(self.mro_order.get(lay.name, [lay.name]));
}

impl LayoutRegistry.get_topo_order -> list[str] {
    """Registration order, which IS dependency order.

    `register` is only reached from `_ensure_layout`, which builds a class's
    ancestors before the class. The old field was a per-module topological
    sort that said nothing about imported classes.
    """;
    names: list[str] = [];
    for aid in self.topo_order {
        lay = self.layouts.get(aid);
        if lay is not None {
            names.append(lay.name);
        }
    }
    return names;
}

impl LayoutRegistry.resolve_method_owner(
    arch_name: str, method_name: str
) -> (str | None) {
    lay = self.get_layout(arch_name);
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

impl LayoutRegistry.is_primary_ancestor(child: str, ancestor: str) -> bool {
    anc_lay = self.get_layout(ancestor);
    anc_aid = anc_lay.aid if anc_lay is not None else None;
    cur = self.get_layout(child);
    while cur is not None and cur.parents {
        primary_aid = cur.parents[0];
        if anc_aid is not None and primary_aid == anc_aid {
            return True;
        }
        cur = self.layouts.get(primary_aid);
    }
    return False;
}

impl LayoutRegistry.get_enum_layout(name: str) -> (EnumLayout | None) {
    return self.enums.get(name);
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
            self.emit(W5031, node_override=var, arch=aname, field=fname);
            continue;
        }
        type_node = var.type_tag.tag;
        if not self._is_layout_compatible_type(type_node, arch_map) {
            type_str = unparse_node(type_node) or str(type_node);
            self.emit(W5032, node_override=var, arch=aname, field=fname, type=type_str);
        }
    }
}

impl LayoutPass._is_layout_compatible_type(
    type_node: (UniNode | None), arch_map: dict[str, Archetype]
) -> bool {
    import from jaclang.compiler.passes.main.layout_pass { LAYOUT_COMPATIBLE_SCALARS }
    if type_node is None {
        return False;
    }
    if isinstance(type_node, FuncSignature) {
        return True;
    }

    if isinstance(type_node, UnaryExpr) and type_node.ownership != OwnershipKind.NONE {
        return self._is_layout_compatible_type(type_node.operand, arch_map);
    }

    if isinstance(type_node, Name) {
        tname = type_node.value;
        if tname in LAYOUT_COMPATIBLE_SCALARS {
            return True;
        }
        if tname == "None" {
            return True;
        }

        if tname in arch_map {
            return True;
        }

        if tname in self.registry.layouts {
            return True;
        }

        return False;
    }

    if BuiltinType and isinstance(type_node, BuiltinType) {
        tname = type_node.value;
        return tname in LAYOUT_COMPATIBLE_SCALARS;
    }

    if isinstance(type_node, BinaryExpr) {
        op_val = getattr(type_node.op, 'value', '');
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

        if target_name == "type" {
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

    if isinstance(type_node, Name) {
        tname = type_node.value;
        if tname in LAYOUT_COMPATIBLE_SCALARS {
            return True;
        }
        if tname in arch_map {
            return True;
        }
        if tname in self.registry.layouts {
            return True;
        }
    }
    return False;
}
