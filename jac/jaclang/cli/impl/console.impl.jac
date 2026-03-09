"""Implementation of console utilities for terminal output (jacpretty)."""
import os;
import sys;
import from contextlib { contextmanager }
import from typing { Any }
import from jaclang.cli.jacpretty { Console as _PrettyConsole, Panel, Table, Theme }

# ===============================================================================
# Theme
# ===============================================================================
glob _JAC_THEME = Theme(
    {
        'success': 'green',
        'error': 'red',
        'warning': 'yellow',
        'info': 'cyan',
        'url': 'underline bright_blue',
        'muted': 'dim',
        'highlight': 'cyan',
        'time': 'yellow'
    }
);

# ===============================================================================
# Internal jacpretty Console Factories (persistent, theme-aware)
# ===============================================================================
glob _stdout_console: _PrettyConsole | None = None,
     _stderr_console: _PrettyConsole | None = None;

def _stdout -> _PrettyConsole {
    global _stdout_console;
    if _stdout_console is None {
        _stdout_console = _PrettyConsole(theme=_JAC_THEME);
    }
    return _stdout_console;
}

def _stderr -> _PrettyConsole {
    global _stderr_console;
    if _stderr_console is None {
        _stderr_console = _PrettyConsole(theme=_JAC_THEME, stderr=True);
    }
    return _stderr_console;
}

def _print(*args: Any, **kwargs: Any) -> None {
    _stdout().print(*args, **kwargs);
}

# ===============================================================================
# JacConsole Implementation
# ===============================================================================
"""Initialize the console."""
impl JacConsole.init -> None {
    self.use_emoji = JacConsole._should_use_emoji();
    self.use_color = JacConsole._should_use_color();
}

"""Check if emoji should be used based on environment."""
impl JacConsole._should_use_emoji -> bool {
    if os.environ.get('NO_EMOJI') or os.environ.get('TERM') == 'dumb' {
        return False;
    }
    if sys.platform == 'win32' and not os.environ.get('WT_SESSION') {
        return False;
    }
    return True;
}

"""Check if color should be used based on environment."""
impl JacConsole._should_use_color -> bool {
    if os.environ.get('NO_COLOR') {
        return False;
    }
    if os.environ.get('TERM') == 'dumb' {
        return False;
    }
    return True;
}

"""Print to stdout using jacpretty's Console."""
impl JacConsole.print(*args: Any, **kwargs: Any) -> None {
    file = kwargs.pop('file', None);
    console = _stderr() if (file == sys.stderr) else _stdout();
    console.print(*args, **kwargs);
    # Flush explicitly: subprocess/PIPE stdout is fully buffered (not line-buffered).
    # Without this, server output never reaches the PIPE reader.
    sys.stdout.flush();
}

"""Context manager for status with real spinner animation."""
impl JacConsole.status(*args: Any, **kwargs: Any) -> object {
    return _stdout().status(*args, **kwargs);
}

"""Print a success message."""
impl JacConsole.success(message: str, emoji: bool = True) -> None {
    prefix = '✔' if emoji and self.use_emoji else '[OK]';
    _print(f"{prefix} {message}", style='success');
}

"""Print an error message in red with optional hint."""
impl JacConsole.error(
    message: str, hint: str | None = None, emoji: bool = True
) -> None {
    prefix = '✖' if emoji and self.use_emoji else '[ERROR]';
    _stderr().print(f"{prefix} Error: {message}", style='error');
    if hint {
        hint_prefix = '💡' if self.use_emoji else 'HINT:';
        _stderr().print(f"{hint_prefix} {hint}", style='info');
    }
}

"""Print a warning message."""
impl JacConsole.warning(message: str, emoji: bool = True) -> None {
    prefix = '⚠' if emoji and self.use_emoji else '[WARNING]';
    _print(f"{prefix} {message}", style='warning');
}

"""Print an info message."""
impl JacConsole.info(message: str, emoji: bool = True) -> None {
    prefix = 'ℹ' if emoji and self.use_emoji else '[INFO]';
    _print(f"{prefix} {message}", style='info');
}

"""Print a header with optional version."""
impl JacConsole.print_header(title: str, version: str | None = None) -> None {
    stdout = _stdout();
    stdout.rule();
    if version {
        stdout.print(f"[bright_white]{title}[/]  [muted]v{version}[/]");
    } else {
        stdout.print(f"[bright_white]{title}[/]");
    }
    stdout.rule();
}

"""Print a list of labeled URLs."""
impl JacConsole.print_urls(urls: Any, symbol: str = '➜') -> None {
    items = urls.items() if isinstance(urls, dict) else urls;
    for (label, url) in items {
        padded_label = f"{label}:".ljust(10);
        _print(f"  [highlight]{symbol}[/]  [muted]{padded_label}[/] [url]{url}[/]");
    }
}

"""Print a bordered panel with numbered next steps."""
impl JacConsole.print_next_steps(steps: list[str], title: str = 'Next Steps') -> None {
    content = '\n'.join(f"  {i}.  {step}" for (i, step) in enumerate(steps, 1));
    panel = Panel(content, title=title, border_style='cyan', padding=(0, 1));
    _print(panel.render(_stdout().width), markup=True);
}

"""Print a list of items with colored symbols."""
impl JacConsole.print_list(
    items: list[str], style: str = 'success', symbol: str = '✔'
) -> None {
    for item in items {
        _print(f"  {symbol} {item}", style=style);
    }
}

"""Print a formatted table."""
impl JacConsole.print_table(
    headers: list[str], rows: list[list[str]], title: str | None = None
) -> None {
    table = Table(title=title, show_header=True, header_style='highlight');
    for header in headers {
        table.add_column(header);
    }
    for row in rows {
        table.add_row(*row);
    }
    _print(table.render(_stdout().width), markup=True);
}

"""Context manager for spinner during long operations."""
@contextmanager
impl JacConsole.spinner(text: str) -> object {
    with _stdout().status(f"[highlight]{text}[/]", spinner='dots') as s {
        yield s;
    }
}

"""Print elapsed time in a human-friendly format."""
impl JacConsole.print_elapsed_time(seconds: float) -> None {
    if seconds < 1 {
        ms = seconds * 1000;
        _print(f"  Done in {ms:.0f}ms", style='muted');
    } else {
        _print(f"  Done in {seconds:.1f}s", style='muted');
    }
}

"""Print file change notification with timestamp."""
impl JacConsole.print_file_change(filepath: str, action: str = 'changed') -> None {
    import from datetime { datetime }
    timestamp = datetime.now().strftime('%H:%M:%S');
    emoji_map = {'changed': '⚡', 'created': '✨', 'deleted': '🗑️'};
    emoji = emoji_map.get(action, '📝') if self.use_emoji else action.upper();
    _print(f"[time][{timestamp}][/] {emoji} [highlight]{action.capitalize()}:[/] {filepath}");
}

"""Print file watching status."""
impl JacConsole.print_watching(pattern: str, count: int) -> None {
    watch_emoji = '👀 ' if self.use_emoji else '';
    _print(f"{watch_emoji}Watching for changes...", style='info');
    _print(f"   Monitoring: {pattern} ({count} files)", style='muted');
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
