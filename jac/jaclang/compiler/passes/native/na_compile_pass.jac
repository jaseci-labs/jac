import jaclang.compiler.passes.native.llvm.binding as llvm;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { Transform }
import from jaclang.jac0core.codeinfo { CodeGenTarget, install_native_static_init }
import from jaclang.jac0core.diagnostics {
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

obj DepClibMeta {
    has clib_paths: list[str] = [],
        clib_symbol_lib: dict[str, str] = {},
        exported_symbols: list[str] = [],
        imported_symbols: list[str] = [],
        owned_symbols: list[str] = [],
        demoted_symbols: list[str] = [],
        transitive_deps: list[str] = [],
        options_fingerprint: str = "",
        unverified_live_calls: dict[str, list[str]] = {};

    def to_meta -> dict;
    static def from_meta(meta: dict) -> DepClibMeta;
    def propagate_to(gen: CodeGenTarget) -> None;
}

def native_compiler_fingerprint(options: any) -> str;
def native_dep_cache_paths(real_path: str, options: any) -> tuple;
def native_demoted_ir_symbols(llvm_ir_text: str) -> list[str];
def native_ir_live_externs(llvm_ir_text: str) -> set[str];
def native_prune_live_record(pending: dict, declared: set[str]) -> dict[str, set[str]];
def native_unit_demotions(
    prog: any, real_path: str, options: any
) -> (set[str] | None);

def native_live_call_conflicts(
    prog: any, pending: dict, options: any
) -> dict[str, set[str]];

glob NATIVE_VERDICT_TAINT_BOUND: int = 2048,
     NATIVE_LINK_COMPILE_BOUND: int = 384,
     NATIVE_VERDICT_MISS_BOUND: int = 512;

def native_verdict_blast_guard(
    prog: any, composed: int, aot_lane: bool = False
) -> str;


obj NativeCompilePass(Transform) {
    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _compile_and_link_native_imports(
        module: uni.Module, main_mod: object, imports: list, target_machine: object
    ) -> None;

    def _jit_load_clib(lib_path: str) -> bool;
    def _link_osp_kernel(main_mod: object) -> None;
    def _references_undefined_osp_kernel(main_mod: object) -> bool;
    def _link_fmt_kernel(main_mod: object) -> None;
    def _references_undefined_fmt_kernel(main_mod: object) -> bool;
}
