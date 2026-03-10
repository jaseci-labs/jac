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
                r = int(p[0].strip());
                g = int(p[1].strip());
                b = int(p[2].strip());
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

"""Render markup to ANSI codes. Supports [link=url] for hyperlinks.

Args:
    markup: Text with markup tags
    base_style: Base style to apply
    strict: If True, raise MarkupError for invalid markup (Rich-compatible)
"""
impl render_markup(markup: str, base_style: str = "", strict: bool = False) -> str {
    # Use Unicode Private Use Area chars as placeholders (unlikely in real input)
    _LBRACKET = "\ue000";
    _RBRACKET = "\ue001";
    markup = markup.replace("\\[", _LBRACKET).replace("\\]", _RBRACKET);

    # Initialize stacks
    result: list = [];
    stack: list = [base_style] if base_style else [];
    link_stack: list = [];
    pos = 0;

    for m in RE_MARKUP.finditer(markup) {
        if (m.start() > pos) {
            txt = markup[pos:m.start()].replace(_LBRACKET, "[").replace(_RBRACKET, "]");
            # Build style with link if present
            current_link = link_stack[-1] if link_stack else None;
            style = Style(" ".join(stack), link=current_link)
                if stack or current_link
                else None;
            result.append(style.render(txt) if style else txt);
        }

        # Group 1 contains the full tag content
        tag = m.group(1).strip();

        if (tag.startswith("/")) {
            # Closing tag: [/] or [/bold] or [/link]
            close_name = tag[1:].strip().lower();
            if (close_name == "link" and link_stack) {
                link_stack.pop();
            } elif (stack) {
                stack.pop();
            } elif (strict) {
                raise MarkupError(
                    f"closing tag '[{tag}]' at position {m.start()} has nothing to close"
                );
            }
        } elif (tag.lower().startswith("link=")) {
            # Link tag: [link=url]
            url = tag[5:];  # Extract URL after "link="
            link_stack.append(url);
        } else {
            # Opening tag: [bold], [red], [#ff0000], etc.
            stack.append(tag);
        }
        pos = m.end();
    }

    if (pos < len(markup)) {
        txt = markup[pos:].replace(_LBRACKET, "[").replace(_RBRACKET, "]");
        current_link = link_stack[-1] if link_stack else None;
        style = Style(" ".join(stack), link=current_link)
            if stack or current_link
            else None;
        result.append(style.render(txt) if style else txt);
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
