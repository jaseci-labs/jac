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
