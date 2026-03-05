# Test cross-module enum import: imports from na_enum_export.na.jac

import from na_enum_export { TokenKind, Token, KEYWORDS, lookup_keyword, make_token, token_kind_value }

def check_if_keyword() -> int {
    return lookup_keyword("if");
}

def check_else_keyword() -> int {
    return lookup_keyword("else");
}

def check_unknown_keyword() -> int {
    return lookup_keyword("unknown");
}

def use_imported_enum() -> int {
    if TokenKind.KW_IF == TokenKind.KW_IF {
        return 1;
    }
    return 0;
}

def imported_enum_ordinals() -> int {
    return TokenKind.EOF;
}

def imported_enum_value() -> str {
    k: TokenKind = TokenKind.PLUS;
    return k.value;
}

with entry {
    _x: int = 1;
}
