glob __all__ = [
         'get_bun',
         'BUN_VERSION',
         'ensure_client_deps',
         'AssetProcessor',
         'JacClientConfig',
         'ImportProcessor',
         'JacToJSCompiler',
         'ViteBundler',
         'RouteScanner',
         'RouteEntry',
         'ViteCompiler',
         'ViteClientBundleBuilder',
         'make_client_bundle_builder'
     ],
     _LAZY_EXPORTS: dict[str, str] = {
         'get_bun': 'jaclang.runtimelib.client.bun_installer',
         'BUN_VERSION': 'jaclang.runtimelib.client.bun_installer',
         'ensure_client_deps': 'jaclang.runtimelib.client.client_deps',
         'AssetProcessor': 'jaclang.runtimelib.client.asset_processor',
         'JacClientConfig': 'jaclang.runtimelib.client.config_loader',
         'ImportProcessor': 'jaclang.runtimelib.client.import_processor',
         'JacToJSCompiler': 'jaclang.runtimelib.client.jac_to_js',
         'ViteBundler': 'jaclang.runtimelib.client.vite_bundler',
         'RouteScanner': 'jaclang.runtimelib.client.route_scanner',
         'RouteEntry': 'jaclang.runtimelib.client.route_scanner',
         'ViteCompiler': 'jaclang.runtimelib.client.compiler',
         'ViteClientBundleBuilder': 'jaclang.runtimelib.client.vite_client_bundle',
         'make_client_bundle_builder': 'jaclang.runtimelib.client.vite_client_bundle'
     };

def __getattr__(name: str) -> object {
    mod_path = _LAZY_EXPORTS.get(name);
    if mod_path is None {
        raise AttributeError(
            f"module 'jaclang.runtimelib.client' has no attribute {name!r}"
        );
    }
    import importlib;
    return getattr(importlib.import_module(mod_path), name);
}
