import os;
import sysconfig;
import site;
import from pathlib { Path }


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


def ensure_dev_build_env {
    for (key, val) in _editable_roots_from_site().items() {
        os.environ.setdefault(key, val);
    }
    for (key, val) in _dev_roots_from_env().items() {
        os.environ.setdefault(key, val);
    }
}


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
