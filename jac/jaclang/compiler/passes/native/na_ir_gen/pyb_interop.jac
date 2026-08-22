import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E5088, E5089, E5092 }
import jaclang.jac0core.unitree as uni;
import os;

obj NaIRGenPybInterop(NaIRGenState) {
    def _pyb_base_of(arch_name: str) -> (tuple | None);
    def _pyb_shadow_postinit_owner(arch_name: str) -> (str | None);
    def _pyb_native_override_owner(arch_name: str, meth: str) -> (str | None);
    def _pyb_shadowed_dispatch(arch_name: str, method_name: str) -> (tuple | None);
    def _pyb_helper(name: str) -> ir.Function;
    def _pyb_emit_conv1(
        name: str,
        cfn: ir.Function,
        arg_ty: ir.Type,
        ret_ty: ir.Type,
        gil_on: ir.Function,
        gil_off: ir.Function
    ) -> ir.Function;

    def _pyb_cstr(text: str) -> ir.Value;
    def _pyb_owner_addr(obj_val: ir.Value) -> ir.Value;
    def _pyb_shadow_of_val(obj_val: ir.Value) -> ir.Value;
    def _pyb_to_py(nd: (uni.UniNode | None), val: ir.Value) -> (ir.Value | None);
    def _pyb_ret_key(nd: uni.FuncCall) -> (str | None);
    def _pyb_from_py(handle: ir.Value, type_key: (str | None)) -> (ir.Value | None);
    def _pyb_build_args(params: list, skip_kwargs: bool = False) -> (tuple | None);
    def _pyb_bridge_call(fn_name: str, args: list[ir.Value]) -> ir.Value;
    def _codegen_pyb_field_load(
        nd: uni.AtomTrailer, obj_val: ir.Value, field_name: str
    ) -> (ir.Value | None);

    def _codegen_pyb_field_assign(
        target: uni.AtomTrailer, value: ir.Value, obj_val: ir.Value
    ) -> (ir.Value | None);

    def _codegen_pyb_method_call(
        nd: uni.FuncCall, type_name: str, method_name: str
    ) -> (ir.Value | None);

    def _codegen_pyb_super_call(
        nd: uni.FuncCall, method_name: str
    ) -> (ir.Value | None);

    def _codegen_pyb_shadow_init(
        nd: (uni.FuncCall | uni.Name),
        type_name: str,
        obj_ptr: ir.Value,
        params: list,
        native_fields: dict
    ) -> bool;
}
