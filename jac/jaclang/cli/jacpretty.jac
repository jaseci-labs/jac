"""jacpretty - Lightweight colored terminal output for Jac CLI."""
import os, re, sys;
import from enum { IntEnum }
import from threading { Thread, Event }
import from time { sleep }

# ANSI color codes as IntEnum
enum Color ( IntEnum ) {
    BLACK = 0,
    RED = 1,
    GREEN = 2,
    YELLOW = 3,
    BLUE = 4,
    MAGENTA = 5,
    CYAN = 6,
    WHITE = 7,
    BRIGHT_BLACK = 8,
    BRIGHT_RED = 9,
    BRIGHT_GREEN = 10,
    BRIGHT_YELLOW = 11,
    BRIGHT_BLUE = 12,
    BRIGHT_MAGENTA = 13,
    BRIGHT_CYAN = 14,
    BRIGHT_WHITE = 15
}

# ANSI style codes as regular enum
enum Style {
    BOLD = "1",
    DIM = "2",
    ITALIC = "3",
    UNDERLINE = "4",
    BLINK = "5",
    REVERSE = "7",
    CONCEAL = "8",
    STRIKE = "9"
}

glob COLORS: Dict[(str, int)] = {
         "black": Color.BLACK.value,
         "red": Color.RED.value,
         "green": Color.GREEN.value,
         "yellow": Color.YELLOW.value,
         "blue": Color.BLUE.value,
         "magenta": Color.MAGENTA.value,
         "cyan": Color.CYAN.value,
         "white": Color.WHITE.value,
         "bright_black": Color.BRIGHT_BLACK.value,
         "bright_red": Color.BRIGHT_RED.value,
         "bright_green": Color.BRIGHT_GREEN.value,
         "bright_yellow": Color.BRIGHT_YELLOW.value,
         "bright_blue": Color.BRIGHT_BLUE.value,
         "bright_magenta": Color.BRIGHT_MAGENTA.value,
         "bright_cyan": Color.BRIGHT_CYAN.value,
         "bright_white": Color.BRIGHT_WHITE.value
     },
     STYLES: Dict[(str, str)] = {
         "bold": Style.BOLD.value,
         "dim": Style.DIM.value,
         "italic": Style.ITALIC.value,
         "underline": Style.UNDERLINE.value,
         "blink": Style.BLINK.value,
         "reverse": Style.REVERSE.value,
         "conceal": Style.CONCEAL.value,
         "strike": Style.STRIKE.value
     },
     STYLE_ALIASES: Dict[(str, str)] = {
         "b": "bold",
         "d": "dim",
         "i": "italic",
         "u": "underline",
         "r": "reverse",
         "s": "strike",
         "c": "conceal"
     },
     _console: Optional[Console] = None,
     RE_MARKUP = re.compile(r"\[(/)?([^\[\]]*)\]"),
     __all__ = [
         "Console",
         "Style",
         "Theme",
         "Panel",
         "Table",
         "print",
         "render_markup",
         "get_console"
     ],
     RE_HIGHLIGHT = re.compile(
         r"(?<![\w\x1b])(\-?[0-9]+\.?[0-9]*(?:e[\-\+]?\d+)?)(?![\w])"
         r"|(\x27[^\x27\\]*(?:\\.[^\x27\\]*)*\x27)"
         r"|(\x22[^\x22\\]*(?:\\.[^\x22\\]*)*\x22)"
         r"|<([-\w.:|]*)([\w\W]*?)>"
     );

def _parse_color(color: str, bg: bool = False) -> Optional[Tuple[(str, ...)]];

def _highlight_text(text: str, base_style: str = "") -> str;

def render_markup(markup: str, base_style: str = "") -> str;

def get_console -> Console;

def print(*objects: Any, **kwargs: Any) -> None;

obj Style {
    has _def: str,
        _codes: Optional[str] = None;

    def init(definition: str = "") -> object {
        (self._def, self._codes) = (definition, None);
    }

    def __repr__ -> object {
        return f"Style({self._def!r})";
    }

    def __bool__ -> object {
        return bool(self._def);
    }

    def __add__(other: "Style") -> "Style" {
        return Style(f"{self._def} {other._def}")
            if (self and other)
            else (self or other);
    }

    @property
    def codes -> str {
        if (self._codes is None) {
            self._codes = self._parse();
        }
        return self._codes;
    }

    def _parse -> str {
        if not self._def {
            return "";
        }
        (codes, words, i) = ([], self._def.lower().split(), 0);
        while (i < len(words)) {
            w = words[i];
            if (
                (w == "on")
                and ((i + 1) < len(words))
                and (bg := _parse_color(words[(i + 1)], True))
            ) {
                codes.extend(bg);
                i += 2;
                continue;
            }
            if ((attr := STYLE_ALIASES.get(w, w)) in STYLES) {
                codes.append(STYLES[attr]);
                i += 1;
                continue;
            }
            if (fg := _parse_color(w)) {
                codes.extend(fg);
            }
            i += 1;
        }
        return ";".join(codes);
    }

    def render(text: str) -> str {
        return f"\x1b[{self.codes}m{text}\x1b[0m" if self.codes else text;
    }

    @classmethod
    def parse(cls: Any, definition: str) -> "Style" {
        return cls(definition);
    }
}

obj Console {
    has _file_arg: Any,
        _stderr: bool,
        _width: Optional[int],
        _force_terminal: Optional[bool],
        _no_color: bool,
        _theme: Optional["Theme"];

    def init(
        *,
        file: Any = None,
        stderr: bool = False,
        width: Optional[int] = None,
        force_terminal: Optional[bool] = None,
        no_color: bool = False,
        theme: Optional["Theme"] = None
    ) -> object {
        (self._file_arg, self._stderr, self._width, self._force_terminal, self._theme) = (
            file,
            stderr,
            width,
            force_terminal,
            theme
        );
        self._no_color = no_color or bool(os.environ.get("NO_COLOR"));
    }

    @property
    def file -> Any {
        """Return the output file, dynamically resolving sys.stdout/stderr each call
        (like rich does) so test redirects and context managers are always respected."""
        f = self._file_arg or (sys.stderr if self._stderr else sys.stdout);
        return getattr(f, 'rich_proxied_file', f);
    }

    @property
    def width -> int {
        if (self._width is not None) {
            return self._width;
        }
        try {
            return os.get_terminal_size().columns;
        } except (OSError, ValueError) {
            return 80;
        }
    }

    @property
    def is_terminal -> bool {
        if (self._force_terminal is not None) {
            return self._force_terminal;
        }

        force_color = os.environ.get('FORCE_COLOR');
        if force_color is not None {
            return force_color != '';
        }
        try {
            isatty = getattr(self.file, 'isatty', None);
            return False if (isatty is None) else isatty();
        } except ValueError {
            # I/O operation on closed file (e.g. end of pytest run)
            return False;
        }
    }

    """Resolve a style name through the theme if available."""
    def _resolve_style(style: str) -> str {
        if self._theme and style {
            return self._theme.get(style, style);
        }
        return style;
    }

    def print(
        *objects: Any,
        sep: str = " ",
        end: str = "\n",
        style: str = "",
        markup: bool = True,
        highlight: bool = True
    ) -> None {
        parts = [];
        resolved_style = self._resolve_style(style);
        for `obj in objects {
            text = str(`obj);
            if (self.is_terminal and not self._no_color) {
                if markup {
                    text = self._render_markup_with_theme(
                        text, resolved_style, highlight
                    );
                } else {
                    # No markup tags: apply highlight then wrap in base style
                    text = _highlight_text(text, resolved_style)
                        if highlight
                        else (
                            Style(resolved_style).render(
                                text
                            )
                                if resolved_style
                                else text
                        );
                }
            }
            parts.append(text);
        }
        self.file.write((sep.join(parts) + end));
        if self.is_terminal {
            self.file.flush();
        }
    }

    def _render_markup_with_theme(
        markup: str, base_style: str = "", highlight: bool = False
    ) -> str {
        """Render markup with theme-aware style resolution and optional auto-highlighting."""
        markup = markup.replace("\\[", "\x00").replace("\\]", "\x01");
        (result, stack, pos) = ([], [base_style] if base_style else [], 0);
        for m in RE_MARKUP.finditer(markup) {
            if (m.start() > pos) {
                txt = markup[pos:m.start()].replace("\x00", "[").replace("\x01", "]");
                combined_style = " ".join(self._resolve_style(s) for s in stack);
                result.append(
                    _highlight_text(txt, combined_style)
                        if highlight
                        else (Style(combined_style).render(txt) if stack else txt)
                );
            }
            if (m.group(1) and stack) {
                stack.pop();
            } elif m.group(2).strip() {
                stack.append(m.group(2).strip());
            }
            pos = m.end();
        }
        if (pos < len(markup)) {
            txt = markup[pos:].replace("\x00", "[").replace("\x01", "]");
            combined_style = " ".join(self._resolve_style(s) for s in stack);
            result.append(
                _highlight_text(txt, combined_style)
                    if highlight
                    else (Style(combined_style).render(txt) if stack else txt)
            );
        }
        return "".join(result);
    }

    """Return a status context manager with spinner animation."""
    def status(status: str, *, spinner: str = "dots") -> object {
        return _StatusContext(self, status, spinner);
    }

    def rule(title: str = "", char: str = "─", style: str = "dim") -> None {
        w = self.width;
        line = (char * ((w - len(title) - 2) // 2)) + f" {title} " + (
            char * ((w - len(title) - 1) // 2)
        )
            if title
            else (char * w);
        self.print(f"[{style}]{line}[/]" if style else line);
    }

    def log(*objects: Any, **kwargs: Any) -> None {
        import from datetime { datetime }
        self.print(
            f"[dim][{datetime.now().strftime('%H:%M:%S')}][/]", *objects, **kwargs
        );
    }
}

obj Theme {
    has styles: Dict[(str, str)];

    def init(styles: Dict[(str, str)] = {}) -> object {
        self.styles = styles;
    }

    def get(name: str, default: str = "") -> str {
        """Get a style by name from the theme."""
        return self.styles.get(name, default);
    }
}

obj Panel {
    """Panel class for drawing bordered boxes around content."""
    has content: str,
        title: str,
        border_style: str,
        padding: Tuple[(int, int)];

    def init(
        content: str,
        *,
        title: str = "",
        border_style: str = "",
        padding: Tuple[(int, int)] = (0, 1)
    ) -> object {
        (self.content, self.title, self.border_style, self.padding) = (
            content,
            title,
            border_style,
            padding
        );
    }

    def __repr__ -> str {
        return f"Panel({self.content!r}, title={self.title!r})";
    }

    """Render the panel to a string."""
    def render(width: int) -> str {
        (pad_v, pad_h) = self.padding;
        lines = [];
        border_start = f"[{self.border_style}]" if self.border_style else "";
        border_end = "[/]" if self.border_style else "";
        title_text = f" {self.title} " if self.title else "";
        title_len = len(self.title) + 2 if self.title else 0;
        top_line = "╭" + title_text + ("─" * (width - 2 - title_len)) + "╮";
        lines.append(f"{border_start}{top_line}{border_end}");
        for _ in range(pad_v) {
            lines.append(
                f"{border_start}│{border_end}{' ' * (width - 2)}{border_start}│{border_end}"
            );
        }
        for line in self.content.split("\n") {
            padded_line = (" " * pad_h) + line + (" " * pad_h);
            pad_right = width - 2 - len(line) - (2 * pad_h);
            lines.append(
                f"{border_start}│{border_end}{padded_line}{' ' * pad_right}{border_start}│{border_end}"
            );
        }
        for _ in range(pad_v) {
            lines.append(
                f"{border_start}│{border_end}{' ' * (width - 2)}{border_start}│{border_end}"
            );
        }
        lines.append(f"{border_start}╰{'─' * (width - 2)}╯{border_end}");
        return "\n".join(lines);
    }
}

obj Table {
    """Table class for creating formatted tables."""
    has title: Optional[str],
        show_header: bool,
        header_style: str,
        columns: list,
        rows: list;

    def init(
        *,
        title: Optional[str] = None,
        show_header: bool = True,
        header_style: str = "bold"
    ) -> object {
        (self.title, self.show_header, self.header_style) = (
            title,
            show_header,
            header_style
        );
        (self.columns, self.rows) = ([], []);
    }

    """Add a column to the table."""
    def add_column(header: str, style: str = "") -> None {
        self.columns.append({"header": header, "style": style});
    }

    """Add a row to the table."""
    def add_row(*cells: str) -> None {
        self.rows.append(list(cells));
    }

    """Render the table to a string."""
    def render(width: int) -> str {
        if not self.columns {
            return "";
        }
        col_count = len(self.columns);
        if col_count == 0 {
            return "";
        }
        col_width = (width - col_count - 1) // col_count;
        lines = [];
        if self.title {
            lines.append(f"[bold]{self.title}[/]");
        }
        if self.show_header {
            header_cells = [];
            for col in self.columns {
                h = col["header"].ljust(col_width);
                header_cells.append(f"[{self.header_style}]{h}[/]");
            }
            lines.append("│".join(header_cells));
            lines.append("─" * width);
        }
        for row in self.rows {
            row_cells = [];
            for (i, cell) in enumerate(row) {
                if (i < col_count) {
                    style = self.columns[i].get("style", "");
                    c = str(cell).ljust(col_width);
                    row_cells.append(f"[{style}]{c}[/]" if style else c);
                }
            }
            lines.append("│".join(row_cells));
        }
        return "\n".join(lines);
    }
}

obj _StatusContext {
    """Context manager for status spinner."""
    has _thread: Thread | None,
        console: Console,
        status: str,
        spinner: str,
        _stop_event: Event;

    def init(console: Console, status: str, spinner: str = "dots") -> object {
        (self.console, self.status, self.spinner, self._stop_event) = (
            console,
            status,
            spinner,
            Event()
        );
        self._thread = None;
    }

    def __enter__ -> object {
        if self.console.is_terminal {
            self._thread = Thread(target=self._spin);
            self._thread.start();
        } else {
            self.console.print(self.status);
        }
        return self;
    }

    def __exit__(*args: Any) -> None {
        if self._thread {
            self._stop_event.set();
            self._thread.join();
            self.console.file.write("\r" + (" " * 80) + "\r");
            self.console.file.flush();
        }
    }

    """Animation loop for spinner."""
    def _spin -> None {
        frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
            if (self.spinner == "dots")
            else ["|", "/", "-", "\\"];
        idx = 0;
        while not self._stop_event.is_set() {
            frame = frames[(idx % len(frames))];
            msg = render_markup(self.status);
            self.console.file.write(f"\r{frame} {msg}");
            self.console.file.flush();
            sleep(0.1);
            idx += 1;
        }
    }
}
