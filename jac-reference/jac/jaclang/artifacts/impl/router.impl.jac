impl names -> list[str] {
    return list(ARTIFACTS);
}

impl artifact_named(name: str) -> Artifact {
    found = _ENTRIES.get(name);
    if found is not None {
        return found;
    }
    import importlib;

    (base, _, variant) = name.partition("@");
    target = ARTIFACTS.get(base);
    if target is None {
        raise KeyError(f"no artifact named {base!r}; known: {', '.join(ARTIFACTS)}");
    }
    (module_name, attr) = target.split(":", 1);
    made = getattr(importlib.import_module(module_name), attr)();
    if variant {
        made.variant = variant;
        made.name = name;
    }
    _ENTRIES[name] = made;
    return made;
}

impl resolve(name: str) -> Resolution {
    known = _RESOLVED.get(name);
    if known is not None {
        return known;
    }

    if resolution_in_flight() {
        return Resolution(name=name, reason="still loading", quiet=True, deferred=True);
    }
    resolution = _decide(artifact_named(name));
    _RESOLVED[name] = resolution;
    if resolution.on_floor() and not resolution.quiet {
        _announce(artifact_named(name), resolution);
    }
    return resolution;
}

impl require(name: str) -> Resolution {
    resolution = resolve(name);
    artifact = artifact_named(name);
    if resolution.on_floor()
        and artifact.provision
        and not resolution.deferred
        and artifact.host_supported() {
        resolution = _provision(artifact, resolution);
    }
    if resolution.on_floor() {
        raise ArtifactUnavailable(
            f"{artifact.summary} is unavailable: {resolution.reason or 'not built'}. "
            f"Run `jac native build {name}`."
        );
    }
    return resolution;
}

impl forget(name: str = "") -> None {
    if name {
        _RESOLVED.pop(name, None);
        _ANNOUNCED.discard(name);
        return;
    }
    _RESOLVED.clear();
    _ANNOUNCED.clear();
}

impl building_now -> frozenset[str] {
    return marked();
}

impl building(names: list[str]) -> _BuildingSpan {
    return _BuildingSpan(added=list(names));
}

impl _BuildingSpan.__enter__ -> _BuildingSpan {
    self.added = begin(self.added);
    forget();
    return self;
}

impl _BuildingSpan.__exit__(
    _exc_type: object, _exc_value: object, _traceback: object
) -> bool {
    end(self.added);
    forget();
    return False;
}

impl build_order(requested: list[str]) -> list[str] {
    ordered: list[str] = [];
    visiting: set[str] = set();

    def place(name: str) {
        if name in ordered {
            return;
        }
        if name in visiting {
            raise ValueError(f"artifact dependency cycle through {name}");
        }
        visiting.add(name);
        for dep in artifact_named(name).requires {
            place(dep);
        }
        visiting.discard(name);
        ordered.append(name);
    }

    for name in requested {
        place(name);
    }
    return ordered;
}

impl publish(stage: str, destination: str, companions: tuple[str, ...] = ()) -> None {
    import from pathlib { Path }

    payloads = [(destination, Path(stage).read_bytes(), 0o755)];
    for suffix in companions {
        payloads.append(
            (destination + suffix, Path(stage + suffix).read_bytes(), 0o644)
        );
    }
    with FileLock(destination + ".lock") {
        for (path, data, mode) in payloads {
            atomic_write(path, data, mode=mode);
        }
    }
}

impl tiers(name: str) -> list[tuple[str, Probe]] {
    artifact = artifact_named(name);
    found: list[tuple[str, Probe]] = [];
    sealed = artifact.probe_sealed();
    if sealed is not None {
        return [(Source.SEALED.value, sealed)];
    }
    found.append((Source.CHECKOUT.value, artifact.probe_checkout()));
    found.append((Source.KIT.value, artifact.probe_kit()));
    return found;
}

impl release_set -> list[str] {
    return [
        n
        for n in names()
        if artifact_named(n).release == ReleasePolicy.REQUIRED
    ];
}

impl shipped_floors -> list[str] {
    return [
        n
        for n in names()
        if artifact_named(n).release == ReleasePolicy.FLOOR
    ];
}

impl build(
    requested: list[str],
    log: Callable[[str], None],
    force: bool = False,
    exact: bool = False,
    strict: bool = False
) -> list[str] {
    import subprocess;
    built: list[str] = [];
    for name in build_order(requested) {
        artifact = artifact_named(name);
        if not artifact.host_supported() {
            message = f"{name}: cannot be built on this host";
            if strict {
                raise ArtifactUnavailable(message);
            }
            log(f"skipped {message}");
            continue;
        }
        why = artifact.unavailable_reason() or artifact.build_blocker();
        if why {
            if strict {
                raise ArtifactUnavailable(f"{name}: {why}");
            }
            log(f"skipped {name}: {why}");
            continue;
        }
        if not (force and name in requested) and artifact.built().found is not None {
            log(f"{name}: current");
            continue;
        }
        log(f"building {name}");
        try {
            with building([name]) {
                artifact.build(log, force, exact);
            }
        } except subprocess.CalledProcessError as e {
            command = " ".join(str(part) for part in e.cmd)
                if isinstance(e.cmd, (list, tuple))
                else str(e.cmd);
            raise ArtifactUnavailable(
                f"{name}: `{command}` failed (exit status {e.returncode}); see its output above"
            ) from None;
        }
        forget(name);
        after = artifact.built();
        if after.found is None {
            raise ArtifactUnavailable(
                f"{name} was built but does not match its inputs: "
                    + "; ".join(after.drift[:5])
            );
        }
        built.append(name);
    }
    return built;
}

impl unmet(required: list[str]) -> list[str] {
    problems: list[str] = [];
    for name in required {
        artifact = artifact_named(name);
        if not artifact.host_supported() {
            continue;
        }
        if artifact.release == ReleasePolicy.FLOOR {
            if not artifact.floor_present() {
                problems.append(
                    f"{name}: its shipped floor ({artifact.floor}) is missing"
                );
            }
            continue;
        }
        resolution = resolve(name);
        if resolution.on_floor() {
            problems.append(f"{name}: {resolution.reason or 'not built'}");
        }
    }
    return problems;
}

impl _decide(artifact: Artifact) -> Resolution {
    if artifact.disabled() {
        return Resolution(name=artifact.name, reason="being built", quiet=True);
    }
    if artifact.name in _omitted(sealed_image=True) {
        return Resolution(
            name=artifact.name, reason="this image leaves it out", quiet=True
        );
    }
    sealed = artifact.probe_sealed();
    if sealed is not None {
        if sealed.found is not None {
            return Resolution(name=artifact.name, found=sealed.found);
        }
        return Resolution(
            name=artifact.name,
            reason="this image ships its floor",
            quiet=sealed.omitted
        );
    }
    why = artifact.unavailable_reason();
    if why {
        return Resolution(name=artifact.name, reason=why);
    }
    tree = artifact.probe_checkout();
    if tree.found is not None {
        return Resolution(name=artifact.name, found=tree.found);
    }
    if artifact.name in _omitted(sealed_image=False) {
        return Resolution(
            name=artifact.name, reason="the kit leaves it out", quiet=True
        );
    }
    kit = artifact.probe_kit();
    if kit.found is not None {
        return Resolution(name=artifact.name, found=kit.found);
    }
    if kit.omitted {
        return Resolution(
            name=artifact.name, reason="the kit ships its floor", quiet=True
        );
    }
    return Resolution(name=artifact.name, reason=tree.describe());
}

impl omitted_by_image -> frozenset[str] {
    return _omitted(sealed_image=True) | _omitted(sealed_image=False);
}

impl _omitted(sealed_image: bool) -> frozenset[str] {
    if sealed_image {
        import from jaclang.jac0core { sealed }
        image = sealed._jaclang_image();
        return image.omits if image is not None else frozenset();
    }

    found = kit_image();
    return found[1].omits if found is not None else frozenset();
}

impl _provision(artifact: Artifact, resolution: Resolution) -> Resolution {
    import sys;

    if offline_mode() {
        return Resolution(
            name=artifact.name,
            reason=f"{resolution.reason
                or 'not provisioned'}, and this project is offline ([network] offline)"
        );
    }
    sys.stderr.write(
        f"jac: provisioning {artifact.summary} ({resolution.reason
            or 'not provisioned yet'}); "
        f"`jac native build {artifact.name}` does this ahead of time.\n"
    );
    sys.stderr.flush();
    build([artifact.name], _to_stderr);
    return resolve(artifact.name);
}

impl _to_stderr(line: str) {
    import sys;
    sys.stderr.write(line + "\n");
}

impl _announce(artifact: Artifact, resolution: Resolution) {
    if artifact.name in _ANNOUNCED
        or artifact.kind != ArtifactKind.ACCELERATOR
        or artifact.release == ReleasePolicy.FLOOR {
        return;
    }
    _ANNOUNCED.add(artifact.name);
    import sys;
    (on, off) = ("\033[1;33m", "\033[0m") if sys.stderr.isatty() else ("", "");
    sys.stderr.write(
        f"{on}jac: {artifact.name} runs on its floor ({artifact.floor}, slower): "
        f"{resolution.reason}. Run `jac native build {artifact.name}`; "
        f"`jac native status {artifact.name}` shows what moved.{off}\n"
    );
    sys.stderr.flush();
}
