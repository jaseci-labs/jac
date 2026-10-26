impl session_of(task: ModuleAnalysis) -> SessionHooks {
    session = task.session;
    if session is None {
        raise RuntimeError(f"codegen steps for {task.path} ran without a session");
    }
    return session;
}

impl admits_native_checks(task: ModuleAnalysis) -> bool {
    options = task.options;
    return variant_selected(task.path) is not False
        and options.no_cgen
        and (options.native_parity or options.native_required_for(task.path))
        and not options.symtab_ir_only
        and not task.parse_failed
        and not task.blocked
        and task.ready(CompilationProduct.ANALYSIS)
        and (task.native or ModuleFacts.has_native_context_stmts(task.module))
        and not unavailable(CompilationProduct.NATIVE_LOWER);
}

impl run_native_checks(task: ModuleAnalysis) {
    lowered = task.require(CompilationProduct.NATIVE_IR);
    if lowered and task.options.native_required_for(task.path) {
        session_of(task).assemble_native(task.program, task.module, True);
    }
}

impl admits_client_dependencies(task: ModuleAnalysis) -> bool {
    options = task.options;
    return not (
        task.parse_failed or task.blocked or options.symtab_ir_only or options.no_cgen
    );
}

impl run_client_dependencies(task: ModuleAnalysis) {
    options = task.options;
    program = task.program;
    host = active_host();
    seen: set[str] = set();
    worklist: list[uni.Module | None] = [task.module];
    paths: list[str] = [];
    dep_options = CompileOptions(no_cgen=True, cancel_token=options.cancel_token);
    while worklist or paths {
        if worklist {
            current = worklist.pop();
            if current is not None {
                paths.extend(client_import_paths(current));
            }
            continue;
        }
        dep_path = paths.pop();
        if dep_path in seen {
            continue;
        }
        seen.add(dep_path);
        dep = program.find_module(dep_path);
        has_facts = dep is not None
            and dep.gen
            and dep.gen.interop_manifest
            and bool(dep.gen.interop_manifest.bindings);
        if not has_facts and not program.has_failed_parse(dep_path) {
            served = host.client_boundary_facts(program, dep_path);
            if served is not None {
                paths.extend(os.path.abspath(edge) for edge in served);
                continue;
            }
            dep = session_of(task).compile(dep_path, program, None, dep_options);
        }
        worklist.append(dep);
    }
    program.options = options;
}

impl admits_interface(task: ModuleAnalysis) -> bool {
    options = task.options;
    closure = session_of(task).closure_options() or options;
    if task.parse_failed or task.blocked or task.source is not None {
        return False;
    }
    return (options.no_cgen and not options.symtab_ir_only)
        or (
            closure.no_cgen
            and not closure.symtab_ir_only
            and not (
                task.program.internal and active_host().in_compiler_tree(task.path)
            )
        );
}

impl run_interface(task: ModuleAnalysis) {
    task.require(CompilationProduct.INTERFACE);
}

impl admits_codegen(task: ModuleAnalysis) -> bool {
    options = task.options;
    return not (
        task.parse_failed or task.blocked or options.no_cgen or options.symtab_ir_only
    );
}

impl run_codegen(task: ModuleAnalysis) {
    options = task.options;
    program = task.program;
    module = task.module;
    program.options = options;
    if not task.has_full_ir() {
        task.require(CompilationProduct.PY_IR);
        session_of(task).assemble_python(program, module);
        return;
    }
    needs_native = task.native or ModuleFacts.has_native_context_stmts(module);
    if needs_native
        and not task.ready(CompilationProduct.ANALYSIS)
        and not task.require(CompilationProduct.ANALYSIS) {
        task.blocked = True;
        return;
    }
    task.require(CompilationProduct.CODEGEN, ProductRequest(native=needs_native));
    if module.gen.has_native_ir() {
        session_of(task).assemble_native(program, module, False);
    }
    task.require(CompilationProduct.PY_IR);
    task.require(CompilationProduct.FROZEN);
    session_of(task).assemble_python(program, module);
    dropped = drop_products_on_error(program, module);
    if module.decided_codespace == 'native' and options.aot_mode and not dropped {
        report_missing_native_ir(program, module);
    }
}

impl client_import_paths(module: uni.Module) -> list[str] {
    out: list[str] = [];
    for imp in module.get_all_sub_nodes(uni.Import) {
        if not imp.from_loc or imp.is_virtual_jac {
            continue;
        }
        try {
            source = imp.from_loc.resolve_relative_path();
        } except Exception {
            continue;
        }
        if isinstance(source, str)
            and imp.code_context == CodeContext.CLIENT
            and source.endswith('.jac') {
            out.append(os.path.abspath(source));
        }
    }
    return out;
}

impl drop_products_on_error(program: JacProgram, mod: uni.Module) -> bool {
    """A module that may not run keeps nothing runnable: not the bytecode the
    host assembles, not the JCIR the kernel hands the host, not native code.
    A native module may not run past a codegen error; no module may run past
    a blocking one (a backend crash, E9003).""";
    mod_path = mod.loc.mod_path if mod?.loc else '';
    if not mod_path {
        return False;
    }
    blocked = program.count_module_blocking_errors(os.path.normpath(mod_path)) > 0;
    if not blocked
        and (
            mod.decided_codespace != 'native'
            or not program.module_scoped_errors(mod_path)
        ) {
        return False;
    }
    gen = mod.gen;
    gen.jcir = None;
    gen.py_bytecode = None;
    gen.drop_native_ir();
    gen.native_engine = None;
    gen.native_bitcode = None;
    gen.native_object = None;
    gen.native_iface = None;
    gen.native_layout = None;
    return True;
}

impl report_missing_native_ir(program: JacProgram, mod: uni.Module) -> None {
    if mod?.gen is None or mod.gen.has_native_ir() {
        return;
    }
    mod_path = mod.loc.mod_path if mod?.loc else '';
    if not mod_path or program.count_module_errors(mod_path) > 0 {
        return;
    }
    reason = unavailable(CompilationProduct.NATIVE_LOWER);
    if not reason {
        (available, why) = active_host().native_pipeline_available();
        if not available {
            reason = why;
        }
    }
    if reason {
        detail = f"the native codegen schedule could not be built ({reason})";
    } elif not ModuleFacts.has_native_context_stmts(mod) {
        detail = "the module declares no native code for the backend to lower";
    } else {
        detail = (
            "the native codegen passes ran but emitted neither IR nor a "
            "diagnostic; this is a compiler bug -- please report it"
        );
    }
    from_pass: type = JcirGenPass
        if reason
        else product_passes(CompilationProduct.NATIVE_LOWER)[-1];
    deliver_alerts(
        [
            Alert(
                msg=E5092.format_message(
                    kind='module', name=os.path.basename(mod_path)
                ),
                loc=mod.loc.span(),
                from_pass=from_pass,
                code=E5092,
                help_text=detail
            )
        ],
        [],
        program
    );
}

impl analyze_for_compile(
    program: JacProgram, path: str, options: CompileOptions, source: str | None
) -> ModuleAnalysis {
    analysis = active_host().native_analyze(program, path, options, source);
    if analysis is None {
        analysis = analyze_module(program, path, options, source);
    }
    return analysis;
}

impl compile_task(
    session: SessionHooks,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: str | None = None
) -> ModuleAnalysis {
    analysis = analyze_for_compile(program, path, options, source);
    analysis.session = session;
    run_plan(analysis, CODEGEN_PLAN);
    return analysis;
}

impl compile_module(
    session: SessionHooks,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: str | None = None
) -> uni.Module {
    return compile_task(session, program, path, options, source).module;
}
