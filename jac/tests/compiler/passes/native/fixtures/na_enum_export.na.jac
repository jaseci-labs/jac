# Exported string enum and related types/functions for cross-module import testing

enum TokenKind {
    INT = "INT",
    FLOAT = "FLOAT",
    NAME = "NAME",
    KW_IF = "if",
    KW_ELSE = "else",
    PLUS = "+",
    EOF = "EOF"
}

obj Token {
    has kind: TokenKind = TokenKind.EOF,
        value: str = "";
}

glob KEYWORDS: dict[str, int] = {
    "if": TokenKind.KW_IF,
    "else": TokenKind.KW_ELSE
};

def lookup_keyword(text: str) -> int {
    return KEYWORDS.get(text, -1);
}

def make_token(kind: TokenKind, value: str) -> Token {
    return Token(kind=kind, value=value);
}

def token_kind_value(kind: TokenKind) -> str {
    return kind.value;
}

with entry {
    _x: int = 1;
}
