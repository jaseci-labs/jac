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
        width: Optional[int] = None,
        force_terminal: Optional[bool] = None,
        no_color: bool = False
    ) -> object {
        (self._file, self._width, self._force_terminal) = (
            (file or sys.stdout),
            width,
            force_terminal
        );
        self._no_color = no_color or bool(os.environ.get("NO_COLOR"));
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
        try {
            return self._file.isatty();
        } except Exception as e {
            return False;
        }
    }

    def print(
        self: Console,
        *objects: Any,
        sep: str = " ",
        end: str = "\n",
        style: str = "",
        markup: bool = True
    ) -> None {
        parts = [];
        for `obj in objects {
            text = str(`obj);
            if (self.is_terminal and not self._no_color) {
                text = render_markup(text, style)
                    if markup
                    else Style(style).render(text) if style else text;
            }
            parts.append(text);
        }
        self._file.write((sep.join(parts) + end));
        if self.is_terminal {
            self._file.flush();
        }
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

glob __all__ = ["Console", "Style", "print", "render_markup", "get_console"];
