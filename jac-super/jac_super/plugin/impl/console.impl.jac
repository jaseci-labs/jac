"""Rich-enhanced console implementation for jac-super.

This module provides a Rich-based implementation of JacConsole that
inherits from the base console and overrides methods to use Rich
for elegant terminal output.
"""
import os;
import sys;
import from contextlib { contextmanager }
import from rich.console { Console as RichConsole }
import from rich.panel { Panel }
import from rich.table { Table }
import from rich.theme { Theme }
import from jaclang.cli.console { JacConsole as BaseJacConsole }

"""Rich-enhanced console that extends base JacConsole."""
obj JacSuperConsole(BaseJacConsole) {
    with entry {
        JAC_THEME = Theme(
            {
                'success': 'green',
                'error': 'red',
                'warning': 'yellow',
                'info': 'cyan',
                'url': 'underline green',
                'muted': 'dim white',
                'highlight': 'cyan',
                'time': 'yellow'
            }
        );
    }

    has _console: RichConsole by postinit,
        _console_stderr: RichConsole by postinit;

    def postinit {
        self._console = RichConsole(theme=self.JAC_THEME);
        self._console_stderr = RichConsole(theme=self.JAC_THEME, file=sys.stderr);
    }

    """Override print to use Rich console.

    Rich's `Console.print` parses bracket-delimited markup like `[red]...[/red]`
    by default. User-supplied content (file paths, source-line snippets,
    f-string output) routinely contains square brackets that look like
    markup — e.g. a diagnostic snippet for `[root()-->][?:Task]` would have
    the `[root()-->]` interpreted as a malformed tag and stripped, leaving a
    misleading `[?:Task]` underneath the carets. Disable markup parsing by
    default; callers that want Rich markup must opt in explicitly via
    `markup=True`. Auto-highlighting (`highlight`) is left at Rich's default
    so numbers, strings, paths, and keywords still get their accent colors.
    """
    def print(*args: Any, **kwargs: Any) {
        # Extract style if provided, otherwise use default
        style = kwargs.pop('style', None);
        file = kwargs.pop('file', None);
        kwargs.setdefault('markup', False);
        # Use appropriate console based on file
        console = self._console_stderr if (file == sys.stderr) else self._console;
        if style {
            console.print(*args, style=style, **kwargs);
        } else {
            console.print(*args, **kwargs);
        }
    }

    """Override status to use Rich console status."""
    def status(*args: Any, **kwargs: Any) -> object {
        return self._console.status(*args, **kwargs);
    }

    """Override success to use Rich styling."""
    def success(message: str, emoji: bool = True) {
        prefix = '✔' if (emoji and self.use_emoji) else '[SUCCESS]';
        self._console.print(f"{prefix} {message}", style='success', markup=False);
    }

    """Override error to use Rich styling with stderr."""
    def error(message: str, hint: (str | None) = None, emoji: bool = True) {
        prefix = '✖' if (emoji and self.use_emoji) else '[ERROR]';
        self._console_stderr.print(
            f"{prefix} Error: {message}", style='error', markup=False
        );
        if hint {
            hint_prefix = '💡' if self.use_emoji else 'HINT:';
            self._console_stderr.print(
                f"{hint_prefix} {hint}", style='info', markup=False
            );
        }
    }

    """Override warning to use Rich styling."""
    def warning(message: str, emoji: bool = True) {
        prefix = '⚠' if (emoji and self.use_emoji) else '[WARNING]';
        self._console_stderr.print(
            f"{prefix} {message}", style='warning', markup=False
        );
    }

    """Override info to use Rich styling."""
    def info(message: str, emoji: bool = True) {
        prefix = 'ℹ' if (emoji and self.use_emoji) else '[INFO]';
        self._console.print(f"{prefix} {message}", style='info', markup=False);
    }

    """Override print_header to use Rich styling."""
    def print_header(title: str, version: (str | None) = None) {
        if version {
            self._console.print(f"{title} v{version}", style='cyan');
        } else {
            self._console.print(f"{title}", style='cyan');
        }
    }

    """Override print_urls to use Rich URL styling."""
    def print_urls(urls: Any, symbol: str = '➜') {
        items = urls.items() if isinstance(urls, dict) else urls;
        for (label, url) in items {
            padded_label = f"{label}:".ljust(10);
            self._console.print(f"  {symbol}  {padded_label} [url]{url}[/url]");
        }
    }

    """Override print_next_steps to use Rich Panel."""
    def print_next_steps(steps: list[str], title: str = 'Next Steps') {
        content = '\n'.join(f"  {i}  {step}" for (i, step) in enumerate(steps, 1));
        panel = Panel(content, title=title, border_style='cyan', padding=(0, 1));
        self._console.print(panel);
    }

    """Override print_list to use Rich styling."""
    def print_list(items: list[str], style: str = 'success', symbol: str = '✔') {
        for item in items {
            self._console.print(f"  {symbol} {item}", style=style);
        }
    }

    """Override print_table to use Rich Table."""
    def print_table(
        headers: list[str], rows: list[list[str]], title: (str | None) = None
    ) {
        table = Table(title=title, show_header=True, header_style='cyan');
        for header in headers {
            table.add_column(header);
        }
        for row in rows {
            table.add_row(*row);
        }
        self._console.print(table);
    }

    """Override spinner to use Rich status."""
    @contextmanager
    def spinner(text: str) -> object {
        with self._console.status(f"[cyan]{text}[/cyan]", spinner='dots') as status {
            yield status;
        }
    }

    """Override print_elapsed_time to use Rich styling."""
    def print_elapsed_time(seconds: float) {
        if (seconds < 1) {
            ms = seconds * 1000;
            self._console.print(f"  Done in {ms:.0f}ms", style='muted');
        } else {
            self._console.print(f"  Done in {seconds:.1f}s", style='muted');
        }
    }

    """Override print_file_change to use Rich styling."""
    def print_file_change(filepath: str, action: str = 'changed') {
        import from datetime { datetime }
        timestamp = datetime.now().strftime('%H:%M:%S');
        emoji_map = {'changed': '⚡', 'created': '✨', 'deleted': '🗑️'};
        emoji = emoji_map.get(action, '📝');
        self._console.print(
            f"[{timestamp}] {emoji} {action.capitalize()}: {filepath}", style='info'
        );
    }

    """Override print_watching to use Rich styling."""
    def print_watching(pattern: str, count: int) {
        watch_emoji = '👀' if self.use_emoji else '[WATCHING]';
        self._console.print(f"{watch_emoji} Watching for changes...", style='info');
        self._console.print(f"   Monitoring: {pattern} ({count} files)", style='muted');
    }
}
