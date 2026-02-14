# Standalone comment that should NOT end up inside f-strings.

def fmt_dict(value: dict) -> str {
    if not value {
        return "{}";
    }
    return f"{{{len(value)} keys}}";
}

def fmt_spaced(pairs: list) -> str {
    return f"{{ {', '.join(pairs)} }}";
}

def build_lines(items: list, redirect: str) -> list {
    lines: list = [];
    lines.append("hello");
    # Comment before f-string statement should stay here.
    lines.append(
        f'function guard() {{ return go("{redirect}"); }}'
    );
    # Comment after f-string statement should stay here.
    lines.append("world");
    return lines;
}
