"""Type layout analysis pass for the Jac compiler.

Computes class hierarchy, C3 MRO, field layout, and vtable structure
for all archetypes in a module. Results are stored in a LayoutRegistry
that all backends (Python, ES, Native/LLVM) can query.

Runs after SemanticAnalysisPass (needs resolved symbols) and before
codegen passes.
"""
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.diagnostics { E5030, W5031, W5032 }

"""Set of primitive type names that have a known, fixed-size native layout.

obj fields must resolve to one of these, another obj, an enum, a typed
collection (list[T], dict[K,V], set[T]) where element types are also
layout-compatible, or a callable with explicit signature (function pointer).
"""
glob LAYOUT_COMPATIBLE_PRIMITIVES: set[str] = {"int","float","bool","str","bytes","i8","u8","i16","u16","i32","u32","i64","u64","f32","f64",};

"""Per-field layout descriptor."""
obj FieldInfo {
    has name: str,
        index: int,
        type_tag: str,
        type_node: (uni.UniNode | None) = None,
        default_expr: (uni.UniNode | None) = None,
        owner: str = "",
        is_func_ptr: bool = False;
}

"""Per-method descriptor for vtable layout."""
obj MethodSlot {
    has name: str,
        index: int,
        owner: str,
        signature: (uni.UniNode | None) = None;
}

"""Complete layout for one archetype/class."""
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

"""Get or compute the layout registry for a module.

Backends call this lazily instead of LayoutPass being in the schedule.
Avoids re-entrancy issues with the self-hosting compiler bootstrap.
"""
def get_layout_registry(module: uni.Module, prog: Any = None) -> LayoutRegistry {
    reg = module.gen.layout_registry;
    if reg is not None {
        return reg;
    }
    # Compute lazily
    pass_inst = LayoutPass(ir_in=module, prog=prog);
    return module.gen.layout_registry or LayoutRegistry();
}

"""Module-level layout registry."""
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

"""Layout analysis pass."""
obj LayoutPass(UniPass) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None;
    def before_pass -> None;
    # Core analysis
    def _collect_archetypes(module: uni.Module) -> dict[str, uni.Archetype];
    def _build_hierarchy(archetypes: dict[str, uni.Archetype]) -> None;
    def _compute_c3_mro(class_name: str) -> list[str];
    def _topo_sort(arch_map: dict[str, uni.Archetype]) -> list[str];
    def _build_layout(arch: uni.Archetype) -> ArchetypeLayout;
    def _build_vtable_layout(
        arch_name: str, arch_map: dict[str, uni.Archetype]
    ) -> None;
    # Field type validation for obj archetypes (CType struct contract)
    def _validate_obj_fields(
        arch: uni.Archetype, arch_map: dict[str, uni.Archetype]
    ) -> None;

    def _is_layout_compatible_type(
        type_node: (uni.UniNode | None), arch_map: dict[str, uni.Archetype]
    ) -> bool;
}
