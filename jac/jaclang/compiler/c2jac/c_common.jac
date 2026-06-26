"""Shared C-semantics knowledge for both c2jac lowering backends.

mapper.jac (Python-AST path → CPython `ast` nodes) and uni_builder.jac
(direct-IR path → `uni` Tokens) each translate C operators and parse C literals.
That knowledge used to live twice — classify a C operator, or parse `int(v, 0)`,
in one backend and you had to remember the other. This module is the single
source of truth: each operator is listed once with *all* the per-backend
encodings (its `ast` class name AND its Jac token), and the literal/coordinate
helpers are shared functions. A new operator or literal form is added here once.
"""

# --- C binary operators -------------------------------------------------- #
# c_op → (kind, ast3_class, jac_tok_name, jac_tok_val)
#   kind        — "arith" | "compare" | "bool"; picks the CPython-ast wrapper
#                 (BinOp / Compare / BoolOp) on the Python-AST path.
#   ast3_class  — the operator class under the `ast` module (getattr(ast3, …)).
#   jac_tok_*   — the uni.Token name/value for the direct-IR path.
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
     # --- C augmented-assignment operators ------------------------------------ #
     # c_op → (ast3_class, jac_tok_name, jac_tok_val)
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

# --- C literal parsers --------------------------------------------------- #
def parse_c_int(raw: str) -> int | None {
    # C integer literal → int (handles 0x/0o/0b prefixes via base 0). On failure
    # retries with any C integer suffix stripped (u/U and l/L combos: `10L`,
    # `5U`, `3ULL`). Returns None only when still unparseable. Single source for
    # every `int(v, 0)` site in c2jac.
    try {
        return int(raw, 0);
    } except ValueError {
        stripped = raw.rstrip("uUlL");
        if stripped and stripped != raw {
            try {
                return int(stripped, 0);
            } except ValueError {
                return None;
            }
        }
        return None;
    }
}

def parse_c_float(raw: str) -> float | None {
    # C float literal → float, retrying with any C float suffix stripped
    # (f/F/l/L: `1.5f`, `2.0L`) when the verbatim parse fails.
    try {
        return float(raw);
    } except ValueError {
        stripped = raw.rstrip("fFlL");
        if stripped and stripped != raw {
            try {
                return float(stripped);
            } except ValueError {
                return None;
            }
        }
        return None;
    }
}

# --- C constant classification ------------------------------------------- #
# Family labels for a pycparser `Constant`. Both backends switch on the family
# returned by classify_c_constant; the encoding (CPython `ast` Constant vs uni
# node) and the failure policy stay backend-specific.
glob CLIT_INT: str = "int",
     CLIT_FLOAT: str = "float",
     CLIT_CHAR: str = "char",
     CLIT_STRING: str = "string",
     CLIT_UNKNOWN: str = "unknown";

def classify_c_constant(c_type: str) -> str {
    # Map pycparser's *widened* Constant type to a c2jac literal family. The
    # type is reported as the C family ("unsigned int" / "long double" / ...),
    # so integers and floats are matched on the suffix; `char` / `string` are
    # exact. A new C type spelling is now classified in one place instead of
    # being mirrored in mapper.c_Constant and uni_builder._expr_to_uni.
    if c_type.endswith("int") {
        return CLIT_INT;
    }
    if c_type.endswith("double") or c_type.endswith("float") {
        return CLIT_FLOAT;
    }
    if c_type == "char" {
        return CLIT_CHAR;
    }
    if c_type == "string" {
        return CLIT_STRING;
    }
    return CLIT_UNKNOWN;
}

def c_char_text(raw: str) -> str {
    # C char constant spelling `'a'` → its inner text `a` (quotes stripped).
    # Returns the spelling unchanged when it is not single-quote wrapped, so a
    # malformed value is preserved verbatim for the caller to flag.
    if raw.startswith("'") and raw.endswith("'") {
        return raw[1:-1];
    }
    return raw;
}

def c_char_ord(raw: str) -> int | None {
    # C char constant ("'z'", "'\n'", "'\0'") → its integer value. Decodes the
    # common escape sequences via unicode_escape; returns None for multi-char
    # or otherwise non-single-char constants so the caller can flag the loss
    # instead of guessing.
    if not (raw.startswith("'") and raw.endswith("'")) or len(raw) < 3 {
        return None;
    }
    inner = raw[1:-1];
    try {
        decoded = bytes(inner, "utf-8").decode("unicode_escape");
    } except Exception {
        return None;
    }
    if len(decoded) != 1 {
        return None;
    }
    return ord(decoded);
}

def c_string_inner(raw: str) -> str | None {
    # Plain C string literal `"…"` → its inner text (quotes stripped). Returns
    # None when the spelling is not a bare double-quoted literal — a prefixed
    # form (L"…"/u8"…") or a malformed value — so the caller can demote/flag
    # rather than emit a wrong-shaped string.
    if raw.startswith('"') and raw.endswith('"') and len(raw) >= 2 {
        return raw[1:-1];
    }
    return None;
}

# --- pycparser coordinate extraction ------------------------------------- #
def coord_of(c_node: object, default_line: int) -> tuple[int, int] {
    # Resolve a pycparser node's (line, col) — col is 0-based for CPython ast /
    # uni stamping. Falls back to `default_line` (and column 0) when the node has
    # no coord or no line. Backends wrap this: the mapper threads its running
    # last-seen line as the default; the direct-IR builder passes 1.
    coord = c_node?.coord;
    if coord {
        line = coord.line or default_line;
        col = (coord.column - 1) if coord.column else 0;
        return (line, col);
    }
    return (default_line, 0);
}
