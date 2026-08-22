import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }

obj NaIRGenBytes(NaIRGenState) {
    def _get_bytes_struct_type -> ir.Type;
    def _bytes_alloc(n: ir.Value) -> ir.Value;
    def _bytes_data_ptr(bv: ir.Value) -> ir.Value;
    def _bytes_len_val(bv: ir.Value) -> ir.Value;
    def _bytes_from_raw(src: ir.Value, n: ir.Value) -> ir.Value;
    def _make_global_bytes(data: bytes) -> ir.Value;
    def _is_bytes_value(v: ir.Value) -> bool;
    def _codegen_bytes_index(bv: ir.Value, idx: ir.Value) -> (ir.Value | None);
    def _codegen_bytes_slice(bv: ir.Value, slice_node: object) -> (ir.Value | None);
    def _emit_bytes_eq(left: ir.Value, right: ir.Value, negate: bool) -> ir.Value;
    def _is_bytes_type(t: ir.Type) -> bool;
    def _emit_bytes_truthy(bv: ir.Value) -> ir.Value;
    def _emit_bytes_repeat(bv: ir.Value, count: ir.Value) -> ir.Value;
    def _emit_bytes_contains(needle: ir.Value, haystack: ir.Value) -> ir.Value;
    def _emit_bytes_cmp(left: ir.Value, right: ir.Value, op_sym: str) -> ir.Value;
    def _emit_bytes_repr(bv: ir.Value) -> ir.Value;
    def _bytes_repr_fn -> ir.Function;
}
