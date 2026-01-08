"""Development Server for Jac Programs with FE/BE separation and proxy support."""
import json;
import os;
import threading;
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from pathlib { Path }
import from typing { Any, Callable }
import from urllib.parse { urlparse }
import from http.client { HTTPConnection }
import from collections.abc { Set }

import from jaclang { JacRuntime as Jac }

"""Type alias for file change callback."""
glob FileChangeCallback: type = Callable[[Path, str], None];

"""Supported change types."""
glob CHANGE_MODIFIED: str = 'modified';
glob CHANGE_CREATED: str = 'created';
glob CHANGE_DELETED: str = 'deleted';

"""File extensions for backend files."""
glob BACKEND_EXTENSIONS: tuple = ('.jac', '.py');

"""File extensions for frontend files."""
glob FRONTEND_EXTENSIONS: tuple = ('.jac', '.js', '.jsx', '.ts', '.tsx', '.css', '.html');

"""Configuration for file watching."""
obj WatchConfig {
    has watch_paths: list[Path],
        ignore_patterns: list[str] = ['.jac/', '__pycache__/', 'node_modules/', '.git/', '*.pyc', '*.session'],
        backend_extensions: tuple = BACKEND_EXTENSIONS,
        frontend_extensions: tuple = FRONTEND_EXTENSIONS,
        debounce_ms: int = 300;
}

"""Manages file change handlers with support for plugin registration."""
obj FileChangeDispatcher {
    has _backend_handlers: list[FileChangeCallback] = [],
        _frontend_handlers: list[FileChangeCallback] = [],
        _generic_handlers: list[FileChangeCallback] = [];

    def register_backend_handler(handler: FileChangeCallback) -> None;
    def register_frontend_handler(handler: FileChangeCallback) -> None;
    def register_handler(handler: FileChangeCallback) -> None;
    def dispatch_backend_change(file_path: Path, change_type: str) -> None;
    def dispatch_frontend_change(file_path: Path, change_type: str) -> None;
    def dispatch_change(file_path: Path, change_type: str, is_frontend: bool) -> None;
    def clear_handlers -> None;
}

"""Core file watcher that monitors directories for changes."""
obj JacFileWatcher {
    has project_root: Path,
        config: WatchConfig,
        dispatcher: FileChangeDispatcher,
        _observer: Any = None,
        _running: bool = False,
        _lock: threading.Lock = threading.Lock(),
        _last_change: dict[(str, float)] = {},
        verbose: bool = False;

    def start -> None;
    def stop -> None;
    def is_running -> bool;
    def _should_ignore(file_path: Path) -> bool;
    def _is_frontend_file(file_path: Path) -> bool;
    def _is_backend_file(file_path: Path) -> bool;
    def _handle_event(file_path: Path, change_type: str) -> None;
}

"""Creates a file watcher with default configuration."""
def create_watcher(
    project_root: Path,
    watch_paths: (list[Path] | None) = None,
    verbose: bool = False
) -> JacFileWatcher;

"""Development server that runs FE on one port and proxies API calls to BE."""
obj JacDevServer {
    has module_name: str,
        session_path: str,
        base_path: str,
        module_path: (Path | None) = None,
        be_port: int = 8000,
        fe_port: int = 3000,
        fe_host: str = 'localhost',
        _be_server: Any = None,
        _be_thread: (threading.Thread | None) = None,
        _be_httpd: (HTTPServer | None) = None,
        _fe_server: (HTTPServer | None) = None,
        _file_watcher: (JacFileWatcher | None) = None,
        _restart_lock: threading.Lock = threading.Lock(),
        _restart_pending: bool = False,
        _plugin_handles_fe: bool = False,
        verbose: bool = False;

    def _start_backend -> None;
    def _restart_backend -> None;
    def _create_fe_handler -> type[BaseHTTPRequestHandler];
    def _setup_file_watcher -> None;
    def _on_backend_change(file_path: Path, change_type: str) -> None;
    def _on_frontend_change(file_path: Path, change_type: str) -> None;
    def get_file_watcher -> (JacFileWatcher | None);
    def start -> None;
    def stop -> None;
}

"""Check if path should be proxied to backend."""
def should_proxy_path(path: str) -> bool;
