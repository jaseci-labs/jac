"""Jac Compiler - handles all compilation operations separate from program state."""
import ast as py_ast;
import atexit;
import marshal;
import os;
import sys;
import types;
import from threading { Event }
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
    HEADER_SIZE,
    write_sections
}
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.helpers { read_file_with_encoding }
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.jac0core.passes {
    ASTValidationPass,
    BoundaryAnalysisPass,
    DeclImplMatchPass,
    JacAnnexPass,
    PyastGenPass,
    PyBytecodeGenPass,
    SemanticAnalysisPass,
    SymTabBuildPass,
    Transform
}
import from jaclang.jac0core.program { JacProgram }

"""Symbol table build schedule."""
def get_symtab_ir_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    return [ASTValidationPass, SymTabBuildPass, DeclImplMatchPass];
}

glob _ir_sched_loading = False,
     _codegen_sched_loading = False,
     _typecheck_sched_loading = False;

"""Boundary analysis schedule: the single producer of cross-boundary interop
    facts for every module (server / client / native).

    Runs unconditionally. `BoundaryAnalysisPass` is statically imported, so it
    has no lazy-compile re-entrancy hazard and must NOT be gated on the
    `_*_sched_loading` flags — doing so dropped interop facts whenever an
    unrelated loader was mid-bootstrap during a concurrent compile.
    """
def get_boundary_analysis_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    return [BoundaryAnalysisPass];
}

"""Full IR generation schedule.

    Uses a re-entrancy guard: when compiling the pass modules that this
    schedule depends on (CFGBuildPass, etc.), importing them would
    trigger recursive compilation. The guard detects this and falls back
    to the basic schedule (symtab + semantic analysis only), which uses
    only jac0core passes.
    """
def get_ir_gen_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    global _ir_sched_loading;
    if _ir_sched_loading {
        return [
            ASTValidationPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass
        ];
    }
    _ir_sched_loading = True;
    try {
        import from jaclang.compiler.passes.main.cfg_build_pass { CFGBuildPass }
        import from jaclang.compiler.passes.main.mtir_gen_pass { MTIRGenPass }
        import from jaclang.compiler.passes.main.sem_def_match_pass { SemDefMatchPass }
        import from jaclang.compiler.passes.main.capability_check_pass {
            CapabilityCheckPass
        }
        # Pre-compile shared analysis modules so codegen passes can import them
        import jaclang.compiler.symbol_utils;
        import jaclang.compiler.passes.main.layout_pass;
        # JSX `{...}` slot bodies are NOT desugared here: the surface AST is
        # kept faithful through analysis (ASTValidationPass enforces the slot
        # body rules) and the accumulator-IIFE lowering happens at cl codegen
        # time in EsastGenPass, so the formatter/unparser round-trip the
        # author's template verbatim from real tokens.
        return [
            ASTValidationPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass,
            MTIRGenPass,
            CapabilityCheckPass
        ];
    } except ImportError {
        return [
            ASTValidationPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass
        ];
    } finally {
        _ir_sched_loading = False;
    }
}

"""CFG-only schedule: the flow-narrowing prerequisite.

    TypeInferencePass's `is not None` / isinstance flow-narrowing walks the
    control-flow graph (UniCFGNode.bb_in/bb_out edges). A full compile builds
    that CFG as part of `get_ir_gen_sched` (CFGBuildPass), but a lightweight
    `symtab_ir_only` compile -- used to resolve an imported dependency or lower
    a cross-module provider's annotations on demand -- skips it. Native still
    runs inference on those modules (it consumes `Expr.type`), so without this
    the narrowing silently no-ops and a `T | None` guarded by `is not None`
    stays `T | None` only on the imported-module path (issue #6667). Run this
    before inference whenever the CFG was not already built so the narrowing is
    identical to the entry-module path.

    CFGBuildPass is purely structural (it reads symbols populated by
    SymTabBuildPass, which the symtab schedule already ran, and does not depend
    on SemanticAnalysisPass / SemDefMatchPass), so it is sound to run on its own
    on a symtab-only tree. Same re-entrancy guard as `get_ir_gen_sched`: during
    bootstrap of the pass modules themselves the import would recurse, so it
    returns an empty schedule for only those modules.
    """
def get_cfg_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    global _ir_sched_loading;
    if _ir_sched_loading {
        return [];
    }
    _ir_sched_loading = True;
    try {
        import from jaclang.compiler.passes.main.cfg_build_pass { CFGBuildPass }
        return [CFGBuildPass];
    } except ImportError {
        return [];
    } finally {
        _ir_sched_loading = False;
    }
}

"""Check-extras schedule (`jac check`).

    Diagnostic-only passes layered on top of the unconditional inference
    run (get_inference_sched), which has already populated Expr.type and
    surfaced type diagnostics in full-diagnostic mode. TypeCheckPass is NOT
    repeated here, and CapabilityCheckPass is not re-run — it runs exactly
    once at the tail of get_ir_gen_sched (rerunning it mutates AST state
    that NaIRGenPass and the cross-module linker depend on).

    Same re-entrancy guard as get_ir_gen_sched: when compiling the
    pass modules that this schedule depends on, importing them would
    trigger recursive compilation. The guard detects this and returns an
    empty schedule, skipping these extras for only those bootstrap modules.
    """
def get_type_check_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    global _typecheck_sched_loading;
    if _typecheck_sched_loading {
        return [];
    }
    _typecheck_sched_loading = True;
    try {
        import from jaclang.compiler.passes.main.static_analysis_pass {
            StaticAnalysisPass
        }
        import from jaclang.compiler.passes.main.capability_check_pass {
            PortabilityWarnPass,
            NativeCapabilityCheckPass
        }
        import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacLintCheckPass }
        return [
            StaticAnalysisPass,
            PortabilityWarnPass,
            NativeCapabilityCheckPass,
            JacLintCheckPass
        ];
    } except ImportError {
        return [];
    } finally {
        _typecheck_sched_loading = False;
    }
}

"""Type-inference schedule: the typed-tree contract.

    Runs TypeInferencePass (a TypeCheckPass subclass) for every full
    compile, regardless of backend or context, so `Expr.type` is populated
    before any codegen runs — sv, cl, and na are all consumers of the same
    centrally computed types. Type *inference* is unconditional; type
    *diagnostics* are mode-gated inside the pass itself: full diagnostics
    when the compile asked for type
    checking (`jac check` / options.type_check) or when the module is
    native-context (#6049 native type discipline), suppressed otherwise so
    checker false positives never leak into plain sv/cl builds (#6262).
    ICE-category diagnostics are never suppressed.

    Same re-entrancy guard as get_type_check_sched.
    """
def get_inference_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    global _typecheck_sched_loading;
    if _typecheck_sched_loading {
        return [];
    }
    _typecheck_sched_loading = True;
    try {
        import from jaclang.compiler.passes.main.type_checker_pass { TypeInferencePass }
        # TypeInferencePass.before_pass needs a fully initialized
        # TypeEvaluator. During bootstrap the evaluator module may be
        # mid-import (partially initialized) while one of its own
        # dependencies compiles — this import raises ImportError in that
        # window, correctly skipping inference for only those bootstrap
        # modules.
        import from jaclang.compiler.type_system.type_evaluator { TypeEvaluator }
        # The evaluator hard-requires the vendored typeshed stubs
        # (builtins.pyi et al. — see TypeEvaluator._load_stub_module).
        # Environments without the typeshed submodule (bare clones,
        # slim docker images, pre-commit.ci) must keep compiling like
        # pre-typed-tree jaclang: skip inference instead of failing
        # every compile with FileNotFoundError.
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
        _typecheck_sched_loading = False;
    }
}

"""Full Python code generation schedule.

    Same re-entrancy guard as get_ir_gen_sched: when compiling the
    pass modules this depends on, falls back to bytecode-only generation.
    """
def get_py_code_gen -> list[type[Transform[uni.Module, uni.Module]]] {
    global _codegen_sched_loading;
    if _codegen_sched_loading or _ir_sched_loading {
        return [PyastGenPass, PyBytecodeGenPass];
    }
    _codegen_sched_loading = True;
    try {
        import from jaclang.compiler.passes.ecmascript { EsastGenPass }
        import from jaclang.compiler.passes.main.pyjac_ast_link_pass {
            PyJacAstLinkPass
        }
        # InteropAnalysis + WalkerEffects were merged into BoundaryAnalysisPass,
        # which now runs once in the shared front-end (get_boundary_analysis_sched)
        # rather than here in codegen.
        passes: list[type[Transform[uni.Module, uni.Module]]] = [EsastGenPass];
        import from jaclang.compiler.passes.native { NaIRGenPass, NativeCompilePass }
        passes.extend([NaIRGenPass, NativeCompilePass]);
        passes.extend([PyastGenPass, PyJacAstLinkPass, PyBytecodeGenPass]);
        return passes;
    } except ImportError {
        return [PyastGenPass, PyBytecodeGenPass];
    } finally {
        _codegen_sched_loading = False;
    }
}

"""Format schedule. If auto_lint=True, includes auto-linting pass.

    Note: Annex modules (.impl.jac, .test.jac) are loaded by the caller
    (jac_file_formatter) via parse-only, NOT through JacAnnexPass which
    triggers cascading compilation of the entire import graph.
    """
def get_format_sched(
    auto_lint: bool = False
) -> list[type[Transform[uni.Module, uni.Module]]] {
    import from jaclang.compiler.passes.tool.comment_injection_pass {
        CommentInjectionPass
    }
    import from jaclang.compiler.passes.tool.doc_ir_gen_pass { DocIRGenPass }
    import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacAutoLintPass }
    import from jaclang.compiler.passes.tool.jac_formatter_pass { JacFormatPass }
    if auto_lint {
        return [JacAutoLintPass, DocIRGenPass, CommentInjectionPass, JacFormatPass];
    } else {
        return [DocIRGenPass, CommentInjectionPass, JacFormatPass];
    }
}

"""Lint-only schedule. Runs lint rules for error reporting without formatting.

    Note: Annex modules are loaded by the caller (jac_file_linter) via
    parse-only to avoid cascading compilation through the import graph.
    """
def get_lint_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacAutoLintPass }
    return [JacAutoLintPass];
}

"""Recursively replace a string in all co_filename fields of marshal bytes.

Used for precompiled bundles: call with (bc, sentinel, real_root) to expand
sentinel paths at load time, or with (bc, real_root, sentinel) to embed
sentinel paths at build time.  Returns raw_bc unchanged on any error.
"""
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

"""Tracks and displays progress during first-run compilation of internal modules."""
obj _SetupProgress {
    has _banner_shown: bool = False,
        _compile_count: int = 0,
        _seen_files: set[str] by postinit,
        _jaclang_root: (str | None) = None;

    def postinit -> None;
    def _get_jaclang_root -> str;
    def _atexit_handler -> None;
    def on_internal_compile(file_path: str) -> None;

    has is_active: bool { getter; }
}

glob setup_progress = _SetupProgress();

"""Coerce a module to a specific code context by unfolding its target block type.

Unfolds elements from `unfold_type` blocks, keeps `skip_types` blocks as-is,
and sets `context` on all remaining ContextAwareNode elements.
"""
def _coerce_module(
    module: uni.Module,
    unfold_type: type,
    skip_types: tuple,
    context: CodeContext,
    skip_token: (Tok | None) = None
) {
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
            if skip_token is not None {
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

"""Coerce a .cl.jac module to client context."""
def _coerce_client_module(module: uni.Module) {
    _coerce_module(
        module,
        unfold_type=uni.ClientBlock,
        skip_types=(uni.ServerBlock, ),
        context=CodeContext.CLIENT,
        skip_token=Tok.KW_SERVER
    );
}

"""Coerce a .sv.jac module to server context."""
def _coerce_server_module(module: uni.Module) {
    _coerce_module(
        module,
        unfold_type=uni.ServerBlock,
        skip_types=(uni.ClientBlock, ),
        context=CodeContext.SERVER
    );
}

"""Coerce a .na.jac module to native context."""
def _coerce_native_module(module: uni.Module) {
    _coerce_module(
        module,
        unfold_type=uni.NativeBlock,
        skip_types=(uni.ServerBlock, uni.ClientBlock),
        context=CodeContext.NATIVE
    );
}

"""Jac Compiler singleton.

    Maintains separate module hub for jaclang.* modules (internal_program)
    vs user modules (target_program passed to methods).
    """
obj JacCompiler {
    with entry {
        _jaclang_root: (str | None) = None;
    }

    has _internal_program: (JacProgram | None) = None;
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

    def get_bytecode(
        full_target: str, target_program: JacProgram
    ) -> (types.CodeType | None);

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

    def _get_precompiled_jir_bytecode(full_target: str) -> (bytes | None);
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

    """Count codegen-blocking errors attributed to a specific module file."""
    static def _count_module_blocking_errors(
        target_program: JacProgram, mod_path: str
    ) -> int;

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
