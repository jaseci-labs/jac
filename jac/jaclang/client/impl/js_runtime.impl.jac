impl bun_name -> str {
    return "bun.exe" if platform.system() == "Windows" else "bun";
}

impl bun_path_in(pkg_dir: str) -> str {
    return os.path.join(pkg_dir, "client", "_bun", bun_name());
}

impl write_bun_record(path: str) {
    atomic_write(
        path + RECORD_SUFFIX, json.dumps({"version": BUN_VERSION}).encode("utf-8")
    );
}

impl _recorded_version(path: str) -> str {
    try {
        with open(path + RECORD_SUFFIX, encoding="utf-8") as f {
            return str(json.load(f).get("version", ""));
        }
    } except (OSError, ValueError, AttributeError) {
        return "";
    }
}

impl _reported_version(path: str) -> str {
    import subprocess;
    try {
        done = subprocess.run(
            [path, "--version"], capture_output=True, text=True, timeout=10
        );
    } except (OSError, subprocess.SubprocessError) {
        return "";
    }
    return done.stdout.strip() if done.returncode == 0 else "";
}

impl _probe_bun(path: str, source: Source) -> Probe {
    if not os.path.isfile(path) {
        return Probe.missing();
    }
    version = _recorded_version(path);
    if version and version != BUN_VERSION {
        return Probe.stale([f"bun {version} is not the pinned {BUN_VERSION}"]);
    }
    if platform.system() != "Windows" and not os.access(path, os.X_OK) {
        try {
            os.chmod(path, 0o755);
        } except OSError as e {
            return Probe.stale([f"bun at {path} is not executable: {e}"]);
        }
    }
    version = version or _reported_version(path);
    if version != BUN_VERSION {
        return Probe.stale(
            [f"bun {version or 'of unknown version'} is not the pinned {BUN_VERSION}"]
        );
    }
    return Probe.hit(source, path, {"version": version});
}

impl _pkg_dir -> str {
    return jaclang_pkg_root();
}

impl BunArtifact.probe_sealed -> (Probe | None) {
    image = sealed._jaclang_image();
    if image is None {
        return None;
    }
    return _probe_bun(bun_path_in(str(image.pkg_dir)), Source.SEALED);
}

impl BunArtifact.probe_checkout -> Probe {
    return _probe_bun(bun_path_in(_pkg_dir()), Source.CHECKOUT);
}

impl BunArtifact.probe_kit -> Probe {
    found = kit_image();
    if found is None {
        return Probe.missing("this process runs on no kit");
    }
    return _probe_bun(bun_path_in(found[0]), Source.KIT);
}

impl BunArtifact.checkout_path -> str {
    return bun_path_in(_pkg_dir());
}

impl BunArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    fetch_bun(osarch(), os.path.dirname(self.checkout_path()));
}

impl _repo_root -> str {
    return os.path.dirname(_pkg_dir());
}

impl js_engine_build_dir -> str {
    return os.path.join(_repo_root(), "zig-out", "js");
}

impl js_engine_inputs_digest(repo_root: str) -> str {
    import hashlib;
    digest = hashlib.sha256();
    base = os.path.join(repo_root, "js_engine");
    for rel in ENGINE_SOURCES {
        top = os.path.join(base, rel);
        paths = [top]
            if os.path.isfile(top)
            else sorted(
                os.path.join(d, f) for (d, _dirs, files) in os.walk(top) for f in files
            );
        for path in paths {
            digest.update(os.path.relpath(path, base).encode("utf-8"));
            with open(path, "rb") as f {
                digest.update(hashlib.sha256(f.read()).digest());
            }
        }
    }
    return digest.hexdigest();
}

impl installed_engine_dir -> str {
    return str(bucket("js-engine").path() / "current");
}

impl _installed_engine -> Probe {
    engine = installed_engine_dir();
    return Probe.hit(Source.CACHE, engine, {"inputs": _engine_record(engine)})
        if os.path.isfile(os.path.join(engine, ENGINE_LIBRARY))
        else Probe.missing("no engine is installed (jac native build js-engine)");
}

impl ensure_node_link(engine: str) -> str {
    link = os.path.join(engine, "bin", "node");
    exe = process_executable();
    try {
        current = os.readlink(link);
    } except OSError {
        current = "";
    }
    if current != exe {
        os.makedirs(os.path.dirname(link), exist_ok=True);
        staged = f"{link}.{os.getpid()}";
        os.symlink(exe, staged);
        os.replace(staged, link);
    }
    return link;
}

impl _install_engine(built: str) {
    import shutil;
    target = installed_engine_dir();
    os.makedirs(os.path.dirname(target), exist_ok=True);
    staging = f"{target}.{os.getpid()}";
    retired = f"{target}.old.{os.getpid()}";
    shutil.rmtree(staging, ignore_errors=True);
    shutil.copytree(built, staging, symlinks=True);
    if os.path.isdir(target) {
        os.replace(target, retired);
    }
    os.replace(staging, target);
    shutil.rmtree(retired, ignore_errors=True);
}

impl _engine_record(engine: str) -> str {
    try {
        with open(os.path.join(engine, RECORD_SUFFIX), encoding="utf-8") as f {
            return str(json.load(f).get("inputs", ""));
        }
    } except (OSError, ValueError, AttributeError) {
        return "";
    }
}

impl JsEngineArtifact.probe_sealed -> (Probe | None) {
    import sys;
    if sealed._jaclang_image() is None {
        return None;
    }
    engine = os.path.join(os.path.dirname(sys.prefix), "js");
    if os.path.isfile(os.path.join(engine, ENGINE_LIBRARY)) {
        return Probe.hit(Source.SEALED, engine, {});
    }
    installed = _installed_engine();
    return installed if installed.found is not None else Probe.by_design();
}

impl JsEngineArtifact.probe_checkout -> Probe {
    engine = js_engine_build_dir();
    if not os.path.isfile(os.path.join(engine, ENGINE_LIBRARY)) {
        return Probe.missing();
    }
    if _engine_record(engine) != js_engine_inputs_digest(_repo_root()) {
        return Probe.stale(["js_engine/ changed since the engine was built"]);
    }
    return Probe.hit(Source.CHECKOUT, engine, {});
}

impl JsEngineArtifact.probe_kit -> Probe {
    if os.path.isdir(os.path.join(_repo_root(), "js_engine")) {
        return Probe.missing("a checkout with js_engine/ uses its own build");
    }
    return _installed_engine();
}

impl JsEngineArtifact.checkout_path -> str {
    return js_engine_build_dir();
}

impl JsEngineArtifact.built -> Probe {
    found = self.probe_checkout();
    if found.found is None {
        return found;
    }
    if _engine_record(installed_engine_dir()) != _engine_record(found.found.path) {
        return Probe.stale(["the engine is built but not installed"]);
    }
    return found;
}

impl JsEngineArtifact.build_blocker -> str {
    import shutil;
    if not os.path.isdir(os.path.join(_repo_root(), "js_engine")) {
        return "this tree has no js_engine/";
    }
    if shutil.which("zig") or self.probe_checkout().found is not None {
        return "";
    }
    return "zig is not on PATH";
}

impl JsEngineArtifact.build(log: Callable[[str], None], force: bool, exact: bool) {
    import subprocess;

    if force or self.probe_checkout().found is None {
        log("  zig build js-engine (about 18 minutes and 7 GB cold)");
        subprocess.run(["zig", "build", "js-engine"], cwd=_repo_root(), check=True);
        atomic_write(
            os.path.join(js_engine_build_dir(), RECORD_SUFFIX),
            json.dumps({"inputs": js_engine_inputs_digest(_repo_root())}).encode(
                "utf-8"
            )
        );
    }
    ensure_node_link(js_engine_build_dir());
    _install_engine(js_engine_build_dir());
    log(f"  installed for every jac at {installed_engine_dir()}");
}

impl JsEngineArtifact.floor_present -> bool {
    return resolve("bun").found is not None;
}

impl JsEngineArtifact.provide_floor(log: Callable[[str], None]) {
    build(["bun"], log);
}

impl _engine -> (str | None) {
    found = resolve("js-engine").found;
    return found.path if found is not None else None;
}

impl js_runtime_path -> str {
    if _engine() is not None {
        import from jaclang.client.js_engine { node_executable }
        return node_executable();
    }
    bun = require("bun").found;
    assert bun is not None;
    return bun.path;
}

impl run_pm(args: list[str], cwd: str, capture: bool = False) -> tuple[int, str] {
    import subprocess;
    runtime = js_runtime_path();
    env = dict(os.environ);
    if _engine() is not None {
        env["PATH"] = os.path.dirname(runtime) + os.pathsep + env.get("PATH", "");
    }
    result = subprocess.run(
        [runtime] + list(args), cwd=cwd, env=env, text=True, capture_output=capture
    );
    if not capture {
        return (result.returncode, "");
    }
    return (
        result.returncode,
        (getattr(result, "stderr", "") or "") + (getattr(result, "stdout", "") or "")
    );
}
