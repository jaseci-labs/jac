import os;
import time;

glob KERNEL_ENTRY_SOURCES: tuple[str, ...] = ("compiler/kernel_module.jac", ),
     KERNEL_INIT_SYMBOL: str = "PyInit_jac_kernel",
     KERNEL_LINK_MODE: str = NATIVE_LINK_MODE_OBJECTS;

class KernelEntryError(RuntimeError) {}

def declared_entry_points(source: str) -> list[str];

def missing_kernel_entries(plan: LinkPlan, pkg_root: str) -> list[str];

def refuse_missing_entries(plan: LinkPlan, pkg_root: str);

def running_kernel_target(pkg_root: str = "") -> KernelTarget;

def kernel_options(spec: (TargetSpec | None) = None) -> CompileOptions;

def kernel_plan(
    prog: (JacProgram | None) = None,
    mode: str = "",
    target: (KernelTarget | None) = None,
    spec: (TargetSpec | None) = None
) -> LinkPlan;

def kernel_llvm_runpath(lib_path: str, pkg_root: str = "") -> str;

def link_kernel(
    dst: str,
    target: (KernelTarget | None) = None,
    prog: (JacProgram | None) = None,
    log: (Callable[[str], None] | None) = None,
    link_mode: str = "",
    spec: (TargetSpec | None) = None,
    runpath: str = ""
) -> LinkResult;

def link_kernel_object(
    dst: str,
    log: (Callable[[str], None] | None) = None,
    spec: (TargetSpec | None) = None
) -> str;
