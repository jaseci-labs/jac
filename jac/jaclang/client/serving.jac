import hashlib;
import html;
import json;
import re;
import from pathlib { Path }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.server.server { ModuleIntrospector }

obj HeaderBuilder {
    has meta_data: dict[str, any],
        function_name: str,
        DEFAULTS: dict[str, any] = {
            "charset": "UTF-8",
            "viewport": "width=device-width,initial-scale=1"
        },
        standard_tags: list[str] = [
            "description",
            "keywords",
            "author",
            "robots",
            "theme_color"
        ];

    def build_head -> str;
    def build_scripts -> list[str];
    def _script_tag(spec: dict[str, any]) -> str;
    def _get_value(key: str) -> (str | None);
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
        args: dict[(str, any)],
        username: str
    ) -> dict[str, any];

    static def get_client_js(introspector: ModuleIntrospector) -> str;
}
