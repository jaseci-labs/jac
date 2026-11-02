impl _repo_root -> str {
    return os.path.dirname(jaclang_pkg_root());
}

impl _has_archives(path: str) -> bool {
    return os.path.isdir(path) and any(n.endswith(".a") for n in os.listdir(path));
}

impl _zig_blocker -> str {
    import shutil;
    return "" if shutil.which("zig") else "zig is not on PATH";
}

impl _zig_build(step: str) {
    import subprocess;
    subprocess.run(["zig", "build", step], cwd=_repo_root(), check=True);
}

impl _floor_tier(
    sealed: bool, rel: str, source: Source, check: Callable[[str], bool]
) -> Probe {
    floor_dir = runtime_floor_root(sealed);
    if not floor_dir {
        return Probe.missing("this process runs on no kit");
    }
    path = os.path.join(floor_dir, rel);
    return Probe.hit(source, path, {}) if check(path) else Probe.missing();
}

impl _running_python_variant -> str {
    parts = os.path.realpath(sys.prefix).split(os.sep);
    for (i, part) in enumerate(parts) {
        if part == ".python-build" and i + 1 < len(parts) {
            return parts[i + 1];
        }
    }
    return "";
}

impl CFloorArtifact.target -> str {
    return self.variant or osarch();
}

impl CFloorArtifact.probe_sealed -> (Probe | None) {
    if sealed._jaclang_image() is None {
        return None;
    }
    return _floor_tier(True, self.target(), Source.SEALED, _has_archives);
}

impl CFloorArtifact.probe_checkout -> Probe {
    running = _running_python_variant();
    order = [running]
        + [
            v
            for v in PYTHON_VARIANTS
            if v != running
        ]
        if running
        else list(PYTHON_VARIANTS);
    for variant in order {
        libdir = os.path.join(
            _repo_root(),
            ".python-build",
            variant,
            self.target(),
            "python",
            "build",
            "lib"
        );
        if _has_archives(libdir) {
            return Probe.hit(Source.CHECKOUT, libdir, {"python": variant});
        }
    }
    return Probe.missing();
}

impl CFloorArtifact.probe_kit -> Probe {
    return _floor_tier(False, self.target(), Source.KIT, _has_archives);
}

impl CFloorArtifact.checkout_path -> str {
    return os.path.join(_repo_root(), ".python-build");
}

impl CFloorArtifact.build_blocker -> str {
    if self.target() != osarch() {
        return (
            f"`zig build build-python` builds the C floor only for this host ({osarch()}); "
            f"build it on a {self.target()} host or use a kit that carries it"
        );
    }
    return _zig_blocker();
}

impl CFloorArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    log("  zig build build-python (the source-built Python and its C floor)");
    _zig_build("build-python");
}

impl MuslArtifact.target -> str {
    return self.variant or osarch();
}

impl MuslArtifact.probe_sealed -> (Probe | None) {
    if sealed._jaclang_image() is None {
        return None;
    }
    return _floor_tier(
        True, os.path.join(self.target(), "musl"), Source.SEALED, _has_libc
    );
}

impl MuslArtifact.probe_checkout -> Probe {
    libdir = self.checkout_path();
    return Probe.hit(Source.CHECKOUT, libdir, {})
        if _has_libc(libdir)
        else Probe.missing();
}

impl MuslArtifact.probe_kit -> Probe {
    return _floor_tier(
        False, os.path.join(self.target(), "musl"), Source.KIT, _has_libc
    );
}

impl MuslArtifact.checkout_path -> str {
    return os.path.join(_repo_root(), ".pbs-build", self.target(), "musl", "lib");
}

impl MuslArtifact.build_blocker -> str {
    return _zig_blocker();
}

impl MuslArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    log(f"  zig build vendor-musl-{self.target()}");
    _zig_build(f"vendor-musl-{self.target()}");
}

impl _has_libc(path: str) -> bool {
    return os.path.isfile(os.path.join(path, "libc.a"));
}

impl wasm_rt_src_dir -> str {
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "wasm_rt");
}

impl wasm_floor_drift(libc_dir: str) -> (list[str] | None) {
    manifest = os.path.join(libc_dir, WASM_FLOOR_MANIFEST);
    try {
        with open(manifest, "r", encoding="utf-8") as fh {
            rows = fh.read().splitlines();
        }
    } except OSError {
        return None;
    }
    src_root = wasm_rt_src_dir();
    drifted: list[str] = [];
    for row in rows {
        line = row.strip();
        if not line or " " not in line {
            continue;
        }
        (want, rel) = line.split(" ", 1);
        try {
            with open(os.path.join(src_root, rel.strip()), "rb") as src {
                got = hashlib.sha256(src.read()).hexdigest();
            }
        } except OSError {
            drifted.append(rel.strip());
            continue;
        }
        if got != want {
            drifted.append(rel.strip());
        }
    }
    return drifted;
}

impl _has_bitcode(path: str) -> bool {
    return os.path.isdir(path) and any(n.endswith(".bc") for n in os.listdir(path));
}

impl _wasm_probe(path: str, source: Source) -> Probe {
    if not _has_bitcode(path) {
        return Probe.missing();
    }
    drift = wasm_floor_drift(path);
    if drift is None {
        return Probe.stale(["it carries no source manifest to check against wasm_rt/"]);
    }
    if drift {
        return Probe.stale([f"wasm_rt/{rel} changed" for rel in drift]);
    }
    return Probe.hit(source, path, {});
}

impl WasmLibcArtifact.probe_sealed -> (Probe | None) {
    if sealed._jaclang_image() is None {
        return None;
    }
    return _floor_tier(
        True, os.path.join("wasm32", "libc"), Source.SEALED, _has_bitcode
    );
}

impl WasmLibcArtifact.probe_checkout -> Probe {
    return _wasm_probe(self.checkout_path(), Source.CHECKOUT);
}

impl WasmLibcArtifact.probe_kit -> Probe {
    floor_dir = runtime_floor_root(False);
    if not floor_dir {
        return Probe.missing("this process runs on no kit");
    }
    return _wasm_probe(os.path.join(floor_dir, "wasm32", "libc"), Source.KIT);
}

impl WasmLibcArtifact.checkout_path -> str {
    return os.path.join(_repo_root(), ".pbs-build", "wasm32", "libc");
}

impl WasmLibcArtifact.build_blocker -> str {
    return _zig_blocker();
}

impl WasmLibcArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    log("  zig build vendor-wasm-libc");
    _zig_build("vendor-wasm-libc");
}
