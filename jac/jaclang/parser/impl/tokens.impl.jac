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

"""Check if this token is a literal value."""
impl Token.is_literal -> bool {
    return self.kind in [
        TokenKind.INT,
        TokenKind.HEX,
        TokenKind.BIN,
        TokenKind.OCT,
        TokenKind.FLOAT,
        TokenKind.STRING,
        TokenKind.BOOL,
        TokenKind.NULL
    ];
}

"""Check if this token is an operator."""
impl Token.is_operator -> bool {
    return self.kind in [
        TokenKind.PLUS,
        TokenKind.MINUS,
        TokenKind.STAR_MUL,
        TokenKind.DIV,
        TokenKind.FLOOR_DIV,
        TokenKind.MOD,
        TokenKind.STAR_POW,
        TokenKind.BW_AND,
        TokenKind.BW_OR,
        TokenKind.BW_XOR,
        TokenKind.BW_NOT,
        TokenKind.LSHIFT,
        TokenKind.RSHIFT,
        TokenKind.EE,
        TokenKind.NE,
        TokenKind.LT,
        TokenKind.GT,
        TokenKind.LTE,
        TokenKind.GTE,
        TokenKind.KW_AND,
        TokenKind.KW_OR,
        TokenKind.KW_NOT,
        TokenKind.KW_IN,
        TokenKind.KW_IS
    ];
}

"""Check if this token is an assignment operator."""
impl Token.is_assignment -> bool {
    return self.kind in [
        TokenKind.EQ,
        TokenKind.WALRUS_EQ,
        TokenKind.ADD_EQ,
        TokenKind.SUB_EQ,
        TokenKind.MUL_EQ,
        TokenKind.DIV_EQ,
        TokenKind.FLOOR_DIV_EQ,
        TokenKind.MOD_EQ,
        TokenKind.STAR_POW_EQ,
        TokenKind.BW_AND_EQ,
        TokenKind.BW_OR_EQ,
        TokenKind.BW_XOR_EQ,
        TokenKind.LSHIFT_EQ,
        TokenKind.RSHIFT_EQ,
        TokenKind.MATMUL_EQ
    ];
}

"""Check if this token is a comparison operator."""
impl Token.is_compare_op -> bool {
    return self.kind in [
        TokenKind.EE,
        TokenKind.NE,
        TokenKind.LT,
        TokenKind.GT,
        TokenKind.LTE,
        TokenKind.GTE,
        TokenKind.KW_IN,
        TokenKind.KW_IS,
        TokenKind.KW_NIN,
        TokenKind.KW_ISN
    ];
}

"""String representation of the token."""
impl Token.__str__ -> str {
    return f"Token({self.kind}, '{self.value}', line={self.loc.line})";
}
