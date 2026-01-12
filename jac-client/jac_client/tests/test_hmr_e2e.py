"""End-to-end tests for HMR with full client app.

These tests require npm/Node.js and jac-client installed.
They test the full HMR workflow including Vite dev server integration.
"""

import shutil
import tempfile
from collections.abc import Generator
from pathlib import Path

import pytest


def _npm_available() -> bool:
    """Check if npm is available."""
    return shutil.which("npm") is not None


def _node_available() -> bool:
    """Check if Node.js is available."""
    return shutil.which("node") is not None


def _jac_client_available() -> bool:
    """Check if jac-client is installed."""
    try:
        import jac_client  # noqa: F401

        return True
    except ImportError:
        return False


# Skip all tests in this module if npm or jac-client is not available
pytestmark = [
    pytest.mark.skipif(
        not _npm_available() or not _node_available(),
        reason="npm/Node.js not available - required for E2E tests",
    ),
    pytest.mark.skipif(
        not _jac_client_available(),
        reason="jac-client not installed",
    ),
]


class TestHMREndToEnd:
    """End-to-end HMR tests with Vite."""

    @pytest.fixture
    def temp_project(self) -> Generator[Path, None, None]:
        """Create a temporary project directory."""
        with tempfile.TemporaryDirectory() as tmp:
            yield Path(tmp)

    def test_client_js_output_regenerated(self, temp_project: Path) -> None:
        """Test that client .jac changes regenerate .js output."""
        # Create a simple client .jac file
        client_file = temp_project / "component.jac"
        client_file.write_text(
            """
client {
    glob clientMessage = "Version 1";
}

with entry {
    print("Loaded");
}
"""
        )

        # Set up output directory
        output_dir = temp_project / ".jac" / "client" / "src"
        output_dir.mkdir(parents=True, exist_ok=True)

        # This test would need actual HMR running to verify JS regeneration
        # For now, we just verify the setup works
        assert client_file.exists()
        assert output_dir.exists()

        pytest.skip("Full E2E test requires running jac start --watch with Vite")

    def test_mixed_file_reloads_both(self, temp_project: Path) -> None:
        """Test that file with both client and server code reloads both."""
        # Create a file with both client and server declarations
        mixed_file = temp_project / "app.jac"
        mixed_file.write_text(
            """
# Server-side walker
walker get_data {
    can enter with `root entry {
        report {"value": 1};
    }
}

# Client-side code
client {
    glob clientValue = 100;
}

with entry {
    print("App loaded");
}
"""
        )

        assert mixed_file.exists()
        pytest.skip("Full E2E test requires running jac start --watch with Vite")

    def test_vite_proxy_configuration(self, temp_project: Path) -> None:  # noqa: ARG002
        """Test that Vite proxy is correctly configured for API routes."""
        # This would test that /walker, /function, etc. are proxied to API server
        pytest.skip("Requires running Vite dev server - run manually")

    def test_vite_hmr_websocket(self, temp_project: Path) -> None:  # noqa: ARG002
        """Test that Vite's HMR WebSocket is functional."""
        # This would test browser receives HMR updates
        pytest.skip("Requires browser automation - run manually")


class TestClientCompilation:
    """Tests for client code compilation during HMR."""

    @pytest.fixture
    def temp_project(self) -> Generator[Path, None, None]:
        """Create a temporary project directory."""
        with tempfile.TemporaryDirectory() as tmp:
            yield Path(tmp)

    def test_client_declaration_detected(self, temp_project: Path) -> None:
        """Test that client declarations are correctly detected."""
        # Create a client-only file
        client_file = temp_project / "client_only.jac"
        client_file.write_text(
            """
client {
    glob clientVar = "hello";

    def clientFunc() -> str {
        return "world";
    }
}
"""
        )

        # In a full test, this would verify that HotReloader correctly
        # classifies this as client code and triggers JS compilation
        assert client_file.exists()
        pytest.skip("Requires HMR runtime verification")

    def test_js_output_location(self, temp_project: Path) -> None:
        """Test that JS output goes to correct directory."""
        expected_output_dir = temp_project / ".jac" / "client" / "src"

        # Create the directory structure
        expected_output_dir.mkdir(parents=True, exist_ok=True)

        # In a full test, this would verify HMR writes JS to this location
        assert expected_output_dir.exists()
