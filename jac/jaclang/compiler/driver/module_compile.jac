import os;

def session_of(task: ModuleAnalysis) -> SessionHooks;

def admits_native_checks(task: ModuleAnalysis) -> bool;

def run_native_checks(task: ModuleAnalysis);

def admits_client_dependencies(task: ModuleAnalysis) -> bool;

def run_client_dependencies(task: ModuleAnalysis);

def admits_interface(task: ModuleAnalysis) -> bool;

def run_interface(task: ModuleAnalysis);

def admits_codegen(task: ModuleAnalysis) -> bool;

def run_codegen(task: ModuleAnalysis);

def client_import_paths(module: uni.Module) -> list[str];

def scrub_native_artifacts_on_error(program: JacProgram, mod: uni.Module) -> bool;

def report_missing_native_ir(program: JacProgram, mod: uni.Module) -> None;

glob CODEGEN_PLAN: tuple[PlanStep, ...] = (
         PlanStep(
             name="NATIVE_CHECKS", admit=admits_native_checks, run=run_native_checks
         ),
         PlanStep(
             name="CLIENT_DEPENDENCIES",
             admit=admits_client_dependencies,
             run=run_client_dependencies
         ),
         PlanStep(name="INTERFACE", admit=admits_interface, run=run_interface),
         PlanStep(name="CODEGEN", admit=admits_codegen, run=run_codegen)
     );

def analyze_for_compile(
    program: JacProgram, path: str, options: CompileOptions, source: str | None
) -> ModuleAnalysis;

def compile_task(
    session: SessionHooks,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: str | None = None
) -> ModuleAnalysis;

def compile_module(
    session: SessionHooks,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: str | None = None
) -> uni.Module;
