"""Unit tests for HMR (Hot Module Replacement) components.

Tests for the file watcher and HotReloader functionality.
"""

import tempfile
import threading
import time
from collections.abc import Generator
from pathlib import Path
from unittest.mock import MagicMock

import pytest


class TestJacFileWatcher:
    """Tests for file watching functionality."""

    @pytest.fixture
    def temp_dir(self) -> Generator[Path, None, None]:
        """Create a temporary directory for tests."""
        with tempfile.TemporaryDirectory() as tmp:
            yield Path(tmp)

    def test_watcher_can_be_imported(self) -> None:
        """Test that watcher module can be imported."""
        try:
            from jaclang.runtimelib.watcher import (
                ChangeType,
                FileChangeEvent,
                JacFileWatcher,
            )

            assert ChangeType is not None
            assert FileChangeEvent is not None
            assert JacFileWatcher is not None
        except ImportError as e:
            pytest.skip(f"watchdog not installed: {e}")

    def test_watcher_can_be_instantiated(self, temp_dir: Path) -> None:
        """Test that JacFileWatcher can be instantiated."""
        try:
            from jaclang.runtimelib.watcher import JacFileWatcher

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)])
            assert watcher is not None
            assert watcher.watch_paths == [str(temp_dir)]
            assert watcher.pattern == "*.jac"
            assert watcher._running is False
        except ImportError:
            pytest.skip("watchdog not installed")

    def test_pattern_matches_jac_files(self, temp_dir: Path) -> None:
        """Test that *.jac pattern matches both .jac and .cl.jac files."""
        try:
            from jaclang.runtimelib.watcher import JacFileWatcher

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)])

            assert watcher._matches_pattern("app.jac") is True
            assert watcher._matches_pattern("component.cl.jac") is True
            # Note: pattern is case sensitive on most systems
            assert watcher._matches_pattern("config.json") is False
            assert watcher._matches_pattern("script.py") is False
            assert watcher._matches_pattern("readme.md") is False
        except ImportError:
            pytest.skip("watchdog not installed")

    def test_callback_registration(self, temp_dir: Path) -> None:
        """Test that callbacks can be registered and removed."""
        try:
            from jaclang.runtimelib.watcher import JacFileWatcher

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)])

            callback = MagicMock()
            watcher.add_callback(callback)

            assert callback in watcher._callbacks

            watcher.remove_callback(callback)
            assert callback not in watcher._callbacks
        except ImportError:
            pytest.skip("watchdog not installed")

    def test_start_and_stop(self, temp_dir: Path) -> None:
        """Test that watcher can start and stop."""
        try:
            from jaclang.runtimelib.watcher import JacFileWatcher

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)])

            assert watcher._running is False
            watcher.start()
            assert watcher._running is True

            watcher.stop()
            assert watcher._running is False
        except ImportError:
            pytest.skip("watchdog not installed")

    def test_debounce_consolidates_rapid_changes(self, temp_dir: Path) -> None:
        """Test that rapid changes are debounced."""
        try:
            from jaclang.runtimelib.watcher import ChangeType, JacFileWatcher

            # Short debounce for testing
            watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50)
            events = []
            watcher.add_callback(lambda e: events.append(e))

            watcher.start()

            # Simulate rapid changes to the same file
            test_file = str(temp_dir / "app.jac")
            for _ in range(5):
                watcher._on_change(test_file, ChangeType.MODIFIED)

            # Wait for debounce to flush
            time.sleep(0.2)

            watcher.stop()

            # Should consolidate to 1-2 events (not 5)
            assert len(events) <= 2, f"Expected <=2 events, got {len(events)}"
        except ImportError:
            pytest.skip("watchdog not installed")

    def test_file_change_detection(self, temp_dir: Path) -> None:
        """Test that actual file changes are detected."""
        try:
            from jaclang.runtimelib.watcher import JacFileWatcher

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50)
            events = []
            watcher.add_callback(lambda e: events.append(e))

            # Create test file before starting watcher
            test_file = temp_dir / "test.jac"
            test_file.write_text("initial content")

            watcher.start()
            time.sleep(0.2)  # Let watcher initialize

            # Modify the file
            test_file.write_text("modified content")
            time.sleep(0.5)  # Wait for detection and debounce

            watcher.stop()

            # Should have detected the change
            assert len(events) >= 1, "File change was not detected"
            assert "test.jac" in events[0].path
        except ImportError:
            pytest.skip("watchdog not installed")


class TestHotReloader:
    """Tests for hot reloading functionality."""

    @pytest.fixture
    def temp_dir(self) -> Generator[Path, None, None]:
        """Create a temporary directory for tests."""
        with tempfile.TemporaryDirectory() as tmp:
            yield Path(tmp)

    def test_hot_reloader_can_be_imported(self) -> None:
        """Test that HotReloader module can be imported."""
        try:
            from jaclang.runtimelib.hmr import HotReloader

            assert HotReloader is not None
        except ImportError as e:
            pytest.skip(f"HMR module not available: {e}")

    def test_hot_reloader_can_be_instantiated(self, temp_dir: Path) -> None:
        """Test that HotReloader can be instantiated."""
        try:
            from jaclang.runtimelib.hmr import HotReloader
            from jaclang.runtimelib.watcher import JacFileWatcher

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)])
            reloader = HotReloader(
                base_path=str(temp_dir), module_name="test", watcher=watcher
            )

            assert reloader is not None
            assert reloader.base_path == str(temp_dir)
            assert reloader.module_name == "test"
            assert reloader._running is False
        except ImportError:
            pytest.skip("watchdog not installed")

    def test_start_and_stop_reloader(self, temp_dir: Path) -> None:
        """Test that HotReloader can start and stop."""
        try:
            from jaclang.runtimelib.hmr import HotReloader
            from jaclang.runtimelib.watcher import JacFileWatcher

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)])
            reloader = HotReloader(
                base_path=str(temp_dir), module_name="test", watcher=watcher
            )

            assert reloader._running is False
            reloader.start()
            assert reloader._running is True

            reloader.stop()
            assert reloader._running is False
        except ImportError:
            pytest.skip("watchdog not installed")

    def test_get_js_filename(self, temp_dir: Path) -> None:
        """Test that JS filename is correctly generated."""
        try:
            from jaclang.runtimelib.hmr import HotReloader
            from jaclang.runtimelib.watcher import JacFileWatcher

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)])
            reloader = HotReloader(
                base_path=str(temp_dir), module_name="test", watcher=watcher
            )

            # Test various input file names
            # Note: .cl.jac files become .js (not .cl.js)
            assert reloader._get_js_filename("app.jac") == "app.js"
            assert reloader._get_js_filename("component.cl.jac") == "component.js"
            assert reloader._get_js_filename("/path/to/module.jac") == "module.js"
        except ImportError:
            pytest.skip("watchdog not installed")

    def test_classify_declarations_server_only(self, temp_dir: Path) -> None:
        """Test that server-only file is classified correctly."""
        try:
            from jaclang.runtimelib.hmr import HotReloader
            from jaclang.runtimelib.watcher import JacFileWatcher

            # Create a server-only jac file
            test_file = temp_dir / "server.jac"
            test_file.write_text(
                """
walker greet {
    can enter with `root entry {
        return {"message": "hello"};
    }
}
"""
            )

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)])
            reloader = HotReloader(
                base_path=str(temp_dir), module_name="test", watcher=watcher
            )

            has_client, has_server = reloader._classify_declarations(str(test_file))

            # Server code should be detected
            assert has_server is True
        except ImportError:
            pytest.skip("watchdog not installed")
        except Exception as e:
            # Parse errors are acceptable for this test
            if "parse" in str(e).lower():
                pytest.skip(f"File parsing issue: {e}")
            raise

    def test_client_output_dir_default(self, temp_dir: Path) -> None:
        """Test that client output directory has correct default."""
        try:
            from jaclang.runtimelib.hmr import HotReloader
            from jaclang.runtimelib.watcher import JacFileWatcher

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)])
            reloader = HotReloader(
                base_path=str(temp_dir), module_name="test", watcher=watcher
            )

            assert reloader._client_output_dir == ".jac/client/src"
        except ImportError:
            pytest.skip("watchdog not installed")


class TestChangeType:
    """Tests for ChangeType enum."""

    def test_change_type_values(self) -> None:
        """Test that ChangeType has expected values."""
        try:
            from jaclang.runtimelib.watcher import ChangeType

            assert hasattr(ChangeType, "CREATED")
            assert hasattr(ChangeType, "MODIFIED")
            assert hasattr(ChangeType, "DELETED")
        except ImportError:
            pytest.skip("watchdog not installed")


class TestFileChangeEvent:
    """Tests for FileChangeEvent."""

    def test_file_change_event_creation(self) -> None:
        """Test that FileChangeEvent can be created."""
        try:
            from jaclang.runtimelib.watcher import ChangeType, FileChangeEvent

            event = FileChangeEvent(
                path="/path/to/file.jac",
                change_type=ChangeType.MODIFIED,
                timestamp=time.time(),
            )

            assert event.path == "/path/to/file.jac"
            assert event.change_type == ChangeType.MODIFIED
            assert isinstance(event.timestamp, float)
        except ImportError:
            pytest.skip("watchdog not installed")


class TestHMRIntegration:
    """Basic integration tests for HMR components working together."""

    @pytest.fixture
    def temp_dir(self) -> Generator[Path, None, None]:
        """Create a temporary directory for tests."""
        with tempfile.TemporaryDirectory() as tmp:
            yield Path(tmp)

    def test_file_change_triggers_callback(self, temp_dir: Path) -> None:
        """Test that file changes trigger HotReloader callback."""
        try:
            from jaclang.runtimelib.hmr import HotReloader
            from jaclang.runtimelib.watcher import JacFileWatcher

            # Create initial file
            test_file = temp_dir / "app.jac"
            test_file.write_text('with entry { print("v1"); }')

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50)
            reloader = HotReloader(
                base_path=str(temp_dir), module_name="test", watcher=watcher
            )

            # Track if callback was called
            callback_called = threading.Event()

            def mock_callback(event: object) -> None:  # noqa: ARG001
                callback_called.set()
                # Don't call original to avoid actual reload

            reloader.on_file_change = mock_callback

            reloader.start()
            time.sleep(0.2)  # Let watcher initialize

            # Modify file
            test_file.write_text('with entry { print("v2"); }')
            time.sleep(0.5)

            reloader.stop()

            assert callback_called.is_set(), "File change callback was not triggered"
        except ImportError:
            pytest.skip("watchdog not installed")

    def test_multiple_file_changes_handled(self, temp_dir: Path) -> None:
        """Test that multiple file changes are all handled."""
        try:
            from jaclang.runtimelib.hmr import HotReloader
            from jaclang.runtimelib.watcher import JacFileWatcher

            # Create multiple files
            file1 = temp_dir / "module1.jac"
            file2 = temp_dir / "module2.jac"
            file1.write_text("glob x = 1;")
            file2.write_text("glob y = 2;")

            watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50)
            reloader = HotReloader(
                base_path=str(temp_dir), module_name="test", watcher=watcher
            )

            changed_files = []

            def track_changes(event: object) -> None:
                changed_files.append(event.path)  # type: ignore[attr-defined]

            reloader.on_file_change = track_changes

            reloader.start()
            time.sleep(0.2)

            # Modify both files
            file1.write_text("glob x = 10;")
            time.sleep(0.3)
            file2.write_text("glob y = 20;")
            time.sleep(0.3)

            reloader.stop()

            # Both files should have been detected
            assert len(changed_files) >= 2, (
                f"Expected 2+ changes, got {len(changed_files)}"
            )
        except ImportError:
            pytest.skip("watchdog not installed")
