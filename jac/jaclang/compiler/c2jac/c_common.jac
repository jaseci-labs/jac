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
    # C integer literal → int (handles 0x/0o/0b prefixes via base 0). Returns
    # None on failure (e.g. suffixed literals like `10U`), letting callers fall
    # back. Single source for every `int(v, 0)` site in c2jac.
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
