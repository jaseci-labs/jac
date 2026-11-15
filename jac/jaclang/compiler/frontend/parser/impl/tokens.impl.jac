impl SourceLoc.span_to(other: SourceLoc) -> SourceLoc {
    return SourceLoc(
        file_path=self.file_path,
        line=self.line,
        end_line=other.end_line,
        col_start=self.col_start,
        col_end=other.col_end,
        pos_start=self.pos_start,
        pos_end=other.pos_end
    );
}

impl LexToken.__str__ -> str {
    return f"LexToken({self.kind}, '{self.value}', line={self.loc.line})";
}

impl lookup_keyword(text: str) -> TokenKind | None {
    if text in KEYWORDS {
        return KEYWORDS[text];
    }
    return None;
}

impl is_reserved_kind(kind: TokenKind) -> bool {
    return kind in RESERVED_KINDS;
}

impl is_builtin_type_kind(kind: TokenKind) -> bool {
    return kind in BUILTIN_TYPE_KINDS;
}

impl reserved_words -> list[str] {
    return sorted(
        word
        for (word, kind) in KEYWORDS.items()
        if kind in RESERVED_KINDS
    );
}

impl is_special_var_kind(kind: TokenKind) -> bool {
    return kind in SPECIAL_VAR_KINDS;
}

impl is_name_usable_kind(kind: TokenKind) -> bool {
    if kind == TokenKind.KW_ROOT or kind == TokenKind.KW_SUPER {
        return False;
    }
    return is_special_var_kind(kind) or is_builtin_type_kind(kind);
}
