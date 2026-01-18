"""HMR (Hot Module Replacement) tests using JacTestClient.

These tests verify HMR functionality without starting real servers.
The reload() method simulates what happens when a file changes.
"""

from __future__ import annotations

import contextlib
from collections.abc import Generator
from pathlib import Path

import pytest

from jaclang.runtimelib.hmr import HotReloader
from jaclang.runtimelib.testing import JacTestClient
from jaclang.runtimelib.watcher import JacFileWatcher


class TestHMRWalkerReload:
    """Tests for walker hot reloading via JacTestClient."""

    @pytest.fixture
    def temp_project(self, tmp_path: Path) -> Generator[Path, None, None]:
        """Create a temporary project directory."""
        yield tmp_path

    def test_walker_code_reloads_after_file_change(self, temp_project: Path) -> None:
        """Test that walker code is actually reloaded when file changes."""
        app_file = temp_project / "app.jac"

        # Version 1: walker returns value 1
        app_file.write_text(
            """
walker get_value {
    can enter with `root entry {
        report {"value": 1};
    }
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project))

        try:
            # Register user for authenticated requests
            client.register_user("testuser", "password123")

            # Call walker - should return 1
            response1 = client.post("/walker/get_value", json={})
            assert response1.ok
            reports1 = response1.data.get("reports", [])
            assert len(reports1) > 0
            assert reports1[0].get("value") == 1

            # Version 2: update walker to return value 2
            app_file.write_text(
                """
walker get_value {
    can enter with `root entry {
        report {"value": 2};
    }
}
"""
            )

            # Trigger reload
            client.reload()

            # Call walker again - should now return 2
            response2 = client.post("/walker/get_value", json={})
            assert response2.ok
            reports2 = response2.data.get("reports", [])
            assert len(reports2) > 0
            assert reports2[0].get("value") == 2

            # Verify the value actually changed
            assert reports1[0].get("value") != reports2[0].get("value")

        finally:
            client.close()

    def test_global_variable_reloads(self, temp_project: Path) -> None:
        """Test that global variables are reloaded."""
        app_file = temp_project / "app.jac"

        # Version 1
        app_file.write_text(
            """
glob VERSION = 1;

walker get_version {
    can enter with `root entry {
        report {"version": VERSION};
    }
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project))

        try:
            client.register_user("testuser", "password123")

            # Get version 1
            response1 = client.post("/walker/get_version", json={})
            assert response1.ok
            v1 = response1.data.get("reports", [{}])[0].get("version")
            assert v1 == 1

            # Version 2
            app_file.write_text(
                """
glob VERSION = 2;

walker get_version {
    can enter with `root entry {
        report {"version": VERSION};
    }
}
"""
            )

            client.reload()

            # Get version 2
            response2 = client.post("/walker/get_version", json={})
            assert response2.ok
            v2 = response2.data.get("reports", [{}])[0].get("version")
            assert v2 == 2

        finally:
            client.close()

    def test_new_walker_available_after_reload(self, temp_project: Path) -> None:
        """Test that newly added walkers are available after reload."""
        app_file = temp_project / "app.jac"

        # Version 1: only one walker
        app_file.write_text(
            """
walker walker_one {
    can enter with `root entry {
        report {"name": "one"};
    }
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(temp_project))

        try:
            client.register_user("testuser", "password123")

            # walker_one should work
            response1 = client.post("/walker/walker_one", json={})
            assert response1.ok

            # walker_two should not exist
            response2 = client.post("/walker/walker_two", json={})
            assert not response2.ok or "error" in str(response2.data)

            # Version 2: add walker_two
            app_file.write_text(
                """
walker walker_one {
    can enter with `root entry {
        report {"name": "one"};
    }
}

walker walker_two {
    can enter with `root entry {
        report {"name": "two"};
    }
}
"""
            )

            client.reload()

            # Both walkers should now work
            response3 = client.post("/walker/walker_one", json={})
            assert response3.ok

            response4 = client.post("/walker/walker_two", json={})
            assert response4.ok
            assert response4.data.get("reports", [{}])[0].get("name") == "two"

        finally:
            client.close()


class TestHMRMultipleReloads:
    """Tests for multiple consecutive reloads."""

    def test_multiple_rapid_reloads(self, tmp_path: Path) -> None:
        """Test that multiple rapid reloads work correctly."""
        app_file = tmp_path / "app.jac"

        app_file.write_text(
            """
glob COUNTER = 0;

walker get_counter {
    can enter with `root entry {
        report {"counter": COUNTER};
    }
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(tmp_path))

        try:
            client.register_user("testuser", "password123")

            # Perform multiple reloads with different values
            for i in range(1, 6):
                app_file.write_text(
                    f"""
glob COUNTER = {i};

walker get_counter {{
    can enter with `root entry {{
        report {{"counter": COUNTER}};
    }}
}}
"""
                )

                client.reload()

                response = client.post("/walker/get_counter", json={})
                assert response.ok
                counter = response.data.get("reports", [{}])[0].get("counter")
                assert counter == i, f"Expected counter={i}, got {counter}"

        finally:
            client.close()


class TestHMRFunctionReload:
    """Tests for function hot reloading."""

    def test_function_code_reloads(self, tmp_path: Path) -> None:
        """Test that function code is reloaded."""
        app_file = tmp_path / "app.jac"

        # Version 1
        app_file.write_text(
            """
def get_message() -> str {
    return "Hello Version 1";
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(tmp_path))

        try:
            client.register_user("testuser", "password123")

            # Call function
            response1 = client.post("/function/get_message", json={})
            assert response1.ok
            result1 = response1.data.get("result")
            assert "Version 1" in result1

            # Version 2
            app_file.write_text(
                """
def get_message() -> str {
    return "Hello Version 2";
}
"""
            )

            client.reload()

            response2 = client.post("/function/get_message", json={})
            assert response2.ok
            result2 = response2.data.get("result")
            assert "Version 2" in result2

        finally:
            client.close()


class TestHMRStatePreservation:
    """Tests for state handling across reloads."""

    def test_auth_token_preserved_after_reload(self, tmp_path: Path) -> None:
        """Test that authentication token is preserved after module reload."""
        app_file = tmp_path / "app.jac"

        app_file.write_text(
            """
walker get_status {
    can check with `root entry {
        report {"status": "v1"};
    }
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(tmp_path))

        try:
            client.register_user("testuser", "password123")

            # Verify auth works
            resp1 = client.post("/walker/get_status", json={})
            assert resp1.ok
            assert resp1.data.get("reports", [{}])[0].get("status") == "v1"

            # Reload module
            app_file.write_text(
                """
walker get_status {
    can check with `root entry {
        report {"status": "v2"};
    }
}
"""
            )
            client.reload()

            # Auth should still work (token preserved in client)
            resp2 = client.post("/walker/get_status", json={})
            assert resp2.ok, "Auth failed after reload"
            assert resp2.data.get("reports", [{}])[0].get("status") == "v2", (
                "Code change not applied after reload"
            )

        finally:
            client.close()

    def test_user_isolation_without_reload(self, tmp_path: Path) -> None:
        """Test that user isolation works correctly (baseline test)."""
        app_file = tmp_path / "app.jac"

        app_file.write_text(
            """
node Secret {
    has data: str;
}

walker store_secret {
    has data: str;
    can store with `root entry {
        here ++> Secret(data=self.data);
        report {"stored": self.data};
    }
}

walker get_secrets {
    can collect with `root entry {
        visit [-->];
    }
    can gather with Secret entry {
        report {"data": here.data};
    }
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(tmp_path))

        try:
            # User A stores a secret
            client.register_user("userA", "passA")
            resp1 = client.post("/walker/store_secret", json={"data": "A's secret"})
            assert resp1.ok

            # User B stores a different secret
            client.clear_auth()
            client.register_user("userB", "passB")
            resp2 = client.post("/walker/store_secret", json={"data": "B's secret"})
            assert resp2.ok

            # User B should only see their own secret
            resp3 = client.post("/walker/get_secrets", json={})
            assert resp3.ok
            secrets_b = [r.get("data") for r in resp3.data.get("reports", [])]
            assert "B's secret" in secrets_b, "User B can't see their own data"
            assert "A's secret" not in secrets_b, (
                "User isolation broken: B can see A's data"
            )

            # User A should only see their own secret
            client.login("userA", "passA")
            resp4 = client.post("/walker/get_secrets", json={})
            assert resp4.ok
            secrets_a = [r.get("data") for r in resp4.data.get("reports", [])]
            assert "A's secret" in secrets_a, "User A can't see their own data"
            assert "B's secret" not in secrets_a, (
                "User isolation broken: A can see B's data"
            )

        finally:
            client.close()


class TestHMRErrorHandling:
    """Tests for error handling during HMR."""

    def test_recovery_from_syntax_error(self, tmp_path: Path) -> None:
        """Test that module can recover from syntax error and continue working."""
        app_file = tmp_path / "app.jac"

        app_file.write_text(
            """
walker get_value {
    can check with `root entry {
        report {"value": 1};
    }
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(tmp_path))

        try:
            client.register_user("testuser", "password123")

            # Verify initial code works
            resp1 = client.post("/walker/get_value", json={})
            assert resp1.ok
            assert resp1.data.get("reports", [{}])[0].get("value") == 1

            # Introduce syntax error
            app_file.write_text(
                """
walker get_value {
    can check with `root entry {
        # SYNTAX ERROR - missing closing brace
        report {"value": 2};
}
"""
            )

            # Reload should handle error gracefully (not crash)
            with contextlib.suppress(Exception):
                client.reload()

            # Fix the syntax error with new value
            app_file.write_text(
                """
walker get_value {
    can check with `root entry {
        report {"value": 3};
    }
}
"""
            )

            # Reload with fixed code
            client.reload()

            # Should work with fixed code
            resp2 = client.post("/walker/get_value", json={})
            assert resp2.ok
            assert resp2.data.get("reports", [{}])[0].get("value") == 3, (
                "Code not updated after recovery from syntax error"
            )

        finally:
            client.close()

    def test_reload_with_code_change_preserves_functionality(
        self, tmp_path: Path
    ) -> None:
        """Test that code changes work correctly after reload."""
        app_file = tmp_path / "app.jac"

        # Version 1: multiply by 2
        app_file.write_text(
            """
def compute(x: int) -> int {
    return x * 2;
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(tmp_path))

        try:
            client.register_user("testuser", "password123")

            # Test v1 logic
            resp1 = client.post("/function/compute", json={"args": {"x": 5}})
            assert resp1.ok
            assert resp1.data.get("result") == 10  # 5 * 2

            # Version 2: multiply by 3
            app_file.write_text(
                """
def compute(x: int) -> int {
    return x * 3;
}
"""
            )

            client.reload()

            # Test v2 logic - should now multiply by 3
            resp2 = client.post("/function/compute", json={"args": {"x": 5}})
            assert resp2.ok
            assert resp2.data.get("result") == 15, (  # 5 * 3
                f"Expected 15 (5*3), got {resp2.data.get('result')} - code change not applied"
            )

        finally:
            client.close()


class TestHMRClientCodeRecompilation:
    """Tests for client-side code HMR recompilation."""

    @pytest.fixture
    def temp_project(self, tmp_path: Path) -> Generator[Path, None, None]:
        """Create a temporary project directory with client structure."""
        import uuid

        # Use unique subdirectory to avoid cross-test contamination
        unique_dir = tmp_path / f"project_{uuid.uuid4().hex[:8]}"
        unique_dir.mkdir(parents=True, exist_ok=True)
        compiled_dir = unique_dir / ".jac" / "client" / "compiled"
        compiled_dir.mkdir(parents=True, exist_ok=True)
        yield unique_dir

    @pytest.mark.xfail(
        reason="HotReloader has global state issue causing cross-test contamination"
    )
    def test_client_js_file_updated_on_change(self, temp_project: Path) -> None:
        """Test that client JS file is actually updated when .jac file changes."""
        app_file = temp_project / "app.jac"
        app_file.write_text(
            """
cl {
    def app() {
        return <div>Hello Version 1</div>;
    }
}
"""
        )

        watcher = JacFileWatcher(watch_paths=[str(temp_project)], _debounce_ms=50)
        reloader = HotReloader(
            base_path=str(temp_project), module_name="app", watcher=watcher
        )

        reloader._recompile_client_code(str(app_file))

        output_file = temp_project / ".jac" / "client" / "compiled" / "app.js"
        assert output_file.exists(), "JS file was not created"

        content_v1 = output_file.read_text()

        # Modify the jac file
        app_file.write_text(
            """
cl {
    def app() {
        return <div>Hello Version 2</div>;
    }
}
"""
        )

        reloader._recompile_client_code(str(app_file))
        content_v2 = output_file.read_text()

        assert content_v1 != content_v2, "JS file was not updated after change"
        assert "Version 2" in content_v2, "New content not in recompiled JS"

    def test_jacjsx_import_added_in_real_compilation(self, temp_project: Path) -> None:
        """Test that __jacJsx import is added when JSX is used."""
        app_file = temp_project / "app.jac"
        app_file.write_text(
            """
cl {
    def app() {
        return <div>Hello</div>;
    }
}
"""
        )

        watcher = JacFileWatcher(watch_paths=[str(temp_project)], _debounce_ms=50)
        reloader = HotReloader(
            base_path=str(temp_project), module_name="app", watcher=watcher
        )

        reloader._recompile_client_code(str(app_file))

        output_file = temp_project / ".jac" / "client" / "compiled" / "app.js"
        assert output_file.exists(), "JS file was not created"

        content = output_file.read_text()
        # JSX code should compile to use __jacJsx
        assert "__jacJsx" in content, (
            "Compiled JS should contain __jacJsx for JSX elements"
        )
        assert "import {__jacJsx" in content or "import{__jacJsx" in content, (
            "__jacJsx is used but import statement is missing"
        )

    def test_client_recompile_preserves_directory_structure(
        self, temp_project: Path
    ) -> None:
        """Test that nested component files preserve directory structure.

        Regression test: components/AuthForm.cl.jac should compile to
        .jac/client/compiled/components/AuthForm.js, not .jac/client/compiled/AuthForm.js
        """
        # Create a nested components directory
        components_dir = temp_project / "components"
        components_dir.mkdir(parents=True, exist_ok=True)

        # Create a component file in the subdirectory
        component_file = components_dir / "Button.cl.jac"
        component_file.write_text(
            """
cl {
    def Button() {
        return <button>Click me</button>;
    }
}
"""
        )

        watcher = JacFileWatcher(watch_paths=[str(temp_project)], _debounce_ms=50)
        reloader = HotReloader(
            base_path=str(temp_project), module_name="app", watcher=watcher
        )

        reloader._recompile_client_code(str(component_file))

        # The output should preserve the components/ subdirectory
        correct_output = (
            temp_project / ".jac" / "client" / "compiled" / "components" / "Button.js"
        )
        wrong_output = temp_project / ".jac" / "client" / "compiled" / "Button.js"

        assert correct_output.exists(), (
            f"Expected output at {correct_output}, but file not found. "
            f"Directory structure not preserved."
        )
        assert not wrong_output.exists(), (
            f"File incorrectly written to {wrong_output} instead of {correct_output}"
        )
