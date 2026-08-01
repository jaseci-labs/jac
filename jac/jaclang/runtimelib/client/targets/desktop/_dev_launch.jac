import os;
import sysconfig;
import site;
import from pathlib { Path }
import from jaclang.project.config { get_config }
import from jaclang.project.pyvenv { get_venv_site_packages }

glob DESKTOP_WEBKIT_ENV: list[tuple[str, str]] = [
         ("GDK_BACKEND", "x11"),
         ("WEBKIT_DISABLE_DMABUF_RENDERER", "1"),
         ("WEBKIT_DISABLE_COMPOSITING_MODE", "1"),

     ];


def _project_venv_site_packages -> str {
    config = get_config(force_discover=True);
    if config is None {
        return "";
    }
    site_pkgs = get_venv_site_packages(config.get_venv_dir());
    if site_pkgs.is_dir() {
        return str(site_pkgs);
    }
    return "";
}


def jac_desktop_webkit_shell_export -> str {
    return "".join(
        [f'export {key}="${{{key}:-{val}}}"\n' for (key, val) in DESKTOP_WEBKIT_ENV]
    );
}


def jac_desktop_deps_shell_export(venv_rel: str = "../../venv") -> str {
    return (
        f"VENV_LIB=\"$(CDPATH= cd -- \"$(dirname \"$0\")/{venv_rel}/lib\" 2>/dev/null && pwd)\"\n"
        "if [ -n \"$VENV_LIB\" ] && [ -d \"$VENV_LIB\" ]; then\n"
        "  for sp in \"$VENV_LIB\"/python*/site-packages; do\n"
        "    if [ -d \"$sp\" ]; then\n"
        "      if [ -n \"${JAC_DESKTOP_DEPS:-}\" ]; then\n"
        "        export JAC_DESKTOP_DEPS=\"$sp${JAC_DESKTOP_DEPS:+:$JAC_DESKTOP_DEPS}\"\n"
        "      else\n"
        "        export JAC_DESKTOP_DEPS=\"$sp\"\n"
        "      fi\n"
        "      break\n"
        "    fi\n"
        "  done\n"
        "fi\n"
    );
}


def _prepend_env_path(env: dict[str, str], key: str, path: str) -> None {
    if not path {
        return;
    }
    existing = env.get(key, "");
    if existing {
        parts = [path]
            + [
                p
                for p in existing.split(os.pathsep)
                if p and p != path
            ];
        env[key] = os.pathsep.join(parts);
    } else {
        env[key] = path;
    }
}


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
        }
    }

    _wanted = {"JAC_DESKTOP_JAC_SRC": "jaclang"};
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
    for key in ["PYTHONEXECUTABLE", "JAC_EXECUTABLE", "VIRTUAL_ENV", ] {
        env.pop(key, None);
    }
    for (key, val) in DESKTOP_WEBKIT_ENV {
        env.setdefault(key, val);
    }
    _prepend_env_path(env, "JAC_DESKTOP_DEPS", _project_venv_site_packages());
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
