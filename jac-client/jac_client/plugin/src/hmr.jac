"""HMR (Hot Module Replacement) implementation for jac-client.

This module provides development server capabilities with hot module replacement
using Vite's dev server. .jac files are pre-compiled to .js and Vite handles HMR.
"""

import subprocess;
import threading;
import time;
import from pathlib { Path }
import from watchdog.observers { Observer }
import from watchdog.events { FileSystemEventHandler }

"""Vite development server manager."""
obj ViteDevServer {
    has project_dir: Path;
    has module_path: Path;
    has vite_process: (subprocess.Popen | None) = None;
    has watcher_thread: (threading.Thread | None) = None;
    has compiled_modules: set[Path] = set();
    has host: str = 'localhost';
    has port: int = 3000;
    has verbose: bool = False;

    def start -> None;
    def stop -> None;
    def create_vite_config -> None;
    def compile_all_jac_files -> None;
    def start_file_watcher -> None;
    def is_vite_available -> bool;
    def _create_runtime_stub(runtime_path: Path) -> None;
}

"""Watches source files and recompiles/copies on changes."""
obj JacFileWatcher {
    has project_dir: Path,
        compiled_modules: set[Path],
        observer: (Observer | None) = None,
        verbose: bool = False;

    def start -> None;
    def stop -> None;
    def on_file_changed(file_path: Path) -> None;
}

"""Handles .jac file compilation."""
obj HMRCompiler {
    has project_dir: Path,
        verbose: bool = False;

    def compile_recursively(module_path: Path, client_dir: Path, visited: (set[Path] | None) = None, source_root: (Path | None) = None) -> set[Path];
    def _compile_to_js(module_path: Path) -> tuple[str, Any];
    def compile_module(module_path: Path, output_path: Path) -> None;
}