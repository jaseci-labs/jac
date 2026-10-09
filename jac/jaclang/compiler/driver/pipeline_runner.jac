import os;
import from jaclang.compiler.passes.context { PassSchedule }
import from jaclang.compiler.driver.pipeline_types { UtilityProduct }
import type from jaclang.compiler.driver.compile_options { CancelToken }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.driver.pipeline { validate_schedule }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;

def wasm_ir(program: JacProgram, file_path: str) -> tuple[str, set[str]] {
    import from jaclang.compiler.backends.native.wasm_build {
        _project_gc_settings,
        _assert_ir_rc_free,
        app_declared_imports
    }
    import from jaclang.compiler.driver.compile_options {
        CompileOptions,
        push_native_target,
        pop_native_target
    }
    import from jaclang.compiler.driver.na_coverage {
        na_coverage_begin,
        na_coverage_end
    }
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
    } finally {
        pop_native_target(prev);
    }
    if gc_mode == "none" {
        _assert_ir_rc_free(app_ir_str, file_path);
    }
    return (llvm_ir_str, app_imports);
}

def wasm_artifact(program: JacProgram, file_path: str, exports: list[str]) -> bytes {
    import from jaclang.compiler.backends.native.wasm_build { emit_wasm_from_ir }
    (llvm_ir, app_imports) = wasm_ir(program, file_path);
    return emit_wasm_from_ir(llvm_ir, exports, app_imports=app_imports);
}


def native_application(
    program: JacProgram,
    file_path: str,
    target: str = '',
    memory: str = '',
    debug: bool = False,
    no_ir_cache: bool = False
) -> tuple[uni.Module, CompileOptions] {
    import from jaclang.compiler.driver.compile_options {
        CompileOptions,
        push_native_target,
        pop_native_target
    }
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


def build_wasm(program: JacProgram, path: str, exports: list[str]) -> bytes {
    return wasm_artifact(program, path, exports);
}

def route_exports(program: JacProgram, path: str) -> tuple[str | None, str | None] {
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

def compile_application(
    program: JacProgram, entry_path: str, options: CompileOptions
) -> uni.Module {
    import copy;
    import from pathlib { Path }
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program
    }
    import from jaclang.compiler.frontend.unitree { Import, ModulePath }
    import from jaclang.compiler.backends.py.artifact_imports { package_sources }
    import from jaclang.jac0core.ext_registry { is_annex }
    import from jaclang.runtime.prepared { holds_application_code }
    import from jaclang.project.app_kinds { kind_has_client }
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


def get_format_sched(auto_lint: bool = False) -> PassSchedule {
    import from jaclang.compiler.tools.comment_attach_pass { CommentAttachPass }
    import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacAutoLintPass }
    import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
    if auto_lint {
        return validate_schedule(
            [CommentAttachPass, JacAutoLintPass, DocIRGenPass, JacFormatPass],
            origin='format schedule'
        );
    }
    return validate_schedule(
        [CommentAttachPass, DocIRGenPass, JacFormatPass], origin='format schedule'
    );
}

def get_lint_sched -> PassSchedule {
    import from jaclang.compiler.tools.jac_auto_lint_pass { JacLintCheckPass }
    return validate_schedule([JacLintCheckPass], origin='lint schedule');
}

def run_utility(
    product: UtilityProduct,
    ir: any,
    program: JacProgram,
    cancel_token: (CancelToken | None) = None
) -> any {
    import from jaclang.compiler.driver.pass_driver { run_pass }
    step: type;
    if product == UtilityProduct.PYTHON_AST {
        import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
        step = PyastBuildPass;
    } elif product == UtilityProduct.PYTHON_SYMBOLS {
        step = SymTabBuildPass;
    } elif product == UtilityProduct.GRAMMAR {
        import from jaclang.compiler.tools.grammar_extract_pass { GrammarExtractPass }
        step = GrammarExtractPass;
    } elif product == UtilityProduct.CFG_DOT {
        import from jaclang.compiler.tools.cfg_dot { CoalesceBBPass }
        step = CoalesceBBPass;
    } elif product == UtilityProduct.NORMALIZE {
        import from jaclang.compiler.tools.normalize_pass { NormalizePass }
        step = NormalizePass;
    } elif product == UtilityProduct.UNPARSE {
        import from jaclang.compiler.tools.unparse_pass { UnparsePass }
        step = UnparsePass;
    } elif product == UtilityProduct.DOC {
        import from jaclang.compiler.tools.doc_ir_gen_pass { DocIRGenPass }
        step = DocIRGenPass;
    } elif product == UtilityProduct.FORMAT {
        import from jaclang.compiler.tools.jac_formatter_pass { JacFormatPass }
        step = JacFormatPass;
    } else {
        raise ValueError(f"Unknown utility product: {product}");
    }
    return run_pass(step, ir, program, cancel_token=cancel_token);
}
