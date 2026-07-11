"""Refcount/ownership regression tests for the native pathway (issue #7320,
Cluster 1).

Two ownership invariants of the na calling convention are exercised end to
end through the JIT:

  - every def returns a +1 reference: returning a module glob (heap string
    or list cache) must retain it, or the caller's release frees the glob
    (items 1d/1e);
  - named locals own what they hold: for-loop tuple unpack must retain the
    borrowed tuple fields it binds, or scope exit / early return releases
    strings still owned by the list (items 1a/1b/1c residue).

Fixtures encode first-use/second-use results into a single i64 so a wrong
value (freed glob, corrupted list) fails the assert rather than relying on
what freed memory happens to contain.
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

# --- Returning module globs must hand the caller a +1 reference (1d/1e) ---
test "glob return: list cache survives a for-loop over the accessor call" {
    # `for c in cmd_defs()` releases the loop collection it owns; the callee
    # must have retained the glob list or the cache dies after one scan.
    (eng, _) = compile_native("rc_glob_return.na.jac");
    get_func(eng, "jac_entry", None)();
    scan_twice = get_func(eng, "scan_twice", ctypes.c_int64);
    result = scan_twice();
    assert result == 13013 , f"Expected 13013 (13 per scan), got {result}";
}

test "glob return: heap glob string survives repeated accessor calls" {
    (eng, _) = compile_native("rc_glob_return.na.jac");
    get_func(eng, "jac_entry", None)();
    name_len_twice = get_func(eng, "name_len_twice", ctypes.c_int64);
    result = name_len_twice();
    assert result == 6006 , f"Expected 6006 (len('jactui') per read), got {result}";
}

test "glob return: accessor called inline inside len() twice" {
    (eng, _) = compile_native("rc_glob_return.na.jac");
    get_func(eng, "jac_entry", None)();
    defs_len_inline = get_func(eng, "defs_len_inline", ctypes.c_int64);
    result = defs_len_inline();
    assert result == 3003 , f"Expected 3003 (3 cmds per len), got {result}";
}

# --- Tuple unpack must retain the borrowed fields it binds (1a/1b/1c) ---
test "tuple unpack: second join over the same list is intact" {
    # Scope exit releases the unpack locals; without the retain the last
    # tuple's strings are freed while the list still holds them.
    (eng, _) = compile_native("rc_tuple_unpack.na.jac");
    get_func(eng, "jac_entry", None)();
    join_twice = get_func(eng, "join_twice", ctypes.c_int64);
    result = join_twice();
    assert result == 11 , f"Expected 11 (both joins match), got {result}";
}

test "tuple unpack: early return of an unpack-bound local keeps the list" {
    (eng, _) = compile_native("rc_tuple_unpack.na.jac");
    get_func(eng, "jac_entry", None)();
    early_ret = get_func(eng, "early_return_keeps_list", ctypes.c_int64);
    result = early_ret();
    assert result == 11 , f"Expected 11 (value and rejoin both ok), got {result}";
}
