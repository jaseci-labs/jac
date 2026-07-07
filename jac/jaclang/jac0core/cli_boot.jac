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

"""Run a bundled app if this binary was built with `jac bundle --target binary`.

The binary packer stages the app's sealed image under `<site>/<app>/` and drops
a `<site>/jac_app.json` boot marker; here we register that image and hand the
process to the app entry (runpy as __main__, so `with entry`/`__main__` both
fire). Returns True when an app ran (caller must not fall through to the CLI).
"""
def _run_bundled_app -> bool {
    import json;
    import runpy;
    try {
        import _jac_finder;
        site_dir = Path(_jac_finder.__file__).parent;
    } except ImportError {
        return False;
    }
    import from jaclang.jac0core.sealed { APP_MARKER, register_image }
    marker = site_dir / APP_MARKER;
    if not marker.is_file() {
        return False;
    }
    cfg = json.loads(marker.read_text());
    register_image(str(site_dir / cfg["package"] / "_precompiled"));
    runpy.run_module(cfg["entry"], run_name="__main__", alter_sys=True);
    return True;
}

"""Start the Jac CLI."""
def start_cli -> None {
    # A bundled-app binary runs its app instead of the jac CLI.
    if _run_bundled_app() {
        return;
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
