import os;
import sys;
import atexit;
import time;
import from collections.abc { Callable, Iterator }
import from contextlib { contextmanager }
import from jaclang.compiler.session.session { JacProgram }


obj _SetupProgress {
    has _banner_shown: bool = False,
        _compile_count: int = 0,
        _seen_files: set[str] postinit,
        _jaclang_root: (str | None) = None,
        _first_compile_at: (float | None) = None;

    def postinit -> None;
    def _get_jaclang_root -> str;
    def _atexit_handler -> None;
    def on_internal_compile(file_path: str) -> None;
    def _precompile_limit -> int;
    def _halt_at_limit -> None;

    has is_active: bool { getter; }
}

glob setup_progress = _SetupProgress();

obj CompileProgress {
    has _listeners: list[Callable[[str], None]] postinit,
        _finished_listeners: list[Callable[[str], None]] postinit;

    def postinit -> None;
    def notify(file_path: str) -> None;
    @contextmanager
    def track(file_path: str) -> Iterator[None];

    @contextmanager
    def listen(
        callback: Callable[[str], None],
        on_finished: Callable[[str], None] | None = None
    ) -> Iterator[None];
}

glob compile_progress = CompileProgress();

enum ProgressState {
    STARTED = "started",
    SUCCEEDED = "succeeded",
    FAILED = "failed",
    CANCELLED = "cancelled"
}

obj ProgressEvent {
    has operation: str,
        path: str,
        context: str,
        state: ProgressState,
        elapsed: float = 0.0;
}

obj PipelineProgress {
    has listeners: list[Callable[[ProgressEvent], None]] = [];

    def emit(event: ProgressEvent) {
        for listener in list(self.listeners) {
            listener(event);
        }
    }

    @contextmanager
    def listen(listener: Callable[[ProgressEvent], None]) -> Iterator[None] {
        self.listeners.append(listener);
        try {
            yield ;
        } finally {
            self.listeners.remove(listener);
        }
    }
}

glob pipeline_progress = PipelineProgress();
