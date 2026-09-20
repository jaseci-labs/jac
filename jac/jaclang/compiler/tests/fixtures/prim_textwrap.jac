"""Textwrap: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

import from textwrap { wrap, fill, dedent, indent }


def textwrap_py -> dict[any, any] {
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


def textwrap_cl -> dict[any, any] {
    return {};
}


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
