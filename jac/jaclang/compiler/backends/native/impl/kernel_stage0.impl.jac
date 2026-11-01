impl declared_entry_points(source: str) -> list[str] {
    import re;
    return re.findall(r"^def:pub\s+([A-Za-z_][A-Za-z0-9_]*)", source, re.MULTILINE);
}

impl missing_kernel_entries(plan: LinkPlan, pkg_root: str) -> list[str] {
    problems: list[str] = [];
    for rel in KERNEL_ENTRY_SOURCES {
        source_path = os.path.realpath(os.path.join(pkg_root, rel));
        unit = plan.unit(source_path);
        if unit is None {
            problems.append(f"{rel} is not a unit of the kernel plan");
            continue;
        }
        with open(source_path, encoding="utf-8") as handle {
            declared = declared_entry_points(handle.read());
        }
        exported = set(unit.iface.pub_symbols());
        for name in declared {
            if native_def_symbol(name) not in exported {
                problems.append(f"{name} is not exported by {rel}");
            }
        }
    }
    return problems;
}

impl refuse_missing_entries(plan: LinkPlan, pkg_root: str) {
    problems = missing_kernel_entries(plan, pkg_root);
    if problems {
        raise KernelEntryError(
            "the native compiler kernel would not export its extension module's "
            "init function:\n  "
                + "\n  ".join(problems)
        );
    }
}

impl running_kernel_target(pkg_root: str = "") -> KernelTarget {
    return KernelTarget(
        format=KERNEL_TARGET_FORMAT,
        `root=os.path.abspath(pkg_root or jaclang_pkg_root()),
        scope_modules=[e.module for e in NATIVE_SCOPE],
        root_module=KERNEL_ROOT_MODULE,
        kernel_unit_rel=list(KERNEL_UNIT_REL),
        native_lowered_rel=list(NATIVE_LOWERED_PATHS),
        native_only_rel=list(NATIVE_ONLY_REL) + list(NATIVE_ONLY_DIR_REL),
        native_host_rel=list(NATIVE_HOST_REL)
    );
}

impl kernel_options(spec: (TargetSpec | None) = None) -> CompileOptions {
    return CompileOptions(
        aot_mode=True,
        native_required=True,
        native_require=[],
        native_link_mode=KERNEL_LINK_MODE,
        na_debug=False,
        default_codespace="native",
        native_unit=True,
        kernel_build=True,
        skip_native_engine=True,
        native_target=(spec or host_target_spec()).triple,
        na_gc_mode="cycles",
        memory_profile="managed",
        nogc_enforce_all=False,
        memory_enforce=[],
        memory_exempt=[],
        native_threads=4,
        rc_debug_codegen=False,
        native_debug=False,
        opt_level=2,
        dump_ir_path="",
        debug_ir=False,
        rc_stats=False,
        nogc_debug=False
    );
}

impl kernel_plan(
    prog: (JacProgram | None) = None,
    mode: str = "",
    target: (KernelTarget | None) = None,
    spec: (TargetSpec | None) = None
) -> LinkPlan {
    program = prog if prog is not None else JacProgram();
    options = kernel_options(spec);
    root_path = target.root_module_path() if target is not None else kernel_root_path();
    return build_link_plan(program, [root_path], options, mode=mode, native_unit=True);
}

impl kernel_llvm_runpath(lib_path: str, pkg_root: str = "") -> str {
    llvm_dir = os.path.join(
        pkg_root or jaclang_pkg_root(), "compiler", "backends", "native", "llvm"
    );
    return os.path.relpath(llvm_dir, os.path.dirname(os.path.abspath(lib_path))).replace(
        os.sep, "/"
    );
}

impl link_kernel(
    dst: str,
    target: (KernelTarget | None) = None,
    prog: (JacProgram | None) = None,
    log: (Callable[[str], None] | None) = None,
    link_mode: str = "",
    spec: (TargetSpec | None) = None,
    runpath: str = ""
) -> LinkResult {
    mode = link_mode
        or (target.link_mode if target is not None else "")
        or KERNEL_LINK_MODE;

    program = prog if prog is not None else JacProgram();
    registry = program.native_units();
    registry.progress = log;
    try {
        started = time.perf_counter();
        if log is not None {
            log(
                f"  Planning the kernel for {(
                    spec.triple if spec is not None else 'this host'
                )} "
                f"({mode} link): analyzing and lowering each unit"
            );
        }
        plan = kernel_plan(program, mode=mode, target=target, spec=spec);
        pkg_root = jaclang_pkg_root();
        if target is not None {
            pkg_root = str(target.root);
        }
        refuse_missing_entries(plan, pkg_root);
        planned = time.perf_counter();
        if log is not None {
            log(
                f"  Kernel plan: {len(plan.units)} units in {planned - started:.1f}s "
                f"({mode} link)"
            );
        }
        os.makedirs(os.path.dirname(os.path.abspath(dst)) or ".", exist_ok=True);

        program.release_compile_closure();
        result = link_artifact(
            plan,
            dst,
            ArtifactKind.SHARED,
            log=log,
            runpaths=[runpath] if runpath else []
        );
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
    } finally {
        registry.progress = None;
    }
}

impl link_kernel_object(
    dst: str,
    log: (Callable[[str], None] | None) = None,
    spec: (TargetSpec | None) = None
) -> str {
    program = JacProgram();
    plan = kernel_plan(program, mode=NATIVE_LINK_MODE_BITCODE, spec=spec);
    refuse_missing_entries(plan, jaclang_pkg_root());
    program.release_compile_closure();
    data = link_object(plan, [KERNEL_INIT_SYMBOL], log=log);
    os.makedirs(os.path.dirname(os.path.abspath(dst)) or ".", exist_ok=True);
    atomic_write(dst, data);
    return dst;
}
