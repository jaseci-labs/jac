"""Jac Client plugin for client-side rendering."""
import hashlib;
import html;
import mimetypes;
import types;
import from http.server { BaseHTTPRequestHandler }
import from pathlib { Path }
import from typing { Any, Literal, TypeAlias }
import from jaclang.runtimelib.client_bundle { ClientBundle, ClientBundleError }
import from jaclang.runtimelib.runtime { JacRuntime as Jac }
import from jaclang.runtimelib.runtime { hookimpl }
import from jaclang.runtimelib.server { ModuleIntrospector }
import from .vite_client_bundle { ViteClientBundleBuilder }
import from .src.vite_bundler { ViteBundler }
import from .src.hmr {
    ViteDevServer,
    HMRCompiler,
    get_client_dir,
    calc_output_path,
    write_file,
    JS_EXTENSIONS
}

glob JsonValue: TypeAlias = None | str | int | float | bool | list['JsonValue'] | dict[
         (str, 'JsonValue')
     ],
     StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 503)];

"""Jac Client Module Introspector."""
class JacClientModuleIntrospector(ModuleIntrospector) {
    def render_page(
        self: JacClientModuleIntrospector,
        function_name: str,
        args: dict[(str, Any)],
        username: str
    ) -> dict[str, Any];
}

"""Jac Client."""
class JacClient {
    @hookimpl
    static def get_client_bundle_builder -> ViteClientBundleBuilder;

    @hookimpl
    static def build_client_bundle(
        module: types.ModuleType, force: bool = False
    ) -> ClientBundle;

    @hookimpl
    static def get_module_introspector(
        module_name: str, base_path: (str | None)
    ) -> ModuleIntrospector;

    @hookimpl
    static def send_static_file(
        handler: BaseHTTPRequestHandler,
        file_path: Path,
        content_type: (str | None) = None
    ) -> None;

    @hookimpl
    static def start_dev_server(
        module_path: Path, host: str = 'localhost', port: int = 3000
    ) -> None;

    @hookimpl
    static def on_dev_server_start(dev_server: Any) -> bool;

    @hookimpl
    static def on_frontend_file_change(file_path: Path, change_type: str) -> None;
}
