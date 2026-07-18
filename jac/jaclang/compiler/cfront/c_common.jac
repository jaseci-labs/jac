import keyword;
import from jaclang.jac0core.constant { TOKEN_MAP }
import from jaclang.jac0core { unitree as uni }
import from jaclang.vendor.pycparser { c_ast }
import from jaclang.compiler.cfront.c_types { JacPrim }

enum BinKind { ARITH = "arith", COMPARE = "compare", BOOL = "bool" }

glob C_BINOPS: dict[str, tuple[BinKind, str]] = {
         "+": (BinKind.ARITH, "Add"),
         "-": (BinKind.ARITH, "Sub"),
         "*": (BinKind.ARITH, "Mult"),
         "/": (BinKind.ARITH, "Div"),
         "%": (BinKind.ARITH, "Mod"),
         "&": (BinKind.ARITH, "BitAnd"),
         "|": (BinKind.ARITH, "BitOr"),
         "^": (BinKind.ARITH, "BitXor"),
         "<<": (BinKind.ARITH, "LShift"),
         ">>": (BinKind.ARITH, "RShift"),
         "==": (BinKind.COMPARE, "Eq"),
         "!=": (BinKind.COMPARE, "NotEq"),
         "<": (BinKind.COMPARE, "Lt"),
         "<=": (BinKind.COMPARE, "LtE"),
         ">": (BinKind.COMPARE, "Gt"),
         ">=": (BinKind.COMPARE, "GtE"),
         "&&": (BinKind.BOOL, "And"),
         "||": (BinKind.BOOL, "Or"),

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

def _c_int_autobase(raw: str) -> int {
    return int(raw, 0);
}

def _parse_strippable(raw: str, fn: callable, suffix: str) -> object | None {
    try {
        return fn(raw);
    } except ValueError {
        stripped = raw.rstrip(suffix);
        if stripped and stripped != raw {
            try {
                return fn(stripped);
            } except ValueError {
                return None;
            }
        }
        return None;
    }
}

def parse_c_int(raw: str) -> int | None {
    return _parse_strippable(raw, _c_int_autobase, "uUlL");
}

def parse_c_float(raw: str) -> float | None {
    return _parse_strippable(raw, float, "fFlL");
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

obj PrimZero {
    has value: object,
        text: str;
}

def jac_prim_zero(jac: JacPrim) -> PrimZero {
    if jac == JacPrim.FLOAT {
        return PrimZero(value=0.0, text="0.0");
    }
    if jac == JacPrim.BOOL {
        return PrimZero(value=False, text="False");
    }
    return PrimZero(value=0, text="0");
}

glob _JAC_KW_IDS: set = set(TOKEN_MAP.values()) | set(keyword.kwlist);

def jac_id(name: str) -> str {
    return f"`{name}" if name in _JAC_KW_IDS else name;
}

def c_field(nd: object, field: str) -> object {
    return getattr(nd, field, None);
}

obj EnumVal {
    has value: int,
        simple: bool;
}

def enumerator_value(en: object, counter: int) -> EnumVal {
    if en.value is None {
        return EnumVal(value=counter, simple=True);
    }
    if isinstance(en.value, c_ast.Constant) and en.value.type == "int" {
        v = parse_c_int(en.value.value);
        return EnumVal(value=v, simple=True)
            if v is not None
            else EnumVal(value=0, simple=False);
    }
    if (
        isinstance(en.value, c_ast.UnaryOp)
        and en.value.op in ("-", "+")
        and isinstance(en.value.expr, c_ast.Constant)
        and en.value.expr.type == "int"
    ) {
        v = parse_c_int(en.value.expr.value);
        if v is None {
            return EnumVal(value=0, simple=False);
        }
        signed = -v if en.value.op == "-" else v;
        return EnumVal(value=signed, simple=True);
    }
    return EnumVal(value=0, simple=False);
}

obj EnumPairs {
    has pairs: list,
        all_simple: bool;
}

def eval_enumerators(enumerator_list: object) -> EnumPairs {
    pairs: list = [];
    counter: int = 0;
    all_simple = True;
    for en in enumerator_list.enumerators {
        ev = enumerator_value(en, counter);
        if not ev.simple {
            all_simple = False;
        }
        pairs.append((en.name, ev.value));
        counter = ev.value + 1;
    }
    return EnumPairs(pairs=pairs, all_simple=all_simple);
}

def c_tok(c_node: object, orig_src: uni.Source, text: str = "") -> uni.Token {
    (line, col) = coord_of(c_node, 1);
    span = max(len(text), 1);
    tok = uni.Token(
        orig_src=orig_src,
        name="C_ANCHOR",
        value=text,
        line=line,
        end_line=line,
        col_start=col,
        col_end=col + span,
        pos_start=0,
        pos_end=span,
    );
    tok._is_synthetic = True;
    return tok;
}
