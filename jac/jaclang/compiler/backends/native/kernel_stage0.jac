import os;
import time;

glob STAGE0_UNKNOWN_FORMAT: int = 3;

def running_kernel_target(pkg_root: str = "") -> KernelTarget {
    return KernelTarget(
        format=KERNEL_TARGET_FORMAT,
        `root=os.path.abspath(pkg_root or jaclang_pkg_root()),
        scope_modules=[e.module for e in NATIVE_SCOPE],
        root_module=KERNEL_ROOT_MODULE,
        kernel_unit_rel=list(KERNEL_UNIT_REL),
        native_lowered_rel=list(NATIVE_LOWERED_PATHS),
        native_only_rel=list(NATIVE_ONLY_REL) + list(NATIVE_ONLY_DIR_REL)
    );
}

def link_kernel(
    dst: str,
    target: (KernelTarget | None) = None,
    prog: (JacProgram | None) = None,
    log: (Callable[[str], None] | None) = None,
    link_mode: str = ""
) -> LinkResult {
    mode = link_mode
        or (target.link_mode if target is not None else "")
        or KERNEL_DEV_LINK_MODE;
    with _StoreParserSpan() {
        started = time.perf_counter();
        plan = kernel_plan(prog, mode=mode, target=target);
        planned = time.perf_counter();
        if log is not None {
            log(
                f"  Kernel plan: {len(plan.units)} units in {planned - started:.1f}s "
                f"({mode} link)"
            );
        }
        os.makedirs(os.path.dirname(os.path.abspath(dst)) or ".", exist_ok=True);
        result = link_artifact(plan, dst, ArtifactKind.SHARED, log=log);
        if log is not None {
            events = plan.prog.analysis.cache_events;
            log(
                f"  Kernel link: {time.perf_counter() - planned:.1f}s "
                f"(total {time.perf_counter() - started:.1f}s); "
                f"analysis/lowering/codegen: {events.get('native_unit_analysis', 0)}/"
                f"{events.get('native_unit_lower', 0)}/"
                f"{events.get('native_unit_codegen', 0)}"
            );
            log(plan.prog.native_units().phase_summary());
        }
        return result;
    }
}

def build_target_kernel(
    spec_path: str, dst: str, log: (Callable[[str], None] | None) = None
) -> int {
    spec = read_kernel_target(spec_path);
    if spec is None {
        return STAGE0_UNKNOWN_FORMAT;
    }
    set_kernel_target(spec);
    link_kernel(dst, target=spec, log=log);
    return 0;
}
