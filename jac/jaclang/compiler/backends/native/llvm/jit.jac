"""In-process execution of native code on the host through LLVM's MCJIT.

This is not part of the kernel: it runs machine code the host loads, so it
binds the LLVM shim with ctypes from the host and takes the kernel binding's
modules and target machines by their handles."""
import ctypes;
import platform;
import from ctypes { CFUNCTYPE, POINTER, c_bool, c_char_p, c_uint64, c_void_p }

glob _SHIM: list[ctypes.CDLL] = [],
     _PINNED_ENGINES: list[ExecutionEngine] = [];

def shim -> ctypes.CDLL;

def take_error(err: c_char_p) -> str;

def add_symbol(name: str, address: int);

def load_library_permanently(filename: str);

def create_mcjit_compiler(
    module: ModuleRef, target_machine: TargetMachine, use_lmm: (bool | None) = None
) -> ExecutionEngine;

"""An MCJIT engine; it owns the modules and target machine it was made from."""
class ExecutionEngine {
    def init(self: ExecutionEngine, handle: int);
    def run_static_init(self: ExecutionEngine);
    def get_function_address(self: ExecutionEngine, name: str) -> int;
    def get_global_value_address(self: ExecutionEngine, name: str) -> int;
    def _pin(self: ExecutionEngine);
    def add_global_mapping(self: ExecutionEngine, value: ValueRef, address: int);
    def finalize_object(self: ExecutionEngine);
    def run_static_constructors(self: ExecutionEngine);
    def run_static_destructors(self: ExecutionEngine);
    def enable_jit_events(self: ExecutionEngine) -> bool;
    def close(self: ExecutionEngine);
}
