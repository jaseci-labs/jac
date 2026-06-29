import time;
import from pathlib { Path }
import from typing { Callable }

enum ChangeType { CREATED, MODIFIED, DELETED }

obj FileChangeEvent {
    has path: str,
        change_type: ChangeType,
        timestamp: float;
}

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
        _observer: any = None,
        _callbacks: list[Callable[[FileChangeEvent], None]] = [],
        _debounce_ms: int = 100,
        _running: bool = False,
        _pending_events: dict[str, FileChangeEvent] = {};

    def start -> None;
    def stop -> None;
    def add_callback(callback: Callable[[FileChangeEvent], None]) -> None;
    def remove_callback(callback: Callable[[FileChangeEvent], None]) -> None;
    def _on_change(path: str, change_type: ChangeType) -> None;
    def _debounce_flush -> None;
    def _matches_pattern(path: str) -> bool;
    def _notify_callbacks(event: FileChangeEvent) -> None;
}
