import from jaclang.compiler.passes.context { CompileContext, CompilerPass }
import jaclang.compiler.backends.native.llvm.binding as llvm;
import type from jaclang.compiler.backends.native.llvm.binding {
    ModuleRef,
    TargetMachine
}
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.diagnostics { E5020, E5026 }
import type from jaclang.compiler.driver.compile_options { CompileOptions }

glob NATIVE_RELOC_MODEL: str = "pic",
     NATIVE_CODE_MODEL: str = "small",
     CODEGEN_SECONDS: dict[str, float] = {};

def module_bitcode(mod: ModuleRef) -> bytes;
def emit_unit_object(bitcode: bytes, options: CompileOptions) -> bytes;
def module_functions(mod: ModuleRef) -> list[any];
def settle_unit_ir(module: uni.Module) -> None;
def create_unit_target_machine(
    options: CompileOptions, jit: bool = False
) -> TargetMachine;

def optimize_unit(
    mod: ModuleRef, target_machine: TargetMachine, opt_level: int
) -> None;

def unit_ir_bitcode(module: uni.Module) -> bytes;
def install_unit_ir_text(module: uni.Module, text: str) -> None;
def native_codegen_workers -> int;
def codegen_unit_products(
    unit_bitcode: bytes,
    target_machine: TargetMachine,
    opt_level: int,
    emit_object: bool
) -> tuple[bytes, (bytes | None)];

def _codegen_job(
    path: str,
    unit_bitcode: bytes,
    target_machine: TargetMachine,
    opt_level: int,
    emit_object: bool
) -> tuple[str, float, tuple[bytes, (bytes | None)]];

def codegen_unit_seconds(paths: list[str]) -> list[tuple[float, str]];
def codegen_units_parallel(
    jobs: list[tuple[str, bytes]],
    options: CompileOptions,
    opt_level: int,
    emit_object: bool
) -> dict[str, tuple[bytes, (bytes | None)]];

walker NativeCompilePass(CompilerPass) {
    def postinit -> None;
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

def require_native_ir(llvm_ir_text: str) -> None;
