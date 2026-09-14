import os;
import sys;
import shutil;
import from pathlib { Path }

"""Run Python with the selected compiler package ahead of the working directory."""
def compiler_python_command(
    source: str, *args: str, compiler_root: str | None = None
) -> list[str] {
    import jaclang;
    selected = compiler_root or os.environ.get("JAC_COMPILER_IMAGE");
    package_root = str(Path(selected).resolve())
        if selected
        else str(Path(str(jaclang.__file__)).resolve().parent.parent);
    if not (Path(package_root) / "jaclang" / "__init__.py").is_file() {
        raise ValueError(f"No compiler package at {package_root}");
    }
    boot = (
        "import sys\nsys.path.insert(0, "
        + repr(package_root)
        + ")\n"
        + "sys.path.extend("
        + repr(sys.path)
        + ")\n"
        + source
    );
    return [sys.executable, "-P", "-c", boot, *args];
}

"""Invoke the selected compiler's CLI without letting a checkout shadow it."""
def jac_command(*args: str, compiler_root: str | None = None) -> list[str] {
    return compiler_python_command(
        "import runpy\nsys.argv[0] = 'jac'\n"
            + "runpy.run_module('jaclang', run_name='__main__', alter_sys=True)",
        *args,
        compiler_root=compiler_root
    );
}

def _handle_purge {
    if "-h" in sys.argv or "--help" in sys.argv {
        print("usage: jac purge [-h]\n");
        print("Remove global Jac compilation caches (JIR and native artifacts).\n");
        print("Useful when switching branches or when cache becomes corrupted.");
        sys.`exit(0);
    }

    import from jaclang.project.cache_paths { get_jir_cache_dir }
    jir_dir = get_jir_cache_dir();

    total_files = 0;
    total_size = 0;
    removed_dirs: list[str] = [];
    for d in [jir_dir] {
        if d.exists() {
            total_files += sum(
                1
                for f in d.rglob("*")
                if f.is_file()
            );
            total_size += sum(
                f.stat().st_size
                for f in d.rglob("*")
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

    import from jaclang.cli.cli { start_cli as _start_cli }
    _start_cli();
}
