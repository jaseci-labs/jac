glob LAYOUT_COMPATIBLE_PRIMITIVES: set[str] = {
         "int",
         "float",
         "bool",
         "str",
         "bytes"
     }
         | set(JAC_TYPE_REGISTRY.sized_scalar_names()),
     VTABLE_HEADER_SLOTS: int = 3,
     VTABLE_DROP_SLOT: int = 2,
     EXC_MESSAGE_FIELD: str = "__jac_exc_msg__";

glob LAYOUT_COMPATIBLE_SCALARS: set[str] = LAYOUT_COMPATIBLE_PRIMITIVES | {"type"};

obj FieldLayout {
    has name: str,
        index: int,
        type_tag: str,
        type_node: (UniNode | None) = None,
        default_expr: (UniNode | None) = None,
        owner: str = "",
        is_func_ptr: bool = False,
        decl_node: (HasVar | TypeParam | None) = None;

    has semantic_type: TypeBase | None { getter; }
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
        fields: list[FieldLayout] = [],
        field_index: dict[str, int] = {},
        methods: list[MethodSlot] = [],
        method_index: dict[str, int] = {},
        has_vtable: bool = False,
        vtable_by_dispatch: bool = False,
        vtable_by_isinstance_only: bool = False,
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

def accessor_slot_name(field_name: str, acc: Ability) -> (str | None);

def archetype_accessors(arch: Archetype) -> list[tuple[(str, HasVar, Ability)]];

glob NON_DISPATCHED_METHODS: frozenset[str] = frozenset(
         {"init", "postinit", "__init__", "__post_init__", "drop"}
     );

def open_dispatch(arch: Archetype) -> bool;

def get_layout_registry(module: Module, prog: JacProgram) -> LayoutRegistry;

def layout_slot_count(lay: ArchetypeLayout) -> int;

glob _NATIVE_NAME_BY_DECL: dict[tuple[str, int, int, str], str] = {},
     _NATIVE_NAMED_CLASSES: set[str] = set(),
     _NATIVE_NAME_BY_STDLIB: dict[tuple[str, str], str] = {};

def archetype_native_name(arch: Archetype) -> str;

def record_interface_twins(native_mod: Module, prog: JacProgram);

def _archetype_native_name(arch: Archetype, name: str) -> str;

def _recorded_native_name(shared: ClassDetailsShared) -> (str | None);

def _declared_native_name(shared: ClassDetailsShared) -> str;

def referenced_archetype(expr: (UniNode | None)) -> (Archetype | None);

def referenced_native_name(expr: (UniNode | None)) -> (str | None);

def class_type_native_name(typ: (TypeBase | None)) -> (str | None);

def interface_class_native_name(shared: ClassDetailsShared) -> str;

def native_type_key(typ: TypeBase) -> str;

def declaring_module_path(base_expr: Expr) -> str;

def headers_agree(child: ArchetypeLayout, base: ArchetypeLayout) -> bool;

def relax_vtable_header(
    lay: ArchetypeLayout, ancestors: list[ArchetypeLayout], header_identity: bool = True
) -> bool;

def extended_mro(reg: LayoutRegistry, lay: ArchetypeLayout) -> list[str];

def adopt_imported_bases(module: Module, header_identity: bool = True) -> list[str];

def adopt_ancestor_slots(lay: ArchetypeLayout, ancestors: list[ArchetypeLayout]);

def clone_field(finfo: FieldLayout, index: int) -> FieldLayout;

def adopt_ancestor_methods(lay: ArchetypeLayout, ancestors: list[ArchetypeLayout]);

def is_erased_base_name(name: str, archetypes: dict[str, Archetype]) -> bool;

def enum_class_of(t: (TypeBase | None)) -> (ClassType | None);

def is_enum_class_type(t: (TypeBase | None)) -> bool;

def enum_decl_of(t: (TypeBase | None)) -> (Enum | Archetype | None);

def enum_value_type_of(t: (TypeBase | None)) -> (TypeBase | None);

def class_form_enum_scalar(t: (TypeBase | None)) -> (str | None);

def class_form_enum_decls(module: Module) -> list[Archetype];

def enum_member_literal(value_expr: (UniNode | None)) -> (str | int | None);

def is_enum_auto(value_expr: (UniNode | None)) -> bool;

def resolve_enum_member_values(
    raw_members: list[tuple[(str, (UniNode | None))]]
) -> list[(str | int | None)];

def class_form_enum_members(
    scope: (UniScopeNode | None)
) -> list[tuple[(str, (UniNode | None))]];

def class_form_enum_literal(t: ClassType, member: str) -> (str | int | None);

def class_form_enum_member(
    t: (TypeBase | None)
) -> (tuple[(str, (str | int), str)] | None);

obj LayoutRegistry {
    has layouts: dict[str, ArchetypeLayout] = {},
        class_parents: dict[str, list[str]] = {},
        parent_mods: dict[str, list[str]] = {},
        mro_order: dict[str, list[str]] = {},
        topo_order: list[str] = [],
        local_names: list[str] = [],
        enums: dict[str, EnumLayout] = {},
        _descendants: (dict[str, list[str]] | None) = None;

    def get_layout(name: str) -> (ArchetypeLayout | None);
    def set_mro(name: str, mro: list[str]) -> None;
    def descendants_of(names: list[str]) -> list[str];
    def get_enum_layout(name: str) -> (EnumLayout | None);
    def resolve_method_owner(arch_name: str, method_name: str) -> (str | None);
    def get_mro(name: str) -> list[str];
    def get_topo_order -> list[str];
    def dependency_order(names: list[str]) -> list[str];
    def is_primary_ancestor(child: str, ancestor: str) -> bool;
}

walker LayoutPass(CompilerPass) {
    static has contract: PassContract = PassContract();
    has registry: LayoutRegistry postinit,
        isinstance_targets: set[str] postinit;

    def postinit -> None;
    def _run_impl(ir_in: Module) -> Module;
    can run_walk with Module entry;
    def _type_declaration_surface(module: Module) -> None;
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
    def _is_layout_compatible_semantic_type(typ: TypeBase | None) -> bool;
    def _is_layout_compatible_type(
        type_node: (UniNode | None), arch_map: dict[str, Archetype]
    ) -> bool;
}
