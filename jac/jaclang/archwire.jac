graph import {
    edge Artifacts: artifacts.* --> cli.* | client.* | compiler.* | data.* | dist.* | project.* | server.* | toolchains.*;
    edge BootstrapManifest: bootstrap_manifest --> compiler.* | dist.* | project.*;
    edge Byllm: byllm.* --> cli.* | runtime.* | scale.* | studio.*;
    edge Cache: cache.* --> byllm.* | cli.* | client.* | compiler.* | data.* | dist.* | packages.* | project.* | scale.* | server.* | toolchains.*;
    edge Cli: cli.* --> byllm.* | client.* | compiler.* | dist.* | jac0core.* | lsp.* | packages.* | project.* | runtime.* | scale.* | server.* | testing.* | toolchains.*;
    edge Client: client.* --> cli.* | compiler.* | dist.* | project.* | runtime.* | scale.* | server.* | testing.* | toolchains.*;
    edge Compiler: compiler.* --> cli.* | client.* | dist.* | lsp.* | packages.* | project.* | runtime.* | scale.* | server.* | studio.* | testing.* | toolchains.*;
    edge Comptime: comptime --> byllm.* | cli.* | client.* | scale.* | server.*;
    edge Data: data.* --> cli.* | client.* | compiler.* | runtime.* | scale.* | server.* | studio.*;
    edge Dist: dist.* --> cli.* | client.* | compiler.* | packages.* | scale.*;
    edge Jac0: jac0 --> dist.*;
    edge Jac0core: jac0core.* --> artifacts.* | cache.* | cli.* | client.* | compiler.* | data.* | dist.* | packages.* | project.* | runtime.* | scale.* | server.* | testing.* | toolchains.*;
    edge Lsp: lsp.* --> cli.* | studio.*;
    edge MetaImporter: meta_importer --> client.*;
    edge Packages: packages.* --> cli.* | client.* | dist.* | project.*;
    edge Project: project.* --> artifacts.* | byllm.* | cache.* | cli.* | client.* | compiler.* | data.* | dist.* | lsp.* | packages.* | runtime.* | scale.* | server.* | studio.* | testing.* | toolchains.*;
    edge Runtime: runtime.* --> byllm.* | cli.* | client.* | compiler.* | comptime | data.* | dist.* | lib.* | project.* | scale.* | server.* | studio.* | testing.*;
    edge Scale: scale.* --> cli.* | client.* | runtime.* | server.*;
    edge Server: server.* --> cli.* | client.* | compiler.* | data.* | dist.* | runtime.* | scale.* | testing.*;
    edge Studio: studio.* --> cli.*;
    edge Testing: testing.* --> cli.* | compiler.* | runtime.* | scale.*;
    edge Toolchains: toolchains.* --> client.* | compiler.* | data.* | dist.* | packages.* | scale.*;

    artifacts.kit ++> [
        client.js_runtime.BunArtifact.build
            | compiler.backends.native.native_link.floor_lib_dir { osarch },
        client.js_runtime.BunArtifact.probe_kit { kit_image },
        compiler.backends.native.floors { osarch, runtime_floor_root },
        compiler.backends.native.llvm.shim_path.ShimArtifact.probe_kit
            | compiler.types.stubcat.locate.StubcatArtifact.probe_kit {
            kit_image,
            kit_path
        },
        compiler.backends.native.native_link.musl_lib_dir { osarch },
    ]
    artifacts.kit --> compiler.backends.native.link_plan.link_artifact { osarch }
    artifacts.model ++> [
        cli.commands.execution._run_node_tool
            | client.cli.run_npm_add_global
            | compiler.backends.native.llvm.binding.ffi
            | dist.seal.ensure_client_dist
            | project.compiler_host.ProjectHost.typeshed_unavailable_reason
            | server.server { ArtifactUnavailable },
        cli.commands.native { ArtifactUnavailable, Probe },
        client.js_runtime
            | compiler.backends.native.floors
            | compiler.backends.native.llvm.shim_path
            | compiler.types.stubcat.locate
            | dist.precompiled { Artifact, ArtifactKind, Probe, ReleasePolicy, Source },
        compiler.tests.test_stubcat_roundtrip { Probe, Source },
        data.pg_dist | toolchains.tools {
            Artifact,
            ArtifactKind,
            ArtifactUnavailable,
            Probe,
            ReleasePolicy,
            Source
        },
        dist.payload.fetch.fetch_bun { Source },
        toolchains.c_backend {
            Artifact as ArtifactBase,
            ArtifactKind,
            Probe,
            ReleasePolicy,
            Source
        },
    ]
    artifacts.router ++> [
        client.js_runtime.js_runtime_path
            | compiler.backends.native.llvm.shim_path.shim_path
            | compiler.backends.native.wasm_build._link_wasm_libc
            | data.pg_dist.postgres_bin_dir
            | project.compiler_host.ProjectHost.typeshed_unavailable_reason
            | toolchains.c_backend.ensure_c_backend
            | toolchains.tools.tool_path { require },
        client.targets.desktop.native.host_boot._enter_embedded_env { forget },
        client.targets.desktop.native.host_boot._leave_embedded_env { forget },
        compiler.backends.native.native_link.floor_lib_dir
            | compiler.backends.native.wasm_build._wasm_libc_dir
            | compiler.types.stubcat.locate.open_catalog { resolve },
        compiler.backends.native.native_link.musl_lib_dir { resolve },
        compiler.types.stubcat.build.build_catalog { building },
    ]
    artifacts.router --> compiler.driver.toolchain.native_pipeline_available { resolve }
    artifacts.router as router ++> cli.commands.native
        | compiler.tests.test_stubcat_roundtrip;
    bootstrap_manifest ++> [
        compiler.driver.jir {
            COMPILER_DIGEST_ROOTS,
            COMPILER_DIGEST_ROSTER,
            COMPILER_IDENTITY_NAME,
            NATIVE_LOWERED_PATHS,
            is_native_lowered,
            is_roster_input,
            is_staging_rewritten,
            read_input_rules
        },
        dist.payload.fsutil.skip_jaclang
            | dist.precompile_bytecode.find_jac_files
            | project.compiler_host.ProjectHost.is_native_lowered_source {
            is_native_lowered
        },
        dist.precompile_bytecode.seal_bootstrap { is_native_only, seed_abs_entries },
        dist.precompile_bytecode.sealable_sources
            | dist.publish.runtime_vendor._compile_runtime_module
            | project.compiler_host.ProjectHost.is_seed_source { is_seed_source },
        project.compiler_host.ProjectHost.is_native_only_source { is_native_only },
    ]
    bootstrap_manifest --> dist.precompile_bytecode.seal_finalize {
        is_native_only,
        is_seed_source
    }
    byllm._optdeps.litellm --> scale.admin.llm_telemetry.JacAPIServerLLMTelemetry.register_llm_telemetry_endpoints {
        HAS_LITELLM,
        when_litellm_loaded
    }
    comptime byllm.cli ++> cli.manifest { SPEC_MODEL }
    byllm.config_loader --> runtime.runtime.JacLLM.default_llm
        | studio.native_agent.NativeAgentSession.resolve_llm { get_byllm_config }
    byllm.exceptions --> runtime.runtime.JacLLM.default_llm { ConfigurationError }
    byllm.llm ++> runtime.runtime.JacLLM.by_operator { BaseLLM }
    byllm.llm --> runtime.runtime.JacLLM.default_llm
        | studio.native_agent.NativeAgentSession.resolve_llm { Model }
    byllm.mtir ++> [
        runtime.runtime.JacLLM.by._decorator._wrapped_caller { MTIR },
        runtime.runtime.JacLLM.get_mtir { MTIR },
    ]
    type byllm.mtir ++> runtime.runtime { MTRuntime }
    byllm.telemetry --> scale.admin.llm_telemetry.JacAPIServerLLMTelemetry.register_llm_telemetry_endpoints {
        register_agent_callback
    }
    byllm.visit_routing --> runtime.runtime.JacLLM.by_operator { route_visit }
    cache.home ++> cli.commands.cache { cache_home }
    cache.locking ++> scale.admin.console_build.AdminConsole._run { FileLock }
    cache.policy ++> [
        cli.commands.cache { format_bytes },
        cli.format_cache {
            DAY_SECONDS,
            Policy,
            SWEEP_INTERVAL_SECONDS,
            SWEEP_SENTINEL,
            maybe_sweep_dir
        },
        compiler.driver.jir.sweep_stale_generations { sweep_dir },
    ]
    cache.policy --> compiler.driver.jir._sweep_once { maybe_sweep_dir }
    cache.registry ++> [
        byllm.model_cache.get_cache_dir
            | compiler.driver.jir.sweep_stale_generations
            | compiler.types.stubcat.locate.dev_catalog_path
            | data.pg_dist.dist_cache_dir
            | dist.fused_binary._runtime_dir_for_key
            | packages.index.Registry._cache_file
            | packages.sources._mirror_dir
            | packages.store.materialize
            | project.package_scope.store_root
            | scale.admin.console_build.AdminConsole._note_hit
            | scale.injector.binary._scale_cache_root
            | server.session.shared_pg_data_dir
            | toolchains.android
            | toolchains.tools.ToolArtifact.checkout_path { bucket },
        cli.commands.cache { RETIRED, gc, purge, status, unmanaged },
        compiler.types.stubcat.locate.StubcatArtifact.build
            | project.compiler_host.ProjectHost.keep_native_scan_record
            | scale.injector.binary._fetch_verified_asset { maybe_sweep },
        dist.jab | toolchains.store { bucket, maybe_sweep },
        packages.index.fetch_verified | scale.admin.console_build.console_cache_dir {
            bucket
        },
    ]
    cache.registry --> [
        compiler.backends.native.link_plan._write_glue_symbols { maybe_sweep },
        compiler.driver.jir._sweep_once { bucket, maybe_sweep },
        compiler.driver.jir._touch_generation
            | compiler.types.stubcat.locate.StubcatArtifact.probe_checkout { bucket },
    ]
    cli.banners ++> server.server.JacAPIServer._ensure_client_bundle { JAC_DISCORD_URL }
    cli.cli_boot ++> jac0core.cli_boot { start_cli }
    cli.command ++> byllm.cli | client.cli | scale.plugin { Arg, ArgKind, CommandSpec }
    cli.commands.analysis ++> packages.publish.check_gate { check }
    cli.commands.execution ++> client.targets.web_target.WebTarget.start { serve }
    cli.commands.execution --> scale.tests.server.test_serve { _find_free_port }
    cli.commands.native_build ++> dist.seal.bake_native_payloads { native_build }
    cli.console ++> [
        byllm.cli
            | byllm.model_cache._emit
            | client.asset_processor
            | client.cli._npm_context
            | client.client_deps.prompt_install_client_deps
            | client.compiler
            | client.config_loader
            | client.desktop_config
            | client.jac_client_compiler
            | client.plugin_config._load_template
            | client.targets.client_dev_common
            | client.targets.desktop.cef_shell
            | client.targets.desktop.desktop_build
            | client.targets.desktop.native.cef.build
            | client.targets.desktop.webview_shell
            | client.targets.mobile_target
            | client.targets.node_tooling_common
            | client.targets.pwa_build
            | client.targets.react_native.build
            | client.targets.react_native.dev
            | client.targets.react_native.scaffold
            | client.targets.seo_build
            | client.targets.static_target
            | client.targets.web_target.WebTarget.dev
            | client.vite_bundler
            | compiler.driver.application.prepare_application
            | compiler.tools.lang_tools
            | dist.precompile_bytecode
            | dist.seal
            | dist.self_update
            | lsp.server.engine
            | lsp.server.server
            | packages.commands
            | packages.install
            | packages.publish
            | packages.verify
            | project.config._apply_build_section
            | project.config_schema.report_schema_findings
            | project.providers
            | project.pyvenv
            | project.template_loader
            | scale.deploy.target.factory.ensure_deploy_tooling
            | scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_client_bundle
            | scale.deploy.target.kubernetes.target.KubernetesTarget._wait_for_fleet_rollout
            | scale.deploy.target.kubernetes.utils.kubernetes_utils
            | scale.injector.binary_injector.select_injector
            | scale.observability.standard_logger
            | scale.plugin
            | scale.runtime.cli.plan
            | scale.runtime.orchestrator.orchestrator
            | scale.runtime.realizer.kubernetes_realizer
            | scale.utils.vendor_wheels
            | server.assembly
            | server.hmr
            | server.server.JacAPIServer._ensure_client_bundle
            | server.watcher
            | testing.cl_test_runner
            | testing.test
            | toolchains.android
            | toolchains.host
            | toolchains.manager
            | toolchains.store { console },
        client.cli.run_client_build
            | client.targets.web_target._copy_public_dirs
            | compiler.driver.application.prepare_dynamic_module
            | project.config._apply_memory_native_placement
            | scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._client_entry_rel
            | server.server.JacAPIServer.start { console },
        client.cli.run_client_setup
            | scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._install_app_deps
            | server.server.print_endpoint_docs { console },
        client.cli.run_client_start
            | scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._prepare_injector {
            console
        },
        client.cli.run_npm_add
            | scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._start_client_build {
            console
        },
        client.cli.run_npm_add_global { console },
        client.cli.run_npm_remove { console },
        client.cli.setup { console },
        runtime.runtime.JacBuiltin.get_console { JacConsole },
    ]
    cli.console --> [
        client.npm_provider.app_npm_deps._add
            | project.compiler_host.ProjectHost.note
            | project.config.JacConfig._write_toml_text
            | project.template_registry._register_builtin_client_templates { console },
        project.config._apply_serve_table
            | project.template_registry._register_builtin_shadcn_template { console },
    ]
    type cli.console ++> runtime.runtime { JacConsole as ConsoleImpl }
    cli.errmap --> scale.tests.server.test_serve { humanize_error }
    cli.manifest_route ++> [
        scale.injector.binary.deploy_generation_refusal
            | scale.tests.deploy.test_client_build_fail_fast
            | scale.tests.deploy.test_version_pin
            | server.sealed_serve.serve_manifest_stamp { resolve_cli_version },
        scale.injector.binary.host_toolchain_path { resolve_cli_version },
    ]
    cli.manifest_route --> scale.observability.prometheus_metrics.PrometheusMetricsCollector.__post_init__
        | scale.tests.deploy.test_memory_trigger_guard
        | scale.tests.misc.test_metrics { resolve_cli_version }
    cli.shadcn.cli --> project.template_registry._register_builtin_shadcn_template {
        register_project_template
    }
    cli.workpool ++> [
        compiler.backends.native.na_compile_pass.codegen_map {
            MEM_HEADROOM,
            memory_headroom_bytes
        },
        dist.precompile_bytecode._precompile_retire {
            WORKER_MEM_BYTES,
            env_int,
            maybe_malloc_trim,
            should_retire,
            worker_rss_mb
        },
        dist.precompile_bytecode.prebuild_native_units { WorkPool },
        dist.precompile_bytecode.precompile_native_unit { maybe_malloc_trim },
        dist.precompile_bytecode.precompile_unit_context { maybe_malloc_trim },
        dist.precompile_bytecode.run_precompile {
            WORKER_MEM_BYTES,
            WorkPool,
            env_int,
            forced_serial,
            jobs_setting,
            pool_available,
            resolve_jobs
        },
        dist.precompile_bytecode.seal_bootstrap {
            WORKER_MEM_BYTES,
            WorkPool,
            pool_available,
            resolve_jobs
        },
        scale.deploy.target.kubernetes.manifest_builder.client_build_alongside_seal {
            memory_headroom_bytes
        },
        server.server.JacAPIServer._validate_or_raise { cpu_quota },
        server.server.JacAPIServer.serve_background { cpu_quota },
        server.settings { cpu_quota, memory_headroom_bytes },
        testing.test_runner { WorkPool, should_retire as _should_retire },
        testing.test_runner._test_retire { env_int },
        testing.test_runner._test_rss_cap_mb { env_int },
        testing.test_runner.resolve_jobs { resolve_jobs as _resolve_pool_jobs },
    ]
    client ++> client.vite_bundler.ViteBundler.build { ensure_client_deps }
    client as _client_pkg ++> client.runtime_source.resolve_client_runtime_cl_path;
    client as _client_pkg --> project.modresolver._resolve_jac_virtual_module;
    client.artifact ++> server.server { ClientBundleError }
    client.artifact --> server.server.ModuleIntrospector.ensure_bundle {
        prebuilt_bundle
    }
    client.cli --> [
        cli.commands.build._build_app { run_client_build },
        cli.commands.execution.serve { run_client_start },
        cli.commands.project.install { run_npm_add },
        cli.commands.project.remove { run_npm_remove },
    ]
    comptime client.cli ++> cli.manifest { SPEC_SETUP }
    client.client_bundle ++> [
        compiler.driver.client_graph.collect_client_graph
            | dist.publish.npm_sources._link_modules
            | server.hmr.HotReloader._recompile_client_unified { ClientBundleError },
        compiler.tests.test_client_codegen_facts {
            _client_target_module,
            _ensure_js_generated
        },
        dist.source.client.write_client { client_program },
    ]
    type client.client_bundle ++> [
        compiler.driver.build_services | runtime.build_services { ClientBundleBuilder },
        runtime.runtime { ClientBundle, ClientBundleBuilder },
    ]
    client.client_diagnostics ++> [
        server.endpoints.pages.register_diagnostics_endpoints.client_error {
            log_client_error
        },
        server.hmr.HotReloader.record_client_event { classify_client_payload },
        server.hmr.HotReloader.record_error {
            build_failure_diagnostic,
            diagnostics_from_alerts
        },
        server.server.JacAPIServer._ensure_client_bundle { format_build_diagnostics },
    ]
    type client.client_diagnostics ++> server.hmr { ClientDiagnostic }
    client.client_surface ++> [
        compiler.backends.es.esast_gen_pass { WASM_HOST_MODULE },
        compiler.backends.es.esast_gen_pass.EsastGenPass._inject_runtime_import {
            runtime_import_source
        },
        compiler.backends.es.esast_gen_pass.EsastGenPass._jsx_fragment {
            backend_jsx_factory_name
        },
    ]
    client.client_surface --> server.hmr.HotReloader._recompile_client_code
        | testing.cl_test_runner._run_harness { prepend_active_runtime_globals }
    type client.compiler ++> runtime.prepared { ViteCompiler }
    client.config_loader --> [
        compiler.driver.application._prepare { JacClientConfig },
        compiler.driver.application._prepare_revision { JacClientConfig },
    ]
    client.desktop_plugin_config --> project.template_registry._register_builtin_client_templates {
        JacDesktopPluginConfig
    }
    client.jac_client_compiler ++> compiler.tests.xbackend_equiv.run_js_module_fixture {
        JacClientCompiler
    }
    client.js_runtime ++> [
        cli.commands.execution._run_node_tool
            | dist.seal.ensure_client_dist
            | testing.cl_test_runner._run_harness { js_runtime_path },
        dist.payload.fetch { BUN_VERSION },
        dist.payload.fetch.fetch_bun { _probe_bun, write_bun_record },
    ]
    client.js_runtime --> dist.payload.assemble._bundle_bun { write_bun_record }
    client.npm_provider ++> [
        dist.publish.npm_builder._react_peer_floor { CORE_RUNTIME_DEPS },
        dist.publish.runtime_npm._peer_versions {
            CORE_RUNTIME_DEPS,
            OPTIONAL_RUNTIME_DEPS
        },
    ]
    client.plugin_config --> project.providers.initialize_provider_registry
        | project.template_registry._register_builtin_client_templates {
        JacClientPluginConfig
    }
    client.preact_entry ++> compiler.backends.es.backends.preact.PreactBackend.build_entry_script {
        build_simple_preact_entry_script
    }
    client.react_entry ++> [
        compiler.backends.es.backends.react.ReactBackend.build_entry_script {
            build_simple_react_entry_script
        },
        compiler.backends.es.backends.react.ReactBackend.build_pages_entry_script {
            build_pages_react_entry_script
        },
    ]
    client.route_scanner --> compiler.driver.application.prepare_route_metadata {
        RouteScanner
    }
    client.runtime_source ++> [
        dist.publish.runtime_npm._runtime_source_path {
            resolve_client_runtime_cl_path
        },
        dist.publish.runtime_npm.build_runtime_tarball {
            resolve_client_runtime_cl_path
        },
        dist.publish.runtime_npm.runtime_pkg_name { client_runtime_cl_basename },
    ]
    client.runtime_source --> project.modresolver._resolve_jac_virtual_module {
        jac_virtual_module_basenames,
        resolve_client_runtime_cl_path
    }
    client.serving ++> [
        runtime.runtime.JacServe.get_client_js { JacClient },
        runtime.runtime.JacServe.render_page { JacClient },
    ]
    client.solid_entry ++> [
        compiler.backends.es.backends.solid.SolidBackend.build_entry_script {
            build_simple_solid_entry_script
        },
        compiler.backends.es.backends.solid.SolidBackend.build_pages_entry_script {
            build_pages_solid_entry_script
        },
    ]
    client.source_mapping ++> [
        scale.tests.server.test_build_status_endpoint._reset_client_globals {
            _error_rate_limiter,
            _locator_cache,
            _mapper_cache
        },
        server.endpoints.pages.register_diagnostics_endpoints {
            ClientErrorLimiter,
            is_extension_report
        },
        server.hmr.HotReloader.record_client_event { _error_rate_limiter },
    ]
    client.targets.desktop.desktop_build --> toolchains.manager.setup_toolchain {
        _find_cef_dir,
        _find_webview_dir
    }
    client.targets.react_native.html_tag_map --> compiler.passes.jsx_intrinsic_guard_pass._suggestion_for {
        rn_tag_suggestions
    }
    client.targets.web_target ++> [
        dist.seal.ensure_client_dist { WebTarget },
        dist.seal.finish_prepared_client { WebTarget },
    ]
    client.vite_bundler ++> [
        compiler.driver.application._prepare_revision
            | dist.seal.sealed_image_key
            | scale.injector.bundle.client_input_digest { client_build_env },
        dist.source.client.write_client { ViteBundler },
        scale.injector.bundle.seal_input_digest { client_build_env },
    ]
    client.vite_bundler --> [
        cli.commands.execution._start_vite_dev_server { ViteBundler },
        cli.commands.execution.serve._announce_ready { DEV_PROXY_PREFIXES },
    ]
    client.vite_client_bundle ++> compiler.driver.build_services.CompilerBuildServices.client_builder {
        make_client_bundle_builder
    }
    client.vite_client_bundle --> compiler.driver.application._prepare_revision {
        make_client_bundle_builder
    }
    compiler ++> cli.commands.analysis.gen_parser { gen_all_parsers }
    compiler.backends.es.backends.registry ++> [
        client.client_surface.prepend_active_runtime_globals
            | client.compiler.ViteCompiler._create_pages_entry_content
            | client.jac_to_js.JacToJSCompiler.add_runtime_imports {
            resolve_active_backend
        },
        client.compiler.ViteCompiler.create_entry_file { resolve_active_backend },
    ]
    compiler.backends.es.backends.registry --> client.vite_bundler.ViteBundler._generate_vite_config_content {
        resolve_active_backend
    }
    compiler.backends.es.client_kernel_cache ++> project.compiler_host.ProjectHost.client_osp_core_js {
        osp_core_js
    }
    compiler.backends.es.client_paths ++> [
        client.jac_client_compiler { client_output_path, jac_js_path },
        client.targets.react_native.build { jac_js_path },
    ]
    type compiler.backends.es.framework_backend ++> client.client_surface {
        FrameworkBackend
    }
    compiler.backends.es.free_ident_audit ++> client.client_surface.with_runtime_globals {
        js_identifiers,
        js_top_level_declarations
    }
    compiler.backends.es.jac_runtime_js ++> [
        client.jac_client_compiler.JacClientCompiler.emit_prelude {
            write_jac_prelude_file
        },
        client.vite_bundler.ViteBundler._generate_vite_config_content {
            JAC_PRELUDE_BASENAME
        },
        dist.publish.runtime_npm._point_at_packaged_prelude {
            JAC_PRELUDE_BASENAME,
            JAC_PRELUDE_MODULE
        },
        dist.publish.runtime_npm.build_runtime_tarball {
            JAC_PRELUDE_BASENAME,
            build_jac_prelude_module
        },
        testing.cl_test_runner._point_at_staged_prelude { point_jac_prelude_at },
    ]
    compiler.backends.es.jac_runtime_js --> testing.cl_test_runner._run_harness {
        JAC_PRELUDE_BASENAME,
        build_jac_prelude_module
    }
    compiler.backends.es.js_paths --> project.modresolver.resolve_module {
        convert_to_js_import_path
    }
    compiler.backends.native.c_emit ++> dist.source.client.write_client { emit_c }
    compiler.backends.native.c_emit --> dist.native_product.write_native_product {
        emit_c
    }
    compiler.backends.native.floors ++> dist.payload.vendor { WASM_FLOOR_MANIFEST }
    compiler.backends.native.host_facts --> project.compiler_host.ProjectHost.native_fact {
        host_native_fact
    }
    compiler.backends.native.link_plan ++> [
        cli.commands.native_build { LinkPlan },
        cli.commands.native_build.native_build {
            ArtifactKind,
            LinkPlanError,
            build_link_plan,
            link_artifact
        },
        dist.native_product.write_native_product {
            ArtifactKind,
            build_link_plan,
            link_artifact,
            optimize_merged_program,
            unique_callbacks,
            whole_program_module
        },
        dist.precompile_bytecode.prebuild_native_closure { build_link_plan },
        dist.precompile_bytecode.seal_native {
            ArtifactKind,
            build_link_plan,
            link_artifact
        },
    ]
    compiler.backends.native.llvm.binding --> project.compiler_host.ProjectHost.default_target_triple {
        get_default_triple
    }
    compiler.backends.native.llvm.binding as llvm ++> cli.commands.native_build._application_ir;
    compiler.backends.native.llvm.binding as llvm --> cli.commands.execution._jab_native_bin
        | dist.seal.bake_native_payloads;
    type compiler.backends.native.llvm.binding.executionengine ++> cli.commands.execution {
        ExecutionEngine
    }
    compiler.backends.native.llvm.shim_path ++> dist.payload.assemble.assemble_site {
        write_shim_record
    }
    compiler.backends.native.na_compile_pass ++> cli.commands.analysis.explain {
        native_linked_ir_text
    }
    compiler.backends.native.wasm_artifact ++> client.compiler.ViteCompiler._compile_wasm_module {
        wasm_assets
    }
    compiler.backends.native.wasm_artifact --> dist.source.build.build_native_product {
        rename_wasm_imports,
        wasm_assets,
        wasm_ld_args,
        wasm_object_functions,
        write_allowed_imports
    }
    compiler.backends.native.wasm_build ++> dist.source.client.write_client {
        prepare_wasm_module
    }
    compiler.backends.native.wasm_build --> [
        cli.commands.native_build.native_build { app_declared_imports },
        dist.native_product.write_native_product { _assert_ir_rc_free },
    ]
    compiler.backends.native.wasm_host_abi --> dist.source.build.build_native_product {
        WASM_HOST_ABI,
        WASM_HOST_MODULE
    }
    compiler.backends.py.artifact_imports ++> dist.precompile_bytecode.seal_runtime_closure {
        runtime_sources
    }
    compiler.backends.py.codegen_shim ++> cli.commands.transform.jac2py
        | cli.mcp.compiler_bridge.CompilerBridge.jac_to_py._do_jac2py {
        generated_python
    }
    compiler.boundary_audit ++> client.compiler.ViteCompiler.prepare_bundle {
        boundary_audit
    }
    compiler.driver.application ++> cli.commands.execution._load_executable
        | dist.seal.prepare_serve_payloads
        | dist.source.project.export_project
        | scale.tests.data.test_eager_spawn
        | scale.tests.microservices.test_microservice
        | scale.tests.server.test_host_serving
        | scale.tests.server.test_served_app_route
        | scale.tests.server.test_sv_outbox_endpoints { prepare_application }
    compiler.driver.application --> [
        cli.commands.execution.serve
            | client.targets.client_dev_common.dev_proxy_paths
            | scale.server.inprocess.prepare_inprocess_runtime { prepare_application },
        server.hmr.HotReloader._reload_server_module { reprepare_application },
    ]
    compiler.driver.bccache ++> [
        cli.commands.analysis._annex_moves
            | project.compiler_host.ProjectHost.base_file
            | server.hmr
            | studio.intel
            | testing.cl_test_runner.module_entry_for { discover_base_file },
        cli.commands.analysis._check_file_job { discover_base_file },
        cli.commands.analysis._drop_covered_annexes { discover_base_file },
        cli.commands.analysis._float_impls_to_annex
            | cli.commands.architecture
            | project.compiler_host.ProjectHost.annex_files
            | toolchains.desktop.module_files { discover_annex_files },
        cli.commands.analysis._unit_weight { discover_annex_files },
        cli.commands.analysis._with_annex_owners { discover_base_file },
        lsp.server.engine | studio.intel_server {
            discover_annex_files,
            discover_base_file
        },
        project.compiler_host.ProjectHost.is_annex_path_of { host_layout_tables },
        project.compiler_host.ProjectHost.package_init { host_layout_tables },
        project.compiler_host.ProjectHost.path_facts { host_layout_tables },
    ]
    compiler.driver.bccache --> [
        cli.commands.analysis._format_single_file_worker { discover_annex_files },
        cli.commands.analysis.lint.lint_fix_file { discover_annex_files },
        cli.commands.analysis.precommit { discover_annex_files },
        testing.test_runner._suite_source { discover_base_file },
    ]
    compiler.driver.client_graph ++> [
        client.jac_client_compiler.JacClientCompiler._module_text { append_link },
        client.jac_client_compiler.JacClientCompiler.emit_dependencies
            | dist.publish.npm_sources._link_modules { collect_client_graph },
        dist.publish.npm_sources.collect_npm_sources {
            ClientLink,
            append_link,
            link_tail
        },
    ]
    type compiler.driver.client_graph ++> client.jac_client_compiler
        | dist.publish.npm_sources { ClientLink }
    compiler.driver.compilation_context ++> [
        dist.precompile_bytecode._application_sources { bind_options },
        dist.precompile_bytecode.precompile_context { bind_options, context_program },
        dist.precompile_bytecode.precompile_unit_context
            | project.compiler_host.ProjectHost.drop_python_lane_products {
            cache_scope,
            owner_scope_options
        },
        packages.api.package_surface { compilation_scope },
        project.compiler_host.ProjectHost.lint_settings { context_app },
    ]
    compiler.driver.compilation_context --> client.client_bundle.client_context_program {
        context_program
    }
    compiler.driver.compile_options ++> [
        cli.commands.analysis._check_file_job
            | cli.mcp.compiler_bridge.CompilerBridge.typecheck_snippet._do_typecheck
            | dist.precompile_bytecode._application_sources
            | dist.publish.builder._module_is_client_source
            | dist.publish.npm_sources._compile_module
            | dist.publish.runtime_vendor
            | dist.seal
            | packages.api.package_surface
            | studio.gate
            | testing.cl_test_runner.module_is_client { CompileOptions },
        cli.commands.analysis.explain
            | dist.precompile_bytecode.prebuild_native_closure { CompileOptions },
        cli.commands.analysis.grammar | dist.precompile_bytecode.precompile_context {
            CompileOptions
        },
        cli.commands.native_build._restore_target { pop_native_target },
        cli.commands.native_build.native_build {
            CompileOptions,
            NATIVE_LINK_MODES,
            push_native_target
        },
        dist.precompile_bytecode.precompile_native_unit { CompileOptions },
        dist.precompile_bytecode.seal_native { CompileOptions },
        lsp.server.engine | studio.intel_server { CancelToken },
    ]
    compiler.driver.compile_options --> [
        cli.commands.execution._exec_file { CompileOptions as _RunOpts },
        lsp.server.engine.JacLangServer.type_check_file { CompileOptions },
    ]
    type compiler.driver.compile_options ++> project.compiler_host { CompileOptions }
    compiler.driver.compiler ++> [
        cli.commands.analysis.check { CHECK_GC_THRESHOLDS },
        cli.mcp.compiler_bridge.CompilerBridge.lint_snippet._do_lint
            | project.compiler_host.ProjectHost.format_file { JacCompiler },
        dist.precompile_bytecode.run_precompile { COMPILE_GC_THRESHOLDS },
        project.compiler_host.ProjectHost.client_pulls { cached_client_pulls },
        project.compiler_host.ProjectHost.format_source { JacCompiler },
        project.compiler_host.ProjectHost.lint_file { JacCompiler },
    ]
    compiler.driver.compiler --> project.compiler_host.ProjectHost.compiler_for {
        JacCompiler
    }
    type compiler.driver.compiler ++> project.compiler_host
        | runtime.build_services
        | runtime.runtime { JacCompiler }
    compiler.driver.ifacecache --> [
        cli.commands.analysis.check { prime_iface_codec },
        dist.precompile_bytecode._unit_extra { DIAG_SCHEMA, IfaceRegistry },
        lsp.server.engine.JacLangServer._fanout_dependents { seed_dep_edges },
        project.compiler_host.ProjectHost.iface_registry_for { IfaceRegistry },
    ]
    type compiler.driver.ifacecache ++> project.compiler_host { IfaceRegistry }
    compiler.driver.jir ++> [
        client.client_bundle.ClientBundleBuilder._signature { ct_dep_digest },
        client.compiler.ViteCompiler._compile_wasm_module { ct_dep_text_fresh },
        client.compiler.ViteCompiler._wasm_input_key {
            ct_dep_digest,
            running_compiler_digest
        },
        client.jac_client_compiler.JacClientCompiler.emit_dependencies {
            compute_content_sha256,
            ct_dep_digest
        },
        client.targets.desktop._dev_launch._dev_roots_from_env { dev_source },
        dist.precompile_bytecode {
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
            require_exact_compiler_products,
            running_compiler_digest,
            write_precompiled_jir
        },
        dist.precompile_bytecode._native_extra {
            NativeStamp,
            SEC_NCTDEPS,
            native_section_variants,
            pack_native_variants
        },
        dist.precompile_bytecode.run_precompile { read_debug_source },
        dist.precompile_bytecode.seal_native {
            native_section_payload,
            read_section_bytes as _rsb
        },
        dist.precompiled.bundle_misses {
            jir_cacheable_source_path,
            precompiled_jir_matches_source
        },
        dist.seal.sealed_image_key { running_compiler_digest },
        packages.artifact.package_manifest | packages.resolve.resolve_graph {
            jaclang_version
        },
        packages.resolve.running_jac_version { jaclang_version },
        project.compiler_host.ProjectHost.drop_python_lane_products {
            drop_python_lane_products
        },
        project.compiler_host.ProjectHost.in_compiler_tree { is_compiler_tree_path },
        project.compiler_host.ProjectHost.save_native_debug_ir { get_native_debug_dir },
        project.compiler_host._native_scan_path {
            get_jir_cache_dir,
            module_env_fingerprint
        },
        project.compiler_host._wiring_records_path {
            get_jir_cache_dir,
            running_compiler_digest
        },
        scale.tests.microservices.test_seed_determinism {
            FLAG_PRECOMPILED,
            compiler_source_digest,
            compiler_source_files,
            compute_module_key,
            compute_precompile_module_key,
            module_cache_key,
            precompiled_jir_matches_source,
            running_compiler_digest,
            write_precompiled_jir
        },
    ]
    compiler.driver.jir --> [
        cli.commands.cache._live_keys { compiler_generation },
        cli.commands.execution._exec_file { scrub_cache_dirs },
        dist.payload.assemble.assemble_site { write_compiler_identity },
        dist.precompile_bytecode._native_extra { rebase_placement_section },
        dist.precompile_bytecode._precompile_unit { cache_mode },
    ]
    compiler.driver.jir as jir --> scale.tests.microservices.test_seed_determinism;
    compiler.driver.na_coverage ++> project.compiler_host.ProjectHost.record_native_coverage {
        na_coverage_record
    }
    compiler.driver.na_coverage --> [
        cli.commands.analysis._check_file_job {
            na_coverage_begin,
            na_coverage_snapshot
        },
        cli.commands.analysis.check { na_coverage_end },
    ]
    compiler.driver.native_iface ++> dist.precompile_bytecode.seal_native {
        NativeIface
    }
    type compiler.driver.native_iface ++> project.compiler_host { NativeIface }
    compiler.driver.nativecache --> project.compiler_host.ProjectHost.native_units_for {
        NativeUnitRegistry
    }
    type compiler.driver.nativecache ++> project.compiler_host { NativeUnitRegistry }
    compiler.driver.pipeline ++> [
        cli.commands.analysis.grammar
            | cli.commands.transform.py2jac
            | project.compiler_host.ProjectHost.parse_python { run_utility },
        dist.publish.npm_sources._compile_module { CompilationProduct, require },
    ]
    compiler.driver.pipeline as pipeline --> scale.tests.apps.test_fleet_from_apps;
    compiler.driver.pipeline_runner ++> [
        client.compiler.ViteCompiler._compile_wasm_module { wasm_artifact_inputs },
        client.route_scanner.resolve_route_exports { route_exports },
        dist.precompile_bytecode._application_sources { compile_application },
        dist.source.client.write_client { wasm_ir },
    ]
    compiler.driver.pipeline_runner --> [
        cli.commands.analysis._check_file_job { compile_application },
        dist.source.project.export_project { native_application },
    ]
    compiler.driver.pipeline_types ++> cli.commands.analysis.grammar
        | cli.commands.transform.py2jac
        | project.compiler_host.ProjectHost.parse_python { CompilationProduct }
    compiler.driver.program ++> [
        cli.commands.analysis._annex_moves
            | cli.commands.architecture
            | cli.commands.fix._client_imports
            | cli.commands.native_build.native_build
            | cli.commands.transform.jac2js
            | cli.mcp.compiler_bridge.CompilerBridge.get_ast_snippet._do_ast
            | dist.native_product.write_native_product
            | dist.precompile_bytecode._application_sources
            | dist.publish.npm_sources.collect_npm_sources
            | dist.publish.runtime_npm._compile_cl_to_js
            | dist.publish.runtime_vendor
            | dist.seal
            | dist.source.project
            | lsp.server.engine
            | lsp.server.module_manager
            | packages.api.package_surface
            | server.hmr.HotReloader._classify_declarations
            | studio.gate
            | studio.model
            | testing.cl_test_runner.compile_cl_module
            | testing.test_runner._fresh_jac_state { JacProgram },
        cli.commands.analysis._check_file_job
            | cli.commands.fix._format_source
            | cli.commands.transform.jac2py
            | cli.mcp.compiler_bridge.CompilerBridge.jac_to_js._do_jac2js
            | dist.precompile_bytecode.prebuild_native_closure
            | testing.cl_test_runner.module_is_client { JacProgram },
        cli.commands.analysis._float_impls_to_annex
            | cli.commands.fix._verify_claims
            | cli.commands.transform.py2jac
            | cli.mcp.compiler_bridge.CompilerBridge.jac_to_py._do_jac2py
            | dist.precompile_bytecode.precompile_native_unit { JacProgram },
        cli.commands.analysis._format_single_file_worker
            | cli.mcp.compiler_bridge.CompilerBridge.parse_snippet._do_parse
            | dist.precompile_bytecode.precompile_unit_context { JacProgram },
        cli.commands.analysis.explain
            | cli.mcp.compiler_bridge.CompilerBridge.py_to_jac._do_py2jac
            | dist.precompile_bytecode.seal_native { JacProgram },
        cli.commands.analysis.grammar
            | cli.mcp.compiler_bridge.CompilerBridge.typecheck_snippet._do_typecheck {
            JacProgram
        },
        cli.commands.analysis.lint { JacProgram },
        dist.publish.builder._backend_source { JacProgram as JacProgramRt },
        dist.publish.builder._module_is_client_source { JacProgram as JacProgramRt },
    ]
    compiler.driver.program --> [
        dist.precompile_bytecode.sealable_sources
            | scale.tests.apps.test_fleet_from_apps { JacProgram },
        dist.publish.builder.WheelBuilder._assemble_src_data {
            JacProgram as JacProgramRt
        },
    ]
    type compiler.driver.program ++> client.client_bundle
        | client.compiler
        | client.vite_client_bundle
        | dist.native_product
        | dist.precompile_bytecode
        | dist.publish.builder
        | project.compiler_host
        | runtime.build_services
        | runtime.runtime { JacProgram }
    type compiler.driver.selfhost ++> runtime.build_services | runtime.runtime {
        SelfHostCache
    }
    compiler.driver.source_failures ++> [
        dist.precompile_bytecode._emit_unit_diagnostics {
            compiler_source_failure_details
        },
        project.compiler_host.ProjectHost.import_in_flight { module_import_in_flight },
        project.compiler_host.ProjectHost.schedule_import_failed {
            fail_loud_on_compiler_source
        },
    ]
    compiler.driver.source_failures --> [
        project.compiler_host.ProjectHost.load_modules { fail_loud_on_compiler_source },
        testing.cl_test_runner.module_is_client {
            CompilerSourceError,
            compiler_source_failure_origin
        },
    ]
    compiler.driver.source_products ++> [
        dist.publish.builder { python_text },
        dist.publish.runtime_vendor._compile_runtime_module {
            python_source,
            python_text
        },
        dist.source.project { python_source },
    ]
    compiler.driver.toolchain ++> dist.precompile_bytecode.seal_native
        | project.compiler_host.ProjectHost.native_pipeline_available {
        native_pipeline_available
    }
    compiler.driver.wiring ++> [
        cli.commands.architecture {
            ARCH_FILE_NAME,
            WireBinding,
            WiringSpec,
            arch_file_for,
            is_positional_import,
            propose_rules,
            render_wiring,
            rule_text,
            scope_path_of,
            wiring_facts,
            wiring_for_path
        },
        dist.payload.assemble.ship_wiring { ARCH_FILE_NAME, prune_wiring_source },
        dist.precompile_bytecode.find_jac_files { is_arch_file },
        project.compiler_host.ProjectHost.place_wired_imports { place_wired_imports },
        project.compiler_host.ProjectHost.session { wiring_scope },
        project.compiler_host.ProjectHost.wiring_file { arch_file_for, is_arch_file },
        studio.gate {
            WireRec,
            WiringSpec,
            arch_file_for,
            is_arch_file,
            parse_records,
            rule_text,
            wiring_facts,
            wiring_for_path
        },
        studio.model { ARCH_FILE_NAME, WiringSpec, wiring_for_path },
    ]
    compiler.driver.wiring as wiring_mod ++> studio.gate;
    compiler.frontend.codeinfo ++> [
        cli.check_report.print_native_coverage { effective_default_codespace },
        cli.commands.execution._count_jac_files
            | server.watcher.JacFileWatcher._on_change { is_compiler_source_path },
        cli.commands.execution._exec_file | dist.precompile_bytecode.served_codespace {
            get_effective_default_codespace_override,
            set_effective_default_codespace
        },
        cli.commands.execution.serve { set_effective_default_codespace },
        cli.commands.native_build._application_ir { is_toolchain_unit },
        client.compiler.ViteCompiler._compile_wasm_module
            | dist.source.client.write_client { native_wasm_stem },
        client.js_runtime._pkg_dir
            | dist.precompile_bytecode.is_toolchain_package
            | dist.precompiled._pkg_dir { jaclang_pkg_root },
        client.vite_client_bundle { ClientArtifact },
        dist.publish.npm_sources._link_modules { ClientArtifact, ClientManifest },
        dist.publish.runtime_vendor._runtime_module_options {
            is_native_by_location,
            is_shared_runtime_module
        },
        project.compiler_host.ProjectHost.ct_environment { effective_native_target },
        runtime.portability { NATIVE_SUPPORTED_STDLIB, is_bundled_native_module },
        server.watcher.watch_roots { is_compiler_source_path },
    ]
    compiler.frontend.codeinfo --> [
        cli.check_report.print_native_coverage { native_display_text },
        project.compiler_host.ProjectHost.client_stub_globals { jaclang_pkg_root },
    ]
    type compiler.frontend.codeinfo ++> client.client_bundle
        | client.compiler
        | client.jac_client_compiler
        | client.jac_to_js { ClientArtifact, ClientManifest }
    compiler.frontend.constant ++> [
        cli.commands.fix._priv_top_decls { SymbolAccess },
        dist.publish.builder._module_is_client_source
            | server.hmr
            | testing.cl_test_runner.module_is_client { CodeContext },
        lsp.server.engine { TOKEN_MAP },
        lsp.server.server {
            JacSemTokenModifier as SemTokMod,
            JacSemTokenType as SemTokType
        },
        packages.api { SymbolAccess, SymbolType },
        studio.intel_server { JacSemTokenModifier, JacSemTokenType },
    ]
    compiler.frontend.diagnostic_utils ++> cli.commands.analysis.check {
        resolve_diagnostic_tokens
    }
    compiler.frontend.diagnostics ++> client.client_diagnostics._diag { DIAGNOSTICS }
    compiler.frontend.host ++> [
        cli.commands.architecture { active_host },
        project.compiler_host {
            CheckSettings,
            HostPlatform,
            HostServices,
            LintSettings,
            PathFacts,
            ProjectDefaults,
            ProjectFacts
        },
        project.compiler_host.ProjectHost.native_fact {
            HOST_FACT_GIT_IGNORED,
            HOST_FACT_SEP,
            HOST_FACT_STDLIB_MODULES
        },
        studio.gate { active_host, install_host },
    ]
    compiler.frontend.parser ++> [
        cli.commands.fix._parse_module { parse as rd_parse },
        cli.commands.fix._parses_clean { parse as rd_parse },
    ]
    compiler.frontend.parser.frontend ++> [
        cli.commands.architecture._parse_imports | studio.gate { parse_woven },
        project.compiler_host.ProjectHost.woven_module { annex_sources, parse_woven },
        studio.model { annex_sources, parse },
    ]
    compiler.frontend.parser.frontend --> cli.commands.analysis._check_file_job
        | lsp.server.engine.JacLangServer.type_check_file { _replay_diags, parse_diags }
    compiler.frontend.parser.lexer ++> [
        cli.commands.fix._strip_markers { tokenize },
        lsp.server.engine | studio.intel { tokenize_full },
    ]
    compiler.frontend.parser.lexer --> [
        cli.commands.analysis._check_file_job { Lexer },
        lsp.server.engine.JacLangServer.type_check_file { Lexer as _Lexer },
    ]
    compiler.frontend.parser.parser --> cli.commands.analysis._check_file_job
        | lsp.server.engine.JacLangServer.type_check_file { Parser as _SyntaxParser }
    compiler.frontend.parser.tokens ++> [
        cli.commands.fix { LexToken },
        lsp.server.engine { TokenKind },
    ]
    compiler.frontend.source_layout ++> [
        project.compiler_host.ProjectHost.is_annex_path_of { is_annex_path_of },
        project.compiler_host.ProjectHost.package_init { package_init_of },
        project.compiler_host.ProjectHost.path_facts { path_facts_of },
    ]
    compiler.frontend.srcloc ++> [
        lsp.server.utils { CodeLocInfo, Span },
        project.textio.span_for_file { Span as SrcSpan },
    ]
    type compiler.frontend.srcloc ++> project.source | project.textio { Span }
    compiler.frontend.unitree ++> [
        cli.commands.architecture { Import },
        dist.publish.dts {
            Ability,
            Archetype,
            AstTypedVarNode,
            FuncSignature,
            GlobalVars,
            Module,
            UniNode
        },
        dist.publish.jsdoc { Ability, FuncSignature, Module, ParamVar, UniNode },
        lsp.server.engine { UniScopeNode },
        lsp.server.utils { Symbol, UniScopeNode },
        packages.api { HasVar, Module, Symbol },
    ]
    compiler.frontend.unitree --> cli.commands.analysis._check_file_job
        | lsp.server.engine.JacLangServer.type_check_file { Source as _Src }
    compiler.frontend.unitree as uni ++> [
        cli.commands.fix._access_plan
            | cli.commands.transform.py2jac
            | lsp.server.engine
            | lsp.server.module_manager
            | lsp.server.sem_manager
            | lsp.server.utils
            | project.compiler_host.ProjectHost.parse_python
            | studio.gate
            | studio.intel_server
            | studio.model,
        cli.commands.fix._client_imports,
        cli.commands.fix._imported_names,
        cli.commands.fix._module_has_jsx,
        cli.commands.fix._plain_top_decls,
        cli.commands.fix._priv_top_decls,
    ]
    type compiler.frontend.unitree ++> client.client_bundle
        | dist.native_product
        | project.compiler_host { Module }
    compiler.frontend.unparse ++> dist.publish.dts
        | dist.publish.jsdoc
        | lsp.server.engine
        | studio.gate
        | studio.model { unparse_node }
    compiler.passes.annex_weave ++> [
        cli.commands.architecture { import_form },
        studio.model { merge_annex_into },
    ]
    compiler.passes.context ++> lsp.server.utils { Alert }
    type compiler.passes.context ++> client.client_diagnostics
        | lsp.server.engine
        | server.hmr { Alert }
    compiler.passes.import_wiring_pass ++> cli.commands.architecture {
        unused_wire_bindings
    }
    compiler.passes.ownership_hints ++> lsp.server.engine.JacLangServer.get_inlay_hints {
        inferred_hints
    }
    compiler.passes.ownership_hints --> cli.commands.analysis.explain { inferred_hints }
    compiler.placement.placement ++> cli.commands.fix._verify_claims {
        element_display_name
    }
    compiler.placement.placement_export --> [
        cli.commands.analysis._check_file_job { collect_placement_rows },
        cli.commands.analysis.explain { collect_placement_rows },
        dist.precompile_bytecode._unit_extra { summary_from_bytes, summary_to_bytes },
    ]
    compiler.placement.placement_facts ++> [
        dist.precompile_bytecode._application_sources {
            module_spaces,
            spaces_are_client_only
        },
        dist.precompile_bytecode.find_jac_files { native_only },
        dist.precompile_bytecode.package_native_units { native_units_of },
        dist.publish.runtime_vendor._compile_runtime_module
            | testing.cl_test_runner.module_is_client { module_record },
        dist.publish.runtime_vendor._runtime_module_options { SPACE_SERVER },
    ]
    compiler.placement.placement_facts --> [
        dist.precompile_bytecode.run_precompile { native_only },
        dist.precompile_bytecode.sealable_sources {
            discover_spaces,
            spaces_are_client_only
        },
        project.compiler_host.ProjectHost.native_session_declares {
            session_declares_native
        },
    ]
    compiler.placement.placement_pins ++> [
        lsp.server.engine.JacLangServer._module_spec_target { in_client_npm_world },
        lsp.server.engine.JacLangServer._npm_item_location { in_client_npm_world },
    ]
    compiler.placement.placement_pins --> scale.tests.microservices.test_app_precompile {
        config_module_pin
    }
    compiler.placement.placement_solver ++> dist.seal.bake_native_payloads {
        native_default_path_ok
    }
    compiler.target_spec ++> dist.precompile_bytecode._shared_suffix {
        host_target_spec
    }
    compiler.target_spec --> dist.precompile_bytecode.seal_native { host_target_spec }
    compiler.tools.code_intel ++> cli.commands.code | studio.native_agent {
        CodeIntelligence
    }
    compiler.tools.grammar_extract_pass ++> cli.commands.analysis.grammar {
        GrammarExtractPass
    }
    compiler.tools.jac_formatter_pass ++> cli.commands.transform.py2jac
        | cli.mcp.compiler_bridge { unparse_module }
    compiler.tools.lang_tools ++> cli.commands.tools.tool { AstTool }
    compiler.tools.treeprinter ++> cli.mcp.compiler_bridge {
        node_to_dict,
        print_ast_tree
    }
    compiler.types.ct_value ++> project.compiler_host.ProjectHost.ct_environment {
        CtEnvironment
    }
    type compiler.types.ct_value ++> project.compiler_host { CtEnvironment }
    compiler.types.stubcat.locate as locate --> dist.payload.assemble.cached_stubcat;
    compiler.types.stubcat.modiface ++> dist.precompile_bytecode.precompile_unit_context;
    type compiler.types.stubcat.reader ++> project.compiler_host { StubCatalog }
    compiler.types.stubcat.writer ++> dist.precompile_bytecode.precompile_unit_context;
    compiler.types.type_evaluator ++> dist.precompile_bytecode.precompile_unit_context;
    compiler.types.type_utils ++> lsp.server.utils { compute_mro_linearization }
    compiler.types.types ++> [
        lsp.server.engine {
            ClassType,
            FunctionType,
            ModuleType,
            OverloadedType,
            TypeBase
        },
        lsp.server.utils { ClassType, ModuleType, TypeBase },
        packages.api { ClassType, FunctionType },
    ]
    comptime ++> [
        byllm.cli
            | cli.commands.analysis
            | cli.commands.architecture
            | cli.commands.browse
            | cli.commands.build
            | cli.commands.cache
            | cli.commands.code
            | cli.commands.config
            | cli.commands.db
            | cli.commands.execution
            | cli.commands.fix
            | cli.commands.guide
            | cli.commands.mcp
            | cli.commands.native
            | cli.commands.precompile
            | cli.commands.project
            | cli.commands.studio
            | cli.commands.tools
            | cli.shadcn.cli
            | client.cli
            | scale.plugin { name as ct_name },
        cli.manifest { module_of },
        client.desktop_config
            | scale.config.base_config
            | scale.deploy.target.kubernetes.kubernetes_config
            | scale.scheduler.scheduler { fields, get_field },
        scale.scheduler.scheduler_models
            | scale.tests.misc.test_config_loader
            | scale.tests.misc.test_config_validation
            | server.identity.auth_models { fields },
    ]
    data.dbcatalog ++> [
        cli.commands.db { DbRecord, MAINTENANCE_DB },
        cli.commands.db._db_drop { is_jac_database },
        cli.commands.db._db_prune {
            condemn_abandoned,
            connect_admin,
            drop_database,
            drop_if_still_dead,
            list_databases,
            pardon_recovered
        },
        cli.commands.db._prune_candidates { holds_no_data },
        cli.commands.db._runtime_for { DbKind },
        server.session { DbKind, MAINTENANCE_DB, SCRATCH_PREFIX, stop_heartbeat },
        server.session.drop_owned_databases {
            connect_admin,
            drop_database,
            owned_databases
        },
        server.session.own_child_databases { process_alive, this_host },
    ]
    data.dbcatalog --> client.targets.desktop.native.host_boot._migrate_legacy_database {
        MAINTENANCE_DB,
        connect_admin,
        list_databases,
        rename_database
    }
    data.pg_dist ++> cli.commands.db._db_fetch { download_dist }
    data.pg_dist --> client.targets.desktop.desktop_build.stage_postgres {
        bundled_dist_dir,
        cached_dist_dir
    }
    data.pgembed ++> [
        cli.commands.db._catalog_runtime
            | scale.tests.data.test_pg_stream
            | scale.tests.server.test_backplane
            | scale.tests.server.test_pg_job_store
            | scale.tests.server.test_registration_limits
            | scale.tests.server.test_scheduler_multipod
            | server.session { PgRuntime },
        cli.commands.db._runtime_for { PgRuntime },
        scale.tests.deploy.test_postgres_predicate_lock_headroom {
            PG_MAX_CONNECTIONS,
            PG_MAX_PRED_LOCKS_PER_TXN,
            pg_tuning_settings,
            predicate_lock_shortfall
        },
    ]
    data.pgembed --> [
        client.targets.desktop.native.host_boot._migrate_legacy_database
            | scale.tests.data.test_auth_cutover
            | scale.tests.deploy.test_postgres_predicate_lock_headroom { PgRuntime },
        client.targets.desktop.native.host_boot._stop_embedded_store { stop_cluster },
        scale.deploy.database.kubernetes_postgres.KubernetesPostgresProvider.deploy {
            pg_tuning_settings
        },
    ]
    data.pgpool ++> runtime.runtime.JacRuntime.after_fork_in_child
        | server.shared_store._after_fork_in_child { detach }
    data.pgwire ++> cli.errmap.humanize_error
        | scale.server.jobs_ext
        | scale.tests.server.test_health_fail_soft
        | scale.tests.server.test_scheduler_endpoints { PgWireError }
    data.query_planner ++> [
        runtime.graph_utils.graph_neighbors_view { resolve_query_page },
        runtime.graph_utils.graph_node_view { resolve_query_type_counts },
    ]
    data.query_planner --> runtime.runtime.JacGraph.refs {
        LazyRefs,
        resolve_query,
        resolve_query_edges
    }
    data.schema_rules as _rules ++> runtime.builtin._get_schema_builder.builder;
    data.serializer ++> [
        compiler.tests.xbackend_equiv.encode_py_wire
            | runtime.builtin._get_archetype_alias.factory.decorator
            | server.endpoints.walkers
            | server.server
            | server.session.Session._expired
            | studio.session { Serializer },
        server.session { frozen_fields },
        server.session.Session._load_edges { Serializer },
        server.session.Session._materialize { Serializer },
        server.session.Session._serialize { Serializer },
        server.session.Session._unflushed { Serializer },
    ]
    data.serializer --> compiler.tests.test_fixed_width_equivalence { Serializer }
    data.storage ++> scale.tests.data.test_storage { LocalStorage }
    data.storage --> runtime.runtime.JacPersistence.store
        | scale.storage.factory.StorageFactory.create { LocalStorage }
    type data.storage ++> scale.runtime.provider { Storage }
    data.storage.local_storage ++> scale.tests.data.test_s3_storage { LocalStorage }
    data.storage.storage ++> scale.storage.bucket_storage | scale.storage.factory {
        Storage
    }
    data.store ++> [
        cli.commands.db | scale.events.streams.postgres | scale.scheduler.scheduler {
            TxnIsolation
        },
        cli.commands.db._open_project_store
            | scale.tests.data.test_pg_stream
            | scale.tests.server.test_backplane
            | scale.tests.server.test_pg_job_store
            | scale.tests.server.test_registration_limits
            | scale.tests.server.test_scheduler_multipod { PgStore },
        cli.commands.db._open_store { PgStore },
        cli.errmap.humanize_error { SessionConflictError },
        server.outbox { OUTBOX_SCHEMA_SQL, PgStore, Store, TxnIsolation },
        server.session { AnchorRow, ConnInfo, PgStore, Store, TxnIsolation },
    ]
    data.store --> scale.events.streams.postgres.PgEventStream._ensure_store
        | scale.memory.context.JScaleExecutionContext.init
        | scale.scheduler.scheduler.PgJobStore._quota_connection
        | scale.tests.data.test_auth_cutover
        | server.shared_store.shared_store { PgStore }
    data.type_identity ++> [
        runtime.graph_utils._graph_edge { storage_type },
        runtime.graph_utils.graph_neighbors_view { storage_type },
        runtime.graph_utils.graph_node_view { storage_type },
        runtime.graph_utils.graph_type_named { storage_type },
        server.session.Session._materialize { ForeignType, resolution_scope },
        server.session.Session._serialize { storage_type, type_module },
    ]
    data.type_identity --> [
        runtime.prepared.publish { index_application },
        server.session._ancestry_of { storage_type },
    ]
    dist.archive ++> [
        packages.artifact { tar_gz_dir },
        packages.store | packages.templates | packages.verify { extract_tar_gz },
        scale.injector.binary.pack_binary_bytes
            | scale.tests.microservices.test_bundle_jacignore { open_det_tar },
        scale.injector.bundle { det_tar_member, open_det_tar },
    ]
    dist.fused_binary ++> [
        cli.commands.project._bundle_binary { append_overlay, has_runtime },
        client.targets.desktop.desktop_build._bundle_runtime { graft_runtime },
        client.targets.desktop.desktop_build._jac_bin
            | scale.runtime.context.util.jac_executable { jac_binary },
        compiler.types.stubcat.locate.StubcatArtifact.probe_kit { running_executable },
        compiler.types.stubcat.locate.StubcatArtifact.probe_sealed {
            running_executable
        },
        compiler.types.stubcat.locate._region_probe { stubcat_region },
    ]
    dist.fused_binary --> cli.commands.cache._live_keys { running_runtime_entries }
    dist.jab ++> [
        cli.commands.execution._run_jab { materialize_jab },
        cli.commands.execution.run_jab_image { jab_app_meta },
    ]
    dist.jab --> [
        cli.cli_boot._run_bundled_app { materialize_jab_bytes },
        client.targets.desktop.native.host_boot.resolve_program {
            jab_app_meta,
            materialize_jab
        },
    ]
    dist.jab_vendor ++> [
        scale.tests.microservices.test_fat_bundle { WheelTarget, download_wheels },
        scale.utils.vendor_wheels {
            WheelTarget,
            download_wheels,
            wheels_dir,
            write_vendor_manifest
        },
    ]
    dist.payload.fetch ++> [
        client.js_runtime.BunArtifact.build { fetch_bun },
        compiler.types.stubcat.locate.TypeshedArtifact.build { fetch_typeshed },
    ]
    dist.precompile_bytecode ++> [
        cli.commands.precompile.precompile { run_precompile },
        scale.injector.bundle.pack_jab { RESULT_NAME },
    ]
    dist.precompile_bytecode --> scale.tests.microservices.test_app_precompile {
        main as seal_main,
        placement_facts_map,
        sealable_sources
    }
    dist.precompile_bytecode as precompiler --> scale.tests.microservices.test_app_precompile;
    dist.publish.builder ++> cli.commands.project._bundle_wheel { WheelBuilder }
    dist.publish.builder --> cli.commands.project.install { WheelBuilder }
    dist.publish.npm_builder ++> cli.commands.project._bundle_npm { NpmBuilder }
    dist.publish.npm_sources ++> cli.commands.project._bundle_npm { NpmBoundaryError }
    dist.publish.runtime_npm ++> cli.commands.project._bundle_npm_runtime {
        build_runtime_to,
        runtime_pkg_name
    }
    dist.sanitize ++> [
        packages.artifact { sanitize_shipped_tree },
        scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_client_bundle
            | scale.injector.bundle
            | scale.tests.microservices.test_app_precompile
            | scale.tests.microservices.test_bundle_jacignore
            | scale.tests.microservices.test_pvc_injector { sanitized_jac_toml },
        scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._check_pod_config_resolves {
            sanitized_jac_toml
        },
    ]
    dist.seal ++> [
        cli.commands.project { build_jab, make_sealed_image as _make_sealed_image },
        client.targets.desktop.desktop_build.stage_program { build_jab },
    ]
    dist.self_update --> cli.commands.project.update { update_self }
    dist.source.project --> cli.commands.build._build_app { export_project }
    jac0 ++> dist.precompile_bytecode._seal_boot_unit {
        compile_jac as jac0_compile,
        discover_impl_files as jac0_impls
    }
    jac0 --> dist.publish.runtime_vendor._compile_runtime_module {
        compile_jac,
        discover_impl_files
    }
    jac0core ++> [
        client.js_runtime.BunArtifact.probe_sealed
            | compiler.backends.native.floors.CFloorArtifact.probe_sealed
            | compiler.backends.native.llvm.shim_path.ShimArtifact.probe_sealed
            | compiler.types.stubcat.locate.StubcatArtifact.probe_sealed
            | dist.precompiled.PrecompiledArtifact.probe_sealed { sealed },
        compiler.backends.native.floors.MuslArtifact.probe_sealed
            | compiler.types.stubcat.locate.TypeshedArtifact.probe_sealed { sealed },
        compiler.backends.native.floors.WasmLibcArtifact.probe_sealed { sealed },
        compiler.driver.compiler.JacCompiler._get_precompiled_jir_bytecode {
            sealed as _sealed
        },
        compiler.driver.compiler.JacCompiler._sealed_jir_data { sealed as _sealed },
        compiler.driver.compiler.JacCompiler._sealed_native_engine {
            sealed as _sealed
        },
        dist.precompile_bytecode | dist.seal.make_sealed_image { ext_registry },
    ]
    jac0core --> [
        artifacts.kit.runtime_floor_root { sealed as sealed_mod },
        artifacts.router._omitted | compiler.backends.native.host_facts.compute_fact {
            sealed
        },
    ]
    jac0core.artifact_registry ++> [
        artifacts.router._BuildingSpan.__enter__ { begin },
        artifacts.router._BuildingSpan.__exit__ { end },
        artifacts.router.artifact_named { ARTIFACTS },
        artifacts.router.building_now { building as marked },
        artifacts.router.names { ARTIFACTS },
        artifacts.router.resolve { resolution_in_flight },
    ]
    jac0core.artifact_registry --> compiler.driver.compiler.JacCompiler.ensure_stub_catalog {
        resolution_in_flight
    }
    jac0core.cache_paths ++> [
        artifacts.router.publish { FileLock, atomic_write },
        cache.home { get_cache_home },
        client.compiler.ViteCompiler._compile_wasm_module
            | client.vite_bundler.ViteBundler.build
            | compiler.driver.ifacecache.IfaceRegistry._event
            | compiler.driver.nativecache.NativeUnitRegistry._event { stat_note },
        client.compiler.ViteCompiler._wasm_input_key
            | client.vite_bundler.ViteBundler._build_inputs_digest
            | compiler.driver.jir.compute_content_sha256
            | dist.jab.materialize_jab
            | dist.seal.sealed_image_key { file_sha256 },
        client.js_runtime.write_bun_record
            | compiler.backends.native.link_plan
            | compiler.backends.native.llvm.shim_path.write_shim_record
            | compiler.backends.native.native_link
            | compiler.types.stubcat.build
            | scale.injector.binary { atomic_write },
        client.targets.desktop.desktop_build._native_build_cef
            | client.targets.node_tooling_common.run_manifest_install
            | client.targets.react_native.build.run_gradle_assemble
            | data.pg_dist.download_dist
            | dist.seal.make_sealed_image
            | packages.sources.checkout
            | packages.store.materialize
            | toolchains.android
            | toolchains.apple
            | toolchains.c_backend
            | toolchains.cef
            | toolchains.desktop
            | toolchains.store { FileLock },
        compiler.backends.es.client_kernel_cache._cache_dir { get_jir_cache_dir },
        compiler.driver.jir { FileLock, atomic_write, stat_note },
        compiler.driver.jir.get_jir_cache_dir { get_jir_cache_dir as _root },
        compiler.driver.jir.read_jir { file_identity },
    ]
    jac0core.ext_registry ++> [
        cli.commands.analysis._drop_covered_annexes
            | compiler.driver.pipeline_runner.compile_application
            | dist.publish.builder
            | testing.cl_test_runner.module_entry_for { is_annex },
        cli.commands.cli_helpers { base_stem, is_jac, is_python },
        cli.commands.execution._jab_native_bin
            | client.jac_client_compiler.JacClientCompiler._native_variant
            | client.targets.client_dev_common.dev_proxy_paths
            | compiler.driver.application._semantic_metadata
            | dist.seal.bake_native_payloads
            | project.kinds
            | project.placement
            | runtime.prepared
            | scale.server.inprocess
            | server.hmr.HotReloader._get_js_filename { base_stem },
        cli.commands.native_build.native_build {
            base_stem,
            is_jac,
            is_retired_native_marker
        },
        compiler.driver.bccache { ANNEX_FOLDER, MODULE_SUFFIXES },
        compiler.tools.code_intel {
            ANNEX_FOLDER,
            ANNEX_SUFFIXES,
            IMPL_SUFFIX,
            is_annex
        },
        project.modresolver { MODULE_SUFFIXES, is_jac_namespace_package, language_of },
        runtime.prepared.semantic_for_scope | server.hmr.HotReloader._path_to_module {
            base_stem
        },
        server.hmr.HotReloader._dispatch_change { is_impl },
        server.watcher.JacFileWatcher._beside_watched_file { is_annex_path_of },
        server.watcher.JacFileWatcher._foreign_shared_annex {
            ANNEX_FOLDER,
            JAC_SUFFIX,
            is_annex_path_of,
            shared_annex_folder
        },
        server.watcher.annex_folders_of {
            ANNEX_FOLDER,
            JAC_SUFFIX,
            shared_annex_folder
        },
        testing.runner.run_test { base_stem, is_annex },
        testing.test { strip_suffix },
        testing.test_runner._is_named_test_file { is_jac, is_test },
        testing.test_runner._iter_candidate_files { is_impl, is_jac },
        testing.test_runner._suite_source { is_test },
        testing.test_runner.discover { is_jac },
        testing.test_runner.run_file { base_stem, is_annex_path_of },
    ]
    jac0core.ext_registry --> [
        compiler.driver.bccache.host_layout_tables {
            ANNEX_FOLDER,
            INIT_FILES,
            JAC_SUFFIX,
            MODULE_SUFFIXES,
            RETIRED_CLIENT_SUFFIX,
            RETIRED_NATIVE_SUFFIX,
            STEM_REKEY_SUFFIXES,
            _JS_SUFFIXES,
            _PY_SUFFIXES
        },
        runtime.runtime.JacModule.impl_patch_filename.decorator { is_jac },
    ]
    jac0core.handoff ++> [
        cli.cli.start_cli
            | cli.manifest_route.resolve_cli_version
            | compiler.driver.jir._handoff { handoff },
        client.targets.desktop.native.host_boot.host_executable
            | dist.fused_binary.running_executable { process_executable },
        compiler.driver.jir.require_exact_compiler_products { update_handoff },
        compiler.driver.jir.set_cache_mode { update_handoff },
    ]
    jac0core.osp0 ++> compiler.frontend.unitree { last_in0 }
    jac0core.sealed ++> [
        compiler.driver.application._prepare_sealed {
            image_for_bundle_dir,
            register_image
        },
        dist.jab { MANIFEST_NAME, image_for_bundle_dir, register_image },
        dist.precompile_bytecode {
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
        },
        dist.seal.vendor_jab_deps | scale.utils.vendor_wheels { python_tag },
        server.sealed_serve { MANIFEST_NAME },
    ]
    jac0core.sealed --> artifacts.kit._find_kit { load_image }
    type jac0core.sealed ++> artifacts.kit { SealedImage }
    jac0core.stubcat_hook ++> [
        compiler.types.stubcat.locate._publish { set_active },
        compiler.types.stubcat.locate.open_catalog { catalog_disabled },
        compiler.types.stubcat.locate.reset_catalog_cache { set_active },
        project.compiler_host.ProjectHost.has_active_stub_catalog
            | project.modresolver._stub_catalog_active { active },
    ]
    jac0core.stubcat_hook --> compiler.driver.compiler.JacCompiler.stub_catalog
        | project.modresolver._candidate_from_stub_catalog { active }
    lib.jaclib as _jaclib ++> lib;
    include lib.jaclib ++> lib;
    lsp.protocol.server ++> studio.intel_server { Workspace }
    lsp.protocol.types as lspt ++> studio.intel_server;
    lsp.server.engine ++> studio.intel_server { JacLangServer }
    lsp.server.server ++> cli.commands.tools.lsp { run_lang_server }
    meta_importer ++> client.targets.desktop.native.host_boot._ensure_jac_meta_importer {
        JacMetaImporter
    }
    packages.artifact ++> [
        cli.commands.project._bundle_jab {
            ArtifactError,
            ROLE_APP,
            build_package,
            project_role
        },
        dist.seal.vendor_packages { stage_source_tree },
    ]
    packages.commands ++> [
        cli.commands.project.install { install_project },
        cli.commands.project.update { PYPI_HINT, install_project, split_package_specs },
    ]
    packages.commands --> [
        cli.commands.project.install { add_packages },
        cli.commands.project.remove { remove_packages },
    ]
    packages.github ++> dist.self_update.update_self { GitHub, GitHubError, find_token }
    packages.install ++> [
        client.config_loader._package_npm_deps {
            InstallError,
            load_lock,
            package_npm_requirements
        },
        dist.seal.sealed_image_key { has_packages },
        dist.seal.vendor_packages { has_packages, sync },
    ]
    packages.migrate ++> cli.commands.fix._fix_dependencies {
        find_manifests,
        migrate_manifest
    }
    packages.provider --> project.providers.initialize_provider_registry {
        JacPackageProvider
    }
    packages.publish ++> cli.commands.project.publish { publish_project }
    packages.publish --> cli.commands.project.publish { yank_version }
    packages.semver ++> dist.self_update.up_to_date { SemverError, Version }
    packages.templates ++> cli.commands.project._resolve_template {
        TemplateError,
        fetch_template,
        is_template_spec,
        load_template_jab
    }
    packages.verify --> cli.commands.project.publish { run_verify }
    project ++> cli.commands.native_build.native_build { get_config }
    project --> compiler.backends.native.wasm_build._project_gc_settings { get_config }
    project.app_kinds ++> [
        cli.commands.execution._app_serves { kind_spec },
        cli.commands.project._create_app { is_valid_kind },
        cli.commands.project._create_body { is_valid_kind },
        client.cli.run_client_start
            | client.npm_provider._app_wants_client
            | compiler.driver.pipeline_runner.compile_application
            | scale.runtime.fleet._has_client
            | server.static_files { kind_has_client },
        client.cli.setup { kind_has_client },
        compiler.placement.placement.project_has_server
            | compiler.placement.placement_pins { kind_codespace },
        dist.source.project.export_project { kind_has_client, kind_has_server },
    ]
    project.app_kinds --> [
        cli.commands.build._build_app { kind_has_client },
        compiler.driver.program.JacProgram.stamp_app_facts { UI_MOBUI },
        runtime.source_app.main { kind_has_server },
    ]
    project.apps ++> [
        scale.injector.bundle._entry_module_spec { resolve_entry_path },
        scale.injector.bundle.sealed_entry_module { resolve_entry_path },
    ]
    project.apps --> scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._client_entry {
        resolve_entry_path
    }
    type project.apps ++> client.cli
        | client.targets.registry
        | dist.seal
        | scale.runtime.fleet
        | server.assembly { AppConfig }
    project.capabilities ++> [
        byllm._optdeps.pillow.open_image
            | byllm._optdeps.pydantic.TypeAdapter
            | byllm.llm { require_optional },
        scale._optdeps.optional_deps { missing_capability_error },
        scale.deploy.target.factory {
            ensure_global_capability,
            missing_capability_dists
        },
        scale.tests.deploy.test_dry_run_purity { CAPABILITY_SPECS },
    ]
    project.client_paths ++> [
        client.artifact.client_output_dir
            | client.targets.desktop.desktop_target.DesktopTarget.out_dir_for
            | dist.seal.ensure_client_dist
            | server.server.JacAPIServer._ensure_client_bundle { client_app_dir_for },
        client.config_loader.JacClientConfig.get_app_root { client_app_root },
        client.config_loader.JacClientConfig.get_assets_config { client_assets_config },
        client.config_loader.JacClientConfig.get_assets_dir { client_assets_dir },
        client.config_loader.JacClientConfig.get_seo_config { client_seo_config },
        client.targets.react_native.scaffold._project_native_deps {
            client_workspace_app
        },
        server.static_files {
            client_app_dir_for,
            client_app_root,
            client_assets_config,
            client_assets_dir,
            client_seo_config
        },
    ]
    project.client_paths --> [
        client.jac_client_compiler.JacClientCompiler._app_root { client_app_root },
        client.jac_client_compiler.JacClientCompiler._client_app_dir
            | client.serving.JacClient.render_page
            | client.vite_bundler.ViteBundler._client_app_dir
            | scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._client_dist_candidates {
            client_workspace_app
        },
        client.targets.desktop.desktop_build.stage_program { client_assets_dir },
        compiler.driver.application._prepare_revision { client_input_dirs },
    ]
    project.compiler_host ++> studio.gate | studio.model { ProjectHost }
    project.config ++> [
        artifacts.router._provision
            | data.pg_dist.bundled_dist_dir
            | toolchains.store.offline { offline_mode },
        cache.registry.project_bucket
            | cli.commands.analysis._configured_check_excludes
            | cli.commands.architecture
            | cli.commands.build.build
            | cli.commands.config.config
            | cli.commands.execution._ensure_watchdog_installed
            | cli.commands.mcp.mcp_cmd
            | cli.commands.project.bundle
            | cli.shadcn.cli.retheme
            | client.targets.desktop._dev_launch
            | client.targets.pwa_build
            | client.targets.registry.target_for_app
            | client.vite_bundler._dev_head
            | data.pg_dist._configured_dist
            | runtime.graph_utils.get_name
            | scale.plugin._resolve_deploy_target
            | scale.storage.factory
            | server.endpoints.colocated
            | server.endpoints.pages
            | server.server.JacAPIServer._ensure_client_bundle
            | server.sv_client._read_cache_enabled { get_config },
        cli.commands.analysis._is_project_wide_run
            | cli.commands.execution._exec_file
            | cli.commands.project.clean
            | cli.shadcn.cli.run_shadcn_add
            | data.pg_dist._database_config
            | scale.plugin.scale_local_serve
            | server.endpoints.pages.register_diagnostics_endpoints.client_error
            | server.server.print_endpoint_docs { get_config },
        cli.commands.analysis.check
            | cli.commands.execution._load_cwd_config
            | cli.commands.project.deps
            | cli.shadcn.cli.run_shadcn_remove { get_config },
        cli.commands.analysis.format
            | cli.commands.execution._resolve_target
            | cli.commands.project.install { get_config },
        cli.commands.analysis.precommit
            | cli.commands.execution._run_node_tool
            | cli.commands.project.publish { get_config },
        cli.commands.analysis.test
            | cli.commands.execution._tool_tiers
            | cli.commands.project.remove { get_config },
        cli.commands.code
            | cli.commands.project._create_app
            | client.vite_bundler.ViteBundler.init
            | scale.tests.server.test_examples
            | server.settings.secret_home { find_project_root },
        cli.commands.config
            | cli.commands.fix._ensure_workspace
            | client.cli
            | client.client_diagnostics.is_debug_mode
            | client.npm_provider
            | client.targets.react_native.scaffold
            | dist.publish.builder
            | dist.publish.npm_builder
            | dist.publish.npm_sources
            | dist.publish.sources
            | dist.publish.wheel_meta
            | dist.source.project
            | packages.commands
            | packages.install
            | packages.provider
            | packages.publish
            | packages.resolve
            | packages.verify._verify_library
            | scale.injector.bundle._resolved_python_specs
            | scale.tests.apps.test_app_scale_overrides
            | scale.tests.apps.test_fleet_from_apps
            | scale.tests.data.test_gcs_storage
            | scale.tests.data.test_s3_storage
            | scale.tests.deploy.test_deploy_banner
            | scale.tests.deploy.test_dry_run_purity
            | scale.tests.deploy.test_version_pin
            | scale.utils.vendor_wheels
            | server.server.JacAPIServer.build_app
            | testing.testing { JacConfig },
        cli.commands.config._config_path { find_project_root, get_config },
        cli.commands.config._config_set
            | scale.injector.binary.deploy_generation_refusal {
            JacConfig,
            find_project_root
        },
        cli.commands.config._get_group_defaults {
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
        },
        cli.commands.config._output_toml | packages.lock { toml_value },
        cli.commands.execution._default_codespace_is_native {
            PlacementConfig,
            get_config
        },
        cli.commands.execution._discover_config_from_file {
            get_config,
            project_scope_is_pinned
        },
        cli.commands.execution._load_executable
            | client.artifact.client_output_dir
            | client.serving
            | dist.precompile_bytecode.app_metadata
            | dist.seal.prepare_serve_payloads
            | scale.config.dev_config.local_pod_binary
            | scale.injector.bundle._project_config { get_config_for_path },
        cli.commands.execution._pin_run_scope {
            JacConfig,
            get_config,
            pin_project_scope
        },
        cli.commands.execution.serve | cli.commands.project.script { get_config },
        cli.commands.execution.x | cli.commands.project.update { get_config },
        cli.commands.fix._append_app_table { _toml_append_section },
        cli.commands.fix._report_invalid_manifest { JacConfig },
        cli.commands.project._bootstrap_project_deps
            | testing.testing.JacTestClient._ensure_initialized {
            get_config,
            set_config
        },
        cli.commands.project._create_body { find_project_root },
        cli.mcp.mode { JacConfig, get_config, set_config },
        client.cli.get_config { get_config as _get_config },
        client.targets.desktop.desktop_target.DesktopTarget.out_dir_for
            | client.targets.react_native.scaffold._project_native_deps
            | scale.config.app_config
            | scale.runtime.realizer.kubernetes_realizer.KubernetesRealizer._resolve_fleet
            | server.endpoints.colocated.served_app_route
            | studio.app { get_config_for_dir },
        client.targets.web_target._get_app_meta_data {
            get_config,
            get_config_for_path
        },
        dist.publish.metadata | dist.publish.package_json { JacConfig, PersonConfig },
        packages.migrate | scale.injector.bundle.staged_jac_toml {
            serialize_toml,
            toml_minimal_update
        },
        scale.config.dev_config.resolve_dev_channel
            | scale.injector.bundle.fat_bundle_setting { get_config_for_path },
        scale.config.dev_config.resolve_experimental_pr
            | scale.injector.bundle.seal_cache_setting { get_config_for_path },
        scale.config.dev_config.resolve_pinned_spec
            | scale.injector.bundle.seal_timeout_setting { get_config_for_path },
        scale.deploy.target.kubernetes.manifest_builder { JacConfig, ServeConfig },
        scale.deploy.target.kubernetes.manifest_builder.ManifestBuilder._check_deploy_settings_resolve {
            get_config_for_path,
            report_env_findings
        },
        scale.injector.binary.resolve_pinned_version { JacConfig, find_project_root },
        scale.injector.bundle.unresolved_toml_references { resolve_env_refs },
        scale.tests.server.test_host_serving
            | scale.tests.server.test_served_app_route { set_config },
        server.session._database_config { DatabaseConfig, get_config_for_dir },
        server.settings { JacConfig, ServeConfig, ServeConfigError, apply_table },
        server.static_files { find_project_root, get_config, get_config_for_dir },
        testing.test_runner._fresh_jac_state { get_explicit_config, set_config },
        toolchains.host.use_system_tools { use_system_toolchains },
    ]
    project.config --> [
        byllm.mtir.MTRuntime.factory
            | client.vite_client_bundle.make_client_bundle_builder {
            find_project_root
        },
        cli.commands.analysis._format_single_file_worker
            | cli.commands.execution.run_jab_image
            | dist.precompile_bytecode.precompile_context
            | scale.tests.microservices.test_app_precompile { get_config_for_path },
        cli.commands.project._resolve_template
            | cli.dispatch._apply_profile
            | client.client_deps._resolve_client_framework
            | client.jac_client_compiler.JacClientCompiler._app_root
            | client.vite_bundler.ViteBundler._client_app_dir
            | server.server._occ_policy { get_config },
        cli.dispatch._discover_project_config
            | client.jac_client_compiler.JacClientCompiler._client_app_dir
            | client.vite_bundler.ViteBundler._get_client_dir { get_config },
        client.jac_client_compiler.JacClientCompiler._get_client_dir { get_config },
        client.targets.desktop.desktop_build.desktop_storage_identifier
            | scale.server.inprocess.prepare_inprocess_runtime
            | server.hmr.HotReloader._reload_server_module { get_config_for_dir },
        client.targets.desktop.desktop_build.stage_program { get_config_for_dir },
        runtime.runtime.JacRuntime.reset_process_state { set_config },
        runtime.source_app.main { JacConfig, set_config },
        scale.runtime.fleet.fleet_member_names { get_config, get_config_for_dir },
        scale.tests.apps.test_app_scale_overrides {
            get_config,
            get_explicit_config,
            set_config
        },
        scale.tests.misc.test_config_validation { JacConfig },
        server.static_files.robots_response { ServeConfigError },
    ]
    type project.config ++> [
        cli.commands.build { AppConfig },
        cli.commands.execution { AppConfig, JacConfig },
        cli.commands.project | testing.testing { JacConfig },
        data.pg_dist | server.session { DatabaseConfig },
    ]
    project.config_schema ++> [
        scale.config.validation { validate_against_schema },
        scale.tests.misc.test_config_validation { report_schema_findings },
    ]
    project.config_schema --> [
        scale.config.config_loader.app_scale_overrides { report_schema_findings },
        scale.tests.misc.test_config_validation { schema_strict_enabled },
    ]
    project.dependencies ++> [
        packages.commands | packages.resolve { PackageDep },
        packages.migrate { migrate_dependency_table },
    ]
    project.jac_version ++> [
        packages.resolve | packages.templates { satisfies as jac_satisfies },
        scale.injector.binary {
            exact_pin,
            is_plain_version,
            satisfies,
            split_clause,
            version_key
        },
        scale.tests.deploy.test_memory_trigger_guard { version_key },
        scale.tests.deploy.test_version_pin { exact_pin, version_key },
    ]
    project.kinds ++> [
        cli.commands.build._build_app | cli.commands.execution._resolve_plan {
            plan_app_run
        },
        cli.commands.execution | scale.plugin { RunPlan },
        cli.commands.execution._serve_fleet { plan_app_run },
        cli.commands.execution._workspace_plans { plan_app_run, plan_workspace },
        cli.commands.project._create_app { VALID_KINDS },
        cli.commands.project._create_body { VALID_KINDS },
        cli.commands.project._run_blurb { VALID_KINDS },
        dist.precompile_bytecode.app_metadata { resolve_app_kind, resolve_entry },
        scale.plugin._resolve_deploy_target { resolve_entry },
    ]
    project.kinds --> cli.commands.execution._exec_file { resolve_app_kind }
    project.mobui_scope ++> compiler.passes.jsx_intrinsic_guard_pass {
        mobui_module_exempt
    }
    project.mobui_scope --> compiler.types.type_evaluator.TypeEvaluator._is_mobui_module {
        mobui_module_exempt
    }
    project.modresolver ++> [
        cli.commands.fix._report_invalid_manifest | server.outbox.outbox_db_path {
            find_jac_project_root
        },
        cli.commands.fix._verify_claims { find_jac_project_root },
        cli.commands.fix.fix { find_jac_project_root },
        client.compiler.ViteCompiler.compile_desktop_sdk
            | compiler.tests.test_jac_mobui_typing
            | testing.cl_test_runner._compile_runtime {
            resolve_jac_virtual_module_path
        },
        compiler.backends.py.artifact_imports.resolve_imports
            | dist.precompile_bytecode.image_mount_prefix { project_mounts },
        compiler.tests.test_missing_local_import | dist.publish.py_imports {
            resolve_module
        },
        compiler.types.type_evaluator.TypeEvaluator._climbs_above_project {
            project_root_chain
        },
        compiler.types.type_evaluator.TypeEvaluator.get_type_of_module_item {
            named_exactly_any
        },
        dist.publish.runtime_vendor._module_to_file { resolve_local_module },
        lsp.server.engine.JacLangServer._module_spec_target {
            resolve_client_npm_declarations,
            resolve_client_npm_package
        },
        lsp.server.engine.JacLangServer._npm_item_location {
            resolve_client_npm_declarations,
            resolve_client_npm_package
        },
        runtime.runtime {
            find_jac_project_root,
            infer_language,
            pop_import_base,
            push_import_base
        },
    ]
    project.modresolver --> client.compiler.ViteCompiler.compile_desktop_sdk {
        resolve_jac_virtual_module_exports
    }
    project.package_scope ++> [
        dist.seal.vendor_packages | packages.mounts { mounts_dir },
        packages.artifact.project_role
            | packages.commands
            | packages.index
            | packages.install
            | packages.publish
            | packages.resolve
            | packages.templates
            | packages.verify { is_package_name },
        packages.store { store_root },
    ]
    project.package_scope --> [
        compiler.backends.native.host_facts.host_native_fact { store_root },
        compiler.driver.jir._module_cache_root { in_store },
        compiler.driver.jir._module_projection { is_dependency_module },
    ]
    project.placement ++> cli.commands.fix._verify_claims { module_dot_path }
    project.plugin_config ++> [
        byllm.config_loader | client.desktop_config | scale.config.config_loader {
            PluginConfigBase
        },
        client.config_loader { PluginConfigBase, deep_merge },
    ]
    project.providers ++> [
        cli.commands.execution._ensure_watchdog_installed
            | cli.commands.project.install { InstallContext, get_python_provider },
        cli.commands.execution._load_cwd_config { initialize_provider_registry },
        cli.commands.execution._serve_with { initialize_provider_registry },
        cli.commands.project._rewrite_compatible_pins { get_python_provider },
        cli.commands.project._update_pypi { get_python_provider },
        cli.commands.project.deps { resolve_plan },
        cli.commands.project.remove { InstallContext, get_python_provider },
        cli.commands.project.update | client.cli.run_npm_add { InstallContext },
        client.cli._npm_context { get_provider_registry },
        client.cli.run_npm_remove { InstallContext },
        client.npm_provider {
            EcosystemProvider,
            InstallContext,
            ResolvedDependency,
            manifest_plugin_deps
        },
        client.targets.react_native.scaffold { manifest_plugin_subdeps },
        dist.publish.package_json.npm_dependencies { manifest_plugin_deps },
        dist.seal.vendor_jab_deps
            | dist.source.project._requirements
            | scale.injector.bundle._resolved_python_specs
            | scale.utils.vendor_wheels { get_python_provider, resolve_plan },
        packages.commands {
            InstallContext,
            get_provider_registry,
            get_python_provider,
            resolve_plan,
            venv_deps_satisfied
        },
        packages.provider { EcosystemProvider, InstallContext, ResolvedDependency },
        scale.injector.bundle._venv_stage | scale.tests.microservices.test_fat_bundle {
            write_venv_deps_marker
        },
        scale.injector.bundle.staged_venv_files { VENV_DEPS_MARKER },
    ]
    type project.providers ++> [
        cli.commands.project { InstallContext },
        client.cli | client.plugin_config { EcosystemProvider },
    ]
    project.pyvenv ++> [
        cli.commands.execution._discover_config_from_file | studio.app {
            add_venv_to_path
        },
        cli.commands.execution._ensure_watchdog_installed { add_venv_to_path },
        cli.commands.execution._pin_run_scope { add_venv_to_path },
        cli.commands.project._update_pypi { make_git_spec },
        cli.commands.project.install {
            ensure_venv,
            get_venv_site_packages,
            make_git_spec
        },
        client.targets.desktop._dev_launch
            | packages.commands._org_collisions
            | scale.injector.bundle._venv_stage { get_venv_site_packages },
        dist.jab_vendor._pip { pip_command, pip_env, pip_python },
        scale.injector.bundle.staged_venv_files { get_venv_site_packages },
    ]
    project.pyvenv --> cli.dispatch._discover_project_config { add_venv_to_path }
    project.source ++> [
        cli.commands.analysis._normalize_ignore_patterns { normalize_exclude_patterns },
        cli.commands.analysis._should_ignore
            | compiler.tools.jac_auto_lint_pass.JacAutoLintPass._is_file_excluded
            | scale.injector.bundle.BundleSourceFilter.matching_ignore_pattern {
            path_matches_exclude
        },
        client.client_diagnostics.ClientDiagnostic.render
            | compiler.passes.context.Alert.pretty_print { render_diagnostic },
        compiler.passes.context.Alert.as_log { render_diagnostic_header },
        compiler.passes.import_wiring_pass
            | compiler.passes.pyast_load_pass.PyastBuildPass.convert
            | compiler.tools.lang_tools { pascal_to_snake },
        dist.seal.make_sealed_image { is_secret_file, path_matches_exclude },
        packages.artifact.package_copy_ignore
            | scale.injector.bundle.BundleSourceFilter.excludes { is_secret_file },
        runtime.traceback_render { pretty_print_source_location },
        scale.injector.bundle.BundleSourceFilter.exclusion_reason { is_secret_file },
        scale.injector.bundle.BundleSourceFilter.parks { path_matches_exclude },
    ]
    project.template_loader ++> [
        cli.commands.fix._ensure_workspace { migrate_implicit_app },
        cli.commands.project._create_app { scaffold_app },
        cli.commands.project._resolve_bundled_template
            | cli.shadcn.cli._build_shadcn_template_info
            | client.plugin_config._load_template { load_template_from_directory },
        cli.commands.project._resolve_template { load_template_from_directory },
    ]
    project.template_registry ++> [
        cli.commands.project._create_body { TemplateRegistry, get_template_registry },
        cli.mcp.compiler_bridge.CompilerBridge.list_templates._do_list_templates {
            get_template_registry
        },
    ]
    type project.template_registry ++> cli.commands.project {
        ProjectTemplate,
        TemplateRegistry
    }
    project.textio ++> [
        cli.commands.analysis._annex_moves
            | cli.commands.architecture
            | cli.commands.transform.py2jac
            | compiler.driver.compiler
            | compiler.tools.lang_tools
            | runtime.traceback_render { read_file_with_encoding },
        cli.commands.analysis._float_impls_to_annex { read_file_with_encoding },
        cli.commands.analysis._format_single_file_worker { read_file_with_encoding },
        cli.commands.analysis._iter_jac_files | cli.commands.architecture._arch_files {
            drop_git_ignored
        },
        client.client_diagnostics.ClientDiagnostic.render {
            read_file_with_encoding,
            span_for_file
        },
        dist.seal.make_sealed_image | scale.injector.bundle.source_filter_for {
            read_jacignore_patterns
        },
    ]
    project.textio --> [
        cli.commands.analysis._check_file_job { read_file_with_encoding as _read_src },
        compiler.driver.compiler.JacCompiler.get_bytecode { read_file_with_encoding },
    ]
    project.tomlio ++> [
        cli.commands.config | cli.commands.project._toml_apps_and_default {
            read_toml_with_encoding
        },
        cli.dispatch._discover_project_config { MalformedJacTomlError },
    ]
    project.tool_paths ++> [
        cli.commands.execution._tool_site_dirs {
            python_global_site,
            python_project_site
        },
        cli.commands.execution._tool_tiers {
            node_bin_dir,
            python_global_site,
            python_project_site
        },
        client.cli.run_npm_add_global { node_root },
    ]
    project.workspace ++> [
        cli.commands.analysis.check
            | cli.commands.execution._load_executable
            | cli.commands.fix._access_plan
            | dist.precompile_bytecode._application_sources
            | server.session.project_database { workspace_for_path },
        compiler.driver.application._warn_private_declarations { app_for_path },
        dist.precompile_bytecode.sealable_sources { workspace_for_path },
    ]
    project.workspace --> lsp.server.engine.JacLangServer.type_check_file {
        workspace_for_path
    }
    project.workspace_model ++> [
        compiler.driver.boundary_classify | compiler.driver.compilation_context {
            AppSpec
        },
        compiler.frontend.host { AppSpec, WorkspaceSpec },
    ]
    runtime.archetype ++> [
        byllm.llm._mock_jsonable { Archetype },
        byllm.visit_routing { Anchor, Archetype, ObjectSpatialFunction },
        byllm.visit_routing._candidate_for { EdgeAnchor, EdgeArchetype, NodeAnchor },
        byllm.visit_routing._route_context {
            EdgeAnchor,
            EdgeArchetype,
            NodeAnchor,
            NodeArchetype,
            WalkerAnchor
        },
        data.query_planner { Anchor, anchor_key },
        data.query_planner._acl_residual { NodeArchetype },
        data.query_planner._edge_residual { EdgeArchetype },
        data.query_planner._trusted_names { Archetype, Root },
        data.serializer {
            Access,
            AccessLevel,
            Anchor,
            EdgeAnchor,
            NodeAnchor,
            ObjectAnchor,
            Permission,
            WalkerAnchor,
            access_level_cast
        },
        lib.jaclib { GenericEdge, ObjectSpatialFunction as DSFunc, Root },
        server.session { Anchor, EdgeAnchor, NodeAnchor, Root },
    ]
    runtime.build_services ++> [
        client.runtime_source.client_runtime_cl_basename
            | scale.runtime.fleet._compiled_app_edges
            | testing.testing.JacTestClient._ensure_initialized { build_services },
        compiler.driver.build_services { BuildServices },
    ]
    runtime.build_services --> testing.testing.JacTestClient.reload { build_services }
    runtime.builtin ++> [
        cli.commands.tools.dot { printgraph },
        scale.server.jobs_ext
            | server.server.JacAPIServer._register_scheduled_tasks
            | server.task_scheduler { ScheduleTrigger },
        scale.server.webhook_ext
            | scale.server.websocket_ext
            | server.endpoints.walkers
            | server.server { APIProtocol },
    ]
    runtime.builtin --> [
        scale.tests.server.test_restspec { APIProtocol },
        scale.tests.server.test_webhook { APIProtocol, restspec },
    ]
    runtime.builtin as blt --> scale.tests.server.test_restspec;
    runtime.constants ++> [
        compiler.backends.py.jcir_gen_pass | compiler.frontend.unitree {
            Constants as Con,
            EdgeDir
        },
        compiler.frontend.parser.parser
            | compiler.passes.graph_lowering_pass
            | compiler.tools.normalize_pass
            | compiler.types.type_evaluator
            | lib.jaclib { EdgeDir },
        data.dbcatalog.holds_no_data
            | scale.server.websocket_ext
            | server.endpoints.colocated
            | server.endpoints.pages
            | server.endpoints.walkers
            | server.identity.identity_storage
            | server.identity.user_manager
            | server.server { Constants as Con },
    ]
    runtime.constants --> compiler.backends.py.jcir_gen_pass.JcirGenPass._gen_native_interop_stubs {
        JAC_TO_CTYPES_STR
    }
    runtime.constructs ++> [
        cli.commands.execution._invoke_entrypoint
            | server.server.ModuleIntrospector.scheduled_members { WalkerArchetype },
        data.serializer {
            Archetype,
            GenericEdge,
            NodeArchetype,
            Root,
            WalkerArchetype
        },
        lib.jaclib {
            Archetype as Obj,
            EdgeArchetype as Edge,
            JsxElement,
            NodeArchetype as Node,
            WalkerArchetype as Walker
        },
        scale.memory.context.JScaleExecutionContext.init { PermissionDenied },
        server.endpoints.pages.register_graph_endpoints.graph_neighbors {
            EdgeArchetype,
            NodeArchetype
        },
        server.endpoints.pages.register_graph_endpoints.graph_target
            | server.server._spawn_target { NodeArchetype },
        server.identity.identity_storage.IdentityStorage.create_user { Root },
        server.identity.identity_storage.IdentityStorage.ensure_user_by_id { Root },
        server.identity.identity_storage.IdentityStorage.reset_root { Root },
        server.server.ModuleIntrospector.target { WalkerArchetype },
        server.session._ancestry_of {
            Archetype,
            EdgeArchetype,
            NodeArchetype,
            WalkerArchetype
        },
    ]
    runtime.constructs --> server.task_scheduler.Scheduler._execute { WalkerArchetype }
    type runtime.constructs ++> server.server { WalkerArchetype }
    runtime.context ++> [
        scale.memory.context | server.server { CallState, ExecutionContext },
        scale.tests.server.test_middleware_async_root
            | server.request_scope
            | server.sv_client._local_call { ExecutionContext },
        server.sv_client._local_spawn { ExecutionContext },
        server.task_scheduler.Scheduler._execute { CallState },
    ]
    type runtime.context ++> cli.commands.cli_helpers
        | scale.runtime.provider
        | scale.server.inprocess { ExecutionContext }
    runtime.debugger ++> cli.commands.execution.debug { debugger as db }
    runtime.exceptions ++> [
        data.store { WriteConflict },
        server.middleware | server.server._abegin_user_request_context {
            MissingAnchorError
        },
        server.server { ReadOnlyRetry, WriteConflict },
        server.session { ReadOnlyRetry, TransactionLost, WriteConflict },
    ]
    runtime.graph_query ++> [
        data.query_planner | data.sqlcompile { GraphQuery, QHop, QPred },
        lib.jaclib { GraphQuery, QHop, QOrder, QPred },
    ]
    runtime.graph_utils ++> [
        scale.injector.binary { host_arch, host_os, release_arch },
        scale.injector.binary_injector
            | scale.tests.microservices.test_binary_injector { host_arch },
        scale.utils.vendor_wheels { release_arch },
        server.endpoints.pages.register_graph_endpoints.graph_neighbors {
            graph_neighbors_view,
            graph_type_named
        },
        server.endpoints.pages.register_graph_endpoints.graph_node { graph_node_view },
        server.session.project_database { get_name },
    ]
    runtime.graph_walk ++> data.query_planner {
        access_gated,
        acl_read_ok,
        needs_store,
        origin_anchors,
        pred_subject,
        walk,
        walk_edges,
        walk_nodes
    }
    runtime.interop_bridge --> compiler.backends.native.na_compile_pass.NativeCompilePass._run_impl
        | compiler.driver.compiler.JacCompiler._load_native_from_cache {
        register_py_callbacks
    }
    runtime.memory ++> server.session { Memory }
    runtime.native_library --> [
        compiler.driver.compiler.JacCompiler._load_native_from_cache {
            SharedNativeEngine
        },
        compiler.driver.compiler.JacCompiler._sealed_native_engine {
            shared_engine_for
        },
    ]
    type runtime.native_library ++> cli.commands.execution
        | compiler.driver.compiler
        | compiler.frontend.codeinfo { SharedNativeEngine }
    runtime.object_interop ++> [
        byllm.llm._mock_jsonable
            | byllm.visit_routing
            | data.contracts
            | data.schema_rules
            | data.serializer
            | project.config._walk_table
            | server.serving.model
            | server.settings { fields, is_record },
        byllm.schema | server.serving.coerce { is_record },
        byllm.systemone._record_fields | server.server {
            fields as record_fields,
            is_record
        },
        byllm.systemone._state_value { fields as record_fields, is_record },
        cli.NonGPT { fields as dc_fields, is_record },
        comptime { fields as _record_fields, is_record as _is_record },
    ]
    runtime.object_model ++> [
        cli.NonGPT | data.contracts | data.serializer | scale.memory.context {
            MISSING
        },
        comptime { MISSING as _MISSING, ObjectField as _field },
        scale.sdk.spec.DeploySpec.from_config { fields },
        scale.server.sso_ext | scale.sso.oauth_session { asdict },
    ]
    runtime.osp_graph_sv ++> [
        server.session.Session._drop_snapshot_reads { sv_forget_edge },
        server.session.Session._forget_loaded { sv_forget_edge },
        server.session.Session.close { sv_store_closed },
        server.session.Session.quarantine_ref { sv_forget_by_id },
    ]
    runtime.osp_graph_sv --> byllm.visit_routing._candidate_for { sv_register_hydrated }
    runtime.osp_kernel ++> [
        byllm.visit_routing._route_context { _current_scope },
        compiler.backends.es.esast_gen_pass
            | compiler.backends.py.jcir_gen_pass
            | compiler.passes.comptime_resolve_pass
            | compiler.passes.declaration_type_pass
            | compiler.passes.jsx_intrinsic_guard_pass
            | compiler.passes.scope_walk
            | compiler.tools.grammar_extract_pass { osp_skip_rest },
    ]
    runtime.osp_kernel --> [
        compiler.passes.context.CompileContext.enter_node { osp_skip_rest },
        compiler.passes.context.CompileContext.exit_node { osp_skip_rest },
    ]
    runtime.osp_kernel_sv ++> server.server._begin_request_context {
        isolate_request_walk_stack
    }
    runtime.osp_tag ++> compiler.backends.es.esast_gen_pass.EsastGenPass._build_osp_tags_js
        | compiler.backends.native.na_ir_gen_pass
        | compiler.backends.py.jcir_gen_pass.JcirGenPass.exit_module
        | compiler.passes.osp_analysis { stable_osp_tag }
    runtime.osp_tag --> [
        compiler.backends.es.esast_gen_pass.EsastGenPass._edge_tag_literal {
            stable_osp_tag
        },
        compiler.backends.es.esast_gen_pass.EsastGenPass._osp_slots_js {
            stable_osp_tag
        },
    ]
    runtime.pass_link ++> lib.jaclib { PassLink }
    runtime.portability ++> [
        compiler.placement.placement_solver { supports },
        compiler.placement.placement_solver._py_import_client_portable { supports },
    ]
    runtime.preparation_lock ++> [
        compiler.driver.application._check { BuildFailed },
        compiler.driver.application._prepare_revision { SourcesChanged },
        server.hmr.HotReloader._reload_server_module { PREPARATION_LOCK },
        server.server.JacAPIServer._refresh_dev_endpoints {
            BuildFailed,
            PREPARATION_LOCK,
            SourcesChanged
        },
    ]
    runtime.preparation_lock --> [
        compiler.driver.application.prepare_application { PREPARATION_LOCK },
        compiler.driver.application.prepare_dynamic_module { PREPARATION_LOCK },
    ]
    runtime.prepared ++> [
        cli.commands.execution._load_executable | server.assembly.colocate_services {
            load_prepared_module
        },
        compiler.driver.application._prepare | dist.source.client {
            PreparedApplication
        },
        compiler.driver.application._prepare_revision { PreparedApplication },
        compiler.driver.application._prepare_sealed { PreparedApplication, publish },
        compiler.driver.pipeline_runner.compile_application
            | server.watcher.watch_roots { holds_application_code },
        dist.source.project { PreparedApplication, application_namespace },
        project.config.JacConfig.app_for_path { origin_for_source },
        server.endpoint_contract.check_endpoint_contract
            | server.hmr.HotReloader._dispatch_change
            | server.sealed_serve.client_dist_for
            | server.server.JacAPIServer._ensure_client_bundle
            | server.session.Session._materialize { application_for },
        server.sealed_serve.serve_manifest_for { prepared_manifest },
        server.server.ModuleIntrospector._resolve_declared {
            application_for,
            load_prepared_module,
            source_for_origin
        },
        server.sv_client._local_call { application_of },
        testing.testing.JacTestClient._ensure_initialized { initialize_application },
        testing.testing.JacTestClient.close { forget },
    ]
    runtime.prepared --> [
        cli.commands.execution.serve
            | scale.server.inprocess.prepare_inprocess_runtime {
            initialize_application
        },
        client.targets.client_dev_common.dev_proxy_paths { prepared_manifest },
        compiler.driver.application.prepare_application { publish },
        compiler.driver.application.prepare_dynamic_module { publish },
        data.type_identity.resolve_type { load_prepared_module },
        server.hmr.HotReloader._reload_server_module {
            application_for,
            initialize_application
        },
    ]
    type runtime.prepared ++> compiler.driver.application
        | compiler.driver.build_services
        | data.type_identity
        | server.assembly { PreparedApplication }
    runtime.runtime ++> [
        byllm.lib
            | client.client_bundle.client_program
            | project.plugin_config
            | scale.memory.context.JScaleExecutionContext.init
            | server.request_scope
            | server.sv_client._local_call
            | studio.session
            | testing.cl_test_runner.module_is_client { JacRuntime },
        byllm.visit_routing.route_visit
            | cli.commands.cli_helpers.proc_file
            | cli.commands.execution._discover_config_from_file
            | cli.commands.tools.dot
            | cli.mcp.compiler_bridge.CompilerBridge.format_snippet._do_format
            | client.cli.run_client_start
            | client.route_scanner.resolve_route_exports
            | client.targets.mobile_target
            | client.targets.web_target.WebTarget.build
            | dist.seal.bake_serve_payloads
            | server.endpoints.pages
            | server.hmr.HotReloader._recompile_client_code
            | server.server.ModuleIntrospector._check_module_freshness
            | server.static_files { JacRuntime as Jac },
        cli.commands.execution._exec_file
            | cli.mcp.compiler_bridge.CompilerBridge.py_to_jac._do_py2jac
            | server.hmr.HotReloader._recompile_client_unified
            | server.server.ModuleIntrospector._resolve_declared { JacRuntime as Jac },
        cli.commands.execution._invoke_entrypoint
            | cli.mcp.compiler_bridge.CompilerBridge.typecheck_snippet._do_typecheck
            | server.server.ModuleIntrospector.route_spec { JacRuntime as Jac },
        cli.commands.execution._load_executable { JacRuntime as Jac },
        cli.commands.execution._pin_run_scope { JacRuntime as Jac },
        cli.commands.execution.debug { JacRuntime as Jac },
        cli.commands.execution.serve { JacRuntime as Jac },
        data.query_planner.LazyRefs._mem | lib.jaclib | testing.runner {
            JacRuntimeInterface
        },
        data.query_planner._acl_pushdown_root { JacRuntimeInterface },
        server.sv_client._scale_transport { _scale_provider },
        testing.test_runner._fresh_jac_state { JacRuntime, JacRuntimeInterface },
    ]
    runtime.runtime --> [
        byllm.visit_routing._candidate_for { JacRuntimeInterface },
        cli.commands.analysis.check.run_units
            | compiler.driver.compiler.JacCompiler.selfhost.getter
            | compiler.driver.selfhost.SelfHostCache.program.getter
            | compiler.tests.test_stubcat_roundtrip.small_catalog
            | project.config.JacConfig.app_for_target
            | server.serving.supervisor.WorkerSupervisor._spawn
            | server.shared_store.shared_store { JacRuntime },
        cli.console._get_console
            | client.cli.run_client_build
            | client.targets.client_dev_common.dev_proxy_paths
            | client.vite_client_bundle.make_client_bundle_builder
            | server.hmr.HotReloader._reload_server_module { JacRuntime as Jac },
        client.cli.run_client_setup { JacRuntime as Jac },
    ]
    runtime.scalars ++> [
        compiler.backends.es.esast_gen_pass.EsastGenPass._apply_fw_coercion
            | compiler.backends.es.primitives_es.ESBuiltinEmitter.emit_print
            | compiler.backends.py.jcir_gen_pass
            | compiler.types.ct_eval
            | comptime._scalar_size_align { shape_of },
        compiler.backends.es.esast_gen_pass.EsastGenPass._exit_name_impl
            | compiler.backends.es.primitives_es.ESBuiltinEmitter.emit_abs { is_sized },
        compiler.backends.es.esast_gen_pass.EsastGenPass._fw_binary { shape_of },
        compiler.backends.es.jac_runtime_js._build_fw_runtime_js {
            numeric_shapes,
            range_of
        },
        compiler.backends.es.jac_runtime_js._build_types_runtime_js { numeric_shapes },
        compiler.backends.es.primitives_es.ESBuiltinEmitter.emit_wrapping { is_sized },
        compiler.backends.native.na_ir_gen_pass { ScalarShape, range_of, shape_of },
        compiler.backends.py.jcir_facts | compiler.boundary_rules.json_refusal {
            sized_scalar_names
        },
        compiler.boundary_rules.non_string_key { sized_scalar_names },
        compiler.boundary_rules.python_native_wire { sized_scalar_names },
        compiler.type_registry {
            ScalarShape,
            numeric_shapes,
            shape_literal_fits,
            shape_range,
            shapes_unify,
            shapes_widen_to,
            sized_scalar_names
        },
    ]
    runtime.scalars --> [
        compiler.passes.wasm_contract.value_contract { ScalarShape, shape_range },
        compiler.types.fixed_width.adopt_literal { float_max },
    ]
    runtime.semantic ++> [
        byllm.mtir { FunctionInfo, Info, MethodInfo },
        byllm.schema {
            ClassInfo,
            EnumInfo,
            FieldInfo,
            FunctionInfo,
            Info,
            ParamInfo,
            TypeForm,
            VarInfo
        },
        byllm.systemone { ClassInfo, EnumInfo, FunctionInfo, TypeForm, VarInfo },
        byllm.types { ClassInfo, EnumInfo, FunctionInfo, Info, ParamInfo, TypeForm },
        byllm.visit_routing { ClassInfo },
        compiler.driver.compiler { info_graph_from_json },
        compiler.driver.unit_products { Info, info_graph_to_json },
        compiler.passes.mtir_gen_pass {
            ClassInfo,
            EnumInfo,
            FieldInfo,
            FunctionInfo,
            MethodInfo,
            ParamInfo,
            TypeForm,
            mk_dict,
            mk_form,
            mk_list,
            type_to_str
        },
    ]
    type runtime.semantic ++> compiler.driver.program | compiler.driver.progstate {
        Info
    }
    runtime.sized --> [
        compiler.tests.test_fixed_width_equivalence
            | data.serializer.Serializer._declared_of { SIZED_TYPES },
        data.serializer.Serializer._serialize_value { json_wire_form },
        data.serializer.Serializer.coerce { json_wire_read },
    ]
    runtime.source_app ++> dist.source.project.export_project { SOURCE_FORMAT }
    runtime.surface ++> compiler.driver.unit_products
        | compiler.frontend.codeinfo
        | server.server.ModuleIntrospector._load_surface { SurfaceEntry }
    runtime.surface --> compiler.passes.boundary_analysis_pass.BoundaryAnalysisPass._record_surface {
        SurfaceEntry
    }
    runtime.traceback_render --> [
        cli.commands.execution._exec_file { dump_traceback },
        cli.commands.execution.serve { dump_traceback },
    ]
    runtime.typecache ++> [
        data.serializer { get_field_types },
        data.serializer.Serializer.register {
            invalidate as _invalidate_typecache,
            warm as _warm_typecache
        },
    ]
    scale as scale_mod ++> server.endpoints.pages.register_graph_endpoints.graph_page;
    scale.config.config_loader --> server.shared_store.scale_db_url { get_scale_config }
    scale.plugin ++> cli.commands.execution._serve_fleet { scale_local_serve }
    comptime scale.plugin ++> cli.manifest { SPEC_SCALE_CMD }
    scale.runtime.provider ++> cli.commands.execution.serve { mark_scale_runtime }
    scale.runtime.provider --> [
        runtime.runtime._scale_provider { JacScaleRuntime },
        runtime.source_app.main { mark_scale_runtime },
    ]
    scale.server.inprocess ++> client.targets.desktop.native.host_boot.serve_program {
        prepare_inprocess_runtime
    }
    server.assembly ++> [
        cli.commands.execution {
            gateway_colocates as _gateway_colocates,
            service_apps as _service_apps
        },
        dist.seal.prepare_serve_payloads { service_apps },
        dist.source.project.export_project { gateway_colocates, service_apps },
    ]
    server.assembly --> [
        cli.commands.execution.serve
            | dist.precompile_bytecode._application_sources
            | scale.server.inprocess.prepare_inprocess_runtime { service_apps },
        runtime.prepared.initialize_application { assemble_served_program },
    ]
    server.bridge ++> scale.tests.data.test_eager_spawn { BridgeUnavailable }
    server.bridge --> scale.tests.server.test_sv_streaming { BridgeError }
    server.build_status ++> cli.commands.execution
        | scale.tests.server.test_build_status_endpoint { BuildMonitor }
    server.endpoints.auth ++> [
        scale.admin.admin_portal { refused, throttled },
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway._install_admin_api
            | scale.tests.server.test_registration_challenge
            | scale.tests.server.test_registration_limits { register_auth_endpoints },
        scale.runtime.middleware.rate_limit.build_client_error_limit_middleware {
            throttled
        },
        scale.server.extensions { register_mail_endpoints },
    ]
    server.endpoints.colocated ++> scale.tests.server.test_sv_outbox_endpoints {
        register_colocated_endpoints
    }
    server.endpoints.pages ++> scale.runtime.middleware.rate_limit.build_client_error_limit_middleware {
        CLIENT_ERROR_PATH
    }
    server.endpoints.pages --> scale.tests.server.test_build_status_endpoint {
        register_diagnostics_endpoints
    }
    server.exchange --> scale.tests.server.test_restspec { current_request, respond }
    server.hmr ++> compiler.driver.build_services.CompilerBuildServices.hot_reloader
        | scale.tests.server.test_build_status_endpoint { HotReloader }
    server.hmr --> cli.commands.execution.serve { HotReloader }
    type server.hmr ++> compiler.driver.build_services
        | runtime.build_services
        | testing.testing { HotReloader }
    server.identity.assurance ++> [
        scale.admin.admin_portal { METHOD_PASSWORD, second_factor_claims },
        scale.sso.grants { caller_user_id },
        scale.sso.oauth_session { METHOD_FEDERATED },
        scale.tests.server.test_sso_grants { bind_caller_user, release_caller_user },
    ]
    server.identity.assurance --> scale.tests.data.test_gateway_owned_identity {
        caller_assurance_level,
        second_factor_claims
    }
    server.identity.audit ++> scale.admin.admin_portal { client_ip }
    server.identity.auth_models ++> [
        scale.admin.admin_portal { IdentityInputModel },
        scale.server.sso_ext { FirebaseTokenRequest },
        scale.tests.server.test_registration_challenge
            | scale.tests.server.test_registration_limits { RegisterRequest },
    ]
    server.identity.auth_tokens ++> [
        scale.sso.oauth_session
            | scale.sso.sso_auth
            | scale.tests.server.test_oauth_session
            | scale.tests.server.test_registration_challenge
            | scale.tests.server.test_sso
            | scale.tests.server.test_sso_grants { AuthTokenStore },
        scale.tests.data.test_auth_tokens_fail_closed
            | scale.tests.server.test_emailer_factory {
            AuthTokenStore,
            reset_auth_token_store
        },
    ]
    server.identity.config ++> [
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway._install_admin_api
            | scale.tests.server.test_auth_policy_startup
            | scale.tests.server.test_sso_grants { configure_identity },
        scale.sso.github | scale.sso.oauth_session { auth_settings },
        scale.sso.grants | scale.tests.server.test_admin { signing_secret },
        scale.tests.data.test_gateway_owned_identity {
            signing_algorithm as jwt_algorithm,
            signing_secret as jwt_secret
        },
        scale.tests.server.test_serve { signing_secret as jwt_secret },
        scale.webhook.webhook.WebhookUtils.create_api_key_token {
            signing_algorithm,
            signing_secret
        },
        scale.webhook.webhook.WebhookUtils.validate_api_key {
            signing_algorithm,
            signing_secret
        },
    ]
    server.identity.config --> [
        scale.tests.microservices.test_microservice {
            signing_algorithm as jwt_algorithm,
            signing_secret as jwt_secret
        },
        scale.tests.server.test_oauth_session | scale.tests.server.test_sso {
            configure_identity
        },
    ]
    server.identity.identity_storage ++> [
        scale.sso.oauth_session { primary_username },
        scale.tests.data.test_identity_password { IdentityStorage },
    ]
    server.identity.identity_storage --> scale.tests.data.test_auth_cutover {
        PgIdentityStorage
    }
    server.identity.identity_storage as storage_mod --> scale.tests.data.test_identity_fail_loud;
    server.identity.mail ++> scale.runtime.gateway.microservice_gateway.MicroserviceGateway._install_admin_api
        | scale.tests.server.test_auth_policy_startup { verification_problems }
    server.identity.policy ++> [
        scale.deploy.target.kubernetes.target { minted_password },
        scale.server.extensions { check_password },
        scale.sso.oauth_session { check_email },
        scale.tests.server.test_auth_policy_startup { check_password, minted_password },
    ]
    server.identity.rate_limit ++> [
        client.source_mapping.ClientErrorLimiter.admit
            | scale.tests.server.test_registration_limits { consume_limit },
        scale.admin.admin_portal { AttemptsExhausted },
    ]
    server.identity.registration_challenge ++> scale.tests.server.test_registration_challenge {
        consume_challenge,
        issue_challenge
    }
    server.identity.second_factor ++> scale.admin.admin_portal {
        SecondFactorUnavailable
    }
    server.identity.user_manager ++> [
        runtime.runtime.JacPersistence.get_user_manager
            | scale.admin.admin_portal
            | scale.runtime.gateway.microservice_gateway
            | scale.sso.oauth_session
            | scale.sso.sso_auth
            | scale.tests.data.test_gateway_owned_identity
            | scale.tests.data.test_identity_fail_loud
            | scale.tests.misc.test_shared_store_failure
            | scale.tests.server.test_auth_policy_startup
            | scale.tests.server.test_firebase_auth_sso
            | scale.tests.server.test_sso
            | scale.tests.server.test_sso_grants
            | scale.tests.server.test_ws_hardening { UserManager },
        scale.server.jobs_ext { SYSTEM_USER, UserRole },
        scale.server.webhook_ext { SYSTEM_USER },
        scale.tests.server.oauth_fixtures
            | scale.tests.server.test_oauth_session
            | scale.tests.server.test_registration_challenge { SessionGrant },
    ]
    server.identity.user_manager --> [
        scale.tests.server.test_oauth_session { SecondFactorRequired, UserManager },
        scale.tests.support { UserManager },
    ]
    type server.identity.user_manager ++> runtime.runtime { UserManager }
    server.middleware ++> [
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway._install_admin_api {
            jwt_middleware
        },
        scale.server.jobs_ext | scale.server.sso_ext { require_user },
    ]
    server.middleware --> scale.tests.data.test_gateway_owned_identity {
        jwt_middleware
    }
    server.net ++> [
        cli.commands.execution._find_free_port { find_available_port },
        cli.errmap.humanize_error { PortInUseError },
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.start {
            PORT_RETRY_LIMIT
        },
    ]
    server.net --> [
        cli.commands.execution.serve { PortInUseError },
        scale.tests.server.test_serve {
            ERRNO_ADDR_IN_USE,
            PORT_RETRY_LIMIT,
            PortInUseError,
            find_available_port as _find_available_port
        },
    ]
    server.outbox ++> scale.tests.server.test_sv_outbox_endpoints {
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
    server.outbox --> scale.tests.server.test_sv_streaming {
        STATUS_DELIVERED,
        SqliteOutboxStore,
        default_idempotency_key,
        deliver_pending,
        enqueue,
        use_store
    }
    server.request_scope ++> scale.server.websocket_ext { RequestScope }
    server.sealed_serve ++> [
        cli.commands.execution._jab_native_bin
            | dist.precompile_bytecode.seal_native
            | dist.seal.bake_native_payloads { NATIVE_DIR_REL },
        client.artifact.client_output_dir { client_dist_for },
        client.artifact.prebuilt_bundle { client_dist_for, serve_manifest_for },
        compiler.driver.application._prepare_sealed {
            CLIENT_DIST_REL,
            read_serve_manifest
        },
        dist.precompile_bytecode._served_client_root
            | scale.injector.bundle.require_serve_manifest { SERVE_MANIFEST_REL },
        dist.precompile_bytecode._served_codespace { SERVE_MANIFEST_REL },
        dist.precompile_bytecode.app_metadata { CLIENT_DIST_REL, NATIVE_DIR_REL },
        dist.precompile_bytecode.collect_payloads {
            CLIENT_DIST_REL,
            NATIVE_DIR_REL,
            SERVE_MANIFEST_REL
        },
        dist.precompile_bytecode.seal_runtime_closure { SERVE_MANIFEST_REL },
        dist.seal.bake_serve_payloads { CLIENT_DIST_REL, SERVE_MANIFEST_REL },
        dist.seal.prepare_serve_payloads { serve_manifest_stamp },
    ]
    server.sealed_serve --> [
        compiler.driver.application.prepare_application {
            sealed_root_for,
            unlisted_image_root
        },
        scale.injector.bundle.pack_jab | scale.tests.microservices.test_app_precompile {
            SERVE_MANIFEST_REL
        },
    ]
    server.server ++> [
        client.targets.desktop.native.broker_extension
            | scale.server.extensions
            | scale.server.inprocess
            | scale.server.jobs_ext
            | scale.server.sso_ext
            | scale.server.websocket_ext { JacAPIServer, ServerExtension },
        runtime.builtin.restspec { restspec_fields },
        runtime.runtime.JacServe.get_api_server_class
            | scale.tests.data.test_eager_spawn
            | scale.tests.microservices.test_microservice
            | scale.tests.server.test_host_serving
            | scale.tests.server.test_served_app_route
            | scale.tests.server.test_sv_outbox_endpoints
            | testing.testing { JacAPIServer },
        scale.admin.admin_portal
            | scale.admin.deploy_health
            | scale.admin.logs
            | scale.admin.network
            | scale.admin.ops
            | scale.admin.podenv
            | scale.admin.traces
            | scale.admin.workloads
            | scale.runtime.gateway.microservice_gateway
            | scale.tests.server.test_sso { EndpointHost },
        scale.admin.llm_telemetry { EndpointHost, JsonValue },
        scale.server.webhook_ext { JacAPIServer, JsonValue, ServerExtension },
        scale.tests.server.test_auth_policy_startup { EndpointHost, ServerExtension },
    ]
    server.server --> [
        client.targets.client_dev_common.dev_proxy_paths { ModuleIntrospector },
        runtime.source_app.main | scale.tests.data.test_identity_fail_loud {
            JacAPIServer
        },
        scale.tests.support { EndpointHost },
    ]
    type server.server ++> [
        client.serving { ModuleIntrospector },
        runtime.builtin.restspec | testing.testing { JacAPIServer },
        runtime.runtime {
            JacAPIServer as JacServer,
            ModuleIntrospector,
            ServerExtension
        },
        scale.runtime.provider { JacAPIServer as JacServer, ServerExtension },
    ]
    server.serving.accesslog --> scale.tests.server.test_serve {
        ACCESS_LOGGER_NAME,
        AccessJsonFormatter,
        AccessRecord,
        HealthCheckFilter,
        access_logger,
        configure_access_logging
    }
    server.serving.app ++> [
        scale.runtime.gateway.embedded_gateway
            | scale.runtime.gateway.microservice_gateway
            | scale.tests.microservices.test_gateway_webapp
            | scale.tests.microservices.test_sse_framing
            | scale.tests.server.test_bodiless_status
            | scale.tests.server.test_error_envelope
            | scale.tests.server.test_serving_tail
            | scale.tests.server.test_stream_ws._spawn_upstream
            | testing.testkit { ServingApp },
        scale.runtime.middleware.rate_limit.build_client_error_limit_middleware
            | scale.tests.server.test_auth_policy_startup
            | scale.tests.server.test_registration_limits { transport_to_response },
        scale.tests.server.test_stream_ws._spawn_ws_upstream { ServingApp },
        scale.tests.server.test_stream_ws._spawn_ws_upstream_with_protocol {
            ServingApp
        },
    ]
    server.serving.app --> scale.tests.microservices.test_drain { ServingApp }
    server.serving.authcrypt ++> [
        scale.deploy.target.kubernetes.manifest_builder
            | scale.deploy.target.kubernetes.utils.kubernetes_utils.resolve_minted_secret
            | scale.tests.deploy.test_deployment_overlay
            | scale.tests.deploy.test_pod_env { PLACEHOLDER_JWT_SECRET },
        scale.tests.data.test_auth_cutover {
            SCRYPT_MAXMEM,
            SCRYPT_MAX_N,
            hash_password,
            is_prescrypt_hash,
            verify_password
        },
        scale.tests.data.test_dev_signing_secret {
            PLACEHOLDER_JWT_SECRET,
            jwt_decode,
            jwt_encode,
            project_data_dir,
            project_signing_secret
        },
        scale.tests.data.test_gateway_owned_identity { jwt_encode },
        scale.tests.server.test_admin { jwt_decode },
        scale.tests.server.test_serve {
            jwt_decode as _jwt_decode,
            jwt_encode as _jwt_encode
        },
        scale.webhook.webhook { JWTError, JWTExpiredError, jwt_decode, jwt_encode },
    ]
    server.serving.authcrypt --> scale.tests.microservices.test_microservice
        | scale.tests.server.test_oauth_providers { jwt_encode }
    server.serving.authcrypt as ac --> scale.tests.data.test_auth_cutover;
    server.serving.client ++> [
        scale.admin.logs._loki_request | scale.admin.traces._tempo_request {
            ClientConnectionError,
            arequest
        },
        scale.admin.ops._http_ready
            | scale.sso.github
            | scale.sso.google
            | scale.sso.provider { arequest },
        scale.admin.ops._loki_recent_count { arequest },
        scale.admin.ops._tempo_recent_count { arequest },
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.forward_to {
            ClientReadTimeout,
            ClientRequestNotSent
        },
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.probe_services {
            ClientReadTimeout,
            ClientRequestNotSent
        },
        scale.runtime.middleware.ws_forward { ClientConnectionError, aws_connect },
        scale.runtime.rpc.rpc._rpc_with_retries {
            ClientConnectionError,
            ClientRequestNotSent
        },
        scale.runtime.rpc.rpc.service_call { post_stream_aware_sync },
        scale.runtime.rpc.rpc.walker_call { request_sync },
        scale.runtime.transport.http_forward {
            ClientConnectionError,
            ClientReadTimeout,
            ClientRequestNotSent,
            arequest
        },
        scale.tests.server.test_serve | testing.testing { run_blocking },
        scale.tests.server.test_stream_ws
            | scale.tests.server.test_sv_auth_forward._install_unreachable_transport {
            ClientRequestNotSent
        },
        scale.tests.server.test_sv_auth_forward._install_unreachable_walker_transport {
            ClientRequestNotSent
        },
        testing.testkit { aws_connect, run_blocking },
    ]
    server.serving.client --> scale.tests.server.test_serve { aws_connect }
    server.serving.client as sv_http ++> scale.tests.server.test_sv_auth_forward;
    server.serving.compression ++> scale.tests.microservices.test_sse_framing {
        CompressionPolicy,
        GzipCache,
        _gzip_stream
    }
    server.serving.datatypes ++> [
        client.targets.desktop.native.broker_extension {
            HTMLResponse,
            JSONResponse,
            Request,
            Response,
            StreamingResponse
        },
        scale.admin.admin_portal {
            FileResponse,
            JSONResponse,
            RedirectResponse,
            Request,
            Response
        },
        scale.admin.admin_portal.JacAPIServerAdmin.register_admin_endpoints
            | scale.admin.workloads
            | scale.server.jobs_ext
            | scale.server.webhook_ext
            | scale.tests.server.test_firebase_auth_sso
            | scale.tests.server.test_oauth_providers
            | scale.tests.server.test_registration_limits
            | scale.tests.server.test_static_fallback { Request },
        scale.admin.console_build { HTMLResponse, Response },
        scale.admin.deploy_health
            | scale.admin.llm_telemetry
            | scale.admin.logs
            | scale.admin.network
            | scale.admin.ops
            | scale.admin.podenv
            | scale.admin.traces { JSONResponse, Request },
        scale.observability.prometheus_metrics { Response },
        scale.runtime.context.errors
            | scale.tests.microservices.test_rate_limit.next_handler { JSONResponse },
        scale.runtime.gateway.embedded_gateway
            | scale.server.extensions
            | scale.tests.microservices.test_gateway_webapp {
            JSONResponse,
            Request,
            Response
        },
        scale.runtime.gateway.microservice_gateway {
            HTMLResponse,
            JSONResponse,
            Request,
            Response
        },
        scale.runtime.transport.http_forward { StreamingResponse },
        scale.server.sso_ext | scale.sso.provider | scale.sso.sso_auth {
            RedirectResponse,
            Request,
            Response
        },
        scale.server.websocket_ext | scale.websocket.websocket { WebSocketDisconnect },
        scale.sso.firebase | scale.tests.server.test_stream_ws._spawn_upstream {
            Request,
            Response
        },
        scale.tests.microservices.test_drain { JSONResponse, Request, URL },
        scale.tests.microservices.test_gateway
            | scale.tests.microservices.test_rate_limit
            | scale.tests.server.test_serve { Headers, Request, URL },
        scale.tests.microservices.test_sse_framing { Headers, Request, Response },
        scale.tests.server.test_bodiless_status { Response, StreamingResponse },
        scale.tests.server.test_oauth_providers._callback_request { QueryParams, URL },
        scale.tests.server.test_sso {
            Headers,
            QueryParams,
            RedirectResponse,
            Request,
            URL
        },
        scale.tests.server.test_static_fallback._get_request { URL },
        scale.tests.server.test_sv_streaming._StubResp.headers_obj { Headers },
        testing.testing | testing.testkit {
            Headers,
            QueryParams,
            Request,
            Response,
            URL,
            parse_query_string
        },
    ]
    server.serving.datatypes --> [
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.handle_admin {
            RedirectResponse
        },
        scale.tests.data.test_gateway_owned_identity { Request, Response },
        scale.tests.server.test_build_status_endpoint { Request },
        scale.tests.server.test_stream_ws { WebSocketDisconnect },
        scale.tests.server.test_stream_ws._spawn_upstream.big { StreamingResponse },
        scale.tests.server.test_stream_ws._spawn_upstream.sse { StreamingResponse },
    ]
    server.serving.drain ++> [
        runtime.builtin.on_drain | runtime.runtime.JacRuntime.after_fork_in_child {
            DRAIN_HOOKS
        },
        scale.runtime.gateway.microservice_gateway { DrainState },
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
            drain_middleware
        },
        scale.server.extensions { HEALTH_PATHS },
        scale.tests.microservices.test_drain {
            DRAIN_HOOKS,
            DRAIN_TAKEN,
            DrainState,
            drain_middleware
        },
    ]
    server.serving.endpoint ++> [
        client.targets.desktop.native.broker_extension
            | scale.admin.admin_portal
            | scale.admin.llm_telemetry
            | scale.admin.logs
            | scale.admin.traces
            | scale.admin.workloads
            | scale.server.jobs_ext
            | scale.server.sso_ext
            | scale.server.webhook_ext {
            APIParameter,
            HTTPMethod,
            JEndPoint,
            ParameterType
        },
        scale.admin.deploy_health
            | scale.admin.network
            | scale.admin.ops
            | scale.admin.podenv
            | scale.server.extensions
            | scale.tests.server.test_bodiless_status
            | scale.tests.server.test_stream_ws._spawn_upstream {
            HTTPMethod,
            JEndPoint
        },
        scale.runtime.gateway.microservice_gateway { JEndPoint, WSEndPoint },
        scale.tests.deploy.test_ops_deploy
            | scale.tests.deploy.test_ops_health
            | scale.tests.deploy.test_ops_network
            | scale.tests.misc.test_ops_podenv { HTTPMethod },
        scale.tests.server.test_auth_policy_startup | scale.tests.server.test_sso {
            JEndPoint
        },
        scale.tests.server.test_serving_tail { HTTPMethod, JEndPoint, WSEndPoint },
        scale.tests.server.test_stream_ws._spawn_ws_upstream { WSEndPoint },
        scale.tests.server.test_stream_ws._spawn_ws_upstream_with_protocol {
            WSEndPoint
        },
    ]
    server.serving.endpoint --> [
        scale.tests.server.test_admin_logs { HTTPMethod },
        scale.tests.support { JEndPoint },
    ]
    server.serving.files ++> [
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.serve_spa_fallback {
            file_response
        },
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.static_file {
            file_response
        },
    ]
    server.serving.middleware ++> scale.config.config_loader.normalize_gateway_config {
        cors_pair_problem
    }
    server.serving.middleware --> scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
        cors_middleware
    }
    server.serving.model ++> scale.scheduler.scheduler_models { ApiModel, require_str }
    server.serving.openapi ++> [
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.handle_docs {
            swagger_ui_html
        },
        scale.tests.server.test_serving_tail { build_openapi },
    ]
    server.serving.proxy ++> scale.tests.microservices.test_rate_limit {
        ProxyResolver,
        _untrusted_warned,
        logger as _proxy_logger
    }
    server.serving.server ++> [
        scale.runtime.gateway.embedded_gateway.EmbeddedGateway.serve {
            PORT_RETRY_LIMIT,
            ServingServer
        },
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.start
            | scale.tests.microservices.test_app_routes._expose_backend
            | scale.tests.microservices.test_gateway_webapp
            | scale.tests.microservices.test_sse_framing
            | scale.tests.server.test_bodiless_status
            | scale.tests.server.test_serving_tail
            | scale.tests.server.test_stream_ws._spawn_upstream
            | scale.tests.server.test_sv_outbox_endpoints
            | testing.testkit { ServingServer },
        scale.tests.server.test_stream_ws._spawn_ws_upstream { ServingServer },
        scale.tests.server.test_stream_ws._spawn_ws_upstream_with_protocol {
            ServingServer
        },
    ]
    server.serving.server --> scale.tests.microservices.test_drain
        | scale.tests.microservices.test_microservice { ServingServer }
    server.serving.sse ++> [
        scale.runtime.rpc.rpc._iter_sse_text { consume_sse_events },
        scale.tests.microservices.test_sse_framing { sse_frame_stream },
        scale.tests.server.test_sv_streaming {
            consume_sse_events as consume_sse_stream,
            parse_sse as _parse_sse
        },
    ]
    server.serving.supervisor ++> cli.commands.execution.serve { worker_metrics_dir }
    server.serving.supervisor --> runtime.source_app.main { worker_metrics_dir }
    server.serving.ws ++> [
        scale.runtime.gateway.microservice_gateway
            | scale.server.websocket_ext
            | scale.tests.server.test_ws_hardening
            | scale.websocket.protocol
            | scale.websocket.websocket { WebSocket },
        scale.tests.server.test_serving_tail {
            OP_CLOSE,
            OP_CONT,
            OP_PING,
            OP_PONG,
            OP_TEXT,
            encode_frame,
            read_frame
        },
        scale.websocket.websocket.WebSocketConnectionManager._local_fanout {
            _ws_json_default
        },
    ]
    server.session ++> [
        cli.commands.db._open_project_store
            | scale.tests.server.test_scheduler_multipod._unreachable_store {
            conninfo_from_url
        },
        cli.commands.db._project_data_dir | scale.tests.data.test_pg_stream {
            shared_pg_data_dir
        },
        cli.commands.db._project_database { project_db_name },
        cli.commands.db._project_target { project_db_name },
        cli.commands.db._runtime_for { scratch_owner_pid },
        data.query_planner | runtime.context.ExecutionContext.__post_init__ { Session },
        scale.injector.bundle.seal_step_env { SCRATCH_ENV },
        scale.memory.context.JScaleExecutionContext.init {
            Session,
            conninfo_from_url,
            promotions_for
        },
        testing.test_runner._fresh_jac_state { mark_scratch_base },
        testing.test_runner.run_tests { own_child_databases },
    ]
    server.session --> [
        cli.commands.db._db_status
            | scale.events.streams.postgres.PgEventStream._ensure_store {
            conninfo_from_url
        },
        cli.commands.execution.serve { takeover_project },
        client.targets.desktop.native.host_boot._migrate_legacy_database {
            project_database,
            shared_pg_data_dir
        },
        runtime.runtime.JacGraph.refs | scale.tests.server.test_sv_outbox_endpoints {
            Session
        },
        scale.tests.deploy.test_postgres_predicate_lock_headroom { shared_pg_data_dir },
        scale.tests.microservices.test_app_precompile { SCRATCH_ENV },
    ]
    server.settings ++> [
        cli.commands.execution.serve
            | scale.runtime.gateway.microservice_gateway.MicroserviceGateway._install_admin_api
            | scale.tests.data.test_dev_signing_secret {
            ServeConfigError,
            ServeSettings
        },
        scale.deploy.target.kubernetes.manifest_builder { AuthSettings, resolve_count },
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.setup {
            ServeSettings,
            in_cluster
        },
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.start
            | scale.server.inprocess
            | scale.tests.server.test_host_serving
            | scale.tests.server.test_serving_tail
            | scale.tests.server.test_sv_outbox_endpoints { ServeSettings },
        scale.tests.deploy.test_deployment_overlay { ServeConfigError },
        scale.tests.server.test_auth_policy_startup {
            AuthSettings,
            EmailSettings,
            LockoutSettings,
            PasswordSettings
        },
        scale.tests.server.test_registration_challenge
            | scale.tests.server.test_registration_limits {
            AuthSettings,
            RegistrationSettings
        },
        scale.tests.server.test_sso_grants { AuthSettings, PasswordSettings },
    ]
    server.settings --> [
        runtime.source_app.main
            | scale.tests.microservices.test_drain
            | scale.tests.server.test_serve { ServeSettings },
        scale.tests.server.test_auth_policy_http { ServeConfigError },
        scale.tests.server.test_oauth_session {
            AuthSettings,
            EmailSettings,
            IdentifierSettings,
            LockoutSettings,
            PasswordSettings,
            RegistrationSettings
        },
        scale.tests.server.test_sso { AuthSettings, IdentifierSettings },
    ]
    server.shared_store ++> [
        scale.memory.context.JScaleExecutionContext.init
            | scale.server.extensions.EventsExtension.register
            | scale.websocket.backplane.build_backplane { scale_db_url },
        scale.scheduler.scheduler
            | scale.sso.oauth_session.OAuthSession.complete_native
            | scale.webhook.webhook
            | scale.websocket.backplane.PgBackplane.start { shared_store },
        scale.server.extensions.EventsExtension.validate { scale_db_url },
        scale.sso.oauth_session.OAuthSession.poll { shared_store },
        scale.state.factory { shared_store, shared_store_failure },
    ]
    server.shared_store --> [
        scale.admin.ops._postgres_ping_blocking {
            NO_DATABASE_RESOLVED,
            shared_store,
            shared_store_failure
        },
        scale.events.streams.postgres.PgEventStream._ensure_store { scale_db_url },
        scale.tests.server.test_oauth_session { shared_store },
    ]
    server.shared_store as pg_mod ++> scale.tests.misc.test_shared_store_failure;
    server.shared_store as store_mod ++> scale.tests.misc.test_state_backend_selection;
    server.static_files ++> [
        client.targets.seo_build.apply_seo { ROBOTS_PATH, SITEMAP_PATH },
        client.targets.seo_build.clear_seo_files { ROBOTS_PATH, SITEMAP_PATH },
        client.targets.seo_build.render_robots { SITEMAP_PATH },
        client.targets.web_target._copy_public_dirs { ROOT_ASSET_EXTENSIONS },
        scale.runtime.gateway.embedded_gateway.EmbeddedGateway._serve_static {
            SEO_ROOT_FILES
        },
        scale.runtime.gateway.embedded_gateway.EmbeddedGateway.dispatch {
            robots_response
        },
        scale.runtime.gateway.microservice_gateway.MicroserviceGateway.handle_static {
            SEO_ROOT_FILES,
            robots_response
        },
    ]
    server.sv_client ++> [
        client.targets.client_dev_common { headless_start_args },
        scale.runtime.orchestrator.process_manager.ServiceProcessManager.start_service {
            app_start_args,
            headless_start_args,
            peer_url_env_key
        },
        scale.tests.deploy.test_pod_env { peer_url_env_key },
    ]
    server.task_scheduler ++> [
        runtime.builtin.schedule { ScheduleSpec },
        scale.scheduler.scheduler { Scheduler, schedule_namespace, tick_of },
        scale.server.extensions { RunOutcome },
        scale.tests.server.test_scheduler_multipod { ScheduleSpec, Scheduler, tick_of },
    ]
    server.transport ++> [
        scale.admin.admin_portal
            | scale.admin.workloads
            | scale.server.jobs_ext
            | scale.server.sso_ext
            | scale.server.webhook_ext
            | scale.shared.utils
            | scale.sso.sso_auth
            | scale.webhook.webhook { Meta, TransportResponse },
        scale.tests.server.test_firebase_auth_sso { TransportResponse },
    ]
    server.watcher ++> [
        client.targets.client_dev_common
            | client.targets.mobile_target
            | client.targets.react_native.dev { FileChangeEvent },
        client.targets.desktop.webview_shell.webview_dev
            | compiler.driver.build_services.CompilerBuildServices.hot_reloader
            | scale.tests.server.test_build_status_endpoint { JacFileWatcher },
    ]
    server.watcher --> [
        cli.commands.execution.serve { JacFileWatcher, application_watch_roots },
        client.targets.mobile_target.MobileTarget.dev
            | client.targets.web_target.WebTarget.dev { JacFileWatcher },
    ]
    studio.app ++> cli.commands.studio.studio { run_studio }
    testing.cl_test_runner ++> scale.tests.server.test_cl_test_runner {
        run_cl_test_file
    }
    testing.requires ++> [
        scale.tests.deploy.test_deploy_k8s { require_flag },
        scale.tests.microservices.test_fat_bundle { require_network },
        scale.tests.server.test_scheduler_endpoints
            | scale.tests.server.test_scheduler_multipod { require_module },
    ]
    testing.runner ++> compiler.driver.build_services.CompilerBuildServices.run_test {
        run_test
    }
    testing.test ++> [
        compiler.tests.test_pipeline_products
            | compiler.tests.test_prim_equivalence
            | scale.tests.deploy.test_k8s_utils { parametrize },
        runtime.runtime.JacTest.jac_test { JacTestCheck },
    ]
    testing.test_runner ++> [
        cli.commands.analysis.test { run_tests },
        scale.tests.support { STRICT_ENV, strict_mode },
    ]
    testing.testkit ++> [
        scale.server.inprocess.prepare_inprocess_runtime
            | scale.tests.microservices.test_gateway_docs_precedence
            | scale.tests.microservices.test_gateway_webapp
            | scale.tests.server.test_error_envelope { ServingTestClient },
        scale.tests.data.test_eager_spawn
            | scale.tests.microservices.test_embedded_gateway
            | scale.tests.microservices.test_microservice
            | scale.tests.server.test_served_app_route
            | scale.tests.server.test_sv_outbox_endpoints {
            ServingTestClient as TestClient
        },
    ]
    testing.testkit --> [
        scale.tests.apps.test_fleet_from_apps
            | scale.tests.microservices.test_app_routes
            | scale.tests.microservices.test_gateway
            | scale.tests.server.test_stream_ws { ServingTestClient as TestClient },
        scale.tests.microservices.test_gateway._gateway {
            ServingTestClient as TestClient
        },
    ]
    toolchains.android ++> [
        client.targets.react_native.build.run_eas_local_build { ensure_android },
        client.targets.react_native.build.run_gradle_assemble { ensure_android },
    ]
    toolchains.apple ++> [
        client.targets.react_native.build.run_eas_local_build { ensure_apple },
        client.targets.react_native.build.run_xcodebuild_ios { ensure_apple },
    ]
    toolchains.c_backend ++> compiler.backends.native.c_emit.emit_c { ensure_c_backend }
    toolchains.c_backend --> dist.source.project.export_project {
        c_backend_license,
        c_backend_provenance
    }
    toolchains.cef ++> client.targets.desktop.cef_shell { ensure_cef }
    toolchains.desktop ++> [
        client.targets.desktop.cef_shell._ensure_cef_subprocess
            | client.targets.desktop.desktop_build._unit_source { module_files },
        client.targets.desktop.cef_shell._ensure_libcef_dispatch { module_files },
        client.targets.desktop.cef_shell.cef_build
            | client.targets.desktop.desktop_build._stage_fused_runtime
            | client.targets.desktop.webview_shell._assemble_native_host {
            stage_module
        },
        client.targets.desktop.desktop_build._find_cef_dir { source_workspace },
        client.targets.desktop.desktop_build._find_webview_dir { source_workspace },
        client.targets.desktop.desktop_build.build_cef_dispatch { source_workspace },
        client.targets.desktop.desktop_build.build_cef_subprocess { source_workspace },
        client.targets.desktop.macos_bundle { MACOS_DESKTOP_MIN_VERSION },
        client.targets.desktop.webview_shell { ensure_webview, webview_library_name },
    ]
    toolchains.desktop --> client.targets.desktop.desktop_build._find_native_asset_dir {
        source_workspace
    }
    toolchains.host ++> [
        client.targets.desktop.webview_shell { host_platform },
        client.targets.react_native.build.run_xcodebuild_ios { run_step },
    ]
    toolchains.javascript ++> [
        client.targets.react_native.build.run_eas_local_build { build_environment },
        client.targets.react_native.build.run_expo_prebuild { build_environment },
        client.targets.react_native.build.run_gradle_assemble { build_environment },
        client.targets.react_native.build.run_xcodebuild_ios { build_environment },
    ]
    toolchains.manager --> client.cli.setup { setup_toolchain }
    toolchains.store ++> [
        client.targets.mobile_target.MobileTarget.ensure_ready
            | client.targets.node_tooling_common.run_manifest_install
            | client.targets.react_native.build.run_eas_local_build
            | packages.sources.checkout { offline },
        client.targets.react_native.build.run_gradle_assemble { offline },
        client.targets.react_native.build.run_xcodebuild_ios { offline },
        data.pg_dist._unpack { Artifact as Download, extract, fetch },
        dist.self_update.update_self
            | packages.index.fetch_verified
            | scale.injector.binary._fetch_verified_asset { Artifact, fetch },
        packages.index.Registry._read { allowed_url, offline },
    ]
    toolchains.system ++> client.targets.desktop.desktop_build._patchelf_rpath {
        ensure_patchelf
    }
}

graph import artifacts {
    kit ++> router._omitted { kit_image }
    model ++> router {
        Artifact,
        ArtifactKind,
        ArtifactUnavailable,
        Probe,
        ReleasePolicy,
        Resolution,
        Source
    }
    router ++> model.Artifact.disabled { building_now }
}

graph import byllm {
    _optdeps.litellm ++> [
        exceptions { when_litellm_loaded },
        llm { _disable_debugging, litellm, when_litellm_loaded },
        types { LiteLLMMessage },
    ]
    _optdeps.loguru ++> llm | visit_routing { logger }
    _optdeps.openai ++> llm { AsyncOpenAI, OpenAI, openai }
    _optdeps.pillow ++> types { PILImageCls, open_image }
    _optdeps.pydantic ++> [
        llm { TypeAdapter, from_json },
        schema | types { TypeAdapter },
    ]
    config_loader ++> llm | mtir { get_byllm_config }
    deadline ++> llm | mtir { CallDeadline }
    exceptions ++> [
        deadline { LLMTimeout },
        lib {
            AuthenticationError,
            ByLLMError,
            ConfigurationError,
            FinishToolError,
            LLMTimeout,
            McpError,
            ModelNotFoundError,
            OutputConversionError,
            OutputTruncatedError,
            RateLimitError
        },
        llm {
            AuthenticationError,
            ByLLMError,
            CompactionNotEffectiveError,
            ConfigurationError,
            FinishToolError,
            LLMTimeout,
            ModelNotFoundError,
            OutputConversionError,
            OutputTruncatedError,
            RateLimitError
        },
        mcp { McpError },
        mtir { ConfigurationError, OutputConversionError },
        schema { ConfigurationError },
        systemone { OutputConversionError },
        types { ByLLMError, FinishToolError },
    ]
    llm ++> [
        lib { MockLLM, MockSystemOne, Model, ModelPool, SystemOneModel },
        visit_routing { BaseLLM },
    ]
    local_runtime ++> [
        cli._cmd_model { LOCAL_MODELS, list_local_aliases },
        llm {
            LOCAL_MODELS,
            filter_params,
            list_local_aliases,
            parse_alias,
            wrap_tool_call
        },
    ]
    mcp ++> [
        lib { McpClient, McpTool },
        mtir | types { McpTool },
    ]
    model_cache ++> [
        cli._cmd_model {
            force_pull,
            get_cache_dir,
            is_downloaded,
            list_downloaded,
            remove_alias
        },
        llm { ensure_model },
    ]
    mtir ++> [
        lib { MTIR, MTRuntime },
        llm | systemone | visit_routing.route_visit { MTRuntime },
    ]
    type mtir ++> telemetry { MTRuntime }
    parallel ++> [
        lib { dispatch_batch, mark_serialize },
        llm { _PARALLEL_TOOL_HINT, _index_by_identity, dispatch_batch },
    ]
    schema ++> [
        llm { inject_schema_hint, type_display_name },
        mtir { json_to_instance, type_display_name, type_to_schema },
        types { _type_to_schema, tool_to_schema, type_display_name },
    ]
    systemone ++> [
        lib { Decision },
        llm {
            Decision,
            ProviderCaps,
            SYSTEMONE_PREFIX,
            SystemOneSpec,
            assemble,
            caps_for,
            distribution,
            lower,
            resolve_api_key,
            resolve_model_name,
            wrap_result
        },
        visit_routing { ROUTE_SELECT_ATTR },
    ]
    telemetry ++> [
        lib {
            register_agent_callback,
            register_llm_call_hook,
            unregister_llm_call_hook
        },
        llm {
            _aggregate_usage,
            _current_invocation_id,
            _emit_agent_telemetry,
            _notify_llm_call
        },
    ]
    tool_protocol ++> llm {
        coerce_message_dict,
        inject_tool_hint,
        recover_tool_calls,
        response_field
    }
    types ++> [
        lib {
            Document,
            Image,
            IterationAction,
            IterationContext,
            Message,
            MessageRole,
            MockError,
            MockRawResponse,
            MockToolCall,
            StreamEvent,
            Text,
            Tool,
            ToolCallResultMsg,
            Video
        },
        llm {
            CompletionResult,
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
            ToolCall,
            ToolCallResultMsg,
            content_preview,
            image_resp_kind,
            reroute_tool_images_to_user_message,
            response_dict
        },
        mtir {
            LiteLLMMessage,
            Message,
            MessageRole,
            MessageType,
            Text,
            Tool,
            as_media_list,
            image_resp_kind
        },
        parallel { ToolCallResultMsg, normalize_tool_result },
        systemone.build_state { as_media_list },
        systemone.lower { image_resp_kind },
        visit_routing.route_visit { Message, MessageRole },
    ]
}

graph import byllm._optdeps {
    _deferred ++> [
        litellm { DeferredClassMeta, is_installed, when_loaded },
        openai { DeferredClassMeta, DeferredModule, is_installed },
    ]
}

graph import cache {
    home ++> [
        policy { CACHEDIR_TAG },
        registry { CACHEDIR_TAG, cache_home, ensure_cache_dir, ensure_root },
    ]
    locking ++> policy { FileLock }
    policy ++> registry {
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
}

graph import cli {
    browser_engine ++> commands.browse {
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
    check_report ++> commands.analysis {
        print_failed_summary,
        print_file_progress,
        print_final_summary,
        print_native_coverage,
        print_placement_report,
        print_section
    }
    check_report --> commands.analysis.explain { print_placement_report }
    cli --> [
        cli_boot.start_cli { start_cli as _start_cli },
        commands.analysis.format | commands.project._stamp_jac_version { jac_version },
    ]
    command ++> [
        commands.analysis
            | commands.architecture
            | commands.browse
            | commands.build
            | commands.cache
            | commands.code
            | commands.config
            | commands.db
            | commands.execution
            | commands.fix
            | commands.guide
            | commands.native
            | commands.precompile
            | commands.project
            | commands.studio
            | commands.tools { Arg, ArgKind, CommandSpec },
        commands.mcp | shadcn.cli { Arg, CommandSpec },
        commands.tools._extract_commands { ArgKind },
        dispatch { Arg, ArgKind, CommandSpec, arg_consumes_value },
        executor | manifest | manifest_help { CommandSpec },
        executor.CommandExecutor.execute { CommandSpec },
        executor.CommandExecutor.run_handler { CommandSpec },
        manifest_parse {
            Arg,
            ArgKind,
            CommandSpec,
            arg_consumes_value,
            resolve_arg_typ
        },
        mcp_manifest.get_command { arg_typ_name },
    ]
    comptime commands.analysis ++> manifest {
        SPEC_CHECK,
        SPEC_EXPLAIN,
        SPEC_FORMAT,
        SPEC_GEN_PARSER,
        SPEC_PRECOMMIT,
        SPEC_TEST
    }
    comptime commands.architecture ++> manifest { SPEC_ARCH }
    comptime commands.browse ++> manifest { SPEC_BROWSE }
    comptime commands.build ++> manifest { SPEC_BUILD }
    comptime commands.cache ++> manifest { SPEC_CACHE }
    comptime commands.code ++> manifest { SPEC_CODE }
    comptime commands.config ++> manifest { SPEC_CONFIG }
    comptime commands.db ++> manifest { SPEC_DB }
    commands.execution --> cli_boot._run_bundled_app { run_jab_image }
    comptime commands.execution ++> manifest { SPEC_RUN, SPEC_X }
    comptime commands.fix ++> manifest { SPEC_FIX }
    comptime commands.guide ++> manifest { SPEC_GUIDE }
    comptime commands.mcp ++> manifest { SPEC_MCP_CMD }
    comptime commands.native ++> manifest { SPEC_NATIVE }
    comptime commands.precompile ++> manifest { SPEC_PRECOMPILE }
    comptime commands.project ++> manifest {
        SPEC_CLEAN,
        SPEC_CREATE,
        SPEC_INSTALL,
        SPEC_PUBLISH,
        SPEC_REMOVE,
        SPEC_UPDATE
    }
    comptime commands.studio ++> manifest { SPEC_STUDIO }
    comptime commands.tools ++> manifest {
        SPEC_COMPLETIONS,
        SPEC_DOT,
        SPEC_LSP,
        SPEC_TOOL
    }
    console ++> [
        banners
            | check_report.print_diag
            | cli.start_cli
            | commands.analysis
            | commands.architecture
            | commands.browse
            | commands.build
            | commands.cache
            | commands.cli_helpers
            | commands.code
            | commands.config
            | commands.db
            | commands.fix
            | commands.guide
            | commands.native
            | commands.native_build
            | commands.project
            | commands.tools
            | commands.transform
            | dispatch._apply_profile
            | executor
            | manifest_help._use_color
            | shadcn.cli._build_shadcn_template_info
            | shadcn.shadcn_handler
            | shadcn.theme_handler { console },
        check_report.print_failed_summary
            | commands.analysis.explain
            | dispatch._exit_on_invalid_jac_toml
            | shadcn.cli._shadcn_post_create { console },
        check_report.print_file_progress
            | dispatch._exit_on_malformed_jac_toml
            | shadcn.cli.retheme { console },
        check_report.print_final_summary
            | dispatch.run_selected_command
            | shadcn.cli.run_shadcn_add { console },
        check_report.print_guide_hint | shadcn.cli.run_shadcn_remove { console },
        check_report.print_native_coverage { console },
        check_report.print_placement_report { console },
        check_report.print_section { console },
        commands.execution { console, use_line_buffered_output },
    ]
    dispatch ++> manifest_route.handle_manifest_route { run_selected_command }
    errmap --> executor.CommandExecutor.execute { humanize_error, show_tracebacks }
    executor ++> dispatch.run_selected_command { get_executor }
    format_cache --> [
        commands.analysis._format_single_file_worker {
            FormatCache,
            canonical_logical_path,
            config_fingerprint,
            default_format_cache_dir,
            frame_unit
        },
        commands.analysis.format {
            FORMAT_CACHE_SCHEMA_VERSION,
            formatter_pipeline_revision
        },
    ]
    guide_store ++> [
        check_report.print_guide_hint { guide_for_diagnostic },
        commands.guide {
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
        },
    ]
    guide_store --> mcp.resources.ResourceProvider._index_shared_guides {
        docs_dir,
        list_docs,
        list_guides
    }
    jaccomplete ++> commands.tools.completions { static_shellcode as shellcode }
    loader ++> dispatch.run_selected_command { load_handler }
    manifest ++> [
        commands.tools.completions { iter_command_meta },
        dispatch.run_selected_command | loader.load_handler | mcp_manifest.get_command {
            get_command_meta
        },
        manifest_help {
            GROUP_DISPLAY,
            GROUP_ORDER,
            TIER_ORDER,
            TIER_SECTIONS,
            iter_command_meta
        },
        manifest_route.handle_manifest_route { TOMBSTONED_VERBS, known_command_names },
        mcp_manifest.list_commands { get_groups, iter_command_meta },
    ]
    manifest_help ++> [
        manifest_route._render_version_line { _TITLE, _color, _use_color },
        manifest_route.handle_manifest_route {
            format_curated_help,
            format_logo,
            format_verbose_help
        },
    ]
    manifest_parse ++> dispatch.run_selected_command { build_command_parser }
    manifest_route ++> [
        cli.jac_version { resolve_cli_version },
        cli.start_cli { handle_manifest_route },
    ]
    manifest_route --> commands.project.update { resolve_cli_version }
    mcp.mode --> commands.mcp.mcp_cmd { set_mcp_mode }
    mcp.prompts ++> commands.mcp._print_mcp_inventory { PromptProvider }
    mcp.resources ++> commands.mcp._print_mcp_inventory { ResourceProvider }
    mcp.server ++> commands.mcp.mcp_cmd { JacMcpServer }
    mcp.tools ++> commands.mcp._print_mcp_inventory { ToolProvider }
    mcp_manifest --> [
        mcp.tools.get_command { get_command as manifest_get_command },
        mcp.tools.list_commands { list_commands as manifest_list_commands },
    ]
    shadcn.cli --> [
        commands.project._create_body { stash_create_theme },
        commands.project.install { run_shadcn_add },
        commands.project.remove { run_shadcn_remove },
    ]
    comptime shadcn.cli ++> manifest { SPEC_RETHEME }
    workpool ++> [
        commands.analysis._check_retire { env_int, should_retire },
        commands.analysis._check_rss_cap_mb { env_int },
        commands.analysis._maybe_malloc_trim { maybe_malloc_trim },
        commands.analysis._settle_check_heap { maybe_malloc_trim, worker_rss_mb },
        commands.analysis.check {
            WorkPool,
            forced_serial,
            jobs_setting,
            pool_available,
            resolve_jobs
        },
        commands.analysis.format {
            WorkPool,
            forced_serial,
            jobs_setting,
            pool_available,
            resolve_jobs
        },
        commands.analysis.test { jobs_setting },
    ]
}

graph import cli.commands {
    analysis --> build.build { check }
    cli_helpers ++> execution | tools { proc_file as _proc_file }
    native_build --> [
        build._build_app { native_build },
        build.build { native_build },
    ]
    project --> [
        build._build_app { bundle },
        execution.x { script },
    ]
}

graph import cli.mcp {
    compiler_bridge ++> [
        tools.ToolProvider.call_tool { CompilerBridge },
        tools.get_ast { CompilerBridge },
        tools.graph_visualize { CompilerBridge },
        tools.jac_to_js { CompilerBridge },
        tools.jac_to_py { CompilerBridge },
        tools.lint_jac { CompilerBridge },
        tools.run_jac { CompilerBridge },
    ]
    mode ++> [
        prompts.PromptProvider.list_prompts { disabled_prompts_for_mode, get_mcp_mode },
        tools.ToolProvider.list_tools { disabled_tools_for_mode, get_mcp_mode },
    ]
    prompts ++> [
        protocol { PromptProvider },
        protocol.build_engine { PromptProvider },
    ]
    protocol ++> server.JacMcpServer.start {
        build_engine,
        serve_sse,
        serve_stdio,
        serve_streamable_http
    }
    resources ++> [
        prompts.load_resource_content | protocol.build_engine | tools.get_example {
            get_resource_provider
        },
        protocol { ResourceProvider },
        tools.get_resource { get_resource_provider },
        tools.list_examples { get_resource_provider },
        tools.search_docs { get_resource_provider },
        tools.understand_jac_and_jaseci { get_resource_provider },
    ]
    tools ++> [
        protocol { ToolProvider },
        protocol.build_engine { ToolProvider },
    ]
}

graph import cli.shadcn {
    shadcn_handler ++> [
        cli.run_shadcn_add { add_shadcn_components },
        cli.run_shadcn_remove { remove_shadcn_components },
        theme_handler { _registry_dir, load_registry, resolve_single_component },
    ]
    theme_handler ++> [
        cli._shadcn_post_create { materialize_themed_starter, normalize_shadcn_config },
        cli.retheme { retheme_project },
    ]
}

graph import client {
    artifact ++> [
        client_bundle { ClientBundle, ClientBundleError, prebuilt_bundle },
        serving { client_output_dir },
    ]
    asset_processor ++> jac_client_compiler { AssetProcessor }
    auth_contract ++> [
        client_react_core | client_runtime_core {
            SignupResult,
            __solveRegistrationChallenge
        },
        client_runtime | solid_runtime { SignupResult },
    ]
    client_bundle ++> [
        compiler { ClientBuildInputs, ClientBundle, ClientBundleError },
        compiler.ViteCompiler._compile_wasm_module { client_program },
        compiler.ViteCompiler.prepare_bundle { client_program },
        jac_client_compiler | npm_provider | route_scanner | vite_bundler {
            ClientBundleError
        },
        jac_client_compiler.JacClientCompiler.compile { client_source_root },
        targets.web_target.WebTarget.build {
            client_context_program,
            client_source_root
        },
        vite_client_bundle {
            ClientBuildInputs,
            ClientBundle,
            ClientBundleBuilder,
            ClientBundleError
        },
        vite_client_bundle.ViteClientBundleBuilder._emitted_digest {
            emitted_tree_digest
        },
    ]
    client_diagnostics ++> cli.run_client_start { is_debug_mode }
    client_react_core ++> client_runtime_native {
        __createJacSchema,
        __jacReportError,
        jacIsLoggedIn,
        useJacForm
    }
    client_runtime_core ++> client_runtime | solid_runtime {
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
        jacSsoConnect as _jacSsoConnect,
        jacSsoConnections as _jacSsoConnections,
        jacSsoDisconnect as _jacSsoDisconnect,
        jacSsoFinish as _jacSsoFinish,
        jacSsoLogin as _jacSsoLogin,
        navigate as _navigate
    }
    client_surface ++> jac_to_js.JacToJSCompiler.add_runtime_imports {
        prepend_active_runtime_globals
    }
    compiler ++> vite_client_bundle { ViteCompiler }
    type compiler ++> targets.client_dev_common { ViteCompiler }
    config_loader ++> [
        asset_processor.AssetProcessor.copy_custom_asset_types
            | client_deps
            | jac_client_compiler.JacClientCompiler.copy_root_assets
            | targets.desktop.desktop_target.DesktopTarget.build
            | targets.mobile_target
            | targets.react_native.common
            | targets.web_target._pwa_enabled
            | vite_bundler { JacClientConfig },
        jac_client_compiler.JacClientCompiler.compile { JacClientConfig as PwaConfig },
    ]
    config_loader --> compiler.ViteCompiler._create_pages_entry_content {
        JacClientConfig
    }
    desktop_config ++> [
        targets.desktop.cef_shell.cef_build
            | targets.desktop.desktop_target.DesktopTarget.build
            | targets.desktop.webview_shell._assemble_native_host {
            get_desktop_config
        },
        targets.desktop.desktop_target.DesktopTarget.engine
            | targets.desktop.webview_shell.webview_dev { get_desktop_config },
        targets.desktop.macos_bundle { DesktopIdentity },
    ]
    desktop_plugin_config ++> desktop_config._validate_plugin_keys {
        _desktop_config_schema
    }
    endpoint_cache ++> [
        client_react_core {
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
        },
        client_runtime_core {
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
        },
    ]
    jac_client_compiler ++> compiler { JacClientCompiler }
    jac_to_js ++> jac_client_compiler { JacToJSCompiler }
    js_runtime ++> [
        cli.run_npm_add_global | targets.node_tooling_common | vite_bundler {
            js_runtime_path,
            run_pm
        },
        npm_provider.regenerate_and_install { js_runtime_path },
    ]
    npm_provider ++> [
        client_deps._default_client_deps {
            CORE_DEV_DEPS,
            CORE_RUNTIME_DEPS,
            OPTIONAL_RUNTIME_DEPS
        },
        config_loader {
            CORE_DEV_DEPS,
            CORE_RUNTIME_DEPS,
            OPTIONAL_RUNTIME_DEPS,
            app_npm_deps
        },
        plugin_config.JacClientPluginConfig.register_ecosystem_providers {
            NpmProvider
        },
    ]
    plugin_config ++> desktop_plugin_config._load_desktop_template { _load_template }
    route_scanner ++> [
        jac_client_compiler { RouteScanner, resolve_route_exports },
        jac_client_compiler.JacClientCompiler._check_entry_renders_routes {
            entry_drops_route_children
        },
        jac_client_compiler.JacClientCompiler._warn_pages_without_routes {
            describe_pages_without_routes
        },
        jac_client_compiler.JacClientCompiler._warn_unrouted_pages {
            describe_unrouted_pages
        },
        targets.seo_build { RouteEntry, RouteScanner, resolve_route_exports },
    ]
    runtime_source ++> [
        compiler.ViteCompiler.compile_runtime_utils { resolve_client_runtime_cl_path },
        vite_bundler.ViteBundler._generate_vite_config_content {
            JAC_VIRTUAL_MODULE_SOURCES
        },
    ]
    serving ++> targets.web_target._generate_index_html | vite_bundler._dev_head {
        HeaderBuilder
    }
    source_mapping ++> client_diagnostics { JacLocator, SourceLocation, _npm_specifier }
    source_mapping --> jac_client_compiler.JacClientCompiler._write_js {
        generate_source_map_json
    }
    targets.node_tooling_common ++> vite_bundler._build_vite_command {
        resolve_node_tool_entry
    }
    targets.react_native.dev --> cli.run_client_start {
        JAC_RN_DEV_HOST_ENV,
        JAC_RN_TUNNEL_ENV
    }
    targets.react_native.html_tag_map ++> client_runtime_native {
        RN_HTML_TEXT_TAGS as _TEXT_TAGS,
        RN_HTML_VIEW_TAGS as _VIEW_TAGS
    }
    targets.registry ++> [
        cli { target_for_app },
        cli.run_client_build { target_for_kind },
        cli.run_client_start { target_for_kind },
        npm_provider.app_npm_deps { KIND_TARGET },
    ]
    vite_bundler ++> [
        compiler
            | npm_provider.regenerate_and_install
            | targets.client_dev_common.prepare_vite_dev_compilation
            | targets.static_target
            | targets.web_target
            | vite_client_bundle.make_client_bundle_builder { ViteBundler },
        targets.client_dev_common.dev_proxy_paths { DEV_PROXY_PREFIXES },
        targets.desktop.desktop_target.DesktopTarget.build { API_BASE_URL_ENV_VAR },
    ]
    type vite_bundler ++> targets.client_dev_common { ViteBundler }
    vite_client_bundle ++> [
        targets.client_dev_common.prepare_vite_dev_compilation
            | targets.web_target.WebTarget.build { make_client_bundle_builder },
        targets.mobile_target.MobileTarget._compile_native_jac_modules {
            ViteClientBundleBuilder
        },
    ]
}

graph import client.targets {
    build_common ++> [
        client_dev_common { SUBPROCESS_TIMEOUT_SHORT },
        react_native.build { artifact_mtime },
        react_native.common { SUBPROCESS_TIMEOUT_BUILD_NATIVE },
    ]
    client_dev_common ++> [
        desktop.webview_shell.webview_dev {
            _ClientHmrHandler,
            ensure_watchdog_common,
            install_dev_signal_handlers,
            prepare_vite_dev_compilation,
            resolve_port_or_next_available,
            stop_dev_watcher,
            terminate_dev_processes
        },
        mobile_target {
            _ClientHmrHandler,
            ensure_watchdog_common,
            install_dev_signal_handlers,
            resolve_port_or_next_available,
            start_backend_server_common,
            stop_dev_watcher,
            terminate_dev_processes
        },
        react_native.dev {
            invalidate_runtime_module_cache,
            setup_android_port_reverse_common
        },
        web_target.WebTarget.dev {
            _ClientHmrHandler,
            dev_proxy_paths,
            ensure_watchdog_common,
            prepare_vite_dev_compilation,
            stop_dev_watcher,
            terminate_dev_processes
        },
    ]
    desktop.desktop_target ++> register { DesktopTarget }
    mobile_target ++> register { MobileTarget }
    node_tooling_common ++> react_native.common {
        resolve_node_tool as _node_resolve_node_tool,
        run_manifest_install as _node_run_manifest_install
    }
    pwa_build --> [
        web_target.WebTarget.finish_dist { apply_pwa, refresh_pwa_precache },
        web_target.WebTarget.setup { ensure_pwa_icons },
    ]
    react_native.build ++> mobile_target {
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
    react_native.common ++> [
        mobile_target {
            DEFAULT_APP_ID,
            DEFAULT_APP_NAME,
            DEFAULT_APP_SLUG,
            detect_lan_ipv4,
            resolve_rn_project_dir
        },
        mobile_target.MobileTarget.start { normalize_rn_platform },
    ]
    react_native.config ++> mobile_target {
        _resolve_rn_android_builder,
        _resolve_rn_eas_profile,
        _resolve_rn_eas_update_branch,
        _resolve_rn_eas_update_enabled,
        _resolve_rn_eas_update_message,
        _resolve_rn_ios_builder,
        _resolve_rn_release
    }
    react_native.dev ++> mobile_target {
        JAC_RN_DEV_HOST_ENV,
        JAC_RN_TUNNEL_ENV,
        METRO_API_PREFIX,
        inject_dev_api_base_url,
        inject_metro_api_base,
        resolve_metro_port,
        restore_app_json,
        rn_hmr_on_jac_changed,
        run_expo_start,
        setup_android_port_reverse
    }
    react_native.scaffold ++> mobile_target {
        ensure_native_deps_installed,
        refresh_metro_config,
        write_expo_scaffold
    }
    register --> registry.get_target_registry { register_targets }
    registry ++> [
        mobile_target | web_target { ClientTarget },
        register { get_target_registry },
    ]
    seo_build --> web_target.WebTarget.finish_dist {
        apply_seo,
        clear_seo_files,
        scan_routes
    }
    static_target ++> register { StaticTarget }
    web_target ++> desktop.desktop_target | register | static_target { WebTarget }
    web_target --> mobile_target.MobileTarget.build { WebTarget }
}

graph import client.targets.desktop {
    _dev_launch ++> [
        cef_shell { desktop_app_runtime_env, ensure_dev_build_env },
        desktop_build { desktop_launch_env },
        webview_shell {
            desktop_app_runtime_env,
            ensure_dev_build_env,
            jac_desktop_deps_shell_export,
            jac_desktop_webkit_shell_export
        },
    ]
    _host_bootstrap ++> [
        cef_shell { _fused_runtime_import_block, _host_boot_py },
        webview_shell { _generate_host_source },
    ]
    app_layout ++> macos_bundle | native.host_boot | webview_shell { AppLayout }
    cef_shell --> [
        desktop_target.DesktopTarget.build { cef_build },
        desktop_target.DesktopTarget.dev { cef_dev_unsupported },
        desktop_target.DesktopTarget.start { cef_start },
    ]
    desktop_build ++> [
        cef_shell {
            _bundle_runtime,
            _find_cef_dir,
            _jac_bin,
            _jac_subprocess_env,
            _patch_host_rpath,
            _stage_fused_runtime,
            build_cef_dispatch,
            build_cef_subprocess,
            desktop_storage_identifier,
            inject_backend_script,
            stage_postgres,
            stage_program
        },
        native.cef.build { build_cef_dispatch, build_cef_subprocess },
        webview_shell {
            _bundle_runtime,
            _find_webview_dir,
            _jac_bin,
            _jac_subprocess_env,
            _stage_fused_runtime,
            desktop_storage_identifier,
            inject_backend_script,
            stage_postgres,
            stage_program
        },
    ]
    macos_bundle ++> webview_shell { write_bundle_metadata }
    webview_shell ++> [
        desktop_target.DesktopTarget.build { webview_build },
        desktop_target.DesktopTarget.dev { webview_dev },
        desktop_target.DesktopTarget.start { webview_start },
    ]
}

graph import client.targets.desktop.native {
    backend_choice ++> [
        broker_extension { BackendChoice },
        host_boot.boot { ASK, BackendChoice },
    ]
    broker_extension ++> host_boot.boot { DesktopBrokerExtension }
    oauth_broker ++> [
        broker_extension {
            CLOSE_PAGE,
            DEFAULT_PREFIX,
            LOOPBACK_HOSTS,
            PendingAuth,
            SAME_SITE_VALUES,
            SessionStore,
            build_sso_login_url
        },
        host_boot.boot { SessionStore },
    ]
    profile_store ++> [
        broker_extension { ProfileStore, clean_profile_name, new_profile_id },
        host_boot.boot { ProfileStore },
    ]
    webview.webview ++> plugin_bridge { respond }
}

graph import client.targets.desktop.native.cef {
    cef ++> [
        cef_smoke { cef_cleanup, new_cef_browser },
        cef_test_host {
            cef_cleanup,
            cef_execute_subprocess,
            cef_open_browser,
            cef_run_loop,
            cef_startup
        },
    ]
    include cef_platform ++> cef_dispatch | cef_subprocess;
}

graph import client.targets.react_native {
    build ++> [
        dev {
            lint_native_incompatible_usage,
            lint_unmapped_tags,
            read_user_js_sources,
            stage_compiled_entry,
            stage_native_image_assets,
            strip_css_imports,
            write_api_base_shim
        },
        scaffold { build_native_index_entry_body },
    ]
    common ++> [
        build { SUBPROCESS_TIMEOUT_BUILD, resolve_node_tool },
        dev { resolve_node_tool },
        scaffold {
            DEFAULT_APP_ID,
            DEFAULT_APP_NAME,
            DEFAULT_APP_SLUG,
            EAS_CLI_VERSION,
            EXPO_SDK_VERSION,
            REACT_NATIVE_VERSION,
            run_manifest_install
        },
    ]
    html_tag_map ++> build { supported_rn_html_tags }
}

graph import compiler {
    backends.es ++> tools.lang_tools { es_node_to_dict }
    backends.es --> tests.xbackend_equiv { EsastGenPass }
    backends.es.backends.registry ++> driver.build_services.CompilerBuildServices.client_runtime_basename {
        resolve_active_backend,
        resolve_framework_backend
    }
    backends.es.backends.registry --> [
        driver.compiler.JacCompiler._get_client_artifact
            | driver.unit_products.client_artifact_of { resolve_active_backend },
        driver.compiler.cached_client_pulls { resolve_active_backend },
    ]
    backends.es.es_unparse ++> tools.lang_tools { es_to_js }
    backends.es.es_unparse --> [
        driver.unit_products.client_artifact_of { es_to_js_with_map },
        tests.xbackend_equiv { es_to_js },
    ]
    backends.es.esast_gen_pass ++> [
        driver.pipeline.client_passes | tests.test_client_codegen_facts {
            EsastGenPass
        },
        driver.pipeline.codegen_passes { EsastGenPass },
    ]
    backends.es.estree ++> tools.lang_tools { Node as EsNode }
    backends.es.estree --> driver.unit_products.client_artifact_of
        | tests.xbackend_equiv { Node as EsNode }
    type backends.es.estree ++> frontend.codeinfo {
        IndexInfo,
        Node as EsNode,
        SliceInfo
    }
    backends.es.jac_runtime_js ++> [
        tests.xbackend_equiv._prelude_cwd { stage_jac_prelude_package },
        tests.xbackend_equiv.run_js_module_fixture { stage_jac_prelude_package },
    ]
    backends.native.link_plan --> [
        driver.compiler.JacCompiler._load_native_from_cache { jit_engine_for_cached },
        driver.nativecache.NativeUnitRegistry.compile_unit { build_link_plan },
        driver.pipeline_runner.wasm_ir_units { build_link_plan, wasm_program_ir },
    ]
    backends.native.llvm.binding as llvm --> driver.compiler.JacCompiler._load_native_from_cache
        | driver.nativecache.NativeBuildSession.unbound_symbols;
    type backends.native.llvm.binding ++> driver.compiler.JacCompiler._load_native_from_cache
        | frontend.codeinfo { ExecutionEngine }
    type backends.native.llvm.ir ++> frontend.codeinfo { Module as IRModule }
    backends.native.lowering ++> tests.test_prim_equivalence { native_lowering_issues }
    type backends.native.lowering ++> frontend.codeinfo { NativeFallbacks }
    backends.native.na_compile_pass ++> [
        driver.nativecache.NativeBuildSession._optimize_in_parallel {
            optimize_unit_bitcodes,
            unit_bitcode,
            unit_fallbacks
        },
        driver.pipeline.native_object_passes { NativeCompilePass },
    ]
    backends.native.na_compile_pass --> [
        driver.nativecache.NativeBuildSession.compact_ir {
            unit_bitcode,
            unit_fallbacks
        },
        driver.nativecache.NativeBuildSession.lower { settle_unit_ir },
        driver.nativecache.NativeUnitRegistry.emit_objects { emit_unit_objects },
        driver.nativecache.NativeUnitRegistry.object_for { emit_unit_object },
    ]
    backends.native.na_constants --> driver.native_iface.resolve_native_unit_ref {
        FACT_IMPORT_PATHS,
        FACT_PACKAGE_STORE,
        FACT_SEP
    }
    backends.native.na_ir_gen_pass ++> [
        driver.pipeline.native_ir_passes { NaIRGenPass },
        driver.pipeline.native_lower_passes { NaIRGenPass },
    ]
    backends.native.na_ir_gen_pass --> driver.pipeline.codegen_passes { NaIRGenPass }
    backends.native.wasm_build ++> [
        driver.pipeline_runner.wasm_artifact_inputs { emit_wasm_from_ir },
        driver.pipeline_runner.wasm_ir_units {
            _assert_ir_rc_free,
            _project_gc_settings,
            app_declared_imports
        },
    ]
    backends.py.artifact_imports ++> [
        driver.application._prepare_sealed { runtime_sources },
        driver.pipeline_runner.compile_application { package_sources },
    ]
    backends.py.artifact_imports --> driver.application._prepare_revision {
        import_specs,
        package_sources,
        resolve_imports
    }
    backends.py.codegen_shim --> driver.source_products.python_source
        | tools.lang_tools.AstTool.ir { generated_python }
    backends.py.jcir_bc_gen_pass ++> driver.pipeline.bytecode_passes {
        JcirBytecodeGenPass
    }
    backends.py.jcir_gen_pass ++> driver.module_compile | driver.pipeline.py_ir_passes {
        JcirGenPass
    }
    boundary_rules ++> [
        passes.placement_pass.NativeLegality.settle { ability_crossing },
        passes.placement_pass.bridged_use_crosses { ability_crossing },
        passes.placement_pass.uncrossable_native { ability_crossing },
    ]
    boundary_rules --> [
        passes.boundary_analysis_pass.BoundaryAnalysisPass._export_mixed_native {
            ability_crossing
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass.finish {
            archetype_refusals,
            signature_crossings,
            signature_refusals
        },
    ]
    c_interop ++> [
        backends.native.na_ir_gen_pass {
            c_array_elem,
            c_builtin_kind,
            c_bytes_array_values,
            c_bytes_elem_shape,
            c_bytes_literal,
            c_offset_address,
            c_scalar_constant,
            c_string_literal,
            c_type_arg,
            c_variadic_param,
            clib_block_defines,
            clib_global_of_name,
            clib_import_of,
            foreign_field_of,
            foreign_read_copies,
            foreign_struct_of_type,
            is_builtin_addressof_call,
            is_builtin_pin_call,
            is_pinned_type,
            is_ptr_type,
            is_ptr_view_type,
            is_va_list_type,
            named_function_of
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_unary {
            c_lent_arg_elem,
            c_lent_param,
            c_param_type
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._ensure_clib_struct
            | passes.type_checker_pass.TypeCheckPass._foreign_struct_contains {
            foreign_struct_of_type
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._final_scalar_value {
            c_scalar_constant,
            final_glob_value
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._final_variant_value {
            final_glob_value
        },
        backends.py.jcir_gen_pass
            | passes.type_checker_pass.TypeCheckPass._check_c_variadic_args {
            c_variadic_param
        },
        backends.py.jcir_gen_pass.JcirGenPass._c_copy_rewrite { foreign_read_copies },
        backends.py.jcir_gen_pass.JcirGenPass._c_interop_call_rewrite {
            c_lent_arg_elem,
            c_lent_param,
            c_param_type,
            c_type_spec,
            c_variadic_param,
            is_builtin_pin_call,
            is_ptr_type,
            named_function_of
        },
        backends.py.jcir_gen_pass.JcirGenPass._c_vararg_rewrite { c_type_spec },
        backends.py.jcir_gen_pass.JcirGenPass._clib_block_desc {
            c_type_spec,
            is_foreign_struct_archetype,
            is_opaque_c_archetype
        },
        backends.py.jcir_gen_pass.JcirGenPass._is_c_global_value {
            clib_global_of_name,
            is_builtin_addressof_call
        },
        passes.import_wiring_pass { clib_global_of_name },
        passes.layout_pass.open_dispatch { is_clib_archetype },
        passes.ownership_check_pass {
            c_call_borrows_args,
            clib_import_of,
            is_c_value_type,
            is_ptr_type,
            is_ptr_view_type,
            reads_foreign_storage
        },
        passes.type_checker_pass.TypeCheckPass._borrowed_scalar_param {
            clib_import_of,
            is_ptr_type
        },
        passes.type_checker_pass.TypeCheckPass._c_arg_instance
            | types.type_evaluator.TypeEvaluator._assign_c_interop_args { c_type_arg },
        passes.type_checker_pass.TypeCheckPass._c_const_problem {
            c_array_elem,
            c_bytes_elem_shape,
            c_bytes_literal,
            c_offset_address,
            c_scalar_constant,
            c_string_literal,
            foreign_struct_of_type,
            is_builtin_addressof_call,
            is_ptr_type,
            named_function_of
        },
        passes.type_checker_pass.TypeCheckPass._c_plain_data {
            foreign_struct_of_type,
            is_ptr_type
        },
        passes.type_checker_pass.TypeCheckPass._check_c_function_def {
            c_variadic_param,
            foreign_struct_of_type,
            is_va_list_type
        },
        passes.type_checker_pass.TypeCheckPass._check_c_global_decl { c_array_elem },
        passes.type_checker_pass.TypeCheckPass._check_c_global_use {
            clib_global_of_name,
            foreign_struct_of_type,
            is_builtin_addressof_call
        },
        passes.type_checker_pass.TypeCheckPass._check_c_interop_call {
            c_string_literal,
            c_type_arg,
            clib_global_of_name,
            is_builtin_addressof_call,
            is_builtin_pin_call,
            is_ptr_type,
            opaque_c_of_type
        },
        passes.type_checker_pass.TypeCheckPass._check_c_interop_import {
            is_foreign_struct_archetype,
            is_pinned_type
        },
        passes.type_checker_pass.TypeCheckPass._check_c_type_use { clib_import_of },
        passes.type_checker_pass.TypeCheckPass._check_c_variadic_def {
            c_variadic_param
        },
        passes.type_checker_pass.TypeCheckPass._opaque_member { opaque_c_of_type },
        types.type_evaluator { is_va_list_type },
        types.type_evaluator.TypeEvaluator._c_lent_args { c_abi_callee, c_lent_elem },
        types.type_evaluator.TypeEvaluator._is_typed_c_declaration { c_builtin_kind },
    ]
    c_interop --> [
        passes.rc_facts_pass.result_ownership { foreign_read_copies },
        passes.type_checker_pass.TypeCheckPass.exit_assignment {
            c_bytes_array_definition
        },
    ]
    capability_notes ++> [
        boundary_rules | passes.placement_pass.NativeLegality.settle {
            TARGET_NATIVE,
            TARGET_SERVER
        },
        passes.placement_pass.PlacementPass._run_undecided { capability_notes_of },
        passes.placement_pass.bridged_use_crosses { TARGET_NATIVE, TARGET_SERVER },
        passes.placement_pass.build_native_legality {
            TARGET_NATIVE,
            capability_notes_of
        },
        passes.placement_pass.element_requirements {
            TARGET_NATIVE,
            capability_notes_of
        },
        passes.placement_pass.uncrossable_native { TARGET_NATIVE, TARGET_SERVER },
        types.type_evaluator.TypeEvaluator.neutral_site { placement_neutral },
        types.type_evaluator.TypeEvaluator.note_native {
            TARGET_NATIVE,
            note_capability
        },
    ]
    capability_notes --> [
        passes.boundary_analysis_pass.BoundaryAnalysisPass._export_mixed_native {
            TARGET_NATIVE,
            TARGET_SERVER
        },
        passes.static_analysis_pass.StaticAnalysisPass._check_undefined_names {
            TARGET_NATIVE,
            note_capability,
            placement_neutral
        },
    ]
    type capability_notes ++> driver.progstate { CapabilityNote }
    driver.bccache ++> tests.test_batch_decl_identity | tests.test_global_narrowing {
        discover_base_file
    }
    driver.boundary_classify ++> [
        backends.es.esast_gen_pass.EsastGenPass._is_client_native_import {
            import_binds_client_native
        },
        backends.es.esast_gen_pass.EsastGenPass._is_service_bridge_import
            | backends.py.jcir_gen_pass.JcirGenPass._sv_bridge_walker_call {
            CrossAppKind,
            classify_cross_app_import
        },
        backends.es.esast_gen_pass.EsastGenPass._partition_client_import_items {
            ClientImportVerdict,
            classify_client_import_item,
            import_crosses_apps,
            is_client_boundary_import
        },
        backends.es.esast_gen_pass.EsastGenPass._record_sv_backend
            | passes.boundary_analysis_pass.BoundaryAnalysisPass._register_sv_import {
            import_crosses_apps,
            import_provider_app,
            import_provider_route
        },
        backends.es.esast_gen_pass.EsastGenPass._sv_provider_options {
            import_crosses_apps,
            import_provider_app,
            import_provider_route
        },
        backends.py.jcir_gen_pass.JcirGenPass._sv_consumer_app_expr { module_app },
        backends.py.jcir_gen_pass.JcirGenPass.exit_import {
            CrossAppKind,
            classify_cross_app_import,
            import_binds_client_native
        },
        passes.access_check_pass.AccessCheckPass._collect_bridged_imports {
            classify_cross_app_import
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._bridge_targets {
            bridgeable_import_target,
            import_provider_app,
            module_app
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._check_app_cycle {
            bridgeable_import_target
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._check_provider_pub {
            ClientImportVerdict,
            classify_client_import_item,
            import_provider_app,
            module_app
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._parsed_provider_of {
            parsed_import_source
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._provider_module_of {
            bridgeable_import_target,
            symbol_linked_source_module
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._record_app_edge {
            import_provider_app,
            module_app
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._register_client_bridged_import {
            ClientImportVerdict,
            classify_client_import_item,
            import_crosses_apps,
            import_item_declaration,
            import_provider_app,
            import_provider_route,
            is_client_boundary_import
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._register_type_import {
            import_provider_app
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._reject_owned_type_import {
            import_provider_app,
            module_app
        },
        passes.placement_pass.PlacementPass._run_undecided
            | placement.placement_facts.settle_server
            | placement.placement_solver._seed_from_summary { _stamp_context_element },
        passes.placement_pass.uncrossable_native
            | placement.placement_solver.solve_module_placement {
            _stamp_context_element
        },
        passes.static_analysis_pass.StaticAnalysisPass._check_client_imports {
            ClientImportVerdict,
            classify_client_import_item,
            is_client_boundary_import,
            is_client_native_edge_import
        },
        passes.wasm_contract.host_contracts { symbol_linked_source_module },
        placement.placement.summarize_module { module_own_native_anchor },
        placement.placement_facts.discover_spaces
            | placement.placement_solver._materialize_module { hub_module_for_path },
        placement.placement_solver._is_sv_import { import_crosses_apps },
        placement.placement_solver._pullable_by_client_reference {
            is_server_anchored_module
        },
        placement.placement_solver.dependency_summary { hub_module_for_path },
    ]
    driver.boundary_classify --> [
        backends.py.jcir_gen_pass.JcirGenPass._generate_sv_to_sv_stubs {
            import_provider_app,
            import_provider_route
        },
        frontend.unitree.Import.is_service_import.getter { is_service_bridge_import },
        passes.boundary_analysis_pass.BoundaryAnalysisPass.enter_import {
            CrossAppKind,
            classify_cross_app_import
        },
        placement.placement._element_reqs { classify_import },
        placement.placement._scan_blockers_under { ability_delegates_to_model },
        placement.placement.module_anchor_reasons {
            ability_delegates_to_model,
            classify_import,
            is_service_app_entry
        },
        placement.placement_export.collect_placement_rows {
            ClientImportVerdict,
            classify_client_import_item,
            is_client_boundary_import
        },
        placement.placement_solver._closure_pullable { is_server_anchored_module },
        placement.placement_solver._pull_boundary_import {
            plain_native_import_target,
            symbol_linked_source_module
        },
        types.type_evaluator.TypeEvaluator._is_sv_async_call {
            ClientImportVerdict,
            CrossAppKind,
            classify_client_import_item,
            classify_cross_app_import,
            is_client_native_edge_import
        },
    ]
    driver.compilation_context ++> [
        passes.access_check_pass.AccessCheckPass._module_app_facts
            | placement.placement_pins { context_app },
        placement.placement_facts.module_record { cache_scope, owner_scope_options },
        types.type_evaluator.TypeEvaluator._in_flight_module { program_for },
    ]
    driver.compile_options ++> [
        backends.es.client_kernel_cache._lower
            | tests.test_batch_decl_identity
            | tests.test_client_codegen_facts
            | tests.test_global_narrowing
            | tests.test_missing_local_import
            | tests.test_native_kernel_cache
            | tests.test_subscript_assignment
            | tests.test_tarfile_equivalence
            | tests.test_unknown_cascade
            | tests.test_zstd_equivalence
            | tools.lang_tools { CompileOptions },
        backends.native.link_plan {
            CompileOptions,
            NATIVE_LINK_MODE_BITCODE,
            NATIVE_LINK_MODE_OBJECTS,
            env_na_debug
        },
        backends.native.link_plan.build_link_plan {
            pop_native_target,
            push_native_target
        },
        backends.native.link_plan.link_artifact { env_symmap_requested },
        backends.native.link_plan.plan_objects { env_symmap_requested },
        backends.native.llvm | backends.native.llvm.ir.types {
            env_typed_pointers_enabled
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._load_native_unit_module {
            CompileOptions as _UnitOpts
        },
        passes.context | passes.execution | tests.test_pipeline_products {
            CancelToken
        },
    ]
    driver.compile_options --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._full_ast_of { env_na_debug },
        backends.native.na_ir_gen_pass.NaIRGenPass._native_imports {
            env_na_debug,
            env_na_debug as _ti_dbg
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._opaque_field_if_unlowerable {
            env_na_debug as _er_dbg
        },
        tests.test_graph_fragment_equivalence
            | tests.test_stubcat_roundtrip
            | tests.xbackend_equiv
            | tools.code_intel.CodeIntelligence._full_compile_one { CompileOptions },
    ]
    type driver.compile_options ++> backends.native.na_compile_pass
        | frontend.host
        | placement.placement_facts { CompileOptions }
    driver.compiler ++> types.stubcat.build.build_catalog { JacCompiler }
    type driver.compiler ++> frontend.host { JacCompiler }
    driver.dependency_graph ++> backends.native.link_plan._build_link_plan {
        dependency_groups
    }
    type driver.ifacecache ++> frontend.host { IfaceRegistry }
    driver.jir ++> [
        backends.es.client_kernel_cache._artifact_path { running_compiler_digest },
        backends.native.link_plan { unit_source_digest },
        backends.native.link_plan.LinkPlan.plan_digest { native_producer_digest },
        backends.native.link_plan._build_link_plan.walk_unit { module_cache_key },
        backends.native.link_plan._glue_symbols_store {
            cache_mode,
            compiler_generation,
            get_jir_cache_dir
        },
        backends.native.link_plan._jit_image_path { cache_mode, get_jir_cache_dir },
        backends.native.link_plan._reuse_artifact { cache_mode },
        backends.native.link_plan._write_sidecar { native_producer_digest },
        backends.native.na_compile_pass.NativeCompilePass._emit_debug_products {
            get_native_debug_dir
        },
        placement.placement_facts._record_at {
            SEC_PLACEMENT,
            get_module_cache_path,
            is_module_cache_valid,
            read_jir,
            read_jir_paths,
            read_section_bytes
        },
        tools.code_intel {
            SEC_SYMINDEX,
            compute_content_sha256,
            get_module_cache_path,
            is_module_cache_valid,
            read_jir,
            read_section_bytes,
            write_module_cache
        },
    ]
    driver.jir --> backends.native.link_plan.build_link_plan {
        begin_prepare_memo,
        end_prepare_memo
    }
    driver.na_coverage ++> backends.native.link_plan._build_link_plan {
        na_coverage_replay
    }
    driver.na_coverage --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._export_native_iface {
            na_coverage_capture
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._opaque_field_if_unlowerable {
            na_coverage_seam
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._place_unit_python {
            na_coverage_seam
        },
    ]
    driver.native_iface ++> [
        backends.native.link_plan {
            NativeIface,
            layout_digest as layout_digest_of,
            merge_class_layouts
        },
        backends.native.na_ir_gen_pass { NativeExport, NativeIface },
        backends.native.na_ir_gen_pass.NaIRGenPass._export_native_iface {
            NativeClassLayout,
            NativeFieldSlot,
            NativeIface
        },
        tests.test_native_kernel_cache { NativeIface },
    ]
    type driver.native_iface ++> frontend.codeinfo | frontend.host { NativeIface }
    driver.nativecache ++> [
        backends.native.link_plan.build_link_plan { NativeBuildSession },
        tests.test_native_kernel_cache { NativeUnitEntry },
    ]
    type driver.nativecache ++> frontend.host { NativeUnitRegistry }
    driver.pass_driver ++> [
        tests.test_client_codegen_facts { run_pass },
        tools.jac_auto_lint_pass.JacAutoLintPass.__post_init__ {
            diagnostic_policy_for
        },
    ]
    driver.pass_driver as pass_driver ++> tests.test_pipeline_products;
    driver.pipeline ++> [
        backends.es.client_kernel_cache._lower
            | backends.native.na_ir_gen_pass.NaIRGenPass._ensure_body_inference
            | passes.layout_pass.get_layout_registry
            | tools.lang_tools { CompilationProduct, require },
        backends.native.na_ir_gen_pass.NaIRGenPass._ensure_dep_inference {
            CompilationProduct,
            require
        },
        tests.test_module_exports
            | tools.cfg_dot.cfg_dot_from_file
            | tools.jac_formatter_pass.format_module
            | tools.lang_tools.AstTool.ir { run_utility },
        tests.test_pipeline_products {
            _LOADING,
            product_facts,
            product_ready,
            require
        },
    ]
    driver.pipeline --> [
        placement.placement_solver.invalidate_importers_es { invalidate },
        placement.placement_solver.solve_module_placement._invalidate_stale_codegen {
            invalidate
        },
        tools.jac_formatter_pass.unparse_module { run_utility },
    ]
    driver.pipeline_runner ++> backends.native.wasm_build.compile_to_wasm { build_wasm }
    driver.pipeline_types ++> [
        backends.es.esast_gen_pass
            | backends.native.na_compile_pass
            | backends.py.jcir_bc_gen_pass
            | backends.py.jcir_gen_pass
            | passes.ast_validation_pass
            | passes.boundary_analysis_pass
            | passes.context
            | passes.endpoint_effect_pass
            | passes.graph_lowering_pass
            | passes.jsx_intrinsic_guard_pass
            | passes.layout_pass
            | passes.mtir_gen_pass
            | passes.pyast_load_pass
            | passes.sem_def_match_pass
            | passes.semantic_analysis_pass
            | tools.cfg_dot
            | tools.comment_attach_pass
            | tools.doc_ir_gen_pass
            | tools.grammar_extract_pass
            | tools.jac_auto_lint_pass
            | tools.jac_formatter_pass
            | tools.normalize_pass
            | tools.unparse_pass { PassContract },
        backends.native.na_ir_gen_pass
            | passes.access_check_pass
            | passes.capability_check_pass
            | passes.cfg_build_pass
            | passes.comptime_resolve_pass
            | passes.decl_impl_match_pass
            | passes.declaration_type_pass
            | passes.freeze_structure_pass
            | passes.import_wiring_pass
            | passes.ownership_check_pass
            | passes.package_boundary_pass
            | passes.placement_pass
            | passes.rc_facts_pass
            | passes.region_infer_pass
            | passes.static_analysis_pass
            | passes.sym_tab_build_pass
            | passes.type_checker_pass
            | passes.variant_agreement_pass
            | placement.placement_solver { AnalysisFact, PassContract },
        tests.test_module_exports
            | tools.cfg_dot.cfg_dot_from_file
            | tools.jac_formatter_pass.format_module
            | tools.lang_tools.AstTool.ir { CompilationProduct },
        tests.test_pipeline_products {
            AnalysisFact,
            CompilationProduct,
            ProductTask,
            TaskState
        },
    ]
    driver.pipeline_types --> [
        placement.placement_solver.invalidate_importers_es
            | tools.jac_formatter_pass.unparse_module { CompilationProduct },
        placement.placement_solver.solve_module_placement._invalidate_stale_codegen {
            CompilationProduct
        },
    ]
    driver.program ++> [
        backends.es.client_kernel_cache._lower
            | backends.native.wasm_build.compile_to_wasm
            | placement.placement_facts.discover_spaces
            | placement.placement_solver._native_dep_scan
            | tests.test_batch_decl_identity
            | tests.test_client_codegen_facts
            | tests.test_client_npm_entry_root
            | tests.test_global_narrowing
            | tests.test_jac_mobui_typing
            | tests.test_missing_local_import
            | tests.test_module_exports
            | tests.test_native_kernel_cache
            | tests.test_pipeline_products
            | tests.test_subscript_assignment
            | tests.test_tarfile_equivalence
            | tests.test_test_block_analysis
            | tests.test_unknown_cascade
            | tests.test_untyped_third_party
            | tests.test_zstd_equivalence
            | tools.cfg_dot.cfg_dot_from_file
            | tools.code_intel
            | tools.jac_formatter_pass.format_module
            | tools.lang_tools
            | types.stubcat.build.build_catalog { JacProgram },
        tools.jac_formatter_pass.unparse_module { JacProgram },
    ]
    driver.program --> tests.test_graph_fragment_equivalence
        | tests.test_stubcat_roundtrip
        | tests.xbackend_equiv { JacProgram }
    type driver.program ++> backends.native.link_plan
        | capability_notes
        | frontend.host
        | frontend.parser.frontend
        | native_bindings
        | passes.context
        | passes.execution
        | passes.layout_pass
        | passes.placement_pass
        | passes.wasm_contract
        | placement.placement
        | placement.placement_export
        | placement.placement_facts
        | placement.placement_pins
        | placement.placement_solver
        | placement.placement_work
        | symbol_utils
        | types.stubcat.build
        | types.type_evaluator { JacProgram }
    driver.selfhost ++> types.stubcat.build.build_catalog { SelfHostCache }
    driver.session_compile ++> passes.placement_pass.settle_native_module {
        drop_native_bindings
    }
    driver.unit_products ++> boundary_audit.boundary_audit { interop_record }
    driver.wiring ++> [
        passes.import_wiring_pass {
            RuleRec,
            WireBinding,
            WireRec,
            WiringSpec,
            is_arch_file,
            is_positional_import,
            rule_record,
            rule_text,
            scope_owners,
            scope_path_of,
            unnamed_module_label,
            variant_base_file,
            wiring_for_path
        },
        passes.package_boundary_pass { local_module_name },
        tools.jac_auto_lint_pass {
            WireRec,
            WiringSpec,
            is_positional_import,
            scope_path_of,
            wiring_for_path
        },
        types.stubcat.writer.CatalogWriter.encode_symbol { is_arch_file },
    ]
    driver.wiring --> frontend.parser.frontend.annex_sources { wiring_annex_for }
    erased_imports ++> [
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
            erased_identity_call_arg
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._ctxmgr_callee {
            contextmanager_ability
        },
        field_semantics.is_field_marker { erased_import_binds },
    ]
    erased_imports --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
            contextmanager_ability
        },
        passes.capability_check_pass.native_capability_violations {
            contextmanager_ability,
            is_contextmanager_decorator
        },
        passes.rc_facts_pass.result_ownership { erased_identity_call_arg },
    ]
    expr_keys ++> [
        backends.native.na_ir_gen_pass
            | passes.ownership_check_pass
            | passes.rc_facts_pass.method_returns_borrow
            | types.ownership { type_tag_borrows },
        passes.cfg_build_pass.CFGBuildPass._wire_bool_operands {
            collect_narrowing_symbols
        },
        passes.cfg_build_pass.CFGBuildPass._wire_compr_filters {
            collect_narrowing_symbols
        },
        passes.cfg_build_pass.CFGBuildPass.cfg_collect_affected {
            collect_assigned_symbols
        },
        passes.cfg_build_pass.CFGBuildPass.enter_assert_stmt {
            collect_narrowing_symbols
        },
        passes.cfg_build_pass.CFGBuildPass.enter_else_if { collect_narrowing_symbols },
        passes.cfg_build_pass.CFGBuildPass.enter_if_stmt { collect_narrowing_symbols },
        passes.cfg_build_pass.CFGBuildPass.exit_if_else_expr {
            collect_narrowing_symbols
        },
        types.type_evaluator.TypeEvaluator._get_type_of_lhs_assignment {
            find_destructure_index_path
        },
        types.type_evaluator.TypeEvaluator._loop_body_writes_target {
            collect_assignment_target_keys
        },
        types.type_evaluator.TypeEvaluator._narrowed_type_for_expr {
            reference_key_deps
        },
    ]
    expr_keys --> [
        types.type_evaluator.TypeEvaluator._get_type_from_flow_node {
            collect_assignment_target_keys,
            find_destructure_index_path
        },
        types.type_evaluator.TypeEvaluator.create_key_for_reference {
            int_subscript_suffix
        },
    ]
    field_semantics ++> [
        backends.es.esast_gen_pass.EsastGenPass._field_constructor_args
            | backends.native.na_ir_gen_pass.NaIRGenPass._codegen_archetype {
            positional_field_names
        },
        backends.native.na_ir_gen_pass
            | passes.type_checker_pass.TypeCheckPass.exit_has_var
            | types.type_evaluator.TypeEvaluator._build_field_params {
            field_initialization
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
            field_initialization,
            is_field_marker
        },
        backends.py.jcir_gen_pass.JcirGenPass.exit_has_var { is_field_marker },
    ]
    frontend.codeinfo ++> [
        backends.es.client_kernel_cache._es_backend_fingerprint
            | backends.native.floors._repo_root
            | backends.native.llvm.shim_path._repo_root
            | driver.pass_driver._alert_in_internal_stub
            | driver.setup_progress
            | driver.source_failures._compiler_source_root
            | native_bindings.typeshed_stub_path
            | types.type_evaluator.TypeEvaluator.__post_init__ { jaclang_pkg_root },
        backends.es.client_kernel_cache._unit_source_path { kernel_unit_path },
        backends.es.esast_gen_pass {
            BoundaryTypeInfo,
            ClientManifest,
            InteropManifest
        },
        backends.es.esast_gen_pass.EsastGenPass._build_spawn_runtime_call
            | passes.endpoint_effect_pass.EndpointEffectPass.enter_ability {
            endpoint_key
        },
        backends.es.esast_gen_pass.EsastGenPass._generate_na_import_binding {
            native_wasm_stem
        },
        backends.es.esast_gen_pass.EsastGenPass._try_lower_server_rpc_call
            | passes.endpoint_effect_pass.EndpointEffectPass.enter_archetype {
            endpoint_key
        },
        backends.es.esast_gen_pass.EsastGenPass.prepare { ClientManifest },
        backends.native.link_glue.inject_heap_accounting { HDR_TOTAL },
        backends.native.link_plan { JAC_ENTRY_SYMBOL, kernel_unit_path },
        backends.native.link_plan.LinkPlan.plan_digest | pkg_paths.package_host_edge {
            native_unit_identity
        },
        backends.native.link_plan._build_link_plan
            | backends.native.na_ir_gen_pass.NaIRGenPass._is_kernel_unit
            | driver.program.JacProgram.prefers_native_codespace {
            is_kernel_unit_path
        },
        backends.native.link_plan._write_sidecar { native_unit_identity },
        backends.native.na_ir_gen_pass {
            HDR_ALLOC_ID_OFF,
            HDR_DTOR_OFF,
            HDR_MAGIC,
            HDR_MAGIC_SHIFT_BASE,
            HDR_RC_OFF,
            HDR_TAG_OFF,
            HDR_TOTAL,
            JACSTR_DESC_FIELDS,
            NativeFuncLayout,
            RC_SENTINEL,
            STR_ASCII_TAG_BIT,
            STR_LEN_PAYLOAD_MASK,
            STR_LEN_TAG_BIT,
            STR_LEN_TAG_SHIFT,
            is_package_keyed_path,
            native_unit_identity,
            real_path,
            str_len_tag
        },
        backends.native.na_ir_gen_pass.NaIRGenPass.__post_init__ { native_unit_prefix },
        backends.native.na_ir_gen_pass.NaIRGenPass._arch_display {
            native_arch_display
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_entry {
            native_entry_name,
            native_runtime_probe_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_test { native_test_symbol },
        backends.native.na_ir_gen_pass.NaIRGenPass._default_repr_fn { native_safe_sym },
        backends.native.na_ir_gen_pass.NaIRGenPass._demote_native_test {
            native_test_symbol
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._discover_kernel_deps {
            FMT_KERNEL_REL,
            OSP_GRAPH_REL,
            OSP_KERNEL_REL,
            kernel_unit_path
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_class_display_fn {
            NATIVE_ARCH_SCOPE_SEP
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_glob_init_func {
            native_glob_init_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_jacval_slot_drop_fn {
            native_safe_sym
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._ensure_fmt_kernel {
            FMT_KERNEL_REL,
            kernel_unit_path
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._eq_fn_new { native_safe_sym },
        backends.native.na_ir_gen_pass.NaIRGenPass._export_native_iface {
            native_glob_init_name,
            native_module_key,
            native_unit_spelling
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._export_native_layout {
            NativeEnumLayout,
            NativeFieldInfo,
            NativeFuncLayout,
            NativeModuleLayout,
            NativeStructLayout,
            NativeTestLayout,
            NativeTupleLayout
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._final_variant_value {
            native_variant_of
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._find_source_ability
            | native_bindings.import_gaps { resolve_native_module },
        backends.native.na_ir_gen_pass.NaIRGenPass._forward_declare_imported_ability {
            NativeModuleLayout
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._from_imported_intercept
            | passes.layout_pass.record_interface_twins
            | types.types.ClassDetailsShared.same_class { bundled_stdlib_module_of },
        backends.native.na_ir_gen_pass.NaIRGenPass._maybe_declare_ability {
            NativeModuleLayout
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._native_imports
            | driver.program.JacProgram.stamp_boundary_facts {
            is_bundled_native_module,
            resolve_native_module
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._native_module_member_ability {
            resolve_native_module
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._native_variant_decl {
            native_variant_of
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._osp_kernel_init_fns {
            native_glob_init_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._pyb_base_of
            | passes.capability_check_pass.base_expr_is_erased
            | passes.layout_pass.is_erased_base_name { NATIVE_ERASED_BASES },
        backends.native.na_ir_gen_pass.NaIRGenPass._register_entry_globals {
            native_def_symbol
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._register_osp_kernel_module {
            OSP_GRAPH_REL,
            OSP_KERNEL_REL,
            kernel_unit_path
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._register_region_kernel {
            REGION_KERNEL_REL,
            kernel_unit_path
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._repr_dict_fn { native_safe_sym },
        backends.native.na_ir_gen_pass.NaIRGenPass._repr_leaf_fn { native_safe_sym },
        backends.native.na_ir_gen_pass.NaIRGenPass._repr_list_fn { native_safe_sym },
        backends.native.na_ir_gen_pass.NaIRGenPass._repr_obj_fn { native_safe_sym },
        backends.native.na_ir_gen_pass.NaIRGenPass._repr_set_fn { native_safe_sym },
        backends.native.na_ir_gen_pass.NaIRGenPass._repr_str_fn { native_safe_sym },
        backends.native.na_ir_gen_pass.NaIRGenPass._repr_tuple_fn { native_safe_sym },
        backends.native.na_ir_gen_pass.NaIRGenPass._ret_tuple_hints {
            NativeTupleLayout
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._symbol_for {
            native_def_symbol,
            native_symbol_name,
            native_unit_identity,
            native_unit_spelling
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._sys_stream_of {
            bundled_stdlib_module_of
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._vtable_symbol {
            native_symbol_name,
            native_unit_spelling
        },
        backends.native.region_abi._region_layout_facts {
            HDR_ALLOC_ID_OFF,
            HDR_DTOR_OFF,
            HDR_MAGIC,
            HDR_MAGIC_SHIFT_BASE,
            HDR_RC_OFF,
            HDR_TAG_OFF,
            HDR_TOTAL,
            RC_SENTINEL
        },
        backends.py.jcir_gen_pass { BoundaryTypeInfo, InteropBinding },
        backends.py.jcir_gen_pass.JcirGenPass._class_ref | types.ct_eval {
            module_dotted_name
        },
        backends.py.jcir_gen_pass.JcirGenPass._materialize { module_dotted_name },
        backends.py.jcir_gen_pass.JcirGenPass._native_test_shim_stmts {
            native_test_symbol,
            native_unit_prefix
        },
        driver.boundary_classify._default_codespace_for { effective_default_codespace },
        driver.boundary_classify.import_binds_client_native
            | driver.session_compile.drop_native_bindings {
            InteropContext,
            InteropManifest
        },
        driver.build_services.CompilerBuildServices.prepare_application {
            set_effective_default_codespace
        },
        driver.compilation_context { is_package_keyed_path },
        driver.compile_options.pop_native_target { _native_target_ctx },
        driver.compile_options.push_native_target { set_native_target_override },
        driver.compiler | tests.xbackend_equiv.run_js_module_fixture {
            ClientArtifact,
            ClientManifest
        },
        driver.compiler.JacCompiler._cached_client_artifact { ClientArtifact },
        driver.compiler.JacCompiler._check_native_abi { NATIVE_ABI_VERSION },
        driver.compiler.JacCompiler._load_native_from_cache { CodeGenTarget },
        driver.compiler.JacCompiler._wants_native_engine
            | driver.program.JacProgram.toolchain_dependency
            | driver.selfhost.SelfHostCache.owns
            | passes.endpoint_effect_pass.EndpointEffectPass.record_callables
            | passes.package_boundary_pass.PackageBoundaryPass.run_walk {
            is_compiler_source_path
        },
        driver.ifacecache.native_lowering_reads {
            is_compiler_source_path,
            is_native_by_location
        },
        driver.jir { is_compiler_source_path, is_package_keyed_path },
        driver.native_iface {
            NATIVE_ABI_VERSION,
            NativeEnumLayout,
            NativeFieldInfo,
            NativeFuncLayout,
            NativeModuleLayout,
            NativeStructLayout,
            NativeTupleLayout,
            native_unit_identity,
            native_unit_root
        },
        driver.nativecache.NativeUnitRegistry._source_key {
            get_effective_default_codespace_override,
            set_effective_default_codespace
        },
        driver.program.JacProgram.declared_codespace { is_client_by_location },
        driver.program.JacProgram.init { forget_real_paths },
        driver.session_compile.compile_in_session {
            get_effective_default_codespace_override,
            reset_native_unit_compile,
            set_effective_default_codespace,
            set_native_unit_compile
        },
        driver.unit_products {
            ClientArtifact,
            ClientManifest,
            InteropBinding,
            InteropContext,
            InteropManifest
        },
        driver.wiring.WiringSpec.import_provider { is_bundled_native_module },
        driver.wiring.variant_base_file { native_variant_base },
        erased_imports.erased_identity_call_arg { NATIVE_ERASED_IDENTITY_CALLS },
        erased_imports.erased_import_binds { NATIVE_ERASED_IMPORTS },
        native_bindings.NativeBindings.surface {
            NATIVE_STDLIB_EXTENSIONS,
            NATIVE_SUPPORTED_STDLIB,
            is_bundled_native_module,
            resolve_native_module
        },
        passes.boundary_analysis_pass {
            BoundaryTypeInfo,
            InteropBinding,
            InteropContext,
            InteropManifest
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._interop_symbol {
            interop_callback_symbol
        },
        passes.capability_check_pass { NATIVE_SUPPORTED_STDLIB, is_native_by_location },
        passes.capability_check_pass.classify_native_import
            | placement.placement._erased_only_import { native_erased_import_names },
        passes.endpoint_effect_pass.EndpointEffectPass._classify {
            endpoint_descriptor
        },
        passes.layout_pass { real_path },
        passes.layout_pass._archetype_native_name { native_arch_name },
        passes.layout_pass.interface_class_native_name { native_arch_name },
        pkg_paths.binds_bare_arch_names { kernel_unit_rels },
        pkg_paths.scope_allows_inferred_path { native_unit_compile_active },
        placement.placement._scan_blockers_under {
            NATIVE_SUPPORTED_STDLIB,
            is_bundled_native_module,
            resolve_native_module
        },
        placement.placement_facts.variant_selected {
            is_native_variant_path,
            is_selected_native_variant
        },
        tools.comment_attach_pass { NodeComments },
    ]
    frontend.codeinfo --> [
        backends.es.esast_gen_pass.EsastGenPass._generate_sv_import_stubs
            | backends.py.jcir_gen_pass.JcirGenPass._sv_endpoint_effects
            | passes.boundary_analysis_pass.BoundaryAnalysisPass._collect_boundary_type {
            endpoint_key
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
            resolve_native_module
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._native_imports {
            native_unit_compile_active as _typed_nuc
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._native_module_call_target {
            NATIVE_STDLIB_EXTENSIONS
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._opaque_field_if_unlowerable {
            native_display_text
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._place_unit_python {
            native_display_text
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._prefix_of_path {
            native_unit_prefix
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._process_clib_imports {
            is_bundled_native_module,
            resolve_native_module
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._skip_is_other_module {
            resolve_native_module
        },
        backends.py.jcir_gen_pass.JcirGenPass._gen_native_interop_stubs {
            native_def_symbol,
            native_symbol_name,
            native_unit_prefix
        },
        backends.py.jcir_gen_pass.JcirGenPass.exit_archetype
            | passes.boundary_analysis_pass.BoundaryAnalysisPass.finish {
            endpoint_key
        },
        driver.application.prepare_application {
            get_effective_default_codespace_override,
            set_effective_default_codespace
        },
        driver.boundary_classify.bridgeable_import_target { is_shared_runtime_module },
        driver.boundary_classify.plain_native_import_target
            | types.stubcat.build._cached_catalog { jaclang_pkg_root },
        driver.compile_options.CompileOptions.__post_init__
            | driver.jir._analysis_fingerprint_for { effective_native_target },
        driver.compile_options.CompileOptions.native_required_for {
            module_dotted_name
        },
        driver.ifacecache.IfaceRegistry.client_boundary_facts
            | driver.nativecache.NativeUnitRegistry._stash_products
            | driver.selfhost.SelfHostCache.evict_unit { CodeGenTarget },
        driver.jir._memoized {
            _native_target_ctx,
            get_effective_default_codespace_override
        },
        driver.jir._module_codespace_mode { effective_default_codespace },
        driver.nativecache.NativeBuildSession.lower {
            get_effective_default_codespace_override,
            reset_native_unit_compile,
            set_effective_default_codespace,
            set_native_unit_compile
        },
        driver.nativecache.NativeUnitRegistry.note_step { native_unit_identity },
        driver.program.JacProgram.compile { native_unit_compile_active },
        driver.selfhost.SelfHostCache.resolve {
            is_native_by_location,
            is_shared_runtime_module
        },
        driver.session_compile.inherit_session_options {
            set_effective_default_codespace
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._register_na_client_import {
            native_wasm_stem
        },
        passes.capability_check_pass.native_capability_violations {
            bundled_native_module_names,
            is_bundled_native_module,
            resolve_native_module
        },
        passes.layout_pass._recorded_native_name { bundled_stdlib_module_of },
        passes.layout_pass.archetype_native_name { bundled_stdlib_module_of },
        passes.ownership_check_pass.OwnershipCheckPass._nogc_resolve_provenance {
            NOGC_NATIVE_STDLIB,
            bundled_stdlib_module_of,
            is_toolchain_unit
        },
        placement.placement_facts.native_unit { is_kernel_unit_path },
        placement.placement_solver._import_source_module { is_compiler_source_path },
        tests.xbackend_equiv {
            JAC_ENTRY_SYMBOL,
            native_symbol_name,
            native_unit_prefix
        },
    ]
    type frontend.codeinfo ++> [
        backends.native.link_glue | backends.native.link_plan { InteropBinding },
        backends.native.na_compile_pass
            | backends.py.codegen_shim
            | driver.nativecache { CodeGenTarget },
        backends.native.na_ir_gen_pass { NativeModuleLayout },
        driver.boundary_classify { InteropManifest },
        driver.client_graph { ClientArtifact, ClientManifest },
        driver.compiler { CodeGenTarget, NativeModuleLayout },
        driver.progstate { ClientArtifact, CodeGenTarget },
    ]
    frontend.const_fold ++> [
        backends.native.na_ir_gen_pass
            | backends.py.jcir_gen_pass
            | c_interop.c_scalar_constant
            | passes.layout_pass
            | types.enum_utils
            | types.operations.get_pow_result_type { fold_const },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_const_expr { fold_const },
        backends.native.na_ir_gen_pass.NaIRGenPass._folded_ord { fold_const },
    ]
    frontend.constant ++> [
        backends.es.esast_gen_pass | symbol_utils {
            CodeContext,
            SymbolType,
            Tokens as Tok
        },
        backends.es.framework_backend.FrameworkBackend._get_setter_name
            | passes.type_checker_pass.TypeCheckPass._install_client_state_setters {
            client_state_setter_name
        },
        backends.es.free_ident_audit
            | placement.placement._references_browser_seed_global {
            BROWSER_SEED_GLOBALS
        },
        backends.es.jac_runtime_js._build_types_runtime_js
            | passes.pyast_load_pass.PyastBuildPass.proc_aug_assign { TOKEN_MAP },
        backends.native.foreign
            | backends.native.na_ir_gen_pass.NaIRGenPass._c_vararg
            | c_interop.c_lent_arg_elem
            | expr_keys.type_tag_borrows
            | passes.type_checker_pass.TypeCheckPass._check_c_function_def
            | types.type_evaluator.TypeEvaluator._c_lent_args { is_borrow_kind },
        backends.native.na_ir_gen_pass {
            CodeContext,
            OwnershipKind,
            SymbolAccess,
            SymbolType,
            Tokens as Tok
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._binds_variable
            | passes.capability_check_pass
            | passes.sym_tab_build_pass.SymTabBuildPass._declare_global_vars
            | types.type_evaluator.TypeEvaluator._merge_catalog_field_params
            | types.types.ClassType.is_edge_type { SymbolType },
        backends.native.na_ir_gen_pass.NaIRGenPass._c_vararg_value
            | c_interop.c_lent_param
            | passes.type_checker_pass.TypeCheckPass._check_c_interop_import {
            is_borrow_kind
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._clib_abi_signature {
            is_borrow_kind
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._clib_param_borrowed {
            is_borrow_kind
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._clib_place_ptr { is_borrow_kind },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_assignment_core {
            SymbolStorage
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_clib_args {
            is_borrow_kind
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_unary {
            OwnershipKind,
            is_borrow_kind
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._ct_fold
            | passes.capability_check_pass.PortabilityWarnPass._check_js_globals
            | passes.import_wiring_pass
            | tools.reactive_use_walk { ExprCtx },
        backends.native.na_ir_gen_pass.NaIRGenPass._flow_future_licensed
            | backends.native.primitives_native
            | c_interop.c_offset_address
            | driver.wiring
            | expr_keys
            | passes.cfg_build_pass.CFGBuildPass.exit_ctrl_stmt
            | passes.graph_lowering_pass
            | passes.mtir_gen_pass
            | passes.ownership_check_pass.OwnershipCheckPass._emit_flow_for_diagnostics
            | passes.type_checker_pass.TypeCheckPass.exit_impl_def
            | tools.cfg_dot.CoalesceBBPass._node_label
            | tools.comment_attach_pass
            | tools.jac_auto_lint_pass
            | types.operations
            | types.type_evaluator.TypeEvaluator._find_predicate_for { Tokens as Tok },
        backends.native.na_ir_gen_pass.NaIRGenPass._hl_view_base_licensed
            | driver.boundary_classify.module_own_native_anchor
            | passes.ownership_hints
            | passes.rc_facts_pass.RcFactsPass._asn_makes_region_handle
            | passes.type_checker_pass.TypeCheckPass._borrowed_scalar_param
            | passes.wasm_contract { OwnershipKind },
        backends.native.na_ir_gen_pass.NaIRGenPass._nogc_borrow_local_assign {
            is_borrow_kind
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._nogc_consume_assigned_local {
            OwnershipKind,
            is_borrow_kind
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._null_safe_on_value
            | types.type_evaluator.TypeEvaluator._scope_has_fields
            | types.types.ClassType.is_node_type { SymbolType },
        backends.native.na_ir_gen_pass.NaIRGenPass._predeclare_nested_siblings
            | types.types.ClassType.is_walker_type { SymbolType },
        backends.native.na_ir_gen_pass.NaIRGenPass._register_entry_globals {
            SymbolStorage
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._try_flow_for_parallel
            | passes.cfg_build_pass._bool_is_and
            | passes.ownership_check_pass.OwnershipCheckPass._emit_sendability_diagnostics
            | types.type_evaluator.TypeEvaluator.classify_condition { Tokens as Tok },
        backends.native.na_ir_gen_pass.NaIRGenPass._try_flow_future
            | passes.ownership_check_pass.OwnershipCheckPass._flow_for_stmts {
            Tokens as Tok
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._unpack_into { SymbolStorage },
        backends.py.jcir_gen_pass {
            CodeContext,
            OwnershipKind,
            SymbolStorage,
            Tokens as Tok,
            is_borrow_kind
        },
        driver.boundary_classify { CodeContext, SymbolAccess, Tokens as Tok },
        driver.ifacecache.IfaceRegistry._client_edges
            | driver.module_compile
            | driver.program.JacProgram.stamp_boundary_facts
            | driver.unit_products
            | passes.boundary_analysis_pass
            | passes.placement_pass
            | passes.static_analysis_pass.StaticAnalysisPass._check_client_imports
            | placement.placement.summarize_module
            | placement.placement_export
            | placement.placement_facts.settle_server
            | placement.placement_solver
            | symbol_utils.report_placement_warnings { CodeContext },
        driver.module_analysis.run_analysis { CodeContext as _CodeCtx },
        native_bindings | types.type_utils { ParamKind, Tokens as Tok },
        passes.access_check_pass
            | passes.boundary_analysis_pass.BoundaryAnalysisPass._register_native_absorb
            | passes.layout_pass.open_dispatch
            | passes.sym_tab_build_pass
            | passes.variant_agreement_pass { SymbolAccess },
        passes.ast_validation_pass { CodeContext, DeleteTargetError, Tokens as Tok },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._get_context { CodeContext },
        passes.capability_check_pass.PortabilityWarnPass._check_js_keywords { ExprCtx },
        passes.capability_check_pass.native_capability_violations {
            CodeContext,
            ExprCtx,
            Tokens as Tok
        },
        passes.endpoint_effect_pass { SymbolType, Tokens as Tok },
        passes.layout_pass | types.ct_eval { OwnershipKind, Tokens as Tok },
        passes.osp_analysis { CodeContext, Tokens as Tok },
        passes.ownership_check_pass {
            OwnershipKind,
            SymbolStorage,
            Tokens as Tok,
            is_borrow_kind,
            is_mut_kind
        },
        passes.ownership_check_pass.OwnershipCheckPass._flow_lend_joined {
            Tokens as Tok
        },
        passes.ownership_check_pass.OwnershipCheckPass._flow_reduce_shape {
            Tokens as Tok
        },
        passes.ownership_check_pass.OwnershipCheckPass._spawn_move_gen {
            Tokens as Tok
        },
        passes.pyast_load_pass { RESERVED_IDENT_NAMES, Tokens as Tok },
        passes.rc_facts_pass {
            ExprCtx,
            OwnershipKind,
            SymbolStorage,
            Tokens as Tok,
            is_borrow_kind
        },
        passes.region_infer_pass { SymbolStorage, Tokens as Tok },
        passes.semantic_analysis_pass { ExprCtx, Tokens as Tok },
        passes.static_analysis_pass { ExprCtx, SymbolType, client_state_setter_name },
        passes.type_checker_pass { ImmutabilityKind, Tokens as Tok },
        passes.type_checker_pass.TypeCheckPass._check_borrowed_scalar_forward {
            OwnershipKind
        },
        passes.type_checker_pass.TypeCheckPass.exit_ability { OwnershipKind },
        placement.placement { SymbolAccess, Tokens as Tok },
        tools.doc_ir_gen_pass { Tokens as Tok, is_mut_kind },
        tools.unparse_pass { OwnershipKind, is_mut_kind },
        types.builtin_extensions { ParamKind, SymbolAccess, SymbolType, Tokens },
        types.fixed_width { TOKEN_MAP, Tokens as Tok },
        types.stubcat.reader {
            BindingKind,
            ImmutabilityKind,
            OwnershipKind,
            ParamKind,
            SymbolAccess,
            SymbolType,
            Tokens as Tok
        },
        types.stubcat.writer { BindingKind, ImmutabilityKind },
        types.ts_decl_parser { BindingKind },
        types.type_evaluator {
            BindingKind,
            CodeContext,
            ExprCtx,
            ImmutabilityKind,
            OwnershipKind,
            ParamKind,
            SymbolAccess,
            SymbolType,
            TOKEN_MAP,
            Tokens as Tok
        },
        types.types { ParamKind },
    ]
    frontend.constant --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_assignment_core {
            OwnershipKind
        },
        backends.py.jcir_gen_pass.JcirGenPass._gen_native_interop_stubs {
            Tokens as _NsTok
        },
        c_interop.foreign_read_is_place { is_borrow_kind },
        driver.program.JacProgram.parse_source { CodeContext },
        types.type_evaluator.TypeEvaluator._collect_return_types { Tokens as _Tok },
        types.type_evaluator.TypeEvaluator.assign_type { SymbolType as _RtSymT },
        types.type_utils._method_entry_of { SymbolType },
    ]
    frontend.diagnostic_utils ++> driver.pass_driver.diagnostic_policy_for
        | passes.context { resolve_diagnostic_tokens }
    frontend.diagnostics ++> [
        backends.es.backends.registry { E5081 },
        backends.es.esast_gen_pass {
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
        },
        backends.es.esast_gen_pass.EsastGenPass._build_edge_ref { E5097 },
        backends.es.esast_gen_pass.EsastGenPass._build_osp_filter_pred { E5097 },
        backends.es.esast_gen_pass.EsastGenPass._warn_rpc_callable_params { W6005 },
        backends.es.esast_gen_pass.EsastGenPass.prepare
            | passes.placement_pass.PlacementPass._run_decided { E5096 },
        backends.native.na_compile_pass { E5020, E5026 },
        backends.native.na_ir_gen_pass {
            DiagnosticInfo,
            E1145,
            E1158,
            E5026,
            E5088,
            E5089,
            E5090,
            E5091,
            E5092,
            E5095,
            E5113,
            E5114,
            E9001,
            E9002,
            E9003
        },
        backends.native.primitives_native
            | driver.module_compile.report_missing_native_ir { E5092 },
        backends.py.jcir_bc_gen_pass { E5040, E5043 },
        backends.py.jcir_gen_pass {
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
        },
        driver.ifacecache._alert_from_record { DIAGNOSTICS },
        driver.program.JacProgram.module_scoped_errors { Category },
        passes.access_check_pass {
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
        },
        passes.ast_validation_pass {
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
            E0057,
            E0058,
            E0063,
            E0065,
            E0066,
            E0067,
            E0071,
            E0075,
            E0076,
            E0078,
            E0082,
            E0083,
            E2019,
            E2020,
            E2021,
            E2022,
            E2024,
            E2036,
            E2084,
            W2019,
            W2020,
            W2021
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._check_app_cycle { E5104 },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._check_provider_pub {
            E5106
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._reject_owned_type_import {
            E5108
        },
        passes.capability_check_pass { W6001, W6002, W6003, W6004 },
        passes.context { DiagnosticInfo, E9001, LINT_ALIASES, Severity },
        passes.decl_impl_match_pass {
            E2009,
            E2011,
            E2012,
            E2013,
            E2016,
            E2017,
            E2026,
            E2030,
            E2087,
            W2080
        },
        passes.decl_impl_match_pass.DeclImplMatchPass._populate_inline_init_symbols {
            W2080
        },
        passes.decl_impl_match_pass.DeclImplMatchPass._populate_self_member_symbols {
            W2080
        },
        passes.graph_lowering_pass { E0084, E0085 },
        passes.import_wiring_pass {
            E1141,
            E1142,
            E1143,
            E1144,
            E1146,
            E1147,
            E1148,
            E2088,
            E2089,
            E2090,
            E2091,
            E2092,
            E2093,
            E2094,
            E2097,
            E2098,
            E2099,
            E2100
        },
        passes.jsx_intrinsic_guard_pass { E1105 },
        passes.layout_pass { E5030, W5031, W5032 },
        passes.ownership_check_pass {
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
        },
        passes.ownership_check_pass.OwnershipCheckPass._emit_place_intrinsic_diagnostics {
            E1319
        },
        passes.ownership_check_pass.OwnershipCheckPass._emit_raises_diagnostics {
            E1407
        },
        passes.package_boundary_pass { E2095, E2096 },
        passes.placement_pass { DIAGNOSTICS, E5090, E5116 },
        passes.placement_pass.PlacementPass._run_undecided { E5096 },
        passes.pyast_load_pass { E5041, E5042 },
        passes.semantic_analysis_pass { E2004, E2005, E2008, W2006, W2007, W2029 },
        passes.static_analysis_pass {
            E1122,
            E1123,
            E1125,
            E2001,
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
        },
        passes.sym_tab_build_pass { E0064, E0077 },
        passes.type_checker_pass {
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
            E1153,
            E1154,
            E1155,
            E1156,
            E1157,
            E1158,
            E1159,
            E1161,
            E1162,
            E1163,
            E1164,
            E2015,
            W1036,
            W1037,
            W1052,
            W2014,
            W6008
        },
        passes.variant_agreement_pass { E5105 },
        placement.placement_solver { DiagnosticInfo },
        placement.placement_solver._warn_state_forks { W6006 },
        symbol_utils { E5082, E5084, W6006, W6007 },
        symbol_utils.report_serverless_kind_errors { E5087 },
        tools.jac_auto_lint_pass {
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
            W3053,
            W3054,
            W3055,
            W3056
        },
        tools.jac_auto_lint_pass.JacAutoLintPass._check_filter_compare_tautology {
            W3040
        },
        tools.jac_formatter_pass { E5051, W5050 },
        types.enum_utils { E1001 },
        types.fixed_width { E1126, E1127, E1128, E1130 },
        types.operations {
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
        },
        types.type_evaluator {
            DiagnosticInfo,
            E0033,
            E0049,
            E0108,
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
        },
    ]
    frontend.diagnostics --> [
        backends.es.esast_gen_pass.EsastGenPass._build_server_forwarder { W6009 },
        backends.es.esast_gen_pass.EsastGenPass._edge_tag_literal { E5097 },
        backends.es.esast_gen_pass.EsastGenPass._ensure_backend { E5081 },
        backends.es.esast_gen_pass.EsastGenPass._get_ast_or_default { E5097 },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._register_na_client_import {
            E5083,
            E5100
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass.enter_atom_trailer { E5112 },
        passes.boundary_analysis_pass.BoundaryAnalysisPass.enter_func_call { E5110 },
        passes.boundary_analysis_pass.BoundaryAnalysisPass.finish { E5093, E5115 },
        passes.decl_impl_match_pass.DeclImplMatchPass._connect_one_impl { E0064 },
        passes.static_analysis_pass.StaticAnalysisPass._check_client_imports {
            W1105,
            W1106
        },
    ]
    type frontend.diagnostics ++> symbol_utils { DiagnosticInfo }
    frontend.helpers ++> types.stubcat.writer | types.type_utils.collect_member_syms {
        evaluate_version_condition
    }
    frontend.host ++> [
        backends.es.backends.registry.active_framework
            | backends.es.esast_gen_pass
            | backends.es.free_ident_audit.client_ambient_globals
            | backends.es.jac_runtime_js.build_osp_core_js
            | backends.native.abi.struct_layouts
            | backends.native.na_ir_gen_pass
            | backends.py.artifact_imports
            | driver.boundary_classify
            | driver.compilation_context.bind_options
            | driver.compile_options.CompileOptions.__post_init__
            | driver.ifacecache.IfaceRegistry._entry_fresh
            | driver.jir.stored_wiring_digest
            | driver.module_analysis
            | driver.module_compile
            | driver.pipeline
            | driver.program.JacProgram.build
            | driver.progstate.DiagLedger._owned
            | driver.session_compile
            | driver.unit_products.dependency_span_rows
            | passes.access_check_pass.AccessCheckPass._module_app_facts
            | passes.placement_pass.PlacementPass._run_decided
            | passes.static_analysis_pass.is_bootstrap_compiled_module
            | passes.variant_agreement_pass.VariantAgreementPass._parse_sibling
            | placement.placement_facts
            | placement.placement_pins
            | placement.placement_solver._held_pull_ids
            | symbol_utils.intrinsic_registry_if_ready
            | tools.jac_auto_lint_pass
            | types.ct_eval.CtEvaluator._embed
            | types.type_evaluator.TypeEvaluator.__post_init__ { active_host },
        backends.native.na_ir_gen_pass.NaIRGenPass._seam_warnings_on
            | driver.compilation_context.compilation_scope
            | driver.ifacecache.IfaceRegistry.analysis_profile
            | driver.program.JacProgram.execution_hubs
            | driver.progstate.ModuleHub.is_fresh
            | passes.placement_pass.PlacementPass._run_undecided
            | placement.placement_solver._keep_native_scan
            | tools.jac_auto_lint_pass.JacAutoLintPass.__post_init__
            | types.type_evaluator.TypeEvaluator._client_npm_base { active_host },
        driver.compilation_context.context_app
            | driver.program.JacProgram.jac_file_formatter
            | driver.progstate.ModuleHub.stamp
            | passes.placement_pass.settle_native_module
            | placement.placement_solver._native_dep_scan
            | tools.jac_auto_lint_pass.JacAutoLintPass._base_decl_archetypes
            | types.type_evaluator.TypeEvaluator._declared_missing_dependency {
            active_host
        },
        driver.pass_driver { CheckSettings, active_host },
        driver.program.JacProgram.jac_file_linter
            | placement.placement_solver._native_scan_digest
            | tools.jac_auto_lint_pass.JacAutoLintPass._is_sibling_annex
            | types.type_evaluator.TypeEvaluator._jac_virtual_sibling_dts {
            active_host
        },
        driver.program.JacProgram.jac_str_formatter
            | placement.placement_solver._read_native_scan
            | types.type_evaluator.TypeEvaluator._load_ts_declarations { active_host },
        driver.program.JacProgram.note_stub_tree_served
            | placement.placement_solver.native_placement_candidate
            | types.type_evaluator.TypeEvaluator._resolve_client_npm_module {
            active_host
        },
        driver.program.JacProgram.parse_source
            | types.type_evaluator.TypeEvaluator._resolve_submodule_attr {
            active_host
        },
        driver.program.JacProgram.stamp_access_check_facts
            | types.type_evaluator.TypeEvaluator._ts_decl_path { active_host },
        driver.program.JacProgram.stamp_app_facts
            | types.type_evaluator.TypeEvaluator._untyped_external_is_error {
            active_host
        },
        driver.wiring {
            HOST_FACT_GIT_IGNORED,
            HOST_FACT_SEP,
            HOST_FACT_STDLIB_MODULES,
            active_host
        },
        passes.package_boundary_pass { ProjectFacts, active_host },
        pkg_paths.target_pkg_root { package_root },
        types.type_evaluator.TypeEvaluator.get_type_of_module { active_host },
    ]
    frontend.host --> [
        backends.es.client_paths.client_output_path
            | backends.native.na_ir_gen_pass.NaIRGenPass._opaque_field_if_unlowerable
            | driver.compilation_context.context_program
            | driver.compile_options.CompileOptions.effective_triple
            | driver.jir._memoized
            | driver.native_iface.resolve_native_unit_ref
            | driver.program.JacProgram._get_compiler
            | passes.boundary_analysis_pass.BoundaryAnalysisPass.enter_atom_trailer
            | passes.mtir_gen_pass.MTIRGenPass._get_scope_str
            | passes.ownership_check_pass.OwnershipCheckPass._nogc_module_enforced
            | passes.static_analysis_pass.StaticAnalysisPass._check_client_imports
            | pkg_paths.binds_bare_arch_names
            | types.type_evaluator.TypeEvaluator.get_type_of_module_item {
            active_host
        },
        backends.es.client_paths.jac_js_path
            | backends.native.na_ir_gen_pass.NaIRGenPass._place_unit_python
            | driver.jir._project_env_fingerprint_uncached
            | driver.program.JacProgram.compile
            | passes.ownership_check_pass.OwnershipCheckPass._nogc_resolve_provenance {
            active_host
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._register_imported_archetype
            | driver.program.JacProgram.iface_registry { active_host },
        driver.program.JacProgram.invalidate_module { active_host },
        driver.program.JacProgram.load_dependency_module { active_host },
        driver.program.JacProgram.native_units { active_host },
        driver.program.JacProgram.release_compile_closure { active_host },
        driver.program.JacProgram.stub_catalog { active_host },
    ]
    frontend.loop_links ++> [
        backends.es.esast_gen_pass {
            LoopLinks,
            LoopStmt,
            PassLink,
            assigned_on_entry,
            binding_sites,
            binds_target,
            confined_to,
            enclosing_loop,
            in_loop_else
        },
        backends.native.na_ir_gen_pass {
            LoopLinks,
            LoopStmt,
            PassLink,
            enclosing_loop,
            frame_owns
        },
        backends.py.jcir_gen_pass { LoopLinks, LoopStmt, PassLink, in_loop_else },
        passes.ast_validation_pass { in_loop_else },
        passes.cfg_build_pass { enclosing_loop },
    ]
    frontend.module_facts ++> [
        backends.es.esast_gen_pass
            | backends.native.na_ir_gen_pass
            | backends.py.jcir_gen_pass
            | driver.boundary_classify.is_server_anchored_module
            | driver.module_compile
            | driver.program.JacProgram.stamp_native_import_facts
            | native_bindings
            | passes.capability_check_pass
            | passes.import_wiring_pass
            | passes.layout_pass
            | passes.osp_analysis
            | passes.package_boundary_pass
            | passes.placement_pass
            | passes.rc_facts_pass
            | passes.type_checker_pass.TypeCheckPass._is_generator
            | placement.placement
            | tests.test_module_exports
            | tools.jac_auto_lint_pass
            | types.type_evaluator.TypeEvaluator._init_prelude_from_sources {
            ModuleFacts
        },
        backends.es.esast_gen_pass.EsastGenPass.prepare {
            ModuleFacts,
            client_capability_violations
        },
        driver.boundary_classify.python_side_name_refs
            | types.type_evaluator.TypeEvaluator.get_type_of_ability { ModuleFacts },
        passes.placement_pass.client_refused_elements { client_capability_violations },
    ]
    frontend.parser.frontend ++> [
        driver.compiler.JacCompiler._prepare_tool_program
            | driver.wiring.WiringSpec.wire_import { parse_woven },
        driver.wiring.canonical_wiring_source { parse_woven },
        driver.wiring.parse_records { parse_woven },
        driver.wiring.prune_wiring_source { parse_woven },
        passes.variant_agreement_pass.VariantAgreementPass._parse_sibling
            | tests.test_module_exports { parse },
        placement.placement_solver._native_dep_scan
            | tools.jac_auto_lint_pass.JacAutoLintPass._base_decl_archetypes {
            parse as rd_parse
        },
    ]
    frontend.parser.frontend --> driver.program.JacProgram.parse_source {
        annex_sources,
        parse_woven
    }
    frontend.parser.lexer ++> [
        tools.jac_auto_lint_pass.JacAutoLintPass._impl_header { tokenize_full },
        tools.jac_auto_lint_pass.JacAutoLintPass._reparse_signature { tokenize_full },
    ]
    frontend.parser.parser ++> [
        tools.jac_auto_lint_pass.JacAutoLintPass._impl_header { Parser },
        tools.jac_auto_lint_pass.JacAutoLintPass._reparse_signature { Parser },
        types.type_evaluator.TypeEvaluator._resolve_string_type_expr {
            parse_expression
        },
    ]
    frontend.parser.tokens ++> [
        driver.wiring { is_name_usable_kind, lookup_keyword },
        tools.grammar_extract_pass { BUILTIN_TYPE_KINDS, TokenKind },
    ]
    frontend.relations ++> [
        driver.program | driver.progstate | passes.scope_walk { ScopeChild },
        types.types {
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
        },
    ]
    frontend.roles ++> [
        backends.native.na_ir_gen_pass
            | backends.py.jcir_gen_pass
            | driver.program
            | driver.progstate
            | passes.ast_validation_pass
            | passes.boundary_analysis_pass
            | passes.capability_check_pass
            | passes.cfg_build_pass
            | passes.comptime_resolve_pass
            | passes.endpoint_effect_pass
            | passes.osp_analysis
            | passes.type_checker_pass
            | tools.cfg_dot
            | tools.comment_attach_pass
            | tools.doc_ir_gen_pass
            | tools.grammar_extract_pass
            | tools.treeprinter
            | types.operations
            | types.stubcat.writer
            | types.type_evaluator { Kid },
        driver.wiring
            | passes.ownership_check_pass
            | passes.region_infer_pass
            | tools.jac_formatter_pass { BodyRole, Kid },
        passes.annex_weave | passes.static_analysis_pass { BodyRole },
        passes.pyast_load_pass {
            Kid,
            NameRefRole,
            ReturnTypeRole,
            UnpackRole,
            ValueRole
        },
        tools.jac_auto_lint_pass {
            AssignmentsRole,
            BodyRole,
            ConditionRole,
            DecoratorsRole,
            DocRole,
            ElseValueRole,
            ExprRole,
            Kid,
            NameRefRole,
            ReturnTypeRole,
            SignatureRole,
            SpecRole,
            TargetRole,
            ValueRole,
            ValuesRole,
            VarsRole
        },
        tools.normalize_pass { BodyRole, ItemsRole, Kid },
        tools.reactive_use_walk { Kid, ValueRole },
        tools.unparse_pass { Kid, Role },
    ]
    frontend.source_layout ++> [
        backends.es.scoped_styles | driver.jir._related_files { style_annex_of },
        driver.bccache { LayoutTables, annex_files_of, base_file_of },
    ]
    frontend.srcloc ++> [
        driver.ifacecache._span_from_record { Span },
        passes.context { CodeLocInfo, Span },
    ]
    frontend.unitree ++> [
        backends.native.na_ir_gen_pass.NaIRGenPass._binds_variable {
            ability_of_symbol
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._record_generic_definition {
            definition_qualname
        },
        backends.native.primitives_native { Expr, UniNode },
        backends.py.jcir_bc_gen_pass
            | driver.context_passes
            | driver.module_analysis
            | driver.pass_driver
            | passes.annex_weave
            | tests.test_client_codegen_facts
            | tests.test_pipeline_products
            | types.stubcat.modiface { Module },
        backends.py.jcir_gen_pass {
            Ability,
            ArchHas,
            ArchSpec,
            Archetype,
            AssertStmt,
            AssignCompr,
            Assignment,
            AstAccessNode,
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
        },
        boundary_rules {
            Ability,
            Archetype,
            Assignment,
            AtomTrailer,
            AtomUnit,
            BinaryExpr,
            Ellipsis,
            Enum,
            FuncSignature,
            HasVar,
            IndexSlice,
            Module,
            MultiString,
            NameAtom,
            Null,
            String,
            Token,
            TupleVal,
            TypeAlias,
            UniNode,
            resolved_decl_of
        },
        c_interop {
            Ability,
            Archetype,
            Assignment,
            AtomTrailer,
            AtomUnit,
            Expr,
            GlobalVars,
            Import,
            Name,
            ParamVar,
            Symbol,
            UnaryExpr,
            UniNode,
            resolved_decl_of
        },
        c_interop._ambient_c_call_returns { FuncCall, Name },
        c_interop._annotation_name { Name, Null },
        c_interop._fold_with_finals { BinaryExpr },
        c_interop._spelled_c_type_name { Name },
        c_interop.c_abi_callee { FuncCall },
        c_interop.c_bytes_array_definition { MultiString, String },
        c_interop.c_bytes_literal { MultiString, String },
        c_interop.c_call_borrows_args { FuncCall },
        c_interop.c_lent_param { FuncCall, FuncSignature, KWPair },
        c_interop.c_offset_address { BinaryExpr, Token },
        c_interop.c_param_type { FuncCall },
        c_interop.c_scalar_constant { BinaryExpr, FuncCall, Name },
        c_interop.c_string_literal { FString, MultiString, literal_string_value },
        c_interop.c_variadic_param { FuncSignature },
        c_interop.clib_block_defines { Ability },
        c_interop.clib_global_of_name { Ability, ImplDef, LambdaExpr, Module, Test },
        c_interop.final_glob_value { Name },
        c_interop.named_function_of { Ability, Name },
        capability_notes | passes.execution { Module, UniNode },
        driver.pipeline_runner.compile_application { Import, ModulePath },
        driver.program.JacProgram.resolve_absorb_imports { find_python_scope_node_of },
        driver.wiring {
            Ability,
            Archetype,
            EmptyToken,
            Enum,
            GraphImport,
            ImplDef,
            Import,
            ImportRule,
            ImportWire,
            Module,
            ModuleItem,
            ModulePath,
            ModulePattern,
            String,
            Token,
            UniNode
        },
        erased_imports {
            Ability,
            Expr,
            FuncCall,
            ImplDef,
            Import,
            Module,
            ModuleItem,
            Name,
            UniNode
        },
        expr_keys {
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
        },
        expr_keys.type_tag_borrows { SubTag, UnaryExpr },
        field_semantics {
            AstSymbolNode,
            Bool,
            Expr,
            FuncCall,
            HasVar,
            KWPair,
            Module,
            ModuleItem,
            Name
        },
        native_bindings {
            Ability,
            Archetype,
            AtomTrailer,
            Enum,
            FuncCall,
            FuncSignature,
            GlobalVars,
            HasVar,
            Import,
            KWPair,
            Module,
            ModuleItem,
            Name,
            Symbol,
            TypeAlias,
            UniNode,
            UniScopeNode,
            resolved_decl_of
        },
        passes.access_check_pass {
            Archetype,
            AstSymbolNode,
            AtomTrailer,
            Import,
            Module,
            ModuleItem,
            ModulePath,
            Name,
            Symbol
        },
        passes.ast_validation_pass {
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
            EventSignature,
            ExprAsItem,
            ExprStmt,
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
            MatchStmt,
            Module,
            ModuleCode,
            ModuleItem,
            ModulePath,
            Name,
            ParamVar,
            ReturnStmt,
            SpecialVarRef,
            SwitchStmt,
            Test,
            Token,
            TryStmt,
            TupleVal,
            TypeAlias,
            UniNode,
            WhileStmt,
            WithStmt,
            YieldExpr
        },
        passes.boundary_analysis_pass {
            Ability,
            ArchHas,
            Archetype,
            Assignment,
            AstSymbolNode,
            AtomTrailer,
            BinaryExpr,
            Bool,
            BuiltinType,
            ContextAwareNode,
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
            TupleVal,
            UnaryExpr,
            UniNode,
            ability_of_symbol,
            resolved_decl_of
        },
        passes.boundary_analysis_pass.BoundaryAnalysisPass._route_facts { KWPair },
        passes.boundary_analysis_pass.route_literal { Null },
        passes.capability_check_pass {
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
            GraphImport,
            ImplDef,
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
            String,
            Token,
            TupleVal,
            UnaryExpr,
            UniNode,
            YieldExpr,
            in_type_position
        },
        passes.cfg_build_pass {
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
            TryStmt,
            TypeAlias,
            TypedCtxBlock,
            UniCFGNode,
            UniNode,
            WhileStmt,
            WithStmt
        },
        passes.comptime_resolve_pass {
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
        },
        passes.context { ImplDef, Module, Source, TreeWalker, UniNode },
        passes.dataflow { AstElseBodyNode, UniCFGNode },
        passes.decl_impl_match_pass {
            Ability,
            Archetype,
            Assignment,
            AstImplNeedingNode,
            AstSymbolNode,
            AtomTrailer,
            BinaryExpr,
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
            bind_walrus_target,
            binding_sites_in,
            is_identifier_slot,
            typed_rebind_names
        },
        passes.declaration_type_pass {
            Ability,
            Archetype,
            CodeBlockStmt,
            Enum,
            Expr,
            FuncSignature,
            ImplDef,
            Kid,
            Module,
            ModuleCode,
            Test,
            UniNode
        },
        passes.endpoint_effect_pass {
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
            Expr,
            FuncCall,
            ImplDef,
            KWPair,
            ListVal,
            Module,
            MultiString,
            Name,
            String,
            Symbol,
            Token,
            UniNode,
            UniScopeNode,
            ability_of_symbol
        },
        passes.import_wiring_pass {
            Ability,
            AtomTrailer,
            EmptyToken,
            GraphImport,
            ImplDef,
            Import,
            ImportRule,
            ImportWire,
            JsxElementName,
            KWPair,
            Module,
            ModuleItem,
            ModulePath,
            Name,
            SpecialVarRef,
            String,
            UniNode,
            WireTarget
        },
        passes.jsx_intrinsic_guard_pass { JsxElement, Module, Name, Token, UniNode },
        passes.layout_pass {
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
            GlobalVars,
            HasVar,
            Import,
            IndexSlice,
            KWPair,
            Module,
            ModuleItem,
            Name,
            Null,
            ParamVar,
            Token,
            TupleVal,
            TypeParam,
            UnaryExpr,
            UniNode,
            UniScopeNode
        },
        passes.mtir_gen_pass {
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
        },
        passes.ownership_check_pass {
            Ability,
            Archetype,
            Assignment,
            AtomTrailer,
            AwaitExpr,
            BinaryExpr,
            BoolExpr,
            CfgExpr,
            CompareExpr,
            ConcurrentExpr,
            ConnectOp,
            CtrlStmt,
            DeleteStmt,
            DictVal,
            DisengageStmt,
            Enum as UniEnum,
            Except,
            Expr,
            ExprAsItem,
            FString,
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
            Int,
            IterForStmt,
            KWPair,
            LambdaExpr,
            ListVal,
            MatchAs,
            MatchStar,
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
            WithStmt,
            YieldExpr
        },
        passes.ownership_hints { Ability, Assignment, FuncSignature, Module, Name },
        passes.package_boundary_pass { Import, Module, ModulePath },
        passes.placement_pass {
            Ability,
            Archetype,
            AtomTrailer,
            ContextAwareNode,
            FuncCall,
            Import,
            Module,
            ModuleCode,
            ModuleItem,
            ModulePath,
            Name,
            Test,
            UniNode
        },
        passes.pyast_load_pass {
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
        },
        passes.rc_facts_pass {
            Ability,
            Assignment,
            AstAsyncNode,
            AtomTrailer,
            BinaryExpr,
            BoolExpr,
            CompareExpr,
            ConcurrentExpr,
            ConnectOp,
            CtrlStmt,
            DictCompr,
            DictVal,
            Expr,
            FString,
            FuncCall,
            FuncSignature,
            IfElseExpr,
            IfStmt,
            Import,
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
            Token,
            TryStmt,
            UnaryExpr,
            UniCFGNode,
            UniNode,
            WhileStmt,
            WithStmt,
            is_frame
        },
        passes.region_infer_pass {
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
        },
        passes.scope_walk | tools.lang_tools { UniScopeNode },
        passes.sem_def_match_pass { Module, SemDef, Symbol, UniScopeNode },
        passes.semantic_analysis_pass {
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
            Name,
            ParamVar,
            SpecialVarRef,
            TypedCtxBlock,
            UniNode,
            VisitStmt
        },
        passes.static_analysis_pass {
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
            GraphImport,
            HasVar,
            IfStmt,
            ImplDef,
            Import,
            InForStmt,
            Int,
            IterForStmt,
            JsxElement,
            JsxElementName,
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
            in_type_position,
            names_except_type
        },
        passes.static_analysis_pass.StaticAnalysisPass._check_undefined_names {
            JsxElementName
        },
        passes.sym_tab_build_pass {
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
            TryStmt,
            TypeAlias,
            TypeParam,
            TypedCtxBlock,
            UniScopeNode,
            WhileStmt,
            WithStmt,
            bind_assignment_targets,
            bind_walrus_target,
            def_insert_unpacking,
            find_python_scope_node_of,
            is_walrus,
            typed_rebind_names
        },
        passes.type_checker_pass {
            Ability,
            ArchHas,
            Archetype,
            AssertStmt,
            Assignment,
            AstSymbolNode,
            AtomTrailer,
            AtomUnit,
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
            FilterCompr,
            FinallyStmt,
            FormattedValue,
            FuncCall,
            FuncSignature,
            GenCompr,
            GlobalVars,
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
            MatchArch,
            MatchAs,
            Module,
            ModuleCode,
            ModuleItem,
            ModulePath,
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
            TryStmt,
            TupleVal,
            TypeAlias,
            UnaryExpr,
            UniCFGNode,
            UniNode,
            VisitStmt,
            WhileStmt,
            WireItem,
            WithStmt,
            YieldExpr,
            find_python_scope_node_of,
            in_type_position,
            type_only_import_of,
            type_param_of
        },
        passes.variant_agreement_pass {
            Ability,
            Archetype,
            Enum,
            FuncSignature,
            GlobalVars,
            HasVar,
            Module,
            Name,
            UniNode
        },
        passes.wasm_contract {
            Ability,
            Expr,
            FuncCall,
            FuncSignature,
            KWPair,
            Module,
            UnaryExpr
        },
        passes.wasm_contract._host_export {
            Archetype,
            Import,
            Module,
            ModuleItem,
            Name,
            ability_of_symbol,
            import_chain_of,
            resolved_decl_of
        },
        passes.wasm_contract.check_host_call { Module, Name, ability_of_symbol },
        passes.wasm_contract.host_contracts { Import },
        symbol_utils {
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
            ParamVar,
            Symbol,
            Token,
            UniNode,
            UniScopeNode,
            ability_of_symbol,
            in_type_position
        },
        tests.test_jac_mobui_typing { Import, ModuleItem, Name },
        tests.test_module_exports { Module, PythonModuleAst, Source },
        tests.test_test_block_analysis { FuncCall, Module, Name, Test },
        tools.cfg_dot {
            Ability,
            Archetype,
            BoolExpr,
            CfgExpr,
            CodeBlockStmt,
            ElseIf,
            ElseStmt,
            Except,
            Expr,
            FinallyStmt,
            ForeverStmt,
            GlobalVars,
            IfElseExpr,
            IfStmt,
            InForStmt,
            IterForStmt,
            MatchCase,
            MatchStmt,
            ModuleCode,
            ReturnStmt,
            SemDef,
            Semi,
            SwitchCase,
            SwitchStmt,
            Token,
            TryStmt,
            TypeAlias,
            UniCFGNode,
            UniNode,
            WhileStmt,
            WithStmt
        },
        tools.normalize_pass { EmptyToken, Tok, Token },
        tools.treeprinter.print_ast_tree { AstSymbolNode, Token },
        types.builtin_extensions { Name, Source },
        types.ct_eval {
            Ability,
            Archetype,
            AssertStmt,
            Assignment,
            AstImplNeedingNode,
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
            SpecialVarRef,
            String,
            Symbol,
            Token,
            TryStmt,
            TupleVal,
            TypeParam,
            UnaryExpr,
            UniNode,
            UniScopeNode,
            WhileStmt,
            definition_qualname
        },
        types.enum_utils {
            Ability,
            Archetype,
            Assignment,
            Enum,
            Int,
            Name,
            String,
            UniNode
        },
        types.fixed_width {
            AtomUnit,
            Expr,
            Float,
            FuncCall,
            Int,
            Name,
            Token,
            UnaryExpr,
            UniNode,
            int_literal_float,
            int_literal_i64,
            int_literal_u64_bits
        },
        types.operations {
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
            UniNode,
            in_type_position
        },
        types.ownership { Archetype, HasVar },
        types.stubcat.reader {
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
        },
        types.stubcat.writer {
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
            UniNode,
            UniScopeNode
        },
        types.type_evaluator {
            Ability,
            ArchSpec,
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
        },
        types.type_evaluator.TypeEvaluator._container_value_type { in_type_position },
        types.type_evaluator.TypeEvaluator._heal_class_bases
            | types.types.ClassType.get_class_symbol { Archetype },
        types.type_evaluator.TypeEvaluator._published_class_type
            | types.types._class_scope_category { Archetype },
        types.type_evaluator.TypeEvaluator._resolve_string_type_expr { SubTag },
        types.type_utils {
            Ability,
            Archetype,
            AtomTrailer,
            ElseIf,
            ElseStmt,
            Expr,
            IfStmt,
            ImplDef,
            Import,
            KWPair,
            Module,
            ModuleItem,
            Name,
            Symbol,
            UnaryExpr,
            UniNode,
            UniScopeNode
        },
        types.type_utils.expr_primitive_name { CfgExpr },
        types.types.ClassType.lookup_member_symbol {
            Ability,
            Archetype,
            Assignment,
            AtomTrailer,
            FuncSignature,
            ParamVar
        },
    ]
    frontend.unitree --> [
        types.type_evaluator.TypeEvaluator._get_type_of_expression_core {
            in_type_position
        },
        types.type_evaluator.TypeEvaluator.get_type_of_expression { names_except_type },
    ]
    frontend.unitree as uni ++> backends.es.backends.react
        | backends.es.backends.solid
        | backends.es.esast_gen_pass
        | backends.es.jsx_processor
        | backends.es.view_ir
        | backends.native.foreign
        | backends.native.na_compile_pass
        | backends.native.na_ir_gen_pass
        | driver.boundary_classify
        | driver.compiler
        | driver.ifacecache.IfaceRegistry._client_edges
        | driver.module_analysis
        | driver.module_compile
        | driver.pipeline_runner
        | driver.program
        | driver.progstate
        | driver.selfhost
        | driver.session_compile
        | driver.unit_products
        | passes.freeze_structure_pass
        | passes.graph_lowering_pass
        | passes.osp_analysis
        | placement.placement
        | placement.placement_export
        | placement.placement_facts
        | placement.placement_solver
        | placement.placement_work
        | tools.code_intel
        | tools.comment_attach_pass
        | tools.doc_ir_gen_pass
        | tools.grammar_extract_pass
        | tools.jac_auto_lint_pass
        | tools.jac_formatter_pass
        | tools.lang_tools
        | tools.normalize_pass
        | tools.reactive_use_walk
        | tools.treeprinter
        | tools.unparse_pass;
    type frontend.unitree ++> [
        backends.native.entry_points
            | driver.ifacecache
            | driver.nativecache
            | driver.pipeline
            | driver.source_products
            | types.stubcat.resolver { Module },
        backends.native.wasm_build { Module as UniModule },
        tools.treeprinter { UniNode, UniScopeNode },
        types.ct_value { Ability },
        types.types { Expr, Symbol, UniScopeNode as SymbolTable },
    ]
    type frontend.unitree as uni ++> tools.doc_ir;
    frontend.unparse ++> [
        backends.es.esast_gen_pass
            | boundary_rules.json_refusal
            | passes.layout_pass
            | passes.mtir_gen_pass
            | passes.variant_agreement_pass.annotation_text
            | passes.wasm_contract.value_contract
            | tools.cfg_dot.CoalesceBBPass._node_label
            | tools.code_intel
            | tools.jac_auto_lint_pass { unparse_node },
        boundary_rules.signature_refusals { unparse_node },
    ]
    frontend.unparse --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_unlowerable_type
            | passes.endpoint_effect_pass.EndpointEffectPass._apply { unparse_node },
        passes.endpoint_effect_pass.EndpointEffectPass._scan { unparse_node },
    ]
    intrinsic_registry ++> [
        backends.native.na_ir_gen_pass { IntrinsicEntry },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call
            | symbol_utils.intrinsic_registry_if_ready { INTRINSIC_REGISTRY },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_intrinsic {
            IntrinsicDispatch
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_intrinsic_atomic {
            IntrinsicDispatch
        },
        passes.type_checker_pass.TypeCheckPass._check_intrinsic_collision
            | types.type_evaluator.TypeEvaluator._intrinsic_function_type {
            IntrinsicRegistry
        },
    ]
    type intrinsic_registry ++> symbol_utils { IntrinsicRegistry }
    native_bindings ++> [
        passes.endpoint_effect_pass.callable_key { is_owning_scope },
        passes.layout_pass.record_interface_twins {
            interface_type,
            typeshed_stub_path
        },
        passes.placement_pass.PlacementPass._check_conformance {
            conformance_mismatches,
            native_library_module_name,
            typeshed_stub_path,
            variant_mismatches
        },
        passes.placement_pass.build_native_legality { binding_gaps },
    ]
    native_bindings --> passes.placement_pass.build_native_legality { import_gaps }
    passes ++> tools.code_intel { Alert }
    passes.access_check_pass ++> driver.pipeline.analysis_passes { AccessCheckPass }
    passes.annex_weave ++> [
        driver.wiring { WovenAnnex, import_form },
        frontend.parser.frontend { WovenAnnex, merge_annex_into },
        frontend.parser.frontend.parse_woven { merge_annex_into },
    ]
    passes.ast_validation_pass ++> driver.pipeline { ASTValidationPass }
    passes.boundary_analysis_pass ++> driver.pipeline { BoundaryAnalysisPass }
    passes.capability_check_pass ++> [
        backends.native.na_ir_gen_pass.NaIRGenPass._fstring_spec_text {
            static_fstring_spec_text
        },
        driver.pipeline.analysis_passes { PortabilityWarnPass },
    ]
    passes.capability_check_pass --> backends.native.na_ir_gen_pass.NaIRGenPass._process_clib_imports {
        classify_native_import
    }
    passes.cfg_build_pass ++> [
        driver.pipeline.flow_passes | tests.test_pipeline_products { CFGBuildPass },
        driver.pipeline.ir_passes { CFGBuildPass },
        tools.cfg_dot { is_structural_child, unwrap_to_bool },
    ]
    passes.comptime_resolve_pass --> driver.pipeline.ir_passes { ComptimeResolvePass }
    passes.context ++> [
        backends.es.esast_gen_pass
            | backends.py.jcir_gen_pass
            | tools.cfg_dot
            | tools.doc_ir_gen_pass
            | tools.grammar_extract_pass
            | tools.jac_auto_lint_pass
            | tools.normalize_pass
            | tools.unparse_pass { TreePass },
        backends.native.na_compile_pass
            | backends.py.jcir_bc_gen_pass
            | driver.context_passes
            | placement.placement_solver
            | tools.comment_attach_pass
            | tools.jac_formatter_pass { CompilerPass },
        backends.native.na_ir_gen_pass { Alert, CompilerPass },
        driver.ifacecache._alert_from_record
            | driver.module_compile.report_missing_native_ir
            | driver.program
            | frontend.parser.frontend
            | placement.placement_solver._emit_solver_warning { Alert },
        driver.pass_driver { Alert, CompilerPass, DiagnosticPolicy },
        driver.pipeline { CompilerPass, PassSchedule },
        driver.progstate { Alert, CompileContext },
        types.type_evaluator { CompileContext },
    ]
    type passes.context ++> symbol_utils { CompilerPass }
    passes.decl_impl_match_pass ++> driver.pipeline { DeclImplMatchPass }
    passes.declaration_type_pass ++> [
        backends.native.na_ir_gen_pass.NaIRGenPass._ensure_dep_inference {
            importer_lowers_bodies
        },
        driver.pipeline.declaration_passes { DeclarationTypePass },
    ]
    passes.endpoint_effect_pass ++> driver.pipeline { EndpointEffectPass }
    passes.execution ++> driver.pass_driver | tests.xbackend_equiv { run_walker }
    passes.freeze_structure_pass ++> driver.pipeline.frozen_passes {
        FreezeStructurePass
    }
    passes.graph_lowering_pass ++> driver.pipeline { GraphLoweringPass }
    passes.import_wiring_pass ++> [
        driver.pipeline { ImportWiringPass },
        tools.jac_auto_lint_pass { ScopeReads, is_effect_binding },
    ]
    passes.jsx_intrinsic_guard_pass ++> driver.pipeline.ir_passes {
        JsxIntrinsicGuardPass
    }
    passes.layout_pass ++> [
        backends.es.esast_gen_pass.EsastGenPass._field_constructor_args {
            archetype_native_name,
            get_layout_registry
        },
        backends.native.na_ir_gen_pass {
            ACCESSOR_SLOT_SUFFIX,
            ArchetypeLayout,
            EnumLayout,
            VTABLE_DROP_SLOT,
            VTABLE_HEADER_SLOTS,
            accessor_slot_name,
            archetype_accessors,
            native_type_key
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._aos_elem_name {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._arch_is_acyclic {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._arch_is_osp_name {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._arch_is_walker_name {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._arch_key { archetype_native_name },
        backends.native.na_ir_gen_pass.NaIRGenPass._arch_layout { get_layout_registry },
        backends.native.na_ir_gen_pass.NaIRGenPass._arch_ref_key {
            referenced_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._class_const_declarer {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._class_const_variants {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._class_expr_bound {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_archetype {
            EXC_MESSAGE_FIELD,
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_class_form_enum_member {
            class_form_enum_member
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_enum_layout {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_instantiation {
            EXC_MESSAGE_FIELD
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_virtual_call {
            get_layout_registry as _vd_glr
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._copy_candidates {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._drop_dispatches {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_dispatched_field_ptr {
            get_layout_registry as _df_glr
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_exception_match {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_isa_hashed_fn {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_jid { get_layout_registry },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_subclass_str {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._ensure_enum_lowered {
            class_form_enum_scalar,
            enum_decl_of,
            enum_value_type_of,
            is_enum_class_type
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._enum_ctor_layout {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._erased_want {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._exc_message_slot {
            EXC_MESSAGE_FIELD
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._exc_stored_message {
            EXC_MESSAGE_FIELD
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._exception_member_name {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._get_exc_descendants {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._is_enum_arch {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._is_graph_type {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._isinstance_needs_class_name {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._isinstance_unprovable_class {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._jc_reference_schema {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._lower_class_type {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._mangled_of { native_type_key },
        backends.native.na_ir_gen_pass.NaIRGenPass._match_arch_name {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._module_class_name {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._mro_of { get_layout_registry },
        backends.native.na_ir_gen_pass.NaIRGenPass._native_archetypes {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._nogc_osp_skip {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._nogc_type_arg_mangles {
            native_type_key
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._register_archetypes {
            get_layout_registry,
            get_layout_registry as _no_glr
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._register_class_consts {
            class_form_enum_scalar
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._register_exc_lineage {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._register_imported_hierarchy {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._register_imported_struct_types {
            adopt_imported_bases
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._report_unreachable_overrides {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._resolve_method {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._resolve_method_owner {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._store_exc_message {
            EXC_MESSAGE_FIELD
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._visit_nonprimary_ancestor_methods {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._vtable_candidates {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._vtable_slot_certain {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._walk_imported_module_type_names {
            record_interface_twins
        },
        boundary_rules.archetype_fields { referenced_archetype },
        driver.pipeline.layout_passes { LayoutPass },
        symbol_utils.collect_method_names { archetype_accessors },
    ]
    passes.layout_pass --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_instantiation {
            get_layout_registry as _ci_glr
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_plain_trailer {
            class_form_enum_member,
            class_form_enum_scalar
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_virtual_call {
            get_layout_registry as _vc_glr
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._elem_arch_name_of {
            class_type_native_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_default_obj_repr {
            get_layout_registry
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._receiver_routed_method_fn {
            get_layout_registry as _sc_glr
        },
    ]
    type passes.layout_pass ++> frontend.codeinfo { LayoutRegistry }
    passes.mtir_gen_pass --> driver.pipeline.ir_passes { MTIRGenPass }
    passes.osp_analysis ++> [
        backends.es.esast_gen_pass { OspAnalysis, OspModel, OspSlot },
        backends.es.esast_gen_pass.EsastGenPass._osp_model
            | backends.native.na_ir_gen_pass.NaIRGenPass._compute_osp_model {
            get_osp_model
        },
        backends.native.na_ir_gen_pass { OSP_ANY_TAGS },
        backends.native.na_ir_gen_pass.NaIRGenPass._trigger_struct_names {
            OspAnalysis
        },
    ]
    type passes.osp_analysis ++> [
        backends.native.na_ir_gen_pass { OspSlot },
        frontend.codeinfo { OspModel },
    ]
    passes.ownership_check_pass ++> driver.pipeline.analysis_passes {
        OwnershipCheckPass
    }
    passes.package_boundary_pass ++> driver.pipeline { PackageBoundaryPass }
    passes.placement_pass ++> [
        backends.native.na_ir_gen_pass { NativeLegality, NativeRefusal, NativeRefused },
        backends.native.na_ir_gen_pass.NaIRGenPass._demote_method_if_unlowerable {
            refusal_from_alert
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._lower_module {
            build_native_legality
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._owner_required {
            element_requirements
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._settle_module {
            settle_native_module
        },
        driver.pipeline.analysis_passes { PlacementPass },
    ]
    passes.placement_pass --> backends.native.na_compile_pass.NativeCompilePass._run_impl {
        settle_native_module
    }
    passes.pyast_load_pass ++> [
        driver.pipeline.python_ast_passes | tools.lang_tools { PyastBuildPass },
        tools.lang_tools.AstTool.py_uni_nodes { PyastBuildPass },
    ]
    passes.rc_facts_pass ++> [
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_for_indexed {
            loop_body_locals
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_forever {
            loop_body_locals
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_iter_for {
            loop_body_locals
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_open_stmt {
            loop_body_locals
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_while { loop_body_locals },
        backends.native.na_ir_gen_pass.NaIRGenPass._opt_result_owned {
            Ownership,
            result_ownership
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._try_chunked_for {
            loop_body_locals
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._try_iter_protocol_for {
            loop_body_locals
        },
        driver.pipeline.codegen_passes { RcFactsPass },
        driver.pipeline.native_ir_passes { RcFactsPass },
        driver.pipeline.native_lower_passes { RcFactsPass },
    ]
    passes.rc_facts_pass --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_expr {
            Ownership,
            call_borrows_receiver,
            result_ownership
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_with_recursive {
            method_returns_borrow
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._try_flow_for_parallel {
            loop_body_locals
        },
    ]
    passes.region_infer_pass ++> driver.pipeline.analysis_passes { RegionInferPass }
    passes.scope_walk ++> tools.code_intel { ScopeWalker }
    passes.sem_def_match_pass ++> driver.pipeline.ir_passes { SemDefMatchPass }
    passes.semantic_analysis_pass ++> driver.pipeline { SemanticAnalysisPass }
    passes.static_analysis_pass ++> driver.pipeline.analysis_passes {
        StaticAnalysisPass
    }
    passes.sym_tab_build_pass ++> driver.pipeline { SymTabBuildPass }
    passes.sym_tab_build_pass --> driver.program.JacProgram.load_dependency_module {
        SymTabBuildPass
    }
    passes.type_checker_pass ++> driver.pipeline.analysis_passes
        | tests.test_pipeline_products
        | tests.xbackend_equiv.compile_fixture_to_js { TypeCheckPass }
    passes.variant_agreement_pass ++> [
        driver.pipeline.analysis_passes { VariantAgreementPass },
        driver.wiring.unnamed_module_label { ANNEX_MARKERS },
        driver.wiring.variant_base_file { VARIANT_SUFFIX },
    ]
    pkg_paths ++> [
        driver.jir._ct_pkg_ref | placement.placement_facts._toolchain_rel {
            target_package_rel
        },
        driver.native_iface | frontend.codeinfo { target_pkg_root },
        driver.program.JacProgram.declared_codespace { package_host_edge },
    ]
    pkg_paths --> [
        driver.jir._ct_row_path { target_pkg_root },
        driver.program.JacProgram.infers_native_codespace { package_host_edge },
        frontend.codeinfo._inferred_native_path { scope_allows_inferred_path },
        frontend.codeinfo.native_arch_scope { binds_bare_arch_names },
    ]
    placement.placement ++> [
        backends.native.na_ir_gen_pass.NaIRGenPass._owner_element
            | passes.placement_pass.element_requirements { element_display_name },
        driver.compiler.JacCompiler.native_entry_engine { summary_store },
        driver.unit_products.placement_record | symbol_utils.report_placement_warnings {
            get_module_summary
        },
        passes.placement_pass.PlacementPass._run_undecided { record_decided },
        passes.placement_pass.build_native_legality { native_blocker_scan },
        passes.placement_pass.settle_native_module { record_decided },
        symbol_utils.client_bridged_endpoint { project_has_server },
        symbol_utils.report_serverless_kind_errors { project_kind_name },
        symbol_utils.serverless_server_evidence {
            get_module_summary,
            project_has_server
        },
    ]
    placement.placement --> [
        driver.compiler.JacCompiler._restore_sections
            | driver.ifacecache.IfaceRegistry._restore_placement { summary_store },
        driver.module_analysis.run_analysis { record_decided },
    ]
    type placement.placement ++> driver.progstate { PlacementSummary }
    placement.placement_export ++> driver.unit_products.placement_record {
        summary_to_dict
    }
    placement.placement_export --> driver.compiler.JacCompiler._restore_sections
        | driver.ifacecache.IfaceRegistry._restore_placement { summary_from_bytes }
    placement.placement_facts ++> [
        backends.native.na_ir_gen_pass.NaIRGenPass._dep_is_native_unit { native_unit },
        driver.module_compile.admits_native_checks { variant_selected },
        driver.program.JacProgram.declared_codespace {
            native_only,
            native_unit,
            variant_selected
        },
        driver.program.JacProgram.prefers_native_codespace {
            native_only,
            native_placement_hard
        },
        driver.unit_products.placement_record { module_spaces },
        passes.placement_pass { native_placement_soft },
        passes.placement_pass.PlacementPass._run_undecided { contexts_of },
        passes.placement_pass.settle_native_module { settle_server },
    ]
    placement.placement_facts --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._native_imports {
            native_unit as _typed_native_unit
        },
        driver.module_analysis.run_analysis { settle_server },
        driver.nativecache.NativeUnitRegistry.known_native_deps { native_unit },
        pkg_paths.package_host_edge { native_lowered, native_unit },
    ]
    placement.placement_pins ++> [
        driver.boundary_classify { BareImportVerdict, classify_bare_import },
        driver.boundary_classify.import_declares_native_target { effective_module_pin },
        driver.boundary_classify.native_only_import_target { effective_module_pin },
        driver.boundary_classify.plain_native_import_target { effective_module_pin },
        driver.program.JacProgram.declared_codespace {
            config_kind_space,
            effective_module_pin
        },
        driver.program.JacProgram.prefers_native_codespace {
            config_kind_space,
            effective_module_pin
        },
        driver.program.JacProgram.stamp_boundary_facts
            | passes.boundary_analysis_pass.BoundaryAnalysisPass._bind_server_callee {
            config_module_pin
        },
        passes.placement_pass.element_requirements {
            config_element_pin,
            config_pin_for
        },
    ]
    placement.placement_pins --> [
        driver.jir._project_env_fingerprint_uncached { config_kind_space, pins_digest },
        driver.program.JacProgram.stamp_app_facts { module_dot_path },
        passes.static_analysis_pass.StaticAnalysisPass._check_client_imports {
            in_client_npm_world
        },
    ]
    placement.placement_solver ++> [
        driver.pipeline { PlacementApplyPass },
        driver.pipeline.place_module {
            refresh_placement_module,
            solve_program_placement
        },
        passes.placement_pass.PlacementPass._run_decided {
            placement_work,
            refresh_placement_module,
            solve_module_placement
        },
        passes.placement_pass.PlacementPass._run_undecided {
            native_placement_candidate,
            placement_work,
            refresh_placement_module,
            solve_module_placement
        },
        passes.placement_pass._demote_unreached_imports {
            placement_work,
            refresh_placement_module
        },
        passes.placement_pass.build_native_legality { native_closure_blocker },
        passes.placement_pass.settle_native_module { invalidate_importers_es },
        passes.placement_pass.uncrossable_native {
            placement_work,
            refresh_placement_module
        },
    ]
    placement.placement_solver --> [
        driver.boundary_classify.plain_native_import_target { _materialize_module },
        driver.module_analysis.run_analysis { placement_work },
        driver.program.JacProgram.parse_source { native_placement_candidate },
        frontend.codeinfo._inferred_native_path { native_default_path_ok },
    ]
    type placement.placement_work ++> driver.progstate { PlacementWork }
    symbol_utils ++> [
        backends.es.esast_gen_pass | passes.type_checker_pass { return_type_is_jsx },
        backends.es.esast_gen_pass.EsastGenPass._bind_client_value_refs {
            client_bridged_endpoint,
            client_value_ref_targets,
            element_display_name
        },
        backends.es.esast_gen_pass.EsastGenPass._build_spawn_arg_object {
            collect_field_names,
            symbol_owner_archetype
        },
        backends.es.esast_gen_pass.EsastGenPass._build_spawn_runtime_call {
            symbol_owner_archetype
        },
        backends.es.esast_gen_pass.EsastGenPass._partition_client_import_items {
            report_dead_client_import
        },
        backends.es.esast_gen_pass.EsastGenPass._resolve_call_ability {
            ability_of_symbol
        },
        backends.es.esast_gen_pass.EsastGenPass._resolve_source_module {
            resolve_import_source_module
        },
        backends.es.esast_gen_pass.EsastGenPass.exit_module {
            report_client_bare_import_uses
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._callee_ability_of
            | c_interop.c_abi_callee
            | passes.ownership_check_pass.OwnershipCheckPass._callee_ability {
            resolved_callee
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_method_call_inner {
            imported_module_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_synthetic_call
            | passes.type_checker_pass.TypeCheckPass.exit_func_call {
            ability_of_symbol,
            classify_call,
            resolve_expr_symbol
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._native_module_call_target {
            imported_module_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._unregistered_class_target
            | types.type_evaluator.TypeEvaluator.flow_pred_never_returns {
            resolve_expr_symbol
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._visit_nonprimary_ancestor_methods {
            collect_method_names
        },
        passes.ownership_check_pass { CallKind, classify_call },
        passes.placement_pass.PlacementPass._run_decided
            | placement.placement_solver.PlacementApplyPass._run_impl {
            report_serverless_kind_errors
        },
        passes.placement_pass.PlacementPass._run_undecided {
            report_serverless_kind_errors
        },
        passes.static_analysis_pass.StaticAnalysisPass._check_client_imports {
            report_dead_client_import,
            resolve_import_source_module
        },
        passes.static_analysis_pass.StaticAnalysisPass._check_placement_warnings {
            report_placement_warnings,
            report_serverless_kind_errors
        },
        passes.type_checker_pass.TypeCheckPass._check_intrinsic_collision
            | types.type_evaluator.TypeEvaluator._intrinsic_function_type {
            intrinsic_registry_if_ready
        },
        types.type_evaluator.TypeEvaluator._resolve_importer_path {
            resolve_importer_path_from_node
        },
    ]
    symbol_utils --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_plain_trailer {
            imported_module_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._copy_call_kind {
            imported_module_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._isinstance_type_name
            | backends.py.jcir_gen_pass.JcirGenPass._exit_func_call_impl {
            CallKind,
            classify_call
        },
        placement.placement_export.collect_placement_rows
            | types.type_evaluator.TypeEvaluator._is_sv_async_call {
            resolve_import_source_module
        },
    ]
    target_spec ++> backends.native.link_glue.link_glue_ir { triple_osarch }
    tools.cfg_dot ++> driver.pipeline.cfg_dot_passes { CoalesceBBPass }
    tools.code_intel ++> tests.test_code_intel { CodeIntelligence }
    tools.comment_attach_pass ++> [
        driver.pipeline.format_lintfix_passes { CommentAttachPass },
        driver.pipeline.format_passes { CommentAttachPass },
    ]
    tools.doc_ir as doc --> frontend.codeinfo.CodeGenTarget.doc_ir.getter;
    type tools.doc_ir ++> frontend.codeinfo { Doc }
    tools.doc_ir_gen_pass ++> [
        driver.pipeline.doc_passes { DocIRGenPass },
        driver.pipeline.format_lintfix_passes { DocIRGenPass },
        driver.pipeline.format_passes { DocIRGenPass },
    ]
    tools.grammar_extract_pass ++> driver.pipeline.grammar_passes { GrammarExtractPass }
    tools.jac_auto_lint_pass ++> [
        driver.pipeline.analysis_passes { JacLintCheckPass },
        driver.pipeline.format_lintfix_passes { JacAutoLintPass },
        driver.pipeline.lint_passes { JacLintCheckPass },
    ]
    tools.jac_formatter_pass ++> [
        driver.pipeline.format_lintfix_passes { JacFormatPass },
        driver.pipeline.format_passes { JacFormatPass },
        driver.pipeline.format_text_passes { JacFormatPass },
    ]
    tools.normalize_pass ++> driver.pipeline.normalize_passes { NormalizePass }
    tools.unparse_pass ++> driver.pipeline.unparse_passes { UnparsePass }
    type_registry ++> [
        backends.es.esast_gen_pass.EsastGenPass._audit_free_identifiers
            | backends.es.jac_runtime_js._build_exc_runtime_js
            | backends.native.foreign
            | backends.native.host_facts.primitive_methods_fact
            | backends.native.na_ir_gen_pass.NaIRGenPass.__post_init__
            | c_interop._spec_for_name
            | passes.declaration_type_pass
            | passes.layout_pass
            | passes.mtir_gen_pass
            | passes.ownership_check_pass
            | passes.type_checker_pass.TypeCheckPass._borrowed_scalar_param
            | passes.wasm_contract._host_type
            | symbol_utils.classify_call
            | types.type_evaluator.TypeEvaluator._brand_distinct_alias
            | types.type_utils.primitive_type_name_of { JAC_TYPE_REGISTRY },
        backends.es.esast_gen_pass.EsastGenPass._ensure_emitters
            | backends.es.jac_runtime_js._build_types_runtime_js
            | backends.native.na_ir_gen_pass.NaIRGenPass._anchor_immutable
            | c_interop.c_bytes_elem_shape
            | passes.type_checker_pass.TypeCheckPass._c_plain_data
            | passes.wasm_contract.value_contract
            | types.type_evaluator.TypeEvaluator._extern_field_type {
            JAC_TYPE_REGISTRY
        },
        backends.es.esast_gen_pass.EsastGenPass._primitive_type_ref
            | backends.native.na_ir_gen_pass.NaIRGenPass._anchor_plain
            | c_interop.c_scalar_constant
            | passes.type_checker_pass.TypeCheckPass._stamp_fixed_width
            | types.type_evaluator.TypeEvaluator._extern_scalar_type {
            JAC_TYPE_REGISTRY
        },
        backends.es.esast_gen_pass.EsastGenPass.exit_archetype
            | backends.native.na_ir_gen_pass.NaIRGenPass._c_scalar_llvm
            | passes.type_checker_pass.TypeCheckPass.exit_archetype
            | types.type_evaluator.TypeEvaluator._is_typed_c_declaration {
            JAC_TYPE_REGISTRY
        },
        backends.es.esast_gen_pass.EsastGenPass.exit_raise_stmt
            | backends.native.na_ir_gen_pass.NaIRGenPass._codegen_name
            | passes.type_checker_pass.TypeCheckPass.exit_type_alias {
            JAC_TYPE_REGISTRY
        },
        backends.es.esast_gen_pass._raised_exc_identity
            | backends.native.na_ir_gen_pass.NaIRGenPass._codegen_sized_builtin_call {
            JAC_TYPE_REGISTRY
        },
        backends.native.na_ir_gen_pass { JacTypeEntry },
        backends.native.na_ir_gen_pass.NaIRGenPass._ensure_emitters {
            JAC_TYPE_REGISTRY
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._get_exc_descendants {
            JAC_TYPE_REGISTRY
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._get_or_register_exc_type {
            JAC_TYPE_REGISTRY
        },
        backends.native.na_ir_gen_pass._caught_exception_class_name {
            JAC_TYPE_REGISTRY
        },
        types.fixed_width | types.operations.is_int_kind_type {
            JAC_TYPE_REGISTRY,
            NumericKind
        },
    ]
    type_registry --> [
        backends.es.esast_gen_pass.EsastGenPass._lower_func_call
            | passes.ownership_check_pass.OwnershipCheckPass._handled_by_enclosing_try
            | types.type_evaluator.TypeEvaluator._assign_class { JAC_TYPE_REGISTRY },
        backends.es.esast_gen_pass.EsastGenPass.exit_try_stmt { JAC_TYPE_REGISTRY },
    ]
    type types.ct_eval ++> backends.native.na_ir_gen_pass { CtEvaluator }
    types.ct_value ++> [
        backends.es.esast_gen_pass {
            CtBool,
            CtDict,
            CtFloat,
            CtInt,
            CtList,
            CtNone,
            CtSet,
            CtStr,
            CtTuple,
            CtValue,
            int_host
        },
        backends.native.na_ir_gen_pass {
            CtBool,
            CtBytes,
            CtFloat,
            CtInt,
            CtNone,
            CtStr,
            CtValue,
            ct_iter,
            ct_mangle,
            ct_truthy
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._instantiate_generic { ct_mangle },
        backends.py.jcir_gen_pass.JcirGenPass._ct_kind {
            CtDict,
            CtEnumMember,
            CtFunc,
            CtList,
            CtRecord,
            CtSet,
            CtTuple,
            CtType,
            ct_is_scalar
        },
        backends.py.jcir_gen_pass.JcirGenPass._ct_materializable {
            ct_is_materializable
        },
        backends.py.jcir_gen_pass.JcirGenPass._ct_order_key {
            CtBool,
            CtBytes,
            CtEnumMember,
            CtFloat,
            CtFunc,
            CtInt,
            CtNone,
            CtSet,
            CtStr,
            CtTuple,
            CtType,
            ct_repr
        },
        backends.py.jcir_gen_pass.JcirGenPass._materialize {
            CtDict,
            CtEnumMember,
            CtFunc,
            CtInt,
            CtList,
            CtRecord,
            CtSet,
            CtTuple,
            CtType,
            ct_host_scalar,
            ct_is_scalar
        },
        backends.py.jcir_gen_pass.JcirGenPass.int_const_of { int_host, int_wide_bytes },
        frontend.host.HostServices.ct_environment { CtEnvironment },
        passes.type_checker_pass { ct_is_iterable, ct_str, ct_truthy, ct_type_name },
    ]
    type types.ct_value ++> [
        backends.py.jcir_gen_pass { CtInt, CtRecord, CtValue },
        frontend.host { CtEnvironment },
        frontend.unitree { CtValue },
    ]
    types.fixed_width ++> [
        passes.declaration_type_pass
            | passes.type_checker_pass.TypeCheckPass._stamp_fixed_width {
            numeric_name_of
        },
        passes.type_checker_pass.TypeCheckPass._provably_in_range {
            interval_of_expr,
            interval_of_op
        },
    ]
    types.operations ++> [
        backends.es.esast_gen_pass { AUG_TO_BINARY_MAP },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_arch_dunder_binop {
            BINARY_OPERATOR_MAP
        },
        passes.type_checker_pass {
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
        },
    ]
    types.ownership ++> passes.ownership_check_pass.OwnershipCheckPass._view_arch_of_call {
        contains_borrow
    }
    types.stubcat.build ++> tests.test_stubcat_roundtrip { build_catalog }
    types.stubcat.build as catalog_build --> tests.test_stubcat_roundtrip;
    types.stubcat.format --> driver.compiler.JacCompiler.ensure_stub_catalog;
    types.stubcat.locate ++> tests.test_stubcat_roundtrip {
        StubcatArtifact,
        jaclang_pkg_dir,
        reset_catalog_cache,
        typeshed_stdlib_dir
    }
    types.stubcat.locate --> [
        driver.compiler.JacCompiler.ensure_stub_catalog { open_catalog },
        driver.ifacecache.IfaceRegistry._pkg_dir { jaclang_pkg_dir },
    ]
    types.stubcat.reader ++> [
        driver.program.JacProgram.load_dependency_module
            | driver.unit_products.dependency_span_rows
            | passes.endpoint_effect_pass.EndpointEffectPass._served_effects {
            CatModule
        },
        native_bindings.is_owning_scope { CatScope },
        tests.test_stubcat_roundtrip { StubCatalog, open_catalog_file },
    ]
    types.stubcat.reader --> [
        driver.compiler.JacCompiler.ensure_stub_catalog,
        placement.placement_solver._import_source_module { CatModule },
    ]
    type types.stubcat.reader ++> driver.compiler | driver.program | frontend.host {
        StubCatalog
    }
    types.stubcat.resolver ++> driver.ifacecache { CatalogResolver }
    types.stubcat.writer ++> [
        driver.ifacecache.IfaceRegistry._encode_iface {
            IncoherentInterface,
            PackagePathMapper
        },
        driver.jir.JirPaths.encode { encode_package_path },
    ]
    types.ts_decl_parser --> tests.test_jac_mobui_typing { parse_dts }
    types.type_evaluator ++> [
        driver.program.JacProgram.get_type_evaluator { TypeEvaluator },
        tests.test_jac_mobui_typing { FunctionType, UnknownType },
    ]
    type types.type_evaluator ++> driver.program | passes.type_checker_pass {
        TypeEvaluator
    }
    types.type_utils ++> [
        backends.es.esast_gen_pass.EsastGenPass._expr_type_name { expr_primitive_name },
        backends.es.esast_gen_pass.EsastGenPass._resolve_primitive_type_name
            | backends.native.na_ir_gen_pass.NaIRGenPass._container_class_name {
            primitive_type_name_of
        },
        backends.es.esast_gen_pass.EsastGenPass._try_primitive_op {
            expr_primitive_name
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._check_native_import_names {
            lookup_symtab
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._is_boolean_result_expr {
            primitive_type_name_of
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._is_number_slot {
            primitive_type_name_of
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._key_elem_unsigned {
            primitive_type_name_of
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._lower_coercion {
            primitive_type_name_of
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._lower_partition_unpack
            | passes.ownership_check_pass { is_builtin_region_type },
        backends.native.na_ir_gen_pass.NaIRGenPass._scalar_shape {
            primitive_type_name_of
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._sort_key_orderable {
            primitive_type_name_of
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._sort_key_unsigned {
            primitive_type_name_of
        },
        native_bindings { collect_member_syms },
        passes.rc_facts_pass.RcFactsPass._asn_makes_region_handle {
            expr_is_builtin_region
        },
        passes.type_checker_pass {
            BARE_GENERIC_REQUIRED,
            PropertyWriteKind,
            get_declared_generator_return_type,
            get_generator_yield_type,
            is_generator_family_type
        },
        tests.test_property_write_kind { PropertyWriteKind },
    ]
    types.type_utils --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_call {
            is_builtin_region_type
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_method_call_inner {
            is_builtin_region_type
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._match_subj_ty {
            convert_to_instance
        },
        passes.static_analysis_pass.StaticAnalysisPass._check_semantic_patterns {
            expr_primitive_name
        },
    ]
    types.types ++> [
        backends.es.esast_gen_pass
            | backends.native.na_ir_gen_pass.NaIRGenPass._register_exc_lineage {
            ClassType,
            TypeBase
        },
        backends.es.esast_gen_pass.EsastGenPass._arch_kind_of_type
            | backends.native.na_ir_gen_pass.NaIRGenPass._agg_key_args
            | passes.capability_check_pass
            | passes.layout_pass.class_form_enum_scalar
            | passes.ownership_check_pass.OwnershipCheckPass._raised_class_names {
            ClassType
        },
        backends.es.esast_gen_pass.EsastGenPass._build_spawn_runtime_call
            | backends.native.na_ir_gen_pass.NaIRGenPass._container_class_name
            | passes.layout_pass.class_type_native_name
            | passes.ownership_check_pass.OwnershipCheckPass._view_arch_of_call {
            ClassType
        },
        backends.es.esast_gen_pass.EsastGenPass._builtin_param_names {
            FunctionType,
            ParameterCategory
        },
        backends.es.esast_gen_pass.EsastGenPass._exit_name_impl {
            ClassType as _ClassType
        },
        backends.es.esast_gen_pass.EsastGenPass._field_constructor_args
            | backends.native.na_ir_gen_pass.NaIRGenPass._exception_member_name
            | passes.layout_pass.declaring_module_path
            | passes.ownership_check_pass._is_class_object { ClassType },
        backends.es.esast_gen_pass.EsastGenPass._osp_expr_arch_name
            | backends.native.na_ir_gen_pass.NaIRGenPass._sort_key_orderable
            | passes.layout_pass.enum_class_of { ClassType },
        backends.native.na_ir_gen_pass {
            ClassType,
            FunctionType as SemanticFunctionType,
            ModuleType,
            Parameter,
            TypeBase,
            UnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._c_scalar_llvm {
            ClassType as _CClassType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._emit_jid
            | frontend.unitree.DeleteStmt.type_may_hold_graph { ClassType, UnionType },
        backends.native.na_ir_gen_pass.NaIRGenPass._enum_name_of {
            ClassType as EnumClassType,
            EnumMemberType,
            TypeBase,
            UnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._is_graph_type {
            ClassType as _GtClassType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._is_object_union_key {
            ClassType,
            UnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._lower_clib_function_type {
            FunctionType as CallbackType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._sort_key_return_type
            | c_interop.c_param_type { FunctionType },
        backends.native.na_ir_gen_pass.NaIRGenPass._typed_elem_llvm_of {
            TypeVarType as _TeTypeVar
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._typevar_bound_struct
            | frontend.unitree.DeleteStmt.type_has_graph_member {
            ClassType,
            TypeVarType,
            UnionType
        },
        c_interop.c_type_spec
            | passes.layout_pass.LayoutPass._is_layout_compatible_semantic_type
            | passes.ownership_check_pass { ClassType, FunctionType, UnionType },
        native_bindings { ClassType, FunctionType, OverloadedType, TypeBase },
        passes.capability_check_pass._class_bounded_typevar { ClassType, TypeVarType },
        passes.layout_pass.class_form_enum_member { EnumMemberType },
        passes.layout_pass.native_type_key {
            ClassType,
            FunctionType,
            OverloadedType,
            UnionType
        },
        passes.layout_pass.record_interface_twins { ClassType },
        passes.layout_pass.referenced_archetype { ClassType },
        passes.layout_pass.referenced_native_name { ClassType },
        passes.ownership_check_pass.OwnershipCheckPass._emit_place_intrinsic_diagnostics {
            ClassType,
            TypeBase,
            UnionType
        },
        passes.ownership_check_pass.OwnershipCheckPass._nogc_infer_locals { AnyType },
        passes.type_checker_pass {
            AnyType,
            ClassType,
            EnumMemberType,
            FunctionType,
            ModuleType,
            NeverType,
            OverloadedType,
            TypeBase,
            TypeVarType,
            UnionType,
            UnknownType
        },
        passes.type_checker_pass.TypeCheckPass._install_client_state_setters {
            create_callable_type
        },
        passes.wasm_contract.check_host_call { ClassType, FunctionType },
        symbol_utils.imported_module_name { ModuleType },
        tests.test_stubcat_roundtrip { ClassType, FunctionType, OverloadedType },
    ]
    types.types --> [
        backends.native.na_ir_gen_pass.NaIRGenPass._aos_elem_name {
            ClassType as _AeClassType,
            TypeVarType as _AeTypeVarType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._apply_flow_narrowing {
            ClassType as _ClassType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._class_expr_bound { TypeVarType },
        backends.native.na_ir_gen_pass.NaIRGenPass._codegen_archetype {
            FunctionType as _ClibFnType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._elem_arch_name_of {
            ClassType as _ClassType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._elem_storage_llvm {
            ClassType as _EsClassType,
            UnionType as _EsUnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._enum_union_tags {
            ClassType as _EnClassType,
            EnumMemberType as _EnMemberType,
            UnionType as _EnUnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._erased_decl {
            ClassType as _EdClassType,
            TypeVarType as _EdTypeVarType,
            UnionType as _EdUnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._erased_decl_names {
            TypeVarType as _EnTypeVarType,
            UnionType as _EnUnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._erased_seq_type {
            ClassType as _EsqClassType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._erased_typevar_names {
            TypeVarType as _EtvTypeVarType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._foreign_optional_field {
            ClassType as _FofClassType,
            TypeVarType as _FofTypeVarType,
            UnionType as _FofUnionType,
            UnknownType as _FofUnknownType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._instantiate_generic_for_target {
            FunctionType as _A5FnType,
            TypeVarType as _A5TypeVar
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._is_runtime_class_tuple {
            ClassType as _SeqClassType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._isinstance_abc_reduction {
            ClassType as _AbcClassType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._lower_type {
            AnyType as _AnyType,
            ClassType as _ClassType,
            EnumMemberType as _EnumMemberType,
            FunctionType as _FunctionType,
            NeverType as _NeverType,
            TypeVarType as _TypeVarType,
            UnionType as _UnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._lower_view_container {
            ClassType as _VcClassType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._opt_sole_member {
            ClassType as _OsClassType,
            UnionType as _OsUnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._osp_disc_list_operand {
            ClassType as _DiscClassType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._resolve_field_type {
            TypeVarType as _RfTypeVarType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._solve_generic_call {
            ClassType as _CT,
            TypeVarType as _TVT,
            UnionType as _UT
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._sort_key_orderable { UnknownType },
        backends.native.na_ir_gen_pass.NaIRGenPass._spec_union_agreement {
            ClassType as _SuClassType,
            UnionType as _SuUnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._syntactic_bind_type_params {
            ClassType as _SbCT
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._type_base_is_unknown {
            UnknownType as _UnknownType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._typevar_optional_field {
            ClassType as _TvoClassType,
            TypeVarType as _TvoTypeVarType,
            UnionType as _TvoUnionType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._unbox_narrowed_member {
            ClassType as _ClassType
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._variadic_tuple_seq_type {
            UnknownType as _VtUnknown
        },
        backends.native.na_ir_gen_pass.NaIRGenPass._widened_tuple_decl_type {
            ClassType as _WdClassType
        },
        backends.py.jcir_gen_pass.JcirGenPass._clib_block_desc { FunctionType },
        c_interop._ambient_c_call_returns { FunctionType, OverloadedType },
        c_interop.c_type_arg { AnyType, ClassType, UnknownType },
        passes.boundary_analysis_pass.BoundaryAnalysisPass.enter_atom_trailer
            | passes.ownership_check_pass.OwnershipCheckPass._handled_by_enclosing_try {
            ClassType
        },
    ]
    type types.types ++> [
        backends.native.primitives_native
            | frontend.unitree
            | passes.ownership_check_pass { TypeBase },
        c_interop { ClassType, TypeBase },
        driver.ifacecache { ClassDetailsShared },
        frontend.relations {
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
        },
        passes.layout_pass { ClassDetailsShared, ClassType, TypeBase },
    ]
}

graph import compiler.backends {
    common.primitives ++> [
        es.esast_gen_pass
            | es.jac_runtime_js._build_types_runtime_js
            | native.na_ir_gen_pass { PrimitiveEmitter },
        es.primitives_es {
            BuiltinEmitter,
            BytesEmitter,
            ComplexEmitter,
            DictEmitter,
            FloatEmitter,
            FrozensetEmitter,
            IntEmitter,
            ListEmitter,
            PrimitiveEmitter,
            RangeEmitter,
            SetEmitter,
            StrEmitter,
            TupleEmitter
        },
        native.primitives_native {
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
        },
    ]
    es ++> es.client_kernel_cache._lower { estree as es }
}

graph import compiler.backends.es {
    backends.react --> esast_gen_pass.EsastGenPass._ensure_backend { ReactBackend }
    backends.registry --> esast_gen_pass.EsastGenPass._ensure_backend {
        active_framework,
        resolve_framework_backend
    }
    client_paths ++> esast_gen_pass { relative_js_specifier }
    es_unparse ++> [
        client_kernel_cache._lower { es_to_js },
        esast_gen_pass { JSCodeGenerator, es_to_js },
        esast_gen_pass.EsastGenPass._try_primitive_op
            | jac_runtime_js._build_types_runtime_js { JSCodeGenerator },
    ]
    es_unparse --> esast_gen_pass.EsastGenPass._lower_func_call { JSCodeGenerator }
    type esast_gen_pass ++> jsx_processor { EsastGenPass }
    estree as es ++> backends.react
        | backends.solid
        | es_unparse
        | esast_gen_pass
        | framework_backend
        | free_ident_audit
        | jsx_processor
        | reactive_intent
        | view_ir;
    type estree ++> jsx_processor { Expression }
    framework_backend ++> backends.react
        | backends.registry
        | backends.solid
        | esast_gen_pass { FrameworkBackend }
    free_ident_audit ++> esast_gen_pass {
        FreeIdentifier,
        RUNTIME_PRELUDE_GLOBALS,
        client_ambient_globals,
        free_identifiers,
        js_identifiers
    }
    jac_runtime_js ++> client_kernel_cache._lower
        | esast_gen_pass.EsastGenPass._inject_runtime_import { JAC_PRELUDE_MODULE }
    jac_runtime_js --> esast_gen_pass.EsastGenPass.exit_module {
        JAC_PRELUDE_MODULE,
        build_osp_core_js,
        build_osp_driver_js
    }
    js_paths ++> esast_gen_pass { convert_to_js_import_path }
    jsx_processor ++> esast_gen_pass { EsJsxProcessor }
    primitives_es ++> [
        esast_gen_pass | jac_runtime_js._build_types_runtime_js {
            ESBuiltinEmitter,
            ESEmitCtx,
            es_sized_cast
        },
        esast_gen_pass.EsastGenPass._ensure_emitters { es_primitive_emitter },
    ]
    reactive_intent ++> backends.react
        | backends.solid
        | esast_gen_pass
        | framework_backend { AsyncBoundary, Effect, RefField, StateField, StateUpdate }
    scoped_styles ++> esast_gen_pass { ScopedStyleSheet, load_style_annex }
    view_ir ++> [
        backends.react {
            DynamicAttr,
            EventAttr,
            RefAttr,
            StaticAttr,
            ViewLocator,
            view_attr_node
        },
        backends.react.ReactBackend.lower_view {
            ComponentTag,
            DynamicChild,
            DynamicTag,
            EachChild,
            ElementChild,
            HostTag,
            IfChild,
            SpreadAttr,
            TextChild
        },
        backends.solid {
            DynamicAttr,
            EachChild,
            EventAttr,
            IfChild,
            RefAttr,
            SpreadAttr,
            StaticAttr,
            ViewLocator
        },
        backends.solid.SolidBackend._jsx_child_nodes {
            DynamicChild,
            EachChild,
            ElementChild,
            FragmentTag,
            IfChild,
            TextChild
        },
        backends.solid.SolidBackend._view_children_as_expr {
            ElementChild,
            FragmentTag
        },
        backends.solid.SolidBackend.lower_async_boundary {
            ComponentTag,
            DynamicAttr,
            DynamicChild,
            ElementChild,
            ViewElement
        },
        backends.solid.SolidBackend.lower_view { ComponentTag, FragmentTag, HostTag },
        backends.solid.SolidBackend.view_runtime_symbols {
            EachChild,
            ElementChild,
            IfChild
        },
        jsx_processor.EsJsxProcessor._lift_each {
            EachChild,
            ElementChild,
            ViewElement
        },
        jsx_processor.EsJsxProcessor._lift_if { IfChild },
        jsx_processor.EsJsxProcessor._split_key { DynamicAttr, StaticAttr },
        jsx_processor.EsJsxProcessor._view_arm { ElementChild },
        jsx_processor.EsJsxProcessor.element {
            ComponentTag,
            DynamicChild,
            DynamicTag,
            ElementChild,
            FragmentTag,
            HostTag,
            SlotChild,
            SpreadAttr,
            TextChild,
            ViewElement,
            ViewLocator
        },
        jsx_processor.EsJsxProcessor.normal_attribute {
            DynamicAttr,
            EventAttr,
            RefAttr,
            StaticAttr
        },
    ]
    type view_ir ++> [
        backends.react {
            DynamicAttr,
            EventAttr,
            RefAttr,
            StaticAttr,
            ViewElement,
            ViewLocator
        },
        backends.solid {
            DynamicAttr,
            EachChild,
            EventAttr,
            IfChild,
            RefAttr,
            SpreadAttr,
            StaticAttr,
            ViewChild,
            ViewElement,
            ViewLocator
        },
        framework_backend { ViewElement, ViewLocator },
        jsx_processor {
            DynamicAttr,
            EachChild,
            EventAttr,
            IfChild,
            RefAttr,
            SpreadAttr,
            StaticAttr,
            ViewChild,
            ViewElement
        },
    ]
}

graph import compiler.backends.es.backends {
    preact --> registry.resolve_framework_backend { PreactBackend }
    react ++> preact { ReactBackend }
    react --> registry.resolve_framework_backend { ReactBackend }
    solid --> registry.resolve_framework_backend { SolidBackend }
}

graph import compiler.backends.native {
    abi ++> [
        na_ir_gen_pass { classify_foreign_fn },
        na_ir_gen_pass.NaIRGenPass._build_jc_layout { struct_layouts },
    ]
    foreign ++> [
        abi.classify_foreign_fn | na_ir_gen_pass.NaIRGenPass._clib_struct_layout {
            foreign_struct_layout
        },
        na_ir_gen_pass.NaIRGenPass._foreign_fns { collect_foreign_fns },
        na_ir_gen_pass.NaIRGenPass._foreign_model { collect_foreign_structs },
    ]
    foreign --> na_ir_gen_pass.NaIRGenPass._codegen_call { declared_type_name }
    lexical_scope ++> na_ir_gen_pass { FunctionSource, LexicalScope }
    link_glue ++> [
        link_plan {
            GlueSpec,
            GlueUnit,
            RC_THREADED_SYMBOL,
            REGION_DIED_HOOK,
            SHARED_INIT_SYMBOL,
            SHARED_MAIN_SYMBOL,
            STR_NEW_SYMBOL,
            init_object_codegen,
            link_glue_ir
        },
        link_plan.callback_glue_ir { bind_shared_callbacks },
        link_plan.heap_glue_ir { inject_heap_accounting },
    ]
    link_plan --> na_compile_pass.NativeCompilePass._run_impl {
        SymbolCollision,
        jit_engine_for_module
    }
    llvm.binding as llvm ++> [
        host_facts.struct_layouts_fact
            | link_glue.bind_shared_callbacks
            | link_plan
            | na_compile_pass
            | native_link
            | wasm_build._exported_functions,
        host_facts.target_fact
            | link_glue.init_object_codegen
            | wasm_build._load_libc_module,
        wasm_build.prepare_wasm_module,
    ]
    type llvm.binding ++> [
        link_plan { ExecutionEngine, ModuleRef, TargetMachine },
        na_compile_pass { ModuleRef, TargetMachine },
        wasm_build { ModuleRef, TargetMachine, ValueRef },
    ]
    llvm.binding.value ++> link_plan.internalize_native_implementation { Visibility }
    type llvm.binding.value ++> link_plan { ValueRef }
    llvm.ir as ir ++> abi
        | lexical_scope
        | lowering
        | na_ir_gen_pass
        | primitives_native;
    llvm.ir.types ++> link_glue.bind_shared_callbacks { _wrapname }
    lowering ++> [
        entry_points.validate_native_application | na_compile_pass.unit_fallbacks {
            native_fallbacks_in_ir
        },
        na_ir_gen_pass {
            DEMOTED_SUFFIX,
            NativeLoweringIssue,
            NativeLoweringKind,
            native_fallbacks
        },
    ]
    type lowering ++> na_compile_pass { NativeFallbacks }
    na_compile_pass ++> [
        entry_points.validate_native_application { native_linked_ir_text },
        link_plan {
            NATIVE_CODE_MODEL,
            NATIVE_RELOC_MODEL,
            emit_unit_objects,
            object_emit_jobs,
            unit_function_counts
        },
        wasm_build.prepare_wasm_module { optimize_unit },
    ]
    na_constants ++> [
        abi.struct_layouts { FACT_SEP, FACT_STRUCT_LAYOUTS },
        host_facts {
            FACT_CODEC_NAME,
            FACT_CODEC_TABLES,
            FACT_IMPORT_PATHS,
            FACT_PACKAGE_STORE,
            FACT_PRIMITIVE_METHODS,
            FACT_SEALED_RUNTIME,
            FACT_SEP,
            FACT_STRUCT_LAYOUTS,
            FACT_TARGET
        },
        na_ir_gen_pass {
            ALLOC_ID_MASK,
            CLASS_DISPLAY_OFF,
            CLASS_RECORD_ANCESTRY,
            CLASS_RECORD_STATICS,
            CLASS_RECORD_STATICS_COUNT,
            EXC_LINEAGE_BITS,
            EXC_LINEAGE_MIX,
            EXC_LINEAGE_SLOTS,
            FACT_CODEC_NAME,
            FACT_CODEC_TABLES,
            FACT_PRIMITIVE_METHODS,
            FACT_SEALED_RUNTIME,
            FACT_SEP,
            FACT_TARGET,
            JACVAL_ELLIPSIS_TAG,
            LIVE_NODE_NEXT_OFF,
            LIVE_NODE_RC_OFF,
            LIVE_NODE_SIZE,
            LIVE_NODE_TAG_OFF,
            LIVE_NODE_USER_OFF,
            NATIVE_CONTAINER_CODES,
            NATIVE_COPY_FUNCS,
            NATIVE_OSPATH_FUNCS,
            NATIVE_OS_FUNCS,
            POOL_CLASS_MASK,
            POOL_CLASS_SHIFT,
            RC_BUFFERED_BIT,
            RC_COLOR_BLACK,
            RC_COLOR_GRAY,
            RC_COLOR_PURPLE,
            RC_COLOR_SHIFT,
            RC_COLOR_WHITE,
            RC_CYCLE_PACE,
            RC_CYCLE_THRESHOLD,
            RC_UNTRACED_BIT,
            UNBOUND_CAUGHT,
            VTABLE_SET_BUCKETS,
            VTABLE_SET_SYMBOL,
            stdlib_intercepted
        },
    ]
    type na_ir_gen_pass ++> primitives_native { NaIRGenPass }
    native_link ++> [
        link_plan {
            MACHO_SYSTEM_DYLIB,
            NativeLinkError,
            NativeLinkJob,
            PE_DLL_ENTRY,
            clib_needed_libs,
            clib_symbol_lib_map,
            floor_archives,
            link_native,
            musl_runtime,
            outline_atomics_archive,
            write_symbol_map
        },
        wasm_build { NativeLinkError, WasmLinkJob, link_wasm_module },
    ]
    posix_floor --> link_glue.link_glue_ir { posix_floor_ir }
    posix_floor_ir ++> posix_floor {
        POSIX_FLOOR_IR_LINUX_AARCH64,
        POSIX_FLOOR_IR_LINUX_X86_64,
        POSIX_FLOOR_IR_MACOS_AARCH64,
        POSIX_FLOOR_IR_MACOS_X86_64
    }
    primitives_native ++> na_ir_gen_pass {
        NativeDictEmitter,
        NativeEmitCtx,
        NativeSetEmitter
    }
    primitives_native as _pm_pn ++> na_ir_gen_pass.NaIRGenPass._dispatch_primitive_method;
    primitives_native as _pn ++> [
        na_ir_gen_pass.NaIRGenPass._ensure_emitters,
        na_ir_gen_pass._native_emitter_of,
    ]
    primitives_native as emitters ++> host_facts.primitive_methods_fact;
    region_abi ++> na_ir_gen_pass { REGION_KERNEL_ABI }
    wasm_artifact ++> [
        native_link { wasm_ld_args, write_allowed_imports },
        wasm_build { rename_wasm_imports },
    ]
    wasm_build ++> link_plan.link_wasm { emit_wasm_from_ir }
    wasm_host_abi ++> [
        wasm_artifact { WASM_HOST_MODULE },
        wasm_build._link_wasm_libc { WASM_HOST_ABI },
        wasm_build.emit_wasm_from_ir { WASM_HOST_ABI, WASM_HOST_MODULE },
    ]
    win_floor ++> native_link { win_import_dll, win_import_name }
    win_floor --> [
        link_glue.link_glue_ir { win_floor_ir },
        link_plan.link_artifact { WIN_CRT_DLL },
    ]
    win_floor_ir ++> [
        win_floor.win_floor_ir { WIN_FLOOR_IR },
        win_floor.win_import_dll { WIN_FLOOR_KERNEL32 },
    ]
}

graph import compiler.backends.native.llvm {
    binding ++> [
        binding.config
            | binding.context
            | binding.dylib
            | binding.initfini
            | binding.linker
            | binding.lld
            | binding.module
            | binding.newpassmanagers
            | binding.object_file
            | binding.options
            | binding.targets
            | binding.value { ffi },
        binding.executionengine { ffi, object_file, targets },
    ]
    include binding.config ++> binding;
    include binding.context ++> binding;
    include binding.dylib ++> binding;
    include binding.executionengine ++> binding;
    include binding.initfini ++> binding;
    include binding.linker ++> binding;
    include binding.lld ++> binding;
    include binding.module ++> binding;
    include binding.newpassmanagers ++> binding;
    include binding.object_file ++> binding;
    include binding.options ++> binding;
    include binding.targets ++> binding;
    include binding.value ++> binding;
    include ir.builder ++> ir;
    ir.context ++> ir { Context, global_context }
    include ir.instructions ++> ir;
    include ir.module ++> ir;
    include ir.types ++> ir;
    include ir.values ++> ir;
    shim_path ++> binding.ffi { shim_path }
}

graph import compiler.backends.native.llvm.binding {
    common ++> [
        dylib | options { _encode_string },
        ffi { _is_shutting_down },
        module | targets | value { _decode_string, _encode_string },
    ]
    context ++> module { get_global_context }
    linker ++> module { link_modules }
    value ++> [
        module { ValueRef },
        targets.TargetMachine.emit_object { Linkage },
    ]
    type value ++> targets { ValueRef }
}

graph import compiler.backends.native.llvm.ir {
    _utils as _utils ++> context | module | values;
    context ++> module { Context, global_context }
    type context ++> types { Context }
    instructions --> values.Block.replace { Instruction }
    instructions as instructions ++> builder;
    module ++> instructions { Module }
    type module ++> builder | values { Module }
    types as types ++> builder | context | instructions | module | values;
    values ++> [
        builder | types._format_members { Value },
        instructions {
            ArgumentAttributes,
            AttributeSet,
            Block,
            Constant,
            Function,
            MetaDataArgument,
            MetaDataString,
            NamedValue,
            Value,
            _str_list,
            _value_list
        },
        types.BaseStructType.gep { Constant },
        types.Type.__call__ { Constant },
        types.VectorType.wrap_constant_value { Constant },
        types._wrap_members { Constant, Value },
    ]
    values --> types.ArrayType.wrap_constant_value { Constant, Value }
    values as values ++> builder | module;
    type values ++> types { Constant, Value }
}

graph import compiler.backends.py {
    codegen_ir ++> [
        codegen_shim {
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
        },
        jcir_gen_pass { CodegenIrWriter, int_literal_magnitude },
    ]
    codegen_shim ++> jcir_bc_gen_pass.JcirBytecodeGenPass.transcribe_module {
        compile_ir
    }
    jcir_facts ++> [
        codegen_ir { jcir_python_version },
        jcir_gen_pass {
            JCIR_AMBIENT_TYPING_NAMES,
            JCIR_BUILTIN_NAMES,
            jcir_is_test_path
        },
    ]
}

graph import compiler.driver {
    application ++> [
        build_services.CompilerBuildServices.prepare_application {
            prepare_application
        },
        build_services.CompilerBuildServices.prepare_dynamic_module {
            prepare_dynamic_module
        },
    ]
    application_edges ++> build_services.CompilerBuildServices.application_edges {
        application_edges
    }
    bccache ++> [
        application._stamp { LISTING_SETTLE_NS },
        ifacecache.IfaceRegistry._entry_fresh | jir._related_files {
            discover_annex_files
        },
    ]
    boundary_classify ++> [
        program.JacProgram.declared_codespace { _default_codespace_for },
        program.JacProgram.infers_native_codespace { _default_codespace_for },
        program.JacProgram.stamp_boundary_facts {
            ClientImportVerdict,
            _default_codespace_for,
            classify_client_import_item,
            import_declares_native_target,
            import_item_declaration,
            is_client_boundary_import,
            is_client_native_edge_import
        },
        program.JacProgram.stamp_native_import_facts {
            clib_decl_type_names,
            import_bound_names,
            native_only_import_target,
            python_side_name_refs
        },
    ]
    boundary_classify --> program.JacProgram.parse_source {
        _coerce_client_module,
        _coerce_native_module
    }
    compilation_context ++> [
        application._sections | ifacecache.artifact_cache_path {
            cache_scope,
            program_for
        },
        application._semantic_metadata
            | ifacecache.IfaceRegistry.ensure
            | unit_products.dependency_span_rows { program_for },
        compiler.JacCompiler.get_bytecode
            | ifacecache.IfaceRegistry._compilation_scope
            | session_compile.compile_in_session {
            compilation_scope,
            owner_scope_options
        },
        compiler.JacCompiler.get_client_artifact {
            compilation_scope,
            owner_scope_options
        },
        compiler.JacCompiler.last_client_artifact {
            compilation_scope,
            owner_scope_options
        },
        compiler.JacCompiler.product_program
            | pipeline_runner.compile_application
            | session_compile.select_context { bind_options, context_program },
        jir._module_projection { active_options },
        jir.compute_precompile_module_key | nativecache.NativeUnitRegistry._source_key {
            cache_scope
        },
        source_products.python_text { cache_scope, owner_scope_options, program_for },
    ]
    compilation_context --> [
        application._prepare_revision
            | program.JacProgram.load_dependency_module
            | source_products.python_source { program_for },
        application.prepare_application { bind_options, context_program },
        application.prepare_dynamic_module { program_for },
        jir._memoized { active_options },
    ]
    compile_options ++> [
        application_edges.application_edges
            | compilation_context
            | compiler
            | jir._analysis_fingerprint_for
            | module_analysis
            | module_compile
            | nativecache
            | pipeline_runner
            | program
            | session_compile { CompileOptions },
        nativecache.NativeBuildSession.finish { pop_native_target, push_native_target },
        nativecache.NativeUnitRegistry._miss { env_na_debug },
        nativecache.NativeUnitRegistry._source_key {
            pop_native_target,
            push_native_target
        },
        pass_driver { CancelToken },
        pipeline_runner.native_application {
            CompileOptions,
            pop_native_target,
            push_native_target
        },
        pipeline_runner.wasm_ir_units {
            CompileOptions,
            pop_native_target,
            push_native_target
        },
    ]
    compile_options --> [
        application.prepare_application | ifacecache.IfaceRegistry._verify_iface {
            CompileOptions
        },
        nativecache.NativeBuildSession.lower {
            env_na_debug,
            pop_native_target,
            push_native_target
        },
        nativecache.NativeUnitRegistry.known_digest { env_na_debug },
        nativecache.NativeUnitRegistry.record_module { env_na_debug },
    ]
    type compile_options ++> pipeline | program { CancelToken }
    compiler ++> build_services.CompilerBuildServices.compiler
        | program.JacProgram._get_compiler { JacCompiler }
    compiler --> nativecache.SessionHeap.take { COMPILE_GC_THRESHOLDS }
    type compiler ++> build_services | program { JacCompiler }
    context_passes ++> pipeline {
        AbsorbImportsPass,
        AppContextPass,
        BoundaryFactsPass,
        NativeImportFactsPass
    }
    ifacecache ++> program.JacProgram.iface_registry { IfaceRegistry }
    type ifacecache ++> program { IfaceRegistry }
    jir ++> [
        application._capture_input { ct_dep_digest },
        application._context_sections {
            HEADER_SIZE,
            SECTIONS_MAGIC,
            get_module_cache_path,
            read_jir,
            read_sections
        },
        application._identity { compiler_generation },
        application._prepare_revision { ct_dep_digest },
        application._prepare_sealed {
            HEADER_SIZE,
            PRECOMPILE_SENTINEL,
            SECTIONS_MAGIC,
            patch_co_filenames_bytes,
            read_bytecode_only,
            read_sections
        },
        application._stamp { compute_content_sha256 },
        compiler {
            FLAG_CARRIED,
            FLAG_PRECOMPILED,
            HEADER_SIZE,
            SECTIONS_MAGIC,
            SEC_BYTECODE,
            SEC_CLIENT,
            SEC_CTDEPS,
            SEC_INTEROP,
            SEC_MTIR,
            SEC_NBITCODE,
            SEC_NOBJ,
            SEC_PLACEMENT,
            cache_mode,
            carried_module_bytecode,
            compute_content_sha256,
            ct_deps_section,
            get_module_cache_path,
            is_module_cache_valid,
            patch_co_filenames_bytes,
            precompiled_jir_matches_source,
            read_bytecode_only,
            read_jir,
            read_section_bytes,
            read_sections,
            seed_definition_texts,
            write_module_cache
        },
        compiler.JacCompiler._get_precompiled_jir_bytecode {
            PRECOMPILE_SENTINEL,
            SEC_CTDEPS,
            absolutize_ct_deps_section,
            bundle_dir_allowed,
            cache_mode
        },
        compiler.JacCompiler._persist_module_cache {
            get_module_cache_path,
            is_module_cache_valid
        },
        compiler.unit_sections {
            DepRow,
            JirPaths,
            SEC_DEPS,
            SEC_IFACE,
            SEC_PATH_ROOT,
            deps_section
        },
        ifacecache {
            DepRow,
            JirPaths,
            SEC_CTDEPS,
            SEC_DEPS,
            SEC_DIAG,
            SEC_IFACE,
            SEC_PATH_ROOT,
            SEC_PLACEMENT,
            cache_mode,
            deps_section,
            get_module_cache_path,
            is_compiler_tree_path,
            is_module_cache_valid,
            is_stub_like_path,
            jir_cacheable_source_path,
            module_cache_key,
            module_ct_deps_section,
            read_dep_hashes,
            read_jir,
            read_jir_paths,
            read_section_bytes,
            write_module_cache
        },
        ifacecache.IfaceRegistry._deps_match { read_dep_rows },
        ifacecache.IfaceRegistry._encode_iface { PRECOMPILE_SENTINEL },
        ifacecache.artifact_cache_path { get_module_cache_path },
        nativecache {
            NativeStamp,
            SEC_NBITCODE,
            SEC_NCTDEPS,
            SEC_NIFACE,
            SEC_NOBJ,
            cache_mode,
            ct_dep_text_fresh,
            current_native_stamp,
            get_module_cache_path,
            jir_cacheable_source_path,
            module_cache_invalid_reason,
            module_cache_key,
            module_ct_deps_section,
            native_producer_digest,
            native_section_payload,
            read_jir,
            read_native_dep_hashes,
            read_section_bytes,
            stale_ct_dep_rows,
            write_module_cache
        },
        pipeline_runner.wasm_ir_units { absolutize_ct_deps_section },
        source_products.python_text {
            SEC_PYSRC,
            get_module_cache_path,
            is_module_cache_valid,
            read_jir,
            read_section_bytes,
            write_module_cache
        },
    ]
    jir --> [
        application._prepare { begin_prepare_memo, end_prepare_memo },
        application._prepare_revision { cache_mode },
        compiler.JacCompiler._get_bytecode {
            PRECOMPILE_SENTINEL,
            SEC_CTDEPS as _CARRY_CTDEPS,
            SEC_CTDEPS as _PC_CTDEPS
        },
        compiler.JacCompiler._precompiled_jir_data {
            bundle_dir_allowed,
            cache_mode,
            precompiled_jir_matches_source
        },
        compiler.JacCompiler._restore_sections { JirPaths, SEC_PATH_ROOT },
        ifacecache.IfaceRegistry._deps_match { compute_stub_module_key },
        ifacecache.IfaceRegistry._persist_in_context { SEC_INTEROP },
        ifacecache.IfaceRegistry.client_boundary_facts { SEC_INTEROP, read_dep_rows },
        ifacecache.IfaceRegistry.note_dep { compute_stub_module_key },
        nativecache.NativeUnitRegistry.emit_objects { write_module_cache },
        nativecache.NativeUnitRegistry.known_native_deps { read_dep_rows },
        nativecache.NativeUnitRegistry.object_for { write_module_cache },
        nativecache.NativeUnitRegistry.product_sections {
            SEC_NDEPS,
            absolutize_ct_deps_section,
            native_deps_section
        },
    ]
    module_analysis ++> module_compile {
        ModuleAnalysis,
        PlanStep,
        analyze_module,
        run_plan
    }
    module_compile ++> compiler { compile_module }
    na_coverage ++> pipeline_runner.wasm_ir_units { na_coverage_begin, na_coverage_end }
    native_iface ++> [
        jir.native_deps_section { native_unit_ref },
        jir.parse_native_dep_rows { resolve_native_unit_ref },
        nativecache { NativeIface },
        unit_products.native_products { native_layout_to_dict },
    ]
    nativecache ++> program.JacProgram.native_units { NativeUnitRegistry }
    type nativecache ++> program { NativeUnitRegistry }
    pass_driver ++> [
        application._prepare | session_compile.compile_in_session { compile_progress },
        ifacecache.IfaceRegistry.analysis_profile { diagnostic_policy_for },
        module_compile.report_missing_native_ir { deliver_alerts },
        pipeline.execute_passes { build_diagnostic_policy, run_pass },
        pipeline.run_utility { run_pass },
    ]
    pass_driver --> [
        application.prepare_application { compile_progress },
        program.JacProgram.load_dependency_module { run_pass },
    ]
    pipeline ++> [
        application_edges.application_edges { CompilationProduct, require },
        compiler.JacCompiler.assemble_native
            | module_analysis.ModuleAnalysis.require
            | nativecache.NativeBuildSession._finish { require },
        compiler.JacCompiler.assemble_python { require },
        module_analysis.ModuleAnalysis.ready { product_ready },
        module_compile { product_passes, unavailable },
        source_failures.bootstrap_tier_failure_details { tier_reason },
        toolchain { schedule_loading },
    ]
    pipeline --> [
        application._tree_source { CompilationProduct, require },
        compiler.JacCompiler._format_program
            | ifacecache.IfaceRegistry._ensure_flow_graph { require },
        compiler.JacCompiler.ensure_client_codegen
            | ifacecache.IfaceRegistry._ensure_in_context { require },
        compiler.JacCompiler.jac_file_linter { require },
        ifacecache.IfaceRegistry._prepare { product_facts },
        nativecache.NativeBuildSession.lower { invalidate, require, unavailable },
    ]
    pipeline_runner --> [
        application._prepare_revision { compile_application },
        application.prepare_route_metadata { route_exports },
    ]
    pipeline_types ++> [
        compiler { AnalysisFact, CompilationProduct },
        context_passes { PassContract },
        ifacecache { AnalysisFact },
        module_analysis { AnalysisFact, CompilationProduct, ProductRequest },
        module_compile { CompilationProduct, ProductRequest },
        nativecache.NativeBuildSession._finish
            | source_failures.bootstrap_tier_failure_details { CompilationProduct },
        pipeline {
            AnalysisFact,
            CompilationProduct,
            ImportFallback,
            PassContract,
            ProductRequest,
            ProductTask,
            TaskState
        },
        progstate { AnalysisFact, CompilationProduct, ProductTask },
    ]
    pipeline_types --> [
        ifacecache.IfaceRegistry._ensure_flow_graph
            | nativecache.NativeBuildSession.lower { CompilationProduct },
        ifacecache.IfaceRegistry._ensure_in_context { CompilationProduct },
        ifacecache.IfaceRegistry._prepare { CompilationProduct },
    ]
    program ++> [
        application_edges.application_edges
            | boundary_classify
            | build_services.CompilerBuildServices.program
            | compilation_context.context_program
            | compiler
            | ifacecache.IfaceRegistry._fresh_verify_program
            | jir._definition_texts
            | module_analysis
            | module_compile
            | nativecache.NativeBuildSession.__post_init__
            | pass_driver
            | pipeline_runner
            | selfhost
            | session_compile
            | source_failures
            | unit_products { JacProgram },
        compiler.JacCompiler._prepare_tool_program { JacProgram },
    ]
    type program ++> build_services
        | compilation_context
        | ifacecache
        | nativecache
        | pipeline
        | source_products { JacProgram }
    progstate ++> program {
        AnalysisCaches,
        BuildScratch,
        DepGraph,
        DiagLedger,
        ModuleHub
    }
    selfhost ++> build_services.CompilerBuildServices.selfhost | compiler {
        SelfHostCache
    }
    type selfhost ++> build_services { SelfHostCache }
    session_compile ++> [
        compiler { CompileFrame, SessionContext, SessionHooks },
        compiler.JacCompiler.compile { compile_in_session },
        module_compile { SessionHooks },
    ]
    type session_compile ++> module_analysis { SessionHooks }
    setup_progress ++> compiler { setup_progress }
    source_failures ++> [
        compiler {
            CompilerSourceError,
            bootstrap_tier_failure_details,
            import_error_re_enters,
            module_scoped_failure_details,
            note_compiler_source_failure
        },
        toolchain { fail_loud_on_compiler_source },
    ]
    source_failures --> application._prepare_revision | source_products.python_source {
        bootstrap_tier_failure_details,
        module_scoped_failure_details
    }
    unit_products ++> [
        application._import_edges_of { DEF_DEP_SEP as EDGE_SEP },
        application._tree_source { import_edge_rows },
        compiler {
            UnitProducts,
            client_artifact_from_json,
            client_artifact_json,
            client_artifact_of,
            definition_deps,
            interop_manifest_of,
            interop_record,
            placement_record,
            unit_products
        },
        jir._definition_texts { definition_span_rows },
        jir._texts_of_spans { DEF_DEP_SEP },
        jir.seed_definition_texts { DEF_DEP_SEP },
    ]
    unit_products --> [
        ifacecache.IfaceRegistry._persist_in_context {
            interop_record,
            placement_record
        },
        ifacecache.IfaceRegistry.client_boundary_facts { interop_manifest_of },
    ]
    wiring ++> [
        compiler.JacCompiler.jac_str_formatter {
            canonical_wiring_source,
            is_arch_file
        },
        jir.stored_wiring_digest {
            arch_file_for,
            import_prefix_for,
            is_arch_file,
            wiring_digest_for
        },
        jir.unit_source_digest { wiring_digest_for },
    ]
}

graph import compiler.frontend {
    codeinfo ++> [
        host.HostServices.typeshed_unavailable_reason { jaclang_pkg_root },
        source_layout { real_path },
        unitree.ModulePath.native_bundled_path {
            NATIVE_STDLIB_EXTENSIONS,
            is_bundled_native_module,
            resolve_native_module
        },
    ]
    codeinfo --> [
        unitree.ModulePath.native_variant_path { _native_variant_path },
        unitree.UniNode.gen.getter { CodeGenTarget as _CGT },
    ]
    type codeinfo ++> unitree { CodeGenTarget }
    constant ++> [
        codeinfo {
            NATIVE_ERASED_ANNOTATIONS,
            NATIVE_ERASED_TYPE_MARKERS,
            TYPE_PARAM_CONSTRUCTORS
        },
        helpers.evaluate_version_condition { Tokens as Tok },
        loop_links { ExprCtx, SymbolType },
        module_facts {
            CodeContext,
            NATIVE_ERASED_TYPE_MARKERS,
            TYPE_PARAM_CONSTRUCTORS
        },
        parser.parser { CodeContext, OwnershipKind, ParamKind, Tokens as Tok },
        unitree {
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
        },
        unitree.UniNode.gen_token { TOKEN_MAP },
    ]
    diagnostics ++> [
        diagnostic_utils.resolve_diagnostic_tokens { DIAGNOSTICS, LINT_ALIASES },
        parser.frontend { DIAGNOSTICS },
    ]
    host ++> [
        codeinfo.endpoint_descriptor
            | helpers.evaluate_version_condition
            | parser.frontend.annex_sources
            | unitree.Import.__jac_detected.getter { active_host },
        codeinfo.jaclang_pkg_root { package_root },
        source_layout { PathFacts },
        unitree.ModulePath.resolve_relative_path { active_host },
    ]
    host --> [
        codeinfo.effective_default_codespace
            | parser.frontend.annex_paths
            | unitree.Module.annexable_by.getter { active_host },
        codeinfo.effective_native_target { active_host },
        codeinfo.native_target_arch { active_host },
        codeinfo.resolve_native_module { active_host },
    ]
    relations ++> unitree {
        Absorbs,
        CalleeDecl,
        CalleeSignature,
        CfgCatch,
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
    roles ++> [
        module_facts | parser.parser | unparse { Kid },
        unitree {
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
        },
    ]
    srcloc ++> [
        parser.frontend { Span },
        unitree { CodeLocInfo },
    ]
    unitree ++> [
        const_fold {
            AtomUnit,
            BinaryExpr,
            Bool,
            Float,
            Int,
            MultiString,
            String,
            Token,
            UnaryExpr,
            UniNode
        },
        loop_links {
            Ability,
            Archetype,
            Assignment,
            CtrlStmt,
            DictCompr,
            Enum,
            ForeverStmt,
            InForStmt,
            InnerCompr,
            IterForStmt,
            LambdaExpr,
            ListCompr,
            Name,
            Symbol,
            UniNode,
            UniScopeNode,
            WhileStmt,
            is_frame,
            is_identifier_slot
        },
        module_facts {
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
            Test,
            TupleVal,
            UniNode,
            YieldExpr,
            literal_string_value
        },
        parser.frontend { CommentToken, Expr, Module, Source },
        parser.parser {
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
            GraphImport,
            HasVar,
            IfElseExpr,
            IfStmt,
            ImplDef,
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
            WireTarget,
            WithStmt,
            YieldExpr
        },
    ]
    unitree as uni ++> [
        helpers._extract_version_tuple | unparse,
        helpers._is_type_checking_ref,
        helpers._is_version_info_access,
        helpers.evaluate_version_condition,
    ]
    type unitree ++> [
        codeinfo { CommentToken, Module, UniNode },
        helpers { Expr },
        host { Module },
        relations {
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
        },
        roles {
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
            GraphImport,
            HasVar,
            IfElseExpr,
            ImplDef,
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
            WireItem,
            WireTarget
        },
        srcloc { Source, Token },
    ]
}

graph import compiler.frontend.parser {
    lexer ++> [
        frontend { Lexer },
        parser { tokenize_full },
    ]
    lexer as na_lexer ++> frontend;
    parser ++> frontend { Parser, parse_expression as _parse_expression }
    tokens ++> [
        frontend { CommentData, SrcDiag },
        lexer { CommentData, LexToken, SourceLoc, SrcDiag, TokenKind, lookup_keyword },
        parser {
            CommentData,
            LexToken,
            SourceLoc,
            SrcDiag,
            TokenKind,
            is_builtin_type_kind,
            is_name_usable_kind,
            is_reserved_kind,
            is_special_var_kind
        },
    ]
}

graph import compiler.passes {
    capability_check_pass ++> placement_pass.build_native_legality {
        native_capability_demotion_owner,
        native_capability_violations
    }
    context ++> [
        access_check_pass
            | capability_check_pass
            | decl_impl_match_pass
            | freeze_structure_pass
            | import_wiring_pass
            | layout_pass
            | mtir_gen_pass
            | ownership_check_pass
            | package_boundary_pass
            | pyast_load_pass
            | rc_facts_pass
            | region_infer_pass
            | sem_def_match_pass
            | static_analysis_pass
            | variant_agreement_pass { CompilerPass },
        ast_validation_pass
            | boundary_analysis_pass
            | cfg_build_pass
            | endpoint_effect_pass
            | graph_lowering_pass
            | jsx_intrinsic_guard_pass
            | semantic_analysis_pass
            | sym_tab_build_pass { TreePass },
        execution { Alert, CompileContext, CompilerPass, DiagnosticPolicy },
        placement_pass { Alert, CompilerPass },
        type_checker_pass { CompileContext, TreePass },
    ]
    dataflow ++> [
        ownership_check_pass {
            DataflowTransfer,
            SymId,
            is_scope_exit,
            solve_backward,
            solve_forward,
            solve_forward_must
        },
        rc_facts_pass { SymId, solve_backward_gen_kill },
        type_checker_pass { SymId, is_scope_exit, solve_forward },
    ]
    execution ++> pyast_load_pass.build_python_module { new_context, walk_pass }
    import_wiring_pass ++> static_analysis_pass { report_unused_wires }
    layout_pass ++> osp_analysis.OspAnalysis.native_slot_triggers {
        native_type_key,
        referenced_native_name
    }
    layout_pass --> [
        osp_analysis.OspAnalysis._isa_closure { referenced_native_name },
        osp_analysis.OspAnalysis.arch_key { archetype_native_name },
    ]
    rc_facts_pass ++> [
        ownership_check_pass.OwnershipCheckPass._nogc_infer_state {
            Ownership,
            call_borrows_receiver,
            result_ownership
        },
        ownership_check_pass.OwnershipCheckPass._nogc_local_shape_expr_heap {
            Ownership,
            result_ownership
        },
    ]
    scope_walk ++> static_analysis_pass { ScopeWalker }
    type_checker_pass ++> comptime_resolve_pass | declaration_type_pass {
        TypeCheckPass
    }
    wasm_contract --> [
        boundary_analysis_pass.BoundaryAnalysisPass._register_na_client_import {
            function_contract,
            host_contract_dicts
        },
        boundary_analysis_pass.BoundaryAnalysisPass.enter_func_call { check_host_call },
    ]
}

graph import compiler.placement {
    placement ++> [
        placement_export {
            ElementSummary,
            PLACEMENT_SCHEMA,
            PlacementSummary,
            element_display_name,
            get_module_summary,
            placement_evidence_for
        },
        placement_solver {
            PLACEMENT_HOLD_EXEMPT_ROOTS,
            PlacementSummary,
            get_module_summary,
            native_blocker_scan,
            record_placement_evidence,
            summary_store
        },
        placement_solver._endpoint_veto_applies { project_has_server },
    ]
    placement --> [
        placement_solver._closure_pullable { module_has_root_access },
        placement_solver._pullable_by_client_reference { module_has_root_access },
    ]
    type placement ++> placement_facts { PlacementSummary }
    placement_export ++> placement_facts._record_at { summary_from_bytes }
    placement_facts ++> placement_solver.native_closure_blocker { pinned_module_space }
    placement_pins ++> [
        placement.module_anchor_reasons
            | placement_facts.pinned_module_space
            | placement_solver._module_externally_pinned { config_module_pin },
        placement_facts.session_declares_native {
            config_kind_space,
            effective_pin_for
        },
    ]
    placement_pins --> [
        placement._scan_blockers_under { config_module_pin as _cmp, config_pin_for },
        placement.project_kind_name { config_project_kind },
        placement.summarize_module {
            config_element_pin,
            config_module_pin,
            effective_pin_for
        },
        placement_facts.native_unit { effective_module_pin },
    ]
    placement_solver ++> [
        placement_work.PlacementWork.drain { _pull_boundary_import },
        placement_work.PlacementWork.refs { _ref_top_ids },
    ]
    placement_solver --> placement_facts.native_unit { native_default_path_ok }
    placement_work ++> placement_solver { PlacementWork }
}

graph import compiler.tests {
    xbackend_equiv ++> [
        test_fixed_width_equivalence {
            call_py_fixture,
            compile_fixture_to_js,
            encode_py_wire,
            run_js_expr,
            run_js_function,
            run_py_fixture,
            run_with_both
        },
        test_fn_identity_equivalence | test_osp_equivalence {
            run_py_fixture,
            run_with_both
        },
        test_graph_fragment_equivalence {
            run_js_module_fixture,
            run_py_fixture,
            run_with_both
        },
        test_loop_closure_equivalence {
            compile_fixture_to_js,
            run_js_function,
            run_py_fixture,
            run_with_both
        },
        test_native_list_search_equality { compile_native, get_func },
        test_prim_equivalence {
            compare_results,
            compile_fixture_to_js,
            compile_native,
            compile_native_errors,
            get_func,
            run_js_function,
            run_py_fixture,
            run_with_both
        },
        test_shared_types_equivalence { run_with_both },
        test_socket_equivalence | test_ssl_equivalence | test_urllib_equivalence {
            compile_native,
            get_func,
            run_py_fixture
        },
        test_tarfile_equivalence {
            FIXTURES,
            get_func,
            remember_engine_unit,
            run_py_fixture
        },
        test_xbackend_equiv { run_js_expr, run_js_function },
        test_zstd_equivalence {
            FIXTURES,
            compare_results,
            remember_engine_unit,
            run_native_function,
            run_py_fixture
        },
    ]
    xbackend_equiv --> [
        test_native_functools { compile_native, get_func },
        test_osp_equivalence { compile_native, run_native_function },
    ]
}

graph import compiler.tools {
    cfg_dot ++> lang_tools { cfg_dot_from_file }
    doc_ir as doc ++> doc_ir_gen_pass | jac_formatter_pass;
    jac_formatter_pass ++> lang_tools { unparse_module }
    reactive_use_walk ++> jac_auto_lint_pass { ReactiveUseWalker }
    treeprinter ++> lang_tools {
        print_ast_tree,
        print_symtab_tree,
        printgraph_ast_tree,
        printgraph_symtab_tree
    }
}

graph import compiler.types {
    builtin_extensions ++> type_evaluator { install_builtin_extensions }
    ct_builtins ++> ct_eval {
        CT_BUILTIN_EXCEPTIONS,
        CT_BUILTIN_FUNCS,
        CT_BUILTIN_TYPES,
        ct_call_builtin,
        ct_call_method,
        ct_call_method_value,
        ct_construct_builtin,
        ct_type_attr,
        ct_value_attr
    }
    ct_eval ++> type_evaluator { CtEvaluator }
    ct_format ++> [
        ct_builtins { ct_binary, ct_format, ct_str_format },
        ct_eval { ct_binary, ct_convert, ct_format, ct_inplace },
    ]
    ct_int ++> [
        ct_builtins {
            mag_bit_length,
            mag_divmod,
            mag_gcd,
            mag_isqrt,
            mag_low_bits_nonzero,
            mag_mul,
            mag_shl,
            mag_shr,
            mag_to_int
        },
        ct_ops {
            MAG_SHIFT,
            MAX_STR_DIGITS,
            mag_add,
            mag_add_small,
            mag_bit_length,
            mag_cmp,
            mag_divmod,
            mag_from_int,
            mag_low_bits_nonzero,
            mag_mul,
            mag_parse_digits,
            mag_shl,
            mag_shr,
            mag_sub,
            mag_to_int,
            mag_to_pow2_str,
            twos_limbs,
            twos_to_signed
        },
        ct_value {
            MAG_SHIFT,
            MAX_STR_DIGITS,
            mag_add_small,
            mag_bit_length,
            mag_cmp,
            mag_decimal_digits,
            mag_from_int,
            mag_shl,
            mag_to_int
        },
    ]
    ct_ops ++> [
        ct_builtins {
            ct_binop,
            ct_hash,
            ct_int_parse,
            ct_lt,
            ct_order,
            float_divmod,
            float_round_to_int,
            int_abs,
            int_add,
            int_bit_length,
            int_divmod,
            int_is_neg,
            int_is_zero,
            int_mul,
            int_prefixed,
            int_round,
            int_sub,
            int_to_float,
            set_algebra,
            slice_indices
        },
        ct_eval {
            ct_compare,
            ct_getitem,
            ct_getslice,
            ct_int_literal,
            ct_setitem,
            ct_symbol,
            ct_unary,
            int_add,
            int_cmp
        },
        ct_format {
            ct_binop,
            ct_getitem,
            int_is_neg,
            int_to_base_str,
            int_to_float,
            set_algebra
        },
    ]
    ct_value ++> [
        ct_builtins {
            CT_FALSE,
            CT_NONE,
            CT_TRUE,
            CtBool,
            CtBuiltin,
            CtBytes,
            CtCaller,
            CtDict,
            CtError,
            CtExc,
            CtFloat,
            CtInt,
            CtList,
            CtMethod,
            CtModule,
            CtNone,
            CtRange,
            CtSet,
            CtStr,
            CtTuple,
            CtValue,
            CtView,
            as_ct_int,
            ct_exc,
            ct_exc_value,
            ct_iter,
            ct_len,
            ct_repr,
            ct_same_or_eq,
            ct_str,
            ct_truthy,
            ct_type_name,
            dict_copy,
            dict_delete,
            dict_get,
            dict_set,
            float_ceil,
            float_floor,
            float_to_ct_int,
            int_cmp,
            int_sign_mag,
            mk_bool,
            mk_bytes,
            mk_dict,
            mk_float,
            mk_int,
            mk_int_mag,
            mk_list,
            mk_set,
            mk_str,
            mk_tuple,
            set_add,
            set_discard,
            set_has
        },
        ct_eval {
            CT_DEFERRED,
            CT_NONE,
            CtBool,
            CtBound,
            CtBuiltin,
            CtBytes,
            CtCaller,
            CtDeferred,
            CtDeferredSignal,
            CtDict,
            CtEnumMember,
            CtEnvironment,
            CtError,
            CtExc,
            CtFloat,
            CtFunc,
            CtInt,
            CtList,
            CtMethod,
            CtModule,
            CtNone,
            CtNotComptime,
            CtRaise,
            CtRange,
            CtRecord,
            CtSet,
            CtStr,
            CtTuple,
            CtType,
            CtValue,
            as_ct_int,
            ct_eq,
            ct_exc,
            ct_exc_is,
            ct_iter,
            ct_repr,
            ct_str,
            ct_truthy,
            ct_type_name,
            dict_set,
            mk_bool,
            mk_bytes,
            mk_dict,
            mk_float,
            mk_int,
            mk_list,
            mk_set,
            mk_str,
            mk_tuple,
            range_len
        },
        ct_format {
            CtBool,
            CtDict,
            CtEnumMember,
            CtError,
            CtFloat,
            CtInt,
            CtList,
            CtRecord,
            CtSet,
            CtStr,
            CtTuple,
            CtValue,
            as_ct_int,
            ascii_escape,
            ct_exc,
            ct_exc_value,
            ct_iter,
            ct_repr,
            ct_str,
            ct_type_name,
            dict_set,
            float_to_ct_int,
            mk_str
        },
        ct_ops {
            CtBool,
            CtBytes,
            CtDeferred,
            CtDeferredSignal,
            CtDict,
            CtEnumMember,
            CtError,
            CtFloat,
            CtFunc,
            CtInt,
            CtList,
            CtNone,
            CtRaise,
            CtRange,
            CtSet,
            CtStr,
            CtTuple,
            CtType,
            CtValue,
            CtView,
            as_ct_int,
            bytes_has,
            ct_eq,
            ct_exc,
            ct_exc_value,
            ct_is_unhashable,
            ct_iter,
            ct_len,
            ct_same_or_eq,
            ct_truthy,
            ct_type_name,
            dict_copy,
            dict_get,
            dict_key_of,
            dict_set,
            float_floor,
            float_to_ct_int,
            int_cmp,
            int_decimal,
            int_float_cmp,
            int_sign_mag,
            mk_bool,
            mk_bytes,
            mk_float,
            mk_int,
            mk_int_mag,
            mk_list,
            mk_set,
            mk_str,
            mk_tuple,
            set_add,
            set_has,
            set_key_of,
            view_items_set
        },
        type_evaluator { CtValue },
    ]
    type ct_value ++> types { CtValue }
    enum_utils ++> type_evaluator {
        build_enum_members,
        get_special_enum_value_type_from_bases
    }
    fixed_width ++> [
        operations {
            arithmetic_result_type,
            both_numeric,
            numeric_name_of,
            shift_result_type,
            unify_numeric_operands
        },
        type_evaluator {
            AssignVerdict,
            arithmetic_result_type,
            assign_numeric_expr,
            both_numeric,
            fixed_width_call_type,
            is_unsigned_type,
            unify_numeric_operands
        },
        type_evaluator.TypeEvaluator._extern_field_type { numeric_name_of },
        type_evaluator.TypeEvaluator._literal_type_from_expr { folded_number },
    ]
    fixed_width --> type_evaluator.TypeEvaluator._get_type_from_flow_node {
        numeric_name_of
    }
    operations ++> type_evaluator {
        BINARY_OPERATOR_MAP,
        get_type_of_binary_operation,
        is_annotation_type
    }
    properties ++> type_evaluator {
        is_cached_property_decorator_type,
        is_property_decorator_type
    }
    stubcat.format ++> [
        type_evaluator.TypeEvaluator._is_instance_method_member {
            SYMF_INSTANCE_METHOD
        },
        type_evaluator.TypeEvaluator._merge_catalog_field_params {
            SYMF_DEFER,
            SYMF_HAS_DEFAULT
        },
    ]
    stubcat.reader ++> [
        ct_eval { CatModule },
        type_evaluator.TypeEvaluator._build_field_params
            | types.ClassType.get_class_symbol { CatScope },
        type_evaluator.TypeEvaluator._is_instance_method_member { CatProvider },
        type_evaluator.TypeEvaluator._merge_catalog_field_params { CatProvider },
        type_evaluator.TypeEvaluator._metaclass_of | types._class_scope_category {
            CatScope
        },
        type_evaluator.TypeEvaluator._scope_has_fields { CatScope },
    ]
    type stubcat.reader ++> type_evaluator { CatScope, StubCatalog }
    ts_decl_parser ++> [
        type_evaluator {
            TsAccess,
            TsDecl,
            TsDeclKind,
            TsMember,
            TsType,
            TsTypeKind,
            ts_decl_binding_kind
        },
        type_evaluator.TypeEvaluator._load_ts_declarations { parse_dts },
    ]
    type type_evaluator ++> [
        ct_eval | fixed_width | operations | stubcat.writer | type_utils {
            TypeEvaluator
        },
        enum_utils { PrefetchedTypes, TypeEvaluator },
    ]
    type_utils ++> [
        ct_eval { lookup_symtab },
        ownership | types.FunctionType.specialize {
            apply_solved_type_vars,
            build_type_var_solution
        },
        stubcat.writer { origin_of_local_name },
        type_evaluator {
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
            lookup_symtab,
            shadowed_type_var_names,
            specialize_for_base_class,
            synthesize_self_type_var
        },
        type_evaluator.TypeEvaluator._apply_function_decorators
            | types.FunctionType.specialize_func_type_vars { apply_solved_type_vars },
        type_evaluator.TypeEvaluator._classify_property_symbol { PropertyWriteKind },
        type_evaluator.TypeEvaluator._heal_ancestry { ensure_mro_fresh },
        type_evaluator.TypeEvaluator._heal_class_bases { linearize_mro, mro_signature },
        type_evaluator.TypeEvaluator._lookup_class_member { ensure_mro_fresh },
        type_evaluator.TypeEvaluator._super_owner_for { collect_member_syms },
        type_evaluator.TypeEvaluator._type_in_list { types_equivalent },
        type_evaluator.TypeEvaluator.get_getter_type_from_property {
            PropertyWriteKind
        },
        type_evaluator.TypeEvaluator.get_property_write_type {
            PropertyWriteKind,
            PropertyWriteResult
        },
        type_evaluator.TypeEvaluator.is_sub_class { ensure_mro_fresh },
        types.ClassType.lookup_member_symbol { collect_member_syms, ensure_mro_fresh },
    ]
    type_utils --> [
        type_evaluator.TypeEvaluator._get_getattr_return_type { collect_member_syms },
        type_evaluator.TypeEvaluator._get_type_of_expression_core {
            PropertyWriteKind,
            synthesize_self_type_var
        },
    ]
    types ++> [
        builtin_extensions {
            ClassType,
            FunctionType,
            FunctionTypeFlags,
            Parameter,
            ParameterCategory,
            TypeBase
        },
        ct_eval { ClassType, ModuleType, TypeBase },
        enum_utils { ClassType, EnumMemberInfo, TypeBase },
        fixed_width { AnyType, ClassType, TypeBase, UnionType, UnknownType },
        operations {
            AnyType,
            ClassType,
            FunctionType,
            ModuleType,
            NeverType,
            OverloadedType,
            TypeBase,
            TypeVarType,
            UnionType,
            UnknownType
        },
        ownership { ClassType, TypeBase, UnionType },
        properties { ClassType, TypeBase },
        stubcat.reader {
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
            Parameter,
            ParameterCategory,
            TypeBase,
            TypeFlags,
            TypeVarType,
            UnionType,
            UnknownType
        },
        stubcat.writer {
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
        },
        type_evaluator {
            AnyType,
            ClassDetailsPrivate,
            ClassDetailsShared,
            ClassType,
            EnumMemberType,
            FunctionType,
            FunctionTypeFlags,
            ModuleType,
            NeverType,
            OverloadedType,
            Parameter,
            ParameterCategory,
            TypeBase,
            TypeCategory,
            TypeFlags,
            TypeVarType,
            UnionType,
            UnknownType,
            create_callable_type
        },
        type_evaluator.TypeEvaluator._extern_field_type { create_callable_type },
        type_utils {
            AnyType,
            CLASS_GRAPH_EPOCH,
            ClassType,
            EnumMemberType,
            FunctionType,
            NeverType,
            Parameter,
            TypeBase,
            TypeVarType,
            UnionType,
            UnknownType
        },
    ]
    type types ++> [
        ct_value { ClassType, TypeBase },
        stubcat.resolver { ClassDetailsShared },
    ]
}

graph import compiler.types.stubcat {
    build ++> locate.StubcatArtifact.build { build_catalog }
    format ++> [
        locate { FORMAT_VERSION },
        modiface { IFACE_HASH_LEN },
        reader {
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
            SH_EXTERN,
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
            u32_at,
            unpack_header
        },
        writer {
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
            SH_EXTERN,
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
            put_u32,
            put_uvar
        },
    ]
    locate ++> build {
        catalog_key,
        jac_internal_stub_dir,
        jaclang_pkg_dir,
        typeshed_stdlib_dir
    }
    locate --> build._cached_catalog { dev_catalog_path }
    reader ++> [
        build,
        locate._open_file { open_catalog_file },
        locate._open_region { open_catalog_region },
        modiface { StubCatalog },
        writer.CatalogWriter.encode_scope { CatScope },
        writer.CatalogWriter.encode_symbol { CatProvider },
        writer.CatalogWriter.force_symbol { CatScope },
        writer.CatalogWriter.scope_dotted_path { CatScope },
        writer.metaclass_of_scope { CatScope },
    ]
    type reader ++> locate { StubCatalog }
    resolver ++> modiface | reader { CatalogResolver }
    writer ++> build { CatalogWriter }
}

graph import data {
    dbcatalog ++> [
        pgembed { DbKind },
        pgembed.PgRuntime._ensure_database {
            connect_admin,
            record_database,
            start_heartbeat
        },
        pgembed.PgRuntime._reap {
            condemn_abandoned,
            drop_if_still_dead,
            orphan_grace_seconds,
            pardon_recovered,
            reclaimable_databases
        },
        pgembed.PgRuntime._reap_scratch { SCRATCH_PREFIX, list_databases },
        pgembed.PgRuntime._sweep_on_start {
            connect_admin,
            drop_database,
            expired_databases,
            list_databases
        },
        pgembed.PgRuntime._warn_superseded { list_databases },
        pgembed.PgRuntime.databases { connect_admin, list_databases },
        pgembed.PgRuntime.drop_database {
            connect_admin,
            drop_database as catalog_drop
        },
    ]
    type dbcatalog ++> pgembed { DbRecord }
    pg_dist --> pgembed.PgRuntime._resolve_binaries { postgres_bin_dir }
    pgembed ++> store.PgStore._warn_lock_headroom { predicate_lock_shortfall }
    pgload ++> [
        dbcatalog.connect_admin | pgembed.PgRuntime._wait_ready { connect },
        dbcatalog.holds_no_data { connect },
        store.PgStore._connect { connect as pg_connect },
    ]
    pgpool ++> [
        store.PgStore._connect { checkout },
        store._park_conn { pool_enabled, release },
    ]
    pgwire ++> store { PgWireError }
    pgwire --> store.PgStore._run { PgWireError }
    schema_rules ++> [
        serializer.Serializer._deserialize_archetype {
            ATTIC_KEY,
            REPAIRS_ATTR,
            repair_mode
        },
        serializer.Serializer.register { collect_rules },
        serializer.Serializer.repair { apply_rules, merged_rules_for, repair_mode },
    ]
    schema_rules --> [
        serializer.Serializer._serialize_attrs { merged_rules_for, repair_mode },
        serializer.Serializer.serialize_fields { merged_rules_for, repair_mode },
    ]
    sqlcompile ++> query_planner { CompiledQuery, compile_query }
    storage.local_storage ++> storage { LocalStorage }
    storage.storage ++> storage { Storage }
    store ++> [
        dbcatalog { ConnInfo, SCHEMA_STAMP_KEY },
        pgembed { ConnInfo },
        sqlcompile { Store },
    ]
    type_identity ++> [
        query_planner._trusted_names { storage_type },
        query_planner.resolve_query_type_counts { storage_type },
        serializer {
            TypeResolutionError,
            UnavailableType,
            class_facts,
            register_type,
            resolution_required,
            resolve_type,
            storage_type,
            type_module
        },
        serializer.Serializer.fingerprint { schema_type },
    ]
    type_identity --> sqlcompile.compile_query { storage_type }
}

graph import data.storage {
    storage ++> local_storage { Storage }
}

graph import dist {
    archive ++> seal.build_jab { tar_gz_dir }
    fused_binary ++> [
        payload.assemble { LINKED_SOURCE_FILE },
        self_update.update_self {
            linked_source_dir,
            materialized_runtime_dir,
            running_executable,
            runtime_trailer
        },
    ]
    jab ++> seal.build_jab { jab_app_meta }
    jab_vendor ++> [
        jab { activate_vendored },
        seal.vendor_jab_deps { download_wheels, wheels_dir, write_vendor_manifest },
    ]
    native_product --> [
        publish.runtime_vendor._compile_runtime_module
            | source.project._write_application { write_native_product },
        source.project.export_project { write_native_product },
    ]
    payload.cli ++> payload { main }
    precompile_bytecode ++> [
        precompiled.PrecompiledArtifact.build { run_precompile },
        precompiled.bundle_misses { sealable_sources },
        seal.resolve_entry_file { bundle_app },
    ]
    publish ++> publish.builder._backend_source { wheel_archive }
    publish.builder ++> publish { WheelBuilder }
    publish.metadata ++> publish { generate_metadata, normalize_package_name }
    publish.runtime_vendor ++> source.project.export_project { vendor_runtime }
    publish.sources ++> source.project._copy_resources {
        EXCLUDED_DIRS,
        EXCLUDED_SUFFIXES
    }
    publish.wheel_meta ++> publish { wheel_filename }
    sanitize ++> seal.make_sealed_image { sanitize_shipped_tree }
}

graph import dist.payload {
    assemble ++> cli { MkPayloadOpts, mk_payload }
    assemble --> cli.dispatch { resolve_python, run_stubcat }
    fetch ++> [
        assemble { TYPESHED_VENDOR },
        cli { fetch_bun, fetch_llvm, fetch_typeshed, typeshed_sha },
    ]
    fsutil ++> [
        assemble {
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
        },
        cli { PayloadDie, die },
        fetch {
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
        },
        pack { die, read_bytes, sha256_hex, strip_best_effort },
        pins { die },
        vendor {
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
        },
    ]
    pack ++> cli { pack }
    pins ++> [
        assemble { py_ver },
        cli { host_py_minor, py_ver },
        fetch { LlvmSlice, llvm_release, pins },
    ]
    vendor ++> [
        assemble { MUSL_ARTIFACTS },
        cli { build_musl, build_wasm_libc },
    ]
}

graph import dist.publish {
    dts ++> npm_sources { dts_for_module }
    jsdoc ++> [
        dts { jac_type_to_ts },
        npm_sources { inject_jsdoc, jsdoc_for_module },
    ]
    metadata ++> [
        builder { generate_metadata, generate_pyproject_toml },
        package_json | wheel_meta { normalize_package_name },
    ]
    npm_sources ++> npm_builder {
        collect_npm_sources,
        resolve_npm_entry,
        runtime_pkg_name
    }
    npm_tarball ++> npm_builder | runtime_npm { pack_tarball }
    package_json ++> npm_builder { generate_package_json, npm_tarball_filename }
    py_imports ++> builder { rewrite_imports, wheel_module_name }
    record ++> builder { RecordEntry, generate_record, record_entry_from_bytes }
    runtime_npm ++> npm_sources { runtime_api_names }
    runtime_vendor ++> builder { build_runtime_closure, scan_jaclang_imports }
    sources ++> [
        builder { collect_source_files, read_source_file },
        npm_sources { EXCLUDED_DIRS },
    ]
    wheel_archive ++> [
        builder { BUILD_DATA_FILE, wheel_bytes },
        record { record_hash, record_text },
    ]
    wheel_meta ++> builder {
        dist_info_dirname,
        generate_entry_points,
        generate_wheel_file,
        sdist_filename,
        wheel_filename
    }
}

graph import dist.source {
    client --> project._write_application { write_client }
}

graph import jac0core {
    handoff ++> [
        artifact_registry._marks { handoff },
        artifact_registry._record { update_handoff },
    ]
}

graph import lsp {
    protocol.server ++> server.engine { LanguageServer }
    protocol.types as lspt ++> server.engine
        | server.sem_manager
        | server.server
        | server.utils;
}

graph import lsp.protocol {
    types ++> server {
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
        WINDOW_SHOW_MESSAGE
    }
}

graph import lsp.server {
    engine ++> server { JacLangServer }
    module_manager ++> engine { ModuleManager }
    rwlock ++> engine { ReadWriteLock }
    sem_manager ++> engine | module_manager { SemTokManager }
    utils ++> engine { doc_of_sym, get_completion_items }
}

graph import packages {
    api ++> [
        artifact.build_package { package_surface },
        artifact.package_manifest { surface_digest },
        verify._verify_library { API_FORMAT, package_surface, surface_digest },
    ]
    apidiff ++> [
        publish { ApiChange, check_bump, diff_surfaces, minimum_next },
        verify { check_bump, diff_surfaces },
    ]
    artifact ++> [
        commands._dep_from_source { read_identity },
        publish {
            API_FILE,
            ArtifactError,
            BuiltPackage,
            MANIFEST_DIR,
            ROLE_LIB,
            ROLE_TEMPLATE,
            build_package,
            package_identity,
            project_role
        },
        sources { pack_source_tree },
        store { ArtifactError, expect_identity },
        templates { MANIFEST_DIR, ROLE_TEMPLATE, read_package_manifest },
        verify { API_FILE, MANIFEST_DIR, read_package_manifest },
    ]
    github ++> [
        index._github_tree { find_token },
        publish.open_index_pull { GitHub },
    ]
    index ++> [
        install { RegistryError, registry_named },
        install._registry_for_source { Registry, registry_urls },
        publish {
            IndexEntry,
            Registry,
            RegistryError,
            api_rel_path,
            index_rel_path,
            registry_named
        },
        resolve { IndexEntry, Registry, RegistryError, registry_named, registry_urls },
        templates { IndexEntry, RegistryError, registry_named },
        verify {
            API_DIR,
            IndexEntry,
            Registry,
            RegistryError,
            api_rel_path,
            fetch_verified,
            parse_index_lines
        },
    ]
    install ++> [
        commands {
            InstallError,
            SyncResult,
            describe_sync,
            has_packages,
            load_lock,
            project_dir,
            sync,
            write_lock
        },
        provider {
            InstallError,
            load_lock,
            package_npm_requirements,
            package_pip_requirements
        },
        verify._verify_library { InstallError, sync },
    ]
    lock ++> [
        commands { Lockfile, digest_of },
        install { LockError, LockedPackage, Lockfile },
        resolve { LockedPackage, Lockfile, digest_of },
    ]
    mounts ++> install { link_mounts }
    pubgrub ++> resolve { PackageSource, SolveFailure, solve }
    publish ++> verify { previous_release, previous_surface }
    resolve ++> [
        artifact.package_manifest { manifest_npm, manifest_pypi },
        commands { manifest_inputs },
        install { ResolveError, manifest_inputs, resolve_graph },
        templates { running_jac_version },
    ]
    semver ++> [
        apidiff { Version },
        commands { SemverError, Version, caret_for },
        pubgrub { Requirement, Version, VersionSet },
        publish | verify { SemverError, Version },
        resolve | templates { Requirement, SemverError, Version },
    ]
    semver --> commands.add_packages { Requirement }
    sources ++> [
        commands._dep_from_source { checkout, resolve_path },
        install { GitError, checkout, pack_checkout },
        resolve { GitError, checkout, pack_checkout, resolve_path },
    ]
    store ++> install { StoreError, cached, materialize }
}

graph import project {
    app_kinds ++> [
        apps.AppConfig.entry_path | template_loader.migrate_implicit_app { kind_entry },
        apps.AppConfig.ui { kind_ui },
        apps.parse_apps { KIND_SPECS },
        config.JacConfig.serving_apps | template_registry._core_template { kind_spec },
        kinds { KIND_SPECS, KindSpec, VALID_KINDS },
        template_loader.scaffold_app { kind_entry },
        workspace { kind_codespace, kind_entry, kind_has_server, kind_ui },
    ]
    apps ++> [
        config { AppConfig, implicit_app, parse_apps },
        kinds { AppConfig, implicit_app },
        template_loader.scaffold_app { APP_TABLE_KEYS, parse_apps, validate_app_name },
    ]
    apps --> [
        config._parse_toml_data { validate_entry_point },
        template_loader.load_template_from_directory { parse_apps },
        workspace._build_workspace { parse_apps, resolve_entry_path },
    ]
    type apps ++> client_paths { AppConfig }
    capabilities ++> providers.capability_dependencies {
        DEPLOY,
        RUNTIME,
        byllm_intent_capabilities,
        command_capabilities,
        derive_capabilities,
        get_capability_registry,
        resolve_closure,
        scale_intent_from_config
    }
    config ++> [
        capabilities | kinds | providers | pyvenv | template_loader { JacConfig },
        compiler_host.ProjectHost.lint_settings {
            JacConfig,
            get_config_for_path,
            get_explicit_config
        },
        package_scope.declared_package_name { get_config_for_dir },
        package_scope.package_exports { get_config_for_dir },
        plugin_config { JacConfig, find_project_root, get_config_for_path },
        pyvenv.add_venv_to_path { get_config },
        pyvenv.is_venv_in_path { get_config },
        pyvenv.remove_venv_from_path { get_config },
        template_loader._append_overlay_tables { _toml_append_section },
        template_loader.migrate_implicit_app {
            _toml_append_section,
            _toml_delete_key,
            _toml_insert_key,
            toml_value
        },
        template_loader.scaffold_app { _toml_append_section },
        tool_paths { JacConfig, get_config },
    ]
    config --> [
        client_paths.client_seo_config { ServeConfigError, apply_table },
        compiler_host.ProjectHost.check_settings | modresolver._get_path_aliases {
            get_config
        },
        compiler_host.ProjectHost.declared_dependencies { get_config_for_path },
        compiler_host.ProjectHost.project_defaults { JacConfig, get_config },
        compiler_host.ProjectHost.project_facts { get_config_for_path },
        modresolver._resolve_path_alias { get_config },
    ]
    type config ++> client_paths { JacConfig }
    config_schema ++> [
        config._walk_table { closest_key },
        plugin_config.PluginConfigBase._validate_layer {
            report_schema_findings,
            validate_against_schema
        },
    ]
    dependencies ++> [
        config { PackageDep },
        config.JacConfig.merge_dependency_tables { split_dependency_table },
    ]
    kinds ++> [
        config.JacConfig.resolved_kind { resolve_app_kind, resolve_entry },
        providers.capability_dependencies { plan_app_run },
        template_loader.scaffold_app | template_registry.TemplateRegistry.list_kinds {
            KIND_SPECS
        },
    ]
    modresolver ++> [
        apps.resolve_entry_path | compiler_host.ProjectHost.resolve_local_module {
            resolve_local_module
        },
        compiler_host.ProjectHost.has_npm_package { has_client_npm_package },
        compiler_host.ProjectHost.in_typeshed_tree { in_typeshed_tree },
        compiler_host.ProjectHost.is_path_alias { is_path_alias_import },
        compiler_host.ProjectHost.is_untyped_third_party {
            is_untyped_third_party_module
        },
        compiler_host.ProjectHost.jac_virtual_module_path {
            resolve_jac_virtual_module_path
        },
        compiler_host.ProjectHost.npm_declarations { resolve_client_npm_declarations },
        compiler_host.ProjectHost.project_facts { project_mounts_dir },
        compiler_host.ProjectHost.project_root
            | package_scope.package_root_of
            | workspace { find_jac_project_root },
        compiler_host.ProjectHost.resolve_module { resolve_module },
        compiler_host.ProjectHost.resolve_npm_package { resolve_client_npm_package },
        compiler_host.ProjectHost.sibling_declaration { sibling_declaration_file },
        compiler_host.package_name_of { is_scoped_package_name },
        config.find_project_root { find_project_root as _find_project_root },
        package_scope { MOUNTS_DIR_NAME, is_scoped_package_name },
        workspace._chain_stamp { project_root_chain },
    ]
    package_scope ++> dependencies { is_package_name }
    persistence ++> [
        config { PersistenceConfig },
        config._parse_toml_data { parse_persistence },
    ]
    placement ++> kinds.resolve_app_kind { match_pin, validate_pins }
    pyvenv ++> [
        capabilities.ensure_global_capability
            | providers.PythonProvider._install_global {
            pip_command,
            pip_env,
            pip_python
        },
        providers {
            ensure_venv,
            make_git_spec,
            make_pip_spec,
            run_pip,
            summarize_pip_failure
        },
        tool_paths { get_venv_site_packages },
    ]
    source ++> textio { JACIGNORE_FILENAME, normalize_exclude_patterns }
    template_registry ++> template_loader { ProjectTemplate, template_kind_for }
    textio ++> [
        compiler_host.ProjectHost.read_source | template_loader.scaffold_app | tomlio {
            read_file_with_encoding
        },
        compiler_host._git_ignored_under { drop_git_ignored },
    ]
    textio --> config.JacConfig.save { read_file_with_encoding }
    tomlio ++> [
        config.JacConfig.load | template_loader { read_toml_with_encoding },
        config.JacConfig.merge_from_toml_file { read_toml_with_encoding },
    ]
    tomlio --> config.JacConfig.save { MalformedJacTomlError }
    workspace ++> [
        compiler_host.ProjectHost.app_for_path { app_for_path },
        compiler_host.ProjectHost.session { workspace_scope },
        kinds.resolve_app_kind { workspace_for_path },
        persistence { persistence_namespace },
    ]
    workspace --> compiler_host.ProjectHost.workspace { workspace_for_path }
    workspace_model ++> workspace { AppSpec, WorkspaceSpec }
    type workspace_model ++> compiler_host { AppSpec, WorkspaceSpec }
}

graph import runtime {
    archetype ++> [
        constructs {
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
        },
        context { NodeAnchor, PermissionDenied, Root },
        graph_query { Anchor, anchor_key },
        graph_utils { Anchor, Archetype },
        graph_utils._graph_edge { EdgeAnchor, GenericEdge },
        graph_utils._graph_label { Root },
        graph_utils.graph_neighbors_view { Root },
        graph_utils.graph_node_view { Root },
        graph_utils.traverse_graph { EdgeAnchor },
        graph_walk {
            Anchor,
            EdgeAnchor,
            NodeAnchor,
            _as_refs,
            anchor_key,
            light_edge_view,
            same_anchor
        },
        graph_walk.acl_read_ok { AccessLevel },
        memory { Anchor, Root },
        osp_graph_sv { Anchor, EdgeAnchor, NodeAnchor, anchor_key, same_anchor },
        osp_kernel_sv {
            EdgeAnchor,
            NodeAnchor,
            ObjectSpatialFunction,
            WalkerArchetype
        },
        runtime {
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
            new_connect_edge,
            same_anchor
        },
        runtime.JacLLM.by_operator { EdgeArchetype, NodeArchetype },
    ]
    build_services ++> [
        runtime.JacServe.get_client_bundle_builder { build_services },
        runtime.JacTest.run_test { build_services },
    ]
    build_services --> [
        prepared_loader.PreparedFinder.find_spec | runtime.JacRuntime.get_compiler {
            build_services
        },
        runtime.JacRuntime.get_program { build_services },
        runtime.JacRuntime.get_selfhost { build_services },
    ]
    builtin --> archetype.Archetype.__init_subclass__ { _jac_region_instrument }
    cinterop ++> interop_bridge.callback_ctype { shape_ctype }
    cinterop as _cinterop_mod --> builtin.__getattr__;
    constants ++> [
        context { Constants as Con },
        runtime { EdgeDir, colors },
    ]
    constructs ++> [
        builtin._get_access_level { AccessLevel },
        runtime {
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
        },
    ]
    type constructs ++> [
        builtin { AccessLevel, NodeArchetype },
        graph_utils { EdgeArchetype, NodeArchetype },
    ]
    context --> runtime.JacContext.create_j_context { ExecutionContext }
    type context ++> runtime { ExecutionContext }
    exceptions ++> context { MissingAnchorError }
    graph_query ++> [
        graph_utils.graph_neighbors_view { GraphQuery, QHop },
        graph_utils.graph_node_view { GraphQuery, QHop },
        graph_walk { GraphQuery, QHop, QPred },
        runtime { GraphQuery, QHop, QPred, filter_query_nodes },
    ]
    graph_utils ++> runtime.JacBuiltin.printgraph { traverse_graph }
    graph_walk --> runtime.JacGraph.refs {
        access_gated,
        has_persistent_origin,
        needs_store,
        origin_anchors,
        walk_edges,
        walk_nodes
    }
    interop_bridge --> [
        prepared.execute_module { NativeLibrary },
        source_app._load_application { NativeLibrary, native_callback_of },
    ]
    memory ++> context { Memory }
    object_interop ++> typecache { fields, is_record }
    object_model ++> [
        archetype { ObjectField, asdict, fields, is_jac_object, make_object },
        context { MISSING },
        object_interop { MISSING, ObjectField, fields as jac_fields, is_jac_object },
        object_pydantic { MISSING, fields },
        runtime { make_object },
    ]
    object_pydantic ++> object_model._pydantic_schema { object_schema }
    osp_graph as _graph ++> osp_graph_sv;
    osp_graph_sv ++> [
        graph_utils.traverse_graph { sv_register_hydrated },
        osp_kernel_sv { cls_of_tag, tag_of_cls },
        runtime.JacAccessValidation._groups_of { sv_live_edges, sv_register_hydrated },
        runtime.JacGraph.disconnect {
            sv_candidate_edges_between,
            sv_register_hydrated
        },
        runtime.JacGraph.heavy_edge { sv_conn },
    ]
    osp_graph_sv --> [
        archetype.EdgeAnchor.detach { sv_forget_edge },
        runtime.JacContext.reset_graph { sv_forget_by_id },
    ]
    osp_kernel ++> [
        osp_kernel_sv {
            OspNodeDesc,
            OspRuntime,
            OspSlot,
            OspWalkScope,
            OspWalkerDesc,
            UNTYPED
        },
        runtime.JacBuiltin.log_report { _current_scope, osp_report },
        runtime.JacGraph.clear_edges { osp_forget },
        runtime.JacWalker.async_spawn_call { _current_scope },
        runtime.JacWalker.disengage { osp_disengage },
        runtime.JacWalker.spawn_call { osp_spawn },
        runtime.JacWalker.visit { osp_visit, scope_of },
    ]
    osp_kernel --> runtime.JacPersistence.destroy { osp_forget }
    osp_kernel as _kernel ++> osp_kernel_sv;
    osp_kernel_sv ++> [
        runtime.JacWalker.async_spawn_call {
            desc_for,
            make_sv_runtime,
            osp_spawn_async
        },
        runtime.JacWalker.spawn_call { desc_for, make_sv_runtime },
    ]
    osp_tag --> osp_graph_sv.tag_of_cls { stable_osp_tag }
    preparation_lock --> runtime.JacModule.jac_import { PREPARATION_LOCK }
    prepared ++> [
        context.ExecutionContext.for_target { application_for, application_of },
        prepared_loader.PreparedFinder.find_spec {
            _applications,
            application_namespace,
            entry_alias,
            module_index
        },
        prepared_loader.PreparedLoader.exec_module { execute_module },
        runtime.JacLLM.get_mtir_from_map { semantic_for_scope },
        runtime.JacModule.update_walker { application_for, module_builtins },
        source_app { PreparedApplication, initialize_application, publish },
    ]
    prepared --> runtime.JacModule.impl_patch_filename.decorator { application_for }
    type prepared ++> build_services | prepared_loader { PreparedApplication }
    prepared_loader ++> prepared.publish { PreparedFinder }
    prepared_loader --> prepared.ensure_namespace { PreparedLoader }
    region ++> cinterop { escape_regions, restore_regions }
    region --> [
        archetype.Archetype.__init_subclass__ { is_drop_hook },
        runtime.JacPersistence.destroy { run_drop },
    ]
    region as _region_mod --> builtin.__getattr__;
    runtime ++> [
        context.ExecutionContext.__post_init__ | graph_utils.get_name { JacRuntime },
        context.ExecutionContext.bind_stream { JacRuntime },
        graph_utils.graph_neighbors_view | graph_walk.access_gated {
            JacRuntimeInterface
        },
        graph_utils.graph_node_view | graph_walk.acl_read_ok { JacRuntimeInterface },
        graph_utils.traverse_graph { JacRuntimeInterface },
        prepared.load_prepared_module { JacRuntime as Jac },
    ]
    runtime --> [
        archetype.EdgeAnchor.detach
            | osp_graph_sv._mem_or_ctx
            | osp_kernel_sv._sv_on_complete
            | prepared_loader.PreparedFinder.find_spec { JacRuntime },
        archetype.NodeAnchor.all_edges { JacRuntimeInterface },
        archetype.Root.__getattr__ | osp_kernel_sv._sv_settle { JacRuntime },
        archetype._dirty_delattr { JacRuntime },
        archetype._dirty_setattr { JacRuntime },
        interop_bridge._pyb_import_module { JacModule },
        prepared.execute_module | source_app.main { JacRuntime as Jac },
    ]
    type runtime ++> builtin { LLMModel }
    scalars ++> [
        builtin._is_sized_type_name { is_sized },
        cinterop { ScalarShape, numeric_shapes },
        interop_bridge { shape_of },
        sized { numeric_shapes, range_of, shape_of, wrap_value },
    ]
    semantic ++> runtime { Info }
    type semantic ++> prepared { Info }
    sized as _sized_mod --> builtin.__getattr__;
}

graph import runtime.na_stdlib {
    _ascii ++> [
        datetime { is_digit, is_space },
        re { hexv, is_alpha, is_digit, is_space, is_word, swapcase },
        string { is_id_start, is_word },
    ]
    _bz2_native ++> bz2 { bz2_compress, bz2_decompress }
    _csprng_native ++> secrets | uuid { csprng_bytes }
    _datetime_native ++> datetime {
        dt_epoch_us,
        dt_fmt_buf,
        dt_gmtime,
        dt_localtime,
        dt_out_buf,
        dt_out_str,
        dt_strftime,
        dt_tm,
        dt_tm_gmtoff,
        dt_tm_zone
    }
    _digest ++> [
        hashlib { new_core },
        hmac { new_hmac },
    ]
    type _digest ++> hashlib | hmac { DigestCore }
    _directory_native ++> [
        glob | shutil | uuid | zoneinfo { try_directory_names },
        pathlib { directory_names },
    ]
    _dirent_native ++> _directory_native { dirent_name }
    _errno_native ++> [
        _datetime_native | _file_native | _replace_native {
            last_errno,
            raise_os_error
        },
        _directory_native { clear_errno, last_errno, raise_os_error },
        _socket_native | shutil | socket { errno_message },
        _time_common { last_errno, raise_errno },
        _time_native { raise_errno },
        fcntl | select { EINTR, errno_message, last_errno },
        termios { errno_message, last_errno },
    ]
    _errno_platform ++> _errno_native { errno_address }
    _fcntl_native ++> fcntl {
        _F_GETFD,
        _F_GETFL,
        _F_SETFD,
        _F_SETFL,
        _F_SETOWN,
        _O_APPEND,
        _O_ASYNC,
        _O_NONBLOCK,
        do_fcntl,
        do_ioctl
    }
    _fd_native ++> _replace_native { AT_FDCWD }
    _file_native ++> [
        gettext | mimetypes | pathlib | uuid | zoneinfo { read_file_bytes },
        io { close_stream, open_stream, read_stream, read_stream_all, seek_stream },
    ]
    _glob_native ++> glob { glob_lexists }
    _hex ++> hashlib | hmac | secrets { to_hex }
    _locale_tables ++> locale { _load_alias, _load_encalias }
    _logging_native ++> logging {
        log_fclose,
        log_fflush,
        log_fopen,
        log_fputs,
        log_strftime
    }
    _math_fused ++> math { fmadd }
    _math_native ++> [
        cmath {
            m_asinh,
            m_atan2,
            m_copysign,
            m_cos,
            m_cosh,
            m_exp,
            m_fabs,
            m_hypot,
            m_log,
            m_log1p,
            m_sin,
            m_sinh,
            m_sqrt,
            m_tan,
            m_tanh
        },
        math {
            m_acos,
            m_acosh,
            m_asin,
            m_asinh,
            m_atan,
            m_atan2,
            m_atanh,
            m_cbrt,
            m_ceil,
            m_copysign,
            m_cos,
            m_cosh,
            m_erf,
            m_erfc,
            m_exp,
            m_exp2,
            m_expm1,
            m_fabs,
            m_floor,
            m_fma,
            m_fmod,
            m_log,
            m_log10,
            m_log1p,
            m_log2,
            m_pow,
            m_remainder,
            m_sin,
            m_sinh,
            m_sqrt,
            m_tan,
            m_tanh,
            m_trunc
        },
    ]
    _mimetypes_tables ++> mimetypes {
        _default_common_ext,
        _default_common_val,
        _default_encodings_map,
        _default_knownfiles,
        _default_suffix_map,
        _default_types_ext,
        _default_types_val
    }
    _replace_native ++> _os_native { replace_file }
    _repr ++> [
        difflib { str_gt },
        pprint | reprlib { repr_str, sorted_str_keys },
    ]
    _select_native ++> select {
        _FD_SETSIZE,
        _POLLERR,
        _POLLHUP,
        _POLLIN,
        _POLLNVAL,
        _POLLOUT,
        do_poll
    }
    _socket_abi ++> [
        _socket_native {
            ADDRINFO_ADDRLEN_OFFSET,
            ADDRINFO_ADDR_OFFSET,
            ADDRINFO_NEXT_OFFSET,
            ADDRINFO_SIZE
        },
        socket { IPV6_FAMILY, address_family },
    ]
    _socket_native ++> socket {
        gai_str,
        resolve_all,
        sock_close,
        sock_connect,
        sock_open,
        sock_recv,
        sock_send
    }
    _sqlite3_native ++> sqlite3 {
        sq3_bind_blob,
        sq3_bind_double,
        sq3_bind_int,
        sq3_bind_null,
        sq3_bind_parameter_count,
        sq3_bind_parameter_name,
        sq3_bind_seq,
        sq3_bind_text,
        sq3_busy_timeout,
        sq3_changes,
        sq3_clear_bindings,
        sq3_close,
        sq3_column_count,
        sq3_column_name,
        sq3_complete,
        sq3_errmsg,
        sq3_exec,
        sq3_exec_err,
        sq3_finalize,
        sq3_free,
        sq3_get_autocommit,
        sq3_last_insert_rowid,
        sq3_libversion,
        sq3_open_err,
        sq3_open_v2,
        sq3_prep_sqlp,
        sq3_prep_stmt,
        sq3_prepare,
        sq3_reset,
        sq3_row,
        sq3_step,
        sq3_tail_nonws,
        sq3_total_changes
    }
    _ssl_native ++> ssl {
        ctx_free,
        ctx_load_ca_file,
        ctx_load_default_ca,
        ctx_new_verifying,
        do_handshake,
        last_error,
        ssl_close,
        ssl_new_client,
        ssl_read,
        ssl_write_all,
        verify_message,
        verify_result
    }
    _tarfile_native ++> tarfile {
        tar_chmod,
        tar_close,
        tar_create,
        tar_link,
        tar_read_file,
        tar_symlink,
        tar_utime,
        tar_write
    }
    _termios_native ++> termios {
        _BRKINT,
        _CREAD,
        _CS7,
        _CS8,
        _CSIZE,
        _CSTOPB,
        _ECHO,
        _ECHOE,
        _ECHOK,
        _ECHONL,
        _HUPCL,
        _ICANON,
        _ICRNL,
        _IEXTEN,
        _IGNBRK,
        _IGNCR,
        _IGNPAR,
        _INLCR,
        _INPCK,
        _ISIG,
        _ISTRIP,
        _IXANY,
        _IXOFF,
        _IXON,
        _NCCS,
        _NOFLSH,
        _OFF_CC,
        _OFF_CFLAG,
        _OFF_IFLAG,
        _OFF_LFLAG,
        _OFF_OFLAG,
        _ONLCR,
        _OPOST,
        _PARENB,
        _PARMRK,
        _PARODD,
        _TCSADRAIN,
        _TCSAFLUSH,
        _TCSANOW,
        _TIOCGWINSZ,
        _TOSTOP,
        _VDISCARD,
        _VEOF,
        _VEOL,
        _VEOL2,
        _VERASE,
        _VINTR,
        _VKILL,
        _VLNEXT,
        _VMIN,
        _VQUIT,
        _VREPRINT,
        _VSTART,
        _VSTOP,
        _VSUSP,
        _VTIME,
        _VWERASE,
        get_attrs,
        in_speed,
        out_speed,
        put_word,
        set_attrs,
        set_speeds,
        word_at
    }
    _time_common ++> [
        _datetime_native { time_clock_ns },
        time { time_clock_ns, time_clock_seconds, time_clock_set_ns },
    ]
    _time_native ++> [
        _datetime_native { CLK_REALTIME },
        time {
            CLK_MONOTONIC,
            CLK_MONOTONIC_RAW,
            CLK_PROCESS_CPUTIME,
            CLK_PY_MONOTONIC,
            CLK_REALTIME,
            CLK_THREAD_CPUTIME,
            time_sleep_ns
        },
    ]
    _typename ++> hmac | secrets { typename }
    _unicodedata_tables ++> unicodedata {
        UNICODE_CATEGORIES,
        UNICODE_EAST_ASIAN_WIDTHS,
        UNICODE_PROPERTY_RANGES
    }
    _user_home ++> os.path { user_home }
    _utf8 ++> [
        re { cps_str, utf8_cps },
        reprlib { cp_len, cpslice_str },
    ]
    _zlib_native ++> [
        gzip {
            ZInflateResult,
            Z_MEM_ERROR,
            Z_OK,
            Z_STREAM_END,
            z_compress2,
            z_compress_bound,
            z_crc32,
            z_inflate_all,
            z_inflate_bound
        },
        zipfile {
            ZInflateResult,
            Z_MEM_ERROR,
            Z_STREAM_END,
            z_crc32,
            z_inflate_all,
            z_inflate_bound
        },
        zlib {
            ZInflateResult,
            Z_MEM_ERROR,
            Z_OK,
            Z_STREAM_END,
            z_adler32,
            z_compress2,
            z_compress_bound,
            z_crc32,
            z_inflate_all,
            z_inflate_bound
        },
    ]
    _zstd_native ++> compression.zstd {
        ZSTD_C_COMPRESSION_LEVEL,
        ZSTD_D_WINDOW_LOG_MAX,
        zstd_cctx_free,
        zstd_cctx_new,
        zstd_cctx_set,
        zstd_compress2,
        zstd_compress_bound,
        zstd_dctx_free,
        zstd_dctx_new,
        zstd_dctx_set,
        zstd_decompress_stream,
        zstd_error_name,
        zstd_frame_content_size,
        zstd_frame_dict_id,
        zstd_is_error,
        zstd_version_number
    }
    datetime ++> zoneinfo { _MAXORDINAL, _ord2ymd }
    http.client ++> urllib.request { HTTPResponse }
    termios ++> tty {
        BRKINT,
        CS8,
        CSIZE,
        ECHO,
        ECHOE,
        ECHOK,
        ECHONL,
        ICANON,
        ICRNL,
        IEXTEN,
        IGNBRK,
        IGNCR,
        IGNPAR,
        INLCR,
        INPCK,
        ISIG,
        ISTRIP,
        IXANY,
        IXOFF,
        IXON,
        NOFLSH,
        OPOST,
        PARENB,
        PARMRK,
        TCSAFLUSH,
        TOSTOP,
        VMIN,
        VTIME,
        tcgetattr,
        tcsetattr
    }
}

graph import scale {
    _optdeps.apscheduler ++> [
        scheduler.scheduler { BackgroundScheduler, CronTrigger, HAS_APSCHEDULER },
        tests.misc.test_optional_deps { BackgroundScheduler, HAS_APSCHEDULER },
    ]
    _optdeps.apscheduler --> tests.misc.test_optional_deps;
    _optdeps.firebase_auth ++> sso.firebase {
        HAS_FIREBASE_ADMIN,
        auth,
        credentials,
        firebase_admin
    }
    _optdeps.gcs ++> [
        storage.gcs_storage { NotFound, StorageClient, require_google_cloud_storage },
        tests.misc.test_optional_deps { HAS_GCS, StorageClient },
    ]
    _optdeps.kubernetes ++> [
        admin.k8s_ops { HAS_KUBERNETES, client, config },
        deploy.autoscale.autoscaler.Autoscaler.read_workload
            | deploy.target.kubernetes.ingress
            | deploy.target.kubernetes.monitoring
            | deploy.target.kubernetes.target
            | deploy.target.kubernetes.utils.kubernetes_utils
            | injector.pvc_injector.PvcInjector.seed { ApiException, client },
        deploy.autoscale.hpa_autoscaler | deploy.autoscale.keda_autoscaler {
            ApiException,
            AutoscalingV2Api,
            client
        },
        deploy.autoscale.http_activation_config | tests.deploy.test_database_intent {
            ApiException
        },
        deploy.autoscale.keda_autoscaler.KEDAAutoscaler.watch_scale_targets { watch },
        deploy.target.kubernetes.cluster_provider
            | deploy.target.kubernetes.database_provisioner { client },
        deploy.target.kubernetes.kubernetes_target {
            ApiException,
            ConfigException,
            client,
            config as k8s_cluster_config
        },
        tests.deploy.observer_transition_recorder { ApiException, config },
        tests.misc.test_optional_deps { HAS_KUBERNETES, client as k8s_client },
    ]
    _optdeps.kubernetes --> tests.misc.test_optional_deps;
    _optdeps.opentelemetry ++> admin.ops | runtime.context.tracing { HAS_OTEL }
    _optdeps.optional_deps ++> [
        config.project_env | deploy.target.factory | sso.firebase { require_optional },
        observability.factory { is_optional_available },
        tests.misc.test_optional_deps { is_optional_available, require_optional },
    ]
    _optdeps.prometheus ++> [
        admin.ops { HAS_PROMETHEUS },
        observability.prometheus_metrics {
            CONTENT_TYPE_LATEST,
            CollectorRegistry,
            Counter,
            Gauge,
            Histogram,
            generate_latest
        },
        tests.misc.test_optional_deps { Counter, HAS_PROMETHEUS },
    ]
    _optdeps.prometheus --> tests.misc.test_optional_deps;
    admin ++> [
        admin.console_build.package_ui_dir { admin_portal },
        tests.misc.test_k8s_ops { k8s_ops },
    ]
    admin --> tests.server.test_admin;
    admin as admin_pkg ++> tests.misc.test_ops_signals;
    admin.admin_portal ++> [
        runtime.gateway.microservice_gateway
            | server.extensions
            | tests.server.test_auth_policy_startup { JacAPIServerAdmin },
        tests.misc.test_metrics._distribution_for {
            _calculate_metrics_summary,
            _parse_prometheus_text
        },
    ]
    admin.admin_portal --> tests.misc.test_metrics {
        _calculate_metrics_summary,
        _classify_path,
        _parse_prometheus_text,
        _percentile_from_buckets
    }
    admin.console_build ++> runtime.gateway.microservice_gateway.MicroserviceGateway.serve_admin_asset {
        resolve_console
    }
    admin.console_build --> tests.server.test_admin { AdminConsole, ConsoleState }
    admin.deploy_health ++> [
        runtime.gateway.microservice_gateway | server.extensions {
            JacAPIServerDeployHealth
        },
        tests.deploy.test_ops_deploy {
            JacAPIServerDeployHealth,
            summarize_deployment,
            summarize_pod
        },
    ]
    admin.llm_telemetry ++> [
        runtime.gateway.microservice_gateway | server.extensions {
            JacAPIServerLLMTelemetry
        },
        tests.misc.test_llm_telemetry { TelemetryStore },
    ]
    admin.logs ++> runtime.gateway.microservice_gateway
        | server.extensions
        | tests.server.test_admin_logs { JacAPIServerLogs }
    admin.logs --> tests.server.test_admin_logs {
        _build_logql,
        _flatten_loki_response,
        _service_to_pod_regex_for_mode,
        _services_for_mode
    }
    admin.network ++> [
        runtime.gateway.microservice_gateway | server.extensions {
            JacAPIServerNetwork
        },
        tests.deploy.test_ops_network {
            JacAPIServerNetwork,
            pvc_claimants,
            summarize_ingress,
            summarize_pvc,
            summarize_service
        },
    ]
    admin.ops ++> [
        runtime.gateway.microservice_gateway | server.extensions { JacAPIServerOps },
        tests.deploy.test_ops_health {
            JacAPIServerOps,
            _traces_chain,
            short_circuit_chain
        },
    ]
    admin.podenv ++> [
        runtime.gateway.microservice_gateway | server.extensions { JacAPIServerPodEnv },
        tests.misc.test_ops_podenv {
            JacAPIServerPodEnv,
            pod_env_entries,
            redact_entry
        },
    ]
    admin.service_urls ++> tests.misc.test_service_urls { service_base_url }
    admin.traces ++> [
        runtime.gateway.microservice_gateway | server.extensions { JacAPIServerTraces },
        tests.server.test_traces_admin {
            _build_traceql,
            _flatten_tempo_trace,
            _normalize_trace_id,
            _otlp_attrs,
            _otlp_value
        },
    ]
    admin.workload_helpers ++> tests.server.test_admin_workloads {
        match_owner,
        owner_name_from_pod,
        phase_to_status
    }
    admin.workloads ++> runtime.gateway.microservice_gateway | server.extensions {
        JacAPIServerWorkloads
    }
    config.app_config ++> [
        deploy.target.deployment_target
            | deploy.target.kubernetes.manifest_builder
            | deploy.target.kubernetes.target
            | runtime.cli.plan
            | tests.apps.test_app_scale_overrides
            | tests.deploy.test_access_hint
            | tests.deploy.test_alb_zero_downtime
            | tests.deploy.test_deploy_k8s
            | tests.deploy.test_dry_run_purity
            | tests.deploy.test_factories
            | tests.deploy.test_ops_rbac
            | tests.deploy.test_pdb_budget
            | tests.deploy.test_pod_env
            | tests.deploy.test_show_yaml_autoscalers
            | tests.deploy.test_superseded_deployment_reap
            | tests.deploy.test_version_pin { AppConfig },
        plugin | tests.deploy.test_deploy_banner { deployed_tree },
        runtime.realizer.kubernetes_realizer | sdk.client { AppConfig, deployed_tree },
    ]
    config.app_config --> tests.deploy.test_http_activation_microservices
        | tests.deploy.test_memory_trigger_guard { AppConfig }
    config.base_config ++> deploy.target.deployment_target
        | deploy.target.kubernetes.kubernetes_config { BaseConfig }
    config.config_loader ++> [
        admin.admin_portal
            | admin.llm_telemetry.JacAPIServerLLMTelemetry.register_llm_telemetry_endpoints
            | admin.logs
            | admin.ops
            | admin.service_urls
            | deploy.database.kubernetes_postgres
            | deploy.target.kubernetes.kubernetes_target
            | emailer.factory.configured
            | plugin
            | runtime.cli.diagnostics.PlanValidator._check_config_keys
            | runtime.gateway.microservice_gateway.MicroserviceGateway.setup
            | runtime.provider
            | runtime.realizer.kubernetes_realizer
            | scheduler.scheduler
            | server.jobs_ext
            | server.sso_ext
            | server.webhook_ext
            | server.websocket_ext
            | sso.sso_auth
            | webhook.webhook { get_scale_config },
        deploy.target.kubernetes.manifest_builder {
            ADMIN_PASSWORD_ENV,
            GATEWAY_POD_KEYS,
            SIGNING_SECRET_ENV,
            get_scale_config,
            normalize_gateway_config
        },
        deploy.target.kubernetes.target {
            ADMIN_PASSWORD_ENV,
            SIGNING_SECRET_ENV,
            get_scale_config
        },
        deploy.target.kubernetes.target.KubernetesTarget._gateway_cfg
            | tests.data.test_gateway_owned_identity { normalize_gateway_config },
        runtime.fleet._build_fleet { app_scale_overrides },
        server.extensions { ADMIN_PASSWORD_ENV, get_scale_config },
        tests.apps.test_app_scale_overrides {
            APP_SCALE_KEYS,
            JacScaleConfig,
            app_scale_overrides,
            get_scale_config,
            normalize_gateway_config,
            reset_scale_config
        },
        tests.data.test_firebase_env
            | tests.deploy.test_client_build_stage
            | tests.deploy.test_database_intent
            | tests.deploy.test_deploy_k8s
            | tests.deploy.test_gateway_config_isolation
            | tests.deploy.test_service_routing
            | tests.misc.test_service_urls
            | tests.server.test_scheduler_endpoints {
            get_scale_config,
            reset_scale_config
        },
        tests.deploy.test_deployment_overlay
            | tests.misc.test_config_loader
            | tests.misc.test_config_validation {
            JacScaleConfig,
            get_scale_config,
            reset_scale_config
        },
        tests.deploy.test_pod_env
            | tests.server.test_firebase_auth_sso
            | tests.server.test_ws_hardening { reset_scale_config },
        tests.microservices.test_binary_injector { JacScaleConfig },
        tests.misc.test_log_emit {
            get_scale_config,
            peek_scale_config,
            reset_scale_config
        },
    ]
    config.config_loader --> [
        admin.workloads._metrics_namespace
            | deploy.target.kubernetes.runtime_resolver.resolve_peer_route
            | runtime.context.service_routing.is_http_activated
            | runtime.context.util.boot_health_timeout
            | runtime.provider.JacScaleRuntime.get_sv_service_routes
            | runtime.rpc.rpc._sv_rpc_timeout { get_scale_config },
        admin.workloads._unavailable_reason
            | runtime.context.util.http_forward_timeout { get_scale_config },
        runtime.context.log_emit.install_structured_logging { peek_scale_config },
        runtime.context.util.route_refresh_seconds { get_scale_config },
        tests.microservices.test_gateway | tests.server.test_webhook {
            get_scale_config,
            reset_scale_config
        },
        tests.misc.test_config_validation { normalize_gateway_config },
        tests.server.test_ws_hardening { _ws_positive, get_scale_config },
    ]
    config.config_loader as cfg_mod --> tests.microservices.test_gateway;
    config.config_loader as config_loader ++> tests.microservices.test_gateway._with_cors_config;
    config.config_loader as config_loader_mod --> tests.deploy.test_pod_env
        | tests.server.test_sv_auth_forward;
    config.dev_config ++> [
        injector.binary.deploy_generation_refusal { Channel, resolve_dev_channel },
        injector.binary.host_toolchain_path | injector.binary_injector.select_injector {
            resolve_dev_channel
        },
        injector.binary.preflight_pod_runtime | injector.binary_injector { Channel },
        injector.binary.read_local_binary { local_pod_binary },
        injector.binary.resolve_console_version { Channel },
        injector.binary.resolve_deploy_version { Channel },
        injector.binary.resolve_pod_base_image {
            Channel,
            resolve_dev_channel,
            resolve_experimental_pr,
            resolve_pinned_spec
        },
        tests.microservices.test_binary_injector {
            Channel,
            resolve_dev_channel,
            resolve_experimental_pr
        },
    ]
    config.dev_config --> deploy.target.kubernetes.target.KubernetesTarget.deploy {
        resolve_dev_channel
    }
    config.firebase_env ++> [
        sso.firebase | sso.sso_auth { firebase_project_id_env_hint },
        storage.factory {
            JAC_STORAGE_FIREBASE_PROJECT_ID_ENV,
            JAC_STORAGE_GCS_PROJECT_ID_ENV,
            resolve_firebase_project_id
        },
        tests.data.test_firebase_env {
            FIREBASE_AUTH_PROJECT_ID_ENV,
            FIREBASE_PROJECT_ID_ENV,
            FIRESTORE_PROJECT_ID_ENV,
            JAC_STORAGE_FIREBASE_PROJECT_ID_ENV,
            resolve_firebase_project_id
        },
    ]
    config.plugin_config ++> tests.misc.test_config_validation { JacScalePluginConfig }
    config.plugin_config --> tests.misc.test_config_loader { JacScalePluginConfig }
    config.project_env ++> plugin | runtime.realizer.kubernetes_realizer {
        load_project_env
    }
    config.project_env --> tests.misc.test_optional_deps {
        PROJECT_ENV_CAPABILITY,
        project_env_path
    }
    config.validation ++> [
        runtime.cli.diagnostics.PlanValidator._check_config_keys
            | tests.server.test_sso_grants { validate_scale_config },
        tests.apps.test_app_scale_overrides {
            STRICT_ENV,
            validate_app_scale_config,
            validate_scale_config
        },
        tests.misc.test_config_validation {
            STRICT_ENV,
            known_deploy_targets,
            validate_scale_config
        },
    ]
    config.validation --> tests.misc.test_config_validation {
        scheduler_job_cap,
        scheduler_min_interval
    }
    deploy.autoscale.autoscaler ++> [
        runtime.cli.diagnostics { triggers_can_reach_zero },
        sdk { AutoscalerRuntimeStatus, AutoscalerTransition },
        sdk.client { AutoscalerRuntimeStatus },
        tests.deploy.test_deployment_overlay { Autoscaler, AutoscalerSpec },
        tests.deploy.test_factories { AutoscalerSpec, Trigger },
        tests.deploy.test_http_activation_microservices {
            AutoscalerSpec,
            Trigger,
            TriggerAuth
        },
    ]
    deploy.autoscale.factory ++> sdk.client
        | tests.deploy.test_factories
        | tests.deploy.test_service_routing { AutoscalerFactory }
    deploy.autoscale.hpa_autoscaler ++> tests.deploy.test_factories { HPAAutoscaler }
    deploy.autoscale.http_activation ++> [
        tests.deploy.http_activation_test_support {
            HTTPActivationSpec,
            HTTPConcurrencyMetric,
            HTTPServiceTarget
        },
        tests.deploy.test_http_activation_microservices {
            HTTPColdStartSpec,
            HTTPHeaderMatch,
            HTTPPathMatch,
            HTTPRequestRateMetric,
            HTTPRoutingRule,
            HTTPServiceTarget,
            HTTPStaticResponse,
            HTTPTimeoutSpec
        },
    ]
    deploy.autoscale.http_activation_config ++> tests.deploy.test_http_activation_config {
        apply_http_activation_for_target,
        build_http_activation_spec,
        destroy_http_activation_for_target
    }
    deploy.autoscale.keda_autoscaler ++> tests.deploy.http_activation_test_support
        | tests.deploy.observer_transition_recorder
        | tests.deploy.test_factories
        | tests.deploy.test_http_activation_config
        | tests.deploy.test_http_activation_microservices
        | tests.deploy.test_service_routing { KEDAAutoscaler }
    deploy.database.kubernetes_postgres ++> tests.deploy.test_deploy_k8s
        | tests.deploy.test_postgres_predicate_lock_headroom {
        KubernetesPostgresProvider
    }
    deploy.target.factory ++> [
        plugin { DeploymentTargetFactory, ensure_deploy_tooling },
        runtime.realizer.kubernetes_realizer
            | tests.deploy.test_deploy_banner
            | tests.deploy.test_deploy_k8s
            | tests.deploy.test_dry_run_purity
            | tests.deploy.test_factories { DeploymentTargetFactory },
        sdk.client { ensure_deploy_tooling, require_deploy_tooling },
    ]
    deploy.target.factory --> tests.misc.test_config_validation
        | tests.misc.test_optional_deps { DeploymentTargetFactory }
    deploy.target.kubernetes.cluster_provider ++> tests.deploy.test_cluster_provider {
        AWSProvider,
        LocalProvider
    }
    deploy.target.kubernetes.database_provisioner ++> tests.deploy.test_pod_env {
        DatabaseProvisioner
    }
    deploy.target.kubernetes.ingress ++> tests.deploy.test_deploy_k8s
        | tests.deploy.test_ingress_deployer
        | tests.deploy.test_ingress_tls_preservation { IngressDeployer }
    deploy.target.kubernetes.kubernetes_config ++> [
        config.config_loader.JacScaleConfig.get_kubernetes_config {
            KubernetesConfig,
            k8s_safe_slug
        },
        sdk.client
            | sdk.spec.DeploySpec.to_target_config
            | tests.apps.test_app_scale_overrides
            | tests.deploy.test_access_hint
            | tests.deploy.test_alb_zero_downtime
            | tests.deploy.test_client_build_deps
            | tests.deploy.test_client_build_fail_fast
            | tests.deploy.test_client_build_stage
            | tests.deploy.test_crash_scan_fleet_guard
            | tests.deploy.test_database_intent
            | tests.deploy.test_deploy_k8s
            | tests.deploy.test_deployment_overlay
            | tests.deploy.test_destroy_reclaim
            | tests.deploy.test_dry_run_purity
            | tests.deploy.test_factories
            | tests.deploy.test_gateway_config_isolation
            | tests.deploy.test_http_activation_microservices
            | tests.deploy.test_ingress_deployer
            | tests.deploy.test_ingress_tls_preservation
            | tests.deploy.test_memory_trigger_guard
            | tests.deploy.test_monitoring_switch
            | tests.deploy.test_ops_rbac
            | tests.deploy.test_pdb_budget
            | tests.deploy.test_pod_env
            | tests.deploy.test_service_routing
            | tests.deploy.test_show_yaml_autoscalers
            | tests.deploy.test_superseded_deployment_reap
            | tests.deploy.test_version_pin
            | tests.microservices.test_binary_injector
            | tests.microservices.test_fleet_rollout
            | tests.misc.test_config_loader
            | tests.misc.test_config_validation
            | tests.misc.test_k8s_config_tracing { KubernetesConfig },
    ]
    deploy.target.kubernetes.kubernetes_config --> [
        sdk.spec.DeploySpec.from_config | tests.deploy.test_deploy_k8s {
            k8s_safe_slug
        },
        tests.microservices.test_pvc_injector { KubernetesConfig },
    ]
    deploy.target.kubernetes.kubernetes_target ++> runtime.realizer.kubernetes_realizer.KubernetesRealizer.realize
        | tests.deploy.test_database_intent { KubernetesTargetBase }
    deploy.target.kubernetes.kubernetes_target --> tests.microservices.test_pvc_injector {
        KubernetesTargetBase
    }
    deploy.target.kubernetes.manifest_builder ++> [
        runtime.cli.diagnostics | runtime.cli.plan { ScalingMode },
        tests.apps.test_app_scale_overrides
            | tests.deploy.test_access_hint
            | tests.deploy.test_alb_zero_downtime
            | tests.deploy.test_client_build_deps
            | tests.deploy.test_client_build_fail_fast
            | tests.deploy.test_destroy_reclaim
            | tests.deploy.test_dry_run_purity
            | tests.deploy.test_gateway_config_isolation
            | tests.deploy.test_memory_trigger_guard
            | tests.deploy.test_ops_rbac
            | tests.deploy.test_service_routing
            | tests.deploy.test_superseded_deployment_reap { ManifestBuilder },
        tests.deploy.test_client_build_stage {
            ManifestBuilder,
            _CLIENT_BUILD_ATTEMPTS,
            _CLIENT_BUILD_RETRY_PAUSE_S,
            _is_transient_client_build_failure,
            _membership_diagnosis,
            _run_until_quiet
        },
        tests.deploy.test_deployment_overlay {
            CONFIG_REVISION_ANNOTATION,
            ManifestBuilder,
            merge_manifest_overlay,
            with_config_revision
        },
        tests.deploy.test_http_activation_microservices
            | tests.deploy.test_show_yaml_autoscalers { ManifestBuilder, ScalingMode },
        tests.deploy.test_pdb_budget { ManifestBuilder, ScalingMode, pdb_spec },
        tests.deploy.test_pod_env {
            CONFIG_REVISION_ANNOTATION,
            ManifestBuilder,
            with_config_revision
        },
    ]
    deploy.target.kubernetes.monitoring ++> tests.deploy.test_monitoring_switch {
        MonitoringDeployer
    }
    deploy.target.kubernetes.ops_rbac ++> tests.deploy.test_ops_rbac {
        build_ops_rbac,
        ops_role_name,
        ops_sa_is_ours,
        ops_sa_name
    }
    deploy.target.kubernetes.runtime_bootstrap ++> tests.microservices.test_binary_injector {
        build_bootstrap_init_container,
        build_runtime_install_commands,
        build_service_apt_prefix,
        runtime_container_env
    }
    deploy.target.kubernetes.runtime_bootstrap --> [
        tests.microservices.test_binary_injector { image_pull_policy },
        tests.microservices.test_pvc_injector { build_bootstrap_init_container },
    ]
    deploy.target.kubernetes.runtime_resolver ++> [
        tests.deploy.test_pod_env {
            K8sRuntimeServiceResolver,
            build_k8s_registry,
            resolve_peer_route
        },
        tests.deploy.test_service_routing { build_k8s_registry_routes },
    ]
    deploy.target.kubernetes.runtime_resolver --> runtime.provider.JacScaleRuntime.get_sv_service_routes {
        build_k8s_registry_routes
    }
    deploy.target.kubernetes.runtime_resolver as resolver_mod --> tests.deploy.test_pod_env;
    deploy.target.kubernetes.target ++> [
        runtime.realizer.kubernetes_realizer.KubernetesRealizer.realize
            | sdk.client.ScaleClient._build_target
            | tests.deploy.test_access_hint
            | tests.deploy.test_alb_zero_downtime
            | tests.deploy.test_crash_scan_fleet_guard
            | tests.deploy.test_memory_trigger_guard
            | tests.deploy.test_monitoring_switch
            | tests.deploy.test_pod_env
            | tests.deploy.test_show_yaml_autoscalers
            | tests.deploy.test_version_pin
            | tests.microservices.test_fleet_rollout { KubernetesTarget },
        tests.deploy.test_http_activation_microservices {
            KubernetesTarget,
            apply_http_activations_for_bundle,
            reap_stale_scaling_resources_for_bundle,
            replacing_init_containers
        },
        tests.deploy.test_superseded_deployment_reap {
            KubernetesTarget,
            app_bundle_digest,
            fleet_revert_order,
            fleet_targets_for_release,
            releases_from_revisions,
            restorable_pod_template
        },
    ]
    deploy.target.kubernetes.target as target_mod --> tests.deploy.test_superseded_deployment_reap;
    type deploy.target.kubernetes.target ++> sdk.client { KubernetesTarget }
    deploy.target.kubernetes.utils.kubernetes_utils ++> [
        injector.injector | injector.pvc_injector { KubectlCluster },
        injector.pvc_injector.PvcInjector.seed {
            run_kubectl_command,
            wait_for_pod_deletion,
            wait_for_pod_phase
        },
        tests.deploy.test_cluster_provider { get_cluster_provider },
        tests.deploy.test_deploy_k8s { wait_for_pod_phase },
        tests.deploy.test_k8s_utils { parse_storage_quantity, resize_pvc_if_needed },
        tests.deploy.test_pod_env { create_k8s_secret, resolve_minted_secret },
        tests.deploy.test_pss_labels {
            PSS_ENFORCE_LABEL,
            PSS_SOURCE_LABEL,
            PSS_WARN_LABEL,
            default_pss_labels,
            privileged_pss_labels
        },
    ]
    deploy.target.kubernetes.utils.kubernetes_utils --> tests.deploy.test_dry_run_purity
        | tests.microservices.test_pvc_injector { KubectlCluster }
    deploy.target.registry ++> config.validation { DeploymentTargetRegistry }
    deploy.target.registry --> tests.misc.test_config_validation {
        BUILTIN_TARGET_TYPES
    }
    deploy.target.service_deployer ++> runtime.orchestrator.local_deployer
        | runtime.orchestrator.process_manager { ServiceDeployer }
    emailer.emailer ++> [
        server.extensions { Emailer },
        tests.server.test_emailer_factory { EmailAttachment, Emailer },
    ]
    emailer.emailers ++> tests.server.test_emailer_factory { SMTPEmailer }
    emailer.factory ++> [
        runtime.gateway.microservice_gateway.MicroserviceGateway._install_admin_api
            | server.extensions { configured as configured_emailer },
        tests.server.test_emailer_factory { create as create_emailer, register },
    ]
    events.broker ++> [
        config.config_loader.JacScaleConfig.get_events_config { RetryPolicy },
        tests.data.test_local_stream | tests.data.test_pg_stream { Event },
        tests.misc.test_events {
            Event,
            EventStreamBroker,
            HealthStatus,
            RetryPolicy,
            StreamPosition,
            starts_at_earliest
        },
    ]
    events.publisher ++> [
        server.extensions.EventsExtension.register { set_broker },
        tests.misc.test_events { publish, set_broker },
    ]
    events.streams._stream_common ++> tests.misc.test_events { consumer_loop }
    events.streams.local ++> tests.data.test_local_stream | tests.misc.test_events {
        LocalEventStream
    }
    events.streams.local --> server.extensions.EventsExtension.register {
        LocalEventStream
    }
    events.streams.postgres ++> [
        tests.data.test_pg_stream { PgEventStream, _STREAM_SCHEMA },
        tests.misc.test_events { PgEventStream },
    ]
    events.streams.postgres --> server.extensions.EventsExtension.register {
        PgEventStream
    }
    events.subscriber ++> [
        server.extensions.EventsExtension.register { get_subscriptions },
        tests.misc.test_events { get_subscriptions, subscribe },
    ]
    injector.binary ++> [
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_client_bundle
            | runtime.realizer.kubernetes_realizer.KubernetesRealizer._deploy_on_pinned_jac {
            host_toolchain_path
        },
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._seal_bakes_client {
            host_toolchain_path
        },
        deploy.target.kubernetes.runtime_bootstrap.build_bootstrap_init_container {
            OFFICIAL_IMAGE
        },
        deploy.target.kubernetes.runtime_bootstrap.image_pull_policy { OFFICIAL_IMAGE },
        deploy.target.kubernetes.target.KubernetesTarget.deploy {
            deploy_generation_refusal
        },
        deploy.target.kubernetes.target.KubernetesTarget.generate_manifests {
            resolve_pod_base_image
        },
        runtime.realizer.kubernetes_realizer.KubernetesRealizer.realize
            | sdk.client.ScaleClient.deploy { reset_deploy_version_cache },
        tests.deploy.test_version_pin { _resolve_target_version },
        tests.microservices.test_admin_console_source {
            admin_dist_source,
            resolve_console_version,
            resolve_deploy_version,
            resolve_pinned_version
        },
        tests.microservices.test_binary_injector {
            cluster_node_archs,
            download_release_binary,
            node_arch,
            pack_binary_bytes,
            read_local_binary,
            stage_admin_dist
        },
        tests.microservices.test_seed_determinism { pack_binary_bytes },
    ]
    injector.binary --> [
        deploy.target.kubernetes.target.KubernetesTarget.deploy {
            node_arch,
            preflight_pod_runtime
        },
        runtime.realizer.kubernetes_realizer.KubernetesRealizer.realize {
            deploy_generation_refusal
        },
        tests.microservices.test_binary_injector { resolve_pod_base_image },
    ]
    injector.binary as binary --> tests.microservices.test_binary_injector;
    injector.binary as binary_mod ++> tests.deploy.test_client_build_fail_fast
        | tests.deploy.test_dry_run_purity
        | tests.deploy.test_pod_env
        | tests.deploy.test_version_pin
        | tests.microservices.test_binary_injector;
    injector.binary as binary_mod --> tests.deploy.test_memory_trigger_guard;
    injector.binary as binmod --> tests.microservices.test_binary_cache;
    injector.binary_injector ++> [
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_pod_spec
            | tests.deploy.test_dry_run_purity
            | tests.microservices.test_binary_injector { BinaryInjector },
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._prepare_injector {
            select_injector
        },
    ]
    injector.binary_injector as bi_mod --> tests.microservices.test_binary_injector;
    injector.binary_injector as binary_injector_mod ++> tests.deploy.test_dry_run_purity;
    injector.bundle ++> [
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_client_bundle {
            _stage_app,
            cached_client_dist,
            client_build_sources,
            client_input_digest,
            nested_sanitized_tomls,
            release_binary_env,
            remember_client_dist,
            remove_stage_root
        },
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_pod_spec
            | tests.deploy.test_pod_env._entrypoint_run { APP_MOUNT_PATH },
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._check_pod_config_resolves {
            nested_sanitized_tomls,
            source_filter_for,
            unresolved_toml_references
        },
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._client_entry_rel {
            source_filter_for
        },
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._pod_entrypoint {
            APP_MOUNT_PATH
        },
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._project_config {
            _project_config
        },
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._seal_bakes_client {
            entry_module_rel
        },
        deploy.target.kubernetes.runtime_bootstrap {
            APP_MOUNT_PATH,
            APP_VOLUME_NAME,
            JAC_HOME,
            TOOLCHAIN_SUBDIR
        },
        runtime.realizer.kubernetes_realizer.KubernetesRealizer._deploy_on_pinned_jac
            | tests.deploy.test_client_build_fail_fast { release_binary_env },
        tests.deploy.test_client_build_stage { bundle_source_files, source_filter_for },
        tests.microservices.test_app_precompile {
            DEFAULT_SEAL_TIMEOUT_S,
            _precompile_app,
            _stage_app,
            bundle_source_files,
            nested_sanitized_tomls,
            pack_jab,
            seal_cache_setting,
            seal_input_digest,
            seal_timeout_setting
        },
        tests.microservices.test_binary_injector { TOOLCHAIN_SUBDIR },
        tests.microservices.test_bundle_jacignore {
            _stage_app,
            add_source_members,
            bundle_source_files,
            content_address,
            nested_sanitized_tomls,
            pack_jab,
            partition_bundle_sources
        },
        tests.microservices.test_fat_bundle {
            _strip_external_record_lines,
            content_address,
            fat_bundle_enabled,
            fat_bundle_setting,
            pack_jab,
            staged_venv_files
        },
        tests.microservices.test_pvc_injector { pack_jab },
        tests.microservices.test_seed_determinism { content_address, pack_jab },
    ]
    injector.bundle --> [
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._bundle_files {
            resolve_fleet_entries
        },
        tests.microservices.test_app_precompile {
            PLACEHOLDER_JAC_TOML,
            reap_stale_stage_roots,
            seal_step_env,
            stage_roots_in_use
        },
    ]
    injector.bundle as bundle --> tests.microservices.test_fat_bundle;
    injector.pvc_injector ++> [
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._prepare_injector {
            PvcInjector
        },
        deploy.target.kubernetes.runtime_bootstrap
            | tests.microservices.test_binary_injector {
            BUNDLE_MOUNT_PATH,
            BUNDLE_VOLUME_NAME
        },
        deploy.target.kubernetes.target {
            bundle_keys_from_pod_spec,
            bundle_loader_pod_name,
            bundle_pvc_name
        },
        tests.deploy.test_destroy_reclaim { bundle_loader_pod_name, bundle_pvc_name },
        tests.microservices.test_pvc_injector {
            BUNDLE_MOUNT_PATH,
            PvcInjector,
            RUNTIME_GID,
            RUNTIME_UID,
            build_bundle_pvc,
            build_loader_pod,
            build_pvc_init_container,
            bundle_keys_from_pod_spec
        },
    ]
    injector.pvc_injector --> [
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_pod_spec {
            VOLUME_PERMS_NAME,
            build_volume_perms_init_container,
            runtime_pod_security_context
        },
        tests.deploy.test_pod_env {
            BUNDLE_MOUNT_PATH,
            PVC_BOOTSTRAP_NAME,
            RUNTIME_GID,
            RUNTIME_UID,
            VOLUME_PERMS_NAME,
            bundle_keys_from_pod_spec
        },
        tests.microservices.test_pvc_injector { pvc_unpack_script },
    ]
    memory.context ++> runtime.provider.JacScaleRuntime.create_j_context {
        JScaleExecutionContext
    }
    models.deploy_context ++> [
        deploy.target.kubernetes.database_provisioner
            | deploy.target.kubernetes.target { DeployContext },
        deploy.target.kubernetes.kubernetes_target { DATABASE_URL_ENV },
        deploy.target.kubernetes.manifest_builder { DATABASE_URL_ENV, DeployContext },
    ]
    models.deployment_result ++> deploy.target.deployment_target
        | deploy.target.kubernetes.target
        | sdk
        | sdk.client
        | tests.deploy.test_deploy_k8s { DeploymentResult }
    models.progress ++> [
        deploy.target.kubernetes.kubernetes_target {
            EventSink,
            NoopSink,
            ProgressEvent
        },
        sdk { CallbackSink, EventSink, ProgressEvent },
        sdk.client { CallbackSink, EventSink, NoopSink, ProgressEvent },
        sdk.events { EventSink, ProgressEvent },
    ]
    models.progress --> tests.deploy.test_superseded_deployment_reap {
        CallbackSink,
        ProgressEvent
    }
    models.resource_status ++> [
        admin.deploy_health { assess_workload },
        deploy.autoscale.autoscaler {
            ResourceStatus,
            ResourceStatusInfo,
            assess_workload,
            field_of
        },
        deploy.autoscale.hpa_autoscaler
            | deploy.autoscale.keda_autoscaler
            | tests.deploy.test_deploy_k8s { ResourceStatus },
        deploy.target.deployment_target | sdk.client { ResourceStatusInfo },
        deploy.target.kubernetes.kubernetes_target {
            ResourceStatus,
            ResourceStatusInfo,
            assess_workload,
            container_crashlooping
        },
        deploy.target.kubernetes.manifest_builder
            | tests.deploy.test_ops_deploy
            | tests.microservices.test_fleet_rollout { REPLICA_FLOOR_ANNOTATION },
        deploy.target.kubernetes.target {
            ResourceStatus,
            assess_workload,
            container_crashlooping
        },
        sdk { ResourceStatus, ResourceStatusInfo },
        tests.deploy.test_http_activation_microservices {
            REPLICA_FLOOR_ANNOTATION,
            ResourceStatus
        },
        tests.deploy.test_superseded_deployment_reap {
            REPLICA_FLOOR_ANNOTATION,
            assess_workload,
            container_crashlooping
        },
    ]
    observability.factory ++> plugin
        | runtime.gateway.microservice_gateway.MicroserviceGateway.setup
        | runtime.realizer.kubernetes_realizer
        | sdk.client.ScaleClient._pick_logger
        | server.extensions.MetricsExtension.register
        | tests.deploy.test_deploy_k8s
        | tests.deploy.test_factories
        | tests.misc.test_metrics { UtilityFactory }
    observability.factory --> tests.misc.test_optional_deps { UtilityFactory }
    observability.logger ++> deploy.autoscale.factory
        | deploy.autoscale.hpa_autoscaler
        | deploy.autoscale.keda_autoscaler
        | deploy.target.deployment_target
        | deploy.target.factory
        | deploy.target.kubernetes.cluster_provider
        | deploy.target.kubernetes.ingress
        | deploy.target.kubernetes.kubernetes_target
        | deploy.target.kubernetes.monitoring
        | sdk.client
        | sdk.events { Logger }
    type observability.logger ++> deploy.target.registry { Logger }
    observability.metrics ++> [
        admin.admin_portal | server.extensions { MetricsCollector },
        tests.misc.test_metrics { NoOpMetricsCollector },
    ]
    observability.metrics --> tests.misc.test_optional_deps { NoOpMetricsCollector }
    observability.prometheus_client ++> admin.workloads {
        query as prom_query,
        query_range as prom_query_range,
        resolve_prometheus_url,
        scalar as prom_scalar
    }
    observability.prometheus_metrics ++> tests.misc.test_metrics {
        PrometheusMetricsCollector
    }
    observability.prometheus_metrics --> tests.misc.test_optional_deps {
        PrometheusMetricsCollector
    }
    observability.standard_logger ++> tests.deploy.test_http_activation_microservices {
        StandardLogger
    }
    runtime.cli.diagnostics ++> tests.deploy.test_pdb_budget { PlanValidator }
    runtime.cli.plan ++> tests.deploy.test_ops_rbac { Plan }
    runtime.context.auth_ctx ++> [
        server.extensions.ObservabilityExtension.register {
            reset_current_auth,
            set_current_auth
        },
        tests.server.test_sv_auth_forward {
            get_current_auth,
            reset_current_auth,
            set_current_auth
        },
    ]
    runtime.context.log_emit ++> [
        server.extensions.ObservabilityExtension.register {
            install_structured_logging
        },
        tests.misc.test_log_emit {
            _JacJsonFormatter,
            emit_log_record,
            install_structured_logging
        },
    ]
    runtime.context.service_routing ++> [
        config.plugin_config | deploy.autoscale.keda_autoscaler {
            KEDA_INTERCEPTOR_SERVICE_ADDRESS
        },
        deploy.autoscale.http_activation_config.build_http_activation_spec {
            k8s_service_dns_host
        },
        deploy.target.kubernetes.manifest_builder { resolve_http_activation_config },
        deploy.target.kubernetes.runtime_resolver {
            ServiceRoute,
            resolve_service_route
        },
        deploy.target.kubernetes.target { resolve_interceptor_service_address },
        tests.deploy.test_service_routing {
            KEDA_INTERCEPTOR_SERVICE_ADDRESS,
            k8s_service_dns_host,
            resolve_http_activation_config,
            resolve_interceptor_service_address,
            resolve_service_route
        },
    ]
    runtime.context.service_routing --> [
        deploy.autoscale.factory.AutoscalerFactory.create {
            resolve_interceptor_service_address
        },
        tests.server.test_sv_auth_forward { ServiceRoute },
    ]
    runtime.context.trace_ctx ++> [
        server.extensions.ObservabilityExtension.register {
            ensure_trace_id,
            reset_current_trace,
            set_current_trace
        },
        tests.misc.test_log_emit {
            install_trace_log_filter,
            reset_current_trace,
            set_current_trace
        },
    ]
    runtime.context.trace_ctx --> [
        tests.misc.test_log_emit { TraceIdLogFilter },
        tests.server.test_sv_auth_forward {
            ensure_trace_id,
            get_current_trace,
            reset_current_trace,
            set_current_trace
        },
    ]
    runtime.context.tracing ++> [
        admin.ops { tracing_active },
        server.extensions.ObservabilityExtension.register {
            end_span,
            install_tracing,
            start_server_span,
            tracing_installed
        },
        tests.misc.test_tracing {
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
        },
    ]
    runtime.context.util ++> [
        admin.console_build.build_with_jac
            | deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_client_bundle
            | tests.deploy.test_client_build_deps
            | tests.deploy.test_client_build_fail_fast
            | tests.deploy.test_client_build_stage
            | tests.deploy.test_dry_run_plan_rate_limit
            | tests.server.test_acl_field_write._prewarm
            | tests.server.test_app_tokens._prewarm
            | tests.server.test_metrics_workers._serve_exported
            | tests.server.test_root_bind_fail_closed._prewarm
            | tests.server.test_serve
            | tests.support.start_server { jac_executable },
        admin.k8s_ops
            | deploy.target.kubernetes.runtime_resolver.build_k8s_registry_routes {
            in_cluster_namespace
        },
        deploy.target.kubernetes.database_provisioner
            | deploy.target.kubernetes.ops_rbac
            | sdk.client { k8s_safe_name },
        deploy.target.kubernetes.manifest_builder
            | deploy.target.kubernetes.target
            | tests.deploy.test_gateway_config_isolation {
            GATEWAY_NAME,
            k8s_safe_name
        },
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._peer_dns_url {
            k8s_service_dns_url
        },
        deploy.target.kubernetes.runtime_resolver { DEFAULT_GATEWAY_PORT },
        tests.deploy.test_deployment_overlay
            | tests.deploy.test_destroy_reclaim
            | tests.deploy.test_http_activation_microservices
            | tests.deploy.test_memory_trigger_guard
            | tests.deploy.test_ops_rbac
            | tests.deploy.test_pod_env { GATEWAY_NAME },
    ]
    runtime.context.util --> [
        tests.apps.test_app_scale_overrides {
            boot_health_timeout,
            http_forward_timeout
        },
        tests.microservices.test_gateway { http_forward_timeout },
        tests.microservices.test_k8s_health_probe
            | tests.server.test_examples.JacScaleTestRunner.start_server
            | tests.server.test_metrics_workers { jac_executable },
    ]
    runtime.fleet ++> [
        deploy.target.kubernetes.manifest_builder {
            FleetSpec,
            fleet_from_config,
            solo_fleet
        },
        deploy.target.kubernetes.manifest_builder.ManifestBuilder._build_env {
            FLEET_ENV
        },
        deploy.target.kubernetes.target | injector.bundle { FleetSpec },
        plugin._fleet_cmd { fleet_from_config, fleet_from_env },
        plugin._print_local_fleet_banner { format_fleet_lines },
        plugin.scale_local_serve { fleet_from_plans },
        tests.apps.test_app_scale_overrides { fleet_from_config },
        tests.apps.test_fleet_from_apps {
            FLEET_ENV,
            ROOT_PREFIX,
            consumer_provider_edges,
            fleet_from_config,
            fleet_from_env,
            fleet_of,
            guard_fleet_routes,
            order_by_edges,
            solo_fleet
        },
        tests.deploy.test_access_hint
            | tests.deploy.test_deploy_banner
            | tests.deploy.test_deployment_overlay
            | tests.deploy.test_dry_run_purity
            | tests.deploy.test_http_activation_microservices
            | tests.deploy.test_memory_trigger_guard
            | tests.deploy.test_ops_rbac
            | tests.deploy.test_pdb_budget
            | tests.deploy.test_show_yaml_autoscalers { fleet_of },
        tests.deploy.test_pod_env { FLEET_ENV, fleet_of },
        tests.microservices.test_bundle_jacignore { solo_fleet },
    ]
    runtime.fleet --> [
        admin.logs._fleet_names | admin.traces._trace_services { fleet_member_names },
        tests.apps.test_fleet_from_apps { _compiled_app_edges },
        tests.deploy.test_client_build_stage { FleetMember, FleetSpec },
        tests.microservices.test_app_precompile { fleet_from_config, solo_fleet },
    ]
    runtime.gateway.dispatch ++> [
        tests.apps.test_fleet_from_apps { ROUTE_PROXY, classify_route },
        tests.microservices.test_dispatch {
            ROUTE_ADMIN,
            ROUTE_PROXY,
            ROUTE_STATIC,
            classify_route
        },
        tests.microservices.test_gateway_docs_precedence {
            ROUTE_BUILTIN,
            ROUTE_CLIENT_PAGE,
            classify_route
        },
    ]
    runtime.gateway.embedded_gateway ++> tests.microservices.test_embedded_gateway {
        EmbeddedGateway
    }
    runtime.gateway.microservice_gateway ++> tests.apps.test_fleet_from_apps
        | tests.microservices.test_app_routes
        | tests.microservices.test_gateway
        | tests.microservices.test_gateway_docs_precedence
        | tests.microservices.test_gateway_webapp
        | tests.microservices.test_k8s_health_probe
        | tests.server.test_static_fallback { MicroserviceGateway }
    runtime.gateway.microservice_gateway --> tests.server.test_stream_ws {
        MicroserviceGateway
    }
    runtime.gateway.openapi_agg ++> tests.microservices.test_openapi_agg {
        _agg_logger,
        aggregate_openapi
    }
    runtime.gateway.openapi_agg --> tests.microservices.test_gateway { _prefixed_paths }
    runtime.gateway.route_table ++> [
        tests.microservices.test_app_routes { ServiceRouteTable, literal_prefix },
        tests.microservices.test_gateway.gw_route_table_for_poison_test
            | tests.microservices.test_route_learning { ServiceRouteTable },
    ]
    runtime.gateway.service_registry ++> [
        deploy.target.kubernetes.runtime_resolver
            | tests.deploy.test_deployer
            | tests.deploy.test_pod_env
            | tests.microservices.test_embedded_gateway
            | tests.microservices.test_stop_signal_scope {
            ServiceEntry,
            ServiceRegistry
        },
        tests.apps.test_fleet_from_apps
            | tests.microservices.test_app_routes
            | tests.microservices.test_boot_grace
            | tests.microservices.test_boot_order
            | tests.microservices.test_gateway
            | tests.microservices.test_gateway_webapp
            | tests.microservices.test_k8s_health_probe
            | tests.microservices.test_microservices_registry
            | tests.microservices.test_openapi_agg {
            ServiceEntry,
            ServiceRegistry,
            ServiceStatus
        },
        tests.microservices.test_gateway_docs_precedence
            | tests.server.test_static_fallback { ServiceRegistry },
        tests.microservices.test_route_learning { ServiceEntry, ServiceStatus },
    ]
    runtime.gateway.service_registry --> tests.server.test_stream_ws {
        ServiceEntry,
        ServiceRegistry,
        ServiceStatus
    }
    runtime.middleware.metrics --> tests.microservices.test_gateway {
        build_gateway_metrics,
        classify_outcome
    }
    runtime.middleware.middleware ++> [
        tests.microservices.test_embedded_gateway { Middleware },
        tests.microservices.test_middleware { Middleware, MiddlewareRegistry },
    ]
    runtime.middleware.rate_limit ++> tests.microservices.test_rate_limit {
        InProcessRateLimiter,
        StateBackendRateLimiter,
        build_rate_limit_middleware
    }
    runtime.middleware.ws_forward ++> tests.server.test_stream_ws {
        _select_handshake_headers,
        _to_ws_scheme,
        websocket_forward
    }
    runtime.orchestrator.local_deployer ++> plugin._fleet_cmd
        | tests.deploy.test_deployer { LocalDeployer }
    runtime.orchestrator.orchestrator ++> [
        plugin._fleet_cmd { ServiceRegistry, build_registry },
        tests.apps.test_fleet_from_apps { build_registry },
    ]
    runtime.orchestrator.orchestrator --> plugin._fleet_cmd { start_gateway_only }
    runtime.orchestrator.process_manager ++> [
        tests.microservices.test_boot_grace
            | tests.microservices.test_boot_order
            | tests.microservices.test_k8s_health_probe { ServiceProcessManager },
        tests.microservices.test_stop_signal_scope {
            ServiceProcessManager,
            _owns_group,
            _signal_group
        },
        tests.support.stop_server { _signal_group },
    ]
    runtime.planner.planner ++> tests.microservices.test_planner { plan_realization }
    runtime.provider ++> [
        plugin | server.inprocess.prepare_inprocess_runtime { mark_scale_runtime },
        tests.server.test_sv_auth_forward | tests.server.test_sv_streaming {
            JacScaleRuntime
        },
    ]
    runtime.provider as provider_mod --> tests.server.test_sv_auth_forward;
    runtime.realizer.kubernetes_realizer ++> [
        tests.deploy.test_deploy_banner | tests.deploy.test_dry_run_purity {
            KubernetesRealizer
        },
        tests.deploy.test_version_pin {
            DELEGATED_ENV,
            KubernetesRealizer,
            pinned_deploy_argv
        },
    ]
    runtime.realizer.kubernetes_realizer --> plugin.scale_deploy { KubernetesRealizer }
    runtime.realizer.kubernetes_realizer as realizer_mod ++> tests.deploy.test_deploy_banner
        | tests.deploy.test_dry_run_purity;
    runtime.realizer.local_realizer ++> plugin.scale_local_serve { LocalRealizer }
    runtime.routing ++> [
        admin.admin_portal._classify_path { GATEWAY_WELLKNOWN_SEGMENTS },
        tests.microservices.test_routing_guard {
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
        },
    ]
    runtime.rpc.breaker --> tests.server.test_sv_auth_forward {
        _BREAKER_TRIP_THRESHOLD,
        _breaker_force_cooldown_elapsed,
        _breaker_peek,
        _breaker_reset,
        breaker_record_failure,
        breaker_record_success,
        breaker_should_skip
    }
    runtime.rpc.rpc --> [
        tests.apps.test_app_scale_overrides { _sv_rpc_timeout },
        tests.server.test_sv_auth_forward { _RPC_MAX_ATTEMPTS, _sv_rpc_timeout },
    ]
    runtime.rpc.rpc as rpc_mod ++> tests.server.test_sv_auth_forward;
    runtime.transport.http_forward ++> tests.server.test_stream_ws {
        raw_forward,
        stream_forward
    }
    runtime.transport.transport ++> tests.microservices.test_embedded_gateway {
        InProcessTransport
    }
    scheduler.scheduler ++> [
        server.jobs_ext { JacScaleScheduler, TriggerSpec },
        tests.server.test_pg_job_store { PgJobStore },
        tests.server.test_scheduler_endpoints { MemoryJobStore, TriggerSpec },
        tests.server.test_scheduler_multipod {
            JOBS_CHANGED_CHANNEL,
            JacScaleScheduler,
            PgJobStore,
            TriggerSpec,
            new_engine
        },
    ]
    scheduler.scheduler --> tests.misc.test_optional_deps {
        JacScaleScheduler,
        TriggerSpec
    }
    scheduler.scheduler_models ++> server.jobs_ext {
        CreateJobRequest,
        UpdateJobRequest
    }
    sdk ++> [
        tests.deploy.sdk_deploy_driver { ProgressEvent, ScaleClient, deploy },
        tests.deploy.test_superseded_deployment_reap {
            AutoscalerRuntimeStatus,
            AutoscalerTransition,
            ScaleClient
        },
    ]
    sdk.client ++> sdk { ScaleClient, deploy }
    sdk.events ++> sdk { EventLogger }
    sdk.spec ++> sdk { DeploySpec }
    server.extensions ++> [
        runtime.provider.JacScaleRuntime.get_server_extensions { scale_extensions },
        tests.data.test_gateway_owned_identity { fleet_provisions_unknown_users },
        tests.server.test_auth_policy_startup { AdminExtension, MailExtension },
    ]
    server.extensions --> [
        tests.server.test_admin { AdminExtension },
        tests.server.test_scheduler_multipod {
            validate_events_url as _validate_events_url
        },
    ]
    server.inprocess ++> tests.scale_test_client.ScaleTestClient._initialize {
        prepare_inprocess_runtime
    }
    server.inprocess --> tests.server.test_host_serving { prepare_inprocess_runtime }
    server.jobs_ext ++> tests.server.test_scheduler_endpoints { _err_response }
    server.sso_ext ++> [
        tests.server.test_firebase_auth_sso { SSOExtension },
        tests.server.test_sso { SSOExtension, resolve_sso_client_redirect },
    ]
    shared.enums ++> sso.sso_auth | tests.server.test_firebase_auth_sso {
        Operations,
        Platforms
    }
    shared.utils ++> server.sso_ext | sso.sso_auth | tests.server.test_sso {
        is_safe_loopback_redirect
    }
    sso.apple ++> tests.server.test_oauth_providers | tests.server.test_sso {
        AppleSSOProvider
    }
    sso.firebase --> tests.server.test_firebase_auth_sso { FirebaseSSOProvider }
    sso.github ++> tests.server.oauth_fixtures
        | tests.server.test_oauth_providers
        | tests.server.test_oauth_session
        | tests.server.test_sso { GithubSSOProvider }
    sso.google ++> tests.server.test_oauth_providers
        | tests.server.test_sso
        | tests.server.test_sso_grants { GoogleSSOProvider }
    sso.grants ++> [
        server.sso_ext { connections_for, disconnect_for, register_sso },
        tests.server.test_sso_grants {
            REFRESH_LEASE_SECONDS,
            REFRESH_REQUEST_SECONDS,
            _grant_context,
            _grant_secret,
            access_token_for,
            connections_for,
            disconnect_for,
            grant_from_tokens,
            register_sso,
            seal_secret,
            sso_access_token,
            unseal_secret
        },
    ]
    sso.oauth_session ++> [
        server.sso_ext { OAuthSession },
        tests.server.test_oauth_session {
            OAuthSession,
            challenge_of,
            complete_identity
        },
        tests.server.test_registration_challenge { complete_identity },
        tests.server.test_sso_grants { OAuthSession, challenge_of },
    ]
    sso.provider ++> [
        server.sso_ext { OAuth2CodeProvider },
        tests.server.test_firebase_auth_sso
            | tests.server.test_oauth_session
            | tests.server.test_registration_challenge
            | tests.server.test_sso { SSOUserInfo },
        tests.server.test_sso_grants { GrantRefused, SSOUserInfo },
    ]
    sso.sso_auth ++> server.sso_ext
        | tests.server.test_firebase_auth_sso
        | tests.server.test_sso
        | tests.server.test_sso_grants { SSOAuth }
    state.factory ++> [
        runtime.middleware.rate_limit { get_state_backend },
        tests.microservices.test_rate_limit._reset_state { _backend_holder },
        tests.misc.test_state_backend_selection { get_state_backend, in_fleet },
    ]
    state.factory as factory_mod ++> tests.misc.test_state_backend_selection;
    state.state_backend ++> [
        runtime.middleware.rate_limit { InProcessStateBackend, StateBackend },
        tests.microservices.test_rate_limit | tests.misc.test_state_backend_selection {
            InProcessStateBackend
        },
    ]
    storage.factory ++> runtime.provider.JacScaleRuntime.store
        | tests.data.test_firebase_env { StorageFactory }
    storage.gcs_storage ++> tests.data.test_gcs_storage { GcsStorage }
    storage.s3_storage ++> tests.data.test_s3_storage { S3Storage }
    utils.vendor_wheels ++> tests.microservices.test_fat_bundle {
        POD_GLIBC,
        pod_arch_from_argv,
        pod_wheel_target
    }
    utils.vendor_wheels --> injector.bundle._vendor_stage { pod_wheel_target }
    webhook.webhook ++> [
        server.sso_ext | tests.server.test_pg_job_store { ApiKeyManager },
        server.webhook_ext { ApiKeyManager, WebhookUtils, rate_window_ok },
    ]
    websocket.backplane ++> [
        server.websocket_ext { MemoryBackplane, build_backplane },
        tests.server.test_backplane { PgBackplane },
        tests.server.test_ws_hardening {
            BaseBackplane,
            MemoryBackplane,
            build_backplane
        },
    ]
    websocket.backplane --> tests.server.test_ws_hardening { PgBackplane }
    websocket.protocol ++> [
        server.websocket_ext {
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
        },
        tests.server.test_ws_hardening { ws_handle_control, ws_heartbeat_loop },
    ]
    websocket.websocket ++> [
        server.websocket_ext {
            ConnectionContext,
            WebSocketConnectionManager,
            _ws_stream_result
        },
        tests.server.test_ws_hardening {
            ConnectionContext,
            WebSocketConnectionManager
        },
    ]
}

graph import scale._optdeps {
    optional_deps ++> [
        gcs { require_optional },
        opentelemetry { is_optional_available },
    ]
}

graph import scale.admin {
    console_build ++> admin_portal { AdminConsole, resolve_console }
    k8s_ops ++> [
        deploy_health {
            api_error_detail,
            apps_api,
            core_api,
            k8s_available,
            ops_namespace,
            unavailable_detail
        },
        network {
            api_error_detail,
            core_api,
            k8s_available,
            networking_api,
            ops_namespace,
            unavailable_detail
        },
        podenv {
            api_error_detail,
            core_api,
            k8s_available,
            ops_namespace,
            unavailable_detail
        },
    ]
    logs ++> ops { _app_namespace, _loki_base_url }
    service_urls ++> logs | ops | traces { service_base_url }
    traces ++> ops { _tempo_base_url }
    workload_helpers ++> workloads { match_owner, owner_name_from_pod, phase_to_status }
}

graph import scale.config {
    firebase_env ++> config_loader {
        FIREBASE_AUTH_PROJECT_ID_ENV,
        resolve_firebase_project_id
    }
    plugin_config ++> [
        config_loader.JacScaleConfig.get_app_config_schema { app_scale_schema },
        validation { JacScalePluginConfig, app_scale_schema },
    ]
    validation ++> [
        config_loader.JacScaleConfig.get_config_schema { scale_schema_options },
        config_loader.JacScaleConfig.get_config_strict_env { STRICT_ENV },
        config_loader.JacScaleConfig.get_scheduler_config {
            scheduler_job_cap,
            scheduler_min_interval
        },
    ]
    validation --> config_loader.app_scale_overrides {
        STRICT_ENV,
        validate_app_scale_config
    }
}

graph import scale.deploy {
    autoscale.autoscaler ++> target.kubernetes.target {
        AutoscalerSpec,
        Trigger,
        TriggerAuth
    }
    autoscale.factory ++> target.kubernetes.target { AutoscalerFactory }
    autoscale.http_activation_config ++> [
        target.kubernetes.manifest_builder { build_http_activation_spec },
        target.kubernetes.target {
            apply_http_activation_for_target,
            destroy_http_activation_for_target
        },
    ]
    autoscale.keda_autoscaler ++> target.kubernetes.target { KEDAAutoscaler }
    database.kubernetes_postgres ++> target.kubernetes.kubernetes_target {
        KubernetesPostgresProvider
    }
    target.deployment_target ++> database.kubernetes_postgres { DeploymentTarget }
    target.kubernetes.kubernetes_config ++> database.kubernetes_postgres.KubernetesPostgresProvider._requested_mode {
        resolve_database_mode
    }
    target.kubernetes.manifest_builder ++> autoscale.autoscaler.Autoscaler._build_behavior {
        merge_manifest_overlay
    }
    target.kubernetes.utils.kubernetes_utils ++> autoscale.hpa_autoscaler {
        delete_if_exists
    }
}

graph import scale.deploy.autoscale {
    autoscaler ++> [
        factory { Autoscaler },
        hpa_autoscaler {
            Autoscaler,
            AutoscalerRuntimeStatus,
            AutoscalerSpec,
            DEFAULT_CPU_UTILIZATION_TARGET,
            DEFAULT_MEMORY_UTILIZATION_TARGET,
            RESOURCE_ONLY_TRIGGER_TYPES,
            condition,
            normalize_conditions,
            tristate
        },
        keda_autoscaler {
            Autoscaler,
            AutoscalerRuntimeStatus,
            AutoscalerSpec,
            AutoscalerTransition,
            DEFAULT_CPU_UTILIZATION_TARGET,
            DEFAULT_MEMORY_UTILIZATION_TARGET,
            Trigger,
            condition,
            normalize_conditions,
            transition_from,
            tristate
        },
    ]
    hpa_autoscaler --> factory.AutoscalerFactory.create { HPAAutoscaler }
    http_activation ++> [
        http_activation_config {
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
        },
        keda_autoscaler { HTTPActivationSpec, HTTPRoutingRule },
    ]
    keda_autoscaler ++> http_activation_config { KEDAAutoscaler }
    keda_autoscaler --> factory.AutoscalerFactory.create { KEDAAutoscaler }
    keda_capabilities ++> keda_autoscaler {
        KEDACapabilities,
        SUPPORTED_HTTP_INTERCEPTOR_API_VERSIONS
    }
}

graph import scale.deploy.target {
    deployment_target ++> factory | kubernetes.kubernetes_target { DeploymentTarget }
    type deployment_target ++> registry { DeploymentTarget }
    kubernetes.kubernetes_config --> factory.DeploymentTargetFactory.create {
        KubernetesConfig
    }
    kubernetes.target --> factory.DeploymentTargetFactory.create { KubernetesTarget }
    registry ++> factory { DeploymentTargetRegistry }
    service_deployer ++> kubernetes.runtime_resolver { ServiceDeployer }
}

graph import scale.deploy.target.kubernetes {
    cluster_provider ++> [
        ingress | monitoring { ClusterProvider },
        utils.kubernetes_utils { AWSProvider, ClusterProvider, LocalProvider },
    ]
    database_provisioner ++> target { DatabaseProvisioner }
    ingress ++> kubernetes_target { IngressDeployer }
    kubernetes_config ++> ingress
        | kubernetes_target
        | manifest_builder
        | monitoring
        | runtime_bootstrap
        | target { KubernetesConfig }
    kubernetes_target ++> target { KubernetesTargetBase }
    manifest_builder ++> target {
        CONFIG_REVISION_ANNOTATION,
        ManifestBuilder,
        ScalingMode,
        with_config_revision
    }
    monitoring ++> target { MonitoringDeployer }
    ops_rbac ++> [
        manifest_builder { ops_sa_name },
        target { ops_sa_is_ours, ops_sa_name },
    ]
    ops_rbac --> manifest_builder.ManifestBuilder.generate_manifests { build_ops_rbac }
    runtime_bootstrap ++> [
        manifest_builder.ManifestBuilder._build_pod_spec {
            build_bootstrap_init_container,
            image_pull_policy,
            runtime_container_env
        },
        manifest_builder.ManifestBuilder._pod_entrypoint { build_service_apt_prefix },
    ]
    utils.kubernetes_utils ++> [
        database_provisioner { ensure_namespace_exists },
        ingress { KubectlCluster, delete_if_exists },
        kubernetes_target {
            COMPANION_DEFS,
            KubectlCluster,
            create_k8s_secret,
            get_cluster_provider,
            resize_pvc_if_needed
        },
        kubernetes_target.KubernetesTargetBase._load_cluster_config {
            in_cluster_kubectl,
            kubectl_cluster
        },
        monitoring { delete_if_exists, delete_k8s_secret },
        target {
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
            privileged_pss_labels,
            resolve_minted_secret
        },
        target.KubernetesTarget._apply_or_replace_pvc { wait_until_deleted },
        target.KubernetesTarget._pod_failure_detail { describe_pod_status },
    ]
}

graph import scale.emailer {
    emailer ++> [
        emailers { EmailAttachment, Emailer, MAX_HEADER_LINE },
        factory { Emailer },
    ]
    emailers --> factory.create { SMTPEmailer }
}

graph import scale.events {
    broker ++> [
        publisher { Event, EventStreamBroker },
        streams._stream_common | subscriber { Event, RetryPolicy, StreamPosition },
        streams.local | streams.postgres {
            Event,
            EventStreamBroker,
            HealthStatus,
            RetryPolicy,
            StreamPosition,
            starts_at_earliest
        },
    ]
}

graph import scale.events.streams {
    _stream_common ++> local { consumer_loop, wait_or_stop }
}

graph import scale.injector {
    binary ++> binary_injector {
        download_release_binary,
        host_seal_platform,
        node_arch,
        pack_binary_bytes,
        read_local_binary,
        resolve_console_version,
        resolve_deploy_version,
        stage_admin_dist,
        toolchain_object_key
    }
    bundle ++> [
        binary { TOOLCHAIN_SUBDIR },
        binary_injector { bundle_object_key, content_address },
        pvc_injector {
            APP_MOUNT_PATH,
            APP_VOLUME_NAME,
            bundle_object_key,
            content_address,
            ensure_jac_toml_cmd,
            pack_jab
        },
    ]
    injector ++> pvc_injector { Injector }
    pvc_injector ++> binary_injector { PvcInjector, bundle_pvc_path }
}

graph import scale.observability {
    logger ++> factory | standard_logger { Logger }
    metrics ++> [
        factory { MetricsCollector, NoOpMetricsCollector },
        prometheus_metrics { MetricsCollector },
    ]
    prometheus_metrics --> factory.UtilityFactory.create_metrics {
        PrometheusMetricsCollector
    }
    standard_logger --> factory.UtilityFactory.create_logger { StandardLogger }
}

graph import scale.runtime {
    cli.diagnostics --> realizer.kubernetes_realizer.KubernetesRealizer.realize {
        has_errors
    }
    cli.plan --> realizer.kubernetes_realizer.KubernetesRealizer.realize { print_plan }
    context.auth_ctx ++> rpc.rpc._rpc_headers { get_current_auth }
    context.errors ++> [
        gateway.microservice_gateway.MicroserviceGateway.forward_to {
            bad_gateway,
            gateway_timeout,
            service_unavailable
        },
        gateway.microservice_gateway.MicroserviceGateway.handle_metrics
            | middleware.rate_limit.build_rate_limit_middleware { error_response },
        gateway.microservice_gateway.MicroserviceGateway.merge_graph_pages {
            not_found
        },
        gateway.microservice_gateway.MicroserviceGateway.probe_services { not_found },
    ]
    context.errors --> [
        gateway.microservice_gateway.MicroserviceGateway.deliver_once { not_found },
        gateway.microservice_gateway.MicroserviceGateway.forward_root_path {
            service_unavailable
        },
        gateway.microservice_gateway.MicroserviceGateway.forward_to_root {
            service_unavailable
        },
        gateway.microservice_gateway.MicroserviceGateway.handle_builtin_passthrough {
            not_found
        },
        gateway.microservice_gateway.MicroserviceGateway.probe_services {
            gateway_timeout,
            service_unavailable
        },
        gateway.microservice_gateway.MicroserviceGateway.setup.dispatcher { not_found },
    ]
    context.log_emit ++> gateway.microservice_gateway.MicroserviceGateway.setup {
        install_structured_logging
    }
    context.service_routing --> rpc.rpc._sv_rpc_timeout {
        HTTP_ACTIVATED_WAKE_TIMEOUT,
        is_http_activated
    }
    context.trace_ctx ++> [
        gateway.microservice_gateway.MicroserviceGateway.build_forward_headers {
            ensure_trace_id,
            get_current_trace
        },
        gateway.microservice_gateway.MicroserviceGateway.setup {
            ensure_trace_id,
            reset_current_trace,
            set_current_trace
        },
        rpc.rpc._rpc_headers { get_current_trace },
    ]
    context.tracing ++> [
        gateway.microservice_gateway.MicroserviceGateway.build_forward_headers
            | rpc.rpc._rpc_headers { current_traceparent },
        gateway.microservice_gateway.MicroserviceGateway.setup {
            end_span,
            install_tracing,
            start_server_span
        },
    ]
    context.util ++> [
        cli.diagnostics | cli.plan { GATEWAY_NAME },
        gateway.embedded_gateway
            | gateway.microservice_gateway
            | gateway.process_gateway {
            DEFAULT_CLIENT_DIST_DIR,
            DEFAULT_GATEWAY_HOST,
            DEFAULT_GATEWAY_PORT
        },
        gateway.microservice_gateway.MicroserviceGateway.forward_to {
            http_forward_timeout
        },
        gateway.microservice_gateway.MicroserviceGateway.merge_graph_pages {
            http_forward_timeout
        },
        gateway.microservice_gateway.MicroserviceGateway.probe_services {
            http_forward_timeout
        },
        gateway.microservice_gateway.MicroserviceGateway.refresh_app_routes {
            route_refresh_seconds
        },
        orchestrator.orchestrator { DEFAULT_GATEWAY_HOST, DEFAULT_GATEWAY_PORT },
        orchestrator.process_manager.ServiceProcessManager._assign_free_port {
            pick_free_port
        },
        orchestrator.process_manager.ServiceProcessManager._assign_port {
            pick_free_port
        },
        orchestrator.process_manager.ServiceProcessManager._await_lead {
            wait_for_health
        },
        orchestrator.process_manager.ServiceProcessManager.start_service {
            jac_executable
        },
    ]
    fleet ++> [
        cli.plan | realizer.local_realizer { FleetSpec },
        orchestrator.orchestrator { FleetSpec, ROOT_PREFIX },
        realizer.kubernetes_realizer {
            FleetSpec,
            fleet_from_config,
            format_fleet_lines
        },
    ]
    fleet --> provider.JacScaleRuntime.get_sv_service_routes { fleet_from_env }
    gateway.process_gateway ++> orchestrator.orchestrator { ProcessGateway }
    gateway.service_registry ++> orchestrator.local_deployer
        | orchestrator.orchestrator
        | orchestrator.process_manager { ServiceEntry, ServiceRegistry, ServiceStatus }
    middleware.metrics ++> [
        gateway.microservice_gateway.MicroserviceGateway.handle_metrics {
            render_metrics
        },
        gateway.microservice_gateway.MicroserviceGateway.setup {
            build_gateway_metrics
        },
    ]
    middleware.metrics --> gateway.microservice_gateway.MicroserviceGateway.setup.dispatcher {
        classify_outcome
    }
    middleware.middleware ++> [
        gateway.gateway { MiddlewareRegistry },
        gateway.microservice_gateway.MicroserviceGateway.setup {
            Middleware,
            MiddlewareRegistry
        },
    ]
    middleware.rate_limit ++> gateway.microservice_gateway.MicroserviceGateway.setup {
        build_client_error_limit_middleware,
        build_rate_limit_middleware,
        client_error_limit_skipped
    }
    middleware.ws_forward ++> gateway.microservice_gateway._install_ws_catchall {
        websocket_forward
    }
    orchestrator.orchestrator ++> realizer.local_realizer { start_fleet_mode }
    planner.planner ++> realizer.local_realizer {
        TOPOLOGY_MICROSERVICE,
        plan_realization
    }
    provider ++> rpc.rpc._resolve_call_target { JacScaleRuntime }
    provider --> orchestrator.orchestrator._populate_k8s_urls { JacScaleRuntime }
    routing ++> [
        fleet { guard_route_prefix },
        gateway.dispatch {
            GATEWAY_API_SEGMENTS,
            GATEWAY_LISTING_SEGMENTS,
            GATEWAY_PAGE_SEGMENTS,
            GATEWAY_WELLKNOWN_SEGMENTS
        },
        gateway.microservice_gateway {
            GATEWAY_BARE_API_PATHS,
            GATEWAY_BUILTIN_PREFIXES,
            GATEWAY_DISCOVERY_SEGMENTS,
            GATEWAY_REPLICATED_SEGMENTS
        },
        gateway.route_table.ServiceRouteTable.learn { is_learnable_prefix },
    ]
    rpc.rpc ++> [
        transport.transport.HttpTransport.call_function { service_call },
        transport.transport.HttpTransport.call_walker { walker_call },
    ]
    transport.http_forward ++> [
        gateway.microservice_gateway.MicroserviceGateway.forward_to { stream_forward },
        gateway.microservice_gateway.MicroserviceGateway.merge_graph_pages
            | gateway.openapi_agg.fetch_service_spec { raw_forward },
        gateway.microservice_gateway.MicroserviceGateway.probe_services {
            stream_forward
        },
    ]
    transport.transport ++> [
        gateway.embedded_gateway { ServiceTransport },
        provider.JacScaleRuntime.sv_service_call { http_transport },
        provider.JacScaleRuntime.sv_walker_call { http_transport },
    ]
}

graph import scale.runtime.cli {
    _narrow ++> [
        diagnostics { bget, dget, effective_resources, iget, lget, pod_spec, sget },
        plan { dget, fget, iget, lget, pod_spec, sget },
    ]
    diagnostics ++> plan { Diagnostic, PlanValidator }
}

graph import scale.runtime.context {
    service_routing --> util.http_forward_timeout {
        HTTP_ACTIVATED_WAKE_TIMEOUT,
        is_http_activated
    }
    trace_ctx ++> errors.error_response { get_current_trace }
    trace_ctx --> log_emit.install_structured_logging { install_trace_log_filter }
    util ++> service_routing { k8s_safe_name, k8s_service_dns_host }
}

graph import scale.runtime.gateway {
    dispatch ++> embedded_gateway { ROUTE_PROXY, classify_route }
    dispatch --> microservice_gateway.MicroserviceGateway.setup.dispatcher {
        ROUTE_ADMIN,
        ROUTE_BUILTIN,
        ROUTE_CLIENT_PAGE,
        ROUTE_IDENTITY,
        ROUTE_PROXY,
        classify_route
    }
    gateway ++> embedded_gateway | process_gateway { Gateway }
    microservice_gateway ++> process_gateway { MicroserviceGateway }
    openapi_agg ++> [
        microservice_gateway.MicroserviceGateway.handle_openapi { aggregate_openapi },
        route_table.learn_service_routes { SpecFetch, fetch_service_spec },
    ]
    route_table ++> [
        microservice_gateway { ServiceRouteTable },
        microservice_gateway.MicroserviceGateway.refresh_app_routes {
            learn_service_routes
        },
    ]
    service_registry ++> [
        embedded_gateway | process_gateway { ServiceRegistry },
        microservice_gateway | route_table {
            ServiceEntry,
            ServiceRegistry,
            ServiceStatus
        },
        microservice_gateway._install_ws_catchall { ServiceStatus },
        openapi_agg { ServiceEntry, ServiceRegistry },
    ]
}

graph import scale.runtime.orchestrator {
    local_deployer ++> orchestrator { LocalDeployer }
    process_manager ++> [
        local_deployer | orchestrator { ServiceProcessManager },
        local_deployer.LocalDeployer.status {
            _pid_alive,
            _read_pidfile,
            _read_portfile
        },
    ]
}

graph import scale.runtime.rpc {
    breaker ++> rpc {
        _BREAKER_COOLDOWN_SECONDS,
        breaker_record_failure,
        breaker_record_success,
        breaker_should_skip
    }
}

graph import scale.scheduler {
    fire_executor ++> scheduler.new_engine { FireTimeExecutor }
}

graph import scale.sdk {
    events ++> client { EventLogger }
    spec ++> client { DeploySpec }
}

graph import scale.server {
    jobs_ext ++> extensions { JobsExtension }
    sso_ext ++> extensions { ApiKeyExtension, SSOExtension }
    webhook_ext ++> extensions { WebhookExtension }
    websocket_ext ++> extensions { WebSocketExtension }
}

graph import scale.sso {
    apple --> sso_auth.SSOAuth.get_sso { AppleSSOProvider }
    firebase --> sso_auth.SSOAuth.get_sso { FirebaseSSOProvider }
    github --> sso_auth.SSOAuth.get_sso { GithubSSOProvider }
    google --> sso_auth.SSOAuth.get_sso { GoogleSSOProvider }
    grants ++> oauth_session { grant_from_tokens }
    oauth_session ++> sso_auth {
        OAuthLogin,
        OAuthSession,
        challenge_of,
        complete_identity
    }
    provider ++> [
        apple { OAuth2CodeProvider, SSOUserInfo, decode_jwt_payload_unverified },
        firebase { SSOProvider, SSOUserInfo },
        github | google | oauth_session { OAuth2CodeProvider, SSOUserInfo },
        grants { GrantRefused, OAuth2CodeProvider },
        sso_auth { OAuth2CodeProvider, SSOProvider, SSOUserInfo },
    ]
    type sso_auth ++> grants { SSOAuth }
}

graph import scale.state {
    pg_state_backend ++> factory { PgStateBackend }
    state_backend ++> [
        factory { InProcessStateBackend, StateBackend },
        pg_state_backend { StateBackend },
    ]
}

graph import scale.storage {
    bucket_storage ++> gcs_storage | s3_storage { BucketStorage }
    gcs_storage --> factory.StorageFactory.create { GcsStorage }
    s3_storage --> factory.StorageFactory.create { S3Storage }
}

graph import scale.tests {
    fixture_policy ++> [
        scale_test_client { ADMIN_BOOTSTRAP_PASSWORD, apply_fixture_policy },
        support { apply_fixture_policy },
    ]
    scale_test_client ++> [
        microservices.test_app_routes { ScaleTestClient, make_client },
        server.test_admin {
            ADMIN_BOOTSTRAP_PASSWORD,
            extract_data,
            fresh_totp_code,
            make_client,
            wrong_totp_code
        },
        server.test_admin_workloads
            | server.test_error_envelope
            | server.test_file_upload
            | server.test_firebase_auth_sso
            | server.test_middleware_async_root { extract_data, make_client },
        server.test_auth_policy_http
            | server.test_health_fail_soft
            | server.test_ws_functions
            | server.test_ws_hardening { make_client },
        server.test_restspec | server.test_webhook {
            ScaleTestClient,
            extract_data,
            make_client
        },
        server.test_scheduler_endpoints { ScaleTestClient },
        server.test_serve {
            ScaleTestClient,
            extract_data,
            fresh_totp_code,
            make_client,
            totp_code,
            wrong_totp_code
        },
    ]
    scale_test_client --> [
        microservices.test_gateway { extract_data, make_client },
        misc.test_llm_telemetry { make_client },
        misc.test_metrics { ScaleTestClient },
        server.test_oauth_session { fresh_totp_code },
    ]
    support ++> [
        data.test_async_io_blocking
            | server.test_acl_field_write
            | server.test_app_tokens
            | server.test_root_bind_fail_closed {
            get_free_port,
            register_user,
            start_server
        },
        deploy.test_client_build_fail_fast
            | microservices.test_app_precompile
            | microservices.test_fat_bundle { require_pod_binary },
        deploy.test_ops_deploy
            | deploy.test_ops_health
            | deploy.test_ops_network
            | misc.test_ops_podenv
            | server.test_admin_logs
            | server.test_firebase_auth_sso { RecordingHost },
        microservices.test_bundle_jacignore
            | microservices.test_pvc_injector
            | microservices.test_seed_determinism { pod_binary, require_pod_binary },
        microservices.test_gateway
            | microservices.test_k8s_health_probe
            | server.test_examples { get_free_port },
        microservices.test_stop_signal_scope { stop_server },
        microservices.test_typed_boundary | server.test_drain_hooks {
            get_free_port,
            start_server,
            stop_server
        },
        server.test_metrics_workers | server.test_serve {
            cleanup_db_files,
            get_free_port,
            start_server,
            stop_server
        },
        server.test_user_identity {
            extract,
            get_free_port,
            register_user,
            start_server,
            stop_server
        },
    ]
    toolchain_http ++> deploy.test_client_build_fail_fast
        | microservices.test_binary_cache { mock_downloads }
}

graph import scale.tests.deploy {
    http_activation_test_support ++> [
        test_http_activation_config {
            default_http_activation_config as _cfg,
            mocked_keda_autoscaler as _mocked_keda
        },
        test_http_activation_microservices {
            default_http_activation_config as _cfg,
            default_http_activation_spec as _spec,
            mocked_keda_autoscaler as _mocked_keda
        },
    ]
}

graph import scale.tests.server {
    oauth_fixtures ++> [
        test_oauth_session { FakeTokens, fake_users, provider },
        test_sso | test_sso_grants { FakeTokens, fake_users },
    ]
}

graph import scale.websocket {
    backplane ++> websocket { BaseBackplane, MemoryBackplane }
    websocket ++> protocol { ConnectionContext, consume_rate_token }
}

graph import server {
    bridge ++> [
        outbox { BridgeRejected },
        outbox.remember_response { serialize_response },
        outbox.replay_cached { replay_response },
        sv_client {
            BridgeError,
            BridgeUnavailable,
            bridge_error_for_status,
            bridge_error_from
        },
    ]
    build_status ++> [
        endpoints.pages.register_diagnostics_endpoints.build_status {
            get_build_status
        },
        hmr { BuildMonitor, BuildStatus },
    ]
    endpoint_contract ++> endpoints.colocated | endpoints.walkers {
        check_endpoint_contract
    }
    endpoints.auth ++> server.JacAPIServer.register_endpoints {
        register_auth_endpoints
    }
    endpoints.colocated ++> [
        server.JacAPIServer._colocated_scheduled_targets {
            colocated_providers,
            provider_introspector
        },
        server.JacAPIServer.register_endpoints { register_colocated_endpoints },
        server.print_endpoint_docs { colocated_providers, provider_route },
    ]
    endpoints.introspection ++> server.JacAPIServer.register_endpoints {
        register_introspection_endpoints
    }
    endpoints.pages ++> [
        server.JacAPIServer.build_app { robots_middleware },
        server.JacAPIServer.register_endpoints {
            register_diagnostics_endpoints,
            register_graph_endpoints,
            register_page_endpoints
        },
    ]
    endpoints.walkers ++> server.JacAPIServer.register_endpoints {
        register_function_endpoints,
        register_walker_endpoints
    }
    exchange ++> [
        endpoints.colocated { settle_envelope },
        endpoints.walkers {
            apply_response_choice,
            has_response_choice,
            refusal_status,
            settle_envelope
        },
        middleware { close_exchange, open_exchange },
        server { forget_response_choice },
    ]
    type hmr ++> build_status { HotReloader }
    identity.assurance ++> [
        endpoints.second_factor {
            AAL1,
            AAL2,
            METHOD_TOTP,
            second_factor_claims,
            token_assurance
        },
        middleware {
            bind_caller_assurance,
            bind_caller_user,
            release_caller_assurance,
            release_caller_user,
            token_assurance
        },
    ]
    identity.audit ++> endpoints.auth | endpoints.second_factor {
        client_ip,
        emit as audit
    }
    identity.auth_models ++> [
        endpoints.auth {
            AddIdentityRequest,
            ForgotPasswordRequest,
            LoginRequest,
            MeIdentity,
            MeResponse,
            RegisterRequest,
            ResetPasswordRequest,
            SendVerificationRequest,
            UpdatePasswordRequest,
            UpdateProfileRequest,
            UpdateProfileResponse,
            UpdateUsernameRequest,
            VerifyIdentityRequest
        },
        endpoints.second_factor {
            EnrollFactorRequest,
            RemoveFactorRequest,
            SecondFactorLoginRequest,
            VerifyFactorRequest
        },
    ]
    identity.auth_tokens ++> endpoints.auth { AuthTokenStore }
    identity.config ++> [
        endpoints.auth { auth_settings },
        server.JacAPIServer.__post_init__ { configure_identity, signing_secret },
    ]
    identity.identity_storage ++> [
        endpoints.auth | endpoints.second_factor { primary_username },
        server.JacAPIServer._register_scheduled_tasks { PgIdentityStorage },
    ]
    identity.mail ++> [
        endpoints.auth { MailOutcome, VERIFY_PURPOSE },
        server { IdentityMailer, verification_problems },
    ]
    identity.policy ++> endpoints.auth { POLICY_VIOLATION, public_policy }
    identity.rate_limit ++> endpoints.auth { AttemptsExhausted, consume_limit }
    identity.registration_challenge ++> endpoints.auth {
        consume_challenge,
        issue_challenge
    }
    identity.second_factor ++> endpoints.second_factor {
        FACTOR_VERIFIED,
        SecondFactorUnavailable
    }
    identity.session_cookie ++> [
        endpoints.auth { end_session, start_session },
        endpoints.second_factor { start_session },
        middleware {
            apply_session_change,
            cookie_session_token,
            keep_out_of_shared_caches
        },
    ]
    identity.user_manager ++> [
        endpoints.auth | endpoints.second_factor { UserRole },
        middleware | server { UserManager },
        server.JacAPIServer._ensure_internal_users { SYSTEM_USER, UserRole },
        server.JacAPIServer._register_scheduled_tasks { SYSTEM_USER },
    ]
    impl.pruned_inotify --> watcher.JacFileWatcher.start { SharedPrunedInotifyObserver }
    middleware ++> [
        endpoints.auth | endpoints.second_factor { bearer_token, require_user },
        endpoints.introspection { unauthorized },
        server.JacAPIServer._install_middleware {
            jwt_middleware,
            request_context_middleware
        },
        server.JacAPIServer.build_app { metrics_middleware },
    ]
    net ++> [
        server { PORT_RETRY_LIMIT },
        serving.server | serving.supervisor { PORT_RETRY_LIMIT, bind_listener },
    ]
    outbox ++> [
        endpoints.colocated { remember_response, replay_cached },
        endpoints.walkers { remember_response, replay_cached, scoped_idempotency_key },
        server.JacAPIServer._worker_main { start_worker_if_bridging, stop_worker },
        server.JacAPIServer.serve_background { start_worker_if_bridging, stop_worker },
        sv_client.spawn_deferred { enqueue },
    ]
    request_scope ++> middleware | server { RequestScope }
    sealed_serve ++> [
        endpoints.pages._static_base | server.ModuleIntrospector._resolve_declared {
            sealed_root_for
        },
        server.ModuleIntrospector._load_manifest { serve_manifest_for },
        server.ModuleIntrospector._load_spa_routes { serve_manifest_for },
        server.ModuleIntrospector._load_surface { serve_manifest_for },
    ]
    sealed_serve --> endpoints.pages.register_page_endpoints { client_dist_for }
    server ++> [
        endpoints.auth | endpoints.second_factor { EndpointHost, JsonValue },
        endpoints.colocated { JacAPIServer, JsonValue, ModuleIntrospector },
        endpoints.introspection { JacAPIServer },
        endpoints.pages { JacAPIServer, JsonValue },
        endpoints.walkers { JacAPIServer, JsonValue, target_restspec },
    ]
    serving.accesslog ++> server.JacAPIServer._prepare_to_serve {
        configure_access_logging
    }
    serving.app ++> [
        bridge.serialize_response | exchange.settle_envelope { transport_to_response },
        server { ServingApp },
    ]
    serving.authcrypt ++> [
        identity.assurance { jwt_decode },
        identity.identity_storage {
            hash_password as _scrypt_hash,
            is_prescrypt_hash as _is_prescrypt,
            needs_rehash as _needs_rehash,
            verify_password as _scrypt_verify
        },
        identity.user_manager { JWTExpiredError, jwt_decode, jwt_encode },
        settings.AuthSettings.resolve_secret {
            PLACEHOLDER_JWT_SECRET,
            project_signing_secret
        },
    ]
    serving.client ++> [
        bridge.bridge_error_from {
            ClientConnectionError,
            ClientReadTimeout,
            ClientRequestNotSent
        },
        identity.policy | sv_client._http_spawn { request_sync },
        sv_client._http_call { post_stream_aware_sync },
    ]
    serving.coerce ++> endpoints.walkers { is_upload_type }
    serving.datatypes ++> [
        bridge.replay_response | outbox.remember_response { JSONResponse },
        bridge.serialize_response { JSONResponse },
        endpoints.auth
            | endpoints.introspection
            | endpoints.second_factor
            | identity.audit { Request },
        endpoints.colocated | identity.session_cookie | static_files {
            Request,
            Response
        },
        endpoints.pages { HTMLResponse, JSONResponse, Request, Response },
        endpoints.walkers { FileResponse, Request, Response, StreamingResponse },
        exchange { JSONResponse, Request },
        middleware { JSONResponse, Request, Response },
    ]
    serving.drain ++> [
        middleware { LIVENESS_PATHS },
        server | task_scheduler { DrainState },
        server.JacAPIServer.build_app { drain_middleware },
    ]
    serving.endpoint ++> [
        endpoints.auth
            | endpoints.colocated
            | endpoints.introspection
            | endpoints.pages
            | endpoints.walkers { APIParameter, HTTPMethod, JEndPoint, ParameterType },
        endpoints.second_factor { HTTPMethod, JEndPoint },
        server { JEndPoint, WSEndPoint },
        server.restspec_fields { HTTPMethod },
    ]
    serving.files ++> endpoints.pages | endpoints.walkers { file_response }
    serving.health ++> server.JacAPIServer.register_endpoints {
        register_health_endpoints
    }
    serving.middleware ++> [
        server.JacAPIServer.build_app { cors_middleware, custom_headers_middleware },
        settings.ServeSettings.validate { cors_pair_problem },
    ]
    serving.model ++> identity.auth_models { ApiModel, require_str }
    serving.openapi ++> [
        server.JacAPIServer._refresh_dev_endpoints { register_docs_endpoints },
        server.JacAPIServer.build_app { register_docs_endpoints },
    ]
    serving.router ++> endpoints.walkers { path_param_names }
    serving.server ++> server { ServingServer }
    serving.sse ++> [
        endpoints.walkers { sse_frame_stream },
        sv_client._http_call { consume_sse_events },
    ]
    serving.supervisor ++> [
        server { WorkerHandle },
        server.JacAPIServer.start { WorkerSupervisor },
    ]
    session ++> outbox._writable_txn { Session }
    session --> [
        server._run_function_with_occ { Session, transient_db_error },
        shared_store.shared_store {
            conninfo_from_url,
            promotions_for,
            runtime_for_base
        },
    ]
    settings ++> [
        identity.config { AuthSettings },
        identity.policy { IDENTIFIER_KINDS, PASSWORD_CLASSES, PasswordSettings },
        identity.user_manager { IDENTIFIER_KINDS, in_cluster },
        server | serving.server | serving.supervisor { ServeSettings },
        server.JacAPIServer._validate_or_raise { ServeConfigError, default_threads },
        server.JacAPIServer.serve_background { default_threads },
    ]
    shared_store ++> [
        identity.rate_limit | identity.second_factor { shared_store },
        identity.user_manager.UserManager.__post_init__ {
            NO_DATABASE_RESOLVED,
            shared_store,
            shared_store_failure
        },
    ]
    shared_store --> identity.auth_tokens.AuthTokenStore.__post_init__ { shared_store }
    static_files ++> [
        endpoints.pages {
            SEO_ROOT_FILES,
            client_dist_index,
            find_root_asset,
            find_static_candidate,
            robots_response,
            sibling_app_dist,
            sibling_app_file
        },
        server.print_endpoint_docs { sibling_app_names },
    ]
    sv_client ++> [
        assembly.colocate_services { register_local },
        endpoints.colocated { _local_providers },
        endpoints.colocated.served_app_route
            | endpoints.walkers.function_callback.callback { consumer_app },
        endpoints.walkers { IDEMPOTENCY_HEADER, bridge_identity },
        endpoints.walkers.walker_callback.callback { consumer_app },
    ]
    sv_client --> assembly.assemble_served_program { set_consumer_app }
    sv_client as sv_client ++> [
        outbox._deliver_one,
        outbox.start_worker_if_bridging,
    ]
    task_scheduler ++> [
        server { Scheduler },
        server.JacAPIServer.__post_init__ { Scheduler },
        server.JacAPIServer._colocated_scheduled_targets { ScheduleSpec },
        server.JacAPIServer._register_scheduled_tasks { schedule_namespace },
        server.ModuleIntrospector.scheduled_members { ScheduleSpec },
        server.ModuleIntrospector.scheduled_targets { ScheduleSpec },
    ]
    task_scheduler --> server.JacAPIServer._start_problems { schedule_problems }
    transport ++> [
        bridge.serialize_response
            | endpoints.pages.register_diagnostics_endpoints.client_error
            | endpoints.second_factor
            | exchange
            | outbox.remember_response
            | serving.app { TransportResponse },
        endpoint_contract
            | endpoints.auth
            | endpoints.colocated
            | endpoints.introspection
            | endpoints.walkers
            | middleware { Meta, TransportResponse },
    ]
}

graph import server.endpoints {
    auth ++> [
        pages.register_diagnostics_endpoints.client_error { throttled },
        second_factor { fail, ok, throttled },
    ]
    second_factor ++> auth.register_auth_endpoints { register_second_factor_endpoints }
    walkers ++> colocated { _failure, idempotency_key, request_caller }
}

graph import server.identity {
    assurance ++> [
        second_factor { METHOD_PASSWORD, METHOD_RECOVERY, METHOD_TOTP },
        user_manager { METHOD_PASSWORD, carried_claims },
    ]
    audit ++> mail { emit as audit }
    auth_tokens ++> app_tokens
        | mail
        | registration_challenge
        | second_factor
        | user_manager { AuthTokenStore }
    common_passwords ++> policy { COMMON_PASSWORDS }
    config ++> [
        assurance { signing_algorithm, signing_secret },
        identity_storage { auth_settings, password_hash_cost },
        mail | policy | second_factor { auth_settings },
        session_cookie { auth_settings, token_ttl_days },
        user_manager {
            auth_settings,
            signing_algorithm,
            signing_secret,
            token_ttl_days
        },
    ]
    identity_storage ++> [
        second_factor { IdentityStorage },
        user_manager { IdentityStorage, IdentityTakenError, PgIdentityStorage },
    ]
    mail ++> user_manager { RESET_PURPOSE }
    policy ++> [
        identity_storage { VERIFY_BEFORE_LOGIN, verify_before_login },
        user_manager {
            Violation,
            awaiting_verification,
            check_identifiers,
            check_identity,
            check_password,
            minted_password,
            refusal
        },
    ]
    rate_limit ++> [
        mail { consume_limit },
        second_factor { consume_limit, refund_limit },
        user_manager { AttemptsExhausted, consume_limit, refund_limit },
    ]
    second_factor ++> user_manager { SecondFactorManager }
    totp ++> second_factor { matching_step, new_totp_secret, provisioning_uri }
}

graph import server.serving {
    accesslog ++> server { AccessRecord, emit as emit_access }
    app ++> health | openapi | server { ServingApp }
    coerce ++> app {
        RequestValidationError,
        bind_parameters,
        body_param_name,
        coerce_value,
        filter_kwargs_for_callback,
        get_callback_spec
    }
    compression ++> server { CompressionPolicy }
    datatypes ++> [
        app {
            HTTPError,
            JSONResponse,
            RedirectResponse,
            Request,
            Response,
            StreamingResponse
        },
        client | proxy { Headers },
        coerce { Request, UploadFile },
        compression { Headers, Request, Response },
        drain | files { JSONResponse, Request, Response },
        health { JSONResponse },
        middleware { Request, Response },
        multipart { HTTPError, Request, UploadFile },
        openapi { HTMLResponse },
        server { Headers, QueryParams, Request, Response, URL, parse_query_string },
        ws { Headers, QueryParams, URL, WebSocketDisconnect },
    ]
    datatypes --> server.ServingServer._dispatch { JSONResponse }
    drain ++> [
        accesslog { HEALTH_PATHS },
        app { run_hooks },
        health | supervisor { DrainState },
        server { DrainState, HEALTH_PATHS },
    ]
    endpoint ++> [
        app { JEndPoint, WSEndPoint },
        coerce { APIParameter, JEndPoint, ParameterType },
        health { HTTPMethod, JEndPoint },
        openapi { APIParameter, HTTPMethod, JEndPoint, ParameterType },
        router { HTTPMethod, JEndPoint, WSEndPoint },
    ]
    executor ++> [
        compression | sse { iterate_sync },
        server { SyncExecutor, iterate_sync },
    ]
    multipart ++> app { parse_multipart, parse_urlencoded_form }
    openapi ++> app.ServingApp.openapi { build_openapi }
    proxy ++> server { ProxyResolver }
    router ++> app { Router }
    server ++> supervisor { EXIT_OK, EXIT_RECYCLE }
    sse ++> [
        app { sse_frame_stream },
        client { parse_sse },
    ]
    ws ++> client | server { WebSocket, compute_accept_key }
}

graph import studio {
    acp ++> agents { AcpSession }
    agent_session ++> [
        acp { AgentEvent, AgentSession, blocks_text },
        agents { AgentSession },
        native_agent { AgentSession, blocks_text },
        session | tui { AgentEvent },
    ]
    agents ++> [
        app { AgentRegistry },
        tui { AgentRegistry, read_studio_table, user_config_path },
    ]
    bridge ++> [
        studio_mcp {
            BridgeClient,
            BridgeError,
            BridgeUnavailable,
            SOCKET_ENV,
            find_studio_socket
        },
        tui { BridgeServer, StudioQueries },
    ]
    context ++> [
        app { context_blocks, resolve_key },
        native_agent {
            WIRE_PREFIX,
            context_block,
            module_of,
            resolve_key,
            rule_lines,
            sig_suffix,
            symbol_context,
            tidy_sig,
            wire_line
        },
        tui { context_blocks },
    ]
    gate ++> [
        app { EditGate, EditReview, format_review },
        tui { EditGate, change_groups, leaf_changes, partial_text },
    ]
    graph ++> [
        app { graph_level, in_scope, level_dict, level_text, scope_for },
        bridge { graph_level, level_dict, scope_for },
        context {
            DEPS_PREFIX,
            MAP_PREFIX,
            deps_text,
            graph_level,
            level_text,
            parse_deps_key,
            split_spec
        },
        insight {
            GraphEdge,
            GraphLevel,
            effective_scope,
            graph_level,
            group_of,
            in_scope
        },
        map_view { GraphEdge, GraphLevel, GraphNode },
        native_agent { graph_level, level_text, scope_for },
        tui {
            MAP_PREFIX,
            deps_key,
            edge_wires,
            graph_level,
            group_of,
            parent_scope,
            parse_deps_key,
            scope_for,
            split_spec
        },
    ]
    insight ++> [
        app {
            arch_diff,
            cluster_report,
            clusters_dict,
            clusters_text,
            default_base,
            diff_dict,
            diff_text,
            intent_dict,
            intent_report,
            intent_text,
            interface_dict,
            interface_of,
            interface_text,
            module_roles,
            reach,
            reach_dict,
            reach_text,
            roles_dict,
            roles_text,
            tour_text
        },
        bridge | native_agent { insight_run },
        context { filter_label, filter_modules },
        map_view {
            ClusterReport,
            IntentReport,
            InterfaceReport,
            ROLE_ORDER,
            ROLE_TEXT,
            RolesReport,
            WHOLE
        },
        tui {
            arch_diff,
            cluster_report,
            default_base,
            diff_text,
            filter_label,
            filter_modules,
            intent_report,
            interface_of,
            module_roles,
            reach,
            spec_parts,
            tour_text
        },
    ]
    intel ++> [
        app { CodeIntel, Span },
        tui { CodeIntel },
    ]
    intel_server --> [
        intel.CodeIntel._do_check { check_head, new_cancel_token },
        intel.CodeIntel._do_invalidate { invalidate_path },
        intel.CodeIntel._do_query { definition_at, hover_at, references_at },
        intel.CodeIntel._ensure_engine { new_server },
        intel.CodeIntel._run { shutdown_server },
    ]
    map_view ++> tui {
        MAP_VIEWS,
        MapItem,
        MapState,
        crumbs,
        issue_items,
        map_lines,
        map_move,
        view_tabs
    }
    model ++> [
        app { ProjectModel, find_project_root },
        bridge {
            ProjectModel,
            SYM_SCHEME,
            StAbility,
            StArchetype,
            StImpl,
            StModule,
            StNode
        },
        context {
            ProjectModel,
            StAbility,
            StArchetype,
            StField,
            StModule,
            StNode,
            WireInfo,
            sym_uri
        },
        graph { Governs, ProjectModel, WireInfo },
        insight { Governs, ProjectModel, StRule, WireInfo },
        native_agent { ProjectModel, SKIP_DIRS },
        tui { ProjectModel, StAbility, StImpl, StModule, StNode, WireInfo },
    ]
    native_agent ++> agents { NativeAgentSession }
    session ++> [
        app {
            StudioSession,
            fork_session,
            list_sessions,
            load_session,
            new_session,
            sessions_dir,
            transcript_of
        },
        tui { load_session, new_session, transcript_of },
    ]
    studio_mcp ++> app { serve_studio_mcp }
    theme ++> [
        map_view {
            C_DIM,
            C_SEL,
            C_SEL_FOCUS,
            THEME,
            blank,
            fit,
            kind_attrs,
            kind_icon,
            plain,
            restyle,
            sp,
            with_bg
        },
        tui {
            CODE_STYLES,
            C_SEL,
            C_SEL_FOCUS,
            THEME,
            blank,
            fit,
            kind_attrs,
            kind_icon,
            plain,
            restyle,
            sp,
            with_bg,
            wrap_plain
        },
    ]
    tui ++> app { run_tui }
    util ++> [
        app { jac_mcp_server, permission_diffs, unified_diff },
        gate | intel { COMPILE_LOCK },
        tui { jac_mcp_server, permission_diffs, read_or_empty, unified_diff },
    ]
}

graph import testing {
    cl_test_runner ++> [
        runner.run_test {
            is_cl_test_file,
            is_cl_test_file_for_discovery,
            register_results_into_jactestcheck,
            run_cl_test_file
        },
        test_runner.run_file { module_is_client, run_cl_test_file },
    ]
    test ++> cl_test_runner.register_results_into_jactestcheck
        | runner.run_test
        | test_runner.run_file { JacTestCheck }
    test_runner ++> requires { STRICT_ENV, strict_mode }
    testkit ++> testing { dispatch_and_collect }
}

graph import toolchains {
    android --> manager.setup_toolchain { ensure_android }
    apple --> manager.setup_toolchain { ensure_apple }
    cef --> manager.setup_toolchain { ensure_cef }
    desktop --> manager.setup_toolchain { ensure_webview }
    host ++> [
        android | c_backend { executable, host_platform, run_step },
        apple { host_platform, run_step, use_system_tools },
        cef | system.ensure_desktop_host { host_platform },
        desktop { host_platform, run_step, shared_library_name },
        system { run_step },
        system.ensure_linux_desktop { host_platform },
        tools { executable, host_platform, use_system_tools },
    ]
    javascript --> manager.setup_toolchain { native_node }
    pins ++> [
        android { ANDROID_ARTIFACTS },
        apple.ensure_apple { RUBY_ARTIFACTS, RUBY_VERSION },
        tools.JdkArtifact._home { JDK_VERSION },
        tools.JdkArtifact.pinned { JDK_ARTIFACTS },
        tools.NodeArtifact.pinned { NODE_ARTIFACTS },
        tools.PatchelfArtifact.pinned { PATCHELF_ARTIFACTS },
    ]
    store ++> [
        android { install, offline },
        apple { install_slot, offline, publish_install_slot, slot_installed },
        apple.ensure_apple { install },
        c_backend {
            Artifact,
            build_slot,
            extract,
            fetch,
            file_digest,
            publish_build_slot,
            slot_ready
        },
        cef { Artifact, install },
        desktop {
            Artifact,
            build_slot,
            fetch,
            file_digest,
            publish_build_slot,
            slot_ready
        },
        javascript | system { offline },
        pins { Artifact },
        tools { Artifact as Download, install, installed },
    ]
    system ++> desktop { ensure_desktop_host, webkit_module }
    tools ++> android.ensure_jdk | javascript.native_node | system.ensure_patchelf {
        tool_path
    }
}
