"""Main compilation orchestration module."""
import contextlib;
import from collections.abc { Callable }
import from pathlib { Path }
import from types { ModuleType }
import from typing { TYPE_CHECKING, Any }
import from jaclang.runtimelib.client_bundle { ClientBundleError }
import from .asset_processor { AssetProcessor }
import from .babel_processor { BabelProcessor }
import from .import_processor { ImportProcessor }
import from .jac_to_js { JacToJSCompiler }
import from .vite_bundler { ViteBundler }

with entry {
    if TYPE_CHECKING { }
}

"""Orchestrates the compilation process for Vite client bundles."""
class ViteCompiler {
    with entry {
        ROUTER_EXPORTS = [
            'Router',
            'Routes',
            'Route',
            'Link',
            'Navigate',
            'useNavigate',
            'useLocation',
            'useParams'
        ];
    }

    """Initialize the Vite compiler."""
    def __init__(
        self: ViteCompiler,
        vite_package_json: Path,
        vite_output_dir: (Path | None) = None,
        vite_minify: bool = False,
        runtime_path: (Path | None) = None,
        compile_to_js_func:
            (Callable[([Path], tuple[(str, (ModuleType | None))])] | None) = None,
        extract_exports_func: (Callable[([Any], list[str])] | None) = None,
        extract_globals_func: (Callable[([Any, ModuleType], dict[(str, Any)])] | None) = None
    ) {
        if (not vite_package_json or not vite_package_json.exists()) {
            raise ClientBundleError(
                'Vite package.json not found. Set vite_package_json when using ViteCompiler'
            ) ;
        }
        if (
            (compile_to_js_func is None)
            or (extract_exports_func is None)
            or (extract_globals_func is None)
        ) {
            raise ClientBundleError(
                'compile_to_js_func, extract_exports_func, and extract_globals_func are required'
            ) ;
        }
        self.vite_package_json = vite_package_json;
        # If package.json is in .jac-client.configs/, go up one level to get project root
        if (vite_package_json.parent.name == '.jac-client.configs') {
            self.project_dir = vite_package_json.parent.parent;
        } else {
            self.project_dir = vite_package_json.parent;
        }
        self.runtime_path = runtime_path;
        self.compiled_dir = self.project_dir / 'compiled';
        self.jac_compiler = JacToJSCompiler(
            compile_to_js_func, extract_exports_func, extract_globals_func
        );
        self.import_processor = ImportProcessor();
        self.asset_processor = AssetProcessor();
        self.babel_processor = BabelProcessor(self.project_dir);
        self.vite_bundler = ViteBundler(self.project_dir, vite_output_dir, vite_minify);
    }

    """Compile client runtime utilities."""
    def compile_runtime_utils(self: ViteCompiler) -> tuple[str, list[str]] {
        if not self.runtime_path {
            raise ClientBundleError('Runtime path not set') ;
        }
        runtime_utils_path = self.runtime_path.parent / 'client_runtime.jac';
        (runtimeutils_js, mod, runtimeutils_manifest) = self.jac_compiler.compile_module(
            runtime_utils_path
        );
        runtimeutils_exports_list = self.jac_compiler.extract_exports(
            runtimeutils_manifest
        );
        all_exports = sorted(set((runtimeutils_exports_list + self.ROUTER_EXPORTS)));
        export_block = self.jac_compiler.generate_export_block(all_exports);
        combined_runtime_utils_js = f"{runtimeutils_js}\n{export_block}";
        self.compiled_dir.mkdir(parents=True, exist_ok=True);
        (self.compiled_dir / 'client_runtime.js').write_text(
            combined_runtime_utils_js, encoding='utf-8'
        );
        return (combined_runtime_utils_js, all_exports);
    }

    """Recursively compile/copy .jac/.js imports to temp, skipping bundling."""
    def compile_dependencies_recursively(
        self: ViteCompiler,
        module_path: Path,
        visited: (set[Path] | None) = None,
        collected_exports: (set[str] | None) = None,
        collected_globals: (dict[(str, Any)] | None) = None,
        source_root: (Path | None) = None
    ) -> None {
        if (visited is None) {
            visited = set();
        }
        if (collected_exports is None) {
            collected_exports = set();
        }
        if (collected_globals is None) {
            collected_globals = {};
        }
        module_path = module_path.resolve();
        if (module_path in visited) {
            return;
        }
        visited.add(module_path);
        if (source_root is None) {
            source_root = module_path.parent.resolve();
        }
        (module_js, mod, manifest) = self.jac_compiler.compile_module(module_path);
        exports_list = self.jac_compiler.extract_exports(manifest);
        collected_exports.update(exports_list);
        non_root_globals: dict[(str, Any)] = {};
        if manifest {
            for name in manifest.globals {
                non_root_globals[name] = manifest.globals_values.get(name);
            }
        }
        collected_globals.update(non_root_globals);
        export_block = self.jac_compiler.generate_export_block(exports_list);
        combined_js = self.jac_compiler.add_runtime_imports(module_js);
        combined_js = f"{combined_js}\n{export_block}";
        try {
            relative_path = module_path.relative_to(source_root);
            output_path = self.compiled_dir / relative_path.with_suffix('.js');
        } except ValueError {
            output_path = self.compiled_dir / f"{module_path.stem}.js";
        }
        output_path.parent.mkdir(parents=True, exist_ok=True);
        output_path.write_text(combined_js, encoding='utf-8');
        if (not manifest or not manifest.imports) {
            return;
        }
        for (_name, import_path) in manifest.imports.items() {
            path_obj = Path(import_path).resolve();
            if (path_obj in visited) {
                continue;
            }
            if (path_obj.suffix == '.jac') {
                self.compile_dependencies_recursively(
                    path_obj,
                    visited,
                    collected_exports=collected_exports,
                    collected_globals=collected_globals,
                    source_root=source_root
                );
            } elif (path_obj.suffix == '.js') {
                self._copy_js_file(path_obj, source_root);
            } elif (path_obj.suffix in {'.ts','.tsx'}) {
                self._copy_ts_file(path_obj, source_root);
            } elif path_obj.is_file() {
                self._copy_asset_file(path_obj, source_root);
            }
        }
    }

    """Copy a JavaScript file to the compiled directory."""
    def _copy_js_file(self: ViteCompiler, js_path: Path, source_root: Path) -> None {
        try {
            js_code = js_path.read_text(encoding='utf-8');
            try {
                relative_path = js_path.relative_to(source_root);
                output_path = self.compiled_dir / relative_path;
            } except ValueError {
                output_path = self.compiled_dir / js_path.name;
            }
            output_path.parent.mkdir(parents=True, exist_ok=True);
            output_path.write_text(js_code, encoding='utf-8');
        } except FileNotFoundError { }
    }

    """Copy a TypeScript file to the compiled directory."""
    def _copy_ts_file(self: ViteCompiler, ts_path: Path, source_root: Path) -> None {
        if not ts_path.exists() {
            return;
        }
        try {
            ts_code = ts_path.read_text(encoding='utf-8');
            try {
                relative_path = ts_path.relative_to(source_root);
                output_path = self.compiled_dir / relative_path;
            } except ValueError {
                output_path = self.compiled_dir / ts_path.name;
            }
            output_path.parent.mkdir(parents=True, exist_ok=True);
            output_path.write_text(ts_code, encoding='utf-8');
        } except (FileNotFoundError, OSError) { }
    }

    """Copy an asset file to the compiled directory."""
    def _copy_asset_file(
        self: ViteCompiler, asset_path: Path, source_root: Path
    ) -> None {
        if not asset_path.exists() {
            return;
        }
        try {
            relative_path = asset_path.relative_to(source_root);
            output_path = self.compiled_dir / relative_path;
        } except ValueError {
            output_path = self.compiled_dir / asset_path.name;
        }
        output_path.parent.mkdir(parents=True, exist_ok=True);
        with contextlib.suppress(FileNotFoundError, OSError) {
            output_path.write_text(
                asset_path.read_text(encoding='utf-8'), encoding='utf-8'
            );
        }
    }

    """Copy assets from root assets/ folder to compiled/assets/ for @jac-client/assets alias."""
    def copy_root_assets(self: ViteCompiler) -> None {
        root_assets_dir = self.project_dir / 'assets';
        compiled_assets_dir = self.compiled_dir / 'assets';
        if (root_assets_dir.exists() and root_assets_dir.is_dir()) {
            self.asset_processor.copy_assets(root_assets_dir, compiled_assets_dir);
        }
    }

    """Create the main entry file for Vite bundling."""
    def create_entry_file(self: ViteCompiler) -> None {
        entry_file = self.compiled_dir / 'main.js';
        entry_content = 'import React from "react";\nimport { createRoot } from "react-dom/client";\nimport { app as App } from "./app.js";\n\nconst root = createRoot(document.getElementById("root"));\nroot.render(<App />);\n';
        entry_file.write_text(entry_content, encoding='utf-8');
    }

    """Compile module and dependencies, then bundle with Vite."""
    def compile_and_bundle(
        self: ViteCompiler, module: ModuleType, module_path: Path
    ) -> tuple[str, str, list[str], list[str]] {
        self.compile_runtime_utils();
        (module_js, mod, module_manifest) = self.jac_compiler.compile_module(
            module_path
        );
        collected_exports: set[str] = set(
            self.jac_compiler.extract_exports(module_manifest)
        );
        client_globals_map = self.jac_compiler.extract_globals(module_manifest, module);
        collected_globals: dict[(str, Any)] = dict(client_globals_map);
        self.compile_dependencies_recursively(
            module_path,
            collected_exports=collected_exports,
            collected_globals=collected_globals
        );
        self.copy_root_assets();
        self.create_entry_file();
        self.babel_processor.compile();
        self.babel_processor.copy_assets_after_compile(
            self.compiled_dir, (self.project_dir / 'build'), self.asset_processor
        );
        entry_file = self.project_dir / 'build' / 'main.js';
        self.vite_bundler.build(entry_file=entry_file);
        (bundle_code, bundle_hash) = self.vite_bundler.read_bundle();
        client_exports = sorted(collected_exports);
        client_globals = list(collected_globals.keys());
        return (bundle_code, bundle_hash, client_exports, client_globals);
    }
}
