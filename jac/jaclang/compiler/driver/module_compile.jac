import os;
import from jaclang.compiler.driver.pipeline_types {
    CompilationProduct,
    ProductRequest
}
import from jaclang.compiler.driver.pipeline { product_passes, unavailable }
import from jaclang.compiler.frontend.host { active_host }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.session_compile { SessionHooks }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.driver.module_analysis {
    ModuleAnalysis,
    PlanStep,
    analyze_module,
    run_plan
}

def session_of(task: ModuleAnalysis) -> SessionHooks {
    session = task.session;
    if session is None {
        raise RuntimeError(f"codegen steps for {task.path} ran without a session");
    }
    return session;
}

def admits_native_checks(task: ModuleAnalysis) -> bool {
    import from jaclang.compiler.placement.placement_facts { variant_selected }
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

def run_native_checks(task: ModuleAnalysis) {
    lowered = task.require(CompilationProduct.NATIVE_IR);
    if lowered and task.options.native_required_for(task.path) {
        session_of(task).assemble_native(task.program, task.module, True);
    }
}

def admits_client_dependencies(task: ModuleAnalysis) -> bool {
    options = task.options;
    return not (
        task.parse_failed or task.blocked or options.symtab_ir_only or options.no_cgen
    );
}

def run_client_dependencies(task: ModuleAnalysis) {
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

def admits_interface(task: ModuleAnalysis) -> bool {
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

def run_interface(task: ModuleAnalysis) {
    task.require(CompilationProduct.INTERFACE);
}

def binds_torch_import(module: uni.Module) -> bool {
    for mp in module.get_all_sub_nodes(uni.ModulePath) {
        if mp.level != 0 {
            continue;
        }
        p = mp.dot_path_str;
        if (p == 'torch') or p.startswith('torch.') {
            return True;
        }
    }
    return False;
}

def graphmend_wanted(task: ModuleAnalysis) -> bool {
    options = task.options;
    if options.graphmend is not None and options.graphmend {
        return binds_torch_import(task.module);
    }
    return False;
}

def admits_codegen(task: ModuleAnalysis) -> bool {
    options = task.options;
    return not (
        task.parse_failed or task.blocked or options.no_cgen or options.symtab_ir_only
    );
}

def run_codegen(task: ModuleAnalysis) {
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
    graphmend = graphmend_wanted(task);
    if graphmend and active_host().in_kernel() {
        return;
    }
    task.require(CompilationProduct.CODEGEN, ProductRequest(native=needs_native));
    if module.gen.has_native_ir() {
        session_of(task).assemble_native(program, module, False);
    }
    if graphmend {
        task.require(CompilationProduct.GRAPHMEND);
    }
    task.require(CompilationProduct.PY_IR);
    task.require(CompilationProduct.FROZEN);
    session_of(task).assemble_python(program, module);
    if module.decided_codespace == 'native' {
        scrubbed = scrub_native_artifacts_on_error(program, module);
        if options.aot_mode and not scrubbed {
            report_missing_native_ir(program, module);
        }
    }
}

def client_import_paths(module: uni.Module) -> list[str] {
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

def scrub_native_artifacts_on_error(program: JacProgram, mod: uni.Module) -> bool {
    mod_path = mod.loc.mod_path if mod?.loc else '';
    if not mod_path or not program.module_scoped_errors(mod_path) {
        return False;
    }
    gen = mod.gen;
    gen.py_bytecode = None;
    gen.drop_native_ir();
    gen.native_engine = None;
    gen.native_bitcode = None;
    gen.native_object = None;
    gen.native_iface = None;
    gen.native_layout = None;
    return True;
}

def report_missing_native_ir(program: JacProgram, mod: uni.Module) -> None {
    import from jaclang.compiler.driver.pass_driver { deliver_alerts }
    import from jaclang.compiler.frontend.diagnostics { E5092 }
    import from jaclang.compiler.passes.context { Alert }
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

glob CODEGEN_PLAN: tuple[PlanStep, ...] = (
         PlanStep(
             name="NATIVE_CHECKS", admit=admits_native_checks, run=run_native_checks
         ),
         PlanStep(
             name="CLIENT_DEPENDENCIES",
             admit=admits_client_dependencies,
             run=run_client_dependencies
         ),
         PlanStep(name="INTERFACE", admit=admits_interface, run=run_interface),
         PlanStep(name="CODEGEN", admit=admits_codegen, run=run_codegen)
     );

def analyze_for_compile(
    program: JacProgram, path: str, options: CompileOptions, source: str | None
) -> ModuleAnalysis {
    analysis = active_host().native_analyze(program, path, options, source);
    if analysis is None {
        analysis = analyze_module(program, path, options, source);
    }
    return analysis;
}

def compile_task(
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

def compile_module(
    session: SessionHooks,
    program: JacProgram,
    path: str,
    options: CompileOptions,
    source: str | None = None
) -> uni.Module {
    return compile_task(session, program, path, options, source).module;
}
