import os;
import platform;
import sys;
import from pathlib { Path }

glob _TITLE: str = "\033[1m",
     _RESET: str = "\033[0m";

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
    if os.environ.get("NO_EMOJI") or os.environ.get("TERM") == "dumb" {
        return False;
    }
    if sys.platform == "win32" and not os.environ.get("WT_SESSION") {
        return False;
    }
    return True;
}

def should_use_color -> bool {
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
    use_color = should_use_color();
    name = f"{_TITLE}jac{_RESET}" if use_color else "jac";
    return f"{name} {version}  ({platform.system()} {platform.machine()})";
}

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
