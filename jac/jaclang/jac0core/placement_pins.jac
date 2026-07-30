import fnmatch;
import json;
import os;
import from jaclang.jac0core.modresolver { find_jac_project_root }

glob _VALID_SPACES: tuple = ('server', 'client', 'native'),
     _pins_cache: dict[str, tuple[float, dict[str, str]]] = {};


def _load_pins(root_dir: str) -> dict[str, str] {
    toml_path = os.path.join(root_dir, "jac.toml");
    try {
        mtime = os.path.getmtime(toml_path);
    } except OSError {
        return {};
    }
    cached = _pins_cache.get(root_dir);
    if cached is not None and cached[0] == mtime {
        return cached[1];
    }
    import tomllib;
    try {
        with open(toml_path, "rb") as f {
            doc = tomllib.load(f);
        }
    } except Exception {
        return {};
    }
    raw = doc.get("placement", {}).get("pins", {});
    pins: dict[str, str] = {};
    for (key, value) in raw.items() {
        space = str(value);
        if space not in _VALID_SPACES {
            raise ValueError(
                f"[placement.pins] in {toml_path}: '{key}' pins to "
                f"'{space}', expected one of {list(_VALID_SPACES)}."
            );
        }
        pins[str(key)] = space;
    }
    _pins_cache[root_dir] = (mtime, pins);
    return pins;
}


def _module_dot_path(source_path: str, root_dir: str) -> str {
    abs_path = os.path.realpath(os.path.abspath(source_path));
    rel = os.path.relpath(abs_path, os.path.realpath(root_dir));
    if rel.startswith("..") {
        rel = os.path.basename(abs_path);
    }
    if rel.endswith(".jac") {
        rel = rel[:-4];
    }
    return rel.replace(os.sep, ".");
}


def config_pins_for(source_path: str) -> dict[str, str] {
    if not source_path {
        return {};
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return {};
    }
    return _load_pins(root_dir);
}


def config_pin_for(source_path: str, element_name: str) -> str {
    if not source_path {
        return '';
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return '';
    }
    pins = _load_pins(root_dir);
    if not pins {
        return '';
    }
    mod_dot = _module_dot_path(source_path, root_dir);
    for (pattern, space) in pins.items() {
        if element_name and fnmatch.fnmatchcase(f"{mod_dot}.{element_name}", pattern) {
            return space;
        }
        if fnmatch.fnmatchcase(mod_dot, pattern) {
            return space;
        }
    }
    return '';
}


def config_module_pin(source_path: str) -> str {
    return config_pin_for(source_path, '');
}


def pins_digest(source_path: str) -> str {
    pins = config_pins_for(source_path);
    if not pins {
        return '';
    }
    return json.dumps(pins, sort_keys=True);
}

glob _npm_deps_cache: dict[str, tuple[float, set[str]]] = {};


def npm_dependency_names(source_path: str) -> set[str] {
    if not source_path {
        return set();
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return set();
    }
    toml_path = os.path.join(root_dir, "jac.toml");
    try {
        mtime = os.path.getmtime(toml_path);
    } except OSError {
        return set();
    }
    cached = _npm_deps_cache.get(root_dir);
    if cached is not None and cached[0] == mtime {
        return cached[1];
    }
    import tomllib;
    try {
        with open(toml_path, "rb") as f {
            doc = tomllib.load(f);
        }
    } except Exception {
        return set();
    }
    deps = doc.get("dependencies", {});
    npm = deps.get("npm", {}) if isinstance(deps, dict) else {};
    names: set[str] = set();
    if isinstance(npm, dict) {
        for k in npm {
            key = str(k);
            if key == "dev" {
                continue;
            }
            names.add(key);
        }
        dev = npm.get("dev", {});
        if isinstance(dev, dict) {
            for k in dev {
                names.add(str(k));
            }
        }
    }
    _npm_deps_cache[root_dir] = (mtime, names);
    return names;
}

glob _framework_cache: dict[str, tuple[float, str]] = {};


def client_framework(source_path: str) -> str {
    if not source_path {
        return "react";
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return "react";
    }
    toml_path = os.path.join(root_dir, "jac.toml");
    try {
        mtime = os.path.getmtime(toml_path);
    } except OSError {
        return "react";
    }
    cached = _framework_cache.get(root_dir);
    if cached is not None and cached[0] == mtime {
        return cached[1];
    }
    import tomllib;
    fw = "react";
    try {
        with open(toml_path, "rb") as f {
            doc = tomllib.load(f);
        }
        client = doc.get("client", {});
        if isinstance(client, dict) {
            fw = str(client.get("framework", "react"));
        }
    } except Exception {
        fw = "react";
    }
    _framework_cache[root_dir] = (mtime, fw);
    return fw;
}
