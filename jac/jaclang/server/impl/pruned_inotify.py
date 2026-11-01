"""A single pruned inotify emitter for a set of application watch roots.

Watchdog's normal recursive inotify emitter scans every descendant directory.
This emitter keeps one inotify instance and adds only directories accepted by
Jac's ignore predicate. The dependency on Watchdog's inotify internals is
isolated here so the rest of the server uses the normal Observer interface.
"""

from __future__ import annotations

import logging
import os
import threading
from collections.abc import Callable, Iterable
from functools import partial

from watchdog.events import FileSystemEventHandler
from watchdog.observers.api import BaseObserver
from watchdog.observers.inotify import InotifyEmitter
from watchdog.observers.inotify_c import inotify_rm_watch

logger = logging.getLogger(__name__)


class _PrunedInotifyEmitter(InotifyEmitter):
    """One emitter that adds pruned directory watches to one inotify instance."""

    def __init__(
        self,
        *args: object,
        roots: list[tuple[str, bool]],
        ignore_directory: Callable[[str, bool], bool],
        **kwargs: object,
    ) -> None:
        super().__init__(*args, **kwargs)
        self._roots = roots
        self._ignore_directory = ignore_directory
        self._watch_lock = threading.RLock()
        self._watched_paths: set[str] = set()
        self._wd_by_path: dict[str, int] = {}

    def on_thread_start(self) -> None:
        super().on_thread_start()
        for path, recursive in self._roots:
            if recursive:
                self.add_tree(path, allow_hidden_root=True)
            else:
                self.add_directory(path, allow_hidden_root=True)

    @property
    def watched_paths(self) -> set[str]:
        with self._watch_lock:
            return set(self._watched_paths)

    def add_directory(self, path: str, *, allow_hidden_root: bool = False) -> None:
        resolved = os.path.realpath(path)
        if self._ignore_directory(resolved, allow_hidden_root):
            return
        with self._watch_lock:
            if resolved in self._watched_paths:
                return
            encoded = os.fsencode(resolved)
            group = self._inotify
            if hasattr(group, "_active_callbacks_by_path"):
                # Watchdog 6 shares an InotifyFD and tracks callbacks in a
                # watch group. Reuse the root callback created by the emitter.
                with group._lock:
                    wd = group._active_callbacks_by_path.get(encoded)
                    if wd is None:
                        group._add_callback(encoded)
                        wd = group._active_callbacks_by_path.get(encoded)
                    if wd is None:
                        raise OSError(f"Watchdog did not register {resolved}")
            else:
                # Watchdog 3-5 wraps one Inotify object in InotifyBuffer.
                inotify = group._inotify
                inotify.add_watch(encoded)
                with inotify._lock:
                    wd = inotify._wd_for_path.get(encoded)
                if wd is None or wd < 0:
                    raise OSError(f"Watchdog did not register {resolved}")
            self._watched_paths.add(resolved)
            self._wd_by_path[resolved] = wd

    def add_tree(self, path: str, *, allow_hidden_root: bool = False) -> None:
        resolved = os.path.realpath(path)
        if not os.path.isdir(resolved):
            return
        for current, dirs, _ in os.walk(resolved, followlinks=False):
            current_real = os.path.realpath(current)
            allow_root = allow_hidden_root and current_real == resolved
            if self._ignore_directory(current_real, allow_root):
                dirs[:] = []
                continue
            dirs[:] = sorted(
                name
                for name in dirs
                if not os.path.islink(os.path.join(current, name))
                and not self._ignore_directory(os.path.join(current, name), False)
            )
            try:
                self.add_directory(current_real, allow_hidden_root=allow_root)
            except OSError:
                logger.exception("Could not add inotify watch for %s", current_real)

    def move_tree(self, source: str, destination: str) -> None:
        source_real = os.path.realpath(source)
        destination_real = os.path.realpath(destination)
        if self._ignore_directory(destination_real, False):
            self.remove_tree(source_real)
            return

        with self._watch_lock:
            self.remove_tree(destination_real)
            paths = sorted(
                (
                    watched
                    for watched in self._watched_paths
                    if watched == source_real
                    or watched.startswith(source_real + os.sep)
                ),
                key=len,
            )
            group = self._inotify
            shared_group = hasattr(group, "_active_callbacks_by_path")
            inotify = None if shared_group else group._inotify
            for watched in paths:
                wd = self._wd_by_path.pop(watched, None)
                if wd is None:
                    continue
                moved = destination_real + watched[len(source_real) :]
                if not shared_group:
                    new_encoded = os.fsencode(moved)
                    with inotify._lock:
                        current = inotify._path_for_wd.get(wd)
                        if current is not None and inotify._wd_for_path.get(current) == wd:
                            del inotify._wd_for_path[current]
                        inotify._wd_for_path[new_encoded] = wd
                        inotify._path_for_wd[wd] = new_encoded
                self._watched_paths.discard(watched)
                self._watched_paths.add(moved)
                self._wd_by_path[moved] = wd

        self.add_tree(destination_real)

    def remove_tree(self, path: str) -> None:
        resolved = os.path.realpath(path)
        with self._watch_lock:
            paths = sorted(
                (
                    watched
                    for watched in self._watched_paths
                    if watched == resolved or watched.startswith(resolved + os.sep)
                ),
                key=len,
                reverse=True,
            )
            group = self._inotify
            shared_group = hasattr(group, "_active_callbacks_by_path")
            inotify = None if shared_group else group._inotify
            for watched in paths:
                wd = self._wd_by_path.pop(watched, None)
                self._watched_paths.discard(watched)
                if wd is None:
                    continue
                if shared_group:
                    with group._lock:
                        if wd in group._active_callbacks_by_watch:
                            group._remove_callbacks([wd])
                else:
                    # Keep Watchdog's descriptor maps until its reader
                    # consumes IN_IGNORED. Removing their entries early makes
                    # older read_events() implementations raise KeyError.
                    with inotify._lock:
                        if wd in inotify._path_for_wd:
                            if inotify_rm_watch(inotify._inotify_fd, wd) == -1:
                                logger.warning(
                                    "Could not remove inotify watch %s for %s",
                                    wd,
                                    watched,
                                )


class SharedPrunedInotifyObserver:
    """Watch selected trees with one Watchdog inotify emitter and instance."""

    def __init__(
        self,
        handler: FileSystemEventHandler,
        roots: Iterable[tuple[str, bool]],
        ignore_directory: Callable[[str, bool], bool],
    ) -> None:
        self._roots = list(roots)
        self._observer = BaseObserver(
            partial(
                _PrunedInotifyEmitter,
                roots=self._roots,
                ignore_directory=ignore_directory,
            )
        )
        self._handler = handler
        self._started = False

    @property
    def emitters(self) -> set[object]:
        return self._observer.emitters

    @property
    def watched_paths(self) -> set[str]:
        return {
            path
            for emitter in self._observer.emitters
            for path in emitter.watched_paths
        }

    def start(self) -> None:
        if self._started or not self._roots:
            return
        anchor = self._roots[0][0]
        self._observer.schedule(self._handler, anchor, recursive=False)
        self._observer.start()
        self._started = True

    def stop(self) -> None:
        if self._started:
            self._observer.stop()

    def join(self, timeout: float | None = None) -> None:
        if self._started:
            self._observer.join(timeout=timeout)
            self._started = False

    def add_directory(self, path: str, *, allow_hidden_root: bool = False) -> None:
        for emitter in self._observer.emitters:
            try:
                emitter.add_directory(path, allow_hidden_root=allow_hidden_root)
            except OSError:
                logger.exception("Could not add inotify watch for %s", path)

    def add_tree(self, path: str, *, allow_hidden_root: bool = False) -> None:
        for emitter in self._observer.emitters:
            try:
                emitter.add_tree(path, allow_hidden_root=allow_hidden_root)
            except OSError:
                logger.exception("Could not add inotify watches under %s", path)

    def move_tree(self, source: str, destination: str) -> None:
        for emitter in self._observer.emitters:
            emitter.move_tree(source, destination)

    def remove_tree(self, path: str) -> None:
        for emitter in self._observer.emitters:
            emitter.remove_tree(path)
