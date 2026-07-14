"""Bundled native `textwrap` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import from textwrap { wrap, fill, dedent, indent }` binds CPython's
`textwrap` on the sv (Python) backend and the bundled `na_stdlib/textwrap.na.jac`
Mechanism-B module on the na (native LLVM) backend. Inputs are whitespace-
separated (no hyphenated words) and tab-free so the two are congruent under this
module's documented `break_on_hyphens=False` / "\n"-only-splitlines scope.

`wrap` returns a list, which the cross-backend harness reads as raw i64; so it is
probed via `len(...)` and through `fill` (the "\n"-joined wrap) compared as an
exact string. The `lw*` keys pin CPython's `_handle_long_word` at
`space_left == 0`, where 3.14 changed behavior (>= 3.14 skips the break;
<= 3.13 appended the empty slice, preserving a trailing-whitespace chunk) --
the sv runtime is CPython 3.14, so these enforce the >= 3.14 semantics.
`werr*` pin the `width <= 0` ValueError. ES/JS opts out.
"""

import from textwrap { wrap, fill, dedent, indent }


def textwrap_py -> dict {
    werr0: str = "no raise";
    try {
        wrap("hello", 0);
    } except ValueError {
        werr0 = "ValueError";
    }
    werrneg: str = "no raise";
    try {
        wrap("hello", -3);
    } except ValueError {
        werrneg = "ValueError";
    }
    return {
        "nlines1": len(wrap("The quick brown fox jumped over the lazy dog", 15)),
        "fill1": fill("The quick brown fox jumped over the lazy dog", 15),
        "fill2": fill("aaaaaaaaaaaaaaaaaaaa bbb cc", 8),
        "fill3": fill("supercalifragilisticexpialidocious word", 10),
        "fill4": fill("a b c d e f g h i j k l m n o p", 5),
        "fill5": fill("hello    world   foo", 11),
        "lw1": fill("bb  quicksand", 4),
        "lw2": fill(" dddd", 1),
        "lw3": fill("word  longlongword", 6),
        "lwn": len(wrap("bb  quicksand", 4)),
        "werr0": werr0,
        "werrneg": werrneg,
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
        werr0: str = "no raise";
        try {
            wrap("hello", 0);
        } except ValueError {
            werr0 = "ValueError";
        }
        werrneg: str = "no raise";
        try {
            wrap("hello", -3);
        } except ValueError {
            werrneg = "ValueError";
        }
        return {
            "nlines1": len(wrap("The quick brown fox jumped over the lazy dog", 15)),
            "fill1": fill("The quick brown fox jumped over the lazy dog", 15),
            "fill2": fill("aaaaaaaaaaaaaaaaaaaa bbb cc", 8),
            "fill3": fill("supercalifragilisticexpialidocious word", 10),
            "fill4": fill("a b c d e f g h i j k l m n o p", 5),
            "fill5": fill("hello    world   foo", 11),
            "lw1": fill("bb  quicksand", 4),
            "lw2": fill(" dddd", 1),
            "lw3": fill("word  longlongword", 6),
            "lwn": len(wrap("bb  quicksand", 4)),
            "werr0": werr0,
            "werrneg": werrneg,
            "ded1": dedent("    hello\n    world\n"),
            "ded2": dedent("  a\n    b\n  c"),
            "ded3": dedent("   line1\n\n   line2\n"),
            "ind1": indent("hello\nworld\n", "> "),
            "ind2": indent("a\n\nb\n", "# "),
            "ind3": indent("line1\n  line2\nline3", "| ")
        };
    }
}
