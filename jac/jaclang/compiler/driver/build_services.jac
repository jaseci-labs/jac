import from jaclang.runtime.build_services { BuildServices }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.driver.selfhost { SelfHostCache }
import type from jaclang.client.client_bundle { ClientBundleBuilder }

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
