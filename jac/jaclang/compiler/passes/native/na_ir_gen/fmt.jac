import from jaclang.compiler.passes.native.llvm { ir }
import from jaclang.compiler.passes.native.na_ir_gen.state { NaIRGenState }
import jaclang.jac0core.unitree as uni;

obj NaIRGenFmt(NaIRGenState) {
    def _ensure_fmt_kernel -> bool;
    def _get_fmt_kernel_fn(name: str) -> (ir.Function | None);
}
