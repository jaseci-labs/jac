"""Vite-enhanced client bundle generation for Jac web front-ends."""
import contextlib;
import shutil;
import from collections.abc { Callable }
import from pathlib { Path }
import from types { ModuleType }
import from typing { cast }
import from jaclang.runtimelib.client_bundle {
    ClientBundle,
    ClientBundleBuilder,
    ClientBundleError
}
import from .src { ViteCompiler }

"""Enhanced ClientBundleBuilder that uses Vite for optimized bundling."""
class ViteClientBundleBuilder(ClientBundleBuilder) {
    def init(
        self: ViteClientBundleBuilder,
        runtime_path: (Path | None) = None,
        vite_output_dir: (Path | None) = None,
        vite_package_json: (Path | None) = None,
        vite_minify: bool = False
    ) -> None;

    def _get_compiler(self: ViteClientBundleBuilder) -> ViteCompiler;
    def _compile_bundle(
        self: ViteClientBundleBuilder, module: ModuleType, module_path: Path
    ) -> ClientBundle;

    def cleanup_temp_dir(self: ViteClientBundleBuilder) -> None;
}
