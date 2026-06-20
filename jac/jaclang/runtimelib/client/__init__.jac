"""Core client build plumbing: bun toolchain, Vite bundler, config, npm install, jac->js bridge."""

import from .bun_installer { get_bun, BUN_VERSION }
import from .client_deps { ensure_client_deps }
import from .asset_processor { AssetProcessor }
import from .config_loader { JacClientConfig }
import from .import_processor { ImportProcessor }
import from .jac_to_js { JacToJSCompiler }
import from .vite_bundler { ViteBundler }
import from .route_scanner { RouteScanner, RouteEntry }
import from .compiler { ViteCompiler }
import from .vite_client_bundle { ViteClientBundleBuilder, make_client_bundle_builder }

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
     ];
