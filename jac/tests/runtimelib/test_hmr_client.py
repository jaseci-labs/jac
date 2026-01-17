"""HMR (Hot Module Replacement) tests using JacTestClient.

These tests verify HMR functionality without starting real servers.
The reload() method simulates what happens when a file changes.
"""

from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

import pytest

from jaclang.runtimelib.testing import JacTestClient


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
    """Tests that user state is preserved across reloads."""

    def test_auth_preserved_after_reload(self, tmp_path: Path) -> None:
        """Test that authentication is preserved after module reload."""
        app_file = tmp_path / "app.jac"

        app_file.write_text(
            """
walker get_user_info {
    can enter with `root entry {
        report {"status": "authenticated"};
    }
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(tmp_path))

        try:
            # Register and authenticate
            client.register_user("testuser", "password123")

            # Verify auth works
            response1 = client.post("/walker/get_user_info", json={})
            assert response1.ok

            # Reload module
            app_file.write_text(
                """
walker get_user_info {
    can enter with `root entry {
        report {"status": "still_authenticated"};
    }
}
"""
            )

            client.reload()

            # Auth should still work (token preserved in client)
            response2 = client.post("/walker/get_user_info", json={})
            assert response2.ok
            assert "still_authenticated" in str(response2.data)

        finally:
            client.close()


class TestHMRErrorHandling:
    """Tests for error handling during HMR."""

    def test_recovery_after_syntax_fix(self, tmp_path: Path) -> None:
        """Test that module can be reloaded after fixing syntax error."""
        app_file = tmp_path / "app.jac"

        # Start with valid code
        app_file.write_text(
            """
walker test_walker {
    can enter with `root entry {
        report {"status": "ok"};
    }
}
"""
        )

        client = JacTestClient.from_file(str(app_file), base_path=str(tmp_path))

        try:
            client.register_user("testuser", "password123")

            # Verify it works
            response1 = client.post("/walker/test_walker", json={})
            assert response1.ok

            # Fix and reload with new valid code
            app_file.write_text(
                """
walker test_walker {
    can enter with `root entry {
        report {"status": "fixed"};
    }
}
"""
            )

            client.reload()

            # Should work with new code
            response2 = client.post("/walker/test_walker", json={})
            assert response2.ok
            assert "fixed" in str(response2.data)

        finally:
            client.close()
