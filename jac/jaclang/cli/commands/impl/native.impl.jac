import time;


def _log(message: str);


def _probe_text(probe: Probe) -> str;


def _status_row(name: str) -> list[str];


def _status(names: list[str]) -> int;


def _require(spec: str) -> int;


def _names_artifact(name: str) -> bool;


def _build(names: list[str], force: bool, exact: bool, release: bool) -> int;


impl native(
    action: str = "status",
    names: (list[str] | None) = None,
    force: bool = False,
    exact: bool = False,
    release: bool = False,
    require: str = "",
    stop_after: int = 0
) -> int {
    names = list(names or []);
    unknown = [
        n
        for n in names
        if not _names_artifact(n)
    ];
    if unknown {
        console.error(
            f"unknown artifact(s): {', '.join(unknown)} (known: {', '.join(
                router.names()
            )})"
        );
        return 1;
    }
    if action == "status" {
        return _require(require) if require else _status(names);
    }
    if stop_after {
        if action != "build" or names != ["kernel"] or stop_after < 0 {
            console.error(
                "--stop-after takes a positive count and only `jac native build kernel`"
            );
            return 1;
        }
        plan_kernel_prefix(stop_after, _log);
        return 0;
    }
    if action == "build" {
        return _build(names, force, exact, release);
    }
    console.error(f"unknown action: {action} (expected status or build)");
    return 1;
}

impl _log(message: str) {
    console.print(message);
}


impl _probe_text(probe: Probe) -> str {
    if probe.found is not None {
        return f"current ({probe.found.path})";
    }
    return probe.describe();
}


impl _status_row(name: str) -> list[str] {
    artifact = router.artifact_named(name);
    resolution = router.resolve(name);
    in_use = resolution.found.source.value
        if resolution.found is not None
        else (f"floor: {artifact.floor}" if artifact.floor else "unavailable");
    return [
        name,
        artifact.kind.value,
        artifact.release.value,
        in_use,
        resolution.reason if resolution.on_floor() else ""
    ];
}


impl _status(names: list[str]) -> int {
    chosen = names or router.names();
    if len(chosen) > 1 or not names {
        console.print_table(
            ["artifact", "kind", "release", "in use", "why"],
            [_status_row(name) for name in chosen]
        );
        return 0;
    }
    name = chosen[0];
    artifact = router.artifact_named(name);
    console.print(
        f"{name}: {artifact.summary} ({artifact.kind.value}, release: {artifact.release.value})"
    );
    for (tier, probe) in router.tiers(name) {
        console.print(f"  {tier}: {_probe_text(probe)}");
        for reason in probe.drift[1:20] if len(probe.drift) > 1 else [] {
            console.print(f"      - {reason}");
        }
        if len(probe.drift) > 20 {
            console.print(f"      ... and {len(probe.drift) - 20} more");
        }
    }
    row = _status_row(name);
    console.print(f"  in use: {row[3]}");
    return 0;
}


impl _require(spec: str) -> int {
    if spec in ("release", "kit") {
        omitted = router.omitted_by_image() if spec == "kit" else frozenset();
        wanted = [
            n
            for n in router.release_set()
            if n not in omitted
        ]
            + router.shipped_floors();
    } else {
        wanted = [
            part.strip()
            for part in spec.split(",")
            if part.strip()
        ];
    }
    problems = router.unmet(wanted);
    for problem in problems {
        console.error(problem);
    }
    if problems {
        return 1;
    }
    console.success(f"in place: {', '.join(wanted)}");
    return 0;
}


impl _names_artifact(name: str) -> bool {
    (base, at, variant) = name.partition("@");
    return base in router.names() and (not at or bool(variant));
}


impl _build(names: list[str], force: bool, exact: bool, release: bool) -> int {
    started = time.monotonic();
    if release {
        requested = router.release_set();
        for name in router.shipped_floors() {
            router.artifact_named(name).provide_floor(_log);
        }
    } else {
        requested = names or router.release_set();
    }
    try {
        built = router.build(requested, _log, force=force, exact=exact, strict=release);
    } except ArtifactUnavailable as e {
        console.error(str(e));
        return 1;
    }
    summary = ", ".join(built) if built else "nothing to build";
    console.success(f"{summary} ({time.monotonic() - started:.1f}s)");
    return 0;
}
