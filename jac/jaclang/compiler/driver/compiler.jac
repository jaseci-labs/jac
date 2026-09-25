import type from jaclang.runtime.native_library { SharedNativeEngine }
import from jaclang.compiler.frontend.roles { Kid }
import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
import type from jaclang.compiler.types.stubcat.reader { StubCatalog }
import ast as py_ast;
import marshal;
import os;
import from collections.abc { Callable }
import sys;
import types;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.unitree { ability_of_symbol }
import from jaclang.compiler.driver.jir {
    SEC_BYTECODE,
    SEC_MTIR,
    SEC_INTEROP,
    SEC_NBITCODE,
    SEC_NIFACE,
    SEC_NOBJ,
    SEC_PLACEMENT,
    SEC_IFACE,
    SEC_CLIENT,
    FLAG_PRECOMPILED,
    compute_content_sha256,
    get_module_cache_path,
    is_module_cache_valid,
    precompiled_jir_matches_source,
    cache_mode,
    read_bytecode_only,
    read_section_bytes,
    read_sections,
    patch_co_filenames_bytes,
    write_module_cache,
    SECTIONS_MAGIC,
    HEADER_SIZE
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import type from jaclang.compiler.frontend.codeinfo {
    ClientArtifact,
    CodeGenTarget,
    NativeModuleLayout
}
import from jaclang.project.textio { read_file_with_encoding }
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import from jaclang.compiler.passes.boundary_analysis_pass { BoundaryAnalysisPass }
import from jaclang.compiler.passes.semantic_analysis_pass { SemanticAnalysisPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.selfhost { SelfHostCache }
import type from jaclang.compiler.frontend.host { HostServices }
import from jaclang.compiler.driver.session_compile {
    CompileFrame,
    SessionContext,
    SessionHooks
}
import from jaclang.compiler.driver.pass_driver {
    build_diagnostic_policy,
    compile_progress,
    deliver_alerts,
    run_pass
}
import from jaclang.compiler.driver.setup_progress { setup_progress }
import from jaclang.compiler.driver.pipeline {
    get_analysis_sched,
    get_boundary_analysis_sched,
    get_ir_gen_sched,
    get_symtab_ir_sched,
    providers_of,
    pass_provides,
    validate_schedule
}
import from jaclang.compiler.driver.pipeline_runner {
    run_utility,
    get_format_sched,
    get_lint_sched
}
import from jaclang.compiler.driver.pipeline_types { UtilityProduct }
import from jaclang.compiler.driver.pipeline_runner {
    get_py_code_gen,
    native_schedule_failure
}
import from jaclang.compiler.driver.toolchain { native_pipeline_available }
import from jaclang.compiler.driver.source_failures {
    CompilerSourceError,
    import_error_re_enters,
    module_import_in_flight,
    module_scoped_failure_details,
    bootstrap_tier_failure_details,
    note_compiler_source_failure
}
import from jaclang.compiler.driver.boundary_classify {
    ClientImportVerdict,
    _coerce_client_module,
    _coerce_native_module,
    _default_codespace_for,
    classify_client_import_item,
    import_declares_native_target,
    is_client_boundary_import,
    is_client_native_edge_import,
    native_only_import_target,
    symbol_linked_source_module
}

glob COMPILE_GC_THRESHOLDS: tuple[int, int, int] = (5000000, 50, 100),
     CHECK_GC_THRESHOLDS: tuple[int, int, int] = (100000, 10, 10),
     CLIENT_SECTION_VERSION: int = 3;

def client_artifact_bytes(artifact: ClientArtifact) -> bytes {
    import pickle;
    return pickle.dumps(
        (
            CLIENT_SECTION_VERSION,
            artifact.js,
            artifact.manifest,
            list(artifact.native_import_sources),
            list(artifact.source_map),
            dict(artifact.dep_digests),
            artifact.framework,
            artifact.boundary_contracts
        ),
        int(pickle.HIGHEST_PROTOCOL)
    );
}

def client_artifact_from_bytes(raw: bytes) -> (ClientArtifact | None) {
    import pickle;
    import from jaclang.compiler.frontend.codeinfo {
        ClientArtifact as _ClientArtifact,
        ClientManifest
    }
    try {
        (
            version,
            js,
            manifest,
            native_import_sources,
            source_map,
            dep_digests,
            framework,
            boundary_contracts
        ) = pickle.loads(raw);
    } except Exception {
        return None;
    }
    if version != CLIENT_SECTION_VERSION
        or not isinstance(js, str)
        or not isinstance(manifest, ClientManifest) {
        return None;
    }
    return _ClientArtifact(
        js=js,
        manifest=manifest,
        native_import_sources=[str(s) for s in native_import_sources],
        source_map=[tuple(seg) for seg in source_map],
        dep_digests={
            str(k): str(v) for (k, v) in dict[object, object](dep_digests).items()
        },
        framework=str(framework),
        boundary_contracts=dict(boundary_contracts)
    );
}

obj HostCompileFrame(CompileFrame) {
    has depth_prev: int = 0,
        gc_prev: (tuple[int, int, int] | None) = None,
        retain_selfhost: bool = False,
        session_host: (HostServices | None) = None;
}

obj JacCompiler(SessionHooks) {
    has _selfhost: (SelfHostCache | None) = None,
        _reentrant_depth: int = 0,
        _closure_opts: (CompileOptions | None) = None,
        _stub_catalog: StubCatalog | None = None,
        _stub_catalog_tried: bool = False,
        stub_catalog_disabled: bool = False,
        unit_collect: bool = True;

    has selfhost: SelfHostCache { getter; }

    def release_compile_state(target_program: JacProgram) -> None;
    def stub_catalog -> StubCatalog | None;
    def ensure_stub_catalog -> StubCatalog | None;
    def product_program(
        full_target: str, target_program: JacProgram, execution: bool = False
    ) -> JacProgram;

    def get_native_interop_setup(
        full_target: str, target_program: JacProgram
    ) -> tuple[((object | None), (dict[(str, object)] | None))];

    def get_native_layout(
        full_target: str, target_program: JacProgram
    ) -> (NativeModuleLayout | None);

    static def _check_native_abi(layout: NativeModuleLayout, full_target: str) -> None;
    def get_bytecode(
        full_target: str, target_program: JacProgram
    ) -> (types.CodeType | None);

    def get_client_artifact(
        full_target: str, target_program: JacProgram
    ) -> (ClientArtifact | None);

    def _get_bytecode(
        full_target: str, target_program: JacProgram
    ) -> (types.CodeType | None);

    def _get_client_artifact(
        full_target: str, target_program: JacProgram
    ) -> (ClientArtifact | None);

    def client_codegen_target(
        full_target: str, target_program: JacProgram
    ) -> (uni.Module | None);

    def ensure_client_codegen(mod: uni.Module, target_program: JacProgram) -> bool;
    def client_artifact_of(mod: uni.Module) -> (ClientArtifact | None);
    def _cached_client_artifact(full_target: str) -> (ClientArtifact | None);
    static def _client_deps_fresh(artifact: ClientArtifact) -> bool;
    def _persist_client_artifact(full_target: str, artifact: ClientArtifact) -> None;
    def _wants_native_engine(full_target: str, program: JacProgram) -> bool;
    def _load_native_from_cache(
        full_target: str,
        target_program: JacProgram,
        cached_interop: (dict[str, any] | None)
    ) -> None;

    def _sealed_native_engine(full_target: str) -> (SharedNativeEngine | None);
    def _restore_sections(
        full_target: str,
        actual_program: JacProgram,
        secs: dict[int, bytes],
        base_dir: str = ""
    ) -> None;

    def _get_precompiled_jir_bytecode(
        full_target: str, allow_unsealed: bool = True
    ) -> (tuple[bytes, bytes] | None);

    def _sealed_jir_data(full_target: str) -> (tuple[bytes, str] | None);
    def _precompiled_jir_data(full_target: str) -> (tuple[bytes, str] | None);
    def _build_interop_dict(result: uni.Module) -> dict[str, any];
    def _restore_native_clibs(
        gen: CodeGenTarget, cached_interop: (dict[str, any] | None)
    ) -> None;

    def _deserialize_interop_table(cached_interop: dict[str, any]) -> InteropManifest;
    def _persist_module_cache(
        full_target: str, result: uni.Module, actual_program: JacProgram
    ) -> None;

    def _persist_native_unit(
        full_target: str, result: uni.Module, actual_program: JacProgram
    ) -> None;

    def _release_compile_scratch(target_program: JacProgram) -> None;
    def compile(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None) = None,
        options: CompileOptions = CompileOptions()
    ) -> uni.Module;

    def enter_compile(ctx: SessionContext) -> CompileFrame;
    def leave_compile(ctx: SessionContext, frame: CompileFrame);
    def finish_compile(frame: CompileFrame);
    def check_crash(crash: Exception, file_path: str);
    def closure_options -> (CompileOptions | None);
    def run_module(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None),
        options: CompileOptions
    ) -> uni.Module;

    def _compile_pipeline(
        file_path: str,
        actual_program: JacProgram,
        use_str: (str | None) = None,
        options: CompileOptions = CompileOptions()
    ) -> uni.Module;

    def build(
        file_path: str, target_program: JacProgram, use_str: (str | None) = None
    ) -> uni.Module;

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
