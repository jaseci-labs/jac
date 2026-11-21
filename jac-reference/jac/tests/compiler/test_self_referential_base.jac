"""A class may name itself in its own generic base.

`class Selfy(Holder[Selfy])` sent the evaluator back through the symbol
it was already resolving, and the re-entry guard answered Unknown, so
every member typed through that base went untyped. A forward reference
to a class declared later always worked, which is what made the failure
specific to naming yourself.

`str` is the one that mattered in practice: typeshed writes it as
`class str(Sequence[str])`, so `sorted(s)` came back `list[Unknown]` and
`list(s)` came back bare, while the same calls over `bytes`, `list[int]`
and `tuple[int, ...]` were exact.
"""

import os;
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { JAC_ROOT }

glob FIXTURE: str = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "fixtures",
         "self_referential_base.jac"
     );


def _assign_errors -> list[str] {
    out = JacProgram();
    out.compile(FIXTURE);
    return [
        e.msg
        for e in out.errors_had
        if e.code is not None and e.code.code == "E1001"
    ];
}


test "a self-referential generic base resolves to the class itself" {
    msgs = _assign_errors();
    assert "Cannot assign Selfy to int" in msgs , msgs;
    assert not [
        m
        for m in msgs
        if "Unknown" in m
    ] , msgs;
}


test "a forward-referenced base still resolves" {
    msgs = _assign_errors();
    assert "Cannot assign Later to int" in msgs , msgs;
    assert "Cannot assign int to str" in msgs , msgs;
}


test "str carries its element type through Sequence[str]" {
    msgs = _assign_errors();
    assert msgs.count("Cannot assign list[str] to int") == 2 , msgs;
}
