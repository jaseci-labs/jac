import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.constant { Tokens as Tok }
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
        registry: LayoutRegistry by postinit;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _collect_archetypes(module: uni.Module) -> dict[str, uni.Archetype];
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
