"""One authority answers "is this name a type, or a value?".

A name in a type position is a message to the checker: nothing loads it, calls
it, or reads an attribute off it at run time. Five separate passes need that
answer -- the type checker (E1132, a type-only import used as a value; E0033, a
comptime import used at run time), the native capability gate (E5090, a Python
module a native unit would have to import at run time), static analysis (E2018,
an unresolved name in a native type position), and the client import gates
(E5082/E5084, a server-only or Python-only binding the browser would have to
resolve).

Each of those passes used to carry its own answer, and each was missing a
different part of the language: an `as` cast, a `type` alias, a generic
parameter, an `edge A --> B` endpoint, or -- in one case -- an annotation
nested more than eight nodes deep. `in_type_position` is the single authority,
and this file is its contract. The consumer-level tests live with their own
diagnostics; what is pinned here is the shape of the language.
"""

import os;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.parser { parse as rd_parse }
import from jaclang.compiler.frontend.unitree { Name, in_type_position }
import from tests.support { TESTS_DIR }

glob PROBE_PATH = os.path.join(
         TESTS_DIR, "compiler", "fixtures", "type_position_probe.jac"
     );

"""Parse `src` without binding: the predicate reads shape, not symbols."""
def _parse(src: str) -> any {
    (mod, had_err) = rd_parse(src, PROBE_PATH, prog=JacProgram());
    assert not had_err , f"probe source did not parse: {src!r}";
    return mod;
}

"""Every `Name` node spelled `value` in `src`, in source order."""
def _names(src: str, value: str) -> list[Name] {
    return [
        nm
        for nm in _parse(src).get_all_sub_nodes(typ=Name)
        if nm.value == value
    ];
}

"""Assert every mention of `value` in `src` reads as a type."""
def _all_type_position(src: str, value: str, count: int) {
    found = _names(src, value);
    assert len(found) == count , (
        f"expected {count} mentions of {value!r}, found {len(found)} in {src!r}"
    );
    for nm in found {
        assert in_type_position(nm) , (
            f"{value!r} at line {nm.loc.first_line} col {nm.loc.col_start} is a "
            f"type position, but the predicate called it a value: {src!r}"
        );
    }
}

"""Assert every mention of `value` in `src` reads as a value."""
def _all_value_position(src: str, value: str, count: int) {
    found = _names(src, value);
    assert len(found) == count , (
        f"expected {count} mentions of {value!r}, found {len(found)} in {src!r}"
    );
    for nm in found {
        assert not in_type_position(nm) , (
            f"{value!r} at line {nm.loc.first_line} col {nm.loc.col_start} is a "
            f"run-time use, but the predicate called it a type: {src!r}"
        );
    }
}

test "a parameter, local, and field annotation are type positions" {
    _all_type_position(
        "obj Box {\n"
        "    has held: Pt;\n"
        "}\n"
        "def take(p: Pt) -> int {\n"
        "    q: Pt = p;\n"
        "    return 0;\n"
        "}\n",
        "Pt",
        3
    );
}

test "a return type is a type position" {
    _all_type_position("def make -> Pt {\n    return ret();\n}\n", "Pt", 1);
}

test "an `as` cast names a type, not a value" {
    _all_type_position(
        "def widen(p: any) -> int {\n    q = p as Pt;\n    return 0;\n}\n", "Pt", 1
    );
}

test "a `type` alias right-hand side is a type position" {
    _all_type_position("type Alias = Pt;\n", "Pt", 1);
    _all_type_position("type Brand := Pt;\n", "Pt", 1);
}

test "a generic parameter bound and its default are type positions" {
    _all_type_position(
        "def pick[T: Pt = Pt](v: T) -> T {\n    return v;\n}\n", "Pt", 2
    );
}

test "an edge declaration's endpoints are type positions" {
    _all_type_position("edge Link: Pt --> Pt {}\n", "Pt", 2);
    _all_type_position("edge Held: Box --> Box {\n    has via: Pt;\n}\n", "Box", 2);
}

test "a generic argument inside an annotation is a type position" {
    _all_type_position(
        "def take(xs: list[Pt]) -> dict[str, Pt] {\n    return {};\n}\n", "Pt", 2
    );
}

test "a deeply nested annotation is a type position at any depth" {
    _all_type_position(
        "def take(xs: dict[str, dict[str, dict[str, list[Pt]]]]) -> int {\n"
        "    return 0;\n"
        "}\n",
        "Pt",
        1
    );
}

test "an ability signature inside an impl is a type position" {
    _all_type_position(
        "obj Box {\n"
        "    def held -> Pt;\n"
        "}\n"
        "impl Box.held -> Pt {\n"
        "    return make();\n"
        "}\n",
        "Pt",
        2
    );
}

test "a call, an attribute base, and a parameter default are run-time uses" {
    _all_value_position("with entry {\n    v = Pt();\n}\n", "Pt", 1);
    _all_value_position("with entry {\n    v = Pt.origin;\n}\n", "Pt", 1);
    _all_value_position("def take(p: any = Pt) -> int {\n    return 0;\n}\n", "Pt", 1);
}

test "a connect operator's edge type is a run-time use" {
    _all_value_position(
        "def link(a: any, b: any) -> None {\n    a +>:Pt:+> b;\n}\n", "Pt", 1
    );
}

test "a subscript index is a run-time use when subscripts are excluded" {
    nm = _names("def take(xs: any) -> int {\n    return xs[Idx];\n}\n", "Idx")[0];
    assert in_type_position(nm) , (
        "a subscript argument reads as a type by default: that is what a "
        "generic argument is"
    );
    assert not in_type_position(nm, include_subscripts=False) , (
        "a subscript alone does not make a name a type -- `xs[Idx]` reads "
        "`Idx` at run time, and the passes that gate a run-time binding on "
        "this predicate must keep seeing it"
    );
}

test "a generic argument inside an annotation survives excluding subscripts" {
    for src in [
        "def take(xs: dict[str, list[Pt]]) -> int {\n    return 0;\n}\n",
        "def make -> list[Pt] {\n    return [];\n}\n",
        "def widen(raw: any) -> int {\n    v = raw as list[Pt];\n    return 0;\n}\n",
        "type Alias = dict[str, Pt];\n"
    ] {
        nm = _names(src, "Pt")[0];
        assert in_type_position(nm, include_subscripts=False) , (
            f"the annotation, return type, cast or alias above the subscript "
            f"is what makes {src!r} a type position"
        );
    }
}
