import keyword;
import from jaclang.jac0core.constant { TOKEN_MAP }
import from jaclang.vendor.pycparser { c_ast }

glob C_BINOPS: dict[str, tuple[str, str]] = {
         "+": ("arith", "Add"),
         "-": ("arith", "Sub"),
         "*": ("arith", "Mult"),
         "/": ("arith", "Div"),
         "%": ("arith", "Mod"),
         "&": ("arith", "BitAnd"),
         "|": ("arith", "BitOr"),
         "^": ("arith", "BitXor"),
         "<<": ("arith", "LShift"),
         ">>": ("arith", "RShift"),
         "==": ("compare", "Eq"),
         "!=": ("compare", "NotEq"),
         "<": ("compare", "Lt"),
         "<=": ("compare", "LtE"),
         ">": ("compare", "Gt"),
         ">=": ("compare", "GtE"),
         "&&": ("bool", "And"),
         "||": ("bool", "Or"),

     },
     C_AUGOPS: dict[str, str] = {
         "+=": "Add",
         "-=": "Sub",
         "*=": "Mult",
         "/=": "Div",
         "%=": "Mod",
         "&=": "BitAnd",
         "|=": "BitOr",
         "^=": "BitXor",
         "<<=": "LShift",
         ">>=": "RShift",

     };

def parse_c_int(raw: str) -> int | None {
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

glob CLIT_INT: str = "int",
     CLIT_FLOAT: str = "float",
     CLIT_CHAR: str = "char",
     CLIT_STRING: str = "string",
     CLIT_UNKNOWN: str = "unknown";

glob UNSUPPORTED_STMT: str = "__c2jac_unsupported__",
     UNSUPPORTED_EXPR: str = "__c2jac_unsupported_expr__";

def classify_c_constant(c_type: str) -> str {
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
    if raw.startswith("'") and raw.endswith("'") {
        return raw[1:-1];
    }
    return raw;
}

def c_char_ord(raw: str) -> int | None {
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
    if raw.startswith('"') and raw.endswith('"') and len(raw) >= 2 {
        return raw[1:-1];
    }
    return None;
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

def expr_reeval_safe(nd: object) -> bool {
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

def has_loop_continue(nd: object) -> bool {
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
    if not expr_reeval_safe(cond) {
        return False;
    }

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
        if i == last {
            continue;
        }
        it = items[i];

        if isinstance(it, c_ast.Case) and not it.stmts {
            continue;
        }
        if not section_terminates(it.stmts) {
            return False;
        }
    }
    return True;
}

def is_simple_ref(c_node: object) -> bool {
    return (
        isinstance(c_node, c_ast.ID)
        or isinstance(c_node, c_ast.StructRef)
        or isinstance(c_node, c_ast.ArrayRef)
    );
}

def cast_scalar_target(nd: object) -> str | None {
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

def jac_prim_zero(jac: str) -> tuple {
    if jac == "float" {
        return (0.0, "0.0");
    }
    if jac == "bool" {
        return (False, "False");
    }
    return (0, "0");
}

glob _JAC_KW_IDS: set = set(TOKEN_MAP.values()) | set(keyword.kwlist);

def jac_id(name: str) -> str {
    return f"`{name}`" if name in _JAC_KW_IDS else name;
}

def enumerator_value(en: object, counter: int) -> tuple {
    if en.value is None {
        return (counter, True);
    }
    if isinstance(en.value, c_ast.Constant) and en.value.type == "int" {
        v = parse_c_int(en.value.value);
        return (v, True) if v is not None else (0, False);
    }
    if (
        isinstance(en.value, c_ast.UnaryOp)
        and en.value.op in ("-", "+")
        and isinstance(en.value.expr, c_ast.Constant)
        and en.value.expr.type == "int"
    ) {
        v = parse_c_int(en.value.expr.value);
        if v is None {
            return (0, False);
        }
        return (-v, True) if en.value.op == "-" else (v, True);
    }
    return (0, False);
}
