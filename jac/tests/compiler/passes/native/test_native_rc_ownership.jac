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
import from jaclang.jac0core.compile_options { CompileOptions }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(
    fixture: str, gc_mode: str | None = None
) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    opts = CompileOptions(na_gc_mode=gc_mode) if gc_mode is not None else None;
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)), options=opts);
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

"""Slice one function's textual IR out of the module dump."""
def fn_ir(ir: uni.Module, name: str) -> str {
    out: list[str] = [];
    inside = False;
    for ln in str(ir.gen.llvm_ir).split("\n") {
        if not inside and ln.startswith("define") and (('@"' + name + '"') in ln) {
            inside = True;
        }
        if inside {
            out.append(ln);
            if ln == "}" {
                break;
            }
        }
    }
    assert out , f"No IR found for function '{name}'";
    return "\n".join(out);
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

# --- Param names must stay per-function codegen state (issue #7466, 1/2) ---
test "param shadow: other fn's param names add no retain-on-return" {
    # `push(s, v)` is never called; its param `v` must not make `make_vec`'s
    # `return v` path treat the fresh local as a borrowed param and retain it
    # (rc=2 at the caller -> every returned Vec leaks).
    (eng, ir) = compile_native("rc_param_shadow_return.na.jac");
    body = fn_ir(ir, "make_vec");
    n = body.count('call void @"__rc_retain"');
    assert n == 0 , f"make_vec should return its owned local with no retain, found {n}";
    sum_first = get_func(eng, "sum_first", ctypes.c_int64, ctypes.c_int64);
    result = sum_first(3);
    assert result == 3 , f"Expected 3 (0.5 * 2 per round), got {result}";
}

test "param shadow: loop-exit cleanup still releases same-named locals" {
    # `use2(a: &Box, b: &Box)`'s param names match `churn`'s two fresh loop
    # locals; the loop-exit (iter_end) cleanup must still release both or the
    # final iteration's Boxes are never freed.
    (eng, ir) = compile_native("rc_param_shadow_looptail.na.jac");
    body = fn_ir(ir, "churn");
    assert "iter.cleanup.a" in body , "loop-exit cleanup for local 'a' was suppressed";
    assert "iter.cleanup.b" in body , "loop-exit cleanup for local 'b' was suppressed";
    churn = get_func(eng, "churn", ctypes.c_int64, ctypes.c_int64);
    result = churn(10);
    assert result == 100 , f"Expected 100, got {result}";
}

# --- Heap-element containers under non-default gc modes (issue #7466, 3) ---
test "heap-element container compiles and runs under --gc rc" {
    # The list[str] element-release helper used to re-enter _emit_rc_helpers
    # (its guard checked a cycles-only global) and redefine __rc_debug:
    # DuplicatedNameError ICE under rc, fine under the default cycles mode.
    (eng, _) = compile_native("rc_heap_container.na.jac", gc_mode="rc");
    count_strs = get_func(eng, "count_strs", ctypes.c_int64);
    result = count_strs();
    assert result == 2 , f"Expected 2, got {result}";
}

test "heap-element container compiles and runs under plain --gc none" {
    (eng, _) = compile_native("rc_heap_container.na.jac", gc_mode="none");
    count_strs = get_func(eng, "count_strs", ctypes.c_int64);
    result = count_strs();
    assert result == 2 , f"Expected 2, got {result}";
}

test "import sys compiles under --gc rc (argv list is a heap container)" {
    (eng, _) = compile_native("rc_import_sys.na.jac", gc_mode="rc");
    addr = eng.get_function_address("argc_minus_one");
    assert addr != 0 , "argc_minus_one not emitted";
}

# --- def drop parity across gc modes (issue #7466, 4) ---
"""Run the drop fixture and assert the hook fired once per destroyed Res."""
def check_drop_parity(gc_mode: str | None) {
    (eng, ir) = compile_native("rc_drop_hook.na.jac", gc_mode=gc_mode);
    body = fn_ir(ir, "__rc_release_Res");
    assert 'call' in body and 'Res.drop' in body , "managed release fn does not invoke the drop hook";
    run_drops = get_func(eng, "run_drops", ctypes.c_int64);
    drop_count = get_func(eng, "drop_count", ctypes.c_int64);
    last_dropped = get_func(eng, "last_dropped", ctypes.c_int64);
    before = drop_count();
    total = run_drops();
    assert total == 18 , f"Expected 18 (5+6+7), got {total}";
    fired = drop_count() - before;
    assert fired == 3 , f"drop should fire once per Res (3), fired {fired}";
    last = last_dropped();
    assert last == 7 , f"last drop should see tag=7, got {last}";
}

test "drop hook fires on rc release (--gc rc)" {
    check_drop_parity("rc");
}

test "drop hook fires under the default cycles collector" {
    check_drop_parity(None);
}
