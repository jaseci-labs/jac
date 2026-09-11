import type from jaclang.compiler.session.services { AnalysisServices }
import from jaclang.compiler.pipeline.keys { SPACES }
import from jaclang.compiler.pipeline.products { require_product }
import from jaclang.compiler.analysis.placement.products {
    NativeEligibility,
    PlacementSpaces
}
import type from jaclang.compiler.ir.schema { Expr, Symbol }
import type from jaclang.compiler.ir.types.nodes { TypeBase }
import os;
import type from jaclang.compiler.session.session { JacProgram }
import type from jaclang.compiler.session.options { CompileOptions }
import type from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.pipeline.contracts { CompilationProduct }

def build_wasm(program: JacProgram, path: str, exports: list[str]) -> bytes {
    import from jaclang.compiler.pipeline.request { wasm_artifact }
    return wasm_artifact(program, path, exports);
}


def route_exports(program: JacProgram, path: str) -> tuple[str | None, str | None] {
    artifact = program.get_client_artifact(os.path.realpath(path));
    if artifact is None {
        return (None, None);
    }
    return (artifact.manifest.page_export, artifact.manifest.layout_export);
}


def compile_application(
    program: JacProgram, entry_path: str, options: CompileOptions
) -> Module {
    import copy;
    import from pathlib { Path }
    import from jaclang.compiler.session.context { bind_options, context_program }
    import from jaclang.compiler.backends.py.artifact_imports { package_sources }
    import from jaclang.jac0core.ext_registry { is_annex }
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
    entry_module: Module | None = None;
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
        module = program.compile(path, options=bound);
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
        require_product(context, module, CompilationProduct.IMPORTS);
        dependencies.update(
            edge.target
            for edge in context.deps.imports.get(path, [])
            if edge.jac and edge.target.endswith('.jac')
        );
        pending.extend(
            (context, dependency)
            for dependency in sorted(dependencies)
            if dependency.startswith(project_root + os.sep)
                and os.path.isfile(dependency)
                and not any(
                    part in ('.jac', 'node_modules', 'venv')
                    for part in os.path.relpath(dependency, project_root).split(os.sep)
                )
        );
    }
    if entry_module is None {
        raise RuntimeError(
            f'Application compilation cancelled before parsing {entry_path}'
        );
    }
    return entry_module;
}


def native_dependency_facts(
    program: AnalysisServices, path: str, hold_exempt: bool = False
) -> NativeEligibility {
    import from jaclang.compiler.frontend.parser.frontend { annex_sources }
    import from jaclang.compiler.frontend.source_io { read_file_with_encoding }
    import from jaclang.compiler.analysis.placement.pins { _is_demoted_native }
    import from jaclang.compiler.pipeline.executor { execute_query }
    import from jaclang.compiler.pipeline.schedule { native_eligibility_query }
    import from jaclang.compiler.pipeline.keys { NATIVE_ELIGIBILITY }
    path = os.path.realpath(path);
    if _is_demoted_native(path) {
        return NativeEligibility('previously-demoted');
    }
    try {
        unit = program.source_store.unit(
            read_file_with_encoding(path), path, annex_sources(path)
        );
    } except OSError {
        return NativeEligibility('unreadable source');
    }
    if unit.failed {
        return NativeEligibility('parse error');
    }
    identity = repr((unit.revision, hold_exempt, program.options.analysis_identity()));
    cached = program.analysis.lookup(path, NATIVE_ELIGIBILITY, identity);
    if cached is None {
        cached = execute_query(
            program, unit.syntax, native_eligibility_query(), hold_exempt
        );
        program.analysis.publish(path, NATIVE_ELIGIBILITY, cached, identity);
    }
    return cached;
}

def native_closure_eligible(
    program: AnalysisServices,
    module: Module,
    dependencies: list[str],
    hold_exempt: bool = False
) -> bool {
    import from jaclang.compiler.pipeline.executor { execute_query }
    import from jaclang.compiler.pipeline.schedule { native_closure_query }
    import from jaclang.compiler.pipeline.contracts { NativeClosureRequest }
    return execute_query(
        program,
        module,
        native_closure_query(),
        NativeClosureRequest(dependencies, hold_exempt)
    );
}

def native_path_eligible(path: str, program: AnalysisServices | None = None) -> bool {
    import from jaclang.compiler.session.session { JacProgram }
    import from jaclang.compiler.ir.schema { Module }
    import from jaclang.compiler.analysis.placement.evidence {
        PLACEMENT_HOLD_EXEMPT_ROOTS
    }
    import from jaclang.compiler.session.context { active_program }
    program = program or active_program() or JacProgram();
    path = os.path.realpath(path);
    exempt = any(
        marker in path.replace(os.sep, '/') for marker in PLACEMENT_HOLD_EXEMPT_ROOTS
    );
    facts = native_dependency_facts(program, path, exempt);
    if facts.reason {
        return False;
    }
    module = Module.make_stub();
    module.source.file_path = path;
    return native_closure_eligible(program, module, facts.dependencies, exempt);
}


def query_type(program: AnalysisServices, query: Expr | Symbol) -> TypeBase | None {
    import from jaclang.compiler.pipeline.executor { execute_query }
    import from jaclang.compiler.pipeline.schedule { type_query }
    import from jaclang.compiler.ir.schema { Module }
    import from jaclang.compiler.ir.schema { Symbol }
    declaration = query.decl if isinstance(query, Symbol) else query;
    module = declaration.find_parent_of_type(Module);
    if module is None {
        module = Module.make_stub(inject_name='type_query');
        query.attach_permit(program.analysis.mutations);
    }
    context = program.module_context(module);
    return execute_query(context, module, type_query(), query);
}


def module_spaces(program: AnalysisServices, module: Module) -> PlacementSpaces {
    program = program.module_context(module);
    require_product(program, module, CompilationProduct.SPACES);
    return program.analysis.result(module.loc.mod_path, SPACES);
}


def placement_report(program: AnalysisServices) -> dict {
    import from jaclang.compiler.pipeline.executor { execute_query }
    import from jaclang.compiler.pipeline.schedule { placement_report_query }
    return execute_query(program, program.mod.main, placement_report_query(), None);
}


def invalidate_native_importers(program: AnalysisServices, path: str) {
    import from jaclang.compiler.pipeline.executor { execute_query }
    import from jaclang.compiler.pipeline.schedule { native_demotion_query }
    execute_query(program, program.mod.main, native_demotion_query(), path);
}

import type from jaclang.compiler.analysis.interfaces.facts {
    CatalogRequest,
    CatalogProduct
}

def prepare_catalog(
    program: AnalysisServices, request: CatalogRequest
) -> CatalogProduct {
    import from jaclang.compiler.pipeline.executor { execute_query }
    import from jaclang.compiler.pipeline.schedule { catalog_query }
    import from jaclang.compiler.ir.schema { Module }
    return execute_query(program, Module.make_stub(), catalog_query(), request);
}

import type from jaclang.compiler.backends.es.link_facts {
    ClientLinkRequest,
    ClientGraph
}

def link_client_graph(
    program: AnalysisServices, request: ClientLinkRequest
) -> ClientGraph {
    import from jaclang.compiler.pipeline.executor { execute_query }
    import from jaclang.compiler.pipeline.schedule { client_link_query }
    import from jaclang.compiler.ir.schema { Module }
    return execute_query(program, Module.make_stub(), client_link_query(), request);
}
