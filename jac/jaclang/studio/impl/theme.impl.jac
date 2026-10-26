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
