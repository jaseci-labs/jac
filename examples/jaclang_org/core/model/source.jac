obj SourceFile {
    has path: str,
        dir: str,
        name: str,
        language: str,
        lines: int;
}

obj SourceView {
    has path: str,
        language: str,
        size_bytes: int,
        lines: int,
        raw_lines: list[str];
}

obj SourceSpan {
    has path: str,
        language: str,
        total_lines: int,
        start: int,
        hl_from: int,
        hl_to: int,
        found: bool,
        raw_lines: list[str];
}
