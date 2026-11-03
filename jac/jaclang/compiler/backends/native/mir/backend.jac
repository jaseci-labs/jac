import json;
import os;
import sys;

glob MIR_RUNTIME_UNITS: list[str] = [
         "runtime/native/exceptions.jac",
         "runtime/native/rc.jac",
         "runtime/native/strings.jac",
         "runtime/native/lists.jac",
         "runtime/native/dicts.jac",
         "runtime/native/closures.jac",
         "runtime/native/anys.jac",
         "runtime/native/iterators.jac",
         "runtime/native/text.jac",
         "runtime/native/format.jac",
         "runtime/native/bytes.jac"
     ];

def mir_runtime_unit_paths -> list[str];

def mir_layout_type(t: MirType) -> str;

def mir_layout_key(t: MirType) -> str;

def mir_layout_enum(t: MirType) -> (str | None);

def mir_demoted_name(mir: MirModule, symbol: str) -> str;

def mir_soft_blocks(top: (uni.UniNode | None), whole: bool, event: bool) -> bool;

def mir_top_element(
    module: uni.Module, nd: (uni.UniNode | None)
) -> (uni.UniNode | None);

def mir_clib_path(spec: tuple[str, list[str], int], triple: str) -> str;

glob MIR_LIST_DATA: int = 16,
     MIR_DICT_KEYS: int = 16,
     MIR_DICT_VALS: int = 24,
     MIR_DICT_ORDER: int = 48;

def mir_field_slot(t: MirType) -> tuple[str, str, (dict[str, any] | None)];

def mir_value_schema(t: MirType) -> (dict[str, any] | None);

walker MirNativePass(CompilerPass) {
    static has contract: PassContract = PassContract(
        requires=(AnalysisFact.TYPE_OF, AnalysisFact.CFG_SUCC)
    );

    def _run_impl(ir_in: uni.Module) -> uni.Module;
    def native_required(path: str) -> bool;
    def report_refusals(lowering: MirLowering);
    def report_crash(lowering: MirLowering, exc: Exception);
    def settle_soft(lowering: MirLowering) -> bool;
    def refuse_events(lowering: MirLowering) -> bool;
    def note_demotions(lowering: MirLowering, prior: (NativeIface | None));
    def interface(
        lowering: MirLowering, deps: list[str], triple: str = ""
    ) -> NativeIface;

    def class_layouts(
        lowering: MirLowering, module: ir.Module
    ) -> dict[str, NativeClassLayout];

    def layout(lowering: MirLowering, mir: MirModule) -> NativeModuleLayout;
    can run_walk with uni.Module entry;
}

def native_coverage(prog: JacProgram) -> dict[str, dict[str, any]];
