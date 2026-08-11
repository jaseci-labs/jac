import hashlib;
import html;
import json;
import re;
import from pathlib { Path }
import from typing { Any }
import from jaclang.jac0core.runtime { JacRuntime as Jac }
import from jaclang.runtimelib.server { ModuleIntrospector }

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
    def build_scripts -> list[str];
    def _script_tag(spec: dict) -> str;
    def _get_value(key: str) -> str;
    def _og_property(suffix: str) -> str;
    def _build_special_tags -> list[str];
    def _build_meta_tags -> list[str];
    def _build_og_tags -> list[str];
    def _build_twitter_tags -> list[str];
    def _build_link_tags -> list[str];
    def _build_generic_meta_tags -> list[str];
}

class JacClient {
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
