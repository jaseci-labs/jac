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
    SEC_PLACEMENT,
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
    DeclImplMatchPass,
    EndpointEffectPass,
    JacAnnexPass,
    PlacementApplyPass,
    PyastGenPass,
    PyBytecodeGenPass,
    SemanticAnalysisPass,
    SymTabBuildPass,
    Transform
}
import from jaclang.jac0core.program { JacProgram }

def get_symtab_ir_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    return [ASTValidationPass, SymTabBuildPass, DeclImplMatchPass, PlacementApplyPass];
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
    return [BoundaryAnalysisPass, EndpointEffectPass];
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
        passes.append(PlacementApplyPass);
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

def typeshed_stubs_available -> bool {
    stub_path = os.path.join(
        os.path.dirname(__file__), '..', 'vendor', 'typeshed', 'stdlib', 'builtins.pyi'
    );
    return os.path.exists(stub_path);
}

def get_inference_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    if _typecheck_sched_loading.get() {
        return [];
    }
    _tok = _typecheck_sched_loading.set(True);
    try {
        import from jaclang.compiler.passes.main.type_checker_pass { TypeInferencePass }

        import from jaclang.compiler.type_system.type_evaluator { TypeEvaluator }

        if not typeshed_stubs_available() {
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
    import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacLintCheckPass }
    return [JacLintCheckPass];
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

def _coerce_module(module: uni.Module, context: CodeContext) {
    module.decided_codespace = context.value;
    for elem in module.body {
        if isinstance(elem, uni.ContextAwareNode) {
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
}

def _coerce_client_module(module: uni.Module) {
    _coerce_module(module, context=CodeContext.CLIENT);
}

def _coerce_native_module(module: uni.Module) {
    _coerce_module(module, context=CodeContext.NATIVE);
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

def hub_module_for_path(path: str, prog: object) -> (uni.Module | None) {
    hub: (dict[str, uni.Module] | None) = prog?.mod?.hub;
    if hub is None or not hub {
        return None;
    }
    if path in hub {
        return hub[path];
    }
    abs_path = os.path.abspath(path);
    if abs_path in hub {
        return hub[abs_path];
    }
    normalized = os.path.normcase(os.path.realpath(abs_path));
    for (hub_path, hub_mod) in hub.items() {
        if os.path.normcase(os.path.realpath(os.path.abspath(hub_path)))
            == normalized {
            return hub_mod;
        }
    }
    return None;
}

def module_has_client_top(module: (uni.Module | None)) -> bool {
    if module is None {
        return False;
    }
    for stmt in module.body {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            return True;
        }
    }
    return False;
}

def is_server_anchored_module(module: (uni.Module | None)) -> bool {
    if module is None {
        return True;
    }
    anchor_path = module.loc.mod_path or '';
    if anchor_path {
        import from jaclang.jac0core.service_cut { is_service_module_stem }
        anchor_stem = os.path.basename(anchor_path);
        if anchor_stem.endswith('.jac') {
            anchor_stem = anchor_stem[:-4];
        }
        if is_service_module_stem(anchor_path, anchor_stem) {
            return True;
        }
    }
    for arch in module.get_all_sub_nodes(uni.Archetype) {
        if arch.arch_kind is not None {
            return True;
        }
    }
    if module.get_all_sub_nodes(uni.PyInlineCode) {
        return True;
    }
    for stmt in module.body {
        if isinstance(stmt, uni.TypedCtxBlock) {
            return True;
        }
    }
    for imp in module.get_all_sub_nodes(uni.Import) {
        if imp.has_clib_decls or imp.is_virtual_jac or imp.has_string_path {
            continue;
        }
        if imp.from_loc is None {
            return True;
        }
        resolved = imp.from_loc.resolve_relative_path();
        if not isinstance(resolved, str) or not resolved.endswith('.jac') {
            import from jaclang.jac0core.modresolver { is_client_npm_import }
            if is_client_npm_import(
                imp.from_loc.dot_path_str, module.loc.mod_path or ''
            ) {
                continue;
            }
            return True;
        }
    }
    return False;
}

def module_own_native_anchor(module: (uni.Module | None)) -> bool {
    import from jaclang.jac0core.constant { OwnershipKind }
    if module is None {
        return False;
    }
    for tag in module.get_all_sub_nodes(uni.SubTag) {
        if tag.ownership != OwnershipKind.NONE {
            return True;
        }
    }
    for stmt in module.body {
        if isinstance(stmt, uni.Import) and stmt.has_clib_decls {
            return True;
        }
    }
    return False;
}

def plain_native_import_target(nd: uni.Import, prog: object) -> (str | None) {
    import from jaclang.jac0core.placement_pins { config_module_pin }
    if (
        nd.is_service_import
        or nd.is_typed
        or nd.is_virtual_jac
        or nd.from_loc is None
        or not nd.items
    ) {
        return None;
    }
    resolved = nd.from_loc.resolve_relative_path();
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return None;
    }
    real_resolved = os.path.realpath(resolved);
    jaclang_root = os.path.realpath(os.path.dirname(os.path.dirname(__file__)));
    if (
        real_resolved.startswith(jaclang_root + os.sep)
        and (os.sep + 'na_stdlib' + os.sep) not in real_resolved
    ) {
        return None;
    }
    if config_module_pin(resolved) == 'native' {
        return resolved;
    }
    target = hub_module_for_path(resolved, prog);
    if target is None {
        import from jaclang.jac0core.placement_solver { _materialize_module }
        target = _materialize_module(resolved, prog);
    }
    if target is None {
        return None;
    }
    if (
        target.decided_codespace == 'native'
        or target.declares_codespace(CodeContext.NATIVE)
        or module_own_native_anchor(target)
    ) {
        return resolved;
    }
    return None;
}

def import_declares_native_target(nd: uni.Import) -> bool {
    import from jaclang.jac0core.placement_pins { config_module_pin }
    if nd.from_loc is None {
        return False;
    }
    try {
        resolved = nd.from_loc.resolve_relative_path();
    } except Exception {
        return False;
    }
    if not isinstance(resolved, str) or not resolved.endswith('.jac') {
        return False;
    }
    return config_module_pin(resolved) == 'native';
}

def native_only_import_target(nd: uni.Import, prog: object) -> (str | None) {
    import from jaclang.jac0core.placement_pins { config_module_pin }
    resolved = plain_native_import_target(nd, prog);
    if resolved is None {
        return None;
    }
    if config_module_pin(resolved) == 'native' {
        return resolved;
    }
    target = hub_module_for_path(resolved, prog);
    if target is not None and module_own_native_anchor(target) {
        return resolved;
    }
    return None;
}

def is_client_native_edge_import(nd: uni.Import, prog: object) -> bool {
    if nd.code_context == CodeContext.CLIENT {
        ;
    } elif nd.code_context == CodeContext.SERVER
        and module_has_client_top(nd.find_parent_of_type(uni.Module)) {
        ;
    } else {
        return False;
    }
    return plain_native_import_target(nd, prog) is not None;
}

def _ability_of_defn(defn_node: uni.UniNode) -> (uni.Ability | None) {
    if isinstance(defn_node, uni.Ability) {
        return defn_node;
    }
    if isinstance(defn_node.parent, uni.Ability) {
        return defn_node.parent;
    }
    return None;
}

def ability_of_symbol(sym: (uni.Symbol | None)) -> (uni.Ability | None) {
    if sym is None or not sym.defn {
        return None;
    }
    decl = _ability_of_defn(sym.defn[0]);

    if decl is not None and str(decl.loc.mod_path).endswith(".pyi") {
        for alt in sym.defn {
            alt_decl = _ability_of_defn(alt);
            if alt_decl is not None
                and not str(alt_decl.loc.mod_path).endswith(".pyi") {
                return alt_decl;
            }
        }
    }
    return decl;
}

enum ClientImportVerdict {
    CLIENT = "client",
    BRIDGED = "bridged",
    DEAD = "dead",
    UNKNOWN = "unknown"
}

def is_client_boundary_import(nd: uni.Import) -> bool {
    return (
        nd.code_context == CodeContext.CLIENT
        and not nd.is_service_import
        and not nd.is_typed
        and not nd.is_virtual_jac
        and nd.from_loc is not None
        and bool(nd.items)
        and nd.from_loc.resolve_relative_path().endswith('.jac')
    );
}

def symbol_linked_source_module(nd: uni.Import) -> (uni.Module | None) {
    for item in nd.items {
        if not (isinstance(item, uni.ModuleItem) and isinstance(item.name, uni.Name)) {
            continue;
        }
        sym = item.name.sym;
        if sym is None or sym.decl is None {
            continue;
        }
        linked = sym.decl.find_parent_of_type(uni.Module);
        if linked is not None {
            return linked;
        }
    }
    return None;
}

def _import_item_owner_decl(
    source_mod: uni.Module, item: uni.ModuleItem
) -> (uni.ContextAwareNode | None) {
    if not isinstance(item.name, uni.Name) {
        return None;
    }
    sym = source_mod.lookup(item.name.sym_name);
    if sym is None or sym.decl is None {
        return None;
    }
    cur: (uni.UniNode | None) = sym.decl;
    while cur is not None and not isinstance(cur, uni.Module) {
        if isinstance(cur, uni.ContextAwareNode) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

def classify_client_import_item(
    source_mod: uni.Module, item: object
) -> ClientImportVerdict {
    if not isinstance(item, uni.ModuleItem) {
        return ClientImportVerdict.UNKNOWN;
    }
    owner = _import_item_owner_decl(source_mod, item);
    if owner is None or isinstance(owner, uni.Import) {
        return ClientImportVerdict.UNKNOWN;
    }
    if owner.code_context == CodeContext.CLIENT {
        return ClientImportVerdict.CLIENT;
    }
    if isinstance(owner, uni.Ability) {
        if (
            not owner.is_method
            and owner.access is not None
            and owner.access.tag.name == Tok.KW_PUB
        ) {
            return ClientImportVerdict.BRIDGED;
        }
        return ClientImportVerdict.DEAD;
    }
    if isinstance(owner, (uni.Archetype, uni.Enum, uni.TypeAlias)) {
        return ClientImportVerdict.BRIDGED;
    }
    return ClientImportVerdict.DEAD;
}

def import_binds_client_native(nd: uni.Import, manifest: object) -> bool {
    import from jaclang.jac0core.codeinfo { InteropContext, InteropManifest }
    if nd.from_loc is None or not nd.items {
        return False;
    }
    if nd.is_service_import or nd.is_typed or nd.is_virtual_jac {
        return False;
    }
    if not isinstance(manifest, InteropManifest) or not manifest.bindings {
        return False;
    }
    try {
        resolved_path = nd.from_loc.resolve_relative_path();
    } except Exception {
        return False;
    }
    for item in nd.items {
        if not isinstance(item, uni.ModuleItem) {
            continue;
        }
        local_name = item.alias.sym_name
            if item.alias is not None
            else getattr(item.name, 'value', str(item.name));
        binding = manifest.bindings.get(local_name);
        if (
            binding is not None
            and binding.source_context == InteropContext.NATIVE
            and (InteropContext.CLIENT in binding.callers)
            and binding.source_module == resolved_path
        ) {
            return True;
        }
    }
    return False;
}

glob _na_demotion_memo: dict[str, tuple] = {},
     _na_census: dict[str, dict] = {},
     _na_census_state: dict[str, bool] = {"enabled": False},
     _na_cap_noted: dict[str, bool] = {};

def na_census_begin {
    import from jaclang.jac0core.placement_solver { native_scan_memo_clear }
    _na_census.clear();
    _na_demotion_memo.clear();
    native_scan_memo_clear();
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
