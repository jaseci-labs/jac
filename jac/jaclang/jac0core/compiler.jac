import ast as py_ast;
import atexit;
import marshal;
import os;
import sys;
import types;
import from threading { Event }
import from contextvars { ContextVar }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.jir {
    SEC_BYTECODE,
    SEC_MTIR,
    SEC_LLVM_IR,
    SEC_INTEROP,
    SEC_NATIVE_OBJ,
    SEC_MODKEY,
    FLAG_PRECOMPILED,
    get_module_cache_path,
    is_module_cache_valid,
    jir_matches_source,
    compute_module_key,
    cache_mode,
    read_bytecode_only,
    read_sections,
    SECTIONS_MAGIC,
    HEADER_SIZE
}
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.helpers { read_file_with_encoding }
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.jac0core.passes {
    ASTValidationPass,
    BoundaryAnalysisPass,
    CodespacePullPass,
    DeclImplMatchPass,
    JacAnnexPass,
    PyastGenPass,
    PyBytecodeGenPass,
    SemanticAnalysisPass,
    SymTabBuildPass,
    Transform
}
import from jaclang.jac0core.program { JacProgram }

def get_symtab_ir_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    return [ASTValidationPass, SymTabBuildPass, DeclImplMatchPass, CodespacePullPass];
}

glob _ir_sched_loading = ContextVar('jac_ir_sched_loading', default=False),
     _codegen_sched_loading = ContextVar('jac_codegen_sched_loading', default=False),
     _typecheck_sched_loading = ContextVar(
         'jac_typecheck_sched_loading', default=False
     );

def expand_with_requirements(
    passes: list[type[Transform[uni.Module, uni.Module]]],
    providers: dict[str, type[Transform[uni.Module, uni.Module]]]
) -> list[type[Transform[uni.Module, uni.Module]]] {
    out: list[type[Transform[uni.Module, uni.Module]]] = [];
    for p in passes {
        for tag in (getattr(p, 'REQUIRES', ()) or ()) {
            prov = providers.get(tag);
            if prov is not None and prov not in out and prov not in passes {
                out.append(prov);
            }
        }
        if p not in out {
            out.append(p);
        }
    }
    return out;
}

def get_boundary_analysis_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    return [BoundaryAnalysisPass];
}

def get_bootstrap_ir_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    return [
        ASTValidationPass,
        SymTabBuildPass,
        DeclImplMatchPass,
        SemanticAnalysisPass
    ];
}

def get_ir_gen_sched(
    is_internal: bool = False, gen_mtir: bool = True
) -> list[type[Transform[uni.Module, uni.Module]]] {
    if _ir_sched_loading.get() {
        return get_bootstrap_ir_sched();
    }
    _tok = _ir_sched_loading.set(True);
    try {
        import from jaclang.compiler.passes.main.cfg_build_pass { CFGBuildPass }
        import from jaclang.compiler.passes.main.sem_def_match_pass { SemDefMatchPass }
        import from jaclang.compiler.passes.main.jsx_intrinsic_guard_pass {
            JsxIntrinsicGuardPass
        }

        import jaclang.compiler.symbol_utils;
        import jaclang.compiler.passes.main.layout_pass;
        import jaclang.compiler.type_registry;

        passes: list[type[Transform[uni.Module, uni.Module]]] = [
            ASTValidationPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass
        ];
        if gen_mtir {
            import from jaclang.compiler.passes.main.mtir_gen_pass { MTIRGenPass }
            passes.append(MTIRGenPass);
        }
        passes.append(JsxIntrinsicGuardPass);
        passes.append(CodespacePullPass);
        return passes;
    } except ImportError {
        if is_internal {
            return get_bootstrap_ir_sched();
        }
        raise;
    } finally {
        _ir_sched_loading.reset(_tok);
    }
}

def get_cfg_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    if _ir_sched_loading.get() {
        return [];
    }
    _tok = _ir_sched_loading.set(True);
    try {
        import from jaclang.compiler.passes.main.cfg_build_pass { CFGBuildPass }
        return [CFGBuildPass];
    } except ImportError {
        return [];
    } finally {
        _ir_sched_loading.reset(_tok);
    }
}

def get_type_check_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    if _typecheck_sched_loading.get() {
        return [];
    }
    _tok = _typecheck_sched_loading.set(True);
    try {
        import from jaclang.compiler.passes.main.static_analysis_pass {
            StaticAnalysisPass
        }
        import from jaclang.compiler.passes.main.access_check_pass { AccessCheckPass }
        import from jaclang.compiler.passes.main.capability_check_pass {
            NativeCapabilityCheckPass,
            PortabilityWarnPass
        }
        import from jaclang.compiler.passes.main.ownership_check_pass {
            OwnershipCheckPass
        }
        import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacLintCheckPass }
        return [
            StaticAnalysisPass,
            AccessCheckPass,
            OwnershipCheckPass,
            NativeCapabilityCheckPass,
            PortabilityWarnPass,
            JacLintCheckPass
        ];
    } except ImportError {
        return [];
    } finally {
        _typecheck_sched_loading.reset(_tok);
    }
}

def get_inference_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    if _typecheck_sched_loading.get() {
        return [];
    }
    _tok = _typecheck_sched_loading.set(True);
    try {
        import from jaclang.compiler.passes.main.type_checker_pass { TypeInferencePass }

        import from jaclang.compiler.type_system.type_evaluator { TypeEvaluator }

        stub_path = os.path.join(
            os.path.dirname(__file__),
            '..',
            'vendor',
            'typeshed',
            'stdlib',
            'builtins.pyi'
        );
        if not os.path.exists(stub_path) {
            return [];
        }
        return [TypeInferencePass];
    } except ImportError {
        return [];
    } finally {
        _typecheck_sched_loading.reset(_tok);
    }
}

def get_py_code_gen(
    native: bool = True
) -> list[type[Transform[uni.Module, uni.Module]]] {
    if _codegen_sched_loading.get() or _ir_sched_loading.get() {
        return [PyastGenPass, PyBytecodeGenPass];
    }
    _tok = _codegen_sched_loading.set(True);
    try {
        import from jaclang.compiler.passes.ecmascript { EsastGenPass }
        import from jaclang.compiler.passes.main.pyjac_ast_link_pass {
            PyJacAstLinkPass
        }

        passes: list[type[Transform[uni.Module, uni.Module]]] = [EsastGenPass];
        if native {
            import from jaclang.compiler.passes.main.rc_facts_pass { RcFactsPass }
            import from jaclang.compiler.passes.native {
                NaIRGenPass,
                NativeCompilePass
            }
            passes.extend(
                expand_with_requirements(
                    [NaIRGenPass, NativeCompilePass], {'rc-facts': RcFactsPass}
                )
            );
        }
        passes.extend([PyastGenPass, PyJacAstLinkPass, PyBytecodeGenPass]);
        return passes;
    } except ImportError {
        return [PyastGenPass, PyBytecodeGenPass];
    } finally {
        _codegen_sched_loading.reset(_tok);
    }
}

def get_format_sched(
    auto_lint: bool = False
) -> list[type[Transform[uni.Module, uni.Module]]] {
    import from jaclang.compiler.passes.tool.comment_attach_pass { CommentAttachPass }
    import from jaclang.compiler.passes.tool.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacAutoLintPass }
    import from jaclang.compiler.passes.tool.jac_formatter_pass { JacFormatPass }
    if auto_lint {
        return [CommentAttachPass, JacAutoLintPass, DocIRGenPass, JacFormatPass];
    } else {
        return [CommentAttachPass, DocIRGenPass, JacFormatPass];
    }
}

def get_lint_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacAutoLintPass }
    return [JacAutoLintPass];
}

def patch_co_filenames_bytes(raw_bc: bytes, find: str, replace: str) -> bytes {
    try {
        import types as _types;
        code = marshal.loads(raw_bc);
        def _patch(c: _types.CodeType) -> _types.CodeType {
            new_filename = c.co_filename.replace(find, replace);
            new_consts = tuple(
                _patch(x) if isinstance(x, _types.CodeType) else x for x in c.co_consts
            );
            return c.replace(co_filename=new_filename, co_consts=new_consts);
        }
        return marshal.dumps(_patch(code));
    } except Exception {
        return raw_bc;
    }
}

obj _SetupProgress {
    has _banner_shown: bool = False,
        _compile_count: int = 0,
        _seen_files: set[str] postinit,
        _jaclang_root: (str | None) = None;

    def postinit -> None;
    def _get_jaclang_root -> str;
    def _atexit_handler -> None;
    def on_internal_compile(file_path: str) -> None;

    has is_active: bool { getter; }
}

glob setup_progress = _SetupProgress();

def _coerce_module(
    module: uni.Module,
    unfold_type: type,
    skip_types: tuple,
    context: CodeContext,
    skip_token: (Tok | None) = None
) {
    module.decided_codespace = context.value;
    elements: list[uni.ElementStmt] = [];
    for stmt in module.body {
        if isinstance(stmt, unfold_type) {
            elements.extend(stmt.body);
        } elif isinstance(stmt, skip_types) {
            elements.append(stmt);
        } elif isinstance(stmt, uni.ElementStmt) {
            elements.append(stmt);
        }
    }
    for elem in elements {
        if isinstance(elem, skip_types) {
            continue;
        }
        if isinstance(elem, uni.ContextAwareNode) {
            if (skip_token is not None and not isinstance(elem, uni.Import)) {
                context_token = elem._source_context_token();
                if (context_token is not None and context_token.name == skip_token) {
                    continue;
                }
            }
            elem.code_context = context;
            if (isinstance(elem, uni.ModuleCode) and elem.body) {
                for inner in elem.body {
                    if isinstance(inner, uni.ContextAwareNode) {
                        inner.code_context = context;
                    }
                }
            }
        }
    }
    module.body = elements;
    new_kid: list[uni.UniNode] = [];
    if module.doc {
        new_kid.append(module.doc);
    }
    new_kid.extend(module.body);
    module.set_kids(nodes=new_kid or [uni.EmptyToken()]);
}

def _coerce_client_module(module: uni.Module) {
    _coerce_module(
        module,
        unfold_type=uni.ClientBlock,
        skip_types=(uni.ServerBlock, ),
        context=CodeContext.CLIENT,
        skip_token=Tok.KW_SERVER
    );
}

def _coerce_server_module(module: uni.Module) {
    _coerce_module(
        module,
        unfold_type=uni.ServerBlock,
        skip_types=(uni.ClientBlock, ),
        context=CodeContext.SERVER
    );
}

def _coerce_native_module(module: uni.Module) {
    _coerce_module(
        module,
        unfold_type=uni.NativeBlock,
        skip_types=(uni.ServerBlock, uni.ClientBlock),
        context=CodeContext.NATIVE
    );
}

def _module_top_element(module: uni.Module, nd: uni.UniNode) -> (uni.UniNode | None) {
    cur: (uni.UniNode | None) = nd;
    while (cur is not None and cur.parent is not module) {
        cur = cur.parent;
    }
    return cur;
}

def _stamp_context_element(elem: uni.UniNode, context: CodeContext) {
    if not isinstance(elem, uni.ContextAwareNode) {
        return;
    }
    elem.code_context = context;
    if (isinstance(elem, uni.ModuleCode) and elem.body) {
        for inner in elem.body {
            if isinstance(inner, uni.ContextAwareNode) {
                inner.code_context = context;
            }
        }
    }
}

def _stamp_client_element(elem: uni.UniNode) {
    _stamp_context_element(elem, CodeContext.CLIENT);
}

def _seed_module_codespace(module: uni.Module) {
    client_top_ids: set[int] = set();
    native_top_ids: set[int] = set();
    for jsx in module.get_all_sub_nodes(uni.JsxElement) {
        top = _module_top_element(module, jsx);
        if top is not None {
            client_top_ids.add(id(top));
        }
    }
    for imp in module.get_all_sub_nodes(uni.Import) {
        top = _module_top_element(module, imp);
        if top is None {
            continue;
        }
        if imp.has_clib_decls {
            native_top_ids.add(id(top));
        } elif imp.has_string_path {
            client_top_ids.add(id(top));
        }
    }
    if (not client_top_ids and not native_top_ids) {
        return;
    }
    for stmt in module.body {
        if not isinstance(stmt, uni.ContextAwareNode) {
            continue;
        }
        if (
            stmt._source_context_token() is not None
            or stmt.code_context != CodeContext.SERVER
        ) {
            continue;
        }
        if id(stmt) in native_top_ids {
            _stamp_context_element(stmt, CodeContext.NATIVE);
        } elif id(stmt) in client_top_ids {
            _stamp_context_element(stmt, CodeContext.CLIENT);
        }
    }
}

glob NATIVE_DEFAULT_SV_SIGNAL_NODES: tuple = (
         uni.VisitStmt,
         uni.DisengageStmt,
         uni.ReportStmt,
         uni.YieldExpr,
         uni.EdgeOpRef,
         uni.DisconnectOp,
         uni.TypedCtxBlock,
         uni.LambdaExpr,
         uni.PyInlineCode,
         uni.ClientBlock,
         uni.ServerBlock,
         uni.JsxElement
     ),
     _na_default_scan_cache: dict[str, tuple] = {},
     _na_demotion_memo: dict[str, tuple] = {},
     _na_census: dict[str, dict] = {},
     _na_census_state: dict[str, bool] = {"enabled": False},
     _na_cap_noted: dict[str, bool] = {};

def na_census_begin {
    _na_census.clear();
    _na_demotion_memo.clear();
    _na_default_scan_cache.clear();
    _na_census_state["enabled"] = True;
}

def na_census_record(path: str, outcome: str, code: str = '', detail: str = '') {
    if not _na_census_state["enabled"] or not path {
        return;
    }
    key = os.path.realpath(path);
    prev = _na_census.get(key);
    if prev is not None and prev['outcome'] == 'demoted' and outcome != 'demoted' {
        return;
    }
    _na_census[key] = {
        'outcome': outcome,
        'code': code,
        'detail': detail,
        'seams': (prev['seams'] if prev is not None else [])
    };
}

def na_census_seam(path: str, reason: str) {
    if not _na_census_state["enabled"] or not path {
        return;
    }
    key = os.path.realpath(path);
    rec = _na_census.get(key);
    if rec is None {
        rec = {'outcome': 'native', 'code': '', 'detail': '', 'seams': []};
        _na_census[key] = rec;
    }
    rec['seams'].append(reason);
}

def na_census_end -> dict {
    snap = dict(_na_census);
    _na_census_state["enabled"] = False;
    return snap;
}

def _default_codespace_for(target_program: JacProgram) -> str {
    import from jaclang.jac0core.codeinfo { effective_default_codespace }
    opts = target_program._compile_options;
    if opts is not None and opts.default_codespace {
        return opts.default_codespace;
    }
    return effective_default_codespace();
}

def _scan_native_default_signals(
    module: uni.Module, base_dir: str
) -> tuple[str, list[str]] {
    import from jaclang.jac0core.codeinfo {
        NATIVE_SUPPORTED_STDLIB,
        is_bundled_native_module,
        resolve_native_module
    }
    deps: list[str] = [];
    for typ in NATIVE_DEFAULT_SV_SIGNAL_NODES {
        if module.get_all_sub_nodes(typ) {
            return (f"contains {typ.__name__}", deps);
        }
    }
    for arch in module.get_all_sub_nodes(uni.Archetype) {
        if arch.arch_type.name in (Tok.KW_NODE, Tok.KW_EDGE, Tok.KW_WALKER) {
            return ("osp archetype", deps);
        }
    }
    for ab in module.get_all_sub_nodes(uni.Ability) {
        if ab.is_async or isinstance(ab.signature, uni.EventSignature) {
            return ("async/event ability", deps);
        }
    }
    for stmt in module.body {
        if isinstance(stmt, uni.ContextAwareNode) {
            tok = stmt._source_context_token();
            if tok is not None and tok.name in (Tok.KW_SERVER, Tok.KW_CLIENT) {
                return ("explicit sv/cl marker", deps);
            }
        }
        if (
            isinstance(stmt, (uni.Ability, uni.GlobalVars))
            and stmt.access is not None
            and stmt.access.tag.name == Tok.KW_PUB
        ) {
            return ("pub access", deps);
        }
    }
    for imp in module.get_all_sub_nodes(uni.Import) {
        if imp.has_clib_decls {
            continue;
        }
        if imp.is_virtual_jac or imp.has_string_path {
            return ("virtual/string-path import", deps);
        }
        targets: list[tuple[str, (str | None), bool, bool]] = [];
        if imp.from_loc is not None {
            targets.append(
                (
                    imp.from_loc.dot_path_str,
                    _try_resolve_import(imp.from_loc),
                    False,
                    False
                )
            );
            for item in imp.items {
                if isinstance(item, uni.ModuleItem) {
                    item_path = _try_resolve_import(item);
                    if item_path is not None {
                        targets.append(("", item_path, False, False));
                    }
                }
            }
        } else {
            for item in imp.items {
                if isinstance(item, uni.ModulePath) {
                    targets.append(
                        (
                            item.dot_path_str,
                            _try_resolve_import(item),
                            not imp.is_absorb,
                            not imp.is_absorb
                            and item.alias is None
                            and len(item.path) == 1
                        )
                    );
                }
            }
        }
        for (name, path, is_bare, is_plain_bare) in targets {
            clean = name.lstrip('.') if name else '';
            if is_bare {
                if clean and clean in NATIVE_SUPPORTED_STDLIB {
                    continue;
                }
                if clean and is_bundled_native_module(clean) {
                    continue;
                }
                if not (is_plain_bare and path is not None and path.endswith('.jac')) {
                    return (f"non-native import '{clean}'", deps);
                }
            }
            if path is not None and path.endswith('.na.jac') {
                continue;
            }
            if path is not None
            and (path.endswith('.cl.jac') or path.endswith('.sv.jac')) {
                return ("cl/sv module import", deps);
            }
            if path is not None and path.endswith('.jac') {
                deps.append(os.path.abspath(path));
                continue;
            }
            if clean and clean in NATIVE_SUPPORTED_STDLIB {
                continue;
            }
            if clean and is_bundled_native_module(clean) {
                continue;
            }
            if clean
            and resolve_native_module(clean, base_dir, allow_inferred=False)[
                1
            ] is not None {
                continue;
            }
            return (f"unresolved import '{clean}'", deps);
        }
    }
    return ('', deps);
}

def _try_resolve_import(nd: (uni.ModulePath | uni.ModuleItem)) -> (str | None) {
    try {
        path = nd.resolve_relative_path();
    } except Exception {
        return None;
    }
    if path and os.path.exists(path) {
        return path;
    }
    return None;
}

def _is_demoted_native(path: str) -> bool {
    key = _na_demotion_memo.get(path);
    if key is None {
        return False;
    }
    try {
        st = os.stat(path);
        if key == (st.st_mtime_ns, st.st_size) {
            return True;
        }
    } except OSError {
        ;
    }
    del _na_demotion_memo[path];
    return False;
}

def _mark_demoted_native(path: str) {
    try {
        st = os.stat(path);
        _na_demotion_memo[path] = (st.st_mtime_ns, st.st_size);
    } except OSError {
        ;
    }
}

def _note_native_closure_cap(root_path: str, cap: int) {
    rp = os.path.realpath(root_path);
    if rp in _na_cap_noted {
        return;
    }
    _na_cap_noted[rp] = True;
    try {
        import from jaclang.cli.console { console }
        console.print(
            f"note: {root_path} preferred native but its import closure "
            f"exceeded the inference cap ({cap} modules); compiled in the "
            f"server codespace. Raise [build] native_closure_cap in jac.toml "
            f"to scan larger closures.",
            style="dim",
            file=sys.stderr
        );
    } except Exception {
        ;
    }
}

def _native_default_dep_scan(path: str) -> (tuple[str, list[str]] | None) {
    if _is_demoted_native(os.path.realpath(path)) {
        return ("previously-demoted", []);
    }
    import from jaclang.jac0core.bccache {
        discover_annex_files,
        discover_variant_files
    }
    import from jaclang.jac0core.parser { parse as rd_parse }
    files = [path] + discover_annex_files(path, '.impl.jac') + discover_annex_files(
        path, '.test.jac'
    );
    fresh_parts: list[tuple] = [];
    for f in files {
        try {
            st = os.stat(f);
            fresh_parts.append((f, st.st_mtime_ns, st.st_size));
        } except OSError {
            return None;
        }
    }
    fresh_key = tuple(fresh_parts);
    cached = _na_default_scan_cache.get(path);
    if cached is not None and cached[0] == fresh_key {
        return (cached[1], cached[2]);
    }
    sv_reason = "sv-variant-file" if discover_variant_files(path) else '';
    deps: list[str] = [];
    if not sv_reason {
        base_dir = os.path.dirname(os.path.abspath(path)) or '.';
        for f in files {
            try {
                src = read_file_with_encoding(f);
            } except Exception {
                sv_reason = "unreadable annex";
                break;
            }
            (dep_mod, had_err) = rd_parse(src, f, prog=JacProgram());
            if had_err {
                sv_reason = "parse error";
                break;
            }
            (f_sv, f_deps) = _scan_native_default_signals(dep_mod, base_dir);
            if f_sv {
                sv_reason = f_sv;
                break;
            }
            deps.extend(f_deps);
        }
    }
    if sv_reason {
        deps = [];
    }
    _na_default_scan_cache[path] = (fresh_key, sv_reason, deps);
    return (sv_reason, deps);
}

def _native_default_deps_ok(root_path: str, root_deps: list[str]) -> bool {
    import from jaclang.jac0core.codeinfo { effective_native_closure_cap }
    cap = effective_native_closure_cap();
    edges: dict[str, list[str]] = {root_path: list(root_deps)};
    queue: list[str] = list(root_deps);
    while queue {
        if len(edges) > cap {
            _note_native_closure_cap(root_path, cap);
            return False;
        }
        dep = queue.pop();
        if dep in edges {
            continue;
        }
        info = _native_default_dep_scan(dep);
        if info is None {
            return False;
        }
        (dep_sv, dep_deps) = info;
        if dep_sv {
            return False;
        }
        edges[dep] = list(dep_deps);
        for d in dep_deps {
            if d not in edges {
                queue.append(d);
            }
        }
    }
    return True;
}

def _native_default_path_ok(path: str) -> bool {
    ap = os.path.abspath(path);
    info = _native_default_dep_scan(ap);
    if info is None {
        return False;
    }
    (has_sv, deps) = info;
    if has_sv {
        return False;
    }
    return _native_default_deps_ok(ap, deps);
}

def _native_default_closure_verdict(module: uni.Module) -> tuple[bool, str] {
    import from jaclang.jac0core.bccache { discover_variant_files }
    mod_path = module.loc.mod_path if module.loc is not None else '';
    if not mod_path {
        return (False, "no module path");
    }
    if _is_demoted_native(os.path.realpath(mod_path)) {
        return (False, "previously-demoted");
    }
    if discover_variant_files(mod_path) {
        return (False, "sv-variant-file");
    }
    base_dir = os.path.dirname(os.path.abspath(mod_path)) or '.';
    (sv_reason, deps) = _scan_native_default_signals(module, base_dir);
    if sv_reason {
        return (False, sv_reason);
    }
    if not _native_default_deps_ok(os.path.abspath(mod_path), deps) {
        return (False, "import-closure (sv dep or cap)");
    }
    return (True, '');
}

def _native_default_closure_ok(module: uni.Module) -> bool {
    return _native_default_closure_verdict(module)[0];
}

obj JacCompiler {
    with entry {
        _jaclang_root: (str | None) = None;
    }

    has _internal_program: (JacProgram | None) = None,
        _internal_bytecode_depth: int = 0;

    has internal_program: JacProgram { getter; }

    @classmethod
    def _get_jaclang_root(cls: any) -> str;

    def _resolve_program(file_path: str, target_program: JacProgram) -> JacProgram;
    def get_native_interop_setup(
        full_target: str, target_program: JacProgram
    ) -> tuple[((object | None), (dict[(str, object)] | None))];

    def get_native_layout(
        full_target: str, target_program: JacProgram
    ) -> (object | None);

    static def _check_native_abi(layout: any, full_target: str) -> None;
    def get_bytecode(
        full_target: str, target_program: JacProgram
    ) -> (types.CodeType | None);

    def _evict_internal_unit(
        full_target: str, actual_program: JacProgram, result: uni.Module
    ) -> None;

    def _load_native_from_cache(
        full_target: str,
        target_program: JacProgram,
        cached_ir: str,
        cached_interop: (dict[str, any] | None)
    ) -> None;

    def _load_native_from_bitcode(
        full_target: str,
        target_program: JacProgram,
        section_data: bytes,
        cached_interop: (dict[str, any] | None)
    ) -> None;

    def _restore_sections(
        full_target: str, actual_program: JacProgram, secs: dict[int, bytes]
    ) -> None;

    def _get_precompiled_jir_bytecode(
        full_target: str, allow_unsealed: bool = True
    ) -> (bytes | None);

    def _sealed_jir_data(full_target: str) -> (tuple[bytes, str] | None);
    def _build_interop_dict(result: uni.Module) -> dict;
    def _deserialize_interop_table(cached_interop: dict[str, any]) -> InteropManifest;
    def parse_str(
        source_str: str,
        file_path: str,
        target_program: JacProgram,
        cancel_token: (Event | None) = None
    ) -> uni.Module;

    def compile(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None) = None,
        options: CompileOptions = CompileOptions()
    ) -> uni.Module;

    def _compile_once(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None) = None,
        options: CompileOptions = CompileOptions()
    ) -> uni.Module;

    def build(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None) = None,
        type_check: bool = False
    ) -> uni.Module;

    def run_schedule(
        mod: uni.Module,
        target_program: JacProgram,
        passes: list[type[Transform[uni.Module, uni.Module]]],
        cancel_token: (Event | None) = None
    ) -> None;

    static def _count_module_blocking_errors(
        target_program: JacProgram, mod_path: str
    ) -> int;

    static def _count_module_errors(target_program: JacProgram, mod_path: str) -> int;
    static def _module_scoped_errors(
        target_program: JacProgram, mod_path: str
    ) -> bool;

    static def _scrub_native_artifacts_on_error(
        target_program: JacProgram, mod: uni.Module
    ) -> bool;

    static def _prepare_tool_program(
        source_str: str, file_path: str
    ) -> tuple[JacProgram, (uni.Module | None)];

    static def jac_file_formatter(
        file_path: str, auto_lint: bool = False
    ) -> JacProgram;

    static def jac_str_formatter(
        source_str: str, file_path: str, auto_lint: bool = False
    ) -> JacProgram;

    static def jac_file_linter(file_path: str) -> JacProgram;
}
