import importlib;
import from functools { cache }
import from typing { Protocol }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.driver.selfhost { SelfHostCache }
import type from jaclang.client.client_bundle { ClientBundleBuilder }
import type from jaclang.runtime.prepared { PreparedApplication }
import type from jaclang.server.hmr { HotReloader }

class BuildServices(Protocol) {
    def compiler(self: BuildServices) -> JacCompiler;
    def program(self: BuildServices) -> JacProgram;
    def selfhost(self: BuildServices) -> SelfHostCache;
    def client_builder(self: BuildServices) -> ClientBundleBuilder;
    def prepare_application(
        self: BuildServices,
        entry_path: str,
        program: JacProgram,
        project_root: str,
        default_codespace: str = ''
    ) -> PreparedApplication;

    def hot_reloader(
        self: BuildServices, base_path: str, module_name: str
    ) -> HotReloader;

    def run_test(
        self: BuildServices,
        filepath: str,
        func_name: str | None,
        filter: str | None,
        xit: bool,
        maxfail: int | None,
        directory: str | None,
        verbose: bool
    ) -> int;

    def application_edges(
        self: BuildServices,
        entry_path: str,
        app_name: str,
        app_kind: str,
        project_root: str
    ) -> list[tuple[str, str]];

    def client_runtime_basename(self: BuildServices, framework: str) -> str;
}

@cache
def build_services -> BuildServices {
    try {
        provider = importlib.import_module('jaclang.compiler.driver.build_services');
    } except ModuleNotFoundError as error {
        if error.name
            not in (
                'jaclang.compiler',
                'jaclang.compiler.driver',
                'jaclang.compiler.driver.build_services'
            ) {
            raise;
        }
        raise RuntimeError(
            'This application contains executable artifacts; compiler services are not installed.'
        ) from error;
    }
    return provider.CompilerBuildServices();
}
