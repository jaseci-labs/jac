"""Minimal CLI entry point for Jac.

This module serves as the main entry point for the jac command.
It handles 'jac purge' for cache cleanup and delegates other commands
to the full CLI.
"""

import os;
import sys;
import shutil;
import from pathlib { Path }

"""Get the platform-appropriate global cache directory for Jac bytecode."""
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

"""Handle the 'jac purge' command."""
def _handle_purge {
    if "-h" in sys.argv or "--help" in sys.argv {
        print("usage: jac purge [-h]\n");
        print(
            "Remove all cached Jac files (JIR, bytecode, bootstrap) from the cache directories.\n"
        );
        print("Useful when switching branches or when cache becomes corrupted.");
        sys.exit(0);
    }

    cache_dir = _get_cache_dir();
    bootstrap_dir = cache_dir.parent / "bootstrap";
    # New unified JIR cache (replaces the old bytecode/ and bootstrap/ dirs)
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
        sys.exit(0);
    }

    print(f"Purged {total_files} cached files ({total_size / 1024:.1f} KB)");
    for rd in removed_dirs {
        print(f"Removed: {rd}");
    }
    sys.exit(0);
}

"""Run a bundled app if this binary was built with `jac build --as binary`.

A `jac build --as binary` artifact carries the app's `.jab` appended after the
runtime payload; the launcher exports its byte range as JAC_APP_OVERLAY_OFF/_LEN.
Here we slice that `.jab` out of the running binary and mount it through the SAME
path as `jac run app.jab` (materialize + register + kind-aware run) -- so a
bundled binary and a loose `.jab` boot identically, entry read from the sealed
manifest. Returns the app's exit code, or None when this is not an app binary
(the caller then continues to the normal CLI)."""
def _run_bundled_app -> (int | None) {
    off = os.environ.get("JAC_APP_OVERLAY_OFF");
    length = os.environ.get("JAC_APP_OVERLAY_LEN");
    if not off or not length {
        return None;
    }
    import from jaclang.runtimelib.jab { materialize_jab_bytes }
    import from jaclang.cli.commands.execution { run_jab_image }
    # The launcher sets these only for THIS binary and clears them for a plain
    # jac, so reaching here means a real app binary; a failed slice/extract is a
    # genuinely corrupt image -> clean error, never an uncaught traceback.
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

"""Start the Jac CLI."""
def start_cli -> None {
    # A bundled-app binary runs its app instead of the jac CLI.
    app_rc = _run_bundled_app();
    if app_rc is not None {
        sys.exit(app_rc);
    }

    # Check if first argument is 'purge'
    if len(sys.argv) >= 2 and sys.argv[1] == "purge" {
        _handle_purge();
        return;
    }

    # Delegate to the full CLI for all other commands
    import from jaclang.cli.cli { start_cli as _start_cli }
    _start_cli();
}
