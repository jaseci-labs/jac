import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.codeinfo { HDR_DTOR_OFF }

obj NaIRGenClibAbi(NaIRGenState) {
    def _clib_struct_layout(name: str) -> tuple;
    def _foreign_model -> dict;
    def _foreign_fns -> dict;
    def _foreign_fields_of(name: str) -> list;
    def _clib_has_nested(name: str) -> bool;
    def _clib_c_type(name: str) -> ir.Type;
    def _clib_materialize_c_ptr(jac_ptr: ir.Value, name: str) -> ir.Value;
    def _clib_box_c_ptr(c_ptr: ir.Value, name: str) -> ir.Value;
    def _clib_copy_jac_to_c(jac_ptr: ir.Value, c_ptr: ir.Value, name: str) -> None;
    def _clib_copy_c_to_jac(c_ptr: ir.Value, jac_ptr: ir.Value, name: str) -> None;
    def _clib_alloc_box(name: str) -> ir.Value;
    def _codegen_clib_call(
        func: ir.Function, func_name: str, args: list[ir.Value]
    ) -> (ir.Value | None);

    def _clib_sext_ret(func_name: str, result: ir.Value) -> ir.Value;
}
