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


def native_placement_hard(prog: JacProgram, mod_path: str) -> bool {
    opts = prog.options;
    if opts is None {
        return False;
    }
    if opts.aot_mode or opts.force_codespace {
        return True;
    }
    return bool(mod_path and opts.native_required_for(mod_path));
}


def native_placement_soft(prog: JacProgram, mod: uni.Module) -> bool {
    if mod.decided_codespace != SPACE_NATIVE and not mod.codespace_inferred {
        return False;
    }
    mod_path = mod.loc.mod_path if mod.loc is not None else "";
    return not native_placement_hard(prog, mod_path);
}


glob _placement_plans: dict[str, str] = {};

def element_key(elem: uni.UniNode) -> str {
    loc = elem.loc;
    return f"{os.path.basename(loc.mod_path)}:{loc.first_line}:{loc.col_start}";
}


def encode_plan(digest: str, placed: dict[str, str]) -> str {
    native: list[str] = [];
    client: list[str] = [];
    for key in sorted(placed.keys()) {
        if placed[key] == SPACE_NATIVE {
            native.append(key);
        } elif placed[key] == SPACE_CLIENT {
            client.append(key);
        }
    }
    return f"{digest}|{','.join(native)}|{','.join(client)}";
}


def decode_plan(plan: str, digest: str) -> (dict[str, str] | None) {
    if not plan {
        return None;
    }
    parts = plan.split('|');
    if len(parts) != 3 or parts[0] != digest {
        return None;
    }
    placed: dict[str, str] = {};
    for item in parts[1].split(',') {
        if item {
            placed[item] = SPACE_NATIVE;
        }
    }
    for item in parts[2].split(',') {
        if item {
            placed[item] = SPACE_CLIENT;
        }
    }
    return placed;
}


def apply_plan(module: uni.Module, placed: dict[str, str]) {
    import from jaclang.compiler.frontend.constant { CodeContext }
    spaces = {SPACE_NATIVE: CodeContext.NATIVE, SPACE_CLIENT: CodeContext.CLIENT};
    for elem in module.body {
        if not isinstance(elem, uni.ContextAwareNode) {
            continue;
        }
        want = placed.get(element_key(elem));
        if want is None or elem.code_context == spaces[want] {
            continue;
        }
        elem.code_context = spaces[want];
        if isinstance(elem, uni.ModuleCode) and elem.body {
            for inner in elem.body {
                if isinstance(inner, uni.ContextAwareNode) {
                    inner.code_context = spaces[want];
                }
            }
        }
    }
}


def write_plan(module: uni.Module, given: list[str]) {
    """Record where the module's elements ended up, as the plan its second
    analysis is run under. `given` is where each stood before placement; a
    module nothing moved in needs no second analysis and gets no plan.""";
    placed: dict[str, str] = {};
    moved = False;
    for (index, elem) in enumerate(module.body) {
        if not isinstance(elem, uni.ContextAwareNode) {
            continue;
        }
        now = elem.code_context.value;
        if index >= len(given) or given[index] != now {
            moved = True;
        }
        if now != SPACE_SERVER {
            placed[element_key(elem)] = now;
        }
    }
    if moved and module.source is not None {
        module.gen.placement_plan = encode_plan(module.source.hash, placed);
    }
}


def contexts_of(module: uni.Module) -> list[str] {
    return [
        elem.code_context.value if isinstance(elem, uni.ContextAwareNode) else ''
        for elem in module.body
    ];
}


def held_plan(path: str) -> str {
    return _placement_plans.get(os.path.realpath(path), '');
}


def hold_plan(path: str, plan: str) {
    key = os.path.realpath(path);
    if plan {
        _placement_plans[key] = plan;
    } else {
        _placement_plans.pop(key, None);
    }
}


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
