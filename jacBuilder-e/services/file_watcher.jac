"""File Watcher — Detects filesystem changes in project directories.

Uses Python watchdog (already installed — jac start --dev depends on it).
Pushes batched events to a per-project queue that the frontend polls via WS.
"""

import os;
import time;
import from threading { Lock }
import from watchdog.observers { Observer }
import from watchdog.events { FileSystemEventHandler }
import from .event_bus { EventBus }


glob _watcher_registry: dict = {};
glob _watcher_lock = Lock();
glob _IGNORE_DIRS: set = {".git", ".jac", "node_modules", "__pycache__", "dist", "__jac_gen__", ".jac-ide", "build"};
glob _MAX_EVENTS: int = 500;


def _watcher_key(user_id: str, project_id: str) -> str {
    return str(user_id) + "::" + str(project_id);
}

def _should_ignore(path: str) -> bool {
    parts = path.replace("\\", "/").split("/");
    for part in parts {
        if part in _IGNORE_DIRS {
            return True;
        }
    }
    return False;
}


"""Sync a changed file from the repo dir to the running sandbox so HMR triggers.
Looks up the sandbox via preview_manager and calls sandbox.write_file()."""
def _sync_file_to_sandbox(watch_dir: str, rel_path: str, abs_path: str) -> None {
    try {
        import from services.preview_manager { _staging_dirs, _sandbox_id_map, _get_sandbox, _preview_key }
        # Find which user/project this watch_dir belongs to
        target_key = "";
        for k in _staging_dirs {
            if _staging_dirs[k] == watch_dir {
                target_key = k;
                break;
            }
        }
        if not target_key { return; }

        sid = _sandbox_id_map.get(target_key);
        if not sid { return; }

        sandbox = _get_sandbox();
        if sandbox is None { return; }

        # Read file content and write to sandbox
        if os.path.isfile(abs_path) {
            with open(abs_path, "r", encoding="utf-8") as f {
                content = f.read();
            }
            sandbox.write_file(sid, rel_path, content);
        }
    } except Exception {
        ;
    }
}


"""Watchdog event handler that batches filesystem events into a deque."""
obj JacWatchHandler(FileSystemEventHandler) {
    has watch_dir: str = "",
        event_queue: Any = None,
        last_git_event: float = 0.0;

    def on_created(event: Any) -> None {
        self._handle_fs_event(event, "created");
    }
    def on_deleted(event: Any) -> None {
        self._handle_fs_event(event, "deleted");
    }
    def on_modified(event: Any) -> None {
        self._handle_fs_event(event, "modified");
    }
    def on_moved(event: Any) -> None {
        self._handle_fs_event(event, "moved");
    }

    def _handle_fs_event(event: Any, action: str) -> None {
        if self.event_queue is None { return; }
        src = event.src_path if hasattr(event, "src_path") else "";
        if not src { return; }

        rel = os.path.relpath(src, self.watch_dir);
        if _should_ignore(rel) { return; }

        # Special case: .git metadata changed
        if rel.startswith(".git/") or rel.startswith(".git\\") {
            if rel in (".git/HEAD", ".git/index", ".git/COMMIT_EDITMSG") {
                now = time.time();
                if (now - self.last_git_event) > 1.0 {
                    self.last_git_event = now;
                        self.event_queue.publish({
                            "type": "git_changed",
                            "path": rel,
                            "action": action,
                            "is_dir": event.is_directory,
                            "timestamp": now
                        });
                }
            }
            return;
        }

        # Skip hidden files (except .env)
        basename = os.path.basename(rel);
        if basename.startswith(".") and basename != ".env" { return; }

        now = time.time();
        prefix = "dir_" if event.is_directory else "file_";
        evt = {
            "type": prefix + action,
            "path": rel,
            "action": action,
            "is_dir": event.is_directory,
            "timestamp": now
        };

        if hasattr(event, "dest_path") and event.dest_path {
            evt["dest_path"] = os.path.relpath(event.dest_path, self.watch_dir);
        }

        self.event_queue.publish(evt);

        # Sync file changes to the sandbox /tmp copy so HMR picks them up.
        # This bridges terminal edits (repo dir) → sandbox (jac start --dev dir).
        if not event.is_directory and action in ("created", "modified") {
            _sync_file_to_sandbox(self.watch_dir, rel, src);
        }
    }
}


"""Start a filesystem watcher for a project directory."""
def start_watcher(user_id: str, project_id: str, watch_dir: str) -> dict {
    key = _watcher_key(user_id, project_id);
    _watcher_lock.acquire();
    try {
        if key in _watcher_registry {
            existing = _watcher_registry[key];
            if existing.get("observer") and existing["observer"].is_alive() {
                return {"success": True, "status": "already_running"};
            }
            _watcher_registry.pop(key, None);
        }

        if not watch_dir or not os.path.isdir(watch_dir) {
            return {"success": False, "error": "Invalid watch directory"};
        }

        event_queue = EventBus(max_size=_MAX_EVENTS);
        handler = JacWatchHandler(watch_dir=watch_dir, event_queue=event_queue);

        observer = Observer();
        observer.schedule(handler, watch_dir, recursive=True);
        observer.daemon = True;
        observer.start();

        _watcher_registry[key] = {
            "observer": observer,
            "handler": handler,
            "event_queue": event_queue,
            "watch_dir": watch_dir,
            "user_id": user_id,
            "project_id": project_id
        };

        return {"success": True, "status": "started"};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    } finally {
        _watcher_lock.release();
    }
}


"""Drain all pending file events for a subscriber. Returns a deduplicated list."""
def drain_file_events(user_id: str, project_id: str, connection_id: str = "") -> list {
    key = _watcher_key(user_id, project_id);
    entry = _watcher_registry.get(key);
    if not entry {
        return [];
    }
    bus = entry["event_queue"];
    cid = connection_id if connection_id else key + "::default";
    raw = bus.drain(cid);
    if not raw {
        return [];
    }
    # Deduplicate: same path + same type → keep only latest
    seen = {};
    result = [];
    for evt in raw {
        path = evt.get("path", "");
        evt_type = evt.get("type", "");
        dedup_key = path + "::" + evt_type;
        if dedup_key not in seen {
            seen[dedup_key] = True;
            result.append(evt);
        }
    }
    return result;
}


"""Stop the filesystem watcher for a project."""
def stop_watcher(user_id: str, project_id: str) -> dict {
    key = _watcher_key(user_id, project_id);
    _watcher_lock.acquire();
    try {
        entry = _watcher_registry.pop(key, None);
        if not entry {
            return {"success": False, "error": "Watcher not running"};
        }
        observer = entry.get("observer");
        if observer {
            observer.stop();
            observer.join(timeout=3);
        }
        return {"success": True, "status": "stopped"};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    } finally {
        _watcher_lock.release();
    }
}


"""Get watcher status."""
def get_watcher_status(user_id: str, project_id: str) -> dict {
    key = _watcher_key(user_id, project_id);
    entry = _watcher_registry.get(key);
    if not entry {
        return {"running": False, "status": "none"};
    }
    observer = entry.get("observer");
    alive = observer is not None and observer.is_alive();
    return {"running": alive, "status": ("running" if alive else "stopped")};
}
