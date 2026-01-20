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

glob JsonValue: TypeAlias = None | str | int | float | bool | list['JsonValue'] | dict[
         (str, 'JsonValue')
     ],
     StatusCode: TypeAlias = Literal[(200, 201, 400, 401, 404, 503)];

"""Builds HTML head content from meta data."""
obj HeaderBuilder {
    has meta_data: dict,
        function_name: str,
        DEFAULTS: dict = {
            "charset": "UTF-8",
            "viewport": "width=device-width,initial-scale=1"
        },
        standard_tags: list = [
            "description",
            "keywords",
            "author",
            "robots",
            "theme_color"
        ];

    def build_head -> str;
    def _get_value(key: str) -> str;
    def _build_special_tags -> list[str];
    def _build_meta_tags -> list[str];
    def _build_og_tags -> list[str];
    def _build_link_tags -> list[str];
    def _build_generic_meta_tags -> list[str];
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
    static def send_static_file(
        handler: BaseHTTPRequestHandler,
        file_path: Path,
        content_type: (str | None) = None
    ) -> None;

    @hookimpl
    static def render_page(
        introspector: ModuleIntrospector,
        function_name: str,
        args: dict[(str, Any)],
        username: str
    ) -> dict[str, Any];
}
