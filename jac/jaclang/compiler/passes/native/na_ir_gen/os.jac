import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import from jaclang.jac0core.constant { Tokens as Tok }
import jaclang.jac0core.unitree as uni;
import os;

obj NaIRGenOs(NaIRGenState) {
    def _emit_os_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_os_const(name: str) -> (ir.Value | None);
    def _emit_os_environ_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_ospath_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
}
