import fnmatch;
import os;
import logging;
import threading;
import time;
import from pathlib { Path }
import from jaclang.cli.console { console }

glob logger = logging.getLogger(__name__);

impl watch_roots(base: str, app_root: str, sources: list[str]) -> list[str] {
    base_real = os.path.realpath(base);
    root_real = os.path.realpath(app_root);
    roots: set[str] = set();
    for source in sources {
        path = os.path.realpath(source);
        if not path.startswith(root_real + os.sep) {
            continue;
        }
        parts = os.path.relpath(path, root_real).split(os.sep);
        if any(
            p.startswith('.') or p in ('node_modules', 'venv', '__pycache__')
            for p in parts
        ) {
            continue;
        }
        top = os.path.join(root_real, parts[0]);
        if top != base_real and not top.startswith(base_real + os.sep) {
            roots.add(top);
        }
    }
    covered = any(base_real.startswith(r + os.sep) for r in roots);
    return ([] if covered else [base]) + sorted(roots);
}

impl JacFileWatcher.start -> None {
    if self._running {
        return;
    }
    import from watchdog.observers { Observer }
    import from watchdog.events { FileSystemEventHandler, FileSystemEvent }
    watcher = self;
    class JacEventHandler(FileSystemEventHandler) {
        def on_modified(inner_self: JacEventHandler, event: FileSystemEvent) {
            if not event.is_directory {
                watcher._on_change(os.fsdecode(event.src_path), ChangeType.MODIFIED);
            }
        }

        def on_created(inner_self: JacEventHandler, event: FileSystemEvent) {
            watcher._on_change(
                os.fsdecode(event.src_path), ChangeType.CREATED, event.is_directory
            );
        }

        def on_deleted(inner_self: JacEventHandler, event: FileSystemEvent) {
            watcher._on_change(
                os.fsdecode(event.src_path), ChangeType.DELETED, event.is_directory
            );
        }

        def on_moved(inner_self: JacEventHandler, event: FileSystemEvent) {
            watcher._on_change(
                os.fsdecode(event.src_path), ChangeType.DELETED, event.is_directory
            );
            dest = str(getattr(event, 'dest_path', '') or '');
            if dest {
                watcher._on_change(dest, ChangeType.CREATED, event.is_directory);
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

    def flush_loop {
        while self._running {
            time.sleep(float(self._debounce_ms) / 1000.0);
            try {
                self._debounce_flush();
            } except Exception as e {
                console.print(f"[HMR] Watcher flush error: {e}");
            }
        }
    }
    flush_thread = threading.Thread(target=flush_loop, daemon=True);
    flush_thread.start();
    logger.debug(f"Watching for changes in: {self.watch_paths}");
}

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

impl JacFileWatcher.add_callback(callback: Callable[[FileChangeEvent], None]) -> None {
    if callback not in self._callbacks {
        self._callbacks.append(callback);
    }
}

impl JacFileWatcher.remove_callback(
    callback: Callable[[FileChangeEvent], None]
) -> None {
    if callback in self._callbacks {
        self._callbacks.remove(callback);
    }
}

impl JacFileWatcher._on_change(
    path: str, change_type: ChangeType, is_directory: bool = False
) -> None {
    if '/.jac/' in path or '\\.jac\\' in path {
        return;
    }

    if is_directory {
        name = Path(path).name;
        if name.startswith('.') or name in {'node_modules', '__pycache__'} {
            return;
        }
    } elif not self._matches_pattern(path) {
        return;
    }

    event = FileChangeEvent(
        path=path,
        change_type=change_type,
        timestamp=time.time(),
        is_directory=is_directory
    );
    with JacFileWatcher._events_lock {
        self._pending_events[path] = event;
    }
}

impl JacFileWatcher._debounce_flush -> None {
    now = time.time();
    debounce_sec = float(self._debounce_ms) / 1000.0;

    events_to_flush: list[FileChangeEvent] = [];

    with JacFileWatcher._events_lock {
        paths_to_remove = [];
        for (path, event) in self._pending_events.items() {
            if (now - event.timestamp) >= debounce_sec {
                events_to_flush.append(event);
                paths_to_remove.append(path);
            }
        }
        for path in paths_to_remove {
            del self._pending_events[path];
        }
    }

    for event in events_to_flush {
        self._notify_callbacks(event);
    }
}

impl JacFileWatcher._matches_pattern(path: str) -> bool {
    filename = Path(path).name;
    patterns = (self.pattern, *self.additional_patterns);
    return any(fnmatch.fnmatch(filename, p) for p in patterns);
}

impl JacFileWatcher._notify_callbacks(event: FileChangeEvent) -> None {
    for callback in self._callbacks {
        try {
            callback(event);
        } except Exception as e {
            console.print(f"[HMR] Error in callback: {e}");
        }
    }
}
