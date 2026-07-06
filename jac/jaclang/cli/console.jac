import os;
import sys;
import from contextlib { contextmanager, AbstractContextManager }
import from typing { cast }

obj Content {
    has text: str;

    def __str__ -> str {
        return self.text;
    }
}

obj Span {
    has text: str,
        style: str | None = None;
}

obj _Spinner {
    has text: str,
        stream: any,
        frames: list[str],
        style_prefix: str,
        reset: str,
        interval: float = 0.08,
        _stop: any by postinit,
        _thread: any = None;

    def postinit {
        import from threading { Event }
        self._stop = Event();
    }

    def update(text: str = '') {
        self.text = text;
    }

    def clear {
        try {
            self.stream.write("\r\033[K");
            self.stream.flush();
        } except (BrokenPipeError, OSError) {
            ;
        }
    }

    def _run {
        idx = 0;
        while not self._stop.is_set() {
            frame = self.frames[idx % len(self.frames)];
            try {
                self.stream.write(
                    f"\r{self.style_prefix}{frame}{self.reset} {self.text}"
                );
                self.stream.flush();
            } except (BrokenPipeError, OSError) {
                return;
            }
            idx += 1;
            self._stop.wait(self.interval);
        }
    }

    def start {
        import from threading { Thread }
        self._thread = Thread(target=self._run, daemon=True);
        self._thread.start();
    }

    def stop {
        self._stop.set();
        if self._thread is not None {
            self._thread.join(timeout=1.0);
        }
        self.clear();
    }
}

obj _NullStatus {
    def update(text: str = '') -> None {
        return;
    }

    def clear -> None {
        return;
    }
}

obj ConsoleRenderer {
    has use_emoji: bool = True,
        use_color: bool = True,
        _active_status: any = None;

    def configure(use_emoji: bool, use_color: bool) -> None;
    def clear_status -> None;
    def emit(spans: list[Span], stream: any = None) -> None;
    def emit_raw(args: list, stream: any, style: str | None, kwargs: dict) -> None;
    def header(title: str, version: str | None = None) -> None;
    def urls(items: list, symbol: str = '') -> None;
    def next_steps(steps: list[str], title: str = 'Next Steps') -> None;
    def table(
        headers: list[str], rows: list[list[str]], title: str | None = None
    ) -> None;

    @contextmanager
    def status_ctx(args: list, kwargs: dict) -> object;

    @contextmanager
    def spinner_ctx(text: str) -> object;
}

obj JacConsole {
    has use_emoji: bool = True,
        use_color: bool = True,
        _renderer: ConsoleRenderer by postinit;

    def postinit -> None;
    def _make_renderer -> ConsoleRenderer;
    static def _should_use_emoji -> bool;
    static def _should_use_color -> bool;
    def _resolve_stream(file: any = None) -> any;
    def print(*args: any, **kwargs: any) -> None;
    def status(*args: any, **kwargs: any) -> AbstractContextManager;
    def success(message: str, emoji: bool = True) -> None;
    def error(message: str, hint: str | None = None, emoji: bool = True) -> None;
    def warning(message: str, emoji: bool = True) -> None;
    def info(message: str, emoji: bool = True) -> None;
    def print_header(title: str, version: str | None = None) -> None;
    def print_urls(urls: any, symbol: str = '') -> None;
    def print_next_steps(steps: list[str], title: str = 'Next Steps') -> None;
    def print_list(items: list[str], style: str = 'success', symbol: str = '') -> None;
    def print_table(
        headers: list[str], rows: list[list[str]], title: str | None = None
    ) -> None;

    @contextmanager
    def spinner(text: str) -> object;

    def print_elapsed_time(seconds: float) -> None;
    def print_file_change(filepath: str, action: str = 'changed') -> None;
    def print_watching(pattern: str, count: int) -> None;
}

glob _console_instance: JacConsole | None = None;

def _get_console -> JacConsole;

class _ConsoleProxy {
    def __getattr__(self: _ConsoleProxy, name: str) -> any {
        return getattr(_get_console(), name);
    }
}

glob console: JacConsole = cast(JacConsole, _ConsoleProxy());
