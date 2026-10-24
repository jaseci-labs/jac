import os;

glob KERNEL_TIMING_ENV: str = "JAC_KERNEL_TIMING",
     SLOW_COMPILE_SECONDS: float = 20.0,
     _APPLICATION_UNITS: dict[str, UnitProducts] = {},
     _HOST_PREPARING: list[str] = [],
     _IN_PROCESS: list[bool] = [];

class KernelCompileError(RuntimeError) {}

def run_kernel_in_process(on: bool = True) -> bool;

def kernel_compile_in_process -> bool;

def kernel_compile(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: (str | None) = None,
    in_process: bool = False,
    isolated: bool = True,
    emit_closure: bool = False,
    emit_cached: bool = True,
    seeds: (list[PythonInterface] | None) = None
) -> CompileReport;

def kernel_route(program: JacProgram, path: str) -> tuple[bool, bool];

def kernel_compile_reported(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    in_process: bool,
    emit_closure: bool,
    emit_cached: bool = True,
    seeds: (list[PythonInterface] | None) = None
) -> CompileReport;

def kernel_generates_native(program: JacProgram, path: str) -> bool;

def host_kernel_compile(
    host: HostServices, program: JacProgram, path: str, options: CompileOptions
) -> (CompileReport | None);

def kernel_compile_application(
    host: HostServices,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    seeds: (list[PythonInterface] | None) = None
) -> (CompileReport | None);

def forget_application_units;

def host_preparing(entry_path: str);

def host_prepared;
