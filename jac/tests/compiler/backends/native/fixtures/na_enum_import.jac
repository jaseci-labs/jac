# Test cross-module enum import: imports from na_enum_export.jac

import from na_enum_export {
    TokenKind,
    Token,
    KEYWORDS,
    lookup_keyword,
    make_token,
    token_kind_value
}

def check_if_keyword -> int {
    try {
        return lookup_keyword("if");
    } except TypeError {
        return -2;
    }
}

def check_else_keyword -> int {
    try {
        return lookup_keyword("else");
    } except TypeError {
        return -2;
    }
}

def check_unknown_keyword -> int {
    try {
        return lookup_keyword("unknown");
    } except TypeError {
        return -2;
    }
}

def use_imported_enum -> int {
    if TokenKind.KW_IF == TokenKind.KW_IF {
        return 1;
    }
    return 0;
}

def imported_enum_value -> str {
    k: TokenKind = TokenKind.PLUS;
    return k.value;
}

glob _x: int = 1;
