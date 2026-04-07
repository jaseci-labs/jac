impl get_home_dir() -> str {
    home = os.path.join(os.path.expanduser("~"), ".jaccoder");
    os.makedirs(home, exist_ok=True);
    return home;
}


glob _STR_FIELDS: list = ["default_model"];
glob _FLOAT_FIELDS: list = ["temperature"];
glob _INT_FIELDS: list = ["max_tokens", "max_react_iterations"];


impl _merge_from_file(config: JacCoderConfig, path: str) -> None {
    try {
        with open(path, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
    } except (json.JSONDecodeError, FileNotFoundError, OSError) {
        return;
    }
    for key in _STR_FIELDS {
        if key in data {
            setattr(config, key, str(data[key]));
        }
    }
    for key in _FLOAT_FIELDS {
        if key in data {
            try {
                setattr(config, key, float(data[key]));
            } except (ValueError, TypeError) { }
        }
    }
    for key in _INT_FIELDS {
        if key in data {
            try {
                setattr(config, key, int(data[key]));
            } except (ValueError, TypeError) { }
        }
    }
}


impl load_config(project_dir: str = "") -> JacCoderConfig {
    global _config;
    config = JacCoderConfig();

    if project_dir {
        config.project_dir = os.path.realpath(project_dir);
    } else {
        config.project_dir = os.getcwd();
    }

    global_path = os.path.join(get_home_dir(), "config.json");
    if os.path.exists(global_path) {
        _merge_from_file(config, global_path);
    }

    project_path = os.path.join(config.project_dir, "jaccoder.json");
    if os.path.exists(project_path) {
        _merge_from_file(config, project_path);
    }

    env_overrides: list = [
        ("MODEL", "default_model", str),
        ("TEMPERATURE", "temperature", float),
        ("MAX_TOKENS", "max_tokens", int),
        ("MAX_REACT_ITERATIONS", "max_react_iterations", int)
    ];
    for (env_key, attr, cast) in env_overrides {
        val = os.environ.get(env_key, "");
        if val {
            try {
                setattr(config, attr, cast(val));
            } except (ValueError, TypeError) { }
        }
    }

    _config = config;
    return config;
}


impl get_config() -> JacCoderConfig {
    global _config;
    return _config;
}


# ---------------------------------------------------------------------------
# Model switching — simple swap, keys come from env/.env
# ---------------------------------------------------------------------------
"""Switch the active LLM model. Mutates the existing Model object
so all modules that imported `llm` see the change immediately."""
impl set_model(model: str) -> dict {
    global model_name, _config;
    model = model.strip();
    if not model {
        return {"error": "Model name cannot be empty"};
    }
    model_name = model;
    llm.model_name = model;
    _config.default_model = model;
    return {"status": "ok", "model": model};
}

"""Return current model name."""
impl get_model() -> dict {
    return {"model": model_name};
}


glob _data_dir_cache: str = "";

impl get_data_dir() -> str {
    global _data_dir_cache;
    if _data_dir_cache {
        return _data_dir_cache;
    }

    # Strategy 1: JACCODER_ROOT env var
    jc_root = os.environ.get("JACCODER_ROOT", "");
    if jc_root {
        candidate = os.path.join(jc_root, "jac_coder", "data");
        if os.path.isdir(os.path.join(candidate, "rules")) {
            _data_dir_cache = candidate;
            return _data_dir_cache;
        }
    }

    # Strategy 2: walk up from __file__ until we find jac_coder/data/rules
    path = os.path.abspath(__file__);
    for _i in range(10) {
        path = os.path.dirname(path);
        if path == os.path.dirname(path) {
            break;
        }
        candidate = os.path.join(path, "data");
        if os.path.isdir(os.path.join(candidate, "rules")) {
            _data_dir_cache = candidate;
            return _data_dir_cache;
        }
        candidate = os.path.join(path, "jac_coder", "data");
        if os.path.isdir(os.path.join(candidate, "rules")) {
            _data_dir_cache = candidate;
            return _data_dir_cache;
        }
    }

    # Strategy 3: CWD based
    for base in [os.getcwd(), os.path.dirname(os.getcwd())] {
        candidate = os.path.join(base, "jac_coder", "data");
        if os.path.isdir(os.path.join(candidate, "rules")) {
            _data_dir_cache = candidate;
            return _data_dir_cache;
        }
    }

    # Fallback: best guess from __file__
    _data_dir_cache = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data"
    );
    return _data_dir_cache;
}
