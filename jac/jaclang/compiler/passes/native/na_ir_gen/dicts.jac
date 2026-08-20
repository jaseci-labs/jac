import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;
import os;

obj NaIRGenDicts(NaIRGenState) {
    def _peer_dict_key -> (str | None);
    def _dict_key_spec(key_type: ir.Type) -> tuple;
    def _dict_val_spec(val_type: ir.Type) -> str;
    def _unwrap_opt_container(val: ir.Value) -> ir.Value;
    def _emit_dict_helpers(
        key_type_name: str,
        val_type_name: str,
        key_type: ir.Type,
        val_type: ir.Type,
        key_size: int = 0
    ) -> None;

    def _emit_dict_order_compact(
        b: ir.IRBuilder,
        fn: ir.Function,
        d_ptr: ir.Value,
        removed_slot: ir.Value,
        new_len: ir.Value,
        i32: ir.Type,
        i64: ir.Type,
        order_idx: int
    ) -> ir.IRBuilder;

    def _emit_order_scan_incr_block(
        b: ir.IRBuilder,
        idx_slot: ir.Value,
        i_cur: ir.Value,
        i64: ir.Type,
        fn: ir.Function,
        scan_bb: ir.Block
    ) -> ir.Block;

    def _box_to_jacval(value: ir.Value) -> ir.Value;
    def _unbox_from_jacval(jv: ir.Value, target_type: ir.Type) -> ir.Value;
    def _codegen_dict_val(nd: uni.DictVal) -> (ir.Value | None);
    def _codegen_dict_access(
        target_val: ir.Value,
        key_val: ir.Value,
        key_type_name: str,
        val_type_name: str,
        key_node: (uni.UniNode | None) = None
    ) -> (ir.Value | None);

    def _codegen_dict_set(
        target_val: ir.Value,
        key_val: ir.Value,
        value: ir.Value,
        key_type_name: str,
        val_type_name: str,
        key_node: (uni.UniNode | None) = None
    ) -> None;

    def _dict_key_reconcile(dk: (str | None), val: (ir.Value | None)) -> (str | None);
}
