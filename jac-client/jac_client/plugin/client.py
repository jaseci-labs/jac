import types
from pathlib import Path
from typing import Any

from jaclang.runtimelib.client_bundle import ClientBundle
from jaclang.runtimelib.machine import (
    JacMachine as Jac,
    hookimpl,
)
from jaclang.runtimelib.server import ModuleIntrospector

from .vite_client_bundle import ViteClientBundleBuilder


class JacClientModuleIntrospector(ModuleIntrospector):
    """Jac Client Module Introspector."""

    def render_page(
        self, function_name: str, args: dict[str, Any], username: str
    ) -> dict[str, Any]:
        return super().render_page(function_name, args, username)


class JacClient:
    """Jac Client."""

    @staticmethod
    @hookimpl
    def get_client_bundle_builder() -> ViteClientBundleBuilder:
        """Get the client bundle builder instance."""
        base_path = Path(Jac.base_path_dir)
        package_json_path = base_path / "package.json"
        output_dir = base_path / "static" / "client" / "js"
        # Use the plugin's client_runtime.jac file
        runtime_path = Path(__file__).with_name("client_runtime.jac")
        print(f"Runtime path: {runtime_path}")
        return ViteClientBundleBuilder(
            runtime_path=runtime_path,
            vite_package_json=package_json_path,
            vite_output_dir=output_dir,
            vite_minify=False,
        )

    @staticmethod
    @hookimpl
    def build_client_bundle(
        module: types.ModuleType,
        force: bool = False,
    ) -> ClientBundle:
        """Build a client bundle for the supplied module."""
        builder = JacClient.get_client_bundle_builder()
        return builder.build(module, force=force)

    @staticmethod
    @hookimpl
    def get_module_introspector(
        module_name: str, base_path: str | None
    ) -> ModuleIntrospector:
        """Get a module introspector for the supplied module."""
        return JacClientModuleIntrospector(module_name, base_path)
