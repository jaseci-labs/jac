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
class HeaderBuilder {
    with entry {
        HEAD_SCHEMA: dict = {
            "meta": {
                "charset": {"attr": "charset", "dflt": "UTF-8"},
                "viewport": {
                    "name": "viewport",
                    "dflt": "width=device-width,initial-scale=1"
                },
                "robots": {"name": "robots", "dflt": "index,follow"},
                "theme_color": {"name": "theme-color", "dflt": "#ffffff"},
                "description": {"name": "description", "dflt": None},

            },
            "title": True,
            "og": {
                "og_type": {"name": "type", "dflt": "website"},
                "og_title": {"name": "title", "dflt": None},
                "og_description": {"name": "description", "dflt": None},
                "og_url": {"name": "url", "dflt": None},
                "og_image": {"name": "image", "dflt": None},

            },
            "link": {
                "canonical": {"rel": "canonical", "attr": "href", "dflt": None},
                "icon": {"rel": "icon", "attr": "href", "dflt": None},

            },

        };
    }

    def init(self: HeaderBuilder, meta_data: dict, function_name: str);
    def build_head(self: HeaderBuilder) -> str;
}

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
}
