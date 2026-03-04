"""Implementation of console utilities for terminal output (jacpretty)."""
import os;
import sys;
import from contextlib { contextmanager }
import from typing { Any }
import from jaclang.cli.jacpretty { Console as _PrettyConsole }

# ===============================================================================
# Internal jacpretty Console Factories
# ===============================================================================
def _stdout -> _PrettyConsole {
    return _PrettyConsole();
}

def _stderr -> _PrettyConsole {
    return _PrettyConsole(file=sys.stderr);
}

def _print(*args: Any, **kwargs: Any) -> None {
    _PrettyConsole().print(*args, **kwargs);
}

# ===============================================================================
# JacConsole Implementation
# ===============================================================================
"""Initialize the console."""
impl JacConsole.init -> None {
    self.use_emoji = JacConsole._should_use_emoji();
    self.use_color = JacConsole._should_use_color();
}

"""Check if emoji should be used based on environment.

Returns:
    True if emoji should be used, False otherwise
"""
impl JacConsole._should_use_emoji -> bool {
    if os.environ.get('NO_EMOJI') or os.environ.get('TERM') == 'dumb' {
        return False;
    }
    if sys.platform == 'win32' and not os.environ.get('WT_SESSION') {
        return False;
    }
    return True;
}

"""Check if color should be used based on environment.

Returns:
    True if color should be used, False otherwise
"""
impl JacConsole._should_use_color -> bool {
    if os.environ.get('NO_COLOR') {
        return False;
    }
    if os.environ.get('TERM') == 'dumb' {
        return False;
    }
    return True;
}

"""Print to stdout using jacpretty's Console.

Supports markup tags like [bold], [red], [bold red on blue], etc.
When markup=False is passed, text is printed as-is with no markup parsing.
"""
impl JacConsole.print(*args: Any, **kwargs: Any) -> None {
    # Extract markup flag (default True)
    markup = kwargs.pop('markup', True);
    # Extract style (default empty)
    style = kwargs.pop('style', '');
    # Remove unsupported kwargs
    kwargs.pop('highlight', None);
    # Forward to jacpretty console
    _print(
        *args,
        sep=kwargs.pop('sep', ' '),
        end=kwargs.pop('end', '\n'),
        style=style,
        markup=markup
    );
    # Flush explicitly: jacpretty's Console.print() only flushes when is_terminal
    # is True, but subprocess/PIPE stdout is fully buffered (not line-buffered).
    # Without this, server output never reaches the PIPE reader.
    sys.stdout.flush();
}

"""Context manager for status during long operations (basic implementation)."""
impl JacConsole.status(*args: Any, **kwargs: Any) -> object {
    if args {
        _print(f"[dim]{args[0] if isinstance(args[0], str) else str(args[0])}[/]");
    }
    @contextmanager
    def _noop_status -> object {
        yield None;
    }
    return _noop_status();
}

"""Print a success message with a green checkmark."""
impl JacConsole.success(message: str, emoji: bool = True) -> None {
    prefix = '✔' if emoji and self.use_emoji else '[OK]';
    _print(f"[bold green]{prefix}[/] {message}");
}

"""Print an error message in red with optional hint.

Args:
    message: The error message
    hint: Optional hint or suggestion
    emoji: Whether to use emoji (✖) or text ([ERROR])
"""
impl JacConsole.error(
    message: str, hint: str | None = None, emoji: bool = True
) -> None {
    prefix = '✖' if emoji and self.use_emoji else '[ERROR]';
    _stderr().print(f"[bold red]{prefix} Error:[/] {message}");
    if hint {
        hint_prefix = '💡' if self.use_emoji else 'HINT:';
        _stderr().print(f"[dim]{hint_prefix} {hint}[/]");
    }
}

"""Print a warning message in yellow."""
impl JacConsole.warning(message: str, emoji: bool = True) -> None {
    prefix = '⚠' if emoji and self.use_emoji else '[WARNING]';
    _print(f"[bold yellow]{prefix}[/] {message}");
}

"""Print an info message in cyan."""
impl JacConsole.info(message: str, emoji: bool = True) -> None {
    prefix = 'ℹ' if emoji and self.use_emoji else '[INFO]';
    _print(f"[bold cyan]{prefix}[/] {message}");
}

"""Print a header with optional version.

Args:
    title: Header title
    version: Optional version string
"""
impl JacConsole.print_header(title: str, version: str | None = None) -> None {
    stdout = _stdout();
    stdout.rule();
    if version {
        _print(f"[bold bright_white]{title}[/]  [dim]v{version}[/]");
    } else {
        _print(f"[bold bright_white]{title}[/]");
    }
    stdout.rule();
}

"""Print a list of labeled URLs.

Args:
    urls: Dict or list of tuples mapping labels to URLs
    symbol: Symbol to use before each line (default: ➜)
"""
impl JacConsole.print_urls(urls: Any, symbol: str = '➜') -> None {
    items = urls.items() if isinstance(urls, dict) else urls;
    for (label, url) in items {
        padded_label = f"{label}:".ljust(10);
        _print(
            f"  [bold cyan]{symbol}[/]  [dim]{padded_label}[/] [bright_blue underline]{url}[/]"
        );
    }
}

"""Print a bordered box with next steps.

Args:
    steps: List of step strings
    title: Box title (default: "Next Steps")
"""
impl JacConsole.print_next_steps(steps: list[str], title: str = 'Next Steps') -> None {
    _print(f"\n[bold bright_white]{title}:[/]");
    for (i, step) in enumerate(steps, 1) {
        _print(f"  [bold cyan]{i}.[/] {step}");
    }
    _print();
}

"""Print a list of items with colored symbols.

Args:
    items: List of items to print
    style: Style key ('success', 'warning', 'error', 'info')
    symbol: Symbol to prefix each item
"""
impl JacConsole.print_list(
    items: list[str], style: str = 'success', symbol: str = '✔'
) -> None {
    color_map = {
        'success': 'bold green',
        'warning': 'bold yellow',
        'error': 'bold red',
        'info': 'bold cyan'
    };
    color = color_map.get(style, 'bold green');
    for item in items {
        _print(f"  [{color}]{symbol}[/] {item}");
    }
}

"""Print a formatted table with colored headers.

Args:
    headers: Column headers
    rows: List of rows (each row is a list of strings)
    title: Optional table title
"""
impl JacConsole.print_table(
    headers: list[str], rows: list[list[str]], title: str | None = None
) -> None {
    if title {
        _print(f"\n[bold bright_white]{title}:[/]");
    }
    # Calculate column widths
    col_widths: list[int] = [len(h) for h in headers];
    for row in rows {
        for (i, cell) in enumerate(row) {
            if i < len(col_widths) {
                col_widths[i] = max(col_widths[i], len(str(cell)));
            }
        }
    }
    # Print header row
    header_parts = [
        f"[bold bright_white]{h.ljust(w)}[/]" for (h, w) in zip(headers, col_widths)
    ];
    _print(' [dim]|[/] '.join(header_parts));
    separator = '-' * (sum(col_widths) + (len(col_widths) - 1) * 3);
    _print(f"[dim]{separator}[/]");
    # Print data rows
    for row in rows {
        row_parts = [
            str(cell).ljust(col_widths[i]) if i < len(col_widths) else str(cell)
            for (i, cell) in enumerate(row)
        ];
        _print(' [dim]|[/] '.join(row_parts));
    }
    _print();
}

"""Context manager for spinner during long operations.

Usage:
    with console.spinner("Loading..."):
        # do work
        pass
"""
@ contextmanager
impl JacConsole.spinner(text: str) -> object {
    _print(f"[dim]{text}...[/]", end='');
    sys.stdout.flush();
    try {
        yield None;
    } finally {
        _print(f" [bold green]done[/]");
    }
}

"""Print elapsed time in a human-friendly format.

Args:
    seconds: Time in seconds
"""
impl JacConsole.print_elapsed_time(seconds: float) -> None {
    if seconds < 1 {
        ms = seconds * 1000;
        _print(f"  [dim]Done in[/] [bold green]{ms:.0f}ms[/]");
    } else {
        _print(f"  [dim]Done in[/] [bold green]{seconds:.1f}s[/]");
    }
}

"""Print file change notification with timestamp.

Args:
    filepath: Path to the file
    action: Action performed (changed, created, deleted)
"""
impl JacConsole.print_file_change(filepath: str, action: str = 'changed') -> None {
    import from datetime { datetime }
    timestamp = datetime.now().strftime('%H:%M:%S');
    emoji_map = {'changed': '⚡', 'created': '✨', 'deleted': '🗑️'};
    color_map = {'changed': 'yellow', 'created': 'green', 'deleted': 'red'};
    emoji = emoji_map.get(action, '📝') if self.use_emoji else action.upper();
    color = color_map.get(action, 'cyan');
    _print(
        f"[dim][{timestamp}][/] [{color}]{emoji} {action.capitalize()}:[/] {filepath}"
    );
}

"""Print file watching status.

Args:
    pattern: File pattern being watched
    count: Number of files
"""
impl JacConsole.print_watching(pattern: str, count: int) -> None {
    watch_emoji = '👀 ' if self.use_emoji else '';
    _print(f"[bold cyan]{watch_emoji}Watching for changes...[/]");
    _print(
        f"   [dim]Monitoring:[/] [bright_white]{pattern}[/] [dim]({count} files)[/]"
    );
}

# ===============================================================================
# Module-level function implementations
# ===============================================================================
"""Get the console instance using the hook system, allowing plugins to override."""
impl _get_console -> JacConsole {
    global _console_instance;
    if _console_instance is None {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        _console_instance = Jac.get_console();
        _console_instance.init();
    }
    return _console_instance;
}
