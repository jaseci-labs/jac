"""A generator expression is a Generator, and an enum union keeps its members.

A generator expression was typed as `list[T]`, the same as a list
comprehension. `list` has no `__next__`, so `next(genexpr, default)` matched
no overload -- while the equivalent `next(iter(seq), default)` worked.

Separately, attribute access over a union only understood class-instance
members, so a union of enum members -- what a variable assigned different
members across branches has -- lost `.value` and `.name`. A single enum
member resolved them fine; only the union broke, and the diagnostic named
no missing type because there was none to name.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="genenum.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "a generator expression can be advanced with next" {
    src = "def probe(items: list[int]) -> (int | None) {\n"
        + "    return next((i for i in items if i > 2), None);\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"generator expression rejected by next: {errs}";
}

test "a generator expression is still iterable and consumable" {
    src = "def probe(items: list[int]) -> int {\n"
        + "    total = 0;\n"
        + "    for i in (x * 2 for x in items) {\n"
        + "        total += i;\n"
        + "    }\n"
        + "    return total + sum(y for y in items);\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"generator expression lost iterability: {errs}";
}

test "value resolves on a union of enum members" {
    src = "import from jaclang.compiler.frontend.constant { Tokens as Tok }\n"
        + "def probe(x: str) -> str {\n"
        + "    t: (Tok | None) = None;\n"
        + "    if x == 'a' {\n"
        + "        t = Tok.KW_INIT;\n"
        + "    } elif x == 'b' {\n"
        + "        t = Tok.KW_POST_INIT;\n"
        + "    }\n"
        + "    if t is not None {\n"
        + "        return t.value;\n"
        + "    }\n"
        + "    return '';\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"enum union lost .value: {errs}";
}

test "any member resolves on a union of enum members" {
    src = "import enum;\n"
        + "class Color(enum.Enum) {\n"
        + "    RED = 1;\n"
        + "    GREEN = 2;\n"
        + "}\n"
        + "def probe(x: str) -> int {\n"
        + "    c: (Color | None) = None;\n"
        + "    if x == 'a' {\n"
        + "        c = Color.RED;\n"
        + "    } elif x == 'b' {\n"
        + "        c = Color.GREEN;\n"
        + "    }\n"
        + "    if c is not None {\n"
        + "        sibling = c.RED;\n"
        + "        assert sibling is not None and c.name is not None;\n"
        + "        return c.value;\n"
        + "    }\n"
        + "    return 0;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"enum union lost a member: {errs}";
}
