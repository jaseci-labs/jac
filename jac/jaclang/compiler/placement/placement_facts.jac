import os;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.host { active_host }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.driver.compile_options { CompileOptions }

glob SPACE_SERVER: str = 'server',
     SPACE_CLIENT: str = 'client',
     SPACE_NATIVE: str = 'native';

glob NATIVE_POLICY_DIR_REL: tuple[str, ...] = ("client/targets/desktop/native", );
glob TOOLCHAIN_NATIVE_ONLY_REL: tuple[str, ...] = ("runtime", "na_stdlib"),
     TOOLCHAIN_MIXED_NATIVE_REL: tuple[str, ...] = (
         "client",
         "targets",
         "desktop",
         "native"
     );


def project_root_of(source_path: str) -> (str | None) {
    return active_host().project_root(source_path);
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


def declared_path_spaces(source_path: str, prog: JacProgram) -> set[str] {
    import from jaclang.compiler.placement.placement_solver { _materialize_module }
    return module_spaces(_materialize_module(source_path, prog));
}


def discover_spaces(
    paths: list[str], prog: (JacProgram | None) = None
) -> dict[str, set[str]] {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.boundary_classify { hub_module_for_path }
    target = prog if prog is not None else JacProgram();
    out: dict[str, set[str]] = {};
    for p in paths {
        ap = os.path.abspath(p);
        mod = hub_module_for_path(ap, target);
        if mod is None {
            try {
                mod = target.compile(file_path=ap, no_cgen=True);
            } except Exception {}
        }
        spaces = set(module_spaces(mod));
        if target.count_module_errors(os.path.normpath(ap)) > 0 {
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


def _toolchain_rel(source_path: str) -> (str | None) {
    import from jaclang.compiler.kernel_target { target_package_rel }
    return target_package_rel(source_path);
}

def native_only(source_path: str) -> bool {
    rel = _toolchain_rel(source_path);
    if rel is None {
        return False;
    }
    import from jaclang.compiler.kernel_target { active_kernel_target }
    spec = active_kernel_target();
    if spec is not None {
        return spec.is_native_only(rel);
    }
    return active_host().is_native_only_source(rel);
}

def native_lowered(source_path: str) -> bool {
    rel = _toolchain_rel(source_path);
    if rel is None {
        return False;
    }
    import from jaclang.compiler.kernel_target { active_kernel_target }
    spec = active_kernel_target();
    if spec is not None {
        return spec.is_native_lowered(rel);
    }
    return active_host().is_native_lowered_source(rel);
}

def native_unit(
    source_path: str,
    native_unit_compile: (bool | None) = None,
    prog: (JacProgram | None) = None
) -> bool {
    if native_only(source_path) {
        return True;
    }
    import from jaclang.compiler.frontend.codeinfo { is_kernel_unit_path }
    if is_kernel_unit_path(source_path) {
        return True;
    }
    import from jaclang.compiler.placement.placement_pins { effective_module_pin }
    if effective_module_pin(source_path, prog) == SPACE_NATIVE {
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

def native_units_of(package_dir: str, sources: list[str]) -> list[str] {
    out: list[str] = [];
    for p in sources {
        if native_unit(p, native_unit_compile=True) {
            out.append(os.path.realpath(p));
        }
    }
    return sorted(set(out));
}

def session_declares_native(
    options: CompileOptions, source: str, element: str, program: JacProgram
) -> bool {
    import from jaclang.compiler.placement.placement_pins {
        effective_pin_for,
        config_kind_space
    }
    return options.force_codespace == "native"
        or options.default_codespace == "native"
        or options.native_required_for(source)
        or effective_pin_for(source, element, program) == "native"
        or native_unit(source, options.native_unit, program)
        or config_kind_space(source, options.app_kind) == "native";
}
