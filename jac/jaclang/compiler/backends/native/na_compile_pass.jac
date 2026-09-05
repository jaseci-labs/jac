"""Turn one module's LLVM IR into the unit's native products.

The pass owns exactly one module. It verifies the IR the generator emitted,
runs the per-unit optimization pipeline, and records the unit's bitcode and
relocatable object on `CodeGenTarget`; the driver writes them into the
module's JIR beside the native interface the generator built. Nothing here
knows about other modules: linking a closure, whether into an executable, a
shared library or an in-process JIT engine, is the link plan's job.
"""
import from collections.abc { Iterator }
import jaclang.compiler.backends.native.llvm.binding as llvm;
import type from jaclang.compiler.backends.native.llvm.binding {
    ModuleRef,
    TargetMachine
}
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes { Transform }
import from jaclang.compiler.frontend.diagnostics { E5020, W5021, W5022 }
import type from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.driver.program { JacProgram }

"""The relocation model and code model every unit object is emitted with:
position-independent, so one object serves executables, shared libraries
and the JIT alike. The native section stamp records both."""
glob NATIVE_RELOC_MODEL: str = "pic",
     NATIVE_CODE_MODEL: str = "small";

def module_bitcode(mod: ModuleRef) -> bytes;
def module_functions(mod: ModuleRef) -> list;
def create_unit_target_machine(options: CompileOptions, jit: bool = False) -> TargetMachine;
def optimize_unit(mod: ModuleRef, target_machine: TargetMachine, opt_level: int) -> None;
def jit_load_clib(lib_path: str) -> bool;

walker NativeCompilePass(Transform) {
    has prog: JacProgram;
    static has HOST_PASS: bool = True;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _run_impl(ir_in: uni.Module) -> uni.Module;
    def _load_unit_clibs(module: uni.Module) -> None;
    def _emit_debug_products(module: uni.Module, mod: ModuleRef, target_machine: TargetMachine) -> str;
    def _write_symbol_map(module: uni.Module, debug_obj_path: str, fn_names: list[str]) -> None;
    can run_walk with uni.Module entry;
}
