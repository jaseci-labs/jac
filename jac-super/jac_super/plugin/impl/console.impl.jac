"""jacpretty-enhanced console implementation for jac-super.

This module provides a jacpretty-based implementation of JacConsole that
inherits from the base console and overrides methods to use jacpretty
for elegant terminal output.
"""
import os;
import sys;
import from contextlib { contextmanager }
import from jaclang.cli.jacpretty { Console, Panel, Table, Theme }
import from jaclang.cli.console { JacConsole as BaseJacConsole }

"""jacpretty-enhanced console that extends base JacConsole."""
class JacSuperConsole(BaseJacConsole) {
    with entry {
        JAC_THEME = Theme(
            {
                'success': 'bold green',
                'error': 'bold red',
                'warning': 'bold yellow',
                'info': 'bold cyan',
                'url': 'underline green',
                'muted': 'dim white',
                'highlight': 'bold cyan',
                'time': 'yellow'
            }
        );
    }

    """Initialize the jacpretty console with Jac theme."""
    def init(self: JacSuperConsole) -> None {
        # Call parent init first
        BaseJacConsole.init(self);
        # Initialize jacpretty consoles
        self._console = Console(theme=self.JAC_THEME);
        self._console_stderr = Console(theme=self.JAC_THEME, stderr=True);
    }

    """Override print to use jacpretty console."""
    def print(self: JacSuperConsole, *args: Any, **kwargs: Any) -> None {
        # Extract style if provided, otherwise use default
        style = kwargs.pop('style', None);
        file = kwargs.pop('file', None);
        # Use appropriate console based on file
        console = self._console_stderr if (file == sys.stderr) else self._console;
        if style {
            console.print(*args, style=style, **kwargs);
        } else {
            console.print(*args, **kwargs);
        }
    }

    """Override status to use jacpretty console status."""
    def status(self: JacSuperConsole, *args: Any, **kwargs: Any) -> object {
        return self._console.status(*args, **kwargs);
    }

    """Override success to use jacpretty styling."""
    def success(self: JacSuperConsole, message: str, emoji: bool = True) -> None {
        prefix = '✔' if (emoji and self.use_emoji) else '[SUCCESS]';
        self._console.print(f"{prefix} {message}", style='success');
    }

    """Override error to use jacpretty styling with stderr."""
    def error(
        self: JacSuperConsole,
        message: str,
        hint: (str | None) = None,
        emoji: bool = True
    ) -> None {
        prefix = '✖' if (emoji and self.use_emoji) else '[ERROR]';
        self._console_stderr.print(f"{prefix} Error: {message}", style='error');
        if hint {
            hint_prefix = '💡' if self.use_emoji else 'HINT:';
            self._console_stderr.print(f"{hint_prefix} {hint}", style='info');
        }
    }

    """Override warning to use jacpretty styling."""
    def warning(self: JacSuperConsole, message: str, emoji: bool = True) -> None {
        prefix = '⚠' if (emoji and self.use_emoji) else '[WARNING]';
        self._console.print(f"{prefix} {message}", style='warning');
    }

    """Override info to use jacpretty styling."""
    def info(self: JacSuperConsole, message: str, emoji: bool = True) -> None {
        prefix = 'ℹ' if (emoji and self.use_emoji) else '[INFO]';
        self._console.print(f"{prefix} {message}", style='info');
    }

    """Override print_header to use jacpretty styling."""
    def print_header(
        self: JacSuperConsole, title: str, version: (str | None) = None
    ) -> None {
        if version {
            self._console.print(f"{title} v{version}", style='bold cyan');
        } else {
            self._console.print(f"{title}", style='bold cyan');
        }
    }

    """Override print_urls to use jacpretty URL styling."""
    def print_urls(self: JacSuperConsole, urls: Any, symbol: str = '➜') -> None {
        items = urls.items() if isinstance(urls, dict) else urls;
        for (label, url) in items {
            padded_label = f"{label}:".ljust(10);
            self._console.print(f"  {symbol}  {padded_label} [url]{url}[/url]");
        }
    }

    """Override print_next_steps to use jacpretty Panel."""
    def print_next_steps(
        self: JacSuperConsole, steps: list[str], title: str = 'Next Steps'
    ) -> None {
        content = '\n'.join(f"  {i}  {step}" for (i, step) in enumerate(steps, 1));
        panel = Panel(content, title=title, border_style='cyan', padding=(0, 1));
        self._console.print(panel.render(self._console.width), markup=True);
    }

    """Override print_list to use jacpretty styling."""
    def print_list(
        self: JacSuperConsole,
        items: list[str],
        style: str = 'success',
        symbol: str = '✔'
    ) -> None {
        for item in items {
            self._console.print(f"  {symbol} {item}", style=style);
        }
    }

    """Override print_table to use jacpretty Table."""
    def print_table(
        self: JacSuperConsole,
        headers: list[str],
        rows: list[list[str]],
        title: (str | None) = None
    ) -> None {
        table = Table(title=title, show_header=True, header_style='bold cyan');
        for header in headers {
            table.add_column(header);
        }
        for row in rows {
            table.add_row(*row);
        }
        self._console.print(table.render(self._console.width), markup=True);
    }

    """Override spinner to use jacpretty status."""
    @contextmanager
    def spinner(self: JacSuperConsole, text: str) -> object {
        with self._console.status(f"[cyan]{text}[/cyan]", spinner='dots') as status {
            yield status;
        }
    }

    """Override print_elapsed_time to use jacpretty styling."""
    def print_elapsed_time(self: JacSuperConsole, seconds: float) -> None {
        if (seconds < 1) {
            ms = seconds * 1000;
            self._console.print(f"  Done in {ms:.0f}ms", style='muted');
        } else {
            self._console.print(f"  Done in {seconds:.1f}s", style='muted');
        }
    }

    """Override print_file_change to use jacpretty styling."""
    def print_file_change(
        self: JacSuperConsole, filepath: str, action: str = 'changed'
    ) -> None {
        import from datetime { datetime }
        timestamp = datetime.now().strftime('%H:%M:%S');
        emoji_map = {'changed': '⚡', 'created': '✨', 'deleted': '🗑️'};
        emoji = emoji_map.get(action, '📝');
        self._console.print(
            f"[{timestamp}] {emoji} {action.capitalize()}: {filepath}", style='info'
        );
    }

    """Override print_watching to use jacpretty styling."""
    def print_watching(self: JacSuperConsole, pattern: str, count: int) -> None {
        watch_emoji = '👀' if self.use_emoji else '[WATCHING]';
        self._console.print(f"{watch_emoji} Watching for changes...", style='info');
        self._console.print(f"   Monitoring: {pattern} ({count} files)", style='muted');
    }
}
