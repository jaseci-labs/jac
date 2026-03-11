"""Implementation of console utilities for terminal output.

Production-grade console with raw ANSI codes. User data is never processed
or modified - only internal CLI chrome (prefixes, symbols) gets styled.
"""
import os;
import sys;
import from contextlib { contextmanager }
import from typing { Any }

# ===============================================================================
# ANSI Color Codes - Raw and Simple
# ===============================================================================
glob RESET: str = "\033[0m",
     BOLD: str = "\033[1m",
     DIM: str = "\033[2m",
     UNDERLINE: str = "\033[4m",
     RED: str = "\033[31m",
     GREEN: str = "\033[32m",
     YELLOW: str = "\033[33m",
     BLUE: str = "\033[34m",
     MAGENTA: str = "\033[35m",
     CYAN: str = "\033[36m",
     WHITE: str = "\033[37m",
     BRIGHT_WHITE: str = "\033[97m",
     BRIGHT_BLUE: str = "\033[94m";

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

"""Check if color should be used based on environment.

Checks: NO_COLOR env, TERM=dumb, and isatty() for CI/pipe/server safety.
"""
impl JacConsole._should_use_color -> bool {
    # Respect NO_COLOR standard (https://no-color.org/)
    if os.environ.get('NO_COLOR') {
        return False;
    }
    # Dumb terminals don't support ANSI
    if os.environ.get('TERM') == 'dumb' {
        return False;
    }
    # Not a TTY = CI, pipe, server, captured output - no colors
    try {
        if not sys.stdout.isatty() {
            return False;
        }
    } except Exception {
        return False;
    }
    return True;
}

"""Print to stdout. User data passes through unchanged - no processing."""
impl JacConsole.print(*args: Any, **kwargs: Any) -> None {
    # Filter out Rich-specific kwargs for compatibility
    kwargs.pop('markup', None);
    kwargs.pop('highlight', None);
    kwargs.pop('style', None);
    # Plain print - user data is never modified
    print(*args, **kwargs);
    # Flush for piped/subprocess output
    sys.stdout.flush();
}

"""Context manager for status during long operations."""
impl JacConsole.status(*args: Any, **kwargs: Any) -> object {
    if args {
        msg = args[0] if isinstance(args[0], str) else str(args[0]);
        if self.use_color {
            print(f"{DIM}{msg}{RESET}");
        } else {
            print(msg);
        }
    }
    @contextmanager
    def _noop_status -> object {
        yield None;
    }
    return _noop_status();
}

"""Print a success message with green checkmark."""
impl JacConsole.success(message: str, emoji: bool = True) -> None {
    prefix = '✔' if emoji and self.use_emoji else '[OK]';
    if self.use_color {
        print(f"{GREEN}{prefix}{RESET} {message}");
    } else {
        print(f"{prefix} {message}");
    }
}

"""Print an error message with optional hint."""
impl JacConsole.error(
    message: str, hint: str | None = None, emoji: bool = True
) -> None {
    prefix = '✖' if emoji and self.use_emoji else '[ERROR]';
    if self.use_color {
        print(f"{RED}{prefix} Error:{RESET} {message}", file=sys.stderr);
    } else {
        print(f"{prefix} Error: {message}", file=sys.stderr);
    }
    if hint {
        hint_prefix = '💡' if self.use_emoji else 'HINT:';
        if self.use_color {
            print(f"{DIM}{hint_prefix} {hint}{RESET}", file=sys.stderr);
        } else {
            print(f"{hint_prefix} {hint}", file=sys.stderr);
        }
    }
}

"""Print a warning message in yellow."""
impl JacConsole.warning(message: str, emoji: bool = True) -> None {
    prefix = '⚠' if emoji and self.use_emoji else '[WARNING]';
    if self.use_color {
        print(f"{YELLOW}{prefix}{RESET} {message}");
    } else {
        print(f"{prefix} {message}");
    }
}

"""Print an info message in cyan."""
impl JacConsole.info(message: str, emoji: bool = True) -> None {
    prefix = 'ℹ' if emoji and self.use_emoji else '[INFO]';
    if self.use_color {
        print(f"{CYAN}{prefix}{RESET} {message}");
    } else {
        print(f"{prefix} {message}");
    }
}

"""Print a header with optional version."""
impl JacConsole.print_header(title: str, version: str | None = None) -> None {
    try {
        width = os.get_terminal_size().columns;
    } except (OSError, ValueError) {
        width = 80;
    }
    rule = '─' * width;
    if self.use_color {
        print(f"{DIM}{rule}{RESET}");
        if version {
            print(f"{BRIGHT_WHITE}{title}{RESET}  {DIM}v{version}{RESET}");
        } else {
            print(f"{BRIGHT_WHITE}{title}{RESET}");
        }
        print(f"{DIM}{rule}{RESET}");
    } else {
        print(rule);
        if version {
            print(f"{title} v{version}");
        } else {
            print(title);
        }
        print(rule);
    }
}

"""Print a list of labeled URLs."""
impl JacConsole.print_urls(urls: Any, symbol: str = '➜') -> None {
    items = urls.items() if isinstance(urls, dict) else urls;
    for (label, url) in items {
        padded_label = f"{label}:".ljust(10);
        if self.use_color {
            print(
                f"  {CYAN}{symbol}{RESET}  {DIM}{padded_label}{RESET} {BRIGHT_BLUE}{UNDERLINE}{url}{RESET}"
            );
        } else {
            print(f"  {symbol}  {padded_label} {url}");
        }
    }
}

"""Print a bordered box with next steps."""
impl JacConsole.print_next_steps(steps: list[str], title: str = 'Next Steps') -> None {
    if self.use_color {
        print(f"\n{BRIGHT_WHITE}{title}:{RESET}");
    } else {
        print(f"\n{title}:");
    }
    for (i, step) in enumerate(steps, 1) {
        if self.use_color {
            print(f"  {CYAN}{i}.{RESET} {step}");
        } else {
            print(f"  {i}. {step}");
        }
    }
    print();
}

"""Print a list of items with colored symbols."""
impl JacConsole.print_list(
    items: list[str], style: str = 'success', symbol: str = '✔'
) -> None {
    color_map = {'success': GREEN, 'warning': YELLOW, 'error': RED, 'info': CYAN};
    color = color_map.get(style, GREEN);
    for item in items {
        if self.use_color {
            print(f"  {color}{symbol}{RESET} {item}");
        } else {
            print(f"  {symbol} {item}");
        }
    }
}

"""Print a formatted table with colored headers."""
impl JacConsole.print_table(
    headers: list[str], rows: list[list[str]], title: str | None = None
) -> None {
    if title {
        if self.use_color {
            print(f"\n{BRIGHT_WHITE}{title}:{RESET}");
        } else {
            print(f"\n{title}:");
        }
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
    if self.use_color {
        header_parts = [
            f"{BRIGHT_WHITE}{h.ljust(w)}{RESET}" for (h, w) in zip(headers, col_widths)
        ];
        print(f" {DIM}|{RESET} ".join(header_parts));
        separator = '-' * (sum(col_widths) + (len(col_widths) - 1) * 3);
        print(f"{DIM}{separator}{RESET}");
    } else {
        header_row = ' | '.join(h.ljust(w) for (h, w) in zip(headers, col_widths));
        print(header_row);
        print('-' * len(header_row));
    }
    # Print data rows - user data unchanged
    for row in rows {
        row_parts = [
            str(cell).ljust(col_widths[i]) if i < len(col_widths) else str(cell)
            for (i, cell) in enumerate(row)
        ];
        if self.use_color {
            print(f" {DIM}|{RESET} ".join(row_parts));
        } else {
            print(' | '.join(row_parts));
        }
    }
    print();
}

"""Context manager for spinner during long operations."""
@contextmanager
impl JacConsole.spinner(text: str) -> object {
    if self.use_color {
        print(f"{DIM}{text}...{RESET}", end='', flush=True);
    } else {
        print(f"{text}...", end='', flush=True);
    }
    try {
        yield None;
    } finally {
        if self.use_color {
            print(f" {GREEN}done{RESET}");
        } else {
            print(" done");
        }
    }
}

"""Print elapsed time in a human-friendly format."""
impl JacConsole.print_elapsed_time(seconds: float) -> None {
    if seconds < 1 {
        ms = seconds * 1000;
        if self.use_color {
            print(f"  {DIM}Done in{RESET} {GREEN}{ms:.0f}ms{RESET}");
        } else {
            print(f"  Done in {ms:.0f}ms");
        }
    } else {
        if self.use_color {
            print(f"  {DIM}Done in{RESET} {GREEN}{seconds:.1f}s{RESET}");
        } else {
            print(f"  Done in {seconds:.1f}s");
        }
    }
}

"""Print file change notification with timestamp."""
impl JacConsole.print_file_change(filepath: str, action: str = 'changed') -> None {
    import from datetime { datetime }
    timestamp = datetime.now().strftime('%H:%M:%S');
    emoji_map = {'changed': '⚡', 'created': '✨', 'deleted': '🗑️'};
    color_map = {'changed': YELLOW, 'created': GREEN, 'deleted': RED};
    emoji = emoji_map.get(action, '📝') if self.use_emoji else action.upper();
    color = color_map.get(action, CYAN);
    if self.use_color {
        print(
            f"{DIM}[{timestamp}]{RESET} {color}{emoji} {action.capitalize()}:{RESET} {filepath}"
        );
    } else {
        print(f"[{timestamp}] {emoji} {action.capitalize()}: {filepath}");
    }
}

"""Print file watching status."""
impl JacConsole.print_watching(pattern: str, count: int) -> None {
    watch_emoji = '👀 ' if self.use_emoji else '';
    if self.use_color {
        print(f"{CYAN}{watch_emoji}Watching for changes...{RESET}");
        print(
            f"   {DIM}Monitoring:{RESET} {BRIGHT_WHITE}{pattern}{RESET} {DIM}({count} files){RESET}"
        );
    } else {
        watch_prefix = watch_emoji or '[WATCHING] ';
        print(f"{watch_prefix}Watching for changes...");
        print(f"   Monitoring: {pattern} ({count} files)");
    }
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
