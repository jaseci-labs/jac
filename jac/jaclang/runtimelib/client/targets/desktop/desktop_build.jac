"""Shared build helpers for native and CEF desktop targets."""
import os;
import json;
import shutil;
import hashlib;
import subprocess;
import sys;
import sysconfig;
import tarfile;
import platform;
import from urllib.request { urlopen, urlretrieve }
import from pathlib { Path }
import from jaclang.cli.console { console }

"""Locate a shipped native/ asset dir (webview, cef, …) inside jac_desktop."""
def _find_native_asset_dir(subdir: str, marker: str) -> Path {
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
    return _find_native_asset_dir("webview", "webview.na.jac");
}

def _find_cef_dir -> Path {
    return _find_native_asset_dir("cef", "cef.na.jac");
}

"""Set an ELF RUNPATH on a binary via patchelf; warn (don't fail) if absent.

Single place that shells out to patchelf for every desktop artifact -- the host
binary (`$ORIGIN:LIBDIR` for libpython) and the CEF native pieces (`$ORIGIN` for
the sibling libcef.so). Returns whether the rpath was set."""
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

"""Add $ORIGIN + libpython LIBDIR to the host ELF RUNPATH."""
def _patch_host_rpath(binary: Path) -> None {
    libdir = sysconfig.get_config_var("LIBDIR") or "";
    if not libdir {
        return;
    }
    _patchelf_rpath(binary, f"$ORIGIN:{libdir}");
}

"""Resolve the jac CLI for nacompile."""
def _jac_bin -> str {
    cand = Path(os.path.dirname(os.sys.executable)) / "jac";
    if cand.exists() {
        return str(cand);
    }
    found = shutil.which("jac");
    if found {
        return found;
    }
    raise RuntimeError("jac CLI not found on PATH.");
}

"""Libpython soname for clib import in generated host.na.jac."""
def _libpython_soname -> str {
    return str(
        sysconfig.get_config_var("INSTSONAME")
        or f"libpython{sys.version_info.major}.{sys.version_info.minor}.so.1.0"
    );
}

"""Embedded-Python loopback server source (oauth_broker + stable origin port).

`plugin_bootstrap` (from `_plugin_bootstrap_py`) is spliced in after the broker
module loads but before `make_handler`, so it can define `_host`/`_dispatch_fn`.
When `dispatch_arg` is set (e.g. ", dispatch=_dispatch_fn") the broker server
routes `POST /__jac/invoke` straight into the plugin host -- the CEF target's
JS->plugin bridge, since CEF's render process cannot bind into the host
in-process the way the single-process webview target does."""
def _loopback_serve_py(
    app_name: str,
    plugin_bootstrap: str = "",
    dispatch_arg: str = "",
    threaded: bool = False
) -> str {
    pref_port = 49152 + (int(hashlib.sha1(app_name.encode()).hexdigest(), 16) % 16000);
    # The CEF target needs a threaded server: /__jac/events holds the SSE
    # connection open for its lifetime, which would otherwise block every other
    # request (including /__jac/invoke) on a single-threaded TCPServer.
    srv_setup = (
        "_S = socketserver.ThreadingTCPServer\n_S.daemon_threads = True\n"
            if threaded
            else "_S = socketserver.TCPServer\n"
    );
    return (
        "import os, sys, socketserver, threading, importlib.util\n" + srv_setup + "if os.path.isfile('/proc/self/exe'):\n"
        "    _exe = os.path.realpath('/proc/self/exe')\n"
        "else:\n"
        "    _exe = os.path.abspath(sys.argv[0])\n"
        "_root = os.path.dirname(_exe)\n"
        "_dir = os.path.join(_root, 'dist')\n"
        "_spec = importlib.util.spec_from_file_location("
        "'oauth_broker', os.path.join(_root, 'oauth_broker.py'))\n"
        "_broker = importlib.util.module_from_spec(_spec)\n"
        "_spec.loader.exec_module(_broker)\n" + plugin_bootstrap + "_data = os.environ.get('JAC_DATA_PATH', _root)\n"
        "_store = _broker.SessionStore("
        "os.path.join(_data, '.jac', 'desktop', 'session.json'))\n" + "_H = _broker.make_handler(_dir, _store" + dispatch_arg + ")\n" + "_S.allow_reuse_address = True\n"
        f"_pref = {pref_port}\n"
        "_srv = None; _port = None\n"
        "for _i in range(64):\n"
        "    try:\n"
        "        _srv = _S(('127.0.0.1', _pref + _i), _H)\n"
        "        _port = _pref + _i; break\n"
        "    except OSError:\n"
        "        continue\n"
        "if _srv is None:\n"
        "    _srv = _S(('127.0.0.1', 0), _H)\n"
        "    _port = _srv.server_address[1]\n"
        "threading.Thread(target=_srv.serve_forever, daemon=True).start()\n"
        "print('JAC_DESKTOP_SERVING http://127.0.0.1:' + str(_port) + '/', flush=True)\n"
    );
}

"""Transpile oauth_broker.jac and stage oauth_broker.py beside the binary."""
def _stage_oauth_broker(out_dir: Path) {
    webview_dir = _find_webview_dir();
    broker_src = webview_dir.parent / "oauth_broker.jac";
    console.print(
        "  Transpiling oauth_broker.jac -> oauth_broker.py...", style="muted"
    );
    broker_res = subprocess.run(
        [_jac_bin(), "jac2py", str(broker_src)], capture_output=True, text=True
    );
    if broker_res.returncode != 0 {
        raise RuntimeError("oauth_broker transpile failed:\n" + broker_res.stderr);
    }
    (out_dir / "oauth_broker.py").write_text(broker_res.stdout);
}

"""Build the embedded-CPython plugin bootstrap source.

Imports the plugin modules via importlib (in `_plugin_mods` load order), bakes
`plugin_configs`, then calls `registry.bootstrap_plugins(...)` to produce `_host`
and `_dispatch_fn`. Runs in the embedded interpreter with only the transpiled
plugin .py files on disk (no jaclang). Shared by both desktop targets.

`registry` imports every `built_in.*` plugin at module scope, so it MUST load
last: in the embedded CPython `built_in` is a bare ModuleType (not a real
package), so `from built_in.x import Y` only resolves once `built_in.x` is
already in sys.modules. This list owns the *module load order*; it cannot be
derived from registry.BUILTIN_PLUGINS (which is not importable yet), so every
`built_in.*` entry here must match a BUILTIN_PLUGINS entry by hand."""
def _plugin_bootstrap_py(plugin_configs: dict = {}) -> str {
    _plugin_mods = [
        "manifest",
        "desktop_plugin",
        "webview_lib",
        "plugin_host",
        "built_in.path_plugin",
        "built_in.window_plugin",
        "built_in.fs_plugin",
        "built_in.notification_plugin",
        "built_in.clipboard_plugin",
        "built_in.dialog_plugin",
        "built_in.shell_plugin",
        "registry"
    ];
    plugin_py = (
        "import sys, importlib.util, types\n"
        "if _root not in sys.path:\n"
        "    sys.path.insert(0, _root)\n"
        "if 'built_in' not in sys.modules:\n"
        "    sys.modules['built_in'] = types.ModuleType('built_in')\n"
    );
    for _mod in _plugin_mods {
        _py_rel = _mod.replace(".", "/") + ".py";
        plugin_py += (
            "_spec = importlib.util.spec_from_file_location(\n" + json.dumps(_mod) + ", os.path.join(_root, " + json.dumps(
                _py_rel
            ) + "))\n" "_m = importlib.util.module_from_spec(_spec)\n" "sys.modules[" + json.dumps(
                _mod
            ) + "] = _m\n" "_spec.loader.exec_module(_m)\n"
        );
        if _mod.startswith("built_in.") {
            _child = _mod.split(".", 1)[1];
            plugin_py += (
                "setattr(sys.modules['built_in'], " + json.dumps(_child) + ", _m)\n"
            );
        }
    }
    _pc = plugin_configs;  # baked at build time
    plugin_py += f"_pc = {repr(_pc)}\n";
    plugin_py += (
        "_host = sys.modules['registry'].bootstrap_plugins(_pc, sys.modules)\n"
        "_dispatch_fn = _host.dispatch\n"
    );
    return plugin_py;
}

"""Read the canonical BOOTSTRAP_JS glob value out of cef_dispatch.na.jac.

That glob is the single source of truth for the desktop JS bootstrap. It is a
one-line native string literal with no embedded double-quotes, so the value is
everything between the first `"` after the assignment and the closing `";`."""
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

"""JS SDK injected at document start: window.__jac.invoke()/on()/__emit__().

`invoke` delegates to the native `window.__jac_invoke(p,c,a)` primitive, which
each target provides differently (webview bind vs. CEF fetch shim) but with the
same contract: returns a promise of the dispatch JSON (string or object).

Single-sourced from `cef_dispatch.na.jac`'s BOOTSTRAP_JS glob, which is
[CEF fetch shim] + [this SDK] + [EventSource pump]; we slice out the shared SDK
between its IIFE boundary and the EventSource pump. The native target relies on
the same extraction (see native_desktop_target's plugin-bridge `_read_between`),
so the webview bind and the CEF fetch transport can never drift. A boundary that
moves fails loudly here at build time rather than silently shipping two SDKs."""
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

"""Transpile every plugin/**/*.jac -> .py into out_dir for the embedded CPython.

Embedded CPython has no jaclang, so prefer jac0 (stdlib-only output) and fall
back to `jac jac2py`. Shared by both desktop targets."""
def _stage_plugins(out_dir: Path) {
    webview_dir = _find_webview_dir();
    plugin_src_dir = webview_dir.parent.parent / "plugin";
    if not plugin_src_dir.exists() {
        return;
    }
    console.print("  Transpiling plugin IPC modules...", style="muted");
    for jac_file in plugin_src_dir.rglob("*.jac") {
        # rglob("*.jac") also matches directories named ".jac" (build cache).
        if not jac_file.is_file() {
            continue;
        }
        rel = jac_file.relative_to(plugin_src_dir);
        py_name = str(rel.with_suffix(".py"));
        console.print(f"    {rel} -> {py_name}", style="muted");
        import jaclang.jac0 as jac0;
        res_stdout = "";
        try {
            res_stdout = jac0.compile_jac(jac_file.read_text());
            if not res_stdout or not res_stdout.strip() {
                raise RuntimeError("jac0 produced empty output");
            }
        } except Exception as jac0_err {
            res = subprocess.run(
                [_jac_bin(), "jac2py", str(jac_file)], capture_output=True, text=True
            );
            if res.returncode != 0 or not res.stdout.strip() {
                raise RuntimeError(
                    f"Plugin transpile failed: {rel} "
                    f"(jac0 and jac2py failed)\n"
                    f"jac0 error: {jac0_err}\n"
                    f"jac2py stderr: {res.stderr or '(empty)'}"
                );
            }
            console.print(
                f"    ⚠ jac0 failed for {rel}, using jac2py fallback", style="yellow"
            );
            res_stdout = res.stdout;
        }
        target = out_dir / py_name;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(res_stdout);
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# CEF native build (in-Jac replacement for the retired build_cef_*.sh /
# fetch_libcef.sh scripts; see native/cef/build.jac for the runnable entry).
# ─────────────────────────────────────────────────────────────────────────────
"""Splice the shared cef_platform fragment into a host source at `# PLATFORM`.

Faithful in-Jac replacement for the awk splice the build_cef_*.sh scripts ran: a
line that is exactly `# PLATFORM` is replaced by the full cef_platform.na.jac
text, and (when drop_entry is set, for the subprocess build) a line that is
exactly `# ENTRY` is dropped. Output is byte-identical to the old awk pass."""
def _splice_platform(host_src: str, platform_src: str, drop_entry: bool) -> str {
    # awk re-adds one newline per spliced line via print; the fragment text
    # already ends in one, so drop a single trailing newline to avoid a blank.
    plat = platform_src[:-1] if platform_src.endswith("\n") else platform_src;
    out: list[str] = [];
    for line in host_src.split("\n") {
        if line == "# PLATFORM" {
            out.append(plat);
            continue;
        }
        if drop_entry and line == "# ENTRY" {
            continue;
        }
        out.append(line);
    }
    return "\n".join(out);
}

"""Splice + `jac nacompile` a CEF source, then set its $ORIGIN rpath.

Shared by the dispatch shared-library build and the subprocess binary build:
writes the spliced source under cef_dir/.build/ (gitignored), compiles it, and
fails loudly if the expected artifact is missing."""
def _nacompile_cef(
    cef_dir: Path,
    source_name: str,
    build_name: str,
    output: Path,
    drop_entry: bool,
    shared: bool,
) -> Path {
    build_dir = cef_dir / ".build";
    build_dir.mkdir(parents=True, exist_ok=True);
    build_src = build_dir / build_name;
    host_src = (cef_dir / source_name).read_text();
    platform_src = (cef_dir / "cef_platform.na.jac").read_text();
    build_src.write_text(_splice_platform(host_src, platform_src, drop_entry));
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

"""Build libcef_dispatch.so (vtables/callbacks/lifecycle) from cef_dispatch.na.jac."""
def build_cef_dispatch(cef_dir: Path) -> Path {
    return _nacompile_cef(
        cef_dir,
        "cef_dispatch.na.jac",
        "cef_dispatch_build.na.jac",
        cef_dir / "libcef_dispatch.so",
        False,
        True,
    );
}

"""Build the cef-subprocess helper binary from cef_subprocess.na.jac."""
def build_cef_subprocess(cef_dir: Path) -> Path {
    return _nacompile_cef(
        cef_dir,
        "cef_subprocess.na.jac",
        "cef_subprocess_build.na.jac",
        cef_dir / "cef-subprocess",
        True,
        False,
    );
}

"""Pinned CEF version from the `# version:` directive in cef_sums.lock."""
def _cef_locked_version(sums_lock: Path) -> str {
    for line in sums_lock.read_text().split("\n") {
        s = line.strip();
        if s.startswith("# version:") {
            return s[len("# version:"):].strip();
        }
    }
    return "";
}

"""SHA-1 the cef_sums.lock pins for an archive filename (empty if unpinned)."""
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

"""CEF CDN platform tag for the current machine (linux64 / linuxarm64)."""
def _cef_plat_tag -> str {
    arch = platform.machine();
    if arch == "x86_64" {
        return "linux64";
    }
    if arch == "aarch64" {
        return "linuxarm64";
    }
    raise RuntimeError(f"unsupported architecture for CEF: {arch}");
}

"""Best-effort SHA-1 the live Spotify index advertises for an archive.

A secondary cross-check against the in-tree pin; returns "" on any failure so a
missing index never blocks a build whose bytes already match the pinned digest."""
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

"""Streaming SHA-1 of a (large) file."""
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

"""Extract the CEF SDK headers (include/** subtree) into headers_dir."""
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

"""Extract the CEF runtime files flat into dist_dir.

Mirrors fetch_libcef.sh: pulls the libs, ICU data, V8 snapshots, every .pak, and
the locales/ tree, flattening the Release/ and Resources/ tarball prefixes."""
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

"""Download + stage the pinned CEF prebuilt distribution into cef_dir.

In-Jac replacement for fetch_libcef.sh. cef_sums.lock is the trust anchor: the
exact version is read from its `# version:` directive and the archive bytes are
verified against the pinned SHA-1 (fail closed). The live Spotify index is a
secondary cross-check that surfaces a stale/tampered pin. Idempotent: reuses a
cached tarball and skips extraction when the staged version already matches. Set
headers_only to stage just the SDK headers."""
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
