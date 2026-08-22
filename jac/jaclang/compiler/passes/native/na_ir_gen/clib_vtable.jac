import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }

obj NaIRGenClibVtable(NaIRGenState) {
    def _clib_struct_has_fn_ptr(name: str) -> bool;
    def _clib_detect_vtable_structs -> None;
    def _clib_coerce_callback(val: ir.Value, c_fn_ty: ir.Type) -> ir.Value;
    def _clib_cb_coerce_scalar(val: ir.Value, target_type: ir.Type) -> ir.Value;
    def _emit_clib_c_trampoline(jac_fn: ir.Function, c_fn_ty: ir.Type) -> ir.Function;
    def _clib_alloc_vtable(name: str) -> ir.Value;
    def _lower_clib_function_type(arch_name: str, fname: str, t: any) -> ir.Type;
    def _clib_fnptr_arg(val: ir.Value, target: ir.Type) -> ir.Value;
    def _clib_fnptr_ret(arch_name: str, fname: str, result: ir.Value) -> ir.Value;
}
