"""A typed connect's attribute assignments reach the edge it creates.

`a +>:E:f=v:+> b` (and its backward `<+:E:f=v:<+` and undirected
`<+:E:f=v:+>` spellings) carries the assignments on the `ConnectOp` as an
`AssignCompr`. The Python runtime builds `E()` and then sets each named
field. The native lowering built the edge through its no-argument factory
and connected it without ever reading `conn_assign`, so every assignment was
dropped silently and the edge kept its field defaults.

The fixture covers literal, variable and computed values; several fields at
once; fields left out keeping their defaults; the forward, backward and
undirected spellings; connects inside a function, a method and a walker
ability; a runtime edge type (including a subclass layout reached through
`type[Link]`); an edge instance with extra assignments; the assignment
landing after `postinit` as in Python; and a loop that replaces string
fields on many edges.
"""

import ctypes;
import os;
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support {
    TESTS_DIR,
    assert_native_identity,
    native_address,
    native_force_opts
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     FIXTURE = "osp_connect_edge_attrs.jac";

glob _MEMO: list[any] = [];

"""Compile the fixture once and return (coverage record, errors, engine)."""
def measured -> tuple[any, ...] {
    if _MEMO {
        return _MEMO[0];
    }
    path = os.path.join(FIXTURES, FIXTURE);
    prog = JacProgram();
    na_coverage_begin();
    ir = None;
    try {
        ir = prog.compile(file_path=path, options=native_force_opts());
    } finally {
        coverage = na_coverage_end();
    }
    errors = [str(e) for e in (prog.errors_had or [])];
    rec = coverage.get(os.path.realpath(path)) or coverage.get(path);
    out = (rec, errors, (ir.gen.native_engine if ir is not None else None), );
    _MEMO.append(out);
    return out;
}

"""Call a no-argument fixture function through the JIT."""
def answer(eng: any, name: str) -> int {
    addr = native_address(eng, name);
    assert addr != 0 , f"function '{name}' is not in the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}

test "connects with edge attributes lower natively without seams" {
    (rec, errors, eng) = measured();
    assert not errors , f"the fixture must compile: {errors}";
    assert rec is not None , "the fixture produced no native coverage record";
    assert rec.get("outcome") == "native" , (
        f"the fixture must lower natively, got {rec.get('outcome')}: "
        f"{rec.get('code')} {rec.get('detail')}"
    );
    assert not (rec.get("seams") or []) , (
        f"no seam is expected here: {[str(s) for s in (rec.get('seams') or [])]}"
    );
    assert eng is not None , "no JIT engine was produced for the fixture";
}

test "literal, variable and computed values are assigned" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "literal_attrs") == 31;
    assert answer(eng, "variable_attrs") == 71;
    assert answer(eng, "expression_attrs") == 631;
}

test "fields left out keep their defaults" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "defaults_kept") == 501;
}

test "backward and undirected connects assign their edge" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "backward_attrs") == 61;
    assert answer(eng, "undirected_attrs") == 441;
}

test "connects inside functions, methods and abilities assign their edge" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "inside_function") == 41;
    assert answer(eng, "inside_method") == 421;
    assert answer(eng, "inside_walker_ability") == 61;
}

test "runtime edge types and subclasses receive the assignments" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "dynamic_type_attrs") == 21;
    assert answer(eng, "subclass_attrs") == 1025;
    assert answer(eng, "instance_with_attrs") == 91;
}

test "assignments land after postinit, as in the Python runtime" {
    (_rec, _errors, eng) = measured();
    assert answer(eng, "assigned_after_postinit") == 1100;
}

test "repeated connects replace string fields on every edge" {
    (_rec, _errors, eng) = measured();
    for _ in range(3) {
        assert answer(eng, "repeated_connects") == 500124751;
    }
}

"""An edge type whose fields have no defaults cannot be built with no
arguments, so a connect that names them passes them to the constructor, as
`E(f=v)` does, on the Python tier and in native binaries alike. Both used to
build `E()` first: Python raised a missing-argument TypeError and native
raised "edge type cannot be constructed without arguments". A defaulted
field named beside them is still set after `postinit`, every value is
evaluated in source order before the edge is built, a list connect
evaluates the values once, and an edge with its own `init` gets the
parameters it requires."""
test "connects build edges whose constructor requires the assigned fields" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "connect_required_fields.jac"),
        profiles=["rc", "managed"]
    );
    assert out
        == (
            "step 2 1\n"
            "in a function 4 0\n"
            "backward 5 3\n"
            "named n4 7\n"
            "postinit kept 101\n"
            "fan out 1 3\n"
            "fan out labels 2 ['fan2', 'fan2']\n"
            "custom init 3 8 custom\n"
            "source order 3 4\n"
            "kept alive old4 9 new4\n"
            "fan kept alive ['old4', 'old4'] new4\n"
        ) , out;
}
