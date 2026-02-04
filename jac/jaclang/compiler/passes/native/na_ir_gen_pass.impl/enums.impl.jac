"""Enum type codegen."""
"""Register an enum type — store each member as an i64 constant."""
impl NaIRGenPass._codegen_enum(<>node: uni.Enum) -> None {
    enum_name = (<>node).name.value if (<>node).name else "unknown_enum";
    self.enum_types[enum_name] = ir.IntType(64);
    self.type_map[enum_name] = ir.IntType(64);
    self.has_native_code = True;
    if (<>node).body is None {
        return;
    }
    for stmt in (<>node).body {
        if isinstance(stmt, uni.Assignment) {
            targets = stmt.target
            if isinstance(stmt.target, (<>list, <>tuple))
            else [stmt.target];
            for target_expr in targets {
                member_name = self._get_name(target_expr);
                if member_name is None {
                    continue;
                }
                # Evaluate the value (should be an integer literal)
                if stmt.value is not None and isinstance(stmt.value, uni.Int) {
                    val = int(stmt.value.value);
                } else {
                    val = 0;
                }
                full_name = f"{enum_name}.{member_name}";
                self.enum_values[full_name] = ir.Constant(ir.IntType(64), val);
            }
        }
    }
}
# ─── Phase 1: AtomTrailer (attribute access) ─────────────────
