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
    HEADER_SIZE
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

def get_symtab_ir_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    return [ASTValidationPass, SymTabBuildPass, DeclImplMatchPass];
}

glob _ir_sched_loading = False,
     _codegen_sched_loading = False,
     _typecheck_sched_loading = False;

def get_boundary_analysis_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    return [BoundaryAnalysisPass];
}

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
        import from jaclang.compiler.passes.main.jsx_intrinsic_guard_pass {
            JsxIntrinsicGuardPass
        }

        import jaclang.compiler.symbol_utils;
        import jaclang.compiler.passes.main.layout_pass;

        return [
            ASTValidationPass,
            SymTabBuildPass,
            DeclImplMatchPass,
            SemanticAnalysisPass,
            SemDefMatchPass,
            CFGBuildPass,
            MTIRGenPass,
            CapabilityCheckPass,
            JsxIntrinsicGuardPass
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
        import from jaclang.compiler.passes.main.access_check_pass { AccessCheckPass }
        import from jaclang.compiler.passes.main.capability_check_pass {
            PortabilityWarnPass
        }
        import from jaclang.compiler.passes.tool.jac_auto_lint_pass { JacLintCheckPass }
        return [
            StaticAnalysisPass,
            AccessCheckPass,
            PortabilityWarnPass,
            JacLintCheckPass
        ];
    } except ImportError {
        return [];
    } finally {
        _typecheck_sched_loading = False;
    }
}

def get_inference_sched -> list[type[Transform[uni.Module, uni.Module]]] {
    global _typecheck_sched_loading;
    if _typecheck_sched_loading {
        return [];
    }
    _typecheck_sched_loading = True;
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
        _typecheck_sched_loading = False;
    }
}

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
        _seen_files: set[str] by postinit,
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
