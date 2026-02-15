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
def _handle_purge -> None {
    if "-h" in sys.argv or "--help" in sys.argv {
        print("usage: jac purge [-h]\n");
        print("Remove all cached bytecode files from the Jac cache directory.\n");
        print("Useful when switching branches or when cache becomes corrupted.");
        sys.exit(0);
    }

    cache_dir = _get_cache_dir();
    bootstrap_dir = cache_dir.parent / "bootstrap";

    total_files = 0;
    total_size = 0;
    removed_dirs: list[str] = [];
    for d in [cache_dir, bootstrap_dir] {
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
        print(f"Cache directory does not exist: {cache_dir}");
        sys.exit(0);
    }

    print(f"Purged {total_files} cached files ({total_size / 1024:.1f} KB)");
    for rd in removed_dirs {
        print(f"Removed: {rd}");
    }
    sys.exit(0);
}

"""Start the Jac CLI."""
def start_cli -> None {
    # Check if first argument is 'purge'
    if len(sys.argv) >= 2 and sys.argv[1] == "purge" {
        _handle_purge();
        return;
    }

    # Delegate to the full CLI for all other commands
    import from jaclang.cli.cli { start_cli as _start_cli }
    _start_cli();
}
