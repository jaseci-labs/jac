"""Centralized Jac Type Registry.

Single source of truth for primitive type information across all compilation
backends (SV/Python, CL/ECMAScript, NA/LLVM). Each entry records what
methods/operators a type supports, which codespaces it's available in,
and how each backend represents it.
"""

"""Backend-specific type representations for a primitive type."""
obj BackendTypeMapping {
    has sv_type: str | None = None,
        cl_type: str | None = None,
        na_llvm_type_spec: str | None = None;
}

"""Signature of a named method on a primitive type."""
obj MethodSignature {
    has name: str,
        return_type_name: str = "None",
        is_static: bool = False;
}

"""Information about an operator supported by a primitive type."""
obj OperatorInfo {
    has op_name: str,
        magic_method: str,
        return_type_name: str = "self";
}

"""A single primitive type entry in the registry."""
obj JacPrimitiveTypeEntry {
    has name: str,
        methods: dict[str, MethodSignature],
        operators: dict[str, OperatorInfo],
        codespace_tags: set[str],
        backend_mappings: BackendTypeMapping,
        emitter_class_name: str,
        inherits_from: str | None = None;
}

"""Central registry of all Jac primitive types."""
obj JacTypeRegistry {
    def init -> None;
    def register(entry: JacPrimitiveTypeEntry) -> None;
    def get(name: str) -> JacPrimitiveTypeEntry | None;
    def get_primitive_names -> set[str];
    def get_type_names_with_emitters -> set[str];
    def has_method(type_name: str, method_name: str) -> bool;
    def get_emitter_class_suffix(type_name: str) -> str;
    def build_na_type_map(ir_mod: object) -> dict[str, object];
    def get_builtin_function_names -> set[str];
    def _populate_primitives -> None;
    def _populate_builtins -> None;
}

glob JAC_TYPE_REGISTRY: JacTypeRegistry = JacTypeRegistry();
