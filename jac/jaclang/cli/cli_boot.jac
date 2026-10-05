import os;
import sys;

def _run_bundled_app -> (int | None) {
    off = os.environ.get("JAC_APP_OVERLAY_OFF");
    length = os.environ.get("JAC_APP_OVERLAY_LEN");
    if not off or not length {
        return None;
    }
    import from jaclang.dist.jab { materialize_jab_bytes }
    import from jaclang.dist.fused.trailer { OVERLAY_MAGIC, TRAILER_LEN, parse_trailer }
    import from jaclang.cli.commands.execution { run_jab_image }

    try {
        with open(sys.executable, "rb") as f {
            f.seek(int(off));
            data = f.read(int(length));
            f.seek(-TRAILER_LEN, os.SEEK_END);
            trailer = parse_trailer(f.read(TRAILER_LEN), OVERLAY_MAGIC);
        }
        if trailer is None {
            raise RuntimeError("no app overlay trailer");
        }
        img_root = materialize_jab_bytes(data, expected_sha256=trailer.hash_hex);
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
