"""Tuple keys in a native set hash and compare their str members by content.

A `set[tuple[str, str]]` used to hash the tuple's raw struct bytes (FNV over
the key) and compare candidates with `memcmp` over the same bytes, so two
tuples holding equal strings from different allocations never matched: the
member pointers differed. Every JIT probe that reused one allocation passed
by accident; the sealed kit's `ASTValidationPass`, executing natively over
real lexer tokens, lost `E0076` for a duplicated property setter because its
`(name, accessor_kind)` key never hit `seen_accessors`. Keys are now hashed
and compared field by field: str members by content, scalars by value,
other pointers by identity. Red-first: every function below builds its probe
key from fresh concatenations.
"""

import os;
import ctypes;
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { TESTS_DIR, native_address, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "tuple-of-str keys compare by content when the strings are fresh allocations" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "tuple_key_content.jac"),
        options=native_force_opts()
    );
    errs = [str(e) for e in prog.errors_had];
    assert not errs , f"errors: {errs}";
    eng = ir.gen.native_engine;
    assert eng is not None , "no native engine";
    got = [];
    for name in ("paren_fresh", "plain_fresh", "mixed_fresh", "dedup_fresh") {
        addr = native_address(eng, name);
        assert addr != 0 , f"{name} not in JIT engine";
        got.append(ctypes.CFUNCTYPE(ctypes.c_int64)(addr)());
    }
    assert got == [101, 101, 101, 102] , (
        f"got {got}: expected [101, 101, 101, 102]. A leading 0/2 means the "
        "equal key built from fresh strings was not found (pointer identity)"
    );
    llvm = str(ir.gen.llvm_ir);
    assert "__jac_str_fnv" in llvm , "tuple keys must hash str members by content";
}
