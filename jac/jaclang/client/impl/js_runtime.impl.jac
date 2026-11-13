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

impl js_runtime_path -> str {
    bun = require("bun").found;
    assert bun is not None;
    return bun.path;
}

impl release_age_settings(npm: dict[str, any]) -> tuple[float, list[str]] {
    return (
        float(npm.get("min_release_age_days", MIN_RELEASE_AGE_DAYS)),
        list(npm.get("min_release_age_excludes", []))
    );
}

impl _project_npm(cwd: str) -> dict[str, any] {
    config = get_config_for_dir(cwd) or get_config_for_dir(os.getcwd());
    return config.get_plugin_config("client").get("npm", {}) if config else {};
}

impl run_pm(
    args: list[str],
    cwd: str,
    capture: bool = False,
    release_age: (tuple[float, list[str]] | None) = None
) -> tuple[int, str] {
    import subprocess;
    runtime = js_runtime_path();
    bunfig = os.path.join(cwd, "bunfig.toml");
    excludes: list[str] = [];
    if args and args[0] in ("install", "add") {
        (days, excludes) = release_age or release_age_settings(_project_npm(cwd));
        args = [args[0], f"--minimum-release-age={int(days * 86400)}"] + list(args[1:]);
    }
    owns_bunfig = bool(excludes) and not os.path.exists(bunfig);
    if owns_bunfig {
        with open(bunfig, "w", encoding="utf-8") as f {
            f.write(f"[install]\nminimumReleaseAgeExcludes = {json.dumps(excludes)}\n");
        }
    }
    try {
        result = subprocess.run(
            [runtime] + list(args), cwd=cwd, text=True, capture_output=capture
        );
    } finally {
        if owns_bunfig {
            os.remove(bunfig);
        }
    }
    if not capture {
        return (result.returncode, "");
    }
    return (
        result.returncode,
        (getattr(result, "stderr", "") or "") + (getattr(result, "stdout", "") or "")
    );
}
