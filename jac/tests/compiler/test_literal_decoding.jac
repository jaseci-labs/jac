"""Differential gate for jac's string-literal decoder.

`String.lit_value` used to hand prefixed literals to CPython `eval`, which
made literal decoding a Python-only seam: `eval` has no native lowering, so
`unitree` could not seal past it and every sealed caller of `lit_value`
(`sem_def_match_pass.connect_sems` among them) reached an `abort()` stub.
`unitree.decode_string_literal` replaces it with one implementation both
lanes run.

The bar for that replacement is CPython-exact for everything jac accepts,
so the corpus here is generated rather than written: every prefix the
parser splices onto a `STRING` token, crossed with every quote form the
lexer scans, crossed with escape payloads built out of the lexer's own
escape-admission alphabet. A candidate only enters the corpus if the real
lexer produces it as one literal token, so the corpus is exactly the set of
literal forms the front end can hand the decoder -- no more, and nothing
hand-picked. Each one is then decoded twice, once by `eval` and once by the
decoder, and the two must agree on the value or agree on refusing.

One exclusion is deliberate and is asserted as a refusal rather than
silently tolerated: `\\N{name}` needs the Unicode name database, which the
compiler cannot carry into a native unit. Every other `\\N` spelling is a
`SyntaxError` in CPython too, so the escape is one loud refusal instead of
a decode that quietly disagrees with Python.
"""

import os;
import warnings;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.parser { parse as rd_parse }
import from jaclang.jac0core.parser.lexer { tokenize, tokenize_full }
import from jaclang.jac0core.parser.tokens { TokenKind }
import from jaclang.jac0core.unitree { decode_string_literal }
import jaclang.jac0core.unitree as uni;

"""Every prefix spelling `Parser.parse_multistring` splices onto a STRING."""
glob LITERAL_PREFIXES: tuple = (
         '',
         'r',
         'b',
         'rb',
         'br',
         'R',
         'B',
         'rB',
         'Rb',
         'bR',
         'Br',
         'BR',
         'RB'
     );

"""Every quote form `Lexer.scan_string` opens a literal with."""
glob LITERAL_QUOTES: tuple = ("'", '"', "'''", '"""');

"""The escape alphabet `Lexer.scan_string` admits without a warning."""
glob LEXER_ESCAPE_CHARS: str = "nrtbfva01234567xNuU\\\"'";

"""The one literal form the decoder refuses that CPython accepts, and why."""
glob DECODER_EXCLUSIONS: dict[(str, str)] = {
         "\\N{name}": (
             "resolving a Unicode character name needs the name database, "
             "which no native unit can host"
         )
     };

glob _CORPUS_MEMO: list = [],
     _HARVEST_MEMO: list = [];

"""Payload bodies, built from the lexer's escape alphabet plus plain text."""
def _payloads -> list[str] {
    out: list[str] = ['', 'plain', 'a b', '{', '}', '{{}}', 'café', '中文'];
    for c in LEXER_ESCAPE_CHARS {
        out.append('\\' + c);
        out.append('x\\' + c + 'y');
        out.append('\\' + c + '0');
        out.append('\\' + c + '41');
        out.append('\\' + c + '0041');
        out.append('\\' + c + '00000041');
        out.append('\\' + c + '0010FFFF');
        out.append('\\' + c + '00110000');
        out.append('\\' + c + 'zz');
        out.append('\\' + c + '\\' + c);
    }
    for tail in ['', 'foo', '{}', '{BULLET}', '{bullet}', '{NO SUCH NAME}'] {
        out.append('\\N' + tail);
    }
    for bad in ['q', ' ', '8', '9', '-', 'p'] {
        out.append('\\' + bad);
    }
    out.append('\\\n');
    out.append('a\\\nb');
    out.append('line\nbreak');
    out.append('\\377');
    out.append('\\400');
    out.append('\\777');
    out.append('\\1111');
    out.append('\\0');
    out.append('\\00');
    out.append('\\000');
    return out;
}

"""True when jac's lexer scans `text` as exactly one string literal.

Mirrors `Parser.parse_multistring`: a bare `STRING`, or a `NAME` holding a
prefix immediately followed by a `STRING`, whose spliced value is `text`.
"""
def _is_one_literal(text: str) -> bool {
    (toks, errs) = tokenize(text, "<corpus>");
    if errs {
        return False;
    }
    body = [
        t
        for t in toks
        if t.kind != TokenKind.EOF
    ];
    if (len(body) == 1) {
        return body[0].kind == TokenKind.STRING and body[0].value == text;
    }
    if (len(body) == 2) {
        return (
            body[0].kind == TokenKind.NAME
            and body[1].kind == TokenKind.STRING
            and body[0].value in LITERAL_PREFIXES
            and (body[0].value + body[1].value) == text
        );
    }
    return False;
}

"""The generated corpus: every literal form the lexer produces from the grid."""
def _corpus -> list[str] {
    if _CORPUS_MEMO {
        return _CORPUS_MEMO[0];
    }
    seen: set[str] = set();
    out: list[str] = [];
    for prefix in LITERAL_PREFIXES {
        for quote in LITERAL_QUOTES {
            for payload in _payloads() {
                text = prefix + quote + payload + quote;
                if (text in seen) {
                    continue;
                }
                seen.add(text);
                if _is_one_literal(text) {
                    out.append(text);
                }
            }
        }
    }
    _CORPUS_MEMO.append(out);
    return out;
}

"""Decode `text` the way CPython does; `(False, None)` when it refuses."""
def _eval_decode(text: str) -> tuple[(bool, object)] {
    with warnings.catch_warnings() {
        warnings.simplefilter("ignore");
        try {
            return (True, eval(text));
        } except Exception {
            return (False, None);
        }
    }
}

"""Decode `text` with the native-lowerable decoder."""
def _native_decode(text: str) -> tuple[(bool, object)] {
    try {
        return (True, decode_string_literal(text));
    } except Exception {
        return (False, None);
    }
}

"""True when `text` carries the one escape the decoder deliberately refuses."""
def _is_excluded(text: str) -> bool {
    start = 0;
    while (start < len(text) and text[start] not in "\"'") {
        start += 1;
    }
    prefix = text[:start].lower();
    if ('r' in prefix or 'b' in prefix) {
        return False;
    }
    return "\\N" in text;
}

"""Every distinct STRING literal the lexer finds in the tree's own sources.

Walks the whole package and the whole suite rather than a sample: the
refusals this decoder added are compile-time failures, so a literal anywhere
in the tree that the decoder will not render is a broken build, and the only
honest way to know is to look at all of them. A source with a lex error is
skipped, since the error fixtures are meant to be unlexable.

Each entry is `(literal, "path:line")` so a failure names the file.
"""
def _harvest -> list[tuple[(str, str)]] {
    if _HARVEST_MEMO {
        return _HARVEST_MEMO[0];
    }
    seen: set[str] = set();
    out: list[tuple[(str, str)]] = [];
    for path in sorted(Path(JAC_ROOT).rglob("*.jac")) {
        text_path = str(path);
        if ("node_modules" in text_path or "/.jac/" in text_path) {
            continue;
        }
        try {
            src = path.read_text(encoding="utf-8");
        } except Exception {
            continue;
        }
        (toks, errs) = tokenize(src, text_path);
        if errs {
            continue;
        }
        rel = os.path.relpath(text_path, JAC_ROOT);
        i = 0;
        while (i < len(toks)) {
            tok = toks[i];
            if (tok.kind == TokenKind.STRING) {
                text = tok.value;
                if (
                    i > 0
                    and toks[i - 1].kind == TokenKind.NAME
                    and toks[i - 1].value in LITERAL_PREFIXES
                    and toks[i - 1].value != ''
                    and toks[i - 1].loc.pos_end == tok.loc.pos_start
                ) {
                    text = toks[i - 1].value + text;
                }
                if (text not in seen) {
                    seen.add(text);
                    out.append((text, f"{rel}:{tok.loc.line}", ));
                }
            }
            i += 1;
        }
    }
    _HARVEST_MEMO.append(out);
    return out;
}

"""Report every literal in `texts` whose two decodes disagree."""
def _diffs(texts: list[str]) -> list[str] {
    bad: list[str] = [];
    for text in texts {
        if _is_excluded(text) {
            continue;
        }
        (eval_ok, eval_val) = _eval_decode(text);
        (na_ok, na_val) = _native_decode(text);
        if (eval_ok != na_ok) {
            bad.append(
                f"{text!r}: eval "
                    + ("decoded" if eval_ok else "refused")
                    + ", decoder "
                    + ("decoded" if na_ok else "refused")
            );
            continue;
        }
        if (eval_ok and (type(eval_val) is not type(na_val) or eval_val != na_val)) {
            bad.append(f"{text!r}: eval {eval_val!r} != decoder {na_val!r}");
        }
    }
    return bad;
}


test "the generated corpus covers the whole literal grid" {
    corpus = _corpus();
    assert len(corpus) > 2000 , (
        f"only {len(corpus)} literal forms generated -- the grid shrank, so "
        "the differential below stopped proving what it claims"
    );
    for prefix in LITERAL_PREFIXES {
        for quote in LITERAL_QUOTES {
            head = prefix + quote;
            assert `any(( t.startswith(head) for t in corpus )) , (
                f"no corpus literal opens with {head!r}; the lexer stopped "
                "producing a form the parser still splices"
            );
        }
    }
}


test "native decode equals CPython decode across the generated corpus" {
    corpus = _corpus();
    bad = _diffs(corpus);
    assert not bad , (
        f"{len(bad)} of {len(corpus)} generated literals decode differently "
        "than CPython:\n"
        + "\n".join(bad[:40])
    );
}


test "native decode equals CPython decode across the harvested corpus" {
    harvest = _harvest();
    assert len(harvest) > 10000 , (
        f"only {len(harvest)} literals harvested from the tree -- the walk "
        "stopped finding sources, so this proves nothing"
    );
    bad = _diffs([text for (text, _where) in harvest]);
    assert not bad , (
        f"{len(bad)} of {len(harvest)} harvested literals decode differently "
        "than CPython:\n"
        + "\n".join(bad[:40])
    );
}


test "no literal anywhere in the tree's own sources is refused" {
    refused: list[str] = [];
    for (text, where) in _harvest() {
        try {
            decode_string_literal(text);
        } except Exception as e {
            refused.append(f"{where}: {text!r} -- {e}");
        }
    }

    # A refusal is a compile-time failure, so one literal in the tree the
    # decoder will not render is a broken build. Catching it here names the
    # file; catching it downstream names a test three layers away from it.
    assert not refused , (
        f"{len(refused)} literal(s) in the tree that the decoder refuses:\n"
        + "\n".join(refused[:40])
    );
}


test "the excluded escape is refused by the lexer and by the decoder" {
    assert DECODER_EXCLUSIONS , "the exclusion table stopped naming anything";
    for text in [
        '"\\N{BULLET}"',
        "'\\N{GREEK SMALL LETTER ALPHA}'",
        '"""\\N{BULLET}"""',
        '"\\Nfoo"',
        '"\\N"'
    ] {
        (_toks, _comments, diags, errs) = tokenize_full(text, "<excluded>");
        assert errs , (
            f"the lexer accepted {text!r}; the escape has to be refused where "
            "the source location still exists, not only at decode time"
        );
        codes = {
            d.code_str
            for d in diags
            if d.is_error
        };
        assert "E0110" in codes , (
            f"the lexer refused {text!r} with {sorted(codes)}, not the code "
            "the diagnostics reference documents for this escape"
        );
        assert not _is_one_literal(text) , (
            f"{text!r} still reaches the corpus, so the lexer refusal is not "
            "the gate this test claims it is"
        );
        raised = "";
        try {
            decode_string_literal(text);
        } except Exception as e {
            raised = str(e);
        }
        assert raised , (
            f"{text!r} decoded silently; a literal the decoder cannot render "
            "exactly has to refuse, never guess"
        );
        assert "\\N{name}" in raised , (
            f"{text!r} refused with {raised!r}, which does not name the "
            "escape that was refused"
        );
    }
}


test "the excluded escape stays a plain backslash where CPython keeps it" {
    for text in ['r"\\N{BULLET}"', 'b"\\N{BULLET}"', 'rb"\\N{BULLET}"'] {
        assert _is_one_literal(text) , (
            f"the lexer stopped accepting {text!r}; `\\N` is not an escape in "
            "a raw or bytes literal, so refusing it there would be wrong"
        );
        (eval_ok, eval_val) = _eval_decode(text);
        (na_ok, na_val) = _native_decode(text);
        assert eval_ok and na_ok , f"{text!r} refused on one side only";
        assert type(eval_val) is type(na_val) and eval_val == na_val , (
            f"{text!r}: eval {eval_val!r} != decoder {na_val!r}"
        );
    }
}


test "malformed hex escapes refuse instead of surviving as literal text" {
    for text in ['"\\x"', '"\\xZZ"', '"\\u12"', '"\\U0011FFFF"', 'b"\\x"'] {
        (eval_ok, _eval_val) = _eval_decode(text);
        assert not eval_ok , f"{text!r} is no longer a CPython error";
        raised = "";
        try {
            decode_string_literal(text);
        } except Exception as e {
            raised = str(e);
        }
        assert raised , f"{text!r} decoded silently instead of refusing";
    }
}


test "String.lit_value serves the decoder end to end" {
    corpus = [
        t
        for t in _corpus()
        if _native_decode(t)[0] and _eval_decode(t)[0] and "\n" not in t
    ];
    assert len(corpus) > 1000 , f"only {len(corpus)} single-line literals to parse";
    src = "glob _corpus_values = [\n" + ",\n".join(corpus) + "\n];\n";
    (module, had_error) = rd_parse(src, "<literal-corpus>");
    assert not had_error , "the generated corpus module does not parse";
    strings = [
        n
        for n in module.get_all_sub_nodes(uni.String)
        if isinstance(n.parent, uni.MultiString)
    ];
    assert len(strings) == len(corpus) , (
        f"parsed {len(strings)} String nodes for {len(corpus)} literals"
    );
    bad: list[str] = [];
    for (text, node) in zip(corpus, strings) {
        (_eval_ok, eval_val) = _eval_decode(text);
        got = node.lit_value;
        if (type(got) is not type(eval_val) or got != eval_val) {
            bad.append(f"{text!r}: lit_value {got!r} != eval {eval_val!r}");
        }
    }
    assert not bad , (
        f"{len(bad)} literals whose parsed `lit_value` disagrees with CPython:\n"
        + "\n".join(bad[:40])
    );
}
