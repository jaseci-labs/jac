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

impl Token.is_keyword -> bool {
    return self.kind.value.startswith("KW_") or self.kind.value.startswith("TYP_");
}

impl Token.__str__ -> str {
    return f"Token({self.kind}, '{self.value}', line={self.loc.line})";
}
