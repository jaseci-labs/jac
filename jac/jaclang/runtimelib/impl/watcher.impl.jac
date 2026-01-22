"""File system watcher implementation using watchdog library."""

import fnmatch;
import logging;
import threading;
import time;
import from pathlib { Path }
import from typing { Any }

glob logger = logging.getLogger(__name__);

"""Start watching for file changes."""
impl JacFileWatcher.start -> None {
    if self._running {
        return;
    }
    import from watchdog.observers { Observer }
    import from watchdog.events { FileSystemEventHandler, FileSystemEvent }
    watcher = self;
    class JacEventHandler(FileSystemEventHandler) {
        def on_modified(inner_self: JacEventHandler, event: FileSystemEvent) -> None {
            if not event.is_directory {
                watcher._on_change(event.src_path, ChangeType.MODIFIED);
            }
        }

        def on_created(inner_self: JacEventHandler, event: FileSystemEvent) -> None {
            if not event.is_directory {
                watcher._on_change(event.src_path, ChangeType.CREATED);
            }
        }

        def on_deleted(inner_self: JacEventHandler, event: FileSystemEvent) -> None {
            if not event.is_directory {
                watcher._on_change(event.src_path, ChangeType.DELETED);
            }
        }
    }
    self._observer = Observer();
    handler = JacEventHandler();
    for watch_path in self.watch_paths {
        path = Path(watch_path);
        if path.is_dir() {
            self._observer.schedule(handler, str(path), recursive=True);
        } elif path.is_file() {
            self._observer.schedule(handler, str(path.parent), recursive=False);
        }
    }
    self._observer.start();
    self._running = True;
    self._last_flush = time.time();
    # Start debounce flush thread
    def flush_loop -> None {
        while self._running {
            time.sleep(float(self._debounce_ms) / 1000.0);
            self._debounce_flush();
        }
    }
    flush_thread = threading.Thread(target=flush_loop, daemon=True);
    flush_thread.start();
    logger.debug(f"Watching for changes in: {self.watch_paths}");
}

"""Stop watching for file changes."""
impl JacFileWatcher.stop -> None {
    if not self._running {
        return;
    }
    self._running = False;
    if self._observer {
        self._observer.stop();
        self._observer.join(timeout=2.0);
        self._observer = None;
    }
    logger.debug("File watcher stopped");
}

"""Add a callback to be invoked on file changes."""
impl JacFileWatcher.add_callback(callback: Callable[[FileChangeEvent], None]) -> None {
    if callback not in self._callbacks {
        self._callbacks.append(callback);
    }
}

"""Remove a previously added callback."""
impl JacFileWatcher.remove_callback(
    callback: Callable[[FileChangeEvent], None]
) -> None {
    if callback in self._callbacks {
        self._callbacks.remove(callback);
    }
}

"""Internal: Handle a file change event from watchdog."""
impl JacFileWatcher._on_change(path: str, change_type: ChangeType) -> None {
    # Only process .jac files
    if not self._matches_pattern(path) {
        return;
    }
    # Add to pending events (debounce by overwriting)
    event = FileChangeEvent(path=path, change_type=change_type, timestamp=time.time());
    self._pending_events[path] = event;
}

"""Internal: Flush pending events after debounce period."""
impl JacFileWatcher._debounce_flush -> None {
    now = time.time();
    debounce_sec = float(self._debounce_ms) / 1000.0;
    # Find events that are old enough to flush
    events_to_flush = [];
    paths_to_remove = [];
    for (path, event) in self._pending_events.items() {
        if (now - event.timestamp) >= debounce_sec {
            events_to_flush.append(event);
            paths_to_remove.append(path);
        }
    }
    # Remove flushed events
    for path in paths_to_remove {
        del self._pending_events[path];
    }
    # Notify callbacks
    for event in events_to_flush {
        self._notify_callbacks(event);
    }
}

"""Internal: Check if a path matches the watch pattern."""
impl JacFileWatcher._matches_pattern(path: str) -> bool {
    filename = Path(path).name;
    # *.jac matches both .jac and .cl.jac since .cl.jac ends with .jac
    return fnmatch.fnmatch(filename, self.pattern);
}

"""Internal: Notify all callbacks of an event."""
impl JacFileWatcher._notify_callbacks(event: FileChangeEvent) -> None {
    for callback in self._callbacks {
        try {
            callback(event);
        } except Exception as e {
            print(f"[HMR] Error in callback: {e}", flush=True);
        }
    }
}
