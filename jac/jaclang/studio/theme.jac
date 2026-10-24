import from jaclang.osprey.ui.cells { StyleAttrs, TextSpan }
import from jaclang.osprey.ui.width { display_width, truncate_text }

glob C_BG: int = 234,
     C_PANEL: int = 235,
     C_TITLE: int = 237,
     C_TITLE_FOCUS: int = 24,
     C_SEL: int = 238,
     C_SEL_FOCUS: int = 25,
     C_TEXT: int = 252,
     C_DIM: int = 244,
     C_FAINT: int = 240,
     C_ACCENT: int = 75,
     C_ACCENT2: int = 179,
     C_OK: int = 114,
     C_WARN: int = 221,
     C_ERR: int = 203,
     C_PURPLE: int = 176,
     C_CYAN: int = 117;

obj Theme {
    has pane: StyleAttrs = StyleAttrs(fg=252, bg=235),
        text: StyleAttrs = StyleAttrs(fg=252),
        dim: StyleAttrs = StyleAttrs(fg=244),
        faint: StyleAttrs = StyleAttrs(fg=240),
        accent: StyleAttrs = StyleAttrs(fg=75, bold=True),
        accent2: StyleAttrs = StyleAttrs(fg=179),
        ok: StyleAttrs = StyleAttrs(fg=114),
        warn: StyleAttrs = StyleAttrs(fg=221),
        err: StyleAttrs = StyleAttrs(fg=203, bold=True),
        title: StyleAttrs = StyleAttrs(fg=250, bg=237, bold=True),
        title_focus: StyleAttrs = StyleAttrs(fg=255, bg=24, bold=True),
        sel: StyleAttrs = StyleAttrs(bg=238),
        sel_focus: StyleAttrs = StyleAttrs(fg=255, bg=25),
        header: StyleAttrs = StyleAttrs(fg=255, bg=24, bold=True),
        header_dim: StyleAttrs = StyleAttrs(fg=153, bg=24),
        status: StyleAttrs = StyleAttrs(fg=250, bg=236),
        status_key: StyleAttrs = StyleAttrs(fg=255, bg=236, bold=True),
        gutter: StyleAttrs = StyleAttrs(fg=240),
        gutter_cur: StyleAttrs = StyleAttrs(fg=250, bold=True),
        cur_line: StyleAttrs = StyleAttrs(bg=236),
        overlay: StyleAttrs = StyleAttrs(fg=252, bg=237),
        overlay_title: StyleAttrs = StyleAttrs(fg=255, bg=24, bold=True),
        overlay_sel: StyleAttrs = StyleAttrs(fg=255, bg=25, bold=True);
}

glob THEME: Theme = Theme(),
     CODE_STYLES: dict[str, StyleAttrs] = {
         "keyword": StyleAttrs(fg=176, bold=True),
         "string": StyleAttrs(fg=114),
         "fstring": StyleAttrs(fg=114),
         "number": StyleAttrs(fg=173),
         "comment": StyleAttrs(fg=243, italic=True),
         "docstring": StyleAttrs(fg=108, italic=True),
         "operator": StyleAttrs(fg=250),
         "punct": StyleAttrs(fg=246),
         "decorator": StyleAttrs(fg=179),
         "builtin": StyleAttrs(fg=81),
         "name": StyleAttrs(fg=252),
         "type": StyleAttrs(fg=81),
         "class": StyleAttrs(fg=81, bold=True),
         "struct": StyleAttrs(fg=81, bold=True),
         "interface": StyleAttrs(fg=81),
         "enum": StyleAttrs(fg=81),
         "type_parameter": StyleAttrs(fg=81),
         "function": StyleAttrs(fg=221),
         "method": StyleAttrs(fg=221),
         "macro": StyleAttrs(fg=221),
         "parameter": StyleAttrs(fg=180),
         "variable": StyleAttrs(fg=252),
         "property": StyleAttrs(fg=117),
         "enum_member": StyleAttrs(fg=173),
         "event": StyleAttrs(fg=176),
         "namespace": StyleAttrs(fg=109),
         "modifier": StyleAttrs(fg=176),
         "regexp": StyleAttrs(fg=114),
         "error": StyleAttrs(fg=203, underline=True),
         "warning": StyleAttrs(fg=221, underline=True)
     },
     KIND_ICONS: dict[str, str] = {
         "project": "◆",
         "package": "▣",
         "module": "◇",
         "external": "◌",
         "obj": "●",
         "class": "●",
         "node": "◉",
         "edge": "⇢",
         "walker": "⟳",
         "enum": "≡",
         "def": "ƒ",
         "method": "ƒ",
         "can": "⚡",
         "has": "·",
         "impl": "⌁",
         "rule": "⚖",
         "wire": "⇄"
     },
     KIND_COLORS: dict[str, int] = {
         "package": 109,
         "module": 75,
         "external": 244,
         "obj": 81,
         "class": 81,
         "node": 114,
         "edge": 180,
         "walker": 176,
         "enum": 173,
         "def": 221,
         "method": 221,
         "can": 176,
         "has": 117,
         "impl": 244,
         "rule": 179,
         "wire": 75
     };

def st(
    fg: (int | None) = None,
    bg: (int | None) = None,
    bold: bool = False,
    dim: bool = False,
    italic: bool = False,
    underline: bool = False,
    reverse: bool = False
) -> StyleAttrs;

def sp(text: str, attrs: (StyleAttrs | None) = None) -> TextSpan;

def with_bg(a: (StyleAttrs | None), bg: (int | None)) -> StyleAttrs;

def fit(
    spans: list[TextSpan], width: int, fill: (StyleAttrs | None) = None
) -> list[TextSpan];

def plain(text: str, width: int, attrs: (StyleAttrs | None) = None) -> list[TextSpan];

def blank(width: int, attrs: (StyleAttrs | None) = None) -> list[TextSpan];

def restyle(spans: list[TextSpan], bg: (int | None)) -> list[TextSpan];

def kind_icon(kind: str) -> str;

def kind_attrs(kind: str) -> StyleAttrs;

def wrap_plain(text: str, width: int) -> list[str];

impl st(
    fg: (int | None) = None,
    bg: (int | None) = None,
    bold: bool = False,
    dim: bool = False,
    italic: bool = False,
    underline: bool = False,
    reverse: bool = False
) -> StyleAttrs {
    return StyleAttrs(
        fg=fg,
        bg=bg,
        bold=bold,
        dim=dim,
        italic=italic,
        underline=underline,
        reverse=reverse
    );
}

impl sp(text: str, attrs: (StyleAttrs | None) = None) -> TextSpan {
    return TextSpan(text=text, attrs=attrs);
}

impl with_bg(a: (StyleAttrs | None), bg: (int | None)) -> StyleAttrs {
    if a is None {
        return StyleAttrs(bg=bg);
    }
    return StyleAttrs(
        fg=a.fg,
        bg=bg,
        bold=a.bold,
        dim=a.dim,
        italic=a.italic,
        underline=a.underline,
        reverse=a.reverse
    );
}

impl fit(
    spans: list[TextSpan], width: int, fill: (StyleAttrs | None) = None
) -> list[TextSpan] {
    out: list[TextSpan] = [];
    used = 0;
    if width <= 0 {
        return out;
    }
    for s in spans {
        if not s.text {
            continue;
        }
        text = s.text.replace("\t", "    ");
        w = display_width(text);
        if used + w <= width {
            out.append(TextSpan(text=text, attrs=s.attrs));
            used += w;
            continue;
        }
        room = width - used;
        if room > 0 {
            cut = truncate_text(text, room, ellipsis="…");
            out.append(TextSpan(text=cut, attrs=s.attrs));
            used += display_width(cut);
        }
        break;
    }
    if used < width {
        out.append(TextSpan(text=" " * (width - used), attrs=fill));
    }
    return out;
}

impl plain(text: str, width: int, attrs: (StyleAttrs | None) = None) -> list[TextSpan] {
    return fit([TextSpan(text=text, attrs=attrs)], width, attrs);
}

impl blank(width: int, attrs: (StyleAttrs | None) = None) -> list[TextSpan] {
    return [TextSpan(text=" " * max(width, 0), attrs=attrs)];
}

impl restyle(spans: list[TextSpan], bg: (int | None)) -> list[TextSpan] {
    return [TextSpan(text=s.text, attrs=with_bg(s.attrs, bg)) for s in spans];
}

impl kind_icon(kind: str) -> str {
    return KIND_ICONS.get(kind, "•");
}

impl kind_attrs(kind: str) -> StyleAttrs {
    return StyleAttrs(fg=KIND_COLORS.get(kind, 252));
}

impl wrap_plain(text: str, width: int) -> list[str] {
    out: list[str] = [];
    if width <= 1 {
        return [text];
    }
    for raw in text.replace("\t", "    ").split("\n") {
        line = raw;
        if not line {
            out.append("");
            continue;
        }
        while display_width(line) > width {
            cut = width;
            space = line.rfind(" ", 0, width);
            if space > width // 2 {
                cut = space + 1;
            }
            out.append(line[:cut].rstrip());
            line = line[cut:];
        }
        out.append(line);
    }
    return out;
}
