"""Global variable and enum registration for native compilation."""
"""Walk the module and register all native enum types."""
impl NaIRGenPass._register_enums(module: uni.Module) -> None {
    for stmt in module.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                if isinstance(inner, uni.Enum) {
                    self._codegen_enum(inner);
                }
            }
        } elif isinstance(stmt, uni.Enum) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                self._codegen_enum(stmt);
            }
        }
    }
}
