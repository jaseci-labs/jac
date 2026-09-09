import fnmatch;
import json;
import os;
import from jaclang.compiler.driver.modresolver { find_jac_project_root }
import from jaclang.compiler.placement.workspace {
    app_fact_digest,
    app_for_path,
    kind_codespace,
    workspace_for_path
}

glob _VALID_SPACES: tuple = ('server', 'client', 'native');


def _validated_pins(pins: dict[str, str], toml_path: str) -> dict[str, str] {
    for (key, space) in pins.items() {
        if space not in _VALID_SPACES {
            raise ValueError(
                f"[placement.pins] in {toml_path}: '{key}' pins to "
                f"'{space}', expected one of {list(_VALID_SPACES)}."
            );
        }
    }
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
    ws = workspace_for_path(source_path);
    if ws is None {
        return {};
    }
    app = ws.app_for_path(source_path);
    pins = app.pins if app is not None else ws.base_pins;
    return _validated_pins(pins, ws.toml_path);
}


def config_pin_for(source_path: str, element_name: str) -> str {
    if not source_path {
        return '';
    }
    ws = workspace_for_path(source_path);
    if ws is None {
        return '';
    }
    pins = config_pins_for(source_path);
    if not pins {
        return '';
    }
    mod_dot = _module_dot_path(source_path, ws.project_root);
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


glob _na_demotion_memo: dict[str, tuple] = {},
     _na_demotion_code: dict[str, str] = {},
     _na_demotion_probed: set[str] = set();


def _demotion_sidecar(path: str) -> (str | None) {
    try {
        import from jaclang.compiler.driver.jir { get_module_cache_path }
        return str(get_module_cache_path(path).with_suffix('.nademote'));
    } except Exception {
        return None;
    }
}


def _file_key(path: str) -> (tuple | None) {
    try {
        st = os.stat(path);
        return (st.st_mtime_ns, st.st_size);
    } except OSError {
        return None;
    }
}


def _load_demotion(path: str) -> (tuple | None) {
    sidecar = _demotion_sidecar(path);
    if sidecar is None {
        return None;
    }
    try {
        with open(sidecar, "r", encoding="utf-8") as f {
            parts = f.read().split();
        }
        if len(parts) < 2 {
            return None;
        }
        _na_demotion_code[path] = parts[2] if len(parts) > 2 else "";
        return (int(parts[0]), int(parts[1]));
    } except Exception {
        return None;
    }
}


def _remove_demotion_sidecar(path: str) {
    sidecar = _demotion_sidecar(path);
    if sidecar is None {
        return;
    }
    try {
        os.remove(sidecar);
    } except OSError {}
}


def _is_demoted_native(path: str) -> bool {
    key = _na_demotion_memo.get(path);
    if key is None {
        if path in _na_demotion_probed {
            return False;
        }
        _na_demotion_probed.add(path);
        key = _load_demotion(path);
        if key is None {
            return False;
        }
        _na_demotion_memo[path] = key;
    }
    if key == _file_key(path) {
        return True;
    }
    del _na_demotion_memo[path];
    _na_demotion_code.pop(path, None);
    _remove_demotion_sidecar(path);
    return False;
}


def _demoted_native_code(path: str) -> str {
    if not _is_demoted_native(path) {
        return "";
    }
    return _na_demotion_code.get(path, "");
}


def _mark_demoted_native(path: str, code: str = "") {
    import from jaclang.compiler.native_scope {
        in_native_scope_path,
        scope_lowering_active
    }
    if scope_lowering_active() and in_native_scope_path(path) {
        return;
    }
    key = _file_key(path);
    if key is None {
        return;
    }
    _na_demotion_memo[path] = key;
    _na_demotion_code[path] = code;
    _na_demotion_probed.discard(path);
    sidecar = _demotion_sidecar(path);
    if sidecar is None {
        return;
    }
    try {
        os.makedirs(os.path.dirname(sidecar), exist_ok=True);
        tmp = f"{sidecar}.{os.getpid()}.tmp";
        with open(tmp, "w", encoding="utf-8") as f {
            f.write(f"{key[0]} {key[1]} {code}\n");
        }
        os.replace(tmp, sidecar);
    } except OSError {}
}


def _clear_demoted_native(path: str) {
    _na_demotion_memo.pop(path, None);
    _na_demotion_code.pop(path, None);
    _na_demotion_probed.discard(path);
    _remove_demotion_sidecar(path);
}


def effective_pin_for(source_path: str, element_name: str) -> str {
    pin = config_pin_for(source_path, element_name);
    if pin == 'native' and _is_demoted_native(os.path.realpath(source_path)) {
        return '';
    }
    return pin;
}


def effective_module_pin(source_path: str) -> str {
    return effective_pin_for(source_path, '');
}


def config_project_kind(source_path: str) -> str {
    if not source_path {
        return '';
    }
    app = app_for_path(source_path);
    return app.kind if app is not None else '';
}


def config_kind_space(source_path: str, fallback_kind: str = '') -> str {
    kind = config_project_kind(source_path) or fallback_kind;
    return kind_codespace(kind) if kind else '';
}


def pins_digest(source_path: str) -> str {
    pins = config_pins_for(source_path);
    facts = app_fact_digest(app_for_path(source_path)) if source_path else '';
    if not pins and not facts {
        return '';
    }
    return json.dumps(pins, sort_keys=True) + facts;
}


def npm_dependency_names(source_path: str) -> set[str] {
    if not source_path {
        return set();
    }
    ws = workspace_for_path(source_path);
    if ws is None {
        return set();
    }
    app = ws.app_for_path(source_path);
    return set(app.npm_names) if app is not None else set(ws.base_npm_names);
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
