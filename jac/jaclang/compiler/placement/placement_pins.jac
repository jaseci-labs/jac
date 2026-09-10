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
