import os;
import shutil;
import sys;

import from jaclang.cli.console { console }


def _find_bundled_js_engine -> str | None {
    `override = os.environ.get("JAC_JS_ENGINE", None);
    if `override {
        if os.path.isfile(`override) {
            return `override;
        }

        console.warning(
            f"JAC_JS_ENGINE is set to '{`override}' but no file exists there; "
            "ignoring it and using the bundled js_engine.",
            emoji=False
        );
    }

    client_dir = os.path.dirname(os.path.abspath(__file__));
    cand = os.path.join(client_dir, "_js_engine", "bin", "js_engine");
    if os.path.isfile(cand) {
        return cand;
    }

    for p in sys.path {
        if not p {
            continue;
        }
        alt = os.path.join(p, "jaclang", "client", "_js_engine", "bin", "js_engine");
        if os.path.isfile(alt) {
            return alt;
        }
    }

    checkout = os.path.normpath(
        os.path.join(client_dir, "..", "..", "..", "js_engine", "bin", "js_engine")
    );
    if os.path.isfile(checkout) {
        return checkout;
    }
    return None;
}


def _ensure_executable(path: str) {
    try {
        os.chmod(path, 0o755);
    } except OSError as e {
        console.warning(
            f"Could not set the executable bit on bundled js_engine at {path}: {e}",
            emoji=False
        );
    }
}


impl _find_path_js_engine -> str | None {
    return shutil.which("js_engine");
}


impl js_engine_unavailable_message -> str {
    return (
        "js_engine is not available in this jac runtime (no bundled copy, no "
        "build in the source checkout, nothing on PATH). Shipped binaries "
        "bundle it (a missing copy indicates a broken build); for an "
        "editable/source checkout run `make` in js_engine/, or set "
        "JAC_JS_ENGINE to an absolute js_engine path."
    );
}


impl get_js_engine -> str | None {
    bundled = _find_bundled_js_engine();
    if bundled is not None {
        _ensure_executable(bundled);
        return bundled;
    }

    system_engine = _find_path_js_engine();
    if system_engine is not None {
        return system_engine;
    }

    console.error(js_engine_unavailable_message(), emoji=False);
    return None;
}
