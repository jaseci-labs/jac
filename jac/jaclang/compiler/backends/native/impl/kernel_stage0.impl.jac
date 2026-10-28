impl declared_entry_points(source: str) -> list[str] {
    import re;
    return re.findall(r"^def:pub\s+([A-Za-z_][A-Za-z0-9_]*)", source, re.MULTILINE);
}

impl unit_issue_details(plan: LinkPlan) -> Callable[[str], dict[str, str]] {
    registry = plan.prog.native_units();
    cache: dict[str, dict[str, str]] = {};

    def details(path: str) -> dict[str, str] {
        found = cache.get(path);
        if found is not None {
            return found;
        }
        out: dict[str, str] = {};
        bitcode = registry.bitcode_for(path, plan.options);
        if bitcode is not None {
            for issue in native_lowering_issues(str(llvm.parse_bitcode(bitcode))) {
                out.setdefault(issue.symbol, issue.detail);
            }
        }
        cache[path] = out;
        return out;
    }
    return details;
}

impl demotion_chain(
    plan: LinkPlan,
    path: str,
    name: str,
    details: Callable[[str], dict[str, str]],
    pkg_root: str
) -> list[str] {
    import re;
    chain: list[str] = [];
    seen: set[str] = set();
    current: (str | None) = name;
    owner: (str | None) = path;
    while current is not None and owner is not None {
        step = f"{owner}:{current}";
        if step in seen {
            break;
        }
        seen.add(step);
        detail = details(owner).get(current, "");
        label = os.path.relpath(owner, os.path.dirname(pkg_root));
        chain.append(f"{current} ({label})" + (f": {detail}" if detail else ""));
        called = re.search(
            r"Native lowering failed for (?:function|method) '([^']+)'", detail
        );
        if called is None {
            break;
        }
        current = called.group(1);
        here = plan.unit(owner);
        candidates = [here] if here is not None else [];
        if here is not None {
            candidates.extend(plan.unit(dep) for dep in here.iface.deps);
        }
        candidates.extend(plan.units);
        owner = next(
            (
                unit.path
                for unit in candidates
                if unit is not None and current in unit.iface.demoted
            ),
            None
        );
    }
    return chain;
}

impl missing_kernel_entries(
    plan: LinkPlan,
    pkg_root: str,
    details: (Callable[[str], dict[str, str]] | None) = None
) -> list[str] {
    issues = details if details is not None else unit_issue_details(plan);
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
            if native_def_symbol(name) in exported {
                continue;
            }
            chain = demotion_chain(plan, unit.path, name, issues, pkg_root);
            problems.append(
                f"{name} is not exported"
                    + (
                        "; it was demoted to Python:\n      "
                            + "\n      <- ".join(chain)
                            if chain
                            else ""
                    )
            );
        }
    }
    return problems;
}

impl refuse_missing_entries(plan: LinkPlan, pkg_root: str) {
    problems = missing_kernel_entries(plan, pkg_root);
    if problems {
        raise KernelEntryError(
            "the native compiler kernel would not export the entry points its "
            "loader calls:\n  "
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
        native_only_rel=list(NATIVE_ONLY_REL) + list(NATIVE_ONLY_DIR_REL)
    );
}

impl link_kernel(
    dst: str,
    target: (KernelTarget | None) = None,
    prog: (JacProgram | None) = None,
    log: (Callable[[str], None] | None) = None,
    link_mode: str = "",
    spec: (TargetSpec | None) = None
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
    } finally {
        registry.progress = None;
    }
}

impl GcPauses.observe(phase: str, info: dict[str, int]) {
    if info.get("generation") != 2 {
        return;
    }
    if phase == "start" {
        self._started = time.perf_counter();
        return;
    }
    pause = time.perf_counter() - self._started;
    self.collections += 1;
    self.total_seconds += pause;
    self.longest_seconds = max(self.longest_seconds, pause);
    if pause > 1.0 {
        self.long_pauses.append(
            (self._started - self.origin, pause, info.get("collected", 0))
        );
    }
}

impl unit_line_count(path: str) -> int {
    total = 0;
    for source in [path] + discover_annex_files(path, ".impl.jac") {
        try {
            with open(source, "rb") as f {
                total += f.read().count(b"\n");
            }
        } except OSError {}
    }
    return total;
}

impl peak_rss_gb -> float {
    import resource;
    import sys;
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss;
    return peak / (1 << 30) if sys.platform == "darwin" else peak / (1 << 20);
}

impl plan_kernel_prefix(stop_after: int, log: Callable[[str], None]) -> int {
    import gc;
    import from operator { itemgetter }
    program = JacProgram();
    registry = program.native_units();
    started = time.perf_counter();

    def stamped(line: str) {
        log(f"[{time.perf_counter() - started:7.1f}s {peak_rss_gb():5.1f}G] {line}");
    }

    registry.progress = stamped;
    registry.cold = True;
    program.iface_registry().cold = True;
    registry.stop_after = stop_after;
    pauses = GcPauses(origin=started);
    gc.callbacks.append(pauses.observe);
    log(f"  Planning the kernel uncached until {stop_after} units are lowered");
    try {
        kernel_plan(program, mode=KERNEL_LINK_MODE);
        log("  The whole kernel was planned before the stop");
    } except NativeBuildStopped {} finally {
        registry.progress = None;
        gc.callbacks.remove(pauses.observe);
    }
    log(
        f"  Kernel prefix: {registry.lowered_units} units lowered in "
        f"{time.perf_counter() - started:.1f}s (nothing linked), "
        f"peak RSS {peak_rss_gb():.1f} GB"
    );
    log(registry.phase_summary());
    log(
        f"  GC: {pauses.collections} gen-2 collections, "
        f"{pauses.total_seconds:.1f}s paused, longest {pauses.longest_seconds:.2f}s"
    );
    for (at, seconds, collected) in pauses.long_pauses {
        log(f"    gen-2 pause of {seconds:.2f}s at {at:.1f}s, {collected} collected");
    }
    for (path, why) in sorted(registry.failures.items()) {
        reason = why.strip().splitlines()[-1] if why.strip() else "no reason recorded";
        log(f"  Failed to lower {native_unit_identity(path)}: {reason}");
    }
    log(
        "  Lowering time per unit (lines include annexes; functions declared/defined):"
    );
    for (path, seconds) in sorted(
        registry.unit_lower_seconds.items(), key=itemgetter(1), reverse=True
    ) {
        (declared, defined) = registry.unit_functions.get(path, (0, 0));
        log(
            f"    {seconds:7.2f}s {unit_line_count(path):7d} lines "
            f"{declared:6d}/{defined:<6d} {native_unit_identity(path)}"
        );
    }
    return registry.lowered_units;
}

impl build_target_kernel(
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
