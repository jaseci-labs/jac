import os;

"""Runtime units in link order: each one may call the units listed before it,
and every other unit links against all of them."""
glob MIR_RUNTIME_UNITS: list[str] = [
         "runtime/native/exceptions.jac",
         "runtime/native/rc.jac",
         "runtime/native/strings.jac",
         "runtime/native/lists.jac",
         "runtime/native/dicts.jac"
     ];

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

"""What the decision step makes of every analysed module in `prog`: lowering
to MIR without emission, and the demoted set it settles. This is what
`jac check --native-coverage` reports."""
def native_coverage(prog: JacProgram) -> dict[str, dict[str, any]];
