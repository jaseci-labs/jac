"""Bundled native `textwrap` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import from textwrap { wrap, fill, dedent, indent }` binds CPython's
`textwrap` on the sv (Python) backend and the bundled `na_stdlib/textwrap.na.jac`
Mechanism-B module on the na (native LLVM) backend. Inputs are whitespace-
separated (no hyphenated words) and tab-free so the two are congruent under this
module's documented `break_on_hyphens=False` / "\n"-only-splitlines scope.

`wrap` returns a list, which the cross-backend harness reads as raw i64; so it is
probed via `len(...)` and through `fill` (the "\n"-joined wrap) compared as an
exact string. ES/JS opts out.
"""

import from textwrap { wrap, fill, dedent, indent }


def textwrap_py -> dict {
    return {
        "nlines1": len(wrap("The quick brown fox jumped over the lazy dog", 15)),
        "fill1": fill("The quick brown fox jumped over the lazy dog", 15),
        "fill2": fill("aaaaaaaaaaaaaaaaaaaa bbb cc", 8),
        "fill3": fill("supercalifragilisticexpialidocious word", 10),
        "fill4": fill("a b c d e f g h i j k l m n o p", 5),
        "fill5": fill("hello    world   foo", 11),
        "ded1": dedent("    hello\n    world\n"),
        "ded2": dedent("  a\n    b\n  c"),
        "ded3": dedent("   line1\n\n   line2\n"),
        "ind1": indent("hello\nworld\n", "> "),
        "ind2": indent("a\n\nb\n", "# "),
        "ind3": indent("line1\n  line2\nline3", "| ")
    };
}


cl def textwrap_cl -> dict {
    return {};
}


na {
    def textwrap_na -> dict[str, any] {
        return {
            "nlines1": len(wrap("The quick brown fox jumped over the lazy dog", 15)),
            "fill1": fill("The quick brown fox jumped over the lazy dog", 15),
            "fill2": fill("aaaaaaaaaaaaaaaaaaaa bbb cc", 8),
            "fill3": fill("supercalifragilisticexpialidocious word", 10),
            "fill4": fill("a b c d e f g h i j k l m n o p", 5),
            "fill5": fill("hello    world   foo", 11),
            "ded1": dedent("    hello\n    world\n"),
            "ded2": dedent("  a\n    b\n  c"),
            "ded3": dedent("   line1\n\n   line2\n"),
            "ind1": indent("hello\nworld\n", "> "),
            "ind2": indent("a\n\nb\n", "# "),
            "ind3": indent("line1\n  line2\nline3", "| ")
        };
    }
}
