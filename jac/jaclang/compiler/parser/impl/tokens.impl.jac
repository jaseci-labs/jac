"""Token implementation methods.

This file contains the implementations for Token and SourceLoc methods.
"""

# =============================================================================
# SourceLoc Implementations
# =============================================================================
"""Create a new SourceLoc spanning from this location to another."""
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

# =============================================================================
# Token Implementations
# =============================================================================
"""Check if this token is a keyword."""
impl Token.is_keyword -> bool {
    return self.kind.value.startswith("KW_") or self.kind.value.startswith("TYP_");
}

"""String representation of the token."""
impl Token.__str__ -> str {
    return f"Token({self.kind}, '{self.value}', line={self.loc.line})";
}
