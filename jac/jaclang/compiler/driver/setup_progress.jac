import atexit;
import os;
import sys;

obj SetupProgress {
    has _banner_shown: bool = False,
        _compile_count: int = 0,
        _reuse_count: int = 0,
        _exit_registered: bool = False,
        _seen_files: set[str] postinit;

    def postinit -> None;
    def _atexit_handler -> None;
    def on_internal_compile(file_path: str) -> None;
    def on_internal_reuse(file_path: str) -> None;
    def _register_exit -> None;
}

glob setup_progress = SetupProgress();
