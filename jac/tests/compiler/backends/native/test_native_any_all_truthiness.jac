"""`any` and `all` ask the element for its truth, not for a nonzero integer.

`any`/`all` compared the element a list handed back against an integer zero
whatever that element's type was. For a list of int that happens to be right;
for a pointer element it produced IR the backend could not parse, so a single
`any(list_of_str)` anywhere took out the module's IR with a parse error rather
than a diagnostic. That is the ICE class: a compiler-side defect must either
lower or refuse by name, never emit IR the backend cannot read.

Both now route the element through the same truth test every other condition
uses, which knows strings, floats, bools, pointers, optionals and boxed
values; where it has no answer, the decision step refuses the one function.

The fixture covers each element family against both a true and a false
answer, because a truth test that always answers "nonzero pointer" also
compiles.
"""

import ctypes;
import from tests.support { compile_mir, compile_native, native_address }

glob FIXTURE = "any_all_elem_truthiness.jac",
     _ENG: list[any] = [];

"""JIT the fixture once and return its engine."""
def engine -> any {
    if not _ENG {
        (eng, _) = compile_native(FIXTURE);
        _ENG.append(eng);
    }
    return _ENG[0];
}

"""Call a no-argument fixture function through the JIT."""
def answer(eng: any, name: str) -> int {
    addr = native_address(eng, name);
    assert addr != 0 , f"function '{name}' is not in the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}


test "a list of non-integer elements does not take the module's IR with it" {
    demoted = compile_mir(FIXTURE).demoted();
    assert not demoted , (
        f"a module whose only unusual content is any()/all() over non-integer "
        f"elements must lower natively with nothing demoted: {demoted}"
    );
}

test "str elements answer with their own emptiness" {
    eng = engine();
    assert answer(eng, "any_str_none") == 0;
    assert answer(eng, "any_str_some") == 1;
    assert answer(eng, "all_str_yes") == 1;
    assert answer(eng, "all_str_no") == 0;
}

test "float elements answer with their own value" {
    eng = engine();
    assert answer(eng, "any_float_none") == 0;
    assert answer(eng, "any_float_some") == 1;
    assert answer(eng, "all_float_no") == 0;
}

test "bool elements answer with themselves" {
    eng = engine();
    assert answer(eng, "any_bool_none") == 0;
    assert answer(eng, "any_bool_some") == 1;
    assert answer(eng, "all_bool_no") == 0;
}

test "int elements keep the answer they always had" {
    eng = engine();
    assert answer(eng, "any_int_none") == 0;
    assert answer(eng, "any_int_some") == 1;
    assert answer(eng, "all_int_yes") == 1;
    assert answer(eng, "all_int_no") == 0;
}


test "boolean comprehensions store results independently of input element types" {
    eng = engine();
    for i in range(20) {
        assert answer(eng, "any_object_comprehension") == 1;
        assert answer(eng, "all_object_comprehension") == 0;
        assert answer(eng, "any_negated_comprehension") == 1;
        assert answer(eng, "all_literal_comprehension") == 1;
        assert answer(eng, "any_float_comparison") == 1;
        assert answer(eng, "any_empty_comprehension") == 0;
    }
}

test "and/or comprehensions over boolean operands store booleans" {
    eng = engine();
    for i in range(20) {
        assert answer(eng, "any_and_field_comparison") == 1;
        assert answer(eng, "any_and_field_comparison_miss") == 0;
        assert answer(eng, "all_or_field_comparison") == 1;
        assert answer(eng, "all_or_field_comparison_miss") == 0;
        assert answer(eng, "any_and_bool_fields") == 1;
        assert answer(eng, "all_nested_boolop") == 1;
        assert answer(eng, "any_not_mixed_boolop") == 1;
        assert answer(eng, "stored_boolop_count") == 10;
        assert answer(eng, "any_float_boolop") == 1;
        assert answer(eng, "all_float_boolop") == 0;
        assert answer(eng, "any_empty_boolop") == 0;
        assert answer(eng, "all_empty_boolop") == 1;
    }
}

test "and/or comprehensions over non-boolean operands keep operand values" {
    eng = engine();
    for i in range(20) {
        assert answer(eng, "or_keeps_int_operand") == 73;
        assert answer(eng, "or_keeps_str_operand") == 1;
    }
}
