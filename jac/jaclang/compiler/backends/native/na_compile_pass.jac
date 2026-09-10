import jaclang.compiler.backends.native.llvm.binding as llvm;
import type from jaclang.compiler.backends.native.llvm.binding {
    ModuleRef,
    TargetMachine
}
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.frontend.diagnostics { E5020, E5026 }
import type from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.driver.program { JacProgram }

glob NATIVE_RELOC_MODEL: str = "pic",
     NATIVE_CODE_MODEL: str = "small";

def module_bitcode(mod: ModuleRef) -> bytes;
def emit_unit_object(bitcode: bytes, options: CompileOptions) -> bytes;
def module_functions(mod: ModuleRef) -> list;
def create_unit_target_machine(
    options: CompileOptions, jit: bool = False
) -> TargetMachine;

def optimize_unit(
    mod: ModuleRef, target_machine: TargetMachine, opt_level: int
) -> None;

walker NativeCompilePass(Transform) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _run_impl(ir_in: uni.Module) -> uni.Module;
    def _share_engine(module: uni.Module, engine: any) -> None;
    def _emit_debug_products(
        module: uni.Module, mod: ModuleRef, target_machine: TargetMachine
    ) -> str;

    def _write_symbol_map(
        module: uni.Module, debug_obj_path: str, fn_names: list[str]
    ) -> None;

    can run_walk with uni.Module entry;
}

def native_demoted_ir_symbols(llvm_ir_text: str) -> list[str];
def native_linked_ir_text(module: uni.Module) -> str;
