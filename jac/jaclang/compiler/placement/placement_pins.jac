import from jaclang.compiler.driver.compilation_context { context_app }
import fnmatch;
import os;
import from jaclang.compiler.frontend.host { NativeVerdict, active_host }
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.project.app_kinds { kind_codespace }

glob PIN_SPACES: tuple[str, ...] = ('server', 'client', 'native');

def validate_pins(pins: dict[str, str], toml_path: str) -> dict[str, str] {
    for (key, space) in pins.items() {
        if space not in PIN_SPACES {
            raise ValueError(
                f"[placement.pins] in {toml_path}: '{key}' pins to '{space}', "
                    + f"expected one of {list(PIN_SPACES)}."
            );
        }
    }
    return pins;
}

def module_dot_path(source_path: str, root_dir: str) -> str {
    path = os.path.realpath(source_path);
    relative = os.path.relpath(os.path.dirname(path), os.path.realpath(root_dir));
    parent = relative.replace(os.sep, '.')
        if relative != '.' and not relative.startswith('..')
        else '';
    stem = active_host().path_facts(path).module_stem;
    if parent and stem {
        return parent + '.' + stem;
    }
    return parent or stem;
}

def match_pin(
    source_path: str, root_dir: str, pins: dict[str, str], element_name: str = ''
) -> str {
    module = module_dot_path(source_path, root_dir);
    for (pattern, space) in pins.items() {
        if element_name and fnmatch.fnmatchcase(f'{module}.{element_name}', pattern) {
            return space;
        }
        if fnmatch.fnmatchcase(module, pattern) {
            return space;
        }
    }
    return '';
}

def config_pins_for(source_path: str) -> dict[str, str] {
    if not source_path {
        return {};
    }
    ws = active_host().workspace(source_path);
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
    ws = active_host().workspace(source_path);
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


def module_native_demoted(source_path: str, prog: (JacProgram | None) = None) -> bool {
    verdict = _native_verdict(source_path, prog);
    return verdict is not None and verdict.demoted;
}

def native_demotion_code(source_path: str, prog: (JacProgram | None) = None) -> str {
    verdict = _native_verdict(source_path, prog);
    return verdict.code if verdict is not None else "";
}

def _native_verdict(
    source_path: str, prog: (JacProgram | None)
) -> (NativeVerdict | None) {
    return active_host().native_verdict(source_path, prog);
}


def effective_pin_for(
    source_path: str, element_name: str, prog: (JacProgram | None) = None
) -> str {
    pin = config_pin_for(source_path, element_name);
    if pin == 'native' and module_native_demoted(os.path.realpath(source_path), prog) {
        return '';
    }
    return pin;
}


def effective_module_pin(source_path: str, prog: (JacProgram | None) = None) -> str {
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
    app = context_app(source_path) if source_path else None;
    facts = app.fact_digest if app is not None else '';
    if not pins and not facts {
        return '';
    }
    return ";".join([f"{name}={pins[name]}" for name in sorted(pins.keys())]) + facts;
}


def npm_dependency_names(source_path: str) -> set[str] {
    if not source_path {
        return set();
    }
    ws = active_host().workspace(source_path);
    if ws is None {
        return set();
    }
    app = context_app(source_path);
    return set(app.npm_names) if app is not None else set(ws.base_npm_names);
}

def client_framework(source_path: str) -> str {
    facts = active_host().project_facts(source_path) if source_path else None;
    return facts.client_framework if facts is not None else "react";
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


def npm_package_root(spec: str) -> str {
    parts = [
        p
        for p in spec.split('/')
        if p
    ];
    if not parts {
        return spec;
    }
    if (spec.startswith('@') and len(parts) >= 2) {
        return parts[0] + '/' + parts[1];
    }
    return parts[0];
}

def _declared_npm_rule(spec: str, source_path: str) -> str {
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
    if active_host().has_npm_package(spec, source_path) {
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
    path = '';
    lang = '';
    try {
        (path, lang) = active_host().resolve_module(spec, source_path);
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
