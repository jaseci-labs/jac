"""Console utilities for terminal output.

This module provides utilities for terminal output using pure Python.
It includes:
- Basic console instance with simple print methods
- Helper functions for common output patterns
- Support for NO_COLOR and NO_EMOJI environment variables

Plugins (like jac-super) can override this to provide Rich-enhanced output.
"""
import os;
import sys;
import from contextlib { contextmanager }
import from typing { Any }

"""Console utility class for terminal output in Jac CLI.

This is the base implementation using pure Python print().
Plugins can inherit from this and override methods to provide
enhanced output (e.g., Rich-based formatting).
"""
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

# Lazy initialization to avoid circular imports
glob _console_instance:
         JacConsole | None = None;

def _get_console -> JacConsole;

# Basic proxy class that lazily initializes the console on first access
# This allows plugins to override via the hook system while avoiding circular imports
class _ConsoleProxy {
    def __getattr__(self: _ConsoleProxy, name: str) -> Any {
        return getattr(_get_console(), name);
    }
}

# Export the proxy as console - provides clean attribute access with lazy initialization
glob console = _ConsoleProxy();
