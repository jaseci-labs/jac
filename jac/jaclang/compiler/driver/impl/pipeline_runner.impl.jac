impl wasm_ir(program: JacProgram, file_path: str) -> tuple[str, set[str]] {
    (llvm_ir, app_imports, _units) = wasm_ir_units(program, file_path);
    return (llvm_ir, app_imports);
}

impl wasm_ir_units(
    program: JacProgram, file_path: str
) -> tuple[str, set[str], list[list[str]]] {
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
        ir = program.compile(file_path=os.path.abspath(file_path), options=options);
        if len(program.errors_had) > before {
            first = program.errors_had[before].pretty_print();
            more = len(program.errors_had) - before - 1;
            suffix = f" (+{more} more)" if more > 0 else "";
            raise RuntimeError(f"{first}{suffix}");
        }
        if (ir is None) or (ir.gen.llvm_ir is None) {
            raise RuntimeError(
                f"native lowering produced no IR for '{file_path}': the module did not compile to the native codespace"
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
        registry = program.native_units();
        unit_paths: list[list[str]] = [];
        for unit in plan.units {
            ent = registry.entries.get(os.path.realpath(unit.path));
            deps = absolutize_ct_deps_section(
                ent.compile_deps, ent.compile_deps_base
            ).decode(
                "utf-8"
            )
                if ent is not None and ent.compile_deps
                else "";
            unit_paths.append([unit.path, deps]);
        }
    } finally {
        pop_native_target(prev);
    }
    if gc_mode == "none" {
        _assert_ir_rc_free(app_ir_str, file_path);
    }
    return (llvm_ir_str, app_imports, unit_paths);
}

impl wasm_artifact_inputs(
    program: JacProgram, file_path: str
) -> tuple[bytes, list[list[str]]] {
    (gc_mode, enf_mods, enf_grand) = _project_gc_settings();
    options = CompileOptions(
        aot_mode=True,
        default_codespace='native',
        na_gc_mode=gc_mode,
        memory_enforce=enf_mods,
        memory_exempt=enf_grand,
        native_target="wasm32-unknown-unknown"
    );
    with tempfile.TemporaryDirectory(prefix="jac-wasm-") as temporary {
        output = os.path.join(temporary, "module.wasm");
        request = native_build_request_for([file_path], "wasm", options, output);
        request.assert_no_rc = gc_mode == "none";
        result = kernel_native_build(program, request);
        if not result.ok() {
            raise RuntimeError(diagnostic_text(result.errors[0]));
        }
        if not result.root_native {
            raise RuntimeError(
                f"native lowering produced no IR for '{file_path}': the module did not compile to the native codespace"
            );
        }
        if result.rc_symbols or result.rc_probes {
            raise RuntimeError(
                f"'{os.path.basename(file_path)}' compiled under [memory] profile ="
                    + " \"nogc\" but its IR still carries RC machinery ("
                    + ", ".join(result.rc_symbols + result.rc_probes)
                    + ")"
            );
        }
        if not result.linked {
            raise RuntimeError(f"no wasm module was linked for '{file_path}'");
        }
        with open(output, "rb") as handle {
            data = handle.read();
        }
    }
    return (data, [[unit.path, unit.digest] for unit in result.units]);
}

impl route_exports(program: JacProgram, path: str) -> tuple[str | None, str | None] {
    artifact = kernel_client_artifact(
        program, os.path.realpath(path), CompileOptions(skip_native_engine=True)
    );
    if artifact is None {
        return (None, None);
    }
    return (artifact.manifest.page_export, artifact.manifest.layout_export);
}
