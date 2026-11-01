import os;
import sys;
import time;

glob _IFACE_MEMO: dict[str, tuple[list[str], list[str], PythonInterface]] = {},
     _IFACE_REFUSED: dict[str, str] = {},
     _IFACE_BUILT: list[float] = [0.0, 0.0],
     _OTHER_COMPILER_DIRS: dict[str, bool] = {},
     OTHER_COMPILER_MISS: str = "other_compiler",
     INTERFACE_QUESTIONS: tuple[str, ...] = ("compile_module", "parse_python"),
     NPM_QUESTIONS: tuple[str, ...] = (
         "has_npm_package",
         "resolve_npm_package",
         "npm_declarations"
     ),
     PATH_QUESTIONS: tuple[str, ...] = (
         "project_root",
         "project_facts",
         "workspace",
         "app_for_path",
         "lint_settings"
     ),
     THIRD_PARTY_DIRS: tuple[str, ...] = ("/site-packages/", "/dist-packages/"),
     _TOTALS: list[HostCensus] = [],
     _EXIT_REPORT: list[bool] = [];

def manifest_sets -> ManifestSets;

def python_interface(
    path: str, options: CompileOptions, scratch: (JacProgram | None) = None
) -> (PythonInterface | None);

def interface_dependencies(iface: PythonInterface) -> list[str];

def interface_wanted(path: str) -> bool;

def forget_interface_memo;

def file_stamp(path: str) -> str;

def interface_cache_file(path: str) -> str;

def cached_interface(path: str) -> (PythonInterface | None);

def dependency_stamps(deps: list[str]) -> list[str];

def remember_interface(iface: PythonInterface, deps: list[str]);

def served_interface(
    path: str, options: CompileOptions, scratch: JacProgram
) -> (PythonInterface | None);

glob SEALED_CATALOG_MISSING: str = "this jac installation is sealed and carries no stub catalog";

class StubCatalogMissing(SystemExit) {
    static has stops_command: bool = True;
}

def catalog_build_blocker(artifact: any) -> str;

def build_stub_catalog;

def _to_stderr(line: str);

def catalog_missing_message(cause: str) -> str;

def require_stub_catalog(host: HostServices, program: JacProgram) -> bool;

def session_inputs(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> KernelInputs;

obj KernelSnapshot(HostAsker) {
    has host: HostServices,
        program: JacProgram,
        options: CompileOptions,
        seed: KernelInputs,
        emit_cached: bool = True,
        scratch: (JacProgram | None) = None,
        shipped: set[str] = set(),
        asked: int = 0,
        ask_seconds: float = 0.0,
        failures: list[str] = [],
        other_compiler: str = "";

    def inputs -> KernelInputs;
    override def record_interface(
        program: JacProgram, module: uni.Module, products: UnitProducts
    );

    def ask(method: str, key: str) -> str;
    def answer(learner: KernelHost, method: str, fields: list[str]) -> str;
    def path_answer(learner: KernelHost, method: str, path: str);
    def path_answers(learner: KernelHost, method: str, path: str);
    def failure_note -> str;
    def serve_interface(learner: KernelHost, module_file: str);
    def emits(path: str) -> bool;
}

def kernel_note(message: str);

def compiled_already(path: str) -> bool;

def kernel_snapshot(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    emit_closure: bool = False,
    emit_cached: bool = True,
    seeds: (list[PythonInterface] | None) = None
) -> KernelSnapshot;

obj HostReferenceSession(SessionHooks) {
    has compiler: any,
        entry_path: str,
        task: (ModuleAnalysis | None) = None;

    def enter_compile(ctx: SessionContext) -> CompileFrame;
    def leave_compile(ctx: SessionContext, frame: CompileFrame);
    def finish_compile(frame: CompileFrame);
    def check_crash(crash: Exception, file_path: str);
    def closure_options -> (CompileOptions | None);
    def assemble_python(program: JacProgram, module: uni.Module);
    def assemble_native(program: JacProgram, module: uni.Module, checking: bool);
    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module;
}

def host_analysis(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None
) -> AnalysisReport;

def in_other_compiler_tree(path: str) -> bool;

def other_compiler_dir(folder: str) -> bool;

def native_stdlib_misses(misses: list[str]) -> bool;

def host_only_miss(miss: str) -> bool;

def host_deferred(outcome: AnalysisReport) -> bool;

def other_compiler_report(path: str, reached: str) -> AnalysisReport;

def kernel_census -> HostCensus;

def reset_kernel_census;

def record_kernel_session(census: HostCensus, path: str);

def report_kernel_census;

def report_stream -> any;
