import fnmatch;
import os;
import logging;
import threading;
import time;
import sys;
import from pathlib { Path }

glob logger = logging.getLogger(__name__);

impl annex_folders_of(module_path: str) -> list[str] {
    stem = module_path[:-len(JAC_SUFFIX)]
        if module_path.endswith(JAC_SUFFIX)
        else module_path;
    beside = os.path.dirname(module_path);
    return [stem + folder for folder in ANNEX_FOLDER.values()]
        + [
            os.path.join(beside, shared_annex_folder(suffix)) for suffix in ANNEX_FOLDER
        ];
}

impl watch_roots(base: str, app_root: str, sources: list[str]) -> list[str] {
    base_real = os.path.realpath(base);
    root_real = os.path.realpath(app_root);
    roots: set[str] = set();
    for source in sources {
        path = os.path.realpath(source);
        if not path.startswith(root_real + os.sep) or is_compiler_source_path(path) {
            continue;
        }
        relative = os.path.relpath(path, root_real);
        if not holds_application_code(relative) {
            continue;
        }
        top = os.path.join(root_real, relative.split(os.sep)[0]);
        if top != base_real and not top.startswith(base_real + os.sep) {
            roots.add(top);
            if top == path {
                roots.update(
                    f
                    for f in annex_folders_of(path)
                    if os.path.isdir(f)
                );
            }
        }
    }
    covered = any(base_real.startswith(r + os.sep) for r in roots);
    return ([] if covered else [base]) + sorted(roots);
}

impl application_watch_roots(base: str, application: any, program: any) -> list[str] {
    sources = [str(key) for key in program.mod.hub.keys()];
    for part in [application, *application.applications] {
        sources.extend(part.code);
        sources.extend(part.manifests);
        sources.extend(
            source
            for source in part.sources
            if source.endswith(('.jac', '.py'))
        );
    }
    return watch_roots(base, application.`root, sources);
}

impl JacFileWatcher.start -> None {
    if self._running {
        return;
    }
    import from watchdog.observers { Observer }
    import from watchdog.events { FileSystemEventHandler, FileSystemEvent }
    watcher = self;
    observer: any = None;
    scheduled: dict[str, any] = {};
    schedule_lock = threading.Lock();

    def ignored_directory(path: str, allow_hidden_root: bool = False) -> bool {
        name = Path(path).name;
        ignored = {'.jac', '.git', '.venv', 'node_modules', '__pycache__', 'venv'};
        resolved_parts = Path(os.path.realpath(path)).parts;
        return name in ignored
            or any([part in ignored for part in resolved_parts])
            or (name.startswith('.') and not allow_hidden_root);
    }

    def schedule_directory(path: str, handler: any, allow_hidden_root: bool = False) {
        resolved = os.path.realpath(path);
        if ignored_directory(resolved, allow_hidden_root) {
            return;
        }
        if sys.platform == 'linux' {
            observer.add_directory(resolved, allow_hidden_root=allow_hidden_root);
            return;
        }
        with schedule_lock {
            if resolved in scheduled {
                return;
            }
            scheduled[resolved] = observer.schedule(handler, resolved, recursive=False);
        }
    }

    def schedule_tree(path: str, allow_hidden_root: bool = False) {
        resolved = os.path.realpath(path);
        if ignored_directory(resolved, allow_hidden_root)
            or not os.path.isdir(resolved) {
            return;
        }
        if sys.platform == 'linux' {
            observer.add_tree(resolved, allow_hidden_root=allow_hidden_root);
        }
    }

    def schedule_new_children(path: str) {
        if sys.platform != 'linux' or not os.path.isdir(path) {
            return;
        }
        explicit_root = any(
            os.path.realpath(watch_root) == os.path.realpath(path)
            for watch_root in watcher.watch_paths
        );
        if ignored_directory(path, explicit_root) {
            return;
        }
        try {
            children = os.listdir(path);
        } except OSError {
            return;
        }
        for name in children {
            child = os.path.join(path, name);
            if os.path.isdir(child)
                and not os.path.islink(child)
                and not ignored_directory(child) {
                schedule_tree(child);
            }
        }
    }

    def unschedule_tree(path: str) {
        if sys.platform != 'linux' or not path {
            return;
        }
        observer.remove_tree(os.path.realpath(path));
    }

    def report_tree_files(path: str) {
        resolved = os.path.realpath(path);
        if ignored_directory(resolved) or not os.path.isdir(resolved) {
            return;
        }
        for (current, dirs, files) in os.walk(resolved, followlinks=False) {
            dirs[:] = sorted(
                name
                for name in dirs
                if not os.path.islink(os.path.join(current, name))
                    and not ignored_directory(os.path.join(current, name))
            );
            for name in files {
                changed = os.path.join(current, name);
                if watcher._matches_pattern(changed) {
                    watcher._on_change(changed, ChangeType.CREATED);
                }
            }
        }
    }

    class JacEventHandler(FileSystemEventHandler) {
        def on_modified(inner_self: JacEventHandler, event: FileSystemEvent) {
            path = os.fsdecode(event.src_path);
            if event.is_directory {
                if sys.platform == 'linux' {
                    schedule_directory(path, inner_self);
                    schedule_new_children(path);
                }
            } else {
                watcher._on_change(path, ChangeType.MODIFIED);
            }
        }

        def on_created(_inner_self: JacEventHandler, event: FileSystemEvent) {
            path = os.fsdecode(event.src_path);
            if event.is_directory {
                schedule_tree(path);
                report_tree_files(path);
            }
            watcher._on_change(path, ChangeType.CREATED, event.is_directory);
        }

        def on_deleted(_inner_self: JacEventHandler, event: FileSystemEvent) {
            path = os.fsdecode(event.src_path);
            if event.is_directory {
                unschedule_tree(path);
            }
            watcher._on_change(path, ChangeType.DELETED, event.is_directory);
        }

        def on_moved(_inner_self: JacEventHandler, event: FileSystemEvent) {
            path = os.fsdecode(event.src_path);
            dest = os.fsdecode(getattr(event, 'dest_path', '') or '');
            if path {
                if event.is_directory {
                    if sys.platform == 'linux' and dest {
                        observer.move_tree(path, dest);
                    } else {
                        unschedule_tree(path);
                    }
                }
                watcher._on_change(path, ChangeType.DELETED, event.is_directory);
            }
            if dest {
                if event.is_directory {
                    schedule_tree(dest);
                    report_tree_files(dest);
                }
                watcher._on_change(dest, ChangeType.CREATED, event.is_directory);
            }
        }
    }
    handler = JacEventHandler();
    if sys.platform == 'linux' {
        import from jaclang.server.impl.pruned_inotify { SharedPrunedInotifyObserver }
        root_modes: dict[str, bool] = {};
        for watch_path in self.watch_paths {
            path = Path(watch_path);
            if path.is_dir() {
                resolved = os.path.realpath(str(path));
                if not ignored_directory(resolved, True) {
                    root_modes[resolved] = True;
                }
            } elif path.is_file() {
                resolved = os.path.realpath(str(path.parent));
                if not ignored_directory(resolved, True) {
                    root_modes[resolved] = root_modes.get(resolved, False);
                }
            }
        }
        roots = [
            (root_path, recursive) for (root_path, recursive) in root_modes.items()
        ];
        observer = SharedPrunedInotifyObserver(handler, roots, ignored_directory);
    } else {
        observer = Observer();
        for watch_path in self.watch_paths {
            path = Path(watch_path);
            if path.is_dir() {
                resolved = os.path.realpath(str(path));
                if not ignored_directory(resolved, True)
                    and resolved not in scheduled {
                    scheduled[resolved] = observer.schedule(
                        handler, resolved, recursive=True
                    );
                }
            } elif path.is_file() {
                schedule_directory(str(path.parent), handler, True);
            }
        }
    }
    self._observer = observer;
    observer.start();
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

impl JacFileWatcher._beside_watched_file(path: str) -> bool {
    changed = os.path.realpath(path);
    files: list[str] = [];
    for watch_path in self.watch_paths {
        watched = os.path.realpath(watch_path);
        if os.path.isdir(watched) {
            if changed == watched or changed.startswith(watched + os.sep) {
                return False;
            }
        } elif os.path.dirname(watched) == os.path.dirname(changed) {
            files.append(watched);
        }
    }
    return bool(files)
        and not any(
            changed == f
                or is_annex_path_of(changed, f)
                or changed in annex_folders_of(f) for f in files
        );
}

impl JacFileWatcher._foreign_shared_annex(path: str) -> bool {
    changed = os.path.realpath(path);
    folder = os.path.dirname(changed);
    suffix = next(
        (
            s
            for s in ANNEX_FOLDER
            if changed.endswith(s)
        ),
        None
    );
    if suffix is None or os.path.basename(folder) != shared_annex_folder(suffix) {
        return False;
    }
    files = [
        os.path.realpath(w)
        for w in self.watch_paths
        if os.path.isfile(os.path.realpath(w))
            and os.path.dirname(os.path.realpath(w)) == os.path.dirname(folder)
    ];
    if not files {
        return False;
    }
    try {
        names = os.listdir(folder);
    } except OSError {
        names = [];
    }
    local = [
        os.path.join(folder, name)
        for name in names
        if name.endswith(JAC_SUFFIX)
            and not any(name.endswith(annex) for annex in ANNEX_FOLDER)
    ];
    return not any(is_annex_path_of(changed, module) for module in [*local, *files]);
}

impl JacFileWatcher._inside_ignored_directory(
    path: str, is_directory: bool = False
) -> bool {
    changed = os.path.realpath(path);
    ignored = {'.jac', '.git', '.venv', 'node_modules', '__pycache__', 'venv'};
    matching_roots = [
        os.path.realpath(watch_path)
        for watch_path in self.watch_paths
        if os.path.isdir(os.path.realpath(watch_path))
            and (
                changed == os.path.realpath(watch_path)
                or changed.startswith(os.path.realpath(watch_path) + os.sep)
            )
    ];
    if not matching_roots {
        return False;
    }
    watched = max(matching_roots, key=len);
    relative = os.path.relpath(changed, watched);
    if relative == '.' {
        return False;
    }
    parts = relative.split(os.sep);
    directories = parts if is_directory else parts[:-1];
    return any(part.startswith('.') or part in ignored for part in directories);
}

impl JacFileWatcher._on_change(
    path: str, change_type: ChangeType, is_directory: bool = False
) -> None {
    if '/.jac/' in path
        or '\\.jac\\' in path
        or self._inside_ignored_directory(path, is_directory) {
        return;
    }

    changed = os.path.realpath(path);
    compiler_roots = [
        os.path.realpath(compiler_root) for compiler_root in self.compiler_source_roots
    ];
    inside_compiler_app = any(
        changed == compiler_root or changed.startswith(compiler_root + os.sep)
        for compiler_root in compiler_roots
    );
    if self._beside_watched_file(path)
        or self._foreign_shared_annex(path)
        or (is_compiler_source_path(path) and not inside_compiler_app) {
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
