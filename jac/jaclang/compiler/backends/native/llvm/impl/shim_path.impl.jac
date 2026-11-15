impl shim_name -> str {
    if os.name == "posix" {
        return "libjacllvm.dylib" if sys.platform == "darwin" else "libjacllvm.so";
    }
    return "jacllvm.dll";
}

impl placed_shim_path -> str {
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), shim_name());
}

impl llvm_host -> str {
    import platform;
    system = {"linux": "linux", "darwin": "macos"}.get(sys.platform, sys.platform);
    machine = platform.machine().lower();
    machine = {"amd64": "x86_64", "arm64": "aarch64"}.get(machine, machine);
    return f"{system}-{machine}";
}

impl pinned_llvm_blocker(repo_root: str) -> str {
    pins = os.path.join(repo_root, *LLVM_PINS.split("/"));
    try {
        with open(pins, encoding="utf-8") as f {
            slices = json.load(f)["llvm"]["slices"];
        }
    } except (OSError, ValueError, KeyError, TypeError) {
        return f"this tree has no LLVM pin ({LLVM_PINS})";
    }
    host = llvm_host();
    if host in slices {
        return "";
    }
    return f"{LLVM_PINS} pins no LLVM release for this host ({host}); pinned: {', '.join(
        sorted(slices)
    )}";
}

impl _repo_root -> str {
    return os.path.dirname(jaclang_pkg_root());
}

impl shim_inputs_digest(repo_root: str) -> str {
    h = hashlib.sha256();
    for rel in TOOLCHAIN_INPUTS {
        h.update(rel.encode());
        with open(os.path.join(repo_root, *rel.split("/")), "rb") as f {
            h.update(f.read());
        }
    }
    native = os.path.join(repo_root, "native");
    sources: list[str] = [];
    for (walk_dir, dirs, files) in os.walk(native) {
        dirs[:] = [
            d
            for d in dirs
            if not d.startswith(".")
        ];
        for name in files {
            if name.endswith(NATIVE_SOURCE_SUFFIXES) {
                sources.append(
                    os.path.relpath(os.path.join(walk_dir, name), native).replace(
                        os.sep, "/"
                    )
                );
            }
        }
    }
    for rel in sorted(sources) {
        h.update(b"native/");
        h.update(rel.encode());
        with open(os.path.join(native, *rel.split("/")), "rb") as f {
            h.update(f.read());
        }
    }
    return h.hexdigest();
}

impl write_shim_record(shim_path: str, repo_root: str) {
    atomic_write(
        shim_path + RECORD_SUFFIX,
        json.dumps({"inputs": shim_inputs_digest(repo_root)}).encode("utf-8")
    );
}

impl _recorded_inputs(shim_path: str) -> str {
    try {
        with open(shim_path + RECORD_SUFFIX, encoding="utf-8") as f {
            return str(json.load(f).get("inputs", ""));
        }
    } except (OSError, ValueError, AttributeError) {
        return "";
    }
}

impl _probe(shim_path: str, source: Source) -> Probe {
    if not os.path.isfile(shim_path) {
        return Probe.missing();
    }
    recorded = _recorded_inputs(shim_path);
    if not recorded {
        return Probe.stale(
            ["the shim carries no record of the sources it was built from"]
        );
    }
    repo = _repo_root();
    if not os.path.isdir(os.path.join(repo, "native")) {
        return Probe.hit(source, shim_path, {"inputs": recorded});
    }
    if recorded != shim_inputs_digest(repo) {
        return Probe.stale(
            ["jac/native, build.zig or the LLVM pin changed since it was built"]
        );
    }
    return Probe.hit(source, shim_path, {"inputs": recorded});
}

impl ShimArtifact.probe_sealed -> (Probe | None) {
    if sealed._jaclang_image() is None {
        return None;
    }
    path = placed_shim_path();
    return Probe.hit(Source.SEALED, path, {})
        if os.path.isfile(path)
        else Probe.missing("this image carries no LLVM shim");
}

impl ShimArtifact.probe_checkout -> Probe {
    return _probe(placed_shim_path(), Source.CHECKOUT);
}

impl ShimArtifact.probe_kit -> Probe {
    if kit_image() is None {
        return Probe.missing("this process runs on no kit");
    }
    return _probe(
        kit_path(os.path.join("compiler", "backends", "native", "llvm", shim_name())),
        Source.KIT
    );
}

impl ShimArtifact.checkout_path -> str {
    return placed_shim_path();
}

impl ShimArtifact.build_blocker -> str {
    import shutil;
    if not shutil.which("zig") {
        return "zig is not on PATH";
    }
    return pinned_llvm_blocker(_repo_root());
}

impl ShimArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    import subprocess;
    record = self.checkout_path() + RECORD_SUFFIX;
    if force and os.path.isfile(record) {
        os.remove(record);
    }
    log(
        f"  zig build fetch-llvm (the pinned LLVM into {LLVM_CACHE_DIR}/, about 84 MB once)"
    );
    subprocess.run(["zig", "build", "fetch-llvm"], cwd=_repo_root(), check=True);
    log("  zig build jacllvm (links the pinned LLVM; places the shim and its record)");
    subprocess.run(["zig", "build", "jacllvm"], cwd=_repo_root(), check=True);
}

impl shim_path -> str {
    found = require("llvm-shim").found;
    assert found is not None;
    return found.path;
}
