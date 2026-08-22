import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    BinaryExpr,
    BuiltinType,
    Enum,
    FuncCall,
    FuncSignature,
    HasVar,
    IndexSlice,
    Module,
    ModuleItem,
    Name,
    TupleVal,
    UnaryExpr,
    UniNode
}
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.const_fold { fold_const }
import from jaclang.jac0core.constant { OwnershipKind, Tokens as Tok }
import from jaclang.jac0core.diagnostics { E5030, W5031, W5032 }

glob LAYOUT_COMPATIBLE_PRIMITIVES: set[str] = {
         "int",
         "float",
         "bool",
         "str",
         "bytes",
         "i8",
         "u8",
         "i16",
         "u16",
         "i32",
         "u32",
         "i64",
         "u64",
         "f32",
         "f64",

     },
     VTABLE_HEADER_SLOTS: int = 1;

glob LAYOUT_COMPATIBLE_SCALARS: set[str] = LAYOUT_COMPATIBLE_PRIMITIVES | {"type"};

obj FieldInfo {
    has name: str,
        index: int,
        type_tag: str,
        type_node: (UniNode | None) = None,
        default_expr: (UniNode | None) = None,
        owner: str = "",
        is_func_ptr: bool = False,
        decl_node: (UniNode | None) = None;
}

obj MethodSlot {
    has name: str,
        index: int,
        owner: str,
        signature: (UniNode | None) = None;
}

obj ArchetypeLayout {
    has name: str,
        arch_type: str,
        decl_mod: str = "",
        parent_mods: list[str] = [],
        parents: list[str] = [],
        mro: list[str] = [],
        fields: list[FieldInfo] = [],
        field_index: dict[str, int] = {},
        methods: list[MethodSlot] = [],
        method_index: dict[str, int] = {},
        has_vtable: bool = False,
        vtable_by_dispatch: bool = False,
        parent_field_start: dict[str, int] = {},
        is_osp: bool = False,
        is_acyclic: bool = False,
        vtable_ptr_slot: (int | None) = None,
        type_tag_slot: (int | None) = None,
        reports_slot: (int | None) = None;
}

obj EnumMemberLayout {
    has name: str,
        ordinal: int,
        int_value: int = 0,
        str_value: (str | None) = None;
}

obj EnumLayout {
    has name: str,
        underlying: str = "i64",
        is_string_enum: bool = False,
        is_class_form: bool = False,
        all_values_known: bool = True,
        members: list[EnumMemberLayout] = [];
}

glob ACCESSOR_SLOT_SUFFIX: dict[str, str] = {
         "property": "__get__",
         "setter": "__set__",
         "deleter": "__del__"
     };

def accessor_slot_name(field_name: str, acc: Ability) -> (str | None) {
    suffix = ACCESSOR_SLOT_SUFFIX.get(acc.accessor_kind);
    return None if suffix is None else f"{field_name}.{suffix}";
}

def archetype_accessors(arch: Archetype) -> list[tuple[(str, HasVar, Ability)]] {
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

def get_layout_registry(module: Module, prog: any = None) -> LayoutRegistry {
    reg = module.gen.layout_registry;
    if reg is not None {
        return reg;
    }

    import from jaclang.jac0core.compiler { run_pass }
    run_pass(LayoutPass, module, prog);
    return module.gen.layout_registry or LayoutRegistry();
}

def layout_slot_count(lay: ArchetypeLayout) -> int {
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

def declaring_module_path(base_expr: UniNode) -> str {
    import os;
    sym = base_expr?.sym;
    decl = sym.decl if sym is not None else None;
    if decl is None {
        return "";
    }
    base_arch = decl.find_parent_of_type(Archetype);
    if base_arch is None {
        return "";
    }
    decl_mod = decl.find_parent_of_type(Module);
    path = decl_mod.loc.mod_path if decl_mod?.loc else None;
    return os.path.realpath(path) if path else "";
}

def headers_agree(child: ArchetypeLayout, base: ArchetypeLayout) -> bool {
    return child.vtable_ptr_slot == base.vtable_ptr_slot
        and child.type_tag_slot == base.type_tag_slot
        and child.reports_slot == base.reports_slot;
}

def relax_vtable_header(
    lay: ArchetypeLayout, ancestors: list[ArchetypeLayout]
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

    Every ancestor is checked, not just the primary: relaxing a child whose
    grandparent carries a header would trade one disagreement for another.
    A class that IS dispatched through keeps its header and its refusal --
    that pair genuinely has no assignment satisfying both.
    """;
    if lay.is_osp or lay.vtable_by_dispatch or not lay.has_vtable {
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

def extended_mro(reg: LayoutRegistry, lay: ArchetypeLayout) -> list[str] {
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

def adopt_imported_bases(module: Module) -> list[str] {
    reg = module.gen.layout_registry;
    if reg is None {
        return [];
    }
    for (name, lay) in reg.layouts.items() {
        full = extended_mro(reg, lay);
        if len(full) > len(lay.mro or []) {
            lay.mro = full;
            reg.mro_order[name] = list(full);
        }
    }
    order = sorted(
        reg.layouts.keys(), key=lambda (n: str) { len(reg.layouts[n].mro or [n]); }
    );
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
        if not absent {
            continue;
        }
        if not headers_agree(lay, ancestors[0])
            and not relax_vtable_header(lay, ancestors) {
            continue;
        }
        adopt_ancestor_slots(lay, ancestors);
        adopted.append(name);
    }
    return adopted;
}

def adopt_ancestor_slots(lay: ArchetypeLayout, ancestors: list[ArchetypeLayout]) {
    primary = ancestors[0];
    fields: list[FieldInfo] = [];
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
    lay.fields = sorted(fields, key=lambda (f) { f.index; });
    lay.field_index = field_index;
    lay.parent_field_start = parent_field_start;
    adopt_ancestor_methods(lay, ancestors);
    for anc_lay in ancestors {
        lay.is_acyclic = lay.is_acyclic and anc_lay.is_acyclic;
    }
}

def clone_field(finfo: FieldInfo, index: int) -> FieldInfo {
    return FieldInfo(
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

def adopt_ancestor_methods(lay: ArchetypeLayout, ancestors: list[ArchetypeLayout]) {
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

def is_erased_base_name(name: str, archetypes: dict[str, Archetype]) -> bool {
    import from jaclang.jac0core.codeinfo { NATIVE_ERASED_BASES }
    return name in NATIVE_ERASED_BASES and name not in archetypes;
}

def is_enum_class_type(t: any) -> bool {
    try {
        import from jaclang.compiler.type_system.types { ClassType as _ClassType }
    } except ImportError {
        return False;
    }
    return isinstance(t, _ClassType)
        and t._shared is not None
        and t.shared.is_enum_class;
}

def enum_decl_of(t: any) -> (Enum | Archetype | None) {
    if not is_enum_class_type(t) {
        return None;
    }
    _scope = t.shared.symbol_table;
    if isinstance(_scope, Enum) {
        return _scope;
    }
    return _scope if class_form_enum_scalar(t) is not None else None;
}

def enum_value_type_of(t: any) -> (any | None) {
    return t.shared.enum_value_type if is_enum_class_type(t) else None;
}

def class_form_enum_scalar(t: any) -> (str | None) {
    if not is_enum_class_type(t) {
        return None;
    }
    if not isinstance(t.shared.symbol_table, Archetype) {
        return None;
    }
    _vt = t.shared.enum_value_type;
    if _vt is None or not (_vt?.shared) {
        return None;
    }
    _vname = _vt.shared.class_name;
    return _vname if _vname in ("str", "int") else None;
}

def class_form_enum_decls(module: Module) -> list[Archetype] {
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

def enum_member_literal(value_expr: (UniNode | None)) -> (str | int | None) {
    (folded, val) = fold_const(value_expr);
    if not folded or isinstance(val, bool) or not isinstance(val, (str, int)) {
        return None;
    }
    return val;
}

def is_enum_auto(value_expr: (UniNode | None)) -> bool {
    if not isinstance(value_expr, FuncCall) or value_expr.params {
        return False;
    }
    _target = value_expr.target;
    if not isinstance(_target, Name) {
        return False;
    }
    _sym = _target.sym;
    _decl = _sym.decl if _sym is not None else None;
    if _decl is None {
        return False;
    }
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

def resolve_enum_member_values(
    raw_members: list[tuple[(str, (UniNode | None))]]
) -> list[(str | int | None)] {
    out: list[(str | int | None)] = [];
    _max: (int | None) = None;
    _blocked = False;
    for member in raw_members {
        _vnode = member[1];
        if is_enum_auto(_vnode) {
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

def class_form_enum_members(scope: any) -> list[tuple[(str, (UniNode | None))]] {
    out: list[tuple[(str, (UniNode | None))]] = [];
    if scope is None or not (scope?.names_in_scope) {
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

def class_form_enum_literal(t: any, member: str) -> (str | int | None) {
    _members = class_form_enum_members(t.shared.symbol_table);
    _values = resolve_enum_member_values(_members);
    for (_idx, _member) in enumerate(_members) {
        if _member[0] == member {
            return _values[_idx];
        }
    }
    return None;
}

def class_form_enum_member(t: any) -> (tuple[(str, (str | int), str)] | None) {
    try {
        import from jaclang.compiler.type_system.types {
            EnumMemberType as _EnumMemberType
        }
    } except ImportError {
        return None;
    }
    if not isinstance(t, _EnumMemberType) or t.enum_class is None {
        return None;
    }
    _scalar = class_form_enum_scalar(t.enum_class);
    if _scalar is None or t.member_info is None {
        return None;
    }
    _name = t.member_info.member_name;
    _lit = class_form_enum_literal(t.enum_class, _name);
    if _scalar == "str" and isinstance(_lit, str) {
        return (_scalar, _lit, _name);
    }
    if _scalar == "int" and isinstance(_lit, int) and not isinstance(_lit, bool) {
        return (_scalar, _lit, _name);
    }
    return None;
}

obj LayoutRegistry {
    has layouts: dict[str, ArchetypeLayout] = {},
        class_parents: dict[str, list[str]] = {},
        parent_mods: dict[str, list[str]] = {},
        mro_order: dict[str, list[str]] = {},
        topo_order: list[str] = [],
        local_names: list[str] = [],
        enums: dict[str, EnumLayout] = {};

    def get_layout(name: str) -> (ArchetypeLayout | None);
    def get_enum_layout(name: str) -> (EnumLayout | None);
    def resolve_method_owner(arch_name: str, method_name: str) -> (str | None);
    def get_mro(name: str) -> list[str];
    def get_topo_order -> list[str];
    def is_primary_ancestor(child: str, ancestor: str) -> bool;
}

obj LayoutPass(Transform) {
    has ir_in: Module,
        cancel_token: any = None,
        registry: LayoutRegistry postinit,
        isinstance_targets: set[str] postinit;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _collect_archetypes(module: Module) -> dict[str, Archetype];
    def _collect_isinstance_targets(module: Module) -> None;
    def _build_hierarchy(archetypes: dict[str, Archetype]) -> None;
    def _compute_c3_mro(class_name: str) -> list[str];
    def _topo_sort(arch_map: dict[str, Archetype]) -> list[str];
    def _build_layout(arch: Archetype) -> ArchetypeLayout;
    def _build_enum_layouts(module: Module) -> None;
    def _compute_acyclicity -> None;
    def _acyclic_walk(name: str, state: dict[str, int]) -> int;
    def _expand_type_keys(key: str) -> (list[str] | None);
    def _split_top_level(s: str, sep: str) -> list[str];
    def _build_vtable_layout(arch_name: str, arch_map: dict[str, Archetype]) -> None;
    def _validate_obj_fields(arch: Archetype, arch_map: dict[str, Archetype]) -> None;
    def _is_layout_compatible_type(
        type_node: (UniNode | None), arch_map: dict[str, Archetype]
    ) -> bool;
}
