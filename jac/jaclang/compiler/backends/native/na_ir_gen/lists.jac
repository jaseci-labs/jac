import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.diagnostics { E5092 }
import jaclang.compiler.frontend.unitree as uni;
import os;
import sys;

obj NaIRGenLists(NaIRGenState) {
    def _spec_from_list_slot_type(t: (ir.Type | None)) -> (str | None);
    def _reflavor_list(
        val: ir.Value, src_spec: str, dst_spec: str
    ) -> (ir.Value | None);

    def _cast_to_list_elem(
        b: any, val: ir.Value, elem_type: ir.Type, name: str
    ) -> ir.Value;

    def _empty_list_dest_spec(nd: uni.ListVal) -> (str | None);
    def _emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None;
    def _emit_aos_list_helpers(tname: str) -> ir.Type;
    def _aos_elem_struct(type_key: str) -> (ir.Type | None);
    def _container_is_view(nd: uni.UniNode) -> bool;
    def _codegen_list_val(nd: uni.ListVal) -> (ir.Value | None);
    def _codegen_index(
        target_val: ir.Value, index_val: ir.Value, elem_type_name: str
    ) -> (ir.Value | None);

    def _codegen_any_subscript(
        jacval: ir.Value, key_val: ir.Value
    ) -> (ir.Value | None);

    def _codegen_any_len(jacval: ir.Value) -> ir.Value;
    def _codegen_index_set(
        target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
    ) -> None;
}
