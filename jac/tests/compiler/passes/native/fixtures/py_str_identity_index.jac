"""str() ownership and negative string indexing (CPython parity).

str(s) on a str returns the value itself; na must hand the caller its
own reference, since builtin call sites release owned argument
temporaries after dispatch. Before the fix `str("".join(...))` aliased
a handle the builtin-arg release freed, and read back empty -- the
sealed parser derived `_jac_gen_N` names for described tests from it.
String subscripts must also wrap negative indices (s[-1] is the last
character, not the byte before the string data) and raise IndexError
out of range, like list/bytes subscripts already do.
"""

def slug(desc_text: str) -> str {
    ident_chars: list[str] = [];
    prev_sep = False;
    for ch in desc_text {
        is_word = ("a" <= ch and ch <= "z")
            or ("A" <= ch and ch <= "Z")
            or ("0" <= ch and ch <= "9");
        if is_word {
            ident_chars.append(ch);
            prev_sep = False;
        } elif not prev_sep {
            ident_chars.append("_");
            prev_sep = True;
        }
    }
    ident: str = str("".join(ident_chars));
    if ident.startswith("_") {
        ident = ident[1:];
    }
    if ident.endswith("_") {
        ident = ident[:-1];
    }
    return ident.lower();
}

def:pub str_of_owned_temp -> int {
    return len(str("".join(["a", "b"])));
}

def:pub slug_of_desc -> int {
    s = slug("canary t");
    ok = 1 if s == "canary_t" else 0;
    return ok * 10 + len(s);
}

def:pub neg_index_reads -> int {
    v = '"canary t"';
    a = 1 if v[-1] == v[0] else 0;
    b = 1 if v[-1] == '"' else 0;
    c = 1 if v[-2] == "t" else 0;
    d = 1 if "abc"[-3] == "a" else 0;
    return a * 1000 + b * 100 + c * 10 + d;
}

def:pub neg_index_oob -> int {
    result = 0;
    try {
        x: str = "ab"[-3];
        result = -1;
    } except IndexError {
        result = 1;
    }
    return result;
}

def:pub pos_index_oob -> int {
    result = 0;
    try {
        x: str = "ab"[2];
        result = -1;
    } except IndexError {
        result = 1;
    }
    return result;
}

with entry {
    slug("");
}
