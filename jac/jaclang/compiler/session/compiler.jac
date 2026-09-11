import from jaclang.compiler.pipeline.contracts { PassIdentity }
import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from jaclang.compiler.pipeline.keys { PLACEMENT_SUMMARY }
import from jaclang.compiler.pipeline.contracts { AnalysisFact }
import type from jaclang.compiler.session.cache.catalog_reader { StubCatalog }
import ast as py_ast;
import marshal;
import os;
import sys;
import types;
import from threading { Event }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.ir.schema { ability_of_symbol }
import from jaclang.compiler.session.cache.artifact_codec {
    SEC_BYTECODE,
    SEC_MTIR,
    SEC_LLVM_IR,
    SEC_INTEROP,
    SEC_NATIVE_OBJ,
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
import from jaclang.compiler.session.options { CompileOptions }
import type from jaclang.compiler.backends.common.artifacts {
    ClientArtifact,
    NativeModuleLayout
}
import from jaclang.compiler.frontend.source_io { read_file_with_encoding }
import from jaclang.compiler.ir.enums { CodeContext }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import from jaclang.compiler.pipeline.pass_base { Transform }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.bootstrap.selfhost { SelfHostCache }
import from jaclang.compiler.pipeline.progress { compile_progress, setup_progress }
import from jaclang.compiler.session.diagnostics { deliver_alerts }
import from jaclang.compiler.pipeline.executor { run_utility }
import from jaclang.compiler.pipeline.contracts { UtilityProduct }
import from jaclang.compiler.pipeline.schedule {
    get_format_sched,
    get_lint_sched,
    native_pipeline_available,
    native_schedule_failure
}
import from jaclang.compiler.bootstrap.source_failures {
    CompilerSourceError,
    import_error_re_enters,
    module_scoped_failure_details,
    bootstrap_tier_failure_details,
    note_compiler_source_failure
}
import from jaclang.compiler.analysis.boundaries.classify {
    ClientImportVerdict,
    _default_codespace_for,
    classify_client_import_item,
    import_declares_native_target,
    is_client_boundary_import,
    is_client_native_edge_import,
    native_only_import_target,
}
import from jaclang.compiler.analysis.placement.native_fallback {
    na_coverage_record,
    na_demotion_note
}

glob COMPILE_GC_THRESHOLDS: tuple[int, int, int] = (100000, 50, 100);

obj JacCompiler {
    has _selfhost: (SelfHostCache | None) = None,
        _reentrant_depth: int = 0,
        _closure_opts: (CompileOptions | None) = None,
        _stub_catalog: StubCatalog | None = None,
        _stub_catalog_tried: bool = False,
        stub_catalog_disabled: bool = False,
        _stub_trees_served: bool = False,
        unit_collect: bool = True;

    has selfhost: SelfHostCache { getter; }

    def stub_catalog -> StubCatalog | None;
    def ensure_stub_catalog -> StubCatalog | None;
    def note_stub_tree_served(path: str, program: JacProgram) -> None;
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
    ) -> (tuple[bytes, bytes] | None);

    def _sealed_jir_data(full_target: str) -> (tuple[bytes, str] | None);
    def parse_str(
        source_str: str,
        file_path: str,
        target_program: JacProgram,
        cancel_token: (Event | None) = None
    ) -> uni.Module;

    def _persist_module_cache(
        full_target: str, result: uni.Module, actual_program: JacProgram
    ) -> None;

    def _release_compile_scratch(target_program: JacProgram) -> None;
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

    def _compile_pipeline(
        file_path: str,
        actual_program: JacProgram,
        use_str: (str | None) = None,
        options: CompileOptions = CompileOptions()
    ) -> uni.Module;

    def build(
        file_path: str, target_program: JacProgram, use_str: (str | None) = None
    ) -> uni.Module;

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
