import from collections.abc { Sequence }
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

     };

obj FieldInfo {
    has name: str,
        index: int,
        type_tag: str,
        type_node: (uni.UniNode | None) = None,
        default_expr: (uni.UniNode | None) = None,
        owner: str = "",
        is_func_ptr: bool = False;
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
        parent_field_start: dict[str, int] = {};
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
        topo_order: list[str] = [];

    def get_layout(name: str) -> (ArchetypeLayout | None);
    def get_mro(name: str) -> list[str];
    def get_topo_order -> list[str];
    def get_field_index(class_name: str, field_name: str) -> (int | None);
    def get_method_slot(class_name: str, method_name: str) -> (int | None);
    def is_subclass(child: str, parent: str) -> bool;
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
