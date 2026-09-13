"""The closed graph-query sublanguage: what is admitted inside `[?...]`.

`E5094`'s help text sets the rule the whole traversal design rests on --
predicates inside a graph reference are `field <op> value` and push into SQL;
everything else belongs in a comprehension over the result "where its
object-space cost is visible". These tests pin the boundary itself.

Composite keys (`(at, seq) < (a, b)`) are the one admitted extension: keyset
pagination needs a tiebreak, and a tuple of field names against a tuple of
scalars stays inside the closed sublanguage -- same operators, same
push-to-SQL guarantee, one more arity.

Anything outside the sublanguage must produce a diagnostic. It must never
crash the checker: a malformed filter is user input, not an ICE.
"""

import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }

glob PRELUDE: str = "node Chan { has name: str = \"\"; }\n"
     "node Msg { has body: str = \"\", at: int = 0, seq: int = 0; }\n"
     "edge Posted { has sent: int = 0; }\n";


"""Compile a filter body and return (diagnostic codes, rendered messages)."""
def _diags(body: str) -> tuple[list[str], str] {
    prog = JacProgram();
    prog.compile(
        file_path="gq_src.jac",
        use_str=PRELUDE + body,
        options=CompileOptions(no_cgen=True)
    );
    alerts = list(prog.errors_had) + list(prog.warnings_had);
    codes = [
        a.code.code
        for a in alerts
        if a.code is not None
    ];
    return (codes, " | ".join([str(a) for a in alerts]));
}


def _codes(body: str) -> list[str] {
    return _diags(body)[0];
}


def _shown(body: str) -> str {
    return _diags(body)[1];
}


"""Codegen diagnostics need the JCIR pass, which `no_cgen` skips."""
def _cgen_codes(body: str) -> list[str] {
    prog = JacProgram();
    prog.compile(file_path="gq_cgen.jac", use_str=PRELUDE + body);
    alerts = list(prog.errors_had) + list(prog.warnings_had);
    return [
        a.code.code
        for a in alerts
        if a.code is not None
    ];
}


test "composite key of field names against scalars is admitted" {
    body = "def go(c: Chan, a: int, b: int) -> list[Msg] {\n"
    "    return [c ->:Posted:-> [?:Msg, (at, seq) < (a, b)]];\n"
    "}\n";
    (codes, shown) = _diags(body);
    assert "E5094" not in codes , shown;
    assert "E1033" not in codes , shown;
    assert "W2001" not in codes , (
        f"a bound composite key must not leave its names undefined: {shown}"
    );
}


test "composite key binds every element to a real member symbol" {
    out = _codes(
        "def go(c: Chan, a: int, b: int) -> list[Msg] {\n"
        "    return [c ->:Posted:-> [?:Msg, (at, nope) < (a, b)]];\n"
        "}\n"
    );
    assert "E1033" in out , (
        f"a composite key naming a field that does not exist must report: {out}"
    );
    assert "nope"
        in _shown(
            "def go(c: Chan, a: int, b: int) -> list[Msg] {\n"
            "    return [c ->:Posted:-> [?:Msg, (at, nope) < (a, b)]];\n"
            "}\n"
        );
}


test "composite key arity mismatch is reported, not crashed" {
    out = _codes(
        "def go(c: Chan, a: int) -> list[Msg] {\n"
        "    return [c ->:Posted:-> [?:Msg, (at, seq) < (a,)]];\n"
        "}\n"
    );
    assert "E5094" in out , out;
    assert "W2001" not in out , (
        f"an arity error must not cascade into undefined-name noise: {out}"
    );
}


test "a non-name left side is still outside the sublanguage" {
    out = _codes(
        "def go(c: Chan) -> list[Msg] {\n"
        "    return [c ->:Posted:-> [?:Msg, len(body) > 3]];\n"
        "}\n"
    );
    assert "E5094" in out , out;
}


test "a malformed filter never raises out of the checker" {
    for body in [
        "def a(c: Chan, x: int) -> list[Msg] {\n"
        "    return [c ->:Posted:-> [?:Msg, (at, seq) < x]];\n"
        "}\n",
        "def b(c: Chan) -> list[Msg] {\n"
        "    return [c ->:Posted:-> [?:Msg, (at,) < (1,)]];\n"
        "}\n",
        "def d(c: Chan) -> list[Msg] {\n"
        "    return [c ->:Posted:-> [?:Msg, () < ()]];\n"
        "}\n"
    ] {
        _ = _diags(body);
    }
}


test "an unfoldable sort key reports the object-space cost" {
    out = _cgen_codes(
        "def go(c: Chan) -> list[Msg] {\n"
        "    return sorted(\n"
        "        [c ->:Posted:-> [?:Msg]],\n"
        "        key=lambda (m: Msg) { -(m.at + m.at); }\n"
        "    );\n"
        "}\n"
    );
    assert "W5096" in out , out;
}


test "a foldable sort key reports nothing" {
    out = _cgen_codes(
        "def go(c: Chan) -> list[Msg] {\n"
        "    return sorted([c ->:Posted:-> [?:Msg]], key=lambda (m: Msg) { -m.at; });\n"
        "}\n"
    );
    assert "W5096" not in out , out;
}


test "an in-place sort over a bound traversal reports" {
    out = _cgen_codes(
        "def go(c: Chan) -> list[Msg] {\n"
        "    got = [c ->:Posted:-> [?:Msg]];\n"
        "    got.sort(key=lambda (m: Msg) { -m.at; });\n"
        "    return got;\n"
        "}\n"
    );
    assert "W5096" in out , out;
}


test "an in-place sort over an ordinary list reports nothing" {
    out = _cgen_codes(
        "def go(c: Chan) -> list[int] {\n"
        "    got = [3, 1, 2];\n"
        "    got.sort();\n"
        "    return got;\n"
        "}\n"
    );
    assert "W5096" not in out , out;
}
