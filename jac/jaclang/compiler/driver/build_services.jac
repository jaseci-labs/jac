"""Compiler implementation of the runtime's optional build service interface."""

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
}
