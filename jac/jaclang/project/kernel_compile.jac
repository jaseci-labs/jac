import os;

glob KERNEL_TIMING_ENV: str = "JAC_KERNEL_TIMING",
     SLOW_COMPILE_SECONDS: float = 20.0,
     _APPLICATION_UNITS: dict[str, UnitProducts] = {},
     _HOST_PREPARING: list[str] = [];

class KernelCompileError(RuntimeError) {}

def kernel_compile(
    program: JacProgram, path: str, options: CompileOptions, source: (str | None) = None
) -> CompileReport;

def kernel_route(program: JacProgram, path: str) -> bool;

def kernel_compile_reported(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> CompileReport;

def kernel_generates_native(program: JacProgram, path: str) -> bool;

def host_kernel_compile(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> (CompileReport | None);

def kernel_compile_application(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> (CompileReport | None);

def forget_application_units;

def host_preparing(entry_path: str);

def host_prepared;
