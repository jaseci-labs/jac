import os;

glob MIR_RUNTIME_UNITS: list[str] = ["runtime/native/exceptions.jac"];

def mir_backend_selected -> bool;

def mir_runtime_unit_paths -> list[str];

walker MirNativePass(CompilerPass) {
    static has contract: PassContract = PassContract(
        requires=(AnalysisFact.TYPE_OF, AnalysisFact.CFG_SUCC)
    );

    def _run_impl(ir_in: uni.Module) -> uni.Module;
    def report_refusals(lowering: MirLowering);
    def interface(mir: MirModule, deps: list[str]) -> NativeIface;
    can run_walk with uni.Module entry;
}
