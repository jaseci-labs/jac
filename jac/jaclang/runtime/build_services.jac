"""Optional build-time services; executable runtime artifacts do not construct compilers."""

import importlib;
import from typing { Protocol }
import type from jaclang.compiler.driver.compiler { JacCompiler }
import type from jaclang.compiler.driver.program { JacProgram }
import type from jaclang.compiler.driver.selfhost { SelfHostCache }
import type from jaclang.client.client_bundle { ClientBundleBuilder }

class BuildServices(Protocol) {
    def compiler(self: BuildServices) -> JacCompiler;
    def program(self: BuildServices) -> JacProgram;
    def selfhost(self: BuildServices) -> SelfHostCache;
    def client_builder(self: BuildServices) -> ClientBundleBuilder;
}

glob _services: BuildServices | None = None;

def build_services -> BuildServices {
    if _services is None {
        try {
            provider = importlib.import_module('jaclang.compiler.driver.build_services');
        } except ModuleNotFoundError as error {
            if error.name not in ('jaclang.compiler', 'jaclang.compiler.driver', 'jaclang.compiler.driver.build_services') {
                raise;
            }
            raise RuntimeError('This application contains executable artifacts; compiler services are not installed.') from error;
        }
        _services = provider.CompilerBuildServices();
    }
    return _services;
}
