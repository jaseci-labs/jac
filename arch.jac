impl import {
    edge JaclangFlows: jaclang.* --> any;
}

impl import {
    jaclang --> jaclang.byllm.tests.support { JacRuntimeInterface as Jac }
    jaclang --> jaclang.byllm.tests.test_byllm { JacRuntimeInterface as Jac }
    jaclang --> jaclang.byllm.tests.test_mtir_integration { JacRuntime }
    jaclang --> jaclang.byllm.tests.test_prompting { JacRuntimeInterface as Jac }
    jaclang --> jaclang.byllm.tests.test_routing { JacRuntimeInterface as Jac }
    jaclang --> jaclang.cli.commands.analysis.grammar;
    jaclang --> jaclang.cli.commands.native_build._floor_ca_bundle;
    jaclang --> jaclang.cli.commands.project._resolve_bundled_template;
    jaclang --> jaclang.cli.guide_store.docs_dir;
    jaclang --> jaclang.cli.guide_store.guides_dir;
    jaclang --> jaclang.cli.manifest_route;
    jaclang --> jaclang.cli.mcp.resources.ResourceProvider._index_grammar;
    jaclang --> jaclang.client.jac_client_compiler.JacClientCompiler.compile_pwa_runtime;
    jaclang --> jaclang.client.targets.client_dev_common.invalidate_runtime_module_cache {
        JacRuntime as Jac
    }
    jaclang --> jaclang.client.targets.desktop.desktop_build._fused_runtime_dir;
    jaclang --> jaclang.client.targets.desktop.desktop_build._jaclang_src_roots;
    jaclang --> jaclang.client.targets.desktop.native.host_boot._bootstrap_plugin_host;
    jaclang --> jaclang.compiler.backends.es.free_ident_audit.client_ambient_globals;
    jaclang --> jaclang.compiler.backends.native.floor.floor_lib_dir;
    jaclang --> jaclang.compiler.backends.native.static_link.musl_lib_dir;
    jaclang --> jaclang.compiler.backends.native.wasm_build._wasm_libc_dir;
    jaclang --> jaclang.compiler.driver.boundary_classify.plain_native_import_target;
    jaclang --> jaclang.compiler.driver.pass_driver._SetupProgress._get_jaclang_root;
    jaclang --> jaclang.compiler.driver.pipeline.typeshed_stubs_available;
    jaclang --> jaclang.compiler.driver.selfhost.SelfHostCache.jaclang_root;
    jaclang --> jaclang.compiler.driver.source_failures._compiler_source_root;
    jaclang --> jaclang.compiler.driver.wiring.compiled_by_seed;
    jaclang --> jaclang.compiler.driver.wiring.compiled_by_seed { bootstrap_manifest }
    jaclang --> jaclang.compiler.frontend.codeinfo.bundled_stdlib_module_of;
    jaclang --> jaclang.compiler.frontend.codeinfo.is_client_by_location;
    jaclang --> jaclang.compiler.frontend.codeinfo.is_native_by_location;
    jaclang --> jaclang.compiler.frontend.codeinfo.is_shared_runtime_module;
    jaclang --> jaclang.compiler.frontend.codeinfo.jaclang_pkg_root;
    jaclang --> jaclang.compiler.frontend.codeinfo.native_stdlib_root;
    jaclang --> jaclang.compiler.frontend.codeinfo.native_toolchain_roots;
    jaclang --> jaclang.compiler.passes.mtir_gen_pass { JacRuntime as Jac }
    jaclang as _jl --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._nogc_resolve_provenance;
    jaclang --> jaclang.compiler.tests.test_batch_decl_identity;
    jaclang --> jaclang.compiler.tests.test_global_narrowing;
    jaclang --> jaclang.compiler.tests.test_jac_mobui_typing;
    jaclang --> jaclang.compiler.tests.test_osp_equivalence;
    jaclang --> jaclang.compiler.tests.xbackend_equiv;
    jaclang --> jaclang.compiler.types.stubcat.locate.jaclang_pkg_dir;
    jaclang --> jaclang.data.serializer.Serializer._deserialize_jac_ref {
        JacRuntimeInterface as Jac
    }
    jaclang --> jaclang.data.serializer.Serializer._serialize_value {
        JacRuntimeInterface as Jac
    }
    jaclang --> jaclang.dist.publish.runtime_npm;
    jaclang --> jaclang.dist.publish.runtime_npm._collect_dep_modules;
    jaclang --> jaclang.dist.publish.runtime_npm.build_runtime_tarball;
    jaclang --> jaclang.dist.publish.runtime_vendor._pkg_root;
    jaclang --> jaclang.lsp.server.engine { JacRuntimeInterface as Jac }
    jaclang --> jaclang.lsp.server.sem_manager { JacRuntimeInterface as Jac }
    jaclang --> jaclang.project.modresolver.get_typeshed_paths;
    jaclang --> jaclang.runtime.archetype.Anchor.populate { JacRuntimeInterface as Jac }
    jaclang --> jaclang.runtime.archetype.Archetype.__init_subclass__ {
        JacRuntimeInterface as _
    }
    jaclang --> jaclang.runtime.archetype._dirty_setattr { JacRuntimeInterface }
    type jaclang --> jaclang.runtime.builtin { JacRuntimeInterface }
    jaclang --> jaclang.runtime.builtin._get_jac { JacRuntimeInterface }
    jaclang --> jaclang.runtime.builtin.restspec { JacRuntimeInterface as Jac }
    jaclang --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.service_base_url;
    jaclang --> jaclang.scale.runtime.rpc.rpc._provider_url;
    jaclang --> jaclang.scale.scheduler.scheduler.JacScaleScheduler._execute_task._run {
        JacRuntime as Jac
    }
    jaclang --> jaclang.scale.server.inprocess { JacRuntime as Jac }
    jaclang --> jaclang.scale.tests.data.test_eager_spawn { JacRuntime as Jac }
    jaclang --> jaclang.scale.tests.deploy.test_database_intent;
    jaclang --> jaclang.scale.tests.microservices.test_gateway;
    jaclang --> jaclang.scale.tests.microservices.test_microservice {
        JacRuntime as Jac
    }
    jaclang --> jaclang.scale.tests.microservices.test_seed_determinism;
    jaclang --> jaclang.scale.tests.microservices.test_typed_boundary;
    jaclang --> jaclang.scale.tests.server.test_host_serving { JacRuntime as Jac }
    jaclang --> jaclang.scale.tests.server.test_served_app_route { JacRuntime as Jac }
    jaclang --> jaclang.scale.tests.server.test_sv_outbox_endpoints {
        JacRuntime as Jac
    }
    jaclang --> jaclang.server.identity.identity_storage.IdentityStorage.create_user {
        JacRuntime as Jac
    }
    jaclang --> jaclang.server.identity.identity_storage.IdentityStorage.ensure_user_by_id {
        JacRuntime as Jac
    }
    jaclang --> jaclang.server.identity.identity_storage.IdentityStorage.reset_root {
        JacRuntime as Jac
    }
    jaclang --> jaclang.server.outbox._current_memory { JacRuntime }
    jaclang --> jaclang.server.outbox.outbox_db_path { JacRuntime }
    jaclang --> jaclang.server.server { JacRuntime as Jac }
    jaclang --> jaclang.server.session.Session._flush_locked {
        JacRuntimeInterface as JacRI
    }
    jaclang --> jaclang.server.sv_client._local_spawn { JacRuntime }
    jaclang --> jaclang.server.task_scheduler.Scheduler._execute {
        JacRuntimeInterface as Jac
    }
    jaclang --> jaclang.testing.testing { JacRuntime as Jac }
    jaclang --> jaclang.compiler.frontend.codeinfo._jaclang_pkg_dir;
}

impl import jaclang {
    bootstrap_manifest --> jaclang.compiler.driver.jir {
        COMPILER_DIGEST_ROOTS,
        COMPILER_IDENTITY_NAME,
        NATIVE_LOWERED_PATHS,
        is_native_lowered,
        is_roster_input
    }
    bootstrap_manifest --> jaclang.compiler.passes.static_analysis_pass.is_bootstrap_compiled_module {
        is_seed_source
    }
    bootstrap_manifest --> jaclang.compiler.placement.placement_facts.native_only {
        is_native_only
    }
    bootstrap_manifest --> jaclang.dist.payload.fsutil.skip_jaclang {
        is_native_lowered
    }
    bootstrap_manifest --> jaclang.dist.precompile_bytecode.find_jac_files {
        is_native_lowered
    }
    bootstrap_manifest --> jaclang.dist.precompile_bytecode.seal_bootstrap {
        is_native_only,
        seed_abs_entries
    }
    bootstrap_manifest --> jaclang.dist.precompile_bytecode.seal_finalize {
        is_native_only,
        is_seed_source
    }
    bootstrap_manifest --> jaclang.dist.precompile_bytecode.sealable_sources {
        is_seed_source
    }
    bootstrap_manifest --> jaclang.dist.publish.runtime_vendor._compile_runtime_module {
        is_seed_source
    }
    client --> jaclang.client.npm_provider.regenerate_and_install { get_bun }
    client as _client_pkg --> jaclang.client.runtime_source.resolve_client_runtime_cl_path;
    client --> jaclang.client.targets.node_tooling_common { get_bun }
    client --> jaclang.client.vite_bundler { get_bun }
    client --> jaclang.client.vite_bundler.ViteBundler.add_packages { get_bun }
    client --> jaclang.client.vite_bundler.ViteBundler.build { ensure_client_deps }
    client --> jaclang.client.vite_bundler.ViteBundler.start_dev_server { get_bun }
    client --> jaclang.dist.seal.ensure_client_dist { get_bun }
    client as _client_pkg --> jaclang.project.modresolver._resolve_jac_virtual_module;
    compiler --> jaclang.cli.commands.analysis.gen_parser { gen_all_parsers }
    comptime --> jaclang.byllm.cli { name as ct_name }
    comptime --> jaclang.cli.commands.analysis { name as ct_name }
    comptime --> jaclang.cli.commands.arch { name as ct_name }
    comptime --> jaclang.cli.commands.browse { name as ct_name }
    comptime --> jaclang.cli.commands.build { name as ct_name }
    comptime --> jaclang.cli.commands.cache { name as ct_name }
    comptime --> jaclang.cli.commands.code { name as ct_name }
    comptime --> jaclang.cli.commands.config { name as ct_name }
    comptime --> jaclang.cli.commands.db { name as ct_name }
    comptime --> jaclang.cli.commands.execution { name as ct_name }
    comptime --> jaclang.cli.commands.fix { name as ct_name }
    comptime --> jaclang.cli.commands.guide { name as ct_name }
    comptime --> jaclang.cli.commands.mcp { name as ct_name }
    comptime --> jaclang.cli.commands.precompile { name as ct_name }
    comptime --> jaclang.cli.commands.project { name as ct_name }
    comptime --> jaclang.cli.commands.tools { name as ct_name }
    comptime --> jaclang.cli.manifest { module_of }
    comptime --> jaclang.cli.shadcn.cli { name as ct_name }
    comptime --> jaclang.client.cli { name as ct_name }
    comptime --> jaclang.client.desktop_config { fields, get_field }
    comptime --> jaclang.scale.config.base_config { fields, get_field }
    comptime --> jaclang.scale.deploy.target.kubernetes.kubernetes_config {
        fields,
        get_field
    }
    comptime --> jaclang.scale.plugin { name as ct_name }
    comptime --> jaclang.scale.scheduler.scheduler { fields, get_field }
    comptime --> jaclang.scale.scheduler.scheduler_models { fields }
    comptime --> jaclang.scale.tests.misc.test_config_loader { fields }
    comptime --> jaclang.scale.tests.misc.test_config_validation { fields }
    comptime --> jaclang.server.identity.auth_models { fields }
    jac0 --> jaclang.dist.precompile_bytecode.seal_bootstrap {
        compile_jac as jac0_compile,
        discover_impl_files as jac0_impls
    }
    jac0 --> jaclang.dist.publish.runtime_vendor._compile_runtime_module {
        compile_jac,
        discover_impl_files
    }
    jac0core --> jaclang.compiler.backends.native.kernel_resolve._from_sealed_image {
        sealed
    }
    jac0core --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._walk_imported_module_abilities {
        sealed as _wl_sealed
    }
    jac0core --> jaclang.compiler.driver.compiler.JacCompiler._get_precompiled_jir_bytecode {
        sealed as _sealed
    }
    jac0core --> jaclang.compiler.driver.compiler.JacCompiler._sealed_jir_data {
        sealed as _sealed
    }
    jac0core --> jaclang.compiler.driver.compiler.JacCompiler._sealed_native_engine {
        sealed as _sealed
    }
    jac0core --> jaclang.dist.precompile_bytecode { ext_registry }
    jac0core --> jaclang.dist.seal.make_sealed_image { ext_registry }
    meta_importer --> jaclang.client.targets.desktop.native.host_boot._ensure_jac_meta_importer {
        JacMetaImporter
    }
    project --> jaclang.cli.commands.native_build.native_build { get_config }
    project --> jaclang.compiler.backends.native.wasm_build._project_gc_settings {
        get_config
    }
    project --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._nogc_module_enforced {
        get_config
    }
    project --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._nogc_resolve_provenance {
        get_config
    }
    scale as scale_mod --> jaclang.server.endpoints.pages.register_graph_endpoints.graph_page;
}

impl import jaclang.byllm {
    comptime cli --> jaclang.cli.manifest { SPEC_MODEL }
    config_loader --> jaclang.byllm.llm { get_byllm_config }
    config_loader --> jaclang.byllm.mtir { get_byllm_config }
    config_loader --> jaclang.byllm.tests.test_byllm {
        JacByllmConfig,
        get_byllm_config,
        reset_byllm_config
    }
    config_loader --> jaclang.byllm.tests.test_compaction {
        get_byllm_config,
        reset_byllm_config
    }
    config_loader --> jaclang.byllm.tests.test_parallel {
        get_byllm_config,
        reset_byllm_config
    }
    config_loader --> jaclang.byllm.tests.test_typed_retry {
        get_byllm_config,
        reset_byllm_config
    }
    config_loader --> jaclang.byllm.tests.test_usage { JacByllmConfig }
    config_loader --> jaclang.runtime.runtime.JacLLM.default_llm { get_byllm_config }
    exceptions --> jaclang.byllm.lib {
        AuthenticationError,
        ByLLMError,
        ConfigurationError,
        FinishToolError,
        McpError,
        ModelNotFoundError,
        OutputConversionError,
        RateLimitError
    }
    exceptions --> jaclang.byllm.llm {
        AuthenticationError,
        CompactionNotEffectiveError,
        ConfigurationError,
        FinishToolError,
        ModelNotFoundError,
        OutputConversionError,
        RateLimitError
    }
    exceptions --> jaclang.byllm.mcp { McpError }
    exceptions --> jaclang.byllm.mtir { ConfigurationError, OutputConversionError }
    exceptions --> jaclang.byllm.schema { ConfigurationError }
    exceptions --> jaclang.byllm.tests.test_byllm {
        AuthenticationError,
        ConfigurationError,
        FinishToolError,
        McpError,
        ModelNotFoundError,
        OutputConversionError,
        RateLimitError
    }
    exceptions --> jaclang.byllm.tests.test_compaction {
        CompactionNotEffectiveError,
        ConfigurationError
    }
    exceptions --> jaclang.byllm.tests.test_mockllm { OutputConversionError }
    exceptions --> jaclang.byllm.tests.test_streaming { ConfigurationError }
    exceptions --> jaclang.byllm.tests.test_tool_arg_streaming {
        FinishToolError,
        OutputConversionError
    }
    exceptions --> jaclang.byllm.types { ByLLMError, FinishToolError }
    exceptions --> jaclang.runtime.runtime.JacLLM.default_llm { ConfigurationError }
    lib --> jaclang.byllm.tests.fixtures.async_by_llm { Model }
    lib --> jaclang.byllm.tests.fixtures.basic { MockLLM }
    lib --> jaclang.byllm.tests.fixtures.basic_compile { MockLLM }
    lib --> jaclang.byllm.tests.fixtures.enum_no_value { Model }
    lib --> jaclang.byllm.tests.fixtures.enum_with_semstr { Model }
    lib --> jaclang.byllm.tests.fixtures.import_dir.importable_schema { MockLLM }
    lib --> jaclang.byllm.tests.fixtures.proj { MockLLM }
    lib --> jaclang.byllm.tests.fixtures.scope_dir.module_alpha { MockLLM }
    lib --> jaclang.byllm.tests.fixtures.scope_dir.module_beta { MockLLM }
    lib --> jaclang.byllm.tests.fixtures.test_schema { Model }
    lib --> jaclang.byllm.tests.fixtures.tool_function { MockLLM, MockToolCall }
    lib --> jaclang.byllm.tests.fixtures.tool_method { MockLLM, MockToolCall }
    lib --> jaclang.byllm.tests.support {
        MockError,
        MockLLM,
        MockRawResponse,
        MockToolCall
    }
    lib --> jaclang.byllm.tests.test_byllm { Image, MockLLM, Model, ModelPool, Video }
    lib --> jaclang.byllm.tests.test_compaction { MockLLM, Model, ModelPool }
    lib --> jaclang.byllm.tests.test_conversation { MockLLM }
    lib --> jaclang.byllm.tests.test_media { ConfigurationError, Image, MockLLM, Video }
    lib --> jaclang.byllm.tests.test_mockllm {
        MockError,
        MockLLM,
        MockRawResponse,
        MockToolCall,
        Model,
        StreamEvent
    }
    lib --> jaclang.byllm.tests.test_model_pool { Model, ModelPool }
    lib --> jaclang.byllm.tests.test_parallel { Model }
    lib --> jaclang.byllm.tests.test_prompting { MockLLM }
    lib --> jaclang.byllm.tests.test_streaming { MockLLM, Model }
    lib --> jaclang.byllm.tests.test_tool_arg_streaming {
        MockLLM,
        MockRawResponse,
        MockToolCall
    }
    lib --> jaclang.byllm.tests.test_tools { MockLLM }
    lib --> jaclang.byllm.tests.test_truncated_tool_calls { Model }
    lib --> jaclang.byllm.tests.test_typed_retry { MockLLM }
    lib --> jaclang.byllm.tests.test_usage { MockLLM, Model }
    lib --> jaclang.byllm.tests.validate_schema { Model }
    llm --> jaclang.byllm.lib { MockLLM, Model, ModelPool }
    llm --> jaclang.byllm.tests.fixtures.async_stream_by_llm { BaseLLM }
    llm --> jaclang.byllm.tests.support { BaseLLM }
    llm as _byllm_llm_mod --> jaclang.byllm.tests.test_byllm;
    llm --> jaclang.byllm.tests.test_byllm {
        _CACHE_CONTROL_EPHEMERAL,
        _apply_prompt_caching,
        _is_prompt_caching_eligible
    }
    llm as _byllm_llm_mod --> jaclang.byllm.tests.test_compaction;
    llm --> jaclang.byllm.tests.test_compaction { BaseLLM, LocalLLM }
    llm --> jaclang.byllm.tests.test_parallel { BaseLLM }
    llm as _byllm_llm_mod --> jaclang.byllm.tests.test_telemetry_;
    llm as _byllm_llm_mod --> jaclang.byllm.tests.test_tool_arg_streaming;
    llm as _byllm_llm_mod --> jaclang.byllm.tests.test_usage;
    llm --> jaclang.byllm.visit_routing { BaseLLM }
    llm --> jaclang.runtime.runtime.JacLLM.by_operator { BaseLLM }
    llm --> jaclang.runtime.runtime.JacLLM.default_llm { Model }
    local_runtime --> jaclang.byllm.cli._cmd_model { LOCAL_MODELS, list_local_aliases }
    local_runtime --> jaclang.byllm.llm {
        LOCAL_MODELS,
        filter_params,
        list_local_aliases,
        parse_alias,
        wrap_tool_call
    }
    mcp --> jaclang.byllm.lib | jaclang.byllm.tests.test_byllm { McpClient, McpTool }
    mcp --> jaclang.byllm.mtir | jaclang.byllm.types { McpTool }
    model_cache --> jaclang.byllm.cli._cmd_model {
        ensure_model,
        force_pull,
        get_cache_dir,
        is_downloaded,
        list_downloaded,
        remove_alias
    }
    model_cache --> jaclang.byllm.llm { ensure_model }
    mtir --> jaclang.byllm.lib | jaclang.byllm.tests.test_telemetry_ { MTIR, MTRuntime }
    mtir --> jaclang.byllm.llm { MTRuntime }
    type mtir --> jaclang.byllm.telemetry | jaclang.runtime.runtime { MTRuntime }
    mtir --> jaclang.byllm.tests.support { MTRuntime }
    mtir --> jaclang.byllm.tests.test_byllm { MTRuntime }
    mtir --> jaclang.byllm.tests.test_usage { MTRuntime }
    mtir --> jaclang.byllm.visit_routing.route_visit { MTRuntime }
    mtir --> jaclang.runtime.runtime.JacLLM.by._decorator._wrapped_caller { MTIR }
    mtir --> jaclang.runtime.runtime.JacLLM.get_mtir { MTIR }
    parallel --> jaclang.byllm.lib { dispatch_batch, mark_serialize }
    parallel --> jaclang.byllm.llm {
        _PARALLEL_TOOL_HINT,
        _index_by_identity,
        dispatch_batch
    }
    parallel --> jaclang.byllm.tests.test_parallel {
        _PARALLEL_TOOL_HINT,
        _WORKER_POOL,
        _index_by_identity,
        _is_async,
        dispatch_batch,
        mark_serialize
    }
    schema --> jaclang.byllm.llm { inject_schema_hint }
    schema --> jaclang.byllm.mtir { json_to_instance, type_to_schema }
    schema as schema --> jaclang.byllm.tests.test_mtir_integration;
    schema --> jaclang.byllm.types { tool_to_schema }
    telemetry --> jaclang.byllm.lib { register_agent_callback }
    telemetry --> jaclang.byllm.llm {
        _aggregate_usage,
        _current_invocation_id,
        _emit_agent_telemetry
    }
    telemetry --> jaclang.byllm.tests.test_streaming { _current_invocation_id }
    telemetry --> jaclang.byllm.tests.test_telemetry_ {
        _agent_callbacks,
        _current_invocation_id,
        _emit_agent_telemetry,
        register_agent_callback
    }
    telemetry --> jaclang.byllm.tests.test_usage {
        _agent_callbacks,
        register_agent_callback
    }
    telemetry --> jaclang.scale.admin.llm_telemetry.JacAPIServerLLMTelemetry.register_llm_telemetry_endpoints {
        register_agent_callback
    }
    tool_protocol --> jaclang.byllm.llm {
        coerce_message_dict,
        inject_tool_hint,
        recover_tool_calls,
        response_field
    }
    tool_protocol --> jaclang.byllm.tests.test_byllm {
        linearize_tool_messages,
        recover_tool_calls
    }
    types --> jaclang.byllm.lib {
        Image,
        IterationAction,
        IterationContext,
        Message,
        MessageRole,
        MockError,
        MockRawResponse,
        MockToolCall,
        StreamEvent,
        Tool,
        ToolCallResultMsg,
        Video
    }
    types --> jaclang.byllm.llm {
        CompletionResult,
        Image,
        IterationAction,
        IterationContext,
        LiteLLMMessage,
        Message,
        MessageRole,
        MockError,
        MockRawResponse,
        MockToolCall,
        StreamEvent,
        Tool,
        ToolCall,
        content_preview,
        image_resp_kind,
        reroute_tool_images_to_user_message,
        response_dict
    }
    types --> jaclang.byllm.mtir {
        LiteLLMMessage,
        Media,
        Message,
        MessageRole,
        MessageType,
        Text,
        Tool,
        ToolCallResultMsg,
        image_resp_kind
    }
    types --> jaclang.byllm.parallel { ToolCallResultMsg, normalize_tool_result }
    types --> jaclang.byllm.tests.support { Message, MessageRole, StreamEvent, Tool }
    types --> jaclang.byllm.tests.test_byllm { Message, MessageRole, Tool }
    types --> jaclang.byllm.tests.test_compaction { MockToolCall }
    types --> jaclang.byllm.tests.test_conversation { Message, MessageRole }
    types --> jaclang.byllm.tests.test_multimodal_tool_results {
        Image,
        Text,
        ToolCallResultMsg,
        content_preview,
        normalize_tool_result,
        reroute_tool_images_to_user_message
    }
    types --> jaclang.byllm.tests.test_parallel {
        Message,
        MessageRole,
        MockToolCall,
        Tool
    }
    types --> jaclang.byllm.tests.test_telemetry_ { Message, MessageRole, Text }
    types --> jaclang.byllm.tests.test_tools { IterationAction, IterationContext }
    types --> jaclang.byllm.tests.test_usage { IterationContext, MockToolCall }
    types --> jaclang.byllm.visit_routing.route_visit { Message, MessageRole }
    visit_routing --> jaclang.runtime.runtime.JacLLM.by_operator { route_visit }
}

impl import jaclang.byllm._optdeps {
    litellm --> jaclang.byllm.llm { _disable_debugging, litellm }
    litellm --> jaclang.byllm.llm._configure_litellm { HAS_LITELLM }
    litellm --> jaclang.byllm.tests.test_telemetry_ { LiteLLMMessage }
    litellm --> jaclang.byllm.types { LiteLLMMessage }
    loguru --> jaclang.byllm.llm | jaclang.byllm.visit_routing { logger }
    openai --> jaclang.byllm.llm { AsyncOpenAI, OpenAI, openai }
    pillow --> jaclang.byllm.types { PILImageCls, open_image }
    pydantic --> jaclang.byllm.schema | jaclang.byllm.types { TypeAdapter }
}

impl import jaclang.byllm.tests {
    fixtures --> jaclang.byllm.tests.test_byllm { python_lib_mode }
    fixtures --> jaclang.byllm.tests.test_mtir_integration { python_lib_mode }
    support --> jaclang.byllm.tests.test_byllm {
        FIXTURE_DIR,
        call as tool_call,
        capture_logs,
        capture_loguru,
        finish,
        fixture_path,
        load_fixture,
        mk_run,
        prompt_text,
        say,
        scripted,
        text_chunk,
        tool_names
    }
    support --> jaclang.byllm.tests.test_compaction {
        call,
        fail,
        finish,
        fixture_path,
        scripted
    }
    support --> jaclang.byllm.tests.test_conversation { call, finish, say }
    support --> jaclang.byllm.tests.test_media {
        data_url,
        fixture_path,
        media_blocks,
        need,
        prompt_text,
        roles,
        say,
        user_blocks
    }
    support --> jaclang.byllm.tests.test_model_pool { text_chunk }
    support --> jaclang.byllm.tests.test_mtir_integration {
        fixture_path,
        load_fixture,
        need_outside_jaclang
    }
    support --> jaclang.byllm.tests.test_parallel { mk_run }
    support --> jaclang.byllm.tests.test_prompting {
        call,
        fixture_path,
        prompt_text,
        roles,
        say,
        tool_names
    }
    support --> jaclang.byllm.tests.test_routing {
        RoutingLLM,
        prompt_text,
        routing_candidates,
        say
    }
    support --> jaclang.byllm.tests.test_streaming {
        call,
        chunk_text,
        event_types,
        events_of,
        fail,
        finish,
        mk_run,
        prompt_text,
        say,
        scripted,
        stream_events
    }
    support --> jaclang.byllm.tests.test_tool_arg_streaming {
        call,
        calls,
        event_types,
        events_of,
        fail,
        mk_run,
        say
    }
    support --> jaclang.byllm.tests.test_tools {
        call,
        finish,
        prompt_text,
        say,
        tool_names
    }
    support --> jaclang.byllm.tests.test_truncated_tool_calls { call, say, scripted }
    support --> jaclang.byllm.tests.test_typed_retry {
        FIXTURE_DIR,
        fail,
        prompt_text,
        say
    }
    support --> jaclang.byllm.tests.test_usage {
        TOKENS,
        call,
        events_of,
        finish,
        mk_run,
        say,
        scripted
    }
}

impl import jaclang.byllm.tests.fixtures {
    agent_graph as ag --> jaclang.byllm.tests.test_routing;
    agent_graph --> jaclang.byllm.tests.test_routing {
        MathAgent,
        PoemAgent,
        Team,
        supervisor
    }
    routing_graph as rg --> jaclang.byllm.tests.test_routing;
    routing_graph --> jaclang.byllm.tests.test_routing {
        Agent,
        Hub,
        Route,
        collector,
        leaky,
        picker,
        router,
        stream_router
    }
}

impl import jaclang.byllm.tests.fixtures.import_dir {
    importable_schema --> jaclang.byllm.tests.fixtures.importer_main {
        get_imported_data
    }
}

impl import jaclang.byllm.tests.fixtures.scope_dir {
    module_alpha --> jaclang.byllm.tests.fixtures.scope_main {
        process_data as alpha_process
    }
    module_beta --> jaclang.byllm.tests.fixtures.scope_main {
        process_data as beta_process
    }
}

impl import jaclang.cache {
    home --> jaclang.cache.policy { CACHEDIR_TAG }
    home --> jaclang.cache.registry {
        CACHEDIR_TAG,
        cache_home,
        ensure_cache_dir,
        ensure_root
    }
    home --> jaclang.cli.commands.cache { cache_home }
    locking --> jaclang.cache.policy | jaclang.toolchains.store { FileLock }
    policy --> jaclang.cache.registry {
        CacheEntry,
        EntryKind,
        Policy,
        Retention,
        SWEEP_SENTINEL,
        SweepReport,
        TempLock,
        TemporaryClaim,
        dir_size,
        maybe_sweep_dir,
        remove_entry,
        scan_entries,
        sweep_dir,
        touch
    }
    policy --> jaclang.cli.commands.cache { format_bytes }
    policy --> jaclang.cli.format_cache {
        DAY_SECONDS,
        Policy,
        SWEEP_INTERVAL_SECONDS,
        SWEEP_SENTINEL,
        maybe_sweep_dir
    }
    policy --> jaclang.compiler.driver.jir._sweep_once { maybe_sweep_dir }
    policy --> jaclang.compiler.driver.jir.sweep_stale_generations { sweep_dir }
    registry --> jaclang.byllm.model_cache.get_cache_dir { bucket }
    registry --> jaclang.cli.commands.cache { RETIRED, gc, purge, status, unmanaged }
    registry --> jaclang.compiler.driver.jir._manifest_compiler_digest {
        bucket,
        maybe_sweep
    }
    registry --> jaclang.compiler.driver.jir._sweep_once { bucket, maybe_sweep }
    registry --> jaclang.compiler.driver.jir._touch_generation { bucket }
    registry --> jaclang.compiler.driver.jir.sweep_stale_generations { bucket }
    registry --> jaclang.compiler.types.stubcat.locate._find_catalog { bucket }
    registry --> jaclang.compiler.types.stubcat.locate.dev_catalog_path { bucket }
    registry --> jaclang.compiler.types.stubcat.locate.ensure_catalog { maybe_sweep }
    registry --> jaclang.data.pgembed.dist_cache_dir { bucket }
    registry --> jaclang.dist.fused_binary._runtime_dir_for_key { bucket }
    registry --> jaclang.dist.jab { bucket, maybe_sweep }
    registry --> jaclang.scale.injector.binary._fetch_verified_asset { maybe_sweep }
    registry --> jaclang.scale.injector.binary._scale_cache_root { bucket }
    registry --> jaclang.toolchains.android { bucket }
    registry --> jaclang.toolchains.store { bucket, maybe_sweep }
}

impl import jaclang.cli {
    banners --> jaclang.server.server.JacAPIServer._ensure_client_bundle {
        JAC_DISCORD_URL
    }
    browser_engine --> jaclang.cli.commands.browse {
        cmd_click,
        cmd_close,
        cmd_console,
        cmd_eval,
        cmd_fill,
        cmd_get,
        cmd_navigate,
        cmd_open,
        cmd_press,
        cmd_screenshot,
        cmd_scroll,
        cmd_sessions,
        cmd_snapshot,
        cmd_state,
        cmd_type,
        cmd_wait
    }
    check_report --> jaclang.cli.commands.analysis {
        print_failed_summary,
        print_file_progress,
        print_final_summary,
        print_native_coverage,
        print_placement_report,
        print_section
    }
    check_report --> jaclang.cli.commands.analysis.explain { print_placement_report }
    cli --> jaclang.cli.cli_boot.start_cli { start_cli as _start_cli }
    cli --> jaclang.cli.commands.analysis.format { jac_version }
    cli --> jaclang.cli.commands.project._stamp_jac_version { jac_version }
    cli_boot --> jaclang.jac0core.cli_boot { start_cli }
    command --> jaclang.byllm.cli { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.analysis { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.arch { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.browse { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.build { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.cache { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.code { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.config { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.db { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.execution { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.fix { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.guide { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.mcp | jaclang.cli.shadcn.cli { Arg, CommandSpec }
    command --> jaclang.cli.commands.precompile { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.project { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.tools { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.commands.tools._extract_commands { ArgKind }
    command --> jaclang.cli.dispatch { Arg, ArgKind, CommandSpec, arg_consumes_value }
    command --> jaclang.cli.executor | jaclang.cli.manifest_help { CommandSpec }
    command --> jaclang.cli.executor.CommandExecutor.execute { CommandSpec }
    command --> jaclang.cli.executor.CommandExecutor.run_handler { CommandSpec }
    command --> jaclang.cli.manifest { Arg, ArgKind, CommandSpec }
    command --> jaclang.cli.manifest_parse {
        Arg,
        ArgKind,
        CommandSpec,
        arg_consumes_value,
        resolve_arg_typ
    }
    command --> jaclang.cli.mcp_manifest.get_command { arg_typ_name }
    command --> jaclang.client.cli { Arg, ArgKind, CommandSpec }
    command --> jaclang.scale.plugin { Arg, ArgKind, CommandSpec }
    console --> jaclang.byllm.cli { console }
    console --> jaclang.byllm.model_cache._emit { console }
    console --> jaclang.cli.banners { console }
    console --> jaclang.cli.check_report.print_diag { console }
    console --> jaclang.cli.check_report.print_failed_summary { console }
    console --> jaclang.cli.check_report.print_file_progress { console }
    console --> jaclang.cli.check_report.print_final_summary { console }
    console --> jaclang.cli.check_report.print_guide_hint { console }
    console --> jaclang.cli.check_report.print_native_coverage { console }
    console --> jaclang.cli.check_report.print_placement_report { console }
    console --> jaclang.cli.check_report.print_section { console }
    console --> jaclang.cli.cli.start_cli { console }
    console --> jaclang.cli.commands.analysis { console }
    console --> jaclang.cli.commands.analysis.explain { console }
    console --> jaclang.cli.commands.arch { console }
    console --> jaclang.cli.commands.browse { console }
    console --> jaclang.cli.commands.build { console }
    console --> jaclang.cli.commands.cache { console }
    console --> jaclang.cli.commands.cli_helpers { console }
    console --> jaclang.cli.commands.code { console }
    console --> jaclang.cli.commands.config { console }
    console --> jaclang.cli.commands.db { console }
    console --> jaclang.cli.commands.execution { console, use_line_buffered_output }
    console --> jaclang.cli.commands.fix { console }
    console --> jaclang.cli.commands.guide { console }
    console --> jaclang.cli.commands.native_build { console }
    console --> jaclang.cli.commands.project { console }
    console --> jaclang.cli.commands.tools { console }
    console --> jaclang.cli.commands.transform { console }
    console --> jaclang.cli.dispatch._apply_profile { console }
    console --> jaclang.cli.dispatch._exit_on_invalid_jac_toml { console }
    console --> jaclang.cli.dispatch._exit_on_malformed_jac_toml { console }
    console --> jaclang.cli.dispatch.run_selected_command { console }
    console --> jaclang.cli.executor { console }
    console --> jaclang.cli.manifest_help._use_color { console }
    console --> jaclang.cli.shadcn.cli._build_shadcn_template_info { console }
    console --> jaclang.cli.shadcn.cli._shadcn_post_create { console }
    console --> jaclang.cli.shadcn.cli.retheme { console }
    console --> jaclang.cli.shadcn.cli.run_shadcn_add { console }
    console --> jaclang.cli.shadcn.cli.run_shadcn_remove { console }
    console --> jaclang.cli.shadcn.shadcn_handler { console }
    console --> jaclang.cli.shadcn.theme_handler { console }
    console --> jaclang.client.asset_processor { console }
    console --> jaclang.client.bun_installer { console }
    console --> jaclang.client.cli._npm_context { console }
    console --> jaclang.client.cli.run_client_build { console }
    console --> jaclang.client.cli.run_client_setup { console }
    console --> jaclang.client.cli.run_client_start { console }
    console --> jaclang.client.cli.run_npm_add { console }
    console --> jaclang.client.cli.run_npm_add_global { console }
    console --> jaclang.client.cli.run_npm_remove { console }
    console --> jaclang.client.cli.setup { console }
    console --> jaclang.client.client_deps.prompt_install_client_deps { console }
    console --> jaclang.client.compiler { console }
    console --> jaclang.client.config_loader { console }
    console --> jaclang.client.desktop_config { console }
    console --> jaclang.client.jac_client_compiler { console }
    console --> jaclang.client.npm_provider.app_npm_deps._add { console }
    console --> jaclang.client.plugin_config._load_template { console }
    console --> jaclang.client.targets.client_dev_common { console }
    console --> jaclang.client.targets.desktop.cef_shell { console }
    console --> jaclang.client.targets.desktop.desktop_build { console }
    console --> jaclang.client.targets.desktop.native.cef.build { console }
    console --> jaclang.client.targets.desktop.webview_shell { console }
    console --> jaclang.client.targets.mobile_target { console }
    console --> jaclang.client.targets.node_tooling_common { console }
    console --> jaclang.client.targets.pwa_build { console }
    console --> jaclang.client.targets.react_native.build { console }
    console --> jaclang.client.targets.react_native.dev { console }
    console --> jaclang.client.targets.react_native.scaffold { console }
    console --> jaclang.client.targets.static_target { console }
    console --> jaclang.client.targets.web_target.WebTarget.dev { console }
    console --> jaclang.client.vite_bundler { console }
    console --> jaclang.client.vite_client_bundle { console }
    console --> jaclang.compiler.backends.native.elf_linker { console }
    console --> jaclang.compiler.backends.native.na_ir_gen_pass { console }
    console --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._demote_method_if_unlowerable {
        console
    }
    console --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._opaque_field_if_unlowerable {
        console
    }
    console --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_imported_archetype {
        console
    }
    console --> jaclang.compiler.backends.native.wasm_build._link_wasm_libc { console }
    console --> jaclang.compiler.driver.application.prepare_application { console }
    console --> jaclang.compiler.driver.application.prepare_dynamic_module { console }
    console --> jaclang.compiler.driver.compiler.JacCompiler.compile {
        console as _note_console
    }
    console --> jaclang.compiler.driver.na_coverage._note_native_closure_cap { console }
    console --> jaclang.compiler.placement.placement_solver.demote_client_pulled_elements {
        console
    }
    console --> jaclang.compiler.tools.lang_tools { console }
    console --> jaclang.dist.precompile_bytecode { console }
    console --> jaclang.dist.seal { console }
    console --> jaclang.lsp.server.engine { console }
    console --> jaclang.lsp.server.server { console }
    console --> jaclang.project.config.JacConfig._write_toml_text { console }
    console --> jaclang.project.config._apply_build_section { console }
    console --> jaclang.project.config._apply_memory_native_placement { console }
    console --> jaclang.project.config._parse_toml_data { console }
    console --> jaclang.project.config_schema.report_schema_findings { console }
    console --> jaclang.project.providers { console }
    console --> jaclang.project.pyvenv { console }
    console --> jaclang.project.template_loader { console }
    console --> jaclang.project.template_registry._register_builtin_client_templates {
        console
    }
    console --> jaclang.project.template_registry._register_builtin_shadcn_template {
        console
    }
    type console --> jaclang.runtime.runtime { JacConsole as ConsoleImpl }
    console --> jaclang.runtime.runtime.JacBuiltin.get_console { JacConsole }
    console --> jaclang.scale.deploy.target.factory.ensure_deploy_tooling { console }
    console --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_client_bundle {
        console
    }
    console --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._install_app_deps {
        console
    }
    console --> jaclang.scale.deploy.target.kubernetes.target.KubernetesTarget._wait_for_fleet_rollout {
        console
    }
    console --> jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
        console
    }
    console --> jaclang.scale.injector.binary_injector.select_injector { console }
    console --> jaclang.scale.observability.standard_logger { console }
    console --> jaclang.scale.plugin { console }
    console --> jaclang.scale.runtime.cli.plan { console }
    console --> jaclang.scale.runtime.orchestrator.orchestrator { console }
    console --> jaclang.scale.runtime.realizer.kubernetes_realizer { console }
    console --> jaclang.scale.utils.vendor_wheels { console }
    console --> jaclang.server.assembly { console }
    console --> jaclang.server.hmr { console }
    console --> jaclang.server.server.JacAPIServer._ensure_client_bundle { console }
    console --> jaclang.server.server.JacAPIServer.start { console }
    console --> jaclang.server.server.print_endpoint_docs { console }
    console --> jaclang.server.watcher { console }
    console --> jaclang.testing.cl_test_runner { console }
    console --> jaclang.testing.test { console }
    console --> jaclang.toolchains.android { console }
    console --> jaclang.toolchains.host { console }
    console --> jaclang.toolchains.manager { console }
    console --> jaclang.toolchains.store { console }
    dispatch --> jaclang.cli.manifest_route.handle_manifest_route {
        run_selected_command
    }
    errmap --> jaclang.cli.executor.CommandExecutor.execute {
        humanize_error,
        show_tracebacks
    }
    errmap --> jaclang.scale.tests.server.test_serve { humanize_error }
    executor --> jaclang.cli.dispatch.run_selected_command { get_executor }
    format_cache --> jaclang.cli.commands.analysis._format_single_file_worker {
        FormatCache,
        canonical_logical_path,
        config_fingerprint,
        default_format_cache_dir,
        frame_unit
    }
    format_cache --> jaclang.cli.commands.analysis.format {
        FORMAT_CACHE_SCHEMA_VERSION,
        formatter_pipeline_revision
    }
    guide_store --> jaclang.cli.check_report.print_guide_hint { guide_for_diagnostic }
    guide_store --> jaclang.cli.commands.guide {
        Guide,
        corpus_blurb,
        doc_corpora,
        get_guide,
        grep_guides,
        grouped_guides,
        guide_group,
        guide_sections,
        list_docs,
        list_guides,
        nav_manifest
    }
    guide_store --> jaclang.cli.mcp.resources.ResourceProvider._index_shared_guides {
        docs_dir,
        list_docs,
        list_guides
    }
    jaccomplete --> jaclang.cli.commands.tools.completions {
        static_shellcode as shellcode
    }
    loader --> jaclang.cli.dispatch.run_selected_command { load_handler }
    manifest --> jaclang.cli.commands.tools.completions { iter_command_meta }
    manifest --> jaclang.cli.dispatch.run_selected_command { get_command_meta }
    manifest --> jaclang.cli.loader.load_handler { get_command_meta }
    manifest --> jaclang.cli.manifest_help {
        GROUP_DISPLAY,
        GROUP_ORDER,
        TIER_ORDER,
        TIER_SECTIONS,
        iter_command_meta
    }
    manifest --> jaclang.cli.manifest_route.handle_manifest_route {
        TOMBSTONED_VERBS,
        known_command_names
    }
    manifest --> jaclang.cli.mcp_manifest.get_command { get_command_meta }
    manifest --> jaclang.cli.mcp_manifest.list_commands {
        get_groups,
        iter_command_meta
    }
    manifest_help --> jaclang.cli.manifest_route._render_version_line {
        _TITLE,
        _color,
        _use_color
    }
    manifest_help --> jaclang.cli.manifest_route.handle_manifest_route {
        format_curated_help,
        format_logo,
        format_verbose_help
    }
    manifest_parse --> jaclang.cli.dispatch.run_selected_command {
        build_command_parser
    }
    manifest_route --> jaclang.cli.cli.jac_version { resolve_cli_version }
    manifest_route --> jaclang.cli.cli.start_cli { handle_manifest_route }
    manifest_route --> jaclang.scale.injector.binary.deploy_generation_refusal {
        resolve_cli_version
    }
    manifest_route --> jaclang.scale.injector.binary.host_toolchain_path {
        resolve_cli_version
    }
    manifest_route --> jaclang.scale.observability.prometheus_metrics.PrometheusMetricsCollector.__post_init__ {
        resolve_cli_version
    }
    manifest_route --> jaclang.scale.tests.deploy.test_client_build_fail_fast {
        resolve_cli_version
    }
    manifest_route --> jaclang.scale.tests.deploy.test_memory_trigger_guard {
        resolve_cli_version
    }
    manifest_route --> jaclang.scale.tests.deploy.test_version_pin {
        resolve_cli_version
    }
    manifest_route --> jaclang.scale.tests.misc.test_metrics { resolve_cli_version }
    mcp_manifest --> jaclang.cli.mcp.tools.get_command {
        get_command as manifest_get_command
    }
    mcp_manifest --> jaclang.cli.mcp.tools.list_commands {
        list_commands as manifest_list_commands
    }
    workpool --> jaclang.cli.commands.analysis._check_retire { env_int, should_retire }
    workpool --> jaclang.cli.commands.analysis._check_rss_cap_mb { env_int }
    workpool --> jaclang.cli.commands.analysis._maybe_malloc_trim { maybe_malloc_trim }
    workpool --> jaclang.cli.commands.analysis.check {
        WorkPool,
        forced_serial,
        jobs_setting,
        pool_available,
        resolve_jobs
    }
    workpool --> jaclang.cli.commands.analysis.format {
        WorkPool,
        forced_serial,
        jobs_setting,
        pool_available,
        resolve_jobs
    }
    workpool --> jaclang.cli.commands.analysis.test { jobs_setting }
    workpool --> jaclang.dist.precompile_bytecode._precompile_retire {
        WORKER_MEM_BYTES,
        env_int,
        maybe_malloc_trim,
        should_retire,
        worker_rss_mb
    }
    workpool --> jaclang.dist.precompile_bytecode.precompile_native_unit {
        maybe_malloc_trim
    }
    workpool --> jaclang.dist.precompile_bytecode.precompile_unit_context {
        maybe_malloc_trim
    }
    workpool --> jaclang.dist.precompile_bytecode.run_precompile {
        WORKER_MEM_BYTES,
        WorkPool,
        env_int,
        forced_serial,
        jobs_setting,
        pool_available,
        resolve_jobs
    }
    workpool --> jaclang.testing.test_runner {
        WorkPool,
        should_retire as _should_retire,
        worker_rss_mb as _worker_rss_mb
    }
    workpool --> jaclang.testing.test_runner._test_retire { env_int }
    workpool --> jaclang.testing.test_runner.resolve_jobs {
        resolve_jobs as _resolve_pool_jobs
    }
}

impl import jaclang.cli.commands {
    analysis --> jaclang.cli.commands.build.build { check }
    comptime analysis --> jaclang.cli.manifest {
        SPEC_CHECK,
        SPEC_EXPLAIN,
        SPEC_FORMAT,
        SPEC_GEN_PARSER,
        SPEC_PRECOMMIT,
        SPEC_TEST
    }
    comptime arch --> jaclang.cli.manifest { SPEC_ARCH }
    comptime browse --> jaclang.cli.manifest { SPEC_BROWSE }
    build --> jaclang.cli.commands.execution._build_plan { build }
    comptime build --> jaclang.cli.manifest { SPEC_BUILD }
    comptime cache --> jaclang.cli.manifest { SPEC_CACHE }
    cli_helpers --> jaclang.cli.commands.execution { proc_file as _proc_file }
    cli_helpers --> jaclang.cli.commands.tools { proc_file as _proc_file }
    comptime code --> jaclang.cli.manifest { SPEC_CODE }
    comptime config --> jaclang.cli.manifest { SPEC_CONFIG }
    comptime db --> jaclang.cli.manifest { SPEC_DB }
    execution --> jaclang.cli.cli_boot._run_bundled_app { run_jab_image }
    comptime execution --> jaclang.cli.manifest { SPEC_RUN, SPEC_X }
    execution --> jaclang.client.targets.web_target.WebTarget.start { serve }
    execution --> jaclang.scale.tests.server.test_serve { _find_free_port }
    comptime fix --> jaclang.cli.manifest { SPEC_FIX }
    comptime guide --> jaclang.cli.manifest { SPEC_GUIDE }
    comptime mcp --> jaclang.cli.manifest { SPEC_MCP_CMD }
    native_build --> jaclang.cli.commands.build._build_app { native_build }
    native_build --> jaclang.cli.commands.build.build { native_build }
    native_build --> jaclang.cli.commands.execution._build_plan { native_build }
    native_build --> jaclang.dist.seal.bake_native_payloads { native_build }
    comptime precompile --> jaclang.cli.manifest { SPEC_PRECOMPILE }
    project --> jaclang.cli.commands.build._build_app { bundle }
    project --> jaclang.cli.commands.execution.x { script }
    comptime project --> jaclang.cli.manifest {
        SPEC_CLEAN,
        SPEC_CREATE,
        SPEC_INSTALL,
        SPEC_REMOVE,
        SPEC_UPDATE
    }
    comptime tools --> jaclang.cli.manifest {
        SPEC_COMPLETIONS,
        SPEC_DOT,
        SPEC_LSP,
        SPEC_TOOL
    }
}

impl import jaclang.cli.mcp {
    compiler_bridge --> jaclang.cli.mcp.tools.ToolProvider.call_tool { CompilerBridge }
    compiler_bridge --> jaclang.cli.mcp.tools.get_ast { CompilerBridge }
    compiler_bridge --> jaclang.cli.mcp.tools.graph_visualize { CompilerBridge }
    compiler_bridge --> jaclang.cli.mcp.tools.jac_to_js { CompilerBridge }
    compiler_bridge --> jaclang.cli.mcp.tools.jac_to_py { CompilerBridge }
    compiler_bridge --> jaclang.cli.mcp.tools.lint_jac { CompilerBridge }
    compiler_bridge --> jaclang.cli.mcp.tools.run_jac { CompilerBridge }
    mode --> jaclang.cli.commands.mcp.mcp_cmd { set_mcp_mode }
    mode --> jaclang.cli.mcp.prompts.PromptProvider.list_prompts {
        disabled_prompts_for_mode,
        get_mcp_mode
    }
    mode --> jaclang.cli.mcp.tools.ToolProvider.list_tools {
        disabled_tools_for_mode,
        get_mcp_mode
    }
    prompts --> jaclang.cli.commands.mcp._print_mcp_inventory { PromptProvider }
    prompts --> jaclang.cli.mcp.protocol { PromptProvider }
    prompts --> jaclang.cli.mcp.protocol.build_engine { PromptProvider }
    protocol --> jaclang.cli.mcp.server.JacMcpServer.start {
        build_engine,
        serve_sse,
        serve_stdio,
        serve_streamable_http
    }
    resources --> jaclang.cli.commands.mcp._print_mcp_inventory { ResourceProvider }
    resources --> jaclang.cli.mcp.prompts.load_resource_content {
        get_resource_provider
    }
    resources --> jaclang.cli.mcp.protocol { ResourceProvider }
    resources --> jaclang.cli.mcp.protocol.build_engine { get_resource_provider }
    resources --> jaclang.cli.mcp.tools.get_example { get_resource_provider }
    resources --> jaclang.cli.mcp.tools.get_resource { get_resource_provider }
    resources --> jaclang.cli.mcp.tools.list_examples { get_resource_provider }
    resources --> jaclang.cli.mcp.tools.search_docs { get_resource_provider }
    resources --> jaclang.cli.mcp.tools.understand_jac_and_jaseci {
        get_resource_provider
    }
    server --> jaclang.cli.commands.mcp.mcp_cmd { JacMcpServer }
    tools --> jaclang.cli.commands.mcp._print_mcp_inventory { ToolProvider }
    tools --> jaclang.cli.mcp.protocol { ToolProvider }
    tools --> jaclang.cli.mcp.protocol.build_engine { ToolProvider }
}

impl import jaclang.cli.shadcn {
    cli --> jaclang.cli.commands.project._create_body { stash_create_theme }
    cli --> jaclang.cli.commands.project.install { run_shadcn_add }
    cli --> jaclang.cli.commands.project.remove { run_shadcn_remove }
    comptime cli --> jaclang.cli.manifest { SPEC_RETHEME }
    cli --> jaclang.project.template_registry._register_builtin_shadcn_template {
        register_project_template
    }
    shadcn_handler --> jaclang.cli.shadcn.cli.run_shadcn_add { add_shadcn_components }
    shadcn_handler --> jaclang.cli.shadcn.cli.run_shadcn_remove {
        remove_shadcn_components
    }
    shadcn_handler --> jaclang.cli.shadcn.theme_handler {
        _registry_dir,
        load_registry,
        resolve_single_component
    }
    theme_handler --> jaclang.cli.shadcn.cli._shadcn_post_create {
        materialize_themed_starter,
        normalize_shadcn_config
    }
    theme_handler --> jaclang.cli.shadcn.cli.retheme { retheme_project }
}

impl import jaclang.cli.shadcn.registry.components.ui {
    button --> jaclang.cli.shadcn.registry.components.ui.alert_dialog { Button }
    button --> jaclang.cli.shadcn.registry.components.ui.attachment { Button }
    button --> jaclang.cli.shadcn.registry.components.ui.calendar {
        Button,
        buttonVariants
    }
    button --> jaclang.cli.shadcn.registry.components.ui.carousel { Button }
    button --> jaclang.cli.shadcn.registry.components.ui.combobox { Button }
    button --> jaclang.cli.shadcn.registry.components.ui.dialog { buttonVariants }
    button --> jaclang.cli.shadcn.registry.components.ui.input_group { Button }
    button --> jaclang.cli.shadcn.registry.components.ui.pagination {
        Button,
        buttonVariants
    }
    button --> jaclang.cli.shadcn.registry.components.ui.sheet { Button }
    button --> jaclang.cli.shadcn.registry.components.ui.sidebar { Button }
    dialog --> jaclang.cli.shadcn.registry.components.ui.command {
        Dialog,
        DialogContent,
        DialogDescription,
        DialogHeader,
        DialogTitle
    }
    input --> jaclang.cli.shadcn.registry.components.ui.input_group { Input }
    input --> jaclang.cli.shadcn.registry.components.ui.sidebar { Input }
    input_group --> jaclang.cli.shadcn.registry.components.ui.combobox {
        InputGroup,
        InputGroupAddon,
        InputGroupButton,
        InputGroupInput
    }
    input_group --> jaclang.cli.shadcn.registry.components.ui.command {
        InputGroup,
        InputGroupAddon
    }
    label --> jaclang.cli.shadcn.registry.components.ui.field { Label }
    separator --> jaclang.cli.shadcn.registry.components.ui.button_group { Separator }
    separator --> jaclang.cli.shadcn.registry.components.ui.field { Separator }
    separator --> jaclang.cli.shadcn.registry.components.ui.item { Separator }
    separator --> jaclang.cli.shadcn.registry.components.ui.sidebar { Separator }
    sheet --> jaclang.cli.shadcn.registry.components.ui.sidebar {
        Sheet,
        SheetContent,
        SheetDescription,
        SheetHeader,
        SheetTitle
    }
    skeleton --> jaclang.cli.shadcn.registry.components.ui.sidebar { Skeleton }
    textarea --> jaclang.cli.shadcn.registry.components.ui.input_group { Textarea }
    toggle --> jaclang.cli.shadcn.registry.components.ui.toggle_group { toggleVariants }
    tooltip --> jaclang.cli.shadcn.registry.components.ui.sidebar {
        Tooltip,
        TooltipContent,
        TooltipTrigger
    }
}

impl import jaclang.cli.shadcn.registry.lib {
    utils --> jaclang.cli.shadcn.registry.components.ui.accordion { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.alert { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.alert_dialog { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.attachment { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.avatar { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.badge { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.breadcrumb { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.bubble { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.button { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.button_group { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.calendar { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.card { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.carousel { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.chart { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.checkbox { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.combobox { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.command { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.context_menu { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.dialog { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.drawer { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.dropdown_menu { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.empty { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.field { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.hover_card { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.input { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.input_group { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.item { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.kbd { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.label { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.marker { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.menubar { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.message { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.native_select { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.navigation_menu { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.otp_input { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.pagination { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.popover { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.progress { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.radio_group { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.resizable { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.scroll_area { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.select { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.separator { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.sheet { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.sidebar { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.skeleton { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.slider { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.spinner { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.switch { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.table { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.tabs { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.textarea { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.toggle { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.toggle_group { cn }
    utils --> jaclang.cli.shadcn.registry.components.ui.tooltip { cn }
}

impl import jaclang.client {
    artifact --> jaclang.client.client_bundle {
        ClientBundle,
        ClientBundleError,
        MissingBunError,
        prebuilt_bundle
    }
    artifact --> jaclang.client.serving { client_output_dir }
    artifact --> jaclang.server.server { ClientBundleError, MissingBunError }
    artifact --> jaclang.server.server.ModuleIntrospector.ensure_bundle {
        prebuilt_bundle
    }
    asset_processor --> jaclang.client.jac_client_compiler { AssetProcessor }
    auth_contract --> jaclang.client.client_react_core { SignupResult }
    auth_contract --> jaclang.client.client_runtime { SignupResult }
    auth_contract --> jaclang.client.client_runtime_core { SignupResult }
    auth_contract --> jaclang.client.solid_runtime { SignupResult }
    bun_installer --> jaclang.cli.commands.execution._run_node_tool { get_bun }
    bun_installer --> jaclang.client.cli.run_npm_add_global {
        bun_unavailable_message,
        get_bun
    }
    bun_installer --> jaclang.client.npm_provider.regenerate_and_install {
        bun_unavailable_message
    }
    bun_installer --> jaclang.client.vite_bundler { bun_unavailable_message }
    bun_installer --> jaclang.dist.payload.fetch { BUN_VERSION }
    bun_installer --> jaclang.testing.cl_test_runner._run_harness { get_bun }
    cli --> jaclang.cli.commands.build._build_app { run_client_build }
    cli --> jaclang.cli.commands.execution.serve { run_client_start }
    cli --> jaclang.cli.commands.project.install { run_npm_add }
    cli --> jaclang.cli.commands.project.remove { run_npm_remove }
    comptime cli --> jaclang.cli.manifest { SPEC_SETUP }
    client_bundle --> jaclang.client.compiler {
        ClientBuildInputs,
        ClientBundle,
        ClientBundleError
    }
    client_bundle --> jaclang.client.compiler.ViteCompiler._compile_wasm_module {
        client_program
    }
    client_bundle --> jaclang.client.compiler.ViteCompiler.prepare_bundle {
        client_program
    }
    client_bundle --> jaclang.client.import_processor { ClientBundleError }
    client_bundle --> jaclang.client.jac_client_compiler { ClientBundleError }
    client_bundle --> jaclang.client.npm_provider { ClientBundleError }
    client_bundle --> jaclang.client.route_scanner { ClientBundleError }
    client_bundle --> jaclang.client.vite_bundler { ClientBundleError, MissingBunError }
    client_bundle --> jaclang.client.vite_client_bundle {
        ClientBuildInputs,
        ClientBundle,
        ClientBundleBuilder,
        ClientBundleError
    }
    client_bundle --> jaclang.client.vite_client_bundle.ViteClientBundleBuilder._emitted_digest {
        emitted_tree_digest
    }
    type client_bundle --> jaclang.compiler.driver.build_services {
        ClientBundleBuilder
    }
    client_bundle --> jaclang.compiler.driver.client_graph.collect_client_graph {
        ClientBundleError
    }
    client_bundle --> jaclang.compiler.tests.test_client_codegen_facts {
        _client_target_module,
        _ensure_js_generated
    }
    client_bundle --> jaclang.dist.source.client.write_client { client_program }
    type client_bundle --> jaclang.runtime.build_services { ClientBundleBuilder }
    type client_bundle --> jaclang.runtime.runtime { ClientBundle, ClientBundleBuilder }
    client_bundle --> jaclang.server.hmr.HotReloader._recompile_client_unified {
        ClientBundleError
    }
    client_diagnostics --> jaclang.client.cli.run_client_start { is_debug_mode }
    client_diagnostics --> jaclang.server.endpoints.pages.register_diagnostics_endpoints.client_error {
        log_client_error
    }
    type client_diagnostics --> jaclang.server.hmr { ClientDiagnostic }
    client_diagnostics --> jaclang.server.hmr.HotReloader.record_client_event {
        classify_client_payload
    }
    client_diagnostics --> jaclang.server.hmr.HotReloader.record_error {
        build_failure_diagnostic,
        diagnostics_from_alerts
    }
    client_diagnostics --> jaclang.server.server.JacAPIServer._ensure_client_bundle {
        format_build_diagnostics
    }
    client_react_core --> jaclang.client.client_runtime_native {
        __createJacSchema,
        __jacReportError,
        jacIsLoggedIn,
        useJacForm
    }
    client_runtime_core --> jaclang.client.client_runtime {
        BridgeError as _BridgeError,
        BridgeRejected as _BridgeRejected,
        BridgeTimeout as _BridgeTimeout,
        BridgeUnavailable as _BridgeUnavailable,
        ErrorFallback as ___ErrorFallback,
        __bridgeApiBase as ___bridgeApiBase,
        __bridgeErrorFor as ___bridgeErrorFor,
        __bridgeErrorFromFetch as ___bridgeErrorFromFetch,
        __cacheGet as ___cacheGet,
        __cacheSet as ___cacheSet,
        __cachedEndpointCall as ___cachedEndpointCall,
        __createJacSchema as ___createJacSchema,
        __doFuncFetch as ___doFuncFetch,
        __doWalkerFetch as ___doWalkerFetch,
        __evictOldest as ___evictOldest,
        __getApiBaseUrl as ___getApiBaseUrl,
        __getCacheState as ___getCacheState,
        __getEndpointEffects as ___getEndpointEffects,
        __getLocalStorage as ___getLocalStorage,
        __invalidateEndpoint as ___invalidateEndpoint,
        __isFresh as ___isFresh,
        __jacCallFunction as ___jacCallFunction,
        __jacClearCache as ___jacClearCache,
        __jacDesktopBroker as ___jacDesktopBroker,
        __jacInstallErrorHandlers as ___jacInstallErrorHandlers,
        __jacPollBrokerSession as ___jacPollBrokerSession,
        __jacReactErrorHandler as ___jacReactErrorHandler,
        __jacReportError as ___jacReportError,
        __jacSleep as ___jacSleep,
        __jacSpawn as ___jacSpawn,
        __normalizeCredential as ___normalizeCredential,
        __normalizeIdentity as ___normalizeIdentity,
        __overlaps as ___overlaps,
        __removeLocalStorage as ___removeLocalStorage,
        __setLocalStorage as ___setLocalStorage,
        __unwrapFormSchema as ___unwrapFormSchema,
        errorOverlay as ___errorOverlay,
        jacIsLoggedIn as _jacIsLoggedIn,
        jacLogin as _jacLogin,
        jacLogout as _jacLogout,
        jacSetToken as _jacSetToken,
        jacSignup as _jacSignup,
        jacSpawn as _jacSpawn,
        jacSsoLogin as _jacSsoLogin,
        navigate as _navigate
    }
    client_runtime_core --> jaclang.client.solid_runtime {
        BridgeError as _BridgeError,
        BridgeRejected as _BridgeRejected,
        BridgeTimeout as _BridgeTimeout,
        BridgeUnavailable as _BridgeUnavailable,
        ErrorFallback as ___ErrorFallback,
        __bridgeApiBase as ___bridgeApiBase,
        __bridgeErrorFor as ___bridgeErrorFor,
        __bridgeErrorFromFetch as ___bridgeErrorFromFetch,
        __cacheGet as ___cacheGet,
        __cacheSet as ___cacheSet,
        __cachedEndpointCall as ___cachedEndpointCall,
        __createJacSchema as ___createJacSchema,
        __doFuncFetch as ___doFuncFetch,
        __doWalkerFetch as ___doWalkerFetch,
        __evictOldest as ___evictOldest,
        __getApiBaseUrl as ___getApiBaseUrl,
        __getCacheState as ___getCacheState,
        __getEndpointEffects as ___getEndpointEffects,
        __getLocalStorage as ___getLocalStorage,
        __invalidateEndpoint as ___invalidateEndpoint,
        __isFresh as ___isFresh,
        __jacCallFunction as ___jacCallFunction,
        __jacClearCache as ___jacClearCache,
        __jacDesktopBroker as ___jacDesktopBroker,
        __jacInstallErrorHandlers as ___jacInstallErrorHandlers,
        __jacPollBrokerSession as ___jacPollBrokerSession,
        __jacReactErrorHandler as ___jacReactErrorHandler,
        __jacReportError as ___jacReportError,
        __jacSleep as ___jacSleep,
        __jacSpawn as ___jacSpawn,
        __normalizeCredential as ___normalizeCredential,
        __normalizeIdentity as ___normalizeIdentity,
        __overlaps as ___overlaps,
        __removeLocalStorage as ___removeLocalStorage,
        __setLocalStorage as ___setLocalStorage,
        __unwrapFormSchema as ___unwrapFormSchema,
        errorOverlay as ___errorOverlay,
        jacIsLoggedIn as _jacIsLoggedIn,
        jacLogin as _jacLogin,
        jacLogout as _jacLogout,
        jacSetToken as _jacSetToken,
        jacSignup as _jacSignup,
        jacSpawn as _jacSpawn,
        jacSsoLogin as _jacSsoLogin,
        navigate as _navigate
    }
    client_surface --> jaclang.client.jac_to_js.JacToJSCompiler.add_runtime_imports {
        prepend_active_runtime_globals
    }
    client_surface --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._inject_runtime_import {
        runtime_import_source
    }
    client_surface --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._jsx_fragment {
        backend_jsx_factory_name
    }
    client_surface --> jaclang.server.hmr.HotReloader._recompile_client_code {
        prepend_active_runtime_globals
    }
    client_surface --> jaclang.testing.cl_test_runner._run_harness {
        prepend_active_runtime_globals
    }
    type compiler --> jaclang.client.targets.client_dev_common { ViteCompiler }
    compiler --> jaclang.client.vite_client_bundle { ViteCompiler }
    type compiler --> jaclang.runtime.prepared { ViteCompiler }
    config_loader --> jaclang.client.asset_processor.AssetProcessor.copy_custom_asset_types {
        JacClientConfig
    }
    config_loader --> jaclang.client.client_deps { JacClientConfig }
    config_loader --> jaclang.client.compiler.ViteCompiler._create_pages_entry_content {
        JacClientConfig
    }
    config_loader --> jaclang.client.jac_client_compiler.JacClientCompiler.compile {
        JacClientConfig as PwaConfig
    }
    config_loader --> jaclang.client.jac_client_compiler.JacClientCompiler.copy_root_assets {
        JacClientConfig
    }
    config_loader --> jaclang.client.targets.mobile_target { JacClientConfig }
    config_loader --> jaclang.client.targets.react_native.common { JacClientConfig }
    config_loader --> jaclang.client.targets.web_target._pwa_enabled { JacClientConfig }
    config_loader --> jaclang.client.vite_bundler { JacClientConfig }
    desktop_config --> jaclang.client.targets.desktop.cef_shell.cef_build {
        get_desktop_config
    }
    desktop_config --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.build {
        get_desktop_config
    }
    desktop_config --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.engine {
        get_desktop_config
    }
    desktop_config --> jaclang.client.targets.desktop.macos_bundle { DesktopIdentity }
    desktop_config --> jaclang.client.targets.desktop.webview_shell._assemble_native_host {
        get_desktop_config
    }
    desktop_plugin_config --> jaclang.client.desktop_config._validate_plugin_keys {
        _desktop_config_schema
    }
    desktop_plugin_config --> jaclang.project.template_registry._register_builtin_client_templates {
        JacDesktopPluginConfig
    }
    endpoint_cache --> jaclang.client.client_react_core {
        __cacheGet as cache___cacheGet,
        __cacheSet as cache___cacheSet,
        __cachedEndpointCall as cache___cachedEndpointCall,
        __endpointKey,
        __evictOldest as cache___evictOldest,
        __getCacheState as cache___getCacheState,
        __getEndpointEffects as cache___getEndpointEffects,
        __invalidateEndpoint as cache___invalidateEndpoint,
        __isFresh as cache___isFresh,
        __jacClearCache,
        __overlaps as cache___overlaps
    }
    endpoint_cache --> jaclang.client.client_runtime_core {
        __cacheGet as cache___cacheGet,
        __cacheSet as cache___cacheSet,
        __cachedEndpointCall as cache___cachedEndpointCall,
        __endpointKey,
        __evictOldest as cache___evictOldest,
        __getCacheState as cache___getCacheState,
        __getEndpointEffects as cache___getEndpointEffects,
        __invalidateEffects as cache___invalidateEffects,
        __invalidateEndpoint as cache___invalidateEndpoint,
        __isFresh as cache___isFresh,
        __jacClearCache as cache___jacClearCache,
        __overlaps as cache___overlaps
    }
    import_processor --> jaclang.client.jac_client_compiler { ImportProcessor }
    jac_client_compiler --> jaclang.client.compiler { JacClientCompiler }
    jac_client_compiler --> jaclang.client.targets.react_native.build {
        JacClientCompiler
    }
    jac_client_compiler --> jaclang.compiler.tests.xbackend_equiv.run_js_module_fixture {
        JacClientCompiler
    }
    jac_to_js --> jaclang.client.jac_client_compiler { JacToJSCompiler }
    npm_provider --> jaclang.client.client_deps._default_client_deps {
        CORE_DEV_DEPS,
        CORE_RUNTIME_DEPS,
        OPTIONAL_RUNTIME_DEPS
    }
    npm_provider --> jaclang.client.config_loader {
        CORE_DEV_DEPS,
        CORE_RUNTIME_DEPS,
        LEGACY_META_PACKAGES,
        OPTIONAL_RUNTIME_DEPS,
        app_npm_deps
    }
    npm_provider --> jaclang.client.plugin_config.JacClientPluginConfig.register_ecosystem_providers {
        NpmProvider
    }
    npm_provider --> jaclang.dist.publish.npm_builder._react_peer_floor {
        CORE_RUNTIME_DEPS
    }
    npm_provider --> jaclang.dist.publish.runtime_npm._peer_versions {
        CORE_RUNTIME_DEPS,
        OPTIONAL_RUNTIME_DEPS
    }
    plugin_config --> jaclang.client.desktop_plugin_config._load_desktop_template {
        _load_template
    }
    plugin_config --> jaclang.project.providers.initialize_provider_registry {
        JacClientPluginConfig
    }
    plugin_config --> jaclang.project.template_registry._register_builtin_client_templates {
        JacClientPluginConfig
    }
    preact_entry --> jaclang.compiler.backends.es.backends.preact.PreactBackend.build_entry_script {
        build_simple_preact_entry_script
    }
    react_entry --> jaclang.compiler.backends.es.backends.react.ReactBackend.build_entry_script {
        build_simple_react_entry_script
    }
    react_entry --> jaclang.compiler.backends.es.backends.react.ReactBackend.build_pages_entry_script {
        build_pages_react_entry_script
    }
    route_scanner --> jaclang.client.jac_client_compiler {
        RouteScanner,
        resolve_route_exports
    }
    route_scanner --> jaclang.client.jac_client_compiler.JacClientCompiler._check_entry_renders_routes {
        entry_drops_route_children
    }
    route_scanner --> jaclang.client.jac_client_compiler.JacClientCompiler._warn_pages_without_routes {
        describe_pages_without_routes
    }
    route_scanner --> jaclang.client.jac_client_compiler.JacClientCompiler._warn_unrouted_pages {
        describe_unrouted_pages
    }
    route_scanner --> jaclang.compiler.driver.application.prepare_route_metadata {
        RouteScanner
    }
    runtime_source --> jaclang.client.compiler.ViteCompiler.compile_runtime_utils {
        resolve_client_runtime_cl_path
    }
    runtime_source --> jaclang.client.vite_bundler.ViteBundler._generate_vite_config_content {
        JAC_VIRTUAL_MODULE_SOURCES
    }
    runtime_source --> jaclang.dist.publish.runtime_npm._runtime_source_path {
        resolve_client_runtime_cl_path
    }
    runtime_source --> jaclang.dist.publish.runtime_npm.build_runtime_tarball {
        resolve_client_runtime_cl_path
    }
    runtime_source --> jaclang.dist.publish.runtime_npm.runtime_pkg_name {
        client_runtime_cl_basename
    }
    runtime_source --> jaclang.project.modresolver._resolve_jac_virtual_module {
        jac_virtual_module_basenames,
        resolve_client_runtime_cl_path
    }
    serving --> jaclang.client.targets.web_target._generate_index_html { HeaderBuilder }
    serving --> jaclang.client.vite_bundler._dev_head_scripts { HeaderBuilder }
    serving --> jaclang.runtime.runtime.JacServe.get_client_js { JacClient }
    serving --> jaclang.runtime.runtime.JacServe.render_page { JacClient }
    solid_entry --> jaclang.compiler.backends.es.backends.solid.SolidBackend.build_entry_script {
        build_simple_solid_entry_script
    }
    solid_entry --> jaclang.compiler.backends.es.backends.solid.SolidBackend.build_pages_entry_script {
        build_pages_solid_entry_script
    }
    source_mapping --> jaclang.client.client_diagnostics {
        JacLocator,
        SourceLocation,
        _npm_specifier
    }
    source_mapping --> jaclang.client.jac_client_compiler.JacClientCompiler._write_source_map {
        generate_source_map_json
    }
    source_mapping --> jaclang.scale.tests.server.test_build_status_endpoint._reset_client_globals {
        _error_rate_limiter,
        _locator_cache,
        _mapper_cache
    }
    source_mapping --> jaclang.server.endpoints.pages.register_diagnostics_endpoints.client_error {
        _error_rate_limiter
    }
    source_mapping --> jaclang.server.hmr.HotReloader.record_client_event {
        _error_rate_limiter
    }
    vite_bundler --> jaclang.cli.commands.execution._start_vite_dev_server {
        ViteBundler
    }
    vite_bundler --> jaclang.cli.commands.execution.serve._announce_ready {
        DEV_PROXY_PREFIXES
    }
    vite_bundler --> jaclang.client.compiler { ViteBundler }
    vite_bundler --> jaclang.client.npm_provider.regenerate_and_install { ViteBundler }
    type vite_bundler --> jaclang.client.targets.client_dev_common { ViteBundler }
    vite_bundler --> jaclang.client.targets.client_dev_common.dev_proxy_paths {
        DEV_PROXY_PREFIXES
    }
    vite_bundler --> jaclang.client.targets.client_dev_common.prepare_vite_dev_compilation {
        ViteBundler
    }
    vite_bundler --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.build {
        API_BASE_URL_ENV_VAR
    }
    vite_bundler --> jaclang.client.targets.static_target { ViteBundler }
    vite_bundler --> jaclang.client.targets.web_target { ViteBundler }
    vite_bundler --> jaclang.client.vite_client_bundle.make_client_bundle_builder {
        ViteBundler
    }
    vite_bundler --> jaclang.dist.source.client.write_client { ViteBundler }
    vite_client_bundle --> jaclang.client.targets.client_dev_common.prepare_vite_dev_compilation {
        make_client_bundle_builder
    }
    vite_client_bundle --> jaclang.client.targets.mobile_target.MobileTarget._compile_native_jac_modules {
        ViteClientBundleBuilder
    }
    vite_client_bundle --> jaclang.client.targets.web_target.WebTarget.build {
        make_client_bundle_builder
    }
    vite_client_bundle --> jaclang.compiler.driver.application._prepare {
        make_client_bundle_builder
    }
    vite_client_bundle --> jaclang.compiler.driver.build_services.CompilerBuildServices.client_builder {
        make_client_bundle_builder
    }
}

impl import jaclang.client.targets {
    build_common --> jaclang.client.targets.client_dev_common {
        SUBPROCESS_TIMEOUT_SHORT
    }
    build_common --> jaclang.client.targets.react_native.build { artifact_mtime }
    build_common --> jaclang.client.targets.react_native.common {
        SUBPROCESS_TIMEOUT_BUILD_NATIVE
    }
    client_dev_common --> jaclang.client.targets.desktop.webview_shell.webview_dev {
        _ClientHmrHandler,
        ensure_watchdog_common,
        install_dev_signal_handlers,
        prepare_vite_dev_compilation,
        resolve_port_or_next_available,
        stop_dev_watcher,
        terminate_dev_processes
    }
    client_dev_common --> jaclang.client.targets.mobile_target {
        _ClientHmrHandler,
        ensure_watchdog_common,
        install_dev_signal_handlers,
        resolve_port_or_next_available,
        start_backend_server_common,
        stop_dev_watcher,
        terminate_dev_processes
    }
    client_dev_common --> jaclang.client.targets.react_native.dev {
        invalidate_runtime_module_cache,
        setup_android_port_reverse_common
    }
    client_dev_common --> jaclang.client.targets.web_target.WebTarget.dev {
        _ClientHmrHandler,
        dev_proxy_paths,
        ensure_watchdog_common,
        prepare_vite_dev_compilation,
        stop_dev_watcher,
        terminate_dev_processes
    }
    mobile_target --> jaclang.client.targets.register { MobileTarget }
    node_tooling_common --> jaclang.client.targets.react_native.common {
        resolve_node_tool as _node_resolve_node_tool,
        run_manifest_install as _node_run_manifest_install
    }
    node_tooling_common --> jaclang.client.vite_bundler._build_vite_command {
        resolve_node_tool_entry
    }
    pwa_build --> jaclang.client.targets.web_target.WebTarget.build { apply_pwa }
    pwa_build --> jaclang.client.targets.web_target.WebTarget.setup { ensure_pwa_icons }
    register --> jaclang.client.targets.registry.get_target_registry {
        register_targets
    }
    registry --> jaclang.client.cli { ClientTarget, target_for_app }
    registry --> jaclang.client.cli.run_client_build { target_for_kind }
    registry --> jaclang.client.cli.run_client_start { target_for_kind }
    registry --> jaclang.client.npm_provider.app_npm_deps { KIND_TARGET }
    registry --> jaclang.client.targets.mobile_target { ClientTarget }
    registry --> jaclang.client.targets.register { get_target_registry }
    registry --> jaclang.client.targets.web_target { ClientTarget }
    static_target --> jaclang.client.targets.register { StaticTarget }
    web_target --> jaclang.client.targets.desktop.desktop_target { WebTarget }
    web_target --> jaclang.client.targets.mobile_target.MobileTarget.build { WebTarget }
    web_target --> jaclang.client.targets.register { WebTarget }
    web_target --> jaclang.client.targets.static_target { WebTarget }
    web_target --> jaclang.dist.seal.ensure_client_dist { WebTarget }
}

impl import jaclang.client.targets.desktop {
    _dev_launch --> jaclang.client.targets.desktop.cef_shell {
        desktop_app_runtime_env,
        ensure_dev_build_env
    }
    _dev_launch --> jaclang.client.targets.desktop.desktop_build { desktop_launch_env }
    _dev_launch --> jaclang.client.targets.desktop.webview_shell {
        desktop_app_runtime_env,
        ensure_dev_build_env,
        jac_desktop_deps_shell_export,
        jac_desktop_webkit_shell_export
    }
    _host_bootstrap --> jaclang.client.targets.desktop.cef_shell {
        _fused_runtime_import_block,
        _host_boot_py
    }
    _host_bootstrap --> jaclang.client.targets.desktop.webview_shell {
        _generate_host_source
    }
    app_layout --> jaclang.client.targets.desktop.macos_bundle { AppLayout }
    app_layout --> jaclang.client.targets.desktop.native.host_boot { AppLayout }
    app_layout --> jaclang.client.targets.desktop.webview_shell { AppLayout }
    cef_shell --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.build {
        cef_build
    }
    cef_shell --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.dev {
        cef_dev_unsupported
    }
    cef_shell --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.start {
        cef_start
    }
    desktop_build --> jaclang.client.targets.desktop.cef_shell {
        _bundle_runtime,
        _find_cef_dir,
        _jac_bin,
        _jac_subprocess_env,
        _patch_host_rpath,
        _stage_fused_runtime,
        build_cef_dispatch,
        build_cef_subprocess,
        stage_program
    }
    desktop_build --> jaclang.client.targets.desktop.native.cef.build {
        build_cef_dispatch,
        build_cef_subprocess
    }
    desktop_build --> jaclang.client.targets.desktop.webview_shell {
        _bundle_runtime,
        _find_webview_dir,
        _jac_bin,
        _jac_subprocess_env,
        _stage_fused_runtime,
        stage_program
    }
    desktop_build --> jaclang.toolchains.manager.setup_toolchain {
        _find_cef_dir,
        _find_webview_dir
    }
    desktop_target --> jaclang.client.targets.register { DesktopTarget }
    macos_bundle --> jaclang.client.targets.desktop.webview_shell {
        write_bundle_metadata
    }
    webview_shell --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.build {
        webview_build
    }
    webview_shell --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.dev {
        webview_dev
    }
    webview_shell --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.start {
        webview_start
    }
}

impl import jaclang.client.targets.desktop.native {
    broker_extension --> jaclang.client.targets.desktop.native.host_boot.serve_program {
        DesktopBrokerExtension
    }
    oauth_broker --> jaclang.client.targets.desktop.native.broker_extension {
        CLOSE_PAGE,
        DEFAULT_PREFIX,
        LOOPBACK_HOSTS,
        PendingAuth,
        SAME_SITE_VALUES,
        SessionStore,
        build_sso_login_url
    }
    oauth_broker --> jaclang.client.targets.desktop.native.host_boot.boot {
        SessionStore
    }
}

impl import jaclang.client.targets.desktop.native.cef {
    cef --> jaclang.client.targets.desktop.native.cef.cef_smoke {
        cef_cleanup,
        new_cef_browser
    }
    cef --> jaclang.client.targets.desktop.native.cef.cef_test_host {
        cef_cleanup,
        cef_execute_subprocess,
        cef_open_browser,
        cef_run_loop,
        cef_startup
    }
    include cef_platform --> jaclang.client.targets.desktop.native.cef.cef_dispatch;
    include cef_platform --> jaclang.client.targets.desktop.native.cef.cef_subprocess;
}

impl import jaclang.client.targets.desktop.native.webview {
    webview --> jaclang.client.targets.desktop.native.plugin_bridge { Webview, respond }
}

impl import jaclang.client.targets.react_native {
    build --> jaclang.client.targets.mobile_target {
        entry_module_for,
        lint_native_incompatible_usage,
        lint_unmapped_tags,
        read_user_js_sources,
        run_eas_local_build,
        run_eas_update_opt_in,
        run_expo_prebuild,
        run_gradle_assemble,
        run_xcodebuild_ios,
        stage_compiled_entry,
        stage_native_image_assets,
        strip_css_imports,
        write_native_entry
    }
    build --> jaclang.client.targets.react_native.dev {
        lint_native_incompatible_usage,
        lint_unmapped_tags,
        read_user_js_sources,
        stage_compiled_entry,
        stage_native_image_assets,
        strip_css_imports,
        write_api_base_shim,
        write_native_entry
    }
    build --> jaclang.client.targets.react_native.scaffold {
        build_native_index_entry_body
    }
    common --> jaclang.client.targets.mobile_target {
        DEFAULT_APP_ID,
        DEFAULT_APP_NAME,
        DEFAULT_APP_SLUG,
        detect_lan_ipv4,
        resolve_rn_project_dir
    }
    common --> jaclang.client.targets.mobile_target.MobileTarget.start {
        normalize_rn_platform
    }
    common --> jaclang.client.targets.react_native.build {
        SUBPROCESS_TIMEOUT_BUILD,
        resolve_node_tool
    }
    common --> jaclang.client.targets.react_native.dev { resolve_node_tool }
    common --> jaclang.client.targets.react_native.scaffold {
        DEFAULT_APP_ID,
        DEFAULT_APP_NAME,
        DEFAULT_APP_SLUG,
        EAS_CLI_VERSION,
        EXPO_SDK_VERSION,
        REACT_NATIVE_VERSION,
        run_manifest_install
    }
    config --> jaclang.client.targets.mobile_target {
        _resolve_rn_android_builder,
        _resolve_rn_eas_profile,
        _resolve_rn_eas_update_branch,
        _resolve_rn_eas_update_enabled,
        _resolve_rn_eas_update_message,
        _resolve_rn_ios_builder,
        _resolve_rn_release
    }
    dev --> jaclang.client.cli.run_client_start { JAC_RN_DEV_HOST_ENV }
    dev --> jaclang.client.targets.mobile_target {
        JAC_RN_DEV_HOST_ENV,
        inject_dev_api_base_url,
        resolve_metro_port,
        restore_app_json,
        rn_hmr_on_jac_changed,
        run_expo_start,
        setup_android_port_reverse
    }
    html_tag_map --> jaclang.client.client_runtime_native {
        RN_HTML_TEXT_TAGS as _TEXT_TAGS,
        RN_HTML_VIEW_TAGS as _VIEW_TAGS
    }
    html_tag_map --> jaclang.client.targets.react_native.build {
        supported_rn_html_tags
    }
    html_tag_map --> jaclang.compiler.passes.jsx_intrinsic_guard_pass._suggestion_for {
        rn_tag_suggestions
    }
    scaffold --> jaclang.client.targets.mobile_target {
        ensure_native_deps_installed,
        write_expo_scaffold
    }
}

impl import jaclang.compiler {
    boundary_audit --> jaclang.client.compiler.ViteCompiler.prepare_bundle {
        boundary_audit
    }
    c_interop --> jaclang.compiler.backends.native.na_ir_gen_pass {
        c_builtin_kind,
        c_type_arg,
        foreign_read_copies,
        foreign_struct_of_type,
        is_builtin_pin_call,
        is_pinned_type,
        is_ptr_type,
        is_ptr_view_type
    }
    c_interop --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._c_copy_rewrite {
        foreign_read_copies
    }
    c_interop --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._c_interop_call_rewrite {
        c_type_spec,
        is_builtin_pin_call
    }
    c_interop --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._clib_block_desc {
        c_type_spec,
        is_foreign_struct_archetype,
        is_opaque_c_archetype
    }
    c_interop --> jaclang.compiler.passes.ownership_check_pass {
        c_call_borrows_args,
        is_c_value_type,
        is_ptr_view_type,
        reads_foreign_storage
    }
    c_interop --> jaclang.compiler.passes.rc_facts_pass.result_ownership {
        foreign_read_copies
    }
    c_interop --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._c_arg_instance {
        c_type_arg
    }
    c_interop --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._c_plain_data {
        foreign_struct_of_type,
        is_ptr_type
    }
    c_interop --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._check_c_interop_call {
        c_type_arg,
        is_builtin_pin_call,
        is_ptr_type,
        opaque_c_of_type
    }
    c_interop --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._check_c_interop_import {
        c_type_arg,
        foreign_struct_of_type,
        is_foreign_struct_archetype,
        is_pinned_type
    }
    c_interop --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._check_c_type_use {
        clib_import_of
    }
    c_interop --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._foreign_struct_contains {
        foreign_struct_of_type
    }
    c_interop --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._opaque_member {
        opaque_c_of_type
    }
    c_interop --> jaclang.compiler.types.type_evaluator.TypeEvaluator._assign_c_interop_args {
        c_type_arg
    }
    c_interop --> jaclang.compiler.types.type_evaluator.TypeEvaluator._is_typed_c_declaration {
        c_builtin_kind
    }
    expr_keys --> jaclang.compiler.backends.native.na_ir_gen_pass { type_tag_borrows }
    expr_keys --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
        is_builtin_region_type
    }
    expr_keys --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_method_call_inner {
        is_builtin_region_type
    }
    expr_keys --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._lower_partition_unpack {
        is_builtin_region_type
    }
    expr_keys --> jaclang.compiler.passes.cfg_build_pass.CFGBuildPass._wire_bool_operands {
        collect_narrowing_symbols
    }
    expr_keys --> jaclang.compiler.passes.cfg_build_pass.CFGBuildPass._wire_compr_filters {
        collect_narrowing_symbols
    }
    expr_keys --> jaclang.compiler.passes.cfg_build_pass.CFGBuildPass.cfg_collect_affected {
        collect_assigned_symbols
    }
    expr_keys --> jaclang.compiler.passes.cfg_build_pass.CFGBuildPass.enter_assert_stmt {
        collect_narrowing_symbols
    }
    expr_keys --> jaclang.compiler.passes.cfg_build_pass.CFGBuildPass.enter_else_if {
        collect_narrowing_symbols
    }
    expr_keys --> jaclang.compiler.passes.cfg_build_pass.CFGBuildPass.enter_if_stmt {
        collect_narrowing_symbols
    }
    expr_keys --> jaclang.compiler.passes.cfg_build_pass.CFGBuildPass.exit_if_else_expr {
        collect_narrowing_symbols
    }
    expr_keys --> jaclang.compiler.passes.ownership_check_pass {
        is_builtin_region_type,
        type_tag_borrows
    }
    expr_keys --> jaclang.compiler.passes.rc_facts_pass.RcFactsPass._asn_makes_region_handle {
        expr_is_builtin_region
    }
    expr_keys --> jaclang.compiler.symbol_utils {
        classify_condition_key,
        collect_assigned_symbols,
        collect_assignment_target_keys,
        collect_narrowing_symbols,
        find_destructure_index_path,
        get_expr_key,
        int_subscript_suffix,
        reference_key_deps
    }
    expr_keys --> jaclang.compiler.types.ownership { type_tag_borrows }
    field_semantics --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._field_constructor_args {
        positional_field_names
    }
    field_semantics --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_archetype {
        positional_field_names
    }
    field_semantics --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
        field_initialization,
        is_field_marker
    }
    field_semantics --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass.exit_has_var {
        is_field_marker
    }
    field_semantics --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass.exit_has_var {
        field_initialization
    }
    field_semantics --> jaclang.compiler.types.type_evaluator.TypeEvaluator._build_field_params {
        field_initialization
    }
    intrinsic_registry --> jaclang.compiler.backends.native.na_ir_gen_pass {
        IntrinsicEntry
    }
    intrinsic_registry --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
        INTRINSIC_REGISTRY
    }
    intrinsic_registry --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_intrinsic {
        IntrinsicDispatch
    }
    intrinsic_registry --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._check_intrinsic_collision {
        IntrinsicRegistry
    }
    intrinsic_registry --> jaclang.compiler.symbol_utils.classify_call {
        IntrinsicRegistry
    }
    intrinsic_registry --> jaclang.compiler.symbol_utils.intrinsic_registry_if_ready {
        INTRINSIC_REGISTRY
    }
    intrinsic_registry --> jaclang.compiler.types.type_evaluator.TypeEvaluator._intrinsic_function_type {
        IntrinsicRegistry
    }
    jc_materialize --> jaclang.compiler.jc_unit {
        hint_commentdata,
        hint_srcdiag,
        jc_mz_dispose,
        jc_mz_obj,
        jc_mz_run,
        jc_mz_shapes3
    }
    native_compiler as _jc --> jaclang.compiler.frontend.parser.frontend._native_parse_woven;
    native_scope --> jaclang.compiler.backends.native.kernel_resolve.kernel_plan {
        kernel_root_path
    }
    native_scope --> jaclang.compiler.driver.compiler.JacCompiler.parse_str {
        in_native_scope_path
    }
    native_scope --> jaclang.compiler.driver.selfhost.SelfHostCache.resolve {
        in_native_scope_path
    }
    native_scope --> jaclang.compiler.frontend.codeinfo._inferred_native_path {
        scope_allows_inferred_path
    }
    native_scope --> jaclang.compiler.frontend.codeinfo.resolve_native_module {
        in_native_scope_path
    }
    native_scope --> jaclang.compiler.placement.placement_facts.native_unit {
        in_native_scope_path
    }
    native_scope --> jaclang.compiler.placement.placement_solver._native_deps_ok {
        in_native_scope_path
    }
    native_scope --> jaclang.compiler.placement.placement_solver.native_default_verdict {
        in_native_scope_path
    }
    native_scope --> jaclang.dist.precompile_bytecode.seal_native { kernel_root_path }
    passes --> jaclang.compiler.tools.code_intel { Alert }
    symbol_utils --> jaclang.compiler.backends.es.esast_gen_pass { return_type_is_jsx }
    symbol_utils --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._bind_client_value_refs {
        client_bridged_endpoint,
        client_value_ref_targets,
        element_display_name
    }
    symbol_utils --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._build_spawn_arg_object {
        collect_field_names,
        symbol_owner_archetype
    }
    symbol_utils --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._build_spawn_runtime_call {
        symbol_owner_archetype
    }
    symbol_utils --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._partition_client_import_items {
        ClientImportVerdict,
        classify_client_import_item,
        is_client_boundary_import,
        report_dead_client_import
    }
    symbol_utils --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._resolve_call_ability {
        ability_of_symbol
    }
    symbol_utils --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._resolve_source_module {
        resolve_import_source_module
    }
    symbol_utils --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass.exit_module {
        report_client_bare_import_uses
    }
    symbol_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._callee_ability_of {
        resolved_callee
    }
    symbol_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_atom_trailer {
        imported_module_name
    }
    symbol_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
        erased_identity_call_arg
    }
    symbol_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_method_call_inner {
        imported_module_name
    }
    symbol_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_synthetic_call {
        ability_of_symbol,
        classify_call,
        resolve_expr_symbol
    }
    symbol_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._isinstance_type_name {
        CallKind,
        classify_call
    }
    symbol_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._native_module_call_target {
        imported_module_name
    }
    symbol_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._unregistered_class_target {
        resolve_expr_symbol
    }
    symbol_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._visit_nonprimary_ancestor_methods {
        collect_method_names
    }
    symbol_utils --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._exit_func_call_impl {
        CallKind,
        classify_call
    }
    symbol_utils --> jaclang.compiler.field_semantics.is_field_marker {
        erased_import_binds
    }
    symbol_utils --> jaclang.compiler.passes.ownership_check_pass {
        CallKind,
        classify_call
    }
    symbol_utils --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._callee_ability {
        resolved_callee
    }
    symbol_utils --> jaclang.compiler.passes.static_analysis_pass.StaticAnalysisPass._check_client_imports {
        ClientImportVerdict,
        classify_client_import_item,
        is_client_boundary_import,
        report_dead_client_import,
        resolve_import_source_module
    }
    symbol_utils --> jaclang.compiler.passes.static_analysis_pass.StaticAnalysisPass._check_placement_warnings {
        report_placement_warnings,
        report_serverless_kind_errors
    }
    symbol_utils --> jaclang.compiler.passes.type_checker_pass { return_type_is_jsx }
    symbol_utils --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._check_intrinsic_collision {
        intrinsic_registry_if_ready
    }
    symbol_utils --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass.exit_func_call {
        ability_of_symbol,
        classify_call,
        resolve_expr_symbol
    }
    symbol_utils --> jaclang.compiler.placement.placement.collect_placement_rows {
        ClientImportVerdict,
        classify_client_import_item,
        is_client_boundary_import,
        resolve_import_source_module
    }
    symbol_utils --> jaclang.compiler.placement.placement_solver.PlacementApplyPass._run_impl {
        report_serverless_kind_errors
    }
    symbol_utils --> jaclang.compiler.placement.placement_solver._pull_boundary_import {
        symbol_linked_source_module
    }
    symbol_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._get_type_from_flow_node {
        collect_assignment_target_keys,
        find_destructure_index_path
    }
    symbol_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._get_type_of_lhs_assignment {
        find_destructure_index_path
    }
    symbol_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._intrinsic_function_type {
        intrinsic_registry_if_ready
    }
    symbol_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._is_sv_async_call {
        ClientImportVerdict,
        classify_client_import_item,
        resolve_import_source_module
    }
    symbol_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._loop_body_writes_target {
        collect_assignment_target_keys
    }
    symbol_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._resolve_importer_path {
        resolve_importer_path_from_node
    }
    symbol_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator.create_key_for_reference {
        int_subscript_suffix
    }
    symbol_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator.flow_pred_never_returns {
        resolve_expr_symbol
    }
    symbol_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator.get_narrowed_type_for_expr {
        reference_key_deps
    }
    type_registry --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._audit_free_identifiers {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._ensure_emitters {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._primitive_type_ref {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass.exit_archetype {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass.exit_func_call {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass.exit_raise_stmt {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass.exit_try_stmt {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.es.esast_gen_pass._raised_exc_identity {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.es.jac_runtime_js._build_exc_runtime_js {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.es.jac_runtime_js._build_types_runtime_js {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.native.foreign { JAC_TYPE_REGISTRY }
    type_registry --> jaclang.compiler.backends.native.na_ir_gen_pass { JacTypeEntry }
    type_registry --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass.__post_init__ {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._c_scalar_llvm {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_name {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_sized_builtin_call {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._ensure_emitters {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._get_exc_descendants {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._get_or_register_exc_type {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.c_interop._spec_for_name { JAC_TYPE_REGISTRY }
    type_registry --> jaclang.compiler.c_interop.c_type_spec { JAC_TYPE_REGISTRY }
    type_registry --> jaclang.compiler.passes.layout_pass { JAC_TYPE_REGISTRY }
    type_registry --> jaclang.compiler.passes.mtir_gen_pass { JAC_TYPE_REGISTRY }
    type_registry --> jaclang.compiler.passes.ownership_check_pass { JAC_TYPE_REGISTRY }
    type_registry --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._handled_by_enclosing_try {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._c_plain_data {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._stamp_fixed_width {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass.exit_archetype {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass.exit_type_alias {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.passes.wasm_contract._host_type {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.passes.wasm_contract.value_contract {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.symbol_utils.classify_call { JAC_TYPE_REGISTRY }
    type_registry --> jaclang.compiler.types.fixed_width {
        JAC_TYPE_REGISTRY,
        NumericKind
    }
    type_registry --> jaclang.compiler.types.operations.is_int_kind_type {
        JAC_TYPE_REGISTRY,
        NumericKind
    }
    type_registry --> jaclang.compiler.types.type_evaluator.TypeEvaluator._assign_class {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.types.type_evaluator.TypeEvaluator._brand_distinct_alias {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.types.type_evaluator.TypeEvaluator._extern_field_type {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.types.type_evaluator.TypeEvaluator._extern_scalar_type {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.types.type_evaluator.TypeEvaluator._is_typed_c_declaration {
        JAC_TYPE_REGISTRY
    }
    type_registry --> jaclang.compiler.types.type_utils.primitive_type_name_of {
        JAC_TYPE_REGISTRY
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
        types as jtypes
    }
}

impl import jaclang.compiler.backends {
    es --> jaclang.compiler.backends.es.client_kernel_cache._lower { estree as es }
    es --> jaclang.compiler.backends.es.es_unparse { estree as es }
    es --> jaclang.compiler.backends.es.jsx_processor.EsJsxProcessor.init {
        estree as es
    }
    es --> jaclang.compiler.driver.pipeline.get_py_code_gen { EsastGenPass }
    es --> jaclang.compiler.tests.xbackend_equiv { EsastGenPass }
    es --> jaclang.compiler.tools.lang_tools { EsastGenPass, es_node_to_dict }
    native --> jaclang.compiler.driver.compiler.JacCompiler._report_missing_native_ir {
        NaIRGenPass
    }
    native --> jaclang.compiler.driver.pipeline.get_py_code_gen {
        NaIRGenPass,
        NativeCompilePass
    }
    native --> jaclang.compiler.driver.pipeline.product_pipeline { NaIRGenPass }
}

impl import jaclang.compiler.backends.common {
    ast_gen_base --> jaclang.compiler.backends.es.esast_gen_pass { BaseAstGenPass }
    ast_gen_base --> jaclang.compiler.backends.py.jcir_gen_pass { BaseAstGenPass }
    primitives --> jaclang.compiler.backends.es.primitives_es {
        BuiltinEmitter,
        BytesEmitter,
        ComplexEmitter,
        DictEmitter,
        FloatEmitter,
        FrozensetEmitter,
        IntEmitter,
        ListEmitter,
        RangeEmitter,
        SetEmitter,
        StrEmitter,
        TupleEmitter
    }
    primitives --> jaclang.compiler.backends.native.primitives_native {
        BuiltinEmitter,
        BytesEmitter,
        ComplexEmitter,
        DictEmitter,
        FloatEmitter,
        FrozensetEmitter,
        IntEmitter,
        ListEmitter,
        RangeEmitter,
        SetEmitter,
        StrEmitter,
        TupleEmitter
    }
}

impl import jaclang.compiler.backends.es {
    client_kernel_cache --> jaclang.compiler.backends.es.jac_runtime_js.build_osp_core_js {
        osp_core_js
    }
    es_unparse --> jaclang.compiler.backends.es.client_kernel_cache._lower { es_to_js }
    es_unparse --> jaclang.compiler.backends.es.esast_gen_pass {
        JSCodeGenerator,
        es_to_js
    }
    es_unparse --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._try_primitive_op {
        JSCodeGenerator
    }
    es_unparse --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass.exit_func_call {
        JSCodeGenerator
    }
    es_unparse --> jaclang.compiler.backends.es.jac_runtime_js._build_types_runtime_js {
        JSCodeGenerator
    }
    es_unparse --> jaclang.compiler.driver.compiler.JacCompiler.client_artifact_of {
        es_to_js_with_map
    }
    es_unparse --> jaclang.compiler.tests.xbackend_equiv { es_to_js }
    es_unparse --> jaclang.compiler.tools.lang_tools { es_to_js }
    esast_gen_pass --> jaclang.compiler.backends.es.client_kernel_cache._lower {
        EsastGenPass
    }
    type esast_gen_pass --> jaclang.compiler.backends.es.jsx_processor { EsastGenPass }
    esast_gen_pass --> jaclang.compiler.driver.pipeline.product_pipeline {
        EsastGenPass
    }
    esast_gen_pass --> jaclang.compiler.tests.test_client_codegen_facts { EsastGenPass }
    esast_gen_pass --> jaclang.dist.publish.npm_sources._compile_module { EsastGenPass }
    estree as es --> jaclang.compiler.backends.es.backends.react;
    estree as es --> jaclang.compiler.backends.es.backends.solid;
    estree as es --> jaclang.compiler.backends.es.esast_gen_pass;
    estree as es --> jaclang.compiler.backends.es.framework_backend;
    estree as es --> jaclang.compiler.backends.es.free_ident_audit;
    type estree --> jaclang.compiler.backends.es.jsx_processor { Expression }
    estree as es --> jaclang.compiler.backends.es.reactive_intent;
    estree as es --> jaclang.compiler.backends.es.view_ir;
    estree --> jaclang.compiler.driver.compiler.JacCompiler.client_artifact_of {
        Node as EsNode
    }
    type estree --> jaclang.compiler.frontend.codeinfo {
        IndexInfo,
        Node as EsNode,
        SliceInfo
    }
    estree --> jaclang.compiler.tests.xbackend_equiv { Node as EsNode }
    estree --> jaclang.compiler.tools.lang_tools { Node as EsNode }
    type framework_backend --> jaclang.client.client_surface { FrameworkBackend }
    framework_backend --> jaclang.compiler.backends.es.backends.react {
        FrameworkBackend
    }
    framework_backend --> jaclang.compiler.backends.es.backends.registry {
        FrameworkBackend
    }
    framework_backend --> jaclang.compiler.backends.es.backends.solid {
        FrameworkBackend
    }
    framework_backend --> jaclang.compiler.backends.es.esast_gen_pass {
        FrameworkBackend
    }
    free_ident_audit --> jaclang.compiler.backends.es.esast_gen_pass {
        FreeIdentifier,
        RUNTIME_PRELUDE_GLOBALS,
        client_ambient_globals,
        free_identifiers
    }
    jac_runtime_js --> jaclang.client.jac_client_compiler.JacClientCompiler.emit_prelude {
        write_jac_prelude_file
    }
    jac_runtime_js --> jaclang.client.vite_bundler.ViteBundler._generate_vite_config_content {
        JAC_PRELUDE_BASENAME
    }
    jac_runtime_js --> jaclang.compiler.backends.es.client_kernel_cache._lower {
        JAC_PRELUDE_MODULE
    }
    jac_runtime_js --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._inject_runtime_import {
        JAC_PRELUDE_MODULE
    }
    jac_runtime_js --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass.exit_module {
        JAC_PRELUDE_MODULE,
        build_osp_core_js,
        build_osp_driver_js
    }
    jac_runtime_js --> jaclang.compiler.tests.xbackend_equiv._prelude_cwd {
        stage_jac_prelude_package
    }
    jac_runtime_js --> jaclang.compiler.tests.xbackend_equiv.run_js_module_fixture {
        stage_jac_prelude_package
    }
    jac_runtime_js --> jaclang.dist.publish.runtime_npm._point_at_packaged_prelude {
        JAC_PRELUDE_BASENAME,
        JAC_PRELUDE_MODULE
    }
    jac_runtime_js --> jaclang.dist.publish.runtime_npm.build_runtime_tarball {
        JAC_PRELUDE_BASENAME,
        build_jac_prelude_module
    }
    jac_runtime_js --> jaclang.testing.cl_test_runner._point_at_staged_prelude {
        point_jac_prelude_at
    }
    jac_runtime_js --> jaclang.testing.cl_test_runner._run_harness {
        JAC_PRELUDE_BASENAME,
        build_jac_prelude_module
    }
    jsx_processor --> jaclang.compiler.backends.es.esast_gen_pass { EsJsxProcessor }
    primitives_es --> jaclang.compiler.backends.es.esast_gen_pass {
        ESBuiltinEmitter,
        ESEmitCtx
    }
    primitives_es as _pes --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._ensure_emitters;
    primitives_es --> jaclang.compiler.backends.es.jac_runtime_js._build_types_runtime_js {
        ESBuiltinEmitter,
        ESEmitCtx
    }
    reactive_intent --> jaclang.compiler.backends.es.backends.react {
        AsyncBoundary,
        Effect,
        RefField,
        StateField,
        StateUpdate
    }
    reactive_intent --> jaclang.compiler.backends.es.backends.solid {
        AsyncBoundary,
        Effect,
        RefField,
        StateField,
        StateUpdate
    }
    reactive_intent --> jaclang.compiler.backends.es.esast_gen_pass {
        AsyncBoundary,
        Effect,
        RefField,
        StateField,
        StateUpdate
    }
    reactive_intent --> jaclang.compiler.backends.es.framework_backend {
        AsyncBoundary,
        Effect,
        RefField,
        StateField,
        StateUpdate
    }
    scoped_styles --> jaclang.compiler.backends.es.esast_gen_pass {
        ScopedStyleSheet,
        load_style_annex
    }
    type view_ir --> jaclang.compiler.backends.es.backends.react { ViewElement }
    view_ir --> jaclang.compiler.backends.es.backends.react.ReactBackend._view_attr_property {
        DynamicAttr,
        EventAttr
    }
    view_ir --> jaclang.compiler.backends.es.backends.react.ReactBackend.lower_view {
        ComponentTag,
        DynamicChild,
        DynamicTag,
        EachChild,
        ElementChild,
        HostTag,
        IfChild,
        SpreadAttr,
        TextChild
    }
    type view_ir --> jaclang.compiler.backends.es.backends.solid {
        ViewChild,
        ViewElement
    }
    view_ir --> jaclang.compiler.backends.es.backends.solid.SolidBackend._jsx_attr {
        EventAttr,
        SpreadAttr,
        StaticAttr
    }
    view_ir --> jaclang.compiler.backends.es.backends.solid.SolidBackend._jsx_child_nodes {
        DynamicChild,
        EachChild,
        ElementChild,
        FragmentTag,
        IfChild,
        TextChild
    }
    view_ir --> jaclang.compiler.backends.es.backends.solid.SolidBackend._view_children_as_expr {
        ElementChild,
        FragmentTag
    }
    view_ir --> jaclang.compiler.backends.es.backends.solid.SolidBackend.lower_async_boundary {
        ComponentTag,
        DynamicAttr,
        DynamicChild,
        ElementChild,
        ViewElement
    }
    view_ir --> jaclang.compiler.backends.es.backends.solid.SolidBackend.lower_view {
        ComponentTag,
        FragmentTag,
        HostTag
    }
    view_ir --> jaclang.compiler.backends.es.backends.solid.SolidBackend.view_runtime_symbols {
        EachChild,
        ElementChild,
        IfChild
    }
    type view_ir --> jaclang.compiler.backends.es.framework_backend { ViewElement }
    type view_ir --> jaclang.compiler.backends.es.jsx_processor {
        DynamicAttr,
        EachChild,
        EventAttr,
        IfChild,
        RefAttr,
        SpreadAttr,
        StaticAttr,
        ViewChild,
        ViewElement
    }
    view_ir --> jaclang.compiler.backends.es.jsx_processor.EsJsxProcessor._lift_each {
        EachChild,
        ElementChild,
        ViewElement
    }
    view_ir --> jaclang.compiler.backends.es.jsx_processor.EsJsxProcessor._lift_if {
        IfChild
    }
    view_ir --> jaclang.compiler.backends.es.jsx_processor.EsJsxProcessor._split_key {
        DynamicAttr,
        StaticAttr
    }
    view_ir --> jaclang.compiler.backends.es.jsx_processor.EsJsxProcessor._view_arm {
        ElementChild
    }
    view_ir --> jaclang.compiler.backends.es.jsx_processor.EsJsxProcessor.element {
        ComponentTag,
        DynamicChild,
        DynamicTag,
        ElementChild,
        FragmentTag,
        HostTag,
        SlotChild,
        SpreadAttr,
        TextChild,
        ViewElement
    }
    view_ir --> jaclang.compiler.backends.es.jsx_processor.EsJsxProcessor.normal_attribute {
        DynamicAttr,
        EventAttr,
        RefAttr,
        StaticAttr
    }
}

impl import jaclang.compiler.backends.es.backends {
    preact --> jaclang.compiler.backends.es.backends.registry.resolve_framework_backend {
        PreactBackend
    }
    react --> jaclang.compiler.backends.es.backends.preact { ReactBackend }
    react --> jaclang.compiler.backends.es.backends.registry.resolve_framework_backend {
        ReactBackend
    }
    react --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._ensure_backend {
        ReactBackend
    }
    registry --> jaclang.client.client_surface.prepend_active_runtime_globals {
        resolve_active_backend
    }
    registry --> jaclang.client.compiler.ViteCompiler._create_pages_entry_content {
        resolve_active_backend
    }
    registry --> jaclang.client.compiler.ViteCompiler.create_entry_file {
        resolve_active_backend
    }
    registry --> jaclang.client.vite_bundler.ViteBundler._generate_vite_config_content {
        resolve_active_backend
    }
    registry --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._ensure_backend {
        resolve_active_backend
    }
    registry --> jaclang.compiler.driver.build_services.CompilerBuildServices.client_runtime_basename {
        resolve_active_backend,
        resolve_framework_backend
    }
    registry --> jaclang.compiler.driver.compiler.JacCompiler._get_client_artifact {
        resolve_active_backend
    }
    registry --> jaclang.compiler.driver.compiler.JacCompiler.client_artifact_of {
        resolve_active_backend
    }
    solid --> jaclang.compiler.backends.es.backends.registry.resolve_framework_backend {
        SolidBackend
    }
}

impl import jaclang.compiler.backends.native {
    abi --> jaclang.compiler.backends.native.na_ir_gen_pass { classify_foreign_fn }
    abi --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._build_jc_layout {
        struct_layouts
    }
    c_emit --> jaclang.dist.native_product.write_native_product { emit_c }
    c_emit --> jaclang.dist.source.client.write_client { emit_c }
    elf_linker --> jaclang.compiler.backends.native.link_plan.link_artifact {
        ElfLinker
    }
    floor --> jaclang.compiler.backends.native.static_link.clib_needed_libs {
        clib_needed_libs as implementation
    }
    floor --> jaclang.compiler.backends.native.static_link.clib_symbol_lib_map {
        clib_symbol_lib_map as implementation
    }
    floor --> jaclang.compiler.backends.native.static_link.clib_to_archive_name {
        clib_to_archive_name as implementation
    }
    floor --> jaclang.compiler.backends.native.static_link.collect_floor_archives {
        collect_floor_archives as implementation
    }
    floor --> jaclang.compiler.backends.native.static_link.floor_lib_dir {
        floor_lib_dir as implementation
    }
    floor --> jaclang.compiler.backends.native.static_link.resolve_floor_dir {
        resolve_floor_dir as implementation
    }
    foreign --> jaclang.compiler.backends.native.abi.classify_foreign_fn {
        foreign_struct_layout
    }
    foreign --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._clib_struct_layout {
        foreign_struct_layout
    }
    foreign --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
        declared_type_name
    }
    foreign --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._foreign_fns {
        collect_foreign_fns
    }
    foreign --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._foreign_model {
        collect_foreign_structs
    }
    kernel_resolve --> jaclang.compiler.native_compiler.ensure_loaded { resolve_kernel }
    kernel_resolve --> jaclang.dist.precompile_bytecode.seal_native { kernel_lib_name }
    link_glue --> jaclang.compiler.backends.native.link_plan {
        ENTRY_SYMBOL,
        GlueSpec,
        GlueUnit,
        REGION_DIED_HOOK,
        SHARED_INIT_SYMBOL,
        STR_NEW_SYMBOL,
        init_object_codegen,
        link_glue_ir
    }
    link_glue --> jaclang.compiler.backends.native.link_plan.callback_glue_ir {
        bind_shared_callbacks
    }
    link_glue --> jaclang.compiler.backends.native.link_plan.heap_glue_ir {
        inject_heap_accounting
    }
    link_plan --> jaclang.cli.commands.native_build { LinkPlan }
    link_plan --> jaclang.cli.commands.native_build.native_build {
        ArtifactKind,
        LinkPlanError,
        build_link_plan,
        link_artifact
    }
    link_plan --> jaclang.compiler.backends.native.kernel_resolve._sidecar_matches_sources {
        units_source_key
    }
    link_plan --> jaclang.compiler.backends.native.kernel_resolve.build_kernel {
        ArtifactKind,
        link_artifact
    }
    link_plan --> jaclang.compiler.backends.native.kernel_resolve.kernel_plan {
        build_link_plan
    }
    link_plan --> jaclang.compiler.backends.native.na_compile_pass.NativeCompilePass._run_impl {
        SymbolCollision,
        jit_engine_for_module
    }
    link_plan --> jaclang.compiler.driver.compiler.JacCompiler._load_native_from_cache {
        jit_engine_for_cached
    }
    link_plan --> jaclang.compiler.driver.nativecache.NativeUnitRegistry.compile_unit {
        build_link_plan
    }
    link_plan --> jaclang.compiler.driver.pipeline_runner.wasm_ir {
        build_link_plan,
        wasm_program_ir
    }
    link_plan --> jaclang.dist.native_product.write_native_product {
        ArtifactKind,
        build_link_plan,
        link_artifact,
        optimize_merged_program,
        whole_program_module
    }
    link_plan --> jaclang.dist.precompile_bytecode.seal_native {
        ArtifactKind,
        build_link_plan,
        link_artifact
    }
    linker_common --> jaclang.compiler.backends.native.elf_linker {
        _align,
        _append_to_blob,
        _build_strtab,
        _find_entry_vaddr,
        _resolve_patch_site,
        _resolve_seg_vaddr
    }
    linker_common --> jaclang.compiler.backends.native.floor.collect_floor_archives {
        select_ar_members
    }
    linker_common --> jaclang.compiler.backends.native.macho_linker {
        _align,
        _append_to_blob,
        _build_strtab,
        _find_entry_vaddr,
        _resolve_patch_site,
        _resolve_seg_vaddr,
        encode_uleb128
    }
    linker_common --> jaclang.compiler.backends.native.pe_linker {
        _align,
        _append_to_blob,
        _resolve_seg_vaddr
    }
    linker_common --> jaclang.compiler.backends.native.static_link {
        object_undefined_symbols,
        select_ar_members
    }
    linker_common --> jaclang.compiler.backends.native.wasm_artifact.wasm_import_map {
        read_leb_name,
        read_uleb128
    }
    linker_common --> jaclang.compiler.backends.native.wasm_build.wasm_import_map {
        read_leb_name,
        read_uleb128
    }
    linker_common --> jaclang.compiler.backends.native.wasm_linker {
        encode_sleb128,
        encode_uleb128,
        encode_uleb128_padded5,
        read_leb_name,
        read_sleb128,
        read_uleb128
    }
    llvm --> jaclang.compiler.backends.native.abi { ir }
    llvm --> jaclang.compiler.backends.native.abi.struct_layouts { binding }
    llvm --> jaclang.compiler.backends.native.llvm.binding.ffi {
        _find_shim,
        _shim_name
    }
    llvm --> jaclang.compiler.backends.native.llvm.ir.types {
        ir_layer_typed_pointers_enabled
    }
    llvm --> jaclang.compiler.backends.native.lowering { ir }
    llvm --> jaclang.compiler.backends.native.na_ir_gen_pass { binding as llvm, ir }
    llvm --> jaclang.compiler.backends.native.primitives_native { ir }
    llvm --> jaclang.compiler.driver.pipeline.native_pipeline_available { _find_shim }
    lowering --> jaclang.compiler.backends.native.entry_points.validate_native_application {
        native_lowering_issues
    }
    lowering --> jaclang.compiler.backends.native.na_compile_pass.native_demoted_ir_symbols {
        NativeLoweringKind,
        native_lowering_issues
    }
    lowering --> jaclang.compiler.backends.native.na_compile_pass.require_native_ir {
        native_lowering_issues
    }
    lowering --> jaclang.compiler.backends.native.na_ir_gen_pass {
        NativeLoweringIssue,
        NativeLoweringKind
    }
    lowering --> jaclang.compiler.tests.test_prim_equivalence { native_lowering_issues }
    macho_linker --> jaclang.compiler.backends.native.link_plan.link_artifact {
        MachOLinker
    }
    na_compile_pass --> jaclang.cli.commands.analysis.explain { native_linked_ir_text }
    na_compile_pass --> jaclang.compiler.backends.native.entry_points.validate_native_application {
        native_demoted_ir_symbols,
        native_linked_ir_text
    }
    na_compile_pass --> jaclang.compiler.backends.native.link_plan {
        NATIVE_CODE_MODEL,
        NATIVE_RELOC_MODEL,
        load_jit_clib,
        optimize_unit
    }
    na_compile_pass --> jaclang.compiler.backends.native.wasm_build.prepare_wasm_module {
        optimize_unit
    }
    na_compile_pass --> jaclang.compiler.driver.nativecache.NativeBuildSession._finish {
        NativeCompilePass
    }
    na_compile_pass --> jaclang.compiler.driver.nativecache.NativeUnitRegistry.object_for {
        emit_unit_object
    }
    na_compile_pass --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.native_checks {
        NativeCompilePass
    }
    na_constants --> jaclang.compiler.backends.native.na_ir_gen_pass {
        CLASS_DISPLAY_OFF,
        LIVE_NODE_NEXT_OFF,
        LIVE_NODE_RC_OFF,
        LIVE_NODE_SIZE,
        LIVE_NODE_TAG_OFF,
        LIVE_NODE_USER_OFF,
        NATIVE_OSPATH_FUNCS,
        NATIVE_OS_FUNCS,
        NATIVE_RANDOM_FUNCS,
        NATIVE_STRUCT_FUNCS,
        RC_BUFFERED_BIT,
        RC_COLOR_BLACK,
        RC_COLOR_GRAY,
        RC_COLOR_PURPLE,
        RC_COLOR_SHIFT,
        RC_COLOR_WHITE,
        RC_CYCLE_THRESHOLD
    }
    type na_ir_gen_pass --> jaclang.compiler.backends.native.primitives_native {
        NaIRGenPass
    }
    na_ir_gen_pass --> jaclang.compiler.driver.nativecache.NativeBuildSession.lower {
        NaIRGenPass
    }
    pe_linker --> jaclang.compiler.backends.native.link_plan.link_artifact { PeLinker }
    primitives_native --> jaclang.compiler.backends.native.na_ir_gen_pass {
        NativeDictEmitter,
        NativeEmitCtx,
        NativeFloatEmitter,
        NativeIntEmitter,
        NativeSetEmitter
    }
    primitives_native as _pn --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._ensure_emitters;
    region_abi --> jaclang.compiler.backends.native.na_ir_gen_pass { REGION_KERNEL_ABI }
    static_link --> jaclang.compiler.backends.native.link_plan {
        clib_needed_libs,
        clib_symbol_lib_map,
        collect_floor_archives,
        load_musl_static
    }
    wasm_artifact --> jaclang.client.compiler.ViteCompiler._compile_wasm_module {
        wasm_assets
    }
    wasm_artifact --> jaclang.dist.source.build.build_native_product { wasm_assets }
    wasm_build --> jaclang.cli.commands.native_build.native_build {
        app_declared_imports
    }
    wasm_build --> jaclang.compiler.backends.native.link_plan.link_wasm {
        emit_wasm_from_ir
    }
    wasm_build --> jaclang.compiler.driver.pipeline_runner.wasm_artifact {
        emit_wasm_from_ir
    }
    wasm_build --> jaclang.compiler.driver.pipeline_runner.wasm_ir {
        _assert_ir_rc_free,
        _project_gc_settings,
        app_declared_imports
    }
    wasm_build --> jaclang.dist.native_product.write_native_product {
        _assert_ir_rc_free
    }
    wasm_build --> jaclang.dist.source.client.write_client { prepare_wasm_module }
    wasm_host_abi --> jaclang.compiler.backends.native.wasm_artifact {
        WASM_HOST_MODULE
    }
    wasm_host_abi --> jaclang.compiler.backends.native.wasm_build._link_wasm_libc {
        WASM_HOST_ABI
    }
    wasm_host_abi --> jaclang.compiler.backends.native.wasm_build.emit_wasm_from_ir {
        WASM_HOST_ABI,
        WASM_HOST_MODULE
    }
    wasm_host_abi --> jaclang.dist.source.build.build_native_product {
        WASM_HOST_ABI,
        WASM_HOST_MODULE
    }
    wasm_linker --> jaclang.compiler.backends.native.wasm_build.emit_wasm_from_ir {
        WasmLinker
    }
    wasm_linker --> jaclang.dist.source.build.build_native_product { WasmLinker }
}

impl import jaclang.compiler.backends.native.llvm {
    binding as llvm --> jaclang.cli.commands.execution._jab_native_bin;
    binding as llvm --> jaclang.cli.commands.native_build._application_ir;
    binding as llvm --> jaclang.compiler.backends.native.link_glue.bind_shared_callbacks;
    binding as llvm --> jaclang.compiler.backends.native.link_glue.init_object_codegen;
    binding as llvm --> jaclang.compiler.backends.native.link_plan;
    type binding --> jaclang.compiler.backends.native.link_plan {
        ExecutionEngine,
        ModuleRef,
        TargetMachine
    }
    binding --> jaclang.compiler.backends.native.llvm.binding.config { ffi }
    binding --> jaclang.compiler.backends.native.llvm.binding.context { ffi }
    binding --> jaclang.compiler.backends.native.llvm.binding.dylib { ffi }
    binding --> jaclang.compiler.backends.native.llvm.binding.executionengine {
        ffi,
        object_file,
        targets
    }
    binding --> jaclang.compiler.backends.native.llvm.binding.initfini { ffi }
    binding --> jaclang.compiler.backends.native.llvm.binding.linker { ffi }
    binding --> jaclang.compiler.backends.native.llvm.binding.module { ffi }
    binding --> jaclang.compiler.backends.native.llvm.binding.newpassmanagers { ffi }
    binding --> jaclang.compiler.backends.native.llvm.binding.object_file { ffi }
    binding --> jaclang.compiler.backends.native.llvm.binding.options { ffi }
    binding --> jaclang.compiler.backends.native.llvm.binding.targets { ffi }
    binding --> jaclang.compiler.backends.native.llvm.binding.value { ffi }
    binding as llvm --> jaclang.compiler.backends.native.na_compile_pass;
    type binding --> jaclang.compiler.backends.native.na_compile_pass {
        ModuleRef,
        TargetMachine
    }
    binding as _llvm_bind --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass.__post_init__;
    type binding --> jaclang.compiler.backends.native.wasm_build {
        ModuleRef,
        TargetMachine,
        ValueRef
    }
    binding as llvm --> jaclang.compiler.backends.native.wasm_build._load_libc_module;
    binding as llvm --> jaclang.compiler.backends.native.wasm_build.prepare_wasm_module;
    binding --> jaclang.compiler.driver.compile_options.CompileOptions.effective_triple {
        get_default_triple
    }
    binding as llvm --> jaclang.compiler.driver.compiler.JacCompiler._load_native_from_cache;
    type binding --> jaclang.compiler.driver.compiler.JacCompiler._load_native_from_cache {
        ExecutionEngine
    }
    type binding --> jaclang.compiler.frontend.codeinfo { ExecutionEngine, ModuleRef }
    binding as llvm --> jaclang.dist.seal.bake_native_payloads;
    ir --> jaclang.compiler.backends.native.llvm.ir.builder {
        instructions,
        types,
        values
    }
    ir --> jaclang.compiler.backends.native.llvm.ir.context { _utils, types }
    ir --> jaclang.compiler.backends.native.llvm.ir.instructions { types }
    ir --> jaclang.compiler.backends.native.llvm.ir.module {
        _utils,
        context,
        types,
        values
    }
    ir --> jaclang.compiler.backends.native.llvm.ir.types.Aggregate.wrap_constant_value {
        Constant,
        Value
    }
    ir --> jaclang.compiler.backends.native.llvm.ir.types.Type.__call__ { Constant }
    ir --> jaclang.compiler.backends.native.llvm.ir.types.VectorType.wrap_constant_value {
        Constant,
        Value
    }
    ir --> jaclang.compiler.backends.native.llvm.ir.values { _utils, types, values }
    type ir --> jaclang.compiler.frontend.codeinfo { Module as IRModule }
}

impl import jaclang.compiler.backends.native.llvm.binding {
    common --> jaclang.compiler.backends.native.llvm.binding.dylib { _encode_string }
    common --> jaclang.compiler.backends.native.llvm.binding.ffi { _is_shutting_down }
    common --> jaclang.compiler.backends.native.llvm.binding.module {
        _decode_string,
        _encode_string
    }
    common --> jaclang.compiler.backends.native.llvm.binding.options { _encode_string }
    common --> jaclang.compiler.backends.native.llvm.binding.targets {
        _decode_string,
        _encode_string
    }
    common --> jaclang.compiler.backends.native.llvm.binding.value {
        _decode_string,
        _encode_string
    }
    include config --> jaclang.compiler.backends.native.llvm.binding;
    config --> jaclang.compiler.backends.native.llvm.binding.targets {
        _has_svml as has_svml
    }
    include context --> jaclang.compiler.backends.native.llvm.binding;
    context --> jaclang.compiler.backends.native.llvm.binding.module {
        get_global_context
    }
    include dylib --> jaclang.compiler.backends.native.llvm.binding;
    type executionengine --> jaclang.cli.commands.execution { ExecutionEngine }
    include executionengine --> jaclang.compiler.backends.native.llvm.binding;
    include initfini --> jaclang.compiler.backends.native.llvm.binding;
    initfini --> jaclang.compiler.backends.native.llvm.binding.targets {
        llvm_version_info
    }
    include linker --> jaclang.compiler.backends.native.llvm.binding;
    linker --> jaclang.compiler.backends.native.llvm.binding.module { link_modules }
    include module --> jaclang.compiler.backends.native.llvm.binding;
    include newpassmanagers --> jaclang.compiler.backends.native.llvm.binding;
    include object_file --> jaclang.compiler.backends.native.llvm.binding;
    include options --> jaclang.compiler.backends.native.llvm.binding;
    include targets --> jaclang.compiler.backends.native.llvm.binding;
    type value --> jaclang.compiler.backends.native.link_plan { ValueRef }
    value --> jaclang.compiler.backends.native.link_plan.internalize_native_implementation {
        Visibility
    }
    include value --> jaclang.compiler.backends.native.llvm.binding;
    value --> jaclang.compiler.backends.native.llvm.binding.module { ValueRef }
    type value --> jaclang.compiler.backends.native.llvm.binding.targets { ValueRef }
}

impl import jaclang.compiler.backends.native.llvm.ir {
    _utils --> jaclang.compiler.backends.native.llvm.ir.instructions { _HasMetadata }
    _utils --> jaclang.compiler.backends.native.llvm.ir.types { _StrCaching }
    _utils --> jaclang.compiler.backends.native.llvm.ir.values {
        _HasMetadata,
        _StrCaching,
        _StringReferenceCaching
    }
    include builder --> jaclang.compiler.backends.native.llvm.ir;
    context --> jaclang.compiler.backends.native.llvm.ir { Context, global_context }
    include instructions --> jaclang.compiler.backends.native.llvm.ir;
    include module --> jaclang.compiler.backends.native.llvm.ir;
    module --> jaclang.compiler.backends.native.llvm.ir.instructions { Module }
    types --> jaclang.compiler.backends.native.link_glue.bind_shared_callbacks {
        _wrapname
    }
    include types --> jaclang.compiler.backends.native.llvm.ir;
    include values --> jaclang.compiler.backends.native.llvm.ir;
    values --> jaclang.compiler.backends.native.llvm.ir.builder { Value }
    values --> jaclang.compiler.backends.native.llvm.ir.instructions {
        ArgumentAttributes,
        AttributeSet,
        Block,
        Constant,
        Function,
        MetaDataArgument,
        MetaDataString,
        NamedValue,
        Value
    }
}

impl import jaclang.compiler.backends.py {
    artifact_imports --> jaclang.compiler.driver.application._prepare {
        package_sources,
        runtime_sources
    }
    artifact_imports --> jaclang.compiler.driver.application._prepare_sealed {
        package_sources,
        runtime_sources
    }
    artifact_imports --> jaclang.compiler.driver.pipeline.compile_application {
        package_sources
    }
    artifact_imports --> jaclang.dist.precompile_bytecode.seal_runtime_closure {
        runtime_sources
    }
    codegen_ir --> jaclang.compiler.backends.py.codegen_shim {
        CirContainer,
        CirDiag,
        CirModule,
        CodegenIrFormatError,
        CodegenIrVersionError,
        DIAG_ERROR,
        OP_BYTES,
        OP_ELLIPSIS,
        OP_END,
        OP_FALSE,
        OP_FLOAT,
        OP_INT,
        OP_INT_BIG,
        OP_LIST,
        OP_LOC,
        OP_NODE,
        OP_NONE,
        OP_PARSE_SPLICE,
        OP_STR,
        OP_TRUE,
        OP_TUPLE,
        _r_svarint,
        _r_varint,
        read_container
    }
    codegen_ir --> jaclang.compiler.backends.py.jcir_gen_pass { CodegenIrWriter }
    codegen_shim --> jaclang.compiler.backends.py.jcir_bc_gen_pass.JcirBytecodeGenPass.transcribe_module {
        compile_ir
    }
    jcir_bc_gen_pass --> jaclang.compiler.driver.pipeline { JcirBytecodeGenPass }
    jcir_facts --> jaclang.compiler.backends.py.codegen_ir { jcir_python_version }
    jcir_facts --> jaclang.compiler.backends.py.jcir_gen_pass {
        JCIR_AMBIENT_TYPING_NAMES,
        JCIR_BUILTIN_NAMES,
        jcir_is_test_path
    }
    jcir_gen_pass --> jaclang.compiler.driver.compiler { JcirGenPass }
    jcir_gen_pass --> jaclang.compiler.driver.pipeline { JcirGenPass }
}

impl import jaclang.compiler.backends.py.jacpython {
    assembler --> jaclang.compiler.backends.py.jacpython.compiler_annotations {
        assemble
    }
    assembler --> jaclang.compiler.backends.py.jacpython.compiler_codegen { assemble }
    assembler --> jaclang.compiler.backends.py.jacpython.compiler_defs { assemble }
    assembler --> jaclang.compiler.backends.py.jacpython.compiler_emit { assemble }
    assembler --> jaclang.compiler.backends.py.jacpython.product_compile { assemble }
    codegen_util --> jaclang.compiler.backends.py.jacpython.compiler_annotations {
        expr_loc,
        nloc,
        no_loc,
        stmt_loc
    }
    codegen_util --> jaclang.compiler.backends.py.jacpython.compiler_codegen {
        args_have_kw_defaults,
        ast_cmp_kind,
        ast_node_name,
        async_function_def_loc,
        binop_id,
        body_docstring,
        body_is_try_except_only,
        body_is_try_finally_only,
        call_effective_args,
        call_func_loc,
        class_effective_bases,
        class_effective_keywords,
        cmpop_filter_oparg,
        cmpop_oparg,
        comp_bound_names_from_target,
        comp_dict_map_loc,
        comp_leftmost_leaf,
        comp_name_bound,
        display_all_constant,
        display_const_items,
        display_has_starred,
        exec_tail_emits_code,
        expr_loc,
        fold_slice_const,
        function_argcounts,
        function_code_flags,
        function_def_loc,
        import_bind_name,
        inplace_binop_id,
        is_seq_literal,
        loop_body_has_break,
        match_pattern_loc,
        match_pattern_unwrap_or,
        match_pattern_wildcard,
        nloc,
        seq_target_elts,
        starred_target_index,
        stmt_loc,
        top_loc,
        try_fold_binop,
        try_handler_span,
        unary_opcode
    }
    codegen_util --> jaclang.compiler.backends.py.jacpython.compiler_defs {
        async_function_def_loc,
        body_docstring,
        class_effective_bases,
        class_effective_keywords,
        exec_tail_emits_code,
        expr_loc,
        function_argcounts,
        function_code_flags,
        function_def_loc,
        import_bind_name,
        nested_code_qualname,
        nloc,
        stmt_loc
    }
    codegen_util --> jaclang.compiler.backends.py.jacpython.compiler_emit {
        args_have_kw_defaults,
        ast_cmp_kind,
        ast_node_name,
        async_function_def_loc,
        binop_id,
        body_is_try_except_only,
        body_is_try_finally_only,
        call_effective_args,
        call_effective_keywords,
        call_func_loc,
        class_effective_bases,
        class_effective_keywords,
        cmpop_filter_oparg,
        cmpop_oparg,
        comp_bound_names_from_target,
        comp_dict_map_loc,
        comp_leftmost_leaf,
        comp_name_bound,
        display_all_constant,
        display_const_items,
        display_has_starred,
        exec_tail_emits_code,
        expr_loc,
        fold_default_leaf_values,
        fold_slice_const,
        function_argcounts,
        function_code_flags,
        function_def_loc,
        import_bind_name,
        inplace_binop_id,
        is_seq_literal,
        loop_body_has_break,
        match_pattern_loc,
        match_pattern_unwrap_or,
        match_pattern_wildcard,
        nested_code_qualname,
        nloc,
        seq_target_elts,
        starred_target_index,
        stmt_loc,
        top_loc,
        try_fold_binop,
        try_handler_span,
        unary_opcode
    }
    codegen_util --> jaclang.compiler.backends.py.jacpython.compiler_exc {
        body_is_try_except_only,
        body_is_try_finally_only,
        exec_tail_emits_code,
        expr_loc,
        nloc,
        stmt_loc,
        try_handler_span
    }
    codegen_util --> jaclang.compiler.backends.py.jacpython.compiler_loops {
        exec_tail_emits_code,
        expr_loc,
        loop_body_has_break,
        loop_body_has_try,
        nloc
    }
    codegen_util --> jaclang.compiler.backends.py.jacpython.compiler_match {
        exec_tail_emits_code,
        expr_loc,
        match_pattern_loc,
        match_pattern_unwrap_or,
        match_pattern_wildcard,
        nloc,
        stmt_loc
    }
    compiler_annotations --> jaclang.compiler.backends.py.jacpython.compiler_codegen {
        ann_scope_plan,
        collect_ann_plan,
        emit_module_annotation_setup,
        finish_module_annotations,
        visit_ann_assign
    }
    compiler_annotations --> jaclang.compiler.backends.py.jacpython.compiler_defs {
        collect_ann_plan_class,
        emit_class_annotation_setup,
        emit_future_function_annotations,
        finish_class_annotations
    }
    compiler_annotations --> jaclang.compiler.backends.py.jacpython.compiler_exc {
        ann_scope_plan
    }
    compiler_annotations --> jaclang.compiler.backends.py.jacpython.compiler_loops {
        ann_scope_plan
    }
    compiler_annotations --> jaclang.compiler.backends.py.jacpython.compiler_match {
        ann_scope_plan
    }
    compiler_codegen --> jaclang.compiler.backends.py.jacpython.compiler_annotations.ann_store_target_tos {
        visit_store_target_tos
    }
    compiler_codegen --> jaclang.compiler.backends.py.jacpython.compiler_defs {
        emit_name_store,
        visit_stmt
    }
    compiler_codegen --> jaclang.compiler.backends.py.jacpython.compiler_emit.emit_comprehension_loop {
        visit_store_target_tos
    }
    compiler_codegen --> jaclang.compiler.backends.py.jacpython.compiler_exc {
        emit_module_return,
        emit_name_delete,
        emit_name_store,
        emit_unit_loop_exit_epilogue,
        visit_return_stmt,
        visit_stmt_tail,
        visit_stmts,
        visit_store_target_tos
    }
    compiler_codegen --> jaclang.compiler.backends.py.jacpython.compiler_loops {
        emit_module_return,
        emit_tail_and_finish,
        visit_stmt_tail,
        visit_stmts,
        visit_store_target_tos
    }
    compiler_codegen --> jaclang.compiler.backends.py.jacpython.compiler_match {
        emit_module_return,
        emit_name_store,
        visit_stmt_tail,
        visit_stmts
    }
    compiler_codegen --> jaclang.compiler.backends.py.jacpython.product_compile {
        compile_eval,
        compile_exec
    }
    compiler_context --> jaclang.compiler.backends.py.jacpython.compiler_ir {
        compile_context
    }
    compiler_context --> jaclang.compiler.backends.py.jacpython.product_compile {
        compile_context
    }
    compiler_context --> jaclang.compiler.frontend.python.compiler_symtable {
        compile_context
    }
    compiler_context --> jaclang.runtime.python.symtable { compile_context }
    compiler_defs as dispatch_defs --> jaclang.compiler.backends.py.jacpython.compiler_codegen.visit_stmt;
    compiler_emit --> jaclang.compiler.backends.py.jacpython.compiler_annotations {
        cellvars_from_sym,
        codegen_busy,
        codegen_fail,
        codegen_mangle,
        fast_local_index,
        fast_varnames_from_sym,
        freevars_from_sym,
        localsplus_index,
        localsplus_index_u,
        visit_expr,
        visit_subscript_index
    }
    compiler_emit --> jaclang.compiler.backends.py.jacpython.compiler_codegen {
        cellvars_from_sym,
        codegen_busy,
        codegen_fail,
        codegen_mangle,
        comp_append_handler,
        comp_emit_bind_target,
        comp_emit_cleanup,
        comp_emit_filters,
        comp_emit_setup,
        comp_emit_single_elt,
        comp_finish_loop,
        comp_lead_loopvar_slot,
        comp_name_fast_index,
        comp_target_slots,
        compile_lambda_cfg,
        emit_anext_send_loop_footer,
        emit_anext_send_loop_header,
        emit_await_send_except_regions,
        emit_await_send_loop_footer,
        emit_await_send_loop_header,
        emit_branch_if_test_false,
        emit_branch_if_test_true,
        emit_cmp_link,
        emit_control_unwind,
        emit_folded_int,
        emit_function_defaults,
        emit_function_kwdefaults,
        emit_function_prologue,
        emit_generator_except_handler,
        emit_make_function_with_closure,
        emit_name_load,
        emit_return_unwind,
        emit_send_delegation_loop,
        emit_slice_bound,
        emit_slice_load,
        emit_starred_list_build,
        emit_suspendable_prologue,
        fast_local_index,
        fast_varnames_from_sym,
        finish_control_unwind,
        flush_pending_await_footers,
        freevars_from_sym,
        is_none_identity_test,
        localsplus_index,
        localsplus_index_u,
        name_load_opcode,
        register_int_literal_const,
        try_emit_fast_local_pair_load,
        unit_fail,
        varname_index,
        visit_boolop,
        visit_comp_dict_kv,
        visit_comp_elt,
        visit_compare,
        visit_dict_comp,
        visit_expr,
        visit_lambda,
        visit_list_comp,
        visit_set_comp,
        visit_subscript_index,
        visit_test_expr
    }
    compiler_emit --> jaclang.compiler.backends.py.jacpython.compiler_defs {
        call_has_unpacking,
        cellvars_from_sym,
        codegen_busy,
        codegen_fail,
        codegen_mangle,
        emit_call_ex_positional,
        emit_call_instruction,
        emit_call_keyword_values,
        emit_folded_int,
        emit_function_defaults,
        emit_function_kwdefaults,
        emit_function_prologue,
        emit_generator_except_handler,
        emit_local_or_cell_store,
        emit_make_function_with_closure,
        emit_name_load,
        fast_local_index,
        fast_varnames_from_sym,
        flush_pending_await_footers,
        freevars_from_sym,
        inline_storage_names,
        localsplus_index,
        localsplus_index_u,
        visit_expr
    }
    compiler_emit --> jaclang.compiler.backends.py.jacpython.compiler_exc {
        anext_send_loop,
        await_send_loop,
        codegen_busy,
        codegen_fail,
        emit_await_send_except_regions,
        emit_await_send_loop_footer,
        emit_await_send_loop_header,
        emit_return_unwind,
        emit_send_delegation_loop,
        visit_expr
    }
    compiler_emit --> jaclang.compiler.backends.py.jacpython.compiler_loops {
        codegen_busy,
        codegen_fail,
        emit_anext_send_loop_footer,
        emit_anext_send_loop_header,
        emit_branch_if_test_false,
        emit_branch_if_test_true,
        emit_send_delegation_loop,
        visit_expr,
        visit_test_expr
    }
    compiler_emit --> jaclang.compiler.backends.py.jacpython.compiler_match {
        codegen_busy,
        codegen_fail,
        codegen_mangle,
        emit_branch_if_test_false,
        fast_local_index,
        visit_expr,
        visit_test_expr
    }
    compiler_exc as dispatch_exc --> jaclang.compiler.backends.py.jacpython.compiler_codegen.finish_source_scope;
    compiler_exc as dispatch_exc --> jaclang.compiler.backends.py.jacpython.compiler_codegen.visit_stmt;
    compiler_exc --> jaclang.compiler.backends.py.jacpython.compiler_defs {
        emit_deferred_comp_handlers
    }
    compiler_exc as dispatch_exc --> jaclang.compiler.backends.py.jacpython.compiler_emit.compile_genexp_cfg;
    compiler_exc as dispatch_exc --> jaclang.compiler.backends.py.jacpython.compiler_emit.compile_lambda_cfg;
    compiler_exc as dispatch_exc --> jaclang.compiler.backends.py.jacpython.compiler_emit.emit_control_unwind;
    compiler_exc --> jaclang.compiler.backends.py.jacpython.compiler_loops {
        emit_anext_send_except_regions
    }
    compiler_exc as dispatch_exc --> jaclang.compiler.backends.py.jacpython.compiler_loops.visit_async_for;
    compiler_exc as dispatch_exc --> jaclang.compiler.backends.py.jacpython.compiler_loops.visit_for;
    compiler_exc as dispatch_exc --> jaclang.compiler.backends.py.jacpython.compiler_loops.visit_if;
    compiler_exc as dispatch_exc --> jaclang.compiler.backends.py.jacpython.compiler_loops.visit_while;
    compiler_ir --> jaclang.compiler.backends.py.jacpython.assembler {
        NO_LINE,
        cinstr,
        cloc,
        except_region,
        instr_size_codeunits,
        loc,
        same_loc
    }
    compiler_ir --> jaclang.compiler.backends.py.jacpython.codegen_util {
        basicblock,
        cfg_builder,
        cinstr,
        cloc,
        comp_handler,
        except_region,
        loc,
        loop_frame,
        mk_instr,
        mk_jump,
        new_cfg_builder,
        no_loc,
        stmt_cont,
        unverified_cfg
    }
    compiler_ir --> jaclang.compiler.backends.py.jacpython.compiler_annotations {
        basicblock,
        cfg_builder,
        cinstr,
        cloc,
        loc,
        new_cfg_builder,
        stmt_cont,
        unverified_cfg
    }
    compiler_ir --> jaclang.compiler.backends.py.jacpython.compiler_codegen {
        basicblock,
        break_site,
        cfg_builder,
        cinstr,
        cloc,
        comp_handler,
        control_unwind,
        except_region,
        loc,
        loop_frame,
        mk_instr,
        mk_jump,
        new_cfg_builder,
        no_loc,
        stmt_cont,
        unverified_cfg
    }
    compiler_ir --> jaclang.compiler.backends.py.jacpython.compiler_defs {
        cfg_builder,
        cloc,
        loc,
        new_cfg_builder,
        no_loc,
        stmt_cont,
        unverified_cfg
    }
    compiler_ir --> jaclang.compiler.backends.py.jacpython.compiler_emit {
        await_footer_job,
        basicblock,
        cfg_builder,
        cinstr,
        cleanup_frame,
        cloc,
        comp_handler,
        control_unwind,
        except_region,
        loc,
        loop_frame,
        mk_instr,
        mk_jump,
        new_cfg_builder,
        no_loc,
        stmt_cont,
        try_await_frame,
        unverified_cfg,
        with_unwind_rec
    }
    compiler_ir --> jaclang.compiler.backends.py.jacpython.compiler_exc {
        await_footer_job,
        basicblock,
        cfg_builder,
        cleanup_frame,
        cloc,
        except_region,
        loc,
        no_loc,
        stmt_cont,
        try_await_frame,
        with_unwind_rec
    }
    compiler_ir --> jaclang.compiler.backends.py.jacpython.compiler_loops {
        basicblock,
        break_site,
        cfg_builder,
        cinstr,
        cloc,
        except_region,
        loc,
        loop_frame,
        mk_instr,
        mk_jump,
        no_loc,
        same_loc,
        stmt_cont
    }
    compiler_ir --> jaclang.compiler.backends.py.jacpython.compiler_match {
        basicblock,
        cfg_builder,
        cloc,
        loc,
        stmt_cont
    }
    compiler_ir --> jaclang.compiler.backends.py.jacpython.flowgraph {
        basicblock,
        cinstr,
        except_region,
        instr_size_codeunits,
        mk_instr,
        unverified_cfg
    }
    compiler_loops as dispatch_loops --> jaclang.compiler.backends.py.jacpython.compiler_codegen.visit_stmt;
    compiler_match as dispatch_match --> jaclang.compiler.backends.py.jacpython.compiler_codegen.visit_stmt;
    flowgraph --> jaclang.compiler.backends.py.jacpython.assembler {
        flatten_blocks,
        verified_cfg
    }
    flowgraph --> jaclang.compiler.backends.py.jacpython.compiler_annotations {
        verify_cfg
    }
    flowgraph --> jaclang.compiler.backends.py.jacpython.compiler_codegen {
        optimize_swap_range,
        verify_cfg
    }
    flowgraph --> jaclang.compiler.backends.py.jacpython.compiler_defs { verify_cfg }
    flowgraph --> jaclang.compiler.backends.py.jacpython.compiler_emit {
        build_layout_pos,
        layout_pos,
        optimize_swap_range,
        verify_cfg
    }
    flowgraph --> jaclang.compiler.backends.py.jacpython.compiler_exc {
        build_layout_pos,
        layout_pos
    }
    flowgraph --> jaclang.compiler.backends.py.jacpython.compiler_loops {
        MAX_COPY_SIZE,
        copy_cinstr
    }
    flowgraph --> jaclang.compiler.backends.py.jacpython.compiler_match {
        optimize_swap_range
    }
    flowgraph --> jaclang.compiler.backends.py.jacpython.product_compile { verify_cfg }
    product_compile --> jaclang.compiler.backends.py.jacpython.native_api {
        compile_ast,
        compile_source,
        prepare_ast_output
    }
}

impl import jaclang.compiler.driver {
    application --> jaclang.cli.commands.execution.serve { prepare_application }
    application --> jaclang.client.targets.client_dev_common.dev_proxy_paths {
        prepare_application
    }
    application --> jaclang.compiler.driver.build_services.CompilerBuildServices.prepare_application {
        prepare_application
    }
    application --> jaclang.dist.seal.build_serve_manifest { prepare_application }
    application --> jaclang.dist.source.project.export_project { prepare_application }
    application --> jaclang.scale.server.inprocess.prepare_inprocess_runtime {
        prepare_application
    }
    application --> jaclang.scale.tests.data.test_eager_spawn { prepare_application }
    application --> jaclang.scale.tests.microservices.test_microservice {
        prepare_application
    }
    application --> jaclang.scale.tests.server.test_host_serving { prepare_application }
    application --> jaclang.scale.tests.server.test_served_app_route {
        prepare_application
    }
    application --> jaclang.scale.tests.server.test_sv_outbox_endpoints {
        prepare_application
    }
    application --> jaclang.server.hmr.HotReloader._reload_server_module {
        reprepare_application
    }
    application_edges --> jaclang.compiler.driver.build_services.CompilerBuildServices.application_edges {
        application_edges
    }
    bccache --> jaclang.cli.commands.analysis._check_file_job { discover_base_file }
    bccache --> jaclang.cli.commands.analysis._drop_covered_annexes {
        discover_base_file
    }
    bccache --> jaclang.cli.commands.analysis._format_single_file_worker {
        discover_annex_files
    }
    bccache --> jaclang.cli.commands.analysis.lint.lint_fix_file {
        discover_annex_files
    }
    bccache --> jaclang.cli.commands.analysis.precommit { discover_annex_files }
    bccache --> jaclang.cli.commands.arch { discover_annex_files }
    bccache --> jaclang.compiler.backends.es.scoped_styles { discover_style_annex }
    bccache --> jaclang.compiler.driver.compiler.JacCompiler._compile_once {
        discover_base_file
    }
    bccache --> jaclang.compiler.driver.ifacecache.IfaceRegistry._entry_fresh {
        discover_annex_files,
        discover_wiring_file
    }
    bccache --> jaclang.compiler.driver.jir._related_files {
        discover_annex_files,
        discover_style_annex
    }
    bccache --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.analysis {
        discover_base_file as _cc_base_file
    }
    bccache --> jaclang.compiler.driver.progstate.ModuleHub.is_fresh {
        discover_annex_files,
        discover_wiring_file
    }
    bccache --> jaclang.compiler.driver.progstate.ModuleHub.stamp {
        discover_annex_files,
        discover_wiring_file
    }
    bccache --> jaclang.compiler.driver.wiring.compiled_by_seed { discover_base_file }
    bccache --> jaclang.compiler.frontend.parser.frontend.annex_sources {
        discover_annex_files,
        discover_base_file
    }
    bccache --> jaclang.compiler.frontend.unitree.Module.annexable_by.getter {
        discover_base_file
    }
    bccache --> jaclang.compiler.placement.placement_solver._native_dep_scan {
        discover_annex_files
    }
    bccache --> jaclang.compiler.tests.test_batch_decl_identity { discover_base_file }
    bccache --> jaclang.compiler.tests.test_global_narrowing { discover_base_file }
    bccache --> jaclang.compiler.tools.code_intel { discover_annex_files }
    bccache --> jaclang.compiler.tools.jac_auto_lint_pass { discover_base_file }
    bccache --> jaclang.compiler.tools.jac_auto_lint_pass.JacAutoLintPass._base_decl_archetypes {
        discover_base_file
    }
    bccache --> jaclang.lsp.server.engine { discover_annex_files, discover_base_file }
    bccache --> jaclang.server.hmr { discover_base_file }
    bccache --> jaclang.testing.test_runner._suite_source { discover_base_file }
    boundary_classify --> jaclang.cli.commands.execution._exec_file {
        module_demoted_native as _na_demoted
    }
    boundary_classify --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._is_client_native_import {
        import_binds_client_native
    }
    boundary_classify --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._is_service_bridge_import {
        CrossAppKind,
        classify_cross_app_import
    }
    boundary_classify --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._partition_client_import_items {
        import_crosses_apps
    }
    boundary_classify --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._record_sv_backend {
        import_crosses_apps,
        import_provider_app,
        import_provider_route
    }
    boundary_classify --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._sv_provider_options {
        import_crosses_apps,
        import_provider_app,
        import_provider_route
    }
    boundary_classify --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._generate_sv_to_sv_stubs {
        import_provider_app,
        import_provider_route
    }
    boundary_classify --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._sv_bridge_walker_call {
        CrossAppKind,
        classify_cross_app_import
    }
    boundary_classify --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._sv_consumer_app_expr {
        module_app
    }
    boundary_classify --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass.exit_import {
        CrossAppKind,
        classify_cross_app_import,
        import_binds_client_native
    }
    boundary_classify --> jaclang.compiler.driver.compiler {
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
    boundary_classify --> jaclang.compiler.frontend.unitree.Import.is_service_import.getter {
        is_service_bridge_import
    }
    boundary_classify --> jaclang.compiler.passes.access_check_pass.AccessCheckPass._collect_bridged_imports {
        classify_cross_app_import
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._bridge_targets {
        bridgeable_import_target,
        import_provider_app,
        module_app
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._check_app_cycle {
        bridgeable_import_target
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._check_provider_pub {
        ClientImportVerdict,
        classify_client_import_item,
        import_provider_app,
        module_app
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._parsed_provider_of {
        bridgeable_import_target
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._provider_module_of {
        bridgeable_import_target,
        symbol_linked_source_module
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._record_app_edge {
        import_provider_app,
        module_app
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._register_client_bridged_import {
        ClientImportVerdict,
        classify_client_import_item,
        import_crosses_apps,
        import_provider_app,
        import_provider_route,
        is_client_boundary_import
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._register_sv_import {
        import_crosses_apps,
        import_provider_app,
        import_provider_route
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._register_type_import {
        import_provider_app
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._reject_owned_type_import {
        import_provider_app,
        module_app
    }
    boundary_classify --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass.enter_import {
        CrossAppKind,
        classify_cross_app_import
    }
    boundary_classify --> jaclang.compiler.passes.static_analysis_pass.StaticAnalysisPass._check_client_imports {
        is_client_native_edge_import
    }
    boundary_classify --> jaclang.compiler.passes.wasm_contract.host_contracts {
        symbol_linked_source_module
    }
    boundary_classify --> jaclang.compiler.placement.placement._element_reqs {
        classify_import
    }
    boundary_classify --> jaclang.compiler.placement.placement.module_anchor_reasons {
        ability_delegates_to_model,
        classify_import,
        is_service_app_entry
    }
    boundary_classify --> jaclang.compiler.placement.placement.scan_native_blockers {
        ability_delegates_to_model
    }
    boundary_classify --> jaclang.compiler.placement.placement_facts.discover_spaces {
        hub_module_for_path
    }
    boundary_classify --> jaclang.compiler.placement.placement_solver._closure_pullable {
        is_server_anchored_module
    }
    boundary_classify --> jaclang.compiler.placement.placement_solver._is_sv_import {
        import_crosses_apps
    }
    boundary_classify --> jaclang.compiler.placement.placement_solver._materialize_module {
        hub_module_for_path
    }
    boundary_classify --> jaclang.compiler.placement.placement_solver._pull_boundary_import {
        plain_native_import_target
    }
    boundary_classify --> jaclang.compiler.placement.placement_solver._pullable_by_client_reference {
        is_server_anchored_module
    }
    boundary_classify --> jaclang.compiler.placement.placement_solver._seed_from_summary {
        _stamp_context_element
    }
    boundary_classify --> jaclang.compiler.placement.placement_solver.solve_module_placement {
        _stamp_context_element
    }
    boundary_classify --> jaclang.compiler.symbol_utils {
        ClientImportVerdict,
        classify_client_import_item,
        is_client_boundary_import,
        symbol_linked_source_module
    }
    boundary_classify --> jaclang.compiler.types.type_evaluator.TypeEvaluator._is_sv_async_call {
        CrossAppKind,
        classify_cross_app_import,
        is_client_native_edge_import
    }
    client_graph --> jaclang.compiler.driver.pipeline { collect_client_graph }
    compilation_context --> jaclang.compiler.backends.native.link_plan.units_source_key {
        cache_scope
    }
    compilation_context --> jaclang.compiler.driver.application._prepare {
        cache_scope,
        program_for
    }
    compilation_context --> jaclang.compiler.driver.application._sections {
        cache_scope,
        program_for
    }
    compilation_context --> jaclang.compiler.driver.application._semantic_metadata {
        program_for
    }
    compilation_context --> jaclang.compiler.driver.application.prepare_application {
        bind_options,
        context_program
    }
    compilation_context --> jaclang.compiler.driver.application.prepare_dynamic_module {
        program_for
    }
    compilation_context --> jaclang.compiler.driver.compiler.JacCompiler.compile {
        bind_options,
        compilation_scope,
        context_program
    }
    compilation_context --> jaclang.compiler.driver.compiler.JacCompiler.get_bytecode {
        bind_options,
        compilation_scope,
        context_program
    }
    compilation_context --> jaclang.compiler.driver.compiler.JacCompiler.get_client_artifact {
        bind_options,
        compilation_scope,
        context_program
    }
    compilation_context --> jaclang.compiler.driver.compiler.JacCompiler.get_native_interop_setup {
        program_for
    }
    compilation_context --> jaclang.compiler.driver.compiler.JacCompiler.get_native_layout {
        program_for
    }
    compilation_context --> jaclang.compiler.driver.ifacecache.IfaceRegistry._compilation_scope {
        compilation_scope
    }
    compilation_context --> jaclang.compiler.driver.ifacecache.IfaceRegistry.ensure {
        program_for
    }
    compilation_context --> jaclang.compiler.driver.ifacecache.seed_dep_edges {
        artifact_cache_path
    }
    compilation_context --> jaclang.compiler.driver.jir._owner_projection {
        active_options
    }
    compilation_context --> jaclang.compiler.driver.jir.compute_precompile_module_key {
        cache_scope
    }
    compilation_context --> jaclang.compiler.driver.nativecache.NativeUnitRegistry._source_key {
        cache_scope
    }
    compilation_context --> jaclang.compiler.driver.pipeline.compile_application {
        bind_options,
        context_program
    }
    compilation_context --> jaclang.compiler.driver.pipeline.invalidate_client_product {
        cache_scope
    }
    type compilation_context --> jaclang.compiler.driver.program { SourceStore }
    compilation_context --> jaclang.compiler.driver.program.JacProgram.init {
        SourceStore
    }
    compilation_context --> jaclang.compiler.driver.program.JacProgram.load_dependency_module {
        program_for
    }
    compilation_context --> jaclang.compiler.driver.source_products.python_source {
        program_for
    }
    compilation_context --> jaclang.compiler.passes.access_check_pass.AccessCheckPass._module_app_facts {
        context_app
    }
    compilation_context --> jaclang.compiler.placement.placement_pins { context_app }
    compilation_context --> jaclang.compiler.tools.jac_auto_lint_pass.JacAutoLintPass.__post_init__ {
        context_app
    }
    compilation_context --> jaclang.dist.precompile_bytecode._application_sources {
        bind_options
    }
    compilation_context --> jaclang.dist.precompile_bytecode.precompile_context {
        bind_options,
        context_program
    }
    compilation_context --> jaclang.dist.precompile_bytecode.precompile_unit_context {
        cache_scope
    }
    compile_options --> jaclang.cli.commands.analysis._check_file_job { CompileOptions }
    compile_options --> jaclang.cli.commands.analysis.explain { CompileOptions }
    compile_options --> jaclang.cli.commands.analysis.grammar { CompileOptions }
    compile_options --> jaclang.cli.commands.execution._exec_file {
        CompileOptions,
        CompileOptions as _RunOpts
    }
    compile_options --> jaclang.cli.commands.native_build._restore_target {
        pop_native_target
    }
    compile_options --> jaclang.cli.commands.native_build.native_build {
        CompileOptions,
        NATIVE_LINK_MODES,
        pop_native_target,
        push_native_target
    }
    compile_options --> jaclang.compiler.backends.es.client_kernel_cache._lower {
        CompileOptions
    }
    compile_options --> jaclang.compiler.backends.native.elf_linker.ElfLinker.link {
        env_symmap_requested
    }
    compile_options --> jaclang.compiler.backends.native.floor.floor_lib_dir {
        env_floor_dir
    }
    compile_options --> jaclang.compiler.backends.native.kernel_resolve {
        CompileOptions,
        NATIVE_LINK_MODE_BITCODE
    }
    compile_options --> jaclang.compiler.backends.native.link_plan {
        CompileOptions,
        NATIVE_LINK_MODE_BITCODE,
        NATIVE_LINK_MODE_OBJECTS,
        env_na_debug
    }
    compile_options --> jaclang.compiler.backends.native.link_plan.build_link_plan {
        pop_native_target,
        push_native_target
    }
    compile_options --> jaclang.compiler.backends.native.llvm {
        env_typed_pointers_enabled
    }
    compile_options --> jaclang.compiler.backends.native.llvm._find_shim {
        env_llvm_shim_override
    }
    type compile_options --> jaclang.compiler.backends.native.na_compile_pass {
        CompileOptions
    }
    compile_options --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._full_ast_of {
        env_na_debug
    }
    compile_options --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._load_native_unit_module {
        CompileOptions as _UnitOpts
    }
    compile_options --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._opaque_field_if_unlowerable {
        env_na_debug as _er_dbg
    }
    compile_options --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_imported_struct_types {
        env_na_debug,
        env_na_debug as _ti_dbg
    }
    compile_options --> jaclang.compiler.backends.native.wasm_build._wasm_libc_dir {
        env_wasm_libc_dir
    }
    compile_options --> jaclang.compiler.driver.application.prepare_application {
        CompileOptions
    }
    compile_options --> jaclang.compiler.driver.application_edges.application_edges {
        CompileOptions
    }
    compile_options --> jaclang.compiler.driver.compilation_context { CompileOptions }
    compile_options --> jaclang.compiler.driver.compiler { CompileOptions }
    compile_options --> jaclang.compiler.driver.ifacecache.IfaceRegistry._ensure_in_context {
        CompileOptions
    }
    compile_options --> jaclang.compiler.driver.ifacecache.IfaceRegistry._verify_analysis {
        CompileOptions
    }
    compile_options --> jaclang.compiler.driver.ifacecache.IfaceRegistry._verify_iface {
        CompileOptions
    }
    compile_options --> jaclang.compiler.driver.jir._analysis_fingerprint_for {
        CompileOptions
    }
    compile_options --> jaclang.compiler.driver.nativecache { CompileOptions }
    compile_options --> jaclang.compiler.driver.nativecache.NativeBuildSession.finish {
        pop_native_target,
        push_native_target
    }
    compile_options --> jaclang.compiler.driver.nativecache.NativeBuildSession.lower {
        env_na_debug,
        pop_native_target,
        push_native_target
    }
    compile_options --> jaclang.compiler.driver.nativecache.NativeUnitRegistry._source_key {
        pop_native_target,
        push_native_target
    }
    compile_options --> jaclang.compiler.driver.nativecache.NativeUnitRegistry.known_digest {
        env_na_debug
    }
    type compile_options --> jaclang.compiler.driver.pipeline { CompileOptions }
    compile_options --> jaclang.compiler.driver.pipeline_runner { CompileOptions }
    compile_options --> jaclang.compiler.driver.pipeline_runner.native_application {
        CompileOptions,
        pop_native_target,
        push_native_target
    }
    compile_options --> jaclang.compiler.driver.pipeline_runner.wasm_ir {
        CompileOptions,
        pop_native_target,
        push_native_target
    }
    compile_options --> jaclang.compiler.driver.program { CompileOptions }
    compile_options --> jaclang.compiler.tests.test_batch_decl_identity {
        CompileOptions
    }
    compile_options --> jaclang.compiler.tests.test_client_codegen_facts {
        CompileOptions
    }
    compile_options --> jaclang.compiler.tests.test_global_narrowing { CompileOptions }
    compile_options --> jaclang.compiler.tests.test_graph_fragment_equivalence {
        CompileOptions
    }
    compile_options --> jaclang.compiler.tests.test_missing_local_import {
        CompileOptions
    }
    compile_options --> jaclang.compiler.tests.test_native_kernel_cache {
        CompileOptions
    }
    compile_options --> jaclang.compiler.tests.test_stubcat_roundtrip { CompileOptions }
    compile_options --> jaclang.compiler.tests.test_subscript_assignment {
        CompileOptions
    }
    compile_options --> jaclang.compiler.tests.test_tarfile_equivalence {
        CompileOptions
    }
    compile_options --> jaclang.compiler.tests.test_unknown_cascade { CompileOptions }
    compile_options --> jaclang.compiler.tests.test_zstd_equivalence { CompileOptions }
    compile_options --> jaclang.compiler.tests.xbackend_equiv { CompileOptions }
    compile_options --> jaclang.compiler.tools.code_intel.CodeIntelligence._full_compile_one {
        CompileOptions
    }
    compile_options --> jaclang.compiler.tools.lang_tools { CompileOptions }
    compile_options --> jaclang.dist.precompile_bytecode._application_sources {
        CompileOptions
    }
    compile_options --> jaclang.dist.precompile_bytecode.precompile_context {
        CompileOptions
    }
    compile_options --> jaclang.dist.precompile_bytecode.precompile_native_unit {
        CompileOptions
    }
    compile_options --> jaclang.dist.precompile_bytecode.seal_native {
        CompileOptions,
        NATIVE_LINK_MODE_BITCODE
    }
    compile_options --> jaclang.dist.publish.builder._module_is_client_source {
        CompileOptions
    }
    compile_options --> jaclang.dist.publish.npm_sources._compile_module {
        CompileOptions
    }
    compile_options --> jaclang.lsp.server.engine.JacLangServer.type_check_file {
        CompileOptions
    }
    compile_options --> jaclang.testing.cl_test_runner.module_is_client {
        CompileOptions
    }
    compiler --> jaclang.cli.commands.analysis.check { COMPILE_GC_THRESHOLDS }
    compiler --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.lint_snippet._do_lint {
        JacCompiler
    }
    type compiler --> jaclang.compiler.driver.build_services { JacCompiler }
    compiler --> jaclang.compiler.driver.build_services.CompilerBuildServices.compiler {
        JacCompiler
    }
    type compiler --> jaclang.compiler.driver.pipeline { JacCompiler }
    type compiler --> jaclang.compiler.driver.pipeline_runner { JacCompiler }
    type compiler --> jaclang.compiler.driver.program { JacCompiler }
    compiler --> jaclang.compiler.driver.program.JacProgram._get_compiler {
        JacCompiler
    }
    compiler --> jaclang.compiler.driver.program.JacProgram.jac_file_formatter {
        JacCompiler
    }
    compiler --> jaclang.compiler.driver.program.JacProgram.jac_file_linter {
        JacCompiler
    }
    compiler --> jaclang.compiler.driver.program.JacProgram.jac_str_formatter {
        JacCompiler
    }
    compiler --> jaclang.compiler.types.stubcat.build.build_catalog { JacCompiler }
    compiler --> jaclang.dist.precompile_bytecode.run_precompile {
        COMPILE_GC_THRESHOLDS
    }
    type compiler --> jaclang.runtime.build_services { JacCompiler }
    type compiler --> jaclang.runtime.runtime { JacCompiler }
    context_passes --> jaclang.compiler.driver.pipeline {
        AbsorbImportsPass,
        AppContextPass,
        BoundaryFactsPass,
        NativeImportFactsPass
    }
    dependency_graph --> jaclang.compiler.backends.native.link_plan._build_link_plan {
        dependency_groups
    }
    ifacecache --> jaclang.compiler.driver.program.JacProgram.iface_registry {
        IfaceRegistry
    }
    ifacecache --> jaclang.dist.precompile_bytecode._unit_extra {
        DIAG_SCHEMA,
        IfaceRegistry
    }
    ifacecache --> jaclang.lsp.server.engine.JacLangServer._fanout_dependents {
        seed_dep_edges
    }
    jir --> jaclang.byllm.tests.test_mtir_integration {
        HEADER_SIZE,
        SECTIONS_MAGIC,
        SEC_BYTECODE,
        SEC_MTIR,
        get_module_cache_path,
        read_sections,
        write_sections
    }
    jir --> jaclang.cli.commands.cache._live_keys { compiler_generation }
    jir --> jaclang.cli.commands.execution._exec_file { scrub_cache_dirs }
    jir --> jaclang.compiler.backends.es.client_kernel_cache._artifact_path {
        running_compiler_digest
    }
    jir --> jaclang.compiler.backends.native.kernel_resolve._sidecar_matches_sources {
        sidecar_unit_paths
    }
    jir --> jaclang.compiler.backends.native.kernel_resolve._unit_sources_match {
        running_compiler_digest,
        unit_source_digest
    }
    jir --> jaclang.compiler.backends.native.link_plan {
        sidecar_unit_paths,
        unit_source_digest
    }
    jir --> jaclang.compiler.backends.native.link_plan.LinkPlan.plan_digest {
        running_compiler_digest
    }
    jir --> jaclang.compiler.backends.native.link_plan._build_link_plan.walk_unit {
        module_cache_key
    }
    jir --> jaclang.compiler.backends.native.link_plan._reuse_artifact { cache_mode }
    jir --> jaclang.compiler.backends.native.link_plan._write_sidecar {
        running_compiler_digest
    }
    jir --> jaclang.compiler.backends.native.link_plan.units_source_key {
        module_cache_key,
        running_compiler_digest
    }
    jir --> jaclang.compiler.backends.native.na_compile_pass.NativeCompilePass._emit_debug_products {
        get_native_debug_dir
    }
    jir --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass.finish {
        get_native_debug_dir
    }
    jir --> jaclang.compiler.driver.application._context_sections {
        HEADER_SIZE,
        SECTIONS_MAGIC,
        get_module_cache_path,
        read_sections
    }
    jir --> jaclang.compiler.driver.application._identity { compiler_generation }
    jir --> jaclang.compiler.driver.application._prepare { cache_mode }
    jir --> jaclang.compiler.driver.application._prepare_sealed {
        HEADER_SIZE,
        PRECOMPILE_SENTINEL,
        SECTIONS_MAGIC,
        patch_co_filenames_bytes,
        read_bytecode_only,
        read_sections
    }
    jir --> jaclang.compiler.driver.compilation_context.artifact_cache_path {
        get_module_cache_path
    }
    jir --> jaclang.compiler.driver.compiler {
        FLAG_PRECOMPILED,
        HEADER_SIZE,
        SECTIONS_MAGIC,
        SEC_BYTECODE,
        SEC_CLIENT,
        SEC_IFACE,
        SEC_INTEROP,
        SEC_MTIR,
        SEC_NBITCODE,
        SEC_NIFACE,
        SEC_NOBJ,
        SEC_PLACEMENT,
        cache_mode,
        compute_content_sha256,
        get_module_cache_path,
        is_module_cache_valid,
        patch_co_filenames_bytes,
        precompiled_jir_matches_source,
        read_bytecode_only,
        read_section_bytes,
        read_sections,
        write_module_cache
    }
    jir --> jaclang.compiler.driver.compiler.JacCompiler._get_bytecode {
        PRECOMPILE_SENTINEL,
        SEC_CTDEPS as _PC_CTDEPS
    }
    jir --> jaclang.compiler.driver.compiler.JacCompiler._get_precompiled_jir_bytecode {
        PRECOMPILE_SENTINEL,
        SEC_CTDEPS,
        absolutize_ct_deps_section,
        bundle_dir_allowed,
        cache_mode,
        precompile_required
    }
    jir --> jaclang.compiler.driver.compiler.JacCompiler._persist_module_cache {
        SEC_CTDEPS,
        ct_deps_section,
        get_module_cache_path,
        is_module_cache_valid,
        write_module_cache
    }
    jir --> jaclang.compiler.driver.compiler.JacCompiler._precompiled_jir_data {
        bundle_dir_allowed,
        cache_mode,
        precompiled_jir_matches_source
    }
    jir --> jaclang.compiler.driver.compiler.JacCompiler._restore_sections {
        JirPaths,
        SEC_PATH_ROOT
    }
    jir --> jaclang.compiler.driver.compiler.JacCompiler._wants_native_engine {
        is_compiler_source_path
    }
    jir --> jaclang.compiler.driver.ifacecache {
        DepRow,
        JirPaths,
        SEC_CTDEPS,
        SEC_DEPS,
        SEC_DIAG,
        SEC_IFACE,
        SEC_PATH_ROOT,
        SEC_PLACEMENT,
        cache_mode,
        ct_deps_section,
        deps_section,
        get_module_cache_path,
        is_compiler_tree_path,
        is_module_cache_valid,
        is_stub_like_path,
        jir_cacheable_source_path,
        module_cache_key,
        read_dep_hashes,
        read_jir_paths,
        read_section_bytes,
        write_module_cache
    }
    jir --> jaclang.compiler.driver.ifacecache.IfaceRegistry._deps_match {
        compute_stub_module_key,
        read_dep_rows
    }
    jir --> jaclang.compiler.driver.ifacecache.IfaceRegistry._persist_in_context {
        SEC_INTEROP
    }
    jir --> jaclang.compiler.driver.ifacecache.IfaceRegistry.client_boundary_facts {
        SEC_INTEROP,
        read_dep_rows
    }
    jir --> jaclang.compiler.driver.ifacecache.IfaceRegistry.note_dep {
        compute_stub_module_key
    }
    jir --> jaclang.compiler.driver.nativecache {
        NativeStamp,
        SEC_NBITCODE,
        SEC_NCTDEPS,
        SEC_NIFACE,
        SEC_NOBJ,
        SEC_PLACEMENT,
        cache_mode,
        ct_dep_text_fresh,
        ct_deps_section,
        current_native_stamp,
        get_module_cache_path,
        is_module_cache_valid,
        jir_cacheable_source_path,
        module_cache_key,
        native_section_payload,
        read_native_dep_hashes,
        read_section_bytes
    }
    jir --> jaclang.compiler.driver.nativecache.NativeUnitRegistry.known_native_deps {
        read_dep_rows
    }
    jir --> jaclang.compiler.driver.nativecache.NativeUnitRegistry.object_for {
        write_module_cache
    }
    jir --> jaclang.compiler.driver.nativecache.NativeUnitRegistry.product_sections {
        SEC_NDEPS,
        absolutize_ct_deps_section,
        native_deps_section
    }
    jir --> jaclang.compiler.driver.pipeline.invalidate_client_product {
        drop_python_lane_products
    }
    jir --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.interface {
        is_compiler_tree_path
    }
    jir --> jaclang.compiler.tools.code_intel {
        HEADER_SIZE,
        SECTIONS_MAGIC,
        SEC_SYMINDEX,
        create_header,
        get_module_cache_path,
        parse_header,
        read_sections,
        write_sections
    }
    jir --> jaclang.dist.payload.assemble.assemble_site { write_compiler_identity }
    jir --> jaclang.dist.precompile_bytecode {
        DepRow,
        FLAG_BOOTSTRAP,
        FLAG_PRECOMPILED,
        FORMAT_VERSION,
        HEADER_SIZE,
        NATIVE_SECTIONS,
        PRECOMPILE_SENTINEL,
        SECTIONS_MAGIC,
        SEC_BYTECODE,
        SEC_CTDEPS,
        SEC_DEBUG_SRC,
        SEC_DEPS,
        SEC_DIAG,
        SEC_IFACE,
        SEC_MODKEY,
        SEC_NIFACE,
        SEC_NOBJ,
        SEC_PATH_ROOT,
        SEC_PLACEMENT,
        compute_precompile_module_key,
        deps_section,
        get_module_cache_path,
        is_module_cache_valid,
        parse_header,
        patch_co_filenames_bytes,
        precompiled_jir_matches_source,
        read_dep_rows,
        read_jir_paths,
        read_section_bytes,
        read_sections,
        rebase_ct_deps_section,
        running_compiler_digest,
        write_precompiled_jir
    }
    jir --> jaclang.dist.precompile_bytecode._native_extra {
        NativeStamp,
        SEC_NCTDEPS,
        native_section_variants,
        pack_native_variants,
        rebase_placement_section
    }
    jir --> jaclang.dist.precompile_bytecode._precompile_unit { cache_mode }
    jir --> jaclang.dist.precompile_bytecode.run_precompile { read_debug_source }
    jir --> jaclang.dist.precompile_bytecode.seal_native {
        native_section_payload,
        read_section_bytes as _rsb
    }
    jir as jir --> jaclang.scale.tests.microservices.test_seed_determinism;
    jir --> jaclang.scale.tests.microservices.test_seed_determinism {
        FLAG_PRECOMPILED,
        compiler_source_digest,
        compiler_source_files,
        compute_module_key,
        compute_precompile_module_key,
        module_cache_key,
        precompiled_jir_matches_source,
        running_compiler_digest,
        write_precompiled_jir
    }
    na_coverage --> jaclang.cli.commands.analysis._check_file_job {
        _na_coverage,
        na_coverage_begin
    }
    na_coverage --> jaclang.cli.commands.analysis.check { na_coverage_end }
    na_coverage --> jaclang.compiler.backends.native.link_plan._build_link_plan {
        na_coverage_replay
    }
    na_coverage --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._demote_method_if_unlowerable {
        na_coverage_seam
    }
    na_coverage --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._export_native_iface {
        na_coverage_capture
    }
    na_coverage --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._opaque_field_if_unlowerable {
        na_coverage_seam
    }
    na_coverage --> jaclang.compiler.driver.compiler {
        _drop_demoted_native_bindings,
        na_coverage_record,
        na_demotion_note
    }
    na_coverage --> jaclang.compiler.driver.pipeline_runner.wasm_ir {
        na_coverage_begin,
        na_coverage_end
    }
    na_coverage --> jaclang.compiler.placement.placement_solver._native_deps_ok {
        _note_native_closure_cap
    }
    native_iface --> jaclang.compiler.backends.native.link_plan {
        NativeIface,
        layout_digest as layout_digest_of,
        merge_class_layouts
    }
    native_iface --> jaclang.compiler.backends.native.na_ir_gen_pass {
        NativeExport,
        NativeIface
    }
    native_iface --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._export_native_iface {
        NativeClassLayout,
        NativeFieldSlot,
        NativeIface
    }
    native_iface --> jaclang.compiler.driver.nativecache { NativeIface }
    type native_iface --> jaclang.compiler.frontend.codeinfo { NativeIface }
    native_iface --> jaclang.compiler.tests.test_native_kernel_cache { NativeIface }
    native_iface --> jaclang.dist.precompile_bytecode.seal_native { NativeIface }
    nativecache --> jaclang.compiler.backends.native.link_plan.build_link_plan {
        NativeBuildSession
    }
    type nativecache --> jaclang.compiler.driver.program { NativeUnitRegistry }
    nativecache --> jaclang.compiler.driver.program.JacProgram.native_units {
        NativeUnitRegistry
    }
    nativecache --> jaclang.compiler.placement.placement_pins._native_verdict {
        read_native_verdict
    }
    nativecache --> jaclang.compiler.tests.test_native_kernel_cache { NativeUnitEntry }
    pass_driver --> jaclang.compiler.backends.native.kernel_resolve._derive_in_tree {
        setup_progress
    }
    pass_driver --> jaclang.compiler.driver.application.prepare_application {
        compile_progress
    }
    pass_driver --> jaclang.compiler.driver.compiler {
        build_diagnostic_policy,
        compile_progress,
        deliver_alerts,
        run_pass,
        setup_progress
    }
    pass_driver --> jaclang.compiler.driver.ifacecache.IfaceRegistry.analysis_profile {
        config_for_app,
        diagnostic_policy_for
    }
    pass_driver --> jaclang.compiler.driver.pipeline.execute_passes {
        build_diagnostic_policy,
        run_pass
    }
    pass_driver --> jaclang.compiler.driver.pipeline.run_utility { run_pass }
    pass_driver --> jaclang.compiler.tests.test_client_codegen_facts { run_pass }
    pass_driver as pass_driver --> jaclang.compiler.tests.test_pipeline_products;
    pass_driver --> jaclang.compiler.tools.jac_auto_lint_pass.JacAutoLintPass.__post_init__ {
        diagnostic_policy_for
    }
    pipeline --> jaclang.cli.commands.analysis._check_file_job { compile_application }
    pipeline --> jaclang.cli.commands.analysis.grammar { UtilityProduct, run_utility }
    pipeline --> jaclang.cli.commands.transform.py2jac { UtilityProduct, run_utility }
    pipeline --> jaclang.client.compiler.ViteCompiler._compile_wasm_module {
        build_wasm
    }
    pipeline --> jaclang.client.jac_client_compiler.JacClientCompiler.emit_dependencies {
        collect_client_graph
    }
    pipeline --> jaclang.client.route_scanner.resolve_route_exports { route_exports }
    pipeline --> jaclang.compiler.backends.es.client_kernel_cache._lower {
        CompilationProduct,
        require_product
    }
    pipeline --> jaclang.compiler.backends.native.kernel_resolve._toolchain_available {
        native_pipeline_available
    }
    pipeline --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._ensure_dep_inference {
        CompilationProduct,
        require_product
    }
    pipeline --> jaclang.compiler.backends.native.wasm_build.compile_to_wasm {
        build_wasm
    }
    pipeline --> jaclang.compiler.driver.application._manifest {
        CompilationProduct,
        require_product
    }
    pipeline --> jaclang.compiler.driver.application._prepare { compile_application }
    pipeline --> jaclang.compiler.driver.application.prepare_route_metadata {
        route_exports
    }
    pipeline --> jaclang.compiler.driver.application_edges.application_edges {
        CompilationProduct,
        require_product
    }
    pipeline --> jaclang.compiler.driver.compiler {
        UtilityProduct,
        get_analysis_sched,
        get_boundary_analysis_sched,
        get_format_sched,
        get_ir_gen_sched,
        get_lint_sched,
        get_py_code_gen,
        get_symtab_ir_sched,
        native_pipeline_available,
        native_schedule_failure,
        pass_provides,
        providers_of,
        run_utility,
        validate_schedule
    }
    pipeline --> jaclang.compiler.driver.compiler.JacCompiler._compile_pipeline {
        compile_module
    }
    pipeline --> jaclang.compiler.driver.compiler.JacCompiler.ensure_client_codegen {
        CompilationProduct,
        require_product
    }
    pipeline --> jaclang.compiler.driver.compiler.JacCompiler.jac_file_formatter {
        execute_passes
    }
    pipeline --> jaclang.compiler.driver.compiler.JacCompiler.jac_file_linter {
        execute_passes
    }
    pipeline --> jaclang.compiler.driver.compiler.JacCompiler.jac_str_formatter {
        execute_passes
    }
    pipeline --> jaclang.compiler.driver.compiler.JacCompiler.run_schedule {
        execute_passes
    }
    pipeline --> jaclang.compiler.driver.ifacecache.IfaceRegistry._ensure_flow_graph {
        CompilationProduct,
        require_product
    }
    pipeline --> jaclang.compiler.driver.ifacecache.IfaceRegistry._ensure_in_context {
        CompilationProduct,
        require_product
    }
    pipeline --> jaclang.compiler.driver.ifacecache._symtab_provides {
        get_symtab_ir_sched,
        providers_of
    }
    pipeline --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.analysis {
        CompilationProduct,
        product_ready,
        require_product
    }
    pipeline --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.boundaries {
        get_boundary_analysis_sched
    }
    pipeline --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.codegen {
        CompilationProduct,
        get_bootstrap_code_gen,
        get_py_code_gen,
        product_ready,
        require_product
    }
    pipeline --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.interface {
        CompilationProduct,
        require_product
    }
    pipeline --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.ir {
        get_ir_gen_sched,
        get_symtab_ir_sched,
        providers_of
    }
    pipeline --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.native_checks {
        CompilationProduct,
        product_ready,
        require_product
    }
    pipeline --> jaclang.compiler.driver.program.JacProgram.load_dependency_module {
        UtilityProduct,
        run_utility
    }
    pipeline --> jaclang.compiler.driver.source_failures.bootstrap_tier_failure_details {
        schedule_tier_reason
    }
    pipeline --> jaclang.compiler.passes.cfg_build_pass.cfg_dot_from_file {
        UtilityProduct,
        run_utility
    }
    pipeline --> jaclang.compiler.passes.layout_pass.get_layout_registry {
        CompilationProduct,
        require_product
    }
    pipeline --> jaclang.compiler.placement.placement_solver.demote_client_pulled_elements {
        invalidate_client_product
    }
    pipeline --> jaclang.compiler.placement.placement_solver.invalidate_importers_es {
        invalidate_client_product
    }
    pipeline --> jaclang.compiler.placement.placement_solver.native_default_verdict {
        native_pipeline_available
    }
    pipeline --> jaclang.compiler.placement.placement_solver.solve_module_placement._invalidate_stale_codegen {
        invalidate_client_product
    }
    pipeline --> jaclang.compiler.tests.test_pipeline_products {
        CompilationProduct,
        _analysis_sched_loading,
        product_ready,
        require_product,
        validate_product_specs
    }
    pipeline --> jaclang.compiler.tools.jac_formatter_pass.format_module {
        UtilityProduct,
        run_utility
    }
    pipeline --> jaclang.compiler.tools.lang_tools {
        CompilationProduct,
        require_product
    }
    pipeline --> jaclang.compiler.tools.lang_tools.AstTool.ir {
        UtilityProduct,
        run_utility
    }
    pipeline --> jaclang.compiler.tools.unparse_pass.unparse_module {
        UtilityProduct,
        run_utility
    }
    pipeline --> jaclang.dist.precompile_bytecode._application_sources {
        compile_application
    }
    pipeline --> jaclang.dist.precompile_bytecode.seal_native {
        native_pipeline_available
    }
    pipeline --> jaclang.dist.publish.npm_sources._compile_module {
        CompilationProduct,
        require_product
    }
    type pipeline_runner --> jaclang.compiler.driver.pipeline { ModuleCompilation }
    pipeline_runner --> jaclang.compiler.driver.pipeline.build_wasm { wasm_artifact }
    pipeline_runner --> jaclang.compiler.driver.pipeline.compile_module {
        ModuleCompilation
    }
    pipeline_runner --> jaclang.compiler.driver.pipeline.module_pipeline {
        ModuleCompilation
    }
    pipeline_runner --> jaclang.dist.source.client.write_client { wasm_ir }
    pipeline_runner --> jaclang.dist.source.project.export_project {
        native_application
    }
    pipeline_types --> jaclang.compiler.backends.native.na_ir_gen_pass { AnalysisFact }
    pipeline_types --> jaclang.compiler.driver.compiler { AnalysisFact }
    pipeline_types --> jaclang.compiler.driver.ifacecache { AnalysisFact }
    pipeline_types --> jaclang.compiler.driver.nativecache.NativeBuildSession.lower {
        CompilationProduct
    }
    pipeline_types --> jaclang.compiler.driver.pipeline {
        AnalysisFact,
        CompilationProduct,
        PassContract,
        ProductTask,
        TaskState,
        UtilityProduct
    }
    pipeline_types --> jaclang.compiler.driver.pipeline_runner { AnalysisFact }
    pipeline_types --> jaclang.compiler.driver.program { AnalysisFact }
    pipeline_types --> jaclang.compiler.driver.progstate {
        AnalysisFact,
        CompilationProduct,
        ProductTask
    }
    pipeline_types --> jaclang.compiler.tests.test_pipeline_products {
        AnalysisFact,
        ProductTask,
        TaskState
    }
    program --> jaclang.byllm.tests.test_byllm { JacProgram }
    program --> jaclang.byllm.tests.test_mtir_integration { JacProgram }
    program --> jaclang.cli.commands.analysis._check_file_job { JacProgram }
    program --> jaclang.cli.commands.analysis._format_single_file_worker { JacProgram }
    program --> jaclang.cli.commands.analysis.explain { JacProgram }
    program --> jaclang.cli.commands.analysis.grammar { JacProgram }
    program --> jaclang.cli.commands.analysis.lint { JacProgram }
    program --> jaclang.cli.commands.arch { JacProgram }
    program --> jaclang.cli.commands.execution.debug { JacProgram }
    program --> jaclang.cli.commands.fix._format_source { JacProgram }
    program --> jaclang.cli.commands.fix._verify_claims { JacProgram }
    program --> jaclang.cli.commands.native_build.native_build { JacProgram }
    program --> jaclang.cli.commands.transform.jac2js { JacProgram }
    program --> jaclang.cli.commands.transform.jac2py { JacProgram }
    program --> jaclang.cli.commands.transform.py2jac { JacProgram }
    program --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.get_ast_snippet._do_ast {
        JacProgram
    }
    program --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.jac_to_js._do_jac2js {
        JacProgram
    }
    program --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.jac_to_py._do_jac2py {
        JacProgram
    }
    program --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.parse_snippet._do_parse {
        JacProgram
    }
    program --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.py_to_jac._do_py2jac {
        JacProgram
    }
    program --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.typecheck_snippet._do_typecheck {
        JacProgram
    }
    type program --> jaclang.client.client_bundle { JacProgram }
    type program --> jaclang.client.compiler { JacProgram }
    type program --> jaclang.client.vite_client_bundle { JacProgram }
    program --> jaclang.compiler.backends.es.client_kernel_cache._lower { JacProgram }
    type program --> jaclang.compiler.backends.es.esast_gen_pass { JacProgram }
    program --> jaclang.compiler.backends.native.kernel_resolve.kernel_plan {
        JacProgram
    }
    type program --> jaclang.compiler.backends.native.link_plan { JacProgram }
    type program --> jaclang.compiler.backends.native.na_compile_pass { JacProgram }
    type program --> jaclang.compiler.backends.native.na_ir_gen_pass { JacProgram }
    program --> jaclang.compiler.backends.native.wasm_build.compile_to_wasm {
        JacProgram
    }
    program --> jaclang.compiler.driver.application_edges.application_edges {
        JacProgram
    }
    program --> jaclang.compiler.driver.boundary_classify { JacProgram }
    type program --> jaclang.compiler.driver.build_services { JacProgram }
    program --> jaclang.compiler.driver.build_services.CompilerBuildServices.program {
        JacProgram
    }
    type program --> jaclang.compiler.driver.compilation_context { JacProgram }
    program --> jaclang.compiler.driver.compilation_context.SourceStore.parse {
        JacProgram
    }
    program --> jaclang.compiler.driver.compilation_context.context_program {
        JacProgram
    }
    program --> jaclang.compiler.driver.compiler { JacProgram }
    program --> jaclang.compiler.driver.compiler.JacCompiler._prepare_tool_program {
        JacProgram
    }
    program --> jaclang.compiler.driver.context_passes { JacProgram }
    program --> jaclang.compiler.driver.ifacecache.IfaceRegistry._fresh_verify_program {
        JacProgram
    }
    type program --> jaclang.compiler.driver.nativecache { JacProgram }
    program --> jaclang.compiler.driver.nativecache.NativeBuildSession.__post_init__ {
        JacProgram
    }
    program --> jaclang.compiler.driver.pass_driver { JacProgram }
    type program --> jaclang.compiler.driver.pipeline { JacProgram }
    program --> jaclang.compiler.driver.pipeline_runner { JacProgram }
    program --> jaclang.compiler.driver.selfhost { JacProgram }
    program --> jaclang.compiler.driver.source_failures { JacProgram }
    type program --> jaclang.compiler.driver.source_products { JacProgram }
    type program --> jaclang.compiler.frontend.parser.frontend { JacProgram }
    type program --> jaclang.compiler.passes.boundary_analysis_pass { JacProgram }
    program --> jaclang.compiler.passes.cfg_build_pass.cfg_dot_from_file { JacProgram }
    type program --> jaclang.compiler.passes.ownership_check_pass { JacProgram }
    type program --> jaclang.compiler.passes.static_analysis_pass { JacProgram }
    type program --> jaclang.compiler.passes.type_checker_pass { JacProgram }
    type program --> jaclang.compiler.passes.variant_agreement_pass { JacProgram }
    type program --> jaclang.compiler.passes.wasm_contract { JacProgram }
    program --> jaclang.compiler.placement.placement_facts.discover_spaces {
        JacProgram
    }
    type program --> jaclang.compiler.placement.placement_solver { JacProgram }
    program --> jaclang.compiler.placement.placement_solver._native_dep_scan {
        JacProgram
    }
    type program --> jaclang.compiler.symbol_utils { JacProgram }
    program --> jaclang.compiler.tests.test_batch_decl_identity { JacProgram }
    program --> jaclang.compiler.tests.test_client_codegen_facts { JacProgram }
    program --> jaclang.compiler.tests.test_client_npm_entry_root { JacProgram }
    program --> jaclang.compiler.tests.test_global_narrowing { JacProgram }
    program --> jaclang.compiler.tests.test_graph_fragment_equivalence { JacProgram }
    program --> jaclang.compiler.tests.test_jac_mobui_typing { JacProgram }
    program --> jaclang.compiler.tests.test_missing_local_import { JacProgram }
    program --> jaclang.compiler.tests.test_native_kernel_cache { JacProgram }
    program --> jaclang.compiler.tests.test_pipeline_products { JacProgram }
    program --> jaclang.compiler.tests.test_stubcat_roundtrip { JacProgram }
    program --> jaclang.compiler.tests.test_subscript_assignment { JacProgram }
    program --> jaclang.compiler.tests.test_tarfile_equivalence { JacProgram }
    program --> jaclang.compiler.tests.test_test_block_analysis { JacProgram }
    program --> jaclang.compiler.tests.test_unknown_cascade { JacProgram }
    program --> jaclang.compiler.tests.test_untyped_third_party { JacProgram }
    program --> jaclang.compiler.tests.test_zstd_equivalence { JacProgram }
    program --> jaclang.compiler.tests.xbackend_equiv { JacProgram }
    program --> jaclang.compiler.tools.code_intel { JacProgram }
    type program --> jaclang.compiler.tools.jac_auto_lint_pass { JacProgram }
    program --> jaclang.compiler.tools.jac_auto_lint_pass.JacAutoLintPass._base_decl_archetypes {
        JacProgram
    }
    program --> jaclang.compiler.tools.jac_formatter_pass.format_module { JacProgram }
    program --> jaclang.compiler.tools.lang_tools { JacProgram }
    program --> jaclang.compiler.tools.unparse_pass.unparse_module { JacProgram }
    type program --> jaclang.compiler.types.stubcat.build { JacProgram }
    program --> jaclang.compiler.types.stubcat.build.build_catalog { JacProgram }
    type program --> jaclang.compiler.types.type_evaluator { JacProgram }
    type program --> jaclang.dist.native_product { JacProgram }
    program --> jaclang.dist.native_product.write_native_product { JacProgram }
    type program --> jaclang.dist.precompile_bytecode { JacProgram }
    program --> jaclang.dist.precompile_bytecode._application_sources { JacProgram }
    program --> jaclang.dist.precompile_bytecode.precompile_native_unit { JacProgram }
    program --> jaclang.dist.precompile_bytecode.precompile_unit_context { JacProgram }
    program --> jaclang.dist.precompile_bytecode.seal_native { JacProgram }
    program --> jaclang.dist.precompile_bytecode.sealable_sources { JacProgram }
    type program --> jaclang.dist.publish.builder { JacProgram }
    program --> jaclang.dist.publish.builder.WheelBuilder._assemble_src_data {
        JacProgram as JacProgramRt
    }
    program --> jaclang.dist.publish.builder._module_is_client_source {
        JacProgram as JacProgramRt
    }
    program --> jaclang.dist.publish.npm_sources.collect_npm_sources { JacProgram }
    program --> jaclang.dist.publish.runtime_npm._compile_cl_to_js { JacProgram }
    program --> jaclang.dist.publish.runtime_vendor { JacProgram }
    program --> jaclang.dist.source.project { JacProgram }
    program --> jaclang.lsp.server.engine { JacProgram }
    program --> jaclang.lsp.server.module_manager { JacProgram }
    type program --> jaclang.runtime.build_services { JacProgram }
    type program --> jaclang.runtime.runtime { JacProgram }
    program --> jaclang.scale.tests.apps.test_fleet_from_apps { JacProgram }
    program --> jaclang.server.hmr.HotReloader._classify_declarations { JacProgram }
    program --> jaclang.testing.cl_test_runner.compile_cl_module { JacProgram }
    program --> jaclang.testing.cl_test_runner.module_is_client { JacProgram }
    program --> jaclang.testing.test_runner._fresh_jac_state { JacProgram }
    progstate --> jaclang.compiler.driver.program {
        AnalysisCaches,
        BuildScratch,
        DepGraph,
        DiagLedger,
        ModuleHub,
        unit_collect_budget
    }
    type selfhost --> jaclang.compiler.driver.build_services { SelfHostCache }
    selfhost --> jaclang.compiler.driver.build_services.CompilerBuildServices.selfhost {
        SelfHostCache
    }
    selfhost --> jaclang.compiler.driver.compiler { SelfHostCache }
    selfhost --> jaclang.compiler.types.stubcat.build.build_catalog { SelfHostCache }
    type selfhost --> jaclang.runtime.build_services { SelfHostCache }
    type selfhost --> jaclang.runtime.runtime { SelfHostCache }
    source_failures --> jaclang.compiler.driver.application._prepare {
        bootstrap_tier_failure_details,
        module_scoped_failure_details
    }
    source_failures --> jaclang.compiler.driver.compiler {
        CompilerSourceError,
        bootstrap_tier_failure_details,
        import_error_re_enters,
        module_import_in_flight,
        module_scoped_failure_details,
        note_compiler_source_failure
    }
    source_failures --> jaclang.compiler.driver.pipeline {
        fail_loud_on_compiler_source
    }
    source_failures --> jaclang.compiler.driver.pipeline_runner {
        module_import_in_flight
    }
    source_failures --> jaclang.compiler.driver.source_products.python_source {
        bootstrap_tier_failure_details,
        module_scoped_failure_details
    }
    source_failures --> jaclang.dist.precompile_bytecode._emit_unit_diagnostics {
        compiler_source_failure_details
    }
    source_failures --> jaclang.testing.cl_test_runner.module_is_client {
        CompilerSourceError,
        compiler_source_failure_origin
    }
    source_products --> jaclang.dist.publish.builder { python_source }
    source_products --> jaclang.dist.publish.runtime_vendor._compile_runtime_module {
        python_source
    }
    source_products --> jaclang.dist.source.project { python_source }
    wiring --> jaclang.cli.commands.arch {
        ARCH_FILE_NAME,
        WiringSpec,
        scope_path_of,
        wiring_for_path
    }
    wiring --> jaclang.compiler.driver.bccache.discover_wiring_file {
        arch_file_for,
        is_arch_file
    }
    wiring --> jaclang.compiler.driver.compilation_context.compilation_scope {
        wiring_scope
    }
    wiring --> jaclang.compiler.driver.compiler.JacCompiler.parse_str {
        dedupe_generated_imports
    }
    wiring --> jaclang.compiler.driver.jir.compute_module_key { wiring_digest_for }
    wiring --> jaclang.compiler.driver.jir.unit_source_digest { wiring_digest_for }
    wiring --> jaclang.compiler.frontend.parser.frontend._native_parse_woven {
        is_arch_file
    }
    wiring --> jaclang.compiler.frontend.parser.frontend.annex_sources {
        wiring_annex_for
    }
    wiring --> jaclang.compiler.passes.import_wiring_pass {
        WireBinding,
        WiringSpec,
        is_arch_file,
        scope_owners,
        scope_path_of,
        wiring_for_path
    }
    wiring --> jaclang.compiler.tools.jac_auto_lint_pass {
        WiringSpec,
        compiled_by_seed,
        is_arch_file,
        scope_path_of,
        wiring_for_path
    }
    wiring --> jaclang.compiler.placement.placement_solver._native_dep_scan {
        arch_file_for,
        dedupe_generated_imports
    }
}

impl import jaclang.compiler.frontend {
    codeinfo --> jaclang.cli.check_report.print_native_coverage {
        effective_default_codespace,
        native_display_text
    }
    codeinfo --> jaclang.cli.commands.execution._exec_file {
        get_effective_default_codespace_override,
        set_effective_default_codespace
    }
    codeinfo --> jaclang.cli.commands.execution.serve {
        set_effective_default_codespace
    }
    codeinfo --> jaclang.cli.commands.native_build._application_ir {
        native_unit_identity
    }
    type codeinfo --> jaclang.client.client_bundle { ClientArtifact, ClientManifest }
    type codeinfo --> jaclang.client.compiler { ClientArtifact, ClientManifest }
    codeinfo --> jaclang.client.compiler.ViteCompiler._compile_wasm_module {
        native_wasm_stem
    }
    type codeinfo --> jaclang.client.jac_client_compiler {
        ClientArtifact,
        ClientManifest
    }
    type codeinfo --> jaclang.client.jac_to_js { ClientArtifact, ClientManifest }
    codeinfo --> jaclang.client.vite_client_bundle { ClientArtifact }
    codeinfo --> jaclang.compiler.backends.es.client_kernel_cache._es_backend_fingerprint {
        jaclang_pkg_root
    }
    codeinfo --> jaclang.compiler.backends.es.client_kernel_cache._unit_source_path {
        kernel_unit_path
    }
    codeinfo --> jaclang.compiler.backends.es.esast_gen_pass {
        BoundaryTypeInfo,
        ClientManifest
    }
    codeinfo --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._build_spawn_runtime_call {
        endpoint_key
    }
    codeinfo --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._generate_na_import_binding {
        native_wasm_stem
    }
    codeinfo --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._generate_sv_import_stubs {
        endpoint_key
    }
    codeinfo --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._try_lower_server_rpc_call {
        endpoint_key
    }
    codeinfo --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass.prepare {
        ClientManifest
    }
    codeinfo --> jaclang.compiler.backends.native.kernel_resolve._bundled_kernel {
        jaclang_pkg_root
    }
    codeinfo --> jaclang.compiler.backends.native.kernel_resolve._unit_sources_match {
        native_unit_identity
    }
    codeinfo --> jaclang.compiler.backends.native.kernel_resolve.compiler_package_parent {
        jaclang_pkg_root
    }
    codeinfo --> jaclang.compiler.backends.native.kernel_resolve.source_tree_kernel_path {
        jaclang_pkg_root
    }
    type codeinfo --> jaclang.compiler.backends.native.link_glue { InteropBinding }
    codeinfo --> jaclang.compiler.backends.native.link_glue.inject_heap_accounting {
        HDR_TOTAL
    }
    codeinfo --> jaclang.compiler.backends.native.link_plan {
        install_native_static_init,
        kernel_unit_path
    }
    type codeinfo --> jaclang.compiler.backends.native.link_plan { InteropBinding }
    codeinfo --> jaclang.compiler.backends.native.link_plan._build_link_plan {
        is_kernel_unit_path
    }
    codeinfo --> jaclang.compiler.backends.native.link_plan._write_sidecar {
        native_unit_identity
    }
    codeinfo --> jaclang.compiler.backends.native.link_plan.units_source_key {
        native_unit_identity
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass {
        HDR_ALLOC_ID_OFF,
        HDR_DTOR_OFF,
        HDR_MAGIC,
        HDR_MAGIC_SHIFT_BASE,
        HDR_RC_OFF,
        HDR_TAG_OFF,
        HDR_TOTAL,
        JACSTR_DESC_FIELDS,
        RC_SENTINEL,
        STR_LEN_TAG_BIT,
        STR_LEN_TAG_SHIFT,
        str_len_tag
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass.__post_init__ {
        native_unit_prefix
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._arch_display {
        native_arch_display
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
        resolve_native_module
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_entry {
        native_entry_name,
        native_runtime_probe_name
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_test {
        native_test_symbol
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._demote_method_if_unlowerable {
        native_display_text
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._emit_class_display_fn {
        NATIVE_ARCH_SCOPE_SEP
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._emit_glob_init_func {
        native_glob_init_name
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._emit_jacval_slot_drop_fn {
        native_safe_sym
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._ensure_fmt_kernel {
        FMT_KERNEL_REL,
        kernel_unit_path
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._eq_fn_new {
        native_safe_sym
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._export_native_iface {
        native_glob_init_name,
        native_module_key,
        native_unit_spelling
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._export_native_layout {
        NativeEnumLayout,
        NativeFieldInfo,
        NativeFuncLayout,
        NativeModuleLayout,
        NativeStructLayout,
        NativeTestLayout,
        NativeTupleLayout
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._find_source_ability {
        resolve_native_module
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._forward_declare_imported_ability {
        native_def_symbol
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._is_kernel_unit {
        is_kernel_unit_path
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._native_module_call_target {
        NATIVE_STDLIB_EXTENSIONS
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._opaque_field_if_unlowerable {
        native_display_text
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._osp_kernel_init_fns {
        native_glob_init_name
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._prefix_of_path {
        native_unit_prefix
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._process_clib_imports {
        is_bundled_native_module,
        resolve_native_module
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._pyb_base_of {
        NATIVE_ERASED_BASES
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_entry_globals {
        native_def_symbol
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_imported_struct_types {
        is_bundled_native_module,
        native_unit_compile_active as _typed_nuc,
        resolve_native_module
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_osp_kernel_module {
        OSP_GRAPH_REL,
        OSP_KERNEL_REL,
        kernel_unit_path
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_region_kernel {
        REGION_KERNEL_REL,
        kernel_unit_path
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._repr_dict_fn {
        native_safe_sym
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._repr_leaf_fn {
        native_safe_sym
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._repr_list_fn {
        native_safe_sym
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._repr_obj_fn {
        native_safe_sym
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._repr_set_fn {
        native_safe_sym
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._repr_str_fn {
        native_safe_sym
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._repr_tuple_fn {
        native_safe_sym
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._skip_is_other_module {
        resolve_native_module
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._symbol_for {
        native_def_symbol,
        native_symbol_name,
        native_unit_identity,
        native_unit_spelling
    }
    codeinfo --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._vtable_symbol {
        native_symbol_name,
        native_unit_spelling
    }
    codeinfo --> jaclang.compiler.backends.native.region_abi._region_layout_facts {
        HDR_ALLOC_ID_OFF,
        HDR_DTOR_OFF,
        HDR_MAGIC,
        HDR_MAGIC_SHIFT_BASE,
        HDR_RC_OFF,
        HDR_TAG_OFF,
        HDR_TOTAL,
        RC_SENTINEL
    }
    codeinfo --> jaclang.compiler.backends.py.jcir_gen_pass {
        BoundaryTypeInfo,
        InteropBinding
    }
    codeinfo --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._class_ref {
        module_dotted_name
    }
    codeinfo --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._gen_native_interop_stubs {
        native_def_symbol,
        native_symbol_name,
        native_unit_prefix
    }
    codeinfo --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._materialize {
        module_dotted_name
    }
    codeinfo --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._native_test_shim_stmts {
        native_test_symbol,
        native_unit_prefix
    }
    codeinfo --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._sv_endpoint_effects {
        endpoint_key
    }
    codeinfo --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass.exit_archetype {
        endpoint_key
    }
    codeinfo --> jaclang.compiler.driver.application.prepare_application {
        get_effective_default_codespace_override,
        set_effective_default_codespace
    }
    codeinfo --> jaclang.compiler.driver.boundary_classify._default_codespace_for {
        effective_default_codespace
    }
    codeinfo --> jaclang.compiler.driver.boundary_classify.bridgeable_import_target {
        is_shared_runtime_module
    }
    codeinfo --> jaclang.compiler.driver.boundary_classify.import_binds_client_native {
        InteropContext,
        InteropManifest
    }
    codeinfo --> jaclang.compiler.driver.build_services.CompilerBuildServices.prepare_application {
        set_effective_default_codespace
    }
    type codeinfo --> jaclang.compiler.driver.client_graph { ClientArtifact }
    codeinfo --> jaclang.compiler.driver.compile_options.CompileOptions.__post_init__ {
        effective_native_target
    }
    codeinfo --> jaclang.compiler.driver.compile_options.CompileOptions.native_required_for {
        module_dotted_name
    }
    codeinfo --> jaclang.compiler.driver.compile_options.pop_native_target {
        _native_target_ctx
    }
    codeinfo --> jaclang.compiler.driver.compile_options.push_native_target {
        set_native_target_override
    }
    type codeinfo --> jaclang.compiler.driver.compiler {
        ClientArtifact,
        CodeGenTarget,
        NativeModuleLayout
    }
    codeinfo --> jaclang.compiler.driver.compiler.JacCompiler._cached_client_artifact {
        ClientArtifact
    }
    codeinfo --> jaclang.compiler.driver.compiler.JacCompiler._check_native_abi {
        NATIVE_ABI_VERSION
    }
    codeinfo --> jaclang.compiler.driver.compiler.JacCompiler._compile_once {
        set_effective_default_codespace
    }
    codeinfo --> jaclang.compiler.driver.compiler.JacCompiler._deserialize_interop_table {
        InteropBinding,
        InteropContext,
        InteropManifest
    }
    codeinfo --> jaclang.compiler.driver.compiler.JacCompiler._load_native_from_cache {
        CodeGenTarget
    }
    codeinfo --> jaclang.compiler.driver.compiler.JacCompiler._restore_sections {
        ClientArtifact
    }
    codeinfo --> jaclang.compiler.driver.compiler.JacCompiler.client_artifact_of {
        ClientArtifact
    }
    codeinfo --> jaclang.compiler.driver.compiler.JacCompiler.compile {
        get_effective_default_codespace_override,
        reset_native_unit_compile,
        set_effective_default_codespace,
        set_native_unit_compile
    }
    codeinfo --> jaclang.compiler.driver.compiler.JacCompiler.parse_str {
        is_client_by_location as _cbl
    }
    codeinfo --> jaclang.compiler.driver.compiler.JacCompiler.stamp_boundary_facts {
        is_bundled_native_module,
        resolve_native_module
    }
    codeinfo --> jaclang.compiler.driver.ifacecache.IfaceRegistry.client_boundary_facts {
        CodeGenTarget
    }
    codeinfo --> jaclang.compiler.driver.jir._analysis_fingerprint_for {
        effective_native_target
    }
    codeinfo --> jaclang.compiler.driver.jir._module_codespace_mode {
        effective_default_codespace
    }
    codeinfo --> jaclang.compiler.driver.jir.native_deps_section { native_unit_ref }
    codeinfo --> jaclang.compiler.driver.jir.parse_native_dep_rows {
        resolve_native_unit_ref
    }
    codeinfo --> jaclang.compiler.driver.jir.sidecar_unit_paths { jaclang_pkg_root }
    codeinfo --> jaclang.compiler.driver.na_coverage._drop_demoted_native_bindings {
        InteropContext,
        InteropManifest
    }
    codeinfo --> jaclang.compiler.driver.native_iface {
        NativeModuleLayout,
        native_layout_to_dict
    }
    codeinfo --> jaclang.compiler.driver.native_iface.NativeIface.from_dict {
        native_layout_from_dict
    }
    codeinfo --> jaclang.compiler.driver.native_iface.NativeIface.resolve_deps {
        resolve_native_unit_ref
    }
    codeinfo --> jaclang.compiler.driver.native_iface.NativeIface.to_dict {
        native_unit_ref
    }
    type codeinfo --> jaclang.compiler.driver.nativecache { CodeGenTarget }
    codeinfo --> jaclang.compiler.driver.nativecache.NativeBuildSession.lower {
        get_effective_default_codespace_override,
        reset_native_unit_compile,
        set_effective_default_codespace,
        set_native_unit_compile
    }
    codeinfo --> jaclang.compiler.driver.nativecache.NativeUnitRegistry._source_key {
        get_effective_default_codespace_override,
        set_effective_default_codespace
    }
    codeinfo --> jaclang.compiler.driver.nativecache.NativeUnitRegistry._stash_products {
        CodeGenTarget
    }
    type codeinfo --> jaclang.compiler.driver.program { ClientArtifact }
    type codeinfo --> jaclang.compiler.driver.progstate { ClientArtifact }
    codeinfo --> jaclang.compiler.driver.selfhost.SelfHostCache.evict_unit {
        CodeGenTarget
    }
    codeinfo --> jaclang.compiler.driver.selfhost.SelfHostCache.resolve {
        is_native_by_location,
        is_shared_runtime_module,
        native_unit_compile_active
    }
    type codeinfo --> jaclang.compiler.frontend.unitree { CodeGenTarget }
    codeinfo --> jaclang.compiler.frontend.unitree.ModulePath.native_bundled_path {
        NATIVE_STDLIB_EXTENSIONS,
        is_bundled_native_module,
        resolve_native_module
    }
    codeinfo --> jaclang.compiler.frontend.unitree.UniNode.gen.getter {
        CodeGenTarget as _CGT
    }
    codeinfo --> jaclang.compiler.native_scope.scope_allows_inferred_path {
        native_unit_compile_active,
        native_unit_identity
    }
    codeinfo --> jaclang.compiler.native_scope.scope_module_path { jaclang_pkg_root }
    codeinfo --> jaclang.compiler.passes.boundary_analysis_pass {
        BoundaryTypeInfo,
        InteropBinding,
        InteropContext
    }
    codeinfo --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._collect_boundary_type {
        endpoint_key
    }
    codeinfo --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._register_na_client_import {
        native_wasm_stem
    }
    codeinfo --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass.finish {
        endpoint_key
    }
    codeinfo --> jaclang.compiler.passes.capability_check_pass {
        NATIVE_SUPPORTED_STDLIB,
        is_native_by_location
    }
    codeinfo --> jaclang.compiler.passes.capability_check_pass.base_expr_is_erased {
        NATIVE_ERASED_BASES
    }
    codeinfo --> jaclang.compiler.passes.capability_check_pass.classify_native_import {
        native_erased_import_names
    }
    codeinfo --> jaclang.compiler.passes.capability_check_pass.native_capability_violations {
        bundled_native_module_names,
        is_bundled_native_module,
        resolve_native_module
    }
    codeinfo --> jaclang.compiler.passes.endpoint_effect_pass.EndpointEffectPass._classify {
        endpoint_descriptor
    }
    codeinfo --> jaclang.compiler.passes.endpoint_effect_pass.EndpointEffectPass.enter_ability {
        endpoint_key
    }
    codeinfo --> jaclang.compiler.passes.endpoint_effect_pass.EndpointEffectPass.enter_archetype {
        endpoint_key
    }
    codeinfo --> jaclang.compiler.passes.layout_pass.archetype_native_name {
        native_arch_name
    }
    codeinfo --> jaclang.compiler.passes.layout_pass.is_erased_base_name {
        NATIVE_ERASED_BASES
    }
    codeinfo --> jaclang.compiler.placement.placement._erased_only_import {
        native_erased_import_names
    }
    codeinfo --> jaclang.compiler.placement.placement.scan_native_blockers {
        NATIVE_SUPPORTED_STDLIB,
        is_bundled_native_module,
        resolve_native_module
    }
    codeinfo --> jaclang.compiler.placement.placement_facts._toolchain_rel {
        jaclang_pkg_root
    }
    codeinfo --> jaclang.compiler.placement.placement_facts.native_unit {
        is_kernel_unit_path,
        native_unit_compile_active
    }
    codeinfo --> jaclang.compiler.placement.placement_solver._native_deps_ok {
        effective_native_closure_cap,
        native_unit_compile_active
    }
    codeinfo --> jaclang.compiler.symbol_utils.erased_identity_call_arg {
        NATIVE_ERASED_IDENTITY_CALLS
    }
    codeinfo --> jaclang.compiler.symbol_utils.erased_import_binds {
        NATIVE_ERASED_IMPORTS
    }
    codeinfo --> jaclang.compiler.tests.xbackend_equiv {
        JAC_ENTRY_SYMBOL,
        native_symbol_name,
        native_unit_prefix
    }
    codeinfo --> jaclang.compiler.tests.xbackend_equiv.run_js_module_fixture {
        ClientArtifact,
        ClientManifest
    }
    codeinfo --> jaclang.compiler.tools.comment_attach_pass { NodeComments }
    codeinfo --> jaclang.compiler.types.ct_eval { module_dotted_name }
    codeinfo --> jaclang.compiler.types.types.ClassDetailsShared.same_class {
        bundled_stdlib_module_of
    }
    codeinfo --> jaclang.dist.source.client.write_client { native_wasm_stem }
    codeinfo --> jaclang.lsp.server.utils { CodeLocInfo }
    codeinfo --> jaclang.runtime.portability {
        NATIVE_SUPPORTED_STDLIB,
        is_bundled_native_module
    }
    const_fold --> jaclang.compiler.backends.native.na_ir_gen_pass { fold_const }
    const_fold --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_const_expr {
        fold_const
    }
    const_fold --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._folded_ord {
        fold_const
    }
    const_fold --> jaclang.compiler.passes.layout_pass { fold_const }
    const_fold --> jaclang.compiler.types.enum_utils { fold_const }
    const_fold --> jaclang.compiler.types.operations.get_pow_result_type { fold_const }
    constant --> jaclang.cli.commands.fix._priv_top_decls { SymbolAccess }
    constant --> jaclang.compiler.backends.es.esast_gen_pass {
        CodeContext,
        SymbolType,
        Tokens as Tok
    }
    constant --> jaclang.compiler.backends.es.framework_backend.FrameworkBackend._get_setter_name {
        client_state_setter_name
    }
    constant --> jaclang.compiler.backends.es.free_ident_audit { BROWSER_SEED_GLOBALS }
    constant --> jaclang.compiler.backends.es.jac_runtime_js._build_types_runtime_js {
        TOKEN_MAP
    }
    constant --> jaclang.compiler.backends.native.foreign { is_borrow_kind }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass {
        CodeContext,
        OwnershipKind,
        SymbolAccess,
        Tokens as Tok
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._clib_param_info {
        is_borrow_kind
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._clib_place_ptr {
        is_borrow_kind
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_assignment {
        OwnershipKind
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_unary {
        OwnershipKind,
        is_borrow_kind
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._ct_fold {
        ExprCtx
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._flow_future_licensed {
        Tokens as Tok
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._hl_view_base_licensed {
        OwnershipKind
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._nogc_borrow_local_assign {
        is_borrow_kind
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._nogc_consume_assigned_local {
        OwnershipKind,
        is_borrow_kind
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._predeclare_nested_siblings {
        SymbolType
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._try_flow_for_parallel {
        Tokens as Tok
    }
    constant --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._try_flow_future {
        Tokens as Tok
    }
    constant --> jaclang.compiler.backends.native.primitives_native { Tokens as Tok }
    constant --> jaclang.compiler.backends.py.jcir_gen_pass {
        CodeContext,
        OwnershipKind,
        SymbolStorage,
        Tokens as Tok,
        is_borrow_kind
    }
    constant --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._gen_native_interop_stubs {
        Tokens as _NsTok
    }
    constant --> jaclang.compiler.c_interop.foreign_read_is_place { is_borrow_kind }
    constant --> jaclang.compiler.driver.boundary_classify {
        CodeContext,
        SymbolAccess,
        Tokens as Tok
    }
    constant --> jaclang.compiler.driver.boundary_classify.module_own_native_anchor {
        OwnershipKind
    }
    constant --> jaclang.compiler.driver.compiler { CodeContext, Tokens as Tok }
    constant --> jaclang.compiler.driver.ifacecache.IfaceRegistry._client_edges {
        CodeContext
    }
    constant --> jaclang.compiler.driver.pipeline_runner { CodeContext }
    constant --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.analysis {
        CodeContext as _CodeCtx
    }
    constant --> jaclang.compiler.driver.wiring { Tokens as Tok }
    constant --> jaclang.compiler.expr_keys { Tokens as Tok }
    constant --> jaclang.compiler.expr_keys.type_tag_borrows { is_borrow_kind }
    constant --> jaclang.compiler.frontend.codeinfo {
        NATIVE_ERASED_ANNOTATIONS,
        NATIVE_ERASED_TYPE_MARKERS,
        TYPE_PARAM_CONSTRUCTORS
    }
    constant --> jaclang.compiler.frontend.helpers.evaluate_version_condition {
        Tokens as Tok
    }
    constant --> jaclang.compiler.frontend.module_facts {
        CodeContext,
        NATIVE_ERASED_TYPE_MARKERS,
        TYPE_PARAM_CONSTRUCTORS
    }
    constant --> jaclang.compiler.frontend.parser.parser {
        CodeContext,
        OwnershipKind,
        ParamKind,
        SymbolAccess,
        SymbolType,
        Tokens as Tok
    }
    constant --> jaclang.compiler.frontend.unitree {
        BUILTIN_CALLABLE_NAMES,
        BindingKind,
        CodeContext,
        DELIM_MAP,
        DeleteTargetError,
        ExprCtx,
        ImmutabilityKind,
        JacSemTokenModifier as SemTokMod,
        JacSemTokenType as SemTokType,
        OwnershipKind,
        ParamKind,
        SymbolAccess,
        SymbolStorage,
        SymbolType,
        Tokens as Tok
    }
    constant --> jaclang.compiler.frontend.unitree.UniNode.gen_token { TOKEN_MAP }
    constant --> jaclang.compiler.jc_unit { CodeContext }
    constant --> jaclang.compiler.passes.access_check_pass { SymbolAccess }
    constant --> jaclang.compiler.passes.ast_validation_pass {
        CodeContext,
        DeleteTargetError,
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.boundary_analysis_pass {
        CodeContext,
        SymbolType,
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._get_context {
        CodeContext
    }
    constant --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._register_native_absorb {
        SymbolAccess
    }
    constant --> jaclang.compiler.passes.capability_check_pass { SymbolType }
    constant --> jaclang.compiler.passes.capability_check_pass.PortabilityWarnPass._check_js_globals {
        ExprCtx
    }
    constant --> jaclang.compiler.passes.capability_check_pass.PortabilityWarnPass._check_js_keywords {
        ExprCtx
    }
    constant --> jaclang.compiler.passes.capability_check_pass.native_capability_violations {
        CodeContext,
        ExprCtx,
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.cfg_build_pass.CFGBuildPass.exit_ctrl_stmt {
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.cfg_build_pass.CoalesceBBPass._node_label {
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.cfg_build_pass._bool_is_and { Tokens as Tok }
    constant --> jaclang.compiler.passes.endpoint_effect_pass {
        SymbolType,
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.graph_lowering_pass { Tokens as Tok }
    constant --> jaclang.compiler.passes.layout_pass { OwnershipKind, Tokens as Tok }
    constant --> jaclang.compiler.passes.mtir_gen_pass { Tokens as Tok }
    constant --> jaclang.compiler.passes.osp_analysis { CodeContext, Tokens as Tok }
    constant --> jaclang.compiler.passes.ownership_check_pass {
        OwnershipKind,
        SymbolStorage,
        Tokens as Tok,
        is_borrow_kind,
        is_mut_kind
    }
    constant --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._emit_flow_for_diagnostics {
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._emit_sendability_diagnostics {
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._flow_for_stmts {
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._flow_lend_joined {
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._flow_reduce_shape {
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._spawn_move_gen {
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.ownership_hints { OwnershipKind }
    constant --> jaclang.compiler.passes.pyast_load_pass {
        RESERVED_IDENT_NAMES,
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.pyast_load_pass.PyastBuildPass.proc_aug_assign {
        TOKEN_MAP
    }
    constant --> jaclang.compiler.passes.rc_facts_pass {
        ExprCtx,
        OwnershipKind,
        SymbolStorage,
        Tokens as Tok,
        is_borrow_kind
    }
    constant --> jaclang.compiler.passes.rc_facts_pass.RcFactsPass._asn_makes_region_handle {
        OwnershipKind
    }
    constant --> jaclang.compiler.passes.region_infer_pass {
        SymbolStorage,
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.semantic_analysis_pass {
        ExprCtx,
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.static_analysis_pass { ExprCtx, SymbolType }
    constant --> jaclang.compiler.passes.static_analysis_pass.StaticAnalysisPass._check_client_imports {
        CodeContext
    }
    constant --> jaclang.compiler.passes.sym_tab_build_pass { SymbolAccess }
    constant --> jaclang.compiler.passes.sym_tab_build_pass.SymTabBuildPass.exit_binary_expr {
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.sym_tab_build_pass.SymTabBuildPass.exit_global_vars {
        SymbolType
    }
    constant --> jaclang.compiler.passes.type_checker_pass {
        ImmutabilityKind,
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._check_c_interop_import {
        is_borrow_kind
    }
    constant --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._install_client_state_setters {
        client_state_setter_name
    }
    constant --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass.exit_ability {
        OwnershipKind
    }
    constant --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass.exit_impl_def {
        Tokens as Tok
    }
    constant --> jaclang.compiler.passes.variant_agreement_pass { SymbolAccess }
    constant --> jaclang.compiler.passes.wasm_contract { OwnershipKind }
    constant --> jaclang.compiler.placement.placement {
        CodeContext,
        SymbolAccess,
        Tokens as Tok
    }
    constant --> jaclang.compiler.placement.placement._references_browser_seed_global {
        BROWSER_SEED_GLOBALS
    }
    constant --> jaclang.compiler.placement.placement_solver {
        CodeContext,
        Tokens as Tok
    }
    constant --> jaclang.compiler.symbol_utils {
        CodeContext,
        SymbolType,
        Tokens as Tok
    }
    constant --> jaclang.compiler.symbol_utils.report_placement_warnings { CodeContext }
    constant --> jaclang.compiler.tools.comment_attach_pass { Tokens as Tok }
    constant --> jaclang.compiler.tools.doc_ir_gen_pass { Tokens as Tok, is_mut_kind }
    constant --> jaclang.compiler.tools.jac_auto_lint_pass { TOKEN_MAP, Tokens as Tok }
    constant --> jaclang.compiler.tools.normalize_pass { CodeContext }
    constant --> jaclang.compiler.tools.reactive_use_walk { ExprCtx }
    constant --> jaclang.compiler.tools.unparse_pass { OwnershipKind, is_mut_kind }
    constant --> jaclang.compiler.types.builtin_extensions {
        SymbolAccess,
        SymbolType,
        Tokens
    }
    constant --> jaclang.compiler.types.ct_eval {
        CodeContext,
        OwnershipKind,
        Tokens as Tok
    }
    constant --> jaclang.compiler.types.fixed_width { TOKEN_MAP, Tokens as Tok }
    constant --> jaclang.compiler.types.operations { Tokens as Tok }
    constant --> jaclang.compiler.types.stubcat.reader {
        BindingKind,
        ImmutabilityKind,
        OwnershipKind,
        SymbolAccess,
        SymbolType,
        Tokens as Tok
    }
    constant --> jaclang.compiler.types.stubcat.writer { BindingKind, ImmutabilityKind }
    constant --> jaclang.compiler.types.ts_decl_parser { BindingKind }
    constant --> jaclang.compiler.types.type_evaluator {
        BindingKind,
        CodeContext,
        ExprCtx,
        ImmutabilityKind,
        OwnershipKind,
        SymbolAccess,
        SymbolType,
        TOKEN_MAP,
        Tokens as Tok
    }
    constant --> jaclang.compiler.types.type_evaluator.TypeEvaluator._collect_return_types {
        Tokens as _Tok
    }
    constant --> jaclang.compiler.types.type_evaluator.TypeEvaluator._find_predicate_for {
        Tokens as Tok
    }
    constant --> jaclang.compiler.types.type_evaluator.TypeEvaluator._merge_catalog_field_params {
        SymbolType
    }
    constant --> jaclang.compiler.types.type_evaluator.TypeEvaluator._scope_has_fields {
        SymbolType
    }
    constant --> jaclang.compiler.types.type_evaluator.TypeEvaluator.assign_type {
        SymbolType as _RtSymT
    }
    constant --> jaclang.compiler.types.type_evaluator.TypeEvaluator.classify_condition {
        Tokens as Tok
    }
    constant --> jaclang.compiler.types.type_utils { Tokens as Tok }
    constant --> jaclang.compiler.types.type_utils._method_entry_of { SymbolType }
    constant --> jaclang.compiler.types.types.ClassType.is_edge_type { SymbolType }
    constant --> jaclang.compiler.types.types.ClassType.is_node_type { SymbolType }
    constant --> jaclang.compiler.types.types.ClassType.is_walker_type { SymbolType }
    constant --> jaclang.dist.publish.builder._module_is_client_source { CodeContext }
    constant --> jaclang.lsp.server.engine { SymbolType, TOKEN_MAP }
    constant --> jaclang.lsp.server.server {
        JacSemTokenModifier as SemTokMod,
        JacSemTokenType as SemTokType
    }
    constant --> jaclang.server.hmr { CodeContext }
    constant --> jaclang.testing.cl_test_runner.module_is_client { CodeContext }
    diagnostic_utils --> jaclang.cli.commands.analysis.check {
        resolve_diagnostic_tokens
    }
    diagnostic_utils --> jaclang.compiler.driver.pass_driver.diagnostic_policy_for {
        resolve_diagnostic_tokens
    }
    diagnostic_utils --> jaclang.compiler.passes.context { resolve_diagnostic_tokens }
    diagnostics --> jaclang.client.client_diagnostics._diag { DIAGNOSTICS }
    diagnostics --> jaclang.compiler.backends.es.backends.registry { E5081 }
    diagnostics --> jaclang.compiler.backends.es.esast_gen_pass {
        E2025,
        E5010,
        E5011,
        E5012,
        E5016,
        E5017,
        E5018,
        E5080,
        E5081,
        E5085,
        E5086,
        E5097,
        E5099,
        E5101,
        E5103,
        W5013,
        W5014,
        W5015
    }
    diagnostics --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._build_edge_ref {
        E5097
    }
    diagnostics --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._build_osp_filter_pred {
        E5097
    }
    diagnostics --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._build_server_forwarder {
        W6009
    }
    diagnostics --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._edge_tag_literal {
        E5097
    }
    diagnostics --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._ensure_backend {
        E5081
    }
    diagnostics --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._get_ast_or_default {
        E5097
    }
    diagnostics --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._warn_rpc_callable_params {
        W6005
    }
    diagnostics --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass.prepare {
        E5096
    }
    diagnostics --> jaclang.compiler.backends.native.na_compile_pass {
        E5020,
        E5026,
        W5021,
        W5022
    }
    diagnostics --> jaclang.compiler.backends.native.na_ir_gen_pass {
        DiagnosticInfo,
        E5026,
        E5060,
        E5088,
        E5089,
        E5090,
        E5091,
        E5092,
        E5095,
        E9001,
        E9002
    }
    diagnostics --> jaclang.compiler.backends.native.primitives_native { E5092 }
    diagnostics --> jaclang.compiler.backends.py.jcir_bc_gen_pass { E5040, E5043 }
    diagnostics --> jaclang.compiler.backends.py.jcir_gen_pass {
        E5001,
        E5002,
        E5003,
        E5004,
        E5005,
        E5006,
        E5007,
        E5008,
        E5094,
        E5098,
        E5102,
        W5096
    }
    diagnostics --> jaclang.compiler.driver.compiler.JacCompiler._module_scoped_errors {
        Category
    }
    diagnostics --> jaclang.compiler.driver.compiler.JacCompiler._report_missing_native_ir {
        E5092
    }
    diagnostics --> jaclang.compiler.driver.ifacecache._alert_from_record {
        DIAGNOSTICS
    }
    diagnostics --> jaclang.compiler.frontend.diagnostic_utils.resolve_diagnostic_tokens {
        DIAGNOSTICS,
        LINT_ALIASES
    }
    diagnostics --> jaclang.compiler.frontend.parser.frontend { DIAGNOSTICS }
    diagnostics --> jaclang.compiler.native_compiler.NativeCompiler.take_pass_results {
        DIAGNOSTICS
    }
    diagnostics --> jaclang.compiler.passes.access_check_pass {
        E2034,
        E2035,
        E2037,
        E2038,
        E2039,
        W2034,
        W2035,
        W2037,
        W2038,
        W2039
    }
    diagnostics --> jaclang.compiler.passes.ast_validation_pass {
        E0010,
        E0020,
        E0023,
        E0024,
        E0031,
        E0040,
        E0041,
        E0042,
        E0043,
        E0044,
        E0050,
        E0051,
        E0052,
        E0055,
        E0058,
        E0059,
        E0063,
        E0065,
        E0066,
        E0067,
        E0071,
        E0075,
        E0076,
        E0082,
        E0083,
        E2019,
        E2020,
        E2021,
        E2022,
        E2024,
        E2084,
        W2019,
        W2020,
        W2021
    }
    diagnostics --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._check_app_cycle {
        E5104
    }
    diagnostics --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._check_provider_pub {
        E5106
    }
    diagnostics --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._register_na_client_import {
        E5083,
        E5100
    }
    diagnostics --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._reject_owned_type_import {
        E5108
    }
    diagnostics --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass.enter_atom_trailer {
        E5112
    }
    diagnostics --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass.enter_func_call {
        E5110
    }
    diagnostics --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass.finish {
        E5093
    }
    diagnostics --> jaclang.compiler.passes.capability_check_pass {
        E5090,
        E5096,
        W6001,
        W6002,
        W6003,
        W6004
    }
    diagnostics --> jaclang.compiler.passes.context {
        DiagnosticInfo,
        E9001,
        LINT_ALIASES,
        Severity
    }
    diagnostics --> jaclang.compiler.passes.decl_impl_match_pass {
        E2009,
        E2011,
        E2012,
        E2013,
        E2016,
        E2017,
        E2026,
        E2087,
        W2080
    }
    diagnostics --> jaclang.compiler.passes.decl_impl_match_pass.DeclImplMatchPass._connect_one_impl {
        E0064
    }
    diagnostics --> jaclang.compiler.passes.decl_impl_match_pass.DeclImplMatchPass._populate_inline_init_symbols {
        W2080
    }
    diagnostics --> jaclang.compiler.passes.decl_impl_match_pass.DeclImplMatchPass._populate_self_member_symbols {
        W2080
    }
    diagnostics --> jaclang.compiler.passes.graph_lowering_pass { E0084, E0085 }
    diagnostics --> jaclang.compiler.passes.import_wiring_pass {
        E1140,
        E1141,
        E1142,
        E1143,
        E1144,
        E2088,
        E2089,
        E2090,
        E2091,
        E2092,
        E2093,
        E2094,
        W2083
    }
    diagnostics --> jaclang.compiler.passes.jsx_intrinsic_guard_pass { E1105 }
    diagnostics --> jaclang.compiler.passes.layout_pass { E5030, W5031, W5032 }
    diagnostics --> jaclang.compiler.passes.ownership_check_pass {
        E1301,
        E1302,
        E1303,
        E1304,
        E1305,
        E1306,
        E1307,
        E1308,
        E1309,
        E1311,
        E1313,
        E1314,
        E1315,
        E1316,
        E1317,
        E1318,
        E1320,
        E1321,
        E1322,
        E1323,
        E1401,
        E1402,
        E1403,
        E1404,
        E1405,
        E1406,
        W1310,
        W1312
    }
    diagnostics --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._emit_place_intrinsic_diagnostics {
        E1319
    }
    diagnostics --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._emit_raises_diagnostics {
        E1407
    }
    diagnostics --> jaclang.compiler.passes.pyast_load_pass { E5041, E5042 }
    diagnostics --> jaclang.compiler.passes.semantic_analysis_pass {
        E2004,
        E2005,
        E2008,
        W2006,
        W2007,
        W2029
    }
    diagnostics --> jaclang.compiler.passes.static_analysis_pass {
        E1122,
        E1123,
        E1125,
        E2018,
        E2027,
        E2055,
        E2083,
        E2085,
        E2086,
        W1103,
        W2001,
        W2002,
        W2003,
        W2058,
        W2063,
        W2070,
        W2074,
        W2075
    }
    diagnostics --> jaclang.compiler.passes.static_analysis_pass.StaticAnalysisPass._check_client_imports {
        W1105,
        W1106
    }
    diagnostics --> jaclang.compiler.passes.sym_tab_build_pass { E0064, E0077 }
    diagnostics --> jaclang.compiler.passes.type_checker_pass {
        Category,
        DiagnosticInfo,
        E0033,
        E0108,
        E0109,
        E1001,
        E1002,
        E1003,
        E1004,
        E1005,
        E1010,
        E1011,
        E1020,
        E1021,
        E1022,
        E1036,
        E1042,
        E1060,
        E1061,
        E1090,
        E1091,
        E1092,
        E1093,
        E1094,
        E1095,
        E1106,
        E1107,
        E1109,
        E1112,
        E1113,
        E1116,
        E1117,
        E1119,
        E1124,
        E1132,
        E1133,
        E1135,
        E1150,
        E1151,
        E1152,
        E2015,
        W1036,
        W1037,
        W1052,
        W2014,
        W6008
    }
    diagnostics --> jaclang.compiler.passes.variant_agreement_pass { E5105 }
    diagnostics --> jaclang.compiler.placement.placement_solver { DiagnosticInfo }
    diagnostics --> jaclang.compiler.placement.placement_solver._warn_state_forks {
        W6006
    }
    diagnostics --> jaclang.compiler.symbol_utils { E5082, E5084, W6006, W6007 }
    type diagnostics --> jaclang.compiler.symbol_utils { DiagnosticInfo }
    diagnostics --> jaclang.compiler.symbol_utils.report_serverless_kind_errors {
        E5087
    }
    diagnostics --> jaclang.compiler.tools.jac_auto_lint_pass {
        E3012,
        W3001,
        W3002,
        W3003,
        W3004,
        W3005,
        W3007,
        W3008,
        W3009,
        W3010,
        W3013,
        W3020,
        W3021,
        W3022,
        W3023,
        W3024,
        W3025,
        W3030,
        W3035,
        W3036,
        W3037,
        W3038,
        W3039,
        W3040,
        W3041,
        W3042,
        W3043,
        W3050,
        W3051,
        W3052,
        W3053
    }
    diagnostics --> jaclang.compiler.tools.jac_auto_lint_pass.JacAutoLintPass._check_filter_compare_tautology {
        W3040
    }
    diagnostics --> jaclang.compiler.tools.jac_formatter_pass { E5051, W5050 }
    diagnostics --> jaclang.compiler.types.enum_utils { E1001 }
    diagnostics --> jaclang.compiler.types.fixed_width { E1126, E1127, E1128, E1130 }
    diagnostics --> jaclang.compiler.types.operations {
        E1010,
        E1033,
        E1035,
        E1055,
        E1096,
        E1097,
        E1098,
        E1114,
        E1115,
        E1118
    }
    diagnostics --> jaclang.compiler.types.type_evaluator {
        DiagnosticInfo,
        E0033,
        E0049,
        E0108,
        E0109,
        E1001,
        E1002,
        E1010,
        E1023,
        E1030,
        E1031,
        E1032,
        E1033,
        E1034,
        E1035,
        E1038,
        E1040,
        E1041,
        E1043,
        E1044,
        E1050,
        E1051,
        E1052,
        E1053,
        E1054,
        E1055,
        E1056,
        E1057,
        E1062,
        E1063,
        E1064,
        E1065,
        E1070,
        E1071,
        E1072,
        E1073,
        E1080,
        E1081,
        E1096,
        E1097,
        E1098,
        E1099,
        E1100,
        E1101,
        E1102,
        E1103,
        E1104,
        E1110,
        E1111,
        E1120,
        E1121,
        E1129,
        E1131,
        E1134,
        E1136,
        E1137,
        E1138,
        E1139,
        E5094,
        W1050,
        W1051,
        W1053,
        W1100,
        W1101,
        W1102,
        W2081,
        W2082
    }
    helpers --> jaclang.compiler.types.stubcat.writer { evaluate_version_condition }
    helpers --> jaclang.compiler.types.type_utils.collect_member_syms {
        evaluate_version_condition
    }
    module_facts --> jaclang.compiler.backends.common.ast_gen_base { ModuleFacts }
    module_facts --> jaclang.compiler.backends.es.esast_gen_pass { ModuleFacts }
    module_facts --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass.prepare {
        ModuleFacts,
        client_capability_violations
    }
    module_facts --> jaclang.compiler.backends.native.na_ir_gen_pass { ModuleFacts }
    module_facts --> jaclang.compiler.backends.py.jcir_gen_pass { ModuleFacts }
    module_facts --> jaclang.compiler.driver.compiler.JacCompiler._report_missing_native_ir {
        ModuleFacts
    }
    module_facts --> jaclang.compiler.driver.compiler.JacCompiler.stamp_native_import_facts {
        ModuleFacts
    }
    module_facts --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.codegen {
        ModuleFacts
    }
    module_facts --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.native_checks {
        ModuleFacts as _PtyMcp
    }
    module_facts --> jaclang.compiler.passes.capability_check_pass {
        ModuleFacts,
        client_capability_violations
    }
    module_facts --> jaclang.compiler.passes.import_wiring_pass { ModuleFacts }
    module_facts --> jaclang.compiler.passes.osp_analysis { ModuleFacts }
    module_facts --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass.exit_ability {
        ModuleFacts
    }
    module_facts --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass.exit_return_stmt {
        ModuleFacts
    }
    module_facts --> jaclang.compiler.tests.test_module_exports { ModuleFacts }
    module_facts --> jaclang.compiler.types.type_evaluator.TypeEvaluator._init_prelude_from_sources {
        ModuleFacts
    }
    module_facts --> jaclang.compiler.types.type_evaluator.TypeEvaluator.get_type_of_ability {
        ModuleFacts
    }
    parser --> jaclang.cli.commands.fix._parse_module { parse as rd_parse }
    parser --> jaclang.cli.commands.fix._parses_clean { parse as rd_parse }
    parser --> jaclang.compiler.driver.compiler.JacCompiler._prepare_tool_program {
        parse as rd_parse
    }
    parser --> jaclang.compiler.tools.jac_auto_lint_pass.JacAutoLintPass._base_decl_archetypes {
        parse as rd_parse
    }
    relations --> jaclang.compiler.driver.program { ScopeChild }
    relations --> jaclang.compiler.driver.progstate { ScopeChild }
    relations --> jaclang.compiler.frontend.unitree {
        Absorbs,
        CalleeDecl,
        CfgFalse,
        CfgSucc,
        CfgTrue,
        Codespace,
        DecidedCodespace,
        Defines,
        EventTriggerOf,
        InScope,
        NarrowedTypeOf,
        PlacedIn,
        ScopeChild,
        ScopeOverload,
        ScopeParent,
        ScopePrimary,
        SymOf,
        TypeOf,
        Uses,
        codespace_node
    }
    relations --> jaclang.compiler.passes.scope_walk { ScopeChild }
    relations --> jaclang.compiler.types.types {
        BaseOf,
        BoundOf,
        ConstraintOf,
        DeclScopeOf,
        EnumClassOf,
        EnumMemberOf,
        GuardOf,
        MemberInfoOf,
        MroOf,
        OverloadOf,
        ParamDefaultOf,
        ParamOf,
        ParamTypeOf,
        PrivOf,
        ReturnsOf,
        SharedOf,
        TypeArgOf,
        TypeMemberOf,
        TypeParamOf,
        UnionMemberOf,
        ValueTypeOf
    }
    roles --> jaclang.compiler.backends.es.esast_gen_pass { Kid }
    roles --> jaclang.compiler.backends.native.na_ir_gen_pass { Kid }
    roles --> jaclang.compiler.backends.py.jcir_gen_pass { Kid }
    roles --> jaclang.compiler.driver.compiler { Kid }
    roles --> jaclang.compiler.driver.program { Kid }
    roles --> jaclang.compiler.driver.progstate { Kid }
    roles --> jaclang.compiler.driver.wiring { BodyRole, Kid }
    roles --> jaclang.compiler.frontend.module_facts { Kid }
    roles --> jaclang.compiler.frontend.parser.parser { Kid }
    roles --> jaclang.compiler.frontend.unitree {
        AccessRole,
        AccessorsRole,
        AliasRole,
        ArchTagInfoRole,
        ArchTypeRole,
        ArgPatternsRole,
        AssignmentsRole,
        AssignsRole,
        AttributesRole,
        AugOpRole,
        AwaitingBodyRole,
        BaseClassesRole,
        BodyRole,
        BoundRole,
        CasesRole,
        CastTypeRole,
        CauseRole,
        ChainRole,
        ChildrenRole,
        ClibDeclsRole,
        CodeRole,
        CollectionRole,
        ComparesRole,
        ComprRole,
        ConditionRole,
        ConditionalRole,
        ConnAssignRole,
        ConnTypeRole,
        ConsumersRole,
        CountByRole,
        CtrlRole,
        DecoratorsRole,
        DefaultValRole,
        DescriptionRole,
        DocRole,
        DynamicTagRole,
        EdgeSpecRole,
        ElseBodyRole,
        ElseValueRole,
        EndRole,
        ErrorMsgRole,
        EventRole,
        ExTypeRole,
        ExceptsRole,
        ExprRole,
        ExprsRole,
        FTypeRole,
        FilterCondRole,
        FinallyBodyRole,
        FormatPartRole,
        FormatSpecRole,
        FromLocRole,
        FromTargetRole,
        GuardRole,
        HintRole,
        ImplOf,
        InsertLocRole,
        ItemsRole,
        IterRole,
        KeyRole,
        KeywordsRole,
        Kid,
        KvPairRole,
        KvPairsRole,
        KwPatternsRole,
        KwargsRole,
        KwonlyargsRole,
        LeftRole,
        MainRole,
        NameRefRole,
        NameRole,
        OpRole,
        OperandRole,
        OpsRole,
        OutExprRole,
        ParamsRole,
        PartsRole,
        PathRole,
        PatternPathRole,
        PatternRole,
        PatternsRole,
        PosonlyParamsRole,
        ProviderRole,
        ReturnTypeRole,
        RightRole,
        RightsRole,
        Role,
        ScopeRole,
        SignatureRole,
        SlicesRole,
        SourcesRole,
        SpecRole,
        SrcEndpointRole,
        StartRole,
        StepRole,
        StopRole,
        StringsRole,
        TargetRole,
        TargetsRole,
        TgtEndpointRole,
        TokRole,
        TypeCtxRole,
        TypeParamsRole,
        TypeTagRole,
        UnpackRole,
        ValueRole,
        ValueTypeRole,
        ValuesRole,
        VarargsRole,
        VarsRole
    }
    roles --> jaclang.compiler.jc_unit { AccessorsRole, BodyRole, SpecRole }
    roles --> jaclang.compiler.native_compiler.NativeCompiler._register {
        AccessorsRole,
        BodyRole,
        SpecRole
    }
    roles --> jaclang.compiler.passes.annex_weave { BodyRole }
    roles --> jaclang.compiler.passes.ast_validation_pass { Kid }
    roles --> jaclang.compiler.passes.boundary_analysis_pass { Kid }
    roles --> jaclang.compiler.passes.capability_check_pass { Kid }
    roles --> jaclang.compiler.passes.cfg_build_pass { Kid }
    roles --> jaclang.compiler.passes.comptime_resolve_pass { Kid }
    roles --> jaclang.compiler.passes.endpoint_effect_pass { Kid }
    roles --> jaclang.compiler.passes.osp_analysis { Kid }
    roles --> jaclang.compiler.passes.ownership_check_pass { Kid }
    roles --> jaclang.compiler.passes.pyast_load_pass {
        Kid,
        NameRefRole,
        ReturnTypeRole,
        UnpackRole,
        ValueRole
    }
    roles --> jaclang.compiler.passes.region_infer_pass { BodyRole, Kid }
    roles --> jaclang.compiler.passes.type_checker_pass { Kid }
    roles --> jaclang.compiler.tools.comment_attach_pass { Kid }
    roles --> jaclang.compiler.tools.doc_ir_gen_pass { Kid }
    roles --> jaclang.compiler.tools.grammar_extract_pass { Kid }
    roles --> jaclang.compiler.tools.jac_auto_lint_pass {
        AssignmentsRole,
        BodyRole,
        ConditionRole,
        DecoratorsRole,
        DocRole,
        ElseValueRole,
        ExprRole,
        ItemsRole,
        Kid,
        NameRefRole,
        ReturnTypeRole,
        SignatureRole,
        SpecRole,
        TargetRole,
        ValueRole,
        ValuesRole,
        VarsRole
    }
    roles --> jaclang.compiler.tools.normalize_pass { BodyRole, ItemsRole, Kid }
    roles --> jaclang.compiler.tools.reactive_use_walk { Kid, ValueRole }
    roles --> jaclang.compiler.tools.treeprinter { Kid }
    roles --> jaclang.compiler.tools.unparse_pass { BodyRole, Kid, Role }
    roles --> jaclang.compiler.types.operations { Kid }
    roles --> jaclang.compiler.types.stubcat.writer { Kid }
    roles --> jaclang.compiler.types.type_evaluator { Kid }
    srcloc --> jaclang.compiler.driver.ifacecache._span_from_record { Span }
    srcloc --> jaclang.compiler.frontend.codeinfo { CodeLocInfo }
    srcloc --> jaclang.compiler.frontend.parser.frontend { Span }
    srcloc --> jaclang.compiler.frontend.unitree { CodeLocInfo }
    srcloc --> jaclang.compiler.passes.context { CodeLocInfo, Span }
    srcloc --> jaclang.lsp.server.utils { Span }
    type srcloc --> jaclang.project.source { Span }
    srcloc --> jaclang.project.source.span_for_file { Span }
    unitree --> jaclang.cli.commands.analysis._check_file_job { Source as _Src }
    unitree --> jaclang.cli.commands.arch {
        ImplImport,
        Import,
        ImportRule,
        ImportWire,
        ModuleItem,
        ModulePath
    }
    unitree as uni --> jaclang.cli.commands.fix._access_plan;
    unitree as uni --> jaclang.cli.commands.fix._imported_names;
    unitree as uni --> jaclang.cli.commands.fix._module_has_jsx;
    unitree as uni --> jaclang.cli.commands.fix._plain_top_decls;
    unitree as uni --> jaclang.cli.commands.fix._priv_top_decls;
    unitree as uni --> jaclang.cli.commands.transform.py2jac;
    type unitree --> jaclang.client.client_bundle { Module }
    unitree as uni --> jaclang.compiler.backends.common.ast_gen_base;
    unitree --> jaclang.compiler.backends.common.ast_gen_base { TreeWalker }
    unitree as uni --> jaclang.compiler.backends.es.esast_gen_pass;
    unitree as uni --> jaclang.compiler.backends.es.jsx_processor;
    unitree as uni --> jaclang.compiler.backends.es.view_ir;
    type unitree --> jaclang.compiler.backends.native.entry_points { Module }
    unitree as uni --> jaclang.compiler.backends.native.foreign;
    unitree as uni --> jaclang.compiler.backends.native.na_compile_pass;
    unitree as uni --> jaclang.compiler.backends.native.na_ir_gen_pass;
    unitree --> jaclang.compiler.backends.native.primitives_native { Expr, UniNode }
    type unitree --> jaclang.compiler.backends.native.wasm_build { Module as UniModule }
    unitree --> jaclang.compiler.backends.py.jcir_bc_gen_pass { Module }
    unitree --> jaclang.compiler.backends.py.jcir_gen_pass {
        Ability,
        ArchHas,
        Archetype,
        AssertStmt,
        AssignCompr,
        Assignment,
        AstSymbolNode,
        AtomTrailer,
        AtomUnit,
        AwaitExpr,
        BinaryExpr,
        Bool,
        BoolExpr,
        BuiltinType,
        CastExpr,
        CfgExpr,
        CodeBlockStmt,
        CommentToken,
        CompareExpr,
        ConcurrentExpr,
        ConnectOp,
        ContextAwareNode,
        CtrlStmt,
        DeleteStmt,
        DictCompr,
        DictVal,
        DisconnectOp,
        DisengageStmt,
        EdgeOpRef,
        EdgeRefTrailer,
        Ellipsis,
        ElseIf,
        ElseStmt,
        Enum,
        EnumBlockStmt,
        EventSignature,
        Except,
        Expr,
        ExprAsItem,
        ExprCtx,
        ExprStmt,
        FString,
        FilterCompr,
        FinallyStmt,
        Float,
        ForeverStmt,
        FormattedValue,
        FuncCall,
        FuncSignature,
        GenCompr,
        GlobalVars,
        HasVar,
        IfElseExpr,
        IfStmt,
        ImplDef,
        Import,
        InForStmt,
        IndexSlice,
        InnerCompr,
        Int,
        IterForStmt,
        JsxComment,
        JsxElement,
        JsxElementName,
        JsxExpression,
        JsxNormalAttribute,
        JsxSlot,
        JsxSpreadAttribute,
        JsxText,
        KVPair,
        KWPair,
        LambdaExpr,
        ListCompr,
        ListVal,
        MatchArch,
        MatchAs,
        MatchCase,
        MatchKVPair,
        MatchMapping,
        MatchOr,
        MatchPattern,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchStmt,
        MatchValue,
        MatchWild,
        Module,
        ModuleCode,
        ModuleItem,
        ModulePath,
        MultiString,
        Name,
        NameAtom,
        Null,
        OpenStmt,
        ParamVar,
        PyInlineCode,
        RaiseStmt,
        ReportStmt,
        ReturnStmt,
        SemDef,
        Semi,
        SetCompr,
        SetVal,
        SpecialVarRef,
        String,
        SubTag,
        SwitchStmt,
        Test,
        Token,
        TryStmt,
        TupleVal,
        TypeAlias,
        TypeParam,
        TypedCtxBlock,
        UnaryExpr,
        UniNode,
        UniScopeNode,
        VisitStmt,
        WhileStmt,
        WithStmt,
        YieldExpr,
        is_identifier_slot,
        literal_string_value
    }
    unitree --> jaclang.compiler.c_interop {
        Archetype,
        Assignment,
        AtomTrailer,
        AtomUnit,
        Expr,
        Import,
        UnaryExpr,
        UniNode
    }
    unitree --> jaclang.compiler.c_interop._annotation_name { Name, Null }
    unitree --> jaclang.compiler.c_interop.c_call_borrows_args { FuncCall }
    unitree --> jaclang.compiler.c_interop.is_builtin_pin_call { FuncCall, Name }
    unitree as uni --> jaclang.compiler.driver.boundary_classify;
    unitree --> jaclang.compiler.driver.compilation_context { Module }
    unitree as uni --> jaclang.compiler.driver.compiler;
    unitree --> jaclang.compiler.driver.compiler { ability_of_symbol }
    unitree --> jaclang.compiler.driver.compiler.JacCompiler.resolve_absorb_imports {
        find_python_scope_node_of
    }
    unitree --> jaclang.compiler.driver.context_passes { Module }
    unitree as uni --> jaclang.compiler.driver.ifacecache.IfaceRegistry._client_edges;
    unitree as uni --> jaclang.compiler.driver.na_coverage;
    type unitree --> jaclang.compiler.driver.nativecache { Module }
    type unitree --> jaclang.compiler.driver.pipeline { Module }
    unitree --> jaclang.compiler.driver.pipeline.compile_application {
        Import,
        ModulePath
    }
    unitree as uni --> jaclang.compiler.driver.pipeline_runner;
    unitree as uni --> jaclang.compiler.driver.program;
    unitree as uni --> jaclang.compiler.driver.progstate;
    unitree as uni --> jaclang.compiler.driver.selfhost;
    type unitree --> jaclang.compiler.driver.source_products { Module }
    unitree --> jaclang.compiler.driver.wiring {
        Ability,
        Archetype,
        EmptyToken,
        Enum,
        ImplDef,
        ImplImport,
        Import,
        ImportRule,
        ImportWire,
        Module,
        ModuleItem,
        ModulePath,
        ModulePattern,
        Token,
        UniNode
    }
    unitree --> jaclang.compiler.expr_keys {
        Assignment,
        AtomTrailer,
        AtomUnit,
        BinaryExpr,
        BoolExpr,
        CfgExpr,
        CompareExpr,
        Expr,
        FuncCall,
        InForStmt,
        IndexSlice,
        Int,
        KWPair,
        ListVal,
        MultiString,
        Name,
        String,
        Token,
        TupleVal,
        UnaryExpr,
        UniNode
    }
    unitree --> jaclang.compiler.expr_keys.is_builtin_region_type { Archetype }
    unitree --> jaclang.compiler.expr_keys.type_tag_borrows { SubTag, UnaryExpr }
    unitree --> jaclang.compiler.field_semantics {
        AstSymbolNode,
        Bool,
        Expr,
        FuncCall,
        HasVar,
        KWPair,
        Module,
        ModuleItem,
        Name
    }
    type unitree --> jaclang.compiler.frontend.codeinfo { CommentToken, Source, Token }
    unitree --> jaclang.compiler.frontend.const_fold {
        AtomUnit,
        BinaryExpr,
        Bool,
        Float,
        Int,
        MultiString,
        String,
        UnaryExpr,
        UniNode
    }
    type unitree --> jaclang.compiler.frontend.helpers { Expr }
    unitree as uni --> jaclang.compiler.frontend.helpers._extract_version_tuple;
    unitree as uni --> jaclang.compiler.frontend.helpers._is_type_checking_ref;
    unitree as uni --> jaclang.compiler.frontend.helpers._is_version_info_access;
    unitree as uni --> jaclang.compiler.frontend.helpers.evaluate_version_condition;
    unitree --> jaclang.compiler.frontend.module_facts {
        Ability,
        Archetype,
        Assignment,
        AtomTrailer,
        ConcurrentExpr,
        ContextAwareNode,
        ElementStmt,
        Enum,
        FuncCall,
        GlobalVars,
        ImplDef,
        Import,
        LambdaExpr,
        ListVal,
        Module,
        ModuleCode,
        ModuleItem,
        Name,
        TupleVal,
        UniNode,
        YieldExpr,
        literal_string_value
    }
    unitree --> jaclang.compiler.frontend.parser.frontend {
        CommentToken,
        Expr,
        Module,
        Source
    }
    unitree --> jaclang.compiler.frontend.parser.parser {
        Ability,
        ArchHas,
        Archetype,
        AssertStmt,
        AssignCompr,
        Assignment,
        AstDocNode,
        AtomTrailer,
        AtomUnit,
        AwaitExpr,
        AwaitingClause,
        BinaryExpr,
        Bool,
        BoolExpr,
        BuiltinType,
        CastExpr,
        CfgExpr,
        CodeBlockStmt,
        CompareExpr,
        ConcurrentExpr,
        ConnectOp,
        ContextAwareNode,
        CtrlStmt,
        DeleteStmt,
        DictCompr,
        DictVal,
        DisconnectOp,
        DisengageStmt,
        EdgeOpRef,
        EdgeRefTrailer,
        ElementStmt,
        Ellipsis as EllipsisLit,
        ElseIf,
        ElseStmt,
        EmptyToken,
        Enum,
        EventSignature,
        Except,
        Expr,
        ExprAsItem,
        ExprStmt,
        FString,
        FilterCompr,
        FinallyStmt,
        Float,
        ForeverStmt,
        FormattedValue,
        FuncCall,
        FuncSignature,
        GenCompr,
        GlobalVars,
        GraphExpr,
        HasVar,
        IfElseExpr,
        IfStmt,
        ImplDef,
        ImplImport,
        Import,
        ImportRule,
        ImportWire,
        InForStmt,
        IndexSlice,
        InnerCompr,
        Int,
        IterForStmt,
        JsxAttribute,
        JsxChild,
        JsxComment,
        JsxElement,
        JsxElementName,
        JsxExpression,
        JsxNormalAttribute,
        JsxSlot,
        JsxSpreadAttribute,
        JsxText,
        KVPair,
        KWPair,
        LambdaExpr,
        ListCompr,
        ListVal,
        MatchArch,
        MatchAs,
        MatchCase,
        MatchKVPair,
        MatchMapping,
        MatchOr,
        MatchPattern,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchStmt,
        MatchValue,
        MatchWild,
        Module,
        ModuleCode,
        ModuleItem,
        ModulePath,
        ModulePattern,
        MultiString,
        Name,
        NameAtom,
        Null,
        OpenStmt,
        ParamVar,
        PyInlineCode,
        RaiseStmt,
        ReportStmt,
        ReturnStmt,
        SemDef,
        Semi,
        SetCompr,
        SetVal,
        Slice,
        Source,
        SpecialVarRef,
        String,
        SubTag,
        SwitchCase,
        SwitchStmt,
        Test,
        Token,
        TryStmt,
        TupleVal,
        TypeAlias,
        TypeParam,
        TypedCtxBlock,
        UnaryExpr,
        UniNode,
        VisitStmt,
        WhileStmt,
        WireItem,
        WithStmt,
        YieldExpr
    }
    type unitree --> jaclang.compiler.frontend.relations {
        Ability,
        AstTypedVarNode,
        ConditionalNode,
        ContextAwareNode,
        Expr,
        FuncCall,
        Import,
        Module,
        NameAtom,
        Symbol,
        UniCFGNode,
        UniScopeNode
    }
    type unitree --> jaclang.compiler.frontend.roles {
        Ability,
        ArchHas,
        Archetype,
        AssertStmt,
        AssignCompr,
        Assignment,
        AstAccessNode,
        AstDocNode,
        AstElseBodyNode,
        AstTypedVarNode,
        AtomTrailer,
        AwaitingClause,
        CastExpr,
        CfgExpr,
        CompareExpr,
        ConcurrentExpr,
        ConnectOp,
        CtrlStmt,
        DictCompr,
        DictVal,
        DisconnectOp,
        EdgeOpRef,
        EdgeRefTrailer,
        ElseIf,
        ElseStmt,
        Enum,
        EventSignature,
        Except,
        Expr,
        ExprAsItem,
        FString,
        FilterCompr,
        FinallyStmt,
        FormattedValue,
        FuncSignature,
        GlobalVars,
        HasVar,
        IfElseExpr,
        ImplDef,
        ImplImport,
        Import,
        ImportRule,
        ImportWire,
        IndexSlice,
        InnerCompr,
        IterForStmt,
        JsxAttribute,
        JsxChild,
        JsxElement,
        JsxElementName,
        KVPair,
        KWPair,
        ListCompr,
        MatchArch,
        MatchCase,
        MatchKVPair,
        MatchOr,
        MatchPattern,
        Module,
        ModuleItem,
        ModulePath,
        ModulePattern,
        MultiString,
        Name,
        NameAtom,
        ParamVar,
        ProgramModule,
        PyInlineCode,
        RaiseStmt,
        Slice,
        String,
        SubTag,
        SwitchCase,
        Test,
        Token,
        TryStmt,
        TypeParam,
        TypedCtxBlock,
        UnaryExpr,
        UniNode,
        VisitStmt,
        WireItem
    }
    type unitree --> jaclang.compiler.frontend.srcloc { Source, Token }
    unitree --> jaclang.compiler.jc_unit { GraphExpr, Import, Module, UniNode }
    unitree --> jaclang.compiler.passes.access_check_pass {
        Archetype,
        AstSymbolNode,
        AtomTrailer,
        Import,
        Module,
        ModuleItem,
        ModulePath,
        Name,
        Symbol,
        UniNode
    }
    unitree --> jaclang.compiler.passes.annex_weave { Module }
    unitree --> jaclang.compiler.passes.ast_validation_pass {
        Ability,
        ArchHas,
        Archetype,
        Assignment,
        AtomTrailer,
        AtomUnit,
        BinaryExpr,
        ContextAwareNode,
        CtrlStmt,
        DeleteStmt,
        ElseStmt,
        Enum,
        ExprAsItem,
        ExprStmt,
        FString,
        ForeverStmt,
        FuncCall,
        FuncSignature,
        GlobalVars,
        HasVar,
        IfStmt,
        ImplDef,
        Import,
        InForStmt,
        InnerCompr,
        IterForStmt,
        JsxElement,
        JsxNormalAttribute,
        JsxSlot,
        KWPair,
        LambdaExpr,
        ListVal,
        Literal,
        MatchStmt,
        Module,
        ModuleCode,
        MultiString,
        Name,
        ParamVar,
        ReturnStmt,
        SpecialVarRef,
        SwitchStmt,
        Token,
        TreeWalker,
        TryStmt,
        TupleVal,
        UnaryExpr,
        UniNode,
        WhileStmt,
        WithStmt,
        YieldExpr
    }
    unitree --> jaclang.compiler.passes.boundary_analysis_pass {
        Ability,
        ArchHas,
        Archetype,
        Assignment,
        AstSymbolNode,
        AtomTrailer,
        BinaryExpr,
        Bool,
        BuiltinType,
        DictVal,
        Enum,
        Float,
        FuncCall,
        FuncSignature,
        HasVar,
        Import,
        IndexSlice,
        Int,
        KVPair,
        LambdaExpr,
        ListVal,
        Module,
        ModuleItem,
        ModulePath,
        MultiString,
        Name,
        NameAtom,
        Null,
        ParamVar,
        Slice,
        String,
        Token,
        TreeWalker,
        TupleVal,
        UnaryExpr,
        UniNode,
        ability_of_symbol,
        resolved_decl_of
    }
    unitree --> jaclang.compiler.passes.capability_check_pass {
        Ability,
        ArchSpec,
        Archetype,
        Assignment,
        AtomTrailer,
        CtrlStmt,
        EdgeOpRef,
        EdgeRefTrailer,
        ElementStmt,
        Enum,
        EventSignature,
        Expr,
        FString,
        FilterCompr,
        FormattedValue,
        FuncCall,
        FuncSignature,
        ImplDef,
        ImplImport,
        Import,
        KWPair,
        LambdaExpr,
        ListVal,
        Module,
        ModuleItem,
        ModulePath,
        MultiString,
        Name,
        ParamVar,
        PyInlineCode,
        String,
        Token,
        TupleVal,
        UnaryExpr,
        UniNode,
        YieldExpr,
        in_type_position
    }
    unitree --> jaclang.compiler.passes.cfg_build_pass {
        Ability,
        Archetype,
        AssertStmt,
        AstElseBodyNode,
        AtomUnit,
        AwaitingClause,
        BoolExpr,
        CfgExpr,
        CodeBlockStmt,
        CtrlStmt,
        DictCompr,
        DisengageStmt,
        ElseIf,
        ElseStmt,
        Except,
        Expr,
        FinallyStmt,
        ForeverStmt,
        GenCompr,
        GlobalVars,
        IfElseExpr,
        IfStmt,
        ImplDef,
        InForStmt,
        InnerCompr,
        IterForStmt,
        JsxSlot,
        LambdaExpr,
        ListCompr,
        MatchCase,
        MatchStmt,
        Module,
        ModuleCode,
        Name,
        OpenStmt,
        RaiseStmt,
        ReturnStmt,
        SemDef,
        Semi,
        SetCompr,
        SwitchCase,
        SwitchStmt,
        Test,
        Token,
        TreeWalker,
        TryStmt,
        TypeAlias,
        TypedCtxBlock,
        UniCFGNode,
        UniNode,
        WhileStmt,
        WithStmt
    }
    unitree --> jaclang.compiler.passes.comptime_resolve_pass {
        Ability,
        AssertStmt,
        Assignment,
        GlobalVars,
        IfStmt,
        Import,
        InForStmt,
        ParamVar,
        TypeParam,
        UniNode
    }
    unitree --> jaclang.compiler.passes.context { Source, UniNode }
    unitree --> jaclang.compiler.passes.dataflow { UniCFGNode }
    unitree --> jaclang.compiler.passes.decl_impl_match_pass {
        Ability,
        Archetype,
        Assignment,
        AstImplNeedingNode,
        AstSymbolNode,
        AtomTrailer,
        FuncSignature,
        HasVar,
        ImplDef,
        Import,
        Module,
        Name,
        NameAtom,
        ParamVar,
        SpecialVarRef,
        Symbol,
        UniNode,
        UniScopeNode,
        bind_assignment_targets,
        find_python_scope_node_of,
        is_identifier_slot
    }
    unitree --> jaclang.compiler.passes.endpoint_effect_pass {
        Ability,
        Archetype,
        Assignment,
        AstSymbolNode,
        AtomTrailer,
        BinaryExpr,
        BoolExpr,
        ConnectOp,
        DeleteStmt,
        DisconnectOp,
        EventSignature,
        FuncCall,
        ImplDef,
        KWPair,
        Module,
        Name,
        SpecialVarRef,
        Symbol,
        Token,
        TreeWalker,
        UniNode,
        ability_of_symbol
    }
    unitree --> jaclang.compiler.passes.execution { UniNode }
    unitree as uni --> jaclang.compiler.passes.freeze_structure_pass;
    unitree as uni --> jaclang.compiler.passes.graph_lowering_pass;
    unitree --> jaclang.compiler.passes.graph_lowering_pass { TreeWalker }
    unitree --> jaclang.compiler.passes.import_wiring_pass {
        Ability,
        EmptyToken,
        ImplDef,
        ImplImport,
        Import,
        ImportRule,
        ImportWire,
        Module,
        ModuleItem,
        ModulePath,
        ModulePattern,
        String,
        UniNode
    }
    unitree --> jaclang.compiler.passes.jsx_intrinsic_guard_pass {
        JsxElement,
        Module,
        Name,
        Token,
        TreeWalker,
        UniNode
    }
    unitree --> jaclang.compiler.passes.layout_pass {
        Ability,
        ArchHas,
        Archetype,
        Assignment,
        AstSymbolNode,
        AstTypedVarNode,
        AtomTrailer,
        BinaryExpr,
        BuiltinType,
        Enum,
        Expr,
        FuncCall,
        FuncSignature,
        HasVar,
        Import,
        IndexSlice,
        Module,
        ModuleItem,
        Name,
        Null,
        TupleVal,
        TypeParam,
        UnaryExpr,
        UniNode
    }
    unitree --> jaclang.compiler.passes.mtir_gen_pass {
        Ability,
        Archetype,
        Assignment,
        AstSymbolNode,
        AtomTrailer,
        BinaryExpr,
        Bool,
        BuiltinType,
        EdgeOpRef,
        EdgeRefTrailer,
        Enum,
        EventSignature,
        Expr,
        FilterCompr,
        Float,
        FuncCall,
        FuncSignature,
        Int,
        KWPair,
        ListVal,
        Module,
        MultiString,
        Name,
        NameAtom,
        String,
        Symbol,
        Token,
        TupleVal,
        UniNode,
        UniScopeNode,
        VisitStmt
    }
    unitree as uni --> jaclang.compiler.passes.osp_analysis;
    unitree --> jaclang.compiler.passes.ownership_check_pass {
        Ability,
        Archetype,
        Assignment,
        AstElseBodyNode,
        AtomTrailer,
        BinaryExpr,
        CfgExpr,
        ConcurrentExpr,
        ConnectOp,
        CtrlStmt,
        DeleteStmt,
        DictVal,
        DisengageStmt,
        Enum as UniEnum,
        Except,
        Expr,
        FString,
        FinallyStmt,
        FuncCall,
        FuncSignature,
        GlobalVars,
        HasVar,
        IfElseExpr,
        ImplDef,
        Import,
        InForStmt,
        IndexSlice,
        Int,
        IterForStmt,
        KWPair,
        LambdaExpr,
        ListVal,
        Module,
        ModuleCode,
        MultiString,
        Name,
        Null,
        OpenStmt,
        ParamVar,
        RaiseStmt,
        ReturnStmt,
        SetVal,
        Slice,
        String,
        SubTag,
        Token,
        TryStmt,
        TupleVal,
        UnaryExpr,
        UniCFGNode,
        UniNode,
        UniScopeNode,
        WhileStmt,
        YieldExpr
    }
    unitree --> jaclang.compiler.passes.ownership_hints {
        Ability,
        Assignment,
        FuncSignature,
        Module,
        Name
    }
    unitree --> jaclang.compiler.passes.pyast_load_pass {
        Ability,
        ArchBlockStmt,
        Archetype,
        AssertStmt,
        Assignment,
        AtomExpr,
        AtomTrailer,
        AtomUnit,
        AwaitExpr,
        BinaryExpr,
        Bool,
        BoolExpr,
        CfgExpr,
        CodeBlockStmt,
        CompareExpr,
        CtrlStmt,
        DeleteStmt,
        DictCompr,
        DictVal,
        ElementStmt,
        Ellipsis as UniEllipsis,
        ElseIf,
        ElseStmt,
        EmptyToken,
        Enum,
        Except,
        Expr,
        ExprAsItem,
        ExprStmt,
        FString,
        FinallyStmt,
        Float,
        FormattedValue,
        FuncCall,
        FuncSignature,
        GenCompr,
        IfElseExpr,
        IfStmt,
        Import,
        InForStmt,
        IndexSlice,
        InnerCompr,
        Int,
        KVPair,
        KWPair,
        LambdaExpr,
        ListCompr,
        ListVal,
        Literal,
        MatchArch,
        MatchAs,
        MatchCase,
        MatchKVPair,
        MatchMapping,
        MatchOr,
        MatchPattern,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchStmt,
        MatchValue,
        MatchWild,
        Module,
        ModuleCode,
        ModuleItem,
        ModulePath,
        MultiString,
        Name,
        NameAtom,
        Null,
        ParamKind,
        ParamVar,
        PythonModuleAst,
        RaiseStmt,
        ReturnStmt,
        Semi,
        SetCompr,
        SetVal,
        Slice,
        Source,
        SpecialVarRef,
        String,
        SubTag,
        Token,
        TryStmt,
        TupleVal,
        UnaryExpr,
        UniNode,
        WhileStmt,
        WithStmt,
        YieldExpr
    }
    unitree --> jaclang.compiler.passes.rc_facts_pass {
        Ability,
        Assignment,
        AtomTrailer,
        BinaryExpr,
        BoolExpr,
        CompareExpr,
        ConnectOp,
        DictCompr,
        DictVal,
        Expr,
        FString,
        FuncCall,
        FuncSignature,
        IfElseExpr,
        IfStmt,
        ImplDef,
        InForStmt,
        IterForStmt,
        KWPair,
        LambdaExpr,
        ListCompr,
        ListVal,
        Module,
        ModuleCode,
        MultiString,
        Name,
        NameAtom,
        ParamVar,
        ReturnStmt,
        SetVal,
        String,
        Symbol,
        Test,
        Token,
        UnaryExpr,
        UniCFGNode,
        UniNode,
        WhileStmt,
        same_lexical_scope
    }
    unitree --> jaclang.compiler.passes.region_infer_pass {
        Ability,
        Archetype,
        Assignment,
        AtomTrailer,
        BinaryExpr,
        CodeBlockStmt,
        ConnectOp,
        CtrlStmt,
        ExprStmt,
        FuncCall,
        FuncSignature,
        ImplDef,
        KWPair,
        Module,
        ModuleCode,
        Name,
        NameAtom,
        OpenStmt,
        RaiseStmt,
        ReturnStmt,
        Symbol,
        Test,
        Token,
        UniNode,
        YieldExpr
    }
    unitree --> jaclang.compiler.passes.scope_walk { UniScopeNode }
    unitree --> jaclang.compiler.passes.sem_def_match_pass {
        Module,
        SemDef,
        Symbol,
        UniScopeNode
    }
    unitree --> jaclang.compiler.passes.semantic_analysis_pass {
        Ability,
        ArchHas,
        Archetype,
        Assignment,
        AstSymbolNode,
        AtomExpr,
        AtomTrailer,
        DisengageStmt,
        EdgeOpRef,
        EventSignature,
        ExprAsItem,
        FuncSignature,
        HasVar,
        ImplDef,
        InForStmt,
        InnerCompr,
        Module,
        Name,
        ParamVar,
        SpecialVarRef,
        TreeWalker,
        TypedCtxBlock,
        UniNode,
        VisitStmt
    }
    unitree --> jaclang.compiler.passes.static_analysis_pass {
        Ability,
        Archetype,
        Assignment,
        AtomTrailer,
        AwaitExpr,
        BinaryExpr,
        Bool,
        CompareExpr,
        ConnectOp,
        CtrlStmt,
        DisconnectOp,
        DisengageStmt,
        EdgeOpRef,
        ElseIf,
        ElseStmt,
        EventSignature,
        FString,
        FilterCompr,
        FinallyStmt,
        Float,
        ForeverStmt,
        FormattedValue,
        IfStmt,
        ImplDef,
        ImplImport,
        Import,
        InForStmt,
        Int,
        IterForStmt,
        KWPair,
        LambdaExpr,
        MatchPattern,
        Module,
        ModuleItem,
        ModulePath,
        Name,
        Null,
        RaiseStmt,
        ReturnStmt,
        Semi,
        Test,
        Token,
        UniNode,
        UniScopeNode,
        WhileStmt,
        in_type_position
    }
    unitree --> jaclang.compiler.passes.sym_tab_build_pass {
        Ability,
        ArchHas,
        Archetype,
        Assignment,
        AstSymbolNode,
        AtomTrailer,
        BinaryExpr,
        DictCompr,
        ElseIf,
        ElseStmt,
        Enum,
        Except,
        ExprAsItem,
        FinallyStmt,
        ForeverStmt,
        GenCompr,
        GlobalVars,
        HasVar,
        IfStmt,
        ImplDef,
        Import,
        InForStmt,
        InnerCompr,
        IterForStmt,
        LambdaExpr,
        ListCompr,
        MatchCase,
        Module,
        ModuleItem,
        ModulePath,
        Name,
        OpenStmt,
        ParamVar,
        SemDef,
        SetCompr,
        SwitchCase,
        Symbol,
        Test,
        Token,
        TreeWalker,
        TryStmt,
        TypeAlias,
        TypeParam,
        TypedCtxBlock,
        UniNode,
        UniScopeNode,
        WhileStmt,
        WithStmt,
        bind_assignment_targets,
        def_insert_unpacking,
        find_python_scope_node_of,
        rebind_or_def_insert,
        record_cross_scope_rebind
    }
    unitree --> jaclang.compiler.passes.type_checker_pass {
        Ability,
        ArchHas,
        Archetype,
        AssertStmt,
        Assignment,
        AstSymbolNode,
        AtomTrailer,
        BinaryExpr,
        BuiltinType,
        CodeBlockStmt,
        CompareExpr,
        DeleteStmt,
        EdgeRefTrailer,
        ElseIf,
        Enum,
        EventSignature,
        Except,
        Expr,
        ExprAsItem,
        FString,
        FilterCompr,
        FormattedValue,
        FuncCall,
        FuncSignature,
        GenCompr,
        HasVar,
        IfStmt,
        ImplDef,
        Import,
        ImportRule,
        InForStmt,
        IndexSlice,
        JsxElement,
        JsxElementName,
        KWPair,
        LambdaExpr,
        ListVal,
        Literal,
        MatchAs,
        Module,
        ModuleCode,
        ModuleItem,
        ModulePath,
        MultiString,
        Name,
        Null,
        ParamVar,
        RaiseStmt,
        ReportStmt,
        ReturnStmt,
        Slice,
        SpecialVarRef,
        SubTag,
        Symbol,
        Token,
        TreeWalker,
        TupleVal,
        TypeAlias,
        UnaryExpr,
        UniNode,
        VisitStmt,
        WhileStmt,
        WireItem,
        WithStmt,
        YieldExpr,
        find_python_scope_node_of,
        in_type_position,
        type_only_import_of
    }
    unitree --> jaclang.compiler.passes.variant_agreement_pass {
        Ability,
        Archetype,
        Enum,
        FuncSignature,
        GlobalVars,
        HasVar,
        Module,
        Name,
        UniNode
    }
    unitree --> jaclang.compiler.passes.wasm_contract {
        Ability,
        FuncSignature,
        UnaryExpr
    }
    unitree --> jaclang.compiler.passes.wasm_contract.check_host_call {
        Module,
        Name,
        ability_of_symbol
    }
    unitree --> jaclang.compiler.passes.wasm_contract.host_contracts { Import }
    unitree as uni --> jaclang.compiler.placement.placement;
    unitree as uni --> jaclang.compiler.placement.placement_facts;
    unitree as uni --> jaclang.compiler.placement.placement_solver;
    unitree as uni --> jaclang.compiler.placement.placement_work;
    unitree --> jaclang.compiler.symbol_utils {
        Ability,
        Archetype,
        Assignment,
        AstSymbolNode,
        AtomTrailer,
        BinaryExpr,
        ContextAwareNode,
        ElementStmt,
        Enum as UniEnum,
        Expr,
        FuncCall,
        GlobalVars,
        HasVar,
        Import,
        KWPair,
        Module,
        ModuleItem,
        ModulePath,
        Name,
        NameAtom,
        ParamVar,
        Symbol,
        Token,
        UniNode,
        UniScopeNode,
        ability_of_symbol,
        in_type_position
    }
    unitree --> jaclang.compiler.tests.test_client_codegen_facts { Module }
    unitree --> jaclang.compiler.tests.test_jac_mobui_typing {
        Import,
        ModuleItem,
        Name
    }
    unitree --> jaclang.compiler.tests.test_module_exports {
        Module,
        PythonModuleAst,
        Source
    }
    unitree --> jaclang.compiler.tests.test_pipeline_products { Module }
    unitree --> jaclang.compiler.tests.test_test_block_analysis {
        FuncCall,
        Module,
        Name,
        Test
    }
    unitree as uni --> jaclang.compiler.tools.code_intel;
    unitree as uni --> jaclang.compiler.tools.comment_attach_pass;
    type unitree as uni --> jaclang.compiler.tools.doc_ir;
    unitree as uni --> jaclang.compiler.tools.doc_ir_gen_pass;
    unitree --> jaclang.compiler.tools.doc_ir_gen_pass { TreeWalker }
    unitree as uni --> jaclang.compiler.tools.grammar_extract_pass;
    unitree --> jaclang.compiler.tools.grammar_extract_pass { TreeWalker }
    unitree as uni --> jaclang.compiler.tools.jac_auto_lint_pass;
    unitree --> jaclang.compiler.tools.jac_auto_lint_pass { TreeWalker }
    unitree as uni --> jaclang.compiler.tools.jac_formatter_pass;
    unitree as uni --> jaclang.compiler.tools.lang_tools;
    unitree --> jaclang.compiler.tools.lang_tools { UniScopeNode }
    unitree as uni --> jaclang.compiler.tools.normalize_pass;
    unitree --> jaclang.compiler.tools.normalize_pass {
        EmptyToken,
        Tok,
        Token,
        TreeWalker
    }
    unitree as uni --> jaclang.compiler.tools.reactive_use_walk;
    unitree as uni --> jaclang.compiler.tools.treeprinter;
    type unitree --> jaclang.compiler.tools.treeprinter { UniNode, UniScopeNode }
    unitree --> jaclang.compiler.tools.treeprinter.print_ast_tree {
        AstSymbolNode,
        Token
    }
    unitree as uni --> jaclang.compiler.tools.unparse_pass;
    unitree --> jaclang.compiler.tools.unparse_pass { TreeWalker }
    unitree --> jaclang.compiler.types.builtin_extensions { Name, Source }
    unitree --> jaclang.compiler.types.ct_eval {
        Ability,
        Archetype,
        AssertStmt,
        Assignment,
        AtomTrailer,
        AtomUnit,
        BinaryExpr,
        Bool,
        BoolExpr,
        BuiltinType,
        CastExpr,
        CfgExpr,
        CompareExpr,
        CtrlStmt,
        DictCompr,
        DictVal,
        ElseIf,
        ElseStmt,
        Enum,
        Expr,
        ExprStmt,
        FString,
        Float,
        FormattedValue,
        FuncCall,
        FuncSignature,
        GlobalVars,
        HasVar,
        IfElseExpr,
        IfStmt,
        ImplDef,
        Import,
        InForStmt,
        IndexSlice,
        InnerCompr,
        Int,
        KVPair,
        KWPair,
        ListCompr,
        ListVal,
        Module,
        ModuleItem,
        ModulePath,
        MultiString,
        Name,
        Null,
        ParamVar,
        RaiseStmt,
        ReturnStmt,
        Semi,
        SetCompr,
        SetVal,
        Slice,
        SpecialVarRef,
        String,
        Symbol,
        Token,
        TryStmt,
        TupleVal,
        TypeParam,
        UnaryExpr,
        UniNode,
        WhileStmt
    }
    type unitree --> jaclang.compiler.types.ct_value { Ability }
    unitree --> jaclang.compiler.types.enum_utils {
        Ability,
        Archetype,
        Assignment,
        Enum,
        Int,
        Name,
        NameAtom,
        String,
        UniNode
    }
    unitree --> jaclang.compiler.types.fixed_width {
        AtomUnit,
        Expr,
        Float,
        FuncCall,
        Int,
        Name,
        Token,
        UnaryExpr,
        UniNode
    }
    unitree --> jaclang.compiler.types.operations {
        AtomTrailer,
        BinaryExpr,
        ConnectOp,
        DisconnectOp,
        Expr,
        FuncCall,
        KWPair,
        Name,
        Token,
        TupleVal,
        UniNode
    }
    unitree --> jaclang.compiler.types.ownership { Archetype, HasVar }
    unitree --> jaclang.compiler.types.stubcat.modiface { Module }
    unitree --> jaclang.compiler.types.stubcat.reader {
        Ability,
        HasVar,
        Module,
        Name,
        Source,
        Symbol,
        SymbolProvider,
        Token,
        UniNode,
        UniScopeNode
    }
    unitree --> jaclang.compiler.types.stubcat.writer {
        Ability,
        Archetype,
        Assignment,
        AtomTrailer,
        DictCompr,
        ElseIf,
        ElseStmt,
        Enum,
        FuncSignature,
        HasVar,
        IfStmt,
        Import,
        InnerCompr,
        KWPair,
        ListCompr,
        Module,
        ModulePath,
        Name,
        ParamVar,
        Symbol,
        UniScopeNode
    }
    unitree --> jaclang.compiler.types.type_evaluator {
        Ability,
        Archetype,
        AssertStmt,
        AssignCompr,
        Assignment,
        AtomTrailer,
        AtomUnit,
        AwaitExpr,
        BinaryExpr,
        Bool,
        BoolExpr,
        BuiltinType,
        CastExpr,
        CfgExpr,
        CodeBlockStmt,
        CompareExpr,
        ConcurrentExpr,
        CtrlStmt,
        DictCompr,
        DictVal,
        EdgeOpRef,
        EdgeRefTrailer,
        Ellipsis,
        ElseIf,
        ElseStmt,
        Enum,
        EventSignature,
        Except,
        Expr,
        ExprAsItem,
        ExprStmt,
        FString,
        FilterCompr,
        Float,
        ForeverStmt,
        FormattedValue,
        FuncCall,
        FuncSignature,
        GenCompr,
        HasVar,
        IfElseExpr,
        IfStmt,
        ImplDef,
        Import,
        InForStmt,
        IndexSlice,
        InnerCompr,
        Int,
        IterForStmt,
        JsxComment,
        JsxElement,
        JsxElementName,
        JsxExpression,
        JsxNormalAttribute,
        JsxSpreadAttribute,
        JsxText,
        KVPair,
        KWPair,
        LambdaExpr,
        ListCompr,
        ListVal,
        MatchArch,
        MatchAs,
        MatchCase,
        MatchOr,
        MatchPattern,
        MatchStmt,
        MatchWild,
        Module,
        ModuleItem,
        ModulePath,
        MultiString,
        Name,
        NameAtom,
        Null,
        OpenStmt,
        ParamKind as UniParamKind,
        ParamVar,
        RaiseStmt,
        ReturnStmt,
        Semi,
        SetCompr,
        SetVal,
        Source,
        SpecialVarRef,
        String,
        SubTag,
        SwitchCase,
        SwitchStmt,
        Symbol,
        Token,
        TryStmt,
        TupleVal,
        TypeAlias,
        TypeParam,
        UnaryExpr,
        UniCFGNode,
        UniNode,
        UniScopeNode,
        WhileStmt,
        WithStmt,
        YieldExpr,
        is_client_destined,
        kind_has_runtime_binding,
        literal_string_value,
        resolved_decl_of
    }
    unitree --> jaclang.compiler.types.type_evaluator.TypeEvaluator._container_value_type {
        in_type_position
    }
    unitree --> jaclang.compiler.types.type_evaluator.TypeEvaluator._get_type_of_expression_core {
        in_type_position
    }
    unitree --> jaclang.compiler.types.type_evaluator.TypeEvaluator._heal_class_bases {
        Archetype
    }
    unitree --> jaclang.compiler.types.type_evaluator.TypeEvaluator._published_class_type {
        Archetype
    }
    unitree --> jaclang.compiler.types.type_evaluator.TypeEvaluator._resolve_string_type_expr {
        SubTag
    }
    unitree --> jaclang.compiler.types.type_utils {
        Ability,
        Archetype,
        AtomTrailer,
        ElseIf,
        ElseStmt,
        Expr,
        HasVar,
        IfStmt,
        ImplDef,
        Import,
        KWPair,
        Module,
        ModuleItem,
        ModulePath,
        Name,
        Symbol,
        UnaryExpr,
        UniNode,
        UniScopeNode
    }
    unitree --> jaclang.compiler.types.type_utils.expr_primitive_name { CfgExpr }
    type unitree --> jaclang.compiler.types.types {
        Expr,
        Symbol,
        UniScopeNode as SymbolTable
    }
    unitree --> jaclang.compiler.types.types.ClassType.get_class_symbol { Archetype }
    unitree --> jaclang.compiler.types.types.ClassType.lookup_member_symbol {
        Ability,
        Archetype,
        Assignment,
        AtomTrailer,
        FuncSignature,
        ParamVar
    }
    unitree --> jaclang.compiler.types.types._class_scope_category { Archetype }
    type unitree --> jaclang.dist.native_product { Module }
    unitree --> jaclang.dist.publish.dts {
        Ability,
        Archetype,
        AstTypedVarNode,
        FuncSignature,
        GlobalVars,
        Module,
        UniNode
    }
    unitree --> jaclang.dist.publish.jsdoc {
        Ability,
        FuncSignature,
        Module,
        ParamVar,
        UniNode
    }
    unitree as uni --> jaclang.lsp.server.engine;
    unitree --> jaclang.lsp.server.engine { UniScopeNode }
    unitree --> jaclang.lsp.server.engine.JacLangServer.type_check_file {
        Source as _Src
    }
    unitree as uni --> jaclang.lsp.server.module_manager;
    unitree as uni --> jaclang.lsp.server.sem_manager;
    unitree as uni --> jaclang.lsp.server.utils;
    unitree --> jaclang.lsp.server.utils { Symbol, UniScopeNode }
    codeinfo --> jaclang.compiler.driver.wiring.WiringSpec.import_provider {
        is_bundled_native_module
    }
    codeinfo --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._nogc_resolve_provenance {
        NOGC_NATIVE_STDLIB,
        bundled_stdlib_module_of,
        is_in_jaclang_package
    }
}

impl import jaclang.compiler.frontend.parser {
    frontend --> jaclang.cli.commands.analysis._check_file_job {
        _replay_diags,
        parse_diags
    }
    frontend --> jaclang.cli.commands.arch._parse_imports { parse_woven }
    frontend --> jaclang.compiler.driver.compilation_context.SourceStore.parse {
        parse_woven
    }
    frontend --> jaclang.compiler.driver.compiler.JacCompiler.parse_str {
        annex_sources,
        parse_woven
    }
    frontend --> jaclang.compiler.driver.wiring.WiringSpec.__post_init__ { parse_woven }
    frontend --> jaclang.compiler.passes.variant_agreement_pass.VariantAgreementPass._parse_sibling {
        parse
    }
    frontend --> jaclang.compiler.tests.test_module_exports { parse }
    frontend --> jaclang.lsp.server.engine.JacLangServer.type_check_file {
        _replay_diags,
        parse_diags
    }
    lexer --> jaclang.cli.commands.analysis._check_file_job { Lexer }
    lexer --> jaclang.cli.commands.fix._strip_markers { tokenize }
    lexer as na_lexer --> jaclang.compiler.frontend.parser.frontend;
    lexer --> jaclang.compiler.frontend.parser.frontend { Lexer }
    lexer --> jaclang.compiler.frontend.parser.parser { tokenize_full }
    lexer --> jaclang.lsp.server.engine { tokenize_full }
    lexer --> jaclang.lsp.server.engine.JacLangServer.type_check_file {
        Lexer as _Lexer
    }
    parser --> jaclang.cli.commands.analysis._check_file_job { Parser as _SyntaxParser }
    parser --> jaclang.compiler.frontend.parser.frontend {
        Parser,
        parse_expression as _parse_expression
    }
    parser --> jaclang.compiler.jc_unit { parse_program }
    parser --> jaclang.compiler.types.type_evaluator.TypeEvaluator._resolve_string_type_expr {
        parse_expression
    }
    parser --> jaclang.lsp.server.engine.JacLangServer.type_check_file {
        Parser as _SyntaxParser
    }
    tokens --> jaclang.cli.commands.fix { LexToken }
    tokens --> jaclang.compiler.frontend.parser.frontend { CommentData, SrcDiag }
    tokens --> jaclang.compiler.frontend.parser.lexer {
        CommentData,
        LexToken,
        SourceLoc,
        SrcDiag,
        TokenKind,
        is_special_var_kind,
        lookup_keyword
    }
    tokens --> jaclang.compiler.frontend.parser.parser {
        CommentData,
        LexToken,
        SourceLoc,
        SrcDiag,
        TokenKind,
        is_builtin_type_kind,
        is_reserved_kind,
        is_special_var_kind
    }
    tokens --> jaclang.compiler.jc_unit { CommentData, SrcDiag }
    type tokens --> jaclang.compiler.native_compiler { CommentData, SrcDiag }
    tokens --> jaclang.compiler.tools.grammar_extract_pass {
        BUILTIN_TYPE_KINDS,
        TokenKind
    }
    tokens --> jaclang.compiler.tools.jac_auto_lint_pass { KEYWORDS }
    tokens --> jaclang.lsp.server.engine { TokenKind }
    frontend --> jaclang.compiler.placement.placement_solver._native_dep_scan {
        annex_sources,
        parse_woven
    }
}

impl import jaclang.compiler.frontend.python {
    annotation_unparse --> jaclang.compiler.backends.py.jacpython.product_compile {
        stringify_future_annotations
    }
    ast_input --> jaclang.compiler.backends.py.jacpython.native_api { read_node }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.codegen_util {
        Add,
        And,
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BitAnd,
        BitOr,
        BitXor,
        BoolOp,
        Break,
        Call,
        ClassDef,
        Compare,
        Constant,
        Continue,
        Delete,
        Dict,
        DictComp,
        Div,
        Eq,
        ExceptHandler,
        Expr,
        FloorDiv,
        For,
        FormattedValue,
        FunctionDef,
        GeneratorExp,
        Global,
        Gt,
        GtE,
        If,
        IfExp,
        Import,
        ImportFrom,
        Interpolation,
        Invert,
        JoinedStr,
        LShift,
        Lambda,
        List,
        ListComp,
        Load,
        Lt,
        LtE,
        MatMult,
        Match,
        MatchAs,
        MatchClass,
        MatchMapping,
        MatchOr,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchValue,
        Mod,
        Mult,
        Name,
        NamedExpr,
        Nonlocal,
        Not,
        NotEq,
        Or,
        Pass,
        Pow,
        RShift,
        Raise,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Store,
        Sub,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        TypeAlias,
        UAdd,
        USub,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        alias,
        arguments,
        ast_node,
        comprehension,
        expr,
        keyword,
        match_case,
        operator,
        pattern,
        stmt
    }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.compiler_annotations {
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BoolOp,
        Break,
        Call,
        ClassDef,
        Compare,
        Constant,
        Continue,
        Delete,
        Dict,
        DictComp,
        ExceptHandler,
        Expr,
        For,
        FormattedValue,
        FunctionDef,
        GeneratorExp,
        Global,
        If,
        IfExp,
        Import,
        ImportFrom,
        Interpolation,
        JoinedStr,
        Lambda,
        List,
        ListComp,
        Match,
        Name,
        NamedExpr,
        Nonlocal,
        Pass,
        Raise,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        expr,
        match_case,
        stmt
    }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.compiler_codegen {
        Add,
        And,
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BitAnd,
        BitOr,
        BitXor,
        BoolOp,
        Break,
        ClassDef,
        Compare,
        Constant,
        Continue,
        Delete,
        Dict,
        DictComp,
        Div,
        Eq,
        ExceptHandler,
        Expr,
        FloorDiv,
        For,
        FormattedValue,
        FunctionDef,
        GeneratorExp,
        Global,
        Gt,
        GtE,
        If,
        IfExp,
        Import,
        ImportFrom,
        In,
        Interpolation,
        Invert,
        Is,
        IsNot,
        JoinedStr,
        LShift,
        Lambda,
        List,
        ListComp,
        Load,
        Lt,
        LtE,
        MatMult,
        Match,
        MatchAs,
        MatchClass,
        MatchMapping,
        MatchOr,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchValue,
        Mod,
        Mult,
        Name,
        NamedExpr,
        Nonlocal,
        Not,
        NotEq,
        NotIn,
        Or,
        Pass,
        Pow,
        RShift,
        Raise,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Store,
        Sub,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        TypeAlias,
        UAdd,
        USub,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        alias,
        arguments,
        ast_node,
        comprehension,
        expr,
        keyword,
        match_case,
        pattern,
        stmt
    }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.compiler_defs {
        AsyncFunctionDef,
        Call,
        ClassDef,
        Constant,
        Dict,
        FunctionDef,
        Import,
        ImportFrom,
        Load,
        Name,
        ParamSpec,
        Starred,
        Tuple,
        TypeAlias,
        TypeVar,
        TypeVarTuple,
        arguments,
        expr,
        keyword,
        stmt,
        type_param
    }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.compiler_emit {
        Add,
        And,
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BitAnd,
        BitOr,
        BitXor,
        BoolOp,
        Break,
        Call,
        ClassDef,
        Compare,
        Constant,
        Continue,
        Delete,
        Dict,
        DictComp,
        Div,
        Eq,
        ExceptHandler,
        Expr,
        FloorDiv,
        For,
        FormattedValue,
        FunctionDef,
        GeneratorExp,
        Global,
        Gt,
        GtE,
        If,
        IfExp,
        Import,
        ImportFrom,
        In,
        Interpolation,
        Invert,
        Is,
        IsNot,
        JoinedStr,
        LShift,
        Lambda,
        List,
        ListComp,
        Load,
        Lt,
        LtE,
        MatMult,
        Match,
        MatchAs,
        MatchClass,
        MatchMapping,
        MatchOr,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchValue,
        Mod,
        Mult,
        Name,
        NamedExpr,
        Nonlocal,
        Not,
        NotEq,
        NotIn,
        Or,
        Pass,
        Pow,
        RShift,
        Raise,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Store,
        Sub,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        TypeAlias,
        UAdd,
        USub,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        alias,
        arguments,
        ast_node,
        comprehension,
        expr,
        keyword,
        match_case,
        pattern,
        stmt
    }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.compiler_exc {
        AsyncWith,
        ExceptHandler,
        Pass,
        Raise,
        Return,
        Try,
        TryStar,
        With,
        expr,
        stmt
    }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.compiler_ir { stmt }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.compiler_loops {
        AsyncFor,
        Constant,
        For,
        If,
        Name,
        While,
        stmt
    }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.compiler_match {
        Attribute,
        Constant,
        Match,
        MatchAs,
        MatchClass,
        MatchMapping,
        MatchOr,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchValue,
        Name,
        expr,
        pattern,
        stmt
    }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.native_api { mod }
    ast_nodes --> jaclang.compiler.backends.py.jacpython.product_compile {
        Expr,
        Expression,
        Interactive,
        Module,
        expr,
        mod
    }
    ast_nodes --> jaclang.compiler.frontend.python.annotation_unparse {
        Add,
        And,
        AnnAssign,
        AsyncFunctionDef,
        Attribute,
        Await,
        BinOp,
        BitAnd,
        BitOr,
        BitXor,
        BoolOp,
        Call,
        Compare,
        Constant,
        Dict,
        DictComp,
        Div,
        Eq,
        FloorDiv,
        FormattedValue,
        FunctionDef,
        GeneratorExp,
        Gt,
        GtE,
        IfExp,
        In,
        Interpolation,
        Invert,
        Is,
        IsNot,
        JoinedStr,
        LShift,
        Lambda,
        List,
        ListComp,
        Lt,
        LtE,
        MatMult,
        Mod,
        Mult,
        Name,
        NamedExpr,
        Not,
        NotEq,
        NotIn,
        Or,
        Pow,
        RShift,
        Set,
        SetComp,
        Slice,
        Starred,
        Sub,
        Subscript,
        TemplateStr,
        Tuple,
        UAdd,
        USub,
        UnaryOp,
        Yield,
        YieldFrom,
        arg,
        arguments,
        ast_node,
        comprehension,
        expr
    }
    ast_nodes --> jaclang.compiler.frontend.python.ast_input {
        Add,
        And,
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BitAnd,
        BitOr,
        BitXor,
        BoolOp,
        Break,
        Call,
        ClassDef,
        Compare,
        Constant,
        Continue,
        Del,
        Delete,
        Dict,
        DictComp,
        Div,
        Eq,
        ExceptHandler,
        Expr,
        Expression,
        FloorDiv,
        For,
        FormattedValue,
        FunctionDef,
        FunctionType,
        GeneratorExp,
        Global,
        Gt,
        GtE,
        If,
        IfExp,
        Import,
        ImportFrom,
        In,
        Interactive,
        Interpolation,
        Invert,
        Is,
        IsNot,
        JoinedStr,
        LShift,
        Lambda,
        List,
        ListComp,
        Load,
        Lt,
        LtE,
        MatMult,
        Match,
        MatchAs,
        MatchClass,
        MatchMapping,
        MatchOr,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchValue,
        Mod,
        Module,
        Mult,
        Name,
        NamedExpr,
        Nonlocal,
        Not,
        NotEq,
        NotIn,
        Or,
        ParamSpec,
        Pass,
        Pow,
        RShift,
        Raise,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Store,
        Sub,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        TypeAlias,
        TypeIgnore,
        TypeVar,
        TypeVarTuple,
        UAdd,
        USub,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        alias,
        arg,
        arguments,
        ast_field,
        ast_kind,
        ast_node,
        boolop,
        cmpop,
        comprehension,
        excepthandler,
        expr,
        expr_context,
        keyword,
        match_case,
        mod,
        operator,
        pattern,
        stmt,
        type_ignore,
        type_param,
        unaryop,
        withitem
    }
    ast_nodes --> jaclang.compiler.frontend.python.ast_output {
        Add,
        And,
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BitAnd,
        BitOr,
        BitXor,
        BoolOp,
        Break,
        Call,
        ClassDef,
        Compare,
        Constant,
        Continue,
        Del,
        Delete,
        Dict,
        DictComp,
        Div,
        Eq,
        ExceptHandler,
        Expr,
        Expression,
        FloorDiv,
        For,
        FormattedValue,
        FunctionDef,
        FunctionType,
        GeneratorExp,
        Global,
        Gt,
        GtE,
        If,
        IfExp,
        Import,
        ImportFrom,
        In,
        Interactive,
        Interpolation,
        Invert,
        Is,
        IsNot,
        JoinedStr,
        LShift,
        Lambda,
        List,
        ListComp,
        Load,
        Lt,
        LtE,
        MatMult,
        Match,
        MatchAs,
        MatchClass,
        MatchMapping,
        MatchOr,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchValue,
        Mod,
        Module,
        Mult,
        Name,
        NamedExpr,
        Nonlocal,
        Not,
        NotEq,
        NotIn,
        Or,
        ParamSpec,
        Pass,
        Pow,
        RShift,
        Raise,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Store,
        Sub,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        TypeAlias,
        TypeIgnore,
        TypeVar,
        TypeVarTuple,
        UAdd,
        USub,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        alias,
        arg,
        arguments,
        ast_field,
        ast_kind,
        ast_node,
        comprehension,
        keyword,
        match_case,
        withitem
    }
    ast_nodes --> jaclang.compiler.frontend.python.ast_validation {
        Add,
        And,
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BitAnd,
        BitOr,
        BitXor,
        BoolOp,
        Break,
        Call,
        ClassDef,
        Compare,
        Constant,
        Continue,
        Del,
        Delete,
        Dict,
        DictComp,
        Div,
        Eq,
        ExceptHandler,
        Expr,
        Expression,
        FloorDiv,
        For,
        FormattedValue,
        FunctionDef,
        FunctionType,
        GeneratorExp,
        Global,
        Gt,
        GtE,
        If,
        IfExp,
        Import,
        ImportFrom,
        In,
        Interactive,
        Interpolation,
        Invert,
        Is,
        IsNot,
        JoinedStr,
        LShift,
        Lambda,
        List,
        ListComp,
        Load,
        Lt,
        LtE,
        MatMult,
        Match,
        MatchAs,
        MatchClass,
        MatchMapping,
        MatchOr,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchValue,
        Mod,
        Module,
        Mult,
        Name,
        NamedExpr,
        Nonlocal,
        Not,
        NotEq,
        NotIn,
        Or,
        ParamSpec,
        Pass,
        Pow,
        RShift,
        Raise,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Store,
        Sub,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        TypeAlias,
        TypeIgnore,
        TypeVar,
        TypeVarTuple,
        UAdd,
        USub,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        alias,
        arg,
        arguments,
        ast_node,
        boolop,
        cmpop,
        comprehension,
        excepthandler,
        expr,
        expr_context,
        keyword,
        match_case,
        mod,
        operator,
        pattern,
        stmt,
        type_ignore,
        type_param,
        unaryop,
        withitem
    }
    ast_nodes --> jaclang.compiler.frontend.python.ast_walk {
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BoolOp,
        Call,
        ClassDef,
        Compare,
        Delete,
        Dict,
        DictComp,
        ExceptHandler,
        Expr,
        Expression,
        For,
        FormattedValue,
        FunctionDef,
        FunctionType,
        GeneratorExp,
        If,
        IfExp,
        Import,
        ImportFrom,
        Interactive,
        Interpolation,
        JoinedStr,
        Lambda,
        List,
        ListComp,
        Match,
        MatchAs,
        MatchClass,
        MatchMapping,
        MatchOr,
        MatchSequence,
        MatchValue,
        Module,
        Name,
        NamedExpr,
        ParamSpec,
        Raise,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        TypeAlias,
        TypeVar,
        TypeVarTuple,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        alias,
        arg,
        arguments,
        ast_node,
        boolop,
        cmpop,
        comprehension,
        excepthandler,
        expr,
        expr_context,
        keyword,
        match_case,
        operator,
        pattern,
        stmt,
        type_ignore,
        type_param,
        unaryop,
        withitem
    }
    ast_nodes --> jaclang.compiler.frontend.python.compiler_preprocess {
        Add,
        AnnAssign,
        AsyncFunctionDef,
        BinOp,
        ClassDef,
        Constant,
        Expr,
        FormattedValue,
        FunctionDef,
        FunctionType,
        JoinedStr,
        Load,
        MatchMapping,
        MatchValue,
        Mod,
        Module,
        Name,
        Pass,
        Starred,
        Sub,
        Tuple,
        USub,
        UnaryOp,
        arg,
        ast_node,
        expr,
        stmt
    }
    ast_nodes --> jaclang.compiler.frontend.python.compiler_symtable {
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BoolOp,
        Call,
        ClassDef,
        Compare,
        Del,
        Delete,
        Dict,
        DictComp,
        Expr,
        For,
        FormattedValue,
        FunctionDef,
        GeneratorExp,
        Global,
        If,
        IfExp,
        Import,
        ImportFrom,
        Interpolation,
        JoinedStr,
        Lambda,
        List,
        ListComp,
        Load,
        Match,
        MatchAs,
        MatchClass,
        MatchMapping,
        MatchOr,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchValue,
        Module,
        Name,
        NamedExpr,
        Nonlocal,
        ParamSpec,
        Pass,
        Raise,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Store,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        TypeAlias,
        TypeVar,
        TypeVarTuple,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        alias,
        arg,
        arguments,
        ast_node,
        comprehension,
        expr,
        match_case,
        pattern,
        stmt,
        type_param
    }
    ast_nodes --> jaclang.compiler.frontend.python.compiler_validate {
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BoolOp,
        Break,
        Call,
        ClassDef,
        Compare,
        Constant,
        Continue,
        Del,
        Delete,
        Dict,
        DictComp,
        Expr,
        For,
        FunctionDef,
        GeneratorExp,
        Global,
        If,
        ImportFrom,
        Is,
        IsNot,
        Lambda,
        List,
        ListComp,
        Load,
        MatMult,
        Match,
        Name,
        NamedExpr,
        Nonlocal,
        ParamSpec,
        Pass,
        Return,
        SetComp,
        Slice,
        Starred,
        Store,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        TypeAlias,
        TypeVar,
        TypeVarTuple,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        arguments,
        ast_node,
        comprehension,
        expr,
        stmt,
        type_param
    }
    ast_nodes --> jaclang.compiler.frontend.python.parser {
        Add,
        And,
        AnnAssign,
        Assert,
        Assign,
        AsyncFor,
        AsyncFunctionDef,
        AsyncWith,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BitAnd,
        BitOr,
        BitXor,
        BoolOp,
        Break,
        Call,
        ClassDef,
        Compare,
        Constant,
        Continue,
        Del,
        Delete,
        Dict,
        DictComp,
        Div,
        Eq,
        ExceptHandler,
        Expr,
        Expression,
        FloorDiv,
        For,
        FormattedValue,
        FunctionDef,
        FunctionType,
        GeneratorExp,
        Global,
        Gt,
        GtE,
        If,
        IfExp,
        Import,
        ImportFrom,
        In,
        Interactive,
        Interpolation,
        Invert,
        Is,
        IsNot,
        JoinedStr,
        LShift,
        Lambda,
        List,
        ListComp,
        Load,
        Lt,
        LtE,
        MatMult,
        Match,
        MatchAs,
        MatchClass,
        MatchMapping,
        MatchOr,
        MatchSequence,
        MatchSingleton,
        MatchStar,
        MatchValue,
        Mod,
        Module,
        Mult,
        Name,
        NamedExpr,
        Nonlocal,
        Not,
        NotEq,
        NotIn,
        Or,
        ParamSpec,
        Pass,
        Pow,
        RShift,
        Raise,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Store,
        Sub,
        Subscript,
        TemplateStr,
        Try,
        TryStar,
        Tuple,
        TypeAlias,
        TypeVar,
        TypeVarTuple,
        UAdd,
        USub,
        UnaryOp,
        While,
        With,
        Yield,
        YieldFrom,
        alias,
        arg,
        arguments,
        ast_node,
        cmpop,
        comprehension,
        excepthandler,
        expr,
        expr_context,
        keyword,
        match_case,
        mod,
        operator,
        pattern,
        stmt,
        type_param,
        withitem
    }
    ast_nodes --> jaclang.compiler.frontend.python.parser.finish_parse { TypeIgnore }
    ast_nodes --> jaclang.compiler.frontend.python.parser_actions {
        Add,
        And,
        AnnAssign,
        Assign,
        AsyncFunctionDef,
        Attribute,
        AugAssign,
        Await,
        BinOp,
        BitAnd,
        BitOr,
        BitXor,
        BoolOp,
        Break,
        Call,
        ClassDef,
        Compare,
        Constant,
        Continue,
        Del,
        Delete,
        Dict,
        DictComp,
        Div,
        Eq,
        Expr,
        Expression,
        FloorDiv,
        FormattedValue,
        FunctionDef,
        GeneratorExp,
        Gt,
        GtE,
        IfExp,
        ImportFrom,
        In,
        Interpolation,
        Invert,
        Is,
        IsNot,
        JoinedStr,
        LShift,
        Lambda,
        List,
        ListComp,
        Load,
        Lt,
        LtE,
        MatMult,
        MatchOr,
        MatchSingleton,
        Mod,
        Module,
        Mult,
        Name,
        NamedExpr,
        Not,
        NotEq,
        NotIn,
        Or,
        Pass,
        Pow,
        RShift,
        Return,
        Set,
        SetComp,
        Slice,
        Starred,
        Store,
        Sub,
        Subscript,
        TemplateStr,
        Tuple,
        UAdd,
        USub,
        UnaryOp,
        Yield,
        YieldFrom,
        alias,
        arg,
        arguments,
        ast_node,
        boolop,
        cmpop,
        comprehension,
        excepthandler,
        expr,
        expr_context,
        keyword,
        match_case,
        mod,
        operator,
        pattern,
        stmt,
        type_param,
        unaryop,
        withitem
    }
    ast_nodes --> jaclang.runtime.python.symtable { Expr, stmt }
    ast_output --> jaclang.compiler.backends.py.jacpython.native_api { ast_write_node }
    ast_output --> jaclang.runtime.python.symtable {
        ast_output_append_owned,
        ast_output_checked,
        ast_write_text
    }
    ast_validation --> jaclang.compiler.backends.py.jacpython.native_api {
        validate_ast_value
    }
    ast_walk --> jaclang.compiler.frontend.python.annotation_unparse {
        ast_child_visitor,
        visit_ast_children
    }
    ast_walk --> jaclang.compiler.frontend.python.ast_validation {
        ast_child_visitor,
        visit_ast_children
    }
    ast_walk --> jaclang.compiler.frontend.python.compiler_preprocess {
        ast_rewriter,
        rewrite_ast_children
    }
    ast_walk --> jaclang.compiler.frontend.python.compiler_validate {
        ast_child_buffer,
        ast_child_visitor,
        visit_ast_children
    }
    compiler_diagnostics --> jaclang.compiler.backends.py.jacpython.compiler_codegen {
        lowering_diagnostic
    }
    compiler_diagnostics --> jaclang.compiler.backends.py.jacpython.compiler_emit {
        lowering_diagnostic
    }
    compiler_diagnostics --> jaclang.compiler.backends.py.jacpython.compiler_ir {
        compiler_diagnostic
    }
    compiler_diagnostics --> jaclang.compiler.backends.py.jacpython.flowgraph {
        compiler_diagnostic,
        internal_compiler_diagnostic
    }
    compiler_diagnostics --> jaclang.compiler.backends.py.jacpython.product_compile {
        compiler_diag_to_pyobj
    }
    compiler_diagnostics --> jaclang.compiler.frontend.python.compiler_symtable {
        compiler_diag_kind,
        compiler_diag_message,
        compiler_diagnostic,
        symbol_diagnostic
    }
    compiler_diagnostics --> jaclang.compiler.frontend.python.compiler_validate {
        compiler_diag_kind,
        compiler_diagnostic,
        syntax_warning,
        validation_diagnostic
    }
    compiler_diagnostics --> jaclang.compiler.frontend.python.peg_runtime.peg_fill_token {
        report_token_warnings
    }
    compiler_diagnostics --> jaclang.runtime.python.symtable { compiler_diag_to_pyobj }
    compiler_diagnostics --> jaclang.runtime.python.tokenize { report_token_warnings }
    compiler_preprocess --> jaclang.compiler.backends.py.jacpython.product_compile {
        preprocess_node
    }
    compiler_symtable --> jaclang.compiler.backends.py.jacpython.codegen_util {
        scope_kind
    }
    compiler_symtable --> jaclang.compiler.backends.py.jacpython.compiler_annotations {
        SCOPE_CELL,
        SCOPE_GLOBAL_IMPLICIT,
        SYM_USE,
        scope_kind,
        sym_block,
        sym_block_tuple_names,
        sym_dict_get,
        sym_set_scope
    }
    compiler_symtable --> jaclang.compiler.backends.py.jacpython.compiler_codegen {
        DEF_COMP_ITER,
        SCOPE_CELL,
        SCOPE_FREE,
        SCOPE_GLOBAL_EXPLICIT,
        SCOPE_GLOBAL_IMPLICIT,
        SCOPE_LOCAL,
        mangle_name,
        scope_kind,
        sym_block,
        sym_block_tuple_names,
        sym_dict_get,
        sym_flag_set,
        sym_scope_of,
        sym_sorted_names
    }
    compiler_symtable --> jaclang.compiler.backends.py.jacpython.compiler_defs {
        SCOPE_GLOBAL_EXPLICIT,
        scope_kind,
        scope_role,
        sym_block,
        sym_dict_get,
        sym_scope_of
    }
    compiler_symtable --> jaclang.compiler.backends.py.jacpython.compiler_emit {
        DEF_COMP_ITER,
        SCOPE_CELL,
        SCOPE_FREE,
        SCOPE_GLOBAL_EXPLICIT,
        SCOPE_GLOBAL_IMPLICIT,
        SCOPE_LOCAL,
        mangle_name,
        scope_kind,
        sym_block,
        sym_block_tuple_names,
        sym_dict_get,
        sym_flag_set,
        sym_mangle_name,
        sym_scope_of,
        sym_sorted_names
    }
    compiler_symtable --> jaclang.compiler.backends.py.jacpython.compiler_ir {
        sym_block
    }
    compiler_symtable --> jaclang.compiler.backends.py.jacpython.compiler_match {
        scope_kind
    }
    compiler_symtable --> jaclang.compiler.backends.py.jacpython.native_api {
        mangle_name
    }
    compiler_symtable --> jaclang.compiler.backends.py.jacpython.product_compile {
        build_module_symtable
    }
    compiler_symtable --> jaclang.runtime.python.symtable {
        DEF_BOUND,
        DEF_PARAM,
        SCOPE_CELL,
        SCOPE_LOCAL,
        SCOPE_OFFSET,
        SYM_USE,
        build_module_symtable,
        is_type_variable_info,
        scope_info_kind,
        scope_kind,
        sym_block
    }
    compiler_validate --> jaclang.compiler.backends.py.jacpython.product_compile {
        check_ast_warnings,
        future_features,
        validate_eval_expr,
        validate_module_body
    }
    compiler_validate --> jaclang.compiler.frontend.python.parser.finish_parse {
        validate_feature_version
    }
    compiler_validate --> jaclang.runtime.python.symtable { future_features }
    parser --> jaclang.compiler.backends.py.jacpython.native_api {
        parse_eval_source,
        parse_file,
        parse_func_type,
        parse_interactive
    }
    parser --> jaclang.compiler.backends.py.jacpython.product_compile {
        parse_eval_expr,
        parse_file,
        parse_interactive
    }
    parser --> jaclang.runtime.python.symtable {
        parse_eval_expr,
        parse_file,
        parse_interactive
    }
    parser_actions --> jaclang.compiler.frontend.python.parser {
        keyword_or_starred_node,
        kp_pair,
        kv_pair,
        name_default_pair,
        pa_add_type_comment_to_arg,
        pa_alias_for_star,
        pa_arguments_parsing_error,
        pa_ast_annassign,
        pa_ast_assign,
        pa_ast_attribute,
        pa_ast_augassign,
        pa_ast_binop,
        pa_ast_boolop,
        pa_ast_break,
        pa_ast_call,
        pa_ast_compare,
        pa_ast_continue,
        pa_ast_delete,
        pa_ast_expr_stmt,
        pa_ast_expression,
        pa_ast_ifexp,
        pa_ast_pass,
        pa_ast_return,
        pa_ast_slice,
        pa_ast_starred,
        pa_ast_subscript,
        pa_ast_tuple,
        pa_ast_unaryop,
        pa_aug_op,
        pa_call_args,
        pa_call_from_optional_args,
        pa_call_keywords,
        pa_check,
        pa_check_fstring_conversion,
        pa_check_legacy_stmt,
        pa_check_legacy_stmt_or_raise,
        pa_checked_future_import,
        pa_class_def_decorators,
        pa_cmpop_expr_pair,
        pa_collect_call_seqs,
        pa_comp_field,
        pa_concatenate_strings,
        pa_concatenate_tstrings,
        pa_constant_bool,
        pa_constant_ellipsis,
        pa_constant_from_expr,
        pa_constant_from_fstring_middle,
        pa_constant_from_string,
        pa_constant_from_token,
        pa_constant_none,
        pa_decoded_constant_from_token,
        pa_dummy_name,
        pa_empty_arguments,
        pa_ensure_imaginary,
        pa_ensure_real,
        pa_err_occurred,
        pa_expr_end_col_offset,
        pa_expr_end_lineno,
        pa_expr_lineno,
        pa_formatted_value,
        pa_function_def_decorators,
        pa_get_cmpops,
        pa_get_expr_name,
        pa_get_exprs,
        pa_get_keys,
        pa_get_last_comprehension_item,
        pa_get_pattern_keys,
        pa_get_patterns,
        pa_get_values,
        pa_interactive_exit,
        pa_interpolation,
        pa_join_names_with_dot,
        pa_join_sequences,
        pa_join_sequences_kw_or_starred,
        pa_joined_str,
        pa_key_pattern_pair,
        pa_key_value_pair,
        pa_keyword_or_starred,
        pa_make_arguments,
        pa_make_cmpop_pair,
        pa_make_module,
        pa_map_names_to_ids,
        pa_match_singleton,
        pa_name_default_pair,
        pa_name_from_token,
        pa_name_id,
        pa_nonparen_genexp_in_call,
        pa_number_from_token,
        pa_or_pattern_singleton,
        pa_pattern_list,
        pa_raise_invalid_target,
        pa_raise_kvpair_error,
        pa_raise_syntax,
        pa_raise_syntax_known_expr,
        pa_raise_syntax_known_range,
        pa_raise_type_param_error,
        pa_seq_append_to_end,
        pa_seq_append_to_end_expr,
        pa_seq_append_to_end_stmt,
        pa_seq_count_dots,
        pa_seq_delete_starred_exprs,
        pa_seq_extract_starred_exprs,
        pa_seq_first,
        pa_seq_flatten,
        pa_seq_get,
        pa_seq_insert_front,
        pa_seq_insert_front_alias,
        pa_seq_insert_front_arg,
        pa_seq_insert_front_expr,
        pa_seq_insert_front_kvpair,
        pa_seq_insert_front_kvpattern,
        pa_seq_insert_front_kw_or_starred,
        pa_seq_insert_front_pattern,
        pa_seq_insert_front_stmt,
        pa_seq_insert_front_type_param,
        pa_seq_insert_front_withitem,
        pa_seq_last,
        pa_seq_len,
        pa_set_context,
        pa_setup_full_format_spec,
        pa_singleton_seq,
        pa_singleton_seq_alias,
        pa_singleton_seq_expr,
        pa_singleton_seq_stmt,
        pa_slash_with_default,
        pa_star_etc,
        pa_stmt_list_or_empty,
        pa_template_str
    }
    peg_runtime --> jaclang.compiler.frontend.python.parser {
        DEL_TARGETS,
        FOR_TARGETS,
        STAR_TARGETS,
        peg_check_memo,
        peg_expect_forced_result,
        peg_expect_forced_token,
        peg_expect_soft_keyword,
        peg_expect_token,
        peg_fill_token,
        peg_get_last_nonnwhitespace_token,
        peg_has_error,
        peg_insert_memo,
        peg_left_rec_finish,
        peg_mark,
        peg_negative_lookahead_token,
        peg_parser,
        peg_parser_from_source,
        peg_positive_lookahead_token,
        peg_reset,
        peg_reset_for_error_pass,
        peg_token,
        peg_update_memo
    }
    peg_runtime --> jaclang.compiler.frontend.python.parser_actions {
        peg_has_error,
        peg_parser,
        peg_raise_syntax_error,
        peg_raise_syntax_error_on_token,
        peg_token
    }
    source_encoding --> jaclang.compiler.backends.py.jacpython.native_api {
        source_fd_encoding
    }
    source_encoding --> jaclang.compiler.frontend.python.source_input {
        source_encoding
    }
    source_input --> jaclang.compiler.backends.py.jacpython.native_api {
        decode_source_value
    }
    syntax_error --> jaclang.compiler.backends.py.jacpython.native_api {
        source_character_column,
        split_source_lines,
        syntax_failure
    }
    syntax_error --> jaclang.compiler.frontend.python.compiler_diagnostics {
        syntax_failure
    }
    syntax_error --> jaclang.compiler.frontend.python.compiler_validate {
        syntax_failure
    }
    syntax_error --> jaclang.compiler.frontend.python.parser {
        decode_source_lines,
        source_character_column,
        syntax_failure
    }
    syntax_error --> jaclang.compiler.frontend.python.parser_actions {
        source_line_bytes,
        syntax_failure
    }
    syntax_error --> jaclang.compiler.frontend.python.source_encoding { syntax_failure }
    syntax_error --> jaclang.compiler.frontend.python.source_input { syntax_failure }
    syntax_error --> jaclang.runtime.python.native_services { syntax_failure }
    syntax_error --> jaclang.runtime.python.tokenize { syntax_failure }
    token_model --> jaclang.compiler.frontend.python.parser {
        DEDENT,
        ENDMARKER,
        FSTRING_END,
        FSTRING_MIDDLE,
        FSTRING_START,
        INDENT,
        NAME,
        NEWLINE,
        NT_OFFSET,
        NUMBER,
        OP,
        STRING,
        TSTRING_END,
        TSTRING_MIDDLE,
        TSTRING_START,
        TYPE_COMMENT
    }
    token_model --> jaclang.compiler.frontend.python.parser_actions { mk_diag, tok_loc }
    token_model --> jaclang.compiler.frontend.python.peg_runtime {
        COMMENT,
        DEDENT,
        ENDMARKER,
        ERRORTOKEN,
        INDENT,
        NAME,
        NEWLINE,
        NL,
        NT_OFFSET,
        NUMBER,
        TOK_NO_COLUMN,
        TOK_NO_LINE,
        TYPE_IGNORE,
        is_whitespace_token,
        mk_diag,
        tok_diag,
        tok_loc,
        tok_no_loc,
        tok_token
    }
    token_model --> jaclang.compiler.frontend.python.tokenizer {
        COLON,
        COMMA,
        COMMENT,
        DEDENT,
        ENDMARKER,
        ERRORTOKEN,
        EXACT_TOKEN_TYPES,
        FSTRING_END,
        FSTRING_MIDDLE,
        FSTRING_START,
        INDENT,
        LBRACE,
        LPAR,
        LSQB,
        NAME,
        NEWLINE,
        NL,
        NUMBER,
        RBRACE,
        RPAR,
        RSQB,
        STRING,
        TOK_NO_COLUMN,
        TSTRING_END,
        TSTRING_MIDDLE,
        TSTRING_START,
        TYPE_COMMENT,
        TYPE_IGNORE,
        exact_token_type,
        mk_diag,
        tok_diag,
        tok_loc_span,
        tok_no_loc,
        tok_token
    }
    token_model --> jaclang.runtime.python.tokenize {
        DEDENT,
        ENDMARKER,
        FSTRING_MIDDLE,
        INDENT,
        NEWLINE,
        NL,
        NUMBER,
        OP,
        STRING,
        TSTRING_MIDDLE,
        tok_diag
    }
    tokenizer --> jaclang.compiler.frontend.python.compiler_diagnostics { tok_state }
    tokenizer --> jaclang.compiler.frontend.python.peg_runtime {
        tok_state,
        tokenizer_from_string,
        tokenizer_next
    }
    tokenizer --> jaclang.runtime.python.tokenize {
        tok_state,
        token_source,
        tokenizer_next
    }
}

impl import jaclang.compiler.passes {
    access_check_pass --> jaclang.compiler.driver.pipeline.get_analysis_sched {
        AccessCheckPass
    }
    annex_weave --> jaclang.compiler.frontend.parser.frontend.parse_woven {
        merge_annex_into
    }
    ast_validation_pass --> jaclang.compiler.driver.pipeline { ASTValidationPass }
    ast_validation_pass --> jaclang.compiler.jc_unit { ASTValidationPass }
    ast_validation_pass --> jaclang.compiler.native_compiler.NativeCompiler.take_pass_results {
        ASTValidationPass
    }
    boundary_analysis_pass --> jaclang.compiler.driver.compiler { BoundaryAnalysisPass }
    boundary_analysis_pass --> jaclang.compiler.driver.pipeline { BoundaryAnalysisPass }
    capability_check_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._fstring_spec_text {
        static_fstring_spec_text
    }
    capability_check_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._process_clib_imports {
        classify_native_import
    }
    capability_check_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._run_impl {
        native_capability_violations,
        partition_native_capability_violations
    }
    capability_check_pass --> jaclang.compiler.driver.pipeline.get_analysis_sched {
        ClientCapabilityCheckPass,
        NativeCapabilityCheckPass,
        PortabilityWarnPass
    }
    cfg_build_pass --> jaclang.compiler.driver.pipeline.get_ir_gen_sched {
        CFGBuildPass
    }
    cfg_build_pass --> jaclang.compiler.driver.pipeline.product_pipeline {
        CFGBuildPass
    }
    cfg_build_pass --> jaclang.compiler.driver.pipeline.run_utility { CoalesceBBPass }
    cfg_build_pass --> jaclang.compiler.tests.test_pipeline_products { CFGBuildPass }
    cfg_build_pass --> jaclang.compiler.tools.lang_tools { cfg_dot_from_file }
    comptime_resolve_pass --> jaclang.compiler.driver.pipeline.get_ir_gen_sched {
        ComptimeResolvePass
    }
    type context --> jaclang.client.client_diagnostics { Alert }
    context --> jaclang.compiler.backends.common.ast_gen_base { CompileContext }
    context --> jaclang.compiler.backends.native.na_compile_pass { CompileContext }
    context --> jaclang.compiler.backends.native.na_ir_gen_pass { CompileContext }
    context --> jaclang.compiler.backends.py.jcir_bc_gen_pass { CompileContext }
    context --> jaclang.compiler.driver.compilation_context { Alert }
    context --> jaclang.compiler.driver.compiler.JacCompiler._report_missing_native_ir {
        Alert
    }
    context --> jaclang.compiler.driver.context_passes { CompileContext }
    context --> jaclang.compiler.driver.ifacecache._alert_from_record { Alert }
    context --> jaclang.compiler.driver.pass_driver { Alert, DiagnosticPolicy }
    context --> jaclang.compiler.driver.program { Alert }
    context --> jaclang.compiler.driver.progstate { Alert, PassResult }
    context --> jaclang.compiler.frontend.parser.frontend { Alert }
    context --> jaclang.compiler.jc_unit { Alert, CompileContext }
    type context --> jaclang.compiler.native_compiler { Alert, PassResult }
    context --> jaclang.compiler.native_compiler.NativeCompiler.take_pass_results {
        PassResult as CompletedPassResult
    }
    context --> jaclang.compiler.passes.access_check_pass { CompileContext }
    context --> jaclang.compiler.passes.ast_validation_pass { CompileContext }
    context --> jaclang.compiler.passes.boundary_analysis_pass { CompileContext }
    context --> jaclang.compiler.passes.capability_check_pass { CompileContext }
    context --> jaclang.compiler.passes.cfg_build_pass { CompileContext }
    context --> jaclang.compiler.passes.decl_impl_match_pass { CompileContext }
    context --> jaclang.compiler.passes.endpoint_effect_pass { CompileContext }
    context --> jaclang.compiler.passes.execution {
        Alert,
        CompileContext,
        DiagnosticPolicy,
        PassResult
    }
    context --> jaclang.compiler.passes.freeze_structure_pass { CompileContext }
    context --> jaclang.compiler.passes.graph_lowering_pass { CompileContext }
    context --> jaclang.compiler.passes.import_wiring_pass { CompileContext }
    context --> jaclang.compiler.passes.jsx_intrinsic_guard_pass { CompileContext }
    context --> jaclang.compiler.passes.layout_pass { CompileContext }
    context --> jaclang.compiler.passes.mtir_gen_pass { CompileContext }
    context --> jaclang.compiler.passes.ownership_check_pass { CompileContext }
    context --> jaclang.compiler.passes.pyast_load_pass { CompileContext }
    context --> jaclang.compiler.passes.rc_facts_pass { CompileContext }
    context --> jaclang.compiler.passes.region_infer_pass { CompileContext }
    context --> jaclang.compiler.passes.sem_def_match_pass { CompileContext }
    context --> jaclang.compiler.passes.semantic_analysis_pass { CompileContext }
    context --> jaclang.compiler.passes.static_analysis_pass { CompileContext }
    context --> jaclang.compiler.passes.sym_tab_build_pass { CompileContext }
    context --> jaclang.compiler.passes.type_checker_pass { CompileContext }
    context --> jaclang.compiler.passes.variant_agreement_pass { CompileContext }
    context --> jaclang.compiler.placement.placement_solver { CompileContext }
    context --> jaclang.compiler.placement.placement_solver._emit_solver_warning {
        Alert
    }
    context --> jaclang.compiler.tools.comment_attach_pass { CompileContext }
    context --> jaclang.compiler.tools.doc_ir_gen_pass { CompileContext }
    context --> jaclang.compiler.tools.grammar_extract_pass { CompileContext }
    context --> jaclang.compiler.tools.jac_auto_lint_pass { CompileContext }
    context --> jaclang.compiler.tools.jac_formatter_pass { CompileContext }
    context --> jaclang.compiler.tools.normalize_pass { CompileContext }
    context --> jaclang.compiler.tools.unparse_pass { CompileContext }
    context --> jaclang.compiler.types.type_evaluator { CompileContext }
    type context --> jaclang.lsp.server.engine { Alert }
    context --> jaclang.lsp.server.utils { Alert }
    type context --> jaclang.server.hmr { Alert }
    dataflow --> jaclang.compiler.passes.ownership_check_pass {
        solve_backward,
        solve_forward,
        solve_forward_must
    }
    dataflow --> jaclang.compiler.passes.rc_facts_pass { solve_backward_gen_kill }
    decl_impl_match_pass --> jaclang.compiler.driver.pipeline { DeclImplMatchPass }
    endpoint_effect_pass --> jaclang.compiler.driver.pipeline { EndpointEffectPass }
    execution --> jaclang.compiler.driver.pass_driver { run_walker }
    execution --> jaclang.compiler.tests.test_module_exports { run_walker }
    execution --> jaclang.compiler.tests.xbackend_equiv { run_walker }
    freeze_structure_pass --> jaclang.compiler.driver.pipeline.get_py_code_gen {
        FreezeStructurePass
    }
    graph_lowering_pass --> jaclang.compiler.driver.pipeline { GraphLoweringPass }
    import_wiring_pass --> jaclang.compiler.driver.pipeline { ImportWiringPass }
    jsx_intrinsic_guard_pass --> jaclang.compiler.driver.pipeline.get_ir_gen_sched {
        JsxIntrinsicGuardPass
    }
    layout_pass --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._field_constructor_args {
        archetype_native_name,
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass {
        ACCESSOR_SLOT_SUFFIX,
        ArchetypeLayout,
        EnumLayout,
        VTABLE_HEADER_SLOTS,
        accessor_slot_name,
        archetype_accessors,
        native_type_key
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._aos_elem_name {
        class_type_native_name
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._arch_is_acyclic {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._arch_is_osp_name {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._arch_is_walker_name {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._arch_key {
        archetype_native_name
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._arch_layout {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._arch_ref_key {
        referenced_native_name
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._class_const_declarer {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._class_const_variants {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_archetype {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_atom_trailer {
        class_form_enum_member,
        class_form_enum_scalar
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_class_form_enum_member {
        class_form_enum_member
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_enum_layout {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_instantiation {
        get_layout_registry as _ci_glr
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_virtual_call {
        get_layout_registry as _vc_glr,
        get_layout_registry as _vd_glr
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._elem_arch_name_of {
        class_type_native_name
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._emit_dispatched_field_ptr {
        get_layout_registry as _df_glr
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._emit_isa_hashed_fn {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._ensure_enum_lowered {
        class_form_enum_scalar,
        enum_decl_of,
        enum_value_type_of,
        is_enum_class_type
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._enum_ctor_layout {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._exception_handler_ids {
        class_type_native_name
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._is_enum_arch {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._isinstance_needs_class_name {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._isinstance_unprovable_class {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._jc_reference_schema {
        class_type_native_name
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._lower_class_type {
        class_type_native_name
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._mangled_of {
        native_type_key
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._mro_of {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._native_archetypes {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._nogc_osp_skip {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._nogc_type_arg_mangles {
        native_type_key
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._osp_edge_class_name {
        class_type_native_name
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._receiver_routed_method_fn {
        get_layout_registry as _sc_glr
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_archetypes {
        get_layout_registry,
        get_layout_registry as _no_glr
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_class_consts {
        class_form_enum_scalar
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_imported_hierarchy {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_imported_struct_types {
        adopt_imported_bases
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._resolve_method {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._resolve_method_owner {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._visit_nonprimary_ancestor_methods {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._vtable_candidates {
        get_layout_registry
    }
    layout_pass --> jaclang.compiler.driver.pipeline.product_pipeline { LayoutPass }
    layout_pass --> jaclang.compiler.passes.osp_analysis.OspAnalysis._isa_closure {
        referenced_native_name
    }
    layout_pass --> jaclang.compiler.passes.osp_analysis.OspAnalysis.arch_key {
        archetype_native_name
    }
    layout_pass --> jaclang.compiler.passes.osp_analysis.OspAnalysis.native_slot_triggers {
        native_type_key,
        referenced_native_name
    }
    layout_pass --> jaclang.compiler.symbol_utils.collect_method_names {
        archetype_accessors
    }
    mtir_gen_pass --> jaclang.compiler.driver.pipeline.get_ir_gen_sched { MTIRGenPass }
    osp_analysis --> jaclang.compiler.backends.es.esast_gen_pass {
        OspAnalysis,
        OspModel,
        OspSlot
    }
    osp_analysis --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._osp_model {
        get_osp_model
    }
    type osp_analysis --> jaclang.compiler.backends.native.na_ir_gen_pass { OspSlot }
    osp_analysis --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._compute_osp_model {
        get_osp_model
    }
    osp_analysis --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._trigger_struct_names {
        OspAnalysis
    }
    type osp_analysis --> jaclang.compiler.frontend.codeinfo { OspModel }
    ownership_check_pass --> jaclang.compiler.driver.pipeline.get_analysis_sched {
        OwnershipCheckPass
    }
    ownership_hints --> jaclang.cli.commands.analysis.explain { inferred_hints }
    ownership_hints --> jaclang.lsp.server.engine.JacLangServer.get_inlay_hints {
        inferred_hints
    }
    pyast_load_pass --> jaclang.cli.commands.transform.py2jac { PyastBuildPass }
    pyast_load_pass --> jaclang.compiler.driver.compiler.JacCompiler.parse_str {
        PyastBuildPass
    }
    pyast_load_pass --> jaclang.compiler.driver.pipeline.run_utility { PyastBuildPass }
    pyast_load_pass --> jaclang.compiler.driver.program.JacProgram.load_dependency_module {
        PyastBuildPass
    }
    pyast_load_pass --> jaclang.compiler.tests.test_module_exports { PyastBuildPass }
    pyast_load_pass --> jaclang.compiler.tools.lang_tools { PyastBuildPass }
    pyast_load_pass --> jaclang.compiler.tools.lang_tools.AstTool.py_uni_nodes {
        PyastBuildPass
    }
    rc_facts_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_expr {
        Ownership,
        result_ownership
    }
    rc_facts_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_for_indexed {
        loop_body_locals
    }
    rc_facts_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_forever {
        loop_body_locals
    }
    rc_facts_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_iter_for {
        loop_body_locals
    }
    rc_facts_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_open_stmt {
        loop_body_locals
    }
    rc_facts_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_while {
        loop_body_locals
    }
    rc_facts_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._opt_result_owned {
        Ownership,
        result_ownership
    }
    rc_facts_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._try_chunked_for {
        loop_body_locals
    }
    rc_facts_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._try_flow_for_parallel {
        loop_body_locals
    }
    rc_facts_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._try_iter_protocol_for {
        loop_body_locals
    }
    rc_facts_pass --> jaclang.compiler.driver.nativecache.NativeBuildSession.lower {
        RcFactsPass
    }
    rc_facts_pass --> jaclang.compiler.driver.pipeline.get_py_code_gen { RcFactsPass }
    rc_facts_pass --> jaclang.compiler.driver.pipeline.product_pipeline { RcFactsPass }
    rc_facts_pass --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._nogc_infer_state {
        Ownership,
        result_ownership
    }
    rc_facts_pass --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._nogc_local_shape_expr_heap {
        Ownership,
        result_ownership
    }
    region_infer_pass --> jaclang.compiler.driver.pipeline.get_analysis_sched {
        RegionInferPass
    }
    scope_walk --> jaclang.compiler.passes.static_analysis_pass { ScopeWalker }
    scope_walk --> jaclang.compiler.tools.code_intel { ScopeWalker }
    sem_def_match_pass --> jaclang.compiler.driver.pipeline.get_ir_gen_sched {
        SemDefMatchPass
    }
    semantic_analysis_pass --> jaclang.compiler.driver.compiler { SemanticAnalysisPass }
    semantic_analysis_pass --> jaclang.compiler.driver.pipeline { SemanticAnalysisPass }
    static_analysis_pass --> jaclang.compiler.driver.pipeline.get_analysis_sched {
        StaticAnalysisPass
    }
    sym_tab_build_pass --> jaclang.compiler.driver.compiler { SymTabBuildPass }
    sym_tab_build_pass --> jaclang.compiler.driver.pipeline { SymTabBuildPass }
    sym_tab_build_pass --> jaclang.compiler.driver.program.JacProgram.load_dependency_module {
        SymTabBuildPass
    }
    sym_tab_build_pass --> jaclang.compiler.jc_unit { SymTabBuildPass }
    sym_tab_build_pass --> jaclang.compiler.native_compiler.NativeCompiler.take_pass_results {
        SymTabBuildPass
    }
    type_checker_pass --> jaclang.compiler.driver.pipeline.get_analysis_sched {
        TypeCheckPass
    }
    type_checker_pass --> jaclang.compiler.passes.comptime_resolve_pass {
        TypeCheckPass
    }
    type_checker_pass --> jaclang.compiler.tests.test_pipeline_products {
        TypeCheckPass
    }
    type_checker_pass --> jaclang.compiler.tests.xbackend_equiv.compile_fixture_to_js {
        TypeCheckPass
    }
    variant_agreement_pass --> jaclang.compiler.driver.pipeline.get_analysis_sched {
        VariantAgreementPass
    }
    wasm_contract --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._register_na_client_import {
        function_contract,
        host_contracts
    }
    wasm_contract --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass.enter_func_call {
        check_host_call
    }
}

impl import jaclang.compiler.placement {
    placement --> jaclang.cli.commands.analysis._check_file_job {
        collect_placement_rows
    }
    placement --> jaclang.cli.commands.analysis.explain { collect_placement_rows }
    placement --> jaclang.cli.commands.fix._verify_claims { element_display_name }
    placement --> jaclang.compiler.driver.compiler.JacCompiler._persist_module_cache {
        get_module_summary,
        summary_to_bytes
    }
    placement --> jaclang.compiler.driver.compiler.JacCompiler._persist_native_unit {
        get_module_summary,
        summary_to_bytes
    }
    placement --> jaclang.compiler.driver.compiler.JacCompiler._restore_sections {
        summary_from_bytes,
        summary_store
    }
    placement --> jaclang.compiler.driver.ifacecache.IfaceRegistry._persist_in_context {
        get_module_summary,
        summary_to_bytes
    }
    placement --> jaclang.compiler.driver.ifacecache.IfaceRegistry._restore_placement {
        summary_from_bytes,
        summary_store
    }
    placement --> jaclang.compiler.driver.nativecache.NativeUnitRegistry.record_verdict {
        note_native_verdict
    }
    placement --> jaclang.compiler.driver.nativecache.verdict_from_jir {
        summary_from_bytes
    }
    placement --> jaclang.compiler.placement.placement_solver {
        PLACEMENT_HOLD_EXEMPT_ROOTS,
        get_module_summary,
        placement_state,
        record_placement_evidence,
        scan_native_blockers,
        summarize_module
    }
    placement --> jaclang.compiler.placement.placement_solver._closure_pullable {
        module_has_root_access
    }
    placement --> jaclang.compiler.placement.placement_solver._endpoint_veto_applies {
        project_has_server
    }
    placement --> jaclang.compiler.placement.placement_solver._pullable_by_client_reference {
        module_has_root_access
    }
    placement --> jaclang.compiler.symbol_utils.client_bridged_endpoint {
        project_has_server
    }
    placement --> jaclang.compiler.symbol_utils.report_placement_warnings {
        get_module_summary
    }
    placement --> jaclang.compiler.symbol_utils.report_serverless_kind_errors {
        project_kind_name
    }
    placement --> jaclang.compiler.symbol_utils.serverless_server_evidence {
        get_module_summary,
        project_has_server
    }
    placement --> jaclang.dist.precompile_bytecode._unit_extra {
        summary_from_bytes,
        summary_to_bytes
    }
    placement_facts --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._dep_is_native_unit {
        native_unit
    }
    placement_facts --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._register_imported_struct_types {
        native_unit as _typed_native_unit
    }
    placement_facts --> jaclang.compiler.driver.compiler.JacCompiler.parse_str {
        native_only as _native_only,
        native_unit as _native_unit
    }
    placement_facts --> jaclang.compiler.driver.nativecache.NativeUnitRegistry.known_native_deps {
        native_unit
    }
    placement_facts --> jaclang.dist.precompile_bytecode._application_sources {
        module_spaces,
        spaces_are_client_only
    }
    placement_facts --> jaclang.dist.precompile_bytecode.find_jac_files { native_only }
    placement_facts --> jaclang.dist.precompile_bytecode.package_native_units {
        native_units_of
    }
    placement_facts --> jaclang.dist.precompile_bytecode.run_precompile { native_only }
    placement_facts --> jaclang.dist.precompile_bytecode.sealable_sources {
        discover_spaces,
        spaces_are_client_only
    }
    placement_pins --> jaclang.compiler.driver.boundary_classify {
        BareImportVerdict,
        classify_bare_import
    }
    placement_pins --> jaclang.compiler.driver.boundary_classify.import_declares_native_target {
        effective_module_pin
    }
    placement_pins --> jaclang.compiler.driver.boundary_classify.module_demoted_native {
        module_native_demoted
    }
    placement_pins --> jaclang.compiler.driver.boundary_classify.native_only_import_target {
        effective_module_pin
    }
    placement_pins --> jaclang.compiler.driver.boundary_classify.plain_native_import_target {
        effective_module_pin,
        module_native_demoted
    }
    placement_pins --> jaclang.compiler.driver.compiler.JacCompiler.parse_str {
        config_kind_space as _kind_space_of,
        effective_module_pin as _mod_pin,
        native_demotion_code
    }
    placement_pins --> jaclang.compiler.driver.compiler.JacCompiler.stamp_boundary_facts {
        config_module_pin
    }
    placement_pins --> jaclang.compiler.driver.jir._project_env_fingerprint {
        config_kind_space,
        pins_digest
    }
    placement_pins --> jaclang.compiler.passes.static_analysis_pass.StaticAnalysisPass._check_client_imports {
        in_client_npm_world
    }
    placement_pins --> jaclang.compiler.placement.placement.module_anchor_reasons {
        config_module_pin
    }
    placement_pins --> jaclang.compiler.placement.placement.project_kind_name {
        config_project_kind
    }
    placement_pins --> jaclang.compiler.placement.placement.scan_native_blockers {
        config_module_pin as _cmp,
        config_pin_for
    }
    placement_pins --> jaclang.compiler.placement.placement.summarize_module {
        effective_pin_for
    }
    placement_pins --> jaclang.compiler.placement.placement_facts.native_unit {
        effective_module_pin
    }
    placement_pins --> jaclang.compiler.placement.placement_facts.pinned_module_space {
        config_module_pin
    }
    placement_pins --> jaclang.compiler.placement.placement_solver._module_externally_pinned {
        config_module_pin
    }
    placement_pins --> jaclang.compiler.placement.placement_solver._native_dep_scan {
        module_native_demoted
    }
    placement_pins --> jaclang.compiler.placement.placement_solver.native_default_verdict {
        module_native_demoted
    }
    placement_pins --> jaclang.lsp.server.engine.JacLangServer._module_spec_target {
        in_client_npm_world
    }
    placement_pins --> jaclang.lsp.server.engine.JacLangServer._npm_item_location {
        in_client_npm_world
    }
    placement_pins --> jaclang.scale.tests.microservices.test_app_precompile {
        config_module_pin
    }
    placement_solver --> jaclang.compiler.driver.boundary_classify.plain_native_import_target {
        _materialize_module
    }
    placement_solver --> jaclang.compiler.driver.compiler.JacCompiler.compile {
        invalidate_importers_es
    }
    placement_solver --> jaclang.compiler.driver.compiler.JacCompiler.parse_str {
        native_default_verdict
    }
    placement_solver --> jaclang.compiler.driver.na_coverage.na_coverage_begin {
        native_scan_memo_clear
    }
    placement_solver --> jaclang.compiler.driver.pipeline { PlacementApplyPass }
    placement_solver --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.placement {
        refresh_placement_module,
        solve_program_placement
    }
    placement_solver --> jaclang.compiler.frontend.codeinfo._inferred_native_path {
        native_default_path_ok
    }
    placement_solver --> jaclang.compiler.placement.placement_facts.declared_path_spaces {
        _materialize_module
    }
    placement_solver --> jaclang.compiler.placement.placement_facts.native_unit {
        native_default_path_ok
    }
    placement_solver --> jaclang.compiler.placement.placement_work.PlacementWork.drain {
        _pull_boundary_import
    }
    placement_solver --> jaclang.compiler.placement.placement_work.PlacementWork.refs {
        _ref_top_ids
    }
    placement_solver --> jaclang.dist.seal.bake_native_payloads {
        native_default_path_ok
    }
    placement_work --> jaclang.compiler.placement.placement_solver { PlacementWork }
}

impl import jaclang.compiler.tests {
    xbackend_equiv --> jaclang.compiler.tests.test_fixed_width_equivalence {
        call_py_fixture,
        compile_fixture_to_js,
        encode_py_wire,
        run_js_expr,
        run_js_function,
        run_py_fixture,
        run_with_both
    }
    xbackend_equiv --> jaclang.compiler.tests.test_graph_fragment_equivalence {
        run_js_module_fixture,
        run_py_fixture,
        run_with_both
    }
    xbackend_equiv --> jaclang.compiler.tests.test_native_list_search_equality {
        compile_native,
        get_func
    }
    xbackend_equiv --> jaclang.compiler.tests.test_osp_equivalence {
        compile_native,
        run_native_function,
        run_py_fixture,
        run_with_both
    }
    xbackend_equiv --> jaclang.compiler.tests.test_prim_equivalence {
        compare_results,
        compile_fixture_to_js,
        compile_native,
        compile_native_errors,
        get_func,
        run_js_function,
        run_py_fixture,
        run_with_both
    }
    xbackend_equiv --> jaclang.compiler.tests.test_shared_types_equivalence {
        run_with_both
    }
    xbackend_equiv --> jaclang.compiler.tests.test_socket_equivalence {
        compile_native,
        get_func,
        run_py_fixture
    }
    xbackend_equiv --> jaclang.compiler.tests.test_ssl_equivalence {
        compile_native,
        get_func,
        run_py_fixture
    }
    xbackend_equiv --> jaclang.compiler.tests.test_tarfile_equivalence {
        FIXTURES,
        get_func,
        remember_engine_unit,
        run_py_fixture
    }
    xbackend_equiv --> jaclang.compiler.tests.test_urllib_equivalence {
        compile_native,
        get_func,
        run_py_fixture
    }
    xbackend_equiv --> jaclang.compiler.tests.test_xbackend_equiv {
        run_js_expr,
        run_js_function
    }
    xbackend_equiv --> jaclang.compiler.tests.test_zstd_equivalence {
        FIXTURES,
        compare_results,
        remember_engine_unit,
        run_native_function,
        run_py_fixture
    }
}

impl import jaclang.compiler.tests.fixtures {
    fw_conformance --> jaclang.compiler.tests.test_fixed_width_equivalence { FwScope }
}

impl import jaclang.compiler.tools {
    code_intel --> jaclang.cli.commands.code { CodeIntelligence }
    code_intel --> jaclang.compiler.tests.test_code_intel { CodeIntelligence }
    comment_attach_pass --> jaclang.compiler.driver.pipeline.get_format_sched {
        CommentAttachPass
    }
    type doc_ir --> jaclang.compiler.frontend.codeinfo { Doc }
    doc_ir as doc --> jaclang.compiler.frontend.codeinfo.CodeGenTarget.doc_ir.getter;
    doc_ir as doc --> jaclang.compiler.tools.doc_ir_gen_pass;
    doc_ir as doc --> jaclang.compiler.tools.jac_formatter_pass;
    doc_ir_gen_pass --> jaclang.compiler.driver.pipeline.get_format_sched {
        DocIRGenPass
    }
    doc_ir_gen_pass --> jaclang.compiler.driver.pipeline.run_utility { DocIRGenPass }
    doc_ir_gen_pass --> jaclang.compiler.tools.jac_formatter_pass.format_module {
        DocIRGenPass
    }
    doc_ir_gen_pass --> jaclang.compiler.tools.lang_tools { DocIRGenPass }
    grammar_extract_pass --> jaclang.cli.commands.analysis.grammar {
        GrammarExtractPass
    }
    grammar_extract_pass --> jaclang.compiler.driver.pipeline.run_utility {
        GrammarExtractPass
    }
    jac_auto_lint_pass --> jaclang.compiler.driver.pipeline.get_analysis_sched {
        JacLintCheckPass
    }
    jac_auto_lint_pass --> jaclang.compiler.driver.pipeline.get_format_sched {
        JacAutoLintPass
    }
    jac_auto_lint_pass --> jaclang.compiler.driver.pipeline.get_lint_sched {
        JacLintCheckPass
    }
    jac_formatter_pass --> jaclang.compiler.driver.pipeline.get_format_sched {
        JacFormatPass
    }
    jac_formatter_pass --> jaclang.compiler.driver.pipeline.run_utility {
        JacFormatPass
    }
    jac_formatter_pass --> jaclang.compiler.tools.unparse_pass.unparse_module {
        format_module
    }
    lang_tools --> jaclang.cli.commands.tools.tool { AstTool }
    normalize_pass --> jaclang.compiler.driver.pipeline.run_utility { NormalizePass }
    normalize_pass --> jaclang.compiler.tools.unparse_pass.unparse_module {
        NormalizePass
    }
    reactive_use_walk --> jaclang.compiler.tools.jac_auto_lint_pass {
        ReactiveUseWalker
    }
    treeprinter --> jaclang.cli.mcp.compiler_bridge { node_to_dict, print_ast_tree }
    treeprinter --> jaclang.compiler.tools.lang_tools {
        print_ast_tree,
        print_symtab_tree,
        printgraph_ast_tree,
        printgraph_symtab_tree
    }
    unparse_pass --> jaclang.cli.commands.transform.py2jac { unparse_module }
    unparse_pass --> jaclang.cli.mcp.compiler_bridge { unparse_module }
    unparse_pass --> jaclang.compiler.backends.es.esast_gen_pass { unparse_node }
    unparse_pass --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._emit_unlowerable_type {
        unparse_node
    }
    unparse_pass --> jaclang.compiler.driver.pipeline.run_utility { UnparsePass }
    unparse_pass --> jaclang.compiler.passes.cfg_build_pass.CoalesceBBPass._node_label {
        unparse_node
    }
    unparse_pass --> jaclang.compiler.passes.endpoint_effect_pass.EndpointEffectPass._declaration_effects {
        unparse_node
    }
    unparse_pass --> jaclang.compiler.passes.endpoint_effect_pass.EndpointEffectPass._scan {
        unparse_node
    }
    unparse_pass --> jaclang.compiler.passes.layout_pass { unparse_node }
    unparse_pass --> jaclang.compiler.passes.mtir_gen_pass { unparse_node }
    unparse_pass --> jaclang.compiler.passes.variant_agreement_pass.annotation_text {
        unparse_node
    }
    unparse_pass --> jaclang.compiler.passes.wasm_contract.value_contract {
        unparse_node
    }
    unparse_pass --> jaclang.compiler.tools.code_intel { unparse_node }
    unparse_pass --> jaclang.compiler.tools.jac_auto_lint_pass { unparse_node }
    unparse_pass --> jaclang.compiler.tools.lang_tools { unparse_module }
    unparse_pass --> jaclang.dist.publish.dts { unparse_node }
    unparse_pass --> jaclang.dist.publish.jsdoc { unparse_node }
    unparse_pass --> jaclang.lsp.server.engine { unparse_node }
}

impl import jaclang.compiler.types {
    builtin_extensions --> jaclang.compiler.types.type_evaluator {
        install_builtin_extensions
    }
    ct_eval --> jaclang.compiler.types.type_evaluator { CtEvaluator }
    ct_value --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._instantiate_generic {
        ct_mangle
    }
    type ct_value --> jaclang.compiler.frontend.unitree { CtValue }
    ct_value --> jaclang.compiler.passes.type_checker_pass { CT_DEFERRED, CtValue }
    ct_value --> jaclang.compiler.types.ct_eval {
        CT_DEFERRED,
        CtDeferred,
        CtEnumMember,
        CtFunc,
        CtRecord,
        CtType,
        CtValue
    }
    ct_value --> jaclang.compiler.types.type_evaluator { CtValue }
    enum_utils --> jaclang.compiler.types.type_evaluator {
        build_enum_members,
        get_special_enum_value_type_from_bases
    }
    fixed_width --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._provably_in_range {
        interval_of_expr,
        interval_of_op
    }
    fixed_width --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._stamp_fixed_width {
        numeric_name_of
    }
    fixed_width --> jaclang.compiler.types.operations {
        arithmetic_result_type,
        both_numeric,
        folded_number,
        numeric_name_of,
        shift_result_type,
        unify_numeric_operands
    }
    fixed_width --> jaclang.compiler.types.type_evaluator {
        AssignVerdict,
        arithmetic_result_type,
        assign_numeric_expr,
        both_numeric,
        fixed_width_call_type,
        is_unsigned_type,
        unify_numeric_operands
    }
    fixed_width --> jaclang.compiler.types.type_evaluator.TypeEvaluator._extern_field_type {
        numeric_name_of
    }
    fixed_width --> jaclang.compiler.types.type_evaluator.TypeEvaluator._get_type_from_flow_node {
        numeric_name_of
    }
    operations --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._emit_arch_dunder_binop {
        BINARY_OPERATOR_MAP
    }
    operations --> jaclang.compiler.passes.type_checker_pass {
        ARITHMETIC_OPERATORS,
        AUG_OPERATOR_MAP,
        AUG_TO_BINARY_MAP,
        BINARY_OPERATOR_MAP,
        BITWISE_OPERATORS,
        COMPLEX_ARITH_OPS,
        SHIFT_OPERATORS,
        get_complex_arith_result_type,
        get_numeric_promotion_type,
        get_pow_result_type
    }
    operations --> jaclang.compiler.types.type_evaluator {
        BINARY_OPERATOR_MAP,
        get_type_of_binary_operation,
        is_annotation_type
    }
    ownership --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._view_arch_of_call {
        contains_borrow
    }
    properties --> jaclang.compiler.types.type_evaluator {
        is_cached_property_decorator_type,
        is_property_decorator_type
    }
    ts_decl_parser --> jaclang.compiler.tests.test_jac_mobui_typing { parse_dts }
    ts_decl_parser --> jaclang.compiler.types.type_evaluator {
        TsAccess,
        TsDecl,
        TsDeclKind,
        TsMember,
        TsType,
        TsTypeKind,
        ts_decl_binding_kind
    }
    ts_decl_parser --> jaclang.compiler.types.type_evaluator.TypeEvaluator._load_ts_declarations {
        parse_dts
    }
    type type_evaluator --> jaclang.compiler.driver.program { TypeEvaluator }
    type_evaluator --> jaclang.compiler.driver.program.JacProgram.get_type_evaluator {
        TypeEvaluator
    }
    type type_evaluator --> jaclang.compiler.passes.type_checker_pass { TypeEvaluator }
    type_evaluator --> jaclang.compiler.tests.test_jac_mobui_typing {
        FunctionType,
        UnknownType
    }
    type type_evaluator --> jaclang.compiler.types.ct_eval { TypeEvaluator }
    type type_evaluator --> jaclang.compiler.types.enum_utils {
        PrefetchedTypes,
        TypeEvaluator
    }
    type type_evaluator --> jaclang.compiler.types.fixed_width { TypeEvaluator }
    type type_evaluator --> jaclang.compiler.types.operations { TypeEvaluator }
    type type_evaluator --> jaclang.compiler.types.type_utils { TypeEvaluator }
    type_evaluator --> jaclang.dist.precompile_bytecode.precompile_unit_context;
    type_utils --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._expr_type_name {
        expr_primitive_name
    }
    type_utils --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._resolve_primitive_type_name {
        primitive_type_name_of
    }
    type_utils --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._try_primitive_op {
        expr_primitive_name
    }
    type_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._agg_key_args {
        primitive_type_name_of
    }
    type_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._container_class_name {
        primitive_type_name_of
    }
    type_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._is_boolean_result_expr {
        primitive_type_name_of
    }
    type_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._key_elem_unsigned {
        primitive_type_name_of
    }
    type_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._lower_coercion {
        primitive_type_name_of
    }
    type_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._match_subj_ty {
        convert_to_instance
    }
    type_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._scalar_shape {
        primitive_type_name_of
    }
    type_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._sort_key_orderable {
        primitive_type_name_of
    }
    type_utils --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._sort_key_unsigned {
        primitive_type_name_of
    }
    type_utils --> jaclang.compiler.passes.static_analysis_pass.StaticAnalysisPass._check_semantic_patterns {
        expr_primitive_name
    }
    type_utils --> jaclang.compiler.passes.type_checker_pass {
        BARE_GENERIC_REQUIRED,
        PropertyWriteKind,
        get_declared_generator_return_type,
        get_generator_yield_type,
        is_generator_family_type
    }
    type_utils --> jaclang.compiler.tests.test_property_write_kind { PropertyWriteKind }
    type_utils --> jaclang.compiler.types.ct_eval { lookup_symtab }
    type_utils --> jaclang.compiler.types.ownership {
        apply_solved_type_vars,
        build_type_var_solution
    }
    type_utils --> jaclang.compiler.types.stubcat.writer.CatalogWriter.property_facts {
        PropertyWriteKind
    }
    type_utils --> jaclang.compiler.types.type_evaluator {
        ClassMember,
        ParamAssignmentTracker,
        PropertyWriteKind,
        PropertyWriteResult,
        apply_solved_type_vars,
        build_type_var_solution,
        class_implements_protocol,
        collect_member_syms,
        compute_module_source_flags,
        compute_mro_linearization,
        convert_to_instance,
        get_declared_generator_return_type,
        is_generator_family_type,
        lookup_symtab,
        shadowed_type_var_names,
        specialize_for_base_class,
        synthesize_self_type_var
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._apply_function_decorators {
        apply_solved_type_vars
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._classify_property_symbol {
        PropertyWriteKind
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._get_getattr_return_type {
        collect_member_syms
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._get_type_of_expression_core {
        PropertyWriteKind,
        synthesize_self_type_var
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._heal_ancestry {
        ensure_mro_fresh
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._heal_class_bases {
        linearize_mro,
        mro_signature
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._lookup_class_member {
        ensure_mro_fresh
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._super_owner_for {
        collect_member_syms
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator._type_in_list {
        types_equivalent
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator.get_getter_type_from_property {
        PropertyWriteKind
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator.get_property_write_type {
        PropertyWriteKind,
        PropertyWriteResult
    }
    type_utils --> jaclang.compiler.types.type_evaluator.TypeEvaluator.is_sub_class {
        ensure_mro_fresh
    }
    type_utils --> jaclang.compiler.types.types.ClassType.lookup_member_symbol {
        collect_member_syms,
        ensure_mro_fresh
    }
    type_utils --> jaclang.compiler.types.types.FunctionType.specialize {
        apply_solved_type_vars,
        build_type_var_solution
    }
    type_utils --> jaclang.compiler.types.types.FunctionType.specialize_func_type_vars {
        apply_solved_type_vars
    }
    type_utils --> jaclang.lsp.server.utils { compute_mro_linearization }
    types --> jaclang.compiler.backends.es.esast_gen_pass { ClassType, TypeBase }
    types --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._arch_kind_of_type {
        ClassType
    }
    types --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._exit_name_impl {
        ClassType as _ClassType
    }
    types --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._field_constructor_args {
        ClassType
    }
    types --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._osp_expr_arch_name {
        ClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass {
        ClassType,
        FunctionType as SemanticFunctionType,
        ModuleType,
        Parameter,
        TypeBase,
        UnionType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._agg_key_args {
        ClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._aos_elem_name {
        ClassType as _AeClassType,
        TypeVarType as _AeTypeVarType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._apply_flow_narrowing {
        ClassType as _ClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._c_scalar_llvm {
        ClassType as _CClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._codegen_archetype {
        FunctionType as _ClibFnType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._container_class_name {
        ClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._elem_arch_name_of {
        ClassType as _ClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._elem_storage_llvm {
        ClassType as _EsClassType,
        UnionType as _EsUnionType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._enum_name_of {
        ClassType as EnumClassType,
        EnumMemberType,
        TypeBase,
        UnionType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._enum_union_tags {
        ClassType as _EnClassType,
        EnumMemberType as _EnMemberType,
        UnionType as _EnUnionType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._erased_seq_type {
        ClassType as _EsqClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._erased_typevar_names {
        TypeVarType as _EtvTypeVarType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._exception_handler_ids {
        ClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._foreign_optional_field {
        ClassType as _FofClassType,
        TypeVarType as _FofTypeVarType,
        UnionType as _FofUnionType,
        UnknownType as _FofUnknownType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._instantiate_generic_for_target {
        FunctionType as _A5FnType,
        TypeVarType as _A5TypeVar
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._is_runtime_class_tuple {
        ClassType as _SeqClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._isinstance_abc_reduction {
        ClassType as _AbcClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._lower_type {
        AnyType as _AnyType,
        ClassType as _ClassType,
        EnumMemberType as _EnumMemberType,
        FunctionType as _FunctionType,
        NeverType as _NeverType,
        TypeVarType as _TypeVarType,
        UnionType as _UnionType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._lower_view_container {
        ClassType as _VcClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._opt_sole_member {
        ClassType as _OsClassType,
        UnionType as _OsUnionType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._osp_disc_list_operand {
        ClassType as _DiscClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._resolve_field_type {
        TypeVarType as _RfTypeVarType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._solve_generic_call {
        ClassType as _CT,
        TypeVarType as _TVT,
        UnionType as _UT
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._sort_key_orderable {
        ClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._sort_key_return_type {
        FunctionType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._spec_union_agreement {
        ClassType as _SuClassType,
        UnionType as _SuUnionType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._syntactic_bind_type_params {
        ClassType as _SbCT
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._type_base_is_unknown {
        UnknownType as _UnknownType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._typevar_optional_field {
        ClassType as _TvoClassType,
        TypeVarType as _TvoTypeVarType,
        UnionType as _TvoUnionType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._unbox_narrowed_member {
        ClassType as _ClassType
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._variadic_tuple_seq_type {
        UnknownType as _VtUnknown
    }
    types --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._widened_tuple_decl_type {
        ClassType as _WdClassType
    }
    types --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._clib_block_desc {
        FunctionType
    }
    types --> jaclang.compiler.c_interop.c_type_arg { AnyType, ClassType, UnknownType }
    types --> jaclang.compiler.c_interop.c_type_spec {
        ClassType,
        FunctionType,
        UnionType
    }
    types --> jaclang.compiler.c_interop.is_builtin_pin_call { FunctionType }
    types --> jaclang.compiler.expr_keys.is_builtin_region_type { ClassType }
    type types --> jaclang.compiler.frontend.relations {
        ClassDetailsPrivate,
        ClassDetailsShared,
        ClassType,
        EnumMemberInfo,
        EnumMemberType,
        FunctionType,
        ModuleType,
        OverloadedType,
        Parameter,
        TypeBase,
        TypeVarType,
        UnionType
    }
    type types --> jaclang.compiler.frontend.unitree { TypeBase }
    types --> jaclang.compiler.frontend.unitree.DeleteStmt.type_has_graph_member {
        ClassType,
        TypeVarType,
        UnionType
    }
    types --> jaclang.compiler.frontend.unitree.DeleteStmt.type_may_hold_graph {
        ClassType,
        UnionType
    }
    types --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass.enter_atom_trailer {
        ClassType
    }
    type types --> jaclang.compiler.passes.layout_pass { TypeBase }
    types --> jaclang.compiler.passes.layout_pass.LayoutPass._is_layout_compatible_semantic_type {
        ClassType,
        FunctionType,
        UnionType
    }
    types --> jaclang.compiler.passes.layout_pass.class_form_enum_member {
        EnumMemberType as _EnumMemberType
    }
    types --> jaclang.compiler.passes.layout_pass.class_type_native_name { ClassType }
    types --> jaclang.compiler.passes.layout_pass.declaring_module_path { ClassType }
    types --> jaclang.compiler.passes.layout_pass.is_enum_class_type {
        ClassType as _ClassType
    }
    types --> jaclang.compiler.passes.layout_pass.native_type_key {
        ClassType,
        FunctionType,
        OverloadedType,
        UnionType
    }
    types --> jaclang.compiler.passes.layout_pass.referenced_archetype { ClassType }
    types --> jaclang.compiler.passes.ownership_check_pass { FunctionType }
    types --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._emit_place_intrinsic_diagnostics {
        ClassType,
        TypeBase,
        UnionType
    }
    types --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._handled_by_enclosing_try {
        ClassType
    }
    types --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._nogc_infer_locals {
        AnyType
    }
    types --> jaclang.compiler.passes.ownership_check_pass.OwnershipCheckPass._view_arch_of_call {
        ClassType
    }
    types --> jaclang.compiler.passes.ownership_check_pass._is_class_object {
        ClassType
    }
    types --> jaclang.compiler.passes.type_checker_pass {
        AnyType,
        ClassType,
        FunctionType,
        ModuleType,
        TypeBase,
        TypeVarType,
        UnionType,
        UnknownType
    }
    types --> jaclang.compiler.passes.type_checker_pass.TypeCheckPass._install_client_state_setters {
        create_callable_type
    }
    types --> jaclang.compiler.passes.wasm_contract.check_host_call {
        ClassType,
        FunctionType
    }
    types --> jaclang.compiler.symbol_utils.imported_module_name { ModuleType }
    types --> jaclang.compiler.tests.test_stubcat_roundtrip {
        ClassType,
        FunctionType,
        OverloadedType
    }
    types --> jaclang.compiler.types.builtin_extensions {
        ClassType,
        FunctionType,
        FunctionTypeFlags,
        ParamKind,
        Parameter,
        ParameterCategory,
        TypeBase
    }
    types --> jaclang.compiler.types.ct_eval {
        ClassType,
        ModuleType,
        TypeBase,
        UnknownType
    }
    type types --> jaclang.compiler.types.ct_value { ClassType, TypeBase }
    types --> jaclang.compiler.types.enum_utils { ClassType, EnumMemberInfo, TypeBase }
    types --> jaclang.compiler.types.fixed_width {
        AnyType,
        ClassType,
        TypeBase,
        UnionType,
        UnknownType
    }
    types --> jaclang.compiler.types.operations {
        AnyType,
        ClassType,
        FunctionType,
        NeverType,
        TypeBase,
        TypeVarType,
        UnionType,
        UnknownType
    }
    types --> jaclang.compiler.types.ownership { ClassType, TypeBase, UnionType }
    types --> jaclang.compiler.types.properties { ClassType, TypeBase }
    types --> jaclang.compiler.types.stubcat.reader {
        AnyType,
        ClassDetailsPrivate,
        ClassDetailsShared,
        ClassType,
        EnumMemberInfo,
        EnumMemberType,
        FunctionType,
        ModuleType,
        NeverType,
        OverloadedType,
        ParamKind,
        Parameter,
        ParameterCategory,
        TypeBase,
        TypeFlags,
        TypeVarType,
        UnionType,
        UnknownType
    }
    types --> jaclang.compiler.types.stubcat.writer {
        AnyType,
        ClassDetailsShared,
        ClassType,
        EnumMemberInfo,
        EnumMemberType,
        FunctionType,
        ModuleType,
        NeverType,
        OverloadedType,
        Parameter,
        TypeBase,
        TypeVarType,
        UnionType,
        UnknownType
    }
    types --> jaclang.compiler.types.type_evaluator {
        AnyType,
        ClassDetailsPrivate,
        ClassDetailsShared,
        ClassType,
        EnumMemberInfo,
        EnumMemberType,
        FunctionType,
        FunctionTypeFlags,
        ModuleType,
        NeverType,
        OverloadedType,
        ParamKind,
        Parameter,
        ParameterCategory,
        TypeBase,
        TypeCategory,
        TypeFlags,
        TypeVarType,
        UnionType,
        UnknownType,
        create_callable_type
    }
    types --> jaclang.compiler.types.type_evaluator.TypeEvaluator._extern_field_type {
        create_callable_type
    }
    types --> jaclang.compiler.types.type_utils {
        AnyType,
        ClassType,
        EnumMemberType,
        FunctionType,
        NeverType,
        ParamKind,
        Parameter,
        TypeBase,
        TypeVarType,
        UnionType,
        UnknownType
    }
    types --> jaclang.lsp.server.engine {
        ClassType,
        FunctionType,
        ModuleType,
        OverloadedType,
        TypeBase
    }
    types --> jaclang.lsp.server.utils { ClassType, ModuleType, TypeBase }
}

impl import jaclang.compiler.types.stubcat {
    build as catalog_build --> jaclang.compiler.tests.test_stubcat_roundtrip;
    build --> jaclang.compiler.tests.test_stubcat_roundtrip { build_catalog }
    build --> jaclang.compiler.types.stubcat.locate._build_dev_catalog { build_catalog }
    format --> jaclang.compiler.driver.compiler.JacCompiler.ensure_stub_catalog;
    format --> jaclang.compiler.types.stubcat.locate { FORMAT_VERSION }
    format --> jaclang.compiler.types.stubcat.reader {
        ACCESS_PRIVATE,
        ACCESS_PROTECTED,
        Cursor,
        Header,
        LIT_BOOL,
        LIT_INT,
        LIT_STR,
        MOD_EXTERNAL,
        PM_CLS,
        PM_COMPTIME,
        PM_HAS_DEFAULT,
        PM_SELF,
        SC_MODULE,
        SH_BUILTIN,
        SH_DATACLASS,
        SH_ENUM,
        SH_NAMEDTUPLE,
        SH_ROOT,
        SH_STDLIB,
        SH_TYPEDDICT,
        SH_XREF,
        SYMF_FINAL,
        SYMF_NA_ESCAPES,
        SYMF_NA_REGION_HANDLE,
        SYMF_NA_STACK_OK,
        SYMF_PARAM_REBOUND,
        SYMF_READONLY,
        TV_CLASS_PARAM,
        TV_CONTRAVARIANT,
        TV_COVARIANT,
        TV_PARAM_SPEC,
        TV_SELF,
        TY_ANY,
        TY_CLASS,
        TY_ENUM_MEMBER,
        TY_FUNCTION,
        TY_MODULE,
        TY_NEVER,
        TY_OVERLOAD,
        TY_TYPEVAR,
        TY_UNION,
        TY_UNKNOWN,
        unpack_header
    }
    format --> jaclang.compiler.types.stubcat.writer {
        ACCESS_PRIVATE,
        ACCESS_PROTECTED,
        ACCESS_PUBLIC,
        ARCH_CLASS,
        ARCH_ENUM,
        ARCH_NONE,
        ARCH_OBJ,
        HEADER_SIZE,
        Header,
        LIT_BOOL,
        LIT_INT,
        LIT_NONE,
        LIT_STR,
        MOD_EXTERNAL,
        MOD_JAC_INTERNAL,
        MOD_TYPESHED,
        PM_CLS,
        PM_COMPTIME,
        PM_HAS_DEFAULT,
        PM_SELF,
        SC_CLASS,
        SC_FUNCTION,
        SC_MODULE,
        SC_OTHER,
        SH_BUILTIN,
        SH_DATACLASS,
        SH_ENUM,
        SH_NAMEDTUPLE,
        SH_ROOT,
        SH_STDLIB,
        SH_TYPEDDICT,
        SH_XREF,
        SYMF_DEFER,
        SYMF_FINAL,
        SYMF_HAS_DEFAULT,
        SYMF_INSTANCE_METHOD,
        SYMF_NA_ESCAPES,
        SYMF_NA_REGION_HANDLE,
        SYMF_NA_STACK_OK,
        SYMF_PARAM_REBOUND,
        SYMF_READONLY,
        TV_CLASS_PARAM,
        TV_CONTRAVARIANT,
        TV_COVARIANT,
        TV_PARAM_SPEC,
        TV_SELF,
        TY_ANY,
        TY_CLASS,
        TY_ENUM_MEMBER,
        TY_FUNCTION,
        TY_MODULE,
        TY_NEVER,
        TY_OVERLOAD,
        TY_TYPEVAR,
        TY_UNION,
        TY_UNKNOWN,
        pack_header,
        put_ref,
        put_refs,
        put_svar,
        put_uvar
    }
    format --> jaclang.compiler.types.type_evaluator.TypeEvaluator._is_unbound_method_call {
        SYMF_INSTANCE_METHOD
    }
    format --> jaclang.compiler.types.type_evaluator.TypeEvaluator._merge_catalog_field_params {
        SYMF_DEFER,
        SYMF_HAS_DEFAULT
    }
    locate --> jaclang.compiler.driver.compiler.JacCompiler.compile {
        StubCatalogUnavailable
    }
    locate --> jaclang.compiler.driver.compiler.JacCompiler.ensure_stub_catalog {
        ensure_catalog
    }
    locate --> jaclang.compiler.driver.ifacecache.IfaceRegistry._pkg_dir {
        jaclang_pkg_dir
    }
    locate --> jaclang.compiler.tests.test_stubcat_roundtrip {
        ENV_FILE,
        jaclang_pkg_dir,
        reset_catalog_cache,
        typeshed_stdlib_dir
    }
    locate --> jaclang.compiler.types.stubcat.build {
        ENV_BUILDING,
        catalog_key,
        jac_internal_stub_dir,
        jaclang_pkg_dir,
        typeshed_stdlib_dir
    }
    modiface --> jaclang.compiler.driver.ifacecache.IfaceRegistry._encode_iface {
        IncoherentInterface
    }
    modiface --> jaclang.dist.precompile_bytecode.precompile_unit_context;
    type reader --> jaclang.compiler.driver.compiler { StubCatalog }
    reader --> jaclang.compiler.driver.compiler.JacCompiler.ensure_stub_catalog;
    type reader --> jaclang.compiler.driver.program { StubCatalog }
    reader --> jaclang.compiler.tests.test_stubcat_roundtrip {
        StubCatalog,
        open_catalog_file
    }
    reader --> jaclang.compiler.types.stubcat.build;
    type reader --> jaclang.compiler.types.stubcat.locate { StubCatalog }
    reader --> jaclang.compiler.types.stubcat.locate._open_file { open_catalog_file }
    reader --> jaclang.compiler.types.stubcat.locate._open_region {
        open_catalog_region
    }
    reader --> jaclang.compiler.types.stubcat.modiface { StubCatalog }
    type reader --> jaclang.compiler.types.type_evaluator { CatScope, StubCatalog }
    reader --> jaclang.compiler.types.type_evaluator.TypeEvaluator._build_field_params {
        CatScope
    }
    reader --> jaclang.compiler.types.type_evaluator.TypeEvaluator._merge_catalog_field_params {
        CatProvider
    }
    reader --> jaclang.compiler.types.type_evaluator.TypeEvaluator._metaclass_of {
        CatScope
    }
    reader --> jaclang.compiler.types.type_evaluator.TypeEvaluator._scope_has_fields {
        CatScope
    }
    reader --> jaclang.compiler.types.types.ClassType.get_class_symbol { CatScope }
    reader --> jaclang.compiler.types.types._class_scope_category { CatScope }
    writer --> jaclang.compiler.types.stubcat.build { CatalogWriter }
    writer --> jaclang.compiler.types.stubcat.modiface { CatalogWriter }
}

impl import jaclang.data {
    dbcatalog --> jaclang.cli.commands.db { DbRecord, MAINTENANCE_DB }
    dbcatalog --> jaclang.cli.commands.db._db_drop { is_jac_database }
    dbcatalog --> jaclang.cli.commands.db._db_prune {
        condemn_abandoned,
        connect_admin,
        drop_database,
        drop_if_still_dead,
        list_databases,
        pardon_recovered
    }
    dbcatalog --> jaclang.cli.commands.db._prune_candidates { holds_no_data }
    dbcatalog --> jaclang.cli.commands.db._runtime_for | jaclang.data.pgembed { DbKind }
    type dbcatalog --> jaclang.data.pgembed { DbRecord }
    dbcatalog --> jaclang.data.pgembed.PgRuntime._ensure_database {
        connect_admin,
        record_database,
        start_heartbeat
    }
    dbcatalog --> jaclang.data.pgembed.PgRuntime._reap {
        condemn_abandoned,
        drop_if_still_dead,
        orphan_grace_seconds,
        pardon_recovered,
        reclaimable_databases
    }
    dbcatalog --> jaclang.data.pgembed.PgRuntime._reap_scratch {
        SCRATCH_PREFIX,
        list_databases
    }
    dbcatalog --> jaclang.data.pgembed.PgRuntime._sweep_on_start {
        connect_admin,
        drop_database,
        expired_databases,
        list_databases
    }
    dbcatalog --> jaclang.data.pgembed.PgRuntime.databases {
        connect_admin,
        list_databases
    }
    dbcatalog --> jaclang.data.pgembed.PgRuntime.drop_database {
        connect_admin,
        drop_database as catalog_drop
    }
    dbcatalog --> jaclang.server.session {
        DbKind,
        MAINTENANCE_DB,
        SCRATCH_PREFIX,
        stop_heartbeat
    }
    dbcatalog --> jaclang.server.session.drop_owned_databases {
        connect_admin,
        drop_database,
        owned_databases
    }
    dbcatalog --> jaclang.server.session.own_child_databases {
        process_alive,
        this_host
    }
    pgembed --> jaclang.cli.commands.db._catalog_runtime { PgRuntime }
    pgembed --> jaclang.cli.commands.db._db_fetch { PgRuntime, dist_cache_dir }
    pgembed --> jaclang.cli.commands.db._runtime_for { PgRuntime }
    pgembed --> jaclang.scale.deploy.database.kubernetes_postgres.KubernetesPostgresProvider.deploy {
        pg_tuning_settings
    }
    pgembed --> jaclang.scale.tests.data.test_auth_cutover { PgRuntime }
    pgembed --> jaclang.scale.tests.data.test_pg_stream { PgRuntime }
    pgembed --> jaclang.scale.tests.deploy.test_postgres_predicate_lock_headroom {
        PG_MAX_CONNECTIONS,
        PG_MAX_PRED_LOCKS_PER_TXN,
        PgRuntime,
        pg_tuning_settings
    }
    pgembed --> jaclang.scale.tests.server.test_backplane { PgRuntime }
    pgembed --> jaclang.scale.tests.server.test_pg_job_store { PgRuntime }
    pgembed --> jaclang.scale.tests.server.test_registration_limits { PgRuntime }
    pgembed --> jaclang.scale.tests.server.test_scheduler_multipod { PgRuntime }
    pgembed --> jaclang.server.session { PgRuntime }
    pgembed --> jaclang.server.session.shared_pg_data_dir { dist_cache_dir }
    pgload --> jaclang.data.dbcatalog.connect_admin { connect }
    pgload --> jaclang.data.dbcatalog.holds_no_data { connect }
    pgload --> jaclang.data.pgembed.PgRuntime._wait_ready { connect }
    pgload --> jaclang.data.store.PgStore._connect { connect as pg_connect }
    pgpool --> jaclang.data.store.PgStore._connect { checkout }
    pgpool --> jaclang.data.store._park_conn { pool_enabled, release }
    pgpool --> jaclang.runtime.runtime.JacRuntime.after_fork_in_child { detach }
    pgpool --> jaclang.server.shared_store._after_fork_in_child { detach }
    pgwire --> jaclang.cli.errmap.humanize_error { PgWireError }
    pgwire --> jaclang.data.store { PgWireError }
    pgwire --> jaclang.data.store.PgStore._run { PgWireError }
    pgwire --> jaclang.scale.server.jobs_ext { PgWireError }
    pgwire --> jaclang.scale.tests.server.test_health_fail_soft { PgWireError }
    pgwire --> jaclang.scale.tests.server.test_scheduler_endpoints { PgWireError }
    query_planner --> jaclang.runtime.runtime.JacGraph.refs {
        LazyRefs,
        resolve_query,
        resolve_query_edges
    }
    schema_rules --> jaclang.data.serializer.Serializer._deserialize_archetype {
        ATTIC_KEY,
        REPAIRS_ATTR,
        repair_mode
    }
    schema_rules --> jaclang.data.serializer.Serializer._serialize_attrs {
        merged_rules_for,
        repair_mode
    }
    schema_rules --> jaclang.data.serializer.Serializer.register { collect_rules }
    schema_rules --> jaclang.data.serializer.Serializer.repair {
        apply_rules,
        merged_rules_for,
        repair_mode
    }
    schema_rules --> jaclang.data.serializer.Serializer.serialize_fields {
        merged_rules_for,
        repair_mode
    }
    schema_rules as _rules --> jaclang.runtime.builtin._get_schema_builder.builder;
    serializer --> jaclang.compiler.tests.test_fixed_width_equivalence { Serializer }
    serializer --> jaclang.compiler.tests.xbackend_equiv.encode_py_wire { Serializer }
    serializer --> jaclang.runtime.builtin._get_archetype_alias.factory.decorator {
        Serializer
    }
    serializer --> jaclang.server.endpoints.walkers { Serializer }
    serializer --> jaclang.server.server { Serializer }
    serializer --> jaclang.server.session.Session._evict_uncommitted { Serializer }
    serializer --> jaclang.server.session.Session._flush_locked { Serializer }
    serializer --> jaclang.server.session.Session._load_edges { Serializer }
    serializer --> jaclang.server.session.Session._materialize { Serializer }
    serializer --> jaclang.server.session.Session._serialize { Serializer }
    serializer --> jaclang.server.session.Session.flush { Serializer }
    serializer --> jaclang.server.session._persist_hash { Serializer }
    sqlcompile --> jaclang.data.query_planner { compile_query }
    storage --> jaclang.runtime.runtime.JacPersistence.store { LocalStorage }
    storage --> jaclang.scale.plugin { Storage }
    type storage --> jaclang.scale.runtime.provider { Storage }
    storage --> jaclang.scale.storage.factory { Storage }
    storage --> jaclang.scale.storage.factory.StorageFactory.create { LocalStorage }
    storage --> jaclang.scale.tests.data.test_s3_storage { Storage }
    storage --> jaclang.scale.tests.data.test_storage { LocalStorage }
    store --> jaclang.cli.commands.db { TxnIsolation }
    store --> jaclang.cli.commands.db._open_project_store { PgStore }
    store --> jaclang.cli.commands.db._open_store { PgStore }
    store --> jaclang.cli.errmap.humanize_error { SessionConflictError }
    store --> jaclang.data.dbcatalog { ConnInfo, SCHEMA_STAMP_KEY }
    store --> jaclang.data.pgembed { ConnInfo }
    store --> jaclang.data.sqlcompile { Store }
    store --> jaclang.scale.events.streams.postgres { TxnIsolation }
    store --> jaclang.scale.events.streams.postgres.PgEventStream._ensure_store {
        PgStore
    }
    store --> jaclang.scale.memory.context.JScaleExecutionContext.init { PgStore }
    store --> jaclang.scale.scheduler.scheduler { TxnIsolation }
    store --> jaclang.scale.scheduler.scheduler.PgJobStore._quota_connection { PgStore }
    store --> jaclang.scale.tests.data.test_auth_cutover { PgStore }
    store --> jaclang.scale.tests.data.test_pg_stream { PgStore }
    store --> jaclang.scale.tests.server.test_backplane { PgStore }
    store --> jaclang.scale.tests.server.test_pg_job_store { PgStore }
    store --> jaclang.scale.tests.server.test_registration_limits { PgStore }
    store --> jaclang.scale.tests.server.test_scheduler_multipod { PgStore }
    store --> jaclang.server.outbox { OUTBOX_SCHEMA_SQL, PgStore, Store, TxnIsolation }
    store --> jaclang.server.session {
        AnchorRow,
        ConnInfo,
        PgStore,
        Store,
        TxnIsolation
    }
    store --> jaclang.server.shared_store.shared_store { PgStore }
}

impl import jaclang.data.storage {
    local_storage --> jaclang.data.storage { LocalStorage }
    local_storage --> jaclang.scale.tests.data.test_s3_storage { LocalStorage }
    storage --> jaclang.data.storage { Storage }
    storage --> jaclang.data.storage.local_storage { Storage }
    storage --> jaclang.scale.storage.bucket_storage { Storage }
}

impl import jaclang.dist {
    fused_binary --> jaclang.cli.commands.cache._live_keys { running_runtime_entries }
    fused_binary --> jaclang.cli.commands.project._bundle_binary {
        append_overlay,
        has_runtime
    }
    fused_binary --> jaclang.client.targets.desktop.desktop_build._bundle_runtime {
        graft_runtime
    }
    fused_binary --> jaclang.compiler.backends.native.floor.resolve_floor_dir {
        bundled_floor_roots
    }
    fused_binary --> jaclang.compiler.backends.native.static_link.musl_lib_dir {
        bundled_floor_roots
    }
    fused_binary --> jaclang.compiler.backends.native.wasm_build._wasm_libc_dir {
        bundled_floor_roots
    }
    jab --> jaclang.cli.cli_boot._run_bundled_app { materialize_jab_bytes }
    jab --> jaclang.cli.commands.execution._run_jab { materialize_jab }
    jab --> jaclang.cli.commands.execution.run_jab_image { jab_app_meta }
    jab --> jaclang.cli.commands.project._bundle_binary { jab_app_meta }
    jab --> jaclang.client.targets.desktop.native.host_boot.resolve_program {
        jab_app_meta,
        materialize_jab
    }
    jab_vendor --> jaclang.dist.jab { activate_vendored }
    jab_vendor --> jaclang.dist.seal.vendor_jab_deps {
        download_wheels,
        wheels_dir,
        write_vendor_manifest
    }
    jab_vendor --> jaclang.scale.tests.microservices.test_fat_bundle {
        WheelTarget,
        download_wheels
    }
    jab_vendor --> jaclang.scale.utils.vendor_wheels {
        WheelTarget,
        download_wheels,
        wheels_dir,
        write_vendor_manifest
    }
    native_product --> jaclang.dist.publish.runtime_vendor._compile_runtime_module {
        write_native_product
    }
    native_product --> jaclang.dist.source.project._write_application {
        write_native_product
    }
    native_product --> jaclang.dist.source.project.export_project {
        write_native_product
    }
    precompile_bytecode --> jaclang.cli.commands.precompile.precompile {
        run_precompile
    }
    precompile_bytecode --> jaclang.dist.seal.resolve_entry_file { bundle_app }
    precompile_bytecode as precompiler --> jaclang.scale.tests.microservices.test_app_precompile;
    precompile_bytecode --> jaclang.scale.tests.microservices.test_app_precompile {
        main as seal_main,
        placement_facts_map,
        sealable_sources
    }
    seal --> jaclang.cli.commands.project {
        build_jab,
        make_sealed_image as _make_sealed_image,
        run_precompiler as _run_precompiler,
        tar_gz_dir as _tar_gz_dir,
        vendor_jab_deps as _vendor_jab_deps
    }
    seal --> jaclang.client.targets.desktop.desktop_build.stage_program { build_jab }
}

impl import jaclang.dist.fused {
    _libc --> jaclang.dist.fused.embed { c_alloc_string, c_string, peek, poke }
    _libc --> jaclang.dist.fused.materialize { getuid, listdir, read_at, write_file }
    embed --> jaclang.dist.fused.bringup { Embed, open_tree }
    materialize --> jaclang.dist.fused.bringup { materialize }
    report --> jaclang.dist.fused.bringup | jaclang.dist.fused.embed { die }
    report --> jaclang.dist.fused.materialize { die, say }
    trailer --> jaclang.dist.fused.materialize {
        MAGIC,
        OVERLAY_MAGIC,
        REGION_DESC_LEN,
        TRAILER_LEN,
        Trailer,
        parse_region_desc,
        parse_trailer,
        region_start,
        rt_key
    }
    trailer --> jaclang.dist.fused_binary {
        MAGIC,
        OVERLAY_MAGIC,
        TRAILER_LEN,
        Trailer,
        build_trailer,
        parse_trailer,
        region_start,
        rt_key
    }
    trailer --> jaclang.dist.payload.pack {
        MAGIC,
        REGION_ALIGN,
        REGION_DESC_LEN,
        TRAILER_LEN,
        build_region_desc,
        build_trailer
    }
}

impl import jaclang.dist.payload {
    assemble --> jaclang.dist.payload.cli { MkPayloadOpts, mk_payload }
    assemble --> jaclang.dist.payload.cli.dispatch { resolve_python, run_stubcat }
    cli --> jaclang.dist.payload { main }
    fetch --> jaclang.dist.payload.assemble { TYPESHED_VENDOR, fetch_typeshed }
    fetch --> jaclang.dist.payload.cli {
        fetch_bun,
        fetch_llvm,
        fetch_typeshed,
        typeshed_sha
    }
    fsutil --> jaclang.dist.payload.assemble {
        PayloadDie,
        clone_env,
        copy_file,
        copy_into,
        copy_tree,
        delete_file,
        delete_tree,
        die,
        file_exists,
        host_os_arch,
        log,
        make_dirs,
        read_bytes,
        run_child,
        sha256_hex,
        skip_jaclang,
        skip_none,
        skip_site_template,
        skip_stage_site,
        source_file_mode,
        strip_best_effort,
        toml_string,
        walk_sorted,
        write_bytes,
        write_text
    }
    fsutil --> jaclang.dist.payload.cli { PayloadDie, die }
    fsutil --> jaclang.dist.payload.fetch {
        PayloadDie,
        copy_file,
        copy_tree,
        delete_tree,
        die,
        extract_tar,
        file_exists,
        find_sum_line,
        host_os_arch,
        log,
        make_dirs,
        rd_u16,
        rd_u32,
        read_trimmed,
        sha256_hex,
        skip_typeshed_tests,
        write_bytes,
        write_text
    }
    fsutil --> jaclang.dist.payload.pack {
        die,
        read_bytes,
        sha256_hex,
        strip_best_effort
    }
    fsutil --> jaclang.dist.payload.pins { die }
    fsutil --> jaclang.dist.payload.vendor {
        clone_env,
        copy_file,
        delete_file,
        delete_tree,
        die,
        file_exists,
        log,
        make_dirs,
        mtime_ns,
        read_bytes,
        run_child,
        sha256_hex,
        walk_sorted,
        write_text
    }
    pack --> jaclang.dist.payload.cli { pack }
    pins --> jaclang.dist.payload.assemble { py_ver }
    pins --> jaclang.dist.payload.cli { host_py_minor, py_ver }
    pins --> jaclang.dist.payload.fetch { LlvmSlice, llvm_release, pins }
    vendor --> jaclang.dist.payload.assemble { MUSL_ARTIFACTS }
    vendor --> jaclang.dist.payload.cli { build_musl, build_wasm_libc }
}

impl import jaclang.dist.publish {
    builder --> jaclang.cli.commands.project._bundle_wheel { WheelBuilder }
    builder --> jaclang.cli.commands.project.install { WheelBuilder }
    builder --> jaclang.dist.publish { WheelBuilder }
    dts --> jaclang.dist.publish.npm_sources { dts_for_module }
    jsdoc --> jaclang.dist.publish.dts { jac_type_to_ts }
    jsdoc --> jaclang.dist.publish.npm_sources { inject_jsdoc, jsdoc_for_module }
    metadata --> jaclang.dist.publish { generate_metadata, normalize_package_name }
    metadata --> jaclang.dist.publish.builder {
        generate_metadata,
        generate_pyproject_toml
    }
    metadata --> jaclang.dist.publish.package_json { normalize_package_name }
    metadata --> jaclang.dist.publish.wheel_meta { normalize_package_name }
    npm_builder --> jaclang.cli.commands.project._bundle_npm { NpmBuilder }
    npm_sources --> jaclang.cli.commands.project._bundle_npm { NpmBoundaryError }
    npm_sources --> jaclang.dist.publish.npm_builder {
        collect_npm_sources,
        resolve_npm_entry,
        runtime_pkg_name
    }
    npm_tarball --> jaclang.dist.publish.npm_builder { pack_tarball }
    npm_tarball --> jaclang.dist.publish.runtime_npm { pack_tarball }
    package_json --> jaclang.dist.publish.npm_builder {
        generate_package_json,
        npm_tarball_filename
    }
    py_imports --> jaclang.dist.publish.builder { rewrite_imports, wheel_module_name }
    record --> jaclang.dist.publish.builder {
        RecordEntry,
        generate_record,
        record_entry_from_bytes
    }
    runtime_npm --> jaclang.cli.commands.project._bundle_npm_runtime {
        build_runtime_to,
        runtime_pkg_name
    }
    runtime_npm --> jaclang.dist.publish.npm_sources { runtime_api_names }
    runtime_vendor --> jaclang.dist.publish.builder {
        build_runtime_closure,
        scan_jaclang_imports
    }
    runtime_vendor --> jaclang.dist.source.project.export_project { vendor_runtime }
    sources --> jaclang.dist.publish.builder {
        SourceFile,
        collect_source_files,
        read_source_file
    }
    sources --> jaclang.dist.publish.npm_sources { EXCLUDED_DIRS }
    sources --> jaclang.dist.source.project._copy_resources {
        EXCLUDED_DIRS,
        EXCLUDED_SUFFIXES
    }
    wheel_meta --> jaclang.dist.publish { wheel_filename }
    wheel_meta --> jaclang.dist.publish.builder {
        dist_info_dirname,
        generate_entry_points,
        generate_wheel_file,
        sdist_filename,
        wheel_filename
    }
}

impl import jaclang.dist.source {
    client --> jaclang.dist.source.project._write_application { write_client }
    project --> jaclang.cli.commands.build._build_app { export_project }
}

impl import jaclang.jac0core {
    cache_paths --> jaclang.cache.home { get_cache_home }
    cache_paths --> jaclang.compiler.backends.es.client_kernel_cache._cache_dir {
        get_jir_cache_dir
    }
    cache_paths --> jaclang.compiler.backends.native.elf_linker { atomic_write }
    cache_paths --> jaclang.compiler.backends.native.kernel_resolve {
        FileLock,
        atomic_write
    }
    cache_paths --> jaclang.compiler.backends.native.link_plan { atomic_write }
    cache_paths --> jaclang.compiler.backends.native.macho_linker { atomic_write }
    cache_paths --> jaclang.compiler.backends.native.pe_linker { atomic_write }
    cache_paths --> jaclang.compiler.driver.jir { FileLock, atomic_write }
    cache_paths --> jaclang.compiler.driver.jir.get_jir_cache_dir {
        get_jir_cache_dir as _root
    }
    ext_registry --> jaclang.cli.commands.analysis._drop_covered_annexes { is_annex }
    ext_registry --> jaclang.cli.commands.cli_helpers { base_stem, is_jac, is_python }
    ext_registry --> jaclang.cli.commands.execution._jab_native_bin { base_stem }
    ext_registry --> jaclang.cli.commands.native_build.native_build {
        base_stem,
        is_jac,
        is_retired_native_marker
    }
    ext_registry --> jaclang.client.jac_client_compiler { ANNEX_SUFFIXES }
    ext_registry --> jaclang.client.jac_client_compiler.JacClientCompiler._native_variant {
        base_stem
    }
    ext_registry --> jaclang.client.targets.client_dev_common.dev_proxy_paths {
        base_stem
    }
    ext_registry --> jaclang.compiler.driver.application._semantic_metadata {
        base_stem
    }
    ext_registry --> jaclang.compiler.driver.bccache { ANNEX_FOLDER, MODULE_SUFFIXES }
    ext_registry --> jaclang.compiler.driver.compiler.JacCompiler._compile_once {
        is_annex
    }
    ext_registry --> jaclang.compiler.driver.compiler.JacCompiler.parse_str {
        is_retired_client_marker,
        is_retired_native_marker
    }
    ext_registry --> jaclang.compiler.driver.pipeline.compile_application { is_annex }
    ext_registry --> jaclang.compiler.driver.pipeline_runner.ModuleCompilation.analysis {
        is_annex as _cc_is_annex
    }
    ext_registry --> jaclang.compiler.driver.progstate.DiagLedger._owned {
        is_annex_path_of
    }
    ext_registry --> jaclang.compiler.frontend.unitree.Import.__jac_detected.getter {
        INIT_FILES,
        is_jac
    }
    ext_registry --> jaclang.compiler.passes.mtir_gen_pass.MTIRGenPass._get_scope_str {
        STEM_REKEY_SUFFIXES
    }
    ext_registry --> jaclang.compiler.tools.code_intel {
        ANNEX_FOLDER,
        ANNEX_SUFFIXES,
        IMPL_SUFFIX,
        is_annex
    }
    ext_registry --> jaclang.dist.publish.builder { is_annex }
    ext_registry --> jaclang.dist.seal.bake_native_payloads { base_stem }
    ext_registry --> jaclang.project.kinds { base_stem }
    ext_registry --> jaclang.project.modresolver {
        MODULE_SUFFIXES,
        is_jac_namespace_package,
        language_of
    }
    ext_registry --> jaclang.project.placement { base_stem }
    ext_registry --> jaclang.runtime.prepared { base_stem }
    ext_registry --> jaclang.runtime.prepared.semantic_for_scope { base_stem }
    ext_registry --> jaclang.runtime.runtime.JacModule.impl_patch_filename.decorator {
        is_jac
    }
    ext_registry --> jaclang.scale.server.inprocess { base_stem }
    ext_registry --> jaclang.server.hmr.HotReloader._dispatch_change { is_impl }
    ext_registry --> jaclang.server.hmr.HotReloader._get_js_filename { base_stem }
    ext_registry --> jaclang.server.hmr.HotReloader._path_to_module { base_stem }
    ext_registry --> jaclang.testing.runner.run_test { base_stem, is_annex }
    ext_registry --> jaclang.testing.test { strip_suffix }
    ext_registry --> jaclang.testing.test_runner._is_named_test_file { is_jac, is_test }
    ext_registry --> jaclang.testing.test_runner._iter_candidate_files {
        is_impl,
        is_jac
    }
    ext_registry --> jaclang.testing.test_runner._suite_source { is_test }
    ext_registry --> jaclang.testing.test_runner.discover { is_jac }
    ext_registry --> jaclang.testing.test_runner.run_file { base_stem }
    sealed --> jaclang.cli.commands.project._bundle_binary { MANIFEST_NAME }
    sealed --> jaclang.compiler.backends.native.kernel_resolve._bundled_kernel {
        load_image
    }
    sealed --> jaclang.compiler.driver.application._prepare_sealed {
        image_for_bundle_dir,
        register_image
    }
    sealed --> jaclang.dist.jab { MANIFEST_NAME, image_for_bundle_dir, register_image }
    sealed --> jaclang.dist.precompile_bytecode {
        HEADER_SIZE as SEALED_HEADER_SIZE,
        JIR_FORMAT_VERSION as SEALED_JIR_FORMAT_VERSION,
        MANIFEST_FORMAT,
        MANIFEST_NAME,
        PRECOMPILE_SENTINEL as SEALED_SENTINEL,
        SECTIONS_MAGIC as SEALED_SECTIONS_MAGIC,
        SEC_BYTECODE as SEALED_SEC_BYTECODE,
        SEC_DEBUG_SRC as SEALED_SEC_DEBUG_SRC,
        SEC_NIFACE as SEALED_SEC_NIFACE,
        SEC_NOBJ as SEALED_SEC_NOBJ
    }
    sealed --> jaclang.dist.seal.vendor_jab_deps { python_tag }
    sealed --> jaclang.runtime.prepared.load_prepared_module { image_for_bundle_dir }
    sealed --> jaclang.scale.utils.vendor_wheels { python_tag }
    sealed --> jaclang.server.sealed_serve { MANIFEST_NAME }
    stubcat_hook --> jaclang.compiler.driver.compiler.JacCompiler.ensure_stub_catalog {
        env_disabled
    }
    stubcat_hook --> jaclang.compiler.driver.compiler.JacCompiler.stub_catalog {
        active
    }
    stubcat_hook --> jaclang.compiler.driver.pipeline.require_typeshed_stubs { active }
    stubcat_hook --> jaclang.compiler.types.stubcat.locate._publish { set_active }
    stubcat_hook --> jaclang.compiler.types.stubcat.locate.reset_catalog_cache {
        set_active
    }
    stubcat_hook --> jaclang.project.modresolver._candidate_from_stub_catalog { active }
    stubcat_hook --> jaclang.project.modresolver._stub_catalog_active { active }
}

impl import jaclang.lib {
    jaclib as _jaclib --> jaclang.lib;
    include jaclib --> jaclang.lib;
}

impl import jaclang.lsp.protocol {
    server --> jaclang.lsp.server.engine { LanguageServer }
    types --> jaclang.lsp.protocol.server {
        Diagnostic,
        DidChangeTextDocumentParams,
        DidCloseTextDocumentParams,
        DidOpenTextDocumentParams,
        EXIT,
        INITIALIZE,
        INITIALIZED,
        METHOD_TO_PARAMS,
        Position,
        PositionEncodingKind,
        Range,
        SHUTDOWN,
        TEXT_DOCUMENT_DID_CHANGE,
        TEXT_DOCUMENT_DID_CLOSE,
        TEXT_DOCUMENT_DID_OPEN,
        TEXT_DOCUMENT_PUBLISH_DIAGNOSTICS,
        TextDocumentContentChangeEvent,
        TextDocumentContentChangeEvent_Type1,
        TextDocumentItem,
        TextDocumentSyncKind,
        VersionedTextDocumentIdentifier,
        WINDOW_LOG_MESSAGE,
        WINDOW_SHOW_MESSAGE,
        WORKSPACE_SEMANTIC_TOKENS_REFRESH
    }
    types as lspt --> jaclang.lsp.server.engine;
    types as lspt --> jaclang.lsp.server.sem_manager;
    types as lspt --> jaclang.lsp.server.server;
    types as lspt --> jaclang.lsp.server.utils;
}

impl import jaclang.lsp.server {
    engine --> jaclang.lsp.server.server { JacLangServer }
    module_manager --> jaclang.lsp.server.engine { ModuleManager }
    rwlock --> jaclang.lsp.server.engine { ReadWriteLock }
    sem_manager --> jaclang.lsp.server.engine { SemTokManager }
    sem_manager --> jaclang.lsp.server.module_manager { SemTokManager }
    server --> jaclang.cli.commands.tools.lsp { run_lang_server }
    utils --> jaclang.lsp.server.engine { doc_of_sym, get_completion_items }
}

impl import jaclang.project {
    app_kinds --> jaclang.compiler.driver.pipeline.compile_application {
        kind_has_client
    }
    app_kinds --> jaclang.dist.seal.build_serve_manifest { kind_has_server }
    app_kinds --> jaclang.dist.source.project.export_project {
        kind_has_client,
        kind_has_server
    }
    app_kinds --> jaclang.project.apps.AppConfig.entry_path { kind_entry }
    app_kinds --> jaclang.project.apps.AppConfig.ui { kind_ui }
    app_kinds --> jaclang.project.apps.parse_apps { KIND_SPECS }
    app_kinds --> jaclang.project.kinds {
        KIND_SPECS,
        KindSpec,
        MOBILE_PLATFORMS,
        UI_DOM,
        UI_MOBUI,
        VALID_KINDS,
        is_valid_kind,
        kind_entry,
        kind_has_client,
        kind_is_mobui,
        kind_spec,
        kind_ui
    }
    app_kinds --> jaclang.project.workspace {
        UI_MOBUI,
        kind_codespace,
        kind_entry,
        kind_has_server,
        kind_ui
    }
    app_kinds --> jaclang.runtime.source_app.main { kind_has_server }
    type apps --> jaclang.client.cli { AppConfig }
    type apps --> jaclang.client.targets.registry { AppConfig }
    type apps --> jaclang.dist.seal { AppConfig }
    type apps --> jaclang.project.client_paths { AppConfig }
    apps --> jaclang.project.config { AppConfig, implicit_app, parse_apps }
    apps --> jaclang.project.config._parse_toml_data { validate_entry_point }
    apps --> jaclang.project.kinds { AppConfig, implicit_app }
    apps --> jaclang.project.template_loader.load_template_from_directory { parse_apps }
    apps --> jaclang.project.template_loader.scaffold_app {
        APP_TABLE_KEYS,
        parse_apps,
        validate_app_name
    }
    apps --> jaclang.project.workspace._build_workspace {
        parse_apps,
        resolve_entry_path
    }
    apps --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._client_entry {
        resolve_entry_path
    }
    apps --> jaclang.scale.injector.bundle._entry_module_spec { resolve_entry_path }
    type apps --> jaclang.scale.runtime.fleet { AppConfig }
    type apps --> jaclang.server.assembly { AppConfig }
    capabilities --> jaclang.byllm._optdeps.pillow.open_image { require_optional }
    capabilities --> jaclang.byllm._optdeps.pydantic.TypeAdapter { require_optional }
    capabilities --> jaclang.byllm.llm { require_optional }
    capabilities --> jaclang.project.providers.capability_dependencies {
        DEPLOY,
        RUNTIME,
        byllm_intent_capabilities,
        command_capabilities,
        derive_capabilities,
        get_capability_registry,
        resolve_closure,
        scale_intent_from_config
    }
    capabilities --> jaclang.scale._optdeps.optional_deps { missing_capability_error }
    capabilities --> jaclang.scale.deploy.target.factory {
        ensure_global_capability,
        missing_capability_dists
    }
    capabilities --> jaclang.scale.tests.deploy.test_dry_run_purity { CAPABILITY_SPECS }
    client_paths --> jaclang.client.artifact.client_output_dir { client_app_dir_for }
    client_paths --> jaclang.client.config_loader.JacClientConfig.get_assets_config {
        client_assets_config
    }
    client_paths --> jaclang.client.config_loader.JacClientConfig.get_assets_dir {
        client_assets_dir
    }
    client_paths --> jaclang.client.jac_client_compiler.JacClientCompiler._app_root {
        client_app_root
    }
    client_paths --> jaclang.client.jac_client_compiler.JacClientCompiler._client_app_dir {
        client_workspace_app
    }
    client_paths --> jaclang.client.serving.JacClient.render_page {
        client_workspace_app
    }
    client_paths --> jaclang.client.targets.desktop.desktop_build.stage_program {
        client_assets_dir
    }
    client_paths --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.out_dir_for {
        client_app_dir_for
    }
    client_paths --> jaclang.client.targets.react_native.scaffold._project_native_deps {
        client_workspace_app
    }
    client_paths --> jaclang.client.vite_bundler.ViteBundler._client_app_dir {
        client_workspace_app
    }
    client_paths --> jaclang.dist.seal.ensure_client_dist { client_app_dir_for }
    client_paths --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._client_dist_candidates {
        client_workspace_app
    }
    client_paths --> jaclang.server.server.JacAPIServer._ensure_client_bundle {
        client_app_dir_for
    }
    client_paths --> jaclang.server.static_files {
        client_app_dir_for,
        client_app_root,
        client_assets_config,
        client_assets_dir
    }
    config --> jaclang.byllm.mtir.MTRuntime.factory { find_project_root }
    config --> jaclang.cache.registry.project_bucket { get_config }
    config --> jaclang.cli.commands.analysis._configured_check_excludes { get_config }
    config --> jaclang.cli.commands.analysis._format_single_file_worker {
        get_config_for_path
    }
    config --> jaclang.cli.commands.analysis._is_project_wide_run { get_config }
    config --> jaclang.cli.commands.analysis.check { get_config }
    config --> jaclang.cli.commands.analysis.format { get_config }
    config --> jaclang.cli.commands.analysis.precommit { get_config }
    config --> jaclang.cli.commands.analysis.test { get_config }
    config --> jaclang.cli.commands.arch { get_config }
    type config --> jaclang.cli.commands.build { AppConfig }
    config --> jaclang.cli.commands.build.build { get_config }
    config --> jaclang.cli.commands.code { find_project_root }
    config --> jaclang.cli.commands.config { JacConfig }
    config --> jaclang.cli.commands.config._config_path {
        find_project_root,
        get_config
    }
    config --> jaclang.cli.commands.config._config_set { JacConfig, find_project_root }
    config --> jaclang.cli.commands.config._config_unset { find_project_root }
    config --> jaclang.cli.commands.config._get_group_defaults {
        BuildConfig,
        CacheConfig,
        CheckConfig,
        DotConfig,
        EnvironmentConfig,
        FormatConfig,
        ProjectConfig,
        RunConfig,
        ServeConfig,
        TestConfig
    }
    config --> jaclang.cli.commands.config._output_toml { toml_value }
    config --> jaclang.cli.commands.config.config { JacConfig, get_config }
    type config --> jaclang.cli.commands.execution { AppConfig, JacConfig }
    config --> jaclang.cli.commands.execution._default_codespace_is_native {
        PlacementConfig,
        get_config
    }
    config --> jaclang.cli.commands.execution._discover_config_from_file {
        JacConfig,
        get_config,
        project_scope_is_pinned,
        set_config
    }
    config --> jaclang.cli.commands.execution._ensure_watchdog_installed { get_config }
    config --> jaclang.cli.commands.execution._exec_file { get_config }
    config --> jaclang.cli.commands.execution._load_cwd_config { get_config }
    config --> jaclang.cli.commands.execution._pin_run_scope {
        JacConfig,
        get_config,
        pin_project_scope
    }
    config --> jaclang.cli.commands.execution._resolve_target { get_config }
    config --> jaclang.cli.commands.execution._run_node_tool { get_config }
    config --> jaclang.cli.commands.execution._tool_tiers { get_config }
    config --> jaclang.cli.commands.execution.run_jab_image { get_config_for_path }
    config --> jaclang.cli.commands.execution.serve { get_config }
    config --> jaclang.cli.commands.execution.x { get_config }
    config --> jaclang.cli.commands.fix._append_app_table { _toml_append_section }
    config --> jaclang.cli.commands.fix._ensure_workspace { JacConfig }
    config --> jaclang.cli.commands.mcp.mcp_cmd { get_config }
    type config --> jaclang.cli.commands.project { JacConfig }
    config --> jaclang.cli.commands.project._bootstrap_project_deps {
        get_config,
        set_config
    }
    config --> jaclang.cli.commands.project._create_app { find_project_root }
    config --> jaclang.cli.commands.project._create_body { find_project_root }
    config --> jaclang.cli.commands.project.bundle { get_config }
    config --> jaclang.cli.commands.project.clean { get_config }
    config --> jaclang.cli.commands.project.deps { get_config }
    config --> jaclang.cli.commands.project.install { get_config }
    config --> jaclang.cli.commands.project.remove { get_config }
    config --> jaclang.cli.commands.project.script { get_config }
    config --> jaclang.cli.commands.project.update { get_config }
    config --> jaclang.cli.dispatch._apply_profile { get_config }
    config --> jaclang.cli.dispatch._discover_project_config { get_config }
    config --> jaclang.cli.mcp.mode { JacConfig, get_config, set_config }
    config --> jaclang.cli.shadcn.cli.retheme { get_config }
    config --> jaclang.cli.shadcn.cli.run_shadcn_add { get_config }
    config --> jaclang.cli.shadcn.cli.run_shadcn_remove { get_config }
    config --> jaclang.client.artifact.client_output_dir { get_config_for_path }
    config --> jaclang.client.asset_processor { get_config }
    config --> jaclang.client.cli { JacConfig }
    config --> jaclang.client.cli.get_config { get_config as _get_config }
    config --> jaclang.client.client_deps._resolve_client_framework { get_config }
    config --> jaclang.client.client_diagnostics.is_debug_mode { JacConfig }
    config --> jaclang.client.config_loader { JacConfig }
    config --> jaclang.client.jac_client_compiler.JacClientCompiler._app_root {
        get_config
    }
    config --> jaclang.client.jac_client_compiler.JacClientCompiler._client_app_dir {
        get_config
    }
    config --> jaclang.client.jac_client_compiler.JacClientCompiler._get_client_dir {
        get_config
    }
    config --> jaclang.client.npm_provider { JacConfig }
    config --> jaclang.client.serving { get_config_for_path }
    config --> jaclang.client.targets.desktop._dev_launch { get_config }
    config --> jaclang.client.targets.desktop.desktop_build.stage_program {
        get_config_for_dir
    }
    config --> jaclang.client.targets.desktop.desktop_target.DesktopTarget.out_dir_for {
        get_config_for_dir
    }
    config --> jaclang.client.targets.pwa_build { get_config }
    config --> jaclang.client.targets.react_native.scaffold { JacConfig }
    config --> jaclang.client.targets.react_native.scaffold._project_native_deps {
        get_config_for_dir
    }
    config --> jaclang.client.targets.registry.target_for_app { get_config }
    config --> jaclang.client.targets.web_target._get_app_meta_data { get_config }
    config --> jaclang.client.vite_bundler.ViteBundler._client_app_dir { get_config }
    config --> jaclang.client.vite_bundler.ViteBundler._get_client_dir { get_config }
    config --> jaclang.client.vite_bundler.ViteBundler.init { find_project_root }
    config --> jaclang.client.vite_bundler._dev_head_scripts { get_config }
    config --> jaclang.client.vite_client_bundle.make_client_bundle_builder {
        find_project_root
    }
    config --> jaclang.compiler.backends.es.backends.registry.resolve_active_backend {
        get_config
    }
    config --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._ensure_backend {
        get_config
    }
    config --> jaclang.compiler.backends.native.na_ir_gen_pass.NaIRGenPass._seam_warnings_on {
        get_config
    }
    config --> jaclang.compiler.driver.compiler.JacCompiler.stamp_access_check_facts {
        get_config
    }
    config --> jaclang.compiler.driver.ifacecache.IfaceRegistry.analysis_profile {
        get_config
    }
    config --> jaclang.compiler.driver.pass_driver.build_diagnostic_policy {
        get_config
    }
    config --> jaclang.compiler.frontend.codeinfo.effective_default_codespace {
        PlacementConfig,
        get_config
    }
    config --> jaclang.compiler.frontend.codeinfo.effective_native_closure_cap {
        BuildConfig,
        get_config
    }
    config --> jaclang.compiler.frontend.codeinfo.effective_native_target { get_config }
    config --> jaclang.compiler.tools.jac_auto_lint_pass.JacAutoLintPass.__post_init__ {
        JacConfig,
        get_config_for_path,
        get_explicit_config
    }
    config --> jaclang.compiler.types.type_evaluator.TypeEvaluator._declared_missing_dependency {
        get_config_for_path
    }
    config --> jaclang.dist.precompile_bytecode.app_metadata { get_config_for_path }
    config --> jaclang.dist.precompile_bytecode.precompile_context {
        get_config_for_path
    }
    config --> jaclang.dist.publish.builder { JacConfig }
    config --> jaclang.dist.publish.metadata { JacConfig, PersonConfig }
    config --> jaclang.dist.publish.npm_builder { JacConfig }
    config --> jaclang.dist.publish.npm_sources { JacConfig }
    config --> jaclang.dist.publish.package_json { JacConfig, PersonConfig }
    config --> jaclang.dist.publish.sources { JacConfig }
    config --> jaclang.dist.publish.wheel_meta { JacConfig }
    config --> jaclang.dist.seal.build_serve_manifest { get_config_for_path }
    config --> jaclang.dist.source.project { JacConfig }
    config --> jaclang.project.capabilities { JacConfig }
    type config --> jaclang.project.client_paths { JacConfig }
    config --> jaclang.project.kinds { JacConfig }
    config --> jaclang.project.modresolver._get_path_aliases { get_config }
    config --> jaclang.project.modresolver._resolve_path_alias { get_config }
    config --> jaclang.project.plugin_config {
        JacConfig,
        find_project_root,
        get_config_for_path
    }
    config --> jaclang.project.providers { JacConfig }
    config --> jaclang.project.pyvenv { JacConfig }
    config --> jaclang.project.pyvenv.add_venv_to_path { get_config }
    config --> jaclang.project.pyvenv.is_venv_in_path { get_config }
    config --> jaclang.project.pyvenv.remove_venv_from_path { get_config }
    config --> jaclang.project.template_loader { JacConfig }
    config --> jaclang.project.template_loader._append_overlay_tables {
        _toml_append_section
    }
    config --> jaclang.project.template_loader.migrate_implicit_app {
        _toml_append_section,
        _toml_delete_key,
        _toml_insert_key,
        toml_value
    }
    config --> jaclang.project.template_loader.scaffold_app { _toml_append_section }
    config --> jaclang.project.tool_paths { JacConfig, get_config }
    config --> jaclang.runtime.graph_utils.get_name { get_config }
    config --> jaclang.runtime.runtime.JacRuntime.reset_process_state { set_config }
    config --> jaclang.runtime.source_app.main { JacConfig, set_config }
    config --> jaclang.scale.config.app_config { get_config_for_dir }
    config --> jaclang.scale.config.dev_config.resolve_dev_channel {
        get_config_for_path
    }
    config --> jaclang.scale.config.dev_config.resolve_experimental_pr {
        get_config_for_path
    }
    config --> jaclang.scale.config.dev_config.resolve_pinned_spec {
        get_config_for_path
    }
    config --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._check_deploy_settings_resolve {
        get_config_for_path,
        report_env_findings
    }
    config --> jaclang.scale.injector.binary.deploy_generation_refusal {
        JacConfig,
        find_project_root
    }
    config --> jaclang.scale.injector.binary.resolve_pinned_version {
        JacConfig,
        find_project_root
    }
    config --> jaclang.scale.injector.bundle._project_config { get_config_for_path }
    config --> jaclang.scale.injector.bundle._resolved_python_specs { JacConfig }
    config --> jaclang.scale.injector.bundle.fat_bundle_setting { get_config_for_path }
    config --> jaclang.scale.injector.bundle.seal_timeout_setting {
        get_config_for_path
    }
    config --> jaclang.scale.injector.bundle.unresolved_toml_references {
        resolve_env_refs
    }
    config --> jaclang.scale.plugin._resolve_deploy_target { get_config }
    config --> jaclang.scale.plugin.scale_local_serve { get_config }
    config --> jaclang.scale.runtime.fleet.fleet_member_names {
        get_config,
        get_config_for_dir
    }
    config --> jaclang.scale.runtime.realizer.kubernetes_realizer.KubernetesRealizer._resolve_fleet {
        get_config_for_dir
    }
    config --> jaclang.scale.server.inprocess.prepare_inprocess_runtime {
        get_config_for_dir
    }
    config --> jaclang.scale.storage.factory { get_config }
    config --> jaclang.scale.tests.apps.test_app_scale_overrides {
        JacConfig,
        get_config,
        get_explicit_config,
        set_config
    }
    config --> jaclang.scale.tests.apps.test_fleet_from_apps { JacConfig }
    config --> jaclang.scale.tests.data.test_gcs_storage { JacConfig }
    config --> jaclang.scale.tests.data.test_s3_storage { JacConfig }
    config --> jaclang.scale.tests.deploy.test_deploy_banner { JacConfig }
    config --> jaclang.scale.tests.deploy.test_dry_run_purity { JacConfig }
    config --> jaclang.scale.tests.deploy.test_version_pin { JacConfig }
    config --> jaclang.scale.tests.microservices.test_app_precompile {
        get_config_for_path
    }
    config --> jaclang.scale.tests.misc.test_config_validation { JacConfig }
    config --> jaclang.scale.tests.server.test_examples { find_project_root }
    config --> jaclang.scale.tests.server.test_host_serving { set_config }
    config --> jaclang.scale.tests.server.test_served_app_route { set_config }
    config --> jaclang.scale.utils.vendor_wheels { JacConfig }
    config --> jaclang.server.endpoints.colocated { get_config }
    config --> jaclang.server.endpoints.colocated.served_app_route {
        get_config_for_dir
    }
    config --> jaclang.server.endpoints.pages { get_config }
    config --> jaclang.server.endpoints.pages.register_diagnostics_endpoints.client_error {
        get_config
    }
    config --> jaclang.server.hmr.HotReloader._reload_server_module {
        get_config_for_dir
    }
    config --> jaclang.server.server.JacAPIServer._ensure_client_bundle { get_config }
    config --> jaclang.server.server.JacAPIServer.build_app { JacConfig }
    config --> jaclang.server.server._occ_policy { get_config }
    config --> jaclang.server.server.print_endpoint_docs { get_config }
    config --> jaclang.server.settings { JacConfig, ServeConfig }
    config --> jaclang.server.settings.secret_home { find_project_root }
    config --> jaclang.server.static_files {
        find_project_root,
        get_config,
        get_config_for_dir
    }
    config --> jaclang.server.sv_client._read_cache_enabled { get_config }
    config --> jaclang.testing.test_runner._fresh_jac_state {
        get_explicit_config,
        set_config
    }
    config --> jaclang.testing.testing { JacConfig }
    type config --> jaclang.testing.testing { JacConfig }
    config --> jaclang.testing.testing.JacTestClient._ensure_initialized {
        get_config,
        set_config
    }
    config_schema --> jaclang.project.plugin_config.PluginConfigBase._validate_layer {
        report_schema_findings,
        validate_against_schema
    }
    config_schema --> jaclang.scale.config.config_loader.app_scale_overrides {
        report_schema_findings
    }
    config_schema --> jaclang.scale.config.validation {
        report_schema_findings,
        validate_against_schema
    }
    config_schema --> jaclang.scale.tests.misc.test_config_validation {
        report_schema_findings,
        schema_strict_enabled
    }
    kinds --> jaclang.cli.commands.build._build_app { kind_has_client, plan_app_run }
    kinds --> jaclang.cli.commands.execution | jaclang.scale.plugin { RunPlan }
    kinds --> jaclang.cli.commands.execution._app_serves { kind_spec }
    kinds --> jaclang.cli.commands.execution._exec_file { resolve_app_kind }
    kinds --> jaclang.cli.commands.execution._resolve_plan { plan_app_run }
    kinds --> jaclang.cli.commands.execution._serve_fleet { plan_app_run }
    kinds --> jaclang.cli.commands.execution._workspace_plans {
        plan_app_run,
        plan_workspace
    }
    kinds --> jaclang.cli.commands.project._create_app { VALID_KINDS, is_valid_kind }
    kinds --> jaclang.cli.commands.project._create_body { VALID_KINDS, is_valid_kind }
    kinds --> jaclang.cli.commands.project._run_blurb { VALID_KINDS }
    kinds --> jaclang.client.cli.run_client_start { kind_has_client }
    kinds --> jaclang.client.cli.setup { kind_has_client }
    kinds --> jaclang.client.npm_provider._app_wants_client { kind_has_client }
    kinds --> jaclang.dist.precompile_bytecode.app_metadata {
        resolve_app_kind,
        resolve_entry
    }
    kinds --> jaclang.project.config.JacConfig.resolved_kind {
        resolve_app_kind,
        resolve_entry
    }
    kinds --> jaclang.project.config.JacConfig.serving_apps { kind_spec }
    kinds --> jaclang.project.providers.capability_dependencies { plan_app_run }
    kinds --> jaclang.project.template_loader.migrate_implicit_app { kind_entry }
    kinds --> jaclang.project.template_loader.scaffold_app { KIND_SPECS, kind_entry }
    kinds --> jaclang.project.template_registry.TemplateRegistry.list_kinds {
        KIND_SPECS
    }
    kinds --> jaclang.project.template_registry._core_template { kind_spec }
    kinds --> jaclang.scale.plugin._resolve_deploy_target { resolve_entry }
    kinds --> jaclang.scale.runtime.fleet._has_client { kind_has_client }
    kinds --> jaclang.server.static_files { kind_has_client }
    mobui_scope --> jaclang.compiler.passes.jsx_intrinsic_guard_pass {
        mobui_module_exempt
    }
    mobui_scope --> jaclang.compiler.types.type_evaluator.TypeEvaluator._is_mobui_module {
        mobui_module_exempt
    }
    modresolver --> jaclang.cli.commands.fix._verify_claims { find_jac_project_root }
    modresolver --> jaclang.cli.commands.fix.fix { find_jac_project_root }
    modresolver --> jaclang.client.compiler.ViteCompiler.compile_desktop_sdk {
        resolve_jac_virtual_module_exports,
        resolve_jac_virtual_module_path
    }
    modresolver --> jaclang.compiler.backends.es.esast_gen_pass {
        convert_to_js_import_path,
        relative_js_specifier,
        resolve_relative_path
    }
    modresolver --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._register_jac_virtual_import {
        resolve_jac_virtual_module_path
    }
    modresolver --> jaclang.compiler.backends.py.artifact_imports {
        resolve_local_module
    }
    modresolver --> jaclang.compiler.driver.compiler.JacCompiler.note_stub_tree_served {
        _in_typeshed_tree
    }
    modresolver --> jaclang.compiler.driver.compiler.JacCompiler.stamp_app_facts {
        find_jac_project_root
    }
    modresolver --> jaclang.compiler.driver.wiring {
        find_jac_project_root,
        resolve_local_module
    }
    modresolver --> jaclang.compiler.frontend.codeinfo.resolve_native_module {
        resolve_module
    }
    modresolver --> jaclang.compiler.frontend.unitree.ModulePath.resolve_relative_path {
        resolve_relative_path
    }
    modresolver --> jaclang.compiler.passes.access_check_pass.AccessCheckPass._module_app_facts {
        find_jac_project_root
    }
    modresolver --> jaclang.compiler.passes.static_analysis_pass.StaticAnalysisPass._check_client_imports {
        is_path_alias_import
    }
    modresolver --> jaclang.compiler.placement.placement_facts.project_root_of {
        find_jac_project_root
    }
    modresolver --> jaclang.compiler.placement.placement_pins { find_jac_project_root }
    modresolver --> jaclang.compiler.placement.placement_pins._declared_npm_rule {
        npm_package_root
    }
    modresolver --> jaclang.compiler.placement.placement_pins._installed_npm_rule {
        has_client_npm_package
    }
    modresolver --> jaclang.compiler.placement.placement_pins.classify_bare_import {
        resolve_module
    }
    modresolver --> jaclang.compiler.tests.test_jac_mobui_typing {
        resolve_jac_virtual_module_path
    }
    modresolver --> jaclang.compiler.types.type_evaluator.TypeEvaluator._client_npm_base {
        has_client_npm_package
    }
    modresolver --> jaclang.compiler.types.type_evaluator.TypeEvaluator._jac_virtual_sibling_dts {
        sibling_declaration_file
    }
    modresolver --> jaclang.compiler.types.type_evaluator.TypeEvaluator._resolve_client_npm_module {
        resolve_client_npm_package
    }
    modresolver --> jaclang.compiler.types.type_evaluator.TypeEvaluator._resolve_submodule_attr {
        is_untyped_third_party_module
    }
    modresolver --> jaclang.compiler.types.type_evaluator.TypeEvaluator._ts_decl_path {
        resolve_client_npm_declarations,
        sibling_declaration_file
    }
    modresolver --> jaclang.compiler.types.type_evaluator.TypeEvaluator._untyped_external_is_error {
        find_jac_project_root
    }
    modresolver --> jaclang.compiler.types.type_evaluator.TypeEvaluator.get_type_of_module {
        is_untyped_third_party_module
    }
    modresolver --> jaclang.compiler.types.type_evaluator.TypeEvaluator.get_type_of_module_item {
        is_untyped_third_party_module,
        sibling_declaration_file
    }
    modresolver --> jaclang.dist.publish.py_imports { resolve_module }
    modresolver --> jaclang.dist.publish.runtime_vendor._module_to_file {
        resolve_local_module
    }
    modresolver --> jaclang.lsp.server.engine.JacLangServer._module_spec_target {
        resolve_client_npm_declarations,
        resolve_client_npm_package
    }
    modresolver --> jaclang.lsp.server.engine.JacLangServer._npm_item_location {
        resolve_client_npm_declarations,
        resolve_client_npm_package
    }
    modresolver --> jaclang.project.apps.resolve_entry_path { resolve_local_module }
    modresolver --> jaclang.project.config.find_project_root {
        find_project_root as _find_project_root
    }
    modresolver --> jaclang.project.workspace { find_jac_project_root }
    modresolver --> jaclang.runtime.runtime {
        find_jac_project_root,
        infer_language,
        pop_import_base,
        push_import_base
    }
    modresolver --> jaclang.server.outbox.outbox_db_path { find_jac_project_root }
    modresolver --> jaclang.testing.cl_test_runner._compile_runtime {
        resolve_jac_virtual_module_path
    }
    placement --> jaclang.cli.commands.fix._verify_claims { module_dot_path }
    placement --> jaclang.compiler.placement.placement_pins { match_pin, validate_pins }
    placement --> jaclang.project.kinds.resolve_app_kind { match_pin, validate_pins }
    placement --> jaclang.project.workspace.WorkspaceSpec.module_dot_path {
        module_dot_path
    }
    plugin_config --> jaclang.byllm.config_loader { PluginConfigBase }
    plugin_config --> jaclang.client.config_loader { PluginConfigBase, deep_merge }
    plugin_config --> jaclang.client.desktop_config { PluginConfigBase }
    plugin_config --> jaclang.scale.config.config_loader { PluginConfigBase }
    providers --> jaclang.cli.commands.execution._ensure_watchdog_installed {
        InstallContext,
        get_python_provider
    }
    providers --> jaclang.cli.commands.execution._load_cwd_config {
        initialize_provider_registry
    }
    providers --> jaclang.cli.commands.execution._serve_with {
        initialize_provider_registry
    }
    providers --> jaclang.cli.commands.project.deps { resolve_plan }
    providers --> jaclang.cli.commands.project.install {
        InstallContext,
        get_provider_registry,
        get_python_provider,
        resolve_plan
    }
    providers --> jaclang.cli.commands.project.remove {
        InstallContext,
        get_python_provider
    }
    providers --> jaclang.cli.commands.project.update {
        InstallContext,
        get_python_provider
    }
    type providers --> jaclang.client.cli { EcosystemProvider }
    providers --> jaclang.client.cli._npm_context { get_provider_registry }
    providers --> jaclang.client.cli.run_npm_add { InstallContext }
    providers --> jaclang.client.cli.run_npm_remove { InstallContext }
    providers --> jaclang.client.npm_provider {
        EcosystemProvider,
        InstallContext,
        ResolvedDependency,
        manifest_plugin_deps
    }
    type providers --> jaclang.client.plugin_config { EcosystemProvider }
    providers --> jaclang.client.targets.react_native.scaffold {
        manifest_plugin_subdeps
    }
    providers --> jaclang.dist.publish.package_json.npm_dependencies {
        manifest_plugin_deps
    }
    providers --> jaclang.dist.seal.vendor_jab_deps {
        get_python_provider,
        resolve_plan
    }
    providers --> jaclang.dist.source.project._requirements {
        get_python_provider,
        resolve_plan
    }
    providers --> jaclang.scale.injector.bundle._resolved_python_specs {
        get_python_provider,
        resolve_plan
    }
    providers --> jaclang.scale.injector.bundle._venv_stage { write_venv_deps_marker }
    providers --> jaclang.scale.injector.bundle.staged_venv_files { VENV_DEPS_MARKER }
    providers --> jaclang.scale.tests.microservices.test_fat_bundle {
        write_venv_deps_marker
    }
    providers --> jaclang.scale.utils.vendor_wheels {
        get_python_provider,
        resolve_plan
    }
    pyvenv --> jaclang.cli.commands.execution._discover_config_from_file {
        add_venv_to_path
    }
    pyvenv --> jaclang.cli.commands.execution._ensure_watchdog_installed {
        add_venv_to_path
    }
    pyvenv --> jaclang.cli.commands.execution._pin_run_scope { add_venv_to_path }
    pyvenv --> jaclang.cli.commands.project.install {
        ensure_venv,
        get_venv_site_packages,
        make_git_spec
    }
    pyvenv --> jaclang.cli.commands.project.update { make_git_spec }
    pyvenv --> jaclang.cli.dispatch._discover_project_config { add_venv_to_path }
    pyvenv --> jaclang.client.targets.desktop._dev_launch { get_venv_site_packages }
    pyvenv --> jaclang.dist.jab_vendor._pip { pip_command, pip_env, pip_python }
    pyvenv --> jaclang.project.capabilities.ensure_global_capability {
        pip_command,
        pip_env,
        pip_python
    }
    pyvenv --> jaclang.project.providers {
        ensure_venv,
        get_venv_site_packages,
        make_git_spec,
        make_pip_spec,
        run_pip,
        summarize_pip_failure
    }
    pyvenv --> jaclang.project.providers.PythonProvider._install_global {
        pip_command,
        pip_env,
        pip_python
    }
    pyvenv --> jaclang.project.tool_paths { get_venv_site_packages }
    pyvenv --> jaclang.scale.injector.bundle._venv_stage { get_venv_site_packages }
    pyvenv --> jaclang.scale.injector.bundle.staged_venv_files {
        get_venv_site_packages
    }
    source --> jaclang.cli.commands.analysis._check_file_job {
        read_file_with_encoding as _read_src
    }
    source --> jaclang.cli.commands.analysis._format_single_file_worker {
        read_file_with_encoding
    }
    source --> jaclang.cli.commands.analysis._iter_jac_files { drop_git_ignored }
    source --> jaclang.cli.commands.analysis._normalize_ignore_patterns {
        normalize_exclude_patterns
    }
    source --> jaclang.cli.commands.analysis._should_ignore { path_matches_exclude }
    source --> jaclang.cli.commands.arch { read_file_with_encoding }
    source --> jaclang.cli.commands.transform.py2jac { read_file_with_encoding }
    source --> jaclang.client.client_diagnostics.ClientDiagnostic.render {
        read_file_with_encoding,
        render_diagnostic,
        span_for_file
    }
    source --> jaclang.compiler.backends.es.es_unparse.JSCodeGenerator.generate {
        pascal_to_snake
    }
    source --> jaclang.compiler.driver.compiler { read_file_with_encoding }
    source --> jaclang.compiler.driver.compiler.JacCompiler.get_bytecode {
        read_file_with_encoding
    }
    source --> jaclang.compiler.driver.pipeline_runner { read_file_with_encoding }
    source --> jaclang.compiler.driver.program.JacProgram.load_dependency_module {
        read_file_with_encoding
    }
    source --> jaclang.compiler.driver.wiring {
        drop_git_ignored,
        read_file_with_encoding
    }
    source --> jaclang.compiler.frontend.parser.frontend.annex_sources {
        read_file_with_encoding
    }
    source --> jaclang.compiler.passes.context.Alert.as_log { render_diagnostic_header }
    source --> jaclang.compiler.passes.context.Alert.pretty_print { render_diagnostic }
    source --> jaclang.compiler.passes.import_wiring_pass { pascal_to_snake }
    source --> jaclang.compiler.passes.pyast_load_pass.PyastBuildPass.convert {
        pascal_to_snake
    }
    source --> jaclang.compiler.passes.variant_agreement_pass.VariantAgreementPass._parse_sibling {
        read_file_with_encoding
    }
    source --> jaclang.compiler.placement.placement_solver._native_dep_scan {
        read_file_with_encoding
    }
    source --> jaclang.compiler.tools.jac_auto_lint_pass.JacAutoLintPass._base_decl_archetypes {
        read_file_with_encoding
    }
    source --> jaclang.compiler.tools.jac_auto_lint_pass.JacAutoLintPass._is_file_excluded {
        path_matches_exclude
    }
    source --> jaclang.compiler.tools.lang_tools {
        pascal_to_snake,
        read_file_with_encoding
    }
    source --> jaclang.compiler.types.type_evaluator { read_file_with_encoding }
    source --> jaclang.project.config.JacConfig.save { read_file_with_encoding }
    source --> jaclang.project.template_loader.scaffold_app { read_file_with_encoding }
    source --> jaclang.project.tomlio { read_file_with_encoding }
    source --> jaclang.runtime.traceback_render {
        pretty_print_source_location,
        read_file_with_encoding
    }
    source --> jaclang.scale.injector.bundle.BundleSourceFilter.matching_ignore_pattern {
        path_matches_exclude
    }
    source --> jaclang.scale.injector.bundle.BundleSourceFilter.parks {
        path_matches_exclude
    }
    source --> jaclang.scale.injector.bundle.source_filter_for {
        read_jacignore_patterns
    }
    template_loader --> jaclang.cli.commands.fix._ensure_workspace {
        migrate_implicit_app
    }
    template_loader --> jaclang.cli.commands.project._create_app { scaffold_app }
    template_loader --> jaclang.cli.commands.project._create_body {
        load_template_from_directory,
        load_template_from_json
    }
    template_loader --> jaclang.cli.commands.project._resolve_bundled_template {
        load_template_from_directory
    }
    template_loader --> jaclang.cli.commands.project._resolve_template {
        load_template_from_directory,
        load_template_from_json
    }
    template_loader --> jaclang.cli.commands.project.jacpack {
        bundle_template,
        load_template_from_directory,
        load_template_from_json
    }
    template_loader --> jaclang.cli.shadcn.cli._build_shadcn_template_info {
        load_template_from_directory
    }
    template_loader --> jaclang.client.plugin_config._load_template {
        load_template_from_directory
    }
    type template_registry --> jaclang.cli.commands.project {
        ProjectTemplate,
        TemplateRegistry
    }
    template_registry --> jaclang.cli.commands.project._create_body {
        TemplateRegistry,
        get_template_registry
    }
    template_registry --> jaclang.cli.commands.project.jacpack {
        TemplateRegistry,
        get_template_registry
    }
    template_registry --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.list_templates._do_list_templates {
        get_template_registry
    }
    template_registry --> jaclang.project.template_loader {
        ProjectTemplate,
        template_kind_for
    }
    tomlio --> jaclang.cli.commands.config { read_toml_with_encoding }
    tomlio --> jaclang.cli.commands.project._toml_apps_and_default {
        read_toml_with_encoding
    }
    tomlio --> jaclang.cli.commands.project.jacpack { read_toml_with_encoding }
    tomlio --> jaclang.cli.dispatch._discover_project_config { MalformedJacTomlError }
    tomlio --> jaclang.compiler.types.type_evaluator.TypeEvaluator._untyped_external_is_error {
        read_toml_with_encoding
    }
    tomlio --> jaclang.project.config.JacConfig.load { read_toml_with_encoding }
    tomlio --> jaclang.project.config.JacConfig.merge_from_toml_file {
        read_toml_with_encoding
    }
    tomlio --> jaclang.project.config.JacConfig.save { MalformedJacTomlError }
    tomlio --> jaclang.project.template_loader { read_toml_with_encoding }
    tool_paths --> jaclang.cli.commands.execution._tool_site_dirs {
        python_global_site,
        python_project_site
    }
    tool_paths --> jaclang.cli.commands.execution._tool_tiers {
        node_bin_dir,
        python_global_site,
        python_project_site
    }
    tool_paths --> jaclang.client.cli.run_npm_add_global { node_root }
    workspace --> jaclang.cli.commands.analysis.check { workspace_for_path }
    workspace --> jaclang.cli.commands.fix._access_plan { workspace_for_path }
    workspace --> jaclang.compiler.driver.application._warn_private_declarations {
        app_for_path
    }
    workspace --> jaclang.compiler.driver.boundary_classify {
        AppSpec,
        app_for_path,
        workspace_for_path
    }
    workspace --> jaclang.compiler.driver.boundary_classify.is_service_app_entry {
        app_for_path
    }
    type workspace --> jaclang.compiler.driver.compilation_context { AppSpec }
    workspace --> jaclang.compiler.driver.compilation_context.bind_options {
        workspace_for_path
    }
    workspace --> jaclang.compiler.driver.compilation_context.compilation_scope {
        workspace_scope
    }
    workspace --> jaclang.compiler.driver.compilation_context.context_app {
        workspace_for_path
    }
    workspace --> jaclang.compiler.driver.compiler.JacCompiler.stamp_app_facts {
        UI_MOBUI,
        workspace_for_path
    }
    workspace --> jaclang.compiler.driver.jir._project_env_fingerprint {
        app_fact_digest,
        app_for_path,
        workspace_for_path
    }
    workspace --> jaclang.compiler.frontend.codeinfo.endpoint_descriptor {
        workspace_for_path
    }
    workspace --> jaclang.compiler.placement.placement.project_has_server {
        kind_codespace
    }
    workspace --> jaclang.compiler.placement.placement_pins {
        app_fact_digest,
        kind_codespace,
        workspace_for_path
    }
    workspace --> jaclang.dist.precompile_bytecode._application_sources {
        workspace_for_path
    }
    workspace --> jaclang.lsp.server.engine.JacLangServer.type_check_file {
        workspace_for_path
    }
    workspace --> jaclang.project.kinds.resolve_app_kind { workspace_for_path }
}

impl import jaclang.runtime {
    archetype --> jaclang.byllm.llm._mock_jsonable { Archetype }
    archetype --> jaclang.byllm.visit_routing {
        Anchor,
        Archetype,
        ObjectSpatialFunction
    }
    archetype --> jaclang.byllm.visit_routing._candidate_for {
        EdgeAnchor,
        EdgeArchetype,
        NodeAnchor,
        NodeArchetype
    }
    archetype --> jaclang.byllm.visit_routing._route_context {
        EdgeAnchor,
        EdgeArchetype,
        NodeAnchor,
        NodeArchetype,
        WalkerAnchor
    }
    archetype --> jaclang.compiler.native_compiler.NativeCompiler._register {
        NodeAnchor,
        NodeArchetype
    }
    archetype --> jaclang.data.query_planner { Anchor, EdgeAnchor, anchor_key }
    archetype --> jaclang.data.query_planner._acl_pushdown_root { Archetype, Root }
    archetype --> jaclang.data.serializer {
        Access,
        AccessLevel,
        Anchor,
        EdgeAnchor,
        NodeAnchor,
        ObjectAnchor,
        Permission,
        WalkerAnchor,
        access_level_cast
    }
    archetype --> jaclang.lib.jaclib {
        GenericEdge,
        ObjectSpatialFunction as DSFunc,
        Root
    }
    archetype --> jaclang.runtime.constructs {
        AccessLevel,
        Anchor,
        Archetype,
        EdgeAnchor,
        EdgeArchetype,
        GenericEdge,
        JsxElement,
        NodeAnchor,
        NodeArchetype,
        ObjectSpatialFunction,
        PermissionDenied,
        Root,
        WalkerAnchor,
        WalkerArchetype,
        access_level_cast
    }
    archetype --> jaclang.runtime.context { NodeAnchor, PermissionDenied, Root }
    archetype --> jaclang.runtime.graph_query { Anchor, anchor_key }
    archetype --> jaclang.runtime.graph_utils.collect_node_connections {
        EdgeAnchor,
        NodeAnchor,
        anchor_key
    }
    archetype --> jaclang.runtime.graph_utils.traverse_graph { EdgeAnchor }
    archetype --> jaclang.runtime.graph_walk {
        Anchor,
        EdgeAnchor,
        NodeAnchor,
        anchor_key,
        light_edge_view,
        same_anchor
    }
    archetype --> jaclang.runtime.graph_walk.acl_read_ok { AccessLevel }
    archetype --> jaclang.runtime.memory { Anchor, Root }
    archetype --> jaclang.runtime.osp_graph_sv {
        Anchor,
        EdgeAnchor,
        NodeAnchor,
        anchor_key,
        same_anchor
    }
    archetype --> jaclang.runtime.osp_kernel_sv {
        EdgeAnchor,
        NodeAnchor,
        ObjectSpatialFunction,
        WalkerArchetype
    }
    archetype --> jaclang.runtime.runtime {
        GenericEdge,
        ObjectAnchor,
        ObjectSpatialFunction,
        Root,
        _deref,
        _edge_subtypes,
        _light_edge_types,
        anchor_key,
        edge_subtypes,
        is_light_edge_type,
        light_clear_hop,
        light_connect,
        light_disconnect,
        light_edge_view,
        light_hop,
        light_hop_answers,
        same_anchor
    }
    archetype --> jaclang.runtime.runtime.JacLLM.by_operator {
        EdgeArchetype,
        NodeArchetype
    }
    archetype --> jaclang.server.session { Anchor, EdgeAnchor, NodeAnchor, Root }
    build_services --> jaclang.client.runtime_source.client_runtime_cl_basename {
        build_services
    }
    build_services --> jaclang.compiler.driver.build_services { BuildServices }
    build_services --> jaclang.runtime.runtime.JacRuntime.get_compiler {
        build_services
    }
    build_services --> jaclang.runtime.runtime.JacRuntime.get_program { build_services }
    build_services --> jaclang.runtime.runtime.JacRuntime.get_selfhost {
        build_services
    }
    build_services --> jaclang.runtime.runtime.JacServe.get_client_bundle_builder {
        build_services
    }
    build_services --> jaclang.runtime.runtime.JacTest.run_test { build_services }
    build_services --> jaclang.scale.runtime.fleet._compiled_app_edges {
        build_services
    }
    build_services --> jaclang.testing.testing.JacTestClient._ensure_initialized {
        build_services
    }
    build_services --> jaclang.testing.testing.JacTestClient.reload { build_services }
    builtin --> jaclang.cli.commands.tools.dot { printgraph }
    builtin --> jaclang.runtime.archetype.Archetype.__init_subclass__ {
        _jac_region_instrument
    }
    builtin --> jaclang.scale.server.jobs_ext { ScheduleTrigger }
    builtin --> jaclang.scale.server.webhook_ext { APIProtocol }
    builtin --> jaclang.scale.server.websocket_ext { APIProtocol }
    builtin as blt --> jaclang.scale.tests.server.test_restspec;
    builtin --> jaclang.scale.tests.server.test_restspec { APIProtocol }
    builtin --> jaclang.scale.tests.server.test_webhook { APIProtocol, restspec }
    builtin --> jaclang.server.endpoints.walkers { APIProtocol }
    builtin --> jaclang.server.server { APIProtocol }
    builtin --> jaclang.server.server.JacAPIServer._register_scheduled_tasks {
        ScheduleTrigger
    }
    builtin --> jaclang.server.task_scheduler { ScheduleTrigger }
    cinterop as _cinterop_mod --> jaclang.runtime.builtin.__getattr__;
    constants --> jaclang.compiler.backends.py.jcir_gen_pass {
        Constants as Con,
        EdgeDir
    }
    constants --> jaclang.compiler.frontend.parser.parser { EdgeDir }
    constants --> jaclang.compiler.frontend.unitree { Constants as Con, EdgeDir }
    constants --> jaclang.compiler.passes.graph_lowering_pass { EdgeDir }
    constants --> jaclang.compiler.tools.normalize_pass { EdgeDir }
    constants --> jaclang.compiler.types.type_evaluator { EdgeDir }
    constants --> jaclang.data.dbcatalog.holds_no_data { Constants as Con }
    constants --> jaclang.lib.jaclib { EdgeDir }
    constants --> jaclang.runtime.archetype { EdgeDir }
    constants --> jaclang.runtime.context { Constants as Con }
    constants --> jaclang.runtime.runtime { EdgeDir, colors }
    constants --> jaclang.scale.admin.admin_portal { Constants as Con }
    constants --> jaclang.scale.server.inprocess { Constants as Con }
    constants --> jaclang.scale.server.websocket_ext { Constants as Con }
    constants --> jaclang.scale.tests.data.test_eager_spawn { Constants as Con }
    constants --> jaclang.scale.tests.microservices.test_microservice {
        Constants as Con
    }
    constants --> jaclang.server.endpoints.colocated { Constants as Con }
    constants --> jaclang.server.endpoints.pages { Constants as Con }
    constants --> jaclang.server.endpoints.walkers { Constants as Con }
    constants --> jaclang.server.identity.identity_storage { Constants as Con }
    constants --> jaclang.server.identity.user_manager { Constants as Con }
    constants --> jaclang.server.server { Constants as Con }
    constructs --> jaclang.cli.commands.execution._invoke_entrypoint { WalkerArchetype }
    constructs --> jaclang.data.serializer {
        Archetype,
        GenericEdge,
        NodeArchetype,
        Root,
        WalkerArchetype
    }
    constructs --> jaclang.lib.jaclib {
        Archetype as Obj,
        EdgeArchetype as Edge,
        JsxElement,
        NodeArchetype as Node,
        WalkerArchetype as Walker
    }
    type constructs --> jaclang.runtime.builtin { AccessLevel, NodeArchetype }
    constructs --> jaclang.runtime.builtin._get_access_level { AccessLevel }
    type constructs --> jaclang.runtime.graph_utils { EdgeArchetype, NodeArchetype }
    constructs --> jaclang.runtime.runtime {
        AccessLevel,
        Anchor,
        Archetype,
        EdgeAnchor,
        EdgeArchetype,
        JsxElement,
        NodeAnchor,
        NodeArchetype,
        PermissionDenied,
        WalkerAnchor,
        WalkerArchetype,
        access_level_cast
    }
    constructs --> jaclang.scale.memory.context.JScaleExecutionContext.init {
        PermissionDenied
    }
    constructs --> jaclang.server.identity.identity_storage.IdentityStorage.create_user {
        Root
    }
    constructs --> jaclang.server.identity.identity_storage.IdentityStorage.ensure_user_by_id {
        Root
    }
    constructs --> jaclang.server.identity.identity_storage.IdentityStorage.reset_root {
        Root
    }
    type constructs --> jaclang.server.server { Archetype, WalkerArchetype }
    constructs --> jaclang.server.server.ExecutionManager.spawn_walker_async {
        NodeArchetype
    }
    constructs --> jaclang.server.server.ExecutionManager.spawn_walker_sync {
        NodeArchetype
    }
    constructs --> jaclang.server.server.ModuleIntrospector._collect_walkers {
        WalkerArchetype
    }
    constructs --> jaclang.server.server.ModuleIntrospector.scheduled_members {
        WalkerArchetype
    }
    constructs --> jaclang.server.session._ancestry_of {
        Archetype,
        EdgeArchetype,
        NodeArchetype,
        WalkerArchetype
    }
    constructs --> jaclang.server.task_scheduler.Scheduler._execute { WalkerArchetype }
    type context --> jaclang.cli.commands.cli_helpers { ExecutionContext }
    type context --> jaclang.runtime.runtime { ExecutionContext }
    context --> jaclang.runtime.runtime.JacContext.create_j_context { ExecutionContext }
    context --> jaclang.scale.memory.context { CallState, ExecutionContext }
    context --> jaclang.scale.plugin { ExecutionContext }
    type context --> jaclang.scale.runtime.provider { ExecutionContext }
    type context --> jaclang.scale.server.inprocess { ExecutionContext }
    context --> jaclang.scale.tests.server.test_middleware_async_root {
        ExecutionContext
    }
    context --> jaclang.server.server { CallState, ExecutionContext }
    context --> jaclang.server.sv_client._local_spawn { ExecutionContext }
    debugger --> jaclang.cli.commands.execution.debug { debugger as db }
    exceptions --> jaclang.data.store { WriteConflict }
    exceptions --> jaclang.runtime.context { MissingAnchorError }
    exceptions --> jaclang.server.middleware { MissingAnchorError }
    exceptions --> jaclang.server.server { ReadOnlyRetry, WriteConflict }
    exceptions --> jaclang.server.server._abegin_user_request_context {
        MissingAnchorError
    }
    exceptions --> jaclang.server.session { ReadOnlyRetry, WriteConflict }
    graph_query --> jaclang.data.query_planner { GraphQuery, QPred }
    graph_query --> jaclang.data.sqlcompile { GraphQuery, QHop, QPred }
    graph_query --> jaclang.lib.jaclib { GraphQuery, QHop, QOrder, QPred }
    graph_query --> jaclang.runtime.graph_walk { GraphQuery, QHop, QPred }
    graph_query --> jaclang.runtime.runtime {
        GraphQuery,
        QHop,
        QPred,
        filter_query_nodes
    }
    graph_utils --> jaclang.cli.commands.db._project_target { get_name }
    graph_utils --> jaclang.compiler.backends.native.floor.resolve_floor_dir {
        triple_arch
    }
    graph_utils --> jaclang.compiler.backends.native.link_glue.aarch64_floor_atomics_ir {
        triple_arch
    }
    graph_utils --> jaclang.compiler.backends.native.static_link.musl_lib_dir {
        triple_arch
    }
    graph_utils --> jaclang.runtime.builtin._jac_graph_json { collect_node_connections }
    graph_utils --> jaclang.runtime.runtime.JacBuiltin.printgraph { traverse_graph }
    graph_utils --> jaclang.scale.admin.admin_portal.JacAPIServerAdmin.admin_graph_data {
        collect_node_connections
    }
    graph_utils --> jaclang.scale.injector.binary { host_arch, host_os, release_arch }
    graph_utils --> jaclang.scale.injector.binary_injector { host_arch }
    graph_utils --> jaclang.scale.tests.microservices.test_binary_injector { host_arch }
    graph_utils --> jaclang.scale.utils.vendor_wheels { release_arch }
    graph_utils --> jaclang.server.endpoints.pages.register_graph_endpoints.graph_data {
        collect_node_connections
    }
    graph_utils --> jaclang.server.session.project_db_name { get_name }
    graph_walk --> jaclang.data.query_planner {
        access_gated,
        acl_read_ok,
        needs_store,
        origin_anchors,
        pred_subject,
        walk,
        walk_edges,
        walk_nodes
    }
    graph_walk --> jaclang.runtime.runtime.JacGraph.refs {
        access_gated,
        has_persistent_origin,
        needs_store,
        origin_anchors,
        walk_edges,
        walk_nodes
    }
    interop_bridge --> jaclang.compiler.backends.native.na_compile_pass.NativeCompilePass._run_impl {
        register_py_callbacks
    }
    interop_bridge --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass._gen_native_interop_stubs {
        JAC_TO_CTYPES_STR
    }
    interop_bridge --> jaclang.compiler.driver.compiler.JacCompiler._load_native_from_cache {
        register_py_callbacks
    }
    interop_bridge --> jaclang.runtime.prepared.execute_module { NativeLibrary }
    interop_bridge --> jaclang.runtime.source_app._load_application {
        NativeCallback,
        NativeLibrary
    }
    memory --> jaclang.runtime.context | jaclang.server.session { Memory }
    type native_library --> jaclang.cli.commands.execution { SharedNativeEngine }
    type native_library --> jaclang.compiler.driver.compiler { SharedNativeEngine }
    native_library --> jaclang.compiler.driver.compiler.JacCompiler._load_native_from_cache {
        SharedNativeEngine
    }
    native_library --> jaclang.compiler.driver.compiler.JacCompiler._sealed_native_engine {
        shared_engine_for
    }
    type native_library --> jaclang.compiler.frontend.codeinfo { SharedNativeEngine }
    object_interop --> jaclang.byllm.llm._mock_jsonable { fields, is_record }
    object_interop --> jaclang.byllm.schema { is_record }
    object_interop --> jaclang.byllm.tests.test_mtir_integration { fields }
    object_interop --> jaclang.byllm.visit_routing { fields, is_record }
    object_interop --> jaclang.cli.NonGPT { fields as dc_fields, is_record }
    object_interop --> jaclang.compiler.native_compiler.NativeCompiler._field_annotations {
        fields
    }
    object_interop --> jaclang.compiler.native_compiler.NativeCompiler._register_defaults {
        fields
    }
    object_interop --> jaclang.comptime {
        fields as _record_fields,
        is_record as _is_record
    }
    object_interop --> jaclang.data.contracts { fields, is_record }
    object_interop --> jaclang.data.schema_rules { fields, is_record }
    object_interop --> jaclang.data.serializer { fields, is_record }
    object_interop --> jaclang.runtime.semantic.type_to_str { is_record }
    object_interop --> jaclang.runtime.typecache { fields, is_record }
    object_interop --> jaclang.server.server { fields as record_fields, is_record }
    object_interop --> jaclang.server.serving.coerce { is_record }
    object_interop --> jaclang.server.serving.model { fields, is_record }
    object_model --> jaclang.cli.NonGPT { MISSING }
    object_model --> jaclang.compiler.native_compiler.NativeCompiler._field_annotations {
        MISSING
    }
    object_model --> jaclang.compiler.native_compiler.NativeCompiler._register_defaults {
        MISSING
    }
    object_model --> jaclang.comptime { MISSING as _MISSING, ObjectField as _field }
    object_model --> jaclang.data.contracts { MISSING }
    object_model --> jaclang.data.serializer { MISSING }
    object_model --> jaclang.runtime.archetype {
        ObjectField,
        asdict,
        fields,
        is_jac_object,
        make_object
    }
    object_model --> jaclang.runtime.context { MISSING }
    object_model --> jaclang.runtime.object_interop {
        MISSING,
        ObjectField,
        fields as jac_fields,
        is_jac_object
    }
    object_model --> jaclang.runtime.object_pydantic { MISSING, fields }
    object_model --> jaclang.runtime.runtime { make_object }
    object_model --> jaclang.scale.memory.context { MISSING }
    object_model --> jaclang.scale.sdk.spec.DeploySpec.from_config { fields }
    object_model --> jaclang.scale.server.sso_ext { asdict }
    object_model --> jaclang.server.server { MISSING }
    object_pydantic --> jaclang.runtime.object_model._pydantic_schema { object_schema }
    osp_graph as _graph --> jaclang.runtime.osp_graph_sv;
    osp_graph_sv --> jaclang.byllm.visit_routing._candidate_for { sv_register_hydrated }
    osp_graph_sv --> jaclang.runtime.archetype.EdgeAnchor.detach { sv_forget_edge }
    osp_graph_sv --> jaclang.runtime.graph_utils.collect_node_connections {
        sv_live_edges,
        sv_register_hydrated
    }
    osp_graph_sv --> jaclang.runtime.graph_utils.traverse_graph { sv_register_hydrated }
    osp_graph_sv --> jaclang.runtime.osp_kernel_sv { cls_of_tag, tag_of_cls }
    osp_graph_sv --> jaclang.runtime.runtime.JacAccessValidation._groups_of {
        sv_live_edges,
        sv_register_hydrated
    }
    osp_graph_sv --> jaclang.runtime.runtime.JacContext.reset_graph { sv_forget_by_id }
    osp_graph_sv --> jaclang.runtime.runtime.JacGraph.disconnect {
        sv_candidate_edges_between,
        sv_register_hydrated
    }
    osp_graph_sv --> jaclang.runtime.runtime.JacGraph.heavy_edge { sv_conn }
    osp_graph_sv --> jaclang.server.session.Session._drop_snapshot_reads {
        sv_forget_edge
    }
    osp_graph_sv --> jaclang.server.session.Session._evict_uncommitted {
        sv_forget_edge
    }
    osp_graph_sv --> jaclang.server.session.Session.close { sv_store_closed }
    osp_graph_sv --> jaclang.server.session.Session.quarantine_ref { sv_forget_by_id }
    osp_kernel --> jaclang.byllm.visit_routing._route_context { _current_scope }
    osp_kernel --> jaclang.compiler.backends.es.esast_gen_pass { osp_skip_rest }
    osp_kernel --> jaclang.compiler.backends.py.jcir_gen_pass { osp_skip_rest }
    osp_kernel --> jaclang.compiler.passes.comptime_resolve_pass { osp_skip_rest }
    osp_kernel --> jaclang.compiler.passes.context.CompileContext.enter_node {
        osp_skip_rest
    }
    osp_kernel --> jaclang.compiler.passes.context.CompileContext.exit_node {
        osp_skip_rest
    }
    osp_kernel --> jaclang.compiler.passes.jsx_intrinsic_guard_pass { osp_skip_rest }
    osp_kernel --> jaclang.compiler.passes.scope_walk { osp_skip_rest }
    osp_kernel --> jaclang.compiler.tools.grammar_extract_pass { osp_skip_rest }
    osp_kernel as _kernel --> jaclang.runtime.osp_kernel_sv;
    osp_kernel --> jaclang.runtime.osp_kernel_sv {
        OspNodeDesc,
        OspRuntime,
        OspSlot,
        OspWalkScope,
        OspWalkerDesc,
        UNTYPED
    }
    osp_kernel --> jaclang.runtime.runtime.JacBuiltin.log_report {
        _current_scope,
        osp_report
    }
    osp_kernel --> jaclang.runtime.runtime.JacGraph.clear_edges { osp_forget }
    osp_kernel --> jaclang.runtime.runtime.JacPersistence.destroy { osp_forget }
    osp_kernel --> jaclang.runtime.runtime.JacWalker.disengage { osp_disengage }
    osp_kernel --> jaclang.runtime.runtime.JacWalker.spawn_call { osp_spawn }
    osp_kernel --> jaclang.runtime.runtime.JacWalker.visit { osp_visit, scope_of }
    osp_kernel_sv --> jaclang.runtime.runtime.JacWalker.async_spawn_call {
        desc_for,
        make_sv_runtime,
        osp_spawn_async
    }
    osp_kernel_sv --> jaclang.runtime.runtime.JacWalker.spawn_call {
        desc_for,
        make_sv_runtime
    }
    osp_kernel_sv --> jaclang.server.server._begin_request_context {
        isolate_request_walk_stack
    }
    osp_tag --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._build_osp_tags_js {
        stable_osp_tag
    }
    osp_tag --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._edge_tag_literal {
        stable_osp_tag
    }
    osp_tag --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._osp_slots_js {
        stable_osp_tag
    }
    osp_tag --> jaclang.compiler.backends.native.na_ir_gen_pass { stable_osp_tag }
    osp_tag --> jaclang.compiler.backends.py.jcir_gen_pass.JcirGenPass.exit_module {
        stable_osp_tag
    }
    osp_tag --> jaclang.compiler.jc_unit._alert_tag { stable_osp_tag }
    osp_tag --> jaclang.compiler.native_compiler { stable_osp_tag }
    osp_tag --> jaclang.compiler.passes.osp_analysis { stable_osp_tag }
    osp_tag --> jaclang.runtime.osp_graph_sv.tag_of_cls { stable_osp_tag }
    portability --> jaclang.compiler.placement.placement_solver._py_import_client_portable {
        supports
    }
    prepared --> jaclang.cli.commands.execution.serve { initialize_application }
    prepared --> jaclang.client.targets.client_dev_common.dev_proxy_paths {
        prepared_manifest
    }
    type prepared --> jaclang.compiler.driver.application { PreparedApplication }
    prepared --> jaclang.compiler.driver.application._prepare {
        PreparedApplication,
        publish
    }
    prepared --> jaclang.compiler.driver.application._prepare_sealed {
        PreparedApplication,
        publish
    }
    prepared --> jaclang.compiler.driver.application.prepare_application { publish }
    prepared --> jaclang.compiler.driver.application.prepare_dynamic_module { publish }
    type prepared --> jaclang.compiler.driver.build_services { PreparedApplication }
    prepared --> jaclang.dist.source.client { PreparedApplication }
    prepared --> jaclang.dist.source.project {
        PreparedApplication,
        application_namespace
    }
    prepared --> jaclang.project.config.JacConfig.app_for_path { origin_for_source }
    type prepared --> jaclang.runtime.build_services { PreparedApplication }
    type prepared --> jaclang.runtime.prepared_loader { PreparedApplication }
    prepared --> jaclang.runtime.prepared_loader.PreparedFinder.find_spec {
        _applications,
        application_namespace,
        entry_alias,
        qualified_module
    }
    prepared --> jaclang.runtime.prepared_loader.PreparedLoader.exec_module {
        execute_module
    }
    prepared --> jaclang.runtime.runtime.JacLLM.get_mtir_from_map { semantic_for_scope }
    prepared --> jaclang.runtime.runtime.JacModule.impl_patch_filename.decorator {
        application_for
    }
    prepared --> jaclang.runtime.source_app {
        PreparedApplication,
        initialize_application,
        publish
    }
    prepared --> jaclang.scale.server.inprocess.prepare_inprocess_runtime {
        initialize_application
    }
    type prepared --> jaclang.server.assembly { PreparedApplication }
    prepared --> jaclang.server.assembly.colocate_services { load_prepared_module }
    prepared --> jaclang.server.endpoint_contract.check_endpoint_contract {
        application_for
    }
    prepared --> jaclang.server.hmr.HotReloader._dispatch_change { application_for }
    prepared --> jaclang.server.hmr.HotReloader._reload_server_module {
        application_for,
        initialize_application
    }
    prepared --> jaclang.server.sealed_serve.client_dist_for { application_for }
    prepared --> jaclang.server.sealed_serve.serve_manifest_for { prepared_manifest }
    prepared --> jaclang.server.server.JacAPIServer._ensure_client_bundle {
        application_for
    }
    prepared --> jaclang.server.server.ModuleIntrospector._resolve_declared {
        application_for,
        load_prepared_module,
        source_for_origin
    }
    prepared --> jaclang.testing.testing.JacTestClient._ensure_initialized {
        initialize_application
    }
    prepared --> jaclang.testing.testing.JacTestClient.close { forget }
    prepared_loader --> jaclang.runtime.prepared.ensure_namespace { PreparedLoader }
    prepared_loader --> jaclang.runtime.prepared.publish { PreparedFinder }
    region --> jaclang.runtime.archetype.Archetype.__init_subclass__ { is_drop_hook }
    region as _region_mod --> jaclang.runtime.builtin.__getattr__;
    region --> jaclang.runtime.runtime.JacPersistence.destroy { run_drop }
    runtime --> jaclang.byllm.lib { JacRuntime }
    runtime --> jaclang.byllm.tests.support.need_outside_jaclang { JacRuntime }
    runtime --> jaclang.byllm.tests.test_byllm { JacRuntime }
    runtime --> jaclang.byllm.tests.test_routing { JacRuntime }
    runtime --> jaclang.byllm.visit_routing._candidate_for { JacRuntimeInterface }
    runtime --> jaclang.byllm.visit_routing.route_visit { JacRuntime as Jac }
    runtime --> jaclang.cli.commands.analysis.check.run_units { JacRuntime }
    runtime --> jaclang.cli.commands.cli_helpers.proc_file { JacRuntime as Jac }
    runtime --> jaclang.cli.commands.execution._discover_config_from_file {
        JacRuntime as Jac
    }
    runtime --> jaclang.cli.commands.execution._exec_file { JacRuntime as Jac }
    runtime --> jaclang.cli.commands.execution._invoke_entrypoint { JacRuntime as Jac }
    runtime --> jaclang.cli.commands.execution._pin_run_scope { JacRuntime as Jac }
    runtime --> jaclang.cli.commands.execution.serve { JacRuntime as Jac }
    runtime --> jaclang.cli.commands.tools.dot { JacRuntime as Jac }
    runtime --> jaclang.cli.console._get_console { JacRuntime as Jac }
    runtime --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.format_snippet._do_format {
        JacRuntime as Jac
    }
    runtime --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.get_ast_snippet._do_ast {
        JacRuntime as Jac
    }
    runtime --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.jac_to_js._do_jac2js {
        JacRuntime as Jac
    }
    runtime --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.jac_to_py._do_jac2py {
        JacRuntime as Jac
    }
    runtime --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.lint_snippet._do_lint {
        JacRuntime as Jac
    }
    runtime --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.parse_snippet._do_parse {
        JacRuntime as Jac
    }
    runtime --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.py_to_jac._do_py2jac {
        JacRuntime as Jac
    }
    runtime --> jaclang.cli.mcp.compiler_bridge.CompilerBridge.typecheck_snippet._do_typecheck {
        JacRuntime as Jac
    }
    runtime --> jaclang.client.cli.run_client_build { JacRuntime as Jac }
    runtime --> jaclang.client.cli.run_client_setup { JacRuntime as Jac }
    runtime --> jaclang.client.cli.run_client_start { JacRuntime as Jac }
    runtime --> jaclang.client.client_bundle.client_program { JacRuntime }
    runtime --> jaclang.client.route_scanner.resolve_route_exports { JacRuntime as Jac }
    runtime --> jaclang.client.targets.client_dev_common.dev_proxy_paths {
        JacRuntime as Jac
    }
    runtime --> jaclang.client.targets.mobile_target { JacRuntime as Jac }
    runtime --> jaclang.client.targets.web_target.WebTarget.build { JacRuntime as Jac }
    runtime --> jaclang.client.targets.web_target._get_client_function_name {
        JacRuntime as Jac
    }
    runtime --> jaclang.client.vite_client_bundle.make_client_bundle_builder {
        JacRuntime as Jac
    }
    runtime --> jaclang.compiler.driver.compiler.JacCompiler.selfhost.getter {
        JacRuntime
    }
    runtime --> jaclang.compiler.driver.selfhost.SelfHostCache.program.getter {
        JacRuntime
    }
    runtime --> jaclang.compiler.tests.test_stubcat_roundtrip.small_catalog {
        JacRuntime
    }
    runtime --> jaclang.data.query_planner.LazyRefs._mem { JacRuntimeInterface }
    runtime --> jaclang.data.query_planner._acl_pushdown_root { JacRuntimeInterface }
    runtime --> jaclang.dist.seal.bake_serve_payloads { JacRuntime as Jac }
    runtime --> jaclang.dist.seal.build_serve_manifest { JacRuntime as Jac }
    runtime --> jaclang.lib.jaclib { JacRuntimeInterface }
    runtime --> jaclang.project.config.JacConfig.app_for_target { JacRuntime }
    runtime --> jaclang.project.plugin_config { JacRuntime }
    runtime --> jaclang.runtime.archetype.EdgeAnchor.detach { JacRuntime }
    runtime --> jaclang.runtime.archetype.NodeAnchor.all_edges { JacRuntimeInterface }
    runtime --> jaclang.runtime.archetype.Root.__getattr__ { JacRuntime }
    runtime --> jaclang.runtime.archetype._dirty_setattr { JacRuntime }
    type runtime --> jaclang.runtime.builtin { LLMModel }
    runtime --> jaclang.runtime.context.ExecutionContext.__post_init__ { JacRuntime }
    runtime --> jaclang.runtime.graph_utils.collect_node_connections { resolve_ref }
    runtime --> jaclang.runtime.graph_utils.get_name { JacRuntime }
    runtime --> jaclang.runtime.graph_utils.traverse_graph { JacRuntimeInterface }
    runtime --> jaclang.runtime.graph_walk.access_gated { JacRuntimeInterface }
    runtime --> jaclang.runtime.graph_walk.acl_read_ok { JacRuntimeInterface }
    runtime --> jaclang.runtime.interop_bridge._pyb_import_module { JacModule }
    runtime --> jaclang.runtime.osp_graph_sv._mem_or_ctx {
        JacRuntime,
        _request_context
    }
    runtime --> jaclang.runtime.osp_kernel_sv._sv_on_complete {
        JacRuntime,
        _request_context
    }
    runtime --> jaclang.runtime.prepared.execute_module { JacRuntime as Jac }
    runtime --> jaclang.runtime.prepared.load_prepared_module { JacRuntime as Jac }
    runtime --> jaclang.runtime.semantic.fetch_mtir { JacRuntime }
    runtime --> jaclang.runtime.source_app.main { JacRuntime as Jac }
    runtime --> jaclang.scale.admin.admin_portal { JacRuntime as Jac }
    runtime --> jaclang.scale.memory.context.JScaleExecutionContext.init { JacRuntime }
    runtime --> jaclang.server.endpoints.pages { JacRuntime as Jac }
    runtime --> jaclang.server.hmr.HotReloader._recompile_client_code {
        JacRuntime as Jac
    }
    runtime --> jaclang.server.hmr.HotReloader._recompile_client_unified {
        JacRuntime as Jac
    }
    runtime --> jaclang.server.hmr.HotReloader._reload_server_module {
        JacRuntime as Jac
    }
    runtime --> jaclang.server.middleware { JacRuntime }
    runtime --> jaclang.server.server.ModuleIntrospector._check_module_freshness {
        JacRuntime as Jac
    }
    runtime --> jaclang.server.server.ModuleIntrospector._resolve_declared {
        JacRuntime as Jac
    }
    runtime --> jaclang.server.serving.supervisor.WorkerSupervisor._spawn { JacRuntime }
    runtime --> jaclang.server.shared_store.shared_store { JacRuntime }
    runtime --> jaclang.server.static_files { JacRuntime as Jac }
    runtime --> jaclang.server.sv_client._scale_transport { _scale_provider }
    runtime --> jaclang.testing.runner { JacRuntimeInterface }
    runtime --> jaclang.testing.test_runner._fresh_jac_state {
        JacRuntime,
        JacRuntimeInterface
    }
    scalars --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._apply_fw_coercion {
        shape_of
    }
    scalars --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._exit_name_impl {
        is_sized
    }
    scalars --> jaclang.compiler.backends.es.esast_gen_pass.EsastGenPass._fw_binary {
        shape_of
    }
    scalars --> jaclang.compiler.backends.es.jac_runtime_js._build_fw_runtime_js {
        numeric_shapes,
        range_of
    }
    scalars --> jaclang.compiler.backends.es.jac_runtime_js._build_types_runtime_js {
        numeric_shapes
    }
    scalars --> jaclang.compiler.backends.es.primitives_es.ESBuiltinEmitter.emit_abs {
        is_sized
    }
    scalars --> jaclang.compiler.backends.es.primitives_es.ESBuiltinEmitter.emit_print {
        shape_of
    }
    scalars --> jaclang.compiler.backends.es.primitives_es.ESBuiltinEmitter.emit_wrapping {
        is_sized
    }
    scalars --> jaclang.compiler.backends.native.na_ir_gen_pass {
        ScalarShape,
        range_of,
        shape_of,
        wrap_value
    }
    scalars --> jaclang.compiler.backends.py.jcir_facts { sized_scalar_names }
    scalars --> jaclang.compiler.backends.py.jcir_gen_pass { shape_of }
    scalars --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass.finish {
        sized_scalar_names
    }
    scalars --> jaclang.compiler.passes.wasm_contract.value_contract {
        ScalarShape,
        shape_range
    }
    scalars --> jaclang.compiler.type_registry {
        ScalarShape,
        numeric_shapes,
        shape_literal_fits,
        shape_range,
        shapes_unify,
        shapes_widen_to,
        sized_scalar_names
    }
    scalars --> jaclang.compiler.types.ct_eval { shape_of }
    scalars --> jaclang.compiler.types.fixed_width.adopt_literal { float_max }
    scalars --> jaclang.comptime._scalar_size_align { shape_of }
    scalars --> jaclang.runtime.builtin._is_sized_type_name { is_sized }
    scalars --> jaclang.runtime.cinterop { numeric_shapes }
    scalars --> jaclang.runtime.sized { numeric_shapes, range_of, shape_of, wrap_value }
    semantic --> jaclang.byllm.mtir { FunctionInfo, Info, MethodInfo }
    semantic --> jaclang.byllm.schema {
        ClassInfo,
        EnumInfo,
        FieldInfo,
        FunctionInfo,
        Info,
        ParamInfo,
        VarInfo
    }
    semantic --> jaclang.byllm.tests.test_mtir_integration {
        ClassInfo,
        EnumInfo,
        FieldInfo,
        FunctionInfo,
        MTIR,
        MethodInfo,
        ParamInfo,
        fetch_mtir,
        mk_dict,
        mk_list
    }
    semantic --> jaclang.byllm.types | jaclang.runtime.runtime { Info }
    semantic --> jaclang.byllm.visit_routing { ClassInfo }
    semantic --> jaclang.byllm.visit_routing._class_info { fetch_mtir }
    type semantic --> jaclang.compiler.driver.program { Info }
    type semantic --> jaclang.compiler.driver.progstate { Info }
    semantic --> jaclang.compiler.passes.mtir_gen_pass {
        ClassInfo,
        EnumInfo,
        FieldInfo,
        FunctionInfo,
        MethodInfo,
        ParamInfo,
        mk_dict,
        mk_list,
        mk_tuple,
        type_to_str
    }
    semantic --> jaclang.runtime.constructs { MTIR, MTRuntime }
    type semantic --> jaclang.runtime.prepared { Info }
    semantic --> jaclang.runtime.runtime.JacLLM.by._decorator._wrapped_caller {
        fetch_mtir
    }
    semantic --> jaclang.runtime.runtime.JacLLM.get_mtir { fetch_mtir }
    sized --> jaclang.compiler.tests.test_fixed_width_equivalence { SIZED_TYPES }
    sized --> jaclang.data.serializer.Serializer._declared_of { SIZED_TYPES }
    sized --> jaclang.data.serializer.Serializer._serialize_value { json_wire_form }
    sized --> jaclang.data.serializer.Serializer.coerce { json_wire_read }
    sized as _sized_mod --> jaclang.runtime.builtin.__getattr__;
    source_app --> jaclang.dist.source.project.export_project { SOURCE_FORMAT }
    surface --> jaclang.compiler.driver.compiler.JacCompiler._deserialize_interop_table {
        SurfaceEntry
    }
    surface --> jaclang.compiler.frontend.codeinfo { SurfaceEntry }
    surface --> jaclang.compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._record_surface {
        SurfaceEntry
    }
    surface --> jaclang.server.server.ModuleIntrospector._load_surface { SurfaceEntry }
    traceback_render --> jaclang.cli.commands.execution._exec_file { dump_traceback }
    traceback_render --> jaclang.cli.commands.execution.serve { dump_traceback }
    typecache --> jaclang.data.serializer { get_field_types }
    typecache --> jaclang.data.serializer.Serializer.register {
        invalidate as _invalidate_typecache,
        warm as _warm_typecache
    }
}

impl import jaclang.runtime.python {
    capi --> jaclang.compiler.backends.py.jacpython.native_api {
        boundary_failure,
        checked,
        jacpy_int,
        jacpy_none,
        jacpy_release,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        required,
        text_object,
        text_value
    }
    capi --> jaclang.compiler.frontend.python.ast_input { boundary_failure }
    capi --> jaclang.compiler.frontend.python.ast_output { boundary_failure }
    capi --> jaclang.compiler.frontend.python.source_encoding { boundary_failure }
    capi --> jaclang.compiler.frontend.python.source_input {
        boundary_failure,
        read_buffer
    }
    capi --> jaclang.runtime.python.bindings.arguments {
        boundary_failure,
        jacpy_dict_items,
        jacpy_error_pending,
        jacpy_index,
        jacpy_is_unicode,
        jacpy_list_item,
        jacpy_list_size,
        jacpy_release,
        jacpy_retain,
        jacpy_tuple_item,
        jacpy_tuple_size,
        jacpy_unicode_char,
        jacpy_unicode_size,
        object_error,
        required,
        text_value
    }
    capi --> jaclang.runtime.python.bindings.array {
        SliceBounds,
        jac_heap_size,
        jacpy_audit,
        jacpy_builtins,
        jacpy_call,
        jacpy_call_one,
        jacpy_dict_get,
        jacpy_dict_size,
        jacpy_error_pending,
        jacpy_getattr_string,
        jacpy_import_attr,
        jacpy_index_check,
        jacpy_int,
        jacpy_is_bytearray,
        jacpy_is_bytes,
        jacpy_is_list,
        jacpy_is_long,
        jacpy_is_slice,
        jacpy_is_type,
        jacpy_is_unicode,
        jacpy_long_as_int32,
        jacpy_none,
        jacpy_not_implemented,
        jacpy_number_ssize,
        jacpy_optional_attr,
        jacpy_release,
        jacpy_retain,
        jacpy_slice_adjust,
        jacpy_slice_unpack,
        jacpy_tuple_new,
        jacpy_type_check,
        jacpy_type_subtype,
        jacpy_uint,
        jacpy_unicode_from_ordinal,
        jacpy_warn,
        object_error,
        text_object,
        type_name
    }
    capi --> jaclang.runtime.python.bindings.binascii {
        jacpy_buffer_byte,
        jacpy_error_pending,
        jacpy_is_bytes,
        jacpy_is_unicode,
        jacpy_long_as_int32,
        jacpy_object_size,
        jacpy_release,
        jacpy_truth,
        object_error
    }
    capi --> jaclang.runtime.python.bindings.bisect { jacpy_is_none }
    capi --> jaclang.runtime.python.bindings.cmath { jacpy_complex, jacpy_float }
    capi --> jaclang.runtime.python.bindings.collections {
        boundary_failure,
        jac_heap_size,
        jacpy_call,
        jacpy_call_one,
        jacpy_callable,
        jacpy_dict_new,
        jacpy_dict_update,
        jacpy_error_pending,
        jacpy_getattr_string,
        jacpy_int,
        jacpy_is_dict,
        jacpy_is_none,
        jacpy_is_tuple,
        jacpy_iter,
        jacpy_none,
        jacpy_not_implemented,
        jacpy_ordered_dict_new,
        jacpy_release,
        jacpy_retain,
        jacpy_tuple_item,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_tuple_size,
        jacpy_tuple_slice,
        jacpy_type_check,
        object_error,
        repr_value,
        text_object,
        type_name
    }
    capi --> jaclang.runtime.python.bindings.csv {
        jacpy_call,
        jacpy_callable,
        jacpy_dict_new,
        jacpy_dict_set,
        jacpy_error_pending,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_exact_long,
        jacpy_is_unicode,
        jacpy_iter,
        jacpy_none,
        jacpy_optional_attr,
        jacpy_release,
        jacpy_retain,
        jacpy_text,
        jacpy_tuple_item,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_type_check,
        jacpy_unicode_from_ordinal,
        object_error,
        type_name
    }
    capi --> jaclang.runtime.python.bindings.functools {
        boundary_failure,
        jacpy_callable,
        jacpy_compare,
        jacpy_dict_size,
        jacpy_error_pending,
        jacpy_getattr_string,
        jacpy_index_check,
        jacpy_is_none,
        jacpy_none,
        jacpy_not_implemented,
        jacpy_recursion_enter,
        jacpy_recursion_leave,
        jacpy_release,
        jacpy_retain,
        jacpy_truth,
        jacpy_tuple_item,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_tuple_size,
        jacpy_tuple_slice,
        jacpy_type_check,
        object_error,
        text_object
    }
    capi --> jaclang.runtime.python.bindings.heapq { jacpy_is_list, type_name }
    capi --> jaclang.runtime.python.bindings.itertools {
        boundary_failure,
        jacpy_clear_error,
        jacpy_dict_get,
        jacpy_dict_size,
        jacpy_error_pending,
        jacpy_int,
        jacpy_is_list,
        jacpy_is_none,
        jacpy_list_size,
        jacpy_none,
        jacpy_number_check,
        jacpy_number_ssize,
        jacpy_release,
        jacpy_retain,
        jacpy_truth,
        jacpy_tuple_item,
        jacpy_tuple_size,
        jacpy_type_check,
        object_error,
        required,
        text_object,
        type_name
    }
    capi --> jaclang.runtime.python.bindings.json {
        boundary_failure,
        jacpy_boolean,
        jacpy_getattr_string,
        jacpy_is_dict,
        jacpy_is_none,
        jacpy_is_unicode,
        jacpy_release,
        jacpy_retain,
        jacpy_truth,
        object_error,
        object_tuple,
        type_name
    }
    capi --> jaclang.runtime.python.bindings.math { jacpy_float }
    capi --> jaclang.runtime.python.bindings.module { jacpy_release }
    capi --> jaclang.runtime.python.bindings.operator {
        boundary_failure,
        jacpy_dict_size,
        jacpy_is_unicode,
        jacpy_release,
        jacpy_retain,
        jacpy_tuple_size,
        object_error,
        text_object,
        type_name
    }
    capi --> jaclang.runtime.python.bindings.pickle {
        boundary_failure,
        builtin_kind,
        jacpy_boolean,
        jacpy_builtin_type,
        jacpy_call,
        jacpy_call_one,
        jacpy_clear_error,
        jacpy_dict_new,
        jacpy_dict_set,
        jacpy_error_is,
        jacpy_error_pending,
        jacpy_generic_getattr,
        jacpy_generic_setattr,
        jacpy_getattr_string,
        jacpy_import_attr,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_none,
        jacpy_is_unicode,
        jacpy_long_as_int32,
        jacpy_none,
        jacpy_optional_attr,
        jacpy_release,
        jacpy_retain,
        jacpy_set_exception,
        jacpy_truth,
        object_error,
        required,
        text_object,
        text_value
    }
    capi --> jaclang.runtime.python.bindings.queue {
        jacpy_boolean,
        jacpy_int,
        jacpy_lock_new,
        jacpy_none,
        jacpy_release,
        jacpy_truth,
        object_error
    }
    capi --> jaclang.runtime.python.bindings.random {
        jacpy_dict_size,
        jacpy_error_pending,
        jacpy_float,
        jacpy_index,
        jacpy_is_none,
        jacpy_long_sign,
        jacpy_long_u64,
        jacpy_none,
        jacpy_release,
        object_error
    }
    capi --> jaclang.runtime.python.bindings.references {
        jacpy_release,
        jacpy_tuple_new,
        jacpy_tuple_set_owned
    }
    capi --> jaclang.runtime.python.bindings.struct {
        boundary_failure,
        jac_heap_size,
        jac_list_heap_size,
        jacpy_bytes_address,
        jacpy_bytes_decode,
        jacpy_bytes_from_memory,
        jacpy_dict_clear,
        jacpy_dict_new,
        jacpy_error_pending,
        jacpy_int,
        jacpy_is_bytes,
        jacpy_is_unicode,
        jacpy_none,
        jacpy_release,
        jacpy_retain,
        jacpy_set_exception,
        jacpy_tuple_item,
        jacpy_tuple_size,
        jacpy_tuple_slice,
        jacpy_unicode_encode,
        object_error,
        repr_value,
        text_object,
        type_name
    }
    capi --> jaclang.runtime.python.constant_input { boundary_failure, read_buffer }
    capi --> jaclang.runtime.python.constant_output {
        checked,
        jacpy_boolean,
        jacpy_complex,
        jacpy_ellipsis,
        jacpy_float,
        jacpy_int,
        jacpy_long_from_bytes,
        jacpy_neg,
        jacpy_none,
        jacpy_release,
        jacpy_retain,
        jacpy_set_new,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        required,
        text_object,
        write_buffer
    }
    capi --> jaclang.runtime.python.modules.array {
        boundary_failure,
        checked,
        jac_heap_size,
        jacpy_boolean,
        jacpy_bytearray_memory,
        jacpy_bytearray_new,
        jacpy_bytearray_resize,
        jacpy_bytes_address,
        jacpy_bytes_from_memory,
        jacpy_bytes_length,
        jacpy_call,
        jacpy_call_one,
        jacpy_compare,
        jacpy_compare_bool,
        jacpy_error_pending,
        jacpy_float,
        jacpy_float32_bits,
        jacpy_float_bits,
        jacpy_float_unpack,
        jacpy_getattr_string,
        jacpy_index,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_bytes,
        jacpy_is_unicode,
        jacpy_iter,
        jacpy_iter_next,
        jacpy_list_append,
        jacpy_list_new,
        jacpy_long_u64,
        jacpy_memory_copy,
        jacpy_memory_move,
        jacpy_memory_zero,
        jacpy_native_little_endian,
        jacpy_native_size,
        jacpy_number_as_double,
        jacpy_release,
        jacpy_retain,
        jacpy_unicode_char,
        jacpy_unicode_decode_bytes,
        jacpy_unicode_from_ordinal,
        jacpy_unicode_join,
        jacpy_unicode_size,
        object_error,
        object_tuple,
        repr_value,
        required,
        text_object
    }
    capi --> jaclang.runtime.python.modules.binary_scalars {
        jacpy_int,
        jacpy_memory_byte,
        jacpy_memory_set,
        jacpy_uint,
        required
    }
    capi --> jaclang.runtime.python.modules.binascii {
        jacpy_buffer_byte,
        jacpy_buffer_size,
        jacpy_int,
        jacpy_set_exception,
        module_failure,
        object_error,
        read_buffer,
        write_buffer
    }
    capi --> jaclang.runtime.python.modules.bisect {
        jacpy_call_one,
        jacpy_comparison_slot,
        jacpy_insert,
        jacpy_int,
        jacpy_less,
        jacpy_none,
        jacpy_object_size,
        jacpy_recursion_enter,
        jacpy_recursion_leave,
        jacpy_release,
        jacpy_same_type,
        jacpy_sequence_slot,
        jacpy_slot_item,
        jacpy_slot_less,
        object_error
    }
    capi --> jaclang.runtime.python.modules.cmath {
        boundary_failure,
        checked,
        jacpy_boolean,
        jacpy_clear_errno,
        jacpy_complex,
        jacpy_complex_imag,
        jacpy_complex_real,
        jacpy_complex_value,
        jacpy_error_is,
        jacpy_error_pending,
        jacpy_float,
        jacpy_math_errno,
        jacpy_number_as_double,
        jacpy_release,
        jacpy_truediv,
        object_error,
        object_tuple,
        required
    }
    capi --> jaclang.runtime.python.modules.collections {
        boundary_failure,
        checked,
        jac_heap_size,
        jac_list_heap_size,
        jacpy_add,
        jacpy_boolean,
        jacpy_call,
        jacpy_compare_bool,
        jacpy_dict_default,
        jacpy_dict_repr,
        jacpy_error_pending,
        jacpy_getattr,
        jacpy_int,
        jacpy_is_none,
        jacpy_iter,
        jacpy_iter_next,
        jacpy_release,
        jacpy_repr_enter,
        jacpy_repr_leave,
        jacpy_retain,
        jacpy_sequence_list,
        jacpy_set_key_error,
        jacpy_setitem,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        object_error,
        repr_value,
        required,
        text_object,
        text_value,
        type_name
    }
    capi --> jaclang.runtime.python.modules.combinatorics {
        boundary_failure,
        checked,
        jac_heap_size,
        jac_list_heap_size,
        jacpy_release,
        jacpy_retain,
        jacpy_sequence_tuple,
        jacpy_tuple_exchange,
        jacpy_tuple_item,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_tuple_size,
        object_error,
        required
    }
    capi --> jaclang.runtime.python.modules.csv {
        boundary_failure,
        checked,
        jacpy_boolean,
        jacpy_call_one,
        jacpy_clear_error,
        jacpy_dict_get,
        jacpy_dict_keys,
        jacpy_dict_pop_discard,
        jacpy_dict_set,
        jacpy_error_is,
        jacpy_error_pending,
        jacpy_getattr_string,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_exact_long,
        jacpy_is_none,
        jacpy_is_unicode,
        jacpy_iter,
        jacpy_iter_next,
        jacpy_list_append,
        jacpy_list_new,
        jacpy_long_as_int32,
        jacpy_none,
        jacpy_number_check,
        jacpy_number_float,
        jacpy_object_str,
        jacpy_release,
        jacpy_retain,
        jacpy_set_exception,
        jacpy_truth,
        jacpy_tuple_item,
        jacpy_type_check,
        jacpy_unicode_char,
        jacpy_unicode_size,
        jacpy_writer_char,
        jacpy_writer_discard,
        jacpy_writer_finish,
        jacpy_writer_new,
        object_error,
        object_tuple,
        required,
        text_object,
        type_name
    }
    capi --> jaclang.runtime.python.modules.functools {
        boundary_failure,
        checked,
        jacpy_boolean,
        jacpy_call,
        jacpy_call_one,
        jacpy_call_two,
        jacpy_callable,
        jacpy_compare,
        jacpy_dict_clear,
        jacpy_dict_copy,
        jacpy_dict_entry,
        jacpy_dict_get,
        jacpy_dict_new,
        jacpy_dict_set,
        jacpy_dict_size,
        jacpy_dict_update,
        jacpy_error_is,
        jacpy_error_pending,
        jacpy_getattr_string,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_dict,
        jacpy_is_exact_dict,
        jacpy_is_exact_long,
        jacpy_is_exact_tuple,
        jacpy_is_exact_unicode,
        jacpy_is_none,
        jacpy_is_tuple,
        jacpy_iter,
        jacpy_iter_next,
        jacpy_none,
        jacpy_object_hash,
        jacpy_object_str,
        jacpy_object_type,
        jacpy_ordered_dict_new,
        jacpy_release,
        jacpy_repr_enter,
        jacpy_repr_leave,
        jacpy_retain,
        jacpy_sequence_tuple,
        jacpy_setitem,
        jacpy_tuple_item,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_tuple_size,
        object_error,
        repr_value,
        required,
        text_object,
        text_value,
        type_name
    }
    capi --> jaclang.runtime.python.modules.grouping {
        boundary_failure,
        checked,
        jacpy_call_one,
        jacpy_compare_bool,
        jacpy_is_none,
        jacpy_iter,
        jacpy_iter_next,
        jacpy_release,
        jacpy_retain,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        required
    }
    capi --> jaclang.runtime.python.modules.heapq {
        jacpy_less,
        jacpy_list_append,
        jacpy_list_delete,
        jacpy_list_exchange,
        jacpy_list_item,
        jacpy_list_size,
        jacpy_list_swap,
        jacpy_none,
        jacpy_release,
        jacpy_retain,
        object_error
    }
    capi --> jaclang.runtime.python.modules.iterators {
        boundary_failure,
        checked,
        jacpy_add,
        jacpy_call,
        jacpy_call_one,
        jacpy_call_two,
        jacpy_clear_error,
        jacpy_error_pending,
        jacpy_integer_value,
        jacpy_is_long,
        jacpy_is_none,
        jacpy_iter,
        jacpy_iter_next,
        jacpy_list_append,
        jacpy_list_exchange,
        jacpy_list_item,
        jacpy_list_new,
        jacpy_list_size,
        jacpy_none,
        jacpy_release,
        jacpy_retain,
        jacpy_sequence_tuple,
        jacpy_truth,
        jacpy_tuple_exchange,
        jacpy_tuple_item,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_tuple_size,
        jacpy_tuple_unique,
        object_error,
        repr_value,
        required,
        text_object,
        type_name
    }
    capi --> jaclang.runtime.python.modules.json {
        boundary_failure,
        checked,
        jacpy_boolean,
        jacpy_call,
        jacpy_call_one,
        jacpy_contains,
        jacpy_dict_default,
        jacpy_dict_entry,
        jacpy_dict_new,
        jacpy_dict_remove,
        jacpy_dict_set,
        jacpy_dict_size,
        jacpy_error_pending,
        jacpy_fast_item,
        jacpy_fast_size,
        jacpy_float_repr,
        jacpy_float_value,
        jacpy_identity,
        jacpy_import_attr,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_bool,
        jacpy_is_dict,
        jacpy_is_exact_dict,
        jacpy_is_float,
        jacpy_is_list,
        jacpy_is_long,
        jacpy_is_none,
        jacpy_is_tuple,
        jacpy_is_unicode,
        jacpy_list_append,
        jacpy_list_item,
        jacpy_list_new,
        jacpy_list_size,
        jacpy_list_sort,
        jacpy_long_repr,
        jacpy_mapping_items,
        jacpy_none,
        jacpy_raise_value,
        jacpy_recursion_enter,
        jacpy_recursion_leave,
        jacpy_release,
        jacpy_retain,
        jacpy_sequence_fast,
        jacpy_sequence_repeat,
        jacpy_set_object_exception,
        jacpy_truth,
        jacpy_tuple_item,
        jacpy_tuple_size,
        jacpy_unicode_char,
        jacpy_unicode_concat,
        jacpy_unicode_size,
        jacpy_unicode_slice,
        jacpy_writer_ascii,
        jacpy_writer_char,
        jacpy_writer_discard,
        jacpy_writer_finish,
        jacpy_writer_new,
        jacpy_writer_slice,
        jacpy_writer_text,
        object_error,
        object_tuple,
        pair,
        repr_value,
        required,
        serialization_note,
        text_object,
        type_name
    }
    capi --> jaclang.runtime.python.modules.math {
        boundary_failure,
        jacpy_abs,
        jacpy_add,
        jacpy_boolean,
        jacpy_clear_errno,
        jacpy_clear_error,
        jacpy_compare_bool,
        jacpy_error_pending,
        jacpy_float,
        jacpy_float_bits,
        jacpy_float_from_bits,
        jacpy_floordiv,
        jacpy_index,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_bool,
        jacpy_is_exact_float,
        jacpy_is_exact_long,
        jacpy_is_long,
        jacpy_is_none,
        jacpy_is_tuple,
        jacpy_iter,
        jacpy_iter_next,
        jacpy_libm_parts,
        jacpy_long_bits,
        jacpy_long_double,
        jacpy_long_fits_i64,
        jacpy_long_frexp,
        jacpy_long_from_double,
        jacpy_long_gcd,
        jacpy_long_shift,
        jacpy_long_sign,
        jacpy_long_u64,
        jacpy_math_errno,
        jacpy_mul,
        jacpy_number_as_double,
        jacpy_release,
        jacpy_retain,
        jacpy_sequence_tuple,
        jacpy_special_noargs,
        jacpy_sub,
        jacpy_tuple_item,
        jacpy_tuple_size,
        jacpy_uint,
        object_error,
        repr_value,
        required,
        type_name
    }
    capi --> jaclang.runtime.python.modules.operator {
        boundary_failure,
        jacpy_abs,
        jacpy_add,
        jacpy_and_,
        jacpy_boolean,
        jacpy_call,
        jacpy_compare,
        jacpy_concat,
        jacpy_contains,
        jacpy_crypto_compare,
        jacpy_delitem,
        jacpy_dict_entry,
        jacpy_dict_size,
        jacpy_error_pending,
        jacpy_floordiv,
        jacpy_getattr,
        jacpy_getitem,
        jacpy_iadd,
        jacpy_iand,
        jacpy_iconcat,
        jacpy_ifloordiv,
        jacpy_ilshift,
        jacpy_imatmul,
        jacpy_imod,
        jacpy_import_attr,
        jacpy_imul,
        jacpy_index,
        jacpy_int,
        jacpy_integer_value,
        jacpy_invert,
        jacpy_ior,
        jacpy_irshift,
        jacpy_is_none,
        jacpy_is_unicode,
        jacpy_isub,
        jacpy_itruediv,
        jacpy_ixor,
        jacpy_length_hint,
        jacpy_list_item,
        jacpy_list_size,
        jacpy_lshift,
        jacpy_matmul,
        jacpy_mod,
        jacpy_mul,
        jacpy_neg,
        jacpy_none,
        jacpy_or_,
        jacpy_pos,
        jacpy_power,
        jacpy_release,
        jacpy_repr,
        jacpy_repr_enter,
        jacpy_repr_leave,
        jacpy_retain,
        jacpy_rshift,
        jacpy_sequence_count,
        jacpy_sequence_index,
        jacpy_setitem,
        jacpy_sub,
        jacpy_text,
        jacpy_truediv,
        jacpy_truth,
        jacpy_tuple_item,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_tuple_size,
        jacpy_tuple_slice,
        jacpy_unicode_join,
        jacpy_unicode_split,
        jacpy_utf8,
        jacpy_xor,
        object_error,
        pair,
        repr_value,
        required,
        text_object,
        text_value
    }
    capi --> jaclang.runtime.python.modules.pickle {
        boundary_failure,
        checked,
        jac_heap_size,
        jac_list_heap_size,
        jacpy_bytearray_memory,
        jacpy_dict_clear,
        jacpy_dict_copy,
        jacpy_dict_memory,
        jacpy_dict_new,
        jacpy_dict_set,
        jacpy_error_pending,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_dict,
        jacpy_is_tuple,
        jacpy_iter,
        jacpy_list_item,
        jacpy_list_size,
        jacpy_mapping_items,
        jacpy_release,
        jacpy_retain,
        jacpy_tuple_item,
        jacpy_tuple_size,
        jacpy_uint,
        required,
        text_value
    }
    capi --> jaclang.runtime.python.modules.pickle_decode {
        boundary_failure,
        checked,
        jacpy_boolean,
        jacpy_bytearray_new,
        jacpy_bytes_address,
        jacpy_bytes_decode,
        jacpy_bytes_from_memory,
        jacpy_bytes_length,
        jacpy_bytes_unescape,
        jacpy_call,
        jacpy_call_one,
        jacpy_dict_get,
        jacpy_dict_items,
        jacpy_dict_new,
        jacpy_dict_set,
        jacpy_dict_size,
        jacpy_error_is,
        jacpy_error_pending,
        jacpy_float,
        jacpy_float_from_text,
        jacpy_float_unpack,
        jacpy_getattr_string,
        jacpy_import_attr,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_dict,
        jacpy_is_exact_unicode,
        jacpy_is_list,
        jacpy_is_none,
        jacpy_is_tuple,
        jacpy_is_type,
        jacpy_is_unicode,
        jacpy_iter_next,
        jacpy_list_append,
        jacpy_list_item,
        jacpy_list_new,
        jacpy_list_size,
        jacpy_long_from_signed_bytes,
        jacpy_memory_byte,
        jacpy_memory_copy,
        jacpy_memoryview,
        jacpy_none,
        jacpy_number_long,
        jacpy_optional_attr,
        jacpy_release,
        jacpy_retain,
        jacpy_set_new,
        jacpy_setattr,
        jacpy_setitem,
        jacpy_truth,
        jacpy_tuple_item,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_tuple_size,
        jacpy_type_new,
        jacpy_unicode_intern,
        object_tuple,
        required,
        text_value
    }
    capi --> jaclang.runtime.python.modules.pickle_encode {
        boundary_failure,
        builtin_kind,
        checked,
        jacpy_add,
        jacpy_builtin_kind,
        jacpy_bytearray_resize,
        jacpy_bytes_address,
        jacpy_bytes_decode,
        jacpy_bytes_from_memory,
        jacpy_bytes_length,
        jacpy_call,
        jacpy_call_one,
        jacpy_callable,
        jacpy_dict_get,
        jacpy_dict_set,
        jacpy_dict_size,
        jacpy_ellipsis,
        jacpy_error_is,
        jacpy_error_pending,
        jacpy_float_bits,
        jacpy_float_repr,
        jacpy_float_value,
        jacpy_getattr_string,
        jacpy_import_attr,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_dict,
        jacpy_is_iterator,
        jacpy_is_none,
        jacpy_is_not_implemented,
        jacpy_is_tuple,
        jacpy_is_type,
        jacpy_is_unicode,
        jacpy_iter,
        jacpy_iter_next,
        jacpy_list_item,
        jacpy_list_size,
        jacpy_long_bits,
        jacpy_long_fits_i64,
        jacpy_long_repr,
        jacpy_long_sign,
        jacpy_long_signed_bytes,
        jacpy_mapping_items,
        jacpy_mapping_optional_item,
        jacpy_memory_byte,
        jacpy_none,
        jacpy_not_implemented,
        jacpy_object_str,
        jacpy_object_type,
        jacpy_optional_attr,
        jacpy_recursion_enter,
        jacpy_recursion_leave,
        jacpy_release,
        jacpy_retain,
        jacpy_sequence_list,
        jacpy_truth,
        jacpy_tuple_item,
        jacpy_tuple_size,
        jacpy_tuple_slice,
        jacpy_uint,
        jacpy_unicode_char,
        jacpy_unicode_encode,
        jacpy_unicode_size,
        object_tuple,
        repr_value,
        required,
        serialization_note,
        text_object,
        text_value,
        type_name
    }
    capi --> jaclang.runtime.python.modules.pickle_objects {
        boundary_failure,
        checked,
        jacpy_audit_pickle_find,
        jacpy_dict_copy,
        jacpy_dict_get,
        jacpy_dict_keys,
        jacpy_error_is,
        jacpy_error_pending,
        jacpy_error_restore,
        jacpy_error_take,
        jacpy_getattr,
        jacpy_import_attr,
        jacpy_import_object,
        jacpy_is_none,
        jacpy_is_tuple,
        jacpy_is_unicode,
        jacpy_list_item,
        jacpy_list_size,
        jacpy_object_str,
        jacpy_optional_attr,
        jacpy_release,
        jacpy_retain,
        jacpy_tuple_item,
        jacpy_tuple_size,
        object_tuple,
        repr_value,
        required,
        text_object,
        text_value
    }
    capi --> jaclang.runtime.python.modules.pickle_stream {
        boundary_failure,
        checked,
        jacpy_bytearray_new,
        jacpy_bytearray_resize,
        jacpy_bytes_address,
        jacpy_bytes_from_memory,
        jacpy_bytes_length,
        jacpy_call,
        jacpy_call_one,
        jacpy_error_restore,
        jacpy_error_take,
        jacpy_exception_context,
        jacpy_int,
        jacpy_is_bytes,
        jacpy_memory_byte,
        jacpy_memory_copy,
        jacpy_memory_set,
        jacpy_release,
        jacpy_retain,
        jacpy_set_exception,
        object_error,
        object_tuple,
        required
    }
    capi --> jaclang.runtime.python.modules.queue {
        jacpy_deadline,
        jacpy_deadline_remaining,
        jacpy_error_pending,
        jacpy_is_none,
        jacpy_lock_free,
        jacpy_lock_notify,
        jacpy_lock_wait,
        jacpy_pending_calls,
        jacpy_release,
        jacpy_retain,
        jacpy_set_none_exception,
        jacpy_timeout_ns,
        object_error
    }
    capi --> jaclang.runtime.python.modules.random {
        jacpy_buffer_byte,
        jacpy_buffer_new,
        jacpy_buffer_set,
        jacpy_buffer_size,
        jacpy_clear_error,
        jacpy_entropy,
        jacpy_error_pending,
        jacpy_hash_unsigned,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_long,
        jacpy_is_tuple,
        jacpy_long_absolute,
        jacpy_long_bits,
        jacpy_long_bytes,
        jacpy_long_from_bytes,
        jacpy_monotonic_time,
        jacpy_process_id,
        jacpy_release,
        jacpy_tuple_item,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_tuple_size,
        jacpy_unsigned_long,
        jacpy_wall_time,
        object_error
    }
    capi --> jaclang.runtime.python.modules.statistics {
        jacpy_error_pending,
        jacpy_float,
        jacpy_number_as_double,
        object_error
    }
    capi --> jaclang.runtime.python.modules.struct {
        boundary_failure,
        checked,
        jac_heap_size,
        jac_list_heap_size,
        jacpy_boolean,
        jacpy_bytes_address,
        jacpy_bytes_from_memory,
        jacpy_bytes_length,
        jacpy_call_one,
        jacpy_clear_error,
        jacpy_complex,
        jacpy_complex_imag,
        jacpy_complex_real,
        jacpy_complex_value,
        jacpy_dict_clear,
        jacpy_dict_get,
        jacpy_dict_set,
        jacpy_dict_size,
        jacpy_error_is,
        jacpy_error_pending,
        jacpy_float,
        jacpy_float_pack,
        jacpy_float_unpack,
        jacpy_index,
        jacpy_index_check,
        jacpy_int,
        jacpy_integer_value,
        jacpy_is_bytearray,
        jacpy_is_bytes,
        jacpy_is_long,
        jacpy_long_pointer,
        jacpy_long_u64,
        jacpy_memory_byte,
        jacpy_memory_copy,
        jacpy_memory_set,
        jacpy_memory_zero,
        jacpy_native_float_store,
        jacpy_native_little_endian,
        jacpy_native_size,
        jacpy_number_as_double,
        jacpy_release,
        jacpy_retain,
        jacpy_set_exception,
        jacpy_truth,
        jacpy_tuple_item,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_tuple_size,
        jacpy_uint,
        object_error,
        required
    }
    capi --> jaclang.runtime.python.modules.tee {
        boundary_failure,
        checked,
        jacpy_iter,
        jacpy_iter_next,
        jacpy_list_item,
        jacpy_list_size,
        jacpy_release,
        jacpy_retain,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        jacpy_type_check,
        object_error,
        required
    }
    capi --> jaclang.runtime.python.native_services {
        boundary_failure,
        read_buffer,
        required
    }
    capi --> jaclang.runtime.python.symtable { boundary_failure }
    capi --> jaclang.runtime.python.tokenize {
        boundary_failure,
        checked,
        jacpy_int,
        jacpy_release,
        jacpy_tuple_new,
        jacpy_tuple_set_owned,
        required,
        text_object
    }
    characters --> jaclang.compiler.frontend.python.parser_actions.pa_decode_escape_body {
        point_at,
        point_width
    }
    characters --> jaclang.compiler.frontend.python.tokenizer {
        point_at,
        point_width,
        unicode_continue,
        unicode_printable,
        unicode_start
    }
    compiler_integer --> jaclang.compiler.backends.py.jacpython.codegen_util {
        PyBigInt,
        integer_add
    }
    compiler_integer --> jaclang.compiler.backends.py.jacpython.compiler_emit {
        PyBigInt,
        integer_negate
    }
    compiler_integer --> jaclang.compiler.frontend.python.annotation_unparse {
        PyBigInt,
        integer_decimal
    }
    compiler_integer --> jaclang.compiler.frontend.python.ast_validation { PyBigInt }
    compiler_integer --> jaclang.compiler.frontend.python.compiler_preprocess {
        PyBigInt,
        integer_add,
        integer_negate,
        integer_to_float
    }
    compiler_integer --> jaclang.runtime.python.constant_input { integer_from_marshal }
    compiler_integer --> jaclang.runtime.python.constant_keys {
        PyBigInt,
        integer_decimal
    }
    compiler_integer --> jaclang.runtime.python.constant_output { PyBigInt }
    compiler_integer --> jaclang.runtime.python.native_services { integer_from_marshal }
    constant_input --> jaclang.compiler.frontend.python.ast_input { read_constant }
    constant_keys --> jaclang.compiler.backends.py.jacpython.compiler_ir {
        constant_key
    }
    constant_keys --> jaclang.runtime.python.constant_output { constant_key }
    constant_output --> jaclang.compiler.backends.py.jacpython.native_api {
        constant_object
    }
    constant_output --> jaclang.compiler.frontend.python.ast_output { constant_object }
    native_services --> jaclang.compiler.frontend.python.ast_input { take_buffer }
    native_services --> jaclang.compiler.frontend.python.compiler_diagnostics.syntax_warning {
        warn
    }
    native_services --> jaclang.compiler.frontend.python.parser_actions.pa_decode_bytes_escape_body {
        decode_bytes
    }
    native_services --> jaclang.compiler.frontend.python.parser_actions.pa_decode_escape_body {
        decode_unicode
    }
    native_services --> jaclang.compiler.frontend.python.parser_actions.pa_name_from_token {
        normalize_identifier
    }
    native_services --> jaclang.compiler.frontend.python.parser_actions.pa_py_number_from_spelling {
        parse_float,
        parse_integer
    }
    native_services --> jaclang.compiler.frontend.python.parser_actions.pa_warn_escape {
        warn
    }
    native_services --> jaclang.compiler.frontend.python.source_encoding {
        take_buffer,
        take_error_text
    }
    native_services --> jaclang.compiler.frontend.python.source_input {
        take_buffer,
        take_error_text
    }
    native_services --> jaclang.runtime.python.constant_input { take_buffer }
    native_services --> jaclang.runtime.python.tokenize {
        parse_float,
        parse_integer,
        take_buffer
    }
    objects --> jaclang.compiler.backends.py.jacpython.assembler { PyCode }
    objects --> jaclang.compiler.backends.py.jacpython.codegen_util {
        PyCode,
        PyInt,
        PyObj,
        PySlice,
        PyStr,
        PyTuple,
        py_none
    }
    objects --> jaclang.compiler.backends.py.jacpython.compiler_annotations {
        PyInt,
        PyStr,
        hashkey_equal,
        py_none
    }
    objects --> jaclang.compiler.backends.py.jacpython.compiler_codegen {
        PyCode,
        PyInt,
        PyNoneType,
        PyObj,
        PySlice,
        PyStr,
        PyTuple,
        py_none
    }
    objects --> jaclang.compiler.backends.py.jacpython.compiler_defs {
        PyCode,
        PyInt,
        PyObj,
        PyStr,
        PyTuple,
        py_none
    }
    objects --> jaclang.compiler.backends.py.jacpython.compiler_emit {
        PyBool,
        PyCode,
        PyComplex,
        PyFloat,
        PyInt,
        PyNoneType,
        PyObj,
        PySet,
        PySlice,
        PyStr,
        PyTuple,
        is_error,
        py_none
    }
    objects --> jaclang.compiler.backends.py.jacpython.compiler_exc { py_none }
    objects --> jaclang.compiler.backends.py.jacpython.compiler_ir {
        PyBool,
        PyBytes,
        PyCode,
        PyComplex,
        PyFloat,
        PyInt,
        PyObj,
        PySet,
        PySlice,
        PyStr,
        PyTuple,
        py_none
    }
    objects --> jaclang.compiler.backends.py.jacpython.compiler_loops { py_none }
    objects --> jaclang.compiler.backends.py.jacpython.compiler_match {
        PyInt,
        PyObj,
        PyStr,
        PyTuple,
        hashkey_equal
    }
    objects --> jaclang.compiler.backends.py.jacpython.flowgraph {
        PyInt,
        PyObj,
        PySet,
        PyTuple,
        is_error
    }
    objects --> jaclang.compiler.backends.py.jacpython.native_api {
        PyCode,
        PyError,
        PyInt,
        PyObj
    }
    objects --> jaclang.compiler.backends.py.jacpython.product_compile {
        PyObj,
        py_error
    }
    objects --> jaclang.compiler.frontend.python.annotation_unparse {
        PyBool,
        PyBytes,
        PyComplex,
        PyEllipsis,
        PyFloat,
        PyInt,
        PyNoneType,
        PyObj,
        PyStr,
        PyTuple
    }
    objects --> jaclang.compiler.frontend.python.ast_input { PyObj }
    objects --> jaclang.compiler.frontend.python.ast_nodes { PyObj }
    objects --> jaclang.compiler.frontend.python.ast_output { PyObj }
    objects --> jaclang.compiler.frontend.python.ast_validation {
        PyBool,
        PyBytes,
        PyComplex,
        PyEllipsis,
        PyFloat,
        PyInt,
        PyNoneType,
        PyObj,
        PySet,
        PyStr,
        PyTuple
    }
    objects --> jaclang.compiler.frontend.python.compiler_diagnostics {
        PyError,
        PyInt,
        PyObj,
        py_error
    }
    objects --> jaclang.compiler.frontend.python.compiler_preprocess {
        PyBool,
        PyComplex,
        PyFloat,
        PyInt,
        PyObj,
        PyStr
    }
    objects --> jaclang.compiler.frontend.python.parser_actions {
        PyBool,
        PyBytes,
        PyComplex,
        PyEllipsis,
        PyFloat,
        PyInt,
        PyNoneType,
        PyObj,
        PyStr,
        py_none
    }
    objects --> jaclang.runtime.python.compiler_integer { PyInt, PyObj, PyStr }
    objects --> jaclang.runtime.python.constant_input {
        PyBool,
        PyBytes,
        PyComplex,
        PyEllipsis,
        PyFloat,
        PyNoneType,
        PyObj,
        PySet,
        PyStr,
        PyTuple
    }
    objects --> jaclang.runtime.python.constant_keys {
        PyBool,
        PyBytes,
        PyCode,
        PyComplex,
        PyFloat,
        PyInt,
        PyObj,
        PySet,
        PySlice,
        PyStr,
        PyTuple
    }
    objects --> jaclang.runtime.python.constant_output {
        PyBool,
        PyBytes,
        PyCode,
        PyComplex,
        PyEllipsis,
        PyFloat,
        PyInt,
        PyNoneType,
        PyObj,
        PySet,
        PySlice,
        PyStr,
        PyTuple
    }
    objects --> jaclang.runtime.python.native_services { PyObj }
    objects --> jaclang.runtime.python.symtable { PyObj, py_error }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.assembler {
        OP_CACHE,
        OP_EXTENDED_ARG,
        opcode_cache_count
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.codegen_util {
        CMP_EQ,
        CMP_GE,
        CMP_GT,
        CMP_LE,
        CMP_LT,
        CMP_NE,
        CO_ASYNC_GENERATOR,
        CO_COROUTINE,
        CO_GENERATOR,
        CO_METHOD,
        CO_NESTED,
        CO_NEWLOCALS,
        CO_OPTIMIZED,
        CO_VARARGS,
        CO_VARKEYWORDS,
        NB_ADD,
        NB_AND,
        NB_FLOOR_DIVIDE,
        NB_INPLACE_ADD,
        NB_INPLACE_AND,
        NB_INPLACE_FLOOR_DIVIDE,
        NB_INPLACE_LSHIFT,
        NB_INPLACE_MATRIX_MULTIPLY,
        NB_INPLACE_MULTIPLY,
        NB_INPLACE_OR,
        NB_INPLACE_POWER,
        NB_INPLACE_REMAINDER,
        NB_INPLACE_RSHIFT,
        NB_INPLACE_SUBTRACT,
        NB_INPLACE_TRUE_DIVIDE,
        NB_INPLACE_XOR,
        NB_LSHIFT,
        NB_MATRIX_MULTIPLY,
        NB_MULTIPLY,
        NB_OR,
        NB_POWER,
        NB_REMAINDER,
        NB_RSHIFT,
        NB_SUBSCR,
        NB_SUBTRACT,
        NB_TRUE_DIVIDE,
        NB_XOR,
        OP_BUILD_LIST,
        OP_BUILD_MAP,
        OP_BUILD_SET,
        OP_BUILD_TUPLE,
        OP_CALL,
        OP_CALL_INTRINSIC_1,
        OP_CALL_KW,
        OP_CHECK_EXC_MATCH,
        OP_CLEANUP_THROW,
        OP_COMPARE_OP,
        OP_COPY,
        OP_COPY_FREE_VARS,
        OP_DELETE_ATTR,
        OP_DELETE_FAST,
        OP_DELETE_NAME,
        OP_DELETE_SUBSCR,
        OP_DICT_UPDATE,
        OP_END_ASYNC_FOR,
        OP_END_FOR,
        OP_END_SEND,
        OP_FOR_ITER,
        OP_GET_AITER,
        OP_GET_ANEXT,
        OP_GET_AWAITABLE,
        OP_GET_ITER,
        OP_GET_LEN,
        OP_GET_YIELD_FROM_ITER,
        OP_IMPORT_FROM,
        OP_IMPORT_NAME,
        OP_IS_OP,
        OP_JUMP_BACKWARD,
        OP_JUMP_BACKWARD_NO_INTERRUPT,
        OP_JUMP_FORWARD,
        OP_LIST_APPEND,
        OP_LIST_EXTEND,
        OP_LOAD_ATTR,
        OP_LOAD_BUILD_CLASS,
        OP_LOAD_COMMON_CONSTANT,
        OP_LOAD_CONST,
        OP_LOAD_DEREF,
        OP_LOAD_FAST,
        OP_LOAD_FAST_AND_CLEAR,
        OP_LOAD_FAST_BORROW,
        OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
        OP_LOAD_FAST_CHECK,
        OP_LOAD_GLOBAL,
        OP_LOAD_LOCALS,
        OP_LOAD_NAME,
        OP_LOAD_SMALL_INT,
        OP_LOAD_SPECIAL,
        OP_MAKE_CELL,
        OP_MAKE_FUNCTION,
        OP_MAP_ADD,
        OP_MATCH_CLASS,
        OP_MATCH_KEYS,
        OP_MATCH_MAPPING,
        OP_MATCH_SEQUENCE,
        OP_NOP,
        OP_NOT_TAKEN,
        OP_POP_EXCEPT,
        OP_POP_ITER,
        OP_POP_JUMP_IF_FALSE,
        OP_POP_JUMP_IF_NONE,
        OP_POP_JUMP_IF_NOT_NONE,
        OP_POP_JUMP_IF_TRUE,
        OP_POP_TOP,
        OP_PUSH_EXC_INFO,
        OP_PUSH_NULL,
        OP_RAISE_VARARGS,
        OP_RERAISE,
        OP_RESUME,
        OP_RETURN_GENERATOR,
        OP_RETURN_VALUE,
        OP_SEND,
        OP_SET_ADD,
        OP_SET_FUNCTION_ATTRIBUTE,
        OP_SET_UPDATE,
        OP_STORE_ATTR,
        OP_STORE_DEREF,
        OP_STORE_FAST,
        OP_STORE_FAST_LOAD_FAST,
        OP_STORE_FAST_STORE_FAST,
        OP_STORE_NAME,
        OP_STORE_SUBSCR,
        OP_SWAP,
        OP_TO_BOOL,
        OP_UNARY_INVERT,
        OP_UNARY_NEGATIVE,
        OP_UNARY_NOT,
        OP_UNPACK_EX,
        OP_UNPACK_SEQUENCE,
        OP_WITH_EXCEPT_START,
        OP_YIELD_VALUE,
        compare_filter_oparg,
        compare_oparg
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.compiler_annotations {
        CMP_GT,
        CO_NESTED,
        CO_NEWLOCALS,
        CO_OPTIMIZED,
        OP_BUILD_MAP,
        OP_BUILD_SET,
        OP_BUILD_TUPLE,
        OP_COMPARE_OP,
        OP_CONTAINS_OP,
        OP_COPY,
        OP_COPY_FREE_VARS,
        OP_LOAD_COMMON_CONSTANT,
        OP_LOAD_CONST,
        OP_LOAD_DEREF,
        OP_LOAD_FAST,
        OP_LOAD_FAST_BORROW,
        OP_LOAD_FROM_DICT_OR_GLOBALS,
        OP_LOAD_GLOBAL,
        OP_LOAD_NAME,
        OP_LOAD_SMALL_INT,
        OP_MAKE_CELL,
        OP_MAKE_FUNCTION,
        OP_POP_JUMP_IF_FALSE,
        OP_POP_TOP,
        OP_RAISE_VARARGS,
        OP_RESUME,
        OP_RETURN_VALUE,
        OP_SETUP_ANNOTATIONS,
        OP_SET_ADD,
        OP_SET_FUNCTION_ATTRIBUTE,
        OP_STORE_ATTR,
        OP_STORE_DEREF,
        OP_STORE_FAST,
        OP_STORE_NAME,
        OP_STORE_SUBSCR,
        OP_SWAP,
        compare_oparg
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.compiler_codegen {
        CMP_EQ,
        CMP_GE,
        CMP_GT,
        CMP_LE,
        CMP_LT,
        CMP_NE,
        CO_ASYNC_GENERATOR,
        CO_COROUTINE,
        CO_GENERATOR,
        CO_NESTED,
        CO_NEWLOCALS,
        CO_OPTIMIZED,
        CO_VARARGS,
        CO_VARKEYWORDS,
        NB_ADD,
        NB_AND,
        NB_FLOOR_DIVIDE,
        NB_INPLACE_ADD,
        NB_INPLACE_AND,
        NB_INPLACE_FLOOR_DIVIDE,
        NB_INPLACE_LSHIFT,
        NB_INPLACE_MATRIX_MULTIPLY,
        NB_INPLACE_MULTIPLY,
        NB_INPLACE_OR,
        NB_INPLACE_POWER,
        NB_INPLACE_REMAINDER,
        NB_INPLACE_RSHIFT,
        NB_INPLACE_SUBTRACT,
        NB_INPLACE_TRUE_DIVIDE,
        NB_INPLACE_XOR,
        NB_LSHIFT,
        NB_MATRIX_MULTIPLY,
        NB_MULTIPLY,
        NB_OR,
        NB_POWER,
        NB_REMAINDER,
        NB_RSHIFT,
        NB_SUBSCR,
        NB_SUBTRACT,
        NB_TRUE_DIVIDE,
        NB_XOR,
        OP_BINARY_OP,
        OP_BINARY_SLICE,
        OP_BUILD_LIST,
        OP_BUILD_MAP,
        OP_BUILD_SET,
        OP_BUILD_SLICE,
        OP_BUILD_TUPLE,
        OP_CALL,
        OP_CALL_INTRINSIC_1,
        OP_CALL_KW,
        OP_CHECK_EXC_MATCH,
        OP_CLEANUP_THROW,
        OP_COMPARE_OP,
        OP_CONTAINS_OP,
        OP_COPY,
        OP_COPY_FREE_VARS,
        OP_DELETE_ATTR,
        OP_DELETE_DEREF,
        OP_DELETE_FAST,
        OP_DELETE_GLOBAL,
        OP_DELETE_NAME,
        OP_DELETE_SUBSCR,
        OP_DICT_UPDATE,
        OP_END_ASYNC_FOR,
        OP_END_FOR,
        OP_END_SEND,
        OP_FOR_ITER,
        OP_GET_AITER,
        OP_GET_ANEXT,
        OP_GET_AWAITABLE,
        OP_GET_ITER,
        OP_GET_LEN,
        OP_GET_YIELD_FROM_ITER,
        OP_IMPORT_FROM,
        OP_IMPORT_NAME,
        OP_IS_OP,
        OP_JUMP_BACKWARD,
        OP_JUMP_BACKWARD_NO_INTERRUPT,
        OP_JUMP_FORWARD,
        OP_LIST_APPEND,
        OP_LIST_EXTEND,
        OP_LOAD_ATTR,
        OP_LOAD_BUILD_CLASS,
        OP_LOAD_COMMON_CONSTANT,
        OP_LOAD_CONST,
        OP_LOAD_DEREF,
        OP_LOAD_FAST,
        OP_LOAD_FAST_AND_CLEAR,
        OP_LOAD_FAST_BORROW,
        OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
        OP_LOAD_FAST_CHECK,
        OP_LOAD_GLOBAL,
        OP_LOAD_LOCALS,
        OP_LOAD_NAME,
        OP_LOAD_SMALL_INT,
        OP_LOAD_SPECIAL,
        OP_MAKE_CELL,
        OP_MAKE_FUNCTION,
        OP_MAP_ADD,
        OP_MATCH_CLASS,
        OP_MATCH_KEYS,
        OP_MATCH_MAPPING,
        OP_MATCH_SEQUENCE,
        OP_NOP,
        OP_NOT_TAKEN,
        OP_POP_EXCEPT,
        OP_POP_ITER,
        OP_POP_JUMP_IF_FALSE,
        OP_POP_JUMP_IF_NONE,
        OP_POP_JUMP_IF_NOT_NONE,
        OP_POP_JUMP_IF_TRUE,
        OP_POP_TOP,
        OP_PUSH_EXC_INFO,
        OP_PUSH_NULL,
        OP_RAISE_VARARGS,
        OP_RERAISE,
        OP_RESUME,
        OP_RETURN_GENERATOR,
        OP_RETURN_VALUE,
        OP_SEND,
        OP_SET_ADD,
        OP_SET_FUNCTION_ATTRIBUTE,
        OP_SET_UPDATE,
        OP_STORE_ATTR,
        OP_STORE_DEREF,
        OP_STORE_FAST,
        OP_STORE_FAST_LOAD_FAST,
        OP_STORE_FAST_STORE_FAST,
        OP_STORE_GLOBAL,
        OP_STORE_NAME,
        OP_STORE_SLICE,
        OP_STORE_SUBSCR,
        OP_SWAP,
        OP_TO_BOOL,
        OP_UNARY_INVERT,
        OP_UNARY_NEGATIVE,
        OP_UNARY_NOT,
        OP_UNPACK_EX,
        OP_UNPACK_SEQUENCE,
        OP_WITH_EXCEPT_START,
        OP_YIELD_VALUE,
        compare_filter_oparg,
        compare_oparg,
        is_scope_exit_opcode,
        is_unconditional_jump_opcode
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.compiler_defs {
        CMP_GT,
        CO_ASYNC_GENERATOR,
        CO_COROUTINE,
        CO_GENERATOR,
        CO_HAS_DOCSTRING,
        CO_NESTED,
        CO_NEWLOCALS,
        CO_OPTIMIZED,
        OP_BUILD_TUPLE,
        OP_CALL,
        OP_CALL_INTRINSIC_1,
        OP_CALL_INTRINSIC_2,
        OP_CALL_KW,
        OP_COMPARE_OP,
        OP_COPY,
        OP_COPY_FREE_VARS,
        OP_IMPORT_FROM,
        OP_IMPORT_NAME,
        OP_LOAD_BUILD_CLASS,
        OP_LOAD_COMMON_CONSTANT,
        OP_LOAD_CONST,
        OP_LOAD_FAST_BORROW,
        OP_LOAD_LOCALS,
        OP_LOAD_NAME,
        OP_LOAD_SMALL_INT,
        OP_MAKE_CELL,
        OP_MAKE_FUNCTION,
        OP_POP_JUMP_IF_FALSE,
        OP_POP_TOP,
        OP_PUSH_NULL,
        OP_RAISE_VARARGS,
        OP_RESUME,
        OP_RETURN_VALUE,
        OP_SET_FUNCTION_ATTRIBUTE,
        OP_STORE_DEREF,
        OP_STORE_FAST,
        OP_STORE_NAME,
        OP_SWAP,
        OP_UNPACK_SEQUENCE,
        compare_oparg
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.compiler_emit {
        CMP_EQ,
        CMP_GE,
        CMP_GT,
        CMP_LE,
        CMP_LT,
        CMP_NE,
        CO_ASYNC_GENERATOR,
        CO_COROUTINE,
        CO_GENERATOR,
        CO_NESTED,
        CO_NEWLOCALS,
        CO_OPTIMIZED,
        CO_VARARGS,
        CO_VARKEYWORDS,
        NB_ADD,
        NB_AND,
        NB_FLOOR_DIVIDE,
        NB_INPLACE_ADD,
        NB_INPLACE_AND,
        NB_INPLACE_FLOOR_DIVIDE,
        NB_INPLACE_LSHIFT,
        NB_INPLACE_MATRIX_MULTIPLY,
        NB_INPLACE_MULTIPLY,
        NB_INPLACE_OR,
        NB_INPLACE_POWER,
        NB_INPLACE_REMAINDER,
        NB_INPLACE_RSHIFT,
        NB_INPLACE_SUBTRACT,
        NB_INPLACE_TRUE_DIVIDE,
        NB_INPLACE_XOR,
        NB_LSHIFT,
        NB_MATRIX_MULTIPLY,
        NB_MULTIPLY,
        NB_OR,
        NB_POWER,
        NB_REMAINDER,
        NB_RSHIFT,
        NB_SUBSCR,
        NB_SUBTRACT,
        NB_TRUE_DIVIDE,
        NB_XOR,
        OP_BINARY_OP,
        OP_BINARY_SLICE,
        OP_BUILD_INTERPOLATION,
        OP_BUILD_LIST,
        OP_BUILD_MAP,
        OP_BUILD_SET,
        OP_BUILD_SLICE,
        OP_BUILD_STRING,
        OP_BUILD_TEMPLATE,
        OP_BUILD_TUPLE,
        OP_CALL,
        OP_CALL_FUNCTION_EX,
        OP_CALL_INTRINSIC_1,
        OP_CALL_KW,
        OP_CHECK_EXC_MATCH,
        OP_CLEANUP_THROW,
        OP_COMPARE_OP,
        OP_CONTAINS_OP,
        OP_CONVERT_VALUE,
        OP_COPY,
        OP_COPY_FREE_VARS,
        OP_DELETE_ATTR,
        OP_DELETE_FAST,
        OP_DELETE_GLOBAL,
        OP_DELETE_NAME,
        OP_DELETE_SUBSCR,
        OP_DICT_MERGE,
        OP_DICT_UPDATE,
        OP_END_ASYNC_FOR,
        OP_END_FOR,
        OP_END_SEND,
        OP_FORMAT_SIMPLE,
        OP_FORMAT_WITH_SPEC,
        OP_FOR_ITER,
        OP_GET_AITER,
        OP_GET_ANEXT,
        OP_GET_AWAITABLE,
        OP_GET_ITER,
        OP_GET_LEN,
        OP_GET_YIELD_FROM_ITER,
        OP_IMPORT_FROM,
        OP_IMPORT_NAME,
        OP_IS_OP,
        OP_JUMP_BACKWARD,
        OP_JUMP_BACKWARD_NO_INTERRUPT,
        OP_JUMP_FORWARD,
        OP_LIST_APPEND,
        OP_LIST_EXTEND,
        OP_LOAD_ATTR,
        OP_LOAD_BUILD_CLASS,
        OP_LOAD_COMMON_CONSTANT,
        OP_LOAD_CONST,
        OP_LOAD_DEREF,
        OP_LOAD_FAST,
        OP_LOAD_FAST_AND_CLEAR,
        OP_LOAD_FAST_BORROW,
        OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
        OP_LOAD_FAST_CHECK,
        OP_LOAD_FROM_DICT_OR_DEREF,
        OP_LOAD_FROM_DICT_OR_GLOBALS,
        OP_LOAD_GLOBAL,
        OP_LOAD_LOCALS,
        OP_LOAD_NAME,
        OP_LOAD_SMALL_INT,
        OP_LOAD_SPECIAL,
        OP_LOAD_SUPER_ATTR,
        OP_MAKE_CELL,
        OP_MAKE_FUNCTION,
        OP_MAP_ADD,
        OP_MATCH_CLASS,
        OP_MATCH_KEYS,
        OP_MATCH_MAPPING,
        OP_MATCH_SEQUENCE,
        OP_NOP,
        OP_NOT_TAKEN,
        OP_POP_EXCEPT,
        OP_POP_ITER,
        OP_POP_JUMP_IF_FALSE,
        OP_POP_JUMP_IF_NONE,
        OP_POP_JUMP_IF_NOT_NONE,
        OP_POP_JUMP_IF_TRUE,
        OP_POP_TOP,
        OP_PUSH_EXC_INFO,
        OP_PUSH_NULL,
        OP_RAISE_VARARGS,
        OP_RERAISE,
        OP_RESUME,
        OP_RETURN_GENERATOR,
        OP_RETURN_VALUE,
        OP_SEND,
        OP_SET_ADD,
        OP_SET_FUNCTION_ATTRIBUTE,
        OP_SET_UPDATE,
        OP_STORE_ATTR,
        OP_STORE_DEREF,
        OP_STORE_FAST,
        OP_STORE_FAST_LOAD_FAST,
        OP_STORE_FAST_MAYBE_NULL,
        OP_STORE_FAST_STORE_FAST,
        OP_STORE_GLOBAL,
        OP_STORE_NAME,
        OP_STORE_SLICE,
        OP_STORE_SUBSCR,
        OP_SWAP,
        OP_TO_BOOL,
        OP_UNARY_INVERT,
        OP_UNARY_NEGATIVE,
        OP_UNARY_NOT,
        OP_UNPACK_EX,
        OP_UNPACK_SEQUENCE,
        OP_WITH_EXCEPT_START,
        OP_YIELD_VALUE,
        compare_filter_oparg,
        compare_oparg
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.compiler_exc {
        OP_BUILD_LIST,
        OP_CALL,
        OP_CALL_INTRINSIC_1,
        OP_CALL_INTRINSIC_2,
        OP_CHECK_EG_MATCH,
        OP_CHECK_EXC_MATCH,
        OP_CLEANUP_THROW,
        OP_COPY,
        OP_END_FOR,
        OP_END_SEND,
        OP_GET_AWAITABLE,
        OP_JUMP_BACKWARD,
        OP_JUMP_BACKWARD_NO_INTERRUPT,
        OP_JUMP_FORWARD,
        OP_LIST_APPEND,
        OP_LOAD_CONST,
        OP_LOAD_SPECIAL,
        OP_NOP,
        OP_NOT_TAKEN,
        OP_POP_EXCEPT,
        OP_POP_ITER,
        OP_POP_JUMP_IF_FALSE,
        OP_POP_JUMP_IF_NONE,
        OP_POP_JUMP_IF_NOT_NONE,
        OP_POP_JUMP_IF_TRUE,
        OP_POP_TOP,
        OP_PUSH_EXC_INFO,
        OP_RAISE_VARARGS,
        OP_RERAISE,
        OP_RESUME,
        OP_RETURN_VALUE,
        OP_SEND,
        OP_STORE_FAST,
        OP_SWAP,
        OP_TO_BOOL,
        OP_WITH_EXCEPT_START,
        OP_YIELD_VALUE
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.compiler_ir {
        OP_LOAD_CONST,
        opcode_cache_count,
        opcode_has_const
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.compiler_loops {
        OP_END_ASYNC_FOR,
        OP_END_FOR,
        OP_FOR_ITER,
        OP_GET_AITER,
        OP_GET_ANEXT,
        OP_GET_ITER,
        OP_GET_YIELD_FROM_ITER,
        OP_JUMP_BACKWARD,
        OP_JUMP_FORWARD,
        OP_LOAD_CONST,
        OP_NOP,
        OP_NOT_TAKEN,
        OP_POP_ITER,
        OP_POP_JUMP_IF_FALSE,
        OP_POP_JUMP_IF_TRUE,
        OP_POP_TOP,
        OP_RETURN_VALUE,
        has_target,
        is_scope_exit_opcode,
        is_unconditional_jump_opcode
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.compiler_match {
        CMP_EQ,
        CMP_GE,
        NB_SUBSCR,
        NB_SUBTRACT,
        OP_BINARY_OP,
        OP_BUILD_MAP,
        OP_BUILD_TUPLE,
        OP_COMPARE_OP,
        OP_COPY,
        OP_DELETE_SUBSCR,
        OP_DICT_UPDATE,
        OP_GET_LEN,
        OP_IS_OP,
        OP_JUMP_FORWARD,
        OP_LOAD_CONST,
        OP_LOAD_FAST,
        OP_LOAD_FAST_BORROW,
        OP_MATCH_CLASS,
        OP_MATCH_KEYS,
        OP_MATCH_MAPPING,
        OP_MATCH_SEQUENCE,
        OP_NOP,
        OP_POP_JUMP_IF_FALSE,
        OP_POP_JUMP_IF_NONE,
        OP_POP_JUMP_IF_NOT_NONE,
        OP_POP_TOP,
        OP_STORE_FAST_STORE_FAST,
        OP_SWAP,
        OP_UNPACK_EX,
        OP_UNPACK_SEQUENCE,
        compare_filter_oparg,
        compare_oparg
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.flowgraph {
        OP_BUILD_LIST,
        OP_BUILD_SET,
        OP_CHECK_EXC_MATCH,
        OP_CONTAINS_OP,
        OP_COPY,
        OP_DELETE_FAST,
        OP_DICT_MERGE,
        OP_DICT_UPDATE,
        OP_END_ASYNC_FOR,
        OP_END_SEND,
        OP_FORMAT_SIMPLE,
        OP_FOR_ITER,
        OP_GET_ANEXT,
        OP_GET_ITER,
        OP_GET_LEN,
        OP_GET_YIELD_FROM_ITER,
        OP_IMPORT_FROM,
        OP_JUMP_BACKWARD,
        OP_JUMP_BACKWARD_NO_INTERRUPT,
        OP_JUMP_FORWARD,
        OP_LIST_APPEND,
        OP_LIST_EXTEND,
        OP_LOAD_ATTR,
        OP_LOAD_CONST,
        OP_LOAD_FAST,
        OP_LOAD_FAST_AND_CLEAR,
        OP_LOAD_FAST_BORROW,
        OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
        OP_LOAD_FAST_CHECK,
        OP_LOAD_FAST_LOAD_FAST,
        OP_LOAD_SMALL_INT,
        OP_LOAD_SPECIAL,
        OP_LOAD_SUPER_ATTR,
        OP_MAP_ADD,
        OP_MATCH_KEYS,
        OP_MATCH_MAPPING,
        OP_MATCH_SEQUENCE,
        OP_NOP,
        OP_NOT_TAKEN,
        OP_POP_JUMP_IF_FALSE,
        OP_POP_JUMP_IF_NONE,
        OP_POP_JUMP_IF_NOT_NONE,
        OP_POP_JUMP_IF_TRUE,
        OP_POP_TOP,
        OP_PUSH_EXC_INFO,
        OP_RERAISE,
        OP_RETURN_VALUE,
        OP_SEND,
        OP_SET_ADD,
        OP_SET_FUNCTION_ATTRIBUTE,
        OP_SET_UPDATE,
        OP_STORE_FAST,
        OP_STORE_FAST_LOAD_FAST,
        OP_STORE_FAST_MAYBE_NULL,
        OP_STORE_FAST_STORE_FAST,
        OP_SWAP,
        OP_WITH_EXCEPT_START,
        _opcode_num_popped,
        _opcode_num_pushed,
        has_target,
        is_scope_exit_opcode,
        is_unconditional_jump_opcode,
        opcode_has_const,
        stack_effect
    }
    opcode_meta --> jaclang.compiler.backends.py.jacpython.native_api { stack_effect }
    opcode_meta --> jaclang.runtime.python.constant_output {
        CO_FAST_CELL,
        CO_FAST_FREE,
        CO_FAST_HIDDEN,
        CO_FAST_LOCAL,
        CO_OPTIMIZED
    }
    opcode_meta --> jaclang.runtime.python.objects {
        NB_ADD,
        NB_AND,
        NB_FLOOR_DIVIDE,
        NB_LSHIFT,
        NB_MULTIPLY,
        NB_OR,
        NB_POWER,
        NB_REMAINDER,
        NB_RSHIFT,
        NB_SUBTRACT,
        NB_TRUE_DIVIDE,
        NB_XOR
    }
    symtable --> jaclang.compiler.backends.py.jacpython.native_api {
        SymtableEntry,
        source_symtable,
        symtable_to_object
    }
    tokenize --> jaclang.compiler.backends.py.jacpython.native_api {
        jacpy_token_close,
        token_iterator,
        token_iterator_state,
        token_object
    }
}

impl import jaclang.runtime.python.bindings {
    arguments --> jaclang.runtime.python.bindings.array {
        BoundArguments,
        CallSignature,
        character_value,
        index_value,
        invoke,
        jacpy_ssize
    }
    arguments --> jaclang.runtime.python.bindings.binascii {
        BoundArguments,
        CallSignature,
        invoke
    }
    arguments --> jaclang.runtime.python.bindings.bisect {
        BoundArguments,
        CallSignature,
        index_value,
        invoke
    }
    arguments --> jaclang.runtime.python.bindings.cmath {
        BoundArguments,
        CallSignature,
        invoke
    }
    arguments --> jaclang.runtime.python.bindings.collections {
        BoundArguments,
        CallSignature,
        index_value,
        invoke,
        jacpy_ssize
    }
    arguments --> jaclang.runtime.python.bindings.csv {
        BoundArguments,
        CallSignature,
        invoke,
        jacpy_ssize
    }
    arguments --> jaclang.runtime.python.bindings.functools {
        BoundArguments,
        CallSignature,
        index_value,
        invoke
    }
    arguments --> jaclang.runtime.python.bindings.heapq {
        BoundArguments,
        CallSignature,
        invalid,
        invoke,
        invoke_one
    }
    arguments --> jaclang.runtime.python.bindings.itertools {
        BoundArguments,
        CallSignature,
        index_value,
        invoke,
        jacpy_ssize
    }
    arguments --> jaclang.runtime.python.bindings.json {
        BoundArguments,
        CallSignature,
        index_value,
        invoke,
        invoke_one
    }
    arguments --> jaclang.runtime.python.bindings.math {
        BoundArguments,
        CallSignature,
        invoke
    }
    arguments --> jaclang.runtime.python.bindings.operator {
        BoundArguments,
        CallSignature,
        index_value,
        invoke,
        invoke_one
    }
    arguments --> jaclang.runtime.python.bindings.pickle {
        BoundArguments,
        CallSignature,
        invoke
    }
    arguments --> jaclang.runtime.python.bindings.queue {
        BoundArguments,
        CallSignature,
        invoke
    }
    arguments --> jaclang.runtime.python.bindings.random {
        BoundArguments,
        CallSignature,
        invoke
    }
    arguments --> jaclang.runtime.python.bindings.statistics {
        BoundArguments,
        CallSignature,
        invoke
    }
    arguments --> jaclang.runtime.python.bindings.struct {
        BoundArguments,
        CallSignature,
        invoke
    }
    array --> jaclang.compiler.backends.py.jacpython.native_api { PyInit_array }
    binascii --> jaclang.compiler.backends.py.jacpython.native_api { PyInit_binascii }
    bisect --> jaclang.compiler.backends.py.jacpython.native_api { PyInit__bisect }
    buffer --> jaclang.runtime.python.bindings.array {
        BufferArgument,
        BufferLayout,
        jacpy_binding_buffer_dispose,
        jacpy_binding_buffer_fill
    }
    buffer --> jaclang.runtime.python.bindings.binascii { BufferArgument }
    buffer --> jaclang.runtime.python.bindings.operator { BufferArgument }
    buffer --> jaclang.runtime.python.bindings.struct { BufferArgument }
    cmath --> jaclang.compiler.backends.py.jacpython.native_api { PyInit_cmath }
    collections --> jaclang.compiler.backends.py.jacpython.native_api {
        PyInit__collections
    }
    csv --> jaclang.compiler.backends.py.jacpython.native_api { PyInit__csv }
    functools --> jaclang.compiler.backends.py.jacpython.native_api {
        PyInit__functools
    }
    heapq --> jaclang.compiler.backends.py.jacpython.native_api { PyInit__heapq }
    itertools --> jaclang.compiler.backends.py.jacpython.native_api { PyInit_itertools }
    json --> jaclang.compiler.backends.py.jacpython.native_api { PyInit__json }
    math --> jaclang.compiler.backends.py.jacpython.native_api { PyInit_math }
    module --> jaclang.runtime.python.bindings.array {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_owned,
        add_state_owned,
        jacpy_binding_state_get,
        jacpy_binding_state_set,
        jacpy_binding_visit
    }
    module --> jaclang.runtime.python.bindings.binascii {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_state_owned,
        jacpy_binding_exception,
        jacpy_binding_state_get
    }
    module --> jaclang.runtime.python.bindings.bisect {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition
    }
    module --> jaclang.runtime.python.bindings.cmath {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_owned
    }
    module --> jaclang.runtime.python.bindings.collections {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_owned,
        add_state_owned,
        jacpy_binding_state_get,
        jacpy_binding_state_set,
        jacpy_binding_visit
    }
    module --> jaclang.runtime.python.bindings.csv {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_owned,
        add_state_owned,
        jacpy_binding_exception,
        jacpy_binding_module_native_get,
        jacpy_binding_module_native_present,
        jacpy_binding_module_native_set,
        jacpy_binding_state_get,
        jacpy_binding_visit
    }
    module --> jaclang.runtime.python.bindings.functools {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_owned,
        add_state_owned,
        jacpy_binding_state_get,
        jacpy_binding_state_set,
        jacpy_binding_visit
    }
    module --> jaclang.runtime.python.bindings.heapq {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition
    }
    module --> jaclang.runtime.python.bindings.itertools {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_state_owned,
        jacpy_binding_state_get,
        jacpy_binding_visit
    }
    module --> jaclang.runtime.python.bindings.json {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_owned
    }
    module --> jaclang.runtime.python.bindings.math {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_owned
    }
    module --> jaclang.runtime.python.bindings.operator {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_owned
    }
    module --> jaclang.runtime.python.bindings.payload { jacpy_binding_visit }
    module --> jaclang.runtime.python.bindings.pickle {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_owned,
        add_state_owned,
        jacpy_binding_exception,
        jacpy_binding_exception_with_base,
        jacpy_binding_state_get,
        jacpy_binding_state_set,
        jacpy_binding_visit
    }
    module --> jaclang.runtime.python.bindings.queue {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_state_owned,
        jacpy_binding_exception,
        jacpy_binding_state_get
    }
    module --> jaclang.runtime.python.bindings.random {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_state_owned
    }
    module --> jaclang.runtime.python.bindings.references { jacpy_binding_visit }
    module --> jaclang.runtime.python.bindings.statistics {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition
    }
    module --> jaclang.runtime.python.bindings.struct {
        MethodCallbacks,
        MethodDefinition,
        ModuleDefinition,
        ModuleHooks,
        add_state_owned,
        jacpy_binding_exception,
        jacpy_binding_state_get,
        jacpy_binding_state_set,
        jacpy_binding_visit
    }
    module --> jaclang.runtime.python.bindings.type {
        MethodDefinition,
        install_methods
    }
    module --> jaclang.runtime.python.modules.queue { jacpy_binding_visit }
    operator --> jaclang.compiler.backends.py.jacpython.native_api { PyInit__operator }
    payload --> jaclang.runtime.python.bindings.array {
        clear_payload,
        dispose_payload,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set,
        traverse_payload
    }
    payload --> jaclang.runtime.python.bindings.collections {
        clear_payload,
        dispose_payload,
        jacpy_binding_native_clear,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set,
        jacpy_binding_untrack,
        traverse_payload
    }
    payload --> jaclang.runtime.python.bindings.csv {
        clear_payload,
        dispose_payload,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set,
        traverse_payload
    }
    payload --> jaclang.runtime.python.bindings.functools {
        clear_payload,
        dispose_payload,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set,
        traverse_payload
    }
    payload --> jaclang.runtime.python.bindings.itertools {
        clear_payload,
        dispose_payload,
        jacpy_binding_dealloc_guard,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set,
        traverse_payload
    }
    payload --> jaclang.runtime.python.bindings.json {
        clear_payload,
        dispose_payload,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set,
        traverse_payload
    }
    payload --> jaclang.runtime.python.bindings.operator {
        clear_payload,
        dispose_payload,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set,
        traverse_payload
    }
    payload --> jaclang.runtime.python.bindings.pickle {
        clear_payload,
        dispose_payload,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set,
        traverse_payload
    }
    payload --> jaclang.runtime.python.bindings.queue {
        clear_payload,
        dispose_payload,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set,
        traverse_payload
    }
    payload --> jaclang.runtime.python.bindings.random {
        jacpy_binding_native_clear,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set
    }
    payload --> jaclang.runtime.python.bindings.struct {
        NativeState,
        clear_payload,
        dispose_payload,
        jacpy_binding_native_get,
        jacpy_binding_native_present,
        jacpy_binding_native_set,
        traverse_payload
    }
    pickle --> jaclang.compiler.backends.py.jacpython.native_api { PyInit__pickle }
    queue --> jaclang.compiler.backends.py.jacpython.native_api { PyInit__queue }
    random --> jaclang.compiler.backends.py.jacpython.native_api { PyInit__random }
    references --> jaclang.runtime.python.bindings.array { ReferenceState, owned_tuple }
    references --> jaclang.runtime.python.bindings.collections {
        ReferenceState,
        owned_tuple
    }
    references --> jaclang.runtime.python.bindings.csv { ReferenceState }
    references --> jaclang.runtime.python.bindings.functools { ReferenceState }
    references --> jaclang.runtime.python.bindings.itertools { ReferenceState }
    references --> jaclang.runtime.python.bindings.json { ReferenceState }
    references --> jaclang.runtime.python.bindings.operator { ReferenceState }
    references --> jaclang.runtime.python.bindings.pickle {
        ReferenceState,
        owned_tuple
    }
    references --> jaclang.runtime.python.bindings.struct { ReferenceState }
    state --> jaclang.runtime.python.bindings.array { NativeState }
    state --> jaclang.runtime.python.bindings.collections { NativeState }
    state --> jaclang.runtime.python.bindings.functools { NativeState }
    state --> jaclang.runtime.python.bindings.itertools { NativeState }
    state --> jaclang.runtime.python.bindings.module { NativeState }
    state --> jaclang.runtime.python.bindings.payload { NativeState }
    state --> jaclang.runtime.python.bindings.pickle { NativeState }
    state --> jaclang.runtime.python.bindings.references { NativeState }
    state --> jaclang.runtime.python.modules.csv { NativeState }
    state --> jaclang.runtime.python.modules.queue { NativeState }
    state --> jaclang.runtime.python.modules.random { NativeState }
    statistics --> jaclang.compiler.backends.py.jacpython.native_api {
        PyInit__statistics
    }
    struct --> jaclang.compiler.backends.py.jacpython.native_api { PyInit__struct }
    type --> jaclang.runtime.python.bindings.array {
        PropertyCallbacks,
        PropertyDefinition,
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        TypeSlot,
        jacpy_binding_allocate,
        jacpy_binding_basicsize,
        jacpy_binding_generic_alias,
        jacpy_binding_matches,
        jacpy_binding_owner,
        jacpy_binding_slot,
        jacpy_binding_typeof
    }
    type --> jaclang.runtime.python.bindings.collections {
        PropertyCallbacks,
        PropertyDefinition,
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        jacpy_binding_allocate,
        jacpy_binding_base_clear,
        jacpy_binding_base_dealloc,
        jacpy_binding_base_init,
        jacpy_binding_base_new,
        jacpy_binding_base_traverse,
        jacpy_binding_basicsize,
        jacpy_binding_generic_alias,
        jacpy_binding_matches,
        jacpy_binding_object_state,
        jacpy_binding_owner,
        jacpy_binding_parent,
        jacpy_binding_typeof
    }
    type --> jaclang.runtime.python.bindings.csv {
        PropertyCallbacks,
        PropertyDefinition,
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        jacpy_binding_allocate,
        jacpy_binding_owner,
        jacpy_binding_typeof
    }
    type --> jaclang.runtime.python.bindings.functools {
        PropertyCallbacks,
        PropertyDefinition,
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        jacpy_binding_allocate,
        jacpy_binding_dict_get,
        jacpy_binding_dict_peek,
        jacpy_binding_dict_present,
        jacpy_binding_dict_replace,
        jacpy_binding_dict_set,
        jacpy_binding_marker,
        jacpy_binding_method_bind,
        jacpy_binding_owner,
        jacpy_binding_typeof
    }
    type --> jaclang.runtime.python.bindings.itertools {
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        TypeSlot,
        jacpy_binding_allocate,
        jacpy_binding_basicsize,
        jacpy_binding_generic_alias,
        jacpy_binding_owner,
        jacpy_binding_slot,
        jacpy_binding_type_matches,
        jacpy_binding_typeof
    }
    type --> jaclang.runtime.python.bindings.json {
        PropertyCallbacks,
        PropertyDefinition,
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        jacpy_binding_allocate
    }
    type --> jaclang.runtime.python.bindings.operator {
        PropertyCallbacks,
        PropertyDefinition,
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        jacpy_binding_allocate,
        jacpy_binding_typeof
    }
    type --> jaclang.runtime.python.bindings.payload {
        jacpy_binding_dict_clear,
        jacpy_binding_dict_visit,
        jacpy_binding_free,
        jacpy_binding_typeof
    }
    type --> jaclang.runtime.python.bindings.pickle {
        PropertyCallbacks,
        PropertyDefinition,
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        jacpy_binding_allocate,
        jacpy_binding_basicsize,
        jacpy_binding_matches,
        jacpy_binding_owner,
        jacpy_binding_type_matches,
        jacpy_binding_typeof
    }
    type --> jaclang.runtime.python.bindings.queue {
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        TypeSlot,
        jacpy_binding_allocate,
        jacpy_binding_base,
        jacpy_binding_owner,
        jacpy_binding_slot,
        jacpy_binding_typeof
    }
    type --> jaclang.runtime.python.bindings.random {
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        TypeSlot,
        jacpy_binding_allocate,
        jacpy_binding_base,
        jacpy_binding_free,
        jacpy_binding_slot,
        jacpy_binding_typeof
    }
    type --> jaclang.runtime.python.bindings.struct {
        PropertyCallbacks,
        PropertyDefinition,
        TypeDefinition,
        TypeFlags,
        TypeHooks,
        jacpy_binding_allocate,
        jacpy_binding_owner,
        jacpy_binding_typeof
    }
}

impl import jaclang.runtime.python.modules {
    array --> jaclang.runtime.python.bindings.array {
        array_cursor,
        array_state,
        jacpy_array_address,
        jacpy_array_assign,
        jacpy_array_assign_slice,
        jacpy_array_clear,
        jacpy_array_code,
        jacpy_array_compare,
        jacpy_array_copy,
        jacpy_array_cursor_clear,
        jacpy_array_cursor_index,
        jacpy_array_cursor_new,
        jacpy_array_cursor_next,
        jacpy_array_cursor_owner,
        jacpy_array_cursor_reduce,
        jacpy_array_cursor_set,
        jacpy_array_delete,
        jacpy_array_empty,
        jacpy_array_export,
        jacpy_array_extend,
        jacpy_array_field,
        jacpy_array_frombytes,
        jacpy_array_fromfile,
        jacpy_array_fromlist,
        jacpy_array_fromunicode,
        jacpy_array_init,
        jacpy_array_insert,
        jacpy_array_item,
        jacpy_array_itemsize,
        jacpy_array_length,
        jacpy_array_memory,
        jacpy_array_new,
        jacpy_array_pop,
        jacpy_array_reconstruct_object,
        jacpy_array_reduce,
        jacpy_array_repeat,
        jacpy_array_repr,
        jacpy_array_reverse,
        jacpy_array_search,
        jacpy_array_tobytes,
        jacpy_array_tofile,
        jacpy_array_tolist,
        jacpy_array_tounicode
    }
    binary_scalars --> jaclang.runtime.python.modules.array {
        integer_from_bits,
        read_bits,
        write_bits
    }
    binary_scalars --> jaclang.runtime.python.modules.pickle_decode {
        integer_from_bits
    }
    binary_scalars --> jaclang.runtime.python.modules.pickle_stream {
        read_bits,
        write_bits
    }
    binary_scalars --> jaclang.runtime.python.modules.struct {
        integer_from_bits,
        read_bits,
        write_bits
    }
    binascii --> jaclang.runtime.python.bindings.binascii { jacpy_binascii_convert }
    bisect --> jaclang.runtime.python.bindings.bisect { jacpy_bisect }
    cmath --> jaclang.runtime.python.bindings.cmath {
        jacpy_cmath_isclose,
        jacpy_cmath_log,
        jacpy_cmath_rect,
        jacpy_cmath_unary
    }
    collections --> jaclang.runtime.python.bindings.collections {
        deque_cursor,
        deque_state,
        jacpy_count_elements,
        jacpy_default_missing,
        jacpy_default_repr,
        jacpy_deque_append,
        jacpy_deque_assign,
        jacpy_deque_borrow,
        jacpy_deque_clear,
        jacpy_deque_compare,
        jacpy_deque_consumed,
        jacpy_deque_cursor,
        jacpy_deque_extend,
        jacpy_deque_insert,
        jacpy_deque_item,
        jacpy_deque_limit,
        jacpy_deque_memory,
        jacpy_deque_next,
        jacpy_deque_pop,
        jacpy_deque_remaining,
        jacpy_deque_repeat,
        jacpy_deque_repr,
        jacpy_deque_reverse,
        jacpy_deque_rotate,
        jacpy_deque_search,
        jacpy_deque_set_limit,
        jacpy_deque_size
    }
    combinatorics --> jaclang.runtime.python.bindings.itertools {
        combinatorial_state,
        jacpy_combinatorial_clear,
        jacpy_combinatorial_field,
        jacpy_combinatorial_init,
        jacpy_combinatorial_memory,
        jacpy_combinatorial_new,
        jacpy_combinatorial_next
    }
    csv --> jaclang.runtime.python.bindings.csv {
        CsvConfig,
        csv_reader,
        csv_writer,
        jacpy_csv_dialect,
        jacpy_csv_read,
        jacpy_csv_reader_clear,
        jacpy_csv_reader_fields,
        jacpy_csv_reader_line,
        jacpy_csv_registry,
        jacpy_csv_write
    }
    functools --> jaclang.runtime.python.bindings.functools {
        jacpy_cmp_key,
        jacpy_lru_call,
        jacpy_lru_clear,
        jacpy_lru_destroy,
        jacpy_lru_field,
        jacpy_lru_info,
        jacpy_lru_init,
        jacpy_partial_call,
        jacpy_partial_clear,
        jacpy_partial_field,
        jacpy_partial_init,
        jacpy_partial_repr,
        jacpy_partial_restore,
        jacpy_reduce,
        lru_state,
        partial_state
    }
    grouping --> jaclang.runtime.python.bindings.itertools {
        group_state,
        jacpy_group_activate,
        jacpy_group_clear,
        jacpy_group_field,
        jacpy_group_init,
        jacpy_group_next,
        jacpy_grouper_next
    }
    heapq --> jaclang.runtime.python.bindings.heapq {
        jacpy_heap_pop,
        jacpy_heap_push,
        jacpy_heap_pushpop,
        jacpy_heap_replace,
        jacpy_heapify
    }
    iterators --> jaclang.runtime.python.bindings.itertools {
        jacpy_pipeline_clear,
        jacpy_pipeline_field,
        jacpy_pipeline_init,
        jacpy_pipeline_length,
        jacpy_pipeline_new,
        jacpy_pipeline_next,
        jacpy_pipeline_repr,
        pipeline_state
    }
    iterators --> jaclang.runtime.python.modules.combinatorics { reusable_tuple }
    json --> jaclang.runtime.python.bindings.json {
        jacpy_json_encode,
        jacpy_json_escape,
        jacpy_json_scan,
        jacpy_json_scanstring
    }
    math --> jaclang.runtime.python.bindings.math {
        jacpy_math_binary,
        jacpy_math_comb,
        jacpy_math_dist,
        jacpy_math_factorial,
        jacpy_math_fma,
        jacpy_math_fsum,
        jacpy_math_gcd,
        jacpy_math_hypot,
        jacpy_math_isclose,
        jacpy_math_isqrt,
        jacpy_math_ldexp,
        jacpy_math_log,
        jacpy_math_nextafter,
        jacpy_math_parts,
        jacpy_math_prod,
        jacpy_math_sumprod,
        jacpy_math_unary
    }
    numeric --> jaclang.runtime.python.modules.cmath {
        asinh,
        atan2,
        copysign,
        cos,
        cosh,
        exp,
        fabs,
        hypot,
        isfinite,
        isinf,
        isnan,
        log,
        log1p,
        scaled,
        sin,
        sinh,
        sqrt,
        tan,
        tanh
    }
    numeric --> jaclang.runtime.python.modules.math {
        acos,
        acosh,
        asin,
        asinh,
        atan,
        atan2,
        atanh,
        cbrt,
        ceil,
        copysign,
        cos,
        cosh,
        erf,
        erfc,
        exp,
        exp2,
        expm1,
        fabs,
        floor,
        fma,
        fmod,
        infinity,
        isfinite,
        isinf,
        isnan,
        lgamma,
        log,
        log10,
        log1p,
        log2,
        nan,
        nextafter,
        pow,
        remainder,
        scaled,
        sin,
        sinh,
        sqrt,
        tan,
        tanh,
        tgamma
    }
    numeric --> jaclang.runtime.python.modules.statistics { fabs, log, sqrt }
    object_ring --> jaclang.runtime.python.modules.collections { object_ring }
    object_ring --> jaclang.runtime.python.modules.queue { object_ring }
    operator --> jaclang.runtime.python.bindings.operator {
        jacpy_operator_abs,
        jacpy_operator_add,
        jacpy_operator_and_,
        jacpy_operator_apply,
        jacpy_operator_call,
        jacpy_operator_compare,
        jacpy_operator_concat,
        jacpy_operator_contains,
        jacpy_operator_countOf,
        jacpy_operator_delitem,
        jacpy_operator_digest,
        jacpy_operator_floordiv,
        jacpy_operator_getitem,
        jacpy_operator_iadd,
        jacpy_operator_iand,
        jacpy_operator_iconcat,
        jacpy_operator_ifloordiv,
        jacpy_operator_ilshift,
        jacpy_operator_imatmul,
        jacpy_operator_imod,
        jacpy_operator_imul,
        jacpy_operator_index,
        jacpy_operator_indexOf,
        jacpy_operator_invert,
        jacpy_operator_ior,
        jacpy_operator_ipow,
        jacpy_operator_irshift,
        jacpy_operator_is_,
        jacpy_operator_is_none,
        jacpy_operator_is_not,
        jacpy_operator_is_not_none,
        jacpy_operator_isub,
        jacpy_operator_itruediv,
        jacpy_operator_ixor,
        jacpy_operator_length_hint,
        jacpy_operator_lshift,
        jacpy_operator_matmul,
        jacpy_operator_mod,
        jacpy_operator_mul,
        jacpy_operator_neg,
        jacpy_operator_not_,
        jacpy_operator_or_,
        jacpy_operator_pos,
        jacpy_operator_pow,
        jacpy_operator_prepare,
        jacpy_operator_reduce,
        jacpy_operator_repr,
        jacpy_operator_rshift,
        jacpy_operator_setitem,
        jacpy_operator_sub,
        jacpy_operator_truediv,
        jacpy_operator_truth,
        jacpy_operator_xor
    }
    pickle --> jaclang.runtime.python.bindings.pickle {
        jacpy_pickler_clear,
        jacpy_pickler_dump,
        jacpy_pickler_field,
        jacpy_pickler_init,
        jacpy_pickler_memo,
        jacpy_pickler_memo_clear,
        jacpy_pickler_memo_set,
        jacpy_pickler_new,
        jacpy_pickler_size,
        jacpy_unpickler_clear,
        jacpy_unpickler_field,
        jacpy_unpickler_field_count,
        jacpy_unpickler_find,
        jacpy_unpickler_init,
        jacpy_unpickler_load,
        jacpy_unpickler_memo,
        jacpy_unpickler_memo_clear,
        jacpy_unpickler_memo_set,
        jacpy_unpickler_new,
        jacpy_unpickler_size
    }
    pickle_decode --> jaclang.runtime.python.bindings.pickle { unpickle_state }
    pickle_decode --> jaclang.runtime.python.modules.pickle { unpickle_state }
    pickle_encode --> jaclang.runtime.python.bindings.pickle { pickle_state }
    pickle_encode --> jaclang.runtime.python.modules.pickle { pickle_state }
    pickle_objects --> jaclang.runtime.python.modules.pickle { find_global }
    pickle_objects --> jaclang.runtime.python.modules.pickle_encode {
        global_names,
        mapped_names
    }
    pickle_opcodes --> jaclang.runtime.python.modules.pickle_decode { opcode }
    pickle_opcodes --> jaclang.runtime.python.modules.pickle_encode { opcode }
    pickle_stream --> jaclang.runtime.python.modules.pickle { builtin_stream_error }
    pickle_stream --> jaclang.runtime.python.modules.pickle_decode {
        builtin_stream_error,
        pickle_reader,
        stream_error
    }
    pickle_stream --> jaclang.runtime.python.modules.pickle_encode {
        builtin_stream_error,
        pickle_writer,
        stream_error
    }
    pickle_stream --> jaclang.runtime.python.modules.pickle_objects {
        builtin_stream_error,
        stream_error
    }
    queue --> jaclang.runtime.python.bindings.queue {
        jacpy_queue_get,
        jacpy_queue_new,
        jacpy_queue_put,
        jacpy_queue_size,
        queue_state
    }
    random --> jaclang.runtime.python.bindings.random {
        jacpy_random_bits,
        jacpy_random_float,
        jacpy_random_getstate,
        jacpy_random_new,
        jacpy_random_seed,
        jacpy_random_setstate,
        mt19937
    }
    statistics --> jaclang.runtime.python.bindings.statistics {
        jacpy_statistics_inv_cdf
    }
    struct --> jaclang.runtime.python.bindings.struct {
        jacpy_struct_cached,
        jacpy_struct_compile,
        jacpy_struct_cursor,
        jacpy_struct_items,
        jacpy_struct_memory,
        jacpy_struct_next,
        jacpy_struct_offset,
        jacpy_struct_pack,
        jacpy_struct_remaining,
        jacpy_struct_size,
        jacpy_struct_unpack,
        struct_plan,
        unpack_cursor
    }
    tee --> jaclang.runtime.python.bindings.itertools {
        TeeBindings,
        jacpy_tee_block_clear,
        jacpy_tee_block_count,
        jacpy_tee_block_field,
        jacpy_tee_block_init,
        jacpy_tee_construct,
        jacpy_tee_cursor_clear,
        jacpy_tee_cursor_field,
        jacpy_tee_next,
        jacpy_tee_split,
        tee_block,
        tee_cursor
    }
}

impl import jaclang.scale {
    admin --> jaclang.scale.admin.admin_portal.JacAPIServerAdmin.build_admin_client {
        admin_portal
    }
    admin --> jaclang.scale.tests.misc.test_k8s_ops { k8s_ops }
    admin as admin_pkg --> jaclang.scale.tests.misc.test_ops_signals;
    admin --> jaclang.scale.tests.server.test_admin;
    plugin --> jaclang.cli.commands.execution._serve_fleet { scale_local_serve }
    comptime plugin --> jaclang.cli.manifest { SPEC_SCALE_CMD }
    sdk --> jaclang.scale.tests.deploy.sdk_deploy_driver {
        ProgressEvent,
        ScaleClient,
        deploy
    }
    sdk --> jaclang.scale.tests.deploy.test_superseded_deployment_reap {
        AutoscalerRuntimeStatus,
        AutoscalerTransition,
        ScaleClient
    }
}

impl import jaclang.scale._optdeps {
    apscheduler --> jaclang.scale.scheduler.scheduler {
        BackgroundScheduler,
        CronTrigger,
        HAS_APSCHEDULER
    }
    apscheduler --> jaclang.scale.tests.misc.test_optional_deps;
    apscheduler --> jaclang.scale.tests.misc.test_optional_deps {
        BackgroundScheduler,
        HAS_APSCHEDULER
    }
    firebase_auth --> jaclang.scale.sso.firebase {
        HAS_FIREBASE_ADMIN,
        auth,
        credentials,
        firebase_admin
    }
    firebase_auth --> jaclang.scale.tests.server.test_firebase_auth_sso {
        firebase_admin as _real_firebase_admin
    }
    gcs --> jaclang.scale.storage.gcs_storage {
        NotFound,
        StorageClient,
        require_google_cloud_storage
    }
    gcs --> jaclang.scale.tests.misc.test_optional_deps { HAS_GCS, StorageClient }
    kubernetes --> jaclang.scale.admin.k8s_ops { HAS_KUBERNETES, client, config }
    kubernetes --> jaclang.scale.deploy.autoscale.autoscaler.Autoscaler.read_workload {
        ApiException,
        client
    }
    kubernetes --> jaclang.scale.deploy.autoscale.hpa_autoscaler {
        ApiException,
        AutoscalingV2Api,
        client
    }
    kubernetes --> jaclang.scale.deploy.autoscale.http_activation_config {
        ApiException
    }
    kubernetes --> jaclang.scale.deploy.autoscale.keda_autoscaler {
        ApiException,
        AutoscalingV2Api,
        client
    }
    kubernetes --> jaclang.scale.deploy.autoscale.keda_autoscaler.KEDAAutoscaler.watch_scale_targets {
        watch
    }
    kubernetes --> jaclang.scale.deploy.target.kubernetes.cluster_provider { client }
    kubernetes --> jaclang.scale.deploy.target.kubernetes.database_provisioner {
        client
    }
    kubernetes --> jaclang.scale.deploy.target.kubernetes.ingress {
        ApiException,
        client
    }
    kubernetes --> jaclang.scale.deploy.target.kubernetes.kubernetes_target {
        ApiException,
        ConfigException,
        client,
        config as k8s_cluster_config
    }
    kubernetes --> jaclang.scale.deploy.target.kubernetes.monitoring {
        ApiException,
        client
    }
    kubernetes --> jaclang.scale.deploy.target.kubernetes.target {
        ApiException,
        client
    }
    kubernetes --> jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
        ApiException,
        ConfigException,
        client,
        config
    }
    kubernetes --> jaclang.scale.injector.pvc_injector.PvcInjector.seed {
        ApiException,
        client
    }
    kubernetes --> jaclang.scale.tests.deploy.observer_transition_recorder {
        ApiException,
        config
    }
    kubernetes --> jaclang.scale.tests.deploy.test_database_intent { ApiException }
    kubernetes --> jaclang.scale.tests.misc.test_optional_deps;
    kubernetes --> jaclang.scale.tests.misc.test_optional_deps {
        HAS_KUBERNETES,
        client as k8s_client
    }
    opentelemetry --> jaclang.scale.admin.ops { HAS_OTEL }
    opentelemetry --> jaclang.scale.runtime.context.tracing { HAS_OTEL }
    optional_deps --> jaclang.scale._optdeps.gcs { require_optional }
    optional_deps --> jaclang.scale._optdeps.opentelemetry { is_optional_available }
    optional_deps --> jaclang.scale.config.project_env { require_optional }
    optional_deps --> jaclang.scale.deploy.target.factory { require_optional }
    optional_deps --> jaclang.scale.observability.factory { is_optional_available }
    optional_deps --> jaclang.scale.sso.firebase { require_optional }
    optional_deps --> jaclang.scale.tests.misc.test_optional_deps {
        is_optional_available,
        require_optional
    }
    prometheus --> jaclang.scale.admin.ops { HAS_PROMETHEUS }
    prometheus --> jaclang.scale.observability.prometheus_metrics {
        CONTENT_TYPE_LATEST,
        CollectorRegistry,
        Counter,
        Gauge,
        Histogram,
        generate_latest
    }
    prometheus --> jaclang.scale.tests.misc.test_optional_deps;
    prometheus --> jaclang.scale.tests.misc.test_optional_deps {
        Counter,
        HAS_PROMETHEUS
    }
}

impl import jaclang.scale.admin {
    admin_portal --> jaclang.scale.runtime.gateway.microservice_gateway {
        JacAPIServerAdmin
    }
    admin_portal --> jaclang.scale.server.extensions { JacAPIServerAdmin }
    admin_portal --> jaclang.scale.tests.misc.test_metrics {
        _calculate_metrics_summary,
        _classify_path,
        _parse_prometheus_text,
        _percentile_from_buckets
    }
    admin_portal --> jaclang.scale.tests.misc.test_metrics._distribution_for {
        _calculate_metrics_summary,
        _parse_prometheus_text
    }
    deploy_health --> jaclang.scale.runtime.gateway.microservice_gateway {
        JacAPIServerDeployHealth
    }
    deploy_health --> jaclang.scale.server.extensions { JacAPIServerDeployHealth }
    deploy_health --> jaclang.scale.tests.deploy.test_ops_deploy {
        JacAPIServerDeployHealth,
        summarize_deployment,
        summarize_pod
    }
    k8s_ops --> jaclang.scale.admin.deploy_health {
        api_error_detail,
        apps_api,
        core_api,
        k8s_available,
        ops_namespace,
        unavailable_detail
    }
    k8s_ops --> jaclang.scale.admin.network {
        api_error_detail,
        core_api,
        k8s_available,
        networking_api,
        ops_namespace,
        unavailable_detail
    }
    k8s_ops --> jaclang.scale.admin.podenv {
        api_error_detail,
        core_api,
        k8s_available,
        ops_namespace,
        unavailable_detail
    }
    llm_telemetry --> jaclang.scale.runtime.gateway.microservice_gateway {
        JacAPIServerLLMTelemetry
    }
    llm_telemetry --> jaclang.scale.server.extensions { JacAPIServerLLMTelemetry }
    llm_telemetry --> jaclang.scale.tests.misc.test_llm_telemetry {
        LLMCallRecord,
        TelemetryStore,
        Trace
    }
    logs --> jaclang.scale.admin.ops { _app_namespace, _loki_base_url }
    logs --> jaclang.scale.runtime.gateway.microservice_gateway { JacAPIServerLogs }
    logs --> jaclang.scale.server.extensions { JacAPIServerLogs }
    logs --> jaclang.scale.tests.server.test_admin_logs {
        JacAPIServerLogs,
        _build_logql,
        _flatten_loki_response,
        _service_to_pod_regex_for_mode,
        _services_for_mode
    }
    network --> jaclang.scale.runtime.gateway.microservice_gateway {
        JacAPIServerNetwork
    }
    network --> jaclang.scale.server.extensions { JacAPIServerNetwork }
    network --> jaclang.scale.tests.deploy.test_ops_network {
        JacAPIServerNetwork,
        pvc_claimants,
        summarize_ingress,
        summarize_pvc,
        summarize_service
    }
    ops --> jaclang.scale.runtime.gateway.microservice_gateway { JacAPIServerOps }
    ops --> jaclang.scale.server.extensions { JacAPIServerOps }
    ops --> jaclang.scale.tests.deploy.test_ops_health {
        JacAPIServerOps,
        _traces_chain,
        short_circuit_chain
    }
    podenv --> jaclang.scale.runtime.gateway.microservice_gateway { JacAPIServerPodEnv }
    podenv --> jaclang.scale.server.extensions { JacAPIServerPodEnv }
    podenv --> jaclang.scale.tests.misc.test_ops_podenv {
        JacAPIServerPodEnv,
        pod_env_entries,
        redact_entry
    }
    service_urls --> jaclang.scale.admin.logs { service_base_url }
    service_urls --> jaclang.scale.admin.ops { service_base_url }
    service_urls --> jaclang.scale.admin.traces { service_base_url }
    service_urls --> jaclang.scale.tests.misc.test_service_urls { service_base_url }
    traces --> jaclang.scale.admin.ops { _tempo_base_url }
    traces --> jaclang.scale.runtime.gateway.microservice_gateway { JacAPIServerTraces }
    traces --> jaclang.scale.server.extensions { JacAPIServerTraces }
    traces --> jaclang.scale.tests.server.test_traces_admin {
        _build_traceql,
        _flatten_tempo_trace,
        _normalize_trace_id,
        _otlp_attrs,
        _otlp_value
    }
    workload_helpers --> jaclang.scale.admin.workloads {
        match_owner,
        owner_name_from_pod,
        phase_to_status
    }
    workload_helpers --> jaclang.scale.tests.server.test_admin_workloads {
        match_owner,
        owner_name_from_pod,
        phase_to_status
    }
    workloads --> jaclang.scale.runtime.gateway.microservice_gateway {
        JacAPIServerWorkloads
    }
    workloads --> jaclang.scale.server.extensions { JacAPIServerWorkloads }
}

impl import jaclang.scale.config {
    app_config --> jaclang.scale.deploy.target.deployment_target { AppConfig }
    app_config --> jaclang.scale.deploy.target.kubernetes.manifest_builder { AppConfig }
    app_config --> jaclang.scale.deploy.target.kubernetes.target { AppConfig }
    app_config --> jaclang.scale.plugin { deployed_tree }
    app_config --> jaclang.scale.runtime.cli.plan { AppConfig }
    app_config --> jaclang.scale.runtime.realizer.kubernetes_realizer {
        AppConfig,
        deployed_tree
    }
    app_config --> jaclang.scale.sdk.client { AppConfig, deployed_tree }
    app_config --> jaclang.scale.tests.apps.test_app_scale_overrides { AppConfig }
    app_config --> jaclang.scale.tests.deploy.test_access_hint { AppConfig }
    app_config --> jaclang.scale.tests.deploy.test_alb_zero_downtime { AppConfig }
    app_config --> jaclang.scale.tests.deploy.test_deploy_banner { deployed_tree }
    app_config --> jaclang.scale.tests.deploy.test_deploy_k8s { AppConfig }
    app_config --> jaclang.scale.tests.deploy.test_dry_run_purity { AppConfig }
    app_config --> jaclang.scale.tests.deploy.test_factories { AppConfig }
    app_config --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        AppConfig
    }
    app_config --> jaclang.scale.tests.deploy.test_memory_trigger_guard { AppConfig }
    app_config --> jaclang.scale.tests.deploy.test_pdb_budget { AppConfig }
    app_config --> jaclang.scale.tests.deploy.test_pod_env { AppConfig }
    app_config --> jaclang.scale.tests.deploy.test_show_yaml_autoscalers { AppConfig }
    app_config --> jaclang.scale.tests.deploy.test_superseded_deployment_reap {
        AppConfig
    }
    app_config --> jaclang.scale.tests.deploy.test_version_pin { AppConfig }
    base_config --> jaclang.scale.deploy.target.deployment_target { BaseConfig }
    base_config --> jaclang.scale.deploy.target.kubernetes.kubernetes_config {
        BaseConfig
    }
    config_loader --> jaclang.scale.admin.admin_portal { get_scale_config }
    config_loader --> jaclang.scale.admin.llm_telemetry.JacAPIServerLLMTelemetry.register_llm_telemetry_endpoints {
        get_scale_config
    }
    config_loader --> jaclang.scale.admin.logs { get_scale_config }
    config_loader --> jaclang.scale.admin.ops { get_scale_config }
    config_loader --> jaclang.scale.admin.service_urls { get_scale_config }
    config_loader --> jaclang.scale.admin.traces { get_scale_config }
    config_loader --> jaclang.scale.admin.workloads._metrics_namespace {
        get_scale_config
    }
    config_loader --> jaclang.scale.admin.workloads._unavailable_reason {
        get_scale_config
    }
    config_loader --> jaclang.scale.deploy.database.kubernetes_postgres {
        get_scale_config
    }
    config_loader --> jaclang.scale.deploy.target.kubernetes.kubernetes_target {
        get_scale_config
    }
    config_loader --> jaclang.scale.deploy.target.kubernetes.manifest_builder {
        GATEWAY_POD_KEYS,
        get_scale_config,
        normalize_gateway_config
    }
    config_loader --> jaclang.scale.deploy.target.kubernetes.runtime_resolver.resolve_peer_route {
        get_scale_config
    }
    config_loader --> jaclang.scale.deploy.target.kubernetes.target { get_scale_config }
    config_loader --> jaclang.scale.deploy.target.kubernetes.target.KubernetesTarget._gateway_cfg {
        normalize_gateway_config
    }
    config_loader --> jaclang.scale.plugin { get_scale_config }
    config_loader --> jaclang.scale.runtime.cli.diagnostics.PlanValidator._check_config_keys {
        get_scale_config
    }
    config_loader --> jaclang.scale.runtime.context.log_emit.install_structured_logging {
        peek_scale_config
    }
    config_loader --> jaclang.scale.runtime.context.util.boot_health_timeout {
        get_scale_config
    }
    config_loader --> jaclang.scale.runtime.context.util.http_forward_timeout {
        get_scale_config
    }
    config_loader --> jaclang.scale.runtime.context.util.route_refresh_seconds {
        get_scale_config
    }
    config_loader --> jaclang.scale.runtime.fleet._build_fleet { app_scale_overrides }
    config_loader --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        get_scale_config
    }
    config_loader --> jaclang.scale.runtime.provider { get_scale_config }
    config_loader --> jaclang.scale.runtime.provider.JacScaleRuntime.get_sv_service_routes {
        get_scale_config
    }
    config_loader --> jaclang.scale.runtime.realizer.kubernetes_realizer {
        get_scale_config
    }
    config_loader --> jaclang.scale.runtime.rpc.rpc._sv_rpc_timeout { get_scale_config }
    config_loader --> jaclang.scale.scheduler.scheduler { get_scale_config }
    config_loader --> jaclang.scale.server.extensions { get_scale_config }
    config_loader --> jaclang.scale.server.jobs_ext { get_scale_config }
    config_loader --> jaclang.scale.server.sso_ext { get_scale_config }
    config_loader --> jaclang.scale.server.webhook_ext { get_scale_config }
    config_loader --> jaclang.scale.server.websocket_ext { get_scale_config }
    config_loader --> jaclang.scale.sso.sso_auth { get_scale_config }
    config_loader --> jaclang.scale.tests.apps.test_app_scale_overrides {
        APP_SCALE_KEYS,
        JacScaleConfig,
        app_scale_overrides,
        get_scale_config,
        normalize_gateway_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.data.test_firebase_env {
        get_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.data.test_gateway_owned_identity {
        normalize_gateway_config
    }
    config_loader --> jaclang.scale.tests.deploy.test_client_build_stage {
        get_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.deploy.test_database_intent {
        get_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.deploy.test_deploy_k8s {
        JacScaleConfig,
        get_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.deploy.test_deployment_overlay {
        JacScaleConfig
    }
    config_loader --> jaclang.scale.tests.deploy.test_gateway_config_isolation {
        get_scale_config,
        reset_scale_config
    }
    config_loader as config_loader_mod --> jaclang.scale.tests.deploy.test_pod_env;
    config_loader --> jaclang.scale.tests.deploy.test_pod_env { reset_scale_config }
    config_loader --> jaclang.scale.tests.deploy.test_service_routing {
        get_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.microservices.test_binary_injector {
        JacScaleConfig
    }
    config_loader as cfg_mod --> jaclang.scale.tests.microservices.test_gateway;
    config_loader as config_loader --> jaclang.scale.tests.microservices.test_gateway._with_cors_config;
    config_loader --> jaclang.scale.tests.misc.test_config_loader {
        JacScaleConfig,
        get_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.misc.test_config_validation {
        JacScaleConfig,
        get_scale_config,
        normalize_gateway_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.misc.test_log_emit {
        get_scale_config,
        peek_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.misc.test_service_urls {
        get_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.misc.test_shared_store_failure {
        get_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.server.test_firebase_auth_sso {
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.server.test_scheduler_endpoints {
        get_scale_config,
        reset_scale_config
    }
    config_loader as config_loader_mod --> jaclang.scale.tests.server.test_sv_auth_forward;
    config_loader --> jaclang.scale.tests.server.test_webhook {
        get_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.tests.server.test_ws_hardening {
        _ws_positive,
        get_scale_config,
        reset_scale_config
    }
    config_loader --> jaclang.scale.webhook.webhook { get_scale_config }
    config_loader --> jaclang.server.shared_store.scale_db_url { get_scale_config }
    dev_config --> jaclang.scale.deploy.target.kubernetes.target.KubernetesTarget.deploy {
        resolve_dev_channel
    }
    dev_config --> jaclang.scale.injector.binary.deploy_generation_refusal {
        Channel,
        resolve_dev_channel
    }
    dev_config --> jaclang.scale.injector.binary.download_release_binary {
        BINARY_PATH_ENV
    }
    dev_config --> jaclang.scale.injector.binary.host_toolchain_path {
        resolve_dev_channel
    }
    dev_config --> jaclang.scale.injector.binary.preflight_pod_runtime { Channel }
    dev_config --> jaclang.scale.injector.binary.resolve_console_version { Channel }
    dev_config --> jaclang.scale.injector.binary.resolve_deploy_version { Channel }
    dev_config --> jaclang.scale.injector.binary.resolve_pod_base_image {
        Channel,
        resolve_dev_channel,
        resolve_experimental_pr,
        resolve_pinned_spec
    }
    dev_config --> jaclang.scale.injector.binary_injector { Channel }
    dev_config --> jaclang.scale.injector.binary_injector.select_injector {
        resolve_dev_channel
    }
    dev_config --> jaclang.scale.tests.microservices.test_binary_injector {
        BINARY_PATH_ENV,
        Channel,
        resolve_dev_channel,
        resolve_experimental_pr
    }
    firebase_env --> jaclang.scale.config.config_loader {
        FIREBASE_AUTH_PROJECT_ID_ENV,
        FIRESTORE_PROJECT_ID_ENV,
        resolve_firebase_project_id
    }
    firebase_env --> jaclang.scale.sso.firebase { firebase_project_id_env_hint }
    firebase_env --> jaclang.scale.sso.sso_auth { firebase_project_id_env_hint }
    firebase_env --> jaclang.scale.storage.factory {
        JAC_STORAGE_FIREBASE_PROJECT_ID_ENV,
        JAC_STORAGE_GCS_PROJECT_ID_ENV,
        resolve_firebase_project_id
    }
    firebase_env --> jaclang.scale.tests.data.test_firebase_env {
        FIREBASE_AUTH_PROJECT_ID_ENV,
        FIREBASE_PROJECT_ID_ENV,
        FIRESTORE_PROJECT_ID_ENV,
        JAC_STORAGE_FIREBASE_PROJECT_ID_ENV,
        resolve_firebase_project_id
    }
    plugin_config --> jaclang.scale.config.config_loader.JacScaleConfig.get_app_config_schema {
        app_scale_schema
    }
    plugin_config --> jaclang.scale.config.validation {
        JacScalePluginConfig,
        app_scale_schema
    }
    plugin_config --> jaclang.scale.tests.misc.test_config_loader {
        JacScalePluginConfig
    }
    plugin_config --> jaclang.scale.tests.misc.test_config_validation {
        JacScalePluginConfig
    }
    project_env --> jaclang.scale.plugin { load_project_env }
    project_env --> jaclang.scale.runtime.realizer.kubernetes_realizer {
        load_project_env
    }
    project_env --> jaclang.scale.tests.misc.test_optional_deps {
        PROJECT_ENV_CAPABILITY,
        project_env_path
    }
    validation --> jaclang.scale.config.config_loader.JacScaleConfig.get_config_schema {
        scale_schema_options
    }
    validation --> jaclang.scale.config.config_loader.JacScaleConfig.get_config_strict_env {
        STRICT_ENV
    }
    validation --> jaclang.scale.config.config_loader.JacScaleConfig.get_scheduler_config {
        scheduler_job_cap,
        scheduler_min_interval
    }
    validation --> jaclang.scale.config.config_loader.app_scale_overrides {
        STRICT_ENV,
        validate_app_scale_config
    }
    validation --> jaclang.scale.runtime.cli.diagnostics.PlanValidator._check_config_keys {
        validate_scale_config
    }
    validation --> jaclang.scale.tests.apps.test_app_scale_overrides {
        STRICT_ENV,
        validate_app_scale_config,
        validate_scale_config
    }
    validation --> jaclang.scale.tests.misc.test_config_validation {
        STRICT_ENV,
        known_deploy_targets,
        scheduler_job_cap,
        scheduler_min_interval,
        validate_scale_config
    }
}

impl import jaclang.scale.deploy.autoscale {
    autoscaler --> jaclang.scale.deploy.autoscale.factory { Autoscaler }
    autoscaler --> jaclang.scale.deploy.autoscale.hpa_autoscaler {
        Autoscaler,
        AutoscalerRuntimeStatus,
        AutoscalerSpec,
        DEFAULT_CPU_UTILIZATION_TARGET,
        DEFAULT_MEMORY_UTILIZATION_TARGET,
        condition,
        normalize_conditions,
        tristate
    }
    autoscaler --> jaclang.scale.deploy.autoscale.keda_autoscaler {
        Autoscaler,
        AutoscalerRuntimeStatus,
        AutoscalerSpec,
        AutoscalerTransition,
        DEFAULT_CPU_UTILIZATION_TARGET,
        DEFAULT_MEMORY_UTILIZATION_TARGET,
        Trigger,
        TriggerAuth,
        condition,
        normalize_conditions,
        transition_from,
        tristate
    }
    autoscaler --> jaclang.scale.deploy.target.kubernetes.target {
        AutoscalerSpec,
        Trigger,
        TriggerAuth
    }
    autoscaler --> jaclang.scale.sdk { AutoscalerRuntimeStatus, AutoscalerTransition }
    autoscaler --> jaclang.scale.sdk.client {
        AutoscalerRuntimeStatus,
        AutoscalerTransition
    }
    autoscaler --> jaclang.scale.tests.deploy.test_deploy_k8s {
        AutoscalerSpec,
        Trigger
    }
    autoscaler --> jaclang.scale.tests.deploy.test_deployment_overlay {
        Autoscaler,
        AutoscalerSpec
    }
    autoscaler --> jaclang.scale.tests.deploy.test_factories { AutoscalerSpec, Trigger }
    autoscaler --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        AutoscalerSpec,
        Trigger,
        TriggerAuth
    }
    factory --> jaclang.scale.deploy.target.kubernetes.target { AutoscalerFactory }
    factory --> jaclang.scale.sdk.client { AutoscalerFactory }
    factory --> jaclang.scale.tests.deploy.test_deploy_k8s { AutoscalerFactory }
    factory --> jaclang.scale.tests.deploy.test_factories { AutoscalerFactory }
    factory --> jaclang.scale.tests.deploy.test_service_routing { AutoscalerFactory }
    hpa_autoscaler --> jaclang.scale.deploy.autoscale.factory.AutoscalerFactory.create {
        HPAAutoscaler
    }
    hpa_autoscaler --> jaclang.scale.tests.deploy.test_factories { HPAAutoscaler }
    http_activation --> jaclang.scale.deploy.autoscale.http_activation_config {
        HTTPActivationSpec,
        HTTPColdStartSpec,
        HTTPConcurrencyMetric,
        HTTPHeaderMatch,
        HTTPPathMatch,
        HTTPRequestRateMetric,
        HTTPRoutingRule,
        HTTPServiceTarget,
        HTTPStaticResponse,
        HTTPTimeoutSpec
    }
    http_activation --> jaclang.scale.deploy.autoscale.keda_autoscaler {
        HTTPActivationSpec,
        HTTPRoutingRule
    }
    http_activation --> jaclang.scale.tests.deploy.http_activation_test_support {
        HTTPActivationSpec,
        HTTPConcurrencyMetric,
        HTTPServiceTarget
    }
    http_activation --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        HTTPColdStartSpec,
        HTTPHeaderMatch,
        HTTPPathMatch,
        HTTPRequestRateMetric,
        HTTPRoutingRule,
        HTTPServiceTarget,
        HTTPStaticResponse,
        HTTPTimeoutSpec
    }
    http_activation_config --> jaclang.scale.deploy.target.kubernetes.manifest_builder {
        build_http_activation_spec
    }
    http_activation_config --> jaclang.scale.deploy.target.kubernetes.target {
        apply_http_activation_for_target,
        destroy_http_activation_for_target
    }
    http_activation_config --> jaclang.scale.tests.deploy.test_http_activation_config {
        apply_http_activation_for_target,
        build_http_activation_spec,
        destroy_http_activation_for_target
    }
    keda_autoscaler --> jaclang.scale.deploy.autoscale.factory.AutoscalerFactory.create {
        KEDAAutoscaler
    }
    keda_autoscaler --> jaclang.scale.deploy.autoscale.http_activation_config {
        KEDAAutoscaler
    }
    keda_autoscaler --> jaclang.scale.deploy.target.kubernetes.target { KEDAAutoscaler }
    keda_autoscaler --> jaclang.scale.tests.deploy.http_activation_test_support {
        KEDAAutoscaler
    }
    keda_autoscaler --> jaclang.scale.tests.deploy.observer_transition_recorder {
        KEDAAutoscaler
    }
    keda_autoscaler --> jaclang.scale.tests.deploy.test_factories { KEDAAutoscaler }
    keda_autoscaler --> jaclang.scale.tests.deploy.test_http_activation_config {
        KEDAAutoscaler
    }
    keda_autoscaler --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        KEDAAutoscaler
    }
    keda_autoscaler --> jaclang.scale.tests.deploy.test_service_routing {
        KEDAAutoscaler
    }
    keda_capabilities --> jaclang.scale.deploy.autoscale.keda_autoscaler {
        KEDACapabilities,
        SUPPORTED_HTTP_INTERCEPTOR_API_VERSIONS
    }
}

impl import jaclang.scale.deploy.database {
    kubernetes_postgres --> jaclang.scale.deploy.target.kubernetes.kubernetes_target {
        KubernetesPostgresProvider
    }
    kubernetes_postgres --> jaclang.scale.tests.deploy.test_deploy_k8s {
        KubernetesPostgresProvider
    }
    kubernetes_postgres --> jaclang.scale.tests.deploy.test_postgres_predicate_lock_headroom {
        KubernetesPostgresProvider
    }
}

impl import jaclang.scale.deploy.target {
    deployment_target --> jaclang.scale.deploy.database.kubernetes_postgres {
        DeploymentTarget
    }
    deployment_target --> jaclang.scale.deploy.target.factory { DeploymentTarget }
    deployment_target --> jaclang.scale.deploy.target.kubernetes.kubernetes_target {
        DeploymentTarget
    }
    type deployment_target --> jaclang.scale.deploy.target.registry { DeploymentTarget }
    factory --> jaclang.scale.plugin { DeploymentTargetFactory }
    factory --> jaclang.scale.runtime.realizer.kubernetes_realizer {
        DeploymentTargetFactory
    }
    factory --> jaclang.scale.sdk.client {
        ensure_deploy_tooling,
        require_deploy_tooling
    }
    factory --> jaclang.scale.tests.deploy.test_deploy_banner {
        DeploymentTargetFactory
    }
    factory --> jaclang.scale.tests.deploy.test_deploy_k8s { DeploymentTargetFactory }
    factory --> jaclang.scale.tests.deploy.test_dry_run_purity {
        DeploymentTargetFactory
    }
    factory --> jaclang.scale.tests.deploy.test_factories { DeploymentTargetFactory }
    factory --> jaclang.scale.tests.misc.test_config_validation {
        DeploymentTargetFactory
    }
    factory --> jaclang.scale.tests.misc.test_optional_deps { DeploymentTargetFactory }
    registry --> jaclang.scale.config.validation { DeploymentTargetRegistry }
    registry --> jaclang.scale.deploy.target.factory { DeploymentTargetRegistry }
    registry --> jaclang.scale.tests.misc.test_config_validation {
        BUILTIN_TARGET_TYPES
    }
    service_deployer --> jaclang.scale.deploy.target.kubernetes.runtime_resolver {
        ServiceDeployer
    }
    service_deployer --> jaclang.scale.runtime.orchestrator.local_deployer {
        ServiceDeployer
    }
    service_deployer --> jaclang.scale.runtime.orchestrator.process_manager {
        ServiceDeployer
    }
}

impl import jaclang.scale.deploy.target.kubernetes {
    cluster_provider --> jaclang.scale.deploy.target.kubernetes.ingress {
        ClusterProvider
    }
    cluster_provider --> jaclang.scale.deploy.target.kubernetes.monitoring {
        ClusterProvider
    }
    cluster_provider --> jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
        AWSProvider,
        ClusterProvider,
        LocalProvider
    }
    cluster_provider --> jaclang.scale.tests.deploy.test_cluster_provider {
        AWSProvider,
        LocalProvider
    }
    database_provisioner --> jaclang.scale.deploy.target.kubernetes.target {
        DatabaseProvisioner
    }
    database_provisioner --> jaclang.scale.tests.deploy.test_pod_env {
        DatabaseProvisioner
    }
    ingress --> jaclang.scale.deploy.target.kubernetes.kubernetes_target {
        IngressDeployer
    }
    ingress --> jaclang.scale.tests.deploy.test_deploy_k8s { IngressDeployer }
    ingress --> jaclang.scale.tests.deploy.test_ingress_deployer { IngressDeployer }
    ingress --> jaclang.scale.tests.deploy.test_ingress_tls_preservation {
        IngressDeployer
    }
    kubernetes_config --> jaclang.scale.config.config_loader.JacScaleConfig.get_kubernetes_config {
        KubernetesConfig,
        k8s_safe_slug
    }
    kubernetes_config --> jaclang.scale.deploy.database.kubernetes_postgres.KubernetesPostgresProvider._requested_mode {
        resolve_database_mode
    }
    kubernetes_config --> jaclang.scale.deploy.target.factory.DeploymentTargetFactory.create {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.deploy.target.kubernetes.ingress {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.deploy.target.kubernetes.kubernetes_target {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.deploy.target.kubernetes.manifest_builder {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.deploy.target.kubernetes.monitoring {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.deploy.target.kubernetes.target {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.sdk.client { KubernetesConfig }
    kubernetes_config --> jaclang.scale.sdk.spec.DeploySpec.from_config {
        k8s_safe_slug
    }
    kubernetes_config --> jaclang.scale.sdk.spec.DeploySpec.to_target_config {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.apps.test_app_scale_overrides {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_access_hint {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_alb_zero_downtime {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_client_build_deps {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_client_build_fail_fast {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_client_build_stage {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_crash_scan_fleet_guard {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_database_intent {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_deploy_k8s {
        KubernetesConfig,
        k8s_safe_slug
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_deployment_overlay {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_destroy_reclaim {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_dry_run_purity {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_factories { KubernetesConfig }
    kubernetes_config --> jaclang.scale.tests.deploy.test_gateway_config_isolation {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_ingress_deployer {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_ingress_tls_preservation {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_memory_trigger_guard {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_monitoring_switch {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_pdb_budget {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_pod_env { KubernetesConfig }
    kubernetes_config --> jaclang.scale.tests.deploy.test_service_routing {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_show_yaml_autoscalers {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_superseded_deployment_reap {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.deploy.test_version_pin {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.microservices.test_binary_injector {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.microservices.test_fleet_rollout {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.misc.test_config_loader {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.misc.test_config_validation {
        KubernetesConfig
    }
    kubernetes_config --> jaclang.scale.tests.misc.test_k8s_config_tracing {
        KubernetesConfig
    }
    kubernetes_target --> jaclang.scale.deploy.target.kubernetes.target {
        KubernetesTargetBase
    }
    kubernetes_target --> jaclang.scale.runtime.realizer.kubernetes_realizer.KubernetesRealizer.realize {
        KubernetesTargetBase
    }
    kubernetes_target --> jaclang.scale.tests.deploy.test_database_intent {
        KubernetesTargetBase
    }
    manifest_builder --> jaclang.scale.deploy.autoscale.autoscaler.Autoscaler._build_behavior {
        merge_manifest_overlay
    }
    manifest_builder --> jaclang.scale.deploy.target.kubernetes.target {
        CONFIG_REVISION_ANNOTATION,
        ManifestBuilder,
        ScalingMode,
        with_config_revision
    }
    manifest_builder --> jaclang.scale.runtime.cli.diagnostics { ScalingMode }
    manifest_builder --> jaclang.scale.runtime.cli.plan { ScalingMode }
    manifest_builder --> jaclang.scale.tests.apps.test_app_scale_overrides {
        ManifestBuilder
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_access_hint { ManifestBuilder }
    manifest_builder --> jaclang.scale.tests.deploy.test_alb_zero_downtime {
        ManifestBuilder
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_client_build_deps {
        ManifestBuilder
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_client_build_fail_fast {
        ManifestBuilder
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_client_build_stage {
        ManifestBuilder,
        _CLIENT_BUILD_ATTEMPTS,
        _CLIENT_BUILD_RETRY_PAUSE_S,
        _is_transient_client_build_failure,
        _membership_diagnosis
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_deployment_overlay {
        CONFIG_REVISION_ANNOTATION,
        ManifestBuilder,
        merge_manifest_overlay,
        with_config_revision
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_dry_run_purity {
        ManifestBuilder
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_gateway_config_isolation {
        ManifestBuilder
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        ManifestBuilder,
        ScalingMode
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_memory_trigger_guard {
        ManifestBuilder
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_pdb_budget {
        ManifestBuilder,
        ScalingMode,
        pdb_spec
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_pod_env {
        CONFIG_REVISION_ANNOTATION,
        ManifestBuilder,
        with_config_revision
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_service_routing {
        ManifestBuilder
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_show_yaml_autoscalers {
        ManifestBuilder,
        ScalingMode
    }
    manifest_builder --> jaclang.scale.tests.deploy.test_superseded_deployment_reap {
        ManifestBuilder
    }
    monitoring --> jaclang.scale.deploy.target.kubernetes.target { MonitoringDeployer }
    ops_rbac --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder.generate_manifests {
        build_ops_rbac
    }
    ops_rbac --> jaclang.scale.tests.deploy.test_ops_rbac {
        build_ops_rbac,
        ops_role_name
    }
    runtime_bootstrap --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_pod_spec {
        build_bootstrap_init_container,
        image_pull_policy,
        runtime_container_env
    }
    runtime_bootstrap --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._pod_entrypoint {
        build_service_apt_prefix
    }
    runtime_bootstrap --> jaclang.scale.tests.microservices.test_binary_injector {
        build_bootstrap_init_container,
        build_runtime_install_commands,
        build_service_apt_prefix,
        image_pull_policy,
        runtime_container_env
    }
    runtime_resolver --> jaclang.scale.runtime.provider.JacScaleRuntime.get_sv_service_routes {
        build_k8s_registry_routes
    }
    runtime_resolver as resolver_mod --> jaclang.scale.tests.deploy.test_pod_env;
    runtime_resolver --> jaclang.scale.tests.deploy.test_pod_env {
        K8sRuntimeServiceResolver,
        build_k8s_registry,
        resolve_peer_route
    }
    runtime_resolver --> jaclang.scale.tests.deploy.test_service_routing {
        build_k8s_registry_routes
    }
    target --> jaclang.scale.deploy.target.factory.DeploymentTargetFactory.create {
        KubernetesTarget
    }
    target --> jaclang.scale.runtime.realizer.kubernetes_realizer.KubernetesRealizer.realize {
        KubernetesTarget
    }
    target --> jaclang.scale.sdk.client { KubernetesTarget }
    target --> jaclang.scale.tests.deploy.test_access_hint { KubernetesTarget }
    target --> jaclang.scale.tests.deploy.test_alb_zero_downtime { KubernetesTarget }
    target --> jaclang.scale.tests.deploy.test_crash_scan_fleet_guard {
        KubernetesTarget
    }
    target --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        KubernetesTarget,
        apply_http_activations_for_bundle,
        reap_stale_scaling_resources_for_bundle
    }
    target --> jaclang.scale.tests.deploy.test_memory_trigger_guard { KubernetesTarget }
    target --> jaclang.scale.tests.deploy.test_monitoring_switch { KubernetesTarget }
    target --> jaclang.scale.tests.deploy.test_pod_env { KubernetesTarget }
    target --> jaclang.scale.tests.deploy.test_show_yaml_autoscalers {
        KubernetesTarget
    }
    target as target_mod --> jaclang.scale.tests.deploy.test_superseded_deployment_reap;
    target --> jaclang.scale.tests.deploy.test_superseded_deployment_reap {
        KubernetesTarget,
        app_bundle_digest,
        fleet_revert_order,
        fleet_targets_for_release,
        releases_from_revisions,
        restorable_pod_template
    }
    target --> jaclang.scale.tests.deploy.test_version_pin { KubernetesTarget }
    target --> jaclang.scale.tests.microservices.test_fleet_rollout { KubernetesTarget }
}

impl import jaclang.scale.deploy.target.kubernetes.utils {
    kubernetes_utils --> jaclang.scale.deploy.autoscale.hpa_autoscaler {
        delete_if_exists
    }
    kubernetes_utils --> jaclang.scale.deploy.target.kubernetes.database_provisioner {
        ensure_namespace_exists
    }
    kubernetes_utils --> jaclang.scale.deploy.target.kubernetes.ingress {
        delete_if_exists
    }
    kubernetes_utils --> jaclang.scale.deploy.target.kubernetes.kubernetes_target {
        COMPANION_DEFS,
        create_k8s_secret,
        get_cluster_provider,
        resize_pvc_if_needed
    }
    kubernetes_utils --> jaclang.scale.deploy.target.kubernetes.monitoring {
        delete_if_exists,
        delete_k8s_secret
    }
    kubernetes_utils --> jaclang.scale.deploy.target.kubernetes.target {
        PSS_ENFORCE_LABEL,
        _refresh_rs_hashes,
        _resolve_current_rs_hashes,
        create_k8s_secret,
        delete_if_exists,
        delete_k8s_secret,
        delete_namespace,
        ensure_namespace_exists,
        get_cluster_provider,
        namespace_is_owned,
        privileged_pss_labels
    }
    kubernetes_utils --> jaclang.scale.deploy.target.kubernetes.target.KubernetesTarget._pod_failure_detail {
        describe_pod_status
    }
    kubernetes_utils --> jaclang.scale.injector.pvc_injector.PvcInjector.seed {
        run_kubectl_command,
        wait_for_pod_deletion,
        wait_for_pod_phase
    }
    kubernetes_utils --> jaclang.scale.tests.deploy.test_cluster_provider {
        get_cluster_provider
    }
    kubernetes_utils --> jaclang.scale.tests.deploy.test_k8s_utils {
        parse_storage_quantity,
        resize_pvc_if_needed
    }
    kubernetes_utils --> jaclang.scale.tests.deploy.test_pod_env { create_k8s_secret }
    kubernetes_utils --> jaclang.scale.tests.deploy.test_pss_labels {
        PSS_ENFORCE_LABEL,
        PSS_SOURCE_LABEL,
        PSS_WARN_LABEL,
        default_pss_labels,
        privileged_pss_labels
    }
}

impl import jaclang.scale.emailer {
    emailer --> jaclang.scale.emailer.emailers { Emailer }
    emailer --> jaclang.scale.emailer.factory { Emailer }
    emailer --> jaclang.scale.server.extensions { Emailer }
    emailer --> jaclang.scale.tests.server.test_emailer_factory { Emailer }
    emailers --> jaclang.scale.emailer.factory.create { SMTPEmailer }
    emailers --> jaclang.scale.tests.server.test_emailer_factory { SMTPEmailer }
    factory --> jaclang.scale.server.extensions.RecoveryMailExtension.register {
        create as create_emailer
    }
    factory --> jaclang.scale.tests.server.test_emailer_factory {
        create as create_emailer,
        register
    }
}

impl import jaclang.scale.events {
    broker --> jaclang.scale.config.config_loader.JacScaleConfig.get_events_config {
        RetryPolicy
    }
    broker --> jaclang.scale.events.publisher { Event, EventStreamBroker }
    broker --> jaclang.scale.events.streams._stream_common {
        Event,
        RetryPolicy,
        StreamPosition
    }
    broker --> jaclang.scale.events.streams.local {
        Event,
        EventStreamBroker,
        HealthStatus,
        RetryPolicy,
        StreamPosition,
        starts_at_earliest
    }
    broker --> jaclang.scale.events.streams.postgres {
        Event,
        EventStreamBroker,
        HealthStatus,
        RetryPolicy,
        StreamPosition,
        starts_at_earliest
    }
    broker --> jaclang.scale.events.subscriber { Event, RetryPolicy, StreamPosition }
    broker --> jaclang.scale.tests.data.test_local_stream { Event, RetryPolicy }
    broker --> jaclang.scale.tests.data.test_pg_stream { Event }
    broker --> jaclang.scale.tests.misc.test_events {
        Event,
        EventStreamBroker,
        HealthStatus,
        RetryPolicy,
        StreamPosition,
        starts_at_earliest
    }
    publisher --> jaclang.scale.server.extensions.EventsExtension.register {
        set_broker
    }
    publisher --> jaclang.scale.tests.misc.test_events { publish, set_broker }
    subscriber --> jaclang.scale.server.extensions.EventsExtension.register {
        get_subscriptions
    }
    subscriber --> jaclang.scale.tests.misc.test_events { get_subscriptions, subscribe }
}

impl import jaclang.scale.events.streams {
    _stream_common --> jaclang.scale.events.streams.local {
        consumer_loop,
        wait_or_stop
    }
    _stream_common --> jaclang.scale.tests.misc.test_events { consumer_loop }
    local --> jaclang.scale.server.extensions.EventsExtension.register {
        LocalEventStream
    }
    local --> jaclang.scale.tests.data.test_local_stream { LocalEventStream }
    local --> jaclang.scale.tests.misc.test_events { LocalEventStream }
    postgres --> jaclang.scale.runtime.provider { PgEventStream }
    postgres --> jaclang.scale.server.extensions.EventsExtension.register {
        PgEventStream
    }
    postgres --> jaclang.scale.tests.data.test_pg_stream {
        PgEventStream,
        _STREAM_SCHEMA
    }
    postgres --> jaclang.scale.tests.misc.test_events { PgEventStream }
}

impl import jaclang.scale.injector {
    binary --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_client_bundle {
        host_toolchain_path
    }
    binary --> jaclang.scale.deploy.target.kubernetes.runtime_bootstrap.build_bootstrap_init_container {
        OFFICIAL_IMAGE
    }
    binary --> jaclang.scale.deploy.target.kubernetes.runtime_bootstrap.image_pull_policy {
        OFFICIAL_IMAGE
    }
    binary --> jaclang.scale.deploy.target.kubernetes.target.KubernetesTarget.deploy {
        deploy_generation_refusal,
        node_arch,
        preflight_pod_runtime
    }
    binary --> jaclang.scale.deploy.target.kubernetes.target.KubernetesTarget.generate_manifests {
        resolve_pod_base_image
    }
    binary --> jaclang.scale.injector.binary_injector {
        download_release_binary,
        host_seal_platform,
        node_arch,
        pack_binary_bytes,
        resolve_console_version,
        resolve_deploy_version,
        stage_admin_dist,
        toolchain_object_key
    }
    binary --> jaclang.scale.runtime.realizer.kubernetes_realizer.KubernetesRealizer._deploy_on_pinned_jac {
        host_toolchain_path
    }
    binary --> jaclang.scale.runtime.realizer.kubernetes_realizer.KubernetesRealizer.realize {
        deploy_generation_refusal,
        reset_deploy_version_cache
    }
    binary --> jaclang.scale.sdk.client.ScaleClient.deploy {
        reset_deploy_version_cache
    }
    binary as binary_mod --> jaclang.scale.tests.deploy.test_client_build_fail_fast;
    binary as binary_mod --> jaclang.scale.tests.deploy.test_dry_run_purity;
    binary as binary_mod --> jaclang.scale.tests.deploy.test_memory_trigger_guard;
    binary as binary_mod --> jaclang.scale.tests.deploy.test_pod_env;
    binary as binary_mod --> jaclang.scale.tests.deploy.test_version_pin;
    binary --> jaclang.scale.tests.deploy.test_version_pin {
        _exact_of,
        _resolve_target_version
    }
    binary --> jaclang.scale.tests.microservices.test_admin_console_source {
        admin_dist_source,
        resolve_console_version,
        resolve_deploy_version,
        resolve_pinned_version
    }
    binary as binmod --> jaclang.scale.tests.microservices.test_binary_cache;
    binary as binary_mod --> jaclang.scale.tests.microservices.test_binary_injector;
    binary as binary --> jaclang.scale.tests.microservices.test_binary_injector;
    binary --> jaclang.scale.tests.microservices.test_binary_injector {
        cluster_node_archs,
        download_release_binary,
        node_arch,
        pack_binary_bytes,
        resolve_pod_base_image,
        stage_admin_dist
    }
    binary --> jaclang.scale.tests.microservices.test_seed_determinism {
        pack_binary_bytes
    }
    binary_injector --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_pod_spec {
        BinaryInjector
    }
    binary_injector --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._prepare_injector {
        select_injector
    }
    binary_injector as binary_injector_mod --> jaclang.scale.tests.deploy.test_dry_run_purity;
    binary_injector --> jaclang.scale.tests.deploy.test_dry_run_purity {
        BinaryInjector
    }
    binary_injector as bi_mod --> jaclang.scale.tests.microservices.test_binary_injector;
    binary_injector --> jaclang.scale.tests.microservices.test_binary_injector {
        BinaryInjector
    }
    bundle --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_client_bundle {
        _stage_app,
        release_binary_env,
        remove_stage_root,
        sanitized_jac_toml,
        source_filter_for
    }
    bundle --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_pod_spec {
        APP_MOUNT_PATH
    }
    bundle --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._bundle_files {
        resolve_fleet_entries
    }
    bundle --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._check_pod_config_resolves {
        nested_sanitized_tomls,
        sanitized_jac_toml,
        source_filter_for,
        unresolved_toml_references
    }
    bundle --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._pod_entrypoint {
        APP_MOUNT_PATH
    }
    bundle --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._project_config {
        _project_config
    }
    bundle --> jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
        APP_MOUNT_PATH,
        APP_VOLUME_NAME,
        JAC_HOME,
        TOOLCHAIN_SUBDIR
    }
    bundle --> jaclang.scale.injector.binary { TOOLCHAIN_SUBDIR }
    bundle --> jaclang.scale.injector.binary.pack_binary_bytes { open_det_tar }
    bundle --> jaclang.scale.injector.binary_injector {
        bundle_object_key,
        content_address
    }
    bundle --> jaclang.scale.injector.pvc_injector {
        APP_MOUNT_PATH,
        APP_VOLUME_NAME,
        bundle_object_key,
        content_address,
        ensure_jac_toml_cmd,
        pack_jab
    }
    bundle --> jaclang.scale.runtime.realizer.kubernetes_realizer.KubernetesRealizer._deploy_on_pinned_jac {
        release_binary_env
    }
    bundle --> jaclang.scale.tests.deploy.test_client_build_fail_fast {
        release_binary_env
    }
    bundle --> jaclang.scale.tests.deploy.test_client_build_stage {
        bundle_source_files,
        source_filter_for
    }
    bundle --> jaclang.scale.tests.deploy.test_pod_env._entrypoint_run {
        APP_MOUNT_PATH
    }
    bundle --> jaclang.scale.tests.microservices.test_app_precompile {
        DEFAULT_SEAL_TIMEOUT_S,
        PLACEHOLDER_JAC_TOML,
        _stage_app,
        nested_sanitized_tomls,
        pack_jab,
        reap_stale_stage_roots,
        sanitized_jac_toml,
        seal_step_env,
        seal_timeout_setting,
        stage_roots_in_use
    }
    bundle --> jaclang.scale.tests.microservices.test_binary_injector {
        TOOLCHAIN_SUBDIR
    }
    bundle --> jaclang.scale.tests.microservices.test_bundle_jacignore {
        _stage_app,
        add_source_members,
        bundle_source_files,
        content_address,
        nested_sanitized_tomls,
        open_det_tar,
        pack_jab,
        partition_bundle_sources,
        sanitized_jac_toml
    }
    bundle as bundle --> jaclang.scale.tests.microservices.test_fat_bundle;
    bundle --> jaclang.scale.tests.microservices.test_fat_bundle {
        _strip_external_record_lines,
        content_address,
        fat_bundle_enabled,
        fat_bundle_setting,
        pack_jab,
        staged_venv_files
    }
    bundle --> jaclang.scale.tests.microservices.test_pvc_injector {
        pack_jab,
        sanitized_jac_toml
    }
    bundle --> jaclang.scale.tests.microservices.test_seed_determinism {
        content_address,
        pack_jab
    }
    injector --> jaclang.scale.injector.pvc_injector { Injector }
    pvc_injector --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_pod_spec {
        VOLUME_PERMS_NAME,
        build_volume_perms_init_container,
        runtime_pod_security_context
    }
    pvc_injector --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._prepare_injector {
        PvcInjector
    }
    pvc_injector --> jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
        BUNDLE_MOUNT_PATH,
        BUNDLE_VOLUME_NAME
    }
    pvc_injector --> jaclang.scale.deploy.target.kubernetes.target {
        bundle_keys_from_pod_spec,
        bundle_pvc_name
    }
    pvc_injector --> jaclang.scale.injector.binary_injector {
        PvcInjector,
        bundle_pvc_path
    }
    pvc_injector --> jaclang.scale.tests.deploy.test_destroy_reclaim { bundle_pvc_name }
    pvc_injector --> jaclang.scale.tests.deploy.test_pod_env {
        RUNTIME_GID,
        RUNTIME_UID,
        VOLUME_PERMS_NAME
    }
    pvc_injector --> jaclang.scale.tests.microservices.test_binary_injector {
        BUNDLE_MOUNT_PATH,
        BUNDLE_VOLUME_NAME
    }
    pvc_injector --> jaclang.scale.tests.microservices.test_pvc_injector {
        BUNDLE_MOUNT_PATH,
        PvcInjector,
        RUNTIME_GID,
        RUNTIME_UID,
        build_bundle_pvc,
        build_loader_pod,
        build_pvc_init_container,
        bundle_keys_from_pod_spec
    }
}

impl import jaclang.scale.memory {
    context --> jaclang.scale.runtime.provider.JacScaleRuntime.create_j_context {
        JScaleExecutionContext
    }
    context --> jaclang.scale.scheduler.scheduler.JacScaleScheduler._execute_task._run {
        JScaleExecutionContext
    }
}

impl import jaclang.scale.models {
    deploy_context --> jaclang.scale.deploy.target.kubernetes.database_provisioner {
        DeployContext
    }
    deploy_context --> jaclang.scale.deploy.target.kubernetes.kubernetes_target {
        DATABASE_URL_ENV
    }
    deploy_context --> jaclang.scale.deploy.target.kubernetes.manifest_builder {
        DATABASE_URL_ENV,
        DeployContext
    }
    deploy_context --> jaclang.scale.deploy.target.kubernetes.target { DeployContext }
    deployment_result --> jaclang.scale.deploy.target.deployment_target {
        DeploymentResult
    }
    deployment_result --> jaclang.scale.deploy.target.kubernetes.target {
        DeploymentResult
    }
    deployment_result --> jaclang.scale.sdk { DeploymentResult }
    deployment_result --> jaclang.scale.sdk.client { DeploymentResult }
    deployment_result --> jaclang.scale.tests.deploy.test_deploy_k8s {
        DeploymentResult
    }
    progress --> jaclang.scale.deploy.target.kubernetes.kubernetes_target {
        EventSink,
        NoopSink,
        ProgressEvent
    }
    progress --> jaclang.scale.sdk { CallbackSink, EventSink, ProgressEvent }
    progress --> jaclang.scale.sdk.client {
        CallbackSink,
        EventSink,
        NoopSink,
        ProgressEvent
    }
    progress --> jaclang.scale.sdk.events { EventSink, ProgressEvent }
    resource_status --> jaclang.scale.admin.deploy_health { assess_workload }
    resource_status --> jaclang.scale.deploy.autoscale.autoscaler {
        ResourceStatus,
        ResourceStatusInfo,
        assess_workload,
        field_of
    }
    resource_status --> jaclang.scale.deploy.autoscale.hpa_autoscaler { ResourceStatus }
    resource_status --> jaclang.scale.deploy.autoscale.keda_autoscaler {
        ResourceStatus
    }
    resource_status --> jaclang.scale.deploy.target.deployment_target {
        ResourceStatusInfo
    }
    resource_status --> jaclang.scale.deploy.target.kubernetes.kubernetes_target {
        ResourceStatus,
        ResourceStatusInfo,
        assess_workload
    }
    resource_status --> jaclang.scale.deploy.target.kubernetes.manifest_builder {
        REPLICA_FLOOR_ANNOTATION
    }
    resource_status --> jaclang.scale.deploy.target.kubernetes.target {
        ResourceStatus,
        assess_workload
    }
    resource_status --> jaclang.scale.sdk { ResourceStatus, ResourceStatusInfo }
    resource_status --> jaclang.scale.sdk.client { ResourceStatusInfo }
    resource_status --> jaclang.scale.tests.deploy.test_deploy_k8s { ResourceStatus }
    resource_status --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        REPLICA_FLOOR_ANNOTATION,
        ResourceStatus
    }
    resource_status --> jaclang.scale.tests.deploy.test_ops_deploy {
        REPLICA_FLOOR_ANNOTATION
    }
    resource_status --> jaclang.scale.tests.deploy.test_superseded_deployment_reap {
        REPLICA_FLOOR_ANNOTATION,
        assess_workload
    }
    resource_status --> jaclang.scale.tests.microservices.test_fleet_rollout {
        REPLICA_FLOOR_ANNOTATION
    }
}

impl import jaclang.scale.observability {
    factory --> jaclang.scale.plugin { UtilityFactory }
    factory --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        UtilityFactory
    }
    factory --> jaclang.scale.runtime.realizer.kubernetes_realizer { UtilityFactory }
    factory --> jaclang.scale.sdk.client.ScaleClient._pick_logger { UtilityFactory }
    factory --> jaclang.scale.server.extensions.MetricsExtension.register {
        UtilityFactory
    }
    factory --> jaclang.scale.tests.deploy.test_deploy_k8s { UtilityFactory }
    factory --> jaclang.scale.tests.deploy.test_factories { UtilityFactory }
    factory --> jaclang.scale.tests.misc.test_metrics { UtilityFactory }
    factory --> jaclang.scale.tests.misc.test_optional_deps { UtilityFactory }
    logger --> jaclang.scale.deploy.autoscale.factory { Logger }
    logger --> jaclang.scale.deploy.autoscale.hpa_autoscaler { Logger }
    logger --> jaclang.scale.deploy.autoscale.keda_autoscaler { Logger }
    logger --> jaclang.scale.deploy.target.deployment_target { Logger }
    logger --> jaclang.scale.deploy.target.factory { Logger }
    logger --> jaclang.scale.deploy.target.kubernetes.cluster_provider { Logger }
    logger --> jaclang.scale.deploy.target.kubernetes.ingress { Logger }
    logger --> jaclang.scale.deploy.target.kubernetes.kubernetes_target { Logger }
    logger --> jaclang.scale.deploy.target.kubernetes.monitoring { Logger }
    type logger --> jaclang.scale.deploy.target.registry { Logger }
    logger --> jaclang.scale.observability.factory { Logger }
    logger --> jaclang.scale.observability.standard_logger { Logger }
    logger --> jaclang.scale.sdk.client { Logger }
    logger --> jaclang.scale.sdk.events { Logger }
    metrics --> jaclang.scale.admin.admin_portal { MetricsCollector }
    metrics --> jaclang.scale.observability.factory {
        MetricsCollector,
        NoOpMetricsCollector
    }
    metrics --> jaclang.scale.observability.prometheus_metrics { MetricsCollector }
    metrics --> jaclang.scale.server.extensions { MetricsCollector }
    metrics --> jaclang.scale.tests.misc.test_metrics { NoOpMetricsCollector }
    metrics --> jaclang.scale.tests.misc.test_optional_deps { NoOpMetricsCollector }
    prometheus_client --> jaclang.scale.admin.workloads {
        query as prom_query,
        query_range as prom_query_range,
        resolve_prometheus_url,
        scalar as prom_scalar
    }
    prometheus_client --> jaclang.scale.observability.prometheus_metrics.PrometheusMetricsCollector.__post_init__ {
        GCCollector,
        PlatformCollector,
        ProcessCollector
    }
    prometheus_client --> jaclang.scale.observability.prometheus_metrics.PrometheusMetricsCollector._scrape_registry {
        multiprocess
    }
    prometheus_client --> jaclang.scale.observability.prometheus_metrics._merges_across_workers {
        values
    }
    prometheus_metrics --> jaclang.scale.observability.factory.UtilityFactory.create_metrics {
        PrometheusMetricsCollector
    }
    prometheus_metrics --> jaclang.scale.tests.misc.test_metrics {
        PrometheusMetricsCollector
    }
    prometheus_metrics --> jaclang.scale.tests.misc.test_optional_deps {
        PrometheusMetricsCollector
    }
    standard_logger --> jaclang.scale.observability.factory.UtilityFactory.create_logger {
        StandardLogger
    }
    standard_logger --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        StandardLogger
    }
}

impl import jaclang.scale.runtime {
    fleet --> jaclang.scale.admin.logs._fleet_names { fleet_member_names }
    fleet --> jaclang.scale.admin.traces._trace_services { fleet_member_names }
    fleet --> jaclang.scale.deploy.target.kubernetes.manifest_builder {
        FleetSpec,
        fleet_from_config,
        solo_fleet
    }
    fleet --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_env {
        FLEET_ENV
    }
    fleet --> jaclang.scale.deploy.target.kubernetes.target { FleetSpec }
    fleet --> jaclang.scale.injector.bundle { FleetSpec }
    fleet --> jaclang.scale.plugin._print_local_fleet_banner { format_fleet_lines }
    fleet --> jaclang.scale.plugin.scale_cmd { fleet_from_config, fleet_from_env }
    fleet --> jaclang.scale.plugin.scale_local_serve { fleet_from_plans }
    fleet --> jaclang.scale.runtime.cli.plan { FleetSpec }
    fleet --> jaclang.scale.runtime.orchestrator.orchestrator { FleetSpec, ROOT_PREFIX }
    fleet --> jaclang.scale.runtime.provider.JacScaleRuntime.get_sv_service_routes {
        fleet_from_env
    }
    fleet --> jaclang.scale.runtime.realizer.kubernetes_realizer {
        FleetSpec,
        fleet_from_config,
        format_fleet_lines
    }
    fleet --> jaclang.scale.runtime.realizer.local_realizer { FleetSpec }
    fleet --> jaclang.scale.tests.apps.test_app_scale_overrides { fleet_from_config }
    fleet --> jaclang.scale.tests.apps.test_fleet_from_apps {
        FLEET_ENV,
        FleetSpec,
        ROOT_PREFIX,
        _compiled_app_edges,
        consumer_provider_edges,
        fleet_from_config,
        fleet_from_env,
        fleet_of,
        guard_fleet_routes,
        order_by_edges,
        solo_fleet
    }
    fleet --> jaclang.scale.tests.deploy.test_access_hint { fleet_of }
    fleet --> jaclang.scale.tests.deploy.test_client_build_stage {
        FleetMember,
        FleetSpec
    }
    fleet --> jaclang.scale.tests.deploy.test_deploy_banner { fleet_of }
    fleet --> jaclang.scale.tests.deploy.test_deployment_overlay { fleet_of }
    fleet --> jaclang.scale.tests.deploy.test_dry_run_purity { fleet_of }
    fleet --> jaclang.scale.tests.deploy.test_http_activation_microservices { fleet_of }
    fleet --> jaclang.scale.tests.deploy.test_memory_trigger_guard { fleet_of }
    fleet --> jaclang.scale.tests.deploy.test_pdb_budget { fleet_of }
    fleet --> jaclang.scale.tests.deploy.test_pod_env { FLEET_ENV, fleet_of }
    fleet --> jaclang.scale.tests.deploy.test_show_yaml_autoscalers { fleet_of }
    fleet --> jaclang.scale.tests.microservices.test_app_precompile {
        fleet_from_config
    }
    provider --> jaclang.cli.commands.execution.serve { mark_scale_runtime }
    provider --> jaclang.runtime.runtime._scale_provider { JacScaleRuntime }
    provider --> jaclang.runtime.source_app.main { mark_scale_runtime }
    provider --> jaclang.scale.plugin { mark_scale_runtime }
    provider --> jaclang.scale.runtime.orchestrator.orchestrator._populate_k8s_urls {
        JacScaleRuntime
    }
    provider --> jaclang.scale.runtime.rpc.rpc._resolve_call_target { JacScaleRuntime }
    provider --> jaclang.scale.server.inprocess.prepare_inprocess_runtime {
        mark_scale_runtime
    }
    provider as provider_mod --> jaclang.scale.tests.server.test_sv_auth_forward;
    provider --> jaclang.scale.tests.server.test_sv_auth_forward { JacScaleRuntime }
    provider --> jaclang.scale.tests.server.test_sv_streaming { JacScaleRuntime }
    routing --> jaclang.scale.admin.admin_portal._classify_path {
        GATEWAY_WELLKNOWN_SEGMENTS
    }
    routing --> jaclang.scale.runtime.fleet { guard_route_prefix }
    routing --> jaclang.scale.runtime.gateway.dispatch {
        GATEWAY_API_SEGMENTS,
        GATEWAY_LISTING_SEGMENTS,
        GATEWAY_PAGE_SEGMENTS,
        GATEWAY_WELLKNOWN_SEGMENTS
    }
    routing --> jaclang.scale.runtime.gateway.microservice_gateway {
        GATEWAY_BARE_API_PATHS,
        GATEWAY_BUILTIN_PREFIXES,
        GATEWAY_DISCOVERY_SEGMENTS,
        GATEWAY_REPLICATED_SEGMENTS
    }
    routing --> jaclang.scale.runtime.gateway.route_table.ServiceRouteTable.learn {
        is_learnable_prefix
    }
    routing --> jaclang.scale.tests.microservices.test_routing_guard {
        GATEWAY_API_SEGMENTS,
        GATEWAY_BUILTIN_PREFIXES,
        GATEWAY_CLIENT_SEGMENT,
        GATEWAY_DISCOVERY_SEGMENTS,
        GATEWAY_LISTING_SEGMENTS,
        GATEWAY_REPLICATED_SEGMENTS,
        GATEWAY_SERVICE_OWNED_SEGMENTS,
        GATEWAY_WELLKNOWN_SEGMENTS,
        guard_route_prefix,
        is_gateway_owned_segment,
        is_learnable_prefix
    }
}

impl import jaclang.scale.runtime.cli {
    _narrow --> jaclang.scale.runtime.cli.diagnostics {
        bget,
        dget,
        effective_resources,
        iget,
        lget,
        pod_spec,
        sget
    }
    _narrow --> jaclang.scale.runtime.cli.plan {
        dget,
        fget,
        iget,
        lget,
        pod_spec,
        sget
    }
    diagnostics --> jaclang.scale.runtime.cli.plan {
        Diagnostic,
        PlanValidator,
        has_errors
    }
    diagnostics --> jaclang.scale.runtime.realizer.kubernetes_realizer.KubernetesRealizer.realize {
        has_errors
    }
    diagnostics --> jaclang.scale.tests.deploy.test_pdb_budget { PlanValidator }
    plan --> jaclang.scale.runtime.realizer.kubernetes_realizer.KubernetesRealizer.realize {
        print_plan
    }
}

impl import jaclang.scale.runtime.context {
    auth_ctx --> jaclang.scale.runtime.rpc.rpc._rpc_headers { get_current_auth }
    auth_ctx --> jaclang.scale.server.extensions.ObservabilityExtension.register {
        reset_current_auth,
        set_current_auth
    }
    auth_ctx --> jaclang.scale.tests.server.test_sv_auth_forward {
        get_current_auth,
        reset_current_auth,
        set_current_auth
    }
    errors --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.deliver_once {
        not_found
    }
    errors --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.forward_root_path {
        service_unavailable
    }
    errors --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.forward_to {
        gateway_timeout,
        service_unavailable
    }
    errors --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.forward_to_root {
        service_unavailable
    }
    errors --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.handle_builtin_passthrough {
        not_found
    }
    errors --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.handle_metrics {
        error_response
    }
    errors --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.probe_services {
        not_found,
        service_unavailable
    }
    errors --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup.dispatcher {
        not_found
    }
    errors --> jaclang.scale.runtime.middleware.rate_limit.build_rate_limit_middleware {
        error_response
    }
    log_emit --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        install_structured_logging
    }
    log_emit --> jaclang.scale.server.extensions.ObservabilityExtension.register {
        install_structured_logging
    }
    log_emit --> jaclang.scale.tests.misc.test_log_emit {
        _JacJsonFormatter,
        emit_log_record,
        install_structured_logging
    }
    service_routing --> jaclang.scale.config.plugin_config {
        KEDA_INTERCEPTOR_SERVICE_ADDRESS
    }
    service_routing --> jaclang.scale.deploy.autoscale.factory.AutoscalerFactory.create {
        resolve_interceptor_service_address
    }
    service_routing --> jaclang.scale.deploy.autoscale.http_activation_config.build_http_activation_spec {
        k8s_service_dns_host
    }
    service_routing --> jaclang.scale.deploy.autoscale.keda_autoscaler {
        KEDA_INTERCEPTOR_SERVICE_ADDRESS
    }
    service_routing --> jaclang.scale.deploy.target.kubernetes.manifest_builder {
        resolve_http_activation_config
    }
    service_routing --> jaclang.scale.deploy.target.kubernetes.runtime_resolver {
        ServiceRoute,
        resolve_service_route
    }
    service_routing --> jaclang.scale.deploy.target.kubernetes.target {
        resolve_interceptor_service_address
    }
    service_routing --> jaclang.scale.tests.deploy.test_service_routing {
        KEDA_INTERCEPTOR_SERVICE_ADDRESS,
        ServiceRoute,
        k8s_service_dns_host,
        resolve_http_activation_config,
        resolve_interceptor_service_address,
        resolve_service_route
    }
    service_routing --> jaclang.scale.tests.server.test_sv_auth_forward { ServiceRoute }
    trace_ctx --> jaclang.scale.runtime.context.errors.error_response {
        get_current_trace
    }
    trace_ctx --> jaclang.scale.runtime.context.log_emit.install_structured_logging {
        install_trace_log_filter
    }
    trace_ctx --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.build_forward_headers {
        ensure_trace_id,
        get_current_trace
    }
    trace_ctx --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        ensure_trace_id,
        reset_current_trace,
        set_current_trace
    }
    trace_ctx --> jaclang.scale.runtime.rpc.rpc._rpc_headers { get_current_trace }
    trace_ctx --> jaclang.scale.server.extensions.ObservabilityExtension.register {
        ensure_trace_id,
        reset_current_trace,
        set_current_trace
    }
    trace_ctx --> jaclang.scale.tests.misc.test_log_emit {
        TraceIdLogFilter,
        install_trace_log_filter,
        reset_current_trace,
        set_current_trace
    }
    trace_ctx --> jaclang.scale.tests.server.test_sv_auth_forward {
        ensure_trace_id,
        get_current_trace,
        reset_current_trace,
        set_current_trace
    }
    tracing --> jaclang.scale.admin.ops { tracing_active }
    tracing --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.build_forward_headers {
        current_traceparent
    }
    tracing --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        end_span,
        install_tracing,
        start_server_span
    }
    tracing --> jaclang.scale.runtime.rpc.rpc._rpc_headers { current_traceparent }
    tracing --> jaclang.scale.server.extensions.ObservabilityExtension.register {
        end_span,
        install_tracing,
        start_server_span,
        tracing_installed
    }
    tracing --> jaclang.scale.tests.misc.test_tracing {
        build_traceparent,
        current_traceparent,
        end_memory_span,
        end_span,
        install_tracing,
        new_span_id,
        parse_traceparent,
        start_memory_span,
        start_server_span,
        trace_id_hex,
        tracing_active,
        uuid_to_trace_id
    }
    util --> jaclang.scale.admin.k8s_ops { in_cluster_namespace }
    util --> jaclang.scale.deploy.target.kubernetes.database_provisioner {
        k8s_safe_name
    }
    util --> jaclang.scale.deploy.target.kubernetes.manifest_builder {
        GATEWAY_NAME,
        k8s_safe_name
    }
    util --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_client_bundle {
        jac_executable
    }
    util --> jaclang.scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._peer_dns_url {
        k8s_service_dns_url
    }
    util --> jaclang.scale.deploy.target.kubernetes.runtime_resolver {
        DEFAULT_GATEWAY_PORT
    }
    util --> jaclang.scale.deploy.target.kubernetes.runtime_resolver.build_k8s_registry_routes {
        in_cluster_namespace
    }
    util --> jaclang.scale.deploy.target.kubernetes.target {
        GATEWAY_NAME,
        k8s_safe_name
    }
    util --> jaclang.scale.runtime.cli.diagnostics { GATEWAY_NAME }
    util --> jaclang.scale.runtime.cli.plan { GATEWAY_NAME }
    util --> jaclang.scale.runtime.context.service_routing {
        k8s_safe_name,
        k8s_service_dns_host
    }
    util --> jaclang.scale.runtime.gateway.embedded_gateway {
        DEFAULT_CLIENT_DIST_DIR,
        DEFAULT_GATEWAY_HOST,
        DEFAULT_GATEWAY_PORT
    }
    util --> jaclang.scale.runtime.gateway.microservice_gateway {
        DEFAULT_CLIENT_DIST_DIR,
        DEFAULT_GATEWAY_HOST,
        DEFAULT_GATEWAY_PORT
    }
    util --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.aggregate_graph_data {
        http_forward_timeout
    }
    util --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.forward_to {
        http_forward_timeout
    }
    util --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.probe_services {
        http_forward_timeout
    }
    util --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.refresh_app_routes {
        route_refresh_seconds
    }
    util --> jaclang.scale.runtime.gateway.process_gateway {
        DEFAULT_CLIENT_DIST_DIR,
        DEFAULT_GATEWAY_HOST,
        DEFAULT_GATEWAY_PORT
    }
    util --> jaclang.scale.runtime.orchestrator.orchestrator {
        DEFAULT_GATEWAY_HOST,
        DEFAULT_GATEWAY_PORT
    }
    util --> jaclang.scale.runtime.orchestrator.process_manager.ServiceProcessManager._assign_free_port {
        pick_free_port
    }
    util --> jaclang.scale.runtime.orchestrator.process_manager.ServiceProcessManager._assign_port {
        pick_free_port
    }
    util --> jaclang.scale.runtime.orchestrator.process_manager.ServiceProcessManager._await_lead {
        wait_for_health
    }
    util --> jaclang.scale.runtime.orchestrator.process_manager.ServiceProcessManager.start_service {
        jac_executable
    }
    util --> jaclang.scale.sdk.client { k8s_safe_name }
    util --> jaclang.scale.tests.apps.test_app_scale_overrides {
        boot_health_timeout,
        http_forward_timeout
    }
    util --> jaclang.scale.tests.deploy.test_client_build_deps { jac_executable }
    util --> jaclang.scale.tests.deploy.test_client_build_fail_fast { jac_executable }
    util --> jaclang.scale.tests.deploy.test_client_build_stage { jac_executable }
    util --> jaclang.scale.tests.deploy.test_dry_run_plan_rate_limit { jac_executable }
    util --> jaclang.scale.tests.deploy.test_gateway_config_isolation {
        GATEWAY_NAME,
        k8s_safe_name
    }
    util --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        GATEWAY_NAME
    }
    util --> jaclang.scale.tests.deploy.test_memory_trigger_guard { GATEWAY_NAME }
    util --> jaclang.scale.tests.deploy.test_pod_env { GATEWAY_NAME }
    util --> jaclang.scale.tests.microservices.test_gateway { http_forward_timeout }
    util --> jaclang.scale.tests.microservices.test_k8s_health_probe { jac_executable }
    util --> jaclang.scale.tests.server.test_acl_field_write._prewarm { jac_executable }
    util --> jaclang.scale.tests.server.test_admin { jac_executable }
    util --> jaclang.scale.tests.server.test_app_tokens._prewarm { jac_executable }
    util --> jaclang.scale.tests.server.test_examples.JacScaleTestRunner.start_server {
        jac_executable
    }
    util --> jaclang.scale.tests.server.test_metrics_workers { jac_executable }
    util --> jaclang.scale.tests.server.test_metrics_workers._serve_exported {
        jac_executable
    }
    util --> jaclang.scale.tests.server.test_root_bind_fail_closed._prewarm {
        jac_executable
    }
    util --> jaclang.scale.tests.server.test_serve { jac_executable }
    util --> jaclang.scale.tests.support.start_server { jac_executable }
}

impl import jaclang.scale.runtime.gateway {
    dispatch --> jaclang.scale.runtime.gateway.embedded_gateway {
        ROUTE_PROXY,
        ROUTE_STATIC,
        classify_route
    }
    dispatch --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup.dispatcher {
        ROUTE_ADMIN,
        ROUTE_BUILTIN,
        ROUTE_CLIENT_PAGE,
        ROUTE_IDENTITY,
        ROUTE_PROXY,
        classify_route
    }
    dispatch --> jaclang.scale.tests.apps.test_fleet_from_apps {
        ROUTE_PROXY,
        classify_route
    }
    dispatch --> jaclang.scale.tests.microservices.test_dispatch {
        ROUTE_ADMIN,
        ROUTE_PROXY,
        ROUTE_STATIC,
        classify_route
    }
    dispatch --> jaclang.scale.tests.microservices.test_gateway_docs_precedence {
        ROUTE_BUILTIN,
        ROUTE_CLIENT_PAGE,
        classify_route
    }
    embedded_gateway --> jaclang.scale.tests.microservices.test_embedded_gateway {
        EmbeddedGateway
    }
    gateway --> jaclang.scale.runtime.gateway.embedded_gateway { Gateway }
    gateway --> jaclang.scale.runtime.gateway.process_gateway { Gateway }
    microservice_gateway --> jaclang.scale.runtime.gateway.process_gateway {
        MicroserviceGateway
    }
    microservice_gateway --> jaclang.scale.tests.apps.test_fleet_from_apps {
        MicroserviceGateway
    }
    microservice_gateway --> jaclang.scale.tests.microservices.test_app_routes {
        MicroserviceGateway
    }
    microservice_gateway --> jaclang.scale.tests.microservices.test_gateway {
        MicroserviceGateway
    }
    microservice_gateway --> jaclang.scale.tests.microservices.test_gateway_docs_precedence {
        MicroserviceGateway
    }
    microservice_gateway --> jaclang.scale.tests.microservices.test_gateway_webapp {
        MicroserviceGateway
    }
    microservice_gateway --> jaclang.scale.tests.microservices.test_k8s_health_probe {
        MicroserviceGateway
    }
    microservice_gateway --> jaclang.scale.tests.server.test_static_fallback {
        MicroserviceGateway
    }
    microservice_gateway --> jaclang.scale.tests.server.test_stream_ws {
        MicroserviceGateway
    }
    openapi_agg --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.handle_openapi {
        aggregate_openapi
    }
    openapi_agg --> jaclang.scale.runtime.gateway.route_table.learn_service_routes {
        SpecFetch,
        fetch_service_spec
    }
    openapi_agg --> jaclang.scale.tests.microservices.test_gateway { _prefixed_paths }
    openapi_agg --> jaclang.scale.tests.microservices.test_openapi_agg {
        _agg_logger,
        aggregate_openapi
    }
    process_gateway --> jaclang.scale.runtime.orchestrator.orchestrator {
        ProcessGateway
    }
    route_table --> jaclang.scale.runtime.gateway.microservice_gateway {
        ServiceRouteTable
    }
    route_table --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.refresh_app_routes {
        learn_service_routes
    }
    route_table --> jaclang.scale.tests.microservices.test_app_routes {
        ServiceRouteTable,
        literal_prefix
    }
    route_table --> jaclang.scale.tests.microservices.test_gateway.gw_route_table_for_poison_test {
        ServiceRouteTable
    }
    route_table --> jaclang.scale.tests.microservices.test_route_learning {
        ServiceRouteTable
    }
    service_registry --> jaclang.scale.deploy.target.kubernetes.runtime_resolver {
        ServiceEntry,
        ServiceRegistry
    }
    service_registry --> jaclang.scale.runtime.gateway.embedded_gateway {
        ServiceRegistry
    }
    service_registry --> jaclang.scale.runtime.gateway.microservice_gateway {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.runtime.gateway.microservice_gateway._install_ws_catchall {
        ServiceStatus
    }
    service_registry --> jaclang.scale.runtime.gateway.openapi_agg {
        ServiceEntry,
        ServiceRegistry
    }
    service_registry --> jaclang.scale.runtime.gateway.process_gateway {
        ServiceRegistry
    }
    service_registry --> jaclang.scale.runtime.gateway.route_table {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.runtime.orchestrator.local_deployer {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.runtime.orchestrator.orchestrator {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.runtime.orchestrator.process_manager {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.apps.test_fleet_from_apps {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.deploy.test_deployer {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.deploy.test_pod_env {
        ServiceEntry,
        ServiceRegistry
    }
    service_registry --> jaclang.scale.tests.microservices.test_app_routes {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.microservices.test_boot_grace {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.microservices.test_boot_order {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.microservices.test_embedded_gateway {
        ServiceEntry,
        ServiceRegistry
    }
    service_registry --> jaclang.scale.tests.microservices.test_gateway {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.microservices.test_gateway_docs_precedence {
        ServiceRegistry
    }
    service_registry --> jaclang.scale.tests.microservices.test_gateway_webapp {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.microservices.test_k8s_health_probe {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.microservices.test_microservices_registry {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.microservices.test_openapi_agg {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.microservices.test_route_learning {
        ServiceEntry,
        ServiceStatus
    }
    service_registry --> jaclang.scale.tests.microservices.test_stop_signal_scope {
        ServiceEntry,
        ServiceRegistry
    }
    service_registry --> jaclang.scale.tests.server.test_static_fallback {
        ServiceRegistry
    }
    service_registry --> jaclang.scale.tests.server.test_stream_ws {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
}

impl import jaclang.scale.runtime.middleware {
    metrics --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.handle_metrics {
        render_metrics
    }
    metrics --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        build_gateway_metrics
    }
    metrics --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup.dispatcher {
        classify_outcome
    }
    metrics --> jaclang.scale.tests.microservices.test_gateway {
        build_gateway_metrics,
        classify_outcome
    }
    middleware --> jaclang.scale.runtime.gateway.gateway { MiddlewareRegistry }
    middleware --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        Middleware,
        MiddlewareRegistry
    }
    middleware --> jaclang.scale.tests.microservices.test_embedded_gateway {
        Middleware
    }
    middleware --> jaclang.scale.tests.microservices.test_middleware {
        Middleware,
        MiddlewareRegistry
    }
    rate_limit --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        build_rate_limit_middleware
    }
    rate_limit --> jaclang.scale.tests.microservices.test_rate_limit {
        InProcessRateLimiter,
        build_rate_limit_middleware
    }
    ws_forward --> jaclang.scale.runtime.gateway.microservice_gateway._install_ws_catchall {
        websocket_forward
    }
    ws_forward --> jaclang.scale.tests.server.test_stream_ws {
        _select_handshake_headers,
        _to_ws_scheme,
        websocket_forward
    }
}

impl import jaclang.scale.runtime.orchestrator {
    local_deployer --> jaclang.scale.plugin.scale_cmd { LocalDeployer }
    local_deployer --> jaclang.scale.runtime.orchestrator.orchestrator { LocalDeployer }
    local_deployer --> jaclang.scale.tests.deploy.test_deployer { LocalDeployer }
    orchestrator --> jaclang.scale.plugin.scale_cmd {
        ServiceRegistry,
        build_registry,
        start_gateway_only
    }
    orchestrator --> jaclang.scale.runtime.realizer.local_realizer { start_fleet_mode }
    orchestrator --> jaclang.scale.tests.apps.test_fleet_from_apps { build_registry }
    process_manager --> jaclang.scale.runtime.orchestrator.local_deployer {
        ServiceProcessManager
    }
    process_manager --> jaclang.scale.runtime.orchestrator.local_deployer.LocalDeployer.status {
        _pid_alive,
        _read_pidfile,
        _read_portfile
    }
    process_manager --> jaclang.scale.runtime.orchestrator.orchestrator {
        ServiceProcessManager
    }
    process_manager --> jaclang.scale.tests.microservices.test_boot_grace {
        ServiceProcessManager
    }
    process_manager --> jaclang.scale.tests.microservices.test_boot_order {
        ServiceProcessManager
    }
    process_manager --> jaclang.scale.tests.microservices.test_k8s_health_probe {
        ServiceProcessManager
    }
    process_manager --> jaclang.scale.tests.microservices.test_stop_signal_scope {
        ServiceProcessManager,
        _owns_group,
        _signal_group
    }
}

impl import jaclang.scale.runtime.planner {
    planner --> jaclang.scale.runtime.realizer.local_realizer {
        TOPOLOGY_MICROSERVICE,
        plan_realization
    }
    planner --> jaclang.scale.tests.microservices.test_planner { plan_realization }
}

impl import jaclang.scale.runtime.realizer {
    kubernetes_realizer --> jaclang.scale.plugin.scale_deploy { KubernetesRealizer }
    kubernetes_realizer as realizer_mod --> jaclang.scale.tests.deploy.test_deploy_banner;
    kubernetes_realizer --> jaclang.scale.tests.deploy.test_deploy_banner {
        KubernetesRealizer
    }
    kubernetes_realizer as realizer_mod --> jaclang.scale.tests.deploy.test_dry_run_purity;
    kubernetes_realizer --> jaclang.scale.tests.deploy.test_dry_run_purity {
        KubernetesRealizer
    }
    kubernetes_realizer --> jaclang.scale.tests.deploy.test_version_pin {
        DELEGATED_ENV,
        KubernetesRealizer,
        pinned_deploy_argv
    }
    local_realizer --> jaclang.scale.plugin.scale_local_serve { LocalRealizer }
}

impl import jaclang.scale.runtime.rpc {
    breaker --> jaclang.scale.runtime.rpc.rpc {
        _BREAKER_COOLDOWN_SECONDS,
        breaker_record_failure,
        breaker_record_success,
        breaker_should_skip
    }
    breaker --> jaclang.scale.tests.server.test_sv_auth_forward {
        _BREAKER_TRIP_THRESHOLD,
        _breaker_force_cooldown_elapsed,
        _breaker_peek,
        _breaker_reset,
        breaker_record_failure,
        breaker_record_success,
        breaker_should_skip
    }
    rpc --> jaclang.scale.runtime.transport.transport.HttpTransport.call_function {
        service_call
    }
    rpc --> jaclang.scale.runtime.transport.transport.HttpTransport.call_walker {
        walker_call
    }
    rpc --> jaclang.scale.tests.apps.test_app_scale_overrides { _sv_rpc_timeout }
    rpc as rpc_mod --> jaclang.scale.tests.server.test_sv_auth_forward;
    rpc --> jaclang.scale.tests.server.test_sv_auth_forward {
        _RPC_MAX_ATTEMPTS,
        _sv_rpc_timeout
    }
}

impl import jaclang.scale.runtime.transport {
    http_forward --> jaclang.scale.runtime.gateway.microservice_gateway { raw_forward }
    http_forward --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.aggregate_graph_data {
        raw_forward
    }
    http_forward --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.forward_to {
        stream_forward
    }
    http_forward --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.probe_services {
        stream_forward
    }
    http_forward --> jaclang.scale.runtime.gateway.openapi_agg.fetch_service_spec {
        raw_forward
    }
    http_forward --> jaclang.scale.tests.server.test_stream_ws {
        ForwardResult,
        raw_forward,
        stream_forward
    }
    transport --> jaclang.scale.runtime.gateway.embedded_gateway { ServiceTransport }
    transport --> jaclang.scale.runtime.provider.JacScaleRuntime.sv_service_call {
        http_transport
    }
    transport --> jaclang.scale.runtime.provider.JacScaleRuntime.sv_walker_call {
        http_transport
    }
    transport --> jaclang.scale.tests.microservices.test_embedded_gateway {
        InProcessTransport
    }
}

impl import jaclang.scale.scheduler {
    fire_executor --> jaclang.scale.scheduler.scheduler.new_engine { FireTimeExecutor }
    scheduler --> jaclang.scale.server.jobs_ext { JacScaleScheduler, TriggerSpec }
    scheduler --> jaclang.scale.tests.misc.test_optional_deps {
        JacScaleScheduler,
        TriggerSpec
    }
    scheduler --> jaclang.scale.tests.server.test_pg_job_store { PgJobStore }
    scheduler --> jaclang.scale.tests.server.test_scheduler_endpoints {
        MemoryJobStore,
        TriggerSpec
    }
    scheduler --> jaclang.scale.tests.server.test_scheduler_multipod {
        JOBS_CHANGED_CHANNEL,
        JacScaleScheduler,
        PgJobStore,
        TriggerSpec,
        new_engine
    }
    scheduler_models --> jaclang.scale.server.jobs_ext {
        CreateJobRequest,
        UpdateJobRequest
    }
}

impl import jaclang.scale.sdk {
    client --> jaclang.scale.sdk { ScaleClient, deploy }
    events --> jaclang.scale.sdk | jaclang.scale.sdk.client { EventLogger }
    spec --> jaclang.scale.sdk | jaclang.scale.sdk.client { DeploySpec }
}

impl import jaclang.scale.server {
    extensions --> jaclang.scale.runtime.provider.JacScaleRuntime.get_server_extensions {
        scale_extensions
    }
    extensions --> jaclang.scale.tests.data.test_gateway_owned_identity {
        fleet_provisions_unknown_users
    }
    extensions --> jaclang.scale.tests.server.test_scheduler_multipod {
        validate_events_url as _validate_events_url
    }
    inprocess --> jaclang.client.targets.desktop.native.host_boot.serve_program {
        prepare_inprocess_runtime
    }
    inprocess --> jaclang.scale.tests.scale_test_client.ScaleTestClient._initialize {
        prepare_inprocess_runtime
    }
    inprocess --> jaclang.scale.tests.server.test_host_serving {
        prepare_inprocess_runtime
    }
    jobs_ext --> jaclang.scale.server.extensions { JobsExtension }
    jobs_ext --> jaclang.scale.tests.server.test_scheduler_endpoints { _err_response }
    sso_ext --> jaclang.scale.server.extensions { ApiKeyExtension, SSOExtension }
    sso_ext --> jaclang.scale.tests.server.test_firebase_auth_sso { SSOExtension }
    sso_ext --> jaclang.scale.tests.server.test_sso {
        SSOExtension,
        resolve_sso_client_redirect
    }
    webhook_ext --> jaclang.scale.server.extensions { WebhookExtension }
    websocket_ext --> jaclang.scale.server.extensions { WebSocketExtension }
}

impl import jaclang.scale.shared {
    enums --> jaclang.scale.sso.sso_auth { Operations, Platforms }
    enums --> jaclang.scale.tests.server.test_firebase_auth_sso {
        Operations,
        Platforms
    }
    utils --> jaclang.scale.server.sso_ext { is_safe_loopback_redirect }
    utils --> jaclang.scale.sso.sso_auth { is_safe_loopback_redirect }
    utils --> jaclang.scale.tests.server.test_sso { is_safe_loopback_redirect }
}

impl import jaclang.scale.sso {
    apple --> jaclang.scale.sso.sso_auth.SSOAuth.get_sso { AppleSSOProvider }
    apple --> jaclang.scale.tests.server.test_oauth_providers { AppleSSOProvider }
    apple --> jaclang.scale.tests.server.test_sso { AppleSSOProvider }
    firebase --> jaclang.scale.sso.sso_auth.SSOAuth.get_sso { FirebaseSSOProvider }
    firebase --> jaclang.scale.tests.server.test_firebase_auth_sso {
        FirebaseSSOProvider
    }
    github --> jaclang.scale.sso.sso_auth.SSOAuth.get_sso { GithubSSOProvider }
    github --> jaclang.scale.tests.server.oauth_fixtures { GithubSSOProvider }
    github --> jaclang.scale.tests.server.test_oauth_providers { GithubSSOProvider }
    github --> jaclang.scale.tests.server.test_oauth_session { GithubSSOProvider }
    github --> jaclang.scale.tests.server.test_sso { GithubSSOProvider }
    google --> jaclang.scale.sso.sso_auth.SSOAuth.get_sso { GoogleSSOProvider }
    google --> jaclang.scale.tests.server.test_oauth_providers { GoogleSSOProvider }
    google --> jaclang.scale.tests.server.test_sso { GoogleSSOProvider }
    oauth_session --> jaclang.scale.server.sso_ext { OAuthSession }
    oauth_session --> jaclang.scale.sso.sso_auth {
        OAuthSession,
        challenge_of,
        complete_identity
    }
    oauth_session --> jaclang.scale.tests.server.test_oauth_session {
        OAuthSession,
        challenge_of,
        complete_identity
    }
    oauth_session --> jaclang.scale.tests.server.test_registration_challenge {
        complete_identity
    }
    provider --> jaclang.scale.server.sso_ext { OAuth2CodeProvider }
    provider --> jaclang.scale.sso.apple {
        OAuth2CodeProvider,
        SSOUserInfo,
        decode_jwt_payload_unverified
    }
    provider --> jaclang.scale.sso.firebase { SSOProvider, SSOUserInfo }
    provider --> jaclang.scale.sso.github { OAuth2CodeProvider, SSOUserInfo }
    provider --> jaclang.scale.sso.google { OAuth2CodeProvider, SSOUserInfo }
    provider --> jaclang.scale.sso.oauth_session { OAuth2CodeProvider, SSOUserInfo }
    provider --> jaclang.scale.sso.sso_auth {
        OAuth2CodeProvider,
        SSOProvider,
        SSOUserInfo
    }
    provider --> jaclang.scale.tests.server.test_firebase_auth_sso { SSOUserInfo }
    provider --> jaclang.scale.tests.server.test_oauth_session { SSOUserInfo }
    provider --> jaclang.scale.tests.server.test_registration_challenge { SSOUserInfo }
    provider --> jaclang.scale.tests.server.test_sso { SSOUserInfo }
    sso_auth --> jaclang.scale.server.sso_ext { SSOAuth }
    sso_auth --> jaclang.scale.tests.server.test_firebase_auth_sso { SSOAuth }
    sso_auth --> jaclang.scale.tests.server.test_sso { SSOAuth }
}

impl import jaclang.scale.state {
    factory --> jaclang.scale.runtime.middleware.rate_limit { get_state_backend }
    factory --> jaclang.scale.server.extensions { get_state_backend }
    factory --> jaclang.scale.tests.microservices.test_rate_limit._reset_state {
        _backend_holder
    }
    factory as factory_mod --> jaclang.scale.tests.misc.test_state_backend_selection;
    factory --> jaclang.scale.tests.misc.test_state_backend_selection {
        get_state_backend,
        in_fleet
    }
    pg_state_backend --> jaclang.scale.runtime.provider {
        PgStateBackend as _state_anchor
    }
    pg_state_backend --> jaclang.scale.state.factory { PgStateBackend }
    state_backend --> jaclang.scale.runtime.middleware.rate_limit { StateBackend }
    state_backend --> jaclang.scale.server.extensions { StateBackend }
    state_backend --> jaclang.scale.state.factory {
        InProcessStateBackend,
        StateBackend
    }
    state_backend --> jaclang.scale.state.pg_state_backend { StateBackend }
    state_backend --> jaclang.scale.tests.misc.test_state_backend_selection {
        InProcessStateBackend
    }
}

impl import jaclang.scale.storage {
    bucket_storage --> jaclang.scale.storage.gcs_storage { BucketStorage }
    bucket_storage --> jaclang.scale.storage.s3_storage { BucketStorage }
    factory --> jaclang.scale.runtime.provider.JacScaleRuntime.store { StorageFactory }
    factory --> jaclang.scale.tests.data.test_firebase_env { StorageFactory }
    gcs_storage --> jaclang.scale.storage.factory.StorageFactory.create { GcsStorage }
    gcs_storage --> jaclang.scale.tests.data.test_gcs_storage { GcsStorage }
    s3_storage --> jaclang.scale.storage.factory.StorageFactory.create { S3Storage }
    s3_storage --> jaclang.scale.tests.data.test_s3_storage { S3Storage }
}

impl import jaclang.scale.tests {
    scale_test_client --> jaclang.scale.tests.microservices.test_app_routes {
        ScaleTestClient,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.misc.test_llm_telemetry {
        ScaleTestClient,
        extract_data,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.misc.test_metrics { ScaleTestClient }
    scale_test_client --> jaclang.scale.tests.server.test_admin {
        ScaleTestClient,
        extract_data,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.server.test_admin_workloads {
        extract_data,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.server.test_error_envelope {
        extract_data,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.server.test_file_upload {
        ScaleTestClient,
        extract_data,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.server.test_firebase_auth_sso {
        extract_data,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.server.test_health_fail_soft {
        make_client
    }
    scale_test_client --> jaclang.scale.tests.server.test_middleware_async_root {
        ScaleTestClient,
        extract_data,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.server.test_restspec {
        ScaleTestClient,
        extract_data,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.server.test_scheduler_endpoints {
        ScaleTestClient
    }
    scale_test_client --> jaclang.scale.tests.server.test_serve {
        ScaleTestClient,
        extract_data,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.server.test_webhook {
        ScaleTestClient,
        extract_data,
        make_client
    }
    scale_test_client --> jaclang.scale.tests.server.test_ws_functions { make_client }
    scale_test_client --> jaclang.scale.tests.server.test_ws_hardening { make_client }
    support --> jaclang.scale.tests.data.test_async_io_blocking {
        get_free_port,
        register_user,
        start_server
    }
    support --> jaclang.scale.tests.deploy.test_client_build_fail_fast {
        require_pod_binary
    }
    support --> jaclang.scale.tests.deploy.test_ops_deploy { RecordingHost }
    support --> jaclang.scale.tests.deploy.test_ops_health { RecordingHost }
    support --> jaclang.scale.tests.deploy.test_ops_network { RecordingHost }
    support --> jaclang.scale.tests.microservices.test_app_precompile {
        require_pod_binary
    }
    support --> jaclang.scale.tests.microservices.test_bundle_jacignore {
        pod_binary,
        require_pod_binary
    }
    support --> jaclang.scale.tests.microservices.test_fat_bundle { require_pod_binary }
    support --> jaclang.scale.tests.microservices.test_gateway { get_free_port }
    support --> jaclang.scale.tests.microservices.test_k8s_health_probe {
        get_free_port
    }
    support --> jaclang.scale.tests.microservices.test_pvc_injector {
        pod_binary,
        require_pod_binary
    }
    support --> jaclang.scale.tests.microservices.test_seed_determinism {
        pod_binary,
        require_pod_binary
    }
    support --> jaclang.scale.tests.microservices.test_typed_boundary {
        get_free_port,
        start_server,
        stop_server
    }
    support --> jaclang.scale.tests.misc.test_ops_podenv { RecordingHost }
    support --> jaclang.scale.tests.server.test_acl_field_write {
        get_free_port,
        register_user,
        start_server
    }
    support --> jaclang.scale.tests.server.test_admin_logs { RecordingHost }
    support --> jaclang.scale.tests.server.test_app_tokens {
        get_free_port,
        register_user,
        start_server
    }
    support --> jaclang.scale.tests.server.test_examples { get_free_port }
    support --> jaclang.scale.tests.server.test_firebase_auth_sso { RecordingHost }
    support --> jaclang.scale.tests.server.test_metrics_workers {
        cleanup_db_files,
        get_free_port,
        start_server,
        stop_server
    }
    support --> jaclang.scale.tests.server.test_root_bind_fail_closed {
        get_free_port,
        register_user,
        start_server
    }
    support --> jaclang.scale.tests.server.test_serve {
        cleanup_db_files,
        get_free_port,
        start_server,
        stop_server
    }
    support --> jaclang.scale.tests.server.test_user_identity {
        extract,
        get_free_port,
        register_user,
        start_server,
        stop_server
    }
    toolchain_http --> jaclang.scale.tests.deploy.test_client_build_fail_fast {
        mock_downloads
    }
    toolchain_http --> jaclang.scale.tests.microservices.test_binary_cache {
        mock_downloads
    }
}

impl import jaclang.scale.tests.deploy {
    http_activation_test_support --> jaclang.scale.tests.deploy.test_http_activation_config {
        default_http_activation_config as _cfg,
        mocked_keda_autoscaler as _mocked_keda
    }
    http_activation_test_support --> jaclang.scale.tests.deploy.test_http_activation_microservices {
        default_http_activation_config as _cfg,
        default_http_activation_spec as _spec,
        mocked_keda_autoscaler as _mocked_keda
    }
}

impl import jaclang.scale.tests.server {
    oauth_fixtures --> jaclang.scale.tests.server.test_oauth_session {
        FakeTokens,
        fake_users,
        provider
    }
    oauth_fixtures --> jaclang.scale.tests.server.test_sso { FakeTokens, fake_users }
}

impl import jaclang.scale.utils {
    vendor_wheels --> jaclang.scale.injector.bundle._vendor_stage { pod_wheel_target }
    vendor_wheels --> jaclang.scale.tests.microservices.test_fat_bundle {
        POD_GLIBC,
        pod_arch_from_argv,
        pod_wheel_target
    }
}

impl import jaclang.scale.webhook {
    webhook --> jaclang.scale.server.sso_ext { ApiKeyManager }
    webhook --> jaclang.scale.server.webhook_ext {
        ApiKeyManager,
        WebhookUtils,
        rate_window_ok
    }
    webhook --> jaclang.scale.tests.server.test_pg_job_store { ApiKeyManager }
}

impl import jaclang.scale.websocket {
    backplane --> jaclang.scale.server.websocket_ext {
        MemoryBackplane,
        build_backplane
    }
    backplane --> jaclang.scale.tests.server.test_backplane { PgBackplane }
    backplane --> jaclang.scale.tests.server.test_ws_hardening {
        BaseBackplane,
        MemoryBackplane,
        PgBackplane,
        build_backplane
    }
    backplane --> jaclang.scale.websocket.websocket { BaseBackplane, MemoryBackplane }
    protocol --> jaclang.scale.server.websocket_ext {
        AUTH_HANDSHAKE_TIMEOUT_SECONDS,
        HEARTBEAT_MISSED_ALLOWED,
        HEARTBEAT_SECONDS,
        SEND_TIMEOUT_SECONDS,
        ws_authenticate,
        ws_error_frame,
        ws_execute_target,
        ws_handle_control,
        ws_heartbeat_loop,
        ws_pre_accept_auth,
        ws_receive_frame,
        ws_reject_auth,
        ws_reject_pre_accept,
        ws_reject_registration
    }
    protocol --> jaclang.scale.tests.server.test_ws_hardening {
        ws_handle_control,
        ws_heartbeat_loop
    }
    websocket --> jaclang.scale.server.websocket_ext {
        ConnectionContext,
        WebSocketConnectionManager,
        _ws_stream_result
    }
    websocket --> jaclang.scale.tests.server.test_ws_hardening {
        ConnectionContext,
        WebSocketConnectionManager
    }
    websocket --> jaclang.scale.websocket.protocol {
        ConnectionContext,
        consume_rate_token
    }
}

impl import jaclang.server {
    assembly --> jaclang.cli.commands.execution {
        gateway_colocates as _gateway_colocates,
        service_apps as _service_apps
    }
    assembly --> jaclang.cli.commands.execution.serve { service_apps }
    assembly --> jaclang.dist.precompile_bytecode._application_sources { service_apps }
    assembly --> jaclang.dist.seal.build_serve_manifest { service_apps }
    assembly --> jaclang.dist.source.project.export_project {
        gateway_colocates,
        service_apps
    }
    assembly --> jaclang.runtime.prepared.initialize_application {
        assemble_served_program
    }
    assembly --> jaclang.scale.server.inprocess.prepare_inprocess_runtime {
        service_apps
    }
    bridge --> jaclang.scale.tests.data.test_eager_spawn { BridgeUnavailable }
    bridge --> jaclang.scale.tests.server.test_sv_streaming { BridgeError }
    bridge --> jaclang.server.outbox { BridgeRejected }
    bridge --> jaclang.server.outbox.remember_response { serialize_response }
    bridge --> jaclang.server.outbox.replay_cached { replay_response }
    bridge --> jaclang.server.sv_client {
        BridgeError,
        BridgeUnavailable,
        bridge_error_for_status,
        bridge_error_from
    }
    build_status --> jaclang.cli.commands.execution { BuildMonitor }
    build_status --> jaclang.scale.tests.server.test_build_status_endpoint {
        BuildMonitor
    }
    build_status --> jaclang.server.endpoints.pages.register_diagnostics_endpoints.build_status {
        get_build_status
    }
    build_status --> jaclang.server.hmr { BuildMonitor, BuildStatus }
    endpoint_contract --> jaclang.server.endpoints.colocated { check_endpoint_contract }
    endpoint_contract --> jaclang.server.endpoints.walkers { check_endpoint_contract }
    hmr --> jaclang.cli.commands.execution._start_vite_dev_server { HotReloader }
    hmr --> jaclang.cli.commands.execution.serve { HotReloader }
    type hmr --> jaclang.compiler.driver.build_services { HotReloader }
    hmr --> jaclang.compiler.driver.build_services.CompilerBuildServices.hot_reloader {
        HotReloader
    }
    type hmr --> jaclang.runtime.build_services { HotReloader }
    hmr --> jaclang.scale.tests.server.test_build_status_endpoint { HotReloader }
    type hmr --> jaclang.server.build_status { HotReloader }
    type hmr --> jaclang.testing.testing { HotReloader }
    middleware --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway._install_admin_api {
        jwt_middleware
    }
    middleware --> jaclang.scale.server.extensions { require_user }
    middleware --> jaclang.scale.server.jobs_ext { require_user }
    middleware --> jaclang.scale.server.sso_ext { require_user }
    middleware --> jaclang.server.endpoints.auth { require_user }
    middleware --> jaclang.server.endpoints.introspection { unauthorized }
    middleware --> jaclang.server.server.JacAPIServer._install_middleware {
        jwt_middleware,
        request_context_middleware
    }
    middleware --> jaclang.server.server.JacAPIServer.build_app { metrics_middleware }
    net --> jaclang.cli.commands.execution._find_free_port { find_available_port }
    net --> jaclang.cli.commands.execution.serve { PortInUseError }
    net --> jaclang.cli.errmap.humanize_error { PortInUseError }
    net --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.start {
        PORT_RETRY_LIMIT
    }
    net --> jaclang.scale.tests.server.test_serve {
        ERRNO_ADDR_IN_USE,
        PORT_RETRY_LIMIT,
        PortInUseError,
        find_available_port as _find_available_port
    }
    net --> jaclang.server.server { PORT_RETRY_LIMIT }
    net --> jaclang.server.serving.server { PORT_RETRY_LIMIT, bind_listener }
    net --> jaclang.server.serving.supervisor { PORT_RETRY_LIMIT, bind_listener }
    outbox --> jaclang.scale.tests.server.test_sv_outbox_endpoints {
        LEASE_S,
        OutboxEntry,
        PgOutboxStore,
        STATUS_DELIVERED,
        STATUS_DELIVERING,
        STATUS_PENDING,
        SqliteOutboxStore,
        stop_worker,
        use_store,
        worker_running
    }
    outbox --> jaclang.scale.tests.server.test_sv_streaming {
        STATUS_DELIVERED,
        SqliteOutboxStore,
        default_idempotency_key,
        deliver_pending,
        enqueue,
        use_store
    }
    outbox --> jaclang.server.endpoints.colocated { remember_response, replay_cached }
    outbox --> jaclang.server.endpoints.walkers {
        remember_response,
        replay_cached,
        scoped_idempotency_key
    }
    outbox --> jaclang.server.server.JacAPIServer._worker_main {
        start_worker_if_bridging,
        stop_worker
    }
    outbox --> jaclang.server.server.JacAPIServer.serve_background {
        start_worker_if_bridging,
        stop_worker
    }
    outbox --> jaclang.server.sv_client.spawn_deferred { enqueue }
    sealed_serve --> jaclang.cli.commands.execution._jab_native_bin { NATIVE_DIR_REL }
    sealed_serve --> jaclang.client.artifact.client_output_dir { client_dist_for }
    sealed_serve --> jaclang.client.artifact.prebuilt_bundle {
        client_dist_for,
        serve_manifest_for
    }
    sealed_serve --> jaclang.compiler.driver.application._prepare_sealed {
        CLIENT_DIST_REL,
        SERVE_MANIFEST_REL
    }
    sealed_serve --> jaclang.compiler.driver.application.prepare_application {
        sealed_root_for,
        unlisted_image_root
    }
    sealed_serve --> jaclang.dist.precompile_bytecode.app_metadata {
        CLIENT_DIST_REL,
        NATIVE_DIR_REL
    }
    sealed_serve --> jaclang.dist.precompile_bytecode.collect_payloads {
        CLIENT_DIST_REL,
        NATIVE_DIR_REL,
        SERVE_MANIFEST_REL
    }
    sealed_serve --> jaclang.dist.precompile_bytecode.seal_native { NATIVE_DIR_REL }
    sealed_serve --> jaclang.dist.precompile_bytecode.seal_runtime_closure {
        SERVE_MANIFEST_REL
    }
    sealed_serve --> jaclang.dist.seal.bake_native_payloads { NATIVE_DIR_REL }
    sealed_serve --> jaclang.dist.seal.bake_serve_payloads {
        CLIENT_DIST_REL,
        SERVE_MANIFEST_REL
    }
    sealed_serve --> jaclang.scale.injector.bundle.pack_jab { SERVE_MANIFEST_REL }
    sealed_serve --> jaclang.server.endpoints.pages._static_base { sealed_root_for }
    sealed_serve --> jaclang.server.endpoints.pages.register_page_endpoints {
        client_dist_for
    }
    sealed_serve --> jaclang.server.server.ModuleIntrospector._load_manifest {
        serve_manifest_for
    }
    sealed_serve --> jaclang.server.server.ModuleIntrospector._load_spa_routes {
        serve_manifest_for
    }
    sealed_serve --> jaclang.server.server.ModuleIntrospector._load_surface {
        serve_manifest_for
    }
    sealed_serve --> jaclang.server.server.ModuleIntrospector._resolve_declared {
        sealed_root_for
    }
    type server --> jaclang.client.serving { ModuleIntrospector }
    server --> jaclang.client.targets.client_dev_common.dev_proxy_paths {
        ModuleIntrospector
    }
    server --> jaclang.client.targets.desktop.native.broker_extension {
        JacAPIServer,
        ServerExtension
    }
    type server --> jaclang.runtime.builtin.restspec { JacAPIServer }
    type server --> jaclang.runtime.runtime {
        JacAPIServer as JacServer,
        ModuleIntrospector,
        ServerExtension
    }
    server --> jaclang.runtime.runtime.JacServe.get_api_server_class { JacAPIServer }
    server --> jaclang.runtime.source_app.main { JacAPIServer }
    server --> jaclang.scale.admin.admin_portal { EndpointHost, JsonValue }
    server --> jaclang.scale.admin.deploy_health { EndpointHost }
    server --> jaclang.scale.admin.llm_telemetry { EndpointHost, JsonValue }
    server --> jaclang.scale.admin.logs { EndpointHost }
    server --> jaclang.scale.admin.network { EndpointHost }
    server --> jaclang.scale.admin.ops { EndpointHost }
    server --> jaclang.scale.admin.podenv { EndpointHost }
    server --> jaclang.scale.admin.traces { EndpointHost }
    server --> jaclang.scale.admin.workloads { EndpointHost }
    server --> jaclang.scale.plugin { JacAPIServer as JacServer, ServerExtension }
    server --> jaclang.scale.runtime.gateway.microservice_gateway { EndpointHost }
    type server --> jaclang.scale.runtime.provider {
        JacAPIServer as JacServer,
        ServerExtension
    }
    server --> jaclang.scale.server.extensions { JacAPIServer, ServerExtension }
    server --> jaclang.scale.server.inprocess { JacAPIServer, ServerExtension }
    server --> jaclang.scale.server.jobs_ext { JacAPIServer, ServerExtension }
    server --> jaclang.scale.server.sso_ext { JacAPIServer, ServerExtension }
    server --> jaclang.scale.server.webhook_ext {
        JacAPIServer,
        JsonValue,
        ServerExtension,
        target_restspec
    }
    server --> jaclang.scale.server.websocket_ext { JacAPIServer, ServerExtension }
    server --> jaclang.scale.tests.data.test_eager_spawn { JacAPIServer }
    server --> jaclang.scale.tests.data.test_identity_fail_loud { JacAPIServer }
    server --> jaclang.scale.tests.microservices.test_microservice { JacAPIServer }
    server --> jaclang.scale.tests.server.test_host_serving { JacAPIServer }
    server --> jaclang.scale.tests.server.test_served_app_route { JacAPIServer }
    server --> jaclang.scale.tests.server.test_sso { EndpointHost }
    server --> jaclang.scale.tests.server.test_sv_outbox_endpoints { JacAPIServer }
    server --> jaclang.scale.tests.support { EndpointHost }
    server --> jaclang.server.endpoints.auth { EndpointHost, JsonValue }
    server --> jaclang.server.endpoints.colocated {
        JacAPIServer,
        JsonValue,
        ModuleIntrospector
    }
    server --> jaclang.server.endpoints.introspection { JacAPIServer }
    server --> jaclang.server.endpoints.pages { JacAPIServer, JsonValue }
    server --> jaclang.server.endpoints.walkers {
        JacAPIServer,
        JsonValue,
        target_restspec,
        target_schedule_spec
    }
    server --> jaclang.testing.testing { JacAPIServer }
    type server --> jaclang.testing.testing { JacAPIServer }
    session --> jaclang.cli.commands.db._db_status { conninfo_from_url }
    session --> jaclang.cli.commands.db._open_project_store { conninfo_from_url }
    session --> jaclang.cli.commands.db._project_data_dir { shared_pg_data_dir }
    session --> jaclang.cli.commands.db._project_database { project_db_name }
    session --> jaclang.cli.commands.db._runtime_for { scratch_owner_pid }
    session --> jaclang.cli.commands.execution.serve { takeover_project }
    session --> jaclang.data.query_planner { Session }
    session --> jaclang.runtime.context.ExecutionContext.__post_init__ { Session }
    session --> jaclang.runtime.runtime.JacGraph.refs { Session }
    session --> jaclang.scale.events.streams.postgres.PgEventStream._ensure_store {
        conninfo_from_url
    }
    session --> jaclang.scale.injector.bundle.seal_step_env { SCRATCH_ENV }
    session --> jaclang.scale.memory.context.JScaleExecutionContext.init {
        Session,
        conninfo_from_url,
        promotions_for
    }
    session --> jaclang.scale.tests.data.test_pg_stream { shared_pg_data_dir }
    session --> jaclang.scale.tests.deploy.test_postgres_predicate_lock_headroom {
        shared_pg_data_dir
    }
    session --> jaclang.scale.tests.microservices.test_app_precompile { SCRATCH_ENV }
    session --> jaclang.scale.tests.server.test_scheduler_multipod._unreachable_store {
        conninfo_from_url
    }
    session --> jaclang.scale.tests.server.test_sv_outbox_endpoints { Session }
    session --> jaclang.server.outbox._writable_txn { Session }
    session --> jaclang.server.shared_store.shared_store {
        conninfo_from_url,
        promotions_for,
        runtime_for_base
    }
    session --> jaclang.testing.test_runner._fresh_jac_state { mark_scratch_base }
    session --> jaclang.testing.test_runner.run_tests { own_child_databases }
    settings --> jaclang.cli.commands.execution.serve {
        ServeConfigError,
        ServeSettings
    }
    settings --> jaclang.runtime.source_app.main { ServeSettings }
    settings --> jaclang.scale.deploy.target.kubernetes.manifest_builder {
        ServeSettings
    }
    settings --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway._install_admin_api {
        ServeSettings
    }
    settings --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.start {
        ServeSettings
    }
    settings --> jaclang.scale.server.inprocess { ServeSettings }
    settings --> jaclang.scale.tests.data.test_dev_signing_secret {
        ServeConfigError,
        ServeSettings
    }
    settings --> jaclang.scale.tests.microservices.test_drain { ServeSettings }
    settings --> jaclang.scale.tests.server.test_host_serving { ServeSettings }
    settings --> jaclang.scale.tests.server.test_registration_challenge { AuthSettings }
    settings --> jaclang.scale.tests.server.test_registration_limits { AuthSettings }
    settings --> jaclang.scale.tests.server.test_serve { ServeSettings }
    settings --> jaclang.scale.tests.server.test_serving_tail { ServeSettings }
    settings --> jaclang.server.identity.config { AuthSettings }
    settings --> jaclang.server.server { ServeSettings }
    settings --> jaclang.server.server.JacAPIServer._validate_or_raise {
        ServeConfigError
    }
    settings --> jaclang.server.serving.server { ServeSettings }
    settings --> jaclang.server.serving.supervisor { ServeSettings }
    shared_store --> jaclang.scale.admin.ops._postgres_ping_blocking {
        NO_DATABASE_RESOLVED,
        shared_store,
        shared_store_failure
    }
    shared_store --> jaclang.scale.events.streams.postgres.PgEventStream._ensure_store {
        scale_db_url
    }
    shared_store --> jaclang.scale.memory.context.JScaleExecutionContext.init {
        scale_db_url
    }
    shared_store --> jaclang.scale.runtime.provider { shared_store as _pg_anchor }
    shared_store --> jaclang.scale.scheduler.scheduler { shared_store }
    shared_store --> jaclang.scale.server.extensions.EventsExtension.register {
        scale_db_url
    }
    shared_store --> jaclang.scale.server.extensions.EventsExtension.validate {
        scale_db_url
    }
    shared_store --> jaclang.scale.sso.oauth_session.OAuthSession.complete_native {
        shared_store
    }
    shared_store --> jaclang.scale.sso.oauth_session.OAuthSession.poll { shared_store }
    shared_store --> jaclang.scale.state.factory { shared_store, shared_store_failure }
    shared_store as pg_mod --> jaclang.scale.tests.misc.test_shared_store_failure;
    shared_store as store_mod --> jaclang.scale.tests.misc.test_state_backend_selection;
    shared_store --> jaclang.scale.tests.server.test_oauth_session { shared_store }
    shared_store --> jaclang.scale.webhook.webhook { shared_store }
    shared_store --> jaclang.scale.websocket.backplane.PgBackplane.start {
        shared_store
    }
    shared_store --> jaclang.scale.websocket.backplane.build_backplane { scale_db_url }
    shared_store --> jaclang.server.identity.auth_tokens.AuthTokenStore.__post_init__ {
        shared_store
    }
    shared_store --> jaclang.server.identity.rate_limit { shared_store }
    shared_store --> jaclang.server.identity.user_manager.UserManager.__post_init__ {
        NO_DATABASE_RESOLVED,
        shared_store,
        shared_store_failure
    }
    static_files --> jaclang.server.endpoints.pages {
        client_dist_index,
        find_root_asset,
        find_static_candidate,
        sibling_app_dist,
        sibling_app_file
    }
    static_files --> jaclang.server.server.print_endpoint_docs { sibling_app_names }
    sv_client --> jaclang.client.targets.client_dev_common { headless_start_args }
    sv_client --> jaclang.scale.runtime.orchestrator.process_manager.ServiceProcessManager.start_service {
        app_start_args,
        headless_start_args,
        peer_url_env_key
    }
    sv_client --> jaclang.scale.tests.deploy.test_pod_env { peer_url_env_key }
    sv_client --> jaclang.server.assembly.assemble_served_program { set_consumer_app }
    sv_client --> jaclang.server.assembly.colocate_services { register_local }
    sv_client --> jaclang.server.endpoints.colocated { _local_providers }
    sv_client --> jaclang.server.endpoints.colocated.served_app_route { consumer_app }
    sv_client --> jaclang.server.endpoints.walkers {
        IDEMPOTENCY_HEADER,
        bridge_identity
    }
    sv_client --> jaclang.server.endpoints.walkers.function_callback.callback {
        consumer_app
    }
    sv_client --> jaclang.server.endpoints.walkers.walker_callback.callback {
        consumer_app
    }
    sv_client as sv_client --> jaclang.server.outbox._deliver_one;
    sv_client as sv_client --> jaclang.server.outbox.start_worker_if_bridging;
    task_scheduler --> jaclang.runtime.builtin.schedule { ScheduleSpec }
    task_scheduler --> jaclang.scale.scheduler.scheduler {
        ScheduleTrigger,
        Scheduler,
        schedule_namespace,
        tick_of
    }
    task_scheduler --> jaclang.scale.tests.server.test_scheduler_multipod { tick_of }
    task_scheduler --> jaclang.server.server { Scheduler }
    task_scheduler --> jaclang.server.server.JacAPIServer.__post_init__ { Scheduler }
    task_scheduler --> jaclang.server.server.JacAPIServer._register_scheduled_tasks {
        schedule_namespace
    }
    task_scheduler --> jaclang.server.server.JacAPIServer._scheduled_targets {
        ScheduleSpec
    }
    task_scheduler --> jaclang.server.server.JacAPIServer._validate_or_raise {
        schedule_problems
    }
    task_scheduler --> jaclang.server.server.ModuleIntrospector.scheduled_members {
        ScheduleSpec
    }
    transport --> jaclang.scale.admin.admin_portal { Meta, TransportResponse }
    transport --> jaclang.scale.admin.llm_telemetry { Meta, TransportResponse }
    transport --> jaclang.scale.admin.logs { TransportResponse }
    transport --> jaclang.scale.admin.workloads { Meta, TransportResponse }
    transport --> jaclang.scale.server.extensions { Meta, TransportResponse }
    transport --> jaclang.scale.server.jobs_ext { Meta, TransportResponse }
    transport --> jaclang.scale.server.sso_ext { TransportResponse }
    transport --> jaclang.scale.server.webhook_ext { Meta, TransportResponse }
    transport --> jaclang.scale.shared.utils { Meta, TransportResponse }
    transport --> jaclang.scale.sso.sso_auth { Meta, TransportResponse }
    transport --> jaclang.scale.tests.server.test_firebase_auth_sso {
        TransportResponse
    }
    transport --> jaclang.scale.tests.server.test_sso { Meta, TransportResponse }
    transport --> jaclang.scale.webhook.webhook { Meta, TransportResponse }
    transport --> jaclang.server.bridge.serialize_response { TransportResponse }
    transport --> jaclang.server.endpoint_contract { Meta, TransportResponse }
    transport --> jaclang.server.endpoints.auth { Meta, TransportResponse }
    transport --> jaclang.server.endpoints.colocated { Meta, TransportResponse }
    transport --> jaclang.server.endpoints.introspection { Meta, TransportResponse }
    transport --> jaclang.server.endpoints.walkers { Meta, TransportResponse }
    transport --> jaclang.server.middleware { Meta, TransportResponse }
    transport --> jaclang.server.outbox.remember_response { TransportResponse }
    transport --> jaclang.server.serving.app { TransportResponse }
    watcher --> jaclang.cli.commands.execution.serve { JacFileWatcher }
    watcher --> jaclang.client.targets.client_dev_common { FileChangeEvent }
    watcher --> jaclang.client.targets.desktop.webview_shell.webview_dev {
        JacFileWatcher
    }
    watcher --> jaclang.client.targets.mobile_target { FileChangeEvent }
    watcher --> jaclang.client.targets.mobile_target.MobileTarget.dev { JacFileWatcher }
    watcher --> jaclang.client.targets.react_native.dev { FileChangeEvent }
    watcher --> jaclang.client.targets.web_target.WebTarget.dev { JacFileWatcher }
    watcher --> jaclang.compiler.driver.build_services.CompilerBuildServices.hot_reloader {
        JacFileWatcher
    }
    watcher --> jaclang.scale.tests.server.test_build_status_endpoint { JacFileWatcher }
    type watcher --> jaclang.server.hmr { ChangeType, FileChangeEvent, JacFileWatcher }
}

impl import jaclang.server.endpoints {
    auth --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway._install_admin_api {
        register_auth_endpoints
    }
    auth --> jaclang.scale.tests.server.test_registration_challenge {
        register_auth_endpoints
    }
    auth --> jaclang.scale.tests.server.test_registration_limits {
        register_auth_endpoints
    }
    auth --> jaclang.server.server.JacAPIServer.register_endpoints {
        register_auth_endpoints
    }
    colocated --> jaclang.scale.tests.server.test_sv_outbox_endpoints {
        register_colocated_endpoints
    }
    colocated --> jaclang.server.server.JacAPIServer.register_endpoints {
        register_colocated_endpoints
    }
    colocated --> jaclang.server.server.print_endpoint_docs {
        colocated_providers,
        provider_route
    }
    introspection --> jaclang.server.server.JacAPIServer.register_endpoints {
        register_introspection_endpoints
    }
    pages --> jaclang.scale.tests.server.test_build_status_endpoint {
        register_diagnostics_endpoints
    }
    pages --> jaclang.server.server.JacAPIServer.register_endpoints {
        register_diagnostics_endpoints,
        register_graph_endpoints,
        register_page_endpoints
    }
    walkers --> jaclang.server.endpoints.colocated { idempotency_key, request_caller }
    walkers --> jaclang.server.server.JacAPIServer.register_endpoints {
        register_function_endpoints,
        register_walker_endpoints
    }
}

impl import jaclang.server.identity {
    audit --> jaclang.scale.server.extensions { client_ip, emit as audit }
    audit --> jaclang.server.endpoints.auth { client_ip, emit as audit }
    auth_models --> jaclang.scale.server.extensions {
        ForgotPasswordRequest,
        SendVerificationRequest
    }
    auth_models --> jaclang.scale.server.sso_ext { FirebaseTokenRequest }
    auth_models --> jaclang.scale.tests.server.test_registration_challenge {
        RegisterRequest
    }
    auth_models --> jaclang.scale.tests.server.test_registration_limits {
        RegisterRequest
    }
    auth_models --> jaclang.server.endpoints.auth {
        AddIdentityRequest,
        LoginRequest,
        MeIdentity,
        MeResponse,
        RegisterRequest,
        ResetPasswordRequest,
        UpdatePasswordRequest,
        UpdateProfileRequest,
        UpdateProfileResponse,
        UpdateUsernameRequest,
        VerifyIdentityRequest
    }
    auth_tokens --> jaclang.scale.server.extensions { AuthTokenStore }
    auth_tokens --> jaclang.scale.sso.oauth_session { AuthTokenStore }
    auth_tokens --> jaclang.scale.sso.sso_auth { AuthTokenStore }
    auth_tokens --> jaclang.scale.tests.data.test_auth_tokens_fail_closed {
        AuthTokenStore,
        reset_auth_token_store
    }
    auth_tokens --> jaclang.scale.tests.server.test_emailer_factory {
        AuthTokenStore,
        reset_auth_token_store
    }
    auth_tokens --> jaclang.scale.tests.server.test_oauth_session { AuthTokenStore }
    auth_tokens --> jaclang.scale.tests.server.test_registration_challenge {
        AuthTokenStore
    }
    auth_tokens --> jaclang.scale.tests.server.test_sso { AuthTokenStore }
    auth_tokens --> jaclang.server.endpoints.auth { AuthTokenStore }
    auth_tokens --> jaclang.server.identity.app_tokens { AuthTokenStore }
    auth_tokens --> jaclang.server.identity.registration_challenge { AuthTokenStore }
    config --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway._install_admin_api {
        configure_identity
    }
    config --> jaclang.scale.tests.data.test_gateway_owned_identity {
        signing_algorithm as jwt_algorithm,
        signing_secret as jwt_secret
    }
    config --> jaclang.scale.tests.microservices.test_microservice {
        signing_algorithm as jwt_algorithm,
        signing_secret as jwt_secret
    }
    config --> jaclang.scale.tests.server.test_serve { signing_secret as jwt_secret }
    config --> jaclang.scale.webhook.webhook.WebhookUtils.create_api_key_token {
        signing_algorithm,
        signing_secret
    }
    config --> jaclang.scale.webhook.webhook.WebhookUtils.validate_api_key {
        signing_algorithm,
        signing_secret
    }
    config --> jaclang.server.endpoints.auth { auth_settings }
    config --> jaclang.server.identity.identity_storage { password_hash_cost }
    config --> jaclang.server.identity.user_manager {
        signing_algorithm,
        signing_secret,
        token_ttl_days
    }
    config --> jaclang.server.server.JacAPIServer.__post_init__ {
        configure_identity,
        signing_secret
    }
    identity_storage --> jaclang.scale.sso.oauth_session { primary_username }
    identity_storage --> jaclang.scale.tests.data.test_auth_cutover {
        PgIdentityStorage
    }
    identity_storage as storage_mod --> jaclang.scale.tests.data.test_identity_fail_loud;
    identity_storage --> jaclang.scale.tests.data.test_identity_password {
        IdentityStorage
    }
    identity_storage --> jaclang.server.endpoints.auth {
        IdentityTakenError,
        primary_username
    }
    identity_storage --> jaclang.server.identity.user_manager {
        IdentityStorage,
        PgIdentityStorage
    }
    identity_storage --> jaclang.server.server.JacAPIServer._register_scheduled_tasks {
        PgIdentityStorage
    }
    rate_limit --> jaclang.scale.tests.server.test_registration_limits { consume_limit }
    rate_limit --> jaclang.server.endpoints.auth { consume_limit }
    registration_challenge --> jaclang.scale.tests.server.test_registration_challenge {
        consume_challenge,
        issue_challenge
    }
    registration_challenge --> jaclang.server.endpoints.auth {
        consume_challenge,
        issue_challenge
    }
    type user_manager --> jaclang.runtime.runtime { UserManager }
    user_manager --> jaclang.runtime.runtime.JacPersistence.get_user_manager {
        UserManager
    }
    user_manager --> jaclang.scale.admin.admin_portal { UserManager, UserRole }
    user_manager --> jaclang.scale.runtime.gateway.microservice_gateway { UserManager }
    user_manager --> jaclang.scale.server.jobs_ext { SYSTEM_USER, UserRole }
    user_manager --> jaclang.scale.server.webhook_ext { SYSTEM_USER }
    user_manager --> jaclang.scale.sso.oauth_session { UserManager }
    user_manager --> jaclang.scale.sso.sso_auth { UserManager }
    user_manager --> jaclang.scale.tests.data.test_gateway_owned_identity {
        UserManager
    }
    user_manager --> jaclang.scale.tests.data.test_identity_fail_loud { UserManager }
    user_manager --> jaclang.scale.tests.misc.test_shared_store_failure { UserManager }
    user_manager --> jaclang.scale.tests.server.test_firebase_auth_sso { UserManager }
    user_manager --> jaclang.scale.tests.server.test_oauth_session { UserManager }
    user_manager --> jaclang.scale.tests.server.test_sso { UserManager }
    user_manager --> jaclang.scale.tests.server.test_ws_hardening { UserManager }
    user_manager --> jaclang.scale.tests.support { UserManager }
    user_manager --> jaclang.server.endpoints.auth { UserRole }
    user_manager --> jaclang.server.middleware { UserManager }
    user_manager --> jaclang.server.server { UserManager }
    user_manager --> jaclang.server.server.JacAPIServer._ensure_internal_users {
        SYSTEM_USER,
        UserRole
    }
    user_manager --> jaclang.server.server.JacAPIServer._register_scheduled_tasks {
        SYSTEM_USER
    }
}

impl import jaclang.server.serving {
    accesslog --> jaclang.scale.tests.server.test_serve {
        ACCESS_LOGGER_NAME,
        AccessJsonFormatter,
        AccessRecord,
        HealthCheckFilter,
        access_logger,
        configure_access_logging
    }
    accesslog --> jaclang.server.server.JacAPIServer._prepare_to_serve {
        configure_access_logging
    }
    accesslog --> jaclang.server.serving.server { AccessRecord, emit as emit_access }
    app --> jaclang.scale.runtime.gateway.embedded_gateway { ServingApp }
    app --> jaclang.scale.runtime.gateway.microservice_gateway { ServingApp }
    app --> jaclang.scale.tests.microservices.test_drain { ServingApp }
    app --> jaclang.scale.tests.microservices.test_gateway_webapp { ServingApp }
    app --> jaclang.scale.tests.server.test_bodiless_status { ServingApp }
    app --> jaclang.scale.tests.server.test_registration_limits {
        transport_to_response
    }
    app --> jaclang.scale.tests.server.test_serving_tail { ServingApp }
    app --> jaclang.scale.tests.server.test_stream_ws._spawn_upstream { ServingApp }
    app --> jaclang.scale.tests.server.test_stream_ws._spawn_ws_upstream { ServingApp }
    app --> jaclang.scale.tests.server.test_stream_ws._spawn_ws_upstream_with_protocol {
        ServingApp
    }
    app --> jaclang.server.bridge.serialize_response { transport_to_response }
    app --> jaclang.server.server { ServingApp }
    app --> jaclang.server.serving.health { ServingApp }
    app --> jaclang.server.serving.openapi { ServingApp }
    app --> jaclang.server.serving.server { ServingApp }
    app --> jaclang.testing.testkit { ServingApp }
    authcrypt as ac --> jaclang.scale.tests.data.test_auth_cutover;
    authcrypt --> jaclang.scale.tests.data.test_auth_cutover {
        SCRYPT_MAXMEM,
        SCRYPT_MAX_N,
        hash_password,
        is_prescrypt_hash,
        verify_password
    }
    authcrypt --> jaclang.scale.tests.data.test_dev_signing_secret {
        PLACEHOLDER_JWT_SECRET,
        jwt_decode,
        jwt_encode,
        project_data_dir,
        project_signing_secret
    }
    authcrypt --> jaclang.scale.tests.data.test_gateway_owned_identity { jwt_encode }
    authcrypt --> jaclang.scale.tests.microservices.test_microservice { jwt_encode }
    authcrypt --> jaclang.scale.tests.server.test_oauth_providers { jwt_encode }
    authcrypt --> jaclang.scale.tests.server.test_serve {
        jwt_decode as _jwt_decode,
        jwt_encode as _jwt_encode
    }
    authcrypt --> jaclang.scale.webhook.webhook {
        JWTError,
        JWTExpiredError,
        jwt_decode,
        jwt_encode
    }
    authcrypt --> jaclang.server.identity.identity_storage {
        hash_password as _scrypt_hash,
        is_prescrypt_hash as _is_prescrypt,
        needs_rehash as _needs_rehash,
        verify_password as _scrypt_verify
    }
    authcrypt --> jaclang.server.identity.user_manager {
        JWTError,
        JWTExpiredError,
        jwt_decode,
        jwt_encode
    }
    authcrypt --> jaclang.server.settings.AuthSettings.resolve_secret {
        PLACEHOLDER_JWT_SECRET,
        project_signing_secret
    }
    client --> jaclang.scale.admin.logs._loki_request {
        ClientConnectionError,
        arequest
    }
    client --> jaclang.scale.admin.ops._http_ready { arequest }
    client --> jaclang.scale.admin.ops._loki_recent_count { arequest }
    client --> jaclang.scale.admin.ops._tempo_recent_count { arequest }
    client --> jaclang.scale.admin.traces._tempo_request {
        ClientConnectionError,
        arequest
    }
    client --> jaclang.scale.runtime.middleware.ws_forward {
        ClientConnectionError,
        aws_connect
    }
    client --> jaclang.scale.runtime.rpc.rpc._rpc_with_retries {
        ClientConnectionError,
        ClientRequestNotSent
    }
    client --> jaclang.scale.runtime.rpc.rpc.service_call { post_stream_aware_sync }
    client --> jaclang.scale.runtime.rpc.rpc.walker_call { request_sync }
    client --> jaclang.scale.runtime.transport.http_forward {
        ClientConnectionError,
        arequest
    }
    client --> jaclang.scale.sso.github { arequest }
    client --> jaclang.scale.sso.google { arequest }
    client --> jaclang.scale.sso.provider { arequest }
    client --> jaclang.scale.tests.server.test_serve { aws_connect }
    client as sv_http --> jaclang.scale.tests.server.test_sv_auth_forward;
    client --> jaclang.scale.tests.server.test_sv_auth_forward._install_unreachable_transport {
        ClientRequestNotSent
    }
    client --> jaclang.scale.tests.server.test_sv_auth_forward._install_unreachable_walker_transport {
        ClientRequestNotSent
    }
    client --> jaclang.server.bridge.bridge_error_from {
        ClientConnectionError,
        ClientReadTimeout,
        ClientRequestNotSent
    }
    client --> jaclang.server.sv_client._http_call { post_stream_aware_sync }
    client --> jaclang.server.sv_client._http_spawn { request_sync }
    client --> jaclang.testing.testing { run_blocking }
    client --> jaclang.testing.testkit { aws_connect, run_blocking }
    coerce --> jaclang.server.endpoints.walkers { is_upload_type }
    coerce --> jaclang.server.serving.app {
        RequestValidationError,
        bind_parameters,
        body_param_name,
        coerce_value,
        filter_kwargs_for_callback,
        get_callback_spec
    }
    compression --> jaclang.server.serving.server { CompressionPolicy }
    datatypes --> jaclang.client.targets.desktop.native.broker_extension {
        HTMLResponse,
        JSONResponse,
        Request,
        Response,
        StreamingResponse
    }
    datatypes --> jaclang.scale.admin.admin_portal {
        FileResponse,
        HTMLResponse,
        JSONResponse,
        RedirectResponse,
        Request,
        Response
    }
    datatypes --> jaclang.scale.admin.admin_portal.JacAPIServerAdmin.register_admin_endpoints {
        Request
    }
    datatypes --> jaclang.scale.admin.deploy_health { JSONResponse, Request }
    datatypes --> jaclang.scale.admin.llm_telemetry { JSONResponse, Request }
    datatypes --> jaclang.scale.admin.logs { JSONResponse, Request }
    datatypes --> jaclang.scale.admin.network { JSONResponse, Request }
    datatypes --> jaclang.scale.admin.ops { JSONResponse, Request }
    datatypes --> jaclang.scale.admin.podenv { JSONResponse, Request }
    datatypes --> jaclang.scale.admin.traces { JSONResponse, Request }
    datatypes --> jaclang.scale.admin.workloads { Request }
    datatypes --> jaclang.scale.observability.prometheus_metrics { Response }
    datatypes --> jaclang.scale.runtime.context.errors { JSONResponse }
    datatypes --> jaclang.scale.runtime.gateway.embedded_gateway {
        JSONResponse,
        Request,
        Response
    }
    datatypes --> jaclang.scale.runtime.gateway.microservice_gateway {
        HTMLResponse,
        JSONResponse,
        Request,
        Response
    }
    datatypes --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.handle_admin {
        RedirectResponse
    }
    datatypes --> jaclang.scale.runtime.transport.http_forward {
        Response,
        StreamingResponse
    }
    datatypes --> jaclang.scale.server.extensions { JSONResponse, Request, Response }
    datatypes --> jaclang.scale.server.jobs_ext { Request }
    datatypes --> jaclang.scale.server.sso_ext { RedirectResponse, Request, Response }
    datatypes --> jaclang.scale.server.webhook_ext { Request }
    datatypes --> jaclang.scale.server.websocket_ext { WebSocketDisconnect }
    datatypes --> jaclang.scale.sso.firebase { Request, Response }
    datatypes --> jaclang.scale.sso.provider { RedirectResponse, Request, Response }
    datatypes --> jaclang.scale.sso.sso_auth { RedirectResponse, Request, Response }
    datatypes --> jaclang.scale.tests.microservices.test_drain {
        JSONResponse,
        Request,
        URL
    }
    datatypes --> jaclang.scale.tests.microservices.test_gateway {
        Headers,
        Request,
        URL
    }
    datatypes --> jaclang.scale.tests.microservices.test_gateway_webapp {
        JSONResponse,
        Request,
        Response
    }
    datatypes --> jaclang.scale.tests.microservices.test_rate_limit {
        Headers,
        Request,
        URL
    }
    datatypes --> jaclang.scale.tests.microservices.test_rate_limit.next_handler {
        JSONResponse
    }
    datatypes --> jaclang.scale.tests.server.test_bodiless_status {
        Response,
        StreamingResponse
    }
    datatypes --> jaclang.scale.tests.server.test_build_status_endpoint { Request }
    datatypes --> jaclang.scale.tests.server.test_firebase_auth_sso { Request }
    datatypes --> jaclang.scale.tests.server.test_oauth_providers {
        RedirectResponse,
        Request
    }
    datatypes --> jaclang.scale.tests.server.test_oauth_providers._callback_request {
        QueryParams,
        URL
    }
    datatypes --> jaclang.scale.tests.server.test_registration_limits { Request }
    datatypes --> jaclang.scale.tests.server.test_serving_tail { JSONResponse }
    datatypes --> jaclang.scale.tests.server.test_sso {
        Headers,
        QueryParams,
        RedirectResponse,
        Request,
        URL
    }
    datatypes --> jaclang.scale.tests.server.test_static_fallback { Request }
    datatypes --> jaclang.scale.tests.server.test_static_fallback._get_request { URL }
    datatypes --> jaclang.scale.tests.server.test_stream_ws { WebSocketDisconnect }
    datatypes --> jaclang.scale.tests.server.test_stream_ws._spawn_upstream {
        Request,
        Response
    }
    datatypes --> jaclang.scale.tests.server.test_stream_ws._spawn_upstream.big {
        StreamingResponse
    }
    datatypes --> jaclang.scale.tests.server.test_stream_ws._spawn_upstream.sse {
        StreamingResponse
    }
    datatypes --> jaclang.scale.tests.server.test_sv_streaming._StubResp.headers_obj {
        Headers
    }
    datatypes --> jaclang.scale.websocket.websocket { WebSocketDisconnect }
    datatypes --> jaclang.server.bridge.replay_response { JSONResponse }
    datatypes --> jaclang.server.bridge.serialize_response { JSONResponse }
    datatypes --> jaclang.server.endpoints.auth { Request }
    datatypes --> jaclang.server.endpoints.colocated { Request, Response }
    datatypes --> jaclang.server.endpoints.introspection { Request }
    datatypes --> jaclang.server.endpoints.pages {
        HTMLResponse,
        JSONResponse,
        Request,
        Response
    }
    datatypes --> jaclang.server.endpoints.walkers {
        Request,
        Response,
        StreamingResponse
    }
    datatypes --> jaclang.server.identity.audit { Request }
    datatypes --> jaclang.server.middleware { JSONResponse, Request, Response }
    datatypes --> jaclang.server.outbox.remember_response { JSONResponse }
    datatypes --> jaclang.server.serving.app {
        HTTPError,
        JSONResponse,
        RedirectResponse,
        Request,
        Response,
        StreamingResponse,
        parse_query_string
    }
    datatypes --> jaclang.server.serving.client { Headers }
    datatypes --> jaclang.server.serving.coerce { Request, UploadFile }
    datatypes --> jaclang.server.serving.compression { Headers, Request, Response }
    datatypes --> jaclang.server.serving.drain { JSONResponse, Request, Response }
    datatypes --> jaclang.server.serving.files { JSONResponse, Request, Response }
    datatypes --> jaclang.server.serving.health { JSONResponse }
    datatypes --> jaclang.server.serving.middleware { Request, Response }
    datatypes --> jaclang.server.serving.multipart { HTTPError, Request, UploadFile }
    datatypes --> jaclang.server.serving.openapi { HTMLResponse }
    datatypes --> jaclang.server.serving.proxy { Headers }
    datatypes --> jaclang.server.serving.server {
        Headers,
        QueryParams,
        Request,
        Response,
        URL,
        parse_query_string
    }
    datatypes --> jaclang.server.serving.server.ServingServer._dispatch { JSONResponse }
    datatypes --> jaclang.server.serving.ws {
        Headers,
        QueryParams,
        URL,
        WebSocketDisconnect
    }
    datatypes --> jaclang.testing.testing {
        Headers,
        QueryParams,
        Request,
        Response,
        URL,
        parse_query_string
    }
    datatypes --> jaclang.testing.testkit {
        Headers,
        QueryParams,
        Request,
        Response,
        URL,
        parse_query_string
    }
    drain --> jaclang.scale.runtime.gateway.microservice_gateway { DrainState }
    drain --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        drain_middleware
    }
    drain --> jaclang.scale.server.extensions { HEALTH_PATHS }
    drain --> jaclang.scale.tests.microservices.test_drain {
        DrainState,
        drain_middleware
    }
    drain --> jaclang.server.middleware { LIVENESS_PATHS }
    drain --> jaclang.server.server { DrainState }
    drain --> jaclang.server.server.JacAPIServer.build_app { drain_middleware }
    drain --> jaclang.server.serving.accesslog { HEALTH_PATHS }
    drain --> jaclang.server.serving.health { DrainState }
    drain --> jaclang.server.serving.server { DrainState, HEALTH_PATHS }
    endpoint --> jaclang.client.targets.desktop.native.broker_extension {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.runtime.builtin.restspec { HTTPMethod }
    endpoint --> jaclang.scale.admin.admin_portal {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.scale.admin.deploy_health { HTTPMethod, JEndPoint }
    endpoint --> jaclang.scale.admin.llm_telemetry {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.scale.admin.logs {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.scale.admin.network { HTTPMethod, JEndPoint }
    endpoint --> jaclang.scale.admin.ops {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.scale.admin.podenv { HTTPMethod, JEndPoint }
    endpoint --> jaclang.scale.admin.traces {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.scale.admin.workloads {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.scale.runtime.gateway.microservice_gateway {
        JEndPoint,
        WSEndPoint
    }
    endpoint --> jaclang.scale.server.extensions { HTTPMethod, JEndPoint }
    endpoint --> jaclang.scale.server.jobs_ext {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.scale.server.sso_ext {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.scale.server.webhook_ext {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.scale.tests.deploy.test_ops_deploy { HTTPMethod }
    endpoint --> jaclang.scale.tests.deploy.test_ops_health { HTTPMethod }
    endpoint --> jaclang.scale.tests.deploy.test_ops_network { HTTPMethod }
    endpoint --> jaclang.scale.tests.misc.test_ops_podenv { HTTPMethod }
    endpoint --> jaclang.scale.tests.server.test_admin_logs { HTTPMethod }
    endpoint --> jaclang.scale.tests.server.test_bodiless_status {
        HTTPMethod,
        JEndPoint
    }
    endpoint --> jaclang.scale.tests.server.test_serving_tail {
        HTTPMethod,
        JEndPoint,
        WSEndPoint
    }
    endpoint --> jaclang.scale.tests.server.test_sso { JEndPoint }
    endpoint --> jaclang.scale.tests.server.test_stream_ws._spawn_upstream {
        HTTPMethod,
        JEndPoint
    }
    endpoint --> jaclang.scale.tests.server.test_stream_ws._spawn_ws_upstream {
        WSEndPoint
    }
    endpoint --> jaclang.scale.tests.server.test_stream_ws._spawn_ws_upstream_with_protocol {
        WSEndPoint
    }
    endpoint --> jaclang.scale.tests.support { JEndPoint }
    endpoint --> jaclang.server.endpoints.auth {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.server.endpoints.colocated {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.server.endpoints.introspection {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.server.endpoints.pages {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.server.endpoints.walkers {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.server.server { JEndPoint, WSEndPoint }
    endpoint --> jaclang.server.serving.app { JEndPoint, WSEndPoint }
    endpoint --> jaclang.server.serving.coerce {
        APIParameter,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.server.serving.health { HTTPMethod, JEndPoint }
    endpoint --> jaclang.server.serving.openapi {
        APIParameter,
        HTTPMethod,
        JEndPoint,
        ParameterType
    }
    endpoint --> jaclang.server.serving.router { HTTPMethod, JEndPoint, WSEndPoint }
    executor --> jaclang.server.serving.server { SyncExecutor }
    files --> jaclang.server.endpoints.pages { file_response }
    health --> jaclang.server.server.JacAPIServer.register_endpoints {
        register_health_endpoints
    }
    middleware --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        cors_middleware
    }
    middleware --> jaclang.server.server.JacAPIServer.build_app {
        cors_middleware,
        custom_headers_middleware
    }
    model --> jaclang.scale.scheduler.scheduler_models { ApiModel, require_str }
    model --> jaclang.server.identity.auth_models { ApiModel, require_str }
    multipart --> jaclang.server.serving.app { parse_multipart, parse_urlencoded_form }
    openapi --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.handle_docs {
        swagger_ui_html
    }
    openapi --> jaclang.scale.tests.server.test_serving_tail { build_openapi }
    openapi --> jaclang.server.server.JacAPIServer._refresh_dev_endpoints {
        register_docs_endpoints
    }
    openapi --> jaclang.server.server.JacAPIServer.build_app { register_docs_endpoints }
    openapi --> jaclang.server.serving.app.ServingApp.openapi { build_openapi }
    proxy --> jaclang.scale.tests.microservices.test_rate_limit {
        ProxyResolver,
        _untrusted_warned,
        logger as _proxy_logger
    }
    proxy --> jaclang.server.serving.server { ProxyResolver }
    router --> jaclang.server.endpoints.walkers { path_param_names }
    router --> jaclang.server.serving.app { Router }
    server --> jaclang.scale.runtime.gateway.embedded_gateway.EmbeddedGateway.serve {
        PORT_RETRY_LIMIT,
        ServingServer
    }
    server --> jaclang.scale.runtime.gateway.microservice_gateway.MicroserviceGateway.start {
        ServingServer
    }
    server --> jaclang.scale.tests.microservices.test_app_routes._expose_backend {
        ServingServer
    }
    server --> jaclang.scale.tests.microservices.test_drain { ServingServer }
    server --> jaclang.scale.tests.microservices.test_gateway_webapp { ServingServer }
    server --> jaclang.scale.tests.microservices.test_microservice { ServingServer }
    server --> jaclang.scale.tests.server.test_bodiless_status { ServingServer }
    server --> jaclang.scale.tests.server.test_serving_tail { ServingServer }
    server --> jaclang.scale.tests.server.test_stream_ws._spawn_upstream {
        ServingServer
    }
    server --> jaclang.scale.tests.server.test_stream_ws._spawn_ws_upstream {
        ServingServer
    }
    server --> jaclang.scale.tests.server.test_stream_ws._spawn_ws_upstream_with_protocol {
        ServingServer
    }
    server --> jaclang.scale.tests.server.test_sv_outbox_endpoints { ServingServer }
    server --> jaclang.server.server { ServingServer }
    server --> jaclang.server.serving.supervisor { EXIT_OK, EXIT_RECYCLE }
    server --> jaclang.testing.testkit { ServingServer }
    sse --> jaclang.scale.runtime.rpc.rpc._iter_sse_text { consume_sse_events }
    sse --> jaclang.scale.tests.microservices.test_sse_framing { sse_frame_stream }
    sse --> jaclang.scale.tests.server.test_sv_streaming {
        consume_sse_events as consume_sse_stream,
        parse_sse as _parse_sse
    }
    sse --> jaclang.server.endpoints.walkers { sse_frame_stream }
    sse --> jaclang.server.serving.app { sse_frame_stream }
    sse --> jaclang.server.serving.client { parse_sse }
    sse --> jaclang.server.sv_client._http_call { consume_sse_events }
    supervisor --> jaclang.cli.commands.execution.serve { worker_metrics_dir }
    supervisor --> jaclang.runtime.source_app.main { worker_metrics_dir }
    supervisor --> jaclang.server.server { WorkerHandle }
    supervisor --> jaclang.server.server.JacAPIServer.start { WorkerSupervisor }
    ws --> jaclang.scale.runtime.gateway.microservice_gateway { WebSocket }
    ws --> jaclang.scale.server.websocket_ext { WebSocket }
    ws --> jaclang.scale.tests.server.test_serving_tail {
        OP_CLOSE,
        OP_CONT,
        OP_PING,
        OP_PONG,
        OP_TEXT,
        encode_frame,
        read_frame
    }
    ws --> jaclang.scale.websocket.protocol { WebSocket }
    ws --> jaclang.scale.websocket.websocket { WebSocket }
    ws --> jaclang.server.serving.client { WebSocket, compute_accept_key }
    ws --> jaclang.server.serving.server { WebSocket, compute_accept_key }
}

impl import jaclang.testing {
    cl_test_runner --> jaclang.scale.tests.server.test_cl_test_runner {
        run_cl_test_file
    }
    cl_test_runner --> jaclang.testing.runner.run_test {
        is_cl_test_file,
        is_cl_test_file_for_discovery,
        register_results_into_jactestcheck,
        run_cl_test_file
    }
    cl_test_runner --> jaclang.testing.test_runner.run_file {
        module_is_client,
        run_cl_test_file
    }
    requires --> jaclang.byllm.tests.test_media { require_module }
    requires --> jaclang.scale.tests.deploy.test_deploy_k8s { require_flag }
    requires --> jaclang.scale.tests.microservices.test_fat_bundle { require_network }
    requires --> jaclang.scale.tests.server.test_scheduler_endpoints { require_module }
    requires --> jaclang.scale.tests.server.test_scheduler_multipod { require_module }
    runner --> jaclang.compiler.driver.build_services.CompilerBuildServices.run_test {
        run_test
    }
    test --> jaclang.compiler.tests.test_pipeline_products { parametrize }
    test --> jaclang.compiler.tests.test_prim_equivalence { parametrize }
    test --> jaclang.runtime.runtime.JacTest.jac_test { JacTestCheck }
    test --> jaclang.scale.tests.deploy.test_k8s_utils { parametrize }
    test --> jaclang.testing.cl_test_runner.register_results_into_jactestcheck {
        JacTestCheck
    }
    test --> jaclang.testing.runner.run_test { JacTestCheck }
    test --> jaclang.testing.test_runner.run_file { JacTestCheck }
    test_runner --> jaclang.byllm.tests.support.need_outside_jaclang { strict_mode }
    test_runner --> jaclang.cli.commands.analysis.test { run_tests }
    test_runner --> jaclang.scale.tests.support { STRICT_ENV, strict_mode }
    test_runner --> jaclang.testing.requires { STRICT_ENV, strict_mode }
    testkit --> jaclang.scale.server.inprocess.prepare_inprocess_runtime {
        ServingTestClient
    }
    testkit --> jaclang.scale.tests.apps.test_fleet_from_apps {
        ServingTestClient as TestClient
    }
    testkit --> jaclang.scale.tests.data.test_eager_spawn {
        ServingTestClient as TestClient
    }
    testkit --> jaclang.scale.tests.microservices.test_app_routes {
        ServingTestClient as TestClient
    }
    testkit --> jaclang.scale.tests.microservices.test_embedded_gateway {
        ServingTestClient as TestClient
    }
    testkit --> jaclang.scale.tests.microservices.test_gateway {
        ServingTestClient as TestClient
    }
    testkit --> jaclang.scale.tests.microservices.test_gateway._gateway {
        ServingTestClient as TestClient
    }
    testkit --> jaclang.scale.tests.microservices.test_gateway_docs_precedence {
        ServingTestClient
    }
    testkit --> jaclang.scale.tests.microservices.test_gateway_webapp {
        ServingTestClient
    }
    testkit --> jaclang.scale.tests.microservices.test_microservice {
        ServingTestClient as TestClient
    }
    testkit --> jaclang.scale.tests.server.test_served_app_route {
        ServingTestClient as TestClient
    }
    testkit --> jaclang.scale.tests.server.test_stream_ws {
        ServingTestClient as TestClient
    }
    testkit --> jaclang.scale.tests.server.test_sv_outbox_endpoints {
        ServingTestClient as TestClient
    }
    testkit --> jaclang.testing.testing { dispatch_and_collect }
}

impl import jaclang.toolchains {
    android --> jaclang.client.targets.react_native.build.run_eas_local_build {
        ensure_android
    }
    android --> jaclang.client.targets.react_native.build.run_gradle_assemble {
        ensure_android
    }
    android --> jaclang.toolchains.manager.setup_toolchain { ensure_android }
    apple --> jaclang.client.targets.react_native.build.run_eas_local_build {
        ensure_apple
    }
    apple --> jaclang.client.targets.react_native.build.run_xcodebuild_ios {
        ensure_apple
    }
    apple --> jaclang.toolchains.manager.setup_toolchain { ensure_apple }
    c_backend --> jaclang.compiler.backends.native.c_emit.emit_c { ensure_c_backend }
    c_backend --> jaclang.dist.source.project.export_project {
        c_backend_license,
        c_backend_provenance
    }
    cef --> jaclang.client.targets.desktop.cef_shell { ensure_cef }
    cef --> jaclang.toolchains.manager.setup_toolchain { ensure_cef }
    desktop --> jaclang.client.targets.desktop.desktop_build._find_cef_dir {
        source_workspace
    }
    desktop --> jaclang.client.targets.desktop.desktop_build._find_native_asset_dir {
        source_workspace
    }
    desktop --> jaclang.client.targets.desktop.desktop_build._find_webview_dir {
        source_workspace
    }
    desktop --> jaclang.client.targets.desktop.desktop_build.build_cef_dispatch {
        source_workspace
    }
    desktop --> jaclang.client.targets.desktop.desktop_build.build_cef_subprocess {
        source_workspace
    }
    desktop --> jaclang.client.targets.desktop.macos_bundle {
        MACOS_DESKTOP_MIN_VERSION
    }
    desktop --> jaclang.client.targets.desktop.webview_shell {
        ensure_webview,
        webview_library_name
    }
    desktop --> jaclang.toolchains.manager.setup_toolchain { ensure_webview }
    host --> jaclang.client.targets.desktop.webview_shell { host_platform }
    host --> jaclang.client.targets.react_native.build.run_xcodebuild_ios { run_step }
    host --> jaclang.toolchains.android {
        executable,
        host_platform,
        run_step,
        use_system_tools
    }
    host --> jaclang.toolchains.apple { host_platform, run_step, use_system_tools }
    host --> jaclang.toolchains.c_backend { executable, host_platform, run_step }
    host --> jaclang.toolchains.cef { host_platform }
    host --> jaclang.toolchains.desktop { host_platform, run_step, shared_library_name }
    host --> jaclang.toolchains.javascript { host_platform, use_system_tools }
    host --> jaclang.toolchains.system { run_step }
    host --> jaclang.toolchains.system.ensure_desktop_host { host_platform }
    host --> jaclang.toolchains.system.ensure_linux_desktop { host_platform }
    host --> jaclang.toolchains.system.ensure_patchelf { host_platform }
    javascript --> jaclang.client.targets.react_native.build.run_eas_local_build {
        build_environment
    }
    javascript --> jaclang.client.targets.react_native.build.run_expo_prebuild {
        build_environment
    }
    javascript --> jaclang.client.targets.react_native.build.run_gradle_assemble {
        build_environment
    }
    javascript --> jaclang.client.targets.react_native.build.run_xcodebuild_ios {
        build_environment
    }
    javascript --> jaclang.toolchains.manager.setup_toolchain { native_node }
    manager --> jaclang.client.cli.setup { setup_toolchain }
    pins --> jaclang.toolchains.android {
        ANDROID_ARTIFACTS,
        JDK_ARTIFACTS,
        JDK_VERSION
    }
    pins --> jaclang.toolchains.apple.ensure_apple { RUBY_ARTIFACTS, RUBY_VERSION }
    pins --> jaclang.toolchains.javascript { NODE_ARTIFACTS }
    pins --> jaclang.toolchains.system.ensure_patchelf { PATCHELF_ARTIFACTS }
    store --> jaclang.client.targets.desktop.desktop_build._native_build_cef {
        InstallLock
    }
    store --> jaclang.client.targets.mobile_target.MobileTarget.ensure_ready { offline }
    store --> jaclang.client.targets.node_tooling_common.run_manifest_install {
        InstallLock,
        offline
    }
    store --> jaclang.client.targets.react_native.build.run_eas_local_build { offline }
    store --> jaclang.client.targets.react_native.build.run_gradle_assemble {
        InstallLock,
        offline
    }
    store --> jaclang.client.targets.react_native.build.run_xcodebuild_ios { offline }
    store --> jaclang.data.pgembed.PgRuntime._download_zonky { InstallLock }
    store --> jaclang.data.pgembed.PgRuntime._fetch_dist { Artifact, extract, fetch }
    store --> jaclang.scale.injector.binary._fetch_verified_asset { Artifact, fetch }
    store --> jaclang.toolchains.android { InstallLock, install, offline }
    store --> jaclang.toolchains.apple {
        InstallLock,
        install_slot,
        offline,
        publish_install_slot,
        slot_installed
    }
    store --> jaclang.toolchains.apple.ensure_apple { install }
    store --> jaclang.toolchains.c_backend {
        Artifact,
        InstallLock,
        build_slot,
        extract,
        fetch,
        file_digest,
        publish_build_slot,
        slot_ready
    }
    store --> jaclang.toolchains.cef { Artifact, InstallLock, install }
    store --> jaclang.toolchains.desktop {
        Artifact,
        InstallLock,
        build_slot,
        fetch,
        file_digest,
        publish_build_slot,
        slot_ready
    }
    store --> jaclang.toolchains.javascript { install, offline }
    store --> jaclang.toolchains.pins { Artifact }
    store --> jaclang.toolchains.system { offline }
    store --> jaclang.toolchains.system.ensure_patchelf { install }
    system --> jaclang.client.targets.desktop.desktop_build._patchelf_rpath {
        ensure_patchelf
    }
    system --> jaclang.toolchains.desktop { ensure_desktop_host, webkit_module }
}
