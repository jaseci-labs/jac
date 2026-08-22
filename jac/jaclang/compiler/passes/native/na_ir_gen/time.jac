import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import jaclang.jac0core.unitree as uni;

obj NaIRGenTime(NaIRGenState) {
    def _emit_time_call(name: str, nd: uni.FuncCall) -> (ir.Value | None);
    def _emit_clock_gettime(clock_id: int) -> tuple;
}
