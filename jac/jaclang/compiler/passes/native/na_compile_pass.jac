import jaclang.compiler.passes.native.llvm.binding as llvm;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { Transform }
import from jaclang.jac0core.codeinfo { CodeGenTarget }
import from jaclang.jac0core.diagnostics {
    E5020,
    W5021,
    W5022,
    W5023,
    E5024,
    E5025,
    E5026
}

obj DepClibMeta {
    has clib_paths: list[str] = [],
        clib_symbol_lib: dict[str, str] = {},
        exported_symbols: list[str] = [],
        imported_symbols: list[str] = [],
        owned_symbols: list[str] = [],
        transitive_deps: list[str] = [];

    def to_meta -> dict;
    static def from_meta(meta: dict) -> DepClibMeta;
    def propagate_to(gen: CodeGenTarget) -> None;
}


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
