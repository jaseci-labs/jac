import from jaclang.compiler.passes.layout_pass { VTABLE_HEADER_SLOTS }
import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.codeinfo { HDR_RC_OFF, HDR_TAG_OFF, RC_SENTINEL }
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenVtable(NaIRGenState) {
    def _build_vtable(arch_name: str) -> None;
    def _emit_vtable_global(arch_name: str) -> None;
    def _vtable_global_for(arch_name: str) -> (ir.GlobalVariable | None);
    def _vtable_symbol(arch_name: str) -> str;
    def _vtable_candidates(names: list[str]) -> list[ir.GlobalVariable];
    def _isinstance_needs_class_name(names: list[str]) -> bool;
    def _isinstance_unprovable_class(
        names: list[str], operand_arch: (str | None)
    ) -> (str | None);

    def _isinstance_class_name_hit(
        obj_ptr: ir.Value, names: list[str]
    ) -> (ir.Value | None);

    def _emit_class_name_const(arch_name: str) -> ir.Value;
    def _emit_runtime_class_name_fn -> (ir.Function | None);
    def _codegen_runtime_class_name(obj_val: ir.Value) -> (ir.Value | None);
    def _codegen_class_name(nd: uni.AtomTrailer) -> (ir.Value | None);
    def _codegen_class_id(receiver: uni.UniNode) -> (ir.Value | None);
    def _class_id_of_value(arch_name: str, obj_val: ir.Value) -> ir.Value;
    def _codegen_class_ref(nd: uni.Name) -> (ir.Value | None);
    def _is_enum_arch(name: str) -> bool;
    def _emit_isa_fn -> ir.Function;
    def _emit_isa_seq_fn -> ir.Function;
    def _is_runtime_class_tuple(t: any) -> bool;
    def _runtime_class_value(expr: (uni.UniNode | None)) -> (ir.Value | None);
    def _runtime_class_arms(expr: (uni.UniNode | None)) -> tuple;
    def _isinstance_operand_arch(nd: uni.FuncCall, operand: ir.Value) -> (str | None);
    def _emit_isinstance_runtime(
        nd: uni.FuncCall, operand: ir.Value, type_arg: uni.UniNode
    ) -> (ir.Value | None);

    def _codegen_virtual_call(
        obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
    ) -> (ir.Value | None);

    def _generate_inherited_method_wrappers -> None;
}
