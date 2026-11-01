import logging;
import os;
import threading;
import from functools { partial }
import from watchdog.events { FileSystemEventHandler }
import from watchdog.observers.api { BaseObserver }
import from watchdog.observers.inotify { InotifyEmitter }
import from watchdog.observers.inotify_c { inotify_rm_watch }

glob logger = logging.getLogger(__name__);

class _PrunedInotifyEmitter(InotifyEmitter) {
    has _roots: list[tuple[str, bool]],
        _ignore_directory: Callable[[str, bool], bool],
        _inotify: any = None,
        _watch_lock: any,
        _watched_paths: set[str] = set(),
        _wd_by_path: dict[str, int] = {};

    def init(
        self: _PrunedInotifyEmitter,
        event_queue: any,
        watch: any,
        roots: list[tuple[str, bool]],
        ignore_directory: Callable[[str, bool], bool],
        timeout: any,
        event_filter: any = None
    );

    def on_thread_start(self: _PrunedInotifyEmitter);

    has watched_paths: set[str] {
        getter {
            with self._watch_lock {
                return set(self._watched_paths);
            }
        }
    }

    def add_directory(
        self: _PrunedInotifyEmitter, path: str, allow_hidden_root: bool = False
    );

    def add_tree(
        self: _PrunedInotifyEmitter, path: str, allow_hidden_root: bool = False
    );

    def move_tree(self: _PrunedInotifyEmitter, source: str, destination: str);
    def remove_tree(self: _PrunedInotifyEmitter, path: str);
}

class SharedPrunedInotifyObserver {
    has _roots: list[tuple[str, bool]],
        _observer: any,
        _handler: FileSystemEventHandler,
        _started: bool = False;

    def init(
        self: SharedPrunedInotifyObserver,
        handler: FileSystemEventHandler,
        roots: list[tuple[str, bool]],
        ignore_directory: Callable[[str, bool], bool]
    );

    has emitters: set[any] {
        getter {
            return self._observer.emitters;
        }
    }

    has watched_paths: set[str] {
        getter {
            return {
                path for emitter in self._observer.emitters
                for path in emitter.watched_paths
            };
        }
    }

    def start(self: SharedPrunedInotifyObserver);
    def stop(self: SharedPrunedInotifyObserver);
    def join(self: SharedPrunedInotifyObserver, timeout: (float | None) = None);
    def add_directory(
        self: SharedPrunedInotifyObserver, path: str, allow_hidden_root: bool = False
    );

    def add_tree(
        self: SharedPrunedInotifyObserver, path: str, allow_hidden_root: bool = False
    );

    def move_tree(self: SharedPrunedInotifyObserver, source: str, destination: str);
    def remove_tree(self: SharedPrunedInotifyObserver, path: str);
}
