import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.passes.transform { Transform }
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

obj FieldInfo {
    has name: str,
        index: int,
        type_tag: str,
        type_node: (uni.UniNode | None) = None,
        default_expr: (uni.UniNode | None) = None,
        owner: str = "",
        is_func_ptr: bool = False,
        decl_node: (uni.UniNode | None) = None;
}

obj MethodSlot {
    has name: str,
        index: int,
        owner: str,
        signature: (uni.UniNode | None) = None;
}

obj ArchetypeLayout {
    has name: str,
        arch_type: str,
        parents: list[str] = [],
        mro: list[str] = [],
        fields: list[FieldInfo] = [],
        field_index: dict[str, int] = {},
        methods: list[MethodSlot] = [],
        method_index: dict[str, int] = {},
        has_vtable: bool = False,
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
        members: list[EnumMemberLayout] = [];
}

def get_layout_registry(module: uni.Module, prog: any = None) -> LayoutRegistry {
    reg = module.gen.layout_registry;
    if reg is not None {
        return reg;
    }

    pass_inst = LayoutPass(ir_in=module, prog=prog);
    return module.gen.layout_registry or LayoutRegistry();
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

def enum_decl_of(t: any) -> (uni.Enum | uni.Archetype | None) {
    if not is_enum_class_type(t) {
        return None;
    }
    _scope = t.shared.symbol_table;
    if isinstance(_scope, uni.Enum) {
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
    if not isinstance(t.shared.symbol_table, uni.Archetype) {
        return None;
    }
    _vt = t.shared.enum_value_type;
    if _vt is None or not (_vt?.shared) {
        return None;
    }
    _vname = _vt.shared.class_name;
    return _vname if _vname in ("str", "int") else None;
}

def class_form_enum_decls(module: uni.Module) -> list[uni.Archetype] {
    out: list[uni.Archetype] = [];
    for nd in UniPass.get_all_sub_nodes(module, uni.Archetype) {
        if nd.name is None {
            continue;
        }
        if class_form_enum_scalar(nd.name.type) is not None {
            out.append(nd);
        }
    }
    return out;
}

def class_form_enum_literal(t: any, member: str) -> (str | int | None) {
    _scope = t.shared.symbol_table;
    _sym = _scope.names_in_scope.get(member) if (_scope?.names_in_scope) else None;
    _decl = _sym.decl if _sym is not None else None;
    _asn = _decl.parent if (_decl is not None) else None;
    if not isinstance(_asn, uni.Assignment) or _asn.value is None {
        return None;
    }
    _v = _asn.value;
    if isinstance(_v, (uni.String, uni.MultiString, uni.Int)) {
        return _v.lit_value;
    }
    return None;
}

def class_form_enum_member(t: any) -> (tuple | None) {
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
        mro_order: dict[str, list[str]] = {},
        topo_order: list[str] = [],
        enums: dict[str, EnumLayout] = {};

    def get_layout(name: str) -> (ArchetypeLayout | None);
    def get_enum_layout(name: str) -> (EnumLayout | None);
    def resolve_method_owner(arch_name: str, method_name: str) -> (str | None);
    def get_mro(name: str) -> list[str];
    def get_topo_order -> list[str];
    def is_primary_ancestor(child: str, ancestor: str) -> bool;
}

obj LayoutPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None,
        registry: LayoutRegistry postinit,
        isinstance_targets: set[str] postinit;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _collect_archetypes(module: uni.Module) -> dict[str, uni.Archetype];
    def _collect_isinstance_targets(module: uni.Module) -> None;
    def _build_hierarchy(archetypes: dict[str, uni.Archetype]) -> None;
    def _compute_c3_mro(class_name: str) -> list[str];
    def _topo_sort(arch_map: dict[str, uni.Archetype]) -> list[str];
    def _build_layout(arch: uni.Archetype) -> ArchetypeLayout;
    def _build_enum_layouts(module: uni.Module) -> None;
    def _compute_acyclicity -> None;
    def _acyclic_walk(name: str, state: dict[str, int]) -> int;
    def _expand_type_keys(key: str) -> (list[str] | None);
    def _split_top_level(s: str, sep: str) -> list[str];
    def _build_vtable_layout(
        arch_name: str, arch_map: dict[str, uni.Archetype]
    ) -> None;

    def _validate_obj_fields(
        arch: uni.Archetype, arch_map: dict[str, uni.Archetype]
    ) -> None;

    def _is_layout_compatible_type(
        type_node: (uni.UniNode | None), arch_map: dict[str, uni.Archetype]
    ) -> bool;
}
