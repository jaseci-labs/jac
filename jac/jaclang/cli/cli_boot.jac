import os;
import sys;

def _run_bundled_app -> (int | None) {
    off = os.environ.get("JAC_APP_OVERLAY_OFF");
    length = os.environ.get("JAC_APP_OVERLAY_LEN");
    if not off or not length {
        return None;
    }
    import from jaclang.dist.jab { materialize_jab_bytes }
    import from jaclang.cli.commands.execution { run_jab_image }

    try {
        with open(sys.executable, "rb") as f {
            f.seek(int(off));
            data = f.read(int(length));
        }
        img_root = materialize_jab_bytes(data);
    } except Exception as e {
        print(
            f"jac: this binary's embedded app image is unreadable ({e})",
            file=sys.stderr
        );
        return 1;
    }
    return run_jab_image(img_root, None, sys.argv[1:], False, "<app binary>");
}

def start_cli {
    app_rc = _run_bundled_app();
    if app_rc is not None {
        sys.`exit(app_rc);
    }

    import from jaclang.cli.cli { start_cli as _start_cli }
    _start_cli();
}
