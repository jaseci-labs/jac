"""jacpretty - Lightweight colored terminal output for Jac CLI."""
import os, re, sys;
import from enum { IntEnum }
import from random { randint }

# MarkupError exception (Rich-compatible)
obj MarkupError(Exception) {
    """Markup was badly formatted."""
    has message: str = "Markup error";
}

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
     RE_MARKUP = re.compile(r"\[(/[a-z]*|#[0-9a-fA-F]{6}|[a-z@][^\[\]]*)\]"),
     __all__ = [
         "Console",
         "Style",
         "print",
         "render_markup",
         "get_console",
         "MarkupError"
     ];

def _parse_color(color: str, bg: bool = False) -> Optional[Tuple[(str, ...)]];

def render_markup(markup: str, base_style: str = "", strict: bool = False) -> str;

def get_console -> Console;

def print(*objects: Any, **kwargs: Any) -> None;

obj Style {
    has _def: str,
        _codes: Optional[str] = None,
        _link: Optional[str] = None,
        _link_id: str = "";

    def init(definition: str = "", link: Optional[str] = None) -> object {
        self._def = definition;
        self._codes = None;
        self._link = link;
        self._link_id = str(randint(0, 999999)) if link else "";
    }

    def __repr__ -> object {
        return f"Style({self._def!r})";
    }

    def __bool__ -> object {
        return bool(self._def or self._link);
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
        codes: list = [];
        words = self._def.split();
        i = 0;
        while (i < len(words)) {
            w = words[i].lower();
            # Handle "link URL" syntax (Rich-compatible)
            if ((w == "link") and ((i + 1) < len(words))) {
                self._link = words[(i + 1)];  # Keep original case for URL
                self._link_id = str(randint(0, 999999));
                i += 2;
                continue;
            }
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
        rendered = f"\x1b[{self.codes}m{text}\x1b[0m" if self.codes else text;
        # Add OSC 8 hyperlink if link is set (Rich-compatible)
        if (self._link) {
            rendered = f"\x1b]8;id={self._link_id};{self._link}\x1b\\{rendered}\x1b]8;;\x1b\\";
        }
        return rendered;
    }

    @classmethod
    def parse(cls: Any, definition: str) -> "Style" {
        return cls(definition);
    }
}

obj Console {
    has _file: Any,
        _width: Optional[int],
        _force_terminal: Optional[bool],
        _no_color: bool;

    def init(
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
        try {
            return self._file.isatty();
        } except Exception as e {
            return False;
        }
    }

    def print(
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
