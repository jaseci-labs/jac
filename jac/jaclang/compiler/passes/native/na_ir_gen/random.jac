import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import jaclang.jac0core.unitree as uni;

obj NaIRGenRandom(NaIRGenState) {
    def _mt_ensure -> None;
    def _emit_random_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
}
