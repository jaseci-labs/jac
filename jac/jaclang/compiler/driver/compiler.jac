import ast as py_ast;
import marshal;
import os;
import sys;
import types;
import from threading { Event }
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
import type from jaclang.compiler.frontend.codeinfo { ClientArtifact }
import from jaclang.compiler.frontend.helpers { read_file_with_encoding }
import from jaclang.compiler.frontend.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.backends.py.jcir_gen_pass { JcirGenPass }
import from jaclang.compiler.passes.boundary_analysis_pass { BoundaryAnalysisPass }
import from jaclang.compiler.passes.semantic_analysis_pass { SemanticAnalysisPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.selfhost { SelfHostCache }
import from jaclang.compiler.driver.pass_driver {
    build_diagnostic_policy,
    compile_progress,
    deliver_alerts,
    run_pass,
    setup_progress
}
import from jaclang.compiler.driver.schedules {
    _jsx_intrinsic_guard_pass_type,
    get_analysis_sched,
    get_boundary_analysis_sched,
    get_format_sched,
    get_ir_gen_sched,
    get_lint_sched,
    get_py_code_gen,
    get_symtab_ir_sched,
    native_pipeline_available,
    native_schedule_failure,
    providers_of,
    validate_schedule
}
import from jaclang.compiler.driver.source_failures {
    CompilerSourceError,
    import_error_re_enters,
    module_import_in_flight,
    module_scoped_failure_details,
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
import from jaclang.compiler.driver.na_coverage {
    _drop_demoted_native_bindings,
    na_coverage_record,
    na_demotion_note
}

glob COMPILE_GC_THRESHOLDS: tuple[int, int, int] = (100000, 50, 100);

obj JacCompiler {
    has _selfhost: (SelfHostCache | None) = None,
        _reentrant_depth: int = 0,
        _closure_opts: (CompileOptions | None) = None,
        _stub_catalog: any = None,
        _stub_catalog_tried: bool = False,
        stub_catalog_disabled: bool = False,
        _stub_trees_served: bool = False,
        unit_collect: bool = True;

    has selfhost: SelfHostCache { getter; }

    def stub_catalog -> any;
    def ensure_stub_catalog -> any;
    def note_stub_tree_served(path: str, program: JacProgram) -> None;
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

    def get_client_artifact(
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
        cached_interop: (dict[str, any] | None)
    ) -> None;

    def _sealed_native_engine(full_target: str) -> (object | None);

    def _restore_sections(
        full_target: str, actual_program: JacProgram, secs: dict[int, bytes]
    ) -> None;

    def _get_precompiled_jir_bytecode(
        full_target: str, allow_unsealed: bool = True
    ) -> (tuple[bytes, bytes] | None);

    def _sealed_jir_data(full_target: str) -> (tuple[bytes, str] | None);
    def _build_interop_dict(result: uni.Module) -> dict;
    def _deserialize_interop_table(cached_interop: dict[str, any]) -> InteropManifest;
    def parse_str(
        source_str: str,
        file_path: str,
        target_program: JacProgram,
        cancel_token: (Event | None) = None
    ) -> uni.Module;

    def resolve_absorb_imports(mod: uni.Module, target_program: JacProgram) -> None;
    def stamp_boundary_facts(mod: uni.Module, target_program: JacProgram) -> None;
    def stamp_client_kind_facts(mod: uni.Module, target_program: JacProgram) -> None;
    def stamp_access_check_facts(mod: uni.Module) -> None;
    def stamp_native_import_facts(mod: uni.Module, target_program: JacProgram) -> None;
    def _persist_module_cache(
        full_target: str, result: uni.Module, actual_program: JacProgram
    ) -> None;

    def _native_sections(
        full_target: str, result: uni.Module, actual_program: JacProgram
    ) -> dict[int, bytes];

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

    def _compile_once(
        file_path: str,
        target_program: JacProgram,
        use_str: (str | None) = None,
        options: CompileOptions = CompileOptions()
    ) -> uni.Module;

    def _ingest_comptime_producers(
        mod_targ: uni.Module, actual_program: JacProgram, file_path: str
    ) -> None;

    def _compile_pipeline(
        file_path: str,
        actual_program: JacProgram,
        use_str: (str | None) = None,
        options: CompileOptions = CompileOptions()
    ) -> uni.Module;

    def build(
        file_path: str, target_program: JacProgram, use_str: (str | None) = None
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
