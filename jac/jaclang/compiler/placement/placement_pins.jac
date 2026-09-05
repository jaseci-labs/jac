import fnmatch;
import json;
import os;
import from jaclang.compiler.driver.modresolver { find_jac_project_root }

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


"""Whether the module's current content was demoted from native, read from
its own JIR through the same validity path everything else uses. The
program that recorded the verdict answers from memory until the entry is
persisted; any reader answers from disk afterwards."""
def module_native_demoted(source_path: str, prog: any = None) -> bool {
    verdict = _native_verdict(source_path, prog);
    return verdict is not None and verdict.demoted;
}

def native_demotion_code(source_path: str, prog: any = None) -> str {
    verdict = _native_verdict(source_path, prog);
    return verdict.code if verdict is not None else "";
}

def _native_verdict(source_path: str, prog: any) -> any {
    try {
        if prog is not None {
            return prog.native_units().verdict_for(source_path);
        }
        import from jaclang.compiler.driver.nativecache { read_native_verdict }
        return read_native_verdict(source_path);
    } except Exception {
        return None;
    }
}


"""A native pin the demotion verdict has not cancelled."""
def effective_pin_for(source_path: str, element_name: str, prog: any = None) -> str {
    pin = config_pin_for(source_path, element_name);
    if pin == 'native' and module_native_demoted(os.path.realpath(source_path), prog) {
        return '';
    }
    return pin;
}


def effective_module_pin(source_path: str, prog: any = None) -> str {
    return effective_pin_for(source_path, '', prog);
}


glob _kind_cache: dict[str, tuple[tuple, str]] = {},
     _kind_chain_cache: dict[str, list[str]] = {},
     _kind_probe: dict = {"active": False};


def _enclosing_project_root(root_dir: str) -> str {
    parent = os.path.dirname(os.path.realpath(root_dir));
    if not parent or parent == os.path.realpath(root_dir) {
        return '';
    }
    outer = find_jac_project_root(parent);
    if not outer or os.path.realpath(outer) == os.path.realpath(root_dir) {
        return '';
    }
    return outer;
}


def _declared_project_kind(root_dir: str) -> str {
    import tomllib;
    try {
        with open(os.path.join(root_dir, "jac.toml"), "rb") as f {
            doc = tomllib.load(f);
        }
        return str(doc.get("project", {}).get("kind", "") or "");
    } except Exception {
        return '';
    }
}


def _project_kind_chain(root_dir: str) -> list[str] {
    cached = _kind_chain_cache.get(root_dir);
    if cached is not None {
        return cached;
    }
    chain: list[str] = [];
    cur = root_dir;
    while cur {
        chain.append(cur);
        cur = _enclosing_project_root(cur);
    }
    _kind_chain_cache[root_dir] = chain;
    return chain;
}


def _load_project_kind(root_dir: str) -> str {
    chain = _project_kind_chain(root_dir);
    stamps: list[float] = [];
    for d in chain {
        try {
            stamps.append(os.path.getmtime(os.path.join(d, "jac.toml")));
        } except OSError {
            return '';
        }
    }
    stamp = tuple(stamps);
    cached = _kind_cache.get(root_dir);
    if cached is not None and cached[0] == stamp {
        return cached[1];
    }
    kind = '';
    for d in chain {
        kind = _declared_project_kind(d);
        if kind {
            break;
        }
    }
    _kind_cache[root_dir] = (stamp, kind);
    return kind;
}


def config_project_kind(source_path: str) -> str {
    if not source_path {
        return '';
    }
    root_dir = find_jac_project_root(source_path);
    if not root_dir {
        return '';
    }
    return _load_project_kind(root_dir);
}


def config_kind_space(source_path: str) -> str {
    kind = config_project_kind(source_path);
    if not kind or _kind_probe["active"] {
        return '';
    }
    _kind_probe["active"] = True;
    try {
        import from jaclang.project.kinds { kind_spec }
        spec = kind_spec(kind);
        return spec.codespace if spec is not None else '';
    } except Exception {
        return '';
    } finally {
        _kind_probe["active"] = False;
    }
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
