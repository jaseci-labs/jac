import from jaclang.compiler.backends.native.llvm { ir }
import from jaclang.compiler.backends.native.na_ir_gen.state { NaIRGenState }
import from jaclang.compiler.frontend.diagnostics { E5092 }
import jaclang.compiler.frontend.unitree as uni;

obj NaIRGenClosures(NaIRGenState) {
    def _scan_closure_escapes(nd: uni.UniNode, body: (list | tuple)) -> None;
    def _closure_sig_struct(fnty: ir.FunctionType) -> tuple;
    def _closure_struct_of(val_type: ir.Type) -> (str | None);
    def _wrap_fn_as_closure_value(val: ir.Value) -> ir.Value;
    def _closure_cell_struct(slot_type: ir.Type) -> str;
    def _emit_closure_cell(var_name: str, slot_type: ir.Type) -> ir.Value;
    def _emit_closure_thunk(
        target_fn: ir.Function, declared_count: int, cap_info: list
    ) -> ir.Function;

    def _emit_closure_pair(
        target_fn: ir.Function, declared_fnty: ir.FunctionType, cap_info: list
    ) -> (ir.Value | None);

    def _emit_closure_value(var_name: str, nd: uni.UniNode) -> (ir.Value | None);
    def _emit_closure_escape_error(var_name: str, nd: uni.UniNode) -> None;
    def _codegen_closure_call(
        nd: uni.FuncCall, clos_val: ir.Value, struct_name: str
    ) -> (ir.Value | None);
}
