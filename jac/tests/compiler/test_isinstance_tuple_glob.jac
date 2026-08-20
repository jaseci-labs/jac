"""`isinstance(x, TABLE)` narrows to the table's classes, not to `tuple`.

Python's `isinstance` takes its second argument by value: a tuple of classes
is as valid spelled as a name as it is spelled inline, and both mean "any of
these". `TypeEvaluator._extract_isinstance_info` read only the literal form
(`condition.params[1]` had to be a `TupleVal` node). Anything else fell to a
catch-all that converted the argument's own type to an instance -- so a name
whose type is `tuple[type[Leaf]]` narrowed the subject to a *tuple*.

That is not a missed narrow, it is a wrong one, and it is louder than it
looks: every member access and every call site downstream of the guard then
type-checks against `tuple`. It surfaced in `capability_check_pass`, whose
`NATIVE_REJECT_NODES` table guards the node it then files a violation for:

    glob NATIVE_REJECT_NODES: tuple = (PyInlineCode, );
    if isinstance(nd, NATIVE_REJECT_NODES) {
        out.append((nd, kind, type(nd).__name__, None));   # nd was `tuple`
    }

The catch-all remains for the ordinary single-class case. What changes is
that a tuple-typed argument is now read as the alternatives it holds: each
element type that names a class contributes its instance, and the narrow is
their union. A table whose element types are erased (a bare `tuple`
annotation) carries no classes to narrow to, so the guard narrows nothing
rather than narrowing to something false -- the erased case is the one that
must stay silent, because there is no honest answer to give.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(TESTS_DIR, "compiler", "fixtures");

"""Type-check a fixture and return its errors."""
def check_errors(fixture: str) -> list {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)),
        options=CompileOptions(type_check=True, no_cgen=True)
    );
    return [str(e) for e in (prog.errors_had or [])];
}


test "a named tuple-of-types guard type-checks clean" {
    errs = check_errors("isinstance_tuple_glob.jac");
    assert not errs , f"expected no type errors, got {errs}";
}


test "the guarded subject keeps its own identity, not the table's" {
    # `takes_base(nd)` inside the guard is the shape that broke: the narrow
    # replaced a `Base` with a `tuple`, and `tuple` is not a `Base`. A
    # single-class table and an erased table both go through it.
    joined = " ".join(check_errors("isinstance_tuple_glob.jac"));
    assert "of type Base" not in joined , (
        "the isinstance guard narrowed its subject away from Base: " + joined
    );
    assert "tuple" not in joined , (
        "the table's own type leaked into the narrowed subject: " + joined
    );
}


test "the bare tuple class narrows like any other class" {
    # `isinstance(x, tuple)` is not a table: the class shares the table
    # type's `shared` but is class-form, not a tuple value. Misreading it as
    # an empty table dropped the guard entirely, so neither branch narrowed
    # (#8330). The fixture's `bare_class_positive` needs the true branch
    # narrowed to `tuple`, `bare_class_negative` needs `tuple` subtracted in
    # the elif.
    errs = check_errors("isinstance_tuple_glob.jac");
    assert not errs , f"bare tuple guard left its subject unnarrowed: {errs}";
}
