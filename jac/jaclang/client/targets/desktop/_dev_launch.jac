import os;
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


def _compiler_roots -> dict[str, str] {
    import jaclang;
    return {"JAC_DESKTOP_JAC_SRC": str(Path(jaclang.__file__).resolve().parent.parent)};
}

def ensure_dev_build_env {
    for (key, val) in _compiler_roots().items() {
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
    for (key, val) in _compiler_roots().items() {
        env.setdefault(key, val);
    }
    return env;
}
