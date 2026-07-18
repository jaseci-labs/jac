"""CPython-parity value-semantics tests for the native pathway (issue
#7320, Cluster 2 silent-wrong-value family).

Each fixture exercises an idiom that previously compiled clean on na but
returned a different value than CPython/sv, with results encoded into a
single i64 so a silent divergence fails an equality assert.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

# --- 2a: chained comparisons lower every link, not just the first ---
test "chained comparison: every link is evaluated and ANDed" {
    (eng, _) = compile_native("py_chain_cmp.na.jac");
    get_func(eng, "jac_entry", None)();
    cases = get_func(eng, "chain_cases", ctypes.c_int64);
    result = cases();
    # a=0 (2<3<1), b=1, c=1, d=1, e=0, f=1, g=1
    assert result == 111011 , f"Expected 111011, got {result}";
}

test "chained comparison: middle operand evaluated exactly once" {
    (eng, _) = compile_native("py_chain_cmp.na.jac");
    get_func(eng, "jac_entry", None)();
    once = get_func(eng, "middle_evaluated_once", ctypes.c_int64);
    result = once();
    assert result == 11 , f"Expected 11 (true, one bump), got {result}";
}

test "chained comparison: three-link chain with mixed directions" {
    (eng, _) = compile_native("py_chain_cmp.na.jac");
    get_func(eng, "jac_entry", None)();
    chain = get_func(eng, "long_chain", ctypes.c_int64);
    result = chain();
    assert result == 1 , f"Expected 1 (1<2<3>2), got {result}";
}

# --- 2b: or/and yield the deciding operand value, not a truth bit ---
test "bool ops: int or/and return the operand value" {
    (eng, _) = compile_native("py_bool_ops.na.jac");
    get_func(eng, "jac_entry", None)();
    ops = get_func(eng, "bool_ops_int", ctypes.c_int64);
    result = ops();
    # 5 or 7 = 5; 0 or 7 = 7; 3 and 9 = 9; 0 and 9 = 0
    assert result == 5790 , f"Expected 5790, got {result}";
}

test "bool ops: str or picks the fallback for empty strings" {
    (eng, _) = compile_native("py_bool_ops.na.jac");
    get_func(eng, "jac_entry", None)();
    ops = get_func(eng, "bool_ops_str", ctypes.c_int64);
    result = ops();
    assert result == 1111 , f"Expected 1111 (all four str cases), got {result}";
}

test "bool ops: rhs is not evaluated when lhs decides" {
    (eng, _) = compile_native("py_bool_ops.na.jac");
    get_func(eng, "jac_entry", None)();
    ops = get_func(eng, "bool_ops_short_circuit", ctypes.c_int64);
    result = ops();
    # v=5, w=0, zero bump() calls
    assert result == 500 , f"Expected 500, got {result}";
}

# --- 2c: membership compares string values, not pointer identity ---
test "membership: str in list[str] compares values" {
    (eng, _) = compile_native("py_membership.na.jac");
    get_func(eng, "jac_entry", None)();
    mem = get_func(eng, "str_list_membership", ctypes.c_int64);
    result = mem();
    # beta found, heap needle found, delta absent, not-in true, 2 in nums
    assert result == 11011 , f"Expected 11011, got {result}";
}

test "membership: str in d.keys() compares values" {
    (eng, _) = compile_native("py_membership.na.jac");
    get_func(eng, "jac_entry", None)();
    mem = get_func(eng, "dict_keys_membership", ctypes.c_int64);
    result = mem();
    assert result == 110 , f"Expected 110, got {result}";
}

# --- 2d: sort()/sorted() honor reverse= and key= ---
test "sort kwargs: reverse=True sorts descending in place" {
    (eng, _) = compile_native("py_sort_kwargs.na.jac");
    get_func(eng, "jac_entry", None)();
    srt = get_func(eng, "sort_reverse", ctypes.c_int64);
    result = srt();
    assert result == 321 , f"Expected 321, got {result}";
}

test "sort kwargs: sorted(reverse=True) returns a descending copy" {
    (eng, _) = compile_native("py_sort_kwargs.na.jac");
    get_func(eng, "jac_entry", None)();
    srt = get_func(eng, "sorted_reverse_copies", ctypes.c_int64);
    result = srt();
    # b untouched (3xxx), c descending 321
    assert result == 3321 , f"Expected 3321, got {result}";
}

test "sort kwargs: key=len orders by key not by element" {
    (eng, _) = compile_native("py_sort_kwargs.na.jac");
    get_func(eng, "jac_entry", None)();
    srt = get_func(eng, "sort_key_len", ctypes.c_int64);
    result = srt();
    assert result == 111 , f"Expected 111 (a, dd, ccc), got {result}";
}

test "sort kwargs: key= and reverse= compose" {
    (eng, _) = compile_native("py_sort_kwargs.na.jac");
    get_func(eng, "jac_entry", None)();
    srt = get_func(eng, "sort_key_and_reverse", ctypes.c_int64);
    result = srt();
    # keys mod 10: 5->5, 12->2, 3->3; descending keys: 5, 3, 12
    assert result == 50312 , f"Expected 50312, got {result}";
}

# --- dropped-argument family: range step, find start, pow modulus ---
test "range honors a positive and negative step in for headers" {
    (eng, _) = compile_native("py_dropped_args.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "range_step_sum", ctypes.c_int64);
    result = fn();
    # 0,3,6,9 -> 369; 5,3,1 -> 531
    assert result == 369531 , f"Expected 369531, got {result}";
}

test "str.find honors the start argument" {
    (eng, _) = compile_native("py_dropped_args.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "find_with_start", ctypes.c_int64);
    result = fn();
    # find('b', 2)=4, find('b')=1, find('z', 1)=-1
    assert result == 411 , f"Expected 411, got {result}";
}

test "pow honors the modulus argument" {
    (eng, _) = compile_native("py_dropped_args.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "pow_with_mod", ctypes.c_int64);
    result = fn();
    # pow(3,4,5)=1, pow(2,10,1000)=24
    assert result == 1024 , f"Expected 1024, got {result}";
}

# --- 2f: f-strings size their buffer and honor format specs ---
test "fstring: output larger than 1024 bytes is not truncated" {
    (eng, _) = compile_native("py_fstring.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "fstring_long", ctypes.c_int64);
    result = fn();
    assert result == 1204 , f"Expected 1204, got {result}";
}

test "fstring: numeric and string format specs render like CPython" {
    (eng, _) = compile_native("py_fstring.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "fstring_specs", ctypes.c_int64);
    result = fn();
    # .2f, 04d, x, and >4/<4 alignment all correct
    assert result == 1111 , f"Expected 1111, got {result}";
}

test "range with zero step raises ValueError instead of looping" {
    (eng, _) = compile_native("py_dropped_args.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "range_zero_step_raises", ctypes.c_int64);
    result = fn();
    assert result == 1 , f"Expected 1 (caught ValueError), got {result}";
}

test "pow with zero modulus raises ValueError instead of trapping" {
    (eng, _) = compile_native("py_dropped_args.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "pow_zero_mod_raises", ctypes.c_int64);
    result = fn();
    assert result == 1 , f"Expected 1 (caught ValueError), got {result}";
}
