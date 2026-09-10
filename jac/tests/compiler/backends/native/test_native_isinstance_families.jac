"""Behavioral tests for the isinstance arms a tag compare cannot answer alone.

Three families are covered, and each is pinned against CPython's own answer for
the same operand rather than against a hand-written expectation, so the native
result is compared to the semantics it is supposed to reproduce.

*Untagged builtins.* A native tuple is an unboxed literal struct and `bytes` /
`bytearray` are pointers to their own runtime structs, so none of the three has
a JacVal tag to compare against. Each is decided from the operand's LLVM type
instead, which is known at the check -- so the arm settles at compile time and
`isinstance(x, (list, tuple))` stops refusing to lower the moment one of its
arms is untagged.

*Abstract base classes.* `collections.abc.Sequence` is a Python object no
native unit can host. It answers by reducing to the finite set of native shapes
that inhabit it; ABCs with no exact reduction refuse loudly instead, and the
refusal is read back off the coverage seam that demotes the method, naming the
ABC, rather than being a wrong answer nobody sees.

*Type arms that arrive as values.* `isinstance(x, types)` with `types` a
parameter. The fixed-arity spelling unrolls its arms; the variadic one lowers
to a native sequence, so the compare runs as a loop over a runtime length.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import jaclang;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     _ENGINE: list = [];

"""Stand-ins for the fixture's archetypes, so CPython answers the same question."""
class PyBase {}

class PyFoo(PyBase) {}

class PyBar(PyBase) {}

class PyBaz(PyBase) {}

"""Compile the fixture once and hand back its JIT engine."""
def families_engine -> ExecutionEngine {
    if _ENGINE {
        return _ENGINE[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "isinstance_families.jac")),
        options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not errors , f"isinstance_families.jac did not lower: {errors}";
    assert ir.gen.llvm_ir , "no native IR for isinstance_families.jac";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine for isinstance_families.jac";
    _ENGINE.append(eng);
    return eng;
}

"""A JIT-resident `int -> int` (or `-> int`) entry point as a callable."""
def native_fn(name: str, argc: int = 1) -> any {
    addr = native_address(families_engine(), name);
    assert addr != 0 , f"'{name}' is not in the JIT engine";
    if argc == 0 {
        return ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
    }
    return ctypes.CFUNCTYPE(ctypes.c_int64, ctypes.c_int64)(addr);
}

"""CPython's verdict for the same operand, as the 0/1 the fixture returns."""
def py_verdict(value: any, types: any) -> int {
    return 1 if isinstance(value, types) else 0;
}

"""The operand `chk_list_or_tuple` / `chk_sequence` build for each selector."""
def operand_for(k: int) -> any {
    return [[1, 2], "s", 3, PyFoo()][k];
}


test "untagged arm: (list, tuple) lowers and answers per CPython" {
    f = native_fn("chk_list_or_tuple");
    for k in range(4) {
        assert f(k) == py_verdict(operand_for(k), (list, tuple, )) , (
            f"chk_list_or_tuple({k}) disagrees with CPython"
        );
    }
}


test "untagged arm: a tuple operand matches tuple and (list, tuple)" {
    assert native_fn("chk_tuple_operand", argc=0)()
        == py_verdict((1, 2, ), (list, tuple, ));
    assert native_fn("chk_tuple_bare", argc=0)() == py_verdict((1, 2, 3, ), tuple);
}


test "untagged arm: a list is not a tuple" {
    assert native_fn("chk_list_is_not_tuple", argc=0)() == py_verdict([1, 2], tuple);
}


test "untagged arm: bytes answers by its own runtime struct" {
    assert native_fn("chk_bytes_operand", argc=0)() == py_verdict(b"abc", bytes);
    assert native_fn("chk_str_is_not_bytes", argc=0)() == py_verdict("abc", bytes);
}


test "abc arm: Sequence reduces to the native shapes that inhabit it" {
    f = native_fn("chk_sequence");
    operands: list = [[1, 2], 5, "ab", {1: 2}, PyFoo()];
    for k in range(len(operands)) {
        assert f(k) == py_verdict(operands[k], Sequence) , (
            f"chk_sequence({k}) disagrees with CPython"
        );
    }
}


test "abc arm: Sequence holds for operands whose type is already known" {
    f = native_fn("chk_sequence_typed");
    operands: list = ["ab", [1, 2], (1, 2, )];
    for k in range(len(operands)) {
        assert f(k) == py_verdict(operands[k], Sequence) , (
            f"chk_sequence_typed({k}) disagrees with CPython"
        );
    }
}


test "abc arm: Mapping separates dicts from sequences" {
    f = native_fn("chk_mapping");
    assert f(0) == py_verdict({1: 2}, Mapping);
    assert f(1) == py_verdict([1, 2], Mapping);
}


test "abc arm: an ABC with no exact reduction refuses instead of guessing" {
    import from jaclang.compiler.driver.na_coverage {
        na_coverage_begin,
        na_coverage_end
    }
    prog = JacProgram();
    na_coverage_begin();
    try {
        prog.compile(
            file_path=str(os.path.join(FIXTURES, "isinstance_abc_opaque.jac")),
            options=native_force_opts()
        );
    } finally {
        coverage = na_coverage_end();
    }
    said = " ".join(
        str(seam) for rec in coverage.values() for seam in (rec["seams"] or [])
    );
    assert "isinstance against `Iterable`" in said , (
        "an unreducible ABC has to name itself in the seam that demotes the "
        f"method, so the refusal is actionable; got: {said}"
    );
}


test "abc arm: a Python-based operand refuses rather than read a partial MRO" {
    import from jaclang.compiler.driver.na_coverage {
        na_coverage_begin,
        na_coverage_end
    }
    prog = JacProgram();
    na_coverage_begin();
    try {
        prog.compile(
            file_path=str(os.path.join(FIXTURES, "isinstance_pyb_abc.jac")),
            options=native_force_opts()
        );
    } finally {
        coverage = na_coverage_end();
    }
    said = " ".join(
        str(seam) for rec in coverage.values() for seam in (rec["seams"] or [])
    );
    assert "isinstance against `Sequence`" in said , (
        "a reducible ABC is only exact while the operand's whole MRO is "
        f"native; a Python-side base has to refuse it; got: {said}"
    );
}


test "value arms: a fixed-arity tuple of types unrolls" {
    f = native_fn("chk_types_fixed");
    picks: list = [PyFoo(), PyBar(), PyBaz()];
    for k in range(3) {
        assert f(k) == py_verdict(picks[k], (PyFoo, PyBar, )) , (
            f"chk_types_fixed({k}) disagrees with CPython"
        );
    }
}


test "value arms: a variadic tuple of types loops over a runtime length" {
    f = native_fn("chk_types_variadic");
    picks: list = [PyFoo(), PyBar(), PyBaz()];
    for k in range(3) {
        assert f(k) == py_verdict(picks[k], (PyFoo, PyBar, )) , (
            f"chk_types_variadic({k}) disagrees with CPython"
        );
    }
}


test "seam shapes: the coverage sites' own spellings lower and answer" {
    walk = native_fn("chk_parent_walk", argc=0);
    assert walk() == 1 , (
        "`_find_parent_of_types` walks parents until an arm in the runtime "
        "tuple matches; the first parent matches here"
    );
    seq = native_fn("chk_link_sequential");
    assert seq(0) == 2 , "`_link_sequential` sees a two-element body";
    assert seq(1) == -1 , "and refuses a `None` body before the Sequence check";
}


test "value arms: the variadic arity is the caller's, not the signature's" {
    one = native_fn("chk_types_variadic_one");
    three = native_fn("chk_types_variadic_three");
    picks: list = [PyFoo(), PyBar(), PyBaz()];
    for k in range(3) {
        assert one(k) == py_verdict(picks[k], (PyBaz, )) , (
            f"chk_types_variadic_one({k}) disagrees with CPython"
        );
        assert three(k) == py_verdict(picks[k], (PyFoo, PyBar, PyBaz, )) , (
            f"chk_types_variadic_three({k}) disagrees with CPython"
        );
    }
}
