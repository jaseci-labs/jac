import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import jaclang.jac0core.unitree as uni;
import os;
import from jaclang.compiler.type_system.types { UnknownType }

obj NaIRGenTuples(NaIRGenState) {
    def _infer_unpack_struct_ptr(nd: object) -> (ir.Type | None);
    def _codegen_tuple_val(nd: uni.TupleVal) -> (ir.Value | None);
    def _codegen_tuple_unpack(
        targets: list, tuple_val: ir.Value, tuple_node: (object | None)
    ) -> bool;

    def _codegen_tuple_index(
        tuple_val: ir.Value, idx_val: ir.Value, struct_type: ir.LiteralStructType
    ) -> (ir.Value | None);

    def _tuple_struct_of_value(
        val: (ir.Value | None)
    ) -> (ir.LiteralStructType | None);

    def _tuple_iter_shape(expr: (uni.UniNode | None), val: (ir.Value | None)) -> bool;
    def _tuple_seq_flavor(elem_types: list) -> (tuple | None);
    def _tuple_iter_seq(
        expr: (uni.UniNode | None), val: (ir.Value | None)
    ) -> (tuple | None);

    def _variadic_tuple_seq_type(type_args: list) -> (ir.Type | None);
    def _tuple_seq_coerce(val: ir.Value, target_type: ir.Type) -> (ir.Value | None);
    def _get_struct_size(struct_type: ir.LiteralStructType) -> int;
    def _sizeof_llvm(ty: ir.Type) -> ir.Value;
    def _box_value_tuple(val: ir.Value, loc: str = "") -> ir.Value;
    def _rc_slot_ref(val: ir.Value) -> (ir.Value | None);
    def _tuple_managed_fields(struct_type: ir.LiteralStructType) -> list;
    def _coerce_tuple_to_struct(val: ir.Value, target_struct: ir.Type) -> ir.Value;
}
