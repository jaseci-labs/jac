import os;


obj NativeDepScan {
    has fresh: list[tuple[str, float, int]],
        reason: str,
        deps: list[str];
}

glob _SPACE_BY_NAME: dict[str, CodeContext] = {
         'server': CodeContext.SERVER,
         'client': CodeContext.CLIENT,
         'native': CodeContext.NATIVE
     },
     _na_scan_memo: dict[str, NativeDepScan] = {};

def native_scan_memo_clear;

def placement_work(prog: JacProgram) -> PlacementWork;

def refresh_placement_module(module: uni.Module, prog: JacProgram);

def _native_dep_scan(
    path: str, hold_exempt: bool = False
) -> (tuple[str, list[str]] | None);

def _native_deps_ok(
    root_path: str, root_deps: list[str], hold_exempt: bool = False
) -> bool;

def native_default_path_ok(path: str) -> bool;

def native_placement_candidate(
    module: uni.Module, prog: JacProgram
) -> tuple[bool, str];

def dependency_summary(prog: JacProgram, path: str) -> (PlacementSummary | None);

def native_closure_blocker(
    prog: JacProgram, root_path: str, deps: list[str]
) -> tuple[str, bool];

def _endpoint_veto_applies(module: uni.Module) -> bool;


def _is_client_top(elem: uni.UniNode) -> bool;

def _py_import_client_portable(elem: uni.Import, app_kind: str = '') -> bool;

def _pullable_by_client_reference(
    elem: uni.UniNode, module: uni.Module, body_refs: dict[int, set[int]]
) -> bool;

def _ref_top_ids(module: uni.Module, elem: uni.UniNode) -> set[int];

def _is_sv_import(elem: uni.UniNode) -> bool;

def _named_top_element(target: uni.Module, name: str) -> (uni.UniNode | None);

def _materialize_module(path: str, prog: JacProgram) -> (uni.Module | None);

def _import_source_module(elem: uni.Import, prog: JacProgram) -> (uni.Module | None);

def _closure_pullable(
    top: uni.UniNode, module: uni.Module, prog: JacProgram, seen: set[int]
) -> bool;

def _module_externally_pinned(mod_path: str) -> bool;

def _python_backend_forced(prog: JacProgram) -> bool;

def _seed_from_summary(module: uni.Module, prog: JacProgram) -> int;

def solve_module_placement(
    module: uni.Module,
    prog: JacProgram,
    seed_ref_ids: (set[int] | None) = None,
    dual: bool = False,
    pull_dependents: bool = True
) -> int;

def _emit_solver_warning(
    prog: JacProgram, diag: DiagnosticInfo, nd: uni.UniNode, name: str
);

def _warn_state_forks(target: uni.Module, prog: JacProgram);

def _held_pull_ids(target: uni.Module, target_path: str) -> set[int];

def _pull_into_target(
    imp: uni.Import, target: uni.Module, module: uni.Module, prog: JacProgram
) -> int;

def _pull_boundary_import(
    imp: uni.Import, module: uni.Module, prog: JacProgram
) -> int;

def solve_program_placement(entry_mod: uni.Module, prog: JacProgram);

def invalidate_importers_es(prog: JacProgram, mod_path: str) -> list[uni.Module];

walker PlacementApplyPass(CompilerPass) {
    static has contract: PassContract = PassContract(
        requires=(AnalysisFact.SYM_OF, ),
        provides=(
            AnalysisFact.PLACED_IN,
            AnalysisFact.DECIDED_CODESPACE,
            AnalysisFact.CODESPACE_PULL,

        )
    );

    def _run_impl(ir_in: uni.Module) -> uni.Module;
    can run_walk with uni.Module entry;
}
