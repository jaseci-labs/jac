"""Offline tests for client page rendering without sockets."""

from __future__ import annotations

import json
import re
import shutil
import socket
import uuid
from collections.abc import Generator
from pathlib import Path

import pytest

from jaclang import JacRuntime as Jac
from jaclang.runtimelib.server import JacAPIServer


def get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


@pytest.fixture
def isolated_fixtures(
    fresh_jac_context: Path,
) -> Generator[tuple[Path, str], None, None]:
    """Copy fixtures to temp directory for test isolation.

    This prevents parallel test interference with shared .jac cache.
    Returns tuple of (fixtures_path, unique_module_name).
    """
    fixtures_src = Path(__file__).parent / "fixtures"
    # Use unique module name to avoid parallel test conflicts
    unique_id = uuid.uuid4().hex[:8]
    module_name = f"client_app_{unique_id}"
    fixtures_dest = fresh_jac_context / module_name
    # Copy only the .jac source files, not the .jac cache directory
    fixtures_dest.mkdir(parents=True, exist_ok=True)
    for f in fixtures_src.glob("*.jac"):
        if f.is_file():  # Skip .jac directory
            # Rename client_app.jac to unique module name
            dest_name = f.name
            if f.name == "client_app.jac":
                dest_name = f"{module_name}.jac"
            shutil.copy(f, fixtures_dest / dest_name)
    yield (fixtures_dest, module_name)


def make_server(fixtures_dir: Path, module_name: str) -> JacAPIServer:
    """Create a test server instance."""
    Jac.jac_import(module_name, str(fixtures_dir))
    server = JacAPIServer(
        module_name=module_name,
        base_path=str(fixtures_dir),
        port=get_free_port(),
    )
    server.load_module()
    return server


def test_render_client_page_returns_html(
    isolated_fixtures: tuple[Path, str],
) -> None:
    """Test that render_client_page returns HTML."""
    fixtures_dir, module_name = isolated_fixtures
    server = make_server(fixtures_dir, module_name)
    server.user_manager.create_user("tester", "pass")
    html_bundle = server.render_client_page("client_page", {}, "tester")

    assert "<!DOCTYPE html>" in html_bundle["html"]
    assert '<div id="__jac_root"></div>' in html_bundle["html"]
    assert "/static/client.js?hash=" in html_bundle["html"]

    init_match = re.search(
        r'<script id="__jac_init__" type="application/json">([^<]*)</script>',
        html_bundle["html"],
    )
    assert init_match is not None
    payload = json.loads(init_match.group(1)) if init_match else {}
    assert payload.get("module") == module_name
    assert payload.get("function") == "client_page"
    assert payload.get("globals", {}).get("API_LABEL") == "Runtime Test"
    assert payload.get("argOrder") == []

    bundle_code = server.get_client_bundle_code()
    assert "function __jacJsx" in bundle_code
    assert bundle_code == html_bundle["bundle_code"]
    server.server.server_close()


def test_render_unknown_page_raises(isolated_fixtures: tuple[Path, str]) -> None:
    """Test that rendering unknown page raises ValueError."""
    fixtures_dir, module_name = isolated_fixtures
    server = make_server(fixtures_dir, module_name)
    server.user_manager.create_user("tester", "pass")

    with pytest.raises(ValueError):
        server.render_client_page("missing", {}, "tester")
    server.server.server_close()
