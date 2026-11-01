impl _PrunedInotifyEmitter.init(
    self: _PrunedInotifyEmitter,
    event_queue: any,
    watch: any,
    roots: list[tuple[str, bool]],
    ignore_directory: Callable[[str, bool], bool],
    timeout: any,
    event_filter: any = None
) {
    super.init(event_queue, watch, timeout=timeout, event_filter=event_filter);
    self._roots = roots;
    self._ignore_directory = ignore_directory;
    self._watch_lock = threading.RLock();
    self._watched_paths = set();
    self._wd_by_path = {};
}

impl _PrunedInotifyEmitter.on_thread_start(self: _PrunedInotifyEmitter) {
    super.on_thread_start();
    for (path, recursive) in self._roots {
        if recursive {
            self.add_tree(path, allow_hidden_root=True);
        } else {
            self.add_directory(path, allow_hidden_root=True);
        }
    }
}

impl _PrunedInotifyEmitter.is_watched(self: _PrunedInotifyEmitter, path: str) -> bool {
    resolved = os.path.realpath(path);
    with self._watch_lock {
        return resolved in self._watched_paths;
    }
}

impl _PrunedInotifyEmitter.add_directory(
    self: _PrunedInotifyEmitter, path: str, allow_hidden_root: bool = False
) {
    resolved = os.path.realpath(path);
    if self._ignore_directory(resolved, allow_hidden_root) {
        return;
    }
    with self._watch_lock {
        if resolved in self._watched_paths {
            return;
        }
        encoded = os.fsencode(resolved);
        group: any = self._inotify;
        wd: any = None;
        if hasattr(group, "_active_callbacks_by_path") {
            with group._lock {
                wd = group._active_callbacks_by_path.get(encoded);
                if wd is None {
                    group._add_callback(encoded);
                    wd = group._active_callbacks_by_path.get(encoded);
                }
                if wd is None {
                    raise OSError(f"Watchdog did not register {resolved}");
                }
            }
        } else {
            inotify = group._inotify;
            inotify.add_watch(encoded);
            with inotify._lock {
                wd = inotify._wd_for_path.get(encoded);
            }
            if wd is None or wd < 0 {
                raise OSError(f"Watchdog did not register {resolved}");
            }
        }
        self._watched_paths.add(resolved);
        self._wd_by_path[resolved] = wd;
    }
}

impl _PrunedInotifyEmitter.add_tree(
    self: _PrunedInotifyEmitter, path: str, allow_hidden_root: bool = False
) {
    resolved = os.path.realpath(path);
    if not os.path.isdir(resolved) {
        return;
    }
    for (current, dirs, _) in os.walk(resolved, followlinks=False) {
        current_real = os.path.realpath(current);
        allow_root = allow_hidden_root and current_real == resolved;
        if self._ignore_directory(current_real, allow_root) {
            dirs[:] = [];
            continue;
        }
        dirs[:] = sorted(
            name
            for name in dirs
            if not os.path.islink(os.path.join(current, name))
                and not self._ignore_directory(os.path.join(current, name), False)
        );
        try {
            self.add_directory(current_real, allow_root);
        } except OSError as e {
            logger.exception(f"Could not add inotify watch for {current_real}: {e}");
        }
    }
}

impl _PrunedInotifyEmitter.move_tree(
    self: _PrunedInotifyEmitter, source: str, destination: str
) {
    source_real = os.path.realpath(source);
    destination_real = os.path.realpath(destination);
    if self._ignore_directory(destination_real, False) {
        self.remove_tree(source_real);
        return;
    }

    with self._watch_lock {
        self.remove_tree(destination_real);
        paths = sorted(
            (
                watched
                for watched in self._watched_paths
                if watched == source_real or watched.startswith(source_real + os.sep)
            ),
            key=len
        );
        group: any = self._inotify;
        shared_group: bool = hasattr(group, "_active_callbacks_by_path");
        inotify: any = None if shared_group else group._inotify;
        for watched in paths {
            wd = self._wd_by_path.pop(watched, None);
            if wd is None {
                continue;
            }
            moved = destination_real + watched[len(source_real):];
            if not shared_group {
                new_encoded = os.fsencode(moved);
                with inotify._lock {
                    current = inotify._path_for_wd.get(wd);
                    if current is not None
                        and inotify._wd_for_path.get(current) == wd {
                        del inotify._wd_for_path[current];
                    }
                    inotify._wd_for_path[new_encoded] = wd;
                    inotify._path_for_wd[wd] = new_encoded;
                }
            }
            self._watched_paths.discard(watched);
            self._watched_paths.add(moved);
            self._wd_by_path[moved] = wd;
        }
    }
    self.add_tree(destination_real);
}

impl _PrunedInotifyEmitter.remove_tree(self: _PrunedInotifyEmitter, path: str) {
    resolved = os.path.realpath(path);
    with self._watch_lock {
        paths = sorted(
            (
                watched
                for watched in self._watched_paths
                if watched == resolved or watched.startswith(resolved + os.sep)
            ),
            key=len,
            reverse=True
        );
        group: any = self._inotify;
        shared_group: bool = hasattr(group, "_active_callbacks_by_path");
        inotify: any = None if shared_group else group._inotify;
        for watched in paths {
            wd = self._wd_by_path.pop(watched, None);
            self._watched_paths.discard(watched);
            if wd is None {
                continue;
            }
            if shared_group {
                with group._lock {
                    if wd in group._active_callbacks_by_watch {
                        group._remove_callbacks([wd]);
                    }
                }
            } else {
                with inotify._lock {
                    if wd in inotify._path_for_wd
                        and inotify_rm_watch(inotify._inotify_fd, wd) == -1 {
                        logger.warning(
                            f"Could not remove inotify watch {wd} for {watched}"
                        );
                    }
                }
            }
        }
    }
}

impl SharedPrunedInotifyObserver.init(
    self: SharedPrunedInotifyObserver,
    handler: FileSystemEventHandler,
    roots: list[tuple[str, bool]],
    ignore_directory: Callable[[str, bool], bool]
) {
    self._roots = roots;
    self._observer = BaseObserver(
        partial(
            _PrunedInotifyEmitter, roots=self._roots, ignore_directory=ignore_directory
        )
    );
    self._handler = handler;
    self._started = False;
}

impl SharedPrunedInotifyObserver.start(self: SharedPrunedInotifyObserver) {
    if self._started or not self._roots {
        return;
    }
    anchor = self._roots[0][0];
    self._observer.schedule(self._handler, anchor, recursive=False);
    self._observer.start();
    self._started = True;
}

impl SharedPrunedInotifyObserver.stop(self: SharedPrunedInotifyObserver) {
    if self._started {
        self._observer.stop();
    }
}

impl SharedPrunedInotifyObserver.join(
    self: SharedPrunedInotifyObserver, timeout: (float | None) = None
) {
    if self._started {
        self._observer.join(timeout=timeout);
        self._started = False;
    }
}

impl SharedPrunedInotifyObserver.is_watched(
    self: SharedPrunedInotifyObserver, path: str
) -> bool {
    resolved = os.path.realpath(path);
    return any(emitter.is_watched(resolved) for emitter in self._observer.emitters);
}

impl SharedPrunedInotifyObserver.add_directory(
    self: SharedPrunedInotifyObserver, path: str, allow_hidden_root: bool = False
) {
    for emitter in self._observer.emitters {
        try {
            emitter.add_directory(path, allow_hidden_root);
        } except OSError as e {
            logger.exception(f"Could not add inotify watch for {path}: {e}");
        }
    }
}

impl SharedPrunedInotifyObserver.add_tree(
    self: SharedPrunedInotifyObserver, path: str, allow_hidden_root: bool = False
) {
    for emitter in self._observer.emitters {
        try {
            emitter.add_tree(path, allow_hidden_root);
        } except OSError as e {
            logger.exception(f"Could not add inotify watches under {path}: {e}");
        }
    }
}

impl SharedPrunedInotifyObserver.move_tree(
    self: SharedPrunedInotifyObserver, source: str, destination: str
) {
    for emitter in self._observer.emitters {
        emitter.move_tree(source, destination);
    }
}

impl SharedPrunedInotifyObserver.remove_tree(
    self: SharedPrunedInotifyObserver, path: str
) {
    for emitter in self._observer.emitters {
        emitter.remove_tree(path);
    }
}
