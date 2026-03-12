"""File system watcher for HMR support.

Watches .jac files for changes and triggers callbacks for hot module replacement.
Uses the watchdog library for cross-platform file system events.
"""

import time;
import from pathlib { Path }
import from typing { Callable, Any }

"""Event types for file changes."""
enum ChangeType {
    CREATED,
    MODIFIED,
    DELETED
}

"""Represents a file change event."""
obj FileChangeEvent {
    has path: str,
        change_type: ChangeType,
        timestamp: float;
}

"""Watches .jac files for changes and triggers callbacks.

Uses watchdog library for cross-platform file system events.
Debounces rapid changes to avoid redundant reloads.
"""
obj JacFileWatcher {
    has watch_paths: list[str],
        pattern: str = "*.jac",
        additional_patterns: list[str] = [
            "*.tsx",
            "*.js",
            "*.css",
            "*.scss",
            "*.png",
            "*.jpg",
            "*.jpeg"
        ],
        _observer: Any = None,
        _callbacks: list[Callable[[FileChangeEvent], None]] = [],
        _debounce_ms: int = 100,
        _running: bool = False,
        _pending_events: dict[str, FileChangeEvent] = {},
        _last_flush: float = 0.0;

    def start -> None;
    def stop -> None;
    def add_callback(callback: Callable[[FileChangeEvent], None]) -> None;
    def remove_callback(callback: Callable[[FileChangeEvent], None]) -> None;
    def _on_change(path: str, change_type: ChangeType) -> None;
    def _debounce_flush -> None;
    def _matches_pattern(path: str) -> bool;
    def _notify_callbacks(event: FileChangeEvent) -> None;
}
