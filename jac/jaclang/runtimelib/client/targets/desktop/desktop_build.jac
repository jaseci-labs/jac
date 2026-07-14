import os;
import json;
import shutil;
import hashlib;
import subprocess;
import sys;
import tarfile;
import from urllib.request { urlopen, urlretrieve }
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.utils { host_arch }
import from jaclang.runtimelib.client.targets.desktop._dev_launch { desktop_launch_env }

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
    } except Exception {
        ;
    }
    return roots;
}

def _find_desktop_native_dir -> Path {
    for src in _jaclang_src_roots() {
        native = (
            src / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native"
        );
        if (
            (native / "oauth_broker.jac").is_file()
            and (native / "inprocess_dispatch.jac").is_file()
            and (native / "webview" / "webview.na.jac").is_file()
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
            and (cand / "inprocess_dispatch.jac").is_file()
            and (cand / "webview" / "webview.na.jac").is_file()
        ) {
            return cand;
        }
    }
    raise RuntimeError(
        "jac-desktop: desktop/native assets incomplete -- need "
        "oauth_broker.jac, inprocess_dispatch.jac, and webview/webview.na.jac. "
        "Rebuild the jac binary (zig build) or set JAC_DESKTOP_JAC_SRC."
    );
}

def _find_native_asset_dir(subdir: str, marker: str) -> Path {
    if subdir == "webview" and marker == "webview.na.jac" {
        return _find_desktop_native_dir() / "webview";
    }
    for src in _jaclang_src_roots() {
        dev = (
            src / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native" / subdir
        );
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
    return _find_desktop_native_dir() / "webview";
}

def _find_cef_dir -> Path {
    return _find_native_asset_dir("cef", "cef.na.jac");
}

def _jac_subprocess_env -> dict[str, str] {
    return desktop_launch_env();
}

def _patchelf_rpath(binary: Path, rpath: str) -> bool {
    patchelf = shutil.which("patchelf");
    if not patchelf {
        console.print(
            f"  [yellow]patchelf not found; {binary.name}'s shared deps must be on LD_LIBRARY_PATH at runtime[/yellow]"
        );
        return False;
    }
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


def _pyembed_shim_name -> str {
    if sys.platform == "darwin" {
        return "libjacpyembed.dylib";
    }
    if sys.platform.startswith("win") {
        return "jacpyembed.dll";
    }
    return "libjacpyembed.so";
}


def _stage_pyembed_shim(out_dir: Path) {
    name = _pyembed_shim_name();
    src = _find_desktop_native_dir() / name;
    if not src.exists() {
        raise RuntimeError(
            f"jac-desktop: {name} not found in the fused runtime ({src}). "
            "Rebuild the jac binary (zig build) so the payload carries the "
            "libjacpyembed shim."
        );
    }
    shutil.copy2(src, out_dir / name);
}


def _bundle_runtime(host_binary: Path) {
    import subprocess;
    jac_bin = os.path.realpath(os.sys.executable);

    rc = subprocess.run([jac_bin, "__graftrt", str(host_binary)]).returncode;
    if rc != 0 {
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
    src = (_find_cef_dir() / "cef_dispatch.na.jac").read_text();
    anchor = "glob BOOTSTRAP_JS: str = \"";
    i = src.find(anchor);
    if i < 0 {
        raise RuntimeError("BOOTSTRAP_JS glob not found in cef_dispatch.na.jac");
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
            "(cef_dispatch.na.jac bootstrap boundaries changed)"
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

def _nacompile_cef(
    cef_dir: Path, source_name: str, build_name: str, output: Path, shared: bool,
) -> Path {
    build_dir = cef_dir / ".build";
    build_dir.mkdir(parents=True, exist_ok=True);
    build_src = build_dir / build_name;
    host_src = (cef_dir / source_name).read_text();
    platform_src = (cef_dir / "cef_platform.na.jac").read_text();
    build_src.write_text(_inject_platform(host_src, platform_src));
    cmd = [_jac_bin(), "nacompile"];
    if shared {
        cmd.append("--shared");
    }
    cmd += [str(build_src), "-o", str(output)];
    res = subprocess.run(cmd);
    if res.returncode != 0 or not output.exists() {
        raise RuntimeError(
            f"jac nacompile failed for {output.name} (source {source_name})."
        );
    }
    _patchelf_rpath(output, "$ORIGIN");
    return output;
}

def build_cef_dispatch(cef_dir: Path) -> Path {
    return _nacompile_cef(
        cef_dir,
        "cef_dispatch.na.jac",
        "cef_dispatch_build.na.jac",
        cef_dir / "libcef_dispatch.so",
        True,
    );
}

def build_cef_subprocess(cef_dir: Path) -> Path {
    return _nacompile_cef(
        cef_dir,
        "cef_subprocess.na.jac",
        "cef_subprocess_build.na.jac",
        cef_dir / "cef-subprocess",
        False,
    );
}

def _cef_locked_version(sums_lock: Path) -> str {
    for line in sums_lock.read_text().split("\n") {
        s = line.strip();
        if s.startswith("# version:") {
            return s[len("# version:"):].strip();
        }
    }
    return "";
}

def _cef_expected_sha1(sums_lock: Path, archive: str) -> str {
    for line in sums_lock.read_text().split("\n") {
        s = line.strip();
        if (not s) or s.startswith("#") {
            continue;
        }
        parts = s.split();
        if len(parts) == 2 and parts[1] == archive {
            return parts[0];
        }
    }
    return "";
}

def _cef_plat_tag -> str {
    arch = host_arch();
    if arch == "x86_64" {
        return "linux64";
    }
    if arch == "aarch64" {
        return "linuxarm64";
    }
    raise RuntimeError(f"unsupported architecture for CEF: {arch}");
}

def _cef_index_sha1(plat_tag: str, archive: str) -> str {
    try {
        with urlopen(
            "https://cef-builds.spotifycdn.com/index.json", timeout=30
        ) as resp {
            idx = json.loads(resp.read().decode("utf-8"));
        }
        versions = idx.get(plat_tag, {}).get("versions", []);
        for v in versions {
            for f in v.get("files", []) {
                if f.get("name") == archive {
                    return f.get("sha1", "");
                }
            }
        }
    } except Exception {
        return "";
    }
    return "";
}

def _sha1_file(path: Path) -> str {
    h = hashlib.sha1();
    with open(str(path), "rb") as f {
        while True {
            chunk = f.read(1048576);
            if not chunk {
                break;
            }
            h.update(chunk);
        }
    }
    return h.hexdigest();
}

def _extract_cef_headers(tarball: Path, headers_dir: Path) {
    if headers_dir.exists() {
        shutil.rmtree(headers_dir);
    }
    with tarfile.open(str(tarball), "r:bz2") as tf {
        for m in tf {
            parts = m.name.split("/", 1);
            if len(parts) < 2 {
                continue;
            }
            rel = parts[1];
            if not rel.startswith("include/") {
                continue;
            }
            target = headers_dir / rel;
            if m.isdir() {
                target.mkdir(parents=True, exist_ok=True);
            } else {
                target.parent.mkdir(parents=True, exist_ok=True);
                with tf.extractfile(m) as src {
                    with open(str(target), "wb") as dst {
                        shutil.copyfileobj(src, dst);
                    }
                }
            }
        }
    }
}

def _extract_cef_runtime(tarball: Path, dist_dir: Path) {
    need = {
        "libcef.so",
        "libEGL.so",
        "libGLESv2.so",
        "libvk_swiftshader.so",
        "vk_swiftshader_icd.json",
        "v8_context_snapshot.bin",
        "chrome-sandbox",
        "icudtl.dat"
    };
    if dist_dir.exists() {
        shutil.rmtree(dist_dir);
    }
    dist_dir.mkdir(parents=True, exist_ok=True);
    with tarfile.open(str(tarball), "r:bz2") as tf {
        for m in tf {
            parts = m.name.split("/", 1);
            if len(parts) < 2 {
                continue;
            }
            rel = parts[1];
            base = rel.split("/")[-1];
            seg0 = rel.split("/")[0];
            want = (base in need) or base.endswith(".pak") or (seg0 == "locales");
            if not want {
                continue;
            }
            flat = rel;
            for pfx in ["Release/", "Resources/", "Debug/"] {
                if flat.startswith(pfx) {
                    flat = flat[len(pfx):];
                    break;
                }
            }
            target = dist_dir / flat;
            if m.isdir() {
                target.mkdir(parents=True, exist_ok=True);
            } else {
                target.parent.mkdir(parents=True, exist_ok=True);
                with tf.extractfile(m) as src {
                    with open(str(target), "wb") as dst {
                        shutil.copyfileobj(src, dst);
                    }
                }
            }
        }
    }
}

def fetch_cef_dist(cef_dir: Path, headers_only: bool = False) -> Path {
    sums_lock = cef_dir / "cef_sums.lock";
    if not sums_lock.exists() {
        raise RuntimeError(f"missing CEF trust anchor: {sums_lock}");
    }
    version = os.environ.get("CEF_VERSION") or _cef_locked_version(sums_lock);
    if not version {
        raise RuntimeError(f"no '# version:' directive in {sums_lock}");
    }
    dist_dir = cef_dir / "cef_dist";
    version_stamp = dist_dir / ".cef_version";
    headers_dir = cef_dir / "cef_headers";
    headers_marker = headers_dir / "include" / "capi" / "cef_app_capi.h";
    cached_tarball = cef_dir / ".cef_tarball.tar.bz2";

    if headers_only and headers_marker.exists() {
        return headers_dir;
    }
    if (
        (not headers_only)
        and version_stamp.exists()
        and (version_stamp.read_text().strip() == version)
        and (dist_dir / "libcef.so").exists()
        and headers_marker.exists()
    ) {
        return dist_dir;
    }

    plat_tag = _cef_plat_tag();
    archive = f"cef_binary_{version}_{plat_tag}.tar.bz2";
    expected = _cef_expected_sha1(sums_lock, archive);
    if not expected {
        raise RuntimeError(
            f"no pinned SHA-1 for {archive} in cef_sums.lock; refusing to "
            "download an unverified CEF archive."
        );
    }
    resolved = f"https://cef-builds.spotifycdn.com/{archive}";
    console.print(f"  Resolving CEF {version} for {plat_tag}...", style="muted");

    index_sha1 = _cef_index_sha1(plat_tag, archive);
    if index_sha1 and (index_sha1 != expected) {
        raise RuntimeError(
            "live CEF index SHA-1 disagrees with cef_sums.lock for " + archive + f" (pinned {expected}, index {index_sha1}); pin or release host is stale."
        );
    }

    if not cached_tarball.exists() {
        console.print(
            "  Downloading CEF distribution (~800 MB, one-time)...", style="muted"
        );
        ok = False;
        last_err = "";
        for _ in range(3) {
            try {
                urlretrieve(resolved, str(cached_tarball));
                ok = True;
                break;
            } except Exception as err {
                last_err = str(err);
            }
        }
        if not ok {
            raise RuntimeError(f"CEF download failed: {last_err}");
        }
    }

    actual = _sha1_file(cached_tarball);
    if actual != expected {
        cached_tarball.unlink();
        raise RuntimeError(
            f"SHA-1 mismatch for CEF archive (expected {expected}, got {actual}); "
            "deleted the corrupted download."
        );
    }
    console.print(f"  SHA-1 verified: {actual}", style="muted");

    if headers_only {
        if not headers_marker.exists() {
            _extract_cef_headers(cached_tarball, headers_dir);
        }
        return headers_dir;
    }

    if not (dist_dir / "libcef.so").exists() {
        console.print(f"  Extracting CEF runtime to {dist_dir}...", style="muted");
        _extract_cef_runtime(cached_tarball, dist_dir);
    }
    version_stamp.write_text(version);
    if not headers_marker.exists() {
        _extract_cef_headers(cached_tarball, headers_dir);
    }
    console.print(f"  Staged CEF {version} in {dist_dir}", style="muted");
    return dist_dir;
}
