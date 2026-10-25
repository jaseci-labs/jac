impl native_placement_hard(prog: JacProgram, mod_path: str) -> bool {
    opts = prog.options;
    if opts is None {
        return False;
    }
    if opts.aot_mode or opts.force_codespace {
        return True;
    }
    return bool(mod_path and opts.native_required_for(mod_path));
}

impl native_placement_soft(prog: JacProgram, mod: uni.Module) -> bool {
    if mod.decided_codespace != SPACE_NATIVE and not mod.codespace_inferred {
        return False;
    }
    mod_path = mod.loc.mod_path if mod.loc is not None else "";
    return not native_placement_hard(prog, mod_path);
}

impl contexts_of(module: uni.Module) -> list[str] {
    return [
        elem.code_context.value if isinstance(elem, uni.ContextAwareNode) else ''
        for elem in module.elements
    ];
}

impl settle_server(module: uni.Module) -> bool {
    moved = False;
    for elem in module.elements {
        if isinstance(elem, uni.ContextAwareNode)
            and elem.code_context == CodeContext.NATIVE {
            _stamp_context_element(elem, CodeContext.SERVER);
            moved = True;
        }
    }
    if module.decided_codespace == SPACE_NATIVE {
        module.decided_codespace = "";
    }
    module.codespace_inferred = False;
    module.gen.native_codespace = False;
    return moved;
}

impl project_root_of(source_path: str) -> (str | None) {
    return active_host().project_root(source_path);
}

impl require_project_root(source_path: str) -> str {
    proj_root = project_root_of(source_path);
    if not proj_root {
        raise ValueError(
            f"{source_path} is not inside a jac project (no jac.toml in any "
            "ancestor directory), so placement cannot be resolved for it."
        );
    }
    return proj_root;
}

impl module_spaces(mod: (uni.Module | None)) -> set[str] {
    if mod is None {
        return {SPACE_SERVER};
    }
    if mod.decided_codespace {
        return {str(mod.decided_codespace)};
    }
    spaces: set[str] = set();
    for stmt in mod.elements {
        if isinstance(stmt, uni.ContextAwareNode) {
            spaces.add(str(stmt.code_context));
        }
    }
    if not spaces {
        return {SPACE_SERVER};
    }
    return spaces;
}

impl is_client_only(mod: (uni.Module | None)) -> bool {
    return module_spaces(mod) == {SPACE_CLIENT};
}

impl emits_server_code(mod: (uni.Module | None)) -> bool {
    return SPACE_SERVER in module_spaces(mod);
}

impl discover_spaces(
    paths: list[str], prog: (JacProgram | None) = None
) -> dict[str, set[str]] {
    target = prog if prog is not None else JacProgram();
    out: dict[str, set[str]] = {};
    for p in paths {
        ap = os.path.abspath(p);
        mod = hub_module_for_path(ap, target);
        if mod is None {
            record = module_record(ap, target);
            if record is not None and record.spaces {
                out[ap] = set(record.spaces);
                continue;
            }
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

impl pinned_module_space(source_path: str) -> str {
    return config_module_pin(source_path);
}

impl spaces_are_client_only(spaces: set[str]) -> bool {
    return len(spaces) == 1 and SPACE_CLIENT in spaces;
}

impl module_record(
    source_path: str, program: (JacProgram | None) = None
) -> (PlacementSummary | None) {
    """With a program, the record is read where that program's compile of the
    module keys its cache file.""";
    real = os.path.realpath(source_path);
    if program is None {
        return _record_at(real);
    }
    actual = program._get_compiler().product_program(real, program, execution=True);
    with cache_scope(owner_scope_options(actual)) {
        return _record_at(real);
    }
}

impl _record_at(real: str) -> (PlacementSummary | None) {
    try {
        cache_path = get_module_cache_path(real);
        if not is_module_cache_valid(real, cache_path) {
            return None;
        }
        data = read_jir(cache_path);
        raw = read_section_bytes(data, SEC_PLACEMENT);
        if raw is None {
            return None;
        }
        return summary_from_bytes(raw, path_mapper=read_jir_paths(data).resolve);
    } except OSError {
        return None;
    }
}

impl _toolchain_rel(source_path: str) -> (str | None) {
    return target_package_rel(source_path);
}

impl variant_selected(source_path: str) -> (bool | None) {
    if not is_native_variant_path(source_path) {
        return None;
    }
    return is_selected_native_variant(source_path);
}

impl native_only(source_path: str) -> bool {
    selected = variant_selected(source_path);
    if selected is not None {
        return selected;
    }
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

impl native_lowered(source_path: str) -> bool {
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

impl native_unit(
    source_path: str,
    native_unit_compile: (bool | None) = None,
    prog: (JacProgram | None) = None
) -> bool {
    selected = variant_selected(source_path);
    if selected is not None {
        return selected;
    }
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

impl native_units_of(package_dir: str, sources: list[str]) -> list[str] {
    out: list[str] = [];
    for p in sources {
        if native_unit(p, native_unit_compile=True) {
            out.append(os.path.realpath(p));
        }
    }
    return sorted(set(out));
}

impl session_declares_native(
    options: CompileOptions, source: str, element: str, program: JacProgram
) -> bool {
    return options.force_codespace == "native"
        or options.default_codespace == "native"
        or options.native_required_for(source)
        or effective_pin_for(source, element, program) == "native"
        or native_unit(source, options.native_unit, program)
        or config_kind_space(source, options.app_kind) == "native";
}
