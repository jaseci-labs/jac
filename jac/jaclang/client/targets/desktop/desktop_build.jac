import os;
import json;
import shutil;
import subprocess;
import sys;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.client.targets.desktop._dev_launch { desktop_launch_env }

def _jaclang_src_roots -> list[Path] {
    roots: list[Path] = [];
    jac_src = os.environ.get("JAC_DESKTOP_JAC_SRC");
    if jac_src {
        roots.append(Path(jac_src));
    }
    try {
        import jaclang;
        jl = jaclang?.__file__;
        if jl {
            roots.append(Path(str(jl)).resolve().parent.parent);
        }
    } except Exception {}
    return roots;
}

def _find_desktop_native_dir -> Path {
    for src in _jaclang_src_roots() {
        native = src / "jaclang" / "client" / "targets" / "desktop" / "native";
        if (
            (native / "oauth_broker.jac").is_file()
            and (native / "host_boot.jac").is_file()
            and (native / "webview" / "webview.jac").is_file()
        ) {
            return native;
        }
    }
    here = Path(os.path.abspath(__file__)).parent;
    candidates = [here.parent / "native", here / "native"];
    p = here;
    for _ in range(6) {
        candidates.append(p / "native");
        p = p.parent;
    }
    for cand in candidates {
        if (
            (cand / "oauth_broker.jac").is_file()
            and (cand / "host_boot.jac").is_file()
            and (cand / "webview" / "webview.jac").is_file()
        ) {
            return cand;
        }
    }
    raise RuntimeError(
        "jac-desktop: desktop/native assets incomplete -- need "
        "oauth_broker.jac, host_boot.jac, and webview/webview.jac. "
        "Rebuild the jac binary (zig build) or set JAC_DESKTOP_JAC_SRC."
    );
}

def _find_native_asset_dir(subdir: str, marker: str) -> Path {
    if subdir == "webview" and marker == "webview.jac" {
        import from jaclang.toolchains.desktop { source_workspace }
        return source_workspace(_find_desktop_native_dir() / "webview", "webview");
    }
    for src in _jaclang_src_roots() {
        dev = src / "jaclang" / "client" / "targets" / "desktop" / "native" / subdir;
        if (dev / marker).exists() {
            return dev;
        }
    }
    here = Path(os.path.abspath(__file__)).parent;
    candidates = [here.parent / "native" / subdir, here / "native" / subdir];
    p = here;
    for _ in range(6) {
        candidates.append(p / "native" / subdir);
        p = p.parent;
    }
    for cand in candidates {
        if (cand / marker).exists() {
            return cand;
        }
    }
    raise RuntimeError(
        f"jac-desktop: native/{subdir} assets not found in the package."
    );
}

def _find_webview_dir -> Path {
    import from jaclang.toolchains.desktop { source_workspace }
    return source_workspace(_find_desktop_native_dir() / "webview", "webview");
}

def _find_cef_dir -> Path {
    import from jaclang.toolchains.desktop { source_workspace }
    return source_workspace(_find_native_asset_dir("cef", "cef.jac"), "cef");
}

def _jac_subprocess_env -> dict[str, str] {
    return desktop_launch_env();
}

def _patchelf_rpath(binary: Path, rpath: str) -> bool {
    import from jaclang.toolchains.system { ensure_patchelf }
    patchelf = ensure_patchelf();
    res = subprocess.run([patchelf, "--set-rpath", rpath, str(binary)]);
    if res.returncode != 0 {
        console.print(
            f"  [yellow]patchelf rpath patch failed for {binary.name}; rebuild on this machine if it won't start[/yellow]"
        );
        return False;
    }
    return True;
}

def _patch_host_rpath(binary: Path) {
    _patchelf_rpath(binary, "$ORIGIN");
}


def _fused_runtime_dir -> Path {
    import jaclang;
    return Path(jaclang.__file__).parent / "dist" / "fused";
}


def _stage_fused_runtime(out_dir: Path) {
    src = _fused_runtime_dir();
    if not (src / "bringup.jac").is_file() {
        raise RuntimeError(
            f"jac-desktop: the fused runtime library is missing from this jaclang ({src})."
        );
    }
    dst = out_dir / "fused";
    dst.mkdir(parents=True, exist_ok=True);
    for f in sorted(src.`glob("*.jac")) {
        shutil.copy2(f, dst / f.name);
    }
}


def _bundle_runtime(host_binary: Path) {
    import from jaclang.dist.fused_binary { graft_runtime }
    jac_bin = os.path.realpath(os.sys.executable);

    if not graft_runtime(jac_bin, str(host_binary)) {
        raise RuntimeError(
            "jac-desktop: the running jac binary carries no fused-runtime "
            f"({jac_bin}); a desktop app needs a fused `jac` built via `zig build`. "
            "(A bare pip/source jaclang install has no embeddable runtime.)"
        );
    }
}

def _jac_bin -> str {
    exe = os.environ.get("JAC_EXECUTABLE");
    if exe and os.path.exists(exe) {
        return exe;
    }
    found = shutil.which("jac");
    if found {
        return found;
    }
    raise RuntimeError("jac CLI not found on PATH.");
}

def _cef_bootstrap_js -> str {
    src = (_find_cef_dir() / "cef_dispatch.jac").read_text();
    anchor = "glob BOOTSTRAP_JS: str = \"";
    i = src.find(anchor);
    if i < 0 {
        raise RuntimeError("BOOTSTRAP_JS glob not found in cef_dispatch.jac");
    }
    start = i + len(anchor);
    end = src.find("\";", start);
    if end < 0 {
        raise RuntimeError("BOOTSTRAP_JS glob literal is not terminated");
    }
    return src[start:end];
}

def _jac_sdk_js -> str {
    boot = _cef_bootstrap_js();
    start = boot.find("(function(){var _l={}");
    end = boot.find("(function(){try{");
    if start < 0 or end < 0 or end <= start {
        raise RuntimeError(
            "could not locate the shared JS SDK within BOOTSTRAP_JS "
            "(cef_dispatch.jac bootstrap boundaries changed)"
        );
    }
    return boot[start:end];
}

def _top_level_import_boundary(lines: list[str]) -> int {
    depth = 0;
    idx = 0;
    for line in lines {
        stripped = line.strip();
        if (
            depth == 0
            and stripped != ""
            and (not stripped.startswith("#"))
            and (not stripped.startswith("import"))
        ) {
            return idx;
        }
        depth += line.count("{") - line.count("}");
        idx += 1;
    }
    return len(lines);
}

def _inject_platform(host_src: str, platform_src: str) -> str {
    plat = platform_src[:-1] if platform_src.endswith("\n") else platform_src;
    lines = host_src.split("\n");
    at = _top_level_import_boundary(lines);
    return "\n".join(lines[:at] + [plat] + lines[at:]);
}

def _native_build_cef(
    cef_dir: Path, source_name: str, build_name: str, output: Path, shared: bool,
) -> Path {
    import from jaclang.toolchains.store { InstallLock }
    with InstallLock(cef_dir / ".native-build.lock") {
        build_dir = cef_dir / ".build";
        build_dir.mkdir(parents=True, exist_ok=True);
        build_src = build_dir / build_name;
        host_src = (cef_dir / source_name).read_text();
        platform_src = (cef_dir / "cef_platform.jac").read_text();
        build_src.write_text(_inject_platform(host_src, platform_src));
        cmd = [_jac_bin(), "build", "--native"];
        if shared {
            cmd.append("--lib");
        }
        cmd += [str(build_src), "-o", str(output)];
        res = subprocess.run(cmd);
        if res.returncode != 0 or not output.exists() {
            raise RuntimeError(
                f"jac build --native failed for {output.name} (source {source_name})."
            );
        }
        _patchelf_rpath(output, "$ORIGIN");
        return output;
    }
}


def build_cef_dispatch(cef_dir: Path) -> Path {
    import from jaclang.toolchains.desktop { source_workspace }
    cef_dir = source_workspace(cef_dir, "cef");
    return _native_build_cef(
        cef_dir,
        "cef_dispatch.jac",
        "cef_dispatch_build.jac",
        cef_dir / "libcef_dispatch.so",
        True,
    );
}

def build_cef_subprocess(cef_dir: Path) -> Path {
    import from jaclang.toolchains.desktop { source_workspace }
    cef_dir = source_workspace(cef_dir, "cef");
    return _native_build_cef(
        cef_dir,
        "cef_subprocess.jac",
        "cef_subprocess_build.jac",
        cef_dir / "cef-subprocess",
        False,
    );
}

def serving_app_for(config: any, entry_file: Path, backend: str) -> str {
    if config is None or not config.is_workspace or not config.apps {
        return "";
    }
    owner = config.app_for_path(str(entry_file.resolve()));
    if backend != "embedded" {
        return owner.name if owner is not None else "";
    }
    try {
        chosen = config.resolve_app("");
    } except ValueError {
        chosen = None;
    }
    if chosen is not None and chosen.has_server {
        return chosen.name;
    }
    for app in config.serving_apps() {
        if app.kind == "web-app" {
            return app.name;
        }
    }
    return owner.name if owner is not None else "";
}


def stage_program(
    entry_file: Path,
    project_dir: Path,
    output_dir: Path,
    backend: str,
    dist_dir: (Path | None)
) -> dict[str, str] {
    if dist_dir is None {
        return {"entry": str(entry_file.resolve())};
    }
    import from jaclang.dist.seal { build_jab }
    import from jaclang.project.config { get_config_for_dir }
    config = get_config_for_dir(str(project_dir));
    if config is None {
        raise RuntimeError(f"jac-desktop: no jac.toml under {project_dir}");
    }
    app = serving_app_for(config, entry_file, backend);
    console.print(
        "  Sealing the app image"
            + (f" for '{app}'" if app else "")
            + (
                " (remote backend: the bundle calls it)"
                    if backend != "embedded"
                    else ""
            ),
        style="muted"
    );
    build_jab(config, output_dir / "app.jab", app=app, bake_client=False);
    return {"jab": "app.jab"};
}
