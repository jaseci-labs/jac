"""Native string comparison lowered inline from (data, len) parts.

== / != compare lengths before any bytes, so against a literal the byte compare
is a constant-size memcmp LLVM expands inline; orderings branch on the shorter
side so the literal's length is the memcmp size on the hot path. These pin the
results against a byte-wise reference and that the inline lowering is used.
"""

import ctypes;
import from tests.support { compile_native, compile_native_ir, get_func }

test "string comparisons match byte-wise lexicographic order" {
    (eng, _) = compile_native("str_parts_cmp.jac");
    assert get_func(eng, "matrix_mismatches", ctypes.c_int64)() == 0;
    assert get_func(eng, "literal_mismatches", ctypes.c_int64)() == 0;
}

test "string comparisons lower length-first, not through str_cmp3" {
    llvm = str(compile_native_ir("str_parts_cmp.jac").gen.llvm_ir);
    assert "seq.len" in llvm , "== / != must test lengths before comparing bytes";
    assert "sord.lge" in llvm , "orderings must branch on the shorter operand";
}
