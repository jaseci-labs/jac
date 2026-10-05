import type from jaclang.runtime.native_library { SharedNativeEngine }
import from jaclang.compiler.driver.pipeline_types { AnalysisFact }
import type from jaclang.compiler.types.stubcat.reader { StubCatalog }
import json;
import marshal;
import os;
import sys;
import types;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.jir {
    SEC_BYTECODE,
    SEC_MTIR,
    SEC_INTEROP,
    SEC_NBITCODE,
    SEC_NOBJ,
    SEC_PLACEMENT,
    SEC_CLIENT,
    SEC_CTDEPS,
    FLAG_CARRIED,
    FLAG_PRECOMPILED,
    carried_module_bytecode,
    ct_deps_section,
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
    CodeGenTarget,
    NativeModuleLayout
}
import from jaclang.compiler.frontend.codeinfo { ClientArtifact, ClientManifest }
import from jaclang.runtime.semantic { info_graph_from_json }
import from jaclang.compiler.driver.unit_products {
    UnitProducts,
    client_artifact_from_json,
    client_artifact_json,
    client_artifact_of,
    definition_deps,
    interop_manifest_of,
    interop_record,
    placement_record,
    unit_products
}
import from jaclang.project.textio { read_file_with_encoding }
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.selfhost { SelfHostCache }
import type from jaclang.compiler.frontend.host { HostServices }
import from jaclang.compiler.driver.session_compile {
    CompileFrame,
    SessionContext,
    SessionHooks
}
import from jaclang.compiler.driver.setup_progress { setup_progress }
import from jaclang.compiler.driver.module_compile { compile_module }
import from jaclang.compiler.driver.pipeline_runner {
    run_utility,
    get_format_sched,
    get_lint_sched
}
import from jaclang.compiler.driver.pipeline_types { UtilityProduct }
import from jaclang.compiler.driver.source_failures {
    CompilerSourceError,
    import_error_re_enters,
    module_scoped_failure_details,
    bootstrap_tier_failure_details,
    note_compiler_source_failure
}

glob COMPILE_GC_THRESHOLDS: tuple[int, int, int] = (5000000, 50, 100),
     CHECK_GC_THRESHOLDS: tuple[int, int, int] = (100000, 10, 10);

def client_dep_digests(manifest: ClientManifest) -> dict[str, str] {
    digests: dict[str, str] = {};
    for dep_path in manifest.imports.values() {
        dep = str(dep_path);
        if not os.path.isfile(dep) {
            continue;
        }
        try {
            digests[dep] = compute_content_sha256(dep);
        } except OSError {
            continue;
        }
    }
    return digests;
}

def stamp_client_artifact(artifact: ClientArtifact) -> ClientArtifact {
    artifact.dep_digests = client_dep_digests(artifact.manifest);
    return artifact;
}

def built_client_artifact(module: uni.Module) -> (ClientArtifact | None) {
    artifact = client_artifact_of(module);
    return stamp_client_artifact(artifact) if artifact is not None else None;
}

def client_artifact_bytes(artifact: ClientArtifact) -> bytes {
    return client_artifact_json(artifact).encode("utf-8");
}

def client_artifact_from_bytes(raw: bytes) -> (ClientArtifact | None) {
    try {
        text = raw.decode("utf-8");
    } except UnicodeDecodeError {
        return None;
    }
    return client_artifact_from_json(text);
}

def assemble_jcir(jcir: bytes) -> (bytes | None) {
    if not jcir {
        return None;
    }
    import from jaclang.compiler.backends.py.codegen_shim { compile_ir }
    result = compile_ir(jcir);
    if result.diags or not result.modules {
        return None;
    }
    return result.modules[0].bytecode;
}

def unit_sections(
    products: UnitProducts, bytecode: (bytes | None)
) -> dict[int, bytes] {
    sections: dict[int, bytes] = {};
    if bytecode is not None {
        sections[SEC_BYTECODE] = bytecode;
    }
    if products.mtir {
        sections[SEC_MTIR] = products.mtir.encode("utf-8");
    }
    if products.interop {
        sections[SEC_INTEROP] = products.interop.encode("utf-8");
    }
    if products.client {
        artifact = client_artifact_from_json(products.client);
        if artifact is not None {
            sections[SEC_CLIENT] = client_artifact_bytes(
                stamp_client_artifact(artifact)
            );
        }
    }
    if products.placement {
        sections[SEC_PLACEMENT] = products.placement.encode("utf-8");
    }
    if products.ct_file_deps or products.ct_body_deps or products.ct_def_deps {
        sections[SEC_CTDEPS] = ct_deps_section(
            products.ct_file_deps,
            products.ct_body_deps,
            definitions=definition_deps(products)
        );
    }
    return sections;
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
        full_target: str, target_program: JacProgram, skip_analysis: bool = False
    ) -> (types.CodeType | None);

    def get_client_artifact(
        full_target: str, target_program: JacProgram
    ) -> (ClientArtifact | None);

    def _get_bytecode(
        full_target: str, target_program: JacProgram, skip_analysis: bool = False
    ) -> (types.CodeType | None);

    def _get_client_artifact(
        full_target: str, target_program: JacProgram
    ) -> (ClientArtifact | None);

    def client_codegen_target(
        full_target: str, target_program: JacProgram
    ) -> (uni.Module | None);

    def ensure_client_codegen(mod: uni.Module, target_program: JacProgram) -> bool;
    def _cached_client_artifact(full_target: str) -> (ClientArtifact | None);
    static def _client_deps_fresh(artifact: ClientArtifact) -> bool;
    def _persist_client_artifact(full_target: str, artifact: ClientArtifact) -> None;
    def _adopt_kernel_compile(
        full_target: str, program: JacProgram, options: CompileOptions
    ) -> tuple[bool, (bytes | None)];

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
    def _restore_native_clibs(
        gen: CodeGenTarget, cached_interop: (dict[str, any] | None)
    ) -> None;

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
    def assemble_python(program: JacProgram, module: uni.Module);
    def assemble_native(program: JacProgram, module: uni.Module, checking: bool);
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
