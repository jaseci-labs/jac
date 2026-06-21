"""Jac Client plugin for client-side rendering."""
import hashlib;
import html;
import json;
import mimetypes;
import types;
import from http.server { BaseHTTPRequestHandler }
import from pathlib { Path }
import from typing { Any, Literal, TypeAlias }
import from jaclang.runtimelib.runtime { JacRuntime as Jac }
import from jaclang.runtimelib.server { ModuleIntrospector }

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

"""Jac Client.

Client bundling (`get_client_bundle_builder` / `build_client_bundle`) is handled
by core's default hook (the single Vite/Bun pipeline in jaclang.runtimelib.client).
This plugin provides the framework serving layer: static files, page rendering,
the client JS endpoint, and rich build-error formatting.
"""
class JacClient {
    static def send_static_file(
        handler: BaseHTTPRequestHandler,
        file_path: Path,
        content_type: (str | None) = None
    ) -> None;

    static def render_page(
        introspector: ModuleIntrospector,
        function_name: str,
        args: dict[(str, Any)],
        username: str
    ) -> dict[str, any];

    static def get_client_js(introspector: ModuleIntrospector) -> str;
    static def format_build_error(
        error_output: str, project_dir: Path, config: object = None
    ) -> str;
}
