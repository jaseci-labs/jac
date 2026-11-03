import os;

glob KERNEL_MODULE_NAME: str = "jac_kernel",
     _KERNEL: list[any] = [],
     _RESOLVED: list[bool] = [],
     _RESOLVING: list[bool] = [];

def runtime_builtin_initializing -> bool;

def loaded_kernel -> (any | None);

def load_kernel_module(lib_path: str, source: str) -> any;

def reset_loaded_kernel;

def call_compile(
    request: KernelRequest, asker: (HostAsker | None) = None, in_process: bool = False
) -> CompileReport;

def call_check(
    request: KernelRequest, asker: (HostAsker | None) = None, in_process: bool = False
) -> AnalysisReport;

def required_kernel -> any;
