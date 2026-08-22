import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.diagnostics { E5092 }
import jaclang.jac0core.unitree as uni;

obj NaIRGenStruct(NaIRGenState) {
    def _emit_struct_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_struct_pack(
        nd: uni.FuncCall, params: list, fields: list, total: int, little: bool
    ) -> (ir.Value | None);

    def _emit_struct_unpack(
        nd: uni.FuncCall, params: list, fields: list, total: int, little: bool
    ) -> (ir.Value | None);
}
