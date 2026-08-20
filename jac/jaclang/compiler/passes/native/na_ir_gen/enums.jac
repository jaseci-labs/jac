import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;

obj NaIRGenEnums(NaIRGenState) {
    def _ensure_enum_lowered(t: any) -> (ir.Type | None);
    def _class_form_enum_self_type(arch_name: str) -> (ir.Type | None);
    def _codegen_class_form_enum_member(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _codegen_enum(nd: (uni.Enum | uni.Archetype)) -> None;
    def _codegen_enum_layout(enum_name: str, owner: (uni.Module | None)) -> None;
    def _enum_ctor_layout(enum_name: str) -> (any | None);
    def _enum_ctor_target(nd: uni.FuncCall) -> (str | None);
    def _emit_enum_ctor_refusal(nd: uni.FuncCall, enum_name: str, why: str) -> None;
    def _codegen_enum_ctor(nd: uni.FuncCall, enum_name: str) -> (ir.Value | None);
    def _build_enum_string_table(
        enum_name: str, entries: list, with_values: bool = True
    ) -> None;

    def _wrap_enum_str(raw: (ir.Value | None)) -> (ir.Value | None);
    def _codegen_enum_value_lookup(
        enum_name: str, ordinal_val: ir.Value, use_name: bool = False
    ) -> (ir.Value | None);

    def _enum_is_string_valued(enum_name: str) -> bool;
    def _enum_ordinal_fn(enum_name: str) -> (ir.Function | None);
    def _codegen_enum_ordinal_of(
        enum_name: str, runtime_val: ir.Value
    ) -> (ir.Value | None);

    def _codegen_enum_attr_runtime(
        enum_name: str, runtime_val: ir.Value, use_name: bool
    ) -> (ir.Value | None);
}
