import os;
import jaclang.compiler.frontend.unitree as uni;

glob SPACE_SERVER: str = 'server',
     SPACE_CLIENT: str = 'client',
     SPACE_NATIVE: str = 'native';

"""The toolchain directory whose modules are native units under the default
verdict (the desktop target's native side)."""
glob NATIVE_POLICY_DIR_REL: tuple[str, ...] = ("client/targets/desktop/native", );


def project_root_of(source_path: str) -> (str | None) {
    import from jaclang.compiler.driver.modresolver { find_jac_project_root }
    return find_jac_project_root(source_path);
}


def require_project_root(source_path: str) -> str {
    proj_root = project_root_of(source_path);
    if not proj_root {
        raise ValueError(
            f"{source_path} is not inside a jac project (no jac.toml in any "
            "ancestor directory), so placement cannot be resolved for it."
        );
    }
    return proj_root;
}


def module_spaces(mod: (uni.Module | None)) -> set[str] {
    if mod is None {
        return {SPACE_SERVER};
    }
    if mod.decided_codespace {
        return {str(mod.decided_codespace)};
    }
    spaces: set[str] = set();
    for stmt in mod.body {
        if isinstance(stmt, uni.ContextAwareNode) {
            spaces.add(str(stmt.code_context));
        }
    }
    if not spaces {
        return {SPACE_SERVER};
    }
    return spaces;
}


def is_client_only(mod: (uni.Module | None)) -> bool {
    return module_spaces(mod) == {SPACE_CLIENT};
}


def emits_server_code(mod: (uni.Module | None)) -> bool {
    return SPACE_SERVER in module_spaces(mod);
}


def declared_path_spaces(source_path: str, prog: any) -> set[str] {
    import from jaclang.compiler.placement.placement_solver { _materialize_module }
    return module_spaces(_materialize_module(source_path, prog));
}


def _errors_for_path(prog: any, ap: str) -> int {
    count = 0;
    normed = os.path.normpath(ap);
    for e in prog.errors_had {
        try {
            e_path = os.path.normpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if e_path == normed {
            count += 1;
        }
    }
    return count;
}


def discover_spaces(paths: list[str], prog: any = None) -> dict[str, set[str]] {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.boundary_classify { hub_module_for_path }
    target = prog if prog is not None else JacProgram();
    out: dict[str, set[str]] = {};
    for p in paths {
        ap = os.path.abspath(p);
        mod = hub_module_for_path(ap, target);
        if mod is None {
            try {
                target.compile(file_path=ap, no_cgen=True);
            } except Exception {}
            mod = hub_module_for_path(ap, target);
        }
        spaces = set(module_spaces(mod));
        if _errors_for_path(target, ap) > 0 {
            spaces.add(SPACE_SERVER);
        }
        out[ap] = spaces;
    }
    if prog is None {
        target.release_compile_closure();
    }
    return out;
}


def pinned_module_space(source_path: str) -> str {
    import from jaclang.compiler.placement.placement_pins { config_module_pin }
    return config_module_pin(source_path);
}


def spaces_are_client_only(spaces: set[str]) -> bool {
    return len(spaces) == 1 and SPACE_CLIENT in spaces;
}


def client_only_paths(paths: list[str]) -> set[str] {
    facts = discover_spaces(paths);
    out: set[str] = set();
    for (p, spaces) in facts.items() {
        if spaces_are_client_only(spaces) {
            out.add(p);
        }
    }
    return out;
}


def sealed_spaces_for(source_path: str) -> (set[str] | None) {
    import json;
    ap = os.path.abspath(source_path);
    d = os.path.dirname(ap);
    while True {
        mf = os.path.join(d, "_precompiled", "MANIFEST.json");
        if os.path.isfile(mf) {
            break;
        }
        parent = os.path.dirname(d);
        if parent == d {
            return None;
        }
        d = parent;
    }
    try {
        with open(mf, "r") as f {
            manifest = json.load(f);
        }
    } except Exception {
        return None;
    }
    placement = manifest.get("placement") or {};
    rel = os.path.relpath(ap, d).replace(os.sep, "/");
    spaces = placement.get(rel);
    if spaces is None {
        return None;
    }
    return set(spaces);
}


def _toolchain_rel(source_path: str) -> (str | None) {
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    pkg = os.path.realpath(jaclang_pkg_root());
    rp = os.path.realpath(source_path);
    if not rp.startswith(pkg + os.sep) {
        return None;
    }
    return rp[len(pkg) + 1:].replace(os.sep, "/");
}

"""The module has no bytecode meaning: it imports C symbols or lives under
the native standard library. Such a module is a native unit and nothing
else; `find_jac_files` and `precompile_unit` never bytecode it."""
def native_only(source_path: str) -> bool {
    rel = _toolchain_rel(source_path);
    if rel is None {
        return False;
    }
    import from jaclang.bootstrap_manifest { is_native_only }
    return is_native_only(rel);
}

"""The module participates in a native artifact.

In the order `parse_str` locks a codespace: a native-only toolchain module,
a native pin the demotion verdict has not cancelled, membership in the
kernel's unit roster (`NATIVE_SCOPE`) under a native-unit compile, then
the toolchain's policy directories under the default verdict. The frontend
scope modules are native units and bytecode units at once; the kernel roots
are native units only.
"""
def native_unit(source_path: str, native_unit_compile: (bool | None) = None) -> bool {
    if native_only(source_path) {
        return True;
    }
    import from jaclang.compiler.frontend.codeinfo { is_kernel_unit_path }
    if is_kernel_unit_path(source_path) {
        return True;
    }
    import from jaclang.compiler.placement.placement_pins { effective_module_pin }
    if effective_module_pin(source_path) == SPACE_NATIVE {
        return True;
    }
    import from jaclang.compiler.native_scope { in_native_scope_path }
    if in_native_scope_path(source_path) {
        if native_unit_compile is None {
            import from jaclang.compiler.frontend.codeinfo {
                native_unit_compile_active
            }
            native_unit_compile = native_unit_compile_active();
        }
        return bool(native_unit_compile);
    }
    rel = _toolchain_rel(source_path);
    if rel is not None {
        for d in NATIVE_POLICY_DIR_REL {
            if rel.startswith(d + "/") {
                import from jaclang.compiler.placement.placement_solver {
                    native_default_path_ok
                }
                return native_default_path_ok(source_path);
            }
        }
    }
    return False;
}

"""The native units of a package: every sealable source `native_unit` claims,
resolved, in sorted order."""
def native_units_of(package_dir: str, sources: list[str]) -> list[str] {
    out: list[str] = [];
    for p in sources {
        if native_unit(p, native_unit_compile=True) {
            out.append(os.path.realpath(p));
        }
    }
    return sorted(set(out));
}
