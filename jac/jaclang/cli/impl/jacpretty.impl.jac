impl _parse_color(color: str, bg: bool = False) -> Optional[Tuple[(str, ...)]] {
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

impl render_markup(markup: str, base_style: str = "") -> str {
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

impl get_console -> Console {
    global _console;
    if (_console is None) {
        _console = Console();
    }
    return _console;
}

impl print(*objects: Any, **kwargs: Any) -> None {
    get_console().print(*objects, **kwargs);
}
