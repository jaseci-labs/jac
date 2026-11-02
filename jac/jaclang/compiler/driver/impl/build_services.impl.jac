impl CompilerBuildServices.compiler -> JacCompiler {
    return JacCompiler();
}

impl CompilerBuildServices.program -> JacProgram {
    return JacProgram();
}

impl CompilerBuildServices.selfhost -> SelfHostCache {
    return SelfHostCache();
}

impl CompilerBuildServices.client_builder -> ClientBundleBuilder {
    return make_client_bundle_builder();
}

impl CompilerBuildServices.prepare_application(
    entry_path: str, program: JacProgram, project_root: str, default_codespace: str = ''
) -> PreparedApplication {
    if default_codespace {
        set_effective_default_codespace(default_codespace);
    }
    return prepare_application(entry_path, program, project_root);
}

impl CompilerBuildServices.prepare_dynamic_module(
    path: str, program: JacProgram, application: PreparedApplication
) -> PreparedApplication {
    return prepare_dynamic_module(path, program, application);
}

impl CompilerBuildServices.hot_reloader(
    base_path: str, module_name: str, entry_path: str = ""
) -> HotReloader {
    return HotReloader(
        base_path=base_path,
        module_name=module_name,
        entry_path=entry_path,
        watcher=JacFileWatcher(watch_paths=[base_path])
    );
}

impl CompilerBuildServices.client_runtime_basename(framework: str) -> str {
    backend = resolve_framework_backend(framework)
        if framework
        else resolve_active_backend();
    return backend.runtime_source_basename();
}

impl CompilerBuildServices.application_edges(
    entry_path: str, app_name: str, app_kind: str, project_root: str
) -> list[tuple[str, str]] {
    return application_edges(entry_path, app_name, app_kind, project_root);
}

impl CompilerBuildServices.run_test(
    filepath: str,
    func_name: str | None,
    filter: str | None,
    xit: bool,
    maxfail: int | None,
    directory: str | None,
    verbose: bool
) -> int {
    return run_test(filepath, func_name, filter, xit, maxfail, directory, verbose);
}
