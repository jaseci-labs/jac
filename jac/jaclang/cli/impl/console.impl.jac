"""JacConsole implementation powered by jacpretty."""
import os, sys;
import from contextlib { contextmanager }
import from typing { Any }
import from jaclang.cli.jacpretty { Console as _PrettyConsole }

# Fresh instances per call so tests can redirect sys.stdout/sys.stderr freely.
def _get_pretty_stdout -> _PrettyConsole {
    return _PrettyConsole();
}

def _get_pretty_stderr -> _PrettyConsole {
    return _PrettyConsole(file=sys.stderr);
}

impl JacConsole.init -> None {
    self.use_emoji = JacConsole._should_use_emoji();
    self.use_color = JacConsole._should_use_color();
}

impl JacConsole._should_use_emoji -> bool {
    if os.environ.get('NO_EMOJI') or os.environ.get('TERM') == 'dumb' {
        return False;
    }
    if sys.platform == 'win32' and not os.environ.get('WT_SESSION') {
        return False;
    }
    return True;
}

impl JacConsole._should_use_color -> bool {
    if os.environ.get('NO_COLOR') or os.environ.get('TERM') == 'dumb' {
        return False;
    }
    return True;
}

impl JacConsole.print(*args: Any, **kwargs: Any) -> None {
    markup = kwargs.pop('markup', True);
    style = kwargs.pop('style', '');
    kwargs.pop('highlight', None);
    _get_pretty_stdout().print(
        *args,
        sep=kwargs.pop('sep', ' '),
        end=kwargs.pop('end', '\n'),
        style=style,
        markup=markup
    );
    # Flush so output reaches PIPE readers in subprocess contexts.
    sys.stdout.flush();
}

impl JacConsole.status(*args: Any, **kwargs: Any) -> object {
    if args {
        _get_pretty_stdout().print(
            f"[dim]{args[0] if isinstance(args[0], str) else str(args[0])}[/]"
        );
    }
    @contextmanager
    def _noop_status -> object {
        yield None;
    }
    return _noop_status();
}

impl JacConsole.success(message: str, emoji: bool = True) -> None {
    prefix = '✔' if emoji and self.use_emoji else '[OK]';
    _get_pretty_stdout().print(f"[bold green]{prefix}[/] {message}");
}

impl JacConsole.error(
    message: str, hint: str | None = None, emoji: bool = True
) -> None {
    prefix = '✖' if emoji and self.use_emoji else '[ERROR]';
    _get_pretty_stderr().print(f"[bold red]{prefix} Error:[/] {message}");
    if hint {
        hint_prefix = '💡' if self.use_emoji else 'HINT:';
        _get_pretty_stderr().print(f"[dim]{hint_prefix} {hint}[/]");
    }
}

impl JacConsole.warning(message: str, emoji: bool = True) -> None {
    prefix = '⚠' if emoji and self.use_emoji else '[WARNING]';
    _get_pretty_stdout().print(f"[bold yellow]{prefix}[/] {message}");
}

impl JacConsole.info(message: str, emoji: bool = True) -> None {
    prefix = 'ℹ' if emoji and self.use_emoji else '[INFO]';
    _get_pretty_stdout().print(f"[bold cyan]{prefix}[/] {message}");
}

impl JacConsole.print_header(title: str, version: str | None = None) -> None {
    pc = _get_pretty_stdout();
    pc.rule();
    if version {
        pc.print(f"[bold bright_white]{title}[/]  [dim]v{version}[/]");
    } else {
        pc.print(f"[bold bright_white]{title}[/]");
    }
    pc.rule();
}

impl JacConsole.print_urls(urls: Any, symbol: str = '➜') -> None {
    pc = _get_pretty_stdout();
    items = urls.items() if isinstance(urls, dict) else urls;
    for (label, url) in items {
        padded_label = f"{label}:".ljust(10);
        pc.print(
            f"  [bold cyan]{symbol}[/]  [dim]{padded_label}[/] [bright_blue underline]{url}[/]"
        );
    }
}

impl JacConsole.print_next_steps(steps: list[str], title: str = 'Next Steps') -> None {
    pc = _get_pretty_stdout();
    pc.print(f"\n[bold bright_white]{title}:[/]");
    for (i, step) in enumerate(steps, 1) {
        pc.print(f"  [bold cyan]{i}.[/] {step}");
    }
    pc.print();
}

impl JacConsole.print_list(
    items: list[str], style: str = 'success', symbol: str = '✔'
) -> None {
    pc = _get_pretty_stdout();
    color_map = {
        'success': 'bold green',
        'warning': 'bold yellow',
        'error': 'bold red',
        'info': 'bold cyan'
    };
    color = color_map.get(style, 'bold green');
    for item in items {
        pc.print(f"  [{color}]{symbol}[/] {item}");
    }
}

impl JacConsole.print_table(
    headers: list[str], rows: list[list[str]], title: str | None = None
) -> None {
    pc = _get_pretty_stdout();
    if title {
        pc.print(f"\n[bold bright_white]{title}:[/]");
    }
    col_widths: list[int] = [len(h) for h in headers];
    for row in rows {
        for (i, cell) in enumerate(row) {
            if i < len(col_widths) {
                col_widths[i] = max(col_widths[i], len(str(cell)));
            }
        }
    }
    header_parts = [
        f"[bold bright_white]{h.ljust(w)}[/]" for (h, w) in zip(headers, col_widths)
    ];
    pc.print(' [dim]|[/] '.join(header_parts));
    separator = '-' * (sum(col_widths) + (len(col_widths) - 1) * 3);
    pc.print(f"[dim]{separator}[/]");
    for row in rows {
        row_parts = [
            str(cell).ljust(col_widths[i]) if i < len(col_widths) else str(cell)
            for (i, cell) in enumerate(row)
        ];
        pc.print(' [dim]|[/] '.join(row_parts));
    }
    pc.print();
}

@ contextmanager
impl JacConsole.spinner(text: str) -> object {
    _get_pretty_stdout().print(f"[dim]{text}...[/]", end='');
    sys.stdout.flush();
    try {
        yield None;
    } finally {
        _get_pretty_stdout().print(f" [bold green]done[/]");
    }
}

impl JacConsole.print_elapsed_time(seconds: float) -> None {
    pc = _get_pretty_stdout();
    if seconds < 1 {
        ms = seconds * 1000;
        pc.print(f"  [dim]Done in[/] [bold green]{ms:.0f}ms[/]");
    } else {
        pc.print(f"  [dim]Done in[/] [bold green]{seconds:.1f}s[/]");
    }
}

impl JacConsole.print_file_change(filepath: str, action: str = 'changed') -> None {
    import from datetime { datetime }
    pc = _get_pretty_stdout();
    timestamp = datetime.now().strftime('%H:%M:%S');
    emoji_map = {'changed': '⚡', 'created': '✨', 'deleted': '🗑️'};
    color_map = {'changed': 'yellow', 'created': 'green', 'deleted': 'red'};
    emoji = emoji_map.get(action, '📝') if self.use_emoji else action.upper();
    color = color_map.get(action, 'cyan');
    pc.print(
        f"[dim][{timestamp}][/] [{color}]{emoji} {action.capitalize()}:[/] {filepath}"
    );
}

impl JacConsole.print_watching(pattern: str, count: int) -> None {
    pc = _get_pretty_stdout();
    watch_emoji = '👀 ' if self.use_emoji else '';
    pc.print(f"[bold cyan]{watch_emoji}Watching for changes...[/]");
    pc.print(
        f"   [dim]Monitoring:[/] [bright_white]{pattern}[/] [dim]({count} files)[/]"
    );
}
