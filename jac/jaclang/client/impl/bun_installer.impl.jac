import os;
import platform;
import shutil;
import sys;

import from jaclang.cli.console { console }


def _find_bundled_bun -> str | None {
    `override = os.environ.get("JAC_BUN", None);
    if `override {
        if os.path.isfile(`override) {
            return `override;
        }

        console.warning(
            f"JAC_BUN is set to '{`override}' but no file exists there; "
            "ignoring it and using the bundled bun.",
            emoji=False
        );
    }
    is_windows = platform.system() == "Windows";
    bun_name = "bun.exe" if is_windows else "bun";

    here = os.path.dirname(os.path.abspath(__file__));
    client_dir = os.path.dirname(here);
    cand = os.path.join(client_dir, "_bun", bun_name);
    if os.path.isfile(cand) {
        return cand;
    }

    for p in sys.path {
        if not p {
            continue;
        }
        alt = os.path.join(p, "jaclang", "client", "_bun", bun_name);
        if os.path.isfile(alt) {
            return alt;
        }

        legacy = os.path.join(p, "jaclang", "runtimelib", "client", "_bun", bun_name);
        if os.path.isfile(legacy) {
            return legacy;
        }
    }
    return None;
}


def _ensure_executable(path: str) {
    if platform.system() == "Windows" {
        return;
    }

    try {
        os.chmod(path, 0o755);
    } except OSError as e {
        console.warning(
            f"Could not set the executable bit on bundled bun at {path}: {e}",
            emoji=False
        );
    }
}


impl _find_path_bun -> str | None {
    on_path = shutil.which("bun.exe" if platform.system() == "Windows" else "bun");
    if on_path {
        return on_path;
    }
    home = os.environ.get("HOME", "");
    if home {
        cand = os.path.join(home, ".bun", "bin", "bun");
        if os.path.isfile(cand) {
            return cand;
        }
    }
    return None;
}


impl bun_unavailable_message -> str {
    return (
        "bun is not available in this jac runtime (no bundled copy, nothing "
        "on PATH, no ~/.bun install). Shipped binaries bundle it (a missing "
        "copy indicates a broken build); for an editable/source checkout run "
        "`zig build fetch-bun`, install bun, or set JAC_BUN to an absolute "
        "bun path."
    );
}


def _js_engine_enabled -> bool {
    raw = os.environ.get("ENABLE_JS_ENGINE", "");
    return raw.strip().lower() not in {"", "0", "false", "no", "off"};
}


def _find_js_engine -> str | None {
    configured = os.environ.get("JS_ENGINE_BIN", "").strip();
    if configured {
        if os.path.isfile(configured) {
            return configured;
        }
        console.error(
            f"ENABLE_JS_ENGINE is set but JS_ENGINE_BIN points at '{configured}', "
            "which is not a file.",
            emoji=False
        );
        return None;
    }
    on_path = shutil.which("js_engine");
    if on_path {
        return on_path;
    }
    console.error(
        "ENABLE_JS_ENGINE is set but JS_ENGINE_BIN is not, and no js_engine was "
        "found on PATH. Export JS_ENGINE_BIN=/absolute/path/to/js_engine.",
        emoji=False
    );
    return None;
}


impl get_bun -> str | None {
    if _js_engine_enabled() {
        engine = _find_js_engine();
        if engine is not None {
            _ensure_executable(engine);
        }
        return engine;
    }

    bundled = _find_bundled_bun();
    if bundled is not None {
        _ensure_executable(bundled);
        return bundled;
    }

    system_bun = _find_path_bun();
    if system_bun is not None {
        return system_bun;
    }

    console.error(bun_unavailable_message(), emoji=False);
    return None;
}
