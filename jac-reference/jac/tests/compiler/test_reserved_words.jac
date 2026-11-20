"""The reserved words have one source, and every one of them says so (#8982 item 10).

The lexer's keyword table is the only list of reserved words. The parser's
binding-position check reads it, the language reference prints it between two
markers, and this file holds the three together: the printed list equals the
table, every reserved word in a binding position is one E0013 (no cascade),
and after a dot none of them needs the escape.
"""

import os;
import re;
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.parser { parse }
import from jaclang.compiler.frontend.parser.tokens {
    BUILTIN_TYPE_KINDS,
    KEYWORDS,
    SPECIAL_VAR_KINDS,
    TokenKind,
    reserved_words
}

glob FOUNDATION = os.path.join(
         os.path.dirname(str(jaclang.__file__)),
         "cli",
         "docs",
         "reference",
         "language",
         "foundation.md"
     );

def _codes(src: str) -> list[str] {
    prog = JacProgram();
    parse(src, "/tmp/reserved_probe.jac", prog=prog);
    return [
        a.code.code
        for a in prog.errors_had
        if a.code is not None
    ];
}

test "the language reference prints exactly the lexer's reserved words" {
    with open(FOUNDATION) as fh {
        doc = fh.read();
    }
    m = re.search(r"<!-- reserved-words:begin.*?-->\s*```text\n(.*?)```", doc, re.S);
    assert m is not None , "foundation.md lost its reserved-words block";
    printed = sorted(str(w) for w in m.group(1).split());
    expected = reserved_words();
    missing = [
        w
        for w in expected
        if w not in printed
    ];
    extra = [
        w
        for w in printed
        if w not in expected
    ];
    assert printed == expected , (
        f"missing from the doc: {missing}; not reserved but printed: {extra}"
    );
}

test "every plain reserved word in a binding position is one E0013" {
    plain = [
        word
        for (word, kind) in KEYWORDS.items()
        if kind not in SPECIAL_VAR_KINDS
            and kind not in BUILTIN_TYPE_KINDS
            and word in reserved_words()
    ];
    assert len(plain) > 50 , plain;
    cascades: dict[str, list[str]] = {};
    for word in plain {
        codes = _codes(f"obj X {{ has {word}: int = 1; }}");
        if codes != ["E0013"] {
            cascades[word] = codes;
        }
    }
    assert not cascades , (
        "a reserved word as a field name must report exactly one E0013 naming "
        f"the escape, not: {cascades}"
    );
}

test "a reserved word after a dot needs no escape" {
    for word in reserved_words() {
        assert _codes(f"with entry {{ v = holder.{word}; }}") == [] , word;
    }
}


test "the builtin type kinds are exactly the enum's TYP_ members" {
    # The set is spelled out because tokens.jac runs natively in the compiler
    # kernel; this keeps it honest against the enum it mirrors.
    typ_members = {
        kind
        for kind in TokenKind
        if str(kind.name).startswith("TYP_")
    };
    assert BUILTIN_TYPE_KINDS == typ_members , (
        f"missing: {sorted(str(k) for k in typ_members - BUILTIN_TYPE_KINDS)}; "
        f"extra: {sorted(str(k) for k in BUILTIN_TYPE_KINDS - typ_members)}"
    );
    for kind in BUILTIN_TYPE_KINDS {
        assert kind in KEYWORDS.values() , f"{kind} is not lexed as a keyword";
    }
}
