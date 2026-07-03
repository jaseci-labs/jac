import os;
import platform;
import sys;

import from jaclang.cli.console { console }


def _find_bundled_bun -> str | None {
    override = os.environ.get("JAC_BUN", None);
    if override {
        if os.path.isfile(override) {
            return override;
        }

        console.warning(
            f"JAC_BUN is set to '{override}' but no file exists there; "
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
        alt = os.path.join(p, "jaclang", "runtimelib", "client", "_bun", bun_name);
        if os.path.isfile(alt) {
            return alt;
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


impl bun_unavailable_message -> str {
    return (
        "bun is not available in this jac runtime. Shipped binaries bundle it "
        "(a missing copy indicates a broken build); for an editable/source "
        "checkout run `zig build fetch-bun`, or set JAC_BUN to an absolute bun "
        "path."
    );
}


impl get_bun -> str | None {
    bundled = _find_bundled_bun();
    if bundled is not None {
        _ensure_executable(bundled);
        return bundled;
    }

    console.error(bun_unavailable_message(), emoji=False);
    return None;
}
