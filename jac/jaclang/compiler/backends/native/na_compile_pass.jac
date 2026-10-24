glob NATIVE_RELOC_MODEL: str = "pic",
     NATIVE_CODE_MODEL: str = "small",
     CODEGEN_BASE_BYTES: int = 32 * 1024 * 1024,
     CODEGEN_BYTES_PER_BITCODE_BYTE: int = 16;

def module_bitcode(mod: ModuleRef) -> bytes;
def emit_unit_object(bitcode: bytes, options: CompileOptions) -> bytes;
def object_emit_jobs -> int;
def codegen_footprint(blob: bytes) -> int;
def codegen_map(work: Callable[..., bytes], blobs: list[bytes]) -> list[bytes];
def emit_unit_objects(bitcodes: list[bytes], options: CompileOptions) -> list[bytes];
def unit_bitcode(unit_ir: any) -> bytes;
def unit_module_copy(unit_ir: any, context: any) -> ModuleRef;
def optimized_bitcode(
    mod: ModuleRef, options: CompileOptions, opt_level: int
) -> bytes;

def optimize_unit_ir(unit_ir: any, options: CompileOptions, opt_level: int) -> bytes;
def optimize_unit_bitcode(
    bitcode: bytes, options: CompileOptions, opt_level: int
) -> bytes;

def optimize_unit_bitcodes(
    bitcodes: list[bytes], options: CompileOptions, opt_level: int
) -> list[bytes];

def module_functions(mod: ModuleRef) -> list[any];
def unit_function_counts(unit_ir: any) -> tuple[int, int];
def settle_unit_ir(module: uni.Module) -> None;
def create_unit_target_machine(
    options: CompileOptions, jit: bool = False
) -> TargetMachine;

def optimize_unit(
    mod: ModuleRef, target_machine: TargetMachine, opt_level: int
) -> None;

walker NativeCompilePass(CompilerPass) {
    static has contract: PassContract = PassContract();

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

def native_linked_ir_text(module: uni.Module) -> str;
def unit_fallbacks(gen: CodeGenTarget) -> NativeFallbacks;
