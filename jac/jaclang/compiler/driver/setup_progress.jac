import atexit;
import os;
import sys;
import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }

obj SetupProgress {
    has _banner_shown: bool = False,
        _compile_count: int = 0,
        _seen_files: set[str] postinit,
        _first_compile_at: (float | None) = None;

    def postinit -> None;
    def _atexit_handler -> None;
    def on_internal_compile(file_path: str) -> None;
    def on_kernel_build(lib_path: str) -> None;
    def _precompile_limit -> int;
    def _halt_at_limit -> None;

    has is_active: bool { getter; }
}

glob setup_progress = SetupProgress();
