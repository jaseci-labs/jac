"""Dev launch helpers for the Jac-native desktop target.

When jaclang / jac-scale are editable-linked (``jac install -e``),
``jac build --client desktop`` and ``jac start --client desktop`` auto-wire the
embedded host: worktree pins (JAC_DESKTOP_*), builder site-packages at build time,
and ``LD_LIBRARY_PATH`` for the linked ``libpython`` at launch. Release / PyPI
installs with no editable roots are left untouched.
"""
import os;
import sysconfig;
import site;
import from pathlib { Path }


"""Map ``__editable__.*.pth`` link farms to ``JAC_DESKTOP_*`` worktree roots."""
def _editable_roots_from_site -> dict[str, str] {
    roots: dict[str, str] = {};
    candidates: list[Path] = [];
    usp = site.getusersitepackages();
    if usp {
        candidates.append(Path(usp));
    }
    plib = sysconfig.get_path("purelib");
    if plib {
        candidates.append(Path(plib));
    }
    for sp in candidates {
        if not sp.is_dir() {
            continue;
        }
        for pth in sp.glob("__editable__.*.pth") {
            line = pth.read_text(encoding="utf-8").strip().split("\n")[0].strip();
            if not line {
                continue;
            }
            # `pip install -e` emits two editable layouts: a bare path line
            # (`/path/to/repo`) and a finder bootstrap (`import __editable___..._finder;
            # ...install()`). Only the former is a usable root; the latter is code,
            # not a path, so skip it here and let the import fallback below recover it.
            if line.startswith("import ") or "(" in line {
                continue;
            }
            pkg_root = Path(line);
            if (pkg_root / "jaclang").is_dir() {
                roots["JAC_DESKTOP_JAC_SRC"] = str(pkg_root);
            }
            if (pkg_root / "jac_scale" / "inprocess.jac").exists() {
                roots["JAC_DESKTOP_SCALE_SRC"] = str(pkg_root);
            }
        }
    }
    # Import fallback for finder-style editable installs (e.g. `jac install -e`,
    # which registers a meta-path finder instead of a path line — its .pth carries
    # code, not a directory). Resolve the worktree root from the imported package's
    # __file__: the dir that *contains* the package dir is the editable root.
    _wanted = {"JAC_DESKTOP_JAC_SRC": "jaclang", "JAC_DESKTOP_SCALE_SRC": "jac_scale"};
    for (env_key, mod_name) in _wanted.items() {
        if env_key in roots {
            continue;
        }
        try {
            import importlib;
            mod = importlib.import_module(mod_name);
            mod_file = mod?.__file__;
            if mod_file {
                # __file__ -> <src_root>/<pkg>/__init__.* ; the editable root is
                # two parents up. (`root` is a Jac builtin, so name it src_root.)
                src_root = Path(str(mod_file)).resolve().parent.parent;
                if (src_root / mod_name).is_dir() {
                    roots[env_key] = str(src_root);
                }
            }
        } except Exception {
            continue;
        }
    }
    return roots;
}


"""Prepend ``libdir`` to ``LD_LIBRARY_PATH`` when not already present."""
def _prepend_libdir(env: dict[str, str], libdir: str) {
    if not libdir {
        return;
    }
    prev = env.get("LD_LIBRARY_PATH", "");
    parts = [
        p
        for p in prev.split(os.pathsep)
        if p
    ];
    if libdir not in parts {
        env["LD_LIBRARY_PATH"] = libdir + (os.pathsep + prev if prev else "");
    }
}


"""Set ``JAC_DESKTOP_*`` in ``os.environ`` when editable worktrees are detected.

Called during ``build()`` so the generated host embeds the dev pin (with baked
builder site-packages). Existing env values win (``setdefault``)."""
def ensure_dev_build_env {
    for (key, val) in _editable_roots_from_site().items() {
        os.environ.setdefault(key, val);
    }
}


"""Merge auto-detected dev launch settings into ``base`` (for ``subprocess``)."""
def desktop_launch_env(base: any = None) -> dict[str, str] {
    env = dict(base) if base is not None else dict(os.environ);
    for (key, val) in _editable_roots_from_site().items() {
        env.setdefault(key, val);
    }
    libdir = sysconfig.get_config_var("LIBDIR");
    if libdir {
        _prepend_libdir(env, str(libdir));
    }
    return env;
}
