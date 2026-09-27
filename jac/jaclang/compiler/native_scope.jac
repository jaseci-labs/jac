import os;

obj NativeScopeEntry {
    has module: str;
}

glob NATIVE_SCOPE: tuple[NativeScopeEntry, ...] = (
         NativeScopeEntry(module="jaclang.compiler.frontend.constant"),
         NativeScopeEntry(module="jaclang.compiler.frontend.srcloc"),
         NativeScopeEntry(module="jaclang.compiler.frontend.roles"),
         NativeScopeEntry(module="jaclang.compiler.frontend.relations"),
         NativeScopeEntry(module="jaclang.compiler.frontend.unitree"),
         NativeScopeEntry(module="jaclang.compiler.frontend.parser.tokens"),
         NativeScopeEntry(module="jaclang.compiler.frontend.parser.lexer"),
         NativeScopeEntry(module="jaclang.compiler.frontend.parser.parser"),
         NativeScopeEntry(module="jaclang.compiler.jc_materialize"),
         NativeScopeEntry(module="jaclang.compiler.jc_unit"),
         NativeScopeEntry(module="jaclang.compiler.frontend.diagnostics"),
         NativeScopeEntry(module="jaclang.compiler.passes.context"),
         NativeScopeEntry(module="jaclang.compiler.passes.ast_validation_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.sym_tab_build_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.annex_weave"),
         NativeScopeEntry(module="jaclang.compiler.passes.early_passes"),
         NativeScopeEntry(module="jaclang.compiler.passes.graph_lowering_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.decl_impl_match_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.semantic_analysis_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.sem_def_match_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.cfg_build_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.jsx_intrinsic_guard_pass"),
         NativeScopeEntry(module="jaclang.compiler.expr_keys"),
         NativeScopeEntry(module="jaclang.project.mobui_scope"),
         NativeScopeEntry(module="jaclang.project.source"),
         NativeScopeEntry(module="jaclang.client.targets.react_native.html_tag_map"),
         NativeScopeEntry(module="jaclang.compiler.c_interop"),
         NativeScopeEntry(module="jaclang.compiler.driver.boundary_classify"),
         NativeScopeEntry(module="jaclang.compiler.driver.compilation_context"),
         NativeScopeEntry(module="jaclang.compiler.driver.compile_options"),
         NativeScopeEntry(module="jaclang.compiler.driver.context_passes"),
         NativeScopeEntry(module="jaclang.compiler.frontend.kernel_analyze"),
         NativeScopeEntry(module="jaclang.compiler.driver.module_analysis"),
         NativeScopeEntry(module="jaclang.compiler.driver.pass_driver"),
         NativeScopeEntry(module="jaclang.compiler.driver.pipeline"),
         NativeScopeEntry(module="jaclang.compiler.driver.pipeline_types"),
         NativeScopeEntry(module="jaclang.compiler.driver.program"),
         NativeScopeEntry(module="jaclang.compiler.driver.progstate"),
         NativeScopeEntry(module="jaclang.compiler.driver.session_compile"),
         NativeScopeEntry(module="jaclang.compiler.driver.wiring"),
         NativeScopeEntry(module="jaclang.compiler.erased_imports"),
         NativeScopeEntry(module="jaclang.compiler.field_semantics"),
         NativeScopeEntry(module="jaclang.compiler.frontend.codeinfo"),
         NativeScopeEntry(module="jaclang.compiler.frontend.const_fold"),
         NativeScopeEntry(module="jaclang.compiler.frontend.diagnostic_utils"),
         NativeScopeEntry(module="jaclang.compiler.frontend.helpers"),
         NativeScopeEntry(module="jaclang.compiler.frontend.host"),
         NativeScopeEntry(module="jaclang.compiler.frontend.kernel_host"),
         NativeScopeEntry(module="jaclang.compiler.frontend.kernel_inputs"),
         NativeScopeEntry(module="jaclang.compiler.frontend.module_facts"),
         NativeScopeEntry(module="jaclang.compiler.frontend.parser.frontend"),
         NativeScopeEntry(module="jaclang.compiler.frontend.source_layout"),
         NativeScopeEntry(module="jaclang.compiler.frontend.unparse"),
         NativeScopeEntry(module="jaclang.compiler.intrinsic_registry"),
         NativeScopeEntry(module="jaclang.compiler.kernel_target"),
         NativeScopeEntry(module="jaclang.compiler.native_scope"),
         NativeScopeEntry(module="jaclang.compiler.passes.access_check_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.boundary_analysis_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.capability_check_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.comptime_resolve_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.dataflow"),
         NativeScopeEntry(module="jaclang.compiler.passes.endpoint_effect_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.execution"),
         NativeScopeEntry(module="jaclang.compiler.passes.import_wiring_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.layout_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.mtir_gen_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.ownership_check_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.rc_facts_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.region_infer_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.scope_walk"),
         NativeScopeEntry(module="jaclang.compiler.passes.static_analysis_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.type_checker_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.variant_agreement_pass"),
         NativeScopeEntry(module="jaclang.compiler.passes.wasm_contract"),
         NativeScopeEntry(module="jaclang.compiler.placement.placement"),
         NativeScopeEntry(module="jaclang.compiler.placement.placement_facts"),
         NativeScopeEntry(module="jaclang.compiler.placement.placement_pins"),
         NativeScopeEntry(module="jaclang.compiler.placement.placement_solver"),
         NativeScopeEntry(module="jaclang.compiler.placement.placement_work"),
         NativeScopeEntry(module="jaclang.compiler.symbol_utils"),
         NativeScopeEntry(module="jaclang.compiler.tools.doc_ir"),
         NativeScopeEntry(module="jaclang.compiler.tools.jac_auto_lint_pass"),
         NativeScopeEntry(module="jaclang.compiler.tools.reactive_use_walk"),
         NativeScopeEntry(module="jaclang.compiler.type_registry"),
         NativeScopeEntry(module="jaclang.compiler.types.builtin_extensions"),
         NativeScopeEntry(module="jaclang.compiler.types.ct_builtins"),
         NativeScopeEntry(module="jaclang.compiler.types.ct_eval"),
         NativeScopeEntry(module="jaclang.compiler.types.ct_format"),
         NativeScopeEntry(module="jaclang.compiler.types.ct_int"),
         NativeScopeEntry(module="jaclang.compiler.types.ct_ops"),
         NativeScopeEntry(module="jaclang.compiler.types.ct_value"),
         NativeScopeEntry(module="jaclang.compiler.types.enum_utils"),
         NativeScopeEntry(module="jaclang.compiler.types.fixed_width"),
         NativeScopeEntry(module="jaclang.compiler.types.operations"),
         NativeScopeEntry(module="jaclang.compiler.types.ownership"),
         NativeScopeEntry(module="jaclang.compiler.types.properties"),
         NativeScopeEntry(module="jaclang.compiler.types.stubcat.format"),
         NativeScopeEntry(module="jaclang.compiler.types.stubcat.modiface"),
         NativeScopeEntry(module="jaclang.compiler.types.stubcat.reader"),
         NativeScopeEntry(module="jaclang.compiler.types.stubcat.resolver"),
         NativeScopeEntry(module="jaclang.compiler.types.ts_decl_parser"),
         NativeScopeEntry(module="jaclang.compiler.types.type_evaluator"),
         NativeScopeEntry(module="jaclang.compiler.types.type_utils"),
         NativeScopeEntry(module="jaclang.compiler.types.types"),
         NativeScopeEntry(module="jaclang.project.app_kinds"),
         NativeScopeEntry(module="jaclang.project.workspace_model"),
         NativeScopeEntry(module="jaclang.runtime.portability")
     ),
     KERNEL_ROOT_MODULE: str = "jaclang.compiler.jc_unit",
     KERNEL_ABI_CONTRACT_REL: tuple[str, ...] = (
         "runtime/osp_kernel.jac",
         "runtime/osp_graph.jac",
         "runtime/region_native.jac",
         "compiler/backends/common/fmt_kernel.jac",
         "runtime/osp_tag.jac",
         "compiler/backends/native/region_abi.jac",
         "compiler/native_compiler.jac"
     ),
     _SCOPE_SUFFIX_CACHE: list[str] = [],
     _SCOPE_SUFFIX_GEN: list[int] = [-1];

def package_host_edge(mod_path: str) -> bool {
    import from jaclang.compiler.frontend.codeinfo { native_unit_identity }
    identity = native_unit_identity(mod_path);
    if not identity.startswith("jaclang/") or identity.startswith("jaclang/runtime/") {
        return False;
    }
    import from jaclang.compiler.placement.placement_facts {
        native_lowered,
        native_unit
    }
    return not native_lowered(mod_path)
        and not native_unit(mod_path, native_unit_compile=True);
}

def scope_allows_inferred_path(mod_path: str) -> bool {
    import from jaclang.compiler.frontend.codeinfo { native_unit_compile_active }
    return not native_unit_compile_active() or not package_host_edge(mod_path);
}

def scope_modules -> list[str] {
    import from jaclang.compiler.kernel_target { active_kernel_target }
    spec = active_kernel_target();
    if spec is not None {
        return list(spec.scope_modules);
    }
    return [e.module for e in NATIVE_SCOPE];
}

def kernel_root_module -> str {
    import from jaclang.compiler.kernel_target { active_kernel_target }
    spec = active_kernel_target();
    return spec.root_module if spec is not None else KERNEL_ROOT_MODULE;
}

def native_scope_path_suffixes -> list[str] {
    import from jaclang.compiler.kernel_target { kernel_target_generation }
    gen = kernel_target_generation();
    if _SCOPE_SUFFIX_GEN[0] != gen {
        _SCOPE_SUFFIX_CACHE.clear();
        for module in scope_modules() {
            rel = module.replace("jaclang.", "", 1).replace(".", "/") + ".jac";
            _SCOPE_SUFFIX_CACHE.append("jaclang/" + rel);
        }
        _SCOPE_SUFFIX_GEN[0] = gen;
    }
    return _SCOPE_SUFFIX_CACHE;
}

def in_native_scope_path(mod_path: str) -> bool {
    if not mod_path {
        return False;
    }
    p = mod_path.replace(os.sep, "/");
    for suf in native_scope_path_suffixes() {
        if p.endswith(suf) {
            return True;
        }
    }
    return False;
}

def scope_module_path(module: str) -> str {
    import from jaclang.compiler.kernel_target { target_pkg_root }
    rel = module.replace("jaclang.", "", 1).replace(".", os.sep) + ".jac";
    return os.path.join(target_pkg_root(), rel);
}

def native_scope_paths -> list[str] {
    return [scope_module_path(m) for m in scope_modules()];
}

def kernel_root_path -> str {
    return scope_module_path(kernel_root_module());
}
