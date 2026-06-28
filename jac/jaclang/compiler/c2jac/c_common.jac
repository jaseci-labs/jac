"""Shared C-semantics knowledge for both c2jac lowering backends.

mapper.jac (Python-AST path → CPython `ast` nodes) and uni_builder.jac
(direct-IR path → `uni` Tokens) each translate C operators and parse C literals.
That knowledge used to live twice — classify a C operator, or parse `int(v, 0)`,
in one backend and you had to remember the other. This module is the single
source of truth: each operator is listed once with *all* the per-backend
encodings (its `ast` class name AND its Jac token), and the literal/coordinate
helpers are shared functions. A new operator or literal form is added here once.
"""

import from jaclang.vendor.pycparser { c_ast }

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

# --- Dispatch-miss surrogate sentinels ----------------------------------- #
# Single source of truth for the surrogate call names a dispatch miss emits.
# The mapper builds these as `ast` Name nodes (mapper.impl/core.impl.jac) and the
# post-format comment injector (comments.jac) matches them by regex to attach the
# BEST-EFFORT note. Both sides import from here so the name lives in exactly one
# place — change it and both the emitter and the matcher move together.
glob UNSUPPORTED_STMT: str = "__c2jac_unsupported__",
     UNSUPPORTED_EXPR: str = "__c2jac_unsupported_expr__";

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

# --- side-effect analysis ------------------------------------------------ #
def expr_reeval_safe(nd: object) -> bool {
    # True when (re-)evaluating `nd` has no observable effect — no call, no
    # assignment, no pre/post inc-dec anywhere in the subtree. Pure lvalues
    # (`x`, `a[i]`, `s->f`) qualify: re-reading them yields the same value.
    # (A `volatile` selector would still be re-read on each access; pycparser
    # exposes no type qualifier here, so that rare case is not separately
    # detected.)
    #
    # Two callers rely on this. The mapper's switch lowering re-emits a pure
    # selector once per `==` comparison, so it must be safe to evaluate more
    # than once. Both backends' comma-expression lowering drop the leading
    # operands of `(a, b, … , z)` and emit only `z`; that is faithful exactly
    # when those leading operands are side-effect-free.
    if nd is None {
        return True;
    }
    if isinstance(nd, c_ast.FuncCall) or isinstance(nd, c_ast.Assignment) {
        return False;
    }
    if isinstance(nd, c_ast.UnaryOp) and nd.op in ("++", "--", "p++", "p--") {
        return False;
    }
    for (_, child) in nd.children() {
        if not expr_reeval_safe(child) {
            return False;
        }
    }
    return True;
}

# --- control-flow shape predicates --------------------------------------- #
# Pure analyses over pycparser nodes — independent of the output IR — so both
# the py-ast mapper and the direct-IR uni builder share them. Keeping a single
# copy is load-bearing: each backend's Tier-A/Tier-B verdict for a switch,
# do-while, or pointer idiom is decided by these, and two copies could drift
# into disagreeing verdicts for the same construct.
def has_loop_continue(nd: object) -> bool {
    # True if a `continue` belonging to THIS loop appears in nd. Nested loops
    # and switch bodies own their own continue/break, so descent stops at them.
    if nd is None {
        return False;
    }
    if (
        isinstance(nd, c_ast.For)
        or isinstance(nd, c_ast.While)
        or isinstance(nd, c_ast.DoWhile)
        or isinstance(nd, c_ast.Switch)
    ) {
        return False;
    }
    if isinstance(nd, c_ast.Continue) {
        return True;
    }
    for (_, child) in nd.children() {
        if has_loop_continue(child) {
            return True;
        }
    }
    return False;
}

def section_terminates(stmts: list | None) -> bool {
    # True when the case body's last *direct* statement transfers control out of
    # the section (break / return / continue), so execution can't fall into the
    # next case. A bare break is the switch terminator; return leaves the
    # function; continue jumps to the enclosing loop — all three are emitted
    # faithfully and stop fall-through. A braced body `case N: { ...; break; }`
    # nests its terminator inside a trailing Compound, so descend through it to
    # find the real last statement. Anything else (incl. a break nested inside an
    # `if`) is treated as potential fall-through and keeps the switch Tier-B.
    if not stmts {
        return False;
    }
    last = stmts[-1];
    while isinstance(last, c_ast.Compound) {
        if not last.block_items {
            return False;
        }
        last = last.block_items[-1];
    }
    return (
        isinstance(last, c_ast.Break)
        or isinstance(last, c_ast.Return)
        or isinstance(last, c_ast.Continue)
    );
}

def switch_is_safe(items: list, cond: object) -> bool {
    # A switch lowers to an EXACT if/elif/else chain iff neither lossy shape is
    # present (§5.3):
    #   1. No fall-through: every section except the last in source order must
    #      end in a control transfer (break / return / continue). The one
    #      exception is an empty label-only `case` (`case 1: case 2:`): it carries
    #      no body and is faithfully OR-folded onto the next body-bearing section,
    #      so it never falls through. This does NOT extend to an empty `default`
    #      — a default is never OR-folded, so an empty default that is not the
    #      last section falls straight into the following case, which if/elif
    #      cannot model.
    #   2. Pure selector: it is re-emitted once per `==` comparison, so it must
    #      be free of side effects to be safe to evaluate more than once.
    # Conservative on both counts — any shape we can't prove clean stays Tier-B.
    if not expr_reeval_safe(cond) {
        return False;
    }
    # Source-order indices of every case/default label (a body may be empty).
    sec_idxs: list[int] = [];
    for (i, it) in enumerate(items) {
        if isinstance(it, c_ast.Case) or isinstance(it, c_ast.Default) {
            sec_idxs.append(i);
        }
    }
    if not sec_idxs {
        return True;
    }
    last = sec_idxs[-1];
    for i in sec_idxs {
        # The final section has nothing to fall into, so its terminator is moot.
        if i == last {
            continue;
        }
        it = items[i];
        # An empty `case` label OR-folds onto the next section (faithful); every
        # other non-final section — a body-bearing case, or ANY default — must
        # transfer control or it falls into the next case.
        if isinstance(it, c_ast.Case) and not it.stmts {
            continue;
        }
        if not section_terminates(it.stmts) {
            return False;
        }
    }
    return True;
}

# --- pointer / cast shape predicates ------------------------------------- #
def is_simple_ref(c_node: object) -> bool {
    # A reference-shaped operand: names a storage location without pointer
    # arithmetic or reinterpretation. ID / s.f / s->f / a[i] qualify; a
    # BinaryOp (`p+1`), Cast, or nested `*`/`&` does not (those stay Tier-B).
    return (
        isinstance(c_node, c_ast.ID)
        or isinstance(c_node, c_ast.StructRef)
        or isinstance(c_node, c_ast.ArrayRef)
    );
}

def cast_scalar_target(nd: object) -> str | None {
    # The C scalar type name a Cast targets when it is a value cast
    # (Typename → TypeDecl → IdentifierType); None for pointer/array/struct
    # casts, which don't change the emitted value.
    to_type = nd?.to_type;
    if to_type is None {
        return None;
    }
    inner = to_type?.type;
    if isinstance(inner, c_ast.TypeDecl)
    and isinstance(inner.type, c_ast.IdentifierType) {
        names = inner.type.names;
        return names[-1] if names else None;
    }
    return None;
}

def is_null_ptr_constant(c_node: object) -> bool {
    # A C null-pointer constant: an integer-constant 0, optionally wrapped in
    # cast layers (after preprocessing, `NULL` is typically `((void *)0)`).
    # Peel any Cast layers, then require an integer Constant whose parsed value
    # is 0. Used by pointer-typed contexts (return/assignment) to lower a bare
    # `0` to Jac `None` instead of the integer literal 0. (Local is named `cur`,
    # not `node` — `node` is a reserved Jac archetype keyword and silently
    # breaks codegen if used as a variable.)
    cur = c_node;
    while isinstance(cur, c_ast.Cast) {
        cur = cur.expr;
    }
    if not isinstance(cur, c_ast.Constant) {
        return False;
    }
    if classify_c_constant(cur.type) != CLIT_INT {
        return False;
    }
    return parse_c_int(cur.value) == 0;
}

# --- Jac scalar zero defaults -------------------------------------------- #
def jac_prim_zero(jac: str) -> tuple {
    # Zero literal (value, display text) for a Jac scalar primitive.
    # Covers int / float / bool — the three numerics whose zero is unambiguous.
    # Callers that need a context-specific str zero ("" vs 0) branch on "str"
    # before calling here (e.g. _zero_default uses "" for static char;
    # _elem_default lets str fall through to (0, "0") for list element fill).
    if jac == "float" {
        return (0.0, "0.0");
    }
    if jac == "bool" {
        return (False, "False");
    }
    return (0, "0");
}
