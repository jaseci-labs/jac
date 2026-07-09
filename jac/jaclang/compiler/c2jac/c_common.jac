glob C_BINOPS: dict[str, tuple[str, str, str, str]] = {
         "+": ("arith", "Add", "PLUS", "+"),
         "-": ("arith", "Sub", "MINUS", "-"),
         "*": ("arith", "Mult", "STAR_MUL", "*"),
         "/": ("arith", "Div", "DIV", "/"),
         "%": ("arith", "Mod", "MOD", "%"),
         "&": ("arith", "BitAnd", "BW_AND", "&"),
         "|": ("arith", "BitOr", "BW_OR", "|"),
         "^": ("arith", "BitXor", "BW_XOR", "^"),
         "<<": ("arith", "LShift", "LSHIFT", "<<"),
         ">>": ("arith", "RShift", "RSHIFT", ">>"),
         "==": ("compare", "Eq", "EE", "=="),
         "!=": ("compare", "NotEq", "NE", "!="),
         "<": ("compare", "Lt", "LT", "<"),
         "<=": ("compare", "LtE", "LTE", "<="),
         ">": ("compare", "Gt", "GT", ">"),
         ">=": ("compare", "GtE", "GTE", ">="),
         "&&": ("bool", "And", "KW_AND", "and"),
         "||": ("bool", "Or", "KW_OR", "or"),

     },
     C_AUGOPS: dict[str, tuple[str, str, str]] = {
         "+=": ("Add", "ADD_EQ", "+="),
         "-=": ("Sub", "SUB_EQ", "-="),
         "*=": ("Mult", "MUL_EQ", "*="),
         "/=": ("Div", "DIV_EQ", "/="),
         "%=": ("Mod", "MOD_EQ", "%="),
         "&=": ("BitAnd", "BW_AND_EQ", "&="),
         "|=": ("BitOr", "BW_OR_EQ", "|="),
         "^=": ("BitXor", "BW_XOR_EQ", "^="),
         "<<=": ("LShift", "LSHIFT_EQ", "<<="),
         ">>=": ("RShift", "RSHIFT_EQ", ">>="),

     };

def parse_c_int(raw: str) -> int | None {
    try {
        return int(raw, 0);
    } except ValueError {
        return None;
    }
}

def parse_c_float(raw: str) -> float | None {
    try {
        return float(raw);
    } except ValueError {
        return None;
    }
}

def coord_of(c_node: object, default_line: int) -> tuple[int, int] {
    coord = c_node?.coord;
    if coord {
        line = coord.line or default_line;
        col = (coord.column - 1) if coord.column else 0;
        return (line, col);
    }
    return (default_line, 0);
}
