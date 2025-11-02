"""Offline tests for client page rendering without sockets."""

from __future__ import annotations

import json
import re
from pathlib import Path

from jaclang.runtimelib.machine import JacMachine as Jac
from jaclang.runtimelib.server import JacAPIServer
from jaclang.utils.test import TestCase


class ClientRenderTests(TestCase):
    """Validate client bundle helpers without opening sockets."""

    def setUp(self) -> None:
        Jac.reset_machine()
        super().setUp()

    def tearDown(self) -> None:
        Jac.reset_machine()
        super().tearDown()

    def _make_server(self) -> JacAPIServer:
        fixtures_dir = Path(__file__).parent / "fixtures"
        Jac.jac_import("client_app", str(fixtures_dir))
        server = JacAPIServer(
            module_name="client_app", session_path=str(self.fixture_abs_path("client.session"))
        )
        server.load_module()
        return server

    def test_render_client_page_returns_html(self) -> None:
        server = self._make_server()
        server.user_manager.create_user("tester", "pass")
        html_bundle = server.render_client_page("client_page", {}, "tester")

        self.assertIn("<!DOCTYPE html>", html_bundle["html"])
        self.assertIn('<div id="__jac_root"></div>', html_bundle["html"])
        self.assertIn("/static/client.js?hash=", html_bundle["html"])

        init_match = re.search(
            r'<script id="__jac_init__" type="application/json">([^<]*)</script>',
            html_bundle["html"],
        )
        self.assertIsNotNone(init_match)
        payload = json.loads(init_match.group(1)) if init_match else {}
        self.assertEqual(payload.get("module"), "client_app")
        self.assertEqual(payload.get("function"), "client_page")
        self.assertEqual(payload.get("globals", {}).get("API_LABEL"), "Runtime Test")
        self.assertEqual(payload.get("argOrder"), [])

        bundle_code = server.get_client_bundle_code()
        self.assertIn("function __jacJsx", bundle_code)
        self.assertEqual(bundle_code, html_bundle["bundle_code"])

    def test_render_unknown_page_raises(self) -> None:
        server = self._make_server()
        server.user_manager.create_user("tester", "pass")

        with self.assertRaises(ValueError):
            server.render_client_page("missing", {}, "tester")
