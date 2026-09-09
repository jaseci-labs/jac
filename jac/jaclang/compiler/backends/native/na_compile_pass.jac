import jaclang.compiler.backends.native.llvm.binding as llvm;
import type from jaclang.compiler.backends.native.llvm.binding {
    ModuleRef,
    TargetMachine,
    ValueRef
}
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.frontend.codeinfo {
    CodeGenTarget,
    install_native_static_init
}
import from jaclang.compiler.frontend.diagnostics {
    E5020,
    W5021,
    W5022,
    W5023,
    E5024,
    E5025,
    E5026,
    E5027,
    E5028,
    E5029
}
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

obj DepClibMeta {
    has clib_paths: list[str] = [],
        clib_symbol_lib: dict[str, str] = {},
        exported_symbols: list[str] = [],
        imported_symbols: list[str] = [],
        owned_symbols: list[str] = [],
        demoted_symbols: list[str] = [],
        transitive_deps: list[str] = [],
        ct_deps: str = "",
        options_fingerprint: str = "",
        unverified_live_calls: dict[str, list[str]] = {},
        coverage: dict = {};

    def to_meta -> dict;
    static def from_meta(meta: dict) -> DepClibMeta;
    def propagate_to(gen: CodeGenTarget) -> None;
}

def native_compiler_fingerprint(options: CompileOptions) -> str;
def native_dep_cache_paths(real_path: str, options: CompileOptions) -> tuple[str, str];
def native_demoted_ir_symbols(llvm_ir_text: str) -> list[str];
def native_linked_ir_text(module: uni.Module) -> str;
def native_ir_live_externs(llvm_ir_text: str) -> set[str];
def native_prune_live_record(pending: dict, declared: set[str]) -> dict[str, set[str]];
def native_unit_demotions(
    prog: JacProgram, real_path: str, options: CompileOptions
) -> (set[str] | None);

def native_live_call_conflicts(
    prog: JacProgram, pending: dict, options: CompileOptions
) -> dict[str, set[str]];

glob NATIVE_VERDICT_TAINT_BOUND: int = 2048,
     NATIVE_LINK_COMPILE_BOUND: int = 384,
     NATIVE_VERDICT_MISS_BOUND: int = 512;

def native_verdict_blast_guard(
    prog: JacProgram, composed: int, aot_lane: bool = False
) -> str;


walker NativeCompilePass(Transform) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _run_impl(ir_in: uni.Module) -> uni.Module;
    can run_walk with uni.Module entry;
    def _compile_and_link_native_imports(
        module: uni.Module,
        main_mod: ModuleRef,
        sources: list[str],
        target_machine: TargetMachine
    ) -> None;

    def _jit_load_clib(lib_path: str) -> bool;
    def _link_osp_kernel(main_mod: ModuleRef) -> None;
    def _references_undefined_osp_kernel(main_mod: ModuleRef) -> bool;
    def _link_fmt_kernel(main_mod: ModuleRef) -> None;
    def _references_undefined_fmt_kernel(main_mod: ModuleRef) -> bool;
    def _link_region_kernel(main_mod: ModuleRef) -> None;
    def _references_undefined_region_kernel(main_mod: ModuleRef) -> bool;
    def _module_defines(main_mod: ModuleRef, name: str) -> bool;
}
