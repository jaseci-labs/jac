"""Console utilities for terminal output.

This module provides utilities for terminal output using jacpretty.
It includes:
- JacConsole class with rich-styled print methods
- A module-level `console` instance ready to use
- Support for NO_COLOR and NO_EMOJI environment variables
"""
import from contextlib { contextmanager }
import from typing { Any }

"""Console utility class for terminal output in Jac CLI."""
obj JacConsole {
    has use_emoji: bool = True,
        use_color: bool = True;

    def init -> None;
    static def _should_use_emoji -> bool;
    static def _should_use_color -> bool;
    def print(*args: Any, **kwargs: Any) -> None;
    def status(*args: Any, **kwargs: Any) -> object;
    def success(message: str, emoji: bool = True) -> None;
    def error(message: str, hint: str | None = None, emoji: bool = True) -> None;
    def warning(message: str, emoji: bool = True) -> None;
    def info(message: str, emoji: bool = True) -> None;
    def print_header(title: str, version: str | None = None) -> None;
    def print_urls(urls: Any, symbol: str = '➜') -> None;
    def print_next_steps(steps: list[str], title: str = 'Next Steps') -> None;
    def print_list(items: list[str], style: str = 'success', symbol: str = '✔') -> None;
    def print_table(
        headers: list[str], rows: list[list[str]], title: str | None = None
    ) -> None;

    @contextmanager
    def spinner(text: str) -> object;

    def print_elapsed_time(seconds: float) -> None;
    def print_file_change(filepath: str, action: str = 'changed') -> None;
    def print_watching(pattern: str, count: int) -> None;
}

# Module-level console instance
glob console: JacConsole = JacConsole();
