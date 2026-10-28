impl HostServices.session -> Iterator[None] {
    yield ;
}

impl HostServices.in_kernel -> bool {
    return False;
}

impl HostServices.project_defaults -> (ProjectDefaults | None) {
    return None;
}

impl HostServices.check_settings(target_app: str) -> CheckSettings {
    return CheckSettings();
}

impl HostServices.project_facts(path: str) -> (ProjectFacts | None) {
    return None;
}

impl HostServices.lint_settings(path: str) -> LintSettings {
    return LintSettings(check=CheckSettings());
}

impl HostServices.workspace(path: str) -> (WorkspaceSpec | None) {
    return None;
}

impl HostServices.app_for_path(path: str) -> (AppSpec | None) {
    return None;
}

impl HostServices.project_root(path: str) -> (str | None) {
    return None;
}

impl HostServices.resolve_module(
    target: str, base_path: str, string_spec: bool = False
) -> tuple[str, str] {
    return ("", "");
}

impl HostServices.resolve_local_module(
    base: str, parts: list[str]
) -> (tuple[str, str] | None) {
    return None;
}

impl HostServices.jac_virtual_module_path(target: str) -> (str | None) {
    return None;
}

impl HostServices.is_path_alias(target: str, base_path: str) -> bool {
    return False;
}

impl HostServices.is_untyped_third_party(path: str) -> bool {
    return False;
}

impl HostServices.in_typeshed_tree(path: str) -> bool {
    return False;
}

impl HostServices.sibling_declaration(js_path: str) -> (str | None) {
    return None;
}

impl HostServices.client_pulls(path: str) -> str {
    return "";
}

impl HostServices.client_pull_grew(path: str) {}

impl HostServices.has_npm_package(spec: str, base_path: str) -> bool {
    return False;
}

impl HostServices.resolve_npm_package(spec: str, base_path: str) -> (str | None) {
    return None;
}

impl HostServices.npm_declarations(spec: str, base_path: str) -> (str | None) {
    return None;
}

impl HostServices.declared_dependencies(
    module_path: str, fallback_app: str
) -> (list[str] | None) {
    return None;
}

impl HostServices.note(message: str, style: str = "dim") {}

impl HostServices.stub_catalog_for(program: JacProgram) -> (StubCatalog | None) {
    return None;
}

impl HostServices.parse_python(
    source_str: str, file_path: str, program: JacProgram
) -> tuple[Module, bool] {
    raise RuntimeError("no compiler host is installed");
}

impl HostServices.stub_interface(
    program: JacProgram, file_path: str
) -> (Module | None) {
    return None;
}

impl HostServices.ct_environment -> CtEnvironment {
    return CtEnvironment();
}

impl HostServices.path_facts(path: str) -> PathFacts {
    return PathFacts();
}

impl HostServices.host_platform -> HostPlatform {
    return HostPlatform();
}

impl HostServices.read_source(path: str) -> str {
    with open(path) as handle {
        return handle.read();
    }
}

impl HostServices.annex_files(path: str, suffix: str = ".impl.jac") -> list[str] {
    return [];
}

impl HostServices.base_file(annex_path: str) -> (str | None) {
    return None;
}

impl HostServices.is_annex_path_of(candidate: str, base: str) -> bool {
    return False;
}

impl HostServices.package_init(directory: str) -> (str | None) {
    return None;
}

impl HostServices.wiring_file(path: str) -> (str | None) {
    return None;
}

impl HostServices.is_seed_source(rel_path: str) -> bool {
    return False;
}

impl HostServices.wiring_records(digest: str) -> str {
    return "";
}

impl HostServices.keep_wiring_records(digest: str, text: str) {}

impl HostServices.native_parse(
    source_str: str,
    file_path: str,
    program: (JacProgram | None),
    annexes: list[WovenAnnex],
    early_context: str = "",
    load_kernel: bool = True
) -> (tuple[Module, bool] | None) {
    return None;
}

impl HostServices.woven_module(
    path: str, program: (JacProgram | None)
) -> (Module | None) {
    return None;
}

impl HostServices.place_wired_imports(module: Module) {}

impl HostServices.drop_python_lane_products(path: str, program: JacProgram) {}

impl HostServices.compiler_for(program: JacProgram) -> JacCompiler {
    raise RuntimeError("no compiler host is installed");
}

impl HostServices.iface_registry_for(program: JacProgram) -> IfaceRegistry {
    raise RuntimeError("no compiler host is installed");
}

impl HostServices.native_dep_iface(
    program: JacProgram, path: str, options: CompileOptions
) -> (NativeIface | None) {
    return None;
}

impl HostServices.native_dep_discovery_open(program: JacProgram) -> bool {
    return False;
}

impl HostServices.native_deps_deferred(program: JacProgram) -> bool {
    return False;
}

impl HostServices.held_native_iface(
    program: JacProgram, path: str, options: CompileOptions
) -> str {
    return "";
}

impl HostServices.native_lowering_failed(
    program: JacProgram, path: str, detail: str
) {}

impl HostServices.native_fact(kind: str, key: str) -> str {
    return "";
}

impl HostServices.save_native_debug_ir(path: str, text: str) {}

impl HostServices.native_units_for(program: JacProgram) -> NativeUnitRegistry {
    raise RuntimeError("no compiler host is installed");
}

impl HostServices.client_boundary_facts(
    program: JacProgram, path: str
) -> (list[str] | None) {
    return None;
}

impl HostServices.kernel_compile(
    program: JacProgram, path: str, options: CompileOptions
) -> (CompileReport | None) {
    return None;
}

impl HostServices.in_compiler_tree(path: str) -> bool {
    return False;
}

impl HostServices.schedule_import_failed(err: ImportError) {}

impl HostServices.client_osp_core_js -> str {
    return "";
}

impl HostServices.client_stub_globals -> list[str] {
    return [];
}

impl HostServices.native_session_declares(
    program: JacProgram, source: str, element: str
) -> (bool | None) {
    return None;
}

impl HostServices.native_session_active(program: JacProgram) -> bool {
    return False;
}

impl HostServices.record_native_coverage(
    path: str, outcome: str, code: str = "", detail: str = ""
) {}

impl HostServices.native_analyze(
    program: JacProgram, path: str, options: CompileOptions, source: (str | None)
) -> (ModuleAnalysis | None) {
    return None;
}

impl HostServices.format_file(file_path: str, auto_lint: bool = False) -> JacProgram {
    raise RuntimeError("no compiler host is installed");
}

impl HostServices.format_source(
    source_str: str, file_path: str, auto_lint: bool = False
) -> JacProgram {
    raise RuntimeError("no compiler host is installed");
}

impl HostServices.lint_file(file_path: str) -> JacProgram {
    raise RuntimeError("no compiler host is installed");
}

impl HostServices.native_pipeline_available -> tuple[bool, str] {
    return (False, "native pipeline unavailable: no compiler host is installed");
}

impl HostServices.compile_module(
    program: JacProgram, file_path: str, use_str: (str | None), options: CompileOptions
) -> Module {
    raise RuntimeError("no compiler host is installed");
}

impl HostServices.build_module(
    program: JacProgram, file_path: str, use_str: (str | None)
) -> Module {
    raise RuntimeError("no compiler host is installed");
}

impl HostServices.run_module_pipeline(
    program: JacProgram, file_path: str, use_str: (str | None), options: CompileOptions
) -> Module {
    raise RuntimeError("no compiler host is installed");
}

impl HostServices.internal_program(program: JacProgram) -> (JacProgram | None) {
    return None;
}

impl HostServices.bind_context_program(
    context_root: JacProgram, program: JacProgram
) {}

impl HostServices.note_program_dependency(program: JacProgram, resolved_path: str) {}

impl HostServices.forget_program_products(program: JacProgram, resolved_path: str) {}

impl HostServices.release_program_products(program: JacProgram, retain_stubs: bool) {}

impl HostServices.prepare_interface(
    program: JacProgram, path: str, module: Module
) -> bool {
    return False;
}

impl HostServices.collect_released_memory {}

impl HostServices.load_modules(names: list[str]) {}

impl HostServices.module_in_flight(names: list[str]) -> str {
    return "";
}

impl HostServices.import_in_flight(path: str) -> bool {
    return False;
}

impl HostServices.has_active_stub_catalog -> bool {
    return False;
}

impl HostServices.typeshed_unavailable_reason -> str {
    import os;
    stdlib = os.path.join(jaclang_pkg_root(), "vendor", "typeshed", "stdlib");
    if os.path.isfile(os.path.join(stdlib, "builtins.pyi")) {
        return "";
    }
    return f"no typeshed stdlib at {stdlib}";
}

impl HostServices.is_native_only_source(rel: str) -> bool {
    return False;
}

impl HostServices.is_native_lowered_source(rel: str) -> bool {
    return False;
}

impl HostServices.default_target_triple -> str {
    return "";
}

impl HostServices.host_side -> HostServices {
    return self;
}

impl active_host -> HostServices {
    return _HOSTS[-1] if _HOSTS else _NEUTRAL_HOST;
}

impl package_root -> str {
    return _PACKAGE_ROOT[0] if _PACKAGE_ROOT else "";
}

impl set_package_root(path: str) {
    _PACKAGE_ROOT.clear();
    _PACKAGE_ROOT.append(path);
}

impl install_host(host: HostServices) {
    _HOSTS.clear();
    _HOSTS.append(host);
}

impl set_kernel_host_mode(mode: str) -> str {
    previous = kernel_host_mode();
    _KERNEL_HOST_MODE.clear();
    if mode {
        _KERNEL_HOST_MODE.append(mode);
    }
    return previous;
}

impl kernel_host_mode -> str {
    return _KERNEL_HOST_MODE[0] if _KERNEL_HOST_MODE else "";
}

impl kernel_host_enabled -> bool {
    return kernel_host_mode() != "";
}
