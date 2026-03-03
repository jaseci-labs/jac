"""jacpretty - Lightweight colored terminal output for Jac CLI."""
import os, re, sys;
import from typing { Dict, Optional, Tuple }

glob COLORS: Dict[(str, int)] = {
         "black": 0,
         "red": 1,
         "green": 2,
         "yellow": 3,
         "blue": 4,
         "magenta": 5,
         "cyan": 6,
         "white": 7,
         "bright_black": 8,
         "bright_red": 9,
         "bright_green": 10,
         "bright_yellow": 11,
         "bright_blue": 12,
         "bright_magenta": 13,
         "bright_cyan": 14,
         "bright_white": 15
     },
     STYLES: Dict[(str, str)] = {
         "bold": "1",
         "dim": "2",
         "italic": "3",
         "underline": "4",
         "blink": "5",
         "reverse": "7",
         "conceal": "8",
         "strike": "9"
     },
     STYLE_ALIASES: Dict[(str, str)] = {
         "b": "bold",
         "d": "dim",
         "i": "italic",
         "u": "underline",
         "r": "reverse",
         "s": "strike",
         "c": "conceal"
     };

def _parse_color(color: str, bg: bool = False) -> Optional[Tuple[(str, ...)]] {
    color = color.lower().strip();
    base = 40 if bg else 30;
    mode = "48" if bg else "38";
    if (color in COLORS) {
        n = COLORS[color];
        return (str((base + n)) if (n < 8) else str(base + 52 + n), );
    }
    if (color.startswith("#") and (len(color) == 7)) {
        return (
            mode,
            "2",
            str(int(color[1:3], 16)),
            str(int(color[3:5], 16)),
            str(int(color[5:7], 16))
        );
    }
    if (color.startswith("rgb(") and color.endswith(")")) {
        p = color[4:-1].split(",");
        return (mode, "2", p[0].strip(), p[1].strip(), p[2].strip())
            if (len(p) == 3)
            else None;
    }
    if (color.startswith("color(") and color.endswith(")")) {
        return (mode, "5", color[6:-1]);
    }
    return None;
}

class Style {
    with entry {
        __slots__ = ["_def", "_codes"];
    }

    def init(self: Style, definition: str = "") -> object {
        (self._def, self._codes) = (definition, None);
    }

    def __repr__(self: Style) -> object {
        return f"Style({self._def!r})";
    }

    def __bool__(self: Style) -> object {
        return bool(self._def);
    }

    def __add__(self: Style, other: "Style") -> "Style" {
        return Style(f"{self._def} {other._def}")
            if (self and other)
            else (self or other);
    }

    @property
    def codes(self: Style) -> str {
        if (self._codes is None) {
            self._codes = self._parse();
        }
        return self._codes;
    }

    def _parse(self: Style) -> str {
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

    def render(self: Style, text: str) -> str {
        return f"\x1b[{self.codes}m{text}\x1b[0m" if self.codes else text;
    }

    @classmethod
    def parse(cls: Any, definition: str) -> "Style" {
        return cls(definition);
    }
}

glob RE_MARKUP = re.compile(r"\[(/)?([^\[\]]*)\]");

# Regex matching tokens that rich's ReprHighlighter would colour:
# group 1 = number
# group 2 = single-quoted string
# group 3 = double-quoted string
# group 4 = tag_name (the word right after <, e.g. 'class' in <class list>)
# group 5 = tag_contents (rest of <tag_name ... > content)
glob RE_HIGHLIGHT = re.compile(
    r"(?<![\w\x1b])(\-?[0-9]+\.?[0-9]*(?:e[\-\+]?\d+)?)(?![\w])"
    r"|(\x27[^\x27\\]*(?:\\.[^\x27\\]*)*\x27)"
    r"|(\x22[^\x22\\]*(?:\\.[^\x22\\]*)*\x22)"
    r"|<([-\w.:|]*)([\w\W]*?)>"
);

def _highlight_text(text: str, base_style: str = "") -> str {
    """Highlight numbers, quoted strings, and <tag> content like rich's
    ReprHighlighter. Non-matched spans are wrapped in base_style so per-segment
    colouring composes correctly with any outer style."""
    base = Style(base_style) if base_style else None;
    base_code = base._parse() if base else "";
    (parts, pos) = ([], 0);
    for m in RE_HIGHLIGHT.finditer(text) {
        if (m.start() > pos) {
            chunk = text[pos:m.start()];
            parts.append(base.render(chunk) if base else chunk);
        }
        if m.group(1) {
            # Number → bold cyan
            parts.append(Style("bold cyan").render(m.group(1)));
        } elif (m.group(2) or m.group(3)) {
            # Quoted string → bold green
            parts.append(Style("bold green").render(m.group(0)));
        } else {
            # <tag_name contents> pattern
            # '<' stays in base colour
            parts.append(base.render("<") if base else "<");
            # tag_name → bold bright_magenta (the "thin pink" from rich repr.tag_name)
            tag_name = m.group(4);
            if tag_name {
                parts.append(Style("bold bright_magenta").render(tag_name));
            }
            # tag_contents → reset to default terminal white (rich repr.tag_contents = default)
            tag_contents = m.group(5);
            if tag_contents {
                parts.append(f"\x1b[0m{tag_contents}");
                # Re-apply base style so the closing > and any following text stay in base
                if base_code {
                    parts.append(f"\x1b[{base_code}m");
                }
            }
            # '>' stays in base colour
            parts.append(base.render(">") if base else ">");
        }
        pos = m.end();
    }
    if (pos < len(text)) {
        chunk = text[pos:];
        parts.append(base.render(chunk) if base else chunk);
    }
    return "".join(parts);
}


def render_markup(markup: str, base_style: str = "") -> str {
    markup = markup.replace("\\[", "\x00").replace("\\]", "\x01");
    (result, stack, pos) = ([], [base_style] if base_style else [], 0);
    for m in RE_MARKUP.finditer(markup) {
        if (m.start() > pos) {
            txt = markup[pos:m.start()].replace("\x00", "[").replace("\x01", "]");
            result.append(Style(" ".join(stack)).render(txt) if stack else txt);
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
        result.append(Style(" ".join(stack)).render(txt) if stack else txt);
    }
    return "".join(result);
}

class Console {
    def init(
        self: Console,
        *,
        file: Any = None,
        stderr: bool = False,
        width: Optional[int] = None,
        force_terminal: Optional[bool] = None,
        no_color: bool = False,
        theme: Optional["Theme"] = None
    ) -> object {
        # Store the user-supplied file (None = dynamic fallback like rich)
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
    def file(self: Console) -> Any {
        """Return the output file, dynamically resolving sys.stdout/stderr each call
        (like rich does) so test redirects and context managers are always respected."""
        f = self._file_arg or (sys.stderr if self._stderr else sys.stdout);
        return getattr(f, 'rich_proxied_file', f);
    }

    @property
    def width(self: Console) -> int {
        if self._width {
            return self._width;
        }
        try {
            return os.get_terminal_size().columns;
        } except (OSError, ValueError) {
            return 80;
        }
    }

    @property
    def is_terminal(self: Console) -> bool {
        if (self._force_terminal is not None) {
            return self._force_terminal;
        }
        # Honour https://force-color.org/ (same as rich)
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
    def _resolve_style(self: Console, style: str) -> str {
        if self._theme and style {
            return self._theme.get(style, style);
        }
        return style;
    }

    def print(
        self: Console,
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
                    text = self._render_markup_with_theme(text, resolved_style, highlight);
                } else {
                    # No markup tags: apply highlight then wrap in base style
                    text = _highlight_text(text, resolved_style) if highlight else (
                        Style(resolved_style).render(text) if resolved_style else text
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
        self: Console, markup: str, base_style: str = "", highlight: bool = False
    ) -> str {
        """Render markup with theme-aware style resolution and optional auto-highlighting."""
        markup = markup.replace("\\[", "\x00").replace("\\]", "\x01");
        (result, stack, pos) = ([], [base_style] if base_style else [], 0);
        for m in RE_MARKUP.finditer(markup) {
            if (m.start() > pos) {
                txt = markup[pos:m.start()].replace("\x00", "[").replace("\x01", "]");
                combined_style = " ".join(self._resolve_style(s) for s in stack);
                result.append(
                    _highlight_text(txt, combined_style) if highlight
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
                _highlight_text(txt, combined_style) if highlight
                else (Style(combined_style).render(txt) if stack else txt)
            );
        }
        return "".join(result);
    }

    """Return a status context manager with spinner animation."""
    def status(
        self: Console, status: str, *, spinner: str = "dots"
    ) -> object {
        return _StatusContext(self, status, spinner);
    }

    def rule(
        self: Console, title: str = "", char: str = "─", style: str = "dim"
    ) -> None {
        w = self.width;
        line = (char * ((w - len(title) - 2) // 2)) + f" {title} " + (
            char * ((w - len(title) - 1) // 2)
        )
            if title
            else (char * w);
        self.print(f"[{style}]{line}[/]" if style else line);
    }

    def log(self: Console, *objects: Any, **kwargs: Any) -> None {
        import from datetime { datetime }
        self.print(
            f"[dim][{datetime.now().strftime('%H:%M:%S')}][/]", *objects, **kwargs
        );
    }
}

glob _console: Optional[Console] = None;

def get_console -> Console {
    global _console;
    if (_console is None) {
        _console = Console();
    }
    return _console;
}

def print(*objects: Any, **kwargs: Any) -> None {
    get_console().print(*objects, **kwargs);
}

class Theme {
    """Theme class for storing named style mappings."""
    with entry {
        __slots__ = ["styles"];
    }

    def init(self: Theme, styles: Dict[(str, str)] = {}) -> object {
        self.styles = styles;
    }

    def get(self: Theme, name: str, default: str = "") -> str {
        """Get a style by name from the theme."""
        return self.styles.get(name, default);
    }
}

class Panel {
    """Panel class for drawing bordered boxes around content."""

    def init(
        self: Panel,
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

    def __repr__(self: Panel) -> str {
        return f"Panel({self.content!r}, title={self.title!r})";
    }

    """Render the panel to a string."""
    def render(self: Panel, width: int) -> str {
        (pad_v, pad_h) = self.padding;
        inner_width = width - 2 - (2 * pad_h);
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

class Table {
    """Table class for creating formatted tables."""

    def init(
        self: Table,
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
    def add_column(self: Table, header: str, style: str = "") -> None {
        self.columns.append({"header": header, "style": style});
    }

    """Add a row to the table."""
    def add_row(self: Table, *cells: str) -> None {
        self.rows.append(list(cells));
    }

    """Render the table to a string."""
    def render(self: Table, width: int) -> str {
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

import from threading { Thread, Event }
import from time { sleep }

class _StatusContext {
    """Context manager for status spinner."""
    has _thread: Thread | None;

    def init(
        self: _StatusContext,
        console: Console,
        status: str,
        spinner: str = "dots"
    ) -> object {
        (self.console, self.status, self.spinner, self._stop_event) = (
            console,
            status,
            spinner,
            Event()
        );
        self._thread = None;
    }

    def __enter__(self: _StatusContext) -> object {
        if self.console.is_terminal {
            self._thread = Thread(target=self._spin);
            self._thread.start();
        } else {
            self.console.print(self.status);
        }
        return self;
    }

    def __exit__(self: _StatusContext, *args: Any) -> None {
        if self._thread {
            self._stop_event.set();
            self._thread.join();
            self.console.file.write("\r" + (" " * 80) + "\r");
            self.console.file.flush();
        }
    }

    """Animation loop for spinner."""
    def _spin(self: _StatusContext) -> None {
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

glob __all__ = [
    "Console",
    "Style",
    "Theme",
    "Panel",
    "Table",
    "print",
    "render_markup",
    "get_console"
];
