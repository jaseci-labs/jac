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
