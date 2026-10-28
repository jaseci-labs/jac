import os;
import time;

glob STAGE0_UNKNOWN_FORMAT: int = 3,
     KERNEL_ENTRY_SOURCES: tuple[str, ...] = (
         "compiler/jc_unit.jac",
         "compiler/jc_materialize.jac"
     );

class KernelEntryError(RuntimeError) {}

def declared_entry_points(source: str) -> list[str];

def unit_issue_details(plan: LinkPlan) -> Callable[[str], dict[str, str]];

def demotion_chain(
    plan: LinkPlan,
    path: str,
    name: str,
    details: Callable[[str], dict[str, str]],
    pkg_root: str
) -> list[str];

def missing_kernel_entries(
    plan: LinkPlan,
    pkg_root: str,
    details: (Callable[[str], dict[str, str]] | None) = None
) -> list[str];

def refuse_missing_entries(plan: LinkPlan, pkg_root: str);

def running_kernel_target(pkg_root: str = "") -> KernelTarget;

def link_kernel(
    dst: str,
    target: (KernelTarget | None) = None,
    prog: (JacProgram | None) = None,
    log: (Callable[[str], None] | None) = None,
    link_mode: str = "",
    spec: (TargetSpec | None) = None
) -> LinkResult;

obj GcPauses {
    has collections: int = 0,
        total_seconds: float = 0.0,
        longest_seconds: float = 0.0,
        origin: float = 0.0,
        long_pauses: list[tuple[float, float, int]] = [],
        _started: float = 0.0;

    def observe(phase: str, info: dict[str, int]);
}

def unit_line_count(path: str) -> int;

def peak_rss_gb -> float;

def plan_kernel_prefix(stop_after: int, log: Callable[[str], None]) -> int;

def build_target_kernel(
    spec_path: str, dst: str, log: (Callable[[str], None] | None) = None
) -> int;
