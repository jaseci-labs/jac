"""Launcher boot: the first jaclang code a `jac` invocation runs.

Binaries built from this tree bake `from jaclang.cli.cli_boot import
start_cli` into their boot source; `jaclang.jac0core.cli_boot` is the
compatibility seam for launchers built before the reorg (#8681). This
module is seed-tier so the boot fast paths (`jac --version`,
`jac purge`) stay off the full compiler.

The version helpers below live here (not in a separate module) so the
seed fast path and `manifest_route` render from one definition with no
extra file in the seed-adjacent surface. They are stdlib-only by
necessity: at the time they run, the self-hosted compiler does not
exist yet.
"""
import os;
import platform;
import sys;
import shutil;
import from pathlib { Path }

glob _TITLE: str = "\033[1m";
glob _RESET: str = "\033[0m";

def _read_version_from_toml(toml_path: Path) -> (str | None) {
    import tomllib;
    try {
        data = tomllib.loads(toml_path.read_text(encoding="utf-8"));
    } except Exception {
        return None;
    }
    project = data.get("project", {});
    if isinstance(project, dict) {
        ver = project.get("version");
        if isinstance(ver, str) and ver {
            return ver;
        }
    }
    return None;
}

def resolve_cli_version(dev_source: (str | None)) -> str {
    """Resolve the jac CLI version.

    Order: the dev source tree's jac.toml (when JAC_DEV_SOURCE is
    engaged), the jac.toml packaged next to the jaclang package, then
    installed package metadata.
    """
    import from importlib.metadata { version as pkg_version }

    if dev_source {
        ver = _read_version_from_toml(Path(dev_source) / "jac.toml");
        if ver {
            return ver;
        }
    }

    source_toml = Path(__file__).resolve().parent.parent / "jac.toml";
    if source_toml.exists() {
        ver = _read_version_from_toml(source_toml);
        if ver {
            return ver;
        }
    }

    return pkg_version("jaclang");
}

def use_emoji -> bool {
    """Same rule as JacConsole._should_use_emoji, without importing it."""
    if os.environ.get("NO_EMOJI") or os.environ.get("TERM") == "dumb" {
        return False;
    }
    if sys.platform == "win32" and not os.environ.get("WT_SESSION") {
        return False;
    }
    return True;
}

def should_use_color -> bool {
    """Same rule as JacConsole._should_use_color, without importing it."""
    if os.environ.get("NO_COLOR") {
        return False;
    }
    if os.environ.get("TERM") == "dumb" {
        return False;
    }
    try {
        if not sys.stdout.isatty() {
            return False;
        }
    } except Exception {
        return False;
    }
    return True;
}

def render_version_line(version: str) -> str {
    """Render the ``jac --version`` line (identical to the manifest route)."""
    use_color = should_use_color();
    name = f"{_TITLE}jac{_RESET}" if use_color else "jac";
    return f"{name} {version}  ({platform.system()} {platform.machine()})";
}

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

def start_cli -> None {
    app_rc = _run_bundled_app();
    if app_rc is not None {
        sys.`exit(app_rc);
    }

    if len(sys.argv) >= 2 and sys.argv[1] == "purge" {
        _handle_purge();
        return;
    }
    raw = sys.argv[1:];
    if raw in (['-V'], ['--version']) {
        dev_source = os.environ.get('JAC_DEV_SOURCE');
        if dev_source {
            notice = (
                f"🛠  jac dev mode — using compiler source at {dev_source}"
                    if use_emoji()
                    else f"[dev] jac dev mode - using compiler source at {dev_source}"
            );
            sys.stderr.write(notice + '\n');
        }
        line = render_version_line(resolve_cli_version(dev_source));
        sys.stdout.write(line + '\n');
        return;
    }

    import from jaclang.cli.cli { start_cli as _start_cli }
    _start_cli();
}
