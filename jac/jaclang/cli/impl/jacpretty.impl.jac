impl _parse_color(color: str, bg: bool = False) -> Optional[Tuple[(str, ...)]] {
    color = color.lower().strip();
    base = 40 if bg else 30;
    mode = "48" if bg else "38";
    if (color in COLORS) {
        n = COLORS[color];
        return (str((base + n)) if (n < 8) else str(base + 52 + n), );
    }
    if (color.startswith("#") and (len(color) == 7)) {
        try {
            return (
                mode,
                "2",
                str(int(color[1:3], 16)),
                str(int(color[3:5], 16)),
                str(int(color[5:7], 16))
            );
        } except ValueError {
            return None;
        }
    }
    if (color.startswith("rgb(") and color.endswith(")")) {
        p = color[4:-1].split(",");
        if (len(p) == 3) {
            try {
                (r, g, b) = (int(p[0].strip()), int(p[1].strip()), int(p[2].strip()));
                return (mode, "2", str(r), str(g), str(b));
            } except ValueError {
                return None;
            }
        }
        return None;
    }
    if (color.startswith("color(") and color.endswith(")")) {
        try {
            n = int(color[6:-1].strip());
            return (mode, "5", str(n));
        } except ValueError {
            return None;
        }
    }
    return None;
}

impl render_markup(markup: str, base_style: str = "") -> str {
    # Use Unicode Private Use Area chars as placeholders (unlikely in real input)
    (_LBRACKET, _RBRACKET) = ("\ue000", "\ue001");
    markup = markup.replace("\\[", _LBRACKET).replace("\\]", _RBRACKET);
    (result, stack, pos) = ([], [base_style] if base_style else [], 0);
    for m in RE_MARKUP.finditer(markup) {
        if (m.start() > pos) {
            txt = markup[pos:m.start()].replace(_LBRACKET, "[").replace(_RBRACKET, "]");
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
        txt = markup[pos:].replace(_LBRACKET, "[").replace(_RBRACKET, "]");
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
