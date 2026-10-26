glob __all__ = [
         'js_runtime_path',
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
         'js_runtime_path': 'jaclang.client.js_runtime',
         'BUN_VERSION': 'jaclang.client.js_runtime',
         'ensure_client_deps': 'jaclang.client.client_deps',
         'AssetProcessor': 'jaclang.client.asset_processor',
         'JacClientConfig': 'jaclang.client.config_loader',
         'ImportProcessor': 'jaclang.client.import_processor',
         'JacToJSCompiler': 'jaclang.client.jac_to_js',
         'ViteBundler': 'jaclang.client.vite_bundler',
         'RouteScanner': 'jaclang.client.route_scanner',
         'RouteEntry': 'jaclang.client.route_scanner',
         'ViteCompiler': 'jaclang.client.compiler',
         'ViteClientBundleBuilder': 'jaclang.client.vite_client_bundle',
         'make_client_bundle_builder': 'jaclang.client.vite_client_bundle'
     };

def __getattr__(name: str) -> object;
