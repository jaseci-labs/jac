obj CompilerBuildServices(BuildServices) {
    def compiler -> JacCompiler;
    def program -> JacProgram;
    def selfhost -> SelfHostCache;
    def client_builder -> ClientBundleBuilder;
    def prepare_application(
        entry_path: str,
        program: JacProgram,
        project_root: str,
        default_codespace: str = ''
    ) -> PreparedApplication;

    def prepare_dynamic_module(
        path: str, program: JacProgram, application: PreparedApplication
    ) -> PreparedApplication;

    def hot_reloader(
        base_path: str, module_name: str, entry_path: str = ""
    ) -> HotReloader;

    def client_runtime_basename(framework: str) -> str;
    def application_edges(
        entry_path: str, app_name: str, app_kind: str, project_root: str
    ) -> list[tuple[str, str]];

    def run_test(
        filepath: str,
        func_name: str | None,
        filter: str | None,
        xit: bool,
        maxfail: int | None,
        directory: str | None,
        verbose: bool
    ) -> int;
}
