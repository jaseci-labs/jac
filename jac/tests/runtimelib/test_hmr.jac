"""Unit tests for HMR (Hot Module Replacement) components.

Tests for the file watcher and HotReloader functionality.
"""

import tempfile;
import threading;
import time;
import from pathlib { Path }
import from unittest.mock { MagicMock }

import watchdog;

import from jaclang.runtimelib.hmr { HotReloader }
import from jaclang.runtimelib.watcher { ChangeType, FileChangeEvent, JacFileWatcher }

# --- TestJacFileWatcher ---
test "watcher can be instantiated" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        assert watcher is not None;
        assert watcher.watch_paths == [str(temp_dir)];
        assert watcher.pattern == "*.jac";
        assert watcher.additional_patterns == [
            "*.tsx",
            "*.js",
            "*.css",
            "*.scss",
            "*.png",
            "*.jpg",
            "*.jpeg"
        ];
        assert watcher._running is False;
    }
}

test "pattern matches jac files" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        # Test main pattern (*.jac)
        assert watcher._matches_pattern("app.jac") is True;
        assert watcher._matches_pattern("component.cl.jac") is True;
        # Test additional patterns
        assert watcher._matches_pattern("app.tsx") is True;
        assert watcher._matches_pattern("script.js") is True;
        assert watcher._matches_pattern("styles.css") is True;
        assert watcher._matches_pattern("styles.scss") is True;
        assert watcher._matches_pattern("image.png") is True;
        assert watcher._matches_pattern("photo.jpg") is True;
        assert watcher._matches_pattern("photo.jpeg") is True;
        # Test non-matching patterns
        assert watcher._matches_pattern("config.json") is False;
        assert watcher._matches_pattern("script.py") is False;
        assert watcher._matches_pattern("readme.md") is False;
    }
}

test "callback registration" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        callback = MagicMock();
        watcher.add_callback(callback);
        assert callback in watcher._callbacks;
        watcher.remove_callback(callback);
        assert callback not in watcher._callbacks;
    }
}

test "start and stop" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        assert watcher._running is False;
        watcher.start();
        assert watcher._running is True;
        watcher.stop();
        assert watcher._running is False;
    }
}

test "debounce consolidates rapid changes" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50);
        events: list[FileChangeEvent] = [];
        watcher.add_callback(lambda e : events.append(e));
        watcher.start();
        # Simulate rapid changes to the same file
        test_file = str(temp_dir / "app.jac");
        for _ in range(5) {
            watcher._on_change(test_file, ChangeType.MODIFIED);
        }
        # Wait for debounce to flush
        time.sleep(0.2);
        watcher.stop();
        # Should consolidate to 1-2 events (not 5)
        assert len(events) <= 2 , f"Expected <=2 events, got {len(events)}";
    }
}

test "file change detection" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50);
        events: list[FileChangeEvent] = [];
        watcher.add_callback(lambda e : events.append(e));
        # Create test file before starting watcher
        test_file = temp_dir / "test.jac";
        test_file.write_text("initial content");
        watcher.start();
        time.sleep(0.2);  # Let watcher initialize
        # Modify the file
        test_file.write_text("modified content");
        time.sleep(0.5);  # Wait for detection and debounce
        watcher.stop();
        # Should have detected the change
        assert len(events) >= 1 , "File change was not detected";
        assert "test.jac" in events[0].path;
    }
}

# --- TestHotReloader ---
test "hot reloader can be instantiated" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        assert reloader is not None;
        assert reloader.base_path == str(temp_dir);
        assert reloader.module_name == "test";
        assert reloader._running is False;
    }
}

test "start and stop reloader" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        assert reloader._running is False;
        reloader.start();
        assert reloader._running is True;
        reloader.stop();
        assert reloader._running is False;
    }
}

test "get js filename" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        # Test various input file names
        # Note: .cl.jac files become .js (not .cl.js)
        assert reloader._get_js_filename("app.jac") == "app.js";
        assert reloader._get_js_filename("component.cl.jac") == "component.js";
        assert reloader._get_js_filename("/path/to/module.jac") == "module.js";
    }
}

test "classify declarations server only" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        # Create a server-only jac file
        test_file = temp_dir / "server.jac";
        test_file.write_text(
            "walker greet {\n"
            "    can enter with Root entry {\n"
            "        return {\"message\": \"hello\"};\n"
            "    }\n"
            "}\n"
        );
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        (has_client, has_server) = reloader._classify_declarations(str(test_file));
        # Server code should be detected
        assert has_server is True;
    }
}

test "client output dir default" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)]);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        assert reloader._client_output_dir == ".jac/client/compiled";
    }
}

# --- TestHMRIntegration ---
test "file change triggers callback" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        # Create initial file
        test_file = temp_dir / "app.jac";
        test_file.write_text("with entry { print(\"v1\"); }");
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        # Track if callback was called
        callback_called = threading.Event();
        def mock_callback(event: object) -> None {
            callback_called.set();
        }
        reloader.on_file_change = mock_callback;
        reloader.start();
        time.sleep(0.2);  # Let watcher initialize
        # Modify file
        test_file.write_text("with entry { print(\"v2\"); }");
        time.sleep(0.5);
        reloader.stop();
        assert callback_called.is_set() , "File change callback was not triggered";
    }
}

test "multiple file changes handled" {
    with tempfile.TemporaryDirectory() as tmp {
        temp_dir = Path(tmp);
        # Create multiple files
        file1 = temp_dir / "module1.jac";
        file2 = temp_dir / "module2.jac";
        file1.write_text("glob x = 1;");
        file2.write_text("glob y = 2;");
        watcher = JacFileWatcher(watch_paths=[str(temp_dir)], _debounce_ms=50);
        reloader = HotReloader(
            base_path=str(temp_dir), module_name="test", watcher=watcher
        );
        changed_files: list[str] = [];
        def track_changes(event: FileChangeEvent) -> None {
            changed_files.append(event.path);
        }
        reloader.on_file_change = track_changes;
        reloader.start();
        time.sleep(0.2);
        # Modify both files
        file1.write_text("glob x = 10;");
        time.sleep(0.3);
        file2.write_text("glob y = 20;");
        time.sleep(0.3);
        reloader.stop();
        # Both files should have been detected
        assert len(changed_files) >= 2 , f"Expected 2+ changes, got {len(changed_files)}";
    }
}
