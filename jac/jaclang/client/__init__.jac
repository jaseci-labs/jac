glob __all__ = [
         'get_bun',
         'BUN_VERSION',
         'ensure_client_deps',
         'AssetProcessor',
         'JacClientConfig',
         'JacToJSCompiler',
         'ViteBundler',
         'RouteScanner',
         'RouteEntry',
         'ViteCompiler',
         'ViteClientBundleBuilder',
         'make_client_bundle_builder'
     ],
     _LAZY_EXPORTS: dict[str, str] = {
         'get_bun': 'jaclang.client.bun_installer',
         'BUN_VERSION': 'jaclang.client.bun_installer',
         'ensure_client_deps': 'jaclang.client.client_deps',
         'AssetProcessor': 'jaclang.client.asset_processor',
         'JacClientConfig': 'jaclang.client.config_loader',
         'JacToJSCompiler': 'jaclang.client.jac_to_js',
         'ViteBundler': 'jaclang.client.vite_bundler',
         'RouteScanner': 'jaclang.client.route_scanner',
         'RouteEntry': 'jaclang.client.route_scanner',
         'ViteCompiler': 'jaclang.client.compiler',
         'ViteClientBundleBuilder': 'jaclang.client.vite_client_bundle',
         'make_client_bundle_builder': 'jaclang.client.vite_client_bundle'
     };

def __getattr__(name: str) -> object {
    mod_path = _LAZY_EXPORTS.get(name);
    if mod_path is None {
        raise AttributeError(f"module 'jaclang.client' has no attribute {name!r}");
    }
    import importlib;
    value = getattr(importlib.import_module(mod_path), name);
    globals()[name] = value;
    return value;
}
