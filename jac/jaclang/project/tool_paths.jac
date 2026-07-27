import os;
import site;
import from pathlib { Path }
import from jaclang.project.config { JacConfig, get_config }
import from jaclang.project.pyvenv { get_venv_site_packages }


def jac_global_prefix -> Path {
    env_override = os.environ.get("JAC_GLOBAL_DIR");
    if env_override {
        return Path(env_override).expanduser();
    }
    return Path.home() / ".jac";
}


def python_project_site(config: JacConfig | None = None) -> Path | None {
    config = config if config is not None else get_config();
    if config is None {
        return None;
    }
    return get_venv_site_packages(config.get_venv_dir());
}


def python_global_site -> Path | None {
    try {
        globals_ = site.getsitepackages();
    } except (AttributeError, IndexError, OSError) {
        return None;
    }
    return Path(globals_[0]) if globals_ else None;
}


def node_root(scope: str, config: JacConfig | None = None) -> Path | None {
    if scope == "global" {
        return jac_global_prefix() / "npm";
    }
    config = config if config is not None else get_config();
    if config is None {
        return None;
    }
    return config.get_client_dir();
}


def node_bin_dir(scope: str, config: JacConfig | None = None) -> Path | None {
    base_dir = node_root(scope, config);
    return (base_dir / "node_modules" / ".bin") if base_dir is not None else None;
}
