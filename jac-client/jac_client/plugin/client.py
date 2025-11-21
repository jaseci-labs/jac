import hashlib
import html
import mimetypes
import types
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from typing import Any, Literal, TypeAlias

from jaclang.runtimelib.client_bundle import ClientBundle
from jaclang.runtimelib.machine import (
    JacMachine as Jac,
    hookimpl,
)
from jaclang.runtimelib.server import ModuleIntrospector

from .vite_client_bundle import ViteClientBundleBuilder

JsonValue: TypeAlias = (
    None | str | int | float | bool | list["JsonValue"] | dict[str, "JsonValue"]
)
StatusCode: TypeAlias = Literal[200, 201, 400, 401, 404, 503]


class JacClientModuleIntrospector(ModuleIntrospector):
    """Jac Client Module Introspector."""

    def render_page(
        self, function_name: str, args: dict[str, Any], username: str
    ) -> dict[str, Any]:
        """Render HTML page for client function using the Vite bundle."""
        self.load()

        available_exports = set(self._client_manifest.get("exports", [])) or set(
            self.get_client_functions().keys()
        )
        if function_name not in available_exports:
            raise ValueError(f"Client function '{function_name}' not found")

        bundle_hash = self.ensure_bundle()

        # Find CSS file in dist directory
        base_path = Path(Jac.base_path_dir)
        dist_dir = base_path / "dist"
        css_link = ""

        # Try to find CSS file (main.css is the default Vite output)
        css_file = dist_dir / "main.css"
        if css_file.exists():
            css_hash = hashlib.sha256(css_file.read_bytes()).hexdigest()[:8]
            css_link = (
                f'<link rel="stylesheet" href="/static/main.css?hash={css_hash}"/>'
            )

        head_content = f'<meta charset="utf-8"/>\n            <title>{html.escape(function_name)}</title>'
        if css_link:
            head_content += f"\n            {css_link}"

        page = (
            "<!DOCTYPE html>"
            '<html lang="en">'
            "<head>"
            f"{head_content}"
            "</head>"
            "<body>"
            '<div id="root"></div>'
            f'<script src="/static/client.js?hash={bundle_hash}" defer></script>'
            "</body>"
            "</html>"
        )

        return {
            "html": page,
            "bundle_hash": bundle_hash,
            "bundle_code": self._bundle.code,
        }


class JacClient:
    """Jac Client."""

    @staticmethod
    @hookimpl
    def get_client_bundle_builder() -> ViteClientBundleBuilder:
        """Get the client bundle builder instance."""
        base_path = Path(Jac.base_path_dir)
        package_json_path = base_path / "package.json"
        output_dir = base_path / "dist"
        # Use the plugin's client_runtime.jac file
        runtime_path = Path(__file__).with_name("client_runtime.jac")
        return ViteClientBundleBuilder(
            runtime_path=runtime_path,
            vite_package_json=package_json_path,
            vite_output_dir=output_dir,
            vite_minify=False,
        )

    @staticmethod
    @hookimpl
    def build_client_bundle(
        module: types.ModuleType,
        force: bool = False,
    ) -> ClientBundle:
        """Build a client bundle for the supplied module."""
        builder = JacClient.get_client_bundle_builder()
        return builder.build(module, force=force)

    @staticmethod
    @hookimpl
    def get_module_introspector(
        module_name: str, base_path: str | None
    ) -> ModuleIntrospector:
        """Get a module introspector for the supplied module."""
        return JacClientModuleIntrospector(module_name, base_path)

    @staticmethod
    @hookimpl
    def send_static_file(
        handler: BaseHTTPRequestHandler,
        file_path: Path,
        content_type: str | None = None,
    ) -> None:
        """Send static file response (images, fonts, etc.).

        Args:
            handler: HTTP request handler
            file_path: Path to the file to serve
            content_type: MIME type (auto-detected if None)
        """
        from jaclang.runtimelib.server import ResponseBuilder

        if not file_path.exists() or not file_path.is_file():
            ResponseBuilder.send_json(handler, 404, {"error": "File not found"})
            return

        try:
            file_content = file_path.read_bytes()
            if content_type is None:
                content_type, _ = mimetypes.guess_type(str(file_path))
                if content_type is None:
                    content_type = "application/octet-stream"

            handler.send_response(200)
            handler.send_header("Content-Type", content_type)
            handler.send_header("Content-Length", str(len(file_content)))
            handler.send_header("Cache-Control", "public, max-age=3600")
            ResponseBuilder._add_cors_headers(handler)
            handler.end_headers()
            handler.wfile.write(file_content)
        except Exception as exc:
            ResponseBuilder.send_json(handler, 500, {"error": str(exc)})
