"""Offline tests for client page rendering without sockets."""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from jaclang.runtimelib.runtime import JacRuntime as Jac
from jaclang.runtimelib.server import JacAPIServer
from jaclang.runtimelib.tests.conftest import fixture_abs_path


@pytest.fixture(autouse=True)
def reset_machine():
    """Reset Jac machine before and after each test."""
    Jac.reset_machine()
    yield
    Jac.reset_machine()


def make_server() -> JacAPIServer:
    """Create a test server instance."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    Jac.jac_import("client_app", str(fixtures_dir))
    server = JacAPIServer(
        module_name="client_app",
        session_path=str(fixture_abs_path("client.session")),
    )
    server.load_module()
    return server


def test_render_client_page_returns_html():
    """Test that render_client_page returns HTML."""
    server = make_server()
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
    assert payload.get("module") == "client_app"
    assert payload.get("function") == "client_page"
    assert payload.get("globals", {}).get("API_LABEL") == "Runtime Test"
    assert payload.get("argOrder") == []

    bundle_code = server.get_client_bundle_code()
    assert "function __jacJsx" in bundle_code
    assert bundle_code == html_bundle["bundle_code"]


def test_render_unknown_page_raises():
    """Test that rendering unknown page raises ValueError."""
    server = make_server()
    server.user_manager.create_user("tester", "pass")

    with pytest.raises(ValueError):
        server.render_client_page("missing", {}, "tester")
