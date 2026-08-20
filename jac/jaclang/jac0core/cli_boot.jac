import os;
import sys;
import shutil;
import from pathlib { Path }

def _get_cache_dir -> Path {
    if sys.platform == "win32" {
        base = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"));
        return base / "jac" / "cache" / "bytecode";
    } elif sys.platform == "darwin" {
        return Path.home() / "Library" / "Caches" / "jac" / "bytecode";
    } else {
        xdg = os.environ.get("XDG_CACHE_HOME");
        base = Path(xdg) if xdg else (Path.home() / ".cache");
        return base / "jac" / "bytecode";
    }
}

def _handle_purge {
    if "-h" in sys.argv or "--help" in sys.argv {
        print("usage: jac purge [-h]\n");
        print(
            "Remove all cached Jac files (JIR, bytecode, bootstrap) from the cache directories.\n"
        );
        print("Useful when switching branches or when cache becomes corrupted.");
        sys.`exit(0);
    }

    cache_dir = _get_cache_dir();
    bootstrap_dir = cache_dir.parent / "bootstrap";

    jir_dir = cache_dir.parent / "jir";

    total_files = 0;
    total_size = 0;
    removed_dirs: list[str] = [];
    for d in [cache_dir, bootstrap_dir, jir_dir] {
        if d.exists() {
            total_files += sum(
                1
                for f in d.iterdir()
                if f.is_file()
            );
            total_size += sum(
                f.stat().st_size
                for f in d.iterdir()
                if f.is_file()
            );
            try {
                shutil.rmtree(d);
                removed_dirs.append(str(d));
            } except OSError as e {
                print(f"Error purging {d}: {e}", file=sys.stderr);
            }
        }
    }

    if not removed_dirs {
        print("No cache directories found.");
        sys.`exit(0);
    }

    print(f"Purged {total_files} cached files ({total_size / 1024:.1f} KB)");
    for rd in removed_dirs {
        print(f"Removed: {rd}");
    }
    sys.`exit(0);
}

def _run_bundled_app -> (int | None) {
    off = os.environ.get("JAC_APP_OVERLAY_OFF");
    length = os.environ.get("JAC_APP_OVERLAY_LEN");
    if not off or not length {
        return None;
    }
    import from jaclang.runtimelib.jab { materialize_jab_bytes }
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

def start_cli -> None {
    app_rc = _run_bundled_app();
    if app_rc is not None {
        sys.`exit(app_rc);
    }

    if len(sys.argv) >= 2 and sys.argv[1] == "purge" {
        _handle_purge();
        return;
    }

    import from jaclang.cli.cli { start_cli as _start_cli }
    _start_cli();
}
