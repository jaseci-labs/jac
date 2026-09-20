import from jaclang.compiler.driver.compilation_context { context_app }
import json;
import os;
import from jaclang.project.modresolver { find_jac_project_root }
import from jaclang.project.workspace {
    app_fact_digest,
    kind_codespace,
    workspace_for_path
}

import from jaclang.project.placement { validate_pins, match_pin }

def config_pins_for(source_path: str) -> dict[str, str] {
    if not source_path {
        return {};
    }
    ws = workspace_for_path(source_path);
    if ws is None {
        return {};
    }
    app = context_app(source_path);
    pins = app.pins if app is not None else ws.base_pins;
    return validate_pins(pins, ws.toml_path);
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
    return match_pin(source_path, ws.project_root, pins, element_name);
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
    app = context_app(source_path);
    return app.kind if app is not None else '';
}


def config_kind_space(source_path: str, fallback_kind: str = '') -> str {
    kind = config_project_kind(source_path) or fallback_kind;
    return kind_codespace(kind) if kind else '';
}


def pins_digest(source_path: str) -> str {
    pins = config_pins_for(source_path);
    facts = app_fact_digest(context_app(source_path)) if source_path else '';
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
    app = context_app(source_path);
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

glob _FRAMEWORK_PACKAGES: dict[str, set[str]] = {
         "react": {"react", "react-dom"},
         "preact": {"preact"},
         "solid": {"solid-js"}
     };


obj BareImportVerdict {
    has world: str = 'py',
        rule: str = 'python import',
        path: str = '';
}


def _declared_npm_rule(spec: str, source_path: str) -> str {
    import from jaclang.project.modresolver { npm_package_root }
    pkg_root = npm_package_root(spec);
    if pkg_root in npm_dependency_names(source_path) {
        return 'npm dependency ([dependencies.npm])';
    }
    fw = client_framework(source_path);
    if pkg_root in _FRAMEWORK_PACKAGES.get(fw, set()) {
        return f"npm dependency ({fw} framework package)";
    }
    return '';
}


def _installed_npm_rule(spec: str, source_path: str) -> str {
    import from jaclang.project.modresolver { has_client_npm_package }
    if has_client_npm_package(spec, source_path) {
        return 'npm dependency (installed under .jac/client/node_modules)';
    }
    return '';
}


def in_client_npm_world(spec: str, source_path: str) -> bool {
    if not spec {
        return False;
    }
    return bool(
        _declared_npm_rule(spec, source_path) or _installed_npm_rule(spec, source_path)
    );
}


def classify_bare_import(spec: str, source_path: str) -> BareImportVerdict {
    if not spec {
        return BareImportVerdict();
    }
    import from jaclang.project.modresolver { resolve_module }
    path = '';
    lang = '';
    try {
        (path, lang) = resolve_module(spec, source_path);
    } except Exception {
        path = '';
    }
    found = bool(path) and os.path.isfile(path);
    if found and lang == 'jac' {
        return BareImportVerdict(world='jac', rule='jac module', path=path);
    }
    declared = _declared_npm_rule(spec, source_path);
    if declared {
        return BareImportVerdict(world='npm', rule=declared);
    }
    installed = _installed_npm_rule(spec, source_path);
    if found and lang in ('py', 'pyi') {
        rule = 'python import (python module shadows the undeclared npm package)'
            if installed
            else 'python import';
        return BareImportVerdict(world='py', rule=rule, path=path);
    }
    if installed {
        return BareImportVerdict(world='npm', rule=installed);
    }
    return BareImportVerdict(path=path if found else '');
}
