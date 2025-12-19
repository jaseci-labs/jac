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
    """Initialize the Vite-enhanced bundle builder."""
    def init(
        self: ViteClientBundleBuilder,
        runtime_path: (Path | None) = None,
        vite_output_dir: (Path | None) = None,
        vite_package_json: (Path | None) = None,
        vite_minify: bool = False
    ) -> None {
        super.init(runtime_path);
        self.vite_output_dir = vite_output_dir;
        self.vite_package_json = vite_package_json;
        self.vite_minify = vite_minify;
        self._compiler: (ViteCompiler | None) = None;
    }

    """Get or create the Vite compiler instance."""
    def _get_compiler(self: ViteClientBundleBuilder) -> ViteCompiler {
        if (self._compiler is None) {
            if (not self.vite_package_json or not self.vite_package_json.exists()) {
                raise ClientBundleError(
                    'Vite package.json not found. Set vite_package_json when using ViteClientBundleBuilder'
                ) ;
            }
            compile_to_js_func: Callable[([Path], tuple[(str, (ModuleType | None))])] = cast(
                Callable[([Path], tuple[(str, (ModuleType | None))])],
                self._compile_to_js
            );
            self._compiler = ViteCompiler(
                vite_package_json=self.vite_package_json,
                vite_output_dir=self.vite_output_dir,
                vite_minify=self.vite_minify,
                runtime_path=self.runtime_path,
                compile_to_js_func=compile_to_js_func,
                extract_exports_func=self._extract_client_exports,
                extract_globals_func=self._extract_client_globals
            );
        }
        return self._compiler;
    }

    """Override to use Vite bundling instead of simple concatenation."""
    def _compile_bundle(
        self: ViteClientBundleBuilder, module: ModuleType, module_path: Path
    ) -> ClientBundle {
        compiler = self._get_compiler();
        (bundle_code, bundle_hash, client_exports, client_globals) = compiler.compile_and_bundle(
            module, module_path
        );
        return ClientBundle(
            module_name=module.__name__,
            code=bundle_code,
            client_functions=client_exports,
            client_globals=client_globals,
            hash=bundle_hash
        );
    }

    """Clean up the compiled directory and its contents."""
    def cleanup_temp_dir(self: ViteClientBundleBuilder) -> None {
        if (not self.vite_package_json or not self.vite_package_json.exists()) {
            return;
        }
        project_dir = self.vite_package_json.parent;
        temp_dir = project_dir / 'compiled';
        if temp_dir.exists() {
            with contextlib.suppress(OSError, shutil.Error) {
                shutil.rmtree(temp_dir);
            }
        }
    }
}
