import from jaclang.runtime.build_services { BuildServices }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.driver.selfhost { SelfHostCache }
import type from jaclang.client.client_bundle { ClientBundleBuilder }
import type from jaclang.runtime.prepared { PreparedApplication }
import type from jaclang.server.hmr { HotReloader }

obj CompilerBuildServices(BuildServices) {
    def compiler -> JacCompiler {
        import from jaclang.compiler.driver.compiler { JacCompiler }
        return JacCompiler();
    }

    def program -> JacProgram {
        import from jaclang.compiler.driver.program { JacProgram }
        return JacProgram();
    }

    def selfhost -> SelfHostCache {
        import from jaclang.compiler.driver.selfhost { SelfHostCache }
        return SelfHostCache();
    }

    def client_builder -> ClientBundleBuilder {
        import from jaclang.client.vite_client_bundle { make_client_bundle_builder }
        return make_client_bundle_builder();
    }

    def prepare_application(
        entry_path: str,
        program: JacProgram,
        project_root: str,
        default_codespace: str = ''
    ) -> PreparedApplication {
        import from jaclang.compiler.driver.application { prepare_application }
        import from jaclang.compiler.frontend.codeinfo {
            set_effective_default_codespace
        }
        if default_codespace {
            set_effective_default_codespace(default_codespace);
        }
        return prepare_application(entry_path, program, project_root);
    }

    def hot_reloader(base_path: str, module_name: str) -> HotReloader {
        import from jaclang.server.hmr { HotReloader }
        import from jaclang.server.watcher { JacFileWatcher }
        return HotReloader(
            base_path=base_path,
            module_name=module_name,
            watcher=JacFileWatcher(watch_paths=[base_path])
        );
    }

    def client_runtime_basename(framework: str) -> str {
        import from jaclang.compiler.backends.es.backends.registry {
            resolve_framework_backend,
            resolve_active_backend
        }
        backend = resolve_framework_backend(framework)
            if framework
            else resolve_active_backend();
        return backend.runtime_source_basename();
    }

    def application_edges(
        entry_path: str, app_name: str, app_kind: str, project_root: str
    ) -> list[tuple[str, str]] {
        import from jaclang.compiler.driver.application_edges { application_edges }
        return application_edges(entry_path, app_name, app_kind, project_root);
    }

    def run_test(
        filepath: str,
        func_name: str | None,
        filter: str | None,
        xit: bool,
        maxfail: int | None,
        directory: str | None,
        verbose: bool
    ) -> int {
        import from jaclang.testing.runner { run_test }
        return run_test(filepath, func_name, filter, xit, maxfail, directory, verbose);
    }
}
