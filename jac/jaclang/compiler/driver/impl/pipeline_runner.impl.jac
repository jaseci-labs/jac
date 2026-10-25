impl wasm_ir(program: JacProgram, file_path: str) -> tuple[str, set[str]] {
    (llvm_ir, app_imports, _units) = wasm_ir_units(program, file_path);
    return (llvm_ir, app_imports);
}

impl wasm_ir_units(
    program: JacProgram, file_path: str
) -> tuple[str, set[str], list[str]] {
    (gc_mode, enf_mods, enf_grand) = _project_gc_settings();
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        before = len(program.errors_had);
        options = CompileOptions(
            aot_mode=True,
            default_codespace='native',
            na_gc_mode=gc_mode,
            memory_enforce=enf_mods,
            memory_exempt=enf_grand,
            native_target="wasm32-unknown-unknown"
        );
        na_coverage_begin();
        try {
            ir = program.compile(file_path=os.path.abspath(file_path), options=options);
        } finally {
            coverage = na_coverage_end();
        }
        if len(program.errors_had) > before {
            first = program.errors_had[before].pretty_print();
            more = len(program.errors_had) - before - 1;
            suffix = f" (+{more} more)" if more > 0 else "";
            raise RuntimeError(f"{first}{suffix}");
        }
        if (ir is None) or (ir.gen.llvm_ir is None) {
            rec = coverage.get(os.path.realpath(os.path.abspath(file_path)));
            reason = "the module did not lower to native IR"
                + " (no demotion recorded; it likely compiled as a"
                + " non-native codespace)";
            if rec {
                code = f" [{rec['code']}]" if rec['code'] else '';
                detail = f": {rec['detail']}" if rec['detail'] else '';
                reason = f"{rec['outcome']}{code}{detail}";
            }
            raise RuntimeError(
                f"native lowering produced no IR for '{file_path}': {reason}"
            );
        }
        import from jaclang.compiler.backends.native.link_plan {
            build_link_plan,
            wasm_program_ir
        }
        plan = build_link_plan(program, [ir.loc.mod_path], options);
        llvm_ir_str = wasm_program_ir(plan);
        app_ir_str = str(ir.gen.llvm_ir);
        app_imports = app_declared_imports(ir, plan);
        unit_paths = [unit.path for unit in plan.units];
    } finally {
        pop_native_target(prev);
    }
    if gc_mode == "none" {
        _assert_ir_rc_free(app_ir_str, file_path);
    }
    return (llvm_ir_str, app_imports, unit_paths);
}

impl wasm_artifact(program: JacProgram, file_path: str, exports: list[str]) -> bytes {
    return wasm_artifact_inputs(program, file_path, exports)[0];
}

impl wasm_artifact_inputs(
    program: JacProgram, file_path: str, exports: list[str]
) -> tuple[bytes, list[str]] {
    (llvm_ir, app_imports, units) = wasm_ir_units(program, file_path);
    return (emit_wasm_from_ir(llvm_ir, exports, app_imports=app_imports), units);
}

impl native_application(
    program: JacProgram,
    file_path: str,
    target: str = '',
    memory: str = '',
    debug: bool = False,
    no_ir_cache: bool = False
) -> tuple[uni.Module, CompileOptions] {
    previous = push_native_target(target) if target else None;
    try {
        options = CompileOptions(
            aot_mode=True,
            default_codespace='native',
            memory_profile=memory or None,
            native_target=target or None,
            native_debug=True if debug else None,
            no_ir_cache=debug or no_ir_cache
        );
        module = program.compile(file_path=os.path.abspath(file_path), options=options);
        return (module, options);
    } finally {
        if target {
            pop_native_target(previous);
        }
    }
}

impl build_wasm(program: JacProgram, path: str, exports: list[str]) -> bytes {
    return wasm_artifact(program, path, exports);
}

impl route_exports(program: JacProgram, path: str) -> tuple[str | None, str | None] {
    real = os.path.realpath(path);
    builder = program._get_compiler();
    artifact = builder.get_client_artifact(real, program);
    if artifact is None {
        artifact = builder.last_client_artifact(real, program);
    }
    if artifact is None {
        return (None, None);
    }
    return (artifact.manifest.page_export, artifact.manifest.layout_export);
}

impl compile_application(
    program: JacProgram, entry_path: str, options: CompileOptions
) -> uni.Module {
    import copy;
    import from pathlib { Path }
    entry_path = os.path.realpath(entry_path);
    project_root = os.path.realpath(
        options.project_root or os.path.dirname(entry_path)
    );
    selected = context_program(program, bind_options(entry_path, program, options));
    pending: list[tuple[JacProgram, str]] = [(selected, entry_path)];
    if kind_has_client(options.app_kind) {
        pages = Path(entry_path).parent / 'pages';
        if pages.is_dir() {
            pending.extend(
                (selected, str(p))
                for p in sorted(pages.rglob('*.jac'))
                if not is_annex(str(p))
            );
        }
    }
    seen: set[tuple[str, str]] = set();
    entry_module: uni.Module | None = None;
    while pending {
        (context, path) = pending.pop(0);
        if options.cancel_token is not None and options.cancel_token.is_set() {
            break;
        }
        bound = bind_options(path, context, copy.copy(context.options));
        bound.no_cgen = options.no_cgen;
        bound.native_parity = options.native_parity;
        bound.cancel_token = options.cancel_token;
        context = context_program(context, bound);
        identity = (context.context_key, path);
        if identity in seen {
            continue;
        }
        seen.add(identity);
        previous = context.options;
        codegen_options = copy.copy(bound);
        codegen_options.skip_native_engine = True;
        try {
            module = program.compile(path, options=codegen_options);
        } finally {
            context.options = previous;
        }
        if path == entry_path and entry_module is None {
            entry_module = module;
        }
        dependencies = package_sources(path, project_root);
        dependencies.update(context.iface_registry().direct_deps.get(path, {}));
        dependencies.update(
            dependency
            for (dependency, importers) in context.deps.dependents.items()
            if path in importers
        );
        for statement in module.get_all_sub_nodes(Import) {
            if not statement.is_jac or statement.is_virtual_jac {
                continue;
            }
            imports = [statement.from_loc]
                if statement.from_loc is not None
                else [
                    item
                    for item in statement.items
                    if isinstance(item, ModulePath)
                ];
            for imported in imports {
                dependency = imported.resolve_relative_path();
                if isinstance(dependency, str) and dependency.endswith('.jac') {
                    dependencies.add(os.path.realpath(dependency));
                }
            }
        }
        pending.extend(
            (context, dependency)
            for dependency in sorted(dependencies)
            if dependency.startswith(project_root + os.sep)
                and not program._get_compiler().selfhost.is_selfhost(
                    program._get_compiler().selfhost.resolve(dependency, context)
                )
                and os.path.isfile(dependency)
                and holds_application_code(os.path.relpath(dependency, project_root))
        );
    }
    if entry_module is None {
        raise RuntimeError(
            f'Application compilation cancelled before parsing {entry_path}'
        );
    }
    return entry_module;
}
