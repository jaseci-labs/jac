import ast as py_ast;
import atexit;
import marshal;
import os;
import sys;
import types;
import from threading { Event }
import from contextvars { ContextVar }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.unitree { ability_of_symbol }
import from jaclang.jac0core.jir {
    SEC_BYTECODE,
    SEC_MTIR,
    SEC_LLVM_IR,
    SEC_INTEROP,
    SEC_NATIVE_OBJ,
    SEC_PLACEMENT,
    FLAG_PRECOMPILED,
    get_module_cache_path,
    is_module_cache_valid,
    precompiled_jir_matches_source,
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
    GraphSchemaPass,
    JacAnnexPass,
    JcirBytecodeGenPass,
    JcirGenPass,
    PlacementApplyPass,
    SemanticAnalysisPass,
    SymTabBuildPass,
    Transform
}
import from jaclang.jac0core.passes.transform { DiagnosticPolicy }
import from jaclang.jac0core.program { JacProgram }

def diagnostic_policy_for(
    config: any, extra_suppress_tokens: (list | None) = None
) -> DiagnosticPolicy {
    import from jaclang.jac0core.diagnostic_utils { resolve_diagnostic_tokens }
    tokens: list[str] = [];
    categories: list[str] = [];
    lint_active = False;
    lint_select: list[str] = [];
    lint_ignore: list[str] = [];
    check = config.check if (config and config.check) else None;
    if check is not None {
        if check.suppress {
            tokens = list(check.suppress);
        }
        if check.suppress_categories {
            categories = list(check.suppress_categories);
        }
        lint = check.lint;
        if lint {
            lint_active = True;
            lint_select = list(lint.select);
            lint_ignore = list(lint.ignore);
        }
    }
    if extra_suppress_tokens {
        tokens.extend(extra_suppress_tokens);
    }
    resolved: list[str] = [];
    if tokens {
        (resolved, _unknown) = resolve_diagnostic_tokens(tokens);
    }
    return DiagnosticPolicy(
        suppress_codes=resolved,
        suppress_categories=categories,
        lint_active=lint_active,
        lint_select=lint_select,
        lint_ignore=lint_ignore
    );
}

def build_diagnostic_policy(prog: JacProgram) -> DiagnosticPolicy {
    config: any = None;
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
    } except Exception {
        config = None;
    }
    opts = prog._compile_options;
    extra: list[str] = (
        list(opts.suppress_codes) if (opts is not None and opts.suppress_codes) else []
    );
    return diagnostic_policy_for(config, extra);
}

def deliver_alerts(
    errors: list,
    warnings: list,
    prog: JacProgram,
    policy: (DiagnosticPolicy | None) = None
) {
    pol = policy if policy is not None else build_diagnostic_policy(prog);
    for alrt in errors {
        if alrt.code is not None and pol.is_suppressed(alrt.code, alrt.loc) {
            continue;
        }
        prog.errors_had.append(alrt);
    }
    for alrt in warnings {
        if alrt.code is not None and pol.is_suppressed(alrt.code, alrt.loc) {
            continue;
        }
        prog.warnings_had.append(alrt);
    }
}

def run_pass(
    pass_cls: type,
    ir_in: any,
    prog: JacProgram,
    cancel_token: any = None,
    policy: (DiagnosticPolicy | None) = None,
    **kwargs: any
) -> any {
    pol = policy if policy is not None else build_diagnostic_policy(prog);
    errors: list = [];
    warnings: list = [];
    inst: any = None;
    try {
        inst = pass_cls(
            ir_in=ir_in,
            prog=prog,
            cancel_token=cancel_token,
            cancel_requested=bool(cancel_token is not None and cancel_token.is_set()),
            policy=pol,
            errors_had=errors,
            warnings_had=warnings,
            **kwargs
        );
    } finally {
        eff = inst.policy if (inst is not None and inst.policy is not None) else pol;
        deliver_alerts(errors, warnings, prog, eff);
    }
    return inst;
}

def get_symtab_ir_sched -> list[type[Transform]] {
    if not _ir_sched_loading.get() {
        _tok = _ir_sched_loading.set(True);
        try {
            import jaclang.compiler.symbol_utils;
        } except ImportError as e {
            fail_loud_on_compiler_source(e);
        } finally {
            _ir_sched_loading.reset(_tok);
        }
    }
    return validate_schedule(
        [ASTValidationPass, SymTabBuildPass, DeclImplMatchPass, PlacementApplyPass],
        origin='symtab-ir schedule'
    );
}

glob _ir_sched_loading = ContextVar('jac_ir_sched_loading', default=False),
     _codegen_sched_loading = ContextVar('jac_codegen_sched_loading', default=False),
     _typecheck_sched_loading = ContextVar(
         'jac_typecheck_sched_loading', default=False
     );

def pass_requires(p: type[Transform]) -> tuple {
    return getattr(p, 'REQUIRES', ()) or ();
}

def pass_provides(p: type[Transform]) -> tuple {
    return getattr(p, 'PROVIDES', ()) or ();
}

def providers_for(passes: list[type[Transform]]) -> dict[str, type[Transform]] {
    out: dict[str, type[Transform]] = {};
    for p in passes {
        for tag in pass_provides(p) {
            out[tag] = p;
        }
    }
    return out;
}

def validate_schedule(
    passes: list[type[Transform]],
    preprovided: (set[str] | None) = None,
    origin: str = 'schedule'
) -> list[type[Transform]] {
    provided: set[str] = set(preprovided) if preprovided is not None else set();
    for p in passes {
        for tag in pass_requires(p) {
            if tag not in provided {
                raise RuntimeError(
                    f"scheduling error: pass {p.__name__} requires analysis "
                    f"'{tag}' which is neither provided by an earlier pass in "
                    f"the {origin} nor already available -- the schedule was "
                    f"constructed missing a declared dependency."
                );
            }
        }
        for tag in pass_provides(p) {
            provided.add(tag);
        }
    }
    return passes;
}

def _schedule_into(
    p: type[Transform],
    provider_map: dict[str, type[Transform]],
    acc_out: list[type[Transform]],
    acc_provided: set[str],
    chain: list[type[Transform]]
) -> (str | None) {
    if p in acc_out or p in chain {
        return None;
    }
    for tag in pass_requires(p) {
        if tag in acc_provided {
            continue;
        }
        prov = provider_map.get(tag);
        if prov is None {
            return tag;
        }
        missing = _schedule_into(
            prov, provider_map, acc_out, acc_provided, chain + [p]
        );
        if missing is not None or tag not in acc_provided {
            return tag;
        }
    }
    acc_out.append(p);
    for tag in pass_provides(p) {
        acc_provided.add(tag);
    }
    return None;
}

def resolve_schedule(
    goals: list[type[Transform]],
    providers: (dict[str, type[Transform]] | None) = None,
    preprovided: (set[str] | None) = None,
    drop_unsatisfiable: bool = False,
    origin: str = 'schedule'
) -> list[type[Transform]] {
    provider_map = dict(providers) if providers is not None else {};
    provided: set[str] = set(preprovided) if preprovided is not None else set();
    out: list[type[Transform]] = [];
    for g in goals {
        trial_out = list(out);
        trial_provided = set(provided);
        missing = _schedule_into(g, provider_map, trial_out, trial_provided, []);
        if missing is None {
            out = trial_out;
            provided = trial_provided;
        } elif not drop_unsatisfiable {
            raise RuntimeError(
                f"scheduling error: pass {g.__name__} requires analysis "
                f"'{missing}' which has no available provider while "
                f"constructing the {origin} -- the schedule cannot satisfy a "
                f"declared dependency."
            );
        }
    }
    return validate_schedule(out, preprovided=preprovided, origin=origin);
}

class CompilerSourceError(RuntimeError) {}

glob _compiler_source_failures: dict[str, str] = {};

def note_compiler_source_failure(path: str, details: str) {
    key = os.path.realpath(path);
    if details {
        _compiler_source_failures[key] = details;
    } else {
        _compiler_source_failures.pop(key, None);
    }
}

def compiler_source_failure_details(path: str) -> str {
    return _compiler_source_failures.get(os.path.realpath(path), '');
}

def module_scoped_failure_details(path: str, program: JacProgram) -> str {
    norm = os.path.normpath(path);
    stem = norm[:-4] if norm.endswith('.jac') else norm;
    prefix = stem + '.';
    lines: list[str] = [];
    for alert in program.errors_had {
        try {
            alert_path = os.path.normpath(alert.loc.mod_path);
        } except Exception {
            continue;
        }
        if alert_path == norm or alert_path.startswith(prefix) {
            lines.append(alert.pretty_print());
        }
    }
    return '\n'.join(lines);
}

def _compiler_source_root -> str {
    return os.path.realpath(os.path.dirname(os.path.dirname(__file__)));
}

def _jac_source_failure_path(err: BaseException) -> (str | None) {
    cursor: any = err;
    for _ in range(8) {
        if cursor is None {
            break;
        }
        path = cursor?.jac_source_path;
        if isinstance(path, str) and path {
            return path;
        }
        cursor = cursor?.__cause__ or cursor?.__context__;
    }
    return None;
}

def fail_loud_on_compiler_source(err: ImportError) -> None {
    path = _jac_source_failure_path(err);
    if path is None {
        return;
    }
    real = os.path.realpath(path);
    if not real.startswith(_compiler_source_root() + os.sep) {
        return;
    }
    raise CompilerSourceError(
        "the Jac compiler's own source failed to compile, so the pass "
        f"schedule cannot be built: {real}\n{err}"
    ) from err;
}

glob _native_sched_failure: dict[str, str] = {};

def _note_native_schedule_failure(err: (BaseException | None)) {
    if err is None {
        _native_sched_failure.pop('reason', None);
    } else {
        _native_sched_failure['reason'] = f"{type(err).__name__}: {err}";
    }
}

def native_schedule_failure -> str {
    return _native_sched_failure.get('reason', '');
}

def compiler_source_failure_origin(err: BaseException) -> (str | None) {
    root = _compiler_source_root() + os.sep;
    cursor: any = err;
    for _ in range(8) {
        if cursor is None {
            break;
        }
        for cand in (cursor?.jac_source_path, cursor?.path) {
            if isinstance(cand, str) and cand {
                real = os.path.realpath(cand);
                if real.startswith(root) {
                    return real;
                }
            }
        }
        name = cursor?.name;
        if isinstance(name, str)
            and (name == 'jaclang' or name.startswith('jaclang.')) {
            return name;
        }
        cursor = cursor?.__cause__ or cursor?.__context__;
    }
    return None;
}

def module_import_in_flight(file_path: str) -> bool {
    for mod in list(sys.modules.values()) {
        spec = mod?.__spec__;
        if spec is None {
            continue;
        }
        if spec?.origin == file_path and bool(spec?._initializing) {
            return True;
        }
    }
    return False;
}

def import_error_re_enters(err: BaseException, file_path: str) -> (str | None) {
    if not isinstance(err, ImportError) or not module_import_in_flight(file_path) {
        return None;
    }
    cursor: any = err;
    for _ in range(8) {
        if cursor is None {
            break;
        }
        name = cursor?.name;
        if isinstance(name, str) and name {
            spec = sys.modules.get(name)?.__spec__;
            if spec is not None and spec?.origin == file_path {
                return name;
            }
        }
        cursor = cursor?.__cause__ or cursor?.__context__;
    }
    return None;
}

def get_boundary_analysis_sched -> list[type[Transform]] {
    return validate_schedule(
        [BoundaryAnalysisPass, EndpointEffectPass, GraphSchemaPass],
        origin='boundary-analysis schedule'
    );
}

def get_bootstrap_ir_sched -> list[type[Transform]] {
    return validate_schedule(
        [ASTValidationPass, SymTabBuildPass, DeclImplMatchPass, SemanticAnalysisPass],
        origin='bootstrap-ir schedule'
    );
}

def get_ir_gen_sched(
    is_internal: bool = False, gen_mtir: bool = True
) -> list[type[Transform]] {
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
        import jaclang.compiler.expr_keys;
        import jaclang.compiler.passes.main.layout_pass;
        import jaclang.compiler.type_registry;
        import jaclang.compiler.intrinsic_registry;
        import jaclang.project.client_kind;

        passes: list[type[Transform]] = [
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
        return validate_schedule(passes, origin='ir-gen schedule');
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        if is_internal {
            return get_bootstrap_ir_sched();
        }
        raise;
    } finally {
        _ir_sched_loading.reset(_tok);
    }
}

def get_cfg_sched -> list[type[Transform]] {
    if _ir_sched_loading.get() {
        return [];
    }
    _tok = _ir_sched_loading.set(True);
    try {
        import from jaclang.compiler.passes.main.cfg_build_pass { CFGBuildPass }
        return validate_schedule([CFGBuildPass], origin='cfg schedule');
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        return [];
    } finally {
        _ir_sched_loading.reset(_tok);
    }
}

def get_type_check_sched(provided: (set[str] | None) = None) -> list[type[Transform]] {
    if _typecheck_sched_loading.get() {
        return [];
    }
    _tok = _typecheck_sched_loading.set(True);
    goals: list[type[Transform]] = [];
    try {
        import from jaclang.compiler.passes.main.static_analysis_pass {
            StaticAnalysisPass
        }
        import from jaclang.compiler.passes.main.access_check_pass { AccessCheckPass }
        import from jaclang.compiler.passes.main.capability_check_pass {
            ClientCapabilityCheckPass,
            NativeCapabilityCheckPass,
            PortabilityWarnPass
        }
        import from jaclang.compiler.passes.main.ownership_check_pass {
            OwnershipCheckPass
        }
        import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacLintCheckPass }
        goals = [
            StaticAnalysisPass,
            AccessCheckPass,
            OwnershipCheckPass,
            NativeCapabilityCheckPass,
            ClientCapabilityCheckPass,
            PortabilityWarnPass,
            JacLintCheckPass
        ];
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        return [];
    } finally {
        _typecheck_sched_loading.reset(_tok);
    }
    return resolve_schedule(
        goals,
        providers=providers_for(get_cfg_sched() + get_inference_sched()),
        preprovided=provided,
        drop_unsatisfiable=True,
        origin='type-check schedule'
    );
}

def typeshed_stubs_available -> bool {
    return os.path.exists(
        os.path.join(
            os.path.dirname(__file__),
            '..',
            'vendor',
            'typeshed',
            'stdlib',
            'builtins.pyi'
        )
    );
}

def get_inference_sched -> list[type[Transform]] {
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
        return validate_schedule([TypeInferencePass], origin='inference schedule');
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        return [];
    } finally {
        _typecheck_sched_loading.reset(_tok);
    }
}

glob _native_env_memo: dict[str, tuple[bool, str]] = {};

def native_pipeline_available -> tuple[bool, str] {
    cached = _native_env_memo.get('verdict');
    if cached is not None {
        return cached;
    }
    if (
        _typecheck_sched_loading.get()
        or _ir_sched_loading.get()
        or _codegen_sched_loading.get()
    ) {
        return (True, '');
    }
    reason = '';
    if not typeshed_stubs_available() {
        reason = (
            'native pipeline unavailable: type inference '
            + '(vendor/typeshed stubs) is not available in this environment'
        );
    }
    if not reason {
        try {
            import from jaclang.compiler.passes.native.llvm.binding.ffi { _find_shim }
            _find_shim();
        } except ModuleNotFoundError {
            reason = (
                'native pipeline unavailable: LLVM shim (libjacllvm) '
                + 'not found in this environment'
            );
        } except ImportError as e {
            fail_loud_on_compiler_source(e);
            return (
                False,
                'native pipeline undecided: the compiler is still initializing'
            );
        } except Exception {
            reason = (
                'native pipeline unavailable: LLVM shim (libjacllvm) '
                + 'not found in this environment'
            );
        }
    }
    verdict = (not reason, reason);
    _native_env_memo['verdict'] = verdict;
    return verdict;
}

def _py_codegen_tail -> list[type[Transform]] {
    return [JcirGenPass, JcirBytecodeGenPass];
}

def get_py_code_gen(
    native: bool = True, provided: (set[str] | None) = None
) -> list[type[Transform]] {
    if _codegen_sched_loading.get() or _ir_sched_loading.get() {
        return _py_codegen_tail();
    }
    _tok = _codegen_sched_loading.set(True);
    try {
        import from jaclang.compiler.passes.ecmascript { EsastGenPass }

        passes: list[type[Transform]] = [EsastGenPass];
        if native {
            import from jaclang.compiler.passes.main.rc_facts_pass { RcFactsPass }
            import from jaclang.compiler.passes.native {
                NaIRGenPass,
                NativeCompilePass
            }
            native_goals: list[type[Transform]] = [NaIRGenPass, NativeCompilePass];
            native_providers = providers_for([RcFactsPass]);
            cross: set[str] = set(provided) if provided is not None else set();
            if provided is None {
                for g in native_goals {
                    for tag in pass_requires(g) {
                        if tag not in native_providers {
                            cross.add(tag);
                        }
                    }
                }
            }
            passes.extend(
                resolve_schedule(
                    native_goals,
                    providers=native_providers,
                    preprovided=cross,
                    origin='native codegen schedule'
                )
            );
            _note_native_schedule_failure(None);
        }
        passes.extend(_py_codegen_tail());
        return passes;
    } except ImportError as e {
        fail_loud_on_compiler_source(e);
        if native {
            _note_native_schedule_failure(e);
        }
        return _py_codegen_tail();
    } finally {
        _codegen_sched_loading.reset(_tok);
    }
}

def get_format_sched(auto_lint: bool = False) -> list[type[Transform]] {
    import from jaclang.compiler.passes.tool.comment_attach_pass { CommentAttachPass }
    import from jaclang.compiler.passes.tool.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacAutoLintPass }
    import from jaclang.compiler.passes.tool.jac_formatter_pass { JacFormatPass }
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

def get_lint_sched -> list[type[Transform]] {
    import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacLintCheckPass }
    return validate_schedule([JacLintCheckPass], origin='lint schedule');
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

def _jsx_intrinsic_guard_pass_type -> (type | None) {
    try {
        import from jaclang.compiler.passes.main.jsx_intrinsic_guard_pass {
            JsxIntrinsicGuardPass
        }
        return JsxIntrinsicGuardPass;
    } except ImportError {
        return None;
    }
}

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
    sticky = ('demoted', 'ice');
    if prev is not None and prev['outcome'] in sticky and outcome not in sticky {
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

def na_demotion_note(
    file_path: str, first_err: str, is_ice: bool
) -> tuple[(str, str)] {
    if is_ice {
        msg = (
            f"warning: {file_path} hit an internal compiler error during "
            + "native lowering and fell back to the server codespace "
            + f"({first_err}); this is a compiler bug -- please report it. "
            + "Set JAC_NATIVE_ICE_RAISE=1 to surface the full traceback."
        );
        return (msg, "yellow");
    }
    msg = (
        f"note: {file_path} preferred native but did not lower; "
        + f"compiled in the server codespace ({first_err})"
    );
    return (msg, "dim");
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
    has _internal_program: (JacProgram | None) = None,
        _internal_bytecode_depth: int = 0,
        _jaclang_root: (str | None) = None;

    has internal_program: JacProgram { getter; }

    def postinit {
        import from jaclang.jac0core.native_brands {
            DRIVER_ORIGIN,
            ensure_native_brands_bound
        }
        ensure_native_brands_bound(DRIVER_ORIGIN);
    }

    def _get_jaclang_root -> str;
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
        cancel_token: (Event | None) = None,
        prefix_kind: str = ''
    ) -> uni.Module;

    def load_annex_modules(
        mod: uni.Module, target_program: JacProgram
    ) -> list[uni.Module];

    def resolve_absorb_imports(mod: uni.Module, target_program: JacProgram) -> None;
    def stamp_boundary_facts(mod: uni.Module, target_program: JacProgram) -> None;
    def stamp_client_kind_facts(mod: uni.Module, target_program: JacProgram) -> None;
    def stamp_access_check_facts(mod: uni.Module) -> None;
    def stamp_native_import_facts(mod: uni.Module, target_program: JacProgram) -> None;
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
        passes: list[type[Transform]],
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

    static def _report_missing_native_ir(
        target_program: JacProgram, mod: uni.Module
    ) -> None;

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
