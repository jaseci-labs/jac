"""Dev launch helpers for the Jac-native desktop target.

The desktop host now runs on the fused runtime (libjacpyembed -> the bundled
CPython + jaclang the CLI ships), so there is no build-machine ``libpython`` to
locate and no builder site-packages to bake in. These helpers only surface the
editable worktree roots (``JAC_DESKTOP_*``) for the dev loop: which jaclang the
desktop *assets* (oauth_broker, the shim, webview) are served from, and -- until
jac-scale is bundled into the fused runtime -- where an editable jac-scale lives.
Release / PyPI installs with no editable roots are left untouched.
"""
import os;
import sysconfig;
import site;
import from pathlib { Path }


"""Derive JAC_DESKTOP_* roots from JAC_DEV_SOURCE set by the launcher.

apply_dev_source_override() in _jac_finder.py reads [dev] jaclang_source from
the nearest jac.toml and exports JAC_DEV_SOURCE before jaclang is imported.
Desktop build/launch code should consume that instead of re-reading jac.toml."""
def _dev_roots_from_env -> dict[str, str] {
    roots: dict[str, str] = {};
    dev_src = os.environ.get("JAC_DEV_SOURCE");
    if not dev_src {
        return roots;
    }
    src = Path(dev_src);
    if not (src / "jaclang").is_dir() {
        return roots;
    }
    roots["JAC_DESKTOP_JAC_SRC"] = dev_src;
    scale = src.parent / "jac-scale";
    if (scale / "jac_scale" / "inprocess.jac").exists() {
        roots["JAC_DESKTOP_SCALE_SRC"] = str(scale);
    }
    return roots;
}


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
    # which registers a meta-path finder instead of a path line -- its .pth carries
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


"""Set ``JAC_DESKTOP_*`` in ``os.environ`` when editable worktrees are detected.

Called during ``build()`` so the desktop build locates its assets (and an
editable jac-scale) from the worktree. Existing env values win (``setdefault``)."""
def ensure_dev_build_env {
    for (key, val) in _editable_roots_from_site().items() {
        os.environ.setdefault(key, val);
    }
    for (key, val) in _dev_roots_from_env().items() {
        os.environ.setdefault(key, val);
    }
}


"""Env for launching the native desktop binary (the fused runtime is hermetic).

The host's jac_engine_boot() sets its own PYTHONHOME/PYTHONPATH/JAC_EXECUTABLE
for the materialized runtime, so any of the launching jac CLI's interpreter env
inherited here would only confuse a stale read before boot -- drop them."""
def desktop_app_runtime_env(base: any = None) -> dict[str, str] {
    env = desktop_launch_env(base);
    for key in [
        "PYTHONHOME",
        "PYTHONPATH",
        "PYTHONEXECUTABLE",
        "JAC_EXECUTABLE",
        "VIRTUAL_ENV",

    ] {
        env.pop(key, None);
    }
    env.setdefault("GDK_BACKEND", "x11");
    env.setdefault("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
    env.setdefault("WEBKIT_DISABLE_COMPOSITING_MODE", "1");
    return env;
}


"""Merge auto-detected dev launch settings into ``base`` (for ``subprocess``).

Only the editable worktree roots (JAC_DESKTOP_*) -- no LD_LIBRARY_PATH for a
build-machine libpython (the shim dlopens the bundled one), no baked dep dirs
(JAC_DESKTOP_DEPS, if needed for an editable jac-scale, is set by the user)."""
def desktop_launch_env(base: any = None) -> dict[str, str] {
    env = dict(base) if base is not None else dict(os.environ);
    for (key, val) in _editable_roots_from_site().items() {
        env.setdefault(key, val);
    }
    for (key, val) in _dev_roots_from_env().items() {
        env.setdefault(key, val);
    }
    return env;
}
