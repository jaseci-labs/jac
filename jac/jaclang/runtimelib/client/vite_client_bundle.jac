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
import from .compiler { ViteCompiler }

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
}

def make_client_bundle_builder(
    base_path: (Path | None) = None
) -> ViteClientBundleBuilder;
