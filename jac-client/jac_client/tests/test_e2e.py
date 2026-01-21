"""Browser-level E2E tests for jac-client authentication flows."""

from __future__ import annotations

import gc
import os
import shutil
import tempfile
import time
from subprocess import PIPE, Popen, run

import pytest

pytest.importorskip("playwright")

from playwright.sync_api import Browser, Page

from .test_helpers import (
    get_env_with_npm,
    get_free_port,
    get_jac_command,
    wait_for_port,
)


@pytest.fixture(scope="module")
def running_server():
    """Start the all-in-one jac server for the test module and yield its URL.

    Yields a dict with keys `port` and `url`.
    """
    tests_dir = os.path.dirname(__file__)
    jac_client_root = os.path.dirname(tests_dir)
    all_in_one_path = os.path.join(jac_client_root, "examples", "all-in-one")

    if not os.path.isdir(all_in_one_path):
        pytest.skip("all-in-one example directory not found")

    app_name = "e2e-browser-test-app"
    jac_cmd = get_jac_command()
    env = get_env_with_npm()

    with tempfile.TemporaryDirectory() as temp_dir:
        original_cwd = os.getcwd()
        try:
            os.chdir(temp_dir)
            process = Popen(
                [*jac_cmd, "create", "--use", "client", app_name],
                stdin=PIPE,
                stdout=PIPE,
                stderr=PIPE,
                text=True,
                env=env,
            )
            stdout, stderr = process.communicate()
            if process.returncode != 0:
                pytest.fail(f"jac create --use client failed: {stderr}")

            project_path = os.path.join(temp_dir, app_name)

            for entry in os.listdir(all_in_one_path):
                if entry in {"node_modules", "build", "dist", ".pytest_cache"}:
                    continue
                src = os.path.join(all_in_one_path, entry)
                dst = os.path.join(project_path, entry)
                if os.path.isdir(src):
                    shutil.copytree(src, dst, dirs_exist_ok=True)
                else:
                    shutil.copy2(src, dst)

            jac_add_result = run(
                [*jac_cmd, "add", "--npm"],
                cwd=project_path,
                capture_output=True,
                text=True,
                env=env,
            )
            if jac_add_result.returncode != 0:
                pytest.fail(f"jac add --npm failed: {jac_add_result.stderr}")

            server_port = get_free_port()
            server = Popen(
                [*jac_cmd, "start", "main.jac", "-p", str(server_port)],
                cwd=project_path,
                env=env,
            )

            try:
                wait_for_port("127.0.0.1", server_port, timeout=90.0)
                time.sleep(5)
                yield {"port": server_port, "url": f"http://127.0.0.1:{server_port}"}

            finally:
                server.terminate()
                try:
                    server.wait(timeout=15)
                except Exception:
                    server.kill()
                    server.wait(timeout=5)
                time.sleep(1)
                gc.collect()

        finally:
            os.chdir(original_cwd)
            gc.collect()


@pytest.fixture(scope="module")
def browser():
    """Provide a Playwright browser instance for the module."""
    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        yield browser
        browser.close()


@pytest.fixture
def page(browser: Browser):
    """Provide a fresh browser page for each test and close context afterwards."""
    context = browser.new_context()
    page = context.new_page()
    yield page
    context.close()


class TestAuthenticationE2E:
    """E2E tests for auth flows with helper methods to reduce duplication."""

    @staticmethod
    def _fill_auth_form(page: Page, username: str, password: str) -> None:
        """Fill username and password fields."""
        page.locator('input[type="text"], input[placeholder="Username" i]').first.fill(
            username
        )
        page.locator('input[type="password"]').first.fill(password)

    @staticmethod
    def _submit_form(page: Page) -> None:
        """Click submit button and wait for navigation."""
        page.locator('button[type="submit"]').first.click()
        page.wait_for_timeout(2000)

    def _signup(self, page: Page, base_url: str, username: str, password: str) -> None:
        """Navigate to signup, fill form, and submit."""
        page.goto(f"{base_url}#/signup", wait_until="networkidle", timeout=60000)
        page.wait_for_selector('input[type="text"]', timeout=30000)
        self._fill_auth_form(page, username, password)
        self._submit_form(page)

    def _login(self, page: Page, base_url: str, username: str, password: str) -> None:
        """Navigate to login, fill form, and submit."""
        page.goto(f"{base_url}#/login", wait_until="networkidle", timeout=30000)
        page.wait_for_selector('input[type="text"]', timeout=30000)
        self._fill_auth_form(page, username, password)
        self._submit_form(page)

    def _logout(self, page: Page) -> None:
        """Click logout button if visible."""
        logout_btn = page.locator('button:has-text("Logout")').first
        if logout_btn.is_visible():
            logout_btn.click()
            page.wait_for_timeout(1000)

    def test_navigate_without_auth(self, running_server: dict, page: Page) -> None:
        """Visiting protected route without auth should redirect to login."""
        page.goto(
            f"{running_server['url']}#/nested", wait_until="networkidle", timeout=60000
        )
        page.wait_for_timeout(2000)
        assert "#/login" in page.url.lower()

    def test_signup_form_submission(self, running_server: dict, page: Page) -> None:
        """Signup via UI should redirect away from signup page on success."""
        self._signup(
            page,
            running_server["url"],
            f"e2e_signup_{int(time.time())}",
            "test_pass_123",
        )
        assert "#/signup" not in page.url.lower()

    def test_login_with_valid_credentials(
        self, running_server: dict, page: Page
    ) -> None:
        """Verify login succeeds for valid credentials."""
        base_url = running_server["url"]
        username, password = f"e2e_login_{int(time.time())}", "valid_pass_123"

        self._signup(page, base_url, username, password)
        self._logout(page)
        self._login(page, base_url, username, password)

        assert "#/login" not in page.url.lower() and "#/signup" not in page.url.lower()

    def test_login_with_invalid_credentials(
        self, running_server: dict, page: Page
    ) -> None:
        """Verify login fails for invalid credentials (stays or shows error)."""
        self._login(page, running_server["url"], "nonexistent_999", "wrong_pass")

        assert "#/login" in page.url.lower()
        assert page.locator("text=/Invalid credentials/i").first.is_visible()

    def test_logout_functionality(self, running_server: dict, page: Page) -> None:
        """Signup then logout should redirect to login."""
        base_url = running_server["url"]
        self._signup(
            page, base_url, f"e2e_logout_{int(time.time())}", "logout_pass_123"
        )

        logout_btn = page.locator('button:has-text("Logout")').first
        logout_btn.click()
        page.wait_for_timeout(1500)

        assert "#/login" in page.url.lower() and not logout_btn.is_visible(timeout=5000)

    def test_complete_auth_flow(self, running_server: dict, page: Page) -> None:
        """Integration: signup -> logout -> login -> access protected route."""
        base_url = running_server["url"]
        username, password = f"e2e_complete_{int(time.time())}", "complete_pass_123"

        self._signup(page, base_url, username, password)
        assert "#/signup" not in page.url.lower()

        self._logout(page)
        self._login(page, base_url, username, password)
        assert "#/login" not in page.url.lower()

        page.goto(f"{base_url}#/nested", wait_until="networkidle", timeout=30000)
        assert "#/nested" in page.url.lower()
